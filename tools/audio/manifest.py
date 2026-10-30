"""Write assets/audio/AUDIO.md from analysis_all.json (run analyze.py all first)."""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

DESC = [
    # ---- music
    ("title_loop", "Title theme: wistful piano statement of the AFTERBLOOM theme (D major), slow strings, violin + celesta reprise, harp."),
    ("coldopen", "Solo piano for Rory's narrated intro: the main theme, gently rubato, ends on a rolled D(add9) chord."),
    ("morning_loop", "Cozy 1967 morning underscore: nylon guitar comp, vibes melody, brushed drums, upright bass in 2. Sparse so TV/radio sit on top."),
    ("explore_day_loop", "Emotional core (G major): fingerpicked guitar, piano theme, vibes counter-line, violins carry the B theme, harp."),
    ("explore_day2_loop", "Second exploration cue: 3/4 piano waltz figure with a new cello theme, flute + clarinet thirds, strings."),
    ("explore_night_loop", "Night: warm pads, slow harp, starry celesta twinkles with echo, flute quotes the main theme (E major)."),
    ("shelter_wake_loop", "Shelter wake-up: periodic low synth drones, bowed-glass pads, distant metallic resonances, sparse celesta. Uneasy, not scary."),
    ("dash_loop", "The dash to Shelter No. 9: driving low-string ostinato, taiko/timpani, brass stabs, heroic horn melody, theme in D minor on trumpets."),
    ("dash_end", "Final hit as the gate slams: timpani roll into a big D-major orchestral chord that tails off."),
    ("combat_loop", "Combat: C-minor string ostinato, taiko + toms, tremolo strings, horn motif (the theme's rising sixth turned anxious), breakdown section."),
    ("boss_loop", "Thornback fight: heavier D-Phrygian ostinato, concert bass drum, brass + orchestra hits, choir, horn/trumpet melody."),
    ("sting_reunion", "Tuppence sees you after 11 years: warm piano + strings on the opening of the main theme."),
    ("sting_levelup", "Level up: bright glockenspiel/celesta arpeggio into a brass + strings D-major chord."),
    ("sting_quest_start", "Quest start: rising horn call over strings, harp flourish."),
    ("sting_quest_done", "Quest complete: theme cadence (Em7-A7-D) on celesta/piano, strings, horns, harp."),
    ("sting_discover", "Location discovered: harp glissando, Gmaj7#11 -> D shimmer, flute sigh."),
    ("sting_ending", "Hopeful finale: full theme with violins and horns, piano arpeggios, timpani build, final D chord."),
    ("sting_bloom", "The Bloom hits: low string cluster and choir crescendo, reverse cymbal, timpani roll into a dissonant brass hit."),
    ("sunday_kind_of_gentle", "RADIO - \"Sunday Kind of Gentle\", The Halcyon Strings & Lou Marten. Lounge swing in Bb: vibes lead (AABA), walking bass, brushes, strings, piano solo, tag ending."),
    ("moonlight_on_gull_lane", "RADIO - \"Moonlight on Gull Lane\", Patsy Vale Quartet. Slow 12/8 doo-wop ballad in Eb: tenor sax lead with vibrato, piano triplets, oohs, AABA + outro."),
    ("rocket_ride_shuffle", "RADIO - \"Rocket Ride Shuffle\", Benny Cole & the Satellites. Rockabilly/surf in E: twangy slap-back guitar head, boogie upright bass, guitar solo, sax honk chorus, tremolo-picked surf bridge."),
    ("a_little_lantern", "RADIO - \"A Little Lantern\", Rosa Dean. 3/4 waltz in G: celesta + music-box melody, pizzicato oom-pah-pah, harp, violins on the bridge, flute descant."),
    ("coffee_for_two", "RADIO - \"Coffee for Two\", Mel Archer Trio. Piano trio in F: head AABA, piano solo chorus, walking bass, brushes, tag ending."),
    ("highway_seventeen", "RADIO - \"Highway Seventeen\", Dusty Carlyle. Country-western shuffle in G: harmonica verse, Hawaiian steel chorus hook with slides, boom-chick bass/guitar."),
    # ---- weapons
    (r"pistol_fire_\d", "Service pistol shot: N-wave crack, muzzle blast, body thump, slide cycling clicks, short outdoor slap-back tail. Variants differ in pitch/decay/echo."),
    (r"rifle_fire_\d", "Bolt-action rifle shot: louder crack, deeper body, receiver ring, longer outdoor echo tail."),
    ("gun_tail_outdoor", "Environment-only outdoor tail (echoes off buildings/hills + rolling rumble); layer under a dry shot."),
    ("gun_tail_indoor", "Environment-only indoor/room tail (boomy short reverb)."),
    ("pistol_mag_out", "Magazine release click, slide out, catch in palm."),
    ("pistol_mag_in", "Magazine slides in and seats with a firm clack."),
    ("pistol_slide", "Slide racked back and released forward."),
    ("rifle_bolt_open", "Bolt handle up and drawn back."),
    ("rifle_bolt_close", "Bolt pushed forward and locked down."),
    ("rifle_round_in", "Cartridge pressed into the rifle's magazine."),
    ("dry_fire", "Hammer click on an empty chamber."),
    (r"shell_\d", "Brass casing bouncing and rolling on hard ground."),
    ("bullet_flyby", "Supersonic snap + doppler whizz of a near miss."),
    # ---- impacts
    (r"impact_flesh_\d", "Bullet into flesh: dull thud, slap, small wet squelch (not gory)."),
    (r"impact_crystal_\d", "Bullet into Bloom crystal: glassy ring + tinkling shards."),
    ("impact_wood", "Bullet into wood: knock + splinters."),
    (r"impact_metal_\d", "Bullet into metal: sharp ping with plate ring."),
    (r"impact_concrete_\d", "Bullet into concrete: crack, chips, dust hiss."),
    ("impact_dirt", "Bullet into dirt: thud and soil spray."),
    (r"ricochet_\d", "Ricochet: metallic ping + descending whine."),
    # ---- footsteps
    (r"step_wood_\d", "Footstep on wooden floorboards (variant 3 has a small creak)."),
    (r"step_grass_\d", "Footstep on grass: soft grainy crunch."),
    (r"step_concrete_\d", "Footstep on concrete: heel click, scuff."),
    (r"step_metal_\d", "Footstep on metal grating/deck: clang + rattle."),
    (r"step_carpet_\d", "Footstep on carpet/rug: muffled thump."),
    (r"step_gravel_\d", "Footstep on gravel: stone-grain crunch."),
    ("jump", "Jump push-off with clothing rustle."),
    ("land", "Landing thump with gear rattle."),
    # ---- player
    (r"hurt_\d", "Player hurt: subtle body thud + short wordless exhale/grunt."),
    ("heartbeat_loop", "Low-health heartbeat, 80 bpm lub-dub."),
    ("heal", "Drinking a tonic: bottle glugs, fizz, faint restorative shimmer."),
    ("eat", "Crisp bite and chewing."),
    ("sureshot_enter", "SureShot engage: time-slowing whoosh and tape-stop tone dropping."),
    ("sureshot_exit", "SureShot release: reverse whoosh rising back to real time."),
    ("sureshot_target", "SureShot body-part focus: soft tick."),
    ("sureshot_queue", "SureShot shot queued: two-note confirm blip."),
    ("sureshot_fail", "SureShot not enough Focus: low double buzz."),
    # ---- UI
    ("ui_hover", "Menu hover: tiny soft tick."),
    ("ui_click", "Menu select: crisp mechanical click."),
    ("ui_back", "Menu back: descending two-blip."),
    ("journal_open", "Journal opens: paper rustle + leather cover thump."),
    ("journal_close", "Journal closes: cover thump."),
    ("page_turn", "Paper page turn."),
    (r"pickup_\d", "Generic item pickup: rustle + soft clunk."),
    ("pickup_ammo", "Ammo pickup: rattle of cartridges."),
    ("pickup_magazine", "Magazine pickup: paper + small two-note chime."),
    ("xp_tick", "XP gained: tiny rising tick."),
    ("quest_update", "Quest updated: typewriter keystrokes + bell ding."),
    # ---- home
    ("doorbell", "Classic two-tone ding-dong door chime (E5 -> C5)."),
    ("door_knock", "Three knocks on a wooden front door."),
    ("door_open", "Latch click, hinge creak, air movement."),
    ("door_close", "Door swings shut: thud + latch."),
    ("phone_ring", "Bell telephone: one ~2 s ring burst (twin bells, 20 Hz hammer)."),
    ("phone_pickup", "Bakelite handset lifted: hook switch click + bell tinkle."),
    ("phone_hangup", "Handset set down on the cradle."),
    ("kettle_whistle_loop", "Kettle whistle with bubbling boil underneath."),
    ("tea_pour", "Tea pouring into a cup (resonance rises as it fills)."),
    ("cup_clink", "Porcelain cup set on saucer."),
    ("toaster_pop", "Toaster pops: spring twang + carriage clank."),
    ("curtain_open", "Curtain drawn: rings sliding along the rod + fabric swish."),
    ("light_switch", "1960s toggle light switch."),
    ("tv_on", "Console TV on: knob, CRT degauss thump/hum, faint rising flyback whine, static."),
    ("tv_off", "TV off: pop, collapsing whine, discharge crackle."),
    ("tv_static_loop", "Dead-channel TV static with faint 60 Hz buzz."),
    ("radio_click", "Radio power knob click + valve hiss."),
    ("radio_tune", "Tuning dial sweep: static, heterodyne whistles, station fragments."),
    ("radio_static_loop", "AM static/crackle between stations."),
    ("clock_tick_loop", "Mantel clock, tick-tock at 1 tick per second."),
    ("fridge_hum_loop", "1960s refrigerator compressor hum."),
    # ---- robot
    (r"robot_servo_\d", "Tuppence servo/actuator whine (warm, brassy)."),
    ("robot_hover_loop", "Tuppence's gentle hover hum."),
    ("robot_beep_happy", "Happy rising chirp."),
    ("robot_beep_worried", "Worried wobbling descending beep."),
    ("robot_zap", "Tuppence's defensive zap: electric crack + arc buzz + sizzle."),
    ("robot_polish", "Cloth squeaks: polishing strokes."),
    # ---- creatures
    (r"mite_chitter_\d", "Bloom mite chittering: rapid glassy mandible clicks."),
    ("mite_attack", "Mite leap: hiss, fast chitter, glass scrape."),
    ("mite_death", "Mite dies: wet pop + spore puff + shard tinkle."),
    (r"husk_groan_\d", "Husk groan: breathy, creaky, hollow resonant voice with a crystalline shimmer (eerie, not gory)."),
    ("husk_attack", "Husk lunge: harsher exhale-roar with crystal rattle."),
    ("husk_death", "Husk dies: crystal shatter + long exhale."),
    (r"crystal_shatter_\d", "Large crystal growth shattering."),
    (r"thornback_roar_\d", "Thornback roar: huge layered growl with sub-octave and crystalline edge."),
    ("thornback_stomp", "Thornback stomp: deep impact, debris, ground rumble."),
    ("thornback_charge", "Thornback charge: accelerating stomps + rising roar."),
    ("thornback_death", "Thornback death: falling roar, collapse, bloom eruption shimmer + shatter cascade."),
    ("spore_burst", "Spore pod burst: pop, airy puff, glitter."),
    # ---- events
    ("siren_loop", "Air-raid siren rising and falling (12 s cycle), distant reverb."),
    ("pa_chime", "Three-tone public-address chime (G-E-C)."),
    ("car_crash", "Car crash: crunch, crumpling metal, glass, debris, hubcap rolling away."),
    ("car_alarm_loop", "1960s horn-style alarm honking in rhythm."),
    ("glass_break", "Window pane breaking."),
    ("explosion_distant", "Distant explosion: low boom + rumble."),
    ("gate_klaxon_loop", "Shelter gate klaxon (ah-OO-ga style), two blasts per cycle."),
    ("gate_slam", "Shelter gate slams: huge metallic boom with long hangar tail."),
    ("gate_open", "Shelter gate opens: lock bolts, hydraulic hiss, heavy grinding, end clunk (~6 s)."),
    ("power_up", "Power restored: big electrical hum rising, relays, whine, arc crackle."),
    ("lever_pull", "Heavy lever: ratchet clicks + clunk."),
    ("fuse_insert", "Fuse pushed into socket: scrape, snap, small electric buzz."),
    (r"thunder_near_\d", "Close thunder: crack then big rolling rumble."),
    (r"thunder_far_\d", "Distant thunder: low rolling rumble."),
    ("lightning_crack", "Lightning strike crack with sizzle."),
    (r"wind_gust_\d", "Wind gust swelling and passing."),
    ("bird_flock", "Flock of birds taking off: wing flaps + a few calls."),
    (r"gull_\d", "Seagull calls."),
    (r"dog_bark_\d", "Distant dog barking."),
    ("water_spray_loop", "Burst hydrant spraying."),
    ("bloom_wave", "The violet wall approaching: rising whoosh, shimmering crystalline chord, rumble (~10 s)."),
    # ---- ambience
    ("amb_house_morning_loop", "Inside the cottage, morning: birdsong muffled through windows, faint surf, room tone."),
    ("amb_town_day_loop", "1967 town day: birds, leaves in the wind, two distant cars, a far dog."),
    ("amb_after_day_loop", "1978 overgrown town: wind, distant gulls, faint crystal chimes, insects."),
    ("amb_night_loop", "Night: crickets, distant surf, light breeze."),
    ("amb_rain_loop", "Outdoor rain (stereo droplets)."),
    ("amb_rain_interior_loop", "Rain on roof and windows heard from inside, gutter drip."),
    ("amb_storm_wind_loop", "Storm wind: gusts, howling resonances, low rumble."),
    ("amb_ocean_loop", "Waves on the shore with occasional distant gulls."),
    ("amb_shelter_hum_loop", "Shelter ventilation hum, airflow, faint duct rattle."),
    ("amb_shelter_drip_loop", "Water drips echoing in concrete corridors."),
    ("amb_bloom_loop", "Bloom squall: eerie shimmering harmonic hum, whispering air, crystalline pings."),
]


