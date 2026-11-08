import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Alur angka-ajaib untuk pipeline ALPR dua-tahap:
/// deteksi plat (YOLOv8n tflite) -> crop -> OCR (CNN-TCN tflite).
///
/// File ini murni (tanpa `tflite_flutter`/`dart:ui`) agar logika matriks dan
/// decoding bisa diuji di host. Nilai kontrak diverifikasi terhadap model asli:
/// - Detektor : input NCHW [1,3,1280,1280] float32 [0,1]; output [1,5,33600]
///   dengan `[cx,cy,w,h,conf]` TER-NORMALISASI [0,1].
/// - OCR      : input [1,48,192,1] float32 grayscale [0,1]; output [1,48,37]
///   logits CTC (vocab blank=0, 0-9=1..10, A-Z=11..36).
const int kDetectorInputSize = 1280;
const int kDetectorAnchors = 33600; // 3 stride YOLOv8n @1280: 160^2+80^2+40^2
const double kDetectorConfThresh = 0.40;
const double kDetectorNmsIou = 0.45;
const double kCropPadRatio = 0.08;
const int kOcrHeight = 48;
const int kOcrWidth = 192;
const int kOcrTimesteps = 48;
const int kOcrVocab = 37;
const int kOcrBlank = 0;

final RegExp _plateRegex = RegExp(r'^[A-Z]{1,2}[0-9]{1,4}[A-Z]{1,3}$');

/// Satu bbox plat dalam koordinat piksel gambar asli.
class PlateDetection {
  const PlateDetection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.conf,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double conf;

  double get width => x2 - x1;
  double get height => y2 - y1;
}

/// Hasil akhir OCR satu plat.
class PlateRecognition {
  const PlateRecognition({
    required this.text,
    required this.confidence,
    required this.validFormat,
    required this.box,
    required this.detConf,
  });

  final String text;
  final double confidence;
  final bool validFormat;

  /// [x1, y1, x2, y2] dalam piksel gambar asli.
  final List<int> box;
  final double detConf;
}

/// Frame RGB hasil decode (EXIF sudah dibenamkan) + metadata dimensi.
class DecodedFrame {
  const DecodedFrame({
    required this.width,
    required this.height,
    required this.rgb,
  });

  final int width;
  final int height;

  /// Flat RGB, panjang `width * height * 3`.
  final Uint8List rgb;
}

/// Tensor input detektor + parameter letterbox untuk memetakan balik bbox.
class DetectorInput {
  const DetectorInput({
    required this.tensor,
    required this.scale,
    required this.padX,
    required this.padY,
    required this.inputSize,
  });

  /// NCHW [1,3,inputSize,inputSize] float32 [0,1].
  final Float32List tensor;
  final double scale;
  final double padX;
  final double padY;
  final int inputSize;
}

/// Crop grayscale hasil pemotongan bbox.
class GrayCrop {
  const GrayCrop({required this.width, required this.height, required this.data});

  final int width;
  final int height;
  final Uint8List data;
}

/// Decode JPEG/PNG -> RGB, dengan orientasi EXIF dibenamkan agar OCR tidak
/// menerima gambar miring 90°.
DecodedFrame? decodeFrame(Uint8List imageBytes) {
  final decoded = img.decodeJpg(imageBytes) ?? img.decodeImage(imageBytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final rgb = upright.getBytes(order: img.ChannelOrder.rgb);
  return DecodedFrame(
    width: upright.width,
    height: upright.height,
    rgb: rgb,
  );
}

/// Letterbox frame ke 1280x1280 (rasio dipertahankan, pad abu-abu 114) lalu
/// buat tensor NCHW float32 [0,1] untuk detektor.
DetectorInput buildDetectorInput(
  DecodedFrame frame, {
  int inputSize = kDetectorInputSize,
}) {
  final w = frame.width;
  final h = frame.height;
  final scale = inputSize / math.max(w, h);
  final nw = (w * scale).round();
  final nh = (h * scale).round();

  Uint8List rgb;
  if (nw == w && nh == h) {
    rgb = frame.rgb;
  } else {
    final wrapped = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: frame.rgb.buffer,
      numChannels: 3,
      order: img.ChannelOrder.rgb,
    );
    final resized = img.copyResize(
      wrapped,
      width: nw,
      height: nh,
      interpolation: img.Interpolation.linear,
    );
    rgb = resized.getBytes(order: img.ChannelOrder.rgb);
  }

  final n = inputSize * inputSize;
  final padX = (inputSize - nw) ~/ 2;
  final padY = (inputSize - nh) ~/ 2;
  final tensor = Float32List(3 * n);
  const padVal = 114.0 / 255.0;

  for (var c = 0; c < 3; c++) {
    final chan = c * n;
    for (var y = 0; y < inputSize; y++) {
      final row = chan + y * inputSize;
      for (var x = 0; x < inputSize; x++) {
        tensor[row + x] = padVal;
      }
    }
  }

  for (var ry = 0; ry < nh; ry++) {
    for (var rx = 0; rx < nw; rx++) {
      final si = (ry * nw + rx) * 3;
      final dy = padY + ry;
      final dx = padX + rx;
      tensor[dy * inputSize + dx] = rgb[si] / 255.0;
      tensor[n + dy * inputSize + dx] = rgb[si + 1] / 255.0;
      tensor[2 * n + dy * inputSize + dx] = rgb[si + 2] / 255.0;
    }
  }

  return DetectorInput(
    tensor: tensor,
    scale: scale,
    padX: padX.toDouble(),
    padY: padY.toDouble(),
    inputSize: inputSize,
  );
}

