"""SFX part A: weapons, impacts, footsteps, player, SureShot, UI."""
import numpy as np
import afx
from afx import SR, n_of, lp, hp, bp, svf, env_exp, reverb, fade, db
from sfxlib import *

REG = {}


def sfx(*names, loop=False, stereo=False, peak=-1.0):
    def deco(fn):
        for i, nm in enumerate(names):
            REG[nm] = (fn, i, loop, stereo, peak)
        return fn
    return deco


# ============================================================================================ WEAPONS
def gun_core(rng, kind="pistol"):
    """Direct sound of a gunshot (no environment)."""
    v = rng.uniform(0.93, 1.07)
    if kind == "pistol":
        body_f0, body_f1, body_tau, boom_lp, boom_tau, crack_g = 190 * v, 62 * v, 0.045, 1800, 0.035, 0.9
        dur = 0.5
    else:
        body_f0, body_f1, body_tau, boom_lp, boom_tau, crack_g = 150 * v, 46 * v, 0.085, 1400, 0.06, 1.0
        dur = 0.8
    x = buf(dur)
    # supersonic crack: N-wave + very bright noise spike
    nw = n_of(0.0007 * v)
    put(x, np.linspace(1, -1, nw) * crack_g, 0)
    put(x, burst(0.01, rng, 2500, 18000, 0.0012, 0.00005), 0, crack_g * 0.9)
    # muzzle blast: broadband, very short, saturated
    blast = burst(0.08, rng, 150, 14000, 0.009 if kind == "pistol" else 0.012, 0.0002)
    put(x, blast, 0.0003, 1.6 if kind == "pistol" else 2.0)
    # high-mid "snap" that makes it read as a gun rather than a drum
    put(x, burst(0.12, rng, 1200, 6500, 0.018 if kind == "pistol" else 0.024, 0.0003), 0.0005, 0.9 if kind == "pistol" else 1.3)
    # body thump and low-mid boom
    put(x, thump(body_f0, body_f1, 0.35, body_tau * 0.7), 0.0005, 0.5 if kind == "pistol" else 0.5)
    put(x, burst(0.4, rng, 60, boom_lp + 700, boom_tau * 0.85, 0.001, color=-3), 0.0008, 0.8)
    # gas/air "chuff" between 400 Hz and 3k
    put(x, burst(0.15, rng, 400, 3000, 0.025, 0.002), 0.002, 0.5)
    x = sat(x * 1.6, 2.2)
    # mechanical layer
    if kind == "pistol":
        # slide cycling: back (click) and forward (clack with small ring)
        for t, g, b in ((0.018, 0.12, 3800), (0.055, 0.2, 2600)):
            m = modal_hit(b * rng.uniform(0.95, 1.05), BAR, 0.15, rng, decay=0.03, bright=0.6)
            put(x, A(m, click(rng, 0.004, 2000, 12000) * 0.6), t, g)
    else:
        # barrel/receiver ring
        m = modal_hit(1150 * v, PLATE, 0.6, rng, decay=0.18, bright=0.75)
        put(x, m, 0.002, 0.06)
    return x


def outdoor_tail(src, rng, length=3.8, strength=1.0):
    """Environment: discrete slap-back echoes from buildings/hills + dark diffuse decay."""
    taps = []
    t = rng.uniform(0.09, 0.16)
    g = 0.5
    while t < length * 0.75:
        taps.append((t, g * rng.uniform(0.6, 1.0)))
        t += rng.uniform(0.08, 0.45)
        g *= 0.78
    y = echoes(src, taps, lp_start=3500, lp_step=0.82, length=length)
    y[: len(src)] -= src  # environment only (no direct sound)
    y = afx.pad_to(y, n_of(length))
    wet = reverb(lp(src, 2500), rt60=2.6, wet=1.0, dry=0.0, predelay=0.06, size=2.0, damp=0.8, seed=5,
                 er=0.1).mean(axis=1)
    y = y + afx.pad_to(wet, len(y)) * 0.8
    return y * strength


def echoes(x, taps, lp_start, lp_step, length):
    return afx.echoes(x, taps, lp_start, lp_step, length)


