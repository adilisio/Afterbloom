"""AFTERBLOOM audio DSP core: synthesis primitives, filters, reverb, looping, mastering, IO, analysis.

Everything here is deterministic given an explicit numpy Generator.
"""
from __future__ import annotations

import os
import numpy as np
import scipy.signal as sps
from scipy.ndimage import minimum_filter1d, uniform_filter1d
import soundfile as sf
from numba import njit

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")


# ----------------------------------------------------------------------------------------- basics
def n_of(sec: float) -> int:
    return int(round(sec * SR))


def tvec(sec: float) -> np.ndarray:
    return np.arange(n_of(sec)) / SR


def db(x):
    return 10 ** (x / 20.0)


def rng_for(name: str, seed: int = 0) -> np.random.Generator:
    h = 0
    for c in name:
        h = (h * 131 + ord(c)) % 2**31
    return np.random.default_rng(h + seed * 7919)


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    if x.shape[0] >= n:
        return x[:n]
    pad = [(0, n - x.shape[0])] + [(0, 0)] * (x.ndim - 1)
    return np.pad(x, pad)


def mix_at(dst: np.ndarray, src: np.ndarray, start: int, gain: float = 1.0):
    """Add src into dst at sample offset start (clipped to dst length). Works for mono or stereo."""
    if start < 0:
        src = src[-start:]
        start = 0
    end = min(dst.shape[0], start + src.shape[0])
    if end <= start:
        return dst
    if dst.ndim == 2 and src.ndim == 1:
        dst[start:end] += gain * src[: end - start, None]
    else:
        dst[start:end] += gain * src[: end - start]
    return dst


def mix(*parts):
    n = max(p.shape[0] for p in parts)
    stereo = any(p.ndim == 2 for p in parts)
    out = np.zeros((n, 2) if stereo else n)
    for p in parts:
        mix_at(out, p, 0)
    return out


def fade(x: np.ndarray, fin: float = 0.002, fout: float = 0.005) -> np.ndarray:
    x = x.copy()
    a, b = n_of(fin), n_of(fout)
    if a > 0:
        r = np.sin(np.linspace(0, np.pi / 2, a)) ** 2
        x[:a] *= r if x.ndim == 1 else r[:, None]
    if b > 0:
        r = np.cos(np.linspace(0, np.pi / 2, b)) ** 2
        x[-b:] *= r if x.ndim == 1 else r[:, None]
    return x


def trim_silence(x: np.ndarray, thresh_db: float = -70, keep: float = 0.02) -> np.ndarray:
    a = np.abs(x if x.ndim == 1 else x.max(axis=1))
    pk = a.max() + 1e-12
    idx = np.nonzero(a > pk * db(thresh_db))[0]
    if len(idx) == 0:
        return x
    end = min(len(a), idx[-1] + n_of(keep))
    return fade(x[:end], 0.0, min(0.05, (end) / SR * 0.2))


# ----------------------------------------------------------------------------------------- noise
def white(n, rng):
    return rng.standard_normal(n)


