# %% [markdown]
# # Training Model Pengenalan Karakter Plat Nomor (CNN-2D + TCN + CTC Loss)
#
# Notebook ini melatih model pembaca karakter plat nomor kendaraan Indonesia secara mandiri.
# Arsitektur dirancang konvolusional murni (free of recurrent layers / RNN / LSTM) agar 100% kompatibel dan ringan saat diekspor ke TensorFlow Lite untuk aplikasi mobile (Flutter).
# Model menerima input citra Grayscale 32x128 dan menghasilkan sekuens prediksi 37 token karakter menggunakan Connectionist Temporal Classification (CTC Loss).

# %% [markdown]
# ## 1. Setup Environment dan Akselerasi GPU

# %%
import os
import glob
import json
import time
import zipfile
import shutil

import numpy as np
import pandas as pd
import cv2
import matplotlib.pyplot as plt

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader

# Konfigurasi peranti komputasi
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"PyTorch Version: {torch.__version__}")
print(f"Peranti Latih  : {device}")
if torch.cuda.is_available():
    print(f"Nama GPU       : {torch.cuda.get_device_name(0)}")
    print(f"VRAM Tersedia  : {torch.cuda.get_device_properties(0).total_memory / (1024**3):.2f} GB")

# %% [markdown]
# ## 2. Ekstraksi dan Penyiapan Dataset dari Fase 4

# %%
# Cari file dataset dan manifest dari output kernel Fase 4
zip_candidates = glob.glob('/kaggle/input/**/ocr_dataset.zip', recursive=True)
csv_candidates = glob.glob('/kaggle/input/**/train_ocr.csv', recursive=True)
vocab_candidates = glob.glob('/kaggle/input/**/vocab.json', recursive=True)

if not zip_candidates and not csv_candidates:
    raise FileNotFoundError("Artefak Fase 4 (ocr_dataset.zip / train_ocr.csv) tidak ditemukan di /kaggle/input")

base_input_dir = os.path.dirname(csv_candidates[0])
vocab_path = vocab_candidates[0]
train_csv_path = glob.glob('/kaggle/input/**/train_ocr.csv', recursive=True)[0]
val_csv_path = glob.glob('/kaggle/input/**/val_ocr.csv', recursive=True)[0]
test_csv_path = glob.glob('/kaggle/input/**/test_ocr.csv', recursive=True)[0]

# Ekstrak ocr_dataset.zip ke /kaggle/working/data jika berbentuk zip
data_root = '/kaggle/working/data'
if zip_candidates:
    print(f"Mengekstrak {zip_candidates[0]} ke {data_root}...")
    with zipfile.ZipFile(zip_candidates[0], 'r') as zip_ref:
        zip_ref.extractall(data_root)
    print("Ekstraksi dataset selesai.")
else:
    # Jika folder sudah langsung diekstrak di input
    unzipped_dir = glob.glob('/kaggle/input/**/ocr_dataset', recursive=True)
    data_root = unzipped_dir[0] if unzipped_dir else base_input_dir

# Load kamus token
with open(vocab_path, 'r') as f:
    vocab = json.load(f)

char_to_idx = vocab['char_to_idx']
idx_to_char = {int(k): v for k, v in vocab['idx_to_char'].items()}
BLANK_IDX = vocab['blank_index']
NUM_CLASSES = vocab['total_tokens']

print(f"Total vocabulary token: {NUM_CLASSES} (Blank index: {BLANK_IDX})")

df_train = pd.read_csv(train_csv_path)
df_val = pd.read_csv(val_csv_path)
df_test = pd.read_csv(test_csv_path)

print(f"Data manifest: Train={len(df_train)}, Val={len(df_val)}, Test={len(df_test)}")

# %% [markdown]
# ## 3. PyTorch Dataset dan Data Augmentation