@sfx("pistol_fire_1", "pistol_fire_2", "pistol_fire_3")
def pistol_fire(rng, i):
    core = gun_core(rng, "pistol")
    env = outdoor_tail(core, rng, 2.2, 0.55)
    x = afx.pad_to(core, len(env)) + env
    return x


@sfx("rifle_fire_1", "rifle_fire_2")
def rifle_fire(rng, i):
    core = gun_core(rng, "rifle")
    env = outdoor_tail(core, rng, 3.2, 0.7)
    return afx.pad_to(core, len(env)) + env


@sfx("gun_tail_outdoor")
def gun_tail_outdoor(rng, i):
    core = gun_core(rng, "rifle")
    env = outdoor_tail(core, rng, 4.5, 1.0)
    # rolling distant rumble
    rum = burst(4.0, rng, 30, 400, 1.2, 0.05, color=-6)
    env += afx.pad_to(rum, len(env)) * 0.25
    return fade(env, 0.03, 0.4)


@sfx("gun_tail_indoor")
def gun_tail_indoor(rng, i):
    core = gun_core(rng, "pistol")
    w = reverb(core, rt60=0.9, wet=1.0, dry=0.0, predelay=0.008, size=0.4, damp=0.4, er=1.0, seed=7,
               lowcut=60).mean(axis=1)
    w = afx.peq(w, 220, 0.8, 5)
    w = afx.peq(w, 3500, 1.0, -4)
    return fade(w[: n_of(1.4)], 0.01, 0.3)


def mech_click(rng, base=3000, decay=0.03, g=1.0, noise=0.6):
    m = modal_hit(base * rng.uniform(0.95, 1.05), BAR, 0.2, rng, decay=decay, bright=0.6)
    return A(m, click(rng, 0.006, 1500, 14000) * noise) * g


def scrape(dur, rng, lo=1500, hi=7000, g=1.0, f0=None, f1=None):
    x = burst(dur, rng, lo, hi, dur * 2, 0.005)
    if f0:
        x = svf(x, np.geomspace(f0, f1, len(x)), 3, "bp") * 2
    return x * np.sin(np.linspace(0, np.pi, len(x))) ** 0.7 * g


@sfx("pistol_mag_out")
def mag_out(rng, i):
    x = buf(0.5)
    put(x, mech_click(rng, 3400, 0.02), 0.0, 0.8)  # release button
    put(x, scrape(0.09, rng, 1800, 8000, 0.35, 5000, 2500), 0.02)
    put(x, A(thump(400, 200, 0.06, 0.012) * 0.3, mech_click(rng, 1900, 0.04, 0.5)), 0.12)  # into palm
    return x


@sfx("pistol_mag_in")
def mag_in(rng, i):
    x = buf(0.5)
    put(x, scrape(0.08, rng, 1500, 7000, 0.3, 2500, 5000), 0.0)
    put(x, thump(500, 160, 0.08, 0.015) * 0.6, 0.085)
    put(x, mech_click(rng, 2800, 0.035, 1.0), 0.085)
    put(x, mech_click(rng, 4200, 0.02, 0.4), 0.092)
    return x


@sfx("pistol_slide")
def pistol_slide(rng, i):
    x = buf(0.6)
    put(x, mech_click(rng, 2500, 0.02, 0.5), 0.0)
    put(x, scrape(0.11, rng, 1200, 9000, 0.35, 3000, 6000), 0.005)
    put(x, mech_click(rng, 3600, 0.03, 0.6), 0.115)
    # release: slams home
    put(x, scrape(0.03, rng, 2000, 9000, 0.3), 0.2)
    put(x, thump(600, 220, 0.07, 0.012) * 0.5, 0.23)
    put(x, mech_click(rng, 2200, 0.06, 1.0), 0.23)
    put(x, mech_click(rng, 4700, 0.04, 0.5), 0.232)
    return x


