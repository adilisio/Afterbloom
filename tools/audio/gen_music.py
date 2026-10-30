"""Regenerate all AFTERBLOOM music (score, stingers, radio records).

Usage:  python gen_music.py            # everything
        python gen_music.py title_loop sting_bloom   # subset
Deterministic: fixed seeds everywhere. Uses GeneralUser GS SoundFont (tools/audio/sf/) via tinysoundfont.
"""
import os
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import afx  # noqa: E402

CUES = {
    # name: (module, function, subdir)
    "title_loop": ("score_main", "title_loop", ""),
    "coldopen": ("score_main", "coldopen", ""),
    "morning_loop": ("score_main", "morning_loop", ""),
    "explore_day_loop": ("score_main", "explore_day_loop", ""),
    "explore_day2_loop": ("score_main", "explore_day2_loop", ""),
    "explore_night_loop": ("score_main", "explore_night_loop", ""),
    "shelter_wake_loop": ("score_main", "shelter_wake_loop", ""),
    "sting_reunion": ("score_main", "sting_reunion", ""),
    "sting_levelup": ("score_main", "sting_levelup", ""),
    "sting_quest_start": ("score_main", "sting_quest_start", ""),
    "sting_quest_done": ("score_main", "sting_quest_done", ""),
    "sting_discover": ("score_main", "sting_discover", ""),
    "sting_ending": ("score_main", "sting_ending", ""),
    "dash_loop": ("score_action", "dash_loop", ""),
    "dash_end": ("score_action", "dash_end", ""),
    "combat_loop": ("score_action", "combat_loop", ""),
    "boss_loop": ("score_action", "boss_loop", ""),
    "sting_bloom": ("score_action", "sting_bloom", ""),
    "sunday_kind_of_gentle": ("score_radio", "sunday_kind_of_gentle", "radio"),
    "moonlight_on_gull_lane": ("score_radio", "moonlight_on_gull_lane", "radio"),
    "rocket_ride_shuffle": ("score_radio", "rocket_ride_shuffle", "radio"),
    "a_little_lantern": ("score_radio", "a_little_lantern", "radio"),
    "coffee_for_two": ("score_radio", "coffee_for_two", "radio"),
    "highway_seventeen": ("score_radio", "highway_seventeen", "radio"),
}


def build(name):
    import importlib
    t = time.time()
    mod, fn, sub = CUES[name]
    x = getattr(importlib.import_module(mod), fn)()
    path = os.path.join(afx.MUSIC_DIR, sub, name + ".ogg")
    afx.write_ogg(path, x)
    return name, x.shape[0] / afx.SR, time.time() - t


if __name__ == "__main__":
    names = sys.argv[1:] or list(CUES)
    with Pool(min(10, len(names))) as p:
        for name, dur, el in p.imap_unordered(build, names):
            print(f"{name:28s} {dur:7.1f}s  ({el:.1f}s)", flush=True)
