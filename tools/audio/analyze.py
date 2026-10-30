"""Analyse every generated OGG: duration, peak, RMS, LUFS (music), DC, NaN, loop seam, band balance, tail.

python analyze.py [music|sfx|all] [--csv out.csv]
"""
import os
import sys
import glob
import json
import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import afx  # noqa: E402


def bands(x):
    m = x if x.ndim == 1 else x.mean(axis=1)
    spec = np.abs(np.fft.rfft(m * np.hanning(len(m)))) ** 2
    f = np.fft.rfftfreq(len(m), 1 / afx.SR)
    tot = spec.sum() + 1e-20
    edges = [(0, 200), (200, 2000), (2000, 8000), (8000, 22050)]
    return [100 * spec[(f >= a) & (f < b)].sum() / tot for a, b in edges]


def tail_time(x, thresh_db=-40):
    a = np.abs(x if x.ndim == 1 else x.max(axis=1))
    pk_i = int(np.argmax(a))
    w = int(0.01 * afx.SR)
    env = np.maximum.reduceat(a, np.arange(0, len(a), w))
    thr = a.max() * afx.db(thresh_db)
    idx = np.nonzero(env > thr)[0]
    return (idx[-1] * w - pk_i) / afx.SR if len(idx) else 0.0


def analyse(path):
    x, sr = sf.read(path, always_2d=False)
    assert sr == afx.SR, (path, sr)
    name = os.path.splitext(os.path.basename(path))[0]
    r = dict(name=name, path=os.path.relpath(path, afx.ROOT).replace("\\", "/"), sr=sr,
             ch=1 if x.ndim == 1 else x.shape[1], dur=len(x) / sr)
    r["nan"] = bool(np.isnan(x).any())
    r["peak_db"] = float(20 * np.log10(np.max(np.abs(x)) + 1e-12))
    r["rms_db"] = float(10 * np.log10(np.mean(x ** 2) + 1e-20))
    r["dc"] = float(np.abs(np.mean(x)))
    r["loop"] = name.endswith("_loop")
    r["seam"] = afx.seam_ratio(x) if r["loop"] else None
    r["lufs"] = float(afx.lufs(x)) if len(x) > afx.SR * 0.4 else None
    r["bands"] = bands(x)
    r["tail40"] = tail_time(x)
    # first/last sample magnitude (click check for one-shots)
    m = np.abs(x if x.ndim == 1 else x.max(axis=1))
    pk = m.max() + 1e-12
    r["edge"] = float(max(m[0], m[-8:].max()) / pk)
    if r["loop"]:
        mono = x if x.ndim == 1 else x.mean(axis=1)
        k = min(4096, len(mono) // 2)
        sp = np.concatenate([mono[-k:], mono[:k]])
        h = afx.hp0(sp, 3000, 4)
        whole = np.abs(afx.hp0(mono, 3000, 4))
        ref = max(np.percentile(whole, 99.5), 2e-3 * np.abs(mono).max()) + 1e-9
        r["seam_click"] = float(np.abs(h[k - 48:k + 48]).max() / ref)
    else:
        r["seam_click"] = None
    r["kb"] = os.path.getsize(path) / 1024
    return r


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    pats = []
    if which in ("music", "all"):
        pats += [os.path.join(afx.MUSIC_DIR, "*.ogg"), os.path.join(afx.MUSIC_DIR, "radio", "*.ogg")]
    if which in ("sfx", "all"):
        pats += [os.path.join(afx.SFX_DIR, "*.ogg")]
    files = sorted(sum([glob.glob(p) for p in pats], []))
    rows = [analyse(f) for f in files]
    bad = []
    print(f"{'name':30s} {'dur':>6s} {'ch':>2s} {'peak':>6s} {'rms':>6s} {'lufs':>6s} {'seam':>6s} {'edge':>5s} {'click':>5s} "
          f"{'<200':>5s} {'-2k':>5s} {'-8k':>5s} {'>8k':>5s} {'t40':>5s}")
    for r in rows:
        b = r["bands"]
        print(f"{r['name']:30s} {r['dur']:6.2f} {r['ch']:2d} {r['peak_db']:6.1f} {r['rms_db']:6.1f} "
              f"{(r['lufs'] if r['lufs'] is not None else float('nan')):6.1f} "
              f"{(r['seam'] if r['seam'] is not None else float('nan')):6.2f} {r['edge']:5.2f} "
              f"{(r['seam_click'] if r['seam_click'] is not None else float('nan')):5.2f} "
              f"{b[0]:5.1f} {b[1]:5.1f} {b[2]:5.1f} {b[3]:5.1f} {r['tail40']:5.2f}")
        if r["nan"] or r["peak_db"] > -0.95 or r["dc"] > 0.01 or (r["loop"] and (r["seam"] > 4 or (r["seam_click"] > 2.0 and r["seam"] > 1.0))) or \
                (not r["loop"] and r["edge"] > 0.05):
            bad.append(r["name"])
    tot = sum(r["kb"] for r in rows)
    print(f"\n{len(rows)} files, {tot / 1024:.1f} MB total. Problems: {bad or 'none'}")
    with open(os.path.join(os.path.dirname(__file__), f"analysis_{which}.json"), "w") as f:
        json.dump(rows, f, indent=1)


if __name__ == "__main__":
    main()
