"""AFTERBLOOM music engine: SoundFont rendering (tinysoundfont + GeneralUser GS), theory helpers,
pattern generators, mixing and mastering."""
from __future__ import annotations

import itertools
import os
import re
import numpy as np
import tinysoundfont

import afx
from afx import SR

SF2 = os.path.join(os.path.dirname(__file__), "sf", "GeneralUser-GS.sf2")
_SF_BYTES = None


def _sf_bytes():
    global _SF_BYTES
    if _SF_BYTES is None:
        with open(SF2, "rb") as f:
            _SF_BYTES = f.read()
    return _SF_BYTES


# (bank, preset, is_drums)
INST = dict(
    piano=(0, 0), brightpiano=(0, 1), honky=(0, 3), epiano=(0, 4), celesta=(0, 8), glock=(0, 9),
    musicbox=(0, 10), vibes=(0, 11), marimba=(0, 12), tubular=(0, 14), organ=(0, 16), accordion=(0, 21),
    harmonica=(0, 22), nylon=(0, 24), steelgtr=(0, 25), jazzgtr=(0, 26), cleangtr=(0, 27), mutedgtr=(0, 28),
    abass=(0, 32), fbass=(0, 33), slap=(0, 36), violin=(0, 40), viola=(0, 41), cello=(0, 42),
    contrabass=(0, 43), tremstr=(0, 44), pizz=(0, 45), harp=(0, 46), timpani=(0, 47), strings=(0, 48),
    slowstr=(0, 49), synstr=(0, 50), choir=(0, 52), oohs=(0, 53), orchhit=(0, 55), trumpet=(0, 56),
    trombone=(0, 57), tuba=(0, 58), mutedtpt=(0, 59), horns=(0, 60), brass=(0, 61), altosax=(0, 65),
    tenorsax=(0, 66), barisax=(0, 67), oboe=(0, 68), clarinet=(0, 71), flute=(0, 73), whistle=(0, 78),
    warmpad=(0, 89), spacevoice=(0, 91), bowedglass=(0, 92), metalpad=(0, 93), halopad=(0, 94),
    sweeppad=(0, 95), atmosphere=(0, 99), echodrops=(0, 102), kalimba=(0, 108), taiko=(0, 116),
    revcym=(0, 119), hawaiian=(8, 26), concertbd=(8, 116), churchbells=(8, 14), gtr12=(8, 25),
    solohorn=(1, 60), stringsmono=(1, 48), slowstrmono=(1, 49), sine=(8, 80), ukulele=(8, 24),
    mandolin=(16, 25), tremstrmono=(1, 44),
)
KITS = dict(standard=(128, 0), room=(128, 8), jazz=(128, 32), brush=(128, 40), orch=(128, 48))

# GM drum keys
KICK, KICK2, STICK, SNARE, CLAP, SNARE2, HHC, HHP, HHO, CRASH, RIDE, RIDEBELL, TAMB, COWBELL = \
    36, 35, 37, 38, 39, 40, 42, 44, 46, 49, 51, 53, 54, 56
TOM_LO, TOM_ML, TOM_M, TOM_H, TOM_FL = 45, 47, 48, 50, 41
CRASH2, SPLASH, CHINA, SHAKER, CLAVES, CABASA = 57, 55, 52, 70, 75, 69

# ------------------------------------------------------------------------------------------ theory
_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name: str) -> int:
    m = re.fullmatch(r"([A-G])([#b]*)(-?\d)", name.strip())
    if not m:
        raise ValueError(name)
    pc = _PC[m.group(1)] + m.group(2).count("#") - m.group(2).count("b")
    return 12 * (int(m.group(3)) + 1) + pc


