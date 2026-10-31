"""End-to-end smoke test: YOLO detection -> crop -> PARSeq OCR.

Verifies the integration contract that the SmartPark backend will use.
Runs on a few images from the detection dataset and prints detected plate text.

Usage:
  python scripts/benchmark/smoke_yolo_ocr.py --yolo checkpoints/plate_detector.pt \
      --ocr checkpoints/parseq_plate_best.pt --limit 5
"""
import argparse
import sys
from pathlib import Path

import cv2

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "scripts" / "benchmark"))

from predict import load_ocr, predict_from_yolo_result  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--yolo", default=str(ROOT / "checkpoints" / "plate_detector.pt"))
    ap.add_argument("--ocr", default=str(ROOT / "checkpoints" / "parseq_plate_best.pt"))
    ap.add_argument("--images", default=str(ROOT / "plate_detection_dataset" / "plate_detection_dataset" / "images"))
    ap.add_argument("--limit", type=int, default=5)
    ap.add_argument("--conf", type=float, default=0.25)
    ap.add_argument("--device", default="cuda")
    a = ap.parse_args()

    from ultralytics import YOLO

    det = YOLO(a.yolo)
    ocr = load_ocr(a.ocr, device=a.device)
    print("models loaded")

    img_dir = Path(a.images)
    files = sorted([p for p in img_dir.glob("*") if p.suffix.lower() in (".jpg", ".jpeg", ".png")])[:a.limit]
    if not files:
        raise SystemExit(f"no images in {img_dir}")

    n_det = n_ok = 0
    for p in files:
        img = cv2.imread(str(p), cv2.IMREAD_COLOR)
        res = det.predict(img, conf=a.conf, verbose=False)[0]
        plates = predict_from_yolo_result(ocr, res, image=img, conf_threshold=a.conf)
        n_det += len(plates)
        for r in plates:
            if r["valid_format"]:
                n_ok += 1
        shown = ", ".join("%s(%.2f)" % (r["text"], r["confidence"]) for r in plates) or "-"
        print("%-45s boxes=%d -> %s" % (p.name[:45], len(res.boxes), shown))

    print("\nSMOKE RESULT: %d images, %d plate crops, %d valid format" % (len(files), n_det, n_ok))
    print("PASS" if n_det > 0 else "WARN: detector produced no boxes (check --yolo path / --conf)")


if __name__ == "__main__":
    main()
