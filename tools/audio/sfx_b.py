"""SFX part B: home, robot butler, creatures, world events, ambience loops."""
import numpy as np
import afx
from afx import SR, n_of, lp, hp, bp, svf, env_exp, reverb, fade, db
from sfxlib import *
from sfx_a import sfx, REG, mech_click, scrape, paper, breath, thump

# ============================================================================================ HOME


def chime(f, dur, rng, decay=1.6):
    return afx.modal(f * np.array([1, 2.756, 5.404, 8.93]), [decay, decay * 0.35, decay * 0.12, decay * 0.05],
                     [1, 0.18, 0.06, 0.02], dur, rng)


@sfx("doorbell")
def doorbell(rng, i):
    x = buf(3.2)
    for f, t in ((659.25, 0.0), (523.25, 0.62)):
        put(x, A(thump(300, 150, 0.05, 0.01) * 0.15, mech_click(rng, 1800, 0.01, 0.15)), t)  # solenoid
        put(x, chime(f, 2.6, rng), t + 0.004, 0.8)
    return reverb(x, rt60=0.7, wet=0.15, dry=1.0, size=0.4, seed=12).mean(axis=1)


def knock(rng, g=1.0):
    y = modal_hit(rng.uniform(110, 130), [1, 1.8, 2.6, 3.9, 5.1], 0.3, rng, decay=0.07, bright=0.55, jitter=0.06)
    y = A(y, burst(0.03, rng, 400, 5000, 0.005) * 0.5, thump(170, 90, 0.12, 0.025) * 0.6)
    return y * g


@sfx("door_knock")
def door_knock(rng, i):
    x = buf(1.0)
    for k, t in enumerate((0.0, 0.2, 0.38)):
        put(x, knock(rng, (1.0, 0.85, 0.95)[k]), t)
    return reverb(x, rt60=0.6, wet=0.2, dry=1.0, size=0.4, seed=13).mean(axis=1)


def hinge_creak(dur, rng, rate0=45, rate1=25):
    n = n_of(dur)
    rc = np.geomspace(rate0, rate1, n) * (1 + 0.3 * afx.smooth_rand(n, rng, 3))
    c = stickslip(dur, rng, rc, (720, 1350, 2400, 3900), 14)
    return c * np.sin(np.linspace(0, np.pi, n)) ** 0.5


@sfx("door_open")
def door_open(rng, i):
    x = buf(1.6)
    put(x, mech_click(rng, 1500, 0.04, 0.8), 0.0)  # latch
    put(x, mech_click(rng, 2100, 0.03, 0.5), 0.07)
    put(x, hinge_creak(0.9, rng), 0.15, 0.5)
    put(x, whoosh(1.0, rng, 200, 700, 0.8, (0.4, 0.6)), 0.2, 0.4)
    return reverb(x, rt60=0.6, wet=0.15, dry=1.0, size=0.4, seed=14).mean(axis=1)


@sfx("door_close")
def door_close(rng, i):
    x = buf(1.2)
    put(x, whoosh(0.35, rng, 300, 900, 0.8, (0.7, 0.3)), 0.0, 0.4)
    put(x, thump(110, 55, 0.35, 0.08), 0.33, 1.0)
    put(x, knock(rng, 0.8), 0.33)
    put(x, mech_click(rng, 1700, 0.04, 0.6), 0.345)  # latch catch
    put(x, mech_click(rng, 2500, 0.03, 0.3), 0.36)
    return reverb(x, rt60=0.7, wet=0.2, dry=1.0, size=0.5, seed=15).mean(axis=1)


def bell_strike(f, rng, dur=0.6):
    return afx.modal(f * np.array([1, 1.51, 2.32, 2.97, 4.1]), [0.5, 0.35, 0.2, 0.12, 0.08],
                     [1, 0.6, 0.4, 0.25, 0.12], dur, rng, detune=0.004)


@sfx("phone_ring")
def phone_ring(rng, i):
    x = buf(2.6)
    # hammer alternates between two bells at 20 Hz for 2 s
    k = 0
    t = 0.0
    while t < 2.0:
        f = 1180 if k % 2 == 0 else 1415
        put(x, bell_strike(f, rng), t, 0.5)
        put(x, click(rng, 0.002, 2000, 8000) * 0.15, t)
        t += 0.05
        k += 1
    return x


@sfx("phone_pickup")
def phone_pickup(rng, i):
    x = buf(0.7)
    put(x, A(thump(300, 140, 0.06, 0.012) * 0.6, burst(0.03, rng, 500, 5000, 0.006) * 0.5), 0.0)  # bakelite
    put(x, mech_click(rng, 2400, 0.02, 0.8), 0.05)  # hook switch
    put(x, bell_strike(1180, rng, 0.5) * 0.08, 0.055)  # bell tinkle
    put(x, burst(0.2, rng, 600, 4000, 0.06, 0.02) * 0.15, 0.1)  # handling
    return x


@sfx("phone_hangup")
def phone_hangup(rng, i):
    x = buf(0.8)
    put(x, A(thump(240, 110, 0.1, 0.02), burst(0.04, rng, 400, 5000, 0.008) * 0.8), 0.0)
    put(x, mech_click(rng, 2200, 0.02, 0.9), 0.012)
    put(x, bell_strike(1415, rng, 0.6) * 0.12, 0.02)
    return x


@sfx("kettle_whistle_loop", loop=True)
def kettle(rng, i):
    L = 4.0
    n = n_of(L)
    jit = periodic_env(n, rng, 3.0, -1, 1)
    f = periodic_scale(2150 * (1 + 0.006 * jit))
    tone = harmonic_tone(f, (1.0, 0.08, 0.03))
    amp = periodic_env(n, rng, 6.0, 0.75, 1.0)
    breathy = afx.shaped_noise(n, rng, lambda fr: np.exp(-((fr - 2150) / 180) ** 2)) * 0.25
    boil = afx.shaped_noise(n, rng, lambda fr: np.where(fr < 400, 1.0, (400 / np.maximum(fr, 1)) ** 2))
    boil *= periodic_env(n, rng, 12.0, 0.2, 1.0) * 0.12
    return tone * amp + breathy * amp + boil


@sfx("tea_pour")
def tea_pour(rng, i):
    d = 2.6
    n = n_of(d)
    t = np.linspace(0, 1, n)
    nz = rng.standard_normal(n)
    fc = 500 + 1100 * t + 150 * afx.smooth_rand(n, rng, 15)  # cup filling: resonance rises
    stream = svf(nz, fc, 6, "bp")
    gurgle = np.zeros(n)
    for k in range(40):
        tt = rng.uniform(0.05, 0.95)
        f = 400 + 900 * tt + rng.uniform(-100, 100)
        b = afx.modal([f], [0.012], [1.0], 0.05, rng)
        mix_at(gurgle, b, int(tt * n), rng.uniform(0.3, 1.0))
    env = np.minimum(1, t / 0.04) * np.minimum(1, (1 - t) / 0.08)
    return lp(stream + gurgle * 0.4 + 0.04 * hp(nz, 4000), 9000) * env


@sfx("cup_clink")
def cup_clink(rng, i):
    x = buf(0.9)
    for t, g, f in ((0.0, 1.0, 2650), (0.11, 0.45, 3150)):
        put(x, modal_hit(f * rng.uniform(0.98, 1.02), [1, 1.73, 2.45, 3.6], 0.6, rng, decay=0.22, bright=0.6), t, g)
        put(x, click(rng, 0.003, 3000, 14000) * 0.4, t, g)
    return x


@sfx("toaster_pop")
def toaster_pop(rng, i):
    x = buf(1.0)
    put(x, mech_click(rng, 1600, 0.04, 1.0, 1.0), 0.0)  # release
    put(x, thump(260, 120, 0.08, 0.015) * 0.5, 0.0)
    n = n_of(0.5)
    t = np.arange(n) / SR
    twang = np.sin(2 * np.pi * (180 + 40 * np.exp(-t / 0.05)) * t) * np.exp(-t / 0.12)  # spring
    put(x, twang, 0.002, 0.35)
    put(x, modal_hit(900, PLATE, 0.5, rng, decay=0.15, bright=0.7), 0.0, 0.3)  # metal carriage
    put(x, burst(0.08, rng, 800, 5000, 0.02), 0.06, 0.25)  # toast slides up
    return x


@sfx("curtain_open")
def curtain_open(rng, i):
    x = buf(1.6)
    t = 0.0
    k = 0
    while t < 1.0:  # rings sliding along the rod
        put(x, modal_hit(rng.uniform(2200, 3200), BAR, 0.08, rng, decay=0.015) * 0.3, t, rng.uniform(0.4, 1))
        t += rng.uniform(0.012, 0.04)
        k += 1
    put(x, scrape(1.1, rng, 2000, 8000, 0.25), 0.0)
    put(x, whoosh(1.1, rng, 300, 1200, 0.7, (0.3, 0.7)), 0.0, 0.6)  # fabric
    return x


