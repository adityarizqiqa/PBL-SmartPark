"""Fine-tune PARSeq on the SmartPark plate dataset (Tahap 3 benchmark).

Fair protocol vs baseline:
  - same train/val split (reports/clean_manifest.csv), same seed
  - training only on train split; checkpoint selected by validation CER
  - PARSeq-native preprocessing (RGB, 32x128, [-1,1])
  - teacher-forced autoregressive cross-entropy (PARSeq's own objective family)

Writes runs under reports/improvement_v1/ocr_benchmark/parseq_runs/<tag>/.
Does not modify any baseline artifact.
"""
import argparse
import csv
import json
import os
import random
import sys
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "benchmark"))
import parseq_common as pc  # noqa: E402

MAN = ROOT / "reports" / "clean_manifest.csv"
OUTROOT = ROOT / "reports" / "improvement_v1" / "ocr_benchmark" / "parseq_runs"


def seed_all(seed, deterministic=True):
    os.environ.setdefault("CUBLAS_WORKSPACE_CONFIG", ":4096:8")
    random.seed(seed); np.random.seed(seed); torch.manual_seed(seed); torch.cuda.manual_seed_all(seed)
    if deterministic:
        torch.backends.cudnn.deterministic = True
        torch.backends.cudnn.benchmark = False
        try:
            torch.use_deterministic_algorithms(True, warn_only=True)
        except Exception:
            pass


def build_dataset(rows):
    paths = [str(pc.ROOT / "plate_text_dataset" / "plate_text_dataset" / "dataset" / r["filename"]) for r in rows]
    imgs = np.stack([pc.preprocess(p) for p in paths])  # [N,3,32,128] float32
    labels = [r["label"] for r in rows]
    return imgs, labels


def augment_img(x, strength=1.0):
    """Augment a normalized CHW float image in-place-safe (returns new array).

    Realistic plate perturbations: small rotation/scale/shift, brightness and
    contrast jitter, blur, noise. x is [3,H,W] in [-1,1].
    """
    import cv2
    img = ((x.transpose(1, 2, 0) + 1.0) * 127.5).astype(np.uint8)  # HWC uint8 RGB
    h, w = img.shape[:2]
    ang = random.uniform(-3.0, 3.0) * strength
    sc = random.uniform(1 - 0.06 * strength, 1 + 0.06 * strength)
    M = cv2.getRotationMatrix2D((w / 2.0, h / 2.0), ang, sc)
    M[0, 2] += random.uniform(-0.04, 0.04) * strength * w
    M[1, 2] += random.uniform(-0.04, 0.04) * strength * h
    img = cv2.warpAffine(img, M, (w, h), borderValue=(0, 0, 0))
    img = np.clip(img.astype(np.float32) * random.uniform(1 - 0.25 * strength, 1 + 0.25 * strength)
                  + random.uniform(-25, 25) * strength, 0, 255).astype(np.uint8)
    if random.random() < 0.35 * strength:
        k = random.choice([3, 5])
        img = cv2.GaussianBlur(img, (k, k), 0)
    if random.random() < 0.25 * strength:
        img = np.clip(img.astype(np.float32)
                      + np.random.normal(0, random.uniform(4, 14) * strength, img.shape), 0, 255).astype(np.uint8)
    out = img.astype(np.float32) / 255.0
    out = (out - 0.5) / 0.5
    return np.transpose(out, (2, 0, 1))


