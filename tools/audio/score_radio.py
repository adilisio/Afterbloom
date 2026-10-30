"""Six instrumental 1950s-60s 'records' for Larkhaven radio. Clean, full-range (the game adds the radio colour)."""
import numpy as np
import afx
import mus
from mus import Song, midi, parse_prog, voicing, bass_note, arp, pad
from score_common import *


def record_bus(width=0.75, drive=0.25):
    def f(x):
        x = afx.hp(x, 35)
        x = afx.stereo_width(x, width)
        pk = np.max(np.abs(x)) + 1e-9
        x = afx.softclip(x / pk * (1 + drive), 1 + drive) * pk  # gentle tape-ish saturation
        x = afx.shelf(x, 9000, -1.5, "high")
        x = afx.shelf(x, 150, -2.0, "low")
        return x
    return f


def vibrato(tr, b0, b1, depth=0.2, rate_hz=5.5, delay=0.3):
    """Pitch-bend vibrato for a monophonic lead (depth in semitones), starting after `delay` beats."""
    s = tr.song
    t0, t1 = s.sec(b0 + delay), s.sec(b1)
    if t1 <= t0:
        return
    n = int((t1 - t0) * 40)
    for i in range(n + 1):
        t = t0 + (t1 - t0) * i / max(n, 1)
        ramp = min(1.0, (t - t0) / 0.4)
        v = depth * ramp * np.sin(2 * np.pi * rate_hz * (t - t0))
        tr.ctl.append((t, "bend", float(np.clip(v / tr.bend_range, -1, 1)), 0))
    tr.ctl.append((t1 + 0.001, "bend", 0.0, 0))


def lead_expression(tr, vib_depth=0.18, rate=5.2, min_beats=1.0, swell=True):
    """Add vibrato to long notes and a small swell, based on the notes already written."""
    s = tr.song
    # convert note seconds back to beats approximately via bpm (no tempo maps in the records)
    spb = 60.0 / s.bpm
    for (t0, t1, k, v) in sorted(tr.notes):
        if (t1 - t0) / spb >= min_beats:
            vibrato(tr, t0 / spb, t1 / spb, vib_depth, rate, delay=0.35)


def brush_swing(dr, bars, start=0, meter=4, vel=1.0, rng=None, ride=True, fills=True):
    for bar in range(bars):
        b = start + bar * meter
        for beat in range(meter):
            dr.n(b + beat, 0.9, 40, int(66 * vel))  # swirl
        dr.n(b + 1, 0.3, 38, int(64 * vel))
        dr.n(b + 3, 0.3, 38, int(70 * vel))
        dr.n(b + 1, 0.3, 44, int(55 * vel))
        dr.n(b + 3, 0.3, 44, int(55 * vel))
        if ride:
            for o in (0, 1, 1.5, 2, 3, 3.5):
                dr.n(b + o, 0.3, 51, int((60 if o % 1 else 72) * vel))
        if rng is not None and rng.random() < 0.3:
            dr.n(b + rng.choice([1.5, 2.5, 3.5]), 0.3, 38, int(50 * vel))
        if fills and bar % 8 == 7:
            dr.n(b + 3.5, 0.3, 39, int(78 * vel))