CHORDS = {
    "": [0, 4, 7], "maj": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11],
    "m7": [0, 3, 7, 10], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "dim": [0, 3, 6], "dim7": [0, 3, 6, 9],
    "m7b5": [0, 3, 6, 10], "aug": [0, 4, 8], "sus4": [0, 5, 7], "sus2": [0, 2, 7], "9": [0, 4, 7, 10, 14],
    "maj9": [0, 4, 7, 11, 14], "m9": [0, 3, 7, 10, 14], "add9": [0, 4, 7, 14], "13": [0, 4, 10, 14, 21],
    "7b9": [0, 4, 7, 10, 13], "69": [0, 4, 7, 9, 14], "madd9": [0, 3, 7, 14], "7sus4": [0, 5, 7, 10],
    "m11": [0, 3, 7, 10, 14, 17], "maj7#11": [0, 4, 7, 11, 18], "mmaj7": [0, 3, 7, 11], "7#5": [0, 4, 8, 10],
    "5": [0, 7], "m6/9": [0, 3, 7, 9, 14], "9sus4": [0, 5, 7, 10, 14],
}


def parse_chord(sym: str):
    """'Cmaj7/E' -> (root_pc, intervals, bass_pc)."""
    bass = None
    if "/" in sym:
        sym, b = sym.split("/")
        bass = (_PC[b[0]] + b[1:].count("#") - b[1:].count("b")) % 12
    m = re.fullmatch(r"([A-G])([#b]?)(.*)", sym)
    root = (_PC[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)) % 12
    q = m.group(3)
    ivs = CHORDS[q]
    return root, ivs, root if bass is None else bass


_NAMES = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]


def transpose_sym(sym, k):
    if k == 0 or sym in ("N", "-"):
        return sym
    def tr(s):
        m = re.fullmatch(r"([A-G][#b]?)(.*)", s)
        r = (_PC[m.group(1)[0]] + (1 if "#" in m.group(1) else -1 if "b" in m.group(1) else 0) + k) % 12
        return _NAMES[r] + m.group(2)
    if "/" in sym:
        a, b = sym.split("/")
        return tr(a) + "/" + tr(b)
    return tr(sym)


def chord_pcs(sym):
    r, ivs, b = parse_chord(sym)
    return [(r + i) % 12 for i in ivs], r, b


def voicing(sym, center=60, prev=None, n=4, low=None, high=None, root_ok=True):
    """Choose a close-ish voicing for sym near center with smooth voice-leading from prev."""
    pcs, root, bass = chord_pcs(sym)
    pcs = list(dict.fromkeys(pcs))
    if len(pcs) > n:
        r, ivs, _ = parse_chord(sym)
        # drop the fifth first, then the root
        fifth = (r + 7) % 12
        if fifth in pcs and len(pcs) > n:
            pcs.remove(fifth)
        if len(pcs) > n and not root_ok and root in pcs:
            pcs.remove(root)
        pcs = pcs[:n] if len(pcs) > n else pcs
    low = center - 8 if low is None else low
    high = center + 10 if high is None else high
    opts = []
    for pc in pcs:
        o = [k for k in range(low, high + 1) if k % 12 == pc]
        opts.append(o or [center - ((center - pc) % 12)])
    best, bc = None, 1e9
    for combo in itertools.product(*opts):
        c = sorted(combo)
        spread = c[-1] - c[0]
        if spread > 14:
            continue
        cost = abs(np.mean(c) - center) * 0.6
        if prev:
            p = sorted(prev)
            m = min(len(p), len(c))
            cost += sum(abs(a - b) for a, b in zip(c[:m], p[:m])) * 0.8
        # avoid minor-second clusters at the bottom
        if len(c) > 1 and c[1] - c[0] == 1:
            cost += 4
        if cost < bc:
            bc, best = cost, c
    if best is None:
        best = sorted(o[0] for o in opts)
    return list(best)


