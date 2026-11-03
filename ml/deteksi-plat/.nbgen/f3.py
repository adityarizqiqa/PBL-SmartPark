# %% [markdown]
# # Training dan Evaluasi Detektor Plat Nomor Kendaraan (YOLOv8n)
#
# Notebook ini melatih model deteksi objek YOLOv8n untuk mendeteksi plat nomor kendaraan Indonesia.
# Dataset menggunakan hasil preprocessing yang membagi citra CCTV dan citra jarak dekat ke dalam split train, val, dan test.
# Resolusi input diatur ke 1280 agar bounding box kecil (terutama dari tangkapan kamera CCTV) tetap dapat terdeteksi dengan baik.
# Setelah proses training selesai, evaluasi dilakukan secara menyeluruh mencakup metrik standar (Precision, Recall, mAP), analisis stratified per jenis kamera, serta visualisasi kasus kegagalan.

# %% [markdown]
# ## 1. Setup Environment dan Cek GPU

# %%
import os
import glob
import json
import shutil
import time

import numpy as np
import cv2
import yaml
import torch
import matplotlib.pyplot as plt

print(f"Versi PyTorch: {torch.__version__}")
gpu_available = torch.cuda.is_available()
device = 0 if gpu_available else 'cpu'

if gpu_available:
    print(f"GPU terdeteksi: {torch.cuda.get_device_name(0)}")
else:
    print("PERINGATAN: GPU tidak terdeteksi. Training akan berjalan di CPU dan memakan waktu sangat lama.")

# %% [markdown]
# ## 2. Konfigurasi Parameter Training

# %%
IMGSZ = 1280          # Resolusi input 1280x1280 untuk mempertahankan detail plat kecil
EPOCHS = 150          # Total epoch training
PATIENCE = 30         # Early stopping patience
BATCH = 8             # Batch size (disesuaikan dengan VRAM GPU T4 16GB)
MOSAIC = 0.5          # Probabilitas augmentasi mosaic (dimoderasi agar objek kecil tidak terlalu terdistorsi)
CLOSE_MOSAIC = 20     # Matikan mosaic di 20 epoch terakhir untuk stabilisasi loss
SCALE = 0.3           # Augmentasi skala
DEGREES = 5.0         # Augmentasi rotasi acak (+/- 5 derajat)
MULTI_SCALE = 0.25    # Variasi skala gambar saat training (imgsz * [0.75 - 1.25])
OP_CONF = 0.25        # Ambang batas confidence score untuk analisis evaluasi
SEED = 0

print("=== KONFIGURASI TRAINING ===")
print(f"Resolution : {IMGSZ}x{IMGSZ}")
print(f"Epochs     : {EPOCHS} (patience: {PATIENCE})")
print(f"Batch Size : {BATCH}")
print(f"Augmentasi : mosaic={MOSAIC}, scale={SCALE}, degrees={DEGREES}")

# %% [markdown]
# ## 3. Penyiapan Dataset

# %%
# Cari data.yaml dari hasil kernel preprocessing
yaml_candidates = glob.glob('/kaggle/input/**/data.yaml', recursive=True)
if not yaml_candidates:
    raise FileNotFoundError("data.yaml tidak ditemukan di /kaggle/input")

src_yaml = yaml_candidates[0]
dataset_dir = os.path.dirname(src_yaml)
print(f"Dataset sumber ditemukan di: {dataset_dir}")

# Cek metadata split jika tersedia
splits_meta_path = os.path.join(dataset_dir, 'detector_splits.json')
if os.path.exists(splits_meta_path):
    with open(splits_meta_path) as f:
        meta_info = json.load(f)
        print("Informasi split dataset:")
        print(f"  Jumlah data: {meta_info.get('counts', {})}")
        print(f"  Leakage check: {meta_info.get('leakage', {})}")

# Salin dataset ke /kaggle/working agar caching disk/RAM bekerja optimal saat training
work_dir = '/kaggle/working/dataset'
if os.path.isdir(work_dir):
    shutil.rmtree(work_dir)