@sfx("light_switch")
def light_switch(rng, i):
    x = buf(0.15)
    put(x, mech_click(rng, 2900, 0.012, 1.0, 1.0), 0.0)
    put(x, thump(800, 300, 0.03, 0.006) * 0.4, 0.0)
    put(x, mech_click(rng, 3800, 0.008, 0.5), 0.012)
    return x


@sfx("tv_on")
def tv_on(rng, i):
    d = 2.0
    x = buf(d)
    put(x, mech_click(rng, 1900, 0.03, 0.6), 0.0)  # knob
    # degauss thump + hum
    n = n_of(1.2)
    t = np.arange(n) / SR
    hum = (np.sin(2 * np.pi * 60 * t) + 0.5 * np.sin(2 * np.pi * 120 * t) + 0.3 * np.sign(np.sin(2 * np.pi * 60 * t)))
    put(x, A(hum * np.exp(-t / 0.25) * 0.5, thump(90, 45, 0.4, 0.1)), 0.05)
    # flyback whine rising
    n2 = n_of(1.6)
    t2 = np.linspace(0, 1, n2)
    f = 3000 + 12700 * (1 - np.exp(-t2 * 4))
    whine = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(1, t2 * 6) * 0.015
    put(x, whine, 0.25)
    put(x, burst(0.6, rng, 800, 10000, 0.15, 0.02) * 0.15, 0.3)  # static crackle
    return x


@sfx("tv_off")
def tv_off(rng, i):
    x = buf(1.3)
    put(x, mech_click(rng, 1900, 0.03, 0.6), 0.0)
    put(x, A(burst(0.02, rng, 200, 9000, 0.004) * 0.5, thump(140, 60, 0.15, 0.03) * 0.6), 0.01)
    n = n_of(1.0)
    t2 = np.linspace(0, 1, n)
    f = 15700 * (0.15 ** t2)
    put(x, np.sin(2 * np.pi * np.cumsum(f) / SR) * (1 - t2) ** 2 * 0.025, 0.02)
    put(x, debris(0.6, rng, 25, 2000, 9000, 0.15, 0.002) * 0.3, 0.05)  # discharge crackle
    return x


@sfx("tv_static_loop", loop=True)
def tv_static(rng, i):
    L = 4.0
    n = n_of(L)
    t = np.arange(n) / SR
    hiss = afx.shaped_noise(n, rng, lambda f: np.where((f > 80) & (f < 13000), 1.0, 0.0) *
                            (1 + 0.5 * np.exp(-((f - 3000) / 2000) ** 2)))
    buzz = 1 + 0.15 * np.sign(np.sin(2 * np.pi * 60 * t))
    whine = 0.02 * np.sin(2 * np.pi * 15734 * t)
    return hiss * buzz * 0.3 + whine


@sfx("radio_click")
def radio_click(rng, i):
    x = buf(0.4)
    put(x, mech_click(rng, 2300, 0.02, 1.0, 1.0), 0.0)
    put(x, thump(400, 150, 0.05, 0.01) * 0.3, 0.0)
    n = n_of(0.3)
    put(x, burst(0.3, rng, 300, 5000, 0.08, 0.01) * 0.12, 0.02)  # valve warm-up hiss
    return x


@sfx("radio_tune")
def radio_tune(rng, i):
    d = 2.6
    n = n_of(d)
    t = np.linspace(0, 1, n)
    st = bp(afx.colored(n, rng, -1.5), 250, 5000)
    st *= 0.6 + 0.4 * afx.smooth_rand(n, rng, 8)
    x = st * 0.35
    # heterodyne whistles sweeping as the dial passes carriers
    for c in (0.18, 0.46, 0.71, 0.9):
        dist = (t - c) * 9000
        f = np.abs(dist) + 60
        w = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-((t - c) / 0.05) ** 2)
        x += w * 0.3
    # fragments of stations (band-limited music/voice-ish) near carriers
    for c in (0.46, 0.9):
        frag = np.zeros(n)
        k = n_of(0.25)
        s0 = int((c - 0.03) * n)
        tt = np.arange(k) / SR
        chord = sum(np.sin(2 * np.pi * f0 * tt) for f0 in (392, 494, 587)) * (1 + 0.5 * np.sin(2 * np.pi * 4 * tt))
        frag[s0:s0 + k] = bp(chord, 300, 3000)[: max(0, min(k, n - s0))] * np.hanning(k)[: max(0, min(k, n - s0))]
        x += frag * 0.25
    x += debris(d, rng, 30, 2000, 8000, 1.0, 0.002) * 0.2
    return x * np.minimum(1, t / 0.02) * np.minimum(1, (1 - t) / 0.05)


@sfx("radio_static_loop", loop=True)
def radio_static(rng, i):
    L = 6.0
    n = n_of(L)
    hiss = afx.shaped_noise(n, rng, lambda f: np.where((f > 200) & (f < 5000), 1.0, 0.05) /
                            np.sqrt(np.maximum(f, 1) / 1000))
    hiss *= periodic_env(n, rng, 1.5, 0.5, 1.0)
    cr = buf(L + 0.1)
    for k in range(70):
        put(cr, burst(0.004, rng, 1000, 9000, 0.0008), rng.uniform(0, L), rng.uniform(0.2, 1.0))
    return hiss * 0.3 + afx.wrap_tail(cr, n) * 0.5


@sfx("clock_tick_loop", loop=True, peak=-6.0)
def clock_tick(rng, i):
    L = 4.0
    x = buf(L + 0.5)
    for k in range(4):
        tick = k % 2 == 0
        f = 3400 if tick else 2900
        y = A(modal_hit(f, BAR, 0.2, rng, decay=0.012, bright=0.6), click(rng, 0.003, 2500, 12000) * 0.5,
              modal_hit(520 if tick else 470, [1, 1.9, 3.1], 0.15, rng, decay=0.03, bright=0.5) * 0.4)  # case
        put(x, y, 0.05 + k * 1.0 + rng.uniform(-0.003, 0.003), 1.0 if tick else 0.85)
    return afx.wrap_tail(x, n_of(L))


@sfx("fridge_hum_loop", loop=True)
def fridge(rng, i):
    L = 8.0
    n = n_of(L)
    t = np.arange(n) / SR
    hum = (0.5 * np.sin(2 * np.pi * 60 * t) + 1.0 * np.sin(2 * np.pi * 120 * t) + 0.35 * np.sin(2 * np.pi * 180 * t)
           + 0.25 * np.sin(2 * np.pi * 240 * t) + 0.12 * np.sin(2 * np.pi * 360 * t)
           + 0.3 * np.sin(2 * np.pi * 120.25 * t))
    comp = afx.shaped_noise(n, rng, lambda f: np.where(f < 500, 1.0, (500 / np.maximum(f, 1)) ** 3)) * 0.25
    return hum * 0.4 + comp


# ============================================================================================ ROBOT
def warm(x):
    x = afx.peq(x, 350, 0.8, 4)
    return lp(x, 4500)


@sfx("robot_servo_1", "robot_servo_2", "robot_servo_3")
def servo(rng, i):
    d = (0.45, 0.6, 0.35)[i]
    n = n_of(d)
    t = np.linspace(0, 1, n)
    f0 = (420, 330, 520)[i]
    shape = np.sin(np.pi * t) ** 0.7
    f = f0 * (1 + (0.5, 0.35, 0.6)[i] * shape) * (1 + 0.01 * afx.smooth_rand(n, rng, 20))
    tone = harmonic_tone(f, (1, 0.55, 0.35, 0.25, 0.12, 0.08))
    grit = 1 + 0.25 * bp(rng.standard_normal(n), 80, 400) * 4
    env = np.minimum(1, t / 0.06) * np.minimum(1, (1 - t) / 0.12)
    y = warm(tone * grit * env * 0.6 + bp(rng.standard_normal(n), 800, 3000) * env * 0.05)
    x = buf(d + 0.1)
    put(x, y, 0)
    put(x, mech_click(rng, 1800, 0.03, 0.25), d - 0.02)
    return x


@sfx("robot_hover_loop", loop=True)
def robot_hover(rng, i):
    L = 6.0
    n = n_of(L)
    t = np.arange(n) / SR
    hum = (np.sin(2 * np.pi * 90 * t) + 0.8 * np.sin(2 * np.pi * 91.5 * t) + 0.45 * np.sin(2 * np.pi * 180 * t)
           + 0.2 * np.sin(2 * np.pi * 270 * t) + 0.08 * np.sin(2 * np.pi * 450 * t))
    wob = 1 + 0.12 * np.sin(2 * np.pi * t / 3.0)
    air = afx.shaped_noise(n, rng, lambda f: np.exp(-((np.log2(np.maximum(f, 1) / 700)) ** 2) * 2)) * 0.12
    air *= periodic_env(n, rng, 0.8, 0.6, 1.0)
    return cyc(warm, hum * wob * 0.4 + air)


