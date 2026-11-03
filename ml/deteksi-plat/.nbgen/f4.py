# %% [markdown]
# # Preprocessing Dataset Pengenalan Karakter Plat Nomor (OCR)
#
# Notebook ini memproses dataset teks plat nomor (`plate_text_dataset`) untuk mempersiapkan data pelatihan model OCR (CNN-2D + TCN + CTC Loss).
# Tahapan pekerjaan meliputi:
# 1. Sanitasi teks label plat nomor dan standarisasi kamus token (`vocab.json`).
# 2. Implementasi modul standarisasi citra bersama (*shared preprocessor*) ke Grayscale 32x128 dengan zero-padding menjaga rasio asli plat.
# 3. Pembuatan variasi augmentasi simulasi potongan tidak sempurna (*simulated imperfect crops*) untuk meningkatkan ketahanan model terhadap deviasi bounding box detektor.
# 4. Pembagian split bebas kebocoran data (Train 80%, Val 10%, Test 10%) dan ekspor arsip dataset serta manifest CSV.

# %% [markdown]
# ## 1. Setup Environment dan Lokasi Dataset

# %%
import os
import glob
import json
import shutil
import zipfile
from collections import Counter, defaultdict

import numpy as np
import pandas as pd
import cv2
import matplotlib.pyplot as plt

# Temukan file label.csv dari direktori input Kaggle
csv_candidates = glob.glob('/kaggle/input/**/label.csv', recursive=True)
if not csv_candidates:
    raise FileNotFoundError("label.csv tidak ditemukan di /kaggle/input")

label_csv_path = csv_candidates[0]
dataset_dir = os.path.dirname(label_csv_path)

# Cari folder gambar plat
images_dir = os.path.join(dataset_dir, 'images')
if not os.path.isdir(images_dir):
    images_dir = os.path.join(dataset_dir, 'dataset')
if not os.path.isdir(images_dir):
    images_dir = dataset_dir

print(f"Path label CSV : {label_csv_path}")
print(f"Direktori citra: {images_dir}")

# Buat mapping nama file ke path lengkap gambar
image_map = {}
for root, _, files in os.walk(images_dir):
    for f in files:
        if f.lower().endswith(('.jpg', '.jpeg', '.png')):
            image_map.setdefault(f, os.path.join(root, f))

print(f"Total citra terindeks: {len(image_map)}")

# %% [markdown]
# ## 2. Sanitasi Label Teks dan Kamus Token (Vocabulary)

# %%
df_raw = pd.read_csv(label_csv_path)
print(f"Total baris data mentah: {len(df_raw)}")
display(df_raw.head())

file_col = [c for c in df_raw.columns if 'name' in c.lower() or 'file' in c.lower() or 'image' in c.lower()][0]
text_col = [c for c in df_raw.columns if 'label' in c.lower() or 'text' in c.lower()][0]

def clean_plate_text(raw_text):
    if pd.isna(raw_text):
        return ""
    text = str(raw_text).strip().upper()
    return ''.join(c for c in text if c.isalnum())

df_raw['clean_text'] = df_raw[text_col].apply(clean_plate_text)
df_raw['char_length'] = df_raw['clean_text'].apply(len)

valid_mask = (df_raw['char_length'] >= 3) & (df_raw['char_length'] <= 12)
df_valid = df_raw[valid_mask].copy().reset_index(drop=True)

print(f"\nTotal sampel valid: {len(df_valid)}")
print(f"Panjang karakter (min/median/max): {df_valid['char_length'].min()} / {int(df_valid['char_length'].median())} / {df_valid['char_length'].max()}")

# Standarisasi Kamus Karakter (37 Token: Index 0 = CTC Blank, 1-10 = Digit, 11-36 = Huruf)
tokens = ['<blank>'] + [str(i) for i in range(10)] + [chr(c) for c in range(ord('A'), ord('Z') + 1)]
char_to_idx = {char: idx for idx, char in enumerate(tokens)}
idx_to_char = {idx: char for idx, char in enumerate(tokens)}

vocab_dict = {
    'total_tokens': len(tokens),
    'blank_index': 0,
    'char_to_idx': char_to_idx,
    'idx_to_char': idx_to_char
}