# ============================================================================================ 1
def sunday_kind_of_gentle():
    """The Halcyon Strings & Lou Marten - lounge swing, vibraphone lead, walking bass, brushes."""
    M = 4
    s = Song(120, swing=0.64, seed=201)
    A1 = "Bbmaj7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 | Bbmaj7 Bb7 | Ebmaj7 Ebm6 | Dm7 G7 | Cm7 F7"
    A2 = "Bbmaj7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 | Bbmaj7 Bb7 | Ebmaj7 Ebm6 | Cm7 F7 | Bb6"
    B = "D7 | D7 | G7 | G7 | C7 | C7 | Cm7 | F7"
    intro = "Bb6 G7 | Cm7 F7 | Bb6 G7 | Cm7 F7"
    tag = "Cm7 F7 | Dm7 G7 | Cm7 F7 | Bbmaj7 | Bbmaj7"
    prog = concat_prog(intro, A1, A2, B, A2, A1, A2, B, A2, tag)
    nb = 73
    melA = ["F5:.5 D5:.5 F5:1 G5:1 F5:1", "Eb5:1.5 C5:.5 r:2", "D5:.5 F5:.5 A5:1 B5:1 A5:1", "G5:3 r:1",
            "F5:.5 D5:.5 F5:1 Ab5:1 G5:1", "G5:1.5 Eb5:.5 Gb5:1 Eb5:1", "D5:1 F5:.5 D5:.5 B4:1 D5:1",
            "C5:2 r:2"]
    melA2 = melA[:6] + ["Eb5:1 C5:.5 Eb5:.5 A4:1 C5:1", "Bb4:3 r:1"]
    melB = ["F#5:1.5 E5:.5 D5:1 A4:1", "C5:1.5 D5:.5 r:2", "B4:1.5 D5:.5 F5:1 G5:1", "F5:3 r:1",
            "E5:1.5 D5:.5 C5:1 G4:1", "Bb4:2 C5:1 E5:1", "G5:1.5 F5:.5 Eb5:1 C5:1", "A4:2 C5:1 Eb5:1"]
    vib = s.track("vibes", "vibes", vol=0.9, pan=0.2, rev=0.25, hum_t=0.01)
    pno = s.track("piano", "piano", vol=0.65, pan=-0.3, rev=0.2)
    gtr = s.track("gtr", "jazzgtr", vol=0.45, pan=-0.5, rev=0.15)
    bass = s.track("bass", "abass", vol=0.72, pan=0.05, rev=0.06)
    strs = s.track("strings", "slowstr", vol=0.5, pan=0.3, rev=0.35, width=1.2)
    vln = s.track("vln", "strings", vol=0.45, pan=0.35, rev=0.35)
    dr = s.track("drums", "brush", vol=1.6, rev=0.1, hum_t=0.006)
    rng = np.random.default_rng(3)
    # piano intro: little arpeggiated pickup feel
    arp(pno, section(prog, 0, 4), [0, 2, 3, 4, 5, 4, 3, 2], vel=60, center=64, n=4, step=0.5, gate=1.2)
    mus.comp_charleston(pno, section(prog, 4, 72), rng, vel=52, center=60, n=4)
    comp_hits(gtr, section(prog, 4, 76), [(0, 0.5), (1, 0.5), (2, 0.5), (3, 0.5)], center=55, vel=48, n=4,
              vel_acc=[4, -4, 2, -4])
    mus.walking_bass(bass, prog, rng, vel=84, low=midi("E1"), high=midi("C3"))
    # head 1 (bars 4-35): vibes
    play_lines(vib, 4 * M, melA + melA2 + melB + melA2, vel=82)
    # strings pad on A sections, countermelody whole notes on B
    for b0 in (4, 12, 28):
        pad(strs, section(prog, b0, b0 + 8), vel=56, center=66, n=3)
    swells(strs, section(prog, 4, 36), 50, 85)
    vln.mel(20 * M, "A5:4 A5:4 B5:4 B5:4 Bb5:4 G5:4 G5:4 A5:4", vel=66, gate=1.0)
    # piano solo (bars 36-51) over A1 A2
    mus.improvise(pno, section(prog, 36, 52), rng, 36 * M, 16, low=midi("F4"), high=midi("F6"), density=0.8,
                  vel=74, scale_key=10, scale="major")
    # vibes back for B and A2 (52-67), strings return
    play_lines(vib, 52 * M, melB + melA2, vel=82)
    pad(strs, section(prog, 52, 73), vel=58, center=66, n=3)
    swells(strs, section(prog, 52, 73), 50, 90)
    vln.mel(52 * M, "A5:4 A5:4 B5:4 B5:4 Bb5:4 G5:4 G5:4 A5:4", vel=68, gate=1.0)
    # tag (68-72)
    play_lines(vib, 68 * M, ["F5:.5 D5:.5 F5:1 G5:1 F5:1", "F5:1.5 D5:.5 r:2", "D5:1 C5:.5 Bb4:.5 C5:1 D5:1",
                             "Bb4:1 F5:1 D6:2"], vel=80)
    vib.chord(72 * M, 4, [midi(k) for k in ("D5", "F5", "A5", "C6")], 70, strum=0.08)
    pno.notes = [n for n in pno.notes if n[0] < s.sec(72 * M)]
    pno.chord(72 * M, 4, [midi(k) for k in ("Bb2", "F3", "A3", "D4")], 58, strum=0.03)
    gtr.notes = [n for n in gtr.notes if n[0] < s.sec(72 * M)]
    gtr.chord(72 * M, 4, [midi(k) for k in ("Bb3", "D4", "F4", "A4", "C5")], 56, strum=0.06)
    bass.notes = [n for n in bass.notes if n[0] < s.sec(72 * M)]
    bass.n(72 * M, 4, "Bb1", 86)
    brush_swing(dr, 4, 0, vel=0.7, ride=False, fills=False)
    brush_swing(dr, 68, 4 * M, rng=rng)
    dr.n(72 * M, 3, 49, 70)
    return s.render(73 * M * 60 / 120, tail=4.0, rt60=1.7, rev_size=0.8, bus=record_bus(0.75))


