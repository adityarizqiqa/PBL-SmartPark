"""SmartPark OCR — inference API for YOLO crop integration.

Loads the fine-tuned PARSeq checkpoint (A-Z0-9 plate recognition) and exposes a
simple callable that accepts an in-memory crop (numpy array) — exactly what a
YOLO `results[0].boxes` crop gives you.

Usage (integration):
    from scripts.benchmark.predict import load_ocr, predict_plate

    ocr = load_ocr("checkpoints/parseq_plate_best.pt")
    out = ocr(crop_bgr)          # crop_bgr: np.ndarray HxWx3 (OpenCV BGR)
    # -> {"text": "B1234XYZ", "confidence": 0.97, "valid_format": True}

    # Batch (faster):
    outs = ocr.predict_batch([crop1, crop2, crop3])

CLI:
    python -m scripts.benchmark.predict --ckpt checkpoints/parseq_plate_best.pt \
        --image path/to/crop.jpg
"""
import argparse
import json
import re
import sys
from pathlib import Path

import cv2
import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import parseq_common as pc  # noqa: E402

# Indonesian plate format: 1-2 letters + 1-4 digits + 1-3 letters
PLATE_RE = re.compile(r"^[A-Z]{1,2}\d{1,4}[A-Z]{1,3}$")


def normalize_plate(text):
    """Uppercase and strip everything that is not A-Z / 0-9."""
    return re.sub(r"[^A-Z0-9]", "", str(text).upper())


def is_valid_plate(text):
    return bool(PLATE_RE.match(text))


class PlateOCR:
    """PARSeq-based plate recognizer that accepts numpy crops."""

    def __init__(self, ckpt_path, device="cuda", img_size=(32, 128)):
        self.device = torch.device(device if (device == "cpu" or torch.cuda.is_available()) else "cpu")
        self.img_size = tuple(img_size)
        self.model, self.tok = pc.build_model(pretrained=True)
        st = torch.load(str(ckpt_path), map_location="cpu", weights_only=False)
        state = st["model"] if isinstance(st, dict) and "model" in st else st
        self.model.load_state_dict(state)
        self.model.to(self.device).eval()
        self.meta = {k: v for k, v in (st.items() if isinstance(st, dict) else [])
                     if k in ("epoch", "best_cer", "charset", "img_h", "img_w", "arch")}

    # ---------- preprocessing ----------
    def _prep(self, img_bgr):
        """BGR numpy -> normalized CHW float32 (PARSeq native: RGB 32x128, [-1,1])."""
        if img_bgr is None:
            raise ValueError("empty image")
        if img_bgr.ndim == 2:                                  # grayscale
            img_bgr = cv2.cvtColor(img_bgr, cv2.COLOR_GRAY2BGR)
        elif img_bgr.shape[2] == 4:                            # RGBA
            img_bgr = cv2.cvtColor(img_bgr, cv2.COLOR_BGRA2BGR)
        rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        rgb = cv2.resize(rgb, (self.img_size[1], self.img_size[0]), interpolation=cv2.INTER_AREA)
        x = rgb.astype(np.float32) / 255.0
        x = (x - 0.5) / 0.5
        return np.transpose(x, (2, 0, 1))

    # ---------- inference ----------
    @torch.no_grad()
    def predict_batch(self, crops, return_confidence=True):
        """crops: list of BGR numpy arrays. Returns list of dicts."""
        if not crops:
            return []
        xs = np.stack([self._prep(c) for c in crops])
        xb = torch.from_numpy(xs).to(self.device)
        logits = self.model.forward(self.tok, xb)              # [N, L, V]
        probs = logits.softmax(-1)
        texts, seq_probs = self.tok.decode(probs)

        out = []
        for text, sp in zip(texts, seq_probs):
            text = normalize_plate(text)
            conf = float(torch.exp(torch.log(sp.clamp_min(1e-12)).mean())) if return_confidence and len(sp) else 0.0
            out.append({
                "text": text,
                "confidence": round(conf, 4),
                "valid_format": is_valid_plate(text),
            })
        return out

    def __call__(self, crop):
        return self.predict_batch([crop])[0]


def load_ocr(ckpt_path, device="cuda"):
    """Load once, reuse for many crops (recommended in a service)."""
    return PlateOCR(ckpt_path, device=device)


# ---------- convenience for YOLO integration ----------
def predict_from_yolo_result(ocr, yolo_result, image=None, pad_ratio=0.08, conf_threshold=0.25):
    """Run OCR on the highest-confidence plate box from an ultralytics result.

    yolo_result: ultralytics Results object (or None to use `image` + boxes only).
    Returns a list (one dict per detected plate), empty if nothing detected.
    """
    if yolo_result is None or yolo_result.boxes is None or len(yolo_result.boxes) == 0:
        return []
    img = image if image is not None else yolo_result.orig_img
    h, w = img.shape[:2]
    xyxy = yolo_result.boxes.xyxy.cpu().numpy()
    confs = yolo_result.boxes.conf.cpu().numpy()

    crops, meta = [], []
    for box, cf in zip(xyxy, confs):
        if cf < conf_threshold:
            continue
        x1, y1, x2, y2 = box
        pad_x = (x2 - x1) * pad_ratio
        pad_y = (y2 - y1) * pad_ratio
        X1 = max(0, int(x1 - pad_x)); Y1 = max(0, int(y1 - pad_y))
        X2 = min(w, int(x2 + pad_x)); Y2 = min(h, int(y2 + pad_y))
        if X2 - X1 < 8 or Y2 - Y1 < 8:
            continue
        crops.append(img[Y1:Y2, X1:X2])
        meta.append({"box": [float(x1), float(y1), float(x2), float(y2)],
                     "det_conf": float(cf)})

    if not crops:
        return []
    results = ocr.predict_batch(crops)
    for r, m in zip(results, meta):
        r.update(m)
    return results


def main():
    ap = argparse.ArgumentParser(description="SmartPark OCR inference on a cropped plate image")
    ap.add_argument("--ckpt", default=str(ROOT / "checkpoints" / "parseq_plate_best.pt"))
    ap.add_argument("--image", required=True, help="path to a cropped plate image")
    ap.add_argument("--device", default="cuda")
    ap.add_argument("--json", action="store_true", help="print JSON instead of plain text")
    a = ap.parse_args()

    img = cv2.imread(a.image, cv2.IMREAD_COLOR)
    if img is None:
        raise SystemExit(f"cannot read image: {a.image}")

    ocr = load_ocr(a.ckpt, device=a.device)
    res = ocr(img)
    if a.json:
        print(json.dumps(res, indent=2, ensure_ascii=False))
    else:
        print(res["text"])


if __name__ == "__main__":
    main()