with open('/kaggle/working/vocab.json', 'w') as f:
    json.dump(vocab_dict, f, indent=2)

print(f"Kamus token berhasil dibuat ({len(tokens)} token). Disimpan ke 'vocab.json'.")

# %% [markdown]
# ## 3. Modul Shared Preprocessor (Standardisasi Grayscale 32x128)

# %%
def preprocess_crop_for_ocr(img_bgr, target_h=48, target_w=192):
    """
    Standardisasi citra potongan plat untuk model OCR:
    1. Konversi ke Grayscale.
    2. Deteksi Aspek Rasio & Auto-Crop Baris Utama (memotong baris bulan/tahun pajak pada plat kotak bertingkat).
    3. Peningkatan Kontras Adaptif (CLAHE) agar karakter terpisah tajam dari background plat.
    4. Interpolasi resolusi tinggi (target 48x192) bebas distorsi dan pixelated.
    5. Normalisasi piksel Float32 [0.0, 1.0].
    """
    if img_bgr is None or img_bgr.size == 0:
        return np.zeros((target_h, target_w, 1), dtype=np.float32)
        
    if len(img_bgr.shape) == 3:
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    else:
        gray = img_bgr.copy()
        
    h, w = gray.shape[:2]
    aspect_ratio = w / max(h, 1)
    
    # Jika citra plat bertingkat / kotak (aspect ratio < 1.8),
    # potong 32% area bawah yang merupakan baris bulan-tahun pajak agar tidak mengacaukan CTC
    if aspect_ratio < 1.8:
        crop_h = int(h * 0.68)
        gray = gray[:crop_h, :]
        h, w = gray.shape[:2]
        
    # Terapkan CLAHE untuk memisahkan teks dari latar/glare plat
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    gray_enhanced = clahe.apply(gray)
    
    # Resize berkualitas tinggi ke 48x192
    interp = cv2.INTER_AREA if (w >= target_w and h >= target_h) else cv2.INTER_CUBIC
    resized = cv2.resize(gray_enhanced, (target_w, target_h), interpolation=interp)
    normalized = resized.astype(np.float32) / 255.0
    
    return np.expand_dims(normalized, axis=-1)

preprocess_config = {
    'target_height': 48,
    'target_width': 192,
    'channels': 1,
    'color_space': 'GRAYSCALE',
    'tax_line_auto_crop': 'CROP_TOP_68_PCT_IF_AR_LT_1_8',
    'contrast_enhancement': 'CLAHE_CLIP_2_0',
    'normalization': '[0.0, 1.0]',
    'resize_mode': 'SMART_ROI_STRETCH_48x192'
}

with open('/kaggle/working/ocr_preprocess_config.json', 'w') as f:
    json.dump(preprocess_config, f, indent=2)

print("Config preprocessing diperbarui dengan Smart ROI Crop & CLAHE (48x192).")

# %% [markdown]
# ## 4. Simulasi Potongan Tidak Sempurna (Simulated Imperfect Crops)

# %%
def generate_simulated_crop(img_bgr, rng):
    if img_bgr is None or img_bgr.size == 0:
        return img_bgr
        
    h, w = img_bgr.shape[:2]
    shift_x1 = int(w * rng.uniform(0.0, 0.08))
    shift_y1 = int(h * rng.uniform(0.0, 0.08))
    shift_x2 = int(w * (1.0 - rng.uniform(0.0, 0.08)))
    shift_y2 = int(h * (1.0 - rng.uniform(0.0, 0.08)))
    
    x1 = max(0, min(shift_x1, w - 10))
    y1 = max(0, min(shift_y1, h - 10))
    x2 = max(x1 + 10, min(shift_x2, w))
    y2 = max(y1 + 10, min(shift_y2, h))
    
    cropped = img_bgr[y1:y2, x1:x2].copy()
    if cropped.size == 0:
        cropped = img_bgr.copy()
        
    ch, cw = cropped.shape[:2]
    angle = rng.uniform(-3.0, 3.0)
    matrix = cv2.getRotationMatrix2D((cw / 2, ch / 2), angle, 1.0)
    rotated = cv2.warpAffine(cropped, matrix, (cw, ch), borderMode=cv2.BORDER_REPLICATE)
    
    if rng.uniform(0.0, 1.0) < 0.30:
        rotated = cv2.GaussianBlur(rotated, (3, 3), 0)
        
    return rotated