# ============================================================================================ 2
def moonlight_on_gull_lane():
    """Patsy Vale Quartet - slow 12/8 doo-wop ballad, tenor sax lead, piano triplets."""
    M = 12  # eighth-note beats
    s = Song(186, meter=12, seed=202)
    intro = "Eb Cm | Ab Bb7"
    A = "Eb Cm | Ab Bb7 | Eb Cm | Ab Bb7 | Eb Eb7 | Ab Abm | Eb Bb7 | Eb Bb7"
    Aend = "Eb Cm | Ab Bb7 | Eb Cm | Ab Bb7 | Eb Eb7 | Ab Abm | Eb Bb7 | Eb"
    B = "Ab | Ab | Eb | Eb | F7 | F7 | Bb7 | Bb7sus4 Bb7"
    outro = "Ab Abm | Eb"
    prog = concat_prog(intro, A, A, B, Aend, outro, meter=12)
    nb = 36
    melA = ["G4:3 Bb4:2 G4:1 C5:4 Bb4:2", "Ab4:3 C5:2 Eb5:1 D5:4 r:2", "G4:3 Bb4:2 G4:1 Eb5:4 C5:2",
            "C5:3 Ab4:2 F4:1 Bb4:6", "Bb4:2 Eb5:1 G5:3 F5:2 Eb5:1 Db5:3", "C5:6 Cb5:6",
            "Bb4:3 G4:2 Eb4:1 F4:3 Ab4:3", "G4:6 r:3 Bb4:3"]
    melA_end = melA[:7] + ["Eb4:9 r:3"]
    melB = ["Eb5:3 C5:2 Ab4:1 C5:6", "Eb5:3 F5:2 Eb5:1 C5:6", "Bb4:3 G4:2 Eb4:1 G4:6",
            "Bb4:3 C5:2 Bb4:1 G4:3 Bb4:3", "A4:3 C5:2 F5:1 Eb5:6", "C5:3 A4:2 F4:1 A4:6",
            "D5:3 F5:2 Ab5:1 G5:4 F5:2", "Eb5:6 D5:3 r:3"]
    sax = s.track("sax", "tenorsax", vol=0.95, pan=0.15, rev=0.35, hum_t=0.014, bend_range=2)
    pno = s.track("piano", "piano", vol=0.6, pan=-0.3, rev=0.25)
    bass = s.track("bass", "abass", vol=0.7, pan=0.0, rev=0.08)
    oohs = s.track("oohs", "oohs", vol=0.55, pan=-0.1, rev=0.45, width=1.4)
    gtr = s.track("gtr", "jazzgtr", vol=0.4, pan=0.4, rev=0.25)
    dr = s.track("drums", "jazz", vol=0.6, rev=0.15, hum_t=0.006)
    # piano triplets: right-hand chord on every eighth, accent each dotted beat
    comp_hits(pno, prog, [(i, 0.9) for i in range(12)], center=63, vel=46, n=4,
              vel_acc=[10, -2, 0, 6, -2, 0, 8, -2, 0, 6, -2, 0])
    for st, du, sy in prog:
        r = bass_note(sy, midi("Eb2"), midi("D3"))
        pno.n(st, min(du, 6), r, 50)
    # bass: root (dotted quarter), fifth, approach per half-bar chord
    prev = None
    for st, du, sy in prog:
        r = bass_note(sy, midi("E1"), midi("D#2"), prev)
        prev = r
        for h in range(int(round(du / 6))):
            b = st + h * 6
            bass.n(b, 3, r, 86, gate=0.9)
            bass.n(b + 3, 2, r + 7 if r + 7 < midi("G3") else r - 5, 76, gate=0.9)
            bass.n(b + 5, 1, r + 12 if h == 0 else r + 9, 68, gate=0.8)
    # doo-wop oohs
    pad(oohs, prog, vel=60, center=64, n=3)
    swells(oohs, prog, 55, 95)
    # guitar: gentle arpeggio in triplets on bridge only
    arp(gtr, section(prog, 18, 26, 12), [0, 2, 3, 4, 3, 2], vel=50, center=60, n=4, step=1, gate=1.5)
    # sax
    sax.mel(2 * M - 3, "Bb3:3", vel=70)
    play_lines(sax, 2 * M, melA + melA + melB + melA_end, meter=12, vel=84, gate=0.97)
    lead_expression(sax, 0.22, 5.0, min_beats=3)
    for bar in range(2, 34):
        b = bar * M
        sax.expr(b, b + 6, 85, 105)
        sax.expr(b + 6, b + 12, 105, 88)
    # outro: sax final sigh
    sax.mel(34 * M, "C5:3 Bb4:3 Cb5:6 Bb4:12", vel=72)
    # drums: soft ride triplets, backbeat on 2 & 4 (eighths 3 and 9), kick 1 & 3
    for bar in range(nb):
        b = bar * M
        if bar >= 34:
            dr.n(b, 1, 51, 50)
            continue
        for i in range(12):
            dr.n(b + i, 0.5, 51, 52 + (12 if i % 3 == 0 else 0))
        dr.n(b + 3, 0.5, 38, 70)
        dr.n(b + 9, 0.5, 38, 76)
        dr.n(b, 0.5, 36, 70)
        dr.n(b + 6, 0.5, 36, 62)
        dr.n(b + 3, 0.5, 44, 50)
        dr.n(b + 9, 0.5, 44, 50)
    pno.chord(35 * M, 12, [midi(k) for k in ("Eb2", "Bb2", "G3", "Bb3", "D4", "G4")], 54, strum=0.25)
    oohs.chord(35 * M, 12, [midi(k) for k in ("G4", "Bb4", "D5")], 60)
    pno.notes = [n for n in pno.notes if n[0] < s.sec(35 * M) or n[1] - n[0] > 1]
    pedal_prog(pno, [(35 * M, 12, "Eb")])
    return s.render(s.sec(36 * M), tail=5.0, rt60=2.0, rev_size=0.9, bus=record_bus(0.7))


