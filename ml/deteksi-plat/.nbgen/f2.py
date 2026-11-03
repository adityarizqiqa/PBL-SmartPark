# %% [markdown]
# # Preprocessing dan Konversi Dataset Deteksi Plat Nomor (COCO ke YOLO)
#
# Notebook ini memproses dataset deteksi plat nomor dari format COCO menjadi format YOLO txt.
# Untuk mencegah data leakage (kebocoran data) antar split, citra yang berasal dari rekaman video CCTV berurutan dikelompokkan dalam satu kesatuan grup (*chunk-based grouping*) sebelum dilakukan pembagian train (80%), validation (10%), dan test (10%).
# Output yang dihasilkan mencakup struktur folder standar YOLO (`images/` dan `labels/`), file konfigurasi `data.yaml`, serta manifest split `detector_splits.json`.

# %% [markdown]
# ## 1. Setup Environment dan Lokasi Data

# %%
import os
import glob
import json
import shutil
from collections import defaultdict, Counter

import numpy as np
import cv2
import yaml
import matplotlib.pyplot as plt

# Temukan file anotasi COCO di direktori input
ann_candidates = glob.glob('/kaggle/input/**/annotations.json', recursive=True)
if not ann_candidates:
    raise FileNotFoundError("annotations.json tidak ditemukan di /kaggle/input")

ann_path = ann_candidates[0]
dataset_root = os.path.dirname(os.path.dirname(ann_path))
images_dir = os.path.join(dataset_root, 'images')

# Buat mapping nama file ke path lengkap citra
image_paths = {}
for root, _, files in os.walk(images_dir):
    for f in files:
        image_paths.setdefault(f, os.path.join(root, f))

output_dir = '/kaggle/working/yolo_dataset'
print(f"Path anotasi: {ann_path}")
print(f"Folder input: {images_dir} (total {len(image_paths)} citra)")
print(f"Folder output: {output_dir}")

# %% [markdown]
# ## 2. Load Anotasi COCO

# %%
with open(ann_path, 'r') as f:
    coco_data = json.load(f)

images_dict = {img['id']: img for img in coco_data['images']}
boxes_dict = defaultdict(list)
for ann in coco_data['annotations']:
    boxes_dict[ann['image_id']].append([float(v) for v in ann['bbox']])

def get_file_stem(filename):
    base = os.path.basename(filename)
    if '.rf.' in base:
        return base.split('.rf.')[0].replace('_jpg', '').replace('_png', '')
    return os.path.splitext(base)[0]

def get_source_category(filename):
    return 'CCTV' if get_file_stem(filename).lower().startswith('cars') else 'RF'

def extract_frame_number(filename):
    digits = ''.join(c for c in get_file_stem(filename) if c.isdigit())
    return int(digits) if digits else None

total_negatives = sum(1 for img_id in images_dict if not boxes_dict.get(img_id))
print(f"Total citra     : {len(images_dict)}")
print(f"Total BBox      : {sum(len(b) for b in boxes_dict.values())}")
print(f"Citra negatif   : {total_negatives}")
print(f"Distribusi tipe : {dict(Counter(get_source_category(img['file_name']) for img in images_dict.values()))}")

# %% [markdown]
# ## 3. Pengelompokan Data (Grouping) untuk Mencegah Leakage

# %%
# Citra CCTV adalah frame berurutan dari video, sehingga dikelompokkan per 8 frame berurutan
# agar frame serupa tidak tersebar antara train dan test.
def build_groups(chunk_size=8):
    groups = defaultdict(list)
    
    # Kelompokkan data RF berdasarkan nama dasar file
    for img_id, info in images_dict.items():
        if get_source_category(info['file_name']) == 'RF':
            groups['RF_' + get_file_stem(info['file_name'])].append(img_id)
            
    # Kelompokkan data CCTV secara berurutan berdasarkan nomor frame
    cctv_ids = [img_id for img_id, info in images_dict.items() if get_source_category(info['file_name']) == 'CCTV']
    cctv_ids.sort(key=lambda i: (extract_frame_number(images_dict[i]['file_name']) is None,
                                extract_frame_number(images_dict[i]['file_name']) or 0))
    
    for idx, img_id in enumerate(cctv_ids):
        chunk_id = idx // chunk_size
        groups[f"CCTV_chunk_{chunk_id:04d}"].append(img_id)
        
    return groups