def bass_note(sym, low=midi("E1"), high=midi("D3"), prefer=None):
    _, root, bass = chord_pcs(sym)
    cands = [k for k in range(low, high + 1) if k % 12 == bass]
    if prefer is None:
        return cands[len(cands) // 2] if len(cands) > 1 else cands[0]
    return min(cands, key=lambda k: abs(k - prefer))


def parse_prog(s: str, meter=4, transpose=0):
    """'Cmaj7 | Am7 | Dm7 G7 | C' -> list of (start_beat, dur_beats, sym)."""
    out = []
    for i, bar in enumerate([b.strip() for b in s.split("|") if b.strip()]):
        syms = bar.split()
        # 'C . . G' style: '.' extends previous chord
        k = len(syms)
        d = meter / k
        for j, sy in enumerate(syms):
            if sy == ".":
                st, du, pv = out[-1]
                out[-1] = (st, du + d, pv)
            else:
                out.append((i * meter + j * d, d, transpose_sym(sy, transpose)))
    return out


def prog_at(prog, beat):
    for st, du, sy in prog:
        if st <= beat < st + du:
            return sy
    return prog[-1][2]


def offset_prog(prog, beats):
    return [(s + beats, d, c) for s, d, c in prog]


SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10],
    "mixo": [0, 2, 4, 5, 7, 9, 10], "blues": [0, 3, 5, 6, 7, 10], "majpent": [0, 2, 4, 7, 9],
    "minpent": [0, 3, 5, 7, 10], "harmminor": [0, 2, 3, 5, 7, 8, 11],
}


# ------------------------------------------------------------------------------------------ song model
class Track:
    def __init__(self, song, name, inst, vol=1.0, pan=0.0, rev=0.2, width=1.0, eq=None, hum_t=0.008,
                 hum_v=6, drums=False, bend_range=2.0, delay=None, sat=0.0):
        self.song, self.name = song, name
        if isinstance(inst, str):
            if inst in KITS:
                bank, pre = KITS[inst]
                drums = True
            else:
                bank, pre = INST[inst]
        else:
            bank, pre = inst
        self.bank, self.preset, self.drums = bank, pre, drums
        self.vol, self.pan, self.rev, self.width, self.eq = vol, pan, rev, width, eq or []
        self.hum_t, self.hum_v = hum_t, hum_v
        self.bend_range = bend_range
        self.delay = delay  # (time_sec, feedback, mix)
        self.sat = sat
        self.notes = []  # (t_on, t_off, key, vel)
        self.ctl = []  # (t, kind, a, b)
        self.rng = afx.rng_for(name, song.seed)

    # times in beats
    def n(self, beat, dur, key, vel=80, exact=False, gate=1.0):
        if isinstance(key, str):
            key = midi(key)
        s = self.song
        jt = 0 if exact else self.rng.normal(0, self.hum_t)
        jv = 0 if exact else self.rng.normal(0, self.hum_v)
        t0 = max(0.0, s.sec(beat) + jt)
        t1 = s.sec(beat + dur * gate) + (0 if exact else self.rng.normal(0, self.hum_t * 0.5))
        t1 = max(t0 + 0.02, t1)
        v = int(np.clip(vel + jv, 1, 127))
        self.notes.append((t0, t1, int(key), v))
        return self

    def chord(self, beat, dur, keys, vel=70, strum=0.0, gate=1.0):
        for i, k in enumerate(keys):
            self.n(beat + i * strum, dur - i * strum, k, vel - i * 2, gate=gate)
        return self

    def cc(self, beat, num, val):
        self.ctl.append((self.song.sec(beat), "cc", num, int(np.clip(val, 0, 127))))

    def cc_ramp(self, b0, b1, num, v0, v1, steps=None):
        steps = steps or max(2, int((b1 - b0) * 8))
        for i in range(steps + 1):
            f = i / steps
            self.cc(b0 + (b1 - b0) * f, num, v0 + (v1 - v0) * f)

    def expr(self, b0, b1, v0, v1, curve=1.0):
        steps = max(2, int((b1 - b0) * 8))
        for i in range(steps + 1):
            f = (i / steps) ** curve
            self.cc(b0 + (b1 - b0) * i / steps, 11, v0 + (v1 - v0) * f)

    def pedal(self, beat, up_beat):
        self.cc(beat + 0.02, 64, 127)
        self.cc(up_beat - 0.02, 64, 0)

    def bend(self, beat, semis):
        self.ctl.append((self.song.sec(beat), "bend", float(np.clip(semis / self.bend_range, -1, 1)), 0))

    def bend_ramp(self, b0, b1, s0, s1, steps=12, curve=1.0):
        for i in range(steps + 1):
            f = (i / steps) ** curve
            self.bend(b0 + (b1 - b0) * i / steps, s0 + (s1 - s0) * f)

    def mel(self, beat, text, vel=80, gate=0.95, transpose=0, octave=0):
        """Melody string: 'E5:1 D5:.5 r:.5 C5+E5:2 G4:1!' ('!' accent, '_' staccato, '~' legato-into-next)."""
        b = beat
        for tok in text.split():
            p, d = tok.split(":")
            acc = 0
            g = gate
            while d and d[-1] in "!_~":
                if d[-1] == "!":
                    acc += 14
                elif d[-1] == "_":
                    g = 0.5
                elif d[-1] == "~":
                    g = 1.04
                d = d[:-1]
            d = float(d)
            if p != "r":
                for pp in p.split("+"):
                    self.n(b, d, midi(pp) + transpose + 12 * octave, vel + acc, gate=g)
            b += d
        return b