# %%
class PlateOCRDataset(Dataset):
    def __init__(self, df, data_dir, char_to_idx, is_training=False):
        self.df = df
        self.data_dir = data_dir
        self.char_to_idx = char_to_idx
        self.is_training = is_training

    def __len__(self):
        return len(self.df)

    def __getitem__(self, idx):
        row = self.df.iloc[idx]
        rel_p = row['rel_path']
        
        # Resolusi path gambar
        img_p = os.path.join(self.data_dir, rel_p)
        if not os.path.exists(img_p):
            img_p = os.path.join(self.data_dir, 'ocr_dataset', rel_p)
        if not os.path.exists(img_p):
            cands = glob.glob(f"{self.data_dir}/**/{row['filename']}", recursive=True)
            img_p = cands[0] if cands else img_p
            
        img = cv2.imread(img_p, cv2.IMREAD_GRAYSCALE)
        if img is None:
            img = np.zeros((48, 192), dtype=np.uint8)
        # Normalisasi ke Float32 [0.0, 1.0]
        img = img.astype(np.float32) / 255.0

        # Augmentasi data saat training
        if self.is_training:
            # 1. Random Color Inversion (50% peluang)
            # Meniru variasi plat hitam tulisan putih dan plat putih tulisan hitam
            if np.random.rand() < 0.50:
                img = 1.0 - img
                
            # 2. Random Brightness & Contrast Adjustment
            if np.random.rand() < 0.35:
                alpha = np.random.uniform(0.8, 1.2) # Kontras
                beta = np.random.uniform(-0.1, 0.1) # Kecerahan
                img = np.clip(img * alpha + beta, 0.0, 1.0)
                
            # 3. Random Gaussian Noise
            if np.random.rand() < 0.25:
                noise = np.random.normal(0.0, 0.03, img.shape).astype(np.float32)
                img = np.clip(img + noise, 0.0, 1.0)

        # Ubah dimensi ke layout PyTorch: [Channels=1, Height=32, Width=128]
        tensor_img = torch.tensor(img, dtype=torch.float32).unsqueeze(0)
        
        # Encode label teks ke indeks integer
        text = str(row['clean_text'])
        target = [self.char_to_idx[c] for c in text if c in self.char_to_idx]
        target = torch.tensor(target, dtype=torch.long)
        
        return tensor_img, target, text

def ocr_collate_fn(batch):
    images, targets, texts = zip(*batch)
    images = torch.stack(images, dim=0)
    target_lengths = torch.tensor([len(t) for t in targets], dtype=torch.long)
    targets = torch.cat(targets, dim=0)
    return images, targets, target_lengths, texts

# Inisialisasi DataLoaders
BATCH_SIZE = 32

train_dataset = PlateOCRDataset(df_train, data_root, char_to_idx, is_training=True)
val_dataset = PlateOCRDataset(df_val, data_root, char_to_idx, is_training=False)
test_dataset = PlateOCRDataset(df_test, data_root, char_to_idx, is_training=False)

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True, collate_fn=ocr_collate_fn, num_workers=2)
val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False, collate_fn=ocr_collate_fn, num_workers=2)
test_loader = DataLoader(test_dataset, batch_size=BATCH_SIZE, shuffle=False, collate_fn=ocr_collate_fn, num_workers=2)

print(f"DataLoader siap: Train={len(train_loader)} batch, Val={len(val_loader)} batch, Test={len(test_loader)} batch")

# %% [markdown]
# ## 4. Arsitektur Model OCR (CNN-2D + TCN + CTC Head)

# %%
class TemporalConvBlock(nn.Module):
    """
    Blok Temporal Convolutional Network (TCN) berbasis Konvolusi 1D Dilatasi.
    Menggantikan peran recurrent layer (LSTM) agar inferensi fully-parallel dan bebas custom ops di TFLite.
    """
    def __init__(self, in_channels, out_channels, dilation, dropout=0.15):
        super().__init__()
        self.conv1 = nn.Conv1d(
            in_channels, out_channels, kernel_size=3,
            padding=dilation, dilation=dilation
        )
        self.bn1 = nn.BatchNorm1d(out_channels)
        self.relu = nn.ReLU(inplace=True)
        self.dropout = nn.Dropout(dropout)
        self.conv2 = nn.Conv1d(
            out_channels, out_channels, kernel_size=3,
            padding=dilation, dilation=dilation
        )
        self.bn2 = nn.BatchNorm1d(out_channels)
        
        self.residual = nn.Conv1d(in_channels, out_channels, 1) if in_channels != out_channels else nn.Identity()

    def forward(self, x):
        res = self.residual(x)
        out = self.dropout(self.relu(self.bn1(self.conv1(x))))
        out = self.dropout(self.bn2(self.conv2(out)))
        return self.relu(out + res)