def beep_seq(notes, rng, wave=(1, 0.15, 0.25, 0.05, 0.08), vib=0.0):
    x = buf(sum(d for _, d, _ in notes) + 0.3)
    t = 0.0
    for f, d, g in notes:
        n = n_of(d + 0.08)
        tt = np.arange(n) / SR
        fc = np.broadcast_to(f(tt) if callable(f) else np.full(n, f), (n,)) * (1 + vib * np.sin(2 * np.pi * 7 * tt))
        y = harmonic_tone(fc, wave) * np.minimum(1, tt / 0.005) * np.exp(-np.maximum(0, tt - d * 0.6) / 0.03)
        put(x, y, t, g)
        t += d
    return warm(x)


@sfx("robot_beep_happy", peak=-2.0)
def beep_happy(rng, i):
    return beep_seq([(1046.5, 0.08, 0.8), (1318.5, 0.08, 0.8), (lambda tt: 1568 * (1 + 0.12 * np.minimum(1, tt / 0.12)),
                                                              0.22, 1.0)], rng, vib=0.004)


@sfx("robot_beep_worried", peak=-2.0)
def beep_worried(rng, i):
    return beep_seq([(880, 0.12, 0.8), (lambda tt: 830 * (1 - 0.25 * np.minimum(1, tt / 0.45)), 0.5, 1.0)], rng,
                    vib=0.025)


@sfx("robot_zap")
def robot_zap(rng, i):
    x = buf(0.9)
    put(x, burst(0.01, rng, 1500, 18000, 0.0015), 0, 1.0)  # crack
    n = n_of(0.35)
    t = np.arange(n) / SR
    f = 110 * (1 + 0.3 * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)))
    arc = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * (0.6 + 0.4 * rng.standard_normal(n))
    arc = bp(arc, 150, 7000) * np.exp(-t / 0.12) * (rng.random(n) < 0.7)
    put(x, arc, 0.003, 0.5)
    put(x, debris(0.5, rng, 40, 3000, 12000, 0.12, 0.0015), 0.01, 0.4)  # sizzle
    put(x, thump(200, 80, 0.1, 0.02) * 0.4, 0)
    return x


@sfx("robot_polish")
def robot_polish(rng, i):
    x = buf(1.4)
    for k, t in enumerate((0.0, 0.42, 0.86)):
        d = 0.32
        n = n_of(d)
        rate = np.linspace(700, 1100, n) if k % 2 == 0 else np.linspace(1050, 750, n)
        sq = stickslip(d, rng, rate, (1600, 3100, 4700), 9)
        rub = burst(d, rng, 1500, 7000, d, 0.02) * 0.3
        put(x, (sq * 0.8 + rub) * np.sin(np.linspace(0, np.pi, n)), t, 1.0 - k * 0.1)
    return x


# ============================================================================================ CREATURES
def chitter(dur, rng, rate=28, f_lo=3000, f_hi=7500, bursts=3, amp=1.0):
    x = buf(dur)
    t = 0.0
    while t < dur - 0.02:
        # bursts of clicks with gaps
        blen = rng.uniform(0.08, 0.25)
        r = rate * rng.uniform(0.8, 1.4)
        tt = t
        while tt < min(dur - 0.02, t + blen):
            f = rng.uniform(f_lo, f_hi)
            c = afx.modal([f, f * 1.7, f * 2.6], [0.006, 0.004, 0.003], [1, 0.5, 0.3], 0.03, rng)
            put(x, A(c, click(rng, 0.002, 2000, 12000) * 0.3), tt, rng.uniform(0.4, 1.0) * amp)
            tt += 1 / r * rng.uniform(0.7, 1.3)
        t = tt + rng.uniform(0.03, 0.12)
    return x


@sfx("mite_chitter_1", "mite_chitter_2", "mite_chitter_3")
def mite_chitter(rng, i):
    d = (0.6, 0.8, 0.5)[i]
    x = chitter(d, rng, rate=(30, 24, 36)[i])
    hiss = burst(d, rng, 3000, 9000, d, 0.05) * 0.06
    return x + hiss


@sfx("mite_attack")
def mite_attack(rng, i):
    x = buf(0.6)
    put(x, chitter(0.35, rng, rate=55, amp=1.0), 0, 0.8)
    n = n_of(0.3)
    put(x, burst(0.3, rng, 2500, 10000, 0.12, 0.01) * np.sin(np.linspace(0, np.pi, n)), 0.02, 0.6)  # hiss
    put(x, scrape(0.15, rng, 3000, 10000, 0.3, 7000, 3000), 0.15)  # glass scrape
    return x


@sfx("mite_death")
def mite_death(rng, i):
    x = buf(1.2)
    put(x, thump(260, 90, 0.08, 0.015), 0, 1.0)  # wet pop
    put(x, burst(0.05, rng, 200, 3000, 0.012), 0, 0.7)
    sq = svf(rng.standard_normal(n_of(0.12)), np.geomspace(1800, 400, n_of(0.12)), 6, "bp")
    put(x, sq * env_exp(n_of(0.12), 0.03), 0.005, 0.4)
    put(x, whoosh(0.7, rng, 2500, 600, 0.8, (0.08, 0.92)), 0.02, 0.6)  # spore puff
    put(x, shards(0.9, rng, 16, 4000, 10000, 0.05, 0.15, 0.3), 0.02, 0.35)
    return x


def husk_voice(dur, rng, f0=70, vowel="oh", creakiness=0.6, breathy=0.6, shimmer_amt=0.12, rise=0.0):
    n = n_of(dur)
    t = np.linspace(0, 1, n)
    f = f0 * (1 + rise * np.sin(np.pi * t)) * (1 + 0.08 * afx.smooth_rand(n, rng, 2))
    voiced = glottal(f, rng, jitter=0.08, shimmer=0.4) * 12
    fry = creak(dur, rng, rate=f0 * 0.45, irregular=0.5, pulse_tau=0.003, lo=150, hi=3000)[:n]
    fry = afx.pad_to(fry, n)
    air = afx.colored(n, rng, -1.0) * 0.5
    src = voiced * (1 - creakiness) + fry * creakiness * 2.0 + air * breathy
    # slowly morphing vowel (resonant, hollow)
    v1 = formant_filter(src, VOWELS[vowel])
    v2 = formant_filter(src, VOWELS["oo"])
    m = 0.5 + 0.5 * np.sin(2 * np.pi * t * rng.uniform(0.5, 1.2))
    y = v1 * m + v2 * (1 - m)
    env = np.minimum(1, t / 0.15) * np.minimum(1, (1 - t) / 0.3) ** 1.2
    # crystalline shimmer riding on the breath
    sh = afx.modal(rng.uniform(2500, 5000, 5), rng.uniform(0.3, 0.9, 5), rng.uniform(0.2, 1, 5), dur, rng)
    sh *= 1 + 0.5 * np.sin(2 * np.pi * 7 * np.arange(n) / SR)
    return y * env + sh * env * shimmer_amt


@sfx("husk_groan_1", "husk_groan_2", "husk_groan_3")
def husk_groan(rng, i):
    d = (1.8, 2.4, 1.5)[i]
    y = husk_voice(d, rng, f0=(68, 58, 80)[i], vowel=("oh", "uh", "ah")[i], rise=(0.15, -0.1, 0.25)[i])
    return reverb(y, rt60=1.2, wet=0.18, dry=1.0, size=0.6, seed=20 + i).mean(axis=1)


@sfx("husk_attack")
def husk_attack(rng, i):
    d = 0.9
    y = husk_voice(d, rng, f0=95, vowel="ah", creakiness=0.4, breathy=1.2, rise=0.35, shimmer_amt=0.2)
    y = sat(y / (np.abs(y).max() + 1e-9) * 2.0, 1.5)
    x = buf(1.0)
    put(x, y, 0)
    put(x, shards(0.6, rng, 10, 3000, 8000, 0.05, 0.2, 0.3), 0.05, 0.25)  # crystal rattle
    return x


@sfx("husk_death")
def husk_death(rng, i):
    x = buf(2.6)
    put(x, crystal_shatter(rng, 0), 0, 1.0)
    ex = breath(1.6, rng, "huh", f0=60, voiced=0.25, pitch_drop=0.6)
    put(x, lp(ex, 2500), 0.15, 0.6)
    return x