@sfx("rifle_bolt_open")
def bolt_open(rng, i):
    x = buf(0.6)
    put(x, mech_click(rng, 1800, 0.05, 0.9), 0.0)  # handle up
    put(x, scrape(0.05, rng, 800, 5000, 0.3), 0.01)
    put(x, scrape(0.18, rng, 900, 6000, 0.45, 1600, 3400), 0.12)  # pull back
    put(x, mech_click(rng, 2400, 0.05, 0.8), 0.3)
    put(x, thump(350, 180, 0.06, 0.012) * 0.3, 0.3)
    return x


@sfx("rifle_bolt_close")
def bolt_close(rng, i):
    x = buf(0.6)
    put(x, scrape(0.16, rng, 900, 6000, 0.45, 3400, 1600), 0.0)
    put(x, thump(400, 160, 0.08, 0.015) * 0.5, 0.16)
    put(x, mech_click(rng, 1700, 0.07, 1.0), 0.16)
    put(x, scrape(0.04, rng, 800, 5000, 0.25), 0.25)
    put(x, mech_click(rng, 2100, 0.05, 0.9), 0.3)  # handle down, lock
    return x


@sfx("rifle_round_in")
def round_in(rng, i):
    x = buf(0.35)
    put(x, mech_click(rng, 5200, 0.025, 0.5), 0.0)
    put(x, scrape(0.06, rng, 2500, 9000, 0.3), 0.005)
    put(x, mech_click(rng, 3300, 0.04, 0.9), 0.07)
    put(x, modal_hit(4100, BRASS_SHELL, 0.2, rng, decay=0.05), 0.07, 0.2)
    return x


@sfx("dry_fire")
def dry_fire(rng, i):
    x = buf(0.3)
    put(x, mech_click(rng, 3100, 0.025, 1.0, 1.0), 0.0)
    put(x, modal_hit(5300, BAR, 0.2, rng, decay=0.06) * 0.15, 0.001)
    put(x, thump(700, 300, 0.03, 0.006) * 0.2, 0.0)
    return x


@sfx("shell_1", "shell_2", "shell_3")
def shell(rng, i):
    x = buf(1.0)
    base = rng.uniform(3800, 4800)
    ts = bounce_times(rng.uniform(0.11, 0.16), 0.62, 6, rng)
    for k, t in enumerate(ts):
        g = 0.85 ** k * rng.uniform(0.6, 1.0)
        m = modal_hit(base * rng.uniform(0.98, 1.02), BRASS_SHELL, 0.4, rng, decay=0.12 * (0.8 ** k), bright=0.8)
        put(x, A(m * g, click(rng, 0.003, 3000, 14000) * g * 0.3), t)
    # little roll at the end
    tr = ts[-1] + 0.02
    for k in range(10):
        put(x, modal_hit(base, BRASS_SHELL, 0.1, rng, decay=0.02) * 0.08 * (1 - k / 10), tr + k * 0.018)
    return x


@sfx("bullet_flyby")
def flyby(rng, i):
    d = 0.7
    n = n_of(d)
    t = np.linspace(0, 1, n)
    nz = rng.standard_normal(n)
    fc = 3800 * (0.25 ** t)
    y = svf(nz, fc, 4, "bp")
    env = np.exp(-((t - 0.32) / 0.12) ** 2)
    # whistle component with doppler
    tone = np.sin(2 * np.pi * np.cumsum(2400 * (0.45 ** t)) / SR) * 0.25
    x = (y + tone) * env
    put(x, burst(0.006, rng, 3000, 16000, 0.001), 0.3, 0.5)  # supersonic snap
    return x


# ============================================================================================ IMPACTS
@sfx("impact_flesh_1", "impact_flesh_2")
def impact_flesh(rng, i):
    x = buf(0.45)
    put(x, thump(140, 55, 0.25, 0.05), 0, 1.0)
    put(x, burst(0.15, rng, 150, 1500, 0.03, 0.001), 0, 0.8)
    put(x, burst(0.06, rng, 600, 3500, 0.008, 0.0005), 0.002, 0.5)  # slap
    # wet squelch: resonant noise sweep down
    sq = svf(rng.standard_normal(n_of(0.2)), np.geomspace(1400, 300, n_of(0.2)), 5, "bp")
    put(x, sq * env_exp(n_of(0.2), 0.05), 0.01, 0.35 + 0.1 * i)
    return sat(x, 1.5)