class PlateOCRNet(nn.Module):
    """
    Arsitektur OCR Recurrent-Free (48x192 High Resolution):
    1. CNN-2D dengan Asymmetric Pooling: Mengubah citra [B, 1, 48, 192] menjadi sekuensial [B, 48, 128].
    2. Stacked Dilated Conv-1D (TCN): Memodelkan konteks urutan huruf kanan-kiri.
    3. Linear Head Proyeksi: Menghasilkan Logits [B, 48, 37].
    """
    def __init__(self, num_classes=37):
        super().__init__()
        
        # 1. Feature Extractor Visual CNN-2D
        self.backbone = nn.Sequential(
            # Blok 1: (B, 1, 48, 192) -> (B, 32, 24, 96)
            nn.Conv2d(1, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2, 2),
            
            # Blok 2: (B, 32, 24, 96) -> (B, 64, 12, 48)
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2, 2),
            
            # Blok 3: (B, 64, 12, 48) -> (B, 128, 4, 48) [Pooling asimetris: tinggi direduksi, lebar dipertahankan]
            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=(3, 1), stride=(3, 1)),
            
            # Blok 4: (B, 128, 4, 48) -> (B, 128, 1, 48)
            nn.Conv2d(128, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=(4, 1), stride=(4, 1))
        )
        
        # 2. Sequence Context Modeler (TCN / Dilated Conv-1D)
        self.tcn = nn.Sequential(
            TemporalConvBlock(128, 128, dilation=1, dropout=0.20),
            TemporalConvBlock(128, 128, dilation=2, dropout=0.20),
            TemporalConvBlock(128, 128, dilation=4, dropout=0.20)
        )
        
        # 3. CTC Projection Head (128 -> 37 Logits per timestep)
        self.dropout = nn.Dropout(0.25)
        self.classifier = nn.Linear(128, num_classes)
    def forward(self, x):
        # x: [Batch, 1, 48, 192]
        feat = self.backbone(x) # [Batch, 128, 1, 48]
        feat = feat.squeeze(2)  # [Batch, 128, 48]
        
        # Sequence modeling sepanjang time-step T=48
        seq = self.tcn(feat)    # [Batch, 128, 48]
        seq = seq.permute(0, 2, 1) # [Batch, 48, 128]
        
        logits = self.classifier(self.dropout(seq)) # [Batch, 48, 37]
        return logits

# Inisialisasi model dan verifikasi dimensi tensor
model = PlateOCRNet(num_classes=NUM_CLASSES).to(device)
dummy_tensor = torch.zeros((1, 1, 48, 192), device=device)
output_dummy = model(dummy_tensor)

total_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
est_fp16_mb = (total_params * 2) / (1024 ** 2)

print(f"Bentuk Output Dummy: {output_dummy.shape} -> (Batch, TimeSteps=48, Vocab={NUM_CLASSES})")
print(f"Total Parameter    : {total_params:,}")
print(f"Estimasi Ukuran FP16: {est_fp16_mb:.2f} MB (Target mobile <= 3 MB) -> {'OK' if est_fp16_mb <= 3.0 else 'LEBIH'}")

# %% [markdown]
# ## 5. Decoder CTC Greedy dan Metrik Evaluasi (EM & CER)

# %%
def decode_ctc_greedy(logits, idx_to_char, blank_idx=0):
    """
    Greedy CTC Decoding:
    1. Ambil argmax per timestep.
    2. Hapus token duplikat berturut-turut.
    3. Hapus token blank.
    """
    preds = torch.argmax(logits, dim=-1).cpu().numpy() # [B, T]
    decoded_strings = []
    
    for row in preds:
        prev_idx = -1
        char_list = []
        for idx in row:
            if idx != prev_idx:
                if idx != blank_idx:
                    char_list.append(idx_to_char.get(idx, ''))
                prev_idx = idx
        decoded_strings.append(''.join(char_list))
    return decoded_strings