@sfx("crystal_shatter_1", "crystal_shatter_2")
def crystal_shatter(rng, i):
    x = buf(2.0)
    put(x, burst(0.03, rng, 1500, 18000, 0.004), 0, 1.0)
    put(x, thump(220, 90, 0.15, 0.03), 0, 0.5)
    for k in range(4):
        put(x, modal_hit(rng.uniform(1600, 3500), GLASS, 1.2, rng, decay=0.5, bright=0.75, jitter=0.15),
            rng.uniform(0, 0.03), 0.4)
    put(x, shards(1.9, rng, 120 + 30 * i, 2500, 11000, 0.1, 0.18, 0.45), 0.005, 0.8)
    put(x, debris(1.2, rng, 40, 2000, 9000, 0.25, 0.002), 0.05, 0.3)
    return x


def roar(dur, rng, f0=55, size=1.0):
    n = n_of(dur)
    t = np.linspace(0, 1, n)
    f = f0 * (1 + 0.35 * np.sin(np.pi * t ** 0.7)) * (1 + 0.05 * afx.smooth_rand(n, rng, 6))
    src = glottal(f, rng, jitter=0.12, shimmer=0.6) * 14 + afx.colored(n, rng, -1.0) * 0.9
    src += creak(dur, rng, rate=f0 * 0.6, irregular=0.6, pulse_tau=0.004, lo=80, hi=2000)[:n] * 1.5
    y = formant_filter(src, [(380 / size, 4, 1.0), (750 / size, 5, 0.8), (1700 / size, 6, 0.4),
                             (2900 / size, 7, 0.2)])
    y = sat(y / (np.abs(y).max() + 1e-9) * 3.0, 2.5)
    sub = np.sin(2 * np.pi * np.cumsum(f * 0.5) / SR) * 0.6
    shriek = svf(rng.standard_normal(n), 2400 + 1800 * np.sin(np.pi * t), 6, "bp") * 0.25  # crystalline edge
    env = np.minimum(1, t / 0.12) * np.minimum(1, (1 - t) / 0.35) ** 1.3
    return (y + sub + shriek) * env


@sfx("thornback_roar_1", "thornback_roar_2")
def thornback_roar(rng, i):
    y = roar((2.6, 3.2)[i], rng, f0=(52, 44)[i], size=(1.4, 1.7)[i])
    return reverb(y, rt60=2.2, wet=0.3, dry=1.0, size=1.6, seed=31 + i, predelay=0.04).mean(axis=1)


@sfx("thornback_stomp")
def thornback_stomp(rng, i):
    x = buf(2.0)
    put(x, thump(70, 32, 0.9, 0.22), 0, 1.0)
    put(x, burst(0.08, rng, 60, 3000, 0.015), 0, 0.6)
    put(x, debris(1.2, rng, 50, 400, 4000, 0.25, 0.005), 0.01, 0.4)
    put(x, shards(1.0, rng, 20, 3000, 8000, 0.06, 0.15, 0.3), 0.02, 0.2)
    put(x, burst(1.6, rng, 25, 200, 0.4, 0.01, color=-6), 0.0, 0.5)  # ground rumble
    return reverb(x, rt60=1.8, wet=0.2, dry=1.0, size=1.5, seed=33).mean(axis=1)


@sfx("thornback_charge")
def thornback_charge(rng, i):
    x = buf(3.0)
    t = 0.0
    gap = 0.42
    k = 0
    while t < 2.3:
        put(x, A(thump(65, 32, 0.5, 0.12), debris(0.3, rng, 12, 400, 3000, 0.08, 0.005) * 0.4), t,
            0.5 + 0.4 * min(1, t / 1.5))
        t += gap
        gap = max(0.2, gap * 0.9)
        k += 1
    r = roar(2.4, rng, f0=60, size=1.4)
    put(x, r * np.linspace(0.2, 1.0, len(r)), 0.4, 0.8)
    return reverb(x, rt60=1.6, wet=0.2, dry=1.0, size=1.4, seed=34).mean(axis=1)


@sfx("thornback_death")
def thornback_death(rng, i):
    x = buf(6.0)
    r = roar(2.8, rng, f0=48, size=1.6)
    n = len(r)
    t = np.linspace(0, 1, n)
    put(x, r * (1 - 0.3 * t), 0, 0.9)
    put(x, thump(55, 25, 1.5, 0.4), 2.4, 1.0)  # collapse
    put(x, debris(1.5, rng, 60, 300, 4000, 0.3, 0.006), 2.42, 0.4)
    # bloom eruption: shimmer whoosh + shatter cascade
    put(x, whoosh(2.5, rng, 500, 4000, 1.0, (0.2, 0.8)), 2.5, 0.6)
    put(x, shards(3.0, rng, 160, 2000, 8000, 0.15, 0.5, 0.9), 2.5, 0.4)
    sh = afx.modal([1174.7, 1760, 2349.3, 2793.8, 3520], [2.5, 2.2, 1.8, 1.5, 1.2], [0.5, 0.4, 0.3, 0.25, 0.2],
                   3.4, rng)
    put(x, sh, 2.55, 0.35)
    return reverb(x, rt60=2.6, wet=0.3, dry=1.0, size=1.8, seed=35).mean(axis=1)


@sfx("spore_burst")
def spore_burst(rng, i):
    x = buf(1.4)
    put(x, A(thump(180, 70, 0.12, 0.02), burst(0.03, rng, 100, 4000, 0.006) * 0.6), 0, 0.8)
    put(x, whoosh(1.0, rng, 3000, 400, 0.7, (0.05, 0.95)), 0.005, 0.8)
    put(x, shards(1.2, rng, 40, 5000, 12000, 0.04, 0.3, 0.5), 0.02, 0.3)
    return x


# ============================================================================================ EVENTS / WORLD
def smoothstep(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


@sfx("siren_loop", loop=True)
def siren(rng, i):
    L = 12.0
    n = n_of(L)
    t = np.arange(n) / SR
    lo, hi = 190.0, 560.0
    s = np.where(t < 3.5, smoothstep(t / 3.5), np.where(t < 6.5, 1.0, 1 - smoothstep((t - 6.5) / 5.5)))
    f = lo * (hi / lo) ** s * (1 + 0.004 * np.sin(2 * np.pi * t * 5 / L * 2))
    ncyc = f.sum() / SR
    f = f * (2 * round(ncyc / 2) / ncyc)
    amps = [1 / k ** 0.9 for k in range(1, 9)]
    y = harmonic_tone(f, amps) + 0.5 * harmonic_tone(f * 1.5, amps[:5])
    y = cyc(lambda v: lp(v, 3500), y) * (0.45 + 0.55 * s)
    # rotating horn: slow amplitude sweep (periodic)
    y *= 0.75 + 0.25 * np.sin(2 * np.pi * t * 3 / L)
    y = np.stack([y, y], axis=1)
    y = reverb(y, rt60=3.5, wet=0.6, dry=0.6, predelay=0.08, size=2.5, damp=0.7, seed=40, loop=True)
    return y.mean(axis=1)


@sfx("pa_chime")
def pa_chime(rng, i):
    x = buf(3.4)
    for f, t in ((783.99, 0.0), (659.25, 0.55), (523.25, 1.1)):
        y = afx.modal(f * np.array([1, 2, 3, 4.1]), [1.6, 0.6, 0.3, 0.15], [1, 0.25, 0.08, 0.03], 2.2, rng)
        put(x, A(y, click(rng, 0.002, 1000, 6000) * 0.05), t, 0.7)
    x = bp(x, 250, 5000)
    return reverb(x, rt60=2.4, wet=0.5, dry=0.8, predelay=0.06, size=2.0, seed=41).mean(axis=1)


@sfx("car_crash")
def car_crash(rng, i):
    x = buf(3.5)
    put(x, thump(80, 35, 0.6, 0.15), 0, 1.0)
    put(x, burst(0.15, rng, 80, 9000, 0.04), 0, 1.0)
    for k in range(18):  # crumpling sheet metal
        t = rng.exponential(0.12)
        put(x, modal_hit(rng.uniform(250, 900), PLATE, 0.6, rng, decay=0.2, bright=0.8, jitter=0.1), t,
            rng.uniform(0.2, 0.6) * np.exp(-t / 0.4))
        put(x, burst(0.05, rng, 400, 6000, 0.01), t, 0.3 * np.exp(-t / 0.4))
    put(x, shards(2.0, rng, 140, 2500, 10000, 0.1, 0.25, 0.5), 0.03, 0.7)  # glass
    put(x, debris(2.5, rng, 60, 500, 6000, 0.5, 0.004), 0.1, 0.35)
    # hubcap rolling away
    t = 1.2
    gap = 0.09
    while t < 3.2:
        put(x, modal_hit(1400, PLATE, 0.2, rng, decay=0.05) * 0.15, t)
        t += gap
        gap *= 1.05
    return reverb(x, rt60=1.8, wet=0.25, dry=1.0, size=1.5, seed=42).mean(axis=1)


@sfx("car_alarm_loop", loop=True)
def car_alarm(rng, i):
    L = 3.2
    x = buf(L + 0.5)
    for k in range(4):
        d = 0.45
        n = n_of(d)
        tt = np.arange(n) / SR
        y = sum(np.sign(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6))) for f in (370, 466))
        y = afx.peq(lp(y, 2800), 1200, 1.5, 6)
        env = np.minimum(1, tt / 0.01) * np.minimum(1, (d - tt) / 0.03)
        put(x, sat(y * env, 1.5), k * 0.8)
    y = afx.wrap_tail(x, n_of(L))
    return reverb(np.stack([y, y], 1), rt60=1.5, wet=0.4, dry=1.0, seed=43, loop=True).mean(axis=1)