# ============================================================================================ 3
def rocket_ride_shuffle():
    """Benny Cole & the Satellites - upbeat rockabilly/surf, twangy guitar lead, slap bass."""
    M = 4
    s = Song(160, swing=0.6, seed=203)
    blues = "E7 | A7 | E7 | E7 | A7 | A7 | E7 | E7 | B7 | A7 | E7 | B7"
    bridge = "C#m | A | E | B7 | C#m | A | E | B7"
    prog = concat_prog("E7 | E7 | E7 | E7", blues, blues, blues, blues, bridge, blues, "E7 | E7 | E7 | E7")
    nb = 76
    head = ["B4:1 E5:.5 G5:.5 G#5:1 E5:1", "C#5:.5 E5:.5 A5:1 G5:1 E5:1", "B4:1 E5:.5 G5:.5 G#5:1 B5:1",
            "B5:.5 G#5:.5 E5:1 r:2", "E5:1 A5:.5 C5:.5 C#5:1 A4:1", "G5:.5 E5:.5 C#5:1 A4:2",
            "B4:1 E5:.5 G5:.5 G#5:1 E5:1", "G#5:.5 B5:.5 G#5:.5 E5:.5 D5:1 B4:1", "F#5:1.5 D#5:.5 B4:2",
            "E5:1.5 C#5:.5 A4:2", "E5:.5 G5:.5 G#5:.5 B5:.5 E6:2", "D#5:1 F#5:1 A5:1 B5:1"]
    head_end = head[:11] + ["E5:2 r:2"]
    gtr = s.track("gtr", "cleangtr", vol=0.85, pan=0.2, rev=0.35, delay=(0.12, 0.25, 0.35), bend_range=2,
                  hum_t=0.006)
    rg = s.track("rhythm", "steelgtr", vol=0.45, pan=-0.45, rev=0.15)
    bass = s.track("bass", "abass", vol=0.8, pan=0.0, rev=0.05, hum_t=0.004)
    slap = s.track("slap", "standard", vol=0.35, pan=0.0, rev=0.05, hum_t=0.004)
    sax = s.track("sax", "tenorsax", vol=0.8, pan=-0.2, rev=0.25)
    bari = s.track("bari", "barisax", vol=0.6, pan=-0.3, rev=0.25)
    pno = s.track("piano", "honky", vol=0.45, pan=-0.15, rev=0.2)
    dr = s.track("drums", "standard", vol=0.8, rev=0.12, hum_t=0.005)
    rng = np.random.default_rng(31)
    # boogie bass on everything (1-3-5-6-b7-6-5-3), slap click on the off-beats
    boogie = [0, 4, 7, 9, 10, 9, 7, 4]
    for st, du, sy in prog:
        _, root, _ = mus.chord_pcs(sy)
        r = bass_note(sy, midi("E1"), midi("D#2"))
        minor = "m" in sy and "maj" not in sy
        pat = [0, 3, 7, 10, 12, 10, 7, 3] if minor else boogie
        if st >= 72 * M:
            pat = [0, 0, 7, 7, 12, 12, 7, 7]
        for i in range(int(du * 2)):
            bass.n(st + i * 0.5, 0.5, r + pat[i % 8], 92 if i % 2 == 0 else 78, gate=0.7)
            if i % 2 == 1:
                slap.n(st + i * 0.5, 0.2, 37, 60)
    # rhythm guitar: off-beat chops
    comp_hits(rg, section(prog, 4, 76), [(0.5, 0.3), (1.5, 0.3), (2.5, 0.3), (3.5, 0.3)], center=60, vel=58,
              n=4, vel_acc=[0, 6, 0, 6])
    # intro riff on guitar (bars 0-3)
    gtr.mel(0, "E4:.5 G4:.5 G#4:.5 B4:.5 C#5:.5 B4:.5 G#4:.5 E4:.5 " * 2, vel=88)
    gtr.mel(2 * M, "E5:.5 E5:.5 D5:.5 B4:.5 G4:.5 G#4:.5 E4:1 r:2 B4:1 B4:1", vel=92)
    play_lines(gtr, 4 * M, head + head, vel=94, gate=0.9)
    # twangy bends into some long notes
    for (t0, t1, k, v) in list(gtr.notes):
        if t1 - t0 > 0.5 and rng.random() < 0.5:
            b0 = t0 * 160 / 60
            gtr.bend(b0 - 0.01, -1.0)
            gtr.bend_ramp(b0, b0 + 0.25, -1.0, 0.0, 6)
    # guitar solo (bars 28-39)
    mus.improvise(gtr, section(prog, 28, 40), rng, 28 * M, 12, low=midi("E4"), high=midi("E6"), density=0.85,
                  vel=92, scale_key=4, scale="blues", bend=True)
    # sax honk chorus (bars 40-51) - riffs with baritone underneath
    honk = ["B4:.5 B4:.5 r:.5 B4:.5 D5:.5 B4:.5 r:1", "E5:.5 E5:.5 r:.5 E5:.5 G5:.5 E5:.5 r:1"]
    for bar in range(40, 52):
        sy = mus.prog_at(prog, bar * M)
        tr = {"E7": 0, "A7": -7, "B7": -5}[sy]
        sax.mel(bar * M, honk[bar % 2], vel=96, transpose=tr)
        bari.mel(bar * M, "E3:1.5 E3:.5 G3:1 G#3:1", vel=90, transpose=tr + (12 if tr == -7 else 0))
    # surf bridge (52-59): tremolo-picked guitar
    surf = ["G#5", "A5", "B5", "F#5", "E5", "C#5", "B4", "D#5"]
    for i, k in enumerate(surf):
        for j in range(16):
            gtr.n((52 + i) * M + j * 0.25, 0.25, k, 80 + (8 if j % 4 == 0 else 0), gate=0.8)
    pad(sax, section(prog, 52, 60), vel=64, center=62, n=1)
    # head out (60-71) and outro (72-75)
    play_lines(gtr, 60 * M, head_end, vel=96, gate=0.9)
    gtr.mel(72 * M, "E5:.5 D5:.5 B4:.5 G#4:.5 G4:.5 E4:.5 r:1 E5:.5 D5:.5 B4:.5 G#4:.5 G4:.5 E4:.5 r:1", vel=94)
    gtr.chord(74 * M, 0.5, [midi(k) for k in ("E3", "G#3", "D4", "F#4", "B4")], 100, strum=0.02)
    gtr.chord(74 * M + 1.5, 6, [midi(k) for k in ("E3", "G#3", "D4", "F#4", "B4")], 104, strum=0.04)
    gtr.bend(74 * M + 2.5, 0)
    gtr.bend_ramp(74 * M + 2.5, 74 * M + 5.5, 0, -0.6, 24)
    gtr.bend(78 * M, 0)
    # drums: kick 1&3, snare 2&4 with train-beat ghosts, swung hats; cut on the last bars
    for bar in range(nb):
        b = bar * M
        if bar < 2:
            dr.n(b + 3, 0.2, 38, 60 + bar * 20)
            continue
        if bar >= 74:
            if bar == 74:
                dr.n(b, 0.3, 36, 110)
                dr.n(b, 0.3, 49, 100)
                dr.n(b + 1.5, 0.3, 36, 110)
                dr.n(b + 1.5, 0.3, 49, 110)
            continue
        for o in (0, 2):
            dr.n(b + o, 0.3, 36, 100)
        for o in (1, 3):
            dr.n(b + o, 0.3, 38, 100)
        for i in range(8):
            if i % 2 == 1:
                dr.n(b + i * 0.5, 0.2, 38, 38 + rng.integers(0, 10))
            dr.n(b + i * 0.5, 0.2, 42, 70 if i % 2 == 0 else 56)
        if bar % 12 == 3 and bar > 3:
            dr.n(b, 0.5, 49, 90)
        if bar % 12 == 2:
            for i in range(4):
                dr.n(b + 2 + i * 0.5, 0.25, [50, 48, 45, 41][i], 95)
    bass.notes = [n for n in bass.notes if n[0] < s.sec(74 * M)]
    slap.notes = [n for n in slap.notes if n[0] < s.sec(74 * M)]
    rg.notes = [n for n in rg.notes if n[0] < s.sec(74 * M)]
    bass.n(74 * M, 0.5, "E1", 100)
    bass.n(74 * M + 1.5, 4, "E1", 100)
    for bar in range(4, 74, 4):
        pno.chord(bar * M + 3.5, 0.4, voicing(mus.prog_at(prog, bar * M), 72, None, 3), 66)
    return s.render(s.sec(76 * M), tail=4.0, rt60=1.4, rev_size=0.7, bus=record_bus(0.8, 0.35))


