# Fase 5: Training Model OCR Recognizer (CNN-2D + TCN + CTC Loss)

## 1. Tujuan
Melatih model pembaca karakter plat nomor (Recognizer) secara independen menggunakan arsitektur konvolusional murni (CNN-2D + Stacked Conv-1D / TCN) dengan CTCLoss dari scratch di Kaggle GPU, yang menjamin ketiadaan operator recurrent (LSTM/GRU) sehingga 100% kompatibel saat diekspor ke TFLite.

---

## 2. Rincian Pekerjaan

### A. Desain Arsitektur Bebas Recurrent (TFLite-Native)
Arsitektur didesain tanpa lapisan RNN demi menjaga stabilitas inferensi paralel pada mobile NPU/GPU dan menghindari *crash* akibat unsupported custom ops pada runtime Flutter:

1. **Dimensi Masukan**:
   - PyTorch Layout: `(B, 1, 32, 128)` (Float32, Grayscale).
   - TFLite Layout: `(B, 32, 128, 1)`.
2. **Backbone Ekstraksi Fitur Visual (CNN-2D Asymmetric Pooling)**:
   - *Block 1*: Conv2D(1 $\rightarrow$ 64, kernel 3) + BatchNorm + ReLU + MaxPool2D(2, 2) $\rightarrow$ `(B, 64, 16, 64)`
   - *Block 2*: Conv2D(64 $\rightarrow$ 128, kernel 3) + BatchNorm + ReLU + MaxPool2D(2, 2) $\rightarrow$ `(B, 128, 8, 32)`
   - *Block 3*: Conv2D(128 $\rightarrow$ 256, kernel 3) + BatchNorm + ReLU + MaxPool2D((2, 1)) $\rightarrow$ `(B, 256, 4, 32)`
   - *Block 4*: Conv2D(256 $\rightarrow$ 256, kernel 3) + BatchNorm + ReLU + MaxPool2D((4, 1)) $\rightarrow$ `(B, 256, 1, 32)`
   - *Reshape / Permute*: Squeeze dimensi tinggi citra yang sudah tereduksi menjadi 1, menghasilkan representasi sekuensial tepat `(B, T=32, D=256)`. Penurunan lebar hanya dilakukan dua kali ($128 \rightarrow 64 \rightarrow 32$), sedangkan tinggi direduksi penuh ($32 \rightarrow 16 \rightarrow 8 \rightarrow 4 \rightarrow 1$).
3. **Pemodel Sekuens Karakter (Stacked Dilated Conv-1D / TCN)**:
   - 3 blok Konvolusi 1D (kernel size 3) dengan laju dilatasi bertingkat ($d = 1, 2, 4$) dan padding sama untuk menangkap konteks karakter kiri-kanan dengan receptive field lebar.
   - Dilengkapi koneksi residual (*residual connection*) dan Dropout 0.15.
4. **Lapisan Proyeksi CTC**:
   - Linear layer memetakan feature dimension $256 \rightarrow 37$ kelas logit probabilitas karakter per timestep.

### B. Loss Function & Pengaturan Pelatihan
1. **Fungsi Loss**:
   - `torch.nn.CTCLoss(blank=0, reduction='mean', zero_infinity=True)`
   - Menghubungkan sekuens logit panjang $T=32$ dengan label teks ground-truth panjang $5\text{--}9$ karakter tanpa perlu anotasi batas karakter per piksel.
2. **Optimizer & Scheduler**:
   - Optimizer: AdamW (bobot decay $1 \times 10^{-4}$, initial learning rate $1 \times 10^{-3}$).
   - Scheduler: Cosine Annealing Learning Rate hingga $1 \times 10^{-5}$.
   - Epochs: 60 epoch.
   - Batch size: 32 atau 64.

### C. Augmentasi Khusus Selama Training OCR
- **Inversi Polaritas Warna Acak (50%)**: Membalikkan citra secara random ($1.0 - x$) agar model terbiasa mengenali plat hitam tulisan putih dan plat putih tulisan hitam tanpa membutuhkan model ganda.
- **Noise & Blur**: Gaussian noise ringan dan motion blur horizontal (mensimulasikan laju kendaraan).
- **Random Brightness & Contrast**: Variasi intensitas pencahayaan $\pm 20\%$.

### D. Monitoring & Checkpointing
- Evaluasi validasi per epoch:
  - Validation CTCLoss.
  - **Exact Match (EM)**: Persentase plat nomor yang seluruh karakternya terbaca tepat 100%.
  - **Character Error Rate (CER)**: Menggunakan Normalized Levenshtein Distance.
- Simpan checkpoint terbaik berdasarkan EM tertinggi pada validasi: `best_ocr.pt`.

---

## 3. Checklist Eksekusi Fase 5
- [ ] Implementasikan kelas arsitektur `PlateOCR_TCN` berbasis PyTorch dengan asymmetric pooling.
- [ ] Verifikasi shape output tensor sekuensial tepat `(B, 32, 37)`.
- [ ] Susun DataLoader dengan augmentasi inversi polaritas kontras dan noise.
- [ ] Latih model OCR selama 60 epoch di GPU Kaggle.
- [ ] Pantau kurva CER dan Exact Match validasi per epoch.
- [ ] Simpan checkpoint model terbaik `best_ocr.pt`.

---

## 4. Kriteria Keberhasilan (Acceptance Criteria)
- Exact Match (EM) $\ge 82\%$ pada validation set OCR.
- Character Error Rate (CER) $\le 0.08$ pada validation set OCR.
- Arsitektur bebas dari layer recurrent / LSTM (siap untuk konversi TFLite).
