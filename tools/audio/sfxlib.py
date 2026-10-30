"""Sound-design building blocks for AFTERBLOOM SFX (all procedural)."""
import numpy as np
import scipy.signal as sps
import afx
from afx import SR, n_of, lp, hp, bp, svf, env_exp, mix_at, reverb, fade, db

# Modal ratio sets
BAR = [1.0, 2.756, 5.404, 8.933, 13.34]
PLATE = [1.0, 1.59, 2.14, 2.30, 2.65, 2.92, 3.16, 3.50, 3.91, 4.15, 4.60, 5.2]
BELL = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166]
GLASS = [1.0, 2.32, 4.25, 6.63, 9.38, 12.1]
BRASS_SHELL = [1.0, 1.47, 2.09, 2.56, 3.39, 4.1]


def buf(sec, stereo=False):
    return np.zeros((n_of(sec), 2) if stereo else n_of(sec))


def put(dst, src, t, g=1.0):
    return mix_at(dst, src, n_of(t), g)


def burst(dur, rng, lo=20, hi=20000, tau=None, attack=0.0005, color=0.0):
    n = n_of(dur)
    x = rng.standard_normal(n) if color == 0 else afx.colored(n, rng, color)
    if lo > 25 or hi < 19000:
        x = bp(x, lo, hi, 2) if lo > 25 and hi < 19000 else (hp(x, lo) if lo > 25 else lp(x, hi))
    return x * env_exp(n, tau if tau else dur / 4, attack)


def thump(f0, f1, dur, tau=None, rng=None, click=0.0):
    """Pitch-dropping sine (kick/body)."""
    n = n_of(dur)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / (dur / 6))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, tau if tau else dur / 3, 0.0008)
    if click and rng is not None:
        x[: n_of(0.003)] += click * rng.standard_normal(n_of(0.003)) * np.linspace(1, 0, n_of(0.003))
    return x


def click(rng, dur=0.006, lo=1500, hi=12000, tau=0.0012):
    return burst(dur, rng, lo, hi, tau, 0.0001)


def modal_hit(base, ratios, dur, rng, decay=0.3, decay_pow=0.7, bright=0.7, jitter=0.02, amps=None):
    r = np.array(ratios) * (1 + rng.uniform(-jitter, jitter, len(ratios)))
    freqs = base * r
    decays = decay / r ** decay_pow * rng.uniform(0.8, 1.2, len(r))
    a = (np.array(amps) if amps is not None else bright ** np.arange(len(r))) * rng.uniform(0.6, 1.0, len(r))
    x = afx.modal(freqs, decays, a, dur, rng)
    return x


def shards(dur, rng, count=40, f_lo=2500, f_hi=9000, decay=0.12, density_tau=0.25, amp_tau=0.4):
    """Cluster of tiny glassy pings (shattering / tinkling)."""
    out = buf(dur)
    for i in range(count):
        t = min(dur * 0.95, rng.exponential(density_tau))
        f = rng.uniform(f_lo, f_hi)
        k = rng.integers(2, 4)
        p = afx.modal(f * np.array([1, 2.3, 3.7])[:k], decay * rng.uniform(0.3, 1.2, k), rng.uniform(0.3, 1, k),
                      min(0.6, decay * 4), rng)
        put(out, p, t, np.exp(-t / amp_tau) * rng.uniform(0.3, 1.0))
    return out


def debris(dur, rng, count=30, lo=300, hi=4000, tau=0.3, size=0.004):
    out = buf(dur)
    for i in range(count):
        t = min(dur * 0.95, rng.exponential(tau))
        c = burst(size * rng.uniform(0.5, 2), rng, lo * rng.uniform(0.7, 1.3), hi, size / 3)
        put(out, c, t, np.exp(-t / tau) * rng.uniform(0.2, 1))
    return out


def whoosh(dur, rng, f0, f1, q=1.5, shape=(0.4, 0.6), curve=None, stereo=False):
    """Swept band-passed noise. shape=(rise_frac, fall_frac) amplitude."""
    n = n_of(dur)
    x = afx.colored(n, rng, -2.0)
    t = np.linspace(0, 1, n)
    fc = f0 * (f1 / f0) ** (t if curve is None else curve(t))
    y = svf(x, fc, q, "bp")
    r, f = shape
    env = np.where(t < r, (t / r) ** 2, np.clip((1 - t) / max(1 - r, 1e-3), 0, 1) ** 1.5)
    return y * env


def formant_filter(x, formants):
    """Parallel resonators: formants = [(freq, q, gain), ...]."""
    y = np.zeros_like(x)
    for f, q, g in formants:
        b, a = sps.iirpeak(min(f, SR / 2 * 0.95), q, fs=SR)
        y += g * sps.lfilter(b, a, x)
    return y