# ============================================================================================ 4
def a_little_lantern():
    """Rosa Dean - 3/4 waltz, celesta/music-box melody with strings."""
    M = 3
    s = Song(96, meter=3, seed=204)
    A = "G | G | Em | Em | C | D7 | G | D7 | G | G7 | C | Cm | G/D | E7 | Am7 D7 | G"
    B = "Em | B7 | Em | E7 | Am | D7 | G | G | C | Cm | G | E7 | A7 | A7 | D7 | D7"
    intro = "G | Em | C | D7"
    prog = concat_prog(intro, A, B, A, "C | Cm | G | G", meter=3)
    nb = 56
    melA = ["D5:2 B4:1", "G5:2 D5:1", "E5:1 G5:1 B5:1", "G5:3", "E5:2 C5:1", "F#5:2 A5:1",
            "G5:1.5 F#5:.5 E5:1", "D5:3", "D5:2 B4:1", "F5:2 D5:1", "E5:1 G5:1 C6:1", "Eb5:2 G5:1",
            "D5:1.5 B4:.5 G4:1", "G#4:1 B4:1 D5:1", "A4:1 C5:.5 E5:.5 F#5:1", "G5:3"]
    melB = ["B5:2 G5:1", "F#5:2 D#5:1", "E5:1 G5:1 B5:1", "D6:2 B5:1", "C6:2 A5:1", "F#5:1 A5:1 C6:1",
            "B5:2 G5:1", "D5:3", "E5:2 G5:1", "Eb5:2 G5:1", "D5:1.5 E5:.5 D5:1", "B4:1 D5:1 G#5:1",
            "A5:2 E5:1", "C#5:2 E5:1", "F#5:1 E5:1 D5:1", "C5:2 A4:1"]
    cel = s.track("celesta", "celesta", vol=0.85, pan=0.1, rev=0.35)
    mb = s.track("musicbox", "musicbox", vol=0.4, pan=-0.2, rev=0.4)
    vln = s.track("violins", "strings", vol=0.6, pan=0.25, rev=0.4)
    strs = s.track("strings", "slowstr", vol=0.45, pan=-0.1, rev=0.45, width=1.3)
    harp = s.track("harp", "harp", vol=0.6, pan=-0.35, rev=0.35)
    pz = s.track("pizz", "pizz", vol=0.7, pan=0.1, rev=0.25)
    cb = s.track("bass", "contrabass", vol=0.5, rev=0.25)
    flute = s.track("flute", "flute", vol=0.5, pan=0.35, rev=0.4)
    # oom-pah-pah
    prev = None
    for st, du, sy in prog:
        if st >= 52 * M:
            break
        r = bass_note(sy, midi("E2"), midi("D#3"), prev)
        prev = r
        v = voicing(sy, 67, None, 3)
        bars = int(round(du / 3)) if du >= 3 else 0
        if du < 3:
            pz.n(st, 1, r, 74)
            harp.chord(st + 1, 0.5, v, 50)
            continue
        for k in range(bars):
            b = st + k * 3
            pz.n(b, 1, r if k % 2 == 0 else (r + 7 if r + 7 < midi("D#3") else r - 5), 76)
            cb.n(b, 1, r - 12, 60)
            harp.chord(b + 1, 0.8, v, 48)
            harp.chord(b + 2, 0.8, v, 44)
    # intro: music box alone
    mb.mel(0, "D6:2 B5:1 G6:2 D6:1 E6:1 G6:1 C6:1 A5:3", vel=70)
    play_lines(cel, 4 * M, melA, meter=3, vel=78)
    play_lines(mb, 4 * M, melA, meter=3, vel=52, octave=1)
    pad(strs, section(prog, 4, 52, 3), vel=55, center=62, n=3)
    swells(strs, section(prog, 4, 52, 3), 45, 85)
    # B: violins carry, celesta answers
    play_lines(vln, 20 * M, melB, meter=3, vel=80, transpose=-12, gate=1.0)
    for i in range(16):
        vln.expr((20 + i) * M, (20 + i) * M + 1.5, 75, 105)
        vln.expr((20 + i) * M + 1.5, (21 + i) * M, 105, 80)
    for i in range(0, 16, 2):
        b = (21 + i) * M
        v = voicing(mus.prog_at(prog, b), 82, None, 3)
        for j, (o, d) in enumerate(((1, 0.5), (1.5, 0.5), (2, 1))):
            cel.n(b + o, d, v[2 - j], 58)
    # last A: celesta + music box + flute descant
    play_lines(cel, 36 * M, melA, meter=3, vel=80)
    play_lines(mb, 36 * M, melA, meter=3, vel=56, octave=1)
    flute.mel(36 * M, "B5:6 G5:6 C6:6 B5:6 A5:6 G5:6 F#5:6 D5:6", vel=60)
    # ending: slows on a music-box wind-down
    cel.mel(52 * M, "E5:2 C5:1 Eb5:2 C5:1 D5:3 B4:3", vel=70)
    mb.mel(52 * M, "E6:2 C6:1 Eb6:2 C6:1 D6:3 G6:3", vel=50)
    strs.chord(52 * M, 12, [midi(k) for k in ("G3", "B3", "D4", "G4")], 55)
    strs.expr(52 * M, 56 * M, 80, 30)
    harp.chord(54 * M, 6, [midi(k) for k in ("G2", "D3", "G3", "B3", "D4", "G4", "B4")], 55, strum=0.12)
    pz.n(54 * M, 2, "G2", 70)
    return s.render(s.sec(56 * M), tail=4.0, rt60=2.2, bus=record_bus(0.8, 0.15))