/// Decode output detektor [1,5,33600] -> bbox piksel asli + NMS.
List<PlateDetection> decodeDetections(
  Float32List output,
  DetectorInput input, {
  double confThresh = kDetectorConfThresh,
  double iouThresh = kDetectorNmsIou,
}) {
  final n = output.length ~/ 5;
  final candidates = <PlateDetection>[];

  for (var i = 0; i < n; i++) {
    final conf = output[4 * n + i];
    if (conf < confThresh) continue;

    final cx = output[i];
    final cy = output[n + i];
    final w = output[2 * n + i];
    final h = output[3 * n + i];

    final lx1 = (cx - w / 2.0) * input.inputSize;
    final ly1 = (cy - h / 2.0) * input.inputSize;
    final lx2 = (cx + w / 2.0) * input.inputSize;
    final ly2 = (cy + h / 2.0) * input.inputSize;

    candidates.add(PlateDetection(
      x1: (lx1 - input.padX) / input.scale,
      y1: (ly1 - input.padY) / input.scale,
      x2: (lx2 - input.padX) / input.scale,
      y2: (ly2 - input.padY) / input.scale,
      conf: conf,
    ));
  }

  return _nms(candidates, iouThresh);
}

/// Crop bbox + margin, lalu konversi ke grayscale BT.601 (sama dengan
/// `cv2.COLOR_BGR2GRAY` yang dipakai training).
GrayCrop cropToGray(DecodedFrame frame, PlateDetection det) {
  final w = frame.width;
  final h = frame.height;
  final bw = det.width;
  final bh = det.height;
  final dx = bw * kCropPadRatio;
  final dy = bh * kCropPadRatio;

  final x1 = math.max(0, ((det.x1 - dx).floor())).toInt();
  final y1 = math.max(0, ((det.y1 - dy).floor())).toInt();
  final x2 = math.min(w, ((det.x2 + dx).ceil())).toInt();
  final y2 = math.min(h, ((det.y2 + dy).ceil())).toInt();

  final cw = x2 - x1;
  final ch = y2 - y1;
  if (cw <= 0 || ch <= 0) {
    return GrayCrop(width: 0, height: 0, data: Uint8List(0));
  }

  final rgb = frame.rgb;
  final gray = Uint8List(cw * ch);
  for (var yy = 0; yy < ch; yy++) {
    final srcRow = (y1 + yy) * w + x1;
    final dstRow = yy * cw;
    for (var xx = 0; xx < cw; xx++) {
      final si = (srcRow + xx) * 3;
      final r = rgb[si];
      final g = rgb[si + 1];
      final b = rgb[si + 2];
      // 299/587/114 + pembulatan, identik dengan BGR2GRAY OpenCV.
      gray[dstRow + xx] = ((r * 299 + g * 587 + b * 114 + 500) ~/ 1000);
    }
  }
  return GrayCrop(width: cw, height: ch, data: gray);
}