data_groups = build_groups(chunk_size=8)
group_sizes = [len(v) for v in data_groups.values()]
print(f"Total grup terbentuk: {len(data_groups)}")
print(f"Ukuran grup (min / median / max): {min(group_sizes)} / {int(np.median(group_sizes))} / {max(group_sizes)}")

# %% [markdown]
# ## 4. Evaluasi Kemiripan Citra Lintas Split Menggunakan dHash

# %%
def compute_dhash(img_path, size=8):
    img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        return None
    resized = cv2.resize(img, (size + 1, size), interpolation=cv2.INTER_AREA)
    diff = resized[:, 1:] > resized[:, :-1]
    return diff.flatten()

all_image_ids = sorted(images_dict.keys())
hashes = np.zeros((len(all_image_ids), 64), dtype=bool)
valid_mask = np.zeros(len(all_image_ids), dtype=bool)

for idx, img_id in enumerate(all_image_ids):
    fn = images_dict[img_id]['file_name']
    full_p = image_paths.get(fn)
    if full_p:
        h = compute_dhash(full_p)
        if h is not None:
            hashes[idx] = h
            valid_mask[idx] = True

valid_indices = np.nonzero(valid_mask)[0]
hamming_threshold = 6
duplicate_pairs = []
pair_distances = {}

# Hitung jarak hamming secara batch
batch_size = 256
for start in range(0, len(valid_indices), batch_size):
    batch = valid_indices[start:start + batch_size]
    dists = (hashes[batch, None, :] != hashes[None, :, :]).sum(axis=-1)
    for r_idx in range(len(batch)):
        matches = np.nonzero(dists[r_idx] <= hamming_threshold)[0]
        for c_idx in matches:
            idx_a, idx_b = int(batch[r_idx]), int(c_idx)
            if idx_b > idx_a:
                duplicate_pairs.append((idx_a, idx_b))
                pair_distances[(idx_a, idx_b)] = int(dists[r_idx][c_idx])

print(f"dHash dihitung untuk {int(valid_mask.sum())}/{len(all_image_ids)} citra.")
print(f"Pasangan dengan kemiripan visual tinggi (Hamming distance <= {hamming_threshold}): {len(duplicate_pairs)}")

# %% [markdown]
# ## 5. Pembagian Split Train, Val, dan Test (80 / 10 / 10)

# %%
def split_by_groups(groups, seed=42, ratios=(0.8, 0.1, 0.1)):
    # Identifikasi grup tanpa bounding box (negatif)
    negative_group_keys = [k for k, ids in groups.items() if all(not boxes_dict.get(i) for i in ids)]
    positive_group_keys = sorted(k for k in groups if k not in set(negative_group_keys))
    
    rng = np.random.RandomState(seed)
    rng.shuffle(positive_group_keys)
    
    n_pos = len(positive_group_keys)
    n_train = int(ratios[0] * n_pos)
    n_val = int(ratios[1] * n_pos)
    
    group_assignment = {}
    for k in positive_group_keys[:n_train]:
        group_assignment[k] = 'train'
    for k in positive_group_keys[n_train:n_train + n_val]:
        group_assignment[k] = 'val'
    for k in positive_group_keys[n_train + n_val:]:
        group_assignment[k] = 'test'
        
    # Distribusikan sampel negatif secara proporsional (3 train, 1 val, 1 test)
    neg_shuffled = sorted(negative_group_keys)
    rng.shuffle(neg_shuffled)
    neg_distribution = ['train', 'train', 'train', 'val', 'test']
    for k, split_name in zip(neg_shuffled, neg_distribution):
        group_assignment[k] = split_name
    for k in neg_shuffled[len(neg_distribution):]:
        group_assignment[k] = 'train'
        
    image_split = {}
    for k, ids in groups.items():
        for img_id in ids:
            image_split[img_id] = group_assignment[k]
            
    return image_split, group_assignment

image_to_split, group_to_split = split_by_groups(data_groups, seed=42)

# Hitung statistik kebocoran data pada pasangan serupa lintas split
cross_split_pairs = [
    p for p in duplicate_pairs
    if image_to_split[all_image_ids[p[0]]] != image_to_split[all_image_ids[p[1]]]
]
leakage_rate = (len(cross_split_pairs) / len(duplicate_pairs) * 100.0) if duplicate_pairs else 0.0