@sfx("glass_break")
def glass_break(rng, i):
    x = buf(2.0)
    put(x, burst(0.02, rng, 2000, 18000, 0.003), 0, 1.0)
    put(x, modal_hit(2100, GLASS, 1.0, rng, decay=0.35, bright=0.8, jitter=0.1), 0, 0.5)
    put(x, shards(1.9, rng, 150, 2200, 9000, 0.09, 0.2, 0.5), 0.004, 0.9)
    put(x, thump(260, 120, 0.06, 0.012), 0, 0.3)
    return x


@sfx("explosion_distant")
def explosion_distant(rng, i):
    x = buf(5.0)
    put(x, thump(60, 28, 1.5, 0.45), 0, 1.0)
    put(x, burst(2.0, rng, 30, 700, 0.5, 0.01, color=-3), 0, 0.8)
    put(x, debris(1.0, rng, 30, 300, 2000, 0.4, 0.008), 0.1, 0.2)
    rum = burst(4.5, rng, 25, 250, 1.4, 0.2, color=-6)
    put(x, rum, 0.05, 0.6)
    return distance(x, 0.6, 44, rt=3.0)[: n_of(5.0)]


@sfx("gate_klaxon_loop", loop=True)
def gate_klaxon(rng, i):
    L = 2.8
    x = buf(L + 1)
    for k in range(2):
        d = 1.0
        n = n_of(d)
        tt = np.arange(n) / SR
        f = 210 + 210 * smoothstep(tt / 0.22) - 30 * smoothstep((tt - 0.85) / 0.15)
        saw = (np.cumsum(f) / SR) % 1.0 * 2 - 1
        y = formant_filter(saw, [(900, 4, 1.0), (2100, 5, 0.6), (3300, 6, 0.3)]) + saw * 0.2
        y = sat(y / (np.abs(y).max() + 1e-9) * 2.5, 2.0)
        env = np.minimum(1, tt / 0.02) * np.minimum(1, (d - tt) / 0.04)
        put(x, y * env, k * 1.4)
    y = afx.wrap_tail(x, n_of(L))
    return reverb(np.stack([y, y], 1), rt60=2.5, wet=0.5, dry=1.0, size=2.0, seed=45, loop=True).mean(axis=1)


def big_metal(rng, base=60, dur=6.0):
    return modal_hit(base, PLATE + [6.1, 7.3, 8.6], dur, rng, decay=3.5, decay_pow=0.45, bright=0.85, jitter=0.03)


@sfx("gate_slam")
def gate_slam(rng, i):
    x = buf(8.5)
    put(x, thump(55, 24, 2.0, 0.5), 0, 1.0)
    put(x, burst(0.2, rng, 40, 6000, 0.05, 0.0005), 0, 1.0)
    put(x, big_metal(rng, 62), 0, 0.5)
    put(x, big_metal(rng, 97), 0.004, 0.3)
    put(x, modal_hit(420, PLATE, 3.0, rng, decay=1.2, bright=0.8), 0, 0.15)
    put(x, debris(2.0, rng, 50, 500, 5000, 0.4, 0.005), 0.05, 0.25)
    x = sat(x * 1.3, 1.6)
    return reverb(x, rt60=5.0, wet=0.45, dry=1.0, predelay=0.05, size=2.5, damp=0.6, seed=46).mean(axis=1)[
        : n_of(8.5)]


@sfx("gate_open")
def gate_open(rng, i):
    d = 6.5
    x = buf(d)
    n = n_of(5.4)
    t = np.linspace(0, 1, n)
    # lock bolts
    for tt in (0.0, 0.35):
        put(x, A(thump(90, 45, 0.6, 0.12), big_metal(rng, 120, 1.2)[: n_of(1.2)] * 0.3), tt, 0.8)
    # hydraulic hiss
    hiss = afx.colored(n, rng, -1.0)
    hiss = hp(hiss, 2500) * (0.3 + 0.7 * np.exp(-t * 6) + 0.6 * smoothstep((t - 0.9) / 0.1))
    put(x, hiss, 0.45, 0.35)
    # grinding: low rumble modulated by stick-slip juddering + metallic squeal
    rum = afx.colored(n, rng, -6.0, hi=700)
    judder = np.clip(afx.smooth_rand(n, rng, 14) * 0.5 + 0.6, 0, 1)
    grind = rum * judder * np.minimum(1, t / 0.05) * np.minimum(1, (1 - t) / 0.05)
    put(x, grind, 0.5, 0.9)
    fsq = 1050 * (1 + 0.03 * afx.smooth_rand(n, rng, 3))
    squeal = harmonic_tone(fsq, (1, 0.4, 0.2)) * np.clip(afx.smooth_rand(n, rng, 1.5), 0, 1) * 0.12
    put(x, squeal, 0.5)
    put(x, debris(5.0, rng, 40, 300, 3000, 2.5, 0.006) * 0.3, 0.5)
    put(x, A(thump(70, 35, 0.9, 0.2), big_metal(rng, 90, 1.5)[: n_of(1.5)] * 0.3), 5.75, 0.9)  # stop
    return reverb(x, rt60=2.5, wet=0.3, dry=1.0, size=2.0, seed=47).mean(axis=1)[: n_of(d)]


@sfx("power_up")
def power_up(rng, i):
    d = 3.6
    n = n_of(d)
    t = np.linspace(0, 1, n)
    f = 22 + 38 * smoothstep(t / 0.7)
    hum = harmonic_tone(f, [1, 0.7, 0.6, 0.45, 0.35, 0.25, 0.2, 0.15, 0.1, 0.08])
    hum = sat(hum * 1.5, 1.5) * smoothstep(t / 0.6)
    whine = np.sin(2 * np.pi * np.cumsum(200 + 2600 * smoothstep(t / 0.8)) / SR) * 0.08 * smoothstep(t / 0.3)
    x = buf(d + 0.3)
    put(x, hum * 0.6 + whine, 0)
    for tt in (0.0, 0.9, 1.7, 2.5):
        put(x, A(thump(140, 60, 0.2, 0.04) * 0.5, mech_click(rng, 1500, 0.05, 0.6)), tt)
    put(x, debris(0.6, rng, 30, 2000, 9000, 0.15, 0.002) * 0.4, 2.5)  # arc crackle at full power
    return fade(x, 0.002, 0.25)


@sfx("lever_pull")
def lever_pull(rng, i):
    x = buf(1.3)
    t = 0.0
    gap = 0.07
    for k in range(9):
        put(x, mech_click(rng, 1600, 0.03, 0.5), t)
        t += gap
        gap *= 0.92
    put(x, A(thump(120, 60, 0.4, 0.08), modal_hit(380, PLATE, 0.8, rng, decay=0.35, bright=0.7) * 0.4), t + 0.05)
    n = n_of(0.5)
    tt = np.arange(n) / SR
    put(x, np.sin(2 * np.pi * 140 * tt) * np.exp(-tt / 0.1) * 0.2, t + 0.06)
    return x


@sfx("fuse_insert")
def fuse_insert(rng, i):
    x = buf(0.8)
    put(x, scrape(0.12, rng, 1500, 7000, 0.4), 0.0)
    put(x, mech_click(rng, 2200, 0.04, 1.0, 1.0), 0.13)
    put(x, thump(400, 200, 0.05, 0.01) * 0.4, 0.13)
    n = n_of(0.15)
    tt = np.arange(n) / SR
    buzz = np.sign(np.sin(2 * np.pi * 120 * tt)) * (0.5 + 0.5 * np.random.default_rng(3).random(n))
    put(x, bp(buzz, 200, 6000) * np.exp(-tt / 0.05) * 0.4, 0.15)
    put(x, debris(0.2, rng, 10, 3000, 10000, 0.05, 0.001) * 0.3, 0.15)
    return x


def rumble(dur, rng, peaks, lo=25, hi=500):
    n = n_of(dur)
    t = np.arange(n) / SR
    env = np.zeros(n)
    for (pt, w, a) in peaks:
        env += a * np.exp(-((t - pt) / w) ** 2)
    env += 0.3 * env.max() * np.exp(-t / (dur * 0.4))
    return afx.colored(n, rng, -5.0, lo=lo, hi=hi) * env