/// Preprocessing OCR identik training:
/// grayscale -> crop baris pajak (ar<1.8) -> CLAHE(2.0,8x8) -> resize 192x48
/// -> normalisasi [0,1] -> tensor [1,48,192,1].
Float32List buildOcrInput(GrayCrop crop) {
  if (crop.width <= 0 || crop.height <= 0) {
    return Float32List(kOcrHeight * kOcrWidth);
  }

  var g = crop.data;
  var gw = crop.width;
  var gh = crop.height;

  final ar = gw / math.max(gh, 1);
  if (ar < 1.8) {
    final newH = (gh * 0.68).round();
    final cropped = Uint8List(newH * gw);
    cropped.setRange(0, newH * gw, g);
    g = cropped;
    gh = newH;
  }

  g = clahe(g, gw, gh);

  final wrapped = img.Image.fromBytes(
    width: gw,
    height: gh,
    bytes: g.buffer,
    numChannels: 1,
  );
  final interp = (gw >= kOcrWidth && gh >= kOcrHeight)
      ? img.Interpolation.average
      : img.Interpolation.cubic;
  final resized = img.copyResize(
    wrapped,
    width: kOcrWidth,
    height: kOcrHeight,
    interpolation: interp,
  );
  final resizedBytes = resized.getBytes();

  final tensor = Float32List(kOcrHeight * kOcrWidth);
  for (var i = 0; i < tensor.length; i++) {
    tensor[i] = resizedBytes[i] / 255.0;
  }
  return tensor;
}

/// CTC greedy decode: argmax per timestep -> collapse repeat -> drop blank.
String ctcGreedyDecode(Float32List logits) {
  final out = StringBuffer();
  var prev = -1;
  for (var t = 0; t < kOcrTimesteps; t++) {
    final base = t * kOcrVocab;
    var bestIdx = 0;
    var bestVal = logits[base];
    for (var c = 1; c < kOcrVocab; c++) {
      final v = logits[base + c];
      if (v > bestVal) {
        bestVal = v;
        bestIdx = c;
      }
    }
    if (bestIdx != prev && bestIdx != kOcrBlank) {
      out.write(_vocabChar(bestIdx));
    }
    prev = bestIdx;
  }
  return out.toString();
}

/// Confidence relatif: rata-rata proabilitas token (max softmax per timestep).
double softmaxConfidence(Float32List logits) {
  var total = 0.0;
  for (var t = 0; t < kOcrTimesteps; t++) {
    final base = t * kOcrVocab;
    var maxVal = logits[base];
    for (var c = 1; c < kOcrVocab; c++) {
      maxVal = math.max(maxVal, logits[base + c]);
    }
    var sumExp = 0.0;
    for (var c = 0; c < kOcrVocab; c++) {
      sumExp += math.exp(logits[base + c] - maxVal);
    }
    total += 1.0 / sumExp;
  }
  return total / kOcrTimesteps;
}

bool isValidPlate(String text) => _plateRegex.hasMatch(text);

String _vocabChar(int index) {
  if (index >= 1 && index <= 10) return String.fromCharCode(0x30 + index - 1);
  if (index >= 11 && index <= 36) return String.fromCharCode(0x41 + index - 11);
  return '';
}

List<PlateDetection> _nms(List<PlateDetection> dets, double iouThresh) {
  final sorted = List<PlateDetection>.from(dets)
    ..sort((a, b) => b.conf.compareTo(a.conf));
  final keep = <PlateDetection>[];
  while (sorted.isNotEmpty) {
    final best = sorted.removeAt(0);
    keep.add(best);
    sorted.removeWhere((d) => _iou(best, d) >= iouThresh);
  }
  return keep;
}

double _iou(PlateDetection a, PlateDetection b) {
  final ix1 = math.max(a.x1, b.x1);
  final iy1 = math.max(a.y1, b.y1);
  final ix2 = math.min(a.x2, b.x2);
  final iy2 = math.min(a.y2, b.y2);
  final iw = math.max(0.0, ix2 - ix1);
  final ih = math.max(0.0, iy2 - iy1);
  final inter = iw * ih;
  final areaA = a.width * a.height;
  final areaB = b.width * b.height;
  final union = areaA + areaB - inter;
  return union <= 0 ? 0.0 : inter / union;
}