shutil.copytree(dataset_dir, work_dir)
print(f"Dataset berhasil disalin ke direktori kerja lokal: {work_dir}")

# Buat file konfigurasi data.yaml yang mengarah ke path lokal
with open(os.path.join(dataset_dir, 'data.yaml')) as f:
    data_config = yaml.safe_load(f)

data_config['path'] = work_dir
data_config['train'] = 'images/train'
data_config['val'] = 'images/val'
data_config['test'] = 'images/test'

local_yaml_path = '/kaggle/working/plate_detector_data.yaml'
with open(local_yaml_path, 'w') as f:
    yaml.dump(data_config, f, sort_keys=False)

print("\nIsi konfigurasi YAML lokal:")
with open(local_yaml_path) as f:
    print(f.read())

# %% [markdown]
# ## 4. Inisialisasi Model YOLOv8n

# %%
!pip install -q ultralytics

from ultralytics import YOLO

# Load pre-trained weights YOLOv8 nano
model = YOLO('yolov8n.pt')

n_params = sum(p.numel() for p in model.model.parameters())
est_fp16_mb = (n_params * 2) / (1024 ** 2)

print(f"Arsitektur model : YOLOv8n")
print(f"Total parameter  : {n_params:,}")
print(f"Estimasi ukuran FP16: {est_fp16_mb:.2f} MB (Target mobile <= 6 MB)")

# %% [markdown]
# ## 5. Eksekusi Training (150 Epoch)

# %%
start_time = time.time()

training_results = model.train(
    data=local_yaml_path,
    epochs=EPOCHS,
    patience=PATIENCE,
    imgsz=IMGSZ,
    batch=BATCH,
    device=device,
    workers=4,
    cache=True,
    optimizer='auto',
    cos_lr=True,
    seed=SEED,
    fliplr=0.0,
    mosaic=MOSAIC,
    close_mosaic=CLOSE_MOSAIC,
    degrees=DEGREES,
    scale=SCALE,
    multi_scale=MULTI_SCALE,
    hsv_v=0.4,
    hsv_s=0.4,
    save=True,
    project='/kaggle/working/runs_detector',
    name='yolov8n_plate_detector',
    exist_ok=True
)

training_duration_hours = (time.time() - start_time) / 3600.0
print(f"\nTraining selesai dalam {training_duration_hours:.2f} jam.")

exp_dir = '/kaggle/working/runs_detector/yolov8n_plate_detector'
best_model_path = os.path.join(exp_dir, 'weights', 'best.pt')
print(f"Bobot terbaik disimpan di: {best_model_path}")

# %% [markdown]
# ## 6. Visualisasi Kurva Training dan Evaluasi

# %%
result_plots = ['results.png', 'BoxPR_curve.png', 'BoxF1_curve.png', 'confusion_matrix.png']

for plot_name in result_plots:
    plot_file = os.path.join(exp_dir, plot_name)
    if os.path.exists(plot_file):
        img_bgr = cv2.imread(plot_file)
        if img_bgr is not None:
            plt.figure(figsize=(12, 7))
            plt.imshow(cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB))
            plt.title(plot_name, fontsize=12)
            plt.axis('off')
            plt.show()

# %% [markdown]
# ## 7. Evaluasi pada Test Set

# %%
# Load model dengan bobot terbaik
best_model = YOLO(best_model_path)

val_results = best_model.val(data=local_yaml_path, split='test', imgsz=IMGSZ, device=device)
res_dict = val_results.results_dict

test_metrics = {
    'precision_50': round(float(res_dict.get('metrics/precision(B)', 0.0)), 4),
    'recall_50': round(float(res_dict.get('metrics/recall(B)', 0.0)), 4),
    'map_50': round(float(res_dict.get('metrics/mAP50(B)', 0.0)), 4),
    'map_50_95': round(float(res_dict.get('metrics/mAP50-95(B)', 0.0)), 4)
}

print(f"=== HASIL TEST SET (imgsz={IMGSZ}) ===")
for metric_name, val in test_metrics.items():
    print(f"  {metric_name:<15}: {val:.4f}")

