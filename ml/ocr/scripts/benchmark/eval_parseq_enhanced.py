"""Enhanced PARSeq decoding: greedy vs beam search vs TTA.

Implements beam search for PARSeq's autoregressive decoder and test-time
augmentation (TTA) by majority voting across geometric/photometric variants.
Evaluates on a manifest split (default: val) and reports CER/EM.

Does not retrain and does not modify any checkpoint.

Usage:
  python scripts/benchmark/eval_parseq_enhanced.py --split val \
      --ckpt reports/improvement_v1/ocr_benchmark/parseq_runs/parseq_ft_seed42/best.pt
"""
import argparse
import csv
import json
import sys
import time
from pathlib import Path

import cv2
import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "benchmark"))
import parseq_common as pc  # noqa: E402

OUT = ROOT / "reports" / "improvement_v1" / "ocr_benchmark" / "decode_experiments"


def preprocess_variant(path, scale=1.0, pad=0, brightness=0):
    """PARSeq preprocessing with optional TTA perturbations."""
    bgr = cv2.imread(str(path), cv2.IMREAD_COLOR)
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    if scale != 1.0:
        h, w = rgb.shape[:2]
        rgb = cv2.resize(rgb, (max(1, int(w * scale)), max(1, int(h * scale))),
                         interpolation=cv2.INTER_AREA)
    rgb = cv2.resize(rgb, (pc.IMG_SIZE[1], pc.IMG_SIZE[0]), interpolation=cv2.INTER_AREA)
    x = rgb.astype(np.float32)
    if brightness:
        x = np.clip(x + brightness, 0, 255)
    x = x / 255.0
    x = (x - 0.5) / 0.5
    return np.transpose(x, (2, 0, 1))


def greedy_batch(model, tok, imgs, dev):
    with torch.no_grad():
        xb = torch.from_numpy(imgs).to(dev)
        logits = model.forward(tok, xb)
        texts, _ = tok.decode(logits.softmax(-1))
    return [t.upper() for t in texts]


def beam_search_batch(model, tok, imgs, dev, beam=5, max_len=None):
    """Batched beam search over PARSeq's AR decoder."""
    max_len = max_len or model.max_label_length
    model.eval()
    results = []
    with torch.no_grad():
        for i in range(len(imgs)):
            xb = torch.from_numpy(imgs[i:i + 1]).to(dev)
            memory = model.encode(xb)                       # [1,T,C]
            # beams: list of (token_ids list, score)
            beams = [([tok.bos_id], 0.0)]
            for _ in range(max_len + 1):
                live = [(s, sc) for s, sc in beams if s[-1] != tok.eos_id]
                done = [(s, sc) for s, sc in beams if s[-1] == tok.eos_id]
                if not live:
                    break
                L = len(live[0][0])
                tgt = torch.tensor([s for s, _ in live], dtype=torch.long, device=dev)  # [B,L]
                mem = memory.expand(len(live), -1, -1)
                causal = torch.triu(torch.ones((L, L), dtype=torch.bool, device=dev), 1)
                pos_q = model.pos_queries[:, :L].expand(len(live), -1, -1)
                out = model.decode(tgt, mem, causal, None, pos_q, causal)
                logp = model.head(out)[:, -1].log_softmax(-1)   # [B,V]
                topv, topi = logp.topk(beam, dim=-1)
                cand = list(done)
                for bi, (seq, sc) in enumerate(live):
                    for v, idx in zip(topv[bi].tolist(), topi[bi].tolist()):
                        cand.append((seq + [idx], sc + v))
                cand.sort(key=lambda x: -x[1])
                beams = cand[:beam]
            best_seq = max(beams, key=lambda x: x[1])[0][1:]   # drop BOS
            if tok.eos_id in best_seq:
                best_seq = best_seq[:best_seq.index(tok.eos_id)]
            text = tok._ids2tok(best_seq) if best_seq else ""
            results.append(text.upper())
    return results


