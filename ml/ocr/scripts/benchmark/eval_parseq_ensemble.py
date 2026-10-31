"""Ensemble evaluation for PARSeq: majority vote + confidence tie-break.

Runs greedy decoding for each checkpoint, then combines predictions by
majority vote. Ties are broken by the highest mean token log-probability
computed on the base (first) model.

Usage:
  python scripts/benchmark/eval_parseq_ensemble.py --split val \
      --ckpt A.pt --ckpt B.pt --ckpt C.pt
"""
import argparse
import csv
import sys
from collections import Counter
from pathlib import Path

import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "benchmark"))
import parseq_common as pc  # noqa: E402

OUT = ROOT / "reports" / "improvement_v1" / "ocr_benchmark" / "decode_experiments"


def greedy_with_conf(model, tok, imgs, dev):
    """Return predictions and mean token log-prob per sample."""
    model.eval()
    preds, confs = [], []
    with torch.no_grad():
        for i in range(len(imgs)):
            xb = torch.from_numpy(imgs[i:i + 1]).to(dev)
            logits = model.forward(tok, xb)
            logp = logits.log_softmax(-1)
            toks = logp.argmax(-1)[0]
            # sequence probability up to EOS
            ids = toks.tolist()
            eos = tok.eos_id
            cut = ids.index(eos) if eos in ids else len(ids)
            seq_lp = logp[0, torch.arange(max(1, cut)), toks[:max(1, cut)]].sum().item()
            text, _ = tok.decode(logits.softmax(-1))
            preds.append(text[0].upper())
            confs.append(seq_lp / max(1, cut))
    return preds, confs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=str(ROOT / "reports" / "clean_manifest.csv"))
    ap.add_argument("--split", default="val")
    ap.add_argument("--ckpt", action="append", required=True)
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--out", default=str(OUT / "ensemble_results.csv"))
    ap.add_argument("--errors-out", default="")
    a = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    dev = torch.device(a.device)
    rows = [r for r in csv.DictReader(open(a.manifest, encoding="utf-8")) if r["split"] == a.split]
    gts = [r["label"] for r in rows]
    paths = [str(ROOT / "plate_text_dataset" / "plate_text_dataset" / "dataset" / r["filename"]) for r in rows]
    imgs = np.stack([pc.preprocess(p) for p in paths])

    all_preds, all_confs = [], []
    for ck in a.ckpt:
        model, tok = pc.build_model(pretrained=True)
        sd = torch.load(ck, map_location="cpu", weights_only=False)
        model.load_state_dict(sd["model"] if "model" in sd else sd)
        model.to(dev)
        p, c = greedy_with_conf(model, tok, imgs, dev)
        cer, em = pc.cer_em(p, gts)
        print("%-45s CER %.4f EM %d/%d" % (Path(ck).parent.name, cer, em, len(gts)))
        all_preds.append(p); all_confs.append(c)

    # majority vote with confidence tie-break
    ensemble = []
    for i in range(len(gts)):
        votes = Counter(pred[i] for pred in all_preds)
        top = votes.most_common()
        best_count = top[0][1]
        cands = [t for t, c in top if c == best_count]
        if len(cands) == 1:
            ensemble.append(cands[0])
        else:
            # tie: choose the candidate with the best mean confidence among models that predicted it
            scores = {c: -1e9 for c in cands}
            for preds, confs in zip(all_preds, all_confs):
                if preds[i] in scores:
                    scores[preds[i]] = max(scores[preds[i]], confs[i])
            ensemble.append(max(scores, key=scores.get))

    cer, em = pc.cer_em(ensemble, gts)
    print("ENSEMBLE (%d models)                     CER %.4f EM %d/%d" % (len(a.ckpt), cer, em, len(gts)))

    with open(a.out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["method", "split", "n", "cer", "exact", "em_rate"])
        for ck, preds in zip(a.ckpt, all_preds):
            c, e = pc.cer_em(preds, gts)
            w.writerow([Path(ck).parent.name, a.split, len(gts), round(c, 4), e, round(e / len(gts), 4)])
        w.writerow(["ENSEMBLE", a.split, len(gts), round(cer, 4), em, round(em / len(gts), 4)])
    print("saved", a.out)

    if a.errors_out:
        with open(a.errors_out, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f); w.writerow(["filename", "pattern", "gt", "pred", "ed"])
            for r, g, p in zip(rows, gts, ensemble):
                w.writerow([r["filename"], r["pattern"], g, p, pc.edit_distance(p, g)])


if __name__ == "__main__":
    main()
