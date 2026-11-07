# Panduan Integrasi OCR TFLite dengan Flutter

Dokumen ini untuk anggota tim yang menangani **aplikasi mobile Flutter**. Tujuannya: mengintegrasikan model OCR TFLite dengan detektor YOLO TFLite yang sudah ada.

---

## 1. Model yang Dibutuhkan

| File | Ukuran | Keterangan |
|---|---|---|
| `checkpoints/ocr_model_fp16.tflite` | **1,11 MB** | Model OCR utama (FP16) |
| `checkpoints/ocr_model_fp32.tflite` | 2,08 MB | Alternatif FP32 (jika FP16 bermasalah) |

---

## 2. Kontrak Input/Output

| Interface | Spek |
|---|---|
| **Input** | `[1, 48, 192, 1]` float32 — grayscale, normalisasi `[0.0, 1.0]` |
| **Output** | `[1, 48, 37]` float32 — logits per token (CTC) |
| **Vocab** | 37 token: `<blank>`=0, `0-9`=1–10, `A-Z`=11–36 |
| **CTC decode** | Greedy: argmax per timestep → collapse repeats → drop blank |

---

## 3. Dependencies (Flutter)

Tambah ke `pubspec.yaml`:

```yaml
dependencies:
  tflite_flutter: ^0.11.0
```

---

## 4. Preprocessing di Dart

Model mengharapkan **grayscale 48×192 float32 [0,1]**:

```dart
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Crop BGR/RGB (Uint8List) → tensor input [1, 48, 192, 1] float32 [0,1]
Uint8List preprocessOcrCrop(Uint8List cropRgba, int cropWidth, int cropHeight) {
  // 1. Convert ke grayscale
  final img = img.Image.fromBytes(
    width: cropWidth, height: cropHeight,
    bytes: cropRgba.buffer, numChannels: 4,
  );
  final gray = img.convert(numChannels: 1);

  // 2. Auto-crop baris pajak (aspect ratio < 1.8)
  final ar = cropWidth / cropHeight;
  var processed = gray;
  if (ar < 1.8) {
    final cropH = (gray.height * 0.68).toInt();
    processed = img.copyCrop(gray, x: 0, y: 0, width: gray.width, height: cropH);
  }

  // 3. CLAHE (opsional — hasil sama dengan training; skip jika sulit)
  // processed = applyClahe(processed);

  // 4. Resize ke 48×192
  final resized = img.copyResize(processed, width: 192, height: 48);

  // 5. Normalisasi [0,1]
  final data = Float32List(48 * 192);
  for (int i = 0; i < data.length; i++) {
    data[i] = resized.data![i] / 255.0;
  }
  return data.buffer.asUint8List();
}
```

---

## 5. CTC Greedy Decode di Dart

```dart
const vocab = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const blankIndex = 0;

/// logits: Float32List panjang 48 * 37 (row-major: [t][c])
String ctcGreedyDecode(Float32List logits, int timesteps, int vocabSize) {
  final chars = <String>[];
  int? prev;
  for (int t = 0; t < timesteps; t++) {
    // argmax per timestep
    int bestIdx = 0;
    double bestVal = logits[t * vocabSize];
    for (int c = 1; c < vocabSize; c++) {
      final v = logits[t * vocabSize + c];
      if (v > bestVal) { bestVal = v; bestIdx = c; }
    }
    // collapse repeats + drop blanks
    if (bestIdx != prev && bestIdx != blankIndex) {
      // vocab index 1 = '0', 2 = '1', ... 11 = 'A', ... 36 = 'Z'
      chars.add(vocabChar(bestIdx));
    }
    prev = bestIdx;
  }
  return chars.join('');
}

String vocabChar(int index) {
  // index 1-10 = digits 0-9, index 11-36 = A-Z
  if (index >= 1 && index <= 10) return String.fromCharCode(0x30 + index - 1);
  if (index >= 11 && index <= 36) return String.fromCharCode(0x41 + index - 11);
  return '';
}
```

---

## 6. Confidence Score

```dart
/// Rata-rata probabilitas token (maksudnya: softmax logit)
double confidenceScore(Float32List logits, int timesteps, int vocabSize) {
  double total = 0;
  int count = 0;
  for (int t = 0; t < timesteps; t++) {
    double maxVal = 0, sum = 0;
    for (int c = 0; c < vocabSize; c++) {
      final v = logits[t * vocabSize + c];
      if (v > maxVal) maxVal = v;
      sum += v;
    }
    total += maxVal / sum;  // softmax approximation
    count++;
  }
  return count > 0 ? total / count : 0;
}
```

---

## 7. Validasi Format Plat Indonesia

```dart
final plateRegex = RegExp(r'^[A-Z]{1,2}[0-9]{1,4}[A-Z]{1,3}$');

bool isValidPlate(String plate) => plateRegex.hasMatch(plate);
```

---

## 8. Integrasi Lengkap dengan YOLO

```dart
import 'package:tflite_flutter/tflite_flutter.dart';

late Interpreter ocrInterpreter;
late Interpreter detectorInterpreter;

// Startup (sekali)
Future<void> loadModels() async {
  detectorInterpreter = await Interpreter.fromAsset('plate_detector.tflite');
  ocrInterpreter = await Interpreter.fromAsset('ocr_model_fp16.tflite');
}

// Per frame
Future<List<PlateResult>> readPlates(Uint8List frameRgba) async {
  // 1. YOLO detect (gunakan NMS di Dart)
  final detections = runYoloDetect(detectorInterpreter, frameRgba);

  // 2. Crop + OCR per bbox
  final results = <PlateResult>[];
  for (final det in detections) {
    final crop = cropWithPadding(frameRgba, det.bbox, padRatio: 0.08);
    final input = preprocessOcrCrop(crop);
    final logits = runOcrInference(ocrInterpreter, input);
    final text = ctcGreedyDecode(logits, 48, 37);
    if (isValidPlate(text)) {
      results.add(PlateResult(
        text: text,
        detConf: det.conf,
        box: det.bbox,
      ));
    }
  }
  return results;
}
```

---

## 9. Kesalahan Umum

| Gejala | Penyebab | Solusi |
|---|---|---|
| `text` kosong / singkat | crop bukan plat / terlalu kecil | cek bbox YOLO, naikkan confidence |
| Karakter tepi hilang | tanpa padding | pastikan padding 8% sebelum crop |
| Confidence tinggi tapi salah | plat blur / karakter mirip | aktifkan `valid_format` + manual review |
| Model lambat | model dimuat per request | pindahkan load ke startup |
| Shape mismatch | input bukan `[1,48,192,1]` | pastikan preprocessing grayscale 1 channel |

---

## 10. Checklist Go-Live

- [ ] Checkpoint `ocr_model_fp16.tflite` tersedia di `assets/`
- [ ] TFLite interpreter loaded di startup (bukan per request)
- [ ] Preprocessing Dart identik dengan training (grayscale, 48×192, [0,1])
- [ ] CTC greedy decode benar (collapse + drop blank)
- [ ] `valid_format` regex diaktifkan
- [ ] `confidence` score digunakan untuk gating
- [ ] Uji pada ≥50 foto kamera nyata dengan label ground truth
- [ ] Latency diukur pada perangkat target
