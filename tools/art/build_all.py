"""Regenerate every AFTERBLOOM 2D texture and write assets/textures/gen/ART.md.

    python build_all.py              # regenerate everything, then write ART.md
    python build_all.py --manifest   # only (re)write ART.md from existing files
    python build_all.py posters tv   # regenerate only these modules (+ ART.md)
"""
from __future__ import annotations

import importlib
import sys
import time

from PIL import Image

from common import OUT

MODULES = [
    ("magazines", "Magazine covers"),
    ("posters", "Posters & billboard"),
    ("signs", "Signs"),
    ("logos", "Logos"),
    ("wallpapers", "Tileable wallpapers"),
    ("docs", "Newspaper & notes"),
    ("photos", "Framed photos"),
    ("tv", "TV graphics (640x480, shown under the CRT shader)"),
    ("ui", "UI"),
    ("labels", "Product labels"),
]

HEADER = """# Generated 2D art — AFTERBLOOM

All files in this folder are **original** procedural illustrations generated with Python + Pillow + numpy by the
scripts in `tools/art/` (fixed seeds — rerun `tools/.venv/Scripts/python.exe tools/art/build_all.py` to rebuild
everything, or `build_all.py <module>` for one group). Fonts are the stock Windows fonts (Georgia, Palatino,
Impact, Arial Black, Franklin Gothic, Bahnschrift, Segoe Script, Ink Free, Courier, Times).

Palette: cream `#F3E6C8`, teal `#2F7F7A`, coral `#E07A5F`, mustard `#E3B23C`, navy `#23395B`, warm red `#C8553D`;
Bloom violet `#9B5CFF` is reserved for Bloom-related things (comet tail hint, crystal flowers, spore specks, dust/cloud).
`*_aged` variants are the 1978 versions (faded, yellowed, stained, torn/rusted, overgrown with violet crystal flowers).

Shared code: `common.py` (supersampled Canvas, fonts, tileable noise, halftone, print finish, paper/sign aging),
`illus.py` (Tuppence, rockets, lighthouses, comets, houses, TV set, shelter portal, Halcyon emblem/lockup,
Civil Defense emblem, ribbons, bursts). `contact.py` makes contact sheets for review.

Alpha notes: logos, icons, compass strip and aged paper items (torn edges) are RGBA — use alpha-scissor or
alpha-blend materials. Wallpapers, `ui_paper`, `ui_leather` tile seamlessly (seam-checked).
"""


def write_manifest():
    lines = [HEADER]
    listed = set()
    for mod, title in MODULES:
        m = importlib.import_module(mod)
        lines.append(f"\n## {title}  (`tools/art/{mod}.py`)\n")
        lines.append("| File | Size | What it is | Where it goes in game |")
        lines.append("|---|---|---|---|")
        for entry in m.MANIFEST:
            name, desc, use = entry[0], entry[1], entry[2]
            p = OUT / f"{name}.png"
            if p.exists():
                with Image.open(p) as im:
                    size = f"{im.width}x{im.height}" + (" RGBA" if im.mode == "RGBA" else "")
            else:
                size = "MISSING"
            lines.append(f"| `{name}.png` | {size} | {desc} | {use} |")
            listed.add(name)
    extra = sorted(p.stem for p in OUT.glob("*.png") if p.stem not in listed)
    if extra:
        lines.append("\n## Unlisted files\n")
        lines += [f"- `{e}.png`" for e in extra]
    (OUT / "ART.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    missing = [l for l in lines if "MISSING" in l]
    print(f"ART.md: {len(listed)} entries, {len(missing)} missing, {len(extra)} unlisted")


def main(args):
    if "--manifest" not in args:
        wanted = [a for a in args if not a.startswith("-")]
        for mod, _ in MODULES:
            if wanted and mod not in wanted:
                continue
            t = time.time()
            m = importlib.import_module(mod)
            for fn in m.ALL:
                fn()
            print(f"[{mod}] {time.time() - t:.0f}s")
    write_manifest()


if __name__ == "__main__":
    main(sys.argv[1:])
