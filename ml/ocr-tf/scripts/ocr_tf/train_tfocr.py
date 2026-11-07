"""Fase 2-4: TensorFlow/Keras OCR (CNN + TCN + CTC) training driver.

Contract:
  input  [48, 192, 1]  grayscale, [0,1]
  output [48, 37]      logits (greedy CTC decode)
  vocab  37 tokens, blank=0, digits 1-10, A-Z 11-36 (ml/deteksi-plat contract)

Architecture (recurrent-free, TFLite-safe):
  CNN 4 blocks with asymmetric pooling -> TCN (dilated Conv1D x3) -> Dense(37)

Usage:
  python scripts/ocr_tf/train_tfocr.py --epochs 80 --batch 32 --seed 42 \
      --manifest reports/data_v2/final_manifest.csv --tag tfocr_seed42
"""
import argparse
import csv
import json
import random
import statistics
import time
from pathlib import Path

import cv2
import numpy as np
import tensorflow as tf

ROOT = Path(r"D:\CollegeFile\SMT 5\SmartPark-OCR")
DATA = ROOT / "reports" / "data_v2" / "tf"
RUNS = ROOT / "reports" / "data_v2" / "tfocr"

SEED = 42
VOCAB = 37
BLANK = 0
IMG_H, IMG_W = 48, 192
CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def set_seed(seed):
    random.seed(seed); np.random.seed(seed); tf.random.set_seed(seed)


# ---------------------------------------------------------------- data

