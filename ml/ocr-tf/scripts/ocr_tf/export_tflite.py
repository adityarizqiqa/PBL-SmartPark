"""Fase 5: Export the TF OCR model to TFLite and verify parity.

Exports:
  ocr_model_fp32.tflite  (full precision)
  ocr_model_fp16.tflite  (FP16 quantized - deployment target)

Parity test: run N images through Keras and TFLite interpreter, compare
argmax-decoded strings and MAE of logits. Acceptance: string match >= 99%,
EM degradation < 1%.
"""
import argparse
import csv
import json
import time
from pathlib import Path

import cv2
import numpy as np
import tensorflow as tf

ROOT = Path(r"D:\CollegeFile\SMT 5\SmartPark-OCR")
DATA = ROOT / "reports" / "data_v2" / "tf"
RUNS = ROOT / "reports" / "data_v2" / "tfocr"
OUT = ROOT / "reports" / "data_v2" / "tflite"

BLANK = 0
CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def greedy_decode(logits, blank=BLANK):
    ids = np.argmax(logits, axis=-1)
    out = []
    for seq in ids:
        chars, prev = [], None
        for t in seq:
            if t != prev and t != blank:
                chars.append(CHARS[t - 1] if 1 <= t <= 36 else "")
            prev = int(t)
        out.append("".join(chars))
    return out


def edit_distance(a, b):
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        cur = [i] + [0] * len(b)
        for j in range(1, len(b) + 1):
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] != b[j - 1]))
        prev = cur
    return prev[-1]


def cer_em(preds, gts):
    tot = sum(len(g) for g in gts)
    err = sum(edit_distance(p, g) for p, g in zip(preds, gts))
    cer = err / max(1, tot)
    em = sum(1 for p, g in zip(preds, gts) if p == g)
    return cer, em


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=str(RUNS / "tfocr_v2_seed42" / "ocr_model.keras"))
    ap.add_argument("--split", default="val")
    ap.add_argument("--limit", type=int, default=0, help="0 = all")
    ap.add_argument("--out", default=str(OUT))
    a = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    model = tf.keras.models.load_model(a.model)

    # load data
    X = np.load(DATA / "split" / f"X_{a.split}.npy").astype("float32") / 255.0
    labels = []
    with open(DATA / "split" / f"y_{a.split}.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            labels.append(r["label"])
    if a.limit:
        X = X[:a.limit]; labels = labels[:a.limit]

    # 1) Keras inference
    t0 = time.time()
    logits_k = model.predict(X, batch_size=32, verbose=0)
    keras_time = (time.time() - t0) / len(X) * 1000
    preds_k = greedy_decode(logits_k)
    cer_k, em_k = cer_em(preds_k, labels)
    print(f"Keras  : CER {cer_k:.4f} | EM {em_k}/{len(labels)} | {keras_time:.2f} ms/img")

    # 2) Export FP32
    conv32 = tf.lite.TFLiteConverter.from_keras_model(model)
    fp32 = conv32.convert()
    fp32_path = Path(a.out) / "ocr_model_fp32.tflite"
    fp32_path.write_bytes(fp32)

    # 3) Export FP16
    conv16 = tf.lite.TFLiteConverter.from_keras_model(model)
    conv16.optimizations = [tf.lite.Optimize.DEFAULT]
    conv16.target_spec.supported_types = [tf.float16]
    fp16 = conv16.convert()
    fp16_path = Path(a.out) / "ocr_model_fp16.tflite"
    fp16_path.write_bytes(fp16)

    # 4) Parity test with FP16 TFLite interpreter
    interp = tf.lite.Interpreter(model_path=str(fp16_path))
    interp.allocate_tensors()
    inp = interp.get_input_details()[0]
    out = interp.get_output_details()[0]
    print(f"TFLite input : {inp['shape']} {inp['dtype']}")
    print(f"TFLite output: {out['shape']} {out['dtype']}")

    t0 = time.time()
    preds_t, logits_t_all = [], []
    for i in range(len(X)):
        interp.set_tensor(inp["index"], X[i:i+1])
        interp.invoke()
        lg = interp.get_tensor(out["index"])
        logits_t_all.append(lg)
        preds_t.extend(greedy_decode(lg))
    tfl_time = (time.time() - t0) / len(X) * 1000
    cer_t, em_t = cer_em(preds_t, labels)
    print(f"TFLite : CER {cer_t:.4f} | EM {em_t}/{len(labels)} | {tfl_time:.2f} ms/img")

    # 5) Parity metrics
    match = sum(1 for a_, b_ in zip(preds_k, preds_t) if a_ == b_)
    match_pct = 100 * match / max(1, len(preds_k))
    mae = float(np.mean([np.abs(lg_k - lg_t).mean()
                         for lg_k, lg_t in zip(logits_k, logits_t_all)]))
    em_drop = em_k - em_t

    results = {
        "model": a.model,
        "keras": {"cer": round(cer_k, 4), "em": em_k, "n": len(labels), "latency_ms": round(keras_time, 2)},
        "tflite_fp16": {"cer": round(cer_t, 4), "em": em_t, "latency_ms": round(tfl_time, 2)},
        "parity": {"string_match_pct": round(match_pct, 2), "logit_mae": round(mae, 6),
                    "em_degradation": em_k - em_t},
        "tflite_sizes_mb": {"fp32": round(len(fp32) / 1e6, 2), "fp16": round(len(fp16) / 1e6, 2)},
    }
    (Path(a.out) / "tflite_parity.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(json.dumps(results, indent=2))

    print("saved", Path(a.out) / "tflite_parity.json")


if __name__ == "__main__":
    main()