@sfx("impact_crystal_1", "impact_crystal_2", "impact_crystal_3")
def impact_crystal(rng, i):
    x = buf(1.2)
    base = rng.uniform(1800, 3200)
    put(x, burst(0.02, rng, 2000, 16000, 0.003), 0, 0.8)
    put(x, modal_hit(base, GLASS, 1.0, rng, decay=0.5, decay_pow=0.5, bright=0.8, jitter=0.1), 0, 0.7)
    put(x, modal_hit(base * 1.37, GLASS, 1.0, rng, decay=0.35, bright=0.7, jitter=0.1), 0.004, 0.4)
    put(x, shards(1.0, rng, 18 + 8 * i, 3000, 10000, 0.08, 0.12, 0.25), 0.01, 0.5)
    put(x, thump(300, 150, 0.08, 0.02), 0, 0.3)
    return x


@sfx("impact_wood")
def impact_wood(rng, i):
    x = buf(0.5)
    put(x, modal_hit(420, [1, 2.1, 3.4, 4.9, 6.6], 0.3, rng, decay=0.04, bright=0.6, jitter=0.08), 0, 1.0)
    put(x, burst(0.05, rng, 500, 5000, 0.01), 0, 0.8)
    put(x, thump(220, 90, 0.12, 0.03), 0, 0.6)
    put(x, debris(0.35, rng, 14, 1500, 7000, 0.08, 0.002), 0.01, 0.35)  # splinters
    return x


@sfx("impact_metal_1", "impact_metal_2")
def impact_metal(rng, i):
    x = buf(1.2)
    base = rng.uniform(700, 1300)
    put(x, burst(0.01, rng, 1500, 16000, 0.0015), 0, 1.0)
    put(x, modal_hit(base, PLATE, 1.1, rng, decay=0.5, decay_pow=0.4, bright=0.85, jitter=0.05), 0, 0.55)
    put(x, modal_hit(base * 3.1, BAR, 0.8, rng, decay=0.2, bright=0.7), 0, 0.25)
    put(x, thump(260, 120, 0.1, 0.02), 0, 0.3)
    return x


@sfx("impact_concrete_1", "impact_concrete_2")
def impact_concrete(rng, i):
    x = buf(0.7)
    put(x, burst(0.03, rng, 300, 14000, 0.004), 0, 1.0)
    put(x, thump(180, 80, 0.12, 0.025), 0, 0.6)
    put(x, debris(0.6, rng, 40, 600, 6000, 0.12, 0.003), 0.005, 0.45)  # chips & grit
    put(x, burst(0.5, rng, 300, 4000, 0.12, 0.01) * 0.15, 0.01)  # dust hiss
    return x


@sfx("impact_dirt")
def impact_dirt(rng, i):
    x = buf(0.6)
    put(x, thump(120, 60, 0.2, 0.04), 0, 1.0)
    put(x, burst(0.3, rng, 200, 3000, 0.06, 0.002, color=-3), 0, 0.7)
    put(x, debris(0.5, rng, 30, 300, 2500, 0.15, 0.004), 0.03, 0.35)
    return lp(x, 6000)


@sfx("ricochet_1", "ricochet_2")
def ricochet(rng, i):
    d = 0.9
    x = buf(d)
    put(x, impact_metal(rng, 0)[: n_of(0.3)], 0, 0.5)
    n = n_of(0.75)
    t = np.linspace(0, 1, n)
    f = rng.uniform(3200, 4200) * (rng.uniform(0.25, 0.35) ** t)
    f = f * (1 + 0.03 * np.sin(2 * np.pi * rng.uniform(25, 40) * t * 0.75))
    whine = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * svf(rng.standard_normal(n), f, 8, "bp")
    env = np.minimum(1, t / 0.03) * np.exp(-t * 3.0)
    put(x, whine * env, 0.01, 0.7)
    return x


