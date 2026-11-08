import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'plate_pipeline.dart';

/// Pemuat + runner dua model TFLite untuk ALPR on-device.
///
/// Detektor YOLOv8n dan OCR CNN-TCN dimuat sekali (singleton) lalu dipakai
/// untuk frame berikutnya. Gunakan `recognize` untuk memproses foto JPEG/PNG
/// mentah menjadi teks plat.
class PlateRecognizer {
  PlateRecognizer({
    this.detectorAsset = 'assets/ml/plate_detector.tflite',
    this.ocrAsset = 'assets/ml/plate_ocr.tflite',
  });

  final String detectorAsset;
  final String ocrAsset;

  Interpreter? _detector;
  Interpreter? _ocr;
  final _detectorOut = Float32List(5 * kDetectorAnchors);
  final _ocrOut = Float32List(kOcrTimesteps * kOcrVocab);

  Future<void> ensureLoaded() async {
    _detector ??= await Interpreter.fromAsset(detectorAsset);
    _ocr ??= await Interpreter.fromAsset(ocrAsset);
  }

  void close() {
    _detector?.close();
    _ocr?.close();
    _detector = null;
    _ocr = null;
  }

  /// Deteksi + crop + OCR untuk satu gambar. Kembalikan plat terbaik (belum
  /// difilter format — pemanggil memutuskan validitas lewat [PlateRecognition.validFormat]).
  Future<PlateRecognition?> recognize(Uint8List imageBytes) async {
    await ensureLoaded();
    final detector = _detector;
    final ocr = _ocr;
    if (detector == null || ocr == null) return null;

    final frame = decodeFrame(imageBytes);
    if (frame == null) return null;

    final input = buildDetectorInput(frame);
    detector.run(_asBytes(input.tensor), _detectorOut.buffer);
    final detections = decodeDetections(_detectorOut, input);

    PlateRecognition? best;
    var bestScore = -1.0;
    for (final det in detections) {
      final crop = cropToGray(frame, det);
      if (crop.width <= 0 || crop.height <= 0) continue;

      final ocrInput = buildOcrInput(crop);
      ocr.run(_asBytes(ocrInput), _ocrOut.buffer);

      final text = ctcGreedyDecode(_ocrOut);
      if (text.isEmpty) continue;

      final confidence = softmaxConfidence(_ocrOut);
      final valid = isValidPlate(text);
      final score = det.conf * confidence;
      if (score > bestScore) {
        bestScore = score;
        best = PlateRecognition(
          text: text,
          confidence: confidence,
          validFormat: valid,
          box: [
            det.x1.round(),
            det.y1.round(),
            det.x2.round(),
            det.y2.round(),
          ],
          detConf: det.conf,
        );
      }
    }
    return best;
  }

  static Uint8List _asBytes(Float32List tensor) =>
      tensor.buffer.asUint8List(tensor.offsetInBytes, tensor.lengthInBytes);
}