def tta_predict(model, tok, paths, dev, variants, mode="greedy", beam=5):
    """TTA by majority vote (ties broken by greedy of the base variant)."""
    from collections import Counter
    per_variant = []
    for v in variants:
        imgs = np.stack([preprocess_variant(p, **v) for p in paths])
        if mode == "beam":
            per_variant.append(beam_search_batch(model, tok, imgs, dev, beam))
        else:
            per_variant.append(greedy_batch(model, tok, imgs, dev))
    out = []
    for i in range(len(paths)):
        votes = Counter(pv[i] for pv in per_variant)
        top = votes.most_common()
        best = top[0][1]
        cands = [t for t, c in top if c == best]
        # tie-break: prefer the base (first) variant's prediction if present
        out.append(per_variant[0][i] if per_variant[0][i] in cands else cands[0])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=str(ROOT / "reports" / "clean_manifest.csv"))
    ap.add_argument("--split", default="val")
    ap.add_argument("--ckpt", default=str(ROOT / "reports" / "improvement_v1" / "ocr_benchmark"
                                          / "parseq_runs" / "parseq_ft_seed42" / "best.pt"))
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--beam", type=int, default=5)
    ap.add_argument("--out", default=str(OUT / "decode_results.csv"))
    ap.add_argument("--errors-out", default="")
    a = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    dev = torch.device(a.device)
    model, tok = pc.build_model(pretrained=True)
    sd = torch.load(a.ckpt, map_location="cpu", weights_only=False)
    model.load_state_dict(sd["model"] if "model" in sd else sd)
    model.to(dev).eval()

    rows = [r for r in csv.DictReader(open(a.manifest, encoding="utf-8")) if r["split"] == a.split]
    gts = [r["label"] for r in rows]
    paths = [str(ROOT / "plate_text_dataset" / "plate_text_dataset" / "dataset" / r["filename"]) for r in rows]
    base_imgs = np.stack([preprocess_variant(p) for p in paths])

    results = []

    def record(name, preds, t0):
        cer, em = pc.cer_em(preds, gts)
        rec = {"method": name, "split": a.split, "n": len(gts), "cer": round(cer, 4),
               "exact": em, "em_rate": round(em / len(gts), 4),
               "seconds": round(time.time() - t0, 1)}
        results.append(rec)
        print(rec, flush=True)
        return preds

    t0 = time.time(); preds_g = record("greedy", greedy_batch(model, tok, base_imgs, dev), t0)
    t0 = time.time(); preds_b = record("beam%d" % a.beam,
                                       beam_search_batch(model, tok, base_imgs, dev, a.beam), t0)

    variants = [
        dict(),
        dict(scale=0.95),
        dict(scale=1.05),
        dict(brightness=-12),
        dict(brightness=12),
    ]
    t0 = time.time(); preds_tg = record("tta_greedy", tta_predict(model, tok, paths, dev, variants, "greedy"), t0)
    t0 = time.time(); preds_tb = record("tta_beam%d" % a.beam,
                                        tta_predict(model, tok, paths, dev, variants, "beam", a.beam), t0)

    with open(a.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(results[0].keys()))
        w.writeheader(); w.writerows(results)
    print("saved", a.out)

    if a.errors_out:
        best = min(results, key=lambda r: r["cer"])
        preds = {"greedy": preds_g, "beam%d" % a.beam: preds_b, "tta_greedy": preds_tg,
                 "tta_beam%d" % a.beam: preds_tb}[best["method"]]
        with open(a.errors_out, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f); w.writerow(["filename", "pattern", "gt", "pred", "ed"])
            for r, g, p in zip(rows, gts, preds):
                w.writerow([r["filename"], r["pattern"], g, p, pc.edit_distance(p, g)])
        print("errors saved for best method:", best["method"])


if __name__ == "__main__":
    main()