@torch.no_grad()
def evaluate(model, tok, imgs, labels, dev, bs=32):
    model.eval()
    preds = []
    for i in range(0, len(imgs), bs):
        xb = torch.from_numpy(imgs[i:i + bs]).to(dev)
        logits = model.forward(tok, xb)
        texts, _ = tok.decode(logits.softmax(-1))
        preds.extend(t.upper() for t in texts)
    cer, em = pc.cer_em(preds, labels)
    return cer, em, preds


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=60)
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--lr", type=float, default=1e-4)
    ap.add_argument("--weight-decay", type=float, default=0.05)
    ap.add_argument("--warmup-pct", type=float, default=0.1)
    ap.add_argument("--patience", type=int, default=20)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--tag", default="parseq_ft")
    ap.add_argument("--smoke", type=int, default=0, help="if >0, run only this many optimizer steps")
    ap.add_argument("--aug", type=float, default=0.0,
                    help="augmentation strength (0 = off, 1 = realistic plate jitter)")
    ap.add_argument("--manifest", default=str(MAN))
    a = ap.parse_args()

    out = OUTROOT / a.tag
    out.mkdir(parents=True, exist_ok=True)
    log = open(out / "train_log.txt", "a", encoding="utf-8")

    def p(*args):
        m = " ".join(str(x) for x in args); print(m, flush=True); log.write(m + "\n"); log.flush()

    seed_all(a.seed)
    dev = torch.device(a.device)
    rows = list(csv.DictReader(open(a.manifest, encoding="utf-8")))
    tr = [r for r in rows if r["split"] == "train"]
    va = [r for r in rows if r["split"] == "val"]
    p("config", vars(a), "| train", len(tr), "| val", len(va))

    tri, trl = build_dataset(tr)
    vai, val = build_dataset(va)
    Xtr = torch.from_numpy(tri)
    model, tok = pc.build_model(pretrained=True)
    model.to(dev)
    p("params", sum(q.numel() for q in model.parameters()))

    no_decay = {"text_embed.embedding.weight", "pos_queries"}
    decay, nodecay = [], []
    for n, q in model.named_parameters():
        (nodecay if (n in no_decay or n.startswith("encoder.") and n.endswith("pos_embed")) else decay).append(q)
    opt = torch.optim.AdamW([{"params": decay, "weight_decay": a.weight_decay},
                             {"params": nodecay, "weight_decay": 0.0}], lr=a.lr)
    nsteps = max(1, (len(tr) + a.batch - 1) // a.batch)
    total = a.epochs * nsteps
    warm = max(1, int(total * a.warmup_pct))
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=a.lr, total_steps=total, pct_start=a.warmup_pct)
    crit = nn.CrossEntropyLoss(ignore_index=tok.pad_id)

    best = {"cer": 1e9, "epoch": -1, "em": 0}
    hist = []
    t0 = time.time()
    no_improve = 0
    step = 0
    stop = False
    for ep in range(1, a.epochs + 1):
        model.train()
        idx = list(range(len(tr))); random.shuffle(idx)
        run, nb = 0.0, 0
        for i in range(0, len(tr), a.batch):
            b = idx[i:i + a.batch]
            if a.aug > 0:
                batch_np = np.stack([augment_img(tri[j], a.aug) for j in b])
                xb = torch.from_numpy(batch_np).to(dev)
            else:
                xb = Xtr[b].to(dev)
            labels = [trl[j] for j in b]
            tgt = tok.encode(labels, device=dev)          # [N, L+2]
            inp = tgt[:, :-1]
            targ = tgt[:, 1:]
            memory = model.encode(xb)
            L = inp.shape[1]
            causal = torch.triu(torch.ones((L, L), dtype=torch.bool, device=dev), 1)
            pad_mask = (inp == tok.pad_id)
            logits = model.head(model.decode(inp, memory, causal, pad_mask))
            loss = crit(logits.reshape(-1, logits.shape[-1]), targ.reshape(-1))
            opt.zero_grad(); loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            opt.step()
            try:
                sched.step()
            except Exception:
                pass
            run += float(loss); nb += 1; step += 1
            if a.smoke and step >= a.smoke:
                stop = True; break
        vcer, vem, _ = evaluate(model, tok, vai, val, dev)
        row = {"epoch": ep, "train_loss": round(run / max(1, nb), 4), "val_cer": round(vcer, 4),
               "val_em": vem, "val_n": len(val)}
        hist.append(row)
        with open(out / "history.csv", "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(row.keys())); w.writeheader(); w.writerows(hist)
        p("ep %3d | loss %.4f | valCER %.4f valEM %d/%d | %.0fs" %
          (ep, row["train_loss"], vcer, vem, len(val), time.time() - t0))
        if vcer < best["cer"]:
            best = {"cer": vcer, "epoch": ep, "em": vem}
            torch.save({"model": model.state_dict(), "epoch": ep, "best_cer": vcer,
                        "charset": pc.CHARSET, "img_h": 32, "img_w": 128, "arch": "parseq"}, out / "best.pt")
            no_improve = 0
        else:
            no_improve += 1
        if stop or no_improve >= a.patience:
            break
    p("done best val CER %.4f EM %d @ ep %d | %.1f min" % (best["cer"], best["em"], best["epoch"], (time.time() - t0) / 60))
    (out / "best.json").write_text(json.dumps({**best, "config": vars(a)}, indent=2), encoding="utf-8")
    log.close()


if __name__ == "__main__":
    import traceback
    try:
        main()
    except Exception:
        tb = traceback.format_exc()
        print(tb, flush=True); raise