# ============================================================================================ FOOTSTEPS
def step(surface, rng, i):
    x = buf(0.45)
    v = rng.uniform(0.9, 1.1)
    heel_toe = rng.uniform(0.045, 0.075)
    if surface == "wood":
        for t, g in ((0, 1.0), (heel_toe, 0.5)):
            put(x, modal_hit(210 * v, [1, 2.3, 3.9, 5.6], 0.25, rng, decay=0.045, bright=0.65, jitter=0.1), t, g)
            put(x, burst(0.03, rng, 300, 4000, 0.006), t, 0.5 * g)
        put(x, thump(130 * v, 70, 0.15, 0.025), 0, 0.3)
        if i == 2:  # creaky board
            cr = stickslip(0.25, rng, np.linspace(50, 30, n_of(0.25)), (700, 1300, 2300), 10)
            put(x, cr * np.sin(np.linspace(0, np.pi, len(cr))), 0.08, 0.25)
    elif surface == "grass":
        put(x, thump(110 * v, 60, 0.1, 0.025), 0, 0.4)
        n = n_of(0.22)
        grain = rng.standard_normal(n) * (rng.random(n) < 0.08) * 3 + rng.standard_normal(n) * 0.4
        g = bp(grain, 1200, 7000) * env_exp(n, 0.06, 0.01)
        put(x, g, 0, 0.7)
        put(x, burst(0.12, rng, 800, 6000, 0.03, 0.01) * 0.3, heel_toe)
    elif surface == "concrete":
        put(x, burst(0.012, rng, 1500, 12000, 0.002), 0, 0.9)  # heel click
        put(x, thump(150 * v, 70, 0.1, 0.02), 0, 0.6)
        put(x, burst(0.08, rng, 2000, 9000, 0.02, 0.004), heel_toe * 0.6, 0.25)  # scuff
        put(x, burst(0.01, rng, 1200, 9000, 0.002), heel_toe, 0.45)
        x = reverb(x, rt60=0.4, wet=0.12, dry=1.0, size=0.3, seed=3).mean(axis=1)[: len(x)]
    elif surface == "metal":
        put(x, modal_hit(380 * v, PLATE, 0.4, rng, decay=0.12, bright=0.8, jitter=0.05), 0, 0.7)
        put(x, burst(0.01, rng, 1500, 12000, 0.002), 0, 0.6)
        put(x, thump(120, 60, 0.12, 0.03), 0, 0.5)
        put(x, modal_hit(640 * v, PLATE, 0.3, rng, decay=0.08, bright=0.7), heel_toe, 0.35)
        for k in range(3):  # grate rattle
            put(x, modal_hit(rng.uniform(1500, 2500), BAR, 0.05, rng, decay=0.01) * 0.15, 0.02 + k * 0.025)
    elif surface == "carpet":
        put(x, lp(thump(100 * v, 55, 0.12, 0.03), 400), 0, 1.0)
        put(x, burst(0.1, rng, 300, 2500, 0.03, 0.008), 0, 0.25)
        put(x, burst(0.08, rng, 400, 2000, 0.02, 0.005), heel_toe, 0.12)
    elif surface == "gravel":
        put(x, thump(120 * v, 60, 0.1, 0.02), 0, 0.5)
        put(x, debris(0.3, rng, 45, 1500, 9000, 0.06, 0.0025), 0, 1.0)
        put(x, debris(0.2, rng, 20, 1000, 7000, 0.05, 0.003), heel_toe, 0.6)
        put(x, burst(0.18, rng, 1000, 6000, 0.05, 0.005) * 0.25, 0)
    return trim_to(x, 0.35)


def trim_to(x, sec):
    return x[: n_of(sec)]


for _s in ("wood", "grass", "concrete", "metal", "carpet", "gravel"):
    sfx(*[f"step_{_s}_{k}" for k in range(1, 5)])((lambda s: (lambda rng, i: step(s, rng, i)))(_s))


