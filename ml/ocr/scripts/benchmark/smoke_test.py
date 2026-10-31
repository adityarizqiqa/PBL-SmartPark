"""Smoke test for the OCR benchmark stack.

Verifies: baseline CRNN loads + preprocesses + decodes; PARSeq loads + decodes;
CER/EM helpers agree; and a checkpoint round-trips. Run from the parseq venv.
"""
import sys
from pathlib import Path

import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "scripts" / "benchmark"))
import phase5_transfer as p5  # noqa: E402
import parseq_common as pc  # noqa: E402

IMG = p5.IMG


def main():
    ok = True
    # 1. baseline CRNN
    ck = ROOT / "artifacts" / "transfer_run_bench_seed42" / "ocr_model.pt"
    st = torch.load(str(ck), map_location="cpu", weights_only=False)
    p5.IMG_H, p5.IMG_W = st["img_h"], st["img_w"]
    m = p5.CRNN(backbone="wp"); m.load_state_dict(st["model"]); m.eval()
    g = __import__("cv2").imread(str(IMG / "DataTrain1.png"), __import__("cv2").IMREAD_GRAYSCALE)
    c = p5.prep(g)
    assert c.shape == (p5.IMG_H, p5.IMG_W), c.shape
    out = m(torch.from_numpy(np.stack([p5.norm(c)])).unsqueeze(1))
    assert out.shape[0] == 1 and out.shape[2] == p5.NUM_CLASSES
    print("[OK] baseline CRNN forward", tuple(out.shape))

    # 2. PARSeq load + decode
    model, tok = pc.build_model(pretrained=True)
    model.eval()
    x = torch.from_numpy(np.stack([pc.preprocess(IMG / "DataTrain1.png")]))
    assert x.shape == (1, 3, 32, 128), x.shape
    logits = model.forward(tok, x)
    texts, _ = tok.decode(logits.softmax(-1))
    print("[OK] PARSeq forward", tuple(logits.shape), "| decode:", texts[0])

    # 3. metric helpers agree
    a, b = p5.ed("B1234XY", "B1234XY"), pc.edit_distance("B1234XY", "B1234XY")
    assert a == b == 0
    assert p5.ed("B1234XZ", "B1234XY") == pc.edit_distance("B1234XZ", "B1234XY")
    print("[OK] edit distance helpers agree")

    # 4. checkpoint round-trip
    tmp = ROOT / "reports" / "improvement_v1" / "ocr_benchmark" / "_smoke_ckpt.pt"
    torch.save({"model": st["model"], "epoch": 0, "img_h": st["img_h"], "img_w": st["img_w"]}, tmp)
    st2 = torch.load(str(tmp), map_location="cpu", weights_only=False)
    assert st2["img_h"] == st["img_h"]
    tmp.unlink()
    print("[OK] checkpoint round-trip")
    print("SMOKE PASS" if ok else "SMOKE FAIL")


if __name__ == "__main__":
    main()
