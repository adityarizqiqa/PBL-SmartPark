"""Evaluate a PARSeq checkpoint (or the raw pretrained weights) on a manifest split.

Usage:
  python scripts/benchmark/eval_parseq.py --split val [--ckpt path.pt] [--out csv]
"""
import argparse
import csv
import sys
import time
from pathlib import Path

import torch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "benchmark"))
import parseq_common as pc  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=str(ROOT / "reports" / "clean_manifest.csv"))
    ap.add_argument("--split", default="val")
    ap.add_argument("--ckpt", default="")
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--out", default="")
    ap.add_argument("--errors-out", default="")
    a = ap.parse_args()

    dev = torch.device(a.device)
    model, tok = pc.build_model(pretrained=True)
    if a.ckpt:
        sd = torch.load(a.ckpt, map_location="cpu", weights_only=False)
        model.load_state_dict(sd["model"] if "model" in sd else sd)
    model.to(dev).eval()

    rows = [r for r in csv.DictReader(open(a.manifest, encoding="utf-8")) if r["split"] == a.split]
    gts = [r["label"] for r in rows]
    paths = [str(pc.ROOT / "plate_text_dataset" / "plate_text_dataset" / "dataset" / r["filename"]) for r in rows]

    t0 = time.time()
    preds = []
    for i in range(0, len(paths), 32):
        preds.extend(pc.decode_batch(model, tok, paths[i:i + 32], dev))
    lat = (time.time() - t0) / max(1, len(paths)) * 1000.0
    cer, em = pc.cer_em(preds, gts)
    n_params = sum(p.numel() for p in model.parameters())
    print("PARSeq %s | n=%d | CER %.4f | EM %d | params %d | latency %.2f ms/img"
          % (a.ckpt or "pretrained", len(gts), cer, em, n_params, lat))
    for g, p in list(zip(gts, preds))[:15]:
        print("   gt=%-10s pred=%s" % (g, p))
    if a.out:
        with open(a.out, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["checkpoint", "split", "n", "cer", "exact", "em_rate", "n_params", "latency_ms_per_img"])
            w.writerow([a.ckpt or "pretrained", a.split, len(gts), round(cer, 4), em, round(em / len(gts), 4),
                        n_params, round(lat, 2)])
    if a.errors_out:
        with open(a.errors_out, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f); w.writerow(["filename", "gt", "pred", "ed"])
            for r, g, p in zip(rows, gts, preds):
                w.writerow([r["filename"], g, p, pc.edit_distance(p, g)])


if __name__ == "__main__":
    main()