@sfx("thunder_near_1", "thunder_near_2")
def thunder_near(rng, i):
    d = 7.5
    x = buf(d)
    put(x, lightning_crack(rng, 0)[: n_of(1.2)], 0, 1.0)
    peaks = [(rng.uniform(0.2, 0.6), 0.3, 1.0)] + [(rng.uniform(0.5, 4.0), rng.uniform(0.3, 0.9), rng.uniform(0.3, 0.8))
                                                 for _ in range(6)]
    put(x, rumble(d - 0.1, rng, peaks, 25, 900), 0.08, 0.9)
    put(x, thump(55, 25, 2.0, 0.6), 0.1, 0.6)
    return reverb(x, rt60=3.0, wet=0.3, dry=1.0, size=2.5, seed=50 + i, lowcut=30).mean(axis=1)[: n_of(d)]


@sfx("thunder_far_1", "thunder_far_2")
def thunder_far(rng, i):
    d = 7.0
    peaks = [(rng.uniform(0.6, 1.2), 0.6, 1.0)] + [(rng.uniform(1.0, 5.0), rng.uniform(0.5, 1.2), rng.uniform(0.3, 0.7))
                                                 for _ in range(5)]
    y = rumble(d, rng, peaks, 20, 300)
    y = y * np.minimum(1, np.arange(len(y)) / n_of(0.4))
    return reverb(y, rt60=3.5, wet=0.4, dry=1.0, size=2.5, seed=52 + i, lowcut=25).mean(axis=1)[: n_of(d)]


@sfx("lightning_crack")
def lightning_crack(rng, i):
    x = buf(2.2)
    put(x, burst(0.02, rng, 300, 18000, 0.004, 0.0002), 0, 1.0)
    put(x, burst(0.08, rng, 1000, 16000, 0.02), 0.002, 0.6)
    put(x, debris(0.6, rng, 120, 1500, 14000, 0.12, 0.0015), 0.0, 0.6)  # sizzle
    put(x, thump(90, 35, 1.0, 0.25), 0.01, 0.8)
    put(x, burst(1.8, rng, 30, 800, 0.5, 0.01, color=-4), 0.02, 0.5)
    return reverb(x, rt60=2.0, wet=0.3, dry=1.0, size=2.0, seed=53).mean(axis=1)[: n_of(2.2)]


@sfx("wind_gust_1", "wind_gust_2")
def wind_gust(rng, i):
    d = (3.5, 4.2)[i]
    n = n_of(d)
    t = np.linspace(0, 1, n)
    f = 300 * (4 ** np.sin(np.pi * t ** (0.8 + 0.3 * i)))
    y = svf(afx.colored(n, rng, -2.0), f * (1 + 0.15 * afx.smooth_rand(n, rng, 2)), 1.2, "bp")
    whistle = svf(rng.standard_normal(n), f * 2.4, 12, "bp") * 0.15
    leaves = hp(rng.standard_normal(n), 2500) * (0.5 + 0.5 * afx.smooth_rand(n, rng, 25)) * 0.08
    env = np.sin(np.pi * t) ** 1.5 * (1 + 0.3 * afx.smooth_rand(n, rng, 1.5))
    return (y + whistle + leaves * np.sin(np.pi * t)) * env


@sfx("bird_flock")
def bird_flock(rng, i):
    d = 3.0
    x = buf(d)
    for b in range(26):
        t0 = rng.uniform(0, 0.6)
        rate = rng.uniform(9, 15)
        nflaps = rng.integers(10, 22)
        g = rng.uniform(0.3, 1.0)
        for k in range(nflaps):
            tt = t0 + k / rate
            if tt > d - 0.05:
                break
            fl = burst(0.04, rng, 200, 2500, 0.012, 0.003)
            put(x, fl, tt, g * np.exp(-k / (nflaps * 0.6)))
    for k in range(5):
        put(x, bird_call(rng, "whistle")[0], rng.uniform(0.1, 1.5), 0.15)
    return x


def bird_call(rng, kind=None):
    kind = kind or rng.choice(["whistle", "trill", "warble", "chirp"])
    out = []
    if kind == "whistle":
        x = buf(1.0)
        t = 0.0
        for s in range(rng.integers(2, 5)):
            d = rng.uniform(0.07, 0.2)
            n = n_of(d)
            tt = np.linspace(0, 1, n)
            f0 = rng.uniform(2400, 4200)
            f = f0 + rng.uniform(-900, 900) * tt
            y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt) ** 1.5
            put(x, y, t)
            t += d + rng.uniform(0.03, 0.12)
        out = x[: n_of(min(1.0, t + 0.05))]
    elif kind == "trill":
        d = rng.uniform(0.4, 1.0)
        x = buf(d + 0.05)
        r = rng.uniform(14, 24)
        f0 = rng.uniform(4000, 6500)
        for k in range(int(d * r)):
            n = n_of(0.035)
            tt = np.linspace(0, 1, n)
            f = f0 * (1.3 - 0.4 * tt)
            put(x, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt), k / r, 0.6 + 0.4 * np.sin(k / 3))
        out = x
    elif kind == "warble":
        d = rng.uniform(0.3, 0.7)
        n = n_of(d)
        tt = np.arange(n) / SR
        fc = rng.uniform(3000, 4500)
        f = fc + rng.uniform(300, 700) * np.sin(2 * np.pi * rng.uniform(25, 50) * tt)
        out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / d) ** 0.8
    else:
        x = buf(0.6)
        for k in range(rng.integers(2, 4)):
            n = n_of(0.05)
            tt = np.linspace(0, 1, n)
            f = rng.uniform(5000, 7000) * (1 - 0.5 * tt)
            put(x, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt), k * rng.uniform(0.09, 0.15))
        out = x
    return out, kind


def gull_call(rng, n_calls=None, base=None):
    n_calls = n_calls or rng.integers(2, 5)
    base = base or rng.uniform(850, 1100)
    x = buf(0.32 * n_calls + 0.6)
    t = 0.0
    for k in range(n_calls):
        d = rng.uniform(0.18, 0.32) if k else rng.uniform(0.35, 0.5)
        n = n_of(d)
        tt = np.linspace(0, 1, n)
        f = base * (1 - 0.06 * k) * (1 + 0.45 * np.sin(np.pi * np.minimum(1, tt * 1.4)) - 0.15 * tt)
        y = harmonic_tone(f, [0.4, 1.0, 0.8, 0.5, 0.35, 0.2, 0.12, 0.08])
        y = afx.peq(y, 2600, 1.0, 6) + 0.05 * bp(rng.standard_normal(n), 2000, 6000)
        env = np.minimum(1, tt / 0.08) * np.minimum(1, (1 - tt) / 0.25)
        put(x, y * env, t)
        t += d + rng.uniform(0.04, 0.1)
    return x[: n_of(t + 0.1)]


@sfx("gull_1", "gull_2")
def gull(rng, i):
    y = gull_call(rng, (3, 4)[i])
    return reverb(y, rt60=1.5, wet=0.2, dry=1.0, seed=60 + i).mean(axis=1)


def bark(rng):
    d = 0.16
    n = n_of(d)
    tt = np.linspace(0, 1, n)
    f = rng.uniform(420, 560) * (1.1 - 0.35 * tt)
    src = glottal(f, rng, 0.05, 0.3) * 10 + afx.colored(n, rng, -1) * 0.6
    y = formant_filter(src, [(700, 4, 1.0), (1300, 5, 0.7), (2600, 6, 0.3)])
    return y * np.minimum(1, tt / 0.04) * (1 - tt) ** 1.5


@sfx("dog_bark_1", "dog_bark_2")
def dog_bark(rng, i):
    x = buf(2.6)
    t = 0.0
    for k in range((3, 2)[i]):
        put(x, bark(rng), t, rng.uniform(0.7, 1.0))
        t += rng.uniform(0.3, 0.5)
    return distance(x, 0.65, 61 + i, rt=2.0)[: n_of(2.6)]


@sfx("water_spray_loop", loop=True)
def water_spray(rng, i):
    L = 6.0
    n = n_of(L)
    jet = afx.shaped_noise(n, rng, lambda f: np.where(f > 300, 1.0, (np.maximum(f, 1) / 300) ** 2) *
                           np.where(f > 9000, (9000 / np.maximum(f, 1)) ** 1.5, 1.0))
    splash = afx.shaped_noise(n, rng, lambda f: np.exp(-((f - 1500) / 1200) ** 2))
    splash *= periodic_env(n, rng, 10.0, 0.2, 1.0)
    rumb = afx.colored(n, rng, -6.0, hi=250)
    return jet * 0.5 + splash * 0.6 + rumb * 0.3