class Song:
    def __init__(self, bpm, meter=4, swing=0.5, seed=0, tempo_map=None, sub=1.0):
        """bpm in beats/min; swing = position of the off-8th (0.5 straight, 0.62 light, 0.667 triplet).
        sub: beat subdivision for swing (1.0 = swing 8ths in quarter beats)."""
        self.bpm, self.meter, self.swing, self.seed = bpm, meter, swing, seed
        self.sub = sub
        self.tracks = []
        self.tempo_map = tempo_map  # list of (beat, bpm) piecewise-linear
        self._cum = None

    def track(self, *a, **k):
        t = Track(self, *a, **k)
        self.tracks.append(t)
        return t

    def _swing(self, beat):
        if self.swing == 0.5:
            return beat
        u = beat / self.sub
        i = np.floor(u)
        f = u - i
        s = self.swing
        f2 = f * (s / 0.5) if f < 0.5 else s + (f - 0.5) * ((1 - s) / 0.5)
        return (i + f2) * self.sub

    def sec(self, beat):
        b = self._swing(beat)
        if not self.tempo_map:
            return b * 60.0 / self.bpm
        if self._cum is None:
            bs = np.arange(0, 4000, 0.01)
            tb, tv = zip(*self.tempo_map)
            bpm = np.interp(bs, tb, tv)
            self._cum = (bs, np.concatenate([[0], np.cumsum(60.0 / bpm[:-1] * 0.01)]))
        return float(np.interp(b, *self._cum))

    def bars(self, n):
        return n * self.meter

    # -------------------------------------------------------------------- rendering
    def render_track(self, tr, length):
        n_total = afx.n_of(length)
        synth = tinysoundfont.Synth(samplerate=SR, gain=-3)
        sfid = synth.sfload(_sf_bytes(), max_voices=256)
        nch = 16
        for c in range(nch):
            synth.program_select(c, sfid, tr.bank, tr.preset, is_drums=tr.drums)
            if not tr.drums:
                synth.pitchbend_range(c, tr.bend_range)
        ev = []
        # allocate channels so the same key never overlaps on one channel
        busy = {}  # (ch,key)->t_off
        for (t0, t1, k, v) in sorted(tr.notes):
            ch = 0
            for c in range(nch):
                if busy.get((c, k), -1) <= t0 + 1e-4:
                    ch = c
                    break
            busy[(ch, k)] = t1
            ev.append((t0, 1, "on", ch, k, v))
            if not tr.drums:
                ev.append((t1, 0, "off", ch, k, 0))
        for (t, kind, a, b) in tr.ctl:
            ev.append((t, -1, kind, a, b, 0))
        ev.sort(key=lambda e: (e[0], e[1]))
        out = np.zeros((n_total, 2), dtype=np.float32)
        pos = 0
        pedal = False
        held = set()  # (ch, key) whose note-off is deferred by the sustain pedal (TSF has no CC64)
        for e in ev:
            target = min(n_total, int(round(e[0] * SR)))
            if target > pos:
                buf = np.frombuffer(synth.generate(target - pos), dtype=np.float32).reshape(-1, 2)
                out[pos:target] = buf
                pos = target
            kind = e[2]
            if kind == "on":
                if (e[3], e[4]) in held:
                    synth.noteoff(e[3], e[4])
                    held.discard((e[3], e[4]))
                synth.noteon(e[3], e[4], e[5])
            elif kind == "off":
                if pedal:
                    held.add((e[3], e[4]))
                else:
                    synth.noteoff(e[3], e[4])
            elif kind == "cc" and e[3] == 64:
                down = e[4] >= 64
                if pedal and not down:
                    for ch, k in held:
                        synth.noteoff(ch, k)
                    held.clear()
                pedal = down
            elif kind == "cc":
                for c in range(nch):
                    synth.control_change(c, e[3], e[4])
            elif kind == "bend":
                val = int(np.clip(8192 + e[3] * 8191, 0, 16383))
                for c in range(nch):
                    synth.pitchbend(c, val)
        if pos < n_total:
            out[pos:] = np.frombuffer(synth.generate(n_total - pos), dtype=np.float32).reshape(-1, 2)
        x = out.astype(np.float64)
        for e in tr.eq:
            k = e[0]
            if k == "hp":
                x = afx.hp(x, e[1], e[2] if len(e) > 2 else 2)
            elif k == "lp":
                x = afx.lp(x, e[1], e[2] if len(e) > 2 else 2)
            elif k == "peq":
                x = afx.peq(x, e[1], e[2], e[3])
            elif k == "lowshelf":
                x = afx.shelf(x, e[1], e[2], "low")
            elif k == "highshelf":
                x = afx.shelf(x, e[1], e[2], "high")
        if tr.sat:
            x = afx.softclip(x * (1 + tr.sat * 3), 1 + tr.sat) / (1 + tr.sat * 0.5)
        if tr.delay:
            dt, fb, mx = tr.delay
            d = afx.n_of(dt)
            y = np.zeros_like(x)
            src = x.copy()
            g = mx
            for i in range(1, 6):
                src = afx.lp(src, 3500)
                afx.mix_at(y, src[: max(0, len(src) - d * i)], d * i, g)
                g *= fb
            x = x + y
        x = afx.stereo_width(x, tr.width)
        p = tr.pan
        x[:, 0] *= np.sqrt(np.clip(1 - p, 0, 1)) if p > 0 else 1.0
        x[:, 1] *= np.sqrt(np.clip(1 + p, 0, 1)) if p < 0 else 1.0
        return x * tr.vol

    def render(self, length, loop=False, tail=8.0, rt60=2.2, rev_predelay=0.025, rev_damp=0.5, rev_size=1.0,
               master=True, target=-16.0, bus=None, stems=False, rev_seed=3, glue=True):
        """Render to stereo. For loops, length is the loop length and the tail is wrapped onto the start."""
        total = length + tail
        dry = np.zeros((afx.n_of(total), 2))
        send = np.zeros_like(dry)
        stem_out = {}
        for tr in self.tracks:
            if not tr.notes:
                continue
            x = self.render_track(tr, total)
            dry += x
            send += x * tr.rev
            if stems:
                stem_out[tr.name] = x
        L = afx.n_of(length)
        if loop:
            dry = afx.wrap_tail(dry, L)
            send = afx.wrap_tail(send, L)
            wet = afx.reverb(send, rt60=rt60, wet=1.0, dry=0.0, predelay=rev_predelay, damp=rev_damp,
                             size=rev_size, seed=rev_seed, loop=True)
            mixd = dry + wet
        else:
            wet = afx.reverb(send, rt60=rt60, wet=1.0, dry=0.0, predelay=rev_predelay, damp=rev_damp,
                             size=rev_size, seed=rev_seed)
            mixd = afx.pad_to(dry, wet.shape[0]) + wet
        if bus:
            mixd = bus(mixd)
        if glue:
            mixd = afx.compress(mixd, thr_db=-20, ratio=1.8, attack=0.02, release=0.25)
        if master:
            if not loop:
                mixd = afx.trim_silence(mixd, -66, 0.05)
            mixd = afx.master_music(mixd, target, -1.5, loop=loop)
            if not loop:
                mixd = afx.fade(mixd, 0.003, 0.25)
        return (mixd, stem_out) if stems else mixd


