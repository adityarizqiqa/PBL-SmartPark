# %% [markdown]
# # Validasi dan Analisis Kualitas Anotasi Bounding Box Plat Nomor
#
# Notebook ini melakukan pengecekan kualitas anotasi bounding box pada dataset deteksi plat nomor kendaraan. 
# Dataset terdiri dari dua sumber citra utama: citra CCTV (`Cars*.png`) dan citra kamera jarak dekat / Roboflow (`*.rf.*.jpg`).
# Fokus analisis adalah memeriksa konsistensi aspect ratio ($w/h$) dan ukuran bounding box untuk mendeteksi potensi anomali atau kesalahan anotasi sebelum data digunakan dalam pipeline training detektor.

# %% [markdown]
# ## 1. Load Dataset dan Penyiapan Path

# %%
import os
import glob
import json
from collections import defaultdict, Counter

import cv2
import numpy as np
import matplotlib.pyplot as plt

# Cari file anotasi COCO di direktori input Kaggle
ann_files = glob.glob('/kaggle/input/**/annotations.json', recursive=True)
if not ann_files:
    raise FileNotFoundError("annotations.json tidak ditemukan di /kaggle/input")

ann_path = ann_files[0]
dataset_root = os.path.dirname(os.path.dirname(ann_path))
images_dir = os.path.join(dataset_root, 'images')

print(f"Path anotasi: {ann_path}")
print(f"Folder gambar: {images_dir}")

# Buat mapping nama file ke path lengkap gambar
image_map = {}
for root, _, files in os.walk(images_dir):
    for f in files:
        image_map[f] = os.path.join(root, f)

print(f"Total gambar terindeks: {len(image_map)}")

# %% [markdown]
# ## 2. Ekstraksi Geometri dan Pengelompokan Data

# %%
# Load data anotasi COCO
with open(ann_path, 'r') as f:
    coco_data = json.load(f)

images_info = {img['id']: img for img in coco_data['images']}

# Kelompokkan bounding box per image_id
boxes_by_image = defaultdict(list)
for ann in coco_data['annotations']:
    boxes_by_image[ann['image_id']].append([float(val) for val in ann['bbox']])

# Identifikasi sumber dataset berdasarkan penamaan file
def get_source_type(filename):
    base = os.path.basename(filename)
    return 'CCTV' if base.lower().startswith('cars') else 'RF'

# Kumpulkan metrik geometri bounding box
records = []
for img_id, info in images_info.items():
    img_w = float(info['width'])
    img_h = float(info['height'])
    file_name = info['file_name']
    src = get_source_type(file_name)
    
    for box in boxes_by_image.get(img_id, []):
        x, y, w, h = box
        ar = (w / h) if h > 0 else 0.0
        h_rel = (h / img_h) if img_h > 0 else 0.0
        area_rel = (w * h) / (img_w * img_h) if (img_w * img_h) > 0 else 0.0
        
        records.append({
            'image_id': img_id,
            'file_name': file_name,
            'source': src,
            'x': x, 'y': y, 'w': w, 'h': h,
            'img_w': img_w, 'img_h': img_h,
            'ar': ar,
            'h_rel': h_rel,
            'area_rel': area_rel
        })

print(f"Total bounding box: {len(records)}")
print(f"Distribusi per sumber: {dict(Counter(r['source'] for r in records))}")
print(f"Gambar tanpa bounding box: {sum(1 for img_id in images_info if not boxes_by_image.get(img_id))}")

# %% [markdown]
# ## 3. Ringkasan Statistik Geometri

# %%
cctv_records = [r for r in records if r['source'] == 'CCTV']
rf_records = [r for r in records if r['source'] == 'RF']

summary_stats = {}
for name, group in [('CCTV', cctv_records), ('RF', rf_records)]:
    ar_vals = np.array([r['ar'] for r in group])
    h_rel_vals = np.array([r['h_rel'] * 100.0 for r in group])
    h_vals = np.array([r['h'] for r in group])
    
    summary_stats[name] = {
        'total_images': sum(1 for _, inf in images_info.items() if get_source_type(inf['file_name']) == name),
        'total_boxes': len(group),
        'ar_p5': round(float(np.percentile(ar_vals, 5)), 2),
        'ar_p25': round(float(np.percentile(ar_vals, 25)), 2),
        'ar_median': round(float(np.percentile(ar_vals, 50)), 2),
        'ar_p75': round(float(np.percentile(ar_vals, 75)), 2),
        'ar_p95': round(float(np.percentile(ar_vals, 95)), 2),
        'ar_lt_1_5_count': int((ar_vals < 1.5).sum()),
        'ar_lt_2_0_count': int((ar_vals < 2.0).sum()),
        'ar_gt_5_0_count': int((ar_vals > 5.0).sum()),
        'h_median_px': round(float(np.percentile(h_vals, 50)), 1),
        'h_lt_8px_count': int((h_vals < 8).sum()),
        'h_rel_median_pct': round(float(np.percentile(h_rel_vals, 50)), 2),
        'h_rel_ge_3pct_ratio': round(float((h_rel_vals >= 3.0).mean()), 4)
    }

