import json
import os
import sys


def to_ipynb(src_path, out_path):
    src = open(src_path, encoding="utf-8").read().split("\n")
    cells = []
    cur_type = None
    cur_lines = []

    def flush():
        if cur_type is None or not cur_lines:
            return
        while cur_lines and cur_lines[-1].strip() == "":
            cur_lines.pop()
        text = "\n".join(cur_lines) + "\n"
        if cur_type == "markdown":
            cells.append({"cell_type": "markdown", "metadata": {}, "source": text})
        else:
            cells.append({
                "cell_type": "code",
                "execution_count": None,
                "metadata": {},
                "outputs": [],
                "source": text,
            })

    for line in src:
        if line.startswith("# %% [markdown]"):
            flush()
            cur_type, cur_lines = "markdown", []
            continue
        if line.startswith("# %%"):
            flush()
            cur_type, cur_lines = "code", []
            continue
        if cur_type == "markdown" and line.startswith("# "):
            cur_lines.append(line[2:])
        elif cur_type == "markdown" and line.strip() == "#":
            cur_lines.append("")
        elif cur_type is not None:
            cur_lines.append(line)
    flush()

    nb = {
        "cells": cells,
        "metadata": {
            "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
            "language_info": {"name": "python", "version": "3.12.13", "mimetype": "text/x-python"},
        },
        "nbformat": 4,
        "nbformat_minor": 4,
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=1, ensure_ascii=False)
    n_md = sum(1 for c in cells if c["cell_type"] == "markdown")
    n_code = len(cells) - n_md
    print("%-58s -> %s  (%d cells: %d md, %d code)"
          % (src_path, os.path.basename(out_path), len(cells), n_md, n_code))
    return cells


if __name__ == "__main__":
    jobs = [
        (".nbgen/f0.py", "fase1_eda_audit/indonesian-plate-eda-and-audit.ipynb"),
        (".nbgen/f1.py", "fase1_label_audit/detection-indonesian-plate-label-audit.ipynb"),
        (".nbgen/f2.py", "fase2_prep_detector/detection-indonesian-plate-prep-detector.ipynb"),
        (".nbgen/f3.py", "fase3_train_detector/detection-indonesian-plate-train-detector.ipynb"),
        (".nbgen/f4.py", "fase4_prep_ocr/recognition-indonesian-plate-prep-ocr.ipynb"),
        (".nbgen/f5.py", "fase5_train_ocr/recognition-indonesian-plate-train-ocr.ipynb"),
        (".nbgen/f8_det.py", "fase8_export_detector/detection-indonesian-plate-export-tflite.ipynb"),
    ]
    for s, o in jobs:
        cells = to_ipynb(s, o)
        # validasi: tiap sel code harus punya source non-kosong dan outputs list
        for i, c in enumerate(cells):
            assert c["source"].strip(), "sel kosong di %s index %d" % (o, i)
            if c["cell_type"] == "code":
                assert c["outputs"] == [], "outputs harus kosong (belum dijalankan)"
        json.load(open(o, encoding="utf-8"))
        print("   valid JSON, semua sel non-kosong, outputs kosong")
    print("done.")