print("Generator simulasi imperfect crop siap.")

# %% [markdown]
# ## 5. Pengelompokan Data Bebas Leakage & Pembagian Split

# %%
def get_image_group_key(filename):
    base = os.path.basename(filename)
    if '.rf.' in base:
        return base.split('.rf.')[0].replace('_jpg', '').replace('_png', '')
    return os.path.splitext(base)[0]

groups = defaultdict(list)
for idx, row in df_valid.iterrows():
    f_name = row[file_col]
    groups[get_image_group_key(f_name)].append(idx)

group_keys = sorted(groups.keys())
rng = np.random.RandomState(42)
rng.shuffle(group_keys)

n_groups = len(group_keys)
n_train = int(0.80 * n_groups)
n_val = int(0.10 * n_groups)

train_indices = [idx for k in group_keys[:n_train] for idx in groups[k]]
val_indices = [idx for k in group_keys[n_train:n_train + n_val] for idx in groups[k]]
test_indices = [idx for k in group_keys[n_train + n_val:] for idx in groups[k]]

df_train_base = df_valid.loc[train_indices].copy().reset_index(drop=True)
df_val = df_valid.loc[val_indices].copy().reset_index(drop=True)
df_test = df_valid.loc[test_indices].copy().reset_index(drop=True)

print(f"Total grup unik : {n_groups}")
print(f"Split dasar     : Train={len(df_train_base)}, Val={len(df_val)}, Test={len(df_test)}")

# %% [markdown]
# ## 6. Pemrosesan Citra dan Pembentukan Dataset

# %%
ocr_temp_dir = '/kaggle/working/ocr_dataset'
for s in ('train', 'val', 'test'):
    os.makedirs(os.path.join(ocr_temp_dir, s), exist_ok=True)

def process_eval_subset(df_subset, split_name):
    records = []
    for _, row in df_subset.iterrows():
        fn = row[file_col]
        full_p = image_map.get(fn)
        if not full_p or not os.path.exists(full_p):
            continue
            
        img = cv2.imread(full_p)
        if img is None:
            continue
            
        prep = preprocess_crop_for_ocr(img)
        dst_fn = f"{os.path.splitext(fn)[0]}.png"
        dst_path = os.path.join(ocr_temp_dir, split_name, dst_fn)
        cv2.imwrite(dst_path, (prep.squeeze() * 255.0).astype(np.uint8))
        
        records.append({
            'filename': dst_fn,
            'rel_path': f"{split_name}/{dst_fn}",
            'clean_text': row['clean_text'],
            'char_length': row['char_length'],
            'type': 'clean'
        })
    return pd.DataFrame(records)

df_val_final = process_eval_subset(df_val, 'val')
df_test_final = process_eval_subset(df_test, 'test')

train_records = []
train_rng = np.random.RandomState(42)

for _, row in df_train_base.iterrows():
    fn = row[file_col]
    full_p = image_map.get(fn)
    if not full_p or not os.path.exists(full_p):
        continue
        
    img = cv2.imread(full_p)
    if img is None:
        continue
        
    prep_clean = preprocess_crop_for_ocr(img)
    clean_fn = f"{os.path.splitext(fn)[0]}_clean.png"
    clean_path = os.path.join(ocr_temp_dir, 'train', clean_fn)
    cv2.imwrite(clean_path, (prep_clean.squeeze() * 255.0).astype(np.uint8))
    
    train_records.append({
        'filename': clean_fn,
        'rel_path': f"train/{clean_fn}",
        'clean_text': row['clean_text'],
        'char_length': row['char_length'],
        'type': 'clean'
    })
    
    # 65% sampel train ditambahkan versi simulasi imperfect crop
    if train_rng.uniform(0.0, 1.0) < 0.65:
        imperfect = generate_simulated_crop(img, train_rng)
        prep_imp = preprocess_crop_for_ocr(imperfect)
        imp_fn = f"{os.path.splitext(fn)[0]}_sim.png"
        imp_path = os.path.join(ocr_temp_dir, 'train', imp_fn)
        cv2.imwrite(imp_path, (prep_imp.squeeze() * 255.0).astype(np.uint8))
        
        train_records.append({
            'filename': imp_fn,
            'rel_path': f"train/{imp_fn}",
            'clean_text': row['clean_text'],
            'char_length': row['char_length'],
            'type': 'simulated'
        })