print("=== DISTRIBUSI SPLIT DATASET ===")
split_counts = {s: {'images': 0, 'boxes': 0, 'negatives': 0} for s in ('train', 'val', 'test')}
split_manifest = {'train': [], 'val': [], 'test': []}

for img_id, info in images_dict.items():
    s_name = image_to_split[img_id]
    n_boxes = len(boxes_dict.get(img_id, []))
    split_counts[s_name]['images'] += 1
    split_counts[s_name]['boxes'] += n_boxes
    if n_boxes == 0:
        split_counts[s_name]['negatives'] += 1
    split_manifest[s_name].append(info['file_name'])

print(json.dumps(split_counts, indent=2))
print(f"Cross-split duplicate leakage rate: {leakage_rate:.2f}% ({len(cross_split_pairs)}/{len(duplicate_pairs)} pasangan)")

# %% [markdown]
# ## 6. Konversi Koordinat ke Format YOLO dan Ekspor File

# %%
# Siapkan struktur folder YOLO
for s in ('train', 'val', 'test'):
    os.makedirs(os.path.join(output_dir, 'images', s), exist_ok=True)
    os.makedirs(os.path.join(output_dir, 'labels', s), exist_ok=True)

def convert_bbox_to_yolo(bbox, img_w, img_h):
    x, y, w, h = [float(v) for v in bbox]
    x_center = min(1.0, max(0.0, (x + w / 2.0) / img_w))
    y_center = min(1.0, max(0.0, (y + h / 2.0) / img_h))
    norm_w = min(1.0, max(0.0, w / img_w))
    norm_h = min(1.0, max(0.0, h / img_h))
    return f"0 {x_center:.6f} {y_center:.6f} {norm_w:.6f} {norm_h:.6f}"

copied_images = 0
for img_id, info in images_dict.items():
    split_name = image_to_split[img_id]
    file_name = info['file_name']
    src_file_path = image_paths.get(file_name)
    
    if not src_file_path or not os.path.exists(src_file_path):
        continue
        
    # Salin citra ke folder split
    dst_img_path = os.path.join(output_dir, 'images', split_name, file_name)
    shutil.copy(src_file_path, dst_img_path)
    copied_images += 1
    
    # Tulis label YOLO txt
    img_w, img_h = float(info['width']), float(info['height'])
    yolo_lines = [convert_bbox_to_yolo(b, img_w, img_h) for b in boxes_dict.get(img_id, [])]
    
    label_stem = os.path.splitext(file_name)[0]
    dst_label_path = os.path.join(output_dir, 'labels', split_name, f"{label_stem}.txt")
    with open(dst_label_path, 'w') as f:
        if yolo_lines:
            f.write('\n'.join(yolo_lines) + '\n')

print(f"Total citra berhasil disalin: {copied_images}")
for s in ('train', 'val', 'test'):
    n_imgs = len(os.listdir(os.path.join(output_dir, 'images', s)))
    n_lbls = len(os.listdir(os.path.join(output_dir, 'labels', s)))
    print(f"  Split {s:<5}: {n_imgs} gambar | {n_lbls} label txt")

# %% [markdown]
# ## 7. Pembuatan data.yaml dan Ekspor Manifest Split

# %%
yaml_config = {
    'path': output_dir,
    'train': 'images/train',
    'val': 'images/val',
    'test': 'images/test',
    'names': {0: 'license_plate'}
}

with open(os.path.join(output_dir, 'data.yaml'), 'w') as f:
    yaml.dump(yaml_config, f, sort_keys=False)

print("Konfigurasi data.yaml:")
with open(os.path.join(output_dir, 'data.yaml')) as f:
    print(f.read())

