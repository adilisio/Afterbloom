"""Regenerate all AFTERBLOOM sound effects (fully procedural, deterministic).

Usage:  python gen_sfx.py                 # everything
        python gen_sfx.py pistol_fire_1 doorbell   # subset (names or prefixes ending in *)
"""
import os
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
import afx  # noqa: E402


def registry():
    import sfx_a
    import sfx_b  # noqa: F401  (registers into sfx_a.REG)
    return sfx_a.REG


def build(name):
    t = time.time()
    fn, idx, loop, stereo, peak = registry()[name]
    rng = afx.rng_for(name, 1)
    try:
        x = np.nan_to_num(np.asarray(fn(rng, idx), dtype=np.float64))
    except Exception as e:  # report and continue
        import traceback
        tb = traceback.extract_tb(e.__traceback__)[-1]
        return name, -1, f"ERROR {type(e).__name__}: {e} @ {os.path.basename(tb.filename)}:{tb.lineno}"

    if not loop:
        x = afx.trim_silence(x, -62, 0.02)
    x = afx.save_sfx(name, x, peak_db=peak, loop=loop, stereo_ok=stereo)
    return name, x.shape[0] / afx.SR, f"{time.time() - t:.1f}s"


if __name__ == "__main__":
    reg = registry()
    names = []
    for a in sys.argv[1:]:
        names += [n for n in reg if (n.startswith(a[:-1]) if a.endswith("*") else n == a)]
    names = names or list(reg)
    with Pool(11) as p:
        for name, dur, el in p.imap_unordered(build, names):
            print(f"{name:28s} {dur:6.2f}s ({el})", flush=True)
    print(len(names), "sfx written")