# ============================================================================================ 5
def coffee_for_two():
    """Mel Archer Trio - piano jazz trio, walking bass, brushes."""
    M = 4
    s = Song(132, swing=0.64, seed=205)
    A1 = "Fmaj7 D7 | Gm7 C7 | Am7 D7 | Gm7 C7 | F7 | Bbmaj7 Bbm6 | Am7 D7 | Gm7 C7"
    A2 = "Fmaj7 D7 | Gm7 C7 | Am7 D7 | Gm7 C7 | F7 | Bbmaj7 Bbm6 | Gm7 C7 | F6"
    B = "Am7b5 D7 | Gm7 | Gm7 C7 | Fmaj7 | Bm7b5 E7 | Am7 D7 | G7 | Gm7 C7"
    intro = "Gm7 C7 | Am7 D7 | Gm7 C7 | F6 C7"
    tag = "Gm7 C7 | Am7 D7 | Gm7 C7 | Fmaj7"
    prog = concat_prog(intro, A1, A2, B, A2, A1, A2, B, A2, tag)
    nb = 76
    melA = ["A5:1 G5:.5 F5:.5 F#5:1 A5:1", "Bb5:1.5 G5:.5 E5:1 C5:1", "C6:1 B5:.5 A5:.5 F#5:1 D5:1",
            "F5:2 E5:1 r:1", "A5:.5 C6:.5 A5:.5 F5:.5 Eb5:1 C5:1", "D5:1.5 F5:.5 Db5:1 F5:1",
            "E5:1 C5:.5 A4:.5 F#5:1 C5:1", "Bb4:2 r:2"]
    melA2 = melA[:6] + ["D5:1 Bb4:.5 G4:.5 E5:1 C5:1", "F5:3 r:1"]
    melB = ["Eb5:1.5 C5:.5 F#5:1 A5:1", "G5:1 F5:.5 D5:.5 Bb4:2", "r:1 Bb4:.5 D5:.5 E5:1 G5:1", "A5:3 r:1",
            "D5:1.5 F5:.5 G#5:1 B5:1", "C6:1 A5:.5 E5:.5 F#5:1 D5:1", "B4:1 D5:1 F5:1 A5:1",
            "Bb5:1 G5:1 E5:1 C5:1"]
    rh = s.track("rh", "piano", vol=0.95, pan=0.05, rev=0.18, hum_t=0.009)
    lh = s.track("lh", "piano", vol=0.7, pan=-0.05, rev=0.18, hum_t=0.009)
    bass = s.track("bass", "abass", vol=0.75, pan=0.2, rev=0.06)
    dr = s.track("drums", "brush", vol=1.6, pan=-0.15, rev=0.1, hum_t=0.006)
    rng = np.random.default_rng(55)
    # intro: piano alone, gentle
    arp(rh, section(prog, 0, 4), [1, 2, 3, 4, 3, 2, 4, 3], vel=56, center=67, n=4, step=0.5, gate=1.1)
    mus.comp_charleston(lh, section(prog, 0, 76), rng, vel=56, center=55, n=3)
    mus.walking_bass(bass, section(prog, 4, 76), rng, vel=86, low=midi("E1"), high=midi("C3"), start=4 * M)
    play_lines(rh, 4 * M, melA + melA2 + melB + melA2, vel=80)
    # light octave doubling on the bridge for a lift
    play_lines(rh, 28 * M, melB, vel=56, octave=-1)
    # piano solo over A1 A2 B (36-59)
    mus.improvise(rh, section(prog, 36, 60), rng, 36 * M, 24, low=midi("F4"), high=midi("A6"), density=0.85,
                  vel=78, scale_key=5, scale="major")
    # head out: last A (60-67), then A2 again with octave melody (68-75 tag)
    play_lines(rh, 60 * M, melA2, vel=82)
    play_lines(rh, 60 * M, melA2, vel=58, octave=-1)
    rh.mel(68 * M, "D5:1 Bb4:.5 G4:.5 E5:1 C5:1 C5:1 A4:.5 C5:.5 F#5:1 A5:1 D5:1 Bb4:.5 G4:.5 E5:1 C5:1", vel=78)
    rh.chord(71 * M, 4, [midi(k) for k in ("E5", "A5", "C6", "F6")], 64, strum=0.06)
    lh.notes = [n for n in lh.notes if n[0] < s.sec(71 * M)]
    lh.chord(71 * M, 4, [midi(k) for k in ("F2", "C3", "E3", "A3")], 62)
    bass.notes = [n for n in bass.notes if n[0] < s.sec(71 * M)]
    bass.n(71 * M, 4, "F1", 88)
    pedal_prog(rh, [(71 * M, 4, "F")])
    brush_swing(dr, 67, 4 * M, rng=rng, vel=1.0)
    dr.n(71 * M, 3, 51, 60)
    return s.render(s.sec(72 * M), tail=4.0, rt60=1.4, rev_size=0.6, bus=record_bus(0.7))


