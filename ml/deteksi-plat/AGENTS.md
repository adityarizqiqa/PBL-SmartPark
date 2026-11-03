# Repository Guidelines

## Project Overview
This repository contains the Machine Learning (ML) engineering pipeline for an on-device **Automatic License Plate Recognition (ALPR)** system targeting Indonesian vehicle plates. The final models deploy to mobile applications (Flutter via `tflite_flutter`) under strict size ($\le 10\text{ MB}$ total) and latency ($\le 70\text{ ms}$ on mobile GPU/NPU, $\le 250\text{ ms}$ on mobile CPU) constraints.

The system uses a decoupled **2-Stage Cascade Pipeline**:
1. **Plate Detector (YOLOv8n)**: Detects plate bounding boxes on full camera frames.
2. **Crop & Normalization Bridge**: Expands bounding boxes adaptively (+5% to 15%) and standardizes them to Grayscale $32 \times 128$.
3. **Plate Recognizer (CNN-2D + TCN + CTC)**: Transcribes characters using a pure convolutional architecture (free of RNN/LSTM ops to guarantee native TFLite compatibility without TensorFlow FlexDelegate).
4. **Post-Processing Engine**: CTC greedy decoding, positional heuristic mapping, and Indonesian regex validation (`^[A-Z]{1,2}[0-9]{1,4}[A-Z]{1,3}$`).

---

## Architecture & Data Flow

```text
[Input Image (Full Frame)]
       │
       ▼ (RGB 640x640x3, Float32 [0.0, 1.0])   # ⚠️ keputusan terbuka: 640 vs 1280, lihat plan/README.md §3
┌────────────────────────────────────────────────────────┐
│ Stage 1: Ultralytics YOLOv8n Detector                  │
│ Output: Raw Tensor [1, 5, 8400]                        │
│ Client-side Standalone NMS (conf >= 0.40, IoU 0.45)    │
│ Bounding Box: [x1, y1, x2, y2]                         │
└────────────────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ Bridge: Adaptive Crop & Preprocessor                   │
│ - Adaptive margin expansion (+5% to 15%)               │
│ - Grayscale conversion + aspect-ratio preserving scale │
│ - Right/bottom zero-padding to fixed [1, 32, 128, 1]   │
└────────────────────────────────────────────────────────┘
       │
       ▼ (Grayscale 32x128x1, Float32 [0.0, 1.0])
┌────────────────────────────────────────────────────────┐
│ Stage 2: Recurrent-Free OCR (CNN-2D + TCN)             │
│ - CNN-2D: 4 Conv-BN-ReLU-MaxPool blocks                │
│   Asymmetric pooling: (32, 128) -> (1, 32)             │
│ - Sequence Modeler: 3-layer Dilated Conv-1D (d=1, 2, 4)│
│ - CTC Head: Linear projection (256 -> 37 logits)       │
│ Output Logits: [1, 32, 37]                             │
└────────────────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ Post-Processing & Formatting                           │
│ - CTC Greedy Decoder (blank index = 0)                 │
│ - Positional Heuristics:                               │
│     * Front letters (1-2 chars): 0->O, 1->I, 8->B      │
│     * Middle digits (1-4 chars): O/D->0, I->1, B->8    │
│     * Rear letters (1-3 chars): digits -> letters      │
│ - Regex Validation: ^[A-Z]{1,2}[0-9]{1,4}[A-Z]{1,3}$   │
└────────────────────────────────────────────────────────┘
       │
       ▼
Verified Plate String + Combined Confidence Score
```

---

## Key Directories

```text
ml/
├── plan/                          # Master plan and phase specification documents
│   ├── README.md                  # System overview, pipeline contracts, and phase matrix
│   ├── fase-1-eda-audit.md        # EDA & cross-dataset leakage prevention audit
│   ├── fase-2-prep-dataset-detector.md  # COCO-to-YOLO conversion & split configuration
│   ├── fase-3-training-eval-detector.md # YOLOv8n detector training & Recall-first eval
│   ├── fase-4-prep-dataset-ocr.md # Clean + simulated imperfect crop dataset generation
│   ├── fase-5-training-ocr-recognizer.md # Pure-conv OCR (CNN-TCN-CTC) model training
│   ├── fase-6-evaluasi-ocr-multitier.md  # 3-Tier OCR evaluation & confusion matrix
│   ├── fase-7-evaluasi-cascade-e2e.md   # Full-frame cascade simulation & bottleneck analysis
│   └── fase-8-export-tflite-deployment.md# FP16 quantization, parity checks & Flutter bundle
├── fase1_eda_audit/               # Phase 1 Kaggle execution workspace (EDA)
│   ├── indonesian-plate-eda-and-audit.ipynb # Phase 1 EDA & audit notebook
│   ├── kernel-metadata.json       # Kaggle kernel configuration & dataset linkages
│   └── output/                    # Downloaded audit artifacts & execution logs
│       ├── data_audit_summary.json# Audited dataset metrics
│       ├── char_distribution.png  # Character frequency plot
│       └── sample_detection_boxes.png
├── fase1_label_audit/             # Phase 1 label-quality audit (bounding box)
│   └── detection-indonesian-plate-label-audit.ipynb
├── fase2_prep_detector/           # Phase 2 COCO-to-YOLO prep & group split
│   ├── detection-indonesian-plate-prep-detector.ipynb
│   ├── kernel-metadata.json
│   └── tmp/                       # Local scratch: annotations.json + CCTV metadata
├── fase3_train_detector/          # Phase 3 YOLOv8n training & evaluation
│   ├── detection-indonesian-plate-train-detector.ipynb
│   ├── kernel-metadata.json
│   └── output/                    # Downloaded weights, metrics, run artifacts
├── .nbgen/                        # Notebook build tooling (source .py -> .ipynb)
│   ├── build.py                   # Converter: cell markers -> nbformat JSON
│   ├── rename.py                  # Adds the `detection-` slug prefix
│   └── f1.py, f2.py, f3.py        # Editable notebook sources
└── [faseX_...]/                   # Subsequent phase workspaces (created per phase)
```