# %% [markdown]
# ## 8. Evaluasi Stratified (Berdasarkan Sumber & Ukuran Objek)

# %%
def compute_iou(box_a, box_b):
    x1 = max(box_a[0], box_b[0])
    y1 = max(box_a[1], box_b[1])
    x2 = min(box_a[2], box_b[2])
    y2 = min(box_a[3], box_b[3])
    
    inter_area = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    union_area = (box_a[2] - box_a[0]) * (box_a[3] - box_a[1]) + (box_b[2] - box_b[0]) * (box_b[3] - box_b[1]) - inter_area
    return inter_area / union_area if union_area > 0 else 0.0

def load_ground_truth(label_path, img_w, img_h):
    boxes = []
    if os.path.exists(label_path):
        with open(label_path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) == 5:
                    _, xc, yc, bw, bh = [float(v) for v in parts]
                    x1 = (xc - bw / 2.0) * img_w
                    y1 = (yc - bh / 2.0) * img_h
                    x2 = (xc + bw / 2.0) * img_w
                    y2 = (yc + bh / 2.0) * img_h
                    boxes.append([x1, y1, x2, y2])
    return boxes

def evaluate_stratified(model, img_files, label_dir, conf_threshold, img_size):
    box_records = []
    image_records = []
    
    for img_path in img_files:
        img = cv2.imread(img_path)
        if img is None:
            continue
        h, w = img.shape[:2]
        base_name = os.path.basename(img_path)
        stem = os.path.splitext(base_name)[0]
        
        lbl_file = os.path.join(label_dir, f"{stem}.txt")
        gt_boxes = load_ground_truth(lbl_file, w, h)
        
        preds = model.predict(img_path, conf=conf_threshold, imgsz=img_size, verbose=False)[0]
        pred_boxes = preds.boxes.xyxy.cpu().numpy().tolist()
        
        used_preds = set()
        matched_gts = set()
        
        for gi, gt_box in enumerate(gt_boxes):
            best_iou, best_idx = 0.5, -1
            for pi, pred_box in enumerate(pred_boxes):
                if pi in used_preds:
                    continue
                iou = compute_iou(gt_box, pred_box)
                if iou >= best_iou:
                    best_iou, best_idx = iou, pi
            if best_idx >= 0:
                used_preds.add(best_idx)
                matched_gts.add(gi)
                
        source = 'CCTV' if stem.split('.rf.')[0].lower().startswith('cars') else 'RF'
        max_h_rel = 0.0
        
        for gi, gt_box in enumerate(gt_boxes):
            h_rel = (gt_box[3] - gt_box[1]) / h
            max_h_rel = max(max_h_rel, h_rel)
            box_records.append({
                'source': source,
                'h_rel': h_rel,
                'is_hit': (gi in matched_gts)
            })
            
        image_records.append({
            'source': source,
            'h_rel': max_h_rel,
            'n_gt': len(gt_boxes),
            'n_pred': len(pred_boxes),
            'n_match': len(matched_gts),
            'false_positives': len(pred_boxes) - len(used_preds)
        })
        
    return box_records, image_records

def aggregate_strata(box_records, image_records):
    summary = {}
    
    def calculate_group(filter_fn, group_name):
        b = [r for r in box_records if filter_fn(r)]
        im = [r for r in image_records if filter_fn(r)]
        summary[group_name] = {
            'total_boxes': len(b),
            'box_recall': round(float(np.mean([r['is_hit'] for r in b])), 4) if b else 0.0,
            'total_images': len(im),
            'plate_detected_image_rate': round(float(np.mean([r['n_match'] > 0 for r in im])), 4) if im else 0.0,
            'avg_false_positives_per_image': round(float(np.mean([r['false_positives'] for r in im])), 3) if im else 0.0
        }
        
    calculate_group(lambda r: True, 'ALL')
    calculate_group(lambda r: r['source'] == 'CCTV', 'CCTV_Source')
    calculate_group(lambda r: r['source'] == 'RF', 'Roboflow_Source')
    
    for low, high in [(0.0, 0.03), (0.03, 0.05), (0.05, 0.08), (0.08, 1.0)]:
        tag = f"plate_height_{int(low*100)}_{int(high*100)}_pct"
        calculate_group(lambda r, l=low, h=high: l <= r['h_rel'] < h, tag)
        
    return summary

