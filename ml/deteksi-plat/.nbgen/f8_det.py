# %% [markdown]
# # Ekspor Model Detektor Plat Nomor (YOLOv8n) ke Format TFLite
#
# Notebook ini mengonversi model detektor plat nomor (`best_detector.pt`) ke format TensorFlow Lite (`.tflite`).
# Format ini disiapkan untuk diintegrasikan ke dalam aplikasi mobile (Flutter menggunakan library `tflite_flutter`).

# %% [markdown]
# ## 1. Setup Environment dan Penyiapan Bobot di Direktori Kerja

# %%
import os
import glob
import shutil
import numpy as np
import tensorflow as tf

print(f"Versi TensorFlow: {tf.__version__}")

# Cari file bobot terbaik dari kernel training
weight_candidates = glob.glob('/kaggle/input/**/best_detector.pt', recursive=True)
if not weight_candidates:
    weight_candidates = glob.glob('/kaggle/input/**/best.pt', recursive=True)

if not weight_candidates:
    raise FileNotFoundError("Bobot model tidak ditemukan di /kaggle/input")

src_weights = weight_candidates[0]
local_weights = '/kaggle/working/best_detector.pt'

# Salin bobot ke /kaggle/working agar direktori ekspor memiliki izin write (read-write)
shutil.copy(src_weights, local_weights)
print(f"Bobot disalin ke: {local_weights}")
print(f"Ukuran PyTorch   : {os.path.getsize(local_weights) / (1024 * 1024):.2f} MB")

# %% [markdown]
# ## 2. Ekspor ke Format TFLite Menggunakan Ultralytics

# %%
!pip install -q ultralytics

from ultralytics import YOLO

# Load model dari direktori kerja
model = YOLO(local_weights)
print("Model YOLOv8n berhasil dimuat.")

# Ekspor resolusi 640x640 (standar mobile)
print("\n--- Memulai ekspor TFLite (imgsz=640) ---")
export_res_640 = model.export(format='tflite', imgsz=640)
print(f"Hasil ekspor 640: {export_res_640}")

# Ekspor resolusi 1280x1280 (resolusi penuh CCTV)
print("\n--- Memulai ekspor TFLite (imgsz=1280) ---")
export_res_1280 = model.export(format='tflite', imgsz=1280)
print(f"Hasil ekspor 1280: {export_res_1280}")

# %% [markdown]
# ## 3. Manajemen dan Penamaan File Hasil Ekspor

# %%
tflite_candidates = glob.glob('/kaggle/working/**/*.tflite', recursive=True)
print(f"Total file .tflite ditemukan: {len(tflite_candidates)}")

final_640 = '/kaggle/working/plate_detector_640.tflite'
final_1280 = '/kaggle/working/plate_detector_1280.tflite'

for f in tflite_candidates:
    size_mb = os.path.getsize(f) / (1024 * 1024)
    print(f"  Ditemukan: {f} ({size_mb:.2f} MB)")
    if '1280' in f or '1280' in os.path.dirname(f):
        shutil.copy(f, final_1280)
    else:
        shutil.copy(f, final_640)

# Buat salinan standar dengan nama plate_detector.tflite
if os.path.exists(final_640):
    shutil.copy(final_640, '/kaggle/working/plate_detector.tflite')

print("\n=== RINGKASAN FILE MODEL TFLITE SIAP PAKAI ===")
for out_f in ['/kaggle/working/plate_detector.tflite', final_640, final_1280]:
    if os.path.exists(out_f):
        print(f"  {out_f} -> {os.path.getsize(out_f) / (1024 * 1024):.2f} MB")

# %% [markdown]
# ## 4. Verifikasi Model TFLite dengan TensorFlow Lite Interpreter

# %%
def verify_tflite(model_path):
    print("=" * 60)
    print(f"Verifikasi: {os.path.basename(model_path)}")
    print("=" * 60)
    
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    
    inputs = interpreter.get_input_details()
    outputs = interpreter.get_output_details()
    
    print("Input Specification:")
    for inp in inputs:
        print(f"  Name : {inp['name']}")
        print(f"  Shape: {inp['shape']}")
        print(f"  Type : {inp['dtype']}")
        
    print("\nOutput Specification:")
    for out in outputs:
        print(f"  Name : {out['name']}")
        print(f"  Shape: {out['shape']}")
        print(f"  Type : {out['dtype']}")
        
    # Uji inferensi dummy input
    dummy_input = np.random.uniform(0.0, 1.0, size=inputs[0]['shape']).astype(inputs[0]['dtype'])
    interpreter.set_tensor(inputs[0]['index'], dummy_input)
    interpreter.invoke()
    dummy_output = interpreter.get_tensor(outputs[0]['index'])
    print(f"\nInferensi dummy berhasil! Output shape: {dummy_output.shape}")

if os.path.exists('/kaggle/working/plate_detector.tflite'):
    verify_tflite('/kaggle/working/plate_detector.tflite')

if os.path.exists(final_1280):
    verify_tflite(final_1280)

print("\nEkspor dan verifikasi seluruh model TFLite selesai.")