### Kaggle kernel naming

Track 1 (detector) notebooks carry the slug prefix `detection-`; Track 2 (OCR) notebooks
will use `recognition-`. The slug is always the title lowercased with dashes, so the
`title` and `id` fields in `kernel-metadata.json` must be changed together.

| Notebook | Slug |
| :--- | :--- |
| EDA & audit (Fase 1) | `indonesian-plate-eda-and-audit` |
| Label audit (Fase 1) | `detection-indonesian-plate-label-audit` |
| Prep detector (Fase 2) | `detection-indonesian-plate-prep-detector` |
| Train detector (Fase 3) | `detection-indonesian-plate-train-detector` |

Rename is done in place: change `title` and `code_file`, push once, then update `id`.
Version history and the numeric kernel id are preserved.


---

## Development Commands

All heavy compute and training workloads run on Kaggle environments via the official Kaggle CLI.

### Kaggle CLI Operations
```bash
# Push notebook and trigger remote execution
cd fase1_eda_audit
kaggle kernels push -p .

# Monitor execution status (COMPLETE, RUNNING, ERROR)
kaggle kernels status singgihwahyupermana/indonesian-plate-eda-and-audit

# Download execution artifacts and logs
kaggle kernels output singgihwahyupermana/indonesian-plate-eda-and-audit -p output/
```

### Local Inspections & Verification
```bash
# Verify integrity of plan documentation links
cd plan
for link in $(grep -o 'fase-[0-9a-z-]*\.md' README.md); do [ -f "$link" ] && echo "[OK] $link" || echo "[MISSING] $link"; done

# View audited dataset metrics
cat fase1_eda_audit/output/data_audit_summary.json
```

---

## Code Conventions & Common Patterns

### 1. Robust Type Casting for COCO Datasets
COCO annotations in public datasets frequently store image dimensions or coordinates as strings (e.g., `"width": "1280"`). Always cast explicitly to floats:
```python
W = float(img['width'])
H = float(img['height'])
x, y, w, h = [float(v) for v in ann['bbox']]
```

### 2. Dynamic Path Resolution in Kaggle Kernels
Datasets under `/kaggle/input/` can change internal nesting structures. Avoid hardcoded paths; use recursive pattern matching:
```python
import glob, os

ann_files = glob.glob("/kaggle/input/**/annotations.json", recursive=True)
csv_files = glob.glob("/kaggle/input/**/label.csv", recursive=True)
det_json_path = ann_files[0]
det_img_dir = os.path.join(os.path.dirname(os.path.dirname(det_json_path)), "images")
```

### 3. Shared OCR Preprocessing Logic
To prevent train-inference skew, training pipelines and production mobile runtimes must use an identical preprocessing sequence:
```python
def preprocess_crop_for_ocr(crop_bgr, target_h=32, target_w=128):
    gray = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape[:2]
    scale = min(target_h / h, target_w / w)
    nw, nh = int(w * scale), int(h * scale)
    resized = cv2.resize(gray, (nw, nh), interpolation=cv2.INTER_AREA)
    
    # Zero-padding (right and bottom) to standard 32x128
    padded = np.zeros((target_h, target_w), dtype=np.float32)
    padded[:nh, :nw] = resized / 255.0
    return padded[np.newaxis, ..., np.newaxis]  # Shape: [1, 32, 128, 1]
```