def compute_levenshtein(s1, s2):
    """Menghitung jarak Levenshtein antara dua string."""
    m, n = len(s1), len(s2)
    dp = np.zeros((m + 1, n + 1), dtype=int)
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if s1[i - 1] == s2[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
    return dp[m][n]

def evaluate_metrics(model, dataloader, criterion, device):
    model.eval()
    total_loss = 0.0
    total_samples = 0
    exact_matches = 0
    total_edit_distance = 0
    total_reference_length = 0

    with torch.no_grad():
        for images, targets, target_lengths, ground_truths in dataloader:
            images = images.to(device)
            targets = targets.to(device)
            batch_size = images.size(0)

            logits = model(images) # [B, T, C]
            
            # CTC Loss format: input log_probs [T, B, C]
            log_probs = logits.log_softmax(2).permute(1, 0, 2)
            input_lengths = torch.full((batch_size,), logits.size(1), dtype=torch.long, device=device)
            
            loss = criterion(log_probs, targets, input_lengths, target_lengths)
            total_loss += loss.item() * batch_size
            total_samples += batch_size

            # Decode teks
            predicted_strings = decode_ctc_greedy(logits, idx_to_char, blank_idx=BLANK_IDX)
            
            for pred, gt in zip(predicted_strings, ground_truths):
                if pred == gt:
                    exact_matches += 1
                dist = compute_levenshtein(pred, gt)
                total_edit_distance += dist
                total_reference_length += max(len(gt), 1)

    mean_loss = total_loss / max(total_samples, 1)
    exact_match_rate = exact_matches / max(total_samples, 1)
    cer = total_edit_distance / max(total_reference_length, 1)
    
    return mean_loss, exact_match_rate, cer

# %% [markdown]
# ## 6. Training Loop (60 Epoch)

# %%
EPOCHS = 75
LEARNING_RATE = 8e-4
WEIGHT_DECAY = 1e-2

# CTCLoss PyTorch
criterion = nn.CTCLoss(blank=BLANK_IDX, reduction='mean', zero_infinity=True)

optimizer = optim.AdamW(model.parameters(), lr=LEARNING_RATE, weight_decay=WEIGHT_DECAY)
scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=EPOCHS, eta_min=1e-5)

best_val_em = 0.0
best_model_path = '/kaggle/working/best_ocr.pt'
history = []

print("=== MEMULAI TRAINING MODEL OCR ===")
start_train_time = time.time()

for epoch in range(1, EPOCHS + 1):
    model.train()
    running_loss = 0.0
    samples_count = 0
    
    for images, targets, target_lengths, _ in train_loader:
        images = images.to(device)
        targets = targets.to(device)
        batch_size = images.size(0)
        
        optimizer.zero_grad()
        logits = model(images) # [B, T, C]
        
        log_probs = logits.log_softmax(2).permute(1, 0, 2) # [T, B, C]
        input_lengths = torch.full((batch_size,), logits.size(1), dtype=torch.long, device=device)
        
        loss = criterion(log_probs, targets, input_lengths, target_lengths)
        loss.backward()
        
        # Gradient clipping untuk kestabilan CTCLoss
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=5.0)
        optimizer.step()
        
        running_loss += loss.item() * batch_size
        samples_count += batch_size

    scheduler.step()
    train_loss = running_loss / max(samples_count, 1)

    # Evaluasi validasi setiap epoch
    val_loss, val_em, val_cer = evaluate_metrics(model, val_loader, criterion, device)
    
    current_lr = optimizer.param_groups[0]['lr']
    history.append({
        'epoch': epoch,
        'train_loss': train_loss,
        'val_loss': val_loss,
        'val_em': val_em,
        'val_cer': val_cer,
        'lr': current_lr
    })
    
    # Simpan bobot terbaik berdasarkan Exact Match tertinggi
    if val_em > best_val_em:
        best_val_em = val_em
        torch.save(model.state_dict(), best_model_path)
        save_tag = f"(*) Model Terbaik Disimpan (EM: {val_em*100:.2f}%)"
    else:
        save_tag = ""

    if epoch % 5 == 0 or epoch == 1 or save_tag:
        print(f"Epoch [{epoch:02d}/{EPOCHS}] | Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | Val EM: {val_em*100:.2f}% | Val CER: {val_cer:.4f} | LR: {current_lr:.6f} {save_tag}")

total_duration_mins = (time.time() - start_train_time) / 60.0
print(f"\nTraining selesai dalam {total_duration_mins:.2f} menit.")
print(f"Best Validation Exact Match: {best_val_em*100:.2f}% (Tersimpan di: {best_model_path})")

# %% [markdown]
# ## 7. Kurva Pembelajaran (Loss, Exact Match, CER)

# %%
df_hist = pd.DataFrame(history)

fig, (ax1, ax2, ax3) = plt.subplots(1, 3, figsize=(18, 4.5))

