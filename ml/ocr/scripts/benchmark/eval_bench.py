"""Benchmark evaluator: overall + per-domain CER/EM, sub/del/ins, latency.

Loads one or more OCR checkpoints (the repo's CRNN architecture), auto-detects
input resolution from the checkpoint, and evaluates on a manifest split using
the same preprocessing/decoding as training. Writes a CSV.

Usage:
  python scripts/benchmark/eval_bench.py --model A.pt --model B.pt --split val \
      --out reports/improvement_v1/ocr_benchmark/bench_eval.csv
"""
import argparse
import csv
import importlib.util
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

import cv2
import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import phase5_transfer as p5  # noqa: E402


def align_ops(a, b):
    la, lb = len(a), len(b)
    D = [[0] * (lb + 1) for _ in range(la + 1)]
    for i in range(la + 1):
        D[i][0] = i
    for j in range(lb + 1):
        D[0][j] = j
    for i in range(1, la + 1):
        for j in range(1, lb + 1):
            D[i][j] = min(D[i - 1][j] + 1, D[i][j - 1] + 1, D[i - 1][j - 1] + (a[i - 1] != b[j - 1]))
    i, j, s, d, ins = la, lb, 0, 0, 0
    while i > 0 or j > 0:
        if i > 0 and j > 0 and D[i][j] == D[i - 1][j - 1] + (a[i - 1] != b[j - 1]):
            if a[i - 1] != b[j - 1]:
                s += 1
            i -= 1; j -= 1
        elif i > 0 and D[i][j] == D[i - 1][j] + 1:
            d += 1; i -= 1
        else:
            ins += 1; j -= 1
    return s, d, ins


def evaluate_checkpoint(path, rows, dev, tta=False):
    st = torch.load(str(path), map_location=dev, weights_only=False)
    p5.IMG_H, p5.IMG_W = int(st.get("img_h", 32)), int(st.get("img_w", 160))
    model = p5.CRNN(backbone="wp").to(dev)
    model.load_state_dict(st["model"]); model.eval()
    labels = [r["label"] for r in rows]
    canv = [p5.prep(cv2.imread(str(p5.IMG / r["filename"]), cv2.IMREAD_GRAYSCALE)) for r in rows]

    def logp(cs):
        xb = torch.from_numpy(np.stack([p5.norm(c) for c in cs])).unsqueeze(1).to(dev)
        with torch.no_grad():
            return model(xb).cpu().numpy()

    # latency: time pure forward per image (greedy)
    preds = []
    t0 = time.time()
    for i in range(0, len(canv), 32):
        preds.extend(p5.decode(torch.from_numpy(logp(canv[i:i + 32]))))
    lat_ms = (time.time() - t0) / max(1, len(canv)) * 1000.0

    dom = defaultdict(lambda: {"n": 0, "ed": 0, "glen": 0, "em": 0, "s": 0, "d": 0, "ins": 0})
    for r, g, pr in zip(rows, labels, preds):
        ed = p5.ed(pr, g)
        s, d, ins = align_ops(pr, g)
        for key in ("ALL", r["pattern"]):
            dom[key]["n"] += 1; dom[key]["ed"] += ed; dom[key]["glen"] += len(g)
            dom[key]["em"] += 1 if pr == g else 0
            dom[key]["s"] += s; dom[key]["d"] += d; dom[key]["ins"] += ins
    out = {"checkpoint": str(path), "n_params": sum(v.numel() for v in st["model"].values() if hasattr(v, "numel")),
           "img_h": p5.IMG_H, "img_w": p5.IMG_W, "latency_ms_per_img": round(lat_ms, 2),
           "n": len(labels), "exact": dom["ALL"]["em"],
           "cer": round(dom["ALL"]["ed"] / max(1, dom["ALL"]["glen"]), 4),
           "em_rate": round(dom["ALL"]["em"] / max(1, dom["ALL"]["n"]), 4),
           "subs": dom["ALL"]["s"], "dels": dom["ALL"]["d"], "ins": dom["ALL"]["ins"]}
    for key in sorted(k for k in dom if k != "ALL"):
        out["%s_cer" % key] = round(dom[key]["ed"] / max(1, dom[key]["glen"]), 4)
        out["%s_em" % key] = dom[key]["em"]
        out["%s_n" % key] = dom[key]["n"]
    return out, labels, preds, rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", action="append", required=True)
    ap.add_argument("--manifest", default=str(ROOT / "reports" / "clean_manifest.csv"))
    ap.add_argument("--split", default="val")
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--out", default=str(ROOT / "reports" / "improvement_v1" / "ocr_benchmark" / "bench_eval.csv"))
    ap.add_argument("--errors-out", default="")
    a = ap.parse_args()

    dev = torch.device(a.device)
    rows = [r for r in csv.DictReader(open(a.manifest, encoding="utf-8")) if r["split"] == a.split]
    results = []
    for mp in a.model:
        res, labels, preds, rws = evaluate_checkpoint(mp, rows, dev)
        results.append(res)
        print(res)
        if a.errors_out:
            with open(a.errors_out, "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f); w.writerow(["filename", "pattern", "gt", "pred", "ed"])
                for r, g, pr in zip(rws, labels, preds):
                    w.writerow([r["filename"], r["pattern"], g, pr, p5.ed(pr, g)])
    fields = []
    for r in results:
        for k in r:
            if k not in fields:
                fields.append(k)
    with open(a.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in results:
            w.writerow(r)
    print("saved", a.out)


if __name__ == "__main__":
    main()