/// CLAHE (clipLimit 2.0, tileGrid 8x8) — port dari algoritma OpenCV dengan
/// bilinear interpolation antar-LUT tile dan border reflect-101.
Uint8List clahe(
  Uint8List src,
  int width,
  int height, {
  int gridX = 8,
  int gridY = 8,
  double clipLimit = 2.0,
}) {
  const histSize = 256;
  // OpenCV hanya pad bila SALAH SATU dimensi tak habis dibagi grid; formula
  // pad-nya `grid - (size % grid)` (bukan modulo), sehingga dimensi yang
  // habis dibagi pun ikut ter-reflect satu kolom/baris ekstra. Ini quirk
  // OpenCV yang wajib direplikasi agar hasil identik dengan training.
  final divisible = (width % gridX == 0) && (height % gridY == 0);
  final padX = divisible ? 0 : (gridX - width % gridX);
  final padY = divisible ? 0 : (gridY - height % gridY);
  final paddedW = width + padX;
  final paddedH = height + padY;
  final padded = _reflectPad101(src, width, height, padX, padY);

  final tileW = paddedW ~/ gridX;
  final tileH = paddedH ~/ gridY;
  final tileArea = tileW * tileH;

  // OpenCV: static_cast<int>(clipLimit * tileArea / histSize), min 1.
  final clip = math.max(1, (clipLimit * tileArea / histSize).toInt());

  final luts = <Uint8List>[];
  for (var ty = 0; ty < gridY; ty++) {
    for (var tx = 0; tx < gridX; tx++) {
      final hist = Int32List(histSize);
      final ox = tx * tileW;
      final oy = ty * tileH;
      for (var yy = 0; yy < tileH; yy++) {
        final rowBase = (oy + yy) * paddedW + ox;
        for (var xx = 0; xx < tileW; xx++) {
          hist[padded[rowBase + xx]]++;
        }
      }
      _clipHistogram(hist, clip);

      final lut = Uint8List(histSize);
      var cum = 0;
      for (var i = 0; i < histSize; i++) {
        cum += hist[i];
        lut[i] = ((cum * 255.0 / tileArea)).round().clamp(0, 255).toInt();
      }
      luts.add(lut);
    }
  }

  final out = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    final tyf = y / tileH - 0.5;
    final ty1 = tyf.floor();
    final ty2 = ty1 + 1;
    final ya = tyf - ty1;
    final t1y = _clampTile(ty1, gridY);
    final t2y = _clampTile(ty2, gridY);

    for (var x = 0; x < width; x++) {
      final txf = x / tileW - 0.5;
      final tx1 = txf.floor();
      final tx2 = tx1 + 1;
      final xa = txf - tx1;
      final t1x = _clampTile(tx1, gridX);
      final t2x = _clampTile(tx2, gridX);

      final pixel = src[y * width + x];
      final v1 = luts[t1y * gridX + t1x][pixel]; // A=(ty1,tx1)
      final v2 = luts[t2y * gridX + t1x][pixel]; // C=(ty2,tx1)
      final v3 = luts[t1y * gridX + t2x][pixel]; // B=(ty1,tx2)
      final v4 = luts[t2y * gridX + t2x][pixel]; // D=(ty2,tx2)

      // OpenCV: (A*xa1 + B*xa)*ya1 + (C*xa1 + D*xa)*ya
      final res = v1 * (1 - xa) * (1 - ya) +
          v2 * (1 - xa) * ya +
          v3 * xa * (1 - ya) +
          v4 * xa * ya;
      out[y * width + x] = res.round().clamp(0, 255).toInt();
    }
  }
  return out;
}

void _clipHistogram(Int32List hist, int clipLimit) {
  var clipped = 0;
  for (var i = 0; i < hist.length; i++) {
    if (hist[i] > clipLimit) {
      clipped += hist[i] - clipLimit;
      hist[i] = clipLimit;
    }
  }
  final redistBatch = clipped ~/ hist.length;
  final residual = clipped - redistBatch * hist.length;
  for (var i = 0; i < hist.length; i++) {
    hist[i] += redistBatch;
  }
  if (residual != 0) {
    final residualStep = math.max(hist.length ~/ residual, 1);
    for (var i = 0, left = residual; i < hist.length && left > 0; i += residualStep, left--) {
      hist[i]++;
    }
  }
}

int _clampTile(int p, int n) => p < 0 ? 0 : (p >= n ? n - 1 : p);

int _reflectIndex(int p, int len) {
  if (p < 0) return -p;
  if (p >= len) return 2 * len - 2 - p;
  return p;
}

Uint8List _reflectPad101(Uint8List src, int w, int h, int padX, int padY) {
  if (padX == 0 && padY == 0) return src;
  final W = w + padX;
  final H = h + padY;
  final out = Uint8List(W * H);
  for (var y = 0; y < H; y++) {
    final sy = _reflectIndex(y, h);
    for (var x = 0; x < W; x++) {
      out[y * W + x] = src[_reflectIndex(x, w) + sy * w];
    }
  }
  return out;
}