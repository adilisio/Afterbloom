"""Score cues: the dash to the shelter, combat, Thornback boss, Bloom stinger."""
import numpy as np
import afx
import mus
from mus import Song, midi, parse_prog, voicing, bass_note, arp, pad
from score_common import *

O_BD, O_SD, O_CYM1, O_CYM2 = 36, 38, 59, 57  # orchestral kit keys


def action_bus(x):
    """Tame the low end of the big percussion/low-string cues and add a little bite."""
    x = afx.shelf(x, 140, -3.5, "low")
    x = afx.peq(x, 2800, 0.9, 2.0)
    return x


def ostinato(tr, prog, pattern, vel=88, low=midi("D2"), high=midi("C#3"), step=0.5, gate=0.55, acc=None):
    prev = None
    for st, du, sy in prog:
        r = bass_note(sy, low, high, prev)
        prev = r
        i = 0
        b = st
        while b < st + du - 1e-6:
            a = acc[i % len(acc)] if acc else (10 if i % 4 == 0 else 0)
            tr.n(b, step, r + pattern[i % len(pattern)], vel + a, gate=gate)
            b += step
            i += 1


def spiccato16(tr, prog, vel=70, center=69, step=0.25):
    prev = None
    for st, du, sy in prog:
        v = voicing(sy, center, prev, 3)
        prev = v
        seq = [v[0], v[1], v[2], v[1]]
        b = st
        i = 0
        while b < st + du - 1e-6:
            tr.n(b, step, seq[i % 4] + (12 if (i // 8) % 2 else 0), vel + (12 if i % 4 == 0 else 0), gate=0.5)
            b += step
            i += 1


def stabs(tr, prog, hits, vel=100, center=58, n=4, gate=0.4):
    comp_hits(tr, prog, [(o, 0.5) for o in hits], center=center, vel=vel, n=n)
    for i, (a, b, k, v) in enumerate(tr.notes):
        pass


# ============================================================================================ DASH
def dash_loop():
    M = 4
    s = Song(144, seed=81)
    P = "Dm | Bb | F | C"
    Q = "Dm | Bb | Gm | A"
    R = "Bb | C | Dm | A"
    S = "Bb | C | Gm | A"
    prog = concat_prog(P, P, Q, P, Q, P, Q, R, S, P, Q, P, "Gm | A | Bb | A")
    nb = 52
    low = s.track("low", "strings", vol=0.9, pan=-0.05, rev=0.2)
    pz = s.track("pizz", "pizz", vol=0.6, pan=-0.2, rev=0.2)
    hi = s.track("hi", "strings", vol=0.55, pan=0.25, rev=0.3)
    cb = s.track("cb", "contrabass", vol=0.5, pan=0.0, rev=0.2)
    br = s.track("brass", "brass", vol=0.7, pan=0.1, rev=0.3)
    tb = s.track("tbn", "trombone", vol=0.6, pan=-0.2, rev=0.3)
    hn = s.track("horns", "horns", vol=0.85, pan=-0.25, rev=0.35)
    tp = s.track("tpt", "trumpet", vol=0.6, pan=0.3, rev=0.35)
    tk = s.track("taiko", "taiko", vol=0.9, pan=0.0, rev=0.25, hum_t=0.004)
    ti = s.track("timp", "timpani", vol=0.8, pan=0.0, rev=0.3, hum_t=0.004)
    kit = s.track("kit", "orch", vol=0.9, pan=0.05, rev=0.2, hum_t=0.004)
    sn = s.track("snare", "standard", vol=0.6, pan=0.1, rev=0.2, hum_t=0.004)
    choir = s.track("choir", "choir", vol=0.4, rev=0.5, width=1.4)
    # low string ostinato everywhere (the engine of the dash)
    ostinato(low, prog, [0, 0, 12, 0, 0, 12, 0, 12], vel=86, low=midi("D2"), high=midi("C#3"))
    ostinato(pz, prog, [0, 12, 12, 0, 12, 12, 0, 12], vel=70, low=midi("D2"), high=midi("C#3"))
    bass_line(cb, section(prog, 4, 52), vel=78, low=midi("D1"), high=midi("C#2") + 12, gate=0.9)
    # pulses: timpani on every beat (bars 0-3 building), then taiko groove
    for bar in range(nb):
        b = bar * M
        sy = mus.prog_at(prog, b)
        r = bass_note(sy, midi("F1"), midi("E2"))
        if bar < 4:
            for beat in range(4):
                ti.n(b + beat, 0.5, r, 60 + bar * 8 + (10 if beat == 0 else 0))
            # snare roll crescendo in bar 3
            if bar == 3:
                for i in range(16):
                    sn.n(b + i * 0.25, 0.2, 38, 40 + i * 4)
            continue
        if 28 <= bar < 36:  # build: 8th taiko, snare roll grows
            for i in range(8):
                tk.n(b + i * 0.5, 0.4, midi("D2"), 70 + (25 if i % 2 == 0 else 0) + (bar - 28) * 2)
            if bar >= 32:
                for i in range(16):
                    sn.n(b + i * 0.25, 0.2, 38, 45 + (bar - 32) * 12 + i)
            ti.n(b, 1, r, 100)
            continue
        groove = [(0, 120), (0.75, 80), (1.5, 95), (2, 115), (2.75, 75), (3, 110), (3.5, 90)]
        for o, v in groove:
            tk.n(b + o, 0.4, midi("D2"), v)
        kit.n(b + 1, 0.3, O_SD, 85)
        kit.n(b + 3, 0.3, O_SD, 95)
        if bar % 4 == 0:
            kit.n(b, 1, O_CYM1, 90 if bar % 8 == 0 else 70)
            kit.n(b, 1, O_BD, 110)
            ti.n(b, 1, r, 110)
        if bar % 4 == 3:
            for i in range(4):
                sn.n(b + 2 + i * 0.25, 0.2, 47 - i * 2, 80 + i * 8)
    # brass stabs (bars 4-11, 36-51)
    stab_prog = section(prog, 4, 12) + section(prog, 36, 52)
    comp_hits(br, stab_prog, [(0, 0.45), (1.5, 0.45), (3, 0.9)], center=58, vel=98, n=4, vel_acc=[10, 0, 4])
    comp_hits(tb, stab_prog, [(0, 0.45), (1.5, 0.45), (3, 0.9)], center=46, vel=92, n=3)
    # heroic horn melody (bars 12-27): 2x8 bars, 2nd pass trumpets doubling an octave up
    horn_mel = [
        "D4:1.5 F4:.5 A4:2", "Bb4:1.5 A4:.5 F4:1 D4:1", "C5:1.5 A4:.5 F4:2", "G4:1.5 E4:.5 C4:1 E4:1",
        "D4:1.5 F4:.5 A4:1 D5:1", "D5:1.5 C5:.5 Bb4:1 F4:1", "G4:1 Bb4:1 D5:1 G5:1", "E5:2 C#5:2",
    ]
    horn_mel2 = horn_mel[:7] + ["E5:1 C#5:1 A4:2"]
    play_lines(hn, 12 * M, horn_mel + horn_mel2, vel=96, gate=0.98)
    play_lines(tp, 20 * M, horn_mel2, vel=84, gate=0.95)
    hn.expr(0, nb * M, 110, 110)
    # build: rising strings line (bars 28-35)
    rise = "D4:2 E4:2 F4:2 G4:2 A4:2 Bb4:2 C5:2 C#5:2 D5:2 E5:2 F5:2 G5:2 A5:2 Bb5:2 C#6:4"
    hi.mel(28 * M, rise, vel=80, gate=1.0)
    hi.expr(28 * M, 36 * M, 60, 120)
    # full section: spiccato 16ths + trumpets with the Afterbloom theme in minor (bars 36-47)
    spiccato16(hi, section(prog, 36, 52), vel=66, center=69)
    theme_min = ["A4:1 F5:1.5 E5:.5 D5:1", "C5:.5 D5:.5 Bb4:2 A4:1", "C5:1 A5:1.5 G5:.5 F5:1",
                 "E5:2 C#5:1 r:1"]
    play_lines(tp, 36 * M, theme_min * 3, vel=94, gate=0.95, transpose=0)
    play_lines(hn, 36 * M, theme_min * 3, vel=88, transpose=-12)
    pad(choir, section(prog, 36, 52), vel=70, center=62, n=3)
    hn.mel(48 * M, "D4:4 E4:4 F4:4 E4:4", vel=92)
    tp.mel(48 * M, "Bb4:4 C#5:4 D5:4 E5:4", vel=86)
    return s.render(nb * M * 60 / 144, loop=True, rt60=2.0, rev_size=1.2, bus=action_bus)


def dash_end():
    s = Song(144, seed=82)
    br = s.track("brass", "brass", vol=0.8, rev=0.4)
    hn = s.track("horns", "horns", vol=0.8, rev=0.45)
    strs = s.track("str", "strings", vol=0.8, rev=0.5, width=1.4)
    hit = s.track("hit", "orchhit", vol=0.5, rev=0.4)
    ti = s.track("timp", "timpani", vol=0.9, rev=0.4)
    kit = s.track("kit", "orch", vol=1.0, rev=0.4)
    tk = s.track("taiko", "taiko", vol=1.0, rev=0.4)
    cb = s.track("cb", "contrabass", vol=0.7, rev=0.4)
    # one-beat timpani roll into the hit on beat 1
    for i in range(8):
        ti.n(i * 0.125, 0.15, "A1", 60 + i * 7)
    H = 1.0
    chord = [midi(k) for k in ("D3", "A3", "D4", "F#4", "A4", "D5")]
    br.chord(H, 3.5, chord[:5], 120)
    hn.chord(H, 6.0, [midi(k) for k in ("D3", "F#3", "A3", "D4")], 115)
    strs.chord(H, 9.0, [midi(k) for k in ("D2", "D3", "A3", "D4", "F#4", "A4", "D5", "F#5")], 120)
    strs.expr(H, H + 2, 127, 110)
    strs.expr(H + 2, H + 10, 110, 0)
    hn.expr(H + 1, H + 6, 127, 20)
    hit.chord(H, 1.0, [midi("D4"), midi("F#4"), midi("A4")], 120)
    ti.n(H, 2, "D2", 127)
    kit.n(H, 2, O_BD, 127)
    kit.n(H, 2, O_CYM1, 120)
    kit.n(H, 2, O_CYM2, 110)
    tk.n(H, 2, "D2", 127)
    tk.n(H, 2, "A1", 120)
    cb.n(H, 8, "D1", 120)
    cb.expr(H + 2, H + 10, 110, 0)
    return s.render(6.2, tail=1.5, rt60=3.2, rev_size=1.6)


# ============================================================================================ COMBAT
def combat_loop():
    M = 4
    bpm = 112
    s = Song(bpm, seed=91)
    P1 = "Cm | Cm | Ab | Bb"
    P2 = "Cm | Cm | Fm | G"
    BR = "Ab | Ab | Fm | G"
    prog = concat_prog(P1, P2, P1, P2, P1, P2, BR, BR, P1, P2, "Ab | G")
    nb = 42
    low = s.track("low", "strings", vol=0.85, rev=0.2)
    cello = s.track("cello", "cello", vol=0.6, pan=0.25, rev=0.25)
    trem = s.track("trem", "tremstr", vol=0.45, pan=-0.2, rev=0.4, width=1.4)
    hn = s.track("horns", "horns", vol=0.7, pan=-0.25, rev=0.4)
    tb = s.track("tbn", "trombone", vol=0.55, pan=0.2, rev=0.35)
    pz = s.track("pizz", "pizz", vol=0.6, pan=0.3, rev=0.3)
    tk = s.track("taiko", "taiko", vol=0.85, rev=0.25, hum_t=0.004)
    kit = s.track("kit", "standard", vol=0.5, pan=0.1, rev=0.2, hum_t=0.004)
    okit = s.track("okit", "orch", vol=0.7, rev=0.3, hum_t=0.004)
    ti = s.track("timp", "timpani", vol=0.7, rev=0.3, hum_t=0.004)
    pno = s.track("piano", "piano", vol=0.5, rev=0.3)
    drone = s.track("drone", "contrabass", vol=0.45, rev=0.4)
    main = section(prog, 0, 24) + section(prog, 32, 42)
    ostinato(low, main, [0, 0, 12, 0, 7, 0, 12, 7], vel=84, low=midi("C2"), high=midi("B2"))
    ostinato(cello, section(prog, 8, 24) + section(prog, 32, 42), [12, 12, 19, 12, 15, 12, 19, 15], vel=70,
             low=midi("C2"), high=midi("B2"), gate=0.5)
    pad(trem, section(prog, 8, 24) + section(prog, 32, 42), vel=62, center=72, n=3)
    swells(trem, section(prog, 8, 24) + section(prog, 32, 42), 60, 100, "rise")
    # horn motif: the theme's rising sixth turned anxious
    motif = ["G4:1 Eb5:1.5 D5:.5 C5:1", "Bb4:.5 C5:.5 G4:3", "G4:1 Eb5:1.5 D5:.5 C5:1", "D5:2 B4:2"]
    play_lines(hn, 16 * M, motif * 2, vel=92)
    play_lines(hn, 32 * M, motif * 2, vel=96)
    play_lines(tb, 32 * M, ["C4:4", "Eb4:4", "C4:4", "B3:4"] * 2, vel=84)
    tb.mel(40 * M, "Ab3:4 G3:4", vel=90)
    hn.mel(40 * M, "C5:4 B4:4", vel=96)
    # breakdown (24-31): pizz + piano low hits + timpani + drone
    ostinato(pz, section(prog, 24, 32), [0, 12, 7, 12], vel=74, low=midi("C3"), high=midi("B3"), step=0.5)
    bass_line(drone, section(prog, 24, 32), vel=70, low=midi("C2"), high=midi("B2"))
    for bar in range(24, 32):
        b = bar * M
        sy = mus.prog_at(prog, b)
        r = bass_note(sy, midi("C1"), midi("B1"))
        pno.chord(b, 2, [r, r + 12], 80)
        pno.chord(b + 2.5, 1, [r, r + 12], 64)
        ti.n(b, 1, r + 12, 85)
        ti.n(b + 2.5, 1, r + 12, 70)
    # percussion
    for bar in range(nb):
        b = bar * M
        if 24 <= bar < 32:
            for o in (1, 3):
                kit.n(b + o, 0.3, 37, 70)
            continue
        groove = [(0, 115), (1.5, 85), (2, 100), (2.75, 70), (3.5, 85)]
        for o, v in groove:
            tk.n(b + o, 0.4, midi("C2"), v)
        kit.n(b + 1, 0.3, 38, 70 if bar < 8 else 88)
        kit.n(b + 3, 0.3, 38, 74 if bar < 8 else 92)
        if bar >= 8:
            for i in range(8):
                kit.n(b + i * 0.5, 0.2, 42, 50 + (14 if i % 2 == 0 else 0))
        if bar % 4 == 0:
            okit.n(b, 1, O_BD, 105)
            if bar % 8 == 0 and bar >= 8:
                okit.n(b, 1, O_CYM1, 80)
        if bar % 4 == 3:
            for i in range(6):
                kit.n(b + 2.5 + i * 0.25, 0.2, 48 - i, 76 + i * 6)
    return s.render(nb * M * 60 / bpm, loop=True, rt60=1.8, rev_size=1.0, bus=action_bus)


# ============================================================================================ BOSS
def boss_loop():
    M = 4
    bpm = 128
    s = Song(bpm, seed=101)
    A = "Dm | Eb | Dm | C"
    B = "Bb | Eb | Dm | A"
    prog = concat_prog(A, A, A, B, A, B, A, B, A, B, A, "Bb | A")
    nb = 46
    low = s.track("low", "strings", vol=0.9, rev=0.2)
    cb = s.track("cb", "contrabass", vol=0.7, rev=0.25)
    hi = s.track("hi", "strings", vol=0.55, pan=0.25, rev=0.3)
    trem = s.track("trem", "tremstr", vol=0.5, pan=-0.2, rev=0.4, width=1.4)
    br = s.track("brass", "brass", vol=0.75, rev=0.3)
    tb = s.track("tbn", "trombone", vol=0.7, pan=-0.25, rev=0.3)
    tu = s.track("tuba", "tuba", vol=0.6, pan=0.0, rev=0.25)
    hn = s.track("horns", "horns", vol=0.9, pan=-0.2, rev=0.35)
    tp = s.track("tpt", "trumpet", vol=0.6, pan=0.3, rev=0.35)
    choir = s.track("choir", "choir", vol=0.55, rev=0.5, width=1.5)
    hit = s.track("hit", "orchhit", vol=0.35, rev=0.35)
    tk = s.track("taiko", "taiko", vol=1.0, rev=0.25, hum_t=0.003)
    tk2 = s.track("cbd", "concertbd", vol=0.9, rev=0.3, hum_t=0.003)
    okit = s.track("okit", "orch", vol=0.9, rev=0.3, hum_t=0.003)
    sn = s.track("snare", "standard", vol=0.55, rev=0.2, hum_t=0.003)
    ti = s.track("timp", "timpani", vol=0.85, rev=0.3, hum_t=0.003)
    pno = s.track("piano", "piano", vol=0.55, rev=0.25)
    ostinato(low, prog, [0, 0, 1, 0, 0, 12, 0, 1], vel=92, low=midi("D2"), high=midi("C#3"),
             acc=[14, 0, 6, 0, 10, 4, 0, 6])
    bass_line(cb, prog, vel=90, low=midi("D1"), high=midi("C#2") + 12, gate=0.95)
    bass_line(tu, section(prog, 8, 46), vel=80, low=midi("D1"), high=midi("C#2") + 12, gate=0.9)
    stab = section(prog, 0, 8) + section(prog, 24, 32) + section(prog, 40, 46)
    comp_hits(br, stab, [(0, 0.4), (0.75, 0.4), (2.5, 1.0)], center=55, vel=105, n=4, vel_acc=[12, 0, 6])
    comp_hits(tb, stab, [(0, 0.4), (0.75, 0.4), (2.5, 1.0)], center=45, vel=100, n=3)
    comp_hits(hit, section(prog, 0, 8) + section(prog, 40, 46), [(0, 0.3)], center=60, vel=100, n=3)
    pad(choir, section(prog, 8, 46), vel=78, center=60, n=4)
    swells(choir, section(prog, 8, 46), 70, 115, "rise")
    # boss melody (horns, then trumpets)
    mel = ["D4:1.5 A4:.5 A4:2", "Bb4:1 A4:1 G4:1 Bb4:1", "A4:1.5 F4:.5 D4:2", "E4:1 F4:1 G4:1 E4:1",
           "D4:1.5 A4:.5 D5:2", "Eb5:1 D5:1 Bb4:1 G4:1", "A4:1.5 F4:.5 D4:1 F4:1", "E4:2 C#4:2"]
    play_lines(hn, 16 * M, mel, vel=100)
    play_lines(hn, 24 * M, mel, vel=104)
    play_lines(tp, 24 * M, mel, vel=96, octave=1)
    play_lines(tp, 40 * M, mel[:4] + ["D5:4", "C#5:4"][:2], vel=100, octave=0)
    spiccato16(hi, section(prog, 24, 32) + section(prog, 40, 46), vel=72, center=69)
    pad(trem, section(prog, 32, 40), vel=80, center=74, n=3)
    trem.expr(32 * M, 40 * M, 50, 120)
    # breakdown 32-39: piano low octaves + timpani
    for bar in range(32, 40):
        b = bar * M
        r = bass_note(mus.prog_at(prog, b), midi("D1"), midi("C#2"))
        for o in (0, 0.75, 1.5):
            pno.chord(b + o, 0.5, [r, r + 12], 92)
        ti.n(b, 1, r + 12, 100)
        ti.n(b + 2, 1, r + 12, 80)
    for bar in range(nb):
        b = bar * M
        bd_pat = [(0, 125), (0.75, 95), (1.5, 110), (2, 120), (2.5, 90), (3, 115), (3.5, 100), (3.75, 90)]
        if 32 <= bar < 40:
            bd_pat = [(0, 110), (2, 95)]
        for o, v in bd_pat:
            tk.n(b + o, 0.4, midi("A1"), v)
        tk2.n(b, 1, midi("D2"), 120)
        if bar % 2 == 1 or bar >= 40:
            tk2.n(b + 2, 1, midi("D2"), 105)
        if not 32 <= bar < 40:
            okit.n(b + 1, 0.3, O_SD, 100)
            okit.n(b + 3, 0.3, O_SD, 108)
        if bar % 4 == 0:
            okit.n(b, 1, O_CYM1, 100)
            ti.n(b, 1, midi("D2"), 118)
        if bar % 4 == 3 and not 32 <= bar < 40:
            for i in range(8):
                sn.n(b + 2 + i * 0.25, 0.2, 50 - i, 80 + i * 5)
    return s.render(nb * M * 60 / bpm, loop=True, rt60=2.2, rev_size=1.3, bus=action_bus)


# ============================================================================================ BLOOM
def sting_bloom():
    s = Song(60, seed=111)
    low = s.track("low", "slowstr", vol=0.9, rev=0.5, width=1.3)
    cb = s.track("cb", "contrabass", vol=0.7, rev=0.4)
    choir = s.track("choir", "choir", vol=0.7, rev=0.6, width=1.5)
    glass = s.track("glass", "bowedglass", vol=0.5, rev=0.7, width=1.6)
    rc = s.track("rc", "revcym", vol=0.7, rev=0.4)
    ti = s.track("timp", "timpani", vol=0.9, rev=0.4)
    br = s.track("brass", "brass", vol=0.8, rev=0.5)
    kit = s.track("kit", "orch", vol=1.0, rev=0.5)
    tk = s.track("taiko", "taiko", vol=0.9, rev=0.5)
    low.chord(0, 5.0, [midi(k) for k in ("D2", "A2", "D3", "Eb3")], 100)
    low.expr(0, 5.0, 15, 127, curve=1.8)
    cb.n(0, 7.5, "D1", 110)
    cb.expr(0, 5.0, 20, 127, curve=1.5)
    cb.expr(5.2, 7.5, 127, 0)
    choir.chord(1.0, 4.0, [midi(k) for k in ("D4", "Eb4", "A4", "D5")], 95)
    choir.expr(1.0, 5.0, 10, 127, curve=1.5)
    glass.chord(0.5, 7.0, [midi(k) for k in ("A5", "Bb5", "E6")], 80)
    glass.expr(0, 5.0, 30, 127)
    glass.expr(5.0, 7.0, 127, 40)
    for b in (4.0, 4.05):
        rc.n(b, 2.5, "C4", 120)
    for i in range(20):
        ti.n(2.5 + i * 0.125, 0.15, "D2", 40 + i * 3)
    H = 5.0
    br.chord(H, 1.2, [midi(k) for k in ("D2", "A2", "D3", "Eb3", "A3")], 125)
    ti.n(H, 2, "D2", 127)
    kit.n(H, 2, O_BD, 127)
    kit.n(H, 2, O_CYM1, 120)
    tk.n(H, 2, "D2", 127)
    x = s.render(7.0, tail=1.5, rt60=3.5, rev_size=1.8)
    return x