def colored(n, rng, slope_db_oct=-3.0, lo=20.0, hi=20000.0):
    """FFT-shaped noise; periodic with period n (great for seamless loops)."""
    spec = rng.standard_normal(n // 2 + 1) + 1j * rng.standard_normal(n // 2 + 1)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1
    g = (f / 1000.0) ** (slope_db_oct / 6.0206)
    g[(f < lo) | (f > hi)] = 0
    x = np.fft.irfft(spec * g, n)
    return x / (np.std(x) + 1e-12)


def pink(n, rng):
    return colored(n, rng, -3.0)


def brown(n, rng):
    return colored(n, rng, -6.0)


def shaped_noise(n, rng, fcurve):
    """Periodic noise with arbitrary magnitude response fcurve(freqs)->gain."""
    spec = rng.standard_normal(n // 2 + 1) + 1j * rng.standard_normal(n // 2 + 1)
    f = np.fft.rfftfreq(n, 1 / SR)
    x = np.fft.irfft(spec * fcurve(f), n)
    return x / (np.std(x) + 1e-12)


def smooth_rand(n, rng, rate_hz, periodic=False):
    """Smooth random control signal in [-1,1]-ish with given bandwidth."""
    if periodic:
        x = colored(n, rng, 0.0, lo=0.0001, hi=rate_hz)
    else:
        k = max(2, int(n * rate_hz / SR) + 3)
        pts = rng.standard_normal(k)
        x = np.interp(np.linspace(0, k - 1, n), np.arange(k), pts)
        x = uniform_filter1d(x, max(1, int(SR / rate_hz / 2)))
    return x / (np.max(np.abs(x)) + 1e-12)


# ----------------------------------------------------------------------------------------- filters
def _sos(kind, f, order=2):
    if kind in ("bandpass", "bandstop"):
        f = [max(5.0, f[0]), min(SR / 2 * 0.98, f[1])]
    else:
        f = min(max(5.0, f), SR / 2 * 0.98)
    return sps.butter(order, f, btype=kind, fs=SR, output="sos")


def lp(x, f, order=2):
    return sps.sosfilt(_sos("lowpass", f, order), x, axis=0)


def hp(x, f, order=2):
    return sps.sosfilt(_sos("highpass", f, order), x, axis=0)


def bp(x, lo, hi, order=2):
    return sps.sosfilt(_sos("bandpass", (lo, hi), order), x, axis=0)


def lp0(x, f, order=2):
    """Zero-phase lowpass."""
    return sps.sosfiltfilt(_sos("lowpass", f, order), x, axis=0)


def hp0(x, f, order=2):
    return sps.sosfiltfilt(_sos("highpass", f, order), x, axis=0)


def biquad_peak(f0, q, gain_db):
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f0 / SR
    al = np.sin(w) / (2 * q)
    b = np.array([1 + al * A, -2 * np.cos(w), 1 - al * A])
    a = np.array([1 + al / A, -2 * np.cos(w), 1 - al / A])
    return b / a[0], a / a[0]


def peq(x, f0, q, gain_db):
    b, a = biquad_peak(f0, q, gain_db)
    return sps.lfilter(b, a, x, axis=0)


def shelf(x, f0, gain_db, kind="low"):
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f0 / SR
    al = np.sin(w) / 2 * np.sqrt(2)
    cw = np.cos(w)
    if kind == "low":
        b = [A * ((A + 1) - (A - 1) * cw + 2 * np.sqrt(A) * al), 2 * A * ((A - 1) - (A + 1) * cw),
             A * ((A + 1) - (A - 1) * cw - 2 * np.sqrt(A) * al)]
        a = [(A + 1) + (A - 1) * cw + 2 * np.sqrt(A) * al, -2 * ((A - 1) + (A + 1) * cw),
             (A + 1) + (A - 1) * cw - 2 * np.sqrt(A) * al]
    else:
        b = [A * ((A + 1) + (A - 1) * cw + 2 * np.sqrt(A) * al), -2 * A * ((A - 1) + (A + 1) * cw),
             A * ((A + 1) + (A - 1) * cw - 2 * np.sqrt(A) * al)]
        a = [(A + 1) - (A - 1) * cw + 2 * np.sqrt(A) * al, 2 * ((A - 1) - (A + 1) * cw),
             (A + 1) - (A - 1) * cw - 2 * np.sqrt(A) * al]
    b, a = np.array(b), np.array(a)
    return sps.lfilter(b / a[0], a / a[0], x, axis=0)


@njit(cache=True)
def _svf(x, fc, q, mode):
    n = x.shape[0]
    y = np.zeros(n)
    ic1 = 0.0
    ic2 = 0.0
    k = 1.0 / q
    for i in range(n):
        g = np.tan(np.pi * min(fc[i], 0.49 * 44100.0) / 44100.0)
        a1 = 1.0 / (1.0 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        v3 = x[i] - ic2
        v1 = a1 * ic1 + a2 * v3
        v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        if mode == 0:
            y[i] = v2
        elif mode == 1:
            y[i] = v1 * k
        else:
            y[i] = x[i] - k * v1 - v2
    return y


def svf(x, fc, q=0.707, mode="lp"):
    """Time-varying state-variable filter. fc may be scalar or per-sample array."""
    x = np.asarray(x, dtype=np.float64)
    fc = np.broadcast_to(np.asarray(fc, dtype=np.float64), x.shape[:1]).copy()
    m = {"lp": 0, "bp": 1, "hp": 2}[mode]
    if x.ndim == 2:
        return np.stack([_svf(x[:, c].copy(), fc, q, m) for c in range(x.shape[1])], axis=1)
    return _svf(x, fc, q, m)


# ----------------------------------------------------------------------------------------- oscillators
def phase_of(freq, n=None):
    freq = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,) if n else np.shape(freq))
    return 2 * np.pi * np.cumsum(freq) / SR


def sine(freq, n=None, phase0=0.0):
    return np.sin(phase_of(freq, n) + phase0)


def saw_blep(freq, n=None):
    """Band-limited-ish saw via additive (fine for low counts) - use for drones."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,) if n else np.shape(freq))
    ph = phase_of(f)
    out = np.zeros_like(ph)
    fmax = f.max()
    k = 1
    while k * fmax < SR / 2 * 0.9 and k < 80:
        amp = np.where(k * f < SR / 2 * 0.9, 1.0 / k, 0.0)
        out += amp * np.sin(k * ph)
        k += 1
    return out * 0.6


def env_exp(n, tau_sec, attack_sec=0.0005):
    t = np.arange(n) / SR
    e = np.exp(-t / max(tau_sec, 1e-5))
    a = n_of(attack_sec)
    if a > 1:
        e[:a] *= np.linspace(0, 1, a)
    return e


def env_adsr(n, a, d, s, r, hold=None):
    """ADSR with release starting at hold seconds (default: n - r)."""
    t = np.arange(n) / SR
    total = n / SR
    hold = total - r if hold is None else hold
    e = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6)))
    rel = t >= hold
    lvl = np.interp(hold, t, e) if n > 1 else 1
    e[rel] = lvl * np.clip(1 - (t[rel] - hold) / max(r, 1e-6), 0, 1)
    return e


def env_curve(n, points):
    """points: list of (time_sec, value). Linear interpolation."""
    t = np.arange(n) / SR
    ts, vs = zip(*points)
    return np.interp(t, ts, vs)


def modal(freqs, decays, amps, dur, rng=None, detune=0.0, phases=None):
    """Sum of exponentially decaying sinusoids (modal synthesis)."""
    n = n_of(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for i, (f, d, a) in enumerate(zip(freqs, decays, amps)):
        if f >= SR / 2 * 0.95:
            continue
        if rng is not None and detune:
            f *= 1 + rng.uniform(-detune, detune)
        ph = phases[i] if phases is not None else (rng.uniform(0, 2 * np.pi) if rng is not None else 0)
        out += a * np.exp(-t / d) * np.sin(2 * np.pi * f * t + ph)
    return out


@njit(cache=True)
def _ks(n, period, damp, bright, noise):
    buf = noise.copy()
    L = buf.shape[0]
    y = np.zeros(n)
    idx = 0
    prev = 0.0
    for i in range(n):
        cur = buf[idx]
        nxt = buf[(idx + 1) % L]
        v = damp * (bright * cur + (1 - bright) * 0.5 * (cur + nxt))
        y[i] = cur
        buf[idx] = v
        idx = (idx + 1) % L
    return y


def pluck(freq, dur, rng, damp=0.996, bright=0.3, pick_lp=4000):
    period = max(2, int(round(SR / freq)))
    nz = lp(rng.uniform(-1, 1, period), pick_lp)
    return _ks(n_of(dur), period, damp, bright, nz)


@njit(cache=True)
def _comb_fb(x, d, g, damp):
    n = x.shape[0]
    y = np.zeros(n)
    buf = np.zeros(d)
    lpst = 0.0
    j = 0
    for i in range(n):
        out = buf[j]
        lpst = out * (1 - damp) + lpst * damp
        buf[j] = x[i] + g * lpst
        y[i] = out
        j = (j + 1) % d
    return y


def comb(x, delay_sec, g, damp=0.2):
    return _comb_fb(np.asarray(x, dtype=np.float64), max(1, n_of(delay_sec)), g, damp)


# ----------------------------------------------------------------------------------------- distortion & dynamics
def softclip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def limiter(x, ceiling_db=-1.0, lookahead=0.004, release=0.08, loop=False):
    """Simple look-ahead peak limiter (mono or stereo)."""
    thr = db(ceiling_db) * 0.995
    a = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
    g = np.minimum(1.0, thr / np.maximum(a, 1e-9))
    w = max(1, n_of(lookahead))
    mode = "wrap" if loop else "nearest"
    g = minimum_filter1d(g, size=2 * w + 1, mode=mode)
    g = uniform_filter1d(g, size=w, mode=mode)
    # release smoothing: one-pole on the gain going up
    if release > 0:
        g = _release(g, np.exp(-1.0 / (release * SR)))
        g = np.minimum(g, minimum_filter1d(np.minimum(1.0, thr / np.maximum(a, 1e-9)), size=3, mode=mode))
    y = x * (g if x.ndim == 1 else g[:, None])
    return np.clip(y, -thr, thr)


@njit(cache=True)
def _release(g, coef):
    out = np.empty_like(g)
    s = g[0]
    for i in range(g.shape[0]):
        if g[i] < s:
            s = g[i]
        else:
            s = coef * s + (1 - coef) * g[i]
        out[i] = s
    return out


def compress(x, thr_db=-18, ratio=3.0, attack=0.01, release=0.15, makeup_db=0.0):
    a = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
    env = _envf(a, np.exp(-1 / (attack * SR)), np.exp(-1 / (release * SR)))
    lvl = 20 * np.log10(env + 1e-9)
    over = np.maximum(0, lvl - thr_db)
    gdb = -over * (1 - 1 / ratio) + makeup_db
    g = db(gdb)
    return x * (g if x.ndim == 1 else g[:, None])


@njit(cache=True)
def _envf(a, ca, cr):
    out = np.empty_like(a)
    s = 0.0
    for i in range(a.shape[0]):
        c = ca if a[i] > s else cr
        s = c * s + (1 - c) * a[i]
        out[i] = s
    return out


# ----------------------------------------------------------------------------------------- space
def make_ir(rt60=2.0, predelay=0.02, size=1.0, damp=0.5, stereo=True, seed=1, er=0.4, lowcut=80):
    """Synthesize a room/hall impulse response: early reflections + band-dependent exp-decaying noise."""
    rng = np.random.default_rng(seed)
    dur = rt60 * 1.1 + predelay + 0.05
    n = n_of(dur)
    t = np.arange(n) / SR
    chans = []
    bands = [(20, 250, 1.15), (250, 1500, 1.0), (1500, 5000, 0.75 - 0.3 * damp), (5000, 20000, 0.5 - 0.3 * damp)]
    for ch in range(2 if stereo else 1):
        ir = np.zeros(n)
        for lo, hi, k in bands:
            nz = rng.standard_normal(n)
            nz = bp(nz, lo, min(hi, SR / 2 * 0.95), 2)
            rt = max(0.05, rt60 * k)
            ir += nz * np.exp(-6.9078 * t / rt)
        # build-up (diffusion onset)
        onset = n_of(predelay)
        ir[:onset] = 0
        ramp = n_of(0.03 * size + 0.005)
        ir[onset:onset + ramp] *= np.linspace(0, 1, ramp) ** 2
        # early reflections
        for _ in range(int(10 * size) + 4):
            d = onset * 0.3 + rng.uniform(0.002, 0.06 * size)
            k = n_of(d)
            if k < n:
                ir[k] += rng.choice([-1, 1]) * er * rng.uniform(0.3, 1.0) * np.exp(-d / 0.08)
        ir = hp(ir, lowcut)
        chans.append(ir)
    ir = np.stack(chans, axis=1) if stereo else chans[0]
    return ir / np.sqrt(np.sum(ir ** 2) / (ir.shape[1] if stereo else 1))


_IR_CACHE = {}


def reverb(x, rt60=2.0, wet=0.3, dry=1.0, predelay=0.02, size=1.0, damp=0.5, seed=1, er=0.4, lowcut=120,
           loop=False):
    """Convolution reverb. Mono input -> stereo output. Stereo input -> stereo output.
    loop=True wraps the tail around (for seamless loops; output length == input length)."""
    key = (rt60, predelay, size, damp, seed, er, lowcut)
    if key not in _IR_CACHE:
        _IR_CACHE[key] = make_ir(rt60, predelay, size, damp, True, seed, er, lowcut)
    ir = _IR_CACHE[key]
    if x.ndim == 1:
        wl = sps.oaconvolve(x, ir[:, 0])
        wr = sps.oaconvolve(x, ir[:, 1])
        drys = np.stack([x, x], axis=1)
    else:
        wl = sps.oaconvolve(x[:, 0], ir[:, 0]) * 0.85 + sps.oaconvolve(x[:, 1], ir[:, 0]) * 0.15
        wr = sps.oaconvolve(x[:, 1], ir[:, 1]) * 0.85 + sps.oaconvolve(x[:, 0], ir[:, 1]) * 0.15
        drys = x
    w = np.stack([wl, wr], axis=1) * 0.25
    n = x.shape[0]
    if loop:
        w = wrap_tail(w, n)
        out = drys * dry + w * wet
    else:
        out = np.zeros((w.shape[0], 2))
        out[:n] += drys * dry
        out += w * wet
    return out


def reverb_mono(x, **kw):
    y = reverb(x, **kw)
    return y.mean(axis=1)


def echoes(x, taps, lp_start=6000, lp_step=0.7, length=None):
    """Discrete echoes: taps = list of (delay_sec, gain). Each later tap is darker."""
    n = x.shape[0] + n_of(max(d for d, _ in taps)) + 10
    if length:
        n = max(n, n_of(length))
    out = np.zeros((n,) + x.shape[1:])
    out[: x.shape[0]] += x
    for i, (d, g) in enumerate(sorted(taps)):
        fc = max(300, lp_start * (lp_step ** i))
        mix_at(out, lp(x, fc), n_of(d), g)
    return out


def pan(x, p):
    """Constant-power pan of mono x; p in [-1,1]."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def stereo_width(x, w):
    m = (x[:, 0] + x[:, 1]) / 2
    s = (x[:, 0] - x[:, 1]) / 2 * w
    return np.stack([m + s, m - s], axis=1)


def haas(x, ms=12, side=1):
    d = n_of(ms / 1000)
    y = np.concatenate([np.zeros(d), x])[: len(x)]
    return np.stack([x, y], axis=1) if side > 0 else np.stack([y, x], axis=1)


# ----------------------------------------------------------------------------------------- looping
def wrap_tail(x, L):
    """Fold everything after L back onto the start (for loops whose content is cyclic)."""
    out = x[:L].copy()
    pos = L
    while pos < x.shape[0]:
        seg = x[pos: pos + L]
        out[: seg.shape[0]] += seg
        pos += L
    return out


def crossfade_loop(x, L, xf_sec=1.0):
    """x has length >= L + xf. Returns length-L loop where end flows into start."""
    X = n_of(xf_sec)
    assert x.shape[0] >= L + X
    out = x[:L].copy()
    th = np.linspace(0, np.pi / 2, X)
    fi, fo = np.sin(th) ** 2, np.cos(th) ** 2
    if x.ndim == 2:
        fi, fo = fi[:, None], fo[:, None]
    out[:X] = x[:X] * fi + x[L:L + X] * fo
    return out


def seam_ratio(x):
    """Seam discontinuity relative to typical sample-to-sample motion (<~3 is seamless)."""
    m = x if x.ndim == 1 else x.mean(axis=1)
    d = np.abs(np.diff(m))
    typ = np.percentile(d, 99) + 1e-9
    return float(np.abs(m[0] - m[-1]) / typ)


# ----------------------------------------------------------------------------------------- mastering & IO
def lufs(x):
    import pyloudnorm as pyln
    meter = pyln.Meter(SR)
    if x.shape[0] < SR * 0.5:
        x = np.concatenate([x, np.zeros((n_of(0.5),) + x.shape[1:])])
    try:
        return meter.integrated_loudness(x)
    except Exception:
        return -70.0


def master_music(x, target_lufs=-16.0, ceiling_db=-1.0, loop=False):
    x = x - np.mean(x, axis=0)
    for _ in range(3):
        L = lufs(x)
        if not np.isfinite(L) or L < -69:
            break
        x = x * db(target_lufs - L)
        x = limiter(x, ceiling_db, loop=loop)
    return x


def norm_peak(x, peak_db=-1.0):
    x = x - np.mean(x, axis=0) if x.shape[0] > SR * 0.2 else x
    pk = np.max(np.abs(x)) + 1e-12
    return x * (db(peak_db) / pk)


def write_ogg(path, x, quality=0.6, max_peak_db=-1.0, _depth=0):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.nan_to_num(np.asarray(x, dtype=np.float64))
    x = np.clip(x, -1, 1).astype(np.float32)
    # NB: libsndfile 1.2 can hang when encoding Vorbis from one huge buffer - write in small blocks.
    ch = 1 if x.ndim == 1 else x.shape[1]
    tmp = path + ".tmp"
    with sf.SoundFile(tmp, "w", SR, ch, format="OGG", subtype="VORBIS",
                      compression_level=1.0 - quality) as f:
        for i in range(0, x.shape[0], 8192):
            f.write(x[i:i + 8192])
    os.replace(tmp, path)
    # lossy encoding can overshoot peaks a little: verify and re-encode if needed
    y, _ = sf.read(path, dtype="float32")
    pk = float(np.max(np.abs(y))) + 1e-12
    if max_peak_db is not None and 20 * np.log10(pk) > max_peak_db and _depth < 3:
        g = db(max_peak_db - 0.15) / pk
        write_ogg(path, x * g, quality, max_peak_db, _depth + 1)


def save_sfx(name, x, peak_db=-1.0, loop=False, fin=0.001, fout=0.01, stereo_ok=False):
    if x.ndim == 2 and not stereo_ok:
        x = x.mean(axis=1)
    if not loop:
        x = fade(x, fin, fout)
    x = norm_peak(x, peak_db - 0.3)
    write_ogg(os.path.join(SFX_DIR, name + ".ogg"), x)
    return x