@sfx("bloom_wave")
def bloom_wave(rng, i):
    d = 10.0
    n = n_of(d)
    t = np.linspace(0, 1, n)
    sw = svf(afx.colored(n, rng, -1.5), 300 * (25 ** (t ** 1.5)), 0.9, "lp") * (0.1 + 0.9 * t ** 2)
    shimmer = np.zeros(n)
    notes = [293.66, 440, 659.25, 830.6, 1108.7, 1318.5, 1760, 2217.5]
    for k, f in enumerate(notes):
        fc = f * (1 + 0.5 * t ** 2) * (1 + 0.003 * np.sin(2 * np.pi * (5 + k) * t * d))
        trem = 0.6 + 0.4 * np.sin(2 * np.pi * (6 + k * 0.7) * t * d)
        shimmer += np.sin(2 * np.pi * np.cumsum(fc) / SR) * trem / (1 + k * 0.3)
    shimmer *= t ** 1.6
    rum = afx.colored(n, rng, -6.0, hi=150) * t ** 1.2
    pings = shards(d, rng, 160, 3000, 10000, 0.15, 6.0, 30.0)
    pings *= t ** 2
    y = sw * 0.8 + shimmer * 0.12 + rum * 0.6 + pings * 0.4
    return reverb(y, rt60=3.0, wet=0.35, dry=1.0, size=2.0, seed=63).mean(axis=1)[:n] * \
        np.minimum(1, (1 - t) / 0.04)


# ============================================================================================ AMBIENCE (stereo loops)
def place(dst, mono, t, pan_pos, g=1.0):
    put(dst, afx.pan(mono, pan_pos), t, g)


def birds_layer(L, rng, count, muffle=None, gain=0.15, kinds=None):
    x = buf(L + 2, True)
    for k in range(count):
        call, kind = bird_call(rng, rng.choice(kinds) if kinds else None)
        if muffle:
            call = lp(call, muffle)
        p = rng.uniform(-0.8, 0.8)
        g = gain * rng.uniform(0.3, 1.0)
        t = rng.uniform(0, L)
        # same bird repeats its phrase a few times
        for r in range(rng.integers(1, 4)):
            place(x, call, t + r * rng.uniform(0.8, 2.0), p, g)
    return afx.wrap_tail(x, n_of(L))


def surf_layer(L, rng, period=(7, 11), distant=0.0):
    x = buf(L + 8, True)
    t = 0.0
    while t < L:
        per = rng.uniform(*period)
        d = per + 3
        n = n_of(d)
        tt = np.arange(n) / SR
        swell = afx.colored(n, rng, -5.0, hi=600) * np.exp(-((tt - per * 0.35) / (per * 0.2)) ** 2) * 0.6
        crash_t = per * 0.45
        crash = afx.colored(n, rng, -2.0, hi=4000) * np.where(tt > crash_t, np.exp(-(tt - crash_t) / 0.9), 0) * \
            np.minimum(1, np.maximum(0, tt - crash_t + 0.15) / 0.15)
        wash = hp(afx.colored(n, rng, -1.0), 1500) * np.where(tt > crash_t, np.exp(-(tt - crash_t) / 2.5), 0) * 0.35
        w = swell + crash + wash
        if distant:
            w = lp(w, 4000 * (1 - distant) + 300 * distant)
        place(x, w, t, rng.uniform(-0.4, 0.4))
        t += per
    y = afx.wrap_tail(x, n_of(L))
    return afx.stereo_width(y, 1.3)


def crickets_layer(L, rng, count=6, gain=0.1):
    x = buf(L + 1, True)
    for c in range(count):
        f = rng.uniform(3800, 5200)
        per = rng.uniform(0.45, 0.9)
        pulses = rng.integers(2, 5)
        p = rng.uniform(-0.9, 0.9)
        g = gain * rng.uniform(0.3, 1.0)
        chirp_n = n_of(0.016)
        tt = np.arange(chirp_n) / SR
        pul = np.sin(2 * np.pi * f * tt) * np.sin(np.pi * tt / 0.016) ** 2
        chirp = buf(0.03 * pulses + 0.02)
        for k in range(pulses):
            put(chirp, pul, k * 0.028)
        t = rng.uniform(0, per)
        while t < L:
            place(x, chirp, t, p, g * rng.uniform(0.7, 1.0))
            t += per * rng.uniform(0.97, 1.03)
    return afx.wrap_tail(x, n_of(L))


def wind_layer(L, rng, center=500, q=0.8, gain=1.0, leaves=0.0, gust_rate=0.15):
    n = n_of(L)
    out = np.zeros((n, 2))
    for ch in range(2):
        nz = afx.colored(n, rng, -2.0)
        fc = center * (1.6 ** (periodic_env(n, rng, gust_rate, -1, 1)))
        y = svf(np.concatenate([nz, nz]), np.tile(fc, 2), q, "bp")[n:]
        env = periodic_env(n, rng, gust_rate, 0.3, 1.0)
        y = y * env
        if leaves:
            lv = hp(np.concatenate([nz, nz]), 2500)[n:] * periodic_env(n, rng, 20, 0.0, 1.0) ** 2 * env
            y = y + lv * leaves
        out[:, ch] = y * gain
    return out


def distant_car(L, rng, t0):
    x = buf(L + 9, True)
    d = 8.0
    n = n_of(d)
    tt = np.linspace(0, 1, n)
    f = 38 * (1.06 - 0.12 * tt)  # doppler-ish
    eng = harmonic_tone(f, [1, 0.8, 0.5, 0.4, 0.3, 0.2, 0.12])
    tyre = bp(afx.colored(n, rng, -1), 400, 2500) * 0.5
    env = np.exp(-((tt - 0.5) / 0.22) ** 2)
    y = lp((eng * 0.6 + tyre) * env, 1800)
    put(x, np.stack([y * (1 - tt), y * tt], 1) * 0.6, t0)
    return afx.wrap_tail(x, n_of(L))


def finish_amb(y, L, rt=1.2, wet=0.15):
    return reverb(y, rt60=rt, wet=wet, dry=1.0, size=1.2, seed=70, loop=True)


@sfx("amb_house_morning_loop", loop=True, stereo=True, peak=-6.0)
def amb_house_morning(rng, i):
    L = 40.0
    n = n_of(L)
    birds = birds_layer(L, rng, 26, muffle=3200, gain=0.12)
    surf = cyc(lambda v: lp(v, 700), surf_layer(L, rng, distant=0.8)) * 0.25
    room = np.stack([lp(afx.colored(n, rng, -3.0), 300), lp(afx.colored(n, rng, -3.0), 300)], 1) * 0.015
    return finish_amb(birds + surf + room, L, 0.6, 0.2)


@sfx("amb_town_day_loop", loop=True, stereo=True, peak=-4.0)
def amb_town_day(rng, i):
    L = 60.0
    birds = birds_layer(L, rng, 40, gain=0.12)
    wind = wind_layer(L, rng, 450, 0.7, 0.08, leaves=0.35)
    car = distant_car(L, rng, 14.0) + distant_car(L, rng, 41.0) * 0.7
    dog = np.zeros((n_of(L) + n_of(3), 2))
    put(dog, afx.pan(dog_bark(rng, 1) * 0.08, -0.6), 30.0)
    dog = afx.wrap_tail(dog, n_of(L))
    return finish_amb(birds + wind + car * 0.25 + dog, L, 1.5, 0.15)


@sfx("amb_after_day_loop", loop=True, stereo=True, peak=-4.0)
def amb_after_day(rng, i):
    L = 60.0
    n = n_of(L)
    wind = wind_layer(L, rng, 380, 0.6, 0.12, leaves=0.4, gust_rate=0.1)
    gulls = buf(L + 3, True)
    for k in range(7):
        place(gulls, distance(gull_call(rng), rng.uniform(0.3, 0.7), 71 + k), rng.uniform(0, L), rng.uniform(-0.9, 0.9),
              0.12)
    gulls = afx.wrap_tail(gulls, n)
    chimes = buf(L + 5, True)
    scale = [1174.7, 1318.5, 1480, 1760, 1976, 2349.3, 2637]
    for k in range(30):
        f = rng.choice(scale)
        y = afx.modal(f * np.array([1, 2.32, 4.25]), [2.5, 1.0, 0.4], [1, 0.2, 0.05], 3.5, rng)
        place(chimes, y, rng.uniform(0, L), rng.uniform(-0.9, 0.9), 0.025)
    chimes = afx.wrap_tail(chimes, n)
    ins = afx.shaped_noise(n, rng, lambda f: np.exp(-((f - 5800) / 700) ** 2))
    ins = ins * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 160 * np.arange(n) / SR))) * periodic_env(n, rng, 0.12, 0, 1) ** 2
    insects = np.stack([ins, np.roll(ins, 3000)], 1) * 0.02
    birds = birds_layer(L, rng, 10, gain=0.06)
    return finish_amb(wind + gulls + chimes + insects + birds, L, 1.8, 0.2)


@sfx("amb_night_loop", loop=True, stereo=True, peak=-6.0)
def amb_night(rng, i):
    L = 40.0
    cr = crickets_layer(L, rng, 9, 0.08)
    surf = cyc(lambda v: lp(v, 1200), surf_layer(L, rng, distant=0.6)) * 0.35
    wind = wind_layer(L, rng, 300, 0.6, 0.03, gust_rate=0.08)
    return finish_amb(cr + surf + wind, L, 1.4, 0.2)


def rain_layer(L, rng, density=350, gain=1.0, drop_hi=7000):
    n = n_of(L)
    bed = np.stack([afx.shaped_noise(n, rng, lambda f: np.where(f > 400, 1.0, (np.maximum(f, 1) / 400) ** 2) *
                                     np.where(f > 8000, (8000 / np.maximum(f, 1)) ** 2, 1)) for _ in range(2)], 1)
    drops = np.zeros((n + n_of(0.05), 2))
    cnt = int(density * L)
    ts = rng.uniform(0, L, cnt)
    fs = rng.uniform(1500, drop_hi, cnt)
    for t, f in zip(ts, fs):
        k = n_of(0.006)
        tt = np.arange(k) / SR
        d = np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.0015)
        p = rng.uniform(-1, 1)
        s = n_of(t)
        a = rng.uniform(0.1, 1.0)
        drops[s:s + k, 0] += d * a * (1 - p) / 2
        drops[s:s + k, 1] += d * a * (1 + p) / 2
    drops = afx.wrap_tail(drops, n)
    return (bed * 0.25 + drops * 0.5) * gain


@sfx("amb_rain_loop", loop=True, stereo=True, peak=-3.0)
def amb_rain(rng, i):
    L = 30.0
    r = rain_layer(L, rng, 450)
    return finish_amb(r, L, 1.0, 0.15)


@sfx("amb_rain_interior_loop", loop=True, stereo=True, peak=-4.0)
def amb_rain_interior(rng, i):
    L = 30.0
    n = n_of(L)
    roof = cyc(lambda v: lp(v, 1400), rain_layer(L, rng, 600, drop_hi=4000))
    window = buf(L + 1, True)
    for k in range(int(30 * L)):
        f = rng.uniform(2500, 6000)
        y = afx.modal([f, f * 1.6], [0.01, 0.006], [1, 0.4], 0.04, rng)
        place(window, y, rng.uniform(0, L), rng.choice([-0.7, 0.7]) + rng.uniform(-0.2, 0.2), rng.uniform(0.02, 0.1))
    window = afx.wrap_tail(window, n)
    gutter = buf(L + 1, True)
    t = 0.3
    while t < L:
        y = afx.modal([rng.uniform(600, 900)], [0.03], [1], 0.1, rng)
        place(gutter, y, t, 0.5, 0.15)
        t += rng.uniform(0.6, 1.4)
    gutter = afx.wrap_tail(gutter, n)
    room = np.stack([lp(afx.colored(n, rng, -4), 200)] * 2, 1) * 0.05
    return finish_amb(roof + window + gutter + room, L, 0.5, 0.25)


@sfx("amb_storm_wind_loop", loop=True, stereo=True, peak=-2.0)
def amb_storm_wind(rng, i):
    L = 40.0
    n = n_of(L)
    w1 = wind_layer(L, rng, 500, 1.4, 1.0, leaves=0.25, gust_rate=0.25)
    w2 = wind_layer(L, rng, 900, 5.0, 0.4, gust_rate=0.18)  # howl
    low = np.stack([afx.colored(n, rng, -6, hi=150)] * 2, 1) * periodic_env(n, rng, 0.2, 0.3, 1)[:, None] * 0.5
    return finish_amb(w1 + w2 + low, L, 1.0, 0.1)


@sfx("amb_ocean_loop", loop=True, stereo=True, peak=-2.0)
def amb_ocean(rng, i):
    L = 48.0
    surf = surf_layer(L, rng, (8, 11))
    gulls = buf(L + 3, True)
    for k in range(3):
        place(gulls, distance(gull_call(rng), 0.6, 80 + k), rng.uniform(0, L), rng.uniform(-0.8, 0.8), 0.06)
    return finish_amb(surf + afx.wrap_tail(gulls, n_of(L)), L, 1.0, 0.1)


@sfx("amb_shelter_hum_loop", loop=True, stereo=True, peak=-6.0)
def amb_shelter_hum(rng, i):
    L = 30.0
    n = n_of(L)
    t = np.arange(n) / SR
    hum = (np.sin(2 * np.pi * 58 * t) * 0.6 + np.sin(2 * np.pi * 116 * t) * 0.4 + np.sin(2 * np.pi * 87 * t) * 0.5
           + np.sin(2 * np.pi * 174 * t) * 0.25 + np.sin(2 * np.pi * 87.1 * t) * 0.3)
    air = afx.shaped_noise(n, rng, lambda f: np.where(f < 1500, 1.0, (1500 / np.maximum(f, 1)) ** 2) *
                           (1 + 2 * np.exp(-((f - 230) / 60) ** 2)))
    rattle = np.zeros(n)
    k = 0
    while k * (1 / 14.5) < L:
        s = n_of(k / 14.5)
        rattle[s:s + 50] += np.exp(-np.arange(min(50, n - s)) / 10) * 0.2
        k += 1
    rattle = cyc(lambda v: bp(v, 800, 4000), rattle) * periodic_env(n, rng, 0.2, 0, 1) ** 3
    mono = hum * 0.15 + air * 0.4 + rattle * 0.3
    y = np.stack([mono, np.roll(mono, 2000)], 1)
    return finish_amb(y, L, 1.6, 0.25)


@sfx("amb_shelter_drip_loop", loop=True, stereo=True, peak=-4.0)
def amb_shelter_drip(rng, i):
    L = 30.0
    n = n_of(L)
    x = buf(L + 1, True)
    for src in range(3):
        p = rng.uniform(-0.8, 0.8)
        base = rng.uniform(700, 1300)
        t = rng.uniform(0, 2)
        per = rng.uniform(1.8, 4.5)
        while t < L:
            k = n_of(0.08)
            tt = np.arange(k) / SR
            f = base * (1 + 1.2 * np.minimum(1, tt / 0.02))
            plip = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.018) + click(rng, 0.08, 2000, 8000, 0.001) * 0.2
            place(x, plip, t, p, rng.uniform(0.5, 1.0))
            t += per * rng.uniform(0.6, 1.5)
    drips = afx.wrap_tail(x, n)
    hum = np.stack([lp(afx.colored(n, rng, -4.0), 250)] * 2, 1) * 0.04
    return reverb(drips, rt60=2.8, wet=0.6, dry=0.8, size=1.6, seed=90, loop=True, er=0.8) + hum


@sfx("amb_bloom_loop", loop=True, stereo=True, peak=-4.0)
def amb_bloom(rng, i):
    L = 30.0
    n = n_of(L)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    freqs = [73.4, 110.0, 146.8, 220.0, 329.6, 415.3, 554.4, 659.3, 880.0, 1108.7, 1318.5, 1661.2]
    for k, f in enumerate(freqs):
        for ch in range(2):
            fq = round(f * (1 + (0.002 if ch else -0.002)) * L) / L
            trem_rate = round((0.2 + 0.15 * k) * L) / L
            hi_trem = round(rng.uniform(5, 9) * L) / L if f > 800 else 0
            a = (0.6 + 0.4 * np.sin(2 * np.pi * trem_rate * t + rng.uniform(0, 6)))
            if hi_trem:
                a *= 0.6 + 0.4 * np.sin(2 * np.pi * hi_trem * t)
            out[:, ch] += np.sin(2 * np.pi * fq * t + rng.uniform(0, 6)) * a / (1 + 0.25 * k)
    whisper = np.stack([afx.shaped_noise(n, rng, lambda f: np.exp(-((f - 3500) / 1500) ** 2)) *
                        periodic_env(n, rng, 0.5, 0, 1) ** 2 for _ in range(2)], 1) * 0.15
    y = out * 0.06 + whisper
    pings = buf(L + 3, True)
    for k in range(40):
        f = rng.choice(freqs[6:]) * 2
        place(pings, afx.modal([f], [1.5], [1], 2.5, rng), rng.uniform(0, L), rng.uniform(-1, 1), 0.02)
    y = y + afx.wrap_tail(pings, n)
    return reverb(y, rt60=3.5, wet=0.5, dry=1.0, size=2.0, seed=91, loop=True)
