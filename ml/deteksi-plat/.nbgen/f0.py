# %% [markdown]
# # Eksplorasi Data (EDA) Plat Nomor Kendaraan Indonesia
#
# Notebook ini melakukan Exploratory Data Analysis (EDA) terhadap dataset plat nomor kendaraan Indonesia.
# Terdapat dua bagian data utama yang dianalisis:
# 1. Dataset deteksi plat nomor (`annotations.json` dan folder `images/`) dalam format COCO.
# 2. Dataset teks OCR (`label.csv` dan folder citra potongan plat).
# Analisis mencakup struktur anotasi, sebaran ukuran bounding box, frekuensi karakter plat nomor, dan visualisasi sampel citra.

# %% [markdown]
# ## 1. Import Library dan Konfigurasi Path

# %%
import os
import json
import glob
from collections import Counter

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import cv2

# Cari path file anotasi dan label di direktori input
ann_files = glob.glob("/kaggle/input/**/annotations.json", recursive=True)
csv_files = glob.glob("/kaggle/input/**/label.csv", recursive=True)

if not ann_files:
    raise FileNotFoundError("annotations.json tidak ditemukan di /kaggle/input")
if not csv_files:
    raise FileNotFoundError("label.csv tidak ditemukan di /kaggle/input")

det_json_path = ann_files[0]
det_img_dir = os.path.join(os.path.dirname(os.path.dirname(det_json_path)), "images")

ocr_csv_path = csv_files[0]
ocr_img_dir = os.path.join(os.path.dirname(ocr_csv_path), "images")
if not os.path.exists(ocr_img_dir):
    ocr_img_dir = os.path.dirname(ocr_csv_path)

print(f"Path anotasi deteksi : {det_json_path}")
print(f"Direktori citra mobil: {det_img_dir}")
print(f"Path label teks OCR  : {ocr_csv_path}")
print(f"Direktori crop plat  : {ocr_img_dir}")

# %% [markdown]
# ## 2. Eksplorasi Anotasi COCO (Dataset Deteksi)

# %%
with open(det_json_path, 'r') as f:
    coco_data = json.load(f)

images_info = {img['id']: img for img in coco_data.get('images', [])}
annotations = coco_data.get('annotations', [])
categories = coco_data.get('categories', [])

print(f"Total citra terdaftar  : {len(images_info):,}")
print(f"Total anotasi BBox     : {len(annotations):,}")
print(f"Kategori objek         : {[cat['name'] for cat in categories]}")

# Tampilkan satu contoh entri anotasi
print("\nContoh data citra:")
print(json.dumps(coco_data['images'][0] if coco_data['images'] else {}, indent=2))
print("\nContoh data anotasi bounding box:")
print(json.dumps(annotations[0] if annotations else {}, indent=2))

# %% [markdown]
# ## 3. Analisis Ukuran dan Aspek Rasio Bounding Box

# %%
aspect_ratios = []
relative_areas = []

for ann in annotations:
    img = images_info.get(ann['image_id'])
    if not img:
        continue
    
    img_w = float(img['width'])
    img_h = float(img['height'])
    x, y, w, h = [float(v) for v in ann['bbox']]
    
    if w > 0 and h > 0:
        aspect_ratios.append(w / h)
        relative_areas.append((w * h) / (img_w * img_h))

mean_ar = float(np.mean(aspect_ratios)) if aspect_ratios else 0.0
median_ar = float(np.median(aspect_ratios)) if aspect_ratios else 0.0
mean_rel_area = float(np.mean(relative_areas)) * 100.0 if relative_areas else 0.0

print(f"Rata-rata Aspect Ratio (w / h) : {mean_ar:.2f}")
print(f"Median Aspect Ratio             : {median_ar:.2f}")
print(f"Rata-rata luas plat thd frame  : {mean_rel_area:.2f}%")

# %% [markdown]
# ## 4. Visualisasi Sampel Bounding Box pada Citra

# %%
fig, axes = plt.subplots(2, 2, figsize=(12, 8))
np.random.seed(42)
sampled_indices = np.random.choice(len(annotations), size=min(4, len(annotations)), replace=False)