### 4. Asymmetric Vertical-Heavy Pooling for OCR
To achieve $T=32$ temporal steps from an input width of $128$ without RNN layers, reduce height completely while pooling width only twice:
```text
Input:       (B, 1, 32, 128)
Block 1:     Conv2D -> MaxPool2D(2, 2)     -> (B, 64, 16, 64)
Block 2:     Conv2D -> MaxPool2D(2, 2)     -> (B, 128, 8, 32)
Block 3:     Conv2D -> MaxPool2D((2, 1))   -> (B, 256, 4, 32)
Block 4:     Conv2D -> MaxPool2D((4, 1))   -> (B, 256, 1, 32)
Reshape:     Squeeze height dimension      -> (B, T=32, D=256)
```

### 5. Vocabulary & Token Order
- Total tokens: `37`
- Index `0`: `CTC Blank` (required by `torch.nn.CTCLoss(blank=0)`)
- Indices `1–10`: Digits `'0'` through `'9'`
- Indices `11–36`: Uppercase letters `'A'` through `'Z'`

---

## Important Files

| File Path | Description |
|---|---|
| `plan/README.md` | Master architecture overview, data contracts, and performance gates |
| `fase1_eda_audit/kernel-metadata.json` | Kaggle kernel definition linking `linkgish/indonesian-plate-number-from-multi-sources` |
| `fase1_eda_audit/indonesian-plate-eda-and-audit.ipynb` | Executed Phase 1 exploratory data analysis notebook |
| `fase1_eda_audit/output/data_audit_summary.json` | Baseline metrics: 1,377 images, 2,128 BBoxes, 5 negatives, 1,863 OCR rows |
| `plan/fase-3-training-eval-detector.md` | Training specifications and Recall prioritization for YOLOv8n |
| `plan/fase-5-training-ocr-recognizer.md` | Full network architecture for recurrent-free CNN-2D + TCN OCR |
| `plan/fase-8-export-tflite-deployment.md` | Standalone NMS, FP16 TFLite quantization, and mobile handover spec |

---

## Runtime & Tooling Preferences

- **Development Environment**: Kaggle Notebooks (Python 3.10+ / 3.12).
  - CPU instances for EDA and dataset preprocessing (Fases 1, 2, 4).
  - GPU instances (T4 / P100) for YOLO and OCR training (Fases 3, 5).
- **Core ML Frameworks**:
  - `ultralytics` (YOLOv8n training and TFLite export)
  - `torch` & `torchvision` (custom OCR model definition and CTCLoss)
  - `opencv-python` & `Pillow` (image reading, bounding box manipulation, color conversions)
  - `numpy` & `pandas` (manifest management and coordinate transforms)
- **Deployment Runtime**:
  - Flutter Mobile Target (`tflite_flutter`)
  - Standalone `tflite_runtime` (Python testing without full TensorFlow or PyTorch dependencies)
  - **Forbidden**: Custom C++ ops or TensorFlow FlexDelegate (keeps binary small and prevents app crashes).

---

## Testing & QA

Testing follows a decoupled multi-tier evaluation framework across all phases:

### 1. Detector Metrics (YOLOv8n)
- **Primary Optimization**: **Recall@0.50** is prioritized over Precision. Missed plates prevent OCR invocation entirely.
- **Acceptance Thresholds**:
  - Validation: $\text{Recall@0.50} \ge 90\%$, $\text{mAP@50} \ge 0.88$
  - Test Set: $\text{Recall@0.50} \ge 92\%$, $\text{mAP@50} \ge 0.88$

### 2. Multi-Tier OCR Evaluation
To isolate localization degradation from character recognition capability, OCR is tested under three separate conditions on the test set:
- **Tier 1 (Oracle GT Crops)**: Evaluated on clean manual bounding box crops. Measures upper-bound recognition performance. Target: $\text{Exact Match (EM)} \ge 85\%$, $\text{CER} \le 0.06$.
- **Tier 2 (Simulated Imperfect Crops)**: Evaluated on crops with 3–12% coordinate shift, asymmetric margin padding, and slight blur. Target: EM degradation $\le 7\%$ relative to Tier 1.
- **Tier 3 (Predicted Detector Crops)**: Evaluated on crops produced directly by the trained detector. Target: $\text{EM} \ge 78\%$, $\text{CER} \le 0.08$.

### 3. End-to-End Cascade Accuracy
Measured over the full population of full-frame test images:
$$A_{e2e} = \frac{\text{Images with correct plate detection AND 100\% character transcription}}{\text{Total full-frame test images}} = R_{det} \times R_{ocr|det}$$
- **Target**: $A_{e2e} \ge 75\%$ on the test set.

### 4. TFLite Parity & Deployment Checks
- **Numerical Parity**: Max absolute difference in OCR logits between PyTorch FP32 and TFLite FP16 must be $< 10^{-2}$; Exact Match drop $< 1\%$.
- **Model Sizes**: `plate_detector_fp16.tflite` $\le 6\text{ MB}$, `plate_ocr_fp16.tflite` $\le 3\text{ MB}$ (Total $\le 9\text{ MB}$).
