"""Fase 6: Evaluate TF OCR on test set (580), per-prefix + confusion matrix.

Usage:
  python scripts/ocr_tf/eval_tf_test.py --manifest ... --model ...keras \
      --out eval_tf_test580.csv --errors-out tf_test_errors.csv
"""
import argparse
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path

import cv2
import numpy as np
import tensorflow as tf

ROOT = Path(r"D:\CollegeFile\SMT 5\SmartPark-OCR")
sys.path.insert(0, str(ROOT / "scripts" / "ocr_tf"))
from train_tfocr import greedy_decode, edit_distance, cer_em, build_model, VOCAB  # noqa: E402

BLANK = 0
CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--split", default="test")
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", default="")
    ap.add_argument("--errors-out", default="")
    a = ap.parse_args()

    dev = "/GPU:0" if tf.config.list_physical_devices("GPU") else "/CPU:0"
    model = tf.keras.models.load_model(a.model)
    model.trainable = False

    rows = [r for r in csv.DictReader(open(a.manifest, encoding="utf-8")) if r["split"] == a.split]
    gts = [r["label"] for r in rows]
    paths = [(r.get("path") or "").strip() or
             str(ROOT / "plate_text_dataset" / "plate_text_dataset" / "dataset" / r["filename"])
             for r in rows]

    # preprocess at model scale (48x192 grayscale [0,1])
    def prep(p):
        g = cv2.imread(p, cv2.IMREAD_GRAYSCALE)
        if g is None:
            return np.zeros((48, 192, 1), dtype=np.float32)
        h, w = g.shape[:2]
        ar = w / max(h, 1)
        if ar < 1.8:
            g = g[: int(h * 0.68), :]
        cl = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        g = cl.apply(g)
        interp = cv2.INTER_AREA if (w >= 192 and h >= 48) else cv2.INTER_CUBIC
        g = cv2.resize(g, (192, 48), interpolation=interp)
        return np.expand_dims(g.astype(np.float32) / 255.0, axis=-1)

    preds, logits_all = [], []
    with tf.device(dev):
        for i in range(0, len(paths), 32):
            xs = np.stack([prep(p) for p in paths[i:i + 32]])
            xb = tf.convert_to_tensor(xs)
            out = model(xb, training=False).numpy()
            preds.extend(greedy_decode(out))
            logits_all.extend(out)

    cer, em = cer_em(preds, gts)
    errs = [r for r, g, p in zip(rows, gts, preds) if p != g]
    print(f"TF OCR | test n={len(gts)} | CER {cer:.4f} | EM {em}/{len(gts)} ({100*em/len(gts):.1f}%) | errors {len(errs)}")

    # per-prefix
    def pref(l): return l[:2] if l[:2].isalpha() else l[:1]
    agg = defaultdict(lambda: {"n": 0, "ed": 0, "glen": 0, "em": 0})
    conf = Counter()
    for r, g, p in zip(rows, gts, preds):
        d = edit_distance(p, g)
        k = pref(g)
        agg[k]["n"] += 1; agg[k]["ed"] += d; agg[k]["glen"] += len(g); agg[k]["em"] += (p == g)
        for gt_c, pr_c in zip(g, p):
            if gt_c != pr_c:
                conf[(gt_c, pr_c)] += 1

    print("\nPer-prefix:")
    for k, v in sorted(agg.items(), key=lambda x: -x[1]["n"]):
        print(f"  {k:4s} n={v['n']:3d} CER={v['ed']/max(1,v['glen']):.4f} EM={v['em']}/{v['n']}")
    print("\nTop substitutions (gt -> pred):")
    for (g, p), c in conf.most_common(10):
        print(f"  {g} -> {p} : {c}")

    # save
    if a.out:
        with open(a.out, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["filename", "prefix", "gt", "pred", "ed"])
            for r, g, p in zip(rows, gts, preds):
                w.writerow([r["filename"], pref(g), g, p, edit_distance(p, g)])
        print("saved", a.out)
    if a.errors_out:
        with open(a.errors_out, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["filename", "prefix", "gt", "pred", "ed"])
            for r, g, p in zip(rows, gts, preds):
                if p != g:
                    w.writerow([r["filename"], pref(g), g, p, edit_distance(p, g)])
        print("saved", a.errors_out)


if __name__ == "__main__":
    main()