VOWELS = {
    "uh": [(600, 6, 1.0), (1040, 8, 0.6), (2250, 10, 0.25)],
    "oh": [(450, 6, 1.0), (800, 8, 0.6), (2830, 10, 0.15)],
    "ah": [(730, 6, 1.0), (1090, 8, 0.6), (2440, 10, 0.25)],
    "oo": [(300, 6, 1.0), (870, 8, 0.4), (2240, 10, 0.1)],
    "eh": [(530, 6, 1.0), (1840, 8, 0.5), (2480, 10, 0.3)],
    "huh": [(500, 3, 1.0), (1500, 4, 0.5), (2500, 5, 0.3)],
}


def glottal(f0_curve, rng, jitter=0.02, shimmer=0.1):
    """Pulse-train voice source with jitter (f0_curve per-sample)."""
    n = len(f0_curve)
    f = f0_curve * (1 + jitter * afx.smooth_rand(n, rng, 30))
    ph = np.cumsum(f) / SR
    saw = ph % 1.0
    src = afx.lp(np.diff(saw ** 3, prepend=0), 4000)  # slow opening, abrupt closure each cycle
    amp = 1 + shimmer * afx.smooth_rand(n, rng, 20)
    return src * amp


def creak(dur, rng, rate=40, irregular=0.35, pulse_tau=0.004, lo=200, hi=3000):
    """Irregular pulse train (vocal fry / creaking wood)."""
    out = buf(dur)
    t = 0.0
    while t < dur:
        p = burst(pulse_tau * 5, rng, lo, hi, pulse_tau)
        put(out, p, t, rng.uniform(0.5, 1.0))
        t += (1 / rate) * (1 + irregular * rng.standard_normal())
        t = max(t, 0) + 0.002
    return out


def stickslip(dur, rng, rate_curve, res=(900, 1800, 3200), q=12, tau=0.0015):
    """Friction squeak/creak: impulse train at rate_curve (Hz per sample) through resonances."""
    n = n_of(dur)
    rc = np.broadcast_to(rate_curve, (n,))
    ph = np.cumsum(rc * (1 + 0.15 * rng.standard_normal(n))) / SR
    imp = np.zeros(n)
    idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
    imp[idx] = rng.uniform(0.5, 1, len(idx))
    imp = sps.lfilter([1], [1, -np.exp(-1 / (tau * SR))], imp)
    return formant_filter(imp, [(f, q, 1.0 / (i + 1)) for i, f in enumerate(res)])


def bounce_times(first_gap, coef, n, rng):
    ts = [0.0]
    g = first_gap
    for i in range(n - 1):
        ts.append(ts[-1] + g * rng.uniform(0.85, 1.15))
        g *= coef
    return ts


def distance(x, amount=0.5, rng_seed=1, rt=1.5):
    """Push a sound into the distance: darker, quieter direct sound, more reverb."""
    fc = 9000 * (1 - amount) + 900 * amount
    y = lp(x, fc)
    return reverb(y, rt60=rt, wet=0.3 + amount * 0.8, dry=1 - amount * 0.6, predelay=0.03 + amount * 0.05,
                  seed=rng_seed).mean(axis=1)


def periodic_scale(freq_curve):
    """Scale a freq curve so the total number of cycles is an integer (phase-continuous loop)."""
    cyc = freq_curve.sum() / SR
    k = max(1, round(cyc))
    return freq_curve * (k / cyc)


def periodic_env(n, rng, rate, lo=0.0, hi=1.0):
    x = afx.colored(n, rng, 0.0, lo=0.00001, hi=rate)
    x = (x - x.min()) / (x.max() - x.min() + 1e-12)
    return lo + (hi - lo) * x


def loop_events(L_sec, tail_sec, stereo=True):
    return buf(L_sec + tail_sec, stereo)


def finish_loop(x, L_sec):
    return afx.wrap_tail(x, n_of(L_sec))


def harmonic_tone(f_curve, amps, rng=None):
    ph = 2 * np.pi * np.cumsum(f_curve) / SR
    y = np.zeros_like(ph)
    for k, a in enumerate(amps, start=1):
        y += a * np.sin(k * ph)
    return y


def sat(x, d=2.0):
    return np.tanh(x * d) / np.tanh(d)


def A(*parts):
    """Sum mono signals of different lengths (zero-padded)."""
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def cyc(fn, x):
    """Apply a (stateful IIR) filter function to a loop cyclically so the seam stays seamless."""
    n = x.shape[0]
    y = fn(np.concatenate([x, x], axis=0))
    return y[n:]