print("=== RINGKASAN STATISTIK GEOMETRI ===")
print(json.dumps(summary_stats, indent=2))

# Simpan hasil ringkasan ke file JSON
with open('label_audit_summary.json', 'w') as f:
    json.dump(summary_stats, f, indent=2)

# %% [markdown]
# ## 4. Fungsi Visualisasi Sampel Anotasi
#
# Fungsi untuk menampilkan konteks citra di sekitar bounding box (kiri) dan hasil crop plat (kanan).

# %%
def visualize_samples(sample_records, title, save_path=None, max_cols=4):
    if not sample_records:
        return
    
    n_samples = len(sample_records)
    n_cols = min(max_cols, n_samples)
    n_rows = int(np.ceil(n_samples / n_cols))
    
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(4 * n_cols, 3 * n_rows))
    axes = np.atleast_1d(axes).flatten()
    
    for idx, r in enumerate(sample_records):
        ax = axes[idx]
        img_full_path = image_map.get(r['file_name'])
        if not img_full_path or not os.path.exists(img_full_path):
            ax.set_title(f"Not found: {r['file_name']}", fontsize=8)
            ax.axis('off')
            continue
            
        img = cv2.imread(img_full_path)
        if img is None:
            ax.axis('off')
            continue
            
        H, W = img.shape[:2]
        x, y, w, h = r['x'], r['y'], r['w'], r['h']
        
        # Area konteks di sekitar bounding box
        pad_x = max(4.0, 0.4 * w)
        pad_y = max(4.0, 0.4 * h)
        x1 = int(max(0, x - pad_x))
        y1 = int(max(0, y - pad_y))
        x2 = int(min(W, x + w + pad_x))
        y2 = int(min(H, y + h + pad_y))
        
        context_img = img[y1:y2, x1:x2].copy()
        
        # Gambar kotak hijau pada area konteks
        cv2.rectangle(
            context_img,
            (int(x - x1), int(y - y1)),
            (int(x - x1 + w), int(y - y1 + h)),
            (0, 255, 0), 2
        )
        
        # Crop area plat saja
        crop_x1 = int(max(0, x))
        crop_y1 = int(max(0, y))
        crop_x2 = int(min(W, x + w))
        crop_y2 = int(min(H, y + h))
        crop_img = img[crop_y1:crop_y2, crop_x1:crop_x2]
        
        if crop_img.size == 0 or context_img.size == 0:
            ax.axis('off')
            continue
            
        # Samakan tinggi untuk display berdampingan
        target_h = 160
        ctx_scaled = cv2.resize(context_img, (max(1, int(context_img.shape[1] * target_h / context_img.shape[0])), target_h))
        crop_scaled = cv2.resize(crop_img, (max(1, int(crop_img.shape[1] * target_h / crop_img.shape[0])), target_h), interpolation=cv2.INTER_NEAREST)
        
        divider = np.full((target_h, 4, 3), 255, dtype=np.uint8)
        combined = np.hstack([ctx_scaled, divider, crop_scaled])
        
        ax.imshow(cv2.cvtColor(combined, cv2.COLOR_BGR2RGB))
        ax.set_title(f"{r['file_name']}\nar={r['ar']:.2f} | h={r['h']:.0f}px ({r['h_rel']*100:.1f}%)", fontsize=8)
        ax.axis('off')
        
    for ax in axes[n_samples:]:
        ax.axis('off')
        
    fig.suptitle(title, fontsize=12)
    plt.tight_layout()
    if save_path:
        plt.savefig(save_path, dpi=120, bbox_inches='tight')
    plt.show()

# %% [markdown]
# ## 5. Visualisasi Sampel Berdasarkan Karakteristik BBox

# %%
# Sampel CCTV dengan Aspect Ratio Terkecil (paling mendekati persegi / anomali)
cctv_smallest_ar = sorted(cctv_records, key=lambda r: r['ar'])[:16]
visualize_samples(
    cctv_smallest_ar,
    title="Sampel CCTV: 16 Bounding Box dengan Aspect Ratio Terkecil",
    save_path="audit_cctv_smallest_ar.png"
)