@sfx("jump")
def jump(rng, i):
    x = buf(0.45)
    put(x, burst(0.08, rng, 1500, 8000, 0.02, 0.003), 0, 0.5)  # push-off scuff
    put(x, thump(110, 60, 0.1, 0.02), 0, 0.4)
    put(x, whoosh(0.35, rng, 500, 1500, 1.2, (0.3, 0.7)), 0.03, 0.5)  # clothing rustle
    return x


@sfx("land")
def land(rng, i):
    x = buf(0.6)
    put(x, thump(95, 45, 0.3, 0.06), 0, 1.0)
    put(x, burst(0.12, rng, 200, 5000, 0.03, 0.002), 0, 0.6)
    put(x, burst(0.1, rng, 2000, 8000, 0.03, 0.004), 0.04, 0.3)
    put(x, debris(0.3, rng, 8, 1500, 6000, 0.05, 0.002), 0.03, 0.2)  # gear rattle
    return x


# ============================================================================================ PLAYER
def breath(dur, rng, vowel="huh", f0=None, voiced=0.3, pitch_drop=0.85):
    n = n_of(dur)
    t = np.linspace(0, 1, n)
    src = afx.colored(n, rng, -1.0) * 0.6
    if f0:
        src = src + voiced * 40 * glottal(f0 * (1 - (1 - pitch_drop) * t), rng)
    y = formant_filter(src, VOWELS[vowel])
    env = np.minimum(1, t / 0.08) * (1 - t) ** 1.5
    return y * env


@sfx("hurt_1", "hurt_2")
def hurt(rng, i):
    x = buf(0.6)
    put(x, thump(110, 55, 0.2, 0.04), 0, 0.6)
    put(x, burst(0.05, rng, 200, 2000, 0.012), 0, 0.3)
    b = breath(0.32 + 0.08 * i, rng, "uh" if i == 0 else "huh", f0=115 + 10 * i, voiced=0.45, pitch_drop=0.8)
    put(x, lp(b, 3500), 0.03, 0.8)
    return x


@sfx("heartbeat_loop", loop=True)
def heartbeat(rng, i):
    bpm = 80
    beats = 8
    L = beats * 60 / bpm
    x = buf(L + 1)
    for k in range(beats):
        t = 0.15 + k * 60 / bpm
        a = rng.uniform(0.92, 1.0)
        put(x, lp(thump(70, 38, 0.25, 0.06), 300), t, a)  # lub
        put(x, lp(thump(85, 45, 0.2, 0.045), 350), t + 0.28, 0.7 * a)  # dub
    return afx.wrap_tail(x, n_of(L))


@sfx("heal")
def heal(rng, i):
    x = buf(2.0)
    t = 0.0
    for k in range(5):  # glugs: bubble resonance rising as the bottle drains
        f = 180 + k * 35 + rng.uniform(-10, 10)
        n = n_of(0.12)
        tt = np.arange(n) / SR
        g = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.8 * tt / 0.12)) / SR) * np.exp(-tt / 0.04)
        put(x, lp(g + 0.3 * burst(0.12, rng, 100, 900, 0.03), 1500), t, 0.8)
        t += rng.uniform(0.13, 0.18)
    # fizz: fine bubbles popping
    nfz = n_of(1.3)
    fz = rng.standard_normal(nfz) * (rng.random(nfz) < 0.02) * 2
    fz = bp(fz, 3000, 12000) * np.exp(-np.linspace(0, 3, nfz))
    put(x, fz + burst(1.3, rng, 4000, 14000, 0.6, 0.05) * 0.15, 0.75, 0.6)
    # gentle restorative shimmer
    sh = afx.modal([1568, 2093, 2637], [0.5, 0.45, 0.4], [0.3, 0.2, 0.15], 1.0, rng)
    put(x, sh, 0.8, 0.25)
    return x


@sfx("eat")
def eat(rng, i):
    x = buf(1.3)
    # bite: crisp crunch
    put(x, debris(0.18, rng, 30, 1500, 9000, 0.05, 0.003), 0, 1.0)
    put(x, thump(140, 80, 0.08, 0.02), 0, 0.3)
    for k, t in enumerate((0.38, 0.68, 0.98)):  # chewing (muffled)
        c = lp(debris(0.15, rng, 14, 600, 4000, 0.05, 0.004), 2500)
        put(x, c, t, 0.45 - k * 0.08)
    return x


