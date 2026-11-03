import json
import os
import shutil

# Bangun prefix dari hex supaya tidak bergantung pada pengetikan literal.
PREFIX_SLUG = bytes.fromhex("646574656374696f6e2d").decode()   # "detection-"
PREFIX_TITLE = bytes.fromhex("446574656374696f6e20").decode()  # "Detection "

JOBS = [
    "fase1_label_audit/kernel-metadata.json",
    "fase2_prep_detector/kernel-metadata.json",
    "fase3_train_detector/kernel-metadata.json",
]

plan = []
for mp in JOBS:
    folder = os.path.dirname(mp)
    m = json.load(open(mp, encoding="utf-8"))

    owner, old_slug = m["id"].split("/")
    new_slug = PREFIX_SLUG + old_slug
    new_title = PREFIX_TITLE + m["title"]

    old_file = m["code_file"]
    new_file = PREFIX_SLUG + old_file

    # kernel_sources ikut di-prefix (Fase 3 -> Fase 2)
    new_sources = []
    for src in m.get("kernel_sources", []):
        o, s = src.split("/")
        new_sources.append(o + "/" + PREFIX_SLUG + s)

    plan.append(dict(folder=folder, meta=mp, old_slug=old_slug, new_slug=new_slug,
                     old_title=m["title"], new_title=new_title,
                     old_file=old_file, new_file=new_file,
                     old_sources=m.get("kernel_sources", []), new_sources=new_sources,
                     doc=m))

print("=== RENCANA RENAME ===")
for p in plan:
    print()
    print("folder      :", p["folder"])
    print("  title     : %r" % p["old_title"])
    print("           -> %r" % p["new_title"])
    print("  slug      : %s" % p["old_slug"])
    print("           -> %s" % p["new_slug"])
    print("  code_file : %s -> %s" % (p["old_file"], p["new_file"]))
    if p["old_sources"]:
        print("  kernel_sources:", p["old_sources"], "->", p["new_sources"])

# --- terapkan ---
for p in plan:
    old_path = os.path.join(p["folder"], p["old_file"])
    new_path = os.path.join(p["folder"], p["new_file"])
    if os.path.exists(old_path):
        if os.path.exists(new_path):
            os.remove(new_path)
        shutil.move(old_path, new_path)
        print("\nmoved: %s -> %s" % (old_path, new_path))
    else:
        print("\nSKIP move (tidak ada):", old_path)

    d = p["doc"]
    d["title"] = p["new_title"]
    d["code_file"] = p["new_file"]
    if p["new_sources"]:
        d["kernel_sources"] = p["new_sources"]
    with open(p["meta"], "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("updated metadata:", p["meta"], "(id sengaja masih lama)")

# --- verifikasi byte-level ---
print()
print("=== VERIFIKASI BYTE ===")
for p in plan:
    mp = p["meta"]
    raw = open(mp, "rb").read()
    d = json.loads(raw.decode("utf-8"))
    print()
    print(mp)
    print("  id           :", d["id"])
    print("  title        :", ascii(d["title"]))
    print("  code_file    :", ascii(d["code_file"]))
    print("  kernel_sources:", d.get("kernel_sources"))
    print("  file ada?    :", os.path.exists(os.path.join(p["folder"], d["code_file"])))
    print("  title hex    :", d["title"].encode().hex()[:64])
