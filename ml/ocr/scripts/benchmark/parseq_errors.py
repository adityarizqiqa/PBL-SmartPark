"""PARSeq val error dump + montage (val split only)."""
import csv
import sys
from pathlib import Path

import cv2
import numpy as np
import torch
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "benchmark"))
import parseq_common as pc  # noqa: E402

OUT = ROOT / "reports" / "improvement_v1" / "ocr_benchmark"
MONT = OUT / "montages"
CKPT = OUT / "parseq_runs" / "parseq_ft_seed42" / "best.pt"
IMG = ROOT / "plate_text_dataset" / "plate_text_dataset" / "dataset"


def main():
    MONT.mkdir(parents=True, exist_ok=True)
    dev = torch.device("cuda")
    model, tok = pc.build_model(pretrained=True)
    sd = torch.load(str(CKPT), map_location="cpu", weights_only=False)
    model.load_state_dict(sd["model"]); model.to(dev).eval()
    rows = [r for r in csv.DictReader(open(ROOT / "reports" / "clean_manifest.csv", encoding="utf-8")) if r["split"] == "val"]
    paths = [str(IMG / r["filename"]) for r in rows]
    gts = [r["label"] for r in rows]
    preds = []
    for i in range(0, len(paths), 32):
        preds.extend(pc.decode_batch(model, tok, paths[i:i + 32], dev))
    errs = []
    for r, g, p in zip(rows, gts, preds):
        if p != g:
            errs.append({"filename": r["filename"], "pattern": r["pattern"], "gt": g, "pred": p,
                         "ed": pc.edit_distance(p, g)})
    errs.sort(key=lambda x: -x["ed"])
    with open(OUT / "parseq_ft_seed42_val_errors.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["filename", "pattern", "gt", "pred", "ed"])
        w.writeheader(); w.writerows(errs)
    print("val errors:", len(errs), "/", len(gts))

    cw, ch = 340, 150
    canvas = Image.new("RGB", (4 * cw, 5 * ch), (15, 15, 15))
    d = ImageDraw.Draw(canvas)
    for i, e in enumerate(errs[:20]):
        col, row = i % 4, i // 4
        x, y = col * cw + 4, row * ch + 4
        g = cv2.imread(str(IMG / e["filename"]), cv2.IMREAD_GRAYSCALE)
        orig = Image.fromarray(g).convert("RGB"); orig.thumbnail((cw - 8, (ch - 34) // 2))
        canvas.paste(orig, (x, y))
        pimg = Image.fromarray(cv2.resize(cv2.cvtColor(cv2.imread(str(IMG / e["filename"])), cv2.COLOR_BGR2RGB),
                                          (pc.IMG_SIZE[1], pc.IMG_SIZE[0]))).convert("RGB").resize((cw - 8, 32), Image.NEAREST)
        canvas.paste(pimg, (x, y + (ch - 34) // 2 + 2))
        d.text((x, y + ch - 30), "gt=%s" % e["gt"], fill=(120, 255, 120))
        d.text((x, y + ch - 15), "pr=%s (%s)" % (e["pred"], e["pattern"][:9]), fill=(255, 160, 160))
    canvas.save(MONT / "parseq_val_errors.png")
    print("saved", MONT / "parseq_val_errors.png")


if __name__ == "__main__":
    main()