# ============================================================================================ SURESHOT
def tape_tone(dur, f0, f1, rng, harmonics=(1, 0.5, 0.3, 0.2), curve=2.0):
    n = n_of(dur)
    t = np.linspace(0, 1, n)
    f = f0 + (f1 - f0) * (t ** curve if f1 < f0 else 1 - (1 - t) ** curve)
    return harmonic_tone(f, harmonics)


@sfx("sureshot_enter")
def ss_enter(rng, i):
    d = 1.3
    x = buf(d + 1.0, True)
    w = whoosh(d, rng, 5000, 250, 2.0, (0.15, 0.85))
    tone = tape_tone(d, 900, 70, rng) * np.exp(-np.linspace(0, 2.5, n_of(d)))
    sub = thump(90, 35, d, 0.5)
    y = w * 1.0 + lp(tone, 3000) * 0.4 + sub * 0.5
    y = fade(y, 0.002, 0.3)
    put(x, reverb(y, rt60=2.0, wet=0.5, dry=1.0, seed=8, predelay=0.04), 0)
    return x.mean(axis=1)


@sfx("sureshot_exit")
def ss_exit(rng, i):
    d = 0.8
    w = whoosh(d, rng, 250, 6000, 2.0, (0.8, 0.2))
    tone = tape_tone(d, 80, 900, rng) * np.linspace(0.3, 1, n_of(d))
    y = w + lp(tone, 3500) * 0.35
    y = fade(y, 0.05, 0.08)
    return reverb(y, rt60=1.2, wet=0.35, dry=1.0, seed=9).mean(axis=1)


@sfx("sureshot_target", peak=-6.0)
def ss_target(rng, i):
    n = n_of(0.06)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * 2200 * t) * np.exp(-t / 0.012) + 0.3 * np.sin(2 * np.pi * 4400 * t) * np.exp(-t / 0.006)
    y[:n_of(0.002)] += click(rng, 0.002, 3000, 12000) * 0.3
    return y


@sfx("sureshot_queue", peak=-3.0)
def ss_queue(rng, i):
    x = buf(0.3)
    for k, (f, t) in enumerate(((1175, 0.0), (1760, 0.07))):
        n = n_of(0.14)
        tt = np.arange(n) / SR
        y = harmonic_tone(np.full(n, f), (1, 0, 0.25, 0, 0.1)) * np.exp(-tt / 0.05) * np.minimum(1, tt / 0.003)
        put(x, y, t, 0.8)
    return x


@sfx("sureshot_fail", peak=-3.0)
def ss_fail(rng, i):
    x = buf(0.4)
    for k in range(2):
        n = n_of(0.12)
        tt = np.arange(n) / SR
        y = np.sign(np.sin(2 * np.pi * 110 * tt)) * 0.5 + np.sign(np.sin(2 * np.pi * 116.5 * tt)) * 0.5
        y = lp(y, 2200) * np.minimum(1, tt / 0.004) * np.minimum(1, (0.12 - tt) / 0.01)
        put(x, y, k * 0.15)
    return x


# ============================================================================================ UI
@sfx("ui_hover", peak=-8.0)
def ui_hover(rng, i):
    n = n_of(0.04)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 3100 * t) * np.exp(-t / 0.006) + 0.2 * click(rng, 0.04, 4000, 12000, 0.002)


@sfx("ui_click", peak=-3.0)
def ui_click(rng, i):
    x = buf(0.08)
    put(x, mech_click(rng, 2600, 0.008, 1.0, 0.8), 0)
    put(x, mech_click(rng, 3300, 0.006, 0.5, 0.6), 0.018)
    put(x, thump(900, 400, 0.03, 0.006) * 0.4, 0)
    return x


@sfx("ui_back", peak=-3.0)
def ui_back(rng, i):
    x = buf(0.18)
    for f, t, g in ((1400, 0.0, 0.8), (930, 0.05, 0.7)):
        n = n_of(0.09)
        tt = np.arange(n) / SR
        put(x, np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.025) * np.minimum(1, tt / 0.002), t, g)
    put(x, mech_click(rng, 2000, 0.006, 0.3, 0.5), 0)
    return x