# ------------------------------------------------------------------------------------------ patterns
def pad(tr, prog, vel=60, center=60, n=4, gate=1.0, expr=None, offset=0.0, low=None, high=None):
    prev = None
    for st, du, sy in prog:
        v = voicing(sy, center, prev, n, low, high)
        tr.chord(st + offset, du, v, vel, gate=gate)
        prev = v
    return tr


def bassline_roots(tr, prog, vel=80, pattern=((0, 1.0),), low=midi("E1"), high=midi("D3"), fifth_on=None,
                   gate=0.9):
    prev = None
    for st, du, sy in prog:
        r = bass_note(sy, low, high, prev)
        _, root, _ = chord_pcs(sy)
        fifth = r + 7 if r + 7 <= high else r - 5
        for (o, d) in pattern:
            if o >= du:
                continue
            k = fifth if (fifth_on and o in fifth_on) else r
            tr.n(st + o, min(d, du - o), k, vel - (0 if o == 0 else 6), gate=gate)
        prev = r
    return tr


def walking_bass(tr, prog, rng, vel=82, low=midi("E1"), high=midi("C3"), meter=4, start=None, end=None):
    """Quarter-note walking bass: root on chord start, chord/scale tones, chromatic approach into the next chord."""
    beats = []
    total = prog[-1][0] + prog[-1][1]
    b0 = prog[0][0] if start is None else start
    b1 = total if end is None else end
    cur = None
    b = b0
    while b < b1 - 1e-6:
        sy = prog_at(prog, b)
        nxt = prog_at(prog, b + 1)
        pcs, root, bass = chord_pcs(sy)
        is_change = any(abs(st - b) < 1e-6 for st, _, _ in prog)
        if is_change or cur is None:
            k = bass_note(sy, low, high, cur if cur is not None else (low + high) // 2)
        elif nxt != sy or (b + 1) % meter == 0 and any(abs(st - (b + 1)) < 1e-6 for st, _, _ in prog):
            # approach next root chromatically or by fifth
            tgt = bass_note(nxt, low, high, cur)
            k = tgt + (rng.choice([-1, 1]) if rng.random() < 0.7 else 7 if tgt + 7 <= high else -5)
            if k == cur:
                k = tgt - 1
        else:
            ch = [p for p in range(low, high + 1) if p % 12 in pcs or (p % 12 - root) % 12 in (2, 9)]
            ch = [p for p in ch if 0 < abs(p - cur) <= 5] or ch
            k = int(rng.choice(ch))
        k = int(np.clip(k, low, high))
        acc = 6 if (b % 2 == 0) else 0
        tr.n(b, 1.0, k, vel + acc - rng.integers(0, 6), gate=0.92)
        # occasional skip-note ghost (swing feel)
        if rng.random() < 0.06:
            tr.n(b + 0.5, 0.5, k, vel - 30, gate=0.5)
        cur = k
        b += 1
    return tr


def comp_charleston(tr, prog, rng, vel=58, center=62, n=4):
    """Swing piano/guitar comping: hits on 1 and 2&, varied with anticipations."""
    prev = None
    for st, du, sy in prog:
        v = voicing(sy, center, prev, n)
        prev = v
        pats = [[(0, 0.9), (1.5, 0.4)], [(0, 1.3)], [(0.5, 0.4), (2.5, 0.4)], [(1, 0.4), (2.5, 0.9)],
                [(0, 0.5), (1.5, 0.5), (3.5, 0.4)]]
        if du < 4:
            pats = [[(0, du * 0.4)], [(0.5, 0.4)], [(0, 0.9)]]
        pat = pats[rng.integers(len(pats))]
        for o, d in pat:
            if o < du:
                tr.chord(st + o, d, v, vel + (6 if o % 1 else 0), strum=0.01)
    return tr


def arp(tr, prog, pattern, vel=60, center=60, n=4, step=0.5, low_root=True, root_oct=-12, gate=1.6,
        accents=None, prev=None):
    """Broken-chord arpeggio. pattern indexes into [bass_root] + voicing (0 = bass root)."""
    for st, du, sy in prog:
        v = voicing(sy, center, prev, n)
        prev = v
        rootk = bass_note(sy, center - 24 + (0 if root_oct == -12 else 12), center - 12)
        pool = [rootk] + v
        steps = int(round(du / step))
        for i in range(steps):
            idx = pattern[i % len(pattern)]
            if idx is None:
                continue
            if idx < len(pool):
                k = pool[idx]
            else:
                m = len(pool) - 1
                k = pool[1 + (idx - 1) % m] + 12 * ((idx - 1) // m)
            a = accents[i % len(accents)] if accents else 0
            tr.n(st + i * step, step * gate, k, vel + a)
    return prev


def improvise(tr, prog, rng, start, bars, meter=4, low=60, high=84, density=0.75, vel=78, scale_key=0,
              scale="major", phrase=(4, 8), step=0.5, bend=False):
    """Algorithmic jazz-ish improvisation: phrases of swung 8ths built from chord tones on strong beats and
    scale/chromatic tones between, with rests between phrases."""
    sc = [(scale_key + s) % 12 for s in SCALES[scale]]
    b = start
    end = start + bars * meter
    cur = (low + high) // 2
    while b < end - 1e-6:
        plen = rng.integers(phrase[0], phrase[1] + 1) * step * 2
        pend = min(end, b + plen)
        direction = rng.choice([-1, 1])
        while b < pend - 1e-6:
            sy = prog_at(prog, b)
            pcs, root, _ = chord_pcs(sy)
            strong = abs((b % 1.0)) < 1e-6
            if rng.random() > density and not strong:
                b += step
                continue
            pool = pcs if strong else list(set(sc) | set(pcs))
            cands = [k for k in range(low, high + 1) if k % 12 in pool]
            if rng.random() < 0.25:
                direction = -direction
            nearc = [k for k in cands if 0 < (k - cur) * direction <= 4]
            if not nearc:
                direction = -direction
                nearc = [k for k in cands if 0 < (k - cur) * direction <= 5] or cands
            k = int(rng.choice(nearc))
            # occasional chromatic lower-neighbour approach
            if not strong and rng.random() < 0.15 and k - 1 >= low:
                k = k - 1
            d = step
            if rng.random() < 0.18:
                d = step * rng.choice([2, 3])
            accent = 10 if (not strong and step == 0.5) else 0
            tr.n(b, d, k, vel + accent - rng.integers(0, 10), gate=0.85)
            if bend and d >= 1 and rng.random() < 0.4:
                tr.bend(b, -1.0)
                tr.bend_ramp(b + 0.02, b + 0.3, -1.0, 0.0, 6)
            cur = k
            b += d
        # land on a chord tone, then breathe
        sy = prog_at(prog, b)
        pcs, _, _ = chord_pcs(sy)
        landing = min([k for k in range(low, high + 1) if k % 12 in pcs], key=lambda k: abs(k - cur))
        if b < end:
            tr.n(b, 1.0, landing, vel - 4, gate=0.9)
            cur = landing
        b += 1 + step * rng.integers(1, 4)
    return tr


def drum_hits(tr, beats, key, vel=80, start=0.0, bars=1, meter=4, vel_var=None):
    for bar in range(bars):
        for i, o in enumerate(beats):
            v = vel if vel_var is None else vel + vel_var[i % len(vel_var)]
            tr.n(start + bar * meter + o, 0.25, key, v)