# ============================================================================================ 6
def highway_seventeen():
    """Dusty Carlyle - country-western shuffle, harmonica / steel lead."""
    M = 4
    s = Song(112, swing=0.64, seed=206)
    verse = "G | G | C | G | G | G | D7 | D7 | G | G7 | C | C | G | D7 | G | G"
    chorus = "C | G | D7 | G | C | G | D7 | G"
    prog = concat_prog("G | C | D7 | G", verse, chorus, verse, chorus, "G | C | D7 | G")
    nb = 56
    melV = ["B4:1.5 A4:.5 G4:1 B4:1", "D5:2 B4:1 G4:1", "E5:1.5 D5:.5 C5:1 E5:1", "D5:3 r:1",
            "B4:1.5 A4:.5 G4:1 B4:1", "D5:1 E5:1 D5:1 B4:1", "A4:1.5 B4:.5 C5:1 A4:1", "F#4:3 r:1",
            "B4:1.5 A4:.5 G4:1 B4:1", "D5:1 F5:1 D5:1 B4:1", "C5:1.5 D5:.5 E5:1 G5:1", "E5:3 r:1",
            "D5:1.5 B4:.5 G4:1 B4:1", "A4:1 C5:1 B4:1 A4:1", "G4:3 r:1", "r:4"]
    melC = ["E5:1 E5:1 E5:1 D5:1", "D5:1 B4:1 G4:2", "A4:1 A4:1 C5:1 B4:1", "G4:3 r:1",
            "E5:1 G5:1 E5:1 D5:1", "D5:1 B4:1 D5:2", "C5:1 B4:1 A4:1 F#4:1", "G4:3 r:1"]
    harm = s.track("harmonica", "harmonica", vol=0.75, pan=-0.15, rev=0.25, bend_range=2)
    steel = s.track("steel", "hawaiian", vol=0.8, pan=0.25, rev=0.35, bend_range=2, delay=(0.18, 0.2, 0.2))
    rg = s.track("rhythm", "steelgtr", vol=0.6, pan=-0.4, rev=0.12)
    bass = s.track("bass", "abass", vol=0.78, rev=0.06)
    pno = s.track("piano", "honky", vol=0.45, pan=0.35, rev=0.15)
    dr = s.track("drums", "brush", vol=1.5, rev=0.1, hum_t=0.006)
    rng = np.random.default_rng(66)
    # boom-chick: bass root on 1, fifth on 3 (alternating); guitar strums on 2 & 4 with shuffle 8ths
    mus.bassline_roots(bass, prog, vel=88, pattern=((0, 1), (2, 1)), fifth_on=(2,), low=midi("E1"),
                       high=midi("D3"))
    comp_hits(rg, prog, [(1, 0.5), (1.5, 0.3), (3, 0.5), (3.5, 0.3)], center=60, vel=62, n=5, strum=0.012,
              vel_acc=[8, -10, 8, -10])
    comp_hits(pno, section(prog, 4, 52), [(1.5, 0.3), (3.5, 0.3)], center=70, vel=50, n=3)

    def steel_line(start, lines, vel=88, octave=0):
        play_lines(steel, start, lines, vel=vel, octave=octave, gate=1.0)

    def add_slides(tr, b0, b1, prob=0.5, amt=-2.0):
        for (t0, t1, k, v) in list(tr.notes):
            b = t0 * 112 / 60
            if b0 <= b < b1 and (t1 - t0) > 0.4 and rng.random() < prob:
                tr.bend(b - 0.02, amt)
                tr.bend_ramp(b, b + 0.35, amt, 0.0, 8, curve=0.6)

    # intro steel lick
    steel.mel(0, "D5:1 B4:.5 D5:.5 E5:1 G5:1 E5:1.5 D5:.5 C5:1 A4:1 F#4:1 A4:1 C5:1 D5:1 G4:4", vel=86)
    play_lines(harm, 4 * M, melV, vel=92)
    play_lines(steel, 20 * M, melC, vel=86)
    G_SCALE = [7, 9, 11, 0, 2, 4, 6]
    harm.notes += diatonic_below([n for n in steel.notes if s.sec(20 * M) <= n[0] < s.sec(28 * M)], G_SCALE)
    steel_line(28 * M, melV, vel=88)
    # harmonica fills in the gaps of the steel verse
    for bar in (31, 35, 39, 42, 43):
        harm.mel(bar * M + 2, "G5:.5 E5:.5 D5:1" if bar % 2 else "B4:.5 D5:.5 G5:1", vel=70)
    play_lines(steel, 44 * M, melC, vel=90)
    play_lines(harm, 44 * M, melC, vel=86, octave=0)
    steel.mel(52 * M, "D5:1 B4:.5 D5:.5 E5:1 G5:1 E5:1.5 D5:.5 C5:1 A4:1 B4:1 A4:1 F#4:1 A4:1", vel=84)
    steel.chord(55 * M, 4, [midi(k) for k in ("G4", "B4", "E5", "G5")], 84)
    harm.chord(55 * M, 3, [midi(k) for k in ("G4", "B4", "D5")], 70)
    add_slides(steel, 0, 60 * M, 0.55)
    lead_expression(steel, 0.12, 5.5, min_beats=1.5)
    lead_expression(harm, 0.15, 6.0, min_beats=2)
    # drums: brush train-beat shuffle
    for bar in range(nb):
        b = bar * M
        if bar == 55:
            dr.n(b, 2, 49, 70)
            dr.n(b, 1, 36, 70)
            continue
        for i in range(8):
            dr.n(b + i * 0.5, 0.3, 38, (62 if i in (2, 6) else 38) + rng.integers(0, 8))
        dr.n(b, 0.3, 36, 72)
        dr.n(b + 2, 0.3, 36, 66)
        for i in range(8):
            dr.n(b + i * 0.5, 0.2, 44 if i % 2 == 0 else 42, 46)
    bass.notes = [n for n in bass.notes if n[0] < s.sec(55 * M)]
    bass.n(55 * M, 3, "G1", 90)
    rg.notes = [n for n in rg.notes if n[0] < s.sec(55 * M)]
    rg.chord(55 * M, 4, [midi(k) for k in ("G2", "B2", "D3", "G3", "B3", "G4")], 80, strum=0.03)
    pno.chord(55 * M, 4, [midi(k) for k in ("G3", "B3", "D4", "E4")], 56)
    return s.render(s.sec(56 * M), tail=4.0, rt60=1.5, rev_size=0.7, bus=record_bus(0.8, 0.3))