def paper(dur, rng, rate=40, lo=1500, hi=9000, smooth=0.6):
    n = n_of(dur)
    x = rng.standard_normal(n)
    flutter = afx.smooth_rand(n, rng, rate) * 0.5 + 0.5
    crinkle = (rng.random(n) < 0.004) * rng.standard_normal(n) * 6
    y = bp(x * flutter ** 2 + crinkle, lo, hi)
    return y * np.sin(np.linspace(0, np.pi, n)) ** smooth


@sfx("journal_open")
def journal_open(rng, i):
    x = buf(0.7)
    put(x, paper(0.4, rng, 30), 0.0, 0.6)
    put(x, A(lp(thump(180, 90, 0.12, 0.025), 800), burst(0.05, rng, 300, 3000, 0.012) * 0.5), 0.33, 0.9)
    return x


@sfx("journal_close")
def journal_close(rng, i):
    x = buf(0.5)
    put(x, paper(0.15, rng, 50), 0.0, 0.4)
    put(x, A(lp(thump(160, 80, 0.15, 0.03), 900), burst(0.04, rng, 300, 4000, 0.01) * 0.7), 0.12, 1.0)
    return x


@sfx("page_turn")
def page_turn(rng, i):
    x = buf(0.45)
    n = n_of(0.35)
    w = svf(rng.standard_normal(n), np.geomspace(1500, 5000, n), 1.2, "bp") * np.sin(np.linspace(0, np.pi, n))
    put(x, w * 0.6 + paper(0.35, rng, 60) * 0.6, 0)
    put(x, burst(0.02, rng, 2000, 9000, 0.004), 0.3, 0.3)
    return x


@sfx("pickup_1", "pickup_2")
def pickup(rng, i):
    x = buf(0.4)
    put(x, burst(0.12, rng, 800, 6000, 0.03, 0.01), 0, 0.4)
    put(x, thump(300 + 80 * i, 140, 0.08, 0.015) * 0.6, 0.06)
    put(x, mech_click(rng, 1800 + 600 * i, 0.03, 0.4), 0.06)
    return x


@sfx("pickup_ammo")
def pickup_ammo(rng, i):
    x = buf(0.5)
    for k in range(9):
        t = rng.uniform(0, 0.18)
        put(x, modal_hit(rng.uniform(3500, 5200), BRASS_SHELL, 0.15, rng, decay=0.04), t, rng.uniform(0.2, 0.5))
    put(x, burst(0.15, rng, 1000, 6000, 0.05, 0.01), 0, 0.2)
    return x


@sfx("pickup_magazine")
def pickup_mag(rng, i):
    x = buf(1.2)
    put(x, paper(0.3, rng, 40), 0, 0.6)
    for k, f in enumerate((1568, 2093)):
        put(x, afx.modal([f, f * 2.0, f * 3.0], [0.6, 0.3, 0.15], [1, 0.3, 0.1], 0.9, rng), 0.12 + k * 0.08, 0.35)
    return x


@sfx("xp_tick", peak=-6.0)
def xp_tick(rng, i):
    n = n_of(0.07)
    t = np.arange(n) / SR
    f = 1600 + 600 * np.minimum(1, t / 0.02)
    return harmonic_tone(f, (1, 0.2, 0.1)) * np.exp(-t / 0.018) * np.minimum(1, t / 0.002)


@sfx("quest_update")
def quest_update(rng, i):
    x = buf(1.5)
    for k, t in enumerate((0.0, 0.09, 0.16)):  # typebar strikes
        put(x, A(mech_click(rng, 2300, 0.02, 0.7, 0.9), thump(500, 200, 0.03, 0.008) * 0.3), t, 0.6)
    bell = afx.modal(np.array([1, 2.76, 5.4]) * 2400, [0.9, 0.35, 0.15], [1, 0.25, 0.08], 1.2, rng)
    put(x, bell, 0.24, 0.8)
    return x