test_images_dir = os.path.join(work_dir, 'images', 'test')
test_labels_dir = os.path.join(work_dir, 'labels', 'test')
test_image_files = sorted(glob.glob(os.path.join(test_images_dir, '*.*')))

print(f"Total citra pengujian: {len(test_image_files)}")

box_recs, img_recs = evaluate_stratified(best_model, test_image_files, test_labels_dir, OP_CONF, IMGSZ)
stratified_results = aggregate_strata(box_recs, img_recs)

print(f"\n=== HASIL STRATIFIED (@conf={OP_CONF}, imgsz={IMGSZ}) ===")
print(json.dumps(stratified_results, indent=2))

# %% [markdown]
# ## 9. Analisis Sensitivitas Ambang Batas (Confidence Sweep)

# %%
conf_sweep_results = []
print(f"{'Conf':<8} {'Precision':<12} {'Recall':<10} {'mAP50':<10} {'mAP50-95':<10}")
print("-" * 52)

for c_val in [0.15, 0.25, 0.40, 0.50, 0.75]:
    sweep_val = best_model.val(
        data=local_yaml_path,
        split='test',
        imgsz=IMGSZ,
        conf=c_val,
        device=device,
        verbose=False
    )
    sw_dict = sweep_val.results_dict
    row_data = {
        'conf': c_val,
        'precision': round(float(sw_dict.get('metrics/precision(B)', 0.0)), 4),
        'recall': round(float(sw_dict.get('metrics/recall(B)', 0.0)), 4),
        'map_50': round(float(sw_dict.get('metrics/mAP50(B)', 0.0)), 4),
        'map_50_95': round(float(sw_dict.get('metrics/mAP50-95(B)', 0.0)), 4)
    }
    conf_sweep_results.append(row_data)
    print(f"{row_data['conf']:<8.2f} {row_data['precision']:<12.4f} {row_data['recall']:<10.4f} {row_data['map_50']:<10.4f} {row_data['map_50_95']:<10.4f}")

# %% [markdown]
# ## 10. Analisis Kasus Kegagalan Deteksi (False Negative & False Positive)

# %%
failures_dir = '/kaggle/working/detector_failure_cases'
if os.path.isdir(failures_dir):
    shutil.rmtree(failures_dir)
os.makedirs(failures_dir, exist_ok=True)

saved_failures = 0
total_gt_boxes = 0
total_pred_boxes = 0
total_false_negatives = 0
total_false_positives = 0