# Hitung statistik per split (stratified)
stratified_info = {}
for s in ('train', 'val', 'test'):
    h_native_list = []
    h_rel_list = []
    ar_list = []
    cctv_img_count = 0
    cctv_box_count = 0
    
    for img_id, info in images_dict.items():
        if image_to_split[img_id] != s:
            continue
        is_cctv = (get_source_category(info['file_name']) == 'CCTV')
        if is_cctv:
            cctv_img_count += 1
            
        img_h = float(info['height'])
        for b in boxes_dict.get(img_id, []):
            bh = float(b[3])
            bw = float(b[2])
            h_native_list.append(bh)
            h_rel_list.append(bh / img_h if img_h > 0 else 0.0)
            ar_list.append(bw / bh if bh > 0 else 0.0)
            if is_cctv:
                cctv_box_count += 1
                
    h_arr = np.array(h_native_list) if h_native_list else np.array([0.0])
    stratified_info[s] = {
        'images': split_counts[s]['images'],
        'boxes': split_counts[s]['boxes'],
        'negatives': split_counts[s]['negatives'],
        'cctv_images': cctv_img_count,
        'cctv_boxes': cctv_box_count,
        'h_native_median': round(float(np.median(h_arr)), 1),
        'ar_median': round(float(np.median(ar_list)), 2) if ar_list else 0.0,
        'frac_h_native_lt_8px': round(float((h_arr < 8).mean()), 4) if h_native_list else 0.0
    }

# Simpan metadata split lengkap
detector_splits_meta = {
    'grouping_scheme': 'cctv_chunk_8_frames',
    'seed': 42,
    'counts': split_counts,
    'stratified': stratified_info,
    'splits': split_manifest,
    'leakage': {
        'duplicate_pairs_checked': len(duplicate_pairs),
        'cross_split_duplicates': len(cross_split_pairs),
        'leakage_rate_pct': round(leakage_rate, 2)
    }
}

with open('/kaggle/working/detector_splits.json', 'w') as f:
    json.dump(detector_splits_meta, f, indent=2)

print("Saved: /kaggle/working/detector_splits.json")

# %% [markdown]
# ## 8. Pengecekan dan Pencatatan Bounding Box Anomali

# %%
suspect_records = []
for img_id, info in images_dict.items():
    for b in boxes_dict.get(img_id, []):
        h = float(b[3])
        w = float(b[2])
        ar = (w / h) if h > 0 else 0.0
        
        if ar < 1.5 or h < 8:
            suspect_records.append({
                'file_name': info['file_name'],
                'split': image_to_split[img_id],
                'source': get_source_category(info['file_name']),
                'xywh': [float(v) for v in b],
                'ar': round(ar, 3),
                'h_px': round(h, 1)
            })

print(f"Total BBox anomali (ar < 1.5 atau h < 8px): {len(suspect_records)}")
with open('/kaggle/working/suspect_boxes.json', 'w') as f:
    json.dump({'total_suspects': len(suspect_records), 'suspects': suspect_records}, f, indent=2)

print("Saved: /kaggle/working/suspect_boxes.json")

# %% [markdown]
# ## 9. Verifikasi Visual Bounding Box Format YOLO

# %%
# Plot 20 sampel acak dari split val dan test untuk memverifikasi normalisasi koordinat YOLO
val_test_samples = []
for s in ('val', 'test'):
    for fn in split_manifest[s]:
        val_test_samples.append((s, fn))

rng = np.random.RandomState(42)
rng.shuffle(val_test_samples)
sample_subset = val_test_samples[:20]

fig, axes = plt.subplots(4, 5, figsize=(20, 14))
axes = np.atleast_1d(axes).ravel()

for ax, (s_name, fn) in zip(axes, sample_subset):
    img_path = os.path.join(output_dir, 'images', s_name, fn)
    img = cv2.imread(img_path)
    if img is None:
        ax.axis('off')
        continue
        
    H, W = img.shape[:2]
    lbl_file = os.path.join(output_dir, 'labels', s_name, f"{os.path.splitext(fn)[0]}.txt")
    box_count = 0
    
    if os.path.exists(lbl_file):
        with open(lbl_file, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) == 5:
                    _, xc, yc, bw, bh = [float(val) for val in parts]
                    x1 = int((xc - bw / 2.0) * W)
                    y1 = int((yc - bh / 2.0) * H)
                    x2 = int((xc + bw / 2.0) * W)
                    y2 = int((yc + bh / 2.0) * H)
                    cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 2)
                    box_count += 1
                    
    ax.imshow(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    ax.set_title(f"[{s_name}] {fn[:22]}... ({box_count} plat)", fontsize=8)
    ax.axis('off')

plt.tight_layout()
plt.savefig('/kaggle/working/verification_yolo_boxes.png', dpi=120, bbox_inches='tight')
plt.show()

print("Verifikasi visual selesai. Gambar disimpan ke 'verification_yolo_boxes.png'.")