def load_np(split):
    X = np.load(DATA / "split" / f"X_{split}.npy")          # uint8 [N,48,192,1]
    X = X.astype("float32") / 255.0
    labels = []
    with open(DATA / "split" / f"y_{split}.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            labels.append(r["label"])
    return X, labels


def encode(labels, max_len=10):
    c2i = {c: i + 1 for i, c in enumerate(CHARS)}            # digits 1-10, A-Z 11-36
    targets = np.full((len(labels), max_len), BLANK, dtype=np.int32)
    tlen = np.zeros(len(labels), dtype=np.int32)
    for i, lab in enumerate(labels):
        ids = [c2i[c] for c in lab if c in c2i][:max_len]
        targets[i, :len(ids)] = ids
        tlen[i] = len(ids)
    return targets, tlen


def augment(x):
    """x: [48,192,1] float32 [0,1]. Returns same shape."""
    g = x.squeeze(-1)                                         # [48,192]
    if np.random.random() < 0.50:
        g = 1.0 - g
    if np.random.random() < 0.35:
        g = np.clip(g * np.random.uniform(0.8, 1.2) + np.random.uniform(-0.10, 0.10), 0, 1)
    if np.random.random() < 0.25:
        g = np.clip(g + np.random.normal(0, 0.03, g.shape), 0, 1)
    if np.random.random() < 0.20:
        M = np.float32([[1, 0, np.random.randint(-2, 3)], [0, 1, np.random.randint(-1, 2)]])
        g = cv2.warpAffine(g, M, (g.shape[1], g.shape[0]), borderValue=0)
    if np.random.random() < 0.15:
        g = cv2.GaussianBlur(g, (3, 3), 0)
    return np.expand_dims(g, axis=-1)


# ---------------------------------------------------------------- model

def build_model(vocab=VOCAB):
    inp = tf.keras.Input(shape=(IMG_H, IMG_W, 1), name="image")
    x = inp
    for filters, pool in ((32, (2, 2)), (64, (2, 2)), (128, (3, 1)), (128, (4, 1))):
        x = tf.keras.layers.Conv2D(filters, 3, padding="same", use_bias=False)(x)
        x = tf.keras.layers.BatchNormalization()(x)
        x = tf.keras.layers.ReLU()(x)
        x = tf.keras.layers.MaxPooling2D(pool)(x)             # height shrinks, width kept
    x = tf.keras.layers.Reshape((48, 128))(x)                 # [B, T=48, C=128]
    for dil in (1, 2, 4):                                     # TCN blocks (residual)
        y = tf.keras.layers.Conv1D(128, 3, padding="causal", dilation_rate=dil, use_bias=False)(x)
        y = tf.keras.layers.BatchNormalization()(y)
        y = tf.keras.layers.ReLU()(y)
        y = tf.keras.layers.Dropout(0.20)(y)
        y = tf.keras.layers.Conv1D(128, 3, padding="causal", dilation_rate=dil, use_bias=False)(y)
        y = tf.keras.layers.BatchNormalization()(y)
        y = tf.keras.layers.ReLU()(y)
        y = tf.keras.layers.Dropout(0.20)(y)
        x = tf.keras.layers.Add()([x, y])
        x = tf.keras.layers.ReLU()(x)
    x = tf.keras.layers.Dropout(0.25)(x)
    logits = tf.keras.layers.Dense(vocab, name="logits")(x)   # [B, 48, 37]
    return tf.keras.Model(inp, logits, name="cnn_tcn_ocr")


# ---------------------------------------------------------------- decode/metric

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


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=120)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--lr", type=float, default=5e-4)
    ap.add_argument("--patience", type=int, default=45)
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--aug", type=int, default=1)
    ap.add_argument("--tag", default="tfocr_seed42")
    ap.add_argument("--overfit", type=int, default=0, help="smoke: train on N samples")
    ap.add_argument("--manifest", default=str(ROOT / "reports" / "data_v2" / "final_manifest.csv"))
    a = ap.parse_args()

    out = RUNS / a.tag
    out.mkdir(parents=True, exist_ok=True)
    log = open(out / "train_log.txt", "a", encoding="utf-8")

    def p(*args):
        m = " ".join(str(x) for x in args)
        print(m, flush=True); log.write(m + "\n"); log.flush()

    set_seed(a.seed)
    dev = "/GPU:0" if tf.config.list_physical_devices("GPU") else "/CPU:0"
    p(f"TF {tf.__version__} | device {tf.config.list_physical_devices()} | config {vars(a)}")

    # data
    all_rows = list(csv.DictReader(open(a.manifest, encoding="utf-8")))
    by_split = {s: [r for r in all_rows if r["split"] == s] for s in ("train", "val", "test")}

    def load(split):
        X = np.load(DATA / "split" / f"X_{split}.npy").astype("float32") / 255.0
        labels = []
        with open(DATA / "split" / f"y_{split}.csv", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                labels.append(r["label"])
        return X, labels

    Xtr, ytr = load("train"); Xva, yva = load("val")
    if a.overfit:
        Xtr, ytr = Xtr[:a.overfit], ytr[:a.overfit]
    targets_tr, tl_tr = encode(ytr)
    p(f"data: train {len(ytr)} | val {len(yva)} | max label len {targets_tr.shape[1]}")

    model = build_model(VOCAB)
    p(f"params: {model.count_params():,}")

    # Warmup + cosine decay schedule (mirrors OneCycleLR used by PARSeq PyTorch)
    n_steps_per_epoch = max(1, (len(ytr) + a.batch - 1) // a.batch)
    total_steps = a.epochs * n_steps_per_epoch
    warmup_steps = max(1, int(total_steps * 0.10))

    lr_schedule = tf.keras.optimizers.schedules.CosineDecay(
        initial_learning_rate=0.0,
        decay_steps=max(1, total_steps - warmup_steps),
        alpha=0.01,  # end at 1% of peak LR
        warmup_target=a.lr,
        warmup_steps=warmup_steps,
    )
    opt = tf.keras.optimizers.AdamW(learning_rate=lr_schedule, weight_decay=0.01)
    model.compile(optimizer=opt)

    n_steps = max(1, (len(ytr) + a.batch - 1) // a.batch)
    total_steps = a.epochs * n_steps

    best = {"cer": 1e9, "em": -1, "epoch": -1}
    history = []
    t0 = time.time()
    no_improve = 0
    rng = random.Random(a.seed)

    with tf.device(dev):
        for ep in range(1, a.epochs + 1):
            idx = list(range(len(ytr))); rng.shuffle(idx)
            run, nb = 0.0, 0
            for i in range(0, len(idx), a.batch):
                b = idx[i:i + a.batch]
                if a.aug:
                    xb = np.stack([augment(x) for x in Xtr[b]])
                else:
                    xb = Xtr[b]
                xb_t = tf.convert_to_tensor(xb)
                tlen = tf.convert_to_tensor(tl_tr[b])
                # tf.nn.ctc_loss expects labels as SparseTensor
                idxs = tf.where(tg_pad := tf.convert_to_tensor(targets_tr[b]))  # positions of nonzero
                vals = tf.gather_nd(tg_pad, idxs)
                sp_labels = tf.SparseTensor(indices=idxs, values=vals,
                                            dense_shape=tf.cast(tf.shape(tg_pad), tf.int64))
                with tf.GradientTape() as tape:
                    logits = model(xb_t, training=True)
                    loss = tf.reduce_mean(tf.nn.ctc_loss(
                        labels=sp_labels,
                        logits=logits,
                        label_length=tf.cast(tlen, tf.int32),
                        logit_length=tf.fill([tg_pad.shape[0]], 48),
                        logits_time_major=False,
                        blank_index=BLANK,
                    ))
                grads = tape.gradient(loss, model.trainable_variables)
                grads, _ = tf.clip_by_global_norm(grads, 5.0)
                opt.apply_gradients(zip(grads, model.trainable_variables))
                run += float(loss); nb += 1

            # greedy eval on val
            preds = []
            with tf.device(dev):
                for i in range(0, len(yva), 32):
                    val_logits = model(tf.convert_to_tensor(Xva[i:i + 32]), training=False)
                    preds.extend(greedy_decode(val_logits.numpy()))
            vcer, vem = cer_em(preds, yva)

            history.append({"epoch": ep, "train_loss": round(run / max(1, nb), 4),
                            "val_cer": round(vcer, 4), "val_em": vem, "val_n": len(yva)})
            with open(out / "history.csv", "w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(f, fieldnames=list(history[0].keys()))
                w.writeheader(); w.writerows(history)
            p("ep %3d | loss %.4f | valCER %.4f valEM %d/%d | %.0fs" %
              (ep, run / max(1, nb), vcer, vem, len(yva), time.time() - t0))

            if vcer < best["cer"]:
                best = {"cer": vcer, "em": vem, "epoch": ep}
                model.save(out / "ocr_model.keras")
                no_improve = 0
                p("  -> best saved (val CER %.4f, EM %d)" % (vcer, vem))
            else:
                no_improve += 1
            if no_improve >= a.patience:
                p("early stop ep", ep); break

    p("done best val CER %.4f EM %d @ep%d | %.1f min" %
      (best["cer"], best["em"], best["epoch"], (time.time() - t0) / 60))
    (out / "metrics.json").write_text(json.dumps(
        {**best, "val_n": len(yva), "config": vars(a),
         "minutes": round((time.time() - t0) / 60, 1)}, indent=2), encoding="utf-8")
    log.close()


if __name__ == "__main__":
    main()