for img_path in test_image_files:
    img = cv2.imread(img_path)
    if img is None:
        continue
    h, w = img.shape[:2]
    base_name = os.path.basename(img_path)
    stem = os.path.splitext(base_name)[0]
    
    lbl_file = os.path.join(test_labels_dir, f"{stem}.txt")
    gt_boxes = load_ground_truth(lbl_file, w, h)
    
    preds = best_model.predict(img_path, conf=OP_CONF, imgsz=IMGSZ, verbose=False)[0]
    pred_boxes = preds.boxes.xyxy.cpu().numpy().tolist()
    
    used_preds = set()
    matched_gts = set()
    for gi, gt in enumerate(gt_boxes):
        best_iou, best_idx = 0.5, -1
        for pi, pred in enumerate(pred_boxes):
            if pi in used_preds:
                continue
            iou = compute_iou(gt, pred)
            if iou >= best_iou:
                best_iou, best_idx = iou, pi
        if best_idx >= 0:
            used_preds.add(best_idx)
            matched_gts.add(gi)
            
    missed_gt = [gt for gi, gt in enumerate(gt_boxes) if gi not in matched_gts]
    extra_preds = [pred for pi, pred in enumerate(pred_boxes) if pi not in used_preds]
    
    total_gt_boxes += len(gt_boxes)
    total_pred_boxes += len(pred_boxes)
    total_false_negatives += len(missed_gt)
    total_false_positives += len(extra_preds)
    
    # Simpan maksimal 20 sampel kegagalan untuk diinspeksi secara visual
    if (missed_gt or extra_preds) and saved_failures < 20:
        vis_img = img.copy()
        # Hijau: Ground Truth
        for b in gt_boxes:
            cv2.rectangle(vis_img, (int(b[0]), int(b[1])), (int(b[2]), int(b[3])), (0, 255, 0), 2)
        # Merah: Missed / False Negative
        for b in missed_gt:
            cv2.rectangle(vis_img, (int(b[0]), int(b[1])), (int(b[2]), int(b[3])), (0, 0, 255), 2)
        # Biru: Deteksi Salah / False Positive
        for b in extra_preds:
            cv2.rectangle(vis_img, (int(b[0]), int(b[1])), (int(b[2]), int(b[3])), (255, 0, 0), 2)
            
        out_fn = f"fail_{saved_failures:02d}_FN{len(missed_gt)}_FP{len(extra_preds)}_{base_name}"
        cv2.imwrite(os.path.join(failures_dir, out_fn), vis_img)
        saved_failures += 1

print(f"\n=== RINGKASAN ERROR (@conf={OP_CONF}) ===")
print(f"Total BBox Ground Truth: {total_gt_boxes}")
print(f"Total BBox Prediksi    : {total_pred_boxes}")
print(f"False Negatives (Miss) : {total_false_negatives} ({total_false_negatives/max(total_gt_boxes,1)*100:.1f}%)")
print(f"False Positives (Extra): {total_false_positives} ({total_false_positives/max(total_pred_boxes,1)*100:.1f}%)")
print(f"Sampel visual disimpan : {saved_failures} gambar di {failures_dir}")

# %% [markdown]
# ## 11. Simpan Bobot Model dan Ringkasan Metrik Evaluasi

# %%
output_best_pt = '/kaggle/working/best_detector.pt'
shutil.copy(best_model_path, output_best_pt)

eval_summary = {
    'config': {
        'imgsz': IMGSZ,
        'epochs': EPOCHS,
        'patience': PATIENCE,
        'batch': BATCH,
        'mosaic': MOSAIC,
        'close_mosaic': CLOSE_MOSAIC,
        'scale': SCALE,
        'degrees': DEGREES,
        'multi_scale': MULTI_SCALE,
        'seed': SEED,
        'op_conf': OP_CONF
    },
    'model': {
        'architecture': 'yolov8n',
        'params': int(n_params),
        'est_fp16_mb': round(est_fp16_mb, 2),
        'meets_mobile_budget': bool(est_fp16_mb <= 6.0)
    },
    'test_metrics': test_metrics,
    'confidence_sweep': conf_sweep_results,
    'stratified_metrics': stratified_results,
    'error_analysis': {
        'gt_boxes': total_gt_boxes,
        'predicted_boxes': total_pred_boxes,
        'false_negatives': total_false_negatives,
        'false_positives': total_false_positives
    },
    'weights_file': 'best_detector.pt',
    'training_duration_hours': round(training_duration_hours, 2)
}

metrics_json_path = '/kaggle/working/detector_eval_metrics.json'
with open(metrics_json_path, 'w') as f:
    json.dump(eval_summary, f, indent=2)

print(f"Bobot terbaik berhasil disimpan: {output_best_pt}")
print(f"Ringkasan evaluasi disimpan ke : {metrics_json_path}")

# %% [markdown]
# ## 12. Cleanup File Sementara

# %%
# Hapus salinan direktori dataset lokal untuk menjaga ukuran output kernel tetap efisien
if os.path.isdir(work_dir) and os.path.abspath(work_dir) != os.path.abspath(dataset_dir):
    shutil.rmtree(work_dir)
    print(f"Direktori sementara {work_dir} berhasil dibersihkan.")

print("Eksekusi notebook training dan evaluasi selesai.")
