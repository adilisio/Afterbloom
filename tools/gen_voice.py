"""Generate every voiced line in data/lines.txt with neural TTS (edge-tts) into assets/audio/voice/.

Lines containing {addr}/{Addr} get one file per address variant: <id>__<variant>.mp3
Usage: python gen_voice.py [--force] [id ...]
"""
import asyncio
import os
import sys

import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "voice")

# speaker -> (voice, rate, pitch)
VOICES = {
    "tuppence": ("en-GB-RyanNeural", "+6%", "+8Hz"),
    "registrar": ("en-US-EricNeural", "-4%", "-6Hz"),
    "june": ("en-US-AvaNeural", "+4%", "+0Hz"),
    "rory": ("en-US-AndrewNeural", "+2%", "+0Hz"),
    "narrator": ("en-US-AndrewNeural", "-10%", "-6Hz"),
    "dot": ("en-US-EmmaNeural", "+6%", "+2Hz"),
    "anchor": ("en-US-ChristopherNeural", "+0%", "-2Hz"),
    "announcer": ("en-US-RogerNeural", "+8%", "+4Hz"),
    "pa": ("en-US-AriaNeural", "-6%", "-2Hz"),
    "civil": ("en-US-GuyNeural", "-6%", "-4Hz"),
    "warden": ("en-US-SteffanNeural", "-6%", "-4Hz"),
}
ADDR = {"sir": "sir", "maam": "ma'am", "boss": "boss", "captain": "captain"}


def parse_lines():
    lines = []
    with open(os.path.join(ROOT, "data", "lines.txt"), encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw or raw.startswith("#"):
                continue
            lid, who, text = [p.strip() for p in raw.split("|", 2)]
            lines.append((lid, who, text))
    return lines


def expand(lid, text):
    if "{addr}" not in text.lower():
        return [(lid, text)]
    out = []
    for key, word in ADDR.items():
        t = text.replace("{addr}", word).replace("{Addr}", word[0].upper() + word[1:])
        out.append((f"{lid}__{key}", t))
    return out


async def synth(fid, who, text, force, sem):
    path = os.path.join(OUT, fid + ".mp3")
    if os.path.exists(path) and not force:
        return False
    voice, rate, pitch = VOICES[who]
    async with sem:
        for attempt in range(4):
            try:
                await edge_tts.Communicate(text, voice, rate=rate, pitch=pitch).save(path)
                return True
            except Exception as e:  # transient network errors
                if attempt == 3:
                    print("FAIL", fid, e)
                await asyncio.sleep(1.5 * (attempt + 1))
    return False


async def main():
    force = "--force" in sys.argv
    only = {a for a in sys.argv[1:] if not a.startswith("--")}
    os.makedirs(OUT, exist_ok=True)
    sem = asyncio.Semaphore(6)
    jobs = []
    for lid, who, text in parse_lines():
        if only and lid not in only:
            continue
        for fid, t in expand(lid, text):
            jobs.append(synth(fid, who, t, force or bool(only), sem))
    made = sum(await asyncio.gather(*jobs))
    print(f"generated {made} of {len(jobs)} files")


if __name__ == "__main__":
    asyncio.run(main())
