"""Shared musical material: the AFTERBLOOM main theme and small arrangement helpers."""
import numpy as np
import mus
from mus import midi, parse_prog, voicing, bass_note, chord_pcs

# ---- Main theme, written in D major, 4/4. Hopeful rising sixth (A4 -> F#5) answered by a gentle descent.
THEME_A_CH = "D | Bm7 | Gmaj7 | Asus4 A | D/F# | G | Em7 A7 | D"
THEME_A = [
    "A4:1 F#5:1.5 E5:.5 D5:1",
    "C#5:.5 D5:.5 B4:2 A4:1",
    "B4:1 G5:1.5 F#5:.5 E5:1",
    "D5:2 C#5:1 r:1",
    "A4:1 F#5:1.5 E5:.5 D5:1",
    "B4:.5 D5:.5 G5:1.5 F#5:.5 E5:1",
    "G5:1.5 F#5:.5 E5:1 C#5:1",
    "D5:3 r:1",
]
THEME_B_CH = "Gmaj7 | F#m7 | Em7 | A7sus4 A7 | Bm7 | Gmaj7 | Em7 A7 | D"
THEME_B = [
    "B5:2 A5:1 G5:1",
    "A5:1.5 F#5:.5 E5:1 C#5:1",
    "G5:1.5 F#5:.5 E5:1 D5:1",
    "E5:2 r:1 A4:1",
    "F#5:1.5 E5:.5 D5:1 B4:1",
    "E5:1 D5:.5 E5:.5 F#5:1 G5:1",
    "A5:1.5 G5:.5 E5:1 C#5:1",
    "D5:4",
]


def play_lines(tr, start_beat, lines, meter=4, vel=76, transpose=0, octave=0, gate=0.95, vel_curve=None):
    for i, ln in enumerate(lines):
        v = vel + (vel_curve[i % len(vel_curve)] if vel_curve else 0)
        tr.mel(start_beat + i * meter, ln, vel=v, transpose=transpose, octave=octave, gate=gate)


def comp_hits(tr, prog, hits, center=60, vel=60, n=4, strum=0.0, vel_acc=None, low=None, high=None):
    """hits: list of (offset_in_chord_beats, dur). Repeats each chord's hits relative to its start."""
    prev = None
    for st, du, sy in prog:
        v = voicing(sy, center, prev, n, low, high)
        prev = v
        for i, (o, d) in enumerate(hits):
            if o < du - 1e-6:
                acc = vel_acc[i % len(vel_acc)] if vel_acc else 0
                tr.chord(st + o, min(d, du - o), v, vel + acc, strum=strum)


def pedal_prog(tr, prog, lift=0.05):
    for st, du, sy in prog:
        tr.cc(st + 0.03, 64, 127)
        tr.cc(st + du - lift, 64, 0)


def swells(tr, prog, lo=55, hi=100, shape="arch"):
    """CC11 expression arch per chord (strings breathing)."""
    for st, du, sy in prog:
        if shape == "arch":
            tr.expr(st, st + du * 0.5, lo, hi)
            tr.expr(st + du * 0.5, st + du, hi, lo)
        else:
            tr.expr(st, st + du, lo, hi)


def bass_line(tr, prog, vel=70, low=midi("C2"), high=midi("D3"), pattern=((0, None),), gate=0.98):
    prev = None
    for st, du, sy in prog:
        r = bass_note(sy, low, high, prev)
        for o, d in pattern:
            if o < du:
                tr.n(st + o, (du - o) if d is None else min(d, du - o), r, vel, gate=gate)
        prev = r


def octave_bass(tr, prog, vel=70, low=midi("C2"), high=midi("D3"), step=0.5, oct_pattern=(0, 12), gate=0.6):
    prev = None
    for st, du, sy in prog:
        r = bass_note(sy, low, high, prev)
        k = 0
        b = st
        while b < st + du - 1e-6:
            tr.n(b, step, r + oct_pattern[k % len(oct_pattern)], vel + (8 if k % 4 == 0 else 0), gate=gate)
            b += step
            k += 1
        prev = r


def concat_prog(*parts, meter=4):
    """Concatenate parse_prog strings into one prog with consecutive bars."""
    out = []
    bar = 0
    for p in parts:
        pr = parse_prog(p, meter)
        nb = int(round((pr[-1][0] + pr[-1][1]) / meter))
        out += [(s + bar * meter, d, c) for s, d, c in pr]
        bar += nb
    return out


def section(prog, bar0, bar1, meter=4):
    return [(s, d, c) for s, d, c in prog if bar0 * meter - 1e-6 <= s < bar1 * meter - 1e-6]


def diatonic_below(notes, scale_pcs, steps=2, vel_drop=10):
    """Return copies of notes moved `steps` scale degrees down (e.g. 2 = a diatonic third below)."""
    out = []
    for (t0, t1, k, v) in notes:
        pc = k % 12
        if pc in scale_pcs:
            i = scale_pcs.index(pc)
            below = scale_pcs[(i - steps) % len(scale_pcs)]
            kk = k - ((pc - below) % 12 or 12)
        else:
            kk = k - 3
        out.append((t0, t1, kk, max(1, v - vel_drop)))
    return out
