"""Generate the voiced lines in data/lines.txt with ElevenLabs into assets/audio/voice/ (same file names as gen_voice.py).

ElevenLabs output replaces the edge-tts placeholder files. tools/eleven_voice_manifest.json records what each file was made from
(voice + model + text), so a rerun only spends credits on lines whose text, voice or settings changed.
Each file is levelled to the same speech loudness the edge-tts files had (TARGET_DB), so the in-game mix is unchanged.
Lines containing {addr}/{Addr} get one file per address variant: <id>__<variant>.mp3

Usage: python gen_voice_eleven.py [--dry] [--force] [id ...]
  --dry    print the files that would be generated and the credit cost, then stop
"""
import hashlib
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np
import soundfile as sf

from eleven_api import API, session
from gen_voice import OUT, ROOT, expand, parse_lines

MODEL = "eleven_multilingual_v2"
FORMAT = "mp3_44100_128"
MANIFEST = os.path.join(ROOT, "tools", "eleven_voice_manifest.json")
TARGET_DB = -19.0  # RMS of the voiced parts (50 ms frames above -20 dB of the loudest)
CEIL_DB = -1.0

# speaker -> (voice_id, voice name, settings). Names are for humans; the id is what's used.
# stability: lower = more expressive. style: exaggeration of the voice's delivery.
CAST = {
    "tuppence": ("JBFqnCBsd6RMkjVDRZzb", "George", {"stability": 0.4, "similarity_boost": 0.8, "style": 0.35, "speed": 1.05}),
    "registrar": ("cjVigY5qzO86Huf0OWal", "Eric", {"stability": 0.7, "similarity_boost": 0.8, "style": 0.15}),
    "june": ("a4SZwHT3FMKGrM6vbf60", "Sara", {"stability": 0.4, "similarity_boost": 0.8, "style": 0.3}),
    "rory": ("KvaCHcJoMXfOzwtsULOZ", "Hank Harvey", {"stability": 0.45, "similarity_boost": 0.8, "style": 0.3}),
    "narrator": ("UzD2XhoJj8J4ncQXotqw", "Adrian", {"stability": 0.6, "similarity_boost": 0.8, "style": 0.15, "speed": 0.95}),
    "dot": ("XrExE9yKIg1WjnnlVkGX", "Matilda", {"stability": 0.4, "similarity_boost": 0.8, "style": 0.4, "speed": 1.05}),
    "anchor": ("nPczCjzI2devNBz1zQrb", "Brian", {"stability": 0.6, "similarity_boost": 0.8, "style": 0.2}),
    "announcer": ("hbdLfaIj2uL2NimPQh6e", "Ben", {"stability": 0.4, "similarity_boost": 0.8, "style": 0.45, "speed": 1.08}),
    "pa": ("F59Bv0jP18ftxRfYvYo5", "Tatiana", {"stability": 0.8, "similarity_boost": 0.8, "style": 0.0, "speed": 0.95}),
    "civil": ("8hmpa25DrgOJjzYgU64z", "Jay", {"stability": 0.65, "similarity_boost": 0.8, "style": 0.2, "speed": 0.95}),
    "warden": ("iPYqcpY8j8Ap4jUf28I3", "Michael", {"stability": 0.5, "similarity_boost": 0.8, "style": 0.25, "speed": 0.95}),
}


def _key(who, text):
    voice, _, settings = CAST[who]
    blob = json.dumps([MODEL, voice, settings, text], sort_keys=True)
    return hashlib.sha1(blob.encode("utf-8")).hexdigest()[:16]


def _level(src, dst):
    x, sr = sf.read(src)
    mono = x if x.ndim == 1 else x.mean(1)
    w = sr // 20
    fr = mono[: len(mono) // w * w].reshape(-1, w)
    rms = np.sqrt((fr ** 2).mean(1))
    voiced = rms[rms > rms.max() * 0.1]
    level = 20 * np.log10(np.sqrt((voiced ** 2).mean()) + 1e-9)
    gain = TARGET_DB - level
    peak = 20 * np.log10(np.abs(x).max() + 1e-9)
    gain = min(gain, CEIL_DB - peak)
    sf.write(dst, x * 10 ** (gain / 20), sr, format="MP3")


def _synth(s, fid, who, text):
    voice, _, settings = CAST[who]
    body = {"text": text, "model_id": MODEL, "voice_settings": settings}
    for attempt in range(4):
        try:
            r = s.post(f"{API}/v1/text-to-speech/{voice}?output_format={FORMAT}", json=body, timeout=120)
            if r.status_code == 429 or r.status_code >= 500:
                raise RuntimeError(f"HTTP {r.status_code}")
            if r.status_code != 200:
                print("FAIL", fid, r.status_code, r.text[:200])
                return False
            raw = os.path.join(OUT, fid + ".raw.mp3")
            with open(raw, "wb") as f:
                f.write(r.content)
            _level(raw, os.path.join(OUT, fid + ".mp3"))
            os.remove(raw)
            return True
        except Exception as e:  # rate limits and transient network errors
            if attempt == 3:
                print("FAIL", fid, e)
            time.sleep(2.0 * (attempt + 1))
    return False


def main():
    force = "--force" in sys.argv
    dry = "--dry" in sys.argv
    only = {a for a in sys.argv[1:] if not a.startswith("--")}
    manifest = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            manifest = json.load(f)
    jobs = []
    for lid, who, text in parse_lines():
        if only and lid not in only:
            continue
        for fid, t in expand(lid, text):
            k = _key(who, t)
            if force or manifest.get(fid) != k or not os.path.exists(os.path.join(OUT, fid + ".mp3")):
                jobs.append((fid, who, t, k))
    chars = sum(len(j[2]) for j in jobs)
    print(f"{len(jobs)} files to generate, about {chars} credits")
    if dry or not jobs:
        return
    s = session()
    with ThreadPoolExecutor(max_workers=4) as ex:  # Creator plan allows a handful of concurrent requests
        results = list(ex.map(lambda j: _synth(s, j[0], j[1], j[2]), jobs))
    for (fid, _, _, k), ok in zip(jobs, results):
        if ok:
            manifest[fid] = k
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(manifest.items())), f, indent=1)
    print(f"generated {sum(results)} of {len(jobs)} files")


if __name__ == "__main__":
    main()