# %%
# Sampel CCTV dengan Area Bounding Box Terbesar
cctv_largest_area = sorted(cctv_records, key=lambda r: -(r['w'] * r['h']))[:16]
visualize_samples(
    cctv_largest_area,
    title="Sampel CCTV: 16 Bounding Box dengan Area Terbesar",
    save_path="audit_cctv_largest_area.png"
)

# %%
# Sampel CCTV dengan Tinggi Bounding Box Terkecil
cctv_smallest_h = sorted(cctv_records, key=lambda r: r['h'])[:16]
visualize_samples(
    cctv_smallest_h,
    title="Sampel CCTV: 16 Bounding Box dengan Tinggi Terkecil (<8px)",
    save_path="audit_cctv_smallest_h.png"
)

# %%
# Sampel RF sebagai Pembanding (Kontrol)
rf_samples = sorted(rf_records, key=lambda r: -(r['w'] * r['h']))[:8] + sorted(rf_records, key=lambda r: r['ar'])[:8]
visualize_samples(
    rf_samples,
    title="Sampel Citra Roboflow (Pembanding): Kombinasi Ukuran & Aspect Ratio",
    save_path="audit_rf_control.png"
)

# %% [markdown]
# ## 6. Distribusi Aspect Ratio dan Tinggi Bounding Box

# %%
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 4.5))

cctv_ar = [r['ar'] for r in cctv_records]
rf_ar = [r['ar'] for r in rf_records]
bins_ar = np.linspace(0, 6, 50)

ax1.hist(cctv_ar, bins=bins_ar, alpha=0.6, label=f'CCTV (n={len(cctv_ar)})', color='crimson')
ax1.hist(rf_ar, bins=bins_ar, alpha=0.6, label=f'RF (n={len(rf_ar)})', color='royalblue')
ax1.axvline(2.5, color='black', linestyle='--', linewidth=1, label='Batas tipikal plat (ar=2.5)')
ax1.set_title('Distribusi Aspect Ratio (w / h)')
ax1.set_xlabel('Aspect Ratio')
ax1.set_ylabel('Jumlah BBox')
ax1.legend()
ax1.grid(True, alpha=0.3)

cctv_h_rel = [r['h_rel'] * 100.0 for r in cctv_records]
rf_h_rel = [r['h_rel'] * 100.0 for r in rf_records]
bins_h = np.linspace(0, 10, 40)

ax2.hist(cctv_h_rel, bins=bins_h, alpha=0.6, label=f'CCTV (n={len(cctv_h_rel)})', color='crimson')
ax2.hist(rf_h_rel, bins=bins_h, alpha=0.6, label=f'RF (n={len(rf_h_rel)})', color='royalblue')
ax2.axvline(3.0, color='black', linestyle='--', linewidth=1, label='Batas 3% tinggi frame')
ax2.set_title('Distribusi Tinggi BBox Relatif terhadap Frame (%)')
ax2.set_xlabel('Tinggi BBox (% frame)')
ax2.set_ylabel('Jumlah BBox')
ax2.legend()
ax2.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('audit_geometry_hist.png', dpi=120)
plt.show()

# %% [markdown]
# ## 7. Filter dan Ekspor Daftar Bounding Box Anomali

# %%
# Kriteria anomali: aspect ratio terlalu kecil (< 1.5) atau tinggi piksel terlalu rendah (< 8px)
suspect_boxes = []
for r in cctv_records:
    reasons = []
    if r['ar'] < 1.5:
        reasons.append('ar<1.5')
    if r['h'] < 8:
        reasons.append('h<8px')
        
    if reasons:
        suspect_boxes.append({
            'file_name': r['file_name'],
            'x': r['x'],
            'y': r['y'],
            'w': r['w'],
            'h': r['h'],
            'ar': round(r['ar'], 3),
            'h_native': round(r['h'], 1),
            'reason': '+'.join(reasons)
        })

suspect_boxes.sort(key=lambda item: item['ar'])

print(f"Total bbox anomali pada CCTV: {len(suspect_boxes)} dari {len(cctv_records)} ({len(suspect_boxes)/len(cctv_records)*100:.1f}%)")
print("Contoh 15 kandidat pertama:")
for s in suspect_boxes[:15]:
    print(f"  {s['file_name']:<20} ar={s['ar']:.2f}  h={s['h_native']:.1f}px  [{s['reason']}]")

# Simpan daftar anomali ke JSON untuk referensi data cleaning
output_suspects = {
    'total_cctv_boxes': len(cctv_records),
    'total_suspects': len(suspect_boxes),
    'suspects': suspect_boxes
}

with open('label_audit_suspects.json', 'w') as f:
    json.dump(output_suspects, f, indent=2)

print("\nFile 'label_audit_summary.json' dan 'label_audit_suspects.json' berhasil disimpan.")