df_train_final = pd.DataFrame(train_records)

print("=== DISTRIBUSI FINAL DATASET OCR ===")
print(f"Train : {len(df_train_final)} sampel ({dict(Counter(df_train_final['type']))})")
print(f"Val   : {len(df_val_final)} sampel")
print(f"Test  : {len(df_test_final)} sampel")

# Simpan file manifest CSV
df_train_final.to_csv('/kaggle/working/train_ocr.csv', index=False)
df_val_final.to_csv('/kaggle/working/val_ocr.csv', index=False)
df_test_final.to_csv('/kaggle/working/test_ocr.csv', index=False)
print("Manifest train_ocr.csv, val_ocr.csv, dan test_ocr.csv berhasil disimpan.")

# %% [markdown]
# ## 7. Verifikasi Visual Citra Grayscale 32x128

# %%
fig, axes = plt.subplots(5, 4, figsize=(16, 10))
axes = axes.flatten()

sample_df = df_train_final.sample(n=min(20, len(df_train_final)), random_state=42).reset_index(drop=True)

for idx, row in sample_df.iterrows():
    ax = axes[idx]
    img_path = os.path.join(ocr_temp_dir, row['rel_path'])
    img_gray = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
    
    if img_gray is not None:
        ax.imshow(img_gray, cmap='gray')
        ax.set_title(f"{row['clean_text']} [{row['type']}]\n({img_gray.shape[1]}x{img_gray.shape[0]})", fontsize=8)
    ax.axis('off')

plt.tight_layout()
plt.savefig('/kaggle/working/verification_ocr_preprocessed.png', dpi=120, bbox_inches='tight')
plt.show()

# %% [markdown]
# ## 8. Kompresi Dataset Citra ke ZIP & Cleanup

# %%
# Kompres folder ocr_dataset menjadi ocr_dataset.zip agar efisien dan mudah diunduh
zip_output_path = '/kaggle/working/ocr_dataset.zip'
print("Mengompresi dataset ke ocr_dataset.zip...")

with zipfile.ZipFile(zip_output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, _, files in os.walk(ocr_temp_dir):
        for f in files:
            full_path = os.path.join(root, f)
            arcname = os.path.relpath(full_path, '/kaggle/working')
            zipf.write(full_path, arcname)

print(f"Kompresi selesai! Ukuran zip: {os.path.getsize(zip_output_path) / (1024 * 1024):.2f} MB")

# Hapus folder uncompressed agar output kernel bersih dan tidak overload file count
shutil.rmtree(ocr_temp_dir)
print("Folder sementara dibersihkan.")

# Simpan metadata ringkasan
summary_meta = {
    'total_vocabulary': len(tokens),
    'image_dimension': [48, 192, 1],
    'subsets': {
        'train': {
            'total_samples': len(df_train_final),
            'clean_count': int((df_train_final['type'] == 'clean').sum()),
            'simulated_count': int((df_train_final['type'] == 'simulated').sum())
        },
        'val': {
            'total_samples': len(df_val_final)
        },
        'test': {
            'total_samples': len(df_test_final)
        }
    },
    'artifacts': [
        'vocab.json',
        'ocr_preprocess_config.json',
        'train_ocr.csv',
        'val_ocr.csv',
        'test_ocr.csv',
        'verification_ocr_preprocessed.png',
        'ocr_dataset.zip'
    ]
}

with open('/kaggle/working/ocr_dataset_summary.json', 'w') as f:
    json.dump(summary_meta, f, indent=2)

print("\n=== RINGKASAN DATASET PREPROCESSED OCR ===")
print(json.dumps(summary_meta, indent=2))
print("Seluruh proses Fase 4 berhasil dieksekusi.")