for ax, idx in zip(axes.flatten(), sampled_indices):
    ann = annotations[idx]
    img_info = images_info[ann['image_id']]
    file_name = img_info['file_name']
    
    # Resolusi path file citra
    img_path = os.path.join(det_img_dir, file_name)
    if not os.path.exists(img_path):
        candidates = glob.glob(f"{det_img_dir}/**/{file_name}", recursive=True)
        if candidates:
            img_path = candidates[0]
            
    if os.path.exists(img_path):
        img_bgr = cv2.imread(img_path)
        img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        x, y, w, h = [int(float(v)) for v in ann['bbox']]
        
        cv2.rectangle(img_rgb, (x, y), (x + w, y + h), (0, 255, 0), 3)
        ax.imshow(img_rgb)
        ax.set_title(f"{file_name} ({w}x{h} px)", fontsize=9)
    ax.axis('off')

plt.tight_layout()
plt.savefig("sample_detection_boxes.png", dpi=120)
plt.show()

# %% [markdown]
# ## 5. Eksplorasi Dataset Teks OCR

# %%
df_ocr = pd.read_csv(ocr_csv_path)
print("5 baris pertama label.csv:")
display(df_ocr.head())

text_col = [c for c in df_ocr.columns if 'label' in c.lower() or 'text' in c.lower()][0]
file_col = [c for c in df_ocr.columns if 'name' in c.lower() or 'file' in c.lower() or 'image' in c.lower()][0]

print(f"\nTotal data sampel OCR : {len(df_ocr):,}")
print(f"Missing values        : {df_ocr.isnull().sum().to_dict()}")

# Standarisasi teks plat (huruf kapital, tanpa spasi/simbol)
clean_texts = [
    str(text).strip().upper().replace(' ', '').replace('-', '').replace('.', '')
    for text in df_ocr[text_col]
]
text_lengths = [len(t) for t in clean_texts]

print(f"Panjang karakter minimum : {min(text_lengths)}")
print(f"Panjang karakter median  : {int(np.median(text_lengths))}")
print(f"Panjang karakter maksimum: {max(text_lengths)}")

# %% [markdown]
# ## 6. Distribusi Frekuensi Karakter

# %%
all_chars = "".join(clean_texts)
char_counts = Counter(all_chars)

vocab = sorted(list("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
frequencies = [char_counts.get(c, 0) for c in vocab]

plt.figure(figsize=(14, 4.5))
plt.bar(vocab, frequencies, color='cornflowerblue', edgecolor='midnightblue')
plt.title("Frekuensi Kemunculan Karakter Alfanumerik (0-9, A-Z)")
plt.xlabel("Karakter")
plt.ylabel("Jumlah")
plt.grid(axis='y', linestyle='--', alpha=0.5)
plt.tight_layout()
plt.savefig("char_distribution.png", dpi=120)
plt.show()

# %% [markdown]
# ## 7. Visualisasi Sampel Potongan Plat Nomor (OCR)

# %%
fig, axes = plt.subplots(2, 2, figsize=(10, 4.5))
sample_rows = df_ocr.sample(n=min(4, len(df_ocr)), random_state=42)

for ax, (_, row) in zip(axes.flatten(), sample_rows.iterrows()):
    f_name = row[file_col]
    f_path = os.path.join(ocr_img_dir, f_name)
    
    if not os.path.exists(f_path):
        cands = glob.glob(f"{ocr_img_dir}/**/{f_name}", recursive=True)
        if cands:
            f_path = cands[0]
            
    if os.path.exists(f_path):
        img = cv2.imread(f_path)
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        ax.imshow(img_rgb)
        ax.set_title(f"Label: {row[text_col]}", fontsize=9)
    ax.axis('off')

plt.tight_layout()
plt.show()

# %% [markdown]
# ## 8. Simpan Ringkasan Hasil EDA

# %%
audit_summary = {
    "total_detection_images": len(images_info),
    "total_bounding_boxes": len(annotations),
    "total_ocr_samples": len(df_ocr),
    "mean_aspect_ratio": round(mean_ar, 2),
    "median_aspect_ratio": round(median_ar, 2),
    "mean_relative_area_percent": round(mean_rel_area, 2)
}

with open("data_audit_summary.json", "w") as f:
    json.dump(audit_summary, f, indent=2)

print("Ringkasan statistik EDA berhasil disimpan ke 'data_audit_summary.json':")
print(json.dumps(audit_summary, indent=2))
