import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/alpr/plate_pipeline.dart';
import 'dart:typed_data';

void main() {
  group('CTC decode', () {
    test('collapse repeat + drop blank', () {
      // [1,48,37]: timesteps t0..t2 -> B(12), B(12), blank(0), 1(2)
      final logits = Float32List(48 * 37);
      void setArgmax(int t, int cls) {
        logits[t * 37 + cls] = 100.0;
      }

      setArgmax(0, 12); // B
      setArgmax(1, 12); // B (repeat -> collapse)
      setArgmax(2, 0); // blank (drop)
      setArgmax(3, 2); // '1'
      setArgmax(4, 2); // '1' -> collapse
      setArgmax(5, 36); // 'Z'

      expect(ctcGreedyDecode(logits), 'B1Z');
    });

    test('vocab index mapping 1->0, 11->A, 36->Z', () {
      final logits = Float32List(48 * 37);
      logits[0 * 37 + 1] = 100; // '0'
      logits[1 * 37 + 11] = 100; // 'A'
      logits[2 * 37 + 36] = 100; // 'Z'
      expect(ctcGreedyDecode(logits), '0AZ');
    });
  });

  group('validasi plat', () {
    test('pola Indonesia valid', () {
      expect(isValidPlate('B1234XYZ'), isTrue);
      expect(isValidPlate('AB1234X'), isTrue);
      expect(isValidPlate('B1X'), isTrue);
    });

    test('pola salah ditolak', () {
      expect(isValidPlate('1234XYZ'), isFalse); // huruf depan wajib
      expect(isValidPlate('B1234'), isFalse); // huruf belakang wajib
      expect(isValidPlate('B1X2'), isFalse); // digit di posisi huruf
      expect(isValidPlate(''), isFalse);
    });
  });

  group('softmax confidence', () {
    test('rata-rata max-softmax per timestep', () {
      final logits = Float32List(48 * 37);
      // Setiap timestep: satu kelas dominan 3.0, sisa 0.0 -> max-softmax
      // = exp(3) / (exp(3) + 36*exp(0)) = 0.3581
      for (var t = 0; t < 48; t++) {
        logits[t * 37 + 5] = 3.0;
      }
      expect(softmaxConfidence(logits), closeTo(0.3581, 0.001));
    });
  });

  group('decode detections + NMS', () {
    DetectorInput input() => DetectorInput(
          tensor: Float32List(0),
          scale: 1.0,
          padX: 0,
          padY: 0,
          inputSize: 100,
        );

    // Output tflite [1,5,N] bersifat channel-major: semua cx, lalu cy, dst.
    Float32List output(List<List<double>> anchors) {
      final n = anchors.length;
      final out = Float32List(5 * n);
      for (var i = 0; i < n; i++) {
        out[i] = anchors[i][0]; // cx
        out[n + i] = anchors[i][1]; // cy
        out[2 * n + i] = anchors[i][2]; // w
        out[3 * n + i] = anchors[i][3]; // h
        out[4 * n + i] = anchors[i][4]; // conf
      }
      return out;
    }

    test('cx,cy,w,h ter-normalisasi -> piksel + filter conf', () {
      final dets = decodeDetections(
        output([
          [0.5, 0.5, 0.5, 0.2, 0.9], // box [25,40,75,60] conf 0.9
          [0.5, 0.5, 0.5, 0.2, 0.2], // di bawah ambang -> dibuang
        ]),
        input(),
      );
      expect(dets, hasLength(1));
      expect(dets.first.x1, closeTo(25, 1e-6));
      expect(dets.first.y1, closeTo(40, 1e-6));
      expect(dets.first.x2, closeTo(75, 1e-6));
      expect(dets.first.y2, closeTo(60, 1e-6));
      expect(dets.first.conf, closeTo(0.9, 1e-6));
    });

    test('NMS menyingkirkan duplikat IoU tinggi', () {
      final dets = decodeDetections(
        output([
          [0.5, 0.5, 0.5, 0.2, 0.9],
          [0.51, 0.51, 0.5, 0.2, 0.8], // tumpang-tindih besar
          [0.1, 0.1, 0.1, 0.1, 0.7], // jauh -> tetap
        ]),
        input(),
      );
      expect(dets, hasLength(2));
    });
  });

  group('buildDetectorInput (NCHW)', () {
    test('urutan channel-major + normalisasi', () {
      final rgb = Uint8List.fromList([
        10, 20, 30, 40, 50, 60, // baris 0
        70, 80, 90, 100, 110, 120, // baris 1
      ]);
      final frame = DecodedFrame(width: 2, height: 2, rgb: rgb);
      final di = buildDetectorInput(frame, inputSize: 2);

      expect(di.scale, 1.0);
      expect(di.padX, 0);
      expect(di.padY, 0);
      // NCHW: c=0 (R) didahulukan
      expect(di.tensor[0], closeTo(10 / 255.0, 1e-6));
      expect(di.tensor[1], closeTo(40 / 255.0, 1e-6));
      expect(di.tensor[2], closeTo(70 / 255.0, 1e-6));
      expect(di.tensor[3], closeTo(100 / 255.0, 1e-6));
      // c=1 (G) di offset n = 4
      expect(di.tensor[4], closeTo(20 / 255.0, 1e-6));
      expect(di.tensor[5], closeTo(50 / 255.0, 1e-6));
      // c=2 (B) di offset 2n = 8
      expect(di.tensor[8], closeTo(30 / 255.0, 1e-6));
    });
  });

  group('cropToGray (BT.601)', () {
    test('konversi grayscale identik BGR2GRAY', () {
      final rgb = Uint8List.fromList([
        255, 0, 0, // merah -> gray 76
        0, 0, 0, // hitam -> gray 0
        255, 255, 255, // putih -> gray 255
      ]);
      final frame = DecodedFrame(width: 3, height: 1, rgb: rgb);
      const det = PlateDetection(
        x1: 0,
        y1: 0,
        x2: 3,
        y2: 1,
        conf: 1.0,
      );
      final crop = cropToGray(frame, det);
      expect(crop.data[0], 76);
      expect(crop.data[1], 0);
      expect(crop.data[2], 255);
    });
  });

  group('clahe (port OpenCV)', () {
    test('output identik cv2.CLAHE(2.0, 8x8) pada ramp 16x16', () {
      // Input: (x*3 + y*7) % 256
      final src = Uint8List(16 * 16);
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 16; x++) {
          src[y * 16 + x] = (x * 3 + y * 7) % 256;
        }
      }
      final out = clahe(src, 16, 16);

      expect(out.length, 16 * 16);
      expect(out[0], 64); // TL
      expect(out[15], 128); // TR
      expect(out[15 * 16], 191); // BL
      expect(out[15 * 16 + 15], 255); // BR
      expect(out[8 * 16 + 8], 176); // center
      expect(out.fold<int>(0, (s, v) => s + v), 52592);
    });
  });
}