"""Score cues: title, cold open, morning, exploration, night, shelter, warm stingers."""
import numpy as np
import afx
import mus
from mus import Song, midi, parse_prog, voicing, bass_note, arp, pad
from score_common import *


# ============================================================================================ TITLE
def title_loop():
    s = Song(72, seed=11)
    M = 4
    intro = "D | Bm7 | Gmaj7 | Asus4 A"
    prog = concat_prog(intro, THEME_A_CH, THEME_B_CH, THEME_A_CH, "Bm7 | Gmaj7 | Em7 A7 | D", intro)
    L_bars = 36
    piano = s.track("piano", "piano", vol=1.0, pan=-0.1, rev=0.28, hum_t=0.012)
    pianoL = s.track("pianoL", "piano", vol=0.75, pan=-0.15, rev=0.32, hum_t=0.012)
    strings = s.track("strings", "slowstr", vol=0.55, pan=0.15, rev=0.45, width=1.3)
    cello = s.track("cello", "cello", vol=0.6, pan=0.25, rev=0.35)
    violin = s.track("violin", "violin", vol=0.65, pan=0.2, rev=0.45, hum_t=0.015)
    celesta = s.track("celesta", "celesta", vol=0.32, pan=-0.35, rev=0.5)
    harp = s.track("harp", "harp", vol=0.45, pan=0.4, rev=0.45)
    padt = s.track("pad", "warmpad", vol=0.25, rev=0.5, width=1.4)

    # left-hand flowing arpeggio throughout (lighter in the violin section where the harp takes over)
    arp_pat = [0, 2, 3, 4, 3, 2, 3, 1]
    for st, du, sy in prog:
        bar = st / M
        sub = [(st, du, sy)]
        v = 50 if (20 <= bar < 28) else 56
        arp(pianoL, sub, arp_pat, vel=v, center=57, n=4, step=0.5, gate=2.5, accents=[6, 0, 0, 0, 3, 0, 0, 0])
    pedal_prog(pianoL, prog)
    pedal_prog(piano, prog)
    # theme on piano (bars 4-19)
    play_lines(piano, 4 * M, THEME_A + THEME_B, vel=72, vel_curve=[0, -4, 2, -6, 0, -2, 4, -6])
    # theme A on violin with celesta doubling (bars 20-27)
    play_lines(violin, 20 * M, THEME_A, vel=78, octave=0, gate=1.0)
    violin.expr(0, 20 * M, 90, 90)
    for i in range(8):
        violin.expr((20 + i) * M, (20 + i) * M + 2, 70, 105)
        violin.expr((20 + i) * M + 2, (21 + i) * M, 105, 80)
    play_lines(celesta, 20 * M, THEME_A, vel=60, octave=1)
    arp(harp, section(prog, 20, 28), [0, 2, 3, 4, 5, 4, 3, 2], vel=55, center=67, n=4, step=0.5, gate=3)
    # theme B ending on piano, octave doubled softly
    play_lines(piano, 28 * M, THEME_B[4:], vel=74)
    play_lines(piano, 28 * M, THEME_B[4:], vel=50, octave=-1)
    # strings pad + cello roots everywhere except the very first bars (enter softly)
    pad(strings, section(prog, 2, 36), vel=62, center=62, n=4)
    swells(strings, section(prog, 2, 36), 50, 92)
    strings.expr(0, 2 * M, 40, 50)
    bass_line(cello, section(prog, 4, 36), vel=62, low=midi("D2"), high=midi("D3"))
    pad(padt, prog, vel=50, center=66, n=3)
    x = s.render(L_bars * M * 60 / 72, loop=True, rt60=2.8)
    return x


# ============================================================================================ COLD OPEN
def coldopen():
    M = 4
    tm = [(0, 68), (8 * M, 66), (10 * M, 60), (12 * M, 50), (13 * M, 46)]
    s = Song(68, seed=12, tempo_map=tm)
    piano = s.track("piano", "piano", rev=0.32, hum_t=0.014, hum_v=7)
    pl = s.track("pianoL", "piano", rev=0.34, vol=0.8, hum_t=0.014)
    prog = concat_prog("D", THEME_A_CH, "Bm7 | Gmaj7 | Em7 A7 | D")
    # bar 16: final chord
    for st, du, sy in prog:
        arp(pl, [(st, du, sy)], [0, 2, 3, 4, 1, 3, 2, 3], vel=46 if st < 4 else 50, center=58, n=4, step=0.5,
            gate=3.0, accents=[8, 0, 2, 0, 4, 0, 2, 0])
    pedal_prog(pl, prog + [(13 * M, 8, "D")])
    pedal_prog(piano, prog + [(13 * M, 8, "D")])
    play_lines(piano, 1 * M, THEME_A, vel=64, vel_curve=[0, -3, 3, -6, 2, 0, 5, -5])
    play_lines(piano, 9 * M, THEME_B[4:], vel=66, vel_curve=[2, 4, 4, -4])
    # final: rolled D(add9) chord, low to high, then a high F# as a last breath
    roll = [midi(k) for k in ("D2", "A2", "D3", "F#3", "A3", "E4", "F#4", "A4", "D5")]
    for i, k in enumerate(roll):
        piano.n(13 * M + i * 0.09, 4.5 - i * 0.09, k, 52 - i)
    piano.n(13 * M + 1.5, 3.0, midi("F#5"), 40)
    x = s.render(s.sec(13 * M + 4.5), loop=False, tail=4.0, rt60=2.8)
    return x


# ============================================================================================ MORNING
MORN_A = "Fmaj7 | D7 | Gm7 | C7 | Fmaj7 | Bbmaj7 | Gm7 C7 | F6"
MORN_B = "Bbmaj7 | Bbm6 | Am7 | D7 | Gm7 | Gm7 | C7sus4 | C7"
MORN_MEL_A = [
    "r:.5 C5:.5 A4:.5 C5:.5 E5:2",
    "D5:1.5 C5:.5 A4:1 r:1",
    "r:.5 Bb4:.5 D5:.5 F5:.5 A5:1.5 G5:.5",
    "E5:2 r:2",
    "r:.5 C5:.5 A4:.5 C5:.5 F5:1.5 E5:.5",
    "D5:1 F5:1 A5:1 G5:1",
    "F5:.5 E5:.5 D5:.5 Bb4:.5 C5:1 E5:1",
    "F5:2 r:2",
]
MORN_MEL_B = [
    "D5:1.5 F5:.5 A5:2",
    "G5:1.5 F5:.5 Db5:2",
    "C5:1.5 E5:.5 G5:2",
    "F#5:1 E5:.5 D5:.5 C5:2",
    "Bb4:1 D5:1 F5:1 A5:1",
    "G5:1.5 F5:.5 D5:2",
    "C5:1 F5:1 E5:1 Bb4:1",
    "C5:3 r:1",
]


def morning_loop():
    s = Song(96, swing=0.6, seed=21)
    M = 4
    prog = concat_prog(MORN_A, MORN_A, MORN_B, MORN_A, MORN_B, MORN_A)
    gtr = s.track("gtr", "nylon", vol=0.8, pan=-0.3, rev=0.2, hum_t=0.01)
    vib = s.track("vibes", "vibes", vol=0.7, pan=0.25, rev=0.3)
    bass = s.track("bass", "abass", vol=0.75, pan=0.05, rev=0.08)
    pno = s.track("piano", "piano", vol=0.6, pan=0.1, rev=0.25)
    dr = s.track("drums", "brush", vol=1.3, pan=0.0, rev=0.12, hum_t=0.006)
    rng = np.random.default_rng(5)
    comp_hits(gtr, prog, [(0, 1.2), (1.5, 0.45), (2.5, 1.2), (3.5, 0.45)], center=58, vel=50, n=4, strum=0.03,
              vel_acc=[6, -2, 2, -4])
    # bass 2-feel with fifths on 3
    mus.bassline_roots(bass, prog, vel=72, pattern=((0, 1.9), (2, 1.9)), fifth_on=(2,))
    play_lines(vib, 8 * M, MORN_MEL_A, vel=66)
    play_lines(vib, 16 * M, MORN_MEL_B, vel=64)
    # piano takes the A melody softly an octave up with a few 6ths underneath
    play_lines(pno, 24 * M, MORN_MEL_A, vel=58, octave=0)
    play_lines(pno, 24 * M, MORN_MEL_A, vel=36, transpose=-9)
    # vibes improvised, sparse counter-line over the second B
    mus.improvise(vib, section(prog, 32, 40), rng, 32 * M, 8, low=midi("F4"), high=midi("D6"), density=0.45,
                  vel=56, scale_key=5, scale="major")
    play_lines(vib, 40 * M, MORN_MEL_A, vel=66)
    play_lines(gtr, 40 * M, MORN_MEL_A, vel=40, transpose=-12)
    for bar in range(48):
        b = bar * M
        for beat in range(4):
            dr.n(b + beat, 0.8, 40, 70 if beat % 2 else 60)  # swirl
        dr.n(b + 1, 0.3, 38, 52)
        dr.n(b + 3, 0.3, 38, 56)
        if bar >= 8:
            for o in (0, 1, 1.5, 2, 3, 3.5):
                dr.n(b + o, 0.3, RIDE, 46 if o % 1 else 54)
    x = s.render(48 * M * 60 / 96, loop=True, rt60=1.6, rev_size=0.6)
    return x


RIDE = mus.RIDE


# ============================================================================================ EXPLORE DAY
def explore_day_loop():
    s = Song(80, seed=31)
    M = 4
    T = 5  # D -> G
    intro = "Gmaj7 | Cmaj7/G | Em7 | Dsus4 D"
    progA = parse_prog(THEME_A_CH, M, T)
    progB = parse_prog(THEME_B_CH, M, T)
    pa = " | ".join(mus.transpose_sym(c, T) for c in THEME_A_CH.split(" | "))
    pb = " | ".join(mus.transpose_sym(c, T) for c in THEME_B_CH.split(" | "))
    prog = concat_prog(intro, intro, pa, intro, intro, pb, intro, intro, pa, "Cmaj7 | Dsus4 D")
    nb = 50
    gtr = s.track("gtr", "nylon", vol=0.85, pan=-0.25, rev=0.28, hum_t=0.012)
    pno = s.track("piano", "piano", vol=0.9, pan=0.05, rev=0.33, hum_t=0.014)
    vib = s.track("vibes", "vibes", vol=0.55, pan=0.35, rev=0.4)
    strs = s.track("strings", "slowstr", vol=0.5, pan=0.1, rev=0.5, width=1.3)
    vln = s.track("violins", "strings", vol=0.5, pan=0.2, rev=0.5)
    cello = s.track("cello", "cello", vol=0.5, pan=0.3, rev=0.4)
    harp = s.track("harp", "harp", vol=0.4, pan=-0.4, rev=0.5)
    rng = np.random.default_rng(9)
    # fingerpicked guitar everywhere (p-i-m-a pattern with thumb on beat 1 and 3)
    gpat = [0, 3, 2, 4, 1, 3, 2, 4]
    arp(gtr, prog, gpat, vel=54, center=60, n=4, step=0.5, gate=3.0, accents=[8, 0, 0, 3, 5, 0, 0, 0])
    # piano theme A (bars 8-15), sparse and singing
    play_lines(pno, 8 * M, THEME_A, vel=66, transpose=T, vel_curve=[0, -3, 3, -6, 0, -2, 4, -6])
    pedal_prog(pno, prog)
    # vibes counter-line over intro (bars 16-23)
    mus.improvise(vib, section(prog, 16, 24), rng, 16 * M, 8, low=midi("D5"), high=midi("D6"), density=0.35,
                  vel=54, scale_key=7, scale="majpent", phrase=(2, 4))
    # strings pad from bar 16
    pad(strs, section(prog, 16, 50), vel=58, center=62, n=4)
    swells(strs, section(prog, 16, 50), 45, 85)
    strs.expr(0, 16 * M, 45, 45)
    # violins carry theme B (bars 24-31)
    play_lines(vln, 24 * M, THEME_B, vel=74, transpose=T - 12, gate=1.0)
    for i in range(8):
        vln.expr((24 + i) * M, (24 + i) * M + 2, 70, 100)
        vln.expr((24 + i) * M + 2, (25 + i) * M, 100, 78)
    arp(pno, section(prog, 24, 32), [0, 2, 3, 4, 5, 4, 3, 2], vel=44, center=64, n=4, step=0.5, gate=2.0)
    bass_line(cello, section(prog, 24, 50), vel=58, low=midi("C2"), high=midi("C3"))
    # memory: piano high-register fragments (bars 32-39)
    for bar, ln in zip((32, 34, 37, 39), THEME_A[:4]):
        pno.mel(bar * M, ln, vel=52, transpose=T)
    # theme A on vibes + harp (bars 40-47)
    play_lines(vib, 40 * M, THEME_A, vel=60, transpose=T - 12)
    arp(harp, section(prog, 40, 48), [0, 2, 3, 4, 5, 4, 3, 2], vel=50, center=64, n=4, step=0.5, gate=3)
    x = s.render(nb * M * 60 / 80, loop=True, rt60=2.6)
    return x


# ============================================================================================ EXPLORE DAY 2
T2_CH_A = "F | Am/E | Dm | Bb | F/C | Gm7 | C7sus4 | C7"
T2_CH_B = "Bb | C | Am | Dm | Gm | Bb/C | F | C7sus4"
T2_A = ["C5:2 A4:1", "E5:2 C5:1", "F5:1.5 E5:.5 D5:1", "D5:3", "C5:2 A4:1", "Bb4:1 D5:1 F5:1",
        "F5:1.5 E5:.5 D5:1", "E5:2 C5:1"]
T2_B = ["D5:1 F5:1 Bb5:1", "G5:2 E5:1", "A5:1.5 G5:.5 E5:1", "F5:2 D5:1", "Bb4:1 D5:1 G5:1",
        "F5:1.5 E5:.5 D5:1", "C5:3", "r:3"]


def explore_day2_loop():
    M = 3
    s = Song(80, meter=3, seed=41)
    intro = "F | Bb/F | Dm | C7sus4"
    prog = concat_prog(intro, T2_CH_A, T2_CH_B, T2_CH_A, T2_CH_A, T2_CH_B, T2_CH_A, T2_CH_B, intro, meter=3)
    nb = 64
    pno = s.track("piano", "piano", vol=0.85, pan=-0.1, rev=0.32, hum_t=0.013)
    cello = s.track("cello", "cello", vol=0.75, pan=0.25, rev=0.4, hum_t=0.014)
    flute = s.track("flute", "flute", vol=0.6, pan=0.3, rev=0.45)
    clar = s.track("clar", "clarinet", vol=0.5, pan=-0.3, rev=0.45)
    harp = s.track("harp", "harp", vol=0.5, pan=-0.35, rev=0.45)
    strs = s.track("strings", "slowstr", vol=0.45, pan=0.1, rev=0.5, width=1.3)
    bass = s.track("bass", "contrabass", vol=0.45, pan=0.0, rev=0.3)
    # piano: waltz broken chords (bass, then chord tones)
    arp(pno, prog, [0, 2, 3, 4, 3, 2], vel=50, center=60, n=3, step=0.5, gate=2.0, accents=[8, 0, 2, 0, 3, 0])
    pedal_prog(pno, prog)
    play_lines(cello, 4 * M, T2_A + T2_B, meter=3, vel=78, transpose=-12, gate=1.0)
    for i in range(16):
        cello.expr((4 + i) * M, (4 + i) * M + 1.5, 70, 105)
        cello.expr((4 + i) * M + 1.5, (5 + i) * M, 105, 80)
    play_lines(flute, 20 * M, T2_A, meter=3, vel=70)
    play_lines(clar, 20 * M, T2_A, meter=3, vel=60, transpose=-4)  # a gentle third-ish below (diatonic-ish)
    clar.notes = []
    # proper diatonic harmony a third below for the clarinet
    scale = [5, 7, 9, 10, 0, 2, 4]
    for (t0, t1, k, v) in list(flute.notes):
        pc = k % 12
        if pc in scale:
            i = scale.index(pc)
            below = scale[(i - 2) % 7]
            kk = k - ((pc - below) % 12)
            clar.notes.append((t0, t1, kk, max(1, v - 10)))
    # interlude 28-35: piano + harp alone
    arp(harp, section(prog, 28, 36), [0, 2, 3, 4, 5, 4], vel=52, center=67, n=4, step=0.5, gate=3)
    # strings take B (36-43) -> second time through A (44-51) piano melody, then B on cello+flute (52-59)
    vln = s.track("vln", "strings", vol=0.5, pan=0.2, rev=0.5)
    play_lines(vln, 36 * M, T2_B, meter=3, vel=80, gate=1.0)
    for i in range(8):
        vln.expr((36 + i) * M, (36 + i) * M + 1.5, 70, 100)
        vln.expr((36 + i) * M + 1.5, (37 + i) * M, 100, 75)
    play_lines(pno, 44 * M, T2_A, meter=3, vel=64, octave=0)
    play_lines(cello, 52 * M, T2_B, meter=3, vel=74, transpose=-12, gate=1.0)
    play_lines(flute, 52 * M, T2_B, meter=3, vel=60)
    pad(strs, section(prog, 4, 36) + section(prog, 44, 60), vel=50, center=60, n=3)
    swells(strs, section(prog, 4, 64), 40, 80)
    bass_line(bass, section(prog, 4, 60), vel=55, low=midi("E1"), high=midi("D2") + 12,
              pattern=((0, 1.5),), gate=0.9)
    x = s.render(nb * M * 60 / 80, loop=True, rt60=2.4)
    return x


# ============================================================================================ NIGHT
def explore_night_loop():
    M = 4
    s = Song(60, seed=51)
    A = "Emaj7 | C#m7 | Amaj7 | Bsus4 B"
    B = "G#m7 | C#m7 | Amaj7 | Bsus4"
    prog = concat_prog(A, A, A, B, A, B, A, "Amaj7 | Bsus4")
    nb = 30
    padt = s.track("pad", "warmpad", vol=0.45, rev=0.6, width=1.5)
    halo = s.track("halo", "halopad", vol=0.25, rev=0.7, width=1.5)
    harp = s.track("harp", "harp", vol=0.6, pan=-0.3, rev=0.55)
    cel = s.track("celesta", "celesta", vol=0.5, pan=0.3, rev=0.6, delay=(0.75, 0.35, 0.3))
    flute = s.track("flute", "flute", vol=0.55, pan=0.15, rev=0.6)
    pno = s.track("piano", "piano", vol=0.55, pan=-0.05, rev=0.5)
    rng = np.random.default_rng(13)
    pad(padt, prog, vel=55, center=57, n=4)
    pad(halo, prog, vel=45, center=69, n=3)
    arp(harp, prog, [0, 2, 3, 4, 5, None, 4, None], vel=48, center=62, n=4, step=0.5, gate=4)
    # starlight: sparse celesta twinkles (pentatonic) bars 8-15, 24-29
    for b0, b1 in ((8, 16), (24, 30)):
        mus.improvise(cel, section(prog, b0, b1), rng, b0 * M, b1 - b0, low=midi("B5"), high=midi("E7"),
                      density=0.3, vel=50, scale_key=4, scale="majpent", phrase=(1, 3), step=0.5)
    # flute: main theme fragment transposed to E (bars 16-23), long-breathed
    T = 2
    for b0 in (16, 24):
        play_lines(flute, b0 * M, THEME_A[:4], vel=62, transpose=T)
        for i in range(4):
            flute.expr((b0 + i) * M, (b0 + i) * M + 2, 70, 100)
            flute.expr((b0 + i) * M + 2, (b0 + i + 1) * M, 100, 70)
    # low piano bell-tones
    for st, du, sy in prog:
        if int(st / M) % 2 == 0:
            pno.n(st, du, bass_note(sy, midi("E2"), midi("D#3")), 40)
            pno.n(st + 1.5, du - 1.5, voicing(sy, 76, None, 2)[-1], 34)
    pedal_prog(pno, prog)
    x = s.render(nb * M, loop=True, rt60=3.5, rev_size=1.4)
    return x


# ============================================================================================ SHELTER WAKE
def shelter_wake_loop():
    """Low synth drones (periodic) + bowed-glass pads + distant metal resonances + sparse celesta."""
    M = 4
    bpm = 60
    nb = 30
    L = nb * M * 60 / bpm  # 120 s
    n = afx.n_of(L)
    s = Song(bpm, seed=61)
    prog = concat_prog("Am | Fmaj7/A | Em/A | Dm9/A", "Am | Cmaj7/G | Fmaj7#11 | Esus4",
                       "Am | Fmaj7/A | Em/A | Dm9/A", "Fmaj7 | Cmaj7/E | Dm9 | Esus4",
                       "Am | Fmaj7/A | Em/A | Dm9/A", "Fmaj7 | Cmaj7/E | Dm9 | Esus4",
                       "Am | Fmaj7/A | Em/A | Dm9/A", "Am | Esus4")
    glass = s.track("glass", "bowedglass", vol=0.5, rev=0.7, width=1.6)
    choir = s.track("oohs", "oohs", vol=0.25, rev=0.7, width=1.4)
    cel = s.track("cel", "celesta", vol=0.35, pan=0.4, rev=0.7, delay=(1.0, 0.4, 0.35))
    low = s.track("lowstr", "contrabass", vol=0.4, rev=0.5)
    pad(glass, prog, vel=50, center=60, n=3)
    swells(glass, prog, 50, 95)
    pad(choir, section(prog, 8, 30), vel=40, center=55, n=3)
    swells(choir, section(prog, 8, 30), 30, 70)
    bass_line(low, prog, vel=45, low=midi("A1"), high=midi("A2"))
    rng = np.random.default_rng(17)
    for bar in range(0, nb, 3):
        if rng.random() < 0.7:
            sy = mus.prog_at(prog, bar * M)
            pcs, _, _ = mus.chord_pcs(sy)
            ks = [k for k in range(midi("A5"), midi("A6")) if k % 12 in pcs]
            b = bar * M + rng.uniform(0, 2)
            for j in range(rng.integers(1, 4)):
                cel.n(b + j * rng.choice([0.75, 1.0, 1.5]), 2.0, int(rng.choice(ks)), 42)
    music = s.render(L, loop=True, rt60=4.5, rev_size=1.6, master=False, glue=False)
    # periodic drones: frequencies quantised so they complete whole cycles in L
    t = np.arange(n) / afx.SR
    q = lambda f: round(f * L) / L
    dr = np.zeros(n)
    for f, a in ((55.0, 1.0), (55.0 * 1.003, 0.8), (82.41, 0.5), (110.0 * 0.998, 0.35)):
        ff = q(f)
        dr += a * afx.saw_blep(np.full(n, ff))
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * q(1 / 20) * t)
    dr = afx.svf(np.concatenate([dr, dr]), np.tile(180 + 260 * lfo, 2), 1.2)[n:]  # run twice: settle state
    rng = np.random.default_rng(23)
    air = afx.shaped_noise(n, rng, lambda f: np.exp(-((np.log2(np.maximum(f, 1) / 400)) ** 2) * 1.5)) * 0.04
    drone = afx.stereo_width(np.stack([dr, np.roll(dr, 900)], axis=1), 1.0) * 0.06 + air[:, None]
    # distant metallic resonances (shelter structure settling) - modal, long, through big reverb
    metal = np.zeros((n, 2))
    for i in range(9):
        t0 = rng.uniform(0, L)
        base = rng.uniform(70, 160)
        ratios = np.array([1, 2.32, 3.86, 5.1, 6.9, 8.7, 11.2])
        hit = afx.modal(base * ratios * rng.uniform(0.98, 1.02, 7), rng.uniform(1.0, 4.0, 7),
                        rng.uniform(0.2, 1.0, 7) / ratios ** 0.6, 7.0, rng)
        hit = afx.lp(hit * afx.env_curve(len(hit), [(0, 0), (0.25, 1), (7, 1)]), 1800)
        p = afx.pan(hit, rng.uniform(-0.8, 0.8)) * rng.uniform(0.3, 0.6)
        tmp = np.zeros((n + p.shape[0], 2))
        afx.mix_at(tmp, p, afx.n_of(t0))
        metal += afx.wrap_tail(tmp, n)
    metal = afx.reverb(metal, rt60=6.0, wet=1.0, dry=0.25, size=2.0, loop=True, seed=9) * 0.25
    x = music + drone + metal
    return afx.master_music(x, -17.0, -1.5, loop=True)


# ============================================================================================ STINGERS
def sting_reunion():
    M = 4
    s = Song(68, seed=71, tempo_map=[(0, 68), (8, 66), (12, 52)])
    pno = s.track("piano", "piano", rev=0.35, hum_t=0.012)
    pl = s.track("pianoL", "piano", rev=0.35, vol=0.8)
    strs = s.track("strings", "slowstr", vol=0.6, rev=0.5, width=1.3)
    vln = s.track("vln", "violin", vol=0.45, pan=0.2, rev=0.5)
    cel = s.track("cel", "celesta", vol=0.3, pan=-0.3, rev=0.5)
    prog = parse_prog("D | Bm7 | Gmaj7 A7sus4 | D", M)
    lines = THEME_A[:2] + ["B4:1 G5:1.5 F#5:.5 E5:1", "F#5:4"]
    play_lines(pno, 0, lines, vel=64)
    play_lines(vln, 2 * M, lines[2:], vel=66, octave=-1)
    play_lines(cel, 3 * M, ["A5:1 D6:1 F#6:2"], vel=50)
    arp(pl, prog, [0, 2, 3, 4, 1, 3, 2, 3], vel=46, center=58, n=4, step=0.5, gate=3)
    pedal_prog(pl, prog)
    pedal_prog(pno, prog)
    pad(strs, prog, vel=58, center=62)
    strs.expr(0, 6, 30, 80)
    strs.expr(6, 12, 80, 100)
    strs.expr(12, 16, 100, 70)
    return s.render(s.sec(16), tail=3.0, rt60=2.8)


def sting_levelup():
    s = Song(132, seed=72)
    br = s.track("brass", "brass", vol=0.7, rev=0.3)
    gl = s.track("glock", "glock", vol=0.5, pan=0.3, rev=0.4)
    cel = s.track("cel", "celesta", vol=0.5, pan=-0.3, rev=0.4)
    strs = s.track("str", "strings", vol=0.5, rev=0.4)
    tim = s.track("timp", "timpani", vol=0.6, rev=0.3)
    up = ["D5", "F#5", "A5", "D6"]
    for i, k in enumerate(up):
        gl.n(i / 3, 0.4, k, 90)
        cel.n(i / 3, 0.4, k, 80)
    gl.n(4 / 3, 2.5, "F#6", 95)
    gl.n(4 / 3 + 0.05, 2.5, "A6", 85)
    br.chord(4 / 3, 2.0, [midi(k) for k in ("D4", "F#4", "A4", "D5")], 92)
    strs.chord(4 / 3, 2.4, [midi(k) for k in ("D3", "A3", "D4", "F#4", "A4", "D5")], 85)
    tim.n(4 / 3, 1.0, "D2", 100)
    return s.render(3.2, tail=2.0, rt60=1.8)


def sting_quest_start():
    s = Song(100, seed=73)
    hn = s.track("horns", "horns", vol=0.8, rev=0.4)
    strs = s.track("str", "slowstr", vol=0.6, rev=0.45)
    tim = s.track("timp", "timpani", vol=0.6, rev=0.35)
    harp = s.track("harp", "harp", vol=0.5, pan=-0.3, rev=0.4)
    hn.mel(0, "A3:.5 D4:.5 E4:.5 F#4:2.5", vel=88)
    hn.mel(1.5, "A3:2.5", vel=70)
    strs.chord(0, 4.0, [midi(k) for k in ("D3", "A3", "E4", "F#4")], 70)
    strs.expr(0, 2, 50, 100)
    strs.expr(2, 4, 100, 70)
    tim.n(1.5, 1.0, "D2", 80)
    tim.n(0, 0.5, "A1", 60)
    for i, k in enumerate(["D4", "F#4", "A4", "D5", "E5", "F#5", "A5"]):
        harp.n(1.5 + i * 0.08, 2.0, k, 60)
    return s.render(3.0, tail=2.5, rt60=2.0)


def sting_quest_done():
    s = Song(96, seed=74)
    cel = s.track("cel", "celesta", vol=0.6, pan=0.2, rev=0.45)
    pno = s.track("piano", "piano", vol=0.7, rev=0.4)
    strs = s.track("str", "slowstr", vol=0.6, rev=0.5)
    hn = s.track("horns", "horns", vol=0.5, rev=0.45)
    harp = s.track("harp", "harp", vol=0.5, pan=-0.3, rev=0.4)
    cel.mel(0, "G5:.5 F#5:.5 E5:.5 C#5:.5 D5:3", vel=78)
    pno.mel(0, "G5:.5 F#5:.5 E5:.5 C#5:.5 D5:3", vel=62)
    pno.chord(0, 1.0, [midi(k) for k in ("E3", "B3", "D4", "G4")], 55)
    pno.chord(1.0, 1.0, [midi(k) for k in ("A2", "G3", "C#4", "E4")], 58)
    pno.chord(2.0, 3.0, [midi(k) for k in ("D2", "A2", "F#3", "A3", "D4")], 62)
    strs.chord(0, 1, [midi(k) for k in ("E3", "B3", "G4")], 60)
    strs.chord(1, 1, [midi(k) for k in ("A2", "G3", "C#4")], 66)
    strs.chord(2, 3.5, [midi(k) for k in ("D3", "A3", "F#4", "A4")], 74)
    hn.chord(2, 3.0, [midi(k) for k in ("D4", "F#4", "A4")], 64)
    for i, k in enumerate(["D5", "E5", "F#5", "A5", "B5", "D6"]):
        harp.n(2 + i * 0.07, 2.0, k, 55)
    pedal_prog(pno, [(0, 1, "x"), (1, 1, "x"), (2, 5, "x")])
    return s.render(4.0, tail=2.5, rt60=2.2)