# Plot Loss
ax1.plot(df_hist['epoch'], df_hist['train_loss'], label='Train Loss', color='crimson')
ax1.plot(df_hist['epoch'], df_hist['val_loss'], label='Val Loss', color='royalblue')
ax1.set_title('CTCLoss Curve')
ax1.set_xlabel('Epoch')
ax1.set_ylabel('Loss')
ax1.grid(True, alpha=0.3)
ax1.legend()

# Plot Exact Match (EM)
ax2.plot(df_hist['epoch'], df_hist['val_em'] * 100.0, label='Val Exact Match (%)', color='forestgreen')
ax2.axhline(82.0, color='black', linestyle='--', label='Target Rencana (82%)')
ax2.set_title('Validation Exact Match (%)')
ax2.set_xlabel('Epoch')
ax2.set_ylabel('Exact Match (%)')
ax2.grid(True, alpha=0.3)
ax2.legend()

# Plot Character Error Rate (CER)
ax3.plot(df_hist['epoch'], df_hist['val_cer'], label='Val CER', color='darkorange')
ax3.axhline(0.08, color='black', linestyle='--', label='Batas Target (0.08)')
ax3.set_title('Validation Character Error Rate (CER)')
ax3.set_xlabel('Epoch')
ax3.set_ylabel('CER')
ax3.grid(True, alpha=0.3)
ax3.legend()

plt.tight_layout()
plt.savefig('/kaggle/working/ocr_training_curves.png', dpi=120)
plt.show()

# %% [markdown]
# ## 8. Evaluasi Resmi pada Test Set & Sampel Prediksi

# %%
# Load bobot terbaik
model.load_state_dict(torch.load(best_model_path, map_location=device))

test_loss, test_em, test_cer = evaluate_metrics(model, test_loader, criterion, device)
print("=== HASIL EVALUASI TEST SET RESMI ===")
print(f"Test Set Loss        : {test_loss:.4f}")
print(f"Exact Match (EM)     : {test_em*100:.2f}% (Target: >= 82%)")
print(f"Character Error Rate : {test_cer:.4f} (Target: <= 0.08)")

# Visualisasikan 12 contoh prediksi pada data pengujian
model.eval()
test_sample_images, _, _, test_sample_gts = next(iter(test_loader))
with torch.no_grad():
    sample_logits = model(test_sample_images.to(device))
    sample_preds = decode_ctc_greedy(sample_logits, idx_to_char, blank_idx=BLANK_IDX)

fig, axes = plt.subplots(3, 4, figsize=(16, 7))
axes = axes.flatten()

for idx in range(min(12, len(test_sample_gts))):
    ax = axes[idx]
    img_disp = (test_sample_images[idx, 0].cpu().numpy() * 255.0).astype(np.uint8)
    gt = test_sample_gts[idx]
    pred = sample_preds[idx]
    
    is_correct = (pred == gt)
    color = 'green' if is_correct else 'red'
    
    ax.imshow(img_disp, cmap='gray')
    ax.set_title(f"GT  : {gt}\nPred: {pred}", color=color, fontsize=9, fontweight='bold')
    ax.axis('off')

plt.tight_layout()
plt.savefig('/kaggle/working/ocr_test_sample_predictions.png', dpi=120)
plt.show()

# %% [markdown]
# ## 9. Simpan Ringkasan Metrik Evaluasi

# %%
eval_summary = {
    'model_architecture': 'CNN2D_TCN_CTC',
    'total_parameters': int(total_params),
    'estimated_fp16_mb': round(est_fp16_mb, 2),
    'meets_mobile_budget': bool(est_fp16_mb <= 3.0),
    'training_epochs': EPOCHS,
    'training_duration_minutes': round(total_duration_mins, 2),
    'validation_metrics': {
        'best_exact_match': round(best_val_em, 4),
        'best_exact_match_pct': f"{best_val_em*100:.2f}%"
    },
    'test_metrics': {
        'loss': round(test_loss, 4),
        'exact_match': round(test_em, 4),
        'exact_match_pct': f"{test_em*100:.2f}%",
        'character_error_rate': round(test_cer, 4),
        'target_em_achieved': bool(test_em >= 0.82),
        'target_cer_achieved': bool(test_cer <= 0.08)
    },
    'weights_file': 'best_ocr.pt'
}

with open('/kaggle/working/ocr_eval_metrics.json', 'w') as f:
    json.dump(eval_summary, f, indent=2)

print("Saved: /kaggle/working/ocr_eval_metrics.json")
print(json.dumps(eval_summary, indent=2))
print("\nTraining dan evaluasi model OCR selesai.")