def desc(name):
    for pat, d in DESC:
        if re.fullmatch(pat, name):
            return d
    return ""


def main():
    rows = json.load(open(os.path.join(HERE, "analysis_all.json")))
    groups = [("Music (assets/audio/music/)", lambda r: r["path"].startswith("assets/audio/music/") and
               "/radio/" not in r["path"]),
              ("Radio records (assets/audio/music/radio/)", lambda r: "/radio/" in r["path"]),
              ("Sound effects (assets/audio/sfx/)", lambda r: r["path"].startswith("assets/audio/sfx/"))]
    total_mb = sum(r["kb"] for r in rows) / 1024
    out = ["# AFTERBLOOM audio manifest", "",
           "All audio is generated offline and deterministically by the scripts in `tools/audio/`:", "",
           "- `python tools/audio/gen_music.py` - score, stingers and radio records "
           "(scores in `score_main.py`, `score_action.py`, `score_radio.py`; engine in `mus.py`).",
           "- `python tools/audio/gen_sfx.py` - every sound effect and ambience (`sfx_a.py`, `sfx_b.py`, "
           "building blocks in `sfxlib.py`, DSP core in `afx.py`).",
           "- `python tools/audio/analyze.py all` then `python tools/audio/manifest.py` - verification + this file.",
           "", "Format: OGG Vorbis, 44.1 kHz. Music is stereo, mastered to about -16 LUFS integrated "
           "(shelter_wake -17), true peaks <= -1 dBFS. SFX are mono and peak-normalised to about -1.3 dBFS "
           "(UI blips quieter by design); ambience loops are stereo. Files ending in `_loop` loop seamlessly "
           "(cyclic rendering: tails are wrapped onto the start, noise beds are FFT-periodic, oscillators "
           "complete whole cycles) - set `loop = true` on import in Godot. Non-loop files have short fades.",
           "", f"Total: {len(rows)} files, {total_mb:.1f} MB.", "",
           "## Instruments / licence", "",
           "Music uses the **GeneralUser GS v2.0.3** SoundFont by S. Christian Collins (rendered with the "
           "`tinysoundfont` Python package), plus custom DSP (synthesised reverb, drones, mastering). "
           "Licence (from the bank's LICENSE.txt): *\"You may use GeneralUser GS without restriction for your own "
           "music creation, private or commercial ... feel free to use it in your software projects.\"* "
           "The bank lives only in `tools/audio/sf/` (with its licence file); it is not shipped in assets. "
           "Rendered music contains no third-party copyrighted compositions - all themes and songs are original. "
           "All SFX are 100% procedural synthesis (no samples).", ""]
    for title, pred in groups:
        out += [f"## {title}", "", "| File | Length | Loop | Description |", "|---|---:|:---:|---|"]
        for r in sorted(filter(pred, rows), key=lambda r: r["name"]):
            ln = f"{r['dur']:.1f} s" if r["dur"] < 60 else f"{int(r['dur'] // 60)}:{r['dur'] % 60:04.1f}"
            out.append(f"| `{r['name']}.ogg` | {ln} | {'yes' if r['loop'] else ''} | {desc(r['name'])} |")
        out.append("")
    out += ["## Mixing notes for the game", "",
            "- The radio records are clean and full-range; route them through the `Radio` bus for the band-pass/crackle.",
            "- `pistol_fire_*` / `rifle_fire_*` already contain a short outdoor slap-back; for interiors play the "
            "shot with `gun_tail_indoor` and duck/cut its tail, outdoors optionally layer `gun_tail_outdoor`.",
            "- SFX are peak-normalised individually, so set per-sound volume in game (footsteps around -14 dB, "
            "UI around -10 dB, guns/explosions near 0 dB).",
            "- Stingers are designed to play over a ducked music bus.", ""]
    path = os.path.join(ROOT, "assets", "audio", "AUDIO.md")
    open(path, "w", encoding="utf8").write("\n".join(out))
    missing = [r["name"] for r in rows if not desc(r["name"])]
    print("wrote", path, "| missing descriptions:", missing or "none")


if __name__ == "__main__":
    main()
