"""Run the TF OCR training for several seeds sequentially, then summarize.

Usage:
  python scripts/ocr_tf/run_tf_seeds.py --seeds 42,43,44
"""
import argparse
import csv
import json
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(r"D:\CollegeFile\SMT 5\SmartPark-OCR")
PY = r"D:\spocr-tf-venv\Scripts\python.exe"
SCRIPT = ROOT / "scripts" / "ocr_tf" / "train_tfocr.py"
RUNS = ROOT / "reports" / "data_v2" / "tfocr"
OUT = ROOT / "reports" / "data_v2"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", default="42,43,44")
    ap.add_argument("--epochs", type=int, default=80)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--patience", type=int, default=30)
    ap.add_argument("--aug", type=int, default=1)
    a = ap.parse_args()
    seeds = [int(s) for s in a.seeds.split(",")]

    logf = open(OUT / "train_tf_multiseed.log", "a", encoding="utf-8")

    def p(*args):
        m = " ".join(str(x) for x in args)
        print(m, flush=True); logf.write(m + "\n"); logf.flush()

    env = dict(os.environ)
    env["TF_CPP_MIN_LOG_LEVEL"] = "2"
    env["PYTHONUNBUFFERED"] = "1"

    rows = []
    for seed in seeds:
        tag = "tfocr_v2_seed%d" % seed
        console = OUT / ("%s_console.txt" % tag)
        cmd = [PY, str(SCRIPT), "--epochs", str(a.epochs), "--batch", str(a.batch),
               "--lr", str(a.lr), "--patience", str(a.patience), "--aug", str(a.aug),
               "--seed", str(seed), "--tag", tag]
        p("RUN", tag, "|", time.strftime("%H:%M:%S"))
        t0 = time.time()
        proc = subprocess.run(cmd, cwd=str(ROOT), env=env,
                              capture_output=True, text=True, encoding="utf-8", errors="replace")
        mins = (time.time() - t0) / 60.0
        if proc.returncode != 0:
            p("  FAILED rc=%s" % proc.returncode)
            p((proc.stderr or "")[-1500:])
            continue

        mfile = RUNS / tag / "metrics.json"
        if not mfile.exists():
            p("  no metrics.json for", tag); continue
        d = json.loads(mfile.read_text(encoding="utf-8"))
        rows.append({"seed": seed, "tag": tag, "val_cer": round(d["cer"], 4),
                     "val_em": d["em"], "val_n": 285, "best_epoch": d["epoch"],
                     "minutes": round(mins, 1)})
        p("  best val CER %.4f EM %d @ep%d | %.1f min" % (d["cer"], d["em"], d["epoch"], mins))

        with open(OUT / "tf_multiseed.csv", "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            w.writeheader(); w.writerows(rows)

    if rows:
        cers = [r["val_cer"] for r in rows]
        ems = [r["val_em"] for r in rows]
        summary = {"n_runs": len(rows),
                   "val_cer_mean": round(statistics.mean(cers), 4),
                   "val_cer_std": round(statistics.pstdev(cers), 4) if len(cers) > 1 else 0.0,
                   "val_cer_min": min(cers), "val_cer_max": max(cers),
                   "val_em_mean": round(statistics.mean(ems), 1),
                   "val_em_min": min(ems), "val_em_max": max(ems)}
        (OUT / "tf_multiseed_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        p("SUMMARY " + json.dumps(summary))
    logf.close()


if __name__ == "__main__":
    main()
