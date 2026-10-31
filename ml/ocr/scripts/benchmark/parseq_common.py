"""Shared PARSeq utilities for the SmartPark OCR benchmark.

Vendored PARSeq (Apache-2.0, https://github.com/baudm/parseq) model code lives in
scripts/benchmark/parseq_vendor. This module builds the model, loads the
pretrained weights, applies PARSeq-native preprocessing (RGB, 32x128, [-1,1]),
and decodes outputs. Labels are A-Z0-9 (subset of PARSeq's 94-char charset).
"""
import sys
from pathlib import Path

import cv2
import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[2]
VEND = ROOT / "scripts" / "benchmark" / "parseq_vendor"
if str(VEND) not in sys.path:
    sys.path.insert(0, str(VEND))

from strhub.models.parseq.model import PARSeq  # noqa: E402
from strhub.data.utils import Tokenizer  # noqa: E402

CHARSET = "".join(chr(i) for i in range(33, 127))  # 94 printable ASCII
IMG_SIZE = (32, 128)

# Pretrained base weights. Checked in order so the repo can ship a single copy
# under checkpoints/ instead of duplicating it inside the vendored package.
_PRETRAINED_CANDIDATES = [
    ROOT / "checkpoints" / "parseq_pretrained_base.pt",
    VEND / "parseq-bb5792a6.pt",
]
PRETRAINED = next((p for p in _PRETRAINED_CANDIDATES if p.exists()), _PRETRAINED_CANDIDATES[0])

CFG = dict(num_tokens=None, max_label_length=25, img_size=[32, 128], patch_size=[4, 8], embed_dim=384,
           enc_num_heads=6, enc_mlp_ratio=4, enc_depth=12, dec_num_heads=12, dec_mlp_ratio=4, dec_depth=1,
           decode_ar=True, refine_iters=1, dropout=0.1)


def get_tokenizer():
    return Tokenizer(CHARSET)


def build_model(pretrained=True):
    tok = get_tokenizer()
    m = PARSeq(num_tokens=len(tok), **{k: v for k, v in CFG.items() if k != "num_tokens"})
    if pretrained and PRETRAINED.exists():
        sd = torch.load(str(PRETRAINED), map_location="cpu", weights_only=False)
        missing, unexpected = m.load_state_dict(sd, strict=False)
        assert not missing and not unexpected, (missing[:5], unexpected[:5])
    return m, tok


def preprocess(path):
    """PARSeq-native preprocessing: BGR->RGB, resize to 32x128, normalize [-1,1]."""
    bgr = cv2.imread(str(path), cv2.IMREAD_COLOR)
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    rgb = cv2.resize(rgb, (IMG_SIZE[1], IMG_SIZE[0]), interpolation=cv2.INTER_AREA)
    x = rgb.astype(np.float32) / 255.0
    x = (x - 0.5) / 0.5
    return np.transpose(x, (2, 0, 1))  # CHW


@torch.no_grad()
def decode_batch(model, tok, paths, device, max_length=None):
    xs = np.stack([preprocess(p) for p in paths])
    xb = torch.from_numpy(xs).to(device)
    logits = model.forward(tok, xb, max_length=max_length)
    probs = logits.softmax(-1)
    texts, _ = tok.decode(probs)
    return [t.upper() for t in texts]


def edit_distance(a, b):
    p = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        c = [i] + [0] * len(b)
        for j in range(1, len(b) + 1):
            c[j] = min(p[j] + 1, c[j - 1] + 1, p[j - 1] + (a[i - 1] != b[j - 1]))
        p = c
    return p[-1]


def cer_em(preds, gts):
    cer = sum(edit_distance(p, g) for p, g in zip(preds, gts)) / max(1, sum(len(g) for g in gts))
    em = sum(1 for p, g in zip(preds, gts) if p == g)
    return cer, em