def sting_discover():
    s = Song(80, seed=75)
    harp = s.track("harp", "harp", vol=0.6, pan=-0.3, rev=0.5)
    vib = s.track("vib", "vibes", vol=0.55, pan=0.3, rev=0.5)
    fl = s.track("flute", "flute", vol=0.6, pan=0.15, rev=0.55)
    strs = s.track("str", "slowstr", vol=0.55, rev=0.55, width=1.4)
    gl = s.track("glass", "bowedglass", vol=0.3, rev=0.6)
    gl_notes = ["G3", "B3", "D4", "F#4", "A4", "C#5", "D5", "F#5", "A5", "C#6"]
    for i, k in enumerate(gl_notes):
        harp.n(i * 0.07, 3.0, k, 50 + i * 2)
    strs.chord(0, 2.0, [midi(k) for k in ("G3", "D4", "F#4", "C#5")], 60)
    strs.chord(2, 3.0, [midi(k) for k in ("D3", "A3", "E4", "F#4")], 66)
    strs.expr(0, 2, 40, 90)
    strs.expr(2, 5, 90, 60)
    gl.chord(0, 5.0, [midi(k) for k in ("D5", "A5")], 50)
    vib.chord(2, 2.5, [midi(k) for k in ("F#5", "A5", "E6")], 60, strum=0.05)
    fl.mel(0.8, "A5:.6 F#5:2.6", vel=70)
    return s.render(4.0, tail=3.0, rt60=2.8)


def sting_ending():
    M = 4
    tm = [(0, 76), (36, 76), (40, 64), (44, 50)]
    s = Song(76, seed=76, tempo_map=tm)
    pno = s.track("piano", "piano", vol=0.75, pan=-0.1, rev=0.32)
    vln = s.track("vln", "strings", vol=0.8, pan=0.15, rev=0.45)
    strs = s.track("str", "slowstr", vol=0.55, rev=0.5, width=1.3)
    cello = s.track("cello", "cello", vol=0.6, pan=0.3, rev=0.4)
    hn = s.track("horns", "horns", vol=0.6, pan=-0.2, rev=0.45)
    tim = s.track("timp", "timpani", vol=0.6, rev=0.4)
    cym = s.track("cym", "orch", vol=0.7, rev=0.4)
    harp = s.track("harp", "harp", vol=0.45, pan=-0.4, rev=0.45)
    gl = s.track("glock", "celesta", vol=0.35, pan=0.35, rev=0.5)
    prog = concat_prog(THEME_A_CH, "Bm7 | Gmaj7 | Em7 A7sus4 A7 | D")
    play_lines(pno, 0, THEME_A[:4], vel=66)
    play_lines(vln, 4 * M, THEME_A[4:], vel=82, gate=1.0)
    play_lines(hn, 4 * M, THEME_A[4:], vel=64, transpose=-12)
    vln.mel(8 * M, "F#5:1.5 E5:.5 D5:1 B4:1 E5:1 D5:.5 E5:.5 F#5:1 G5:1 A5:1.5 G5:.5 E5:1 E5:1 D5:4", vel=86,
            gate=1.0)
    hn.mel(8 * M, "D4:2 B3:2 G3:2 B3:2 E4:1.333 D4:1.333 C#4:1.334 A3:4", vel=60)
    vln.expr(0, 8 * M, 70, 95)
    vln.expr(8 * M, 11 * M, 95, 120)
    vln.expr(11 * M, 12 * M + 3, 120, 90)
    arp(pno, prog, [0, 2, 3, 4, 5, 4, 3, 2], vel=50, center=60, n=4, step=0.5, gate=2.5)
    pedal_prog(pno, prog)
    pad(strs, prog, vel=60, center=62)
    swells(strs, prog, 60, 100)
    bass_line(cello, prog, vel=66, low=midi("D2"), high=midi("D3"))
    arp(harp, section(prog, 4, 12), [0, 2, 3, 4, 5, 4, 3, 2], vel=48, center=67, n=4, step=0.5, gate=3)
    # build into final chord
    for i in range(16):
        tim.n(10 * M + 2 + i * 0.125, 0.15, "A1", 40 + i * 4)
    tim.n(11 * M, 2, "D2", 105)
    cym.n(11 * M, 2, 57, 70)
    for i, k in enumerate(["D4", "F#4", "A4", "D5", "F#5", "A5", "D6"]):
        gl.n(11 * M + i * 0.12, 4.0, k, 54)
    return s.render(s.sec(12 * M + 4), tail=6.0, rt60=3.0)
