"""Unified val comparison: CRNN baseline checkpoints vs PARSeq fine-tuned.

Runs from the parseq venv (which reuses the baseline torch). Produces
reports/improvement_v1/ocr_benchmark/bench_comparison_val.csv with overall and
per-domain CER/EM, params, and latency for every model. Validation split only.
"""
import argparse
import csv
import sys
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "scripts" / "benchmark"))
import phase5_transfer as p5  # noqa: E402
import parseq_common as pc  # noqa: E402

IMG = p5.IMG


def ed(a, b):
    return p5.ed(a, b)


def metrics(rows, gts, preds):
    dom = defaultdict(lambda: {"n": 0, "ed": 0, "glen": 0, "em": 0})
    for r, g, pr in zip(rows, gts, preds):
        d = ed(pr, g)
        for k in ("ALL", r["pattern"]):
            dom[k]["n"] += 1; dom[k]["ed"] += d; dom[k]["glen"] += len(g)
            dom[k]["em"] += 1 if pr == g else 0
    out = {}
    for k, v in dom.items():
        out["%s_cer" % k] = round(v["ed"] / max(1, v["glen"]), 4)
        out["%s_em" % k] = v["em"]
        out["%s_n" % k] = v["n"]
    return out


def eval_crnn(path, rows, dev):
    st = torch.load(str(path), map_location=dev, weights_only=False)
    p5.IMG_H, p5.IMG_W = int(st.get("img_h", 32)), int(st.get("img_w", 160))
    m = p5.CRNN(backbone="wp").to(dev)
    m.load_state_dict(st["model"]); m.eval()
    canv = [p5.prep(__import__("cv2").imread(str(IMG / r["filename"]), __import__("cv2").IMREAD_GRAYSCALE)) for r in rows]
    t0 = time.time(); preds = []
    for i in range(0, len(canv), 32):
        xb = torch.from_numpy(np.stack([p5.norm(c) for c in canv[i:i + 32]])).unsqueeze(1).to(dev)
        with torch.no_grad():
            preds.extend(p5.decode(m(xb)))
    lat = (time.time() - t0) / len(canv) * 1000
    npar = sum(q.numel() for q in m.parameters())
    return preds, npar, lat


def eval_parseq(path, rows, dev):
    model, tok = pc.build_model(pretrained=True)
    sd = torch.load(str(path), map_location="cpu", weights_only=False)
    model.load_state_dict(sd["model"] if "model" in sd else sd)
    model.to(dev).eval()
    paths = [str(IMG / r["filename"]) for r in rows]
    t0 = time.time(); preds = []
    for i in range(0, len(paths), 32):
        preds.extend(pc.decode_batch(model, tok, paths[i:i + 32], dev))
    lat = (time.time() - t0) / len(paths) * 1000
    npar = sum(q.numel() for q in model.parameters())
    return preds, npar, lat


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--crnn", action="append", default=[])
    ap.add_argument("--parseq", action="append", default=[])
    ap.add_argument("--manifest", default=str(ROOT / "reports" / "clean_manifest.csv"))
    ap.add_argument("--split", default="val")
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--out", default=str(ROOT / "reports" / "improvement_v1" / "ocr_benchmark" / "bench_comparison_val.csv"))
    a = ap.parse_args()

    dev = torch.device(a.device)
    rows = [r for r in csv.DictReader(open(a.manifest, encoding="utf-8")) if r["split"] == a.split]
    gts = [r["label"] for r in rows]
    results = []

    for mp in a.crnn:
        preds, npar, lat = eval_crnn(mp, rows, dev)
        res = {"model": "CRNN-ResNet18(wp)", "checkpoint": Path(mp).parent.name, "params": npar,
               "latency_ms": round(lat, 2), **metrics(rows, gts, preds)}
        results.append(res); print(res)
    for mp in a.parseq:
        preds, npar, lat = eval_parseq(mp, rows, dev)
        res = {"model": "PARSeq-finetuned", "checkpoint": Path(mp).parent.name, "params": npar,
               "latency_ms": round(lat, 2), **metrics(rows, gts, preds)}
        results.append(res); print(res)

    fields = []
    for r in results:
        for k in r:
            if k not in fields:
                fields.append(k)
    with open(a.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields); w.writeheader()
        for r in results:
            w.writerow(r)
    print("saved", a.out)


if __name__ == "__main__":
    main()
