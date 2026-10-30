# AFTERBLOOM audio manifest

All audio is generated offline and deterministically by the scripts in `tools/audio/`:

- `python tools/audio/gen_music.py` - score, stingers and radio records (scores in `score_main.py`, `score_action.py`, `score_radio.py`; engine in `mus.py`).
- `python tools/audio/gen_sfx.py` - every sound effect and ambience (`sfx_a.py`, `sfx_b.py`, building blocks in `sfxlib.py`, DSP core in `afx.py`).
- `python tools/audio/analyze.py all` then `python tools/audio/manifest.py` - verification + this file.

Format: OGG Vorbis, 44.1 kHz. Music is stereo, mastered to about -16 LUFS integrated (shelter_wake -17), true peaks <= -1 dBFS. SFX are mono and peak-normalised to about -1.3 dBFS (UI blips quieter by design); ambience loops are stereo. Files ending in `_loop` loop seamlessly (cyclic rendering: tails are wrapped onto the start, noise beds are FFT-periodic, oscillators complete whole cycles) - set `loop = true` on import in Godot. Non-loop files have short fades.

Total: 187 files, 44.0 MB.

## Instruments / licence

Music uses the **GeneralUser GS v2.0.3** SoundFont by S. Christian Collins (rendered with the `tinysoundfont` Python package), plus custom DSP (synthesised reverb, drones, mastering). Licence (from the bank's LICENSE.txt): *"You may use GeneralUser GS without restriction for your own music creation, private or commercial ... feel free to use it in your software projects."* The bank lives only in `tools/audio/sf/` (with its licence file); it is not shipped in assets. Rendered music contains no third-party copyrighted compositions - all themes and songs are original. All SFX are 100% procedural synthesis (no samples).

## Music (assets/audio/music/)

| File | Length | Loop | Description |
|---|---:|:---:|---|
| `boss_loop.ogg` | 1:26.2 | yes | Thornback fight: heavier D-Phrygian ostinato, concert bass drum, brass + orchestra hits, choir, horn/trumpet melody. |
| `coldopen.ogg` | 1:00.7 |  | Solo piano for Rory's narrated intro: the main theme, gently rubato, ends on a rolled D(add9) chord. |
| `combat_loop.ogg` | 1:30.0 | yes | Combat: C-minor string ostinato, taiko + toms, tremolo strings, horn motif (the theme's rising sixth turned anxious), breakdown section. |
| `dash_end.ogg` | 5.4 s |  | Final hit as the gate slams: timpani roll into a big D-major orchestral chord that tails off. |
| `dash_loop.ogg` | 1:26.7 | yes | The dash to Shelter No. 9: driving low-string ostinato, taiko/timpani, brass stabs, heroic horn melody, theme in D minor on trumpets. |
| `explore_day2_loop.ogg` | 2:24.0 | yes | Second exploration cue: 3/4 piano waltz figure with a new cello theme, flute + clarinet thirds, strings. |
| `explore_day_loop.ogg` | 2:30.0 | yes | Emotional core (G major): fingerpicked guitar, piano theme, vibes counter-line, violins carry the B theme, harp. |
| `explore_night_loop.ogg` | 2:00.0 | yes | Night: warm pads, slow harp, starry celesta twinkles with echo, flute quotes the main theme (E major). |
| `morning_loop.ogg` | 2:00.0 | yes | Cozy 1967 morning underscore: nylon guitar comp, vibes melody, brushed drums, upright bass in 2. Sparse so TV/radio sit on top. |
| `shelter_wake_loop.ogg` | 2:00.0 | yes | Shelter wake-up: periodic low synth drones, bowed-glass pads, distant metallic resonances, sparse celesta. Uneasy, not scary. |
| `sting_bloom.ogg` | 9.3 s |  | The Bloom hits: low string cluster and choir crescendo, reverse cymbal, timpani roll into a dissonant brass hit. |
| `sting_discover.ogg` | 6.3 s |  | Location discovered: harp glissando, Gmaj7#11 -> D shimmer, flute sigh. |
| `sting_ending.ogg` | 43.7 s |  | Hopeful finale: full theme with violins and horns, piano arpeggios, timpani build, final D chord. |
| `sting_levelup.ogg` | 3.8 s |  | Level up: bright glockenspiel/celesta arpeggio into a brass + strings D-major chord. |
| `sting_quest_done.ogg` | 5.7 s |  | Quest complete: theme cadence (Em7-A7-D) on celesta/piano, strings, horns, harp. |
| `sting_quest_start.ogg` | 4.9 s |  | Quest start: rising horn call over strings, harp flourish. |
| `sting_reunion.ogg` | 18.4 s |  | Tuppence sees you after 11 years: warm piano + strings on the opening of the main theme. |
| `title_loop.ogg` | 2:00.0 | yes | Title theme: wistful piano statement of the AFTERBLOOM theme (D major), slow strings, violin + celesta reprise, harp. |

## Radio records (assets/audio/music/radio/)

| File | Length | Loop | Description |
|---|---:|:---:|---|
| `a_little_lantern.ogg` | 1:47.2 |  | RADIO - "A Little Lantern", Rosa Dean. 3/4 waltz in G: celesta + music-box melody, pizzicato oom-pah-pah, harp, violins on the bridge, flute descant. |
| `coffee_for_two.ogg` | 2:13.0 |  | RADIO - "Coffee for Two", Mel Archer Trio. Piano trio in F: head AABA, piano solo chorus, walking bass, brushes, tag ending. |
| `highway_seventeen.ogg` | 2:02.1 |  | RADIO - "Highway Seventeen", Dusty Carlyle. Country-western shuffle in G: harmonica verse, Hawaiian steel chorus hook with slides, boom-chick bass/guitar. |
| `moonlight_on_gull_lane.ogg` | 2:20.4 |  | RADIO - "Moonlight on Gull Lane", Patsy Vale Quartet. Slow 12/8 doo-wop ballad in Eb: tenor sax lead with vibrato, piano triplets, oohs, AABA + outro. |
| `rocket_ride_shuffle.ogg` | 1:55.4 |  | RADIO - "Rocket Ride Shuffle", Benny Cole & the Satellites. Rockabilly/surf in E: twangy slap-back guitar head, boogie upright bass, guitar solo, sax honk chorus, tremolo-picked surf bridge. |
| `sunday_kind_of_gentle.ogg` | 2:28.3 |  | RADIO - "Sunday Kind of Gentle", The Halcyon Strings & Lou Marten. Lounge swing in Bb: vibes lead (AABA), walking bass, brushes, strings, piano solo, tag ending. |

## Sound effects (assets/audio/sfx/)

| File | Length | Loop | Description |
|---|---:|:---:|---|
| `amb_after_day_loop.ogg` | 1:00.0 | yes | 1978 overgrown town: wind, distant gulls, faint crystal chimes, insects. |
| `amb_bloom_loop.ogg` | 30.0 s | yes | Bloom squall: eerie shimmering harmonic hum, whispering air, crystalline pings. |
| `amb_house_morning_loop.ogg` | 40.0 s | yes | Inside the cottage, morning: birdsong muffled through windows, faint surf, room tone. |
| `amb_night_loop.ogg` | 40.0 s | yes | Night: crickets, distant surf, light breeze. |
| `amb_ocean_loop.ogg` | 48.0 s | yes | Waves on the shore with occasional distant gulls. |
| `amb_rain_interior_loop.ogg` | 30.0 s | yes | Rain on roof and windows heard from inside, gutter drip. |
| `amb_rain_loop.ogg` | 30.0 s | yes | Outdoor rain (stereo droplets). |
| `amb_shelter_drip_loop.ogg` | 30.0 s | yes | Water drips echoing in concrete corridors. |
| `amb_shelter_hum_loop.ogg` | 30.0 s | yes | Shelter ventilation hum, airflow, faint duct rattle. |
| `amb_storm_wind_loop.ogg` | 40.0 s | yes | Storm wind: gusts, howling resonances, low rumble. |
| `amb_town_day_loop.ogg` | 1:00.0 | yes | 1967 town day: birds, leaves in the wind, two distant cars, a far dog. |
| `bird_flock.ogg` | 2.4 s |  | Flock of birds taking off: wing flaps + a few calls. |
| `bloom_wave.ogg` | 10.0 s |  | The violet wall approaching: rising whoosh, shimmering crystalline chord, rumble (~10 s). |
| `bullet_flyby.ogg` | 0.5 s |  | Supersonic snap + doppler whizz of a near miss. |
| `car_alarm_loop.ogg` | 3.2 s | yes | 1960s horn-style alarm honking in rhythm. |
| `car_crash.ogg` | 3.4 s |  | Car crash: crunch, crumpling metal, glass, debris, hubcap rolling away. |
| `clock_tick_loop.ogg` | 4.0 s | yes | Mantel clock, tick-tock at 1 tick per second. |
| `crystal_shatter_1.ogg` | 1.2 s |  | Large crystal growth shattering. |
| `crystal_shatter_2.ogg` | 1.7 s |  | Large crystal growth shattering. |
| `cup_clink.ogg` | 0.7 s |  | Porcelain cup set on saucer. |
| `curtain_open.ogg` | 1.1 s |  | Curtain drawn: rings sliding along the rod + fabric swish. |
| `dog_bark_1.ogg` | 2.6 s |  | Distant dog barking. |
| `dog_bark_2.ogg` | 2.2 s |  | Distant dog barking. |
| `door_close.ogg` | 0.9 s |  | Door swings shut: thud + latch. |
| `door_knock.ogg` | 0.9 s |  | Three knocks on a wooden front door. |
| `door_open.ogg` | 1.2 s |  | Latch click, hinge creak, air movement. |
| `doorbell.ogg` | 3.5 s |  | Classic two-tone ding-dong door chime (E5 -> C5). |
| `dry_fire.ogg` | 0.2 s |  | Hammer click on an empty chamber. |
| `eat.ogg` | 1.1 s |  | Crisp bite and chewing. |
| `explosion_distant.ogg` | 5.0 s |  | Distant explosion: low boom + rumble. |
| `fridge_hum_loop.ogg` | 8.0 s | yes | 1960s refrigerator compressor hum. |
| `fuse_insert.ogg` | 0.4 s |  | Fuse pushed into socket: scrape, snap, small electric buzz. |
| `gate_klaxon_loop.ogg` | 2.8 s | yes | Shelter gate klaxon (ah-OO-ga style), two blasts per cycle. |
| `gate_open.ogg` | 6.5 s |  | Shelter gate opens: lock bolts, hydraulic hiss, heavy grinding, end clunk (~6 s). |
| `gate_slam.ogg` | 8.5 s |  | Shelter gate slams: huge metallic boom with long hangar tail. |
| `glass_break.ogg` | 1.6 s |  | Window pane breaking. |
| `gull_1.ogg` | 1.8 s |  | Seagull calls. |
| `gull_2.ogg` | 2.2 s |  | Seagull calls. |
| `gun_tail_indoor.ogg` | 1.0 s |  | Environment-only indoor/room tail (boomy short reverb). |
| `gun_tail_outdoor.ogg` | 4.0 s |  | Environment-only outdoor tail (echoes off buildings/hills + rolling rumble); layer under a dry shot. |
| `heal.ogg` | 2.0 s |  | Drinking a tonic: bottle glugs, fizz, faint restorative shimmer. |
| `heartbeat_loop.ogg` | 6.0 s | yes | Low-health heartbeat, 80 bpm lub-dub. |
| `hurt_1.ogg` | 0.4 s |  | Player hurt: subtle body thud + short wordless exhale/grunt. |
| `hurt_2.ogg` | 0.4 s |  | Player hurt: subtle body thud + short wordless exhale/grunt. |
| `husk_attack.ogg` | 0.9 s |  | Husk lunge: harsher exhale-roar with crystal rattle. |
| `husk_death.ogg` | 1.6 s |  | Husk dies: crystal shatter + long exhale. |
| `husk_groan_1.ogg` | 2.1 s |  | Husk groan: breathy, creaky, hollow resonant voice with a crystalline shimmer (eerie, not gory). |
| `husk_groan_2.ogg` | 2.6 s |  | Husk groan: breathy, creaky, hollow resonant voice with a crystalline shimmer (eerie, not gory). |
| `husk_groan_3.ogg` | 1.8 s |  | Husk groan: breathy, creaky, hollow resonant voice with a crystalline shimmer (eerie, not gory). |
| `impact_concrete_1.ogg` | 0.5 s |  | Bullet into concrete: crack, chips, dust hiss. |
| `impact_concrete_2.ogg` | 0.5 s |  | Bullet into concrete: crack, chips, dust hiss. |
| `impact_crystal_1.ogg` | 1.0 s |  | Bullet into Bloom crystal: glassy ring + tinkling shards. |
| `impact_crystal_2.ogg` | 1.0 s |  | Bullet into Bloom crystal: glassy ring + tinkling shards. |
| `impact_crystal_3.ogg` | 1.0 s |  | Bullet into Bloom crystal: glassy ring + tinkling shards. |
| `impact_dirt.ogg` | 0.5 s |  | Bullet into dirt: thud and soil spray. |
| `impact_flesh_1.ogg` | 0.3 s |  | Bullet into flesh: dull thud, slap, small wet squelch (not gory). |
| `impact_flesh_2.ogg` | 0.3 s |  | Bullet into flesh: dull thud, slap, small wet squelch (not gory). |
| `impact_metal_1.ogg` | 1.1 s |  | Bullet into metal: sharp ping with plate ring. |
| `impact_metal_2.ogg` | 1.1 s |  | Bullet into metal: sharp ping with plate ring. |
| `impact_wood.ogg` | 0.3 s |  | Bullet into wood: knock + splinters. |
| `journal_close.ogg` | 0.3 s |  | Journal closes: cover thump. |
| `journal_open.ogg` | 0.5 s |  | Journal opens: paper rustle + leather cover thump. |
| `jump.ogg` | 0.4 s |  | Jump push-off with clothing rustle. |
| `kettle_whistle_loop.ogg` | 4.0 s | yes | Kettle whistle with bubbling boil underneath. |
| `land.ogg` | 0.3 s |  | Landing thump with gear rattle. |
| `lever_pull.ogg` | 1.3 s |  | Heavy lever: ratchet clicks + clunk. |
| `light_switch.ogg` | 0.1 s |  | 1960s toggle light switch. |
| `lightning_crack.ogg` | 2.2 s |  | Lightning strike crack with sizzle. |
| `mite_attack.ogg` | 0.4 s |  | Mite leap: hiss, fast chitter, glass scrape. |
| `mite_chitter_1.ogg` | 0.6 s |  | Bloom mite chittering: rapid glassy mandible clicks. |
| `mite_chitter_2.ogg` | 0.8 s |  | Bloom mite chittering: rapid glassy mandible clicks. |
| `mite_chitter_3.ogg` | 0.5 s |  | Bloom mite chittering: rapid glassy mandible clicks. |
| `mite_death.ogg` | 0.7 s |  | Mite dies: wet pop + spore puff + shard tinkle. |
| `pa_chime.ogg` | 4.8 s |  | Three-tone public-address chime (G-E-C). |
| `page_turn.ogg` | 0.4 s |  | Paper page turn. |
| `phone_hangup.ogg` | 0.6 s |  | Handset set down on the cradle. |
| `phone_pickup.ogg` | 0.6 s |  | Bakelite handset lifted: hook switch click + bell tinkle. |
| `phone_ring.ogg` | 2.6 s |  | Bell telephone: one ~2 s ring burst (twin bells, 20 Hz hammer). |
| `pickup_1.ogg` | 0.3 s |  | Generic item pickup: rustle + soft clunk. |
| `pickup_2.ogg` | 0.2 s |  | Generic item pickup: rustle + soft clunk. |
| `pickup_ammo.ogg` | 0.3 s |  | Ammo pickup: rattle of cartridges. |
| `pickup_magazine.ogg` | 1.1 s |  | Magazine pickup: paper + small two-note chime. |
| `pistol_fire_1.ogg` | 2.2 s |  | Service pistol shot: N-wave crack, muzzle blast, body thump, slide cycling clicks, short outdoor slap-back tail. Variants differ in pitch/decay/echo. |
| `pistol_fire_2.ogg` | 2.2 s |  | Service pistol shot: N-wave crack, muzzle blast, body thump, slide cycling clicks, short outdoor slap-back tail. Variants differ in pitch/decay/echo. |
| `pistol_fire_3.ogg` | 2.2 s |  | Service pistol shot: N-wave crack, muzzle blast, body thump, slide cycling clicks, short outdoor slap-back tail. Variants differ in pitch/decay/echo. |
| `pistol_mag_in.ogg` | 0.3 s |  | Magazine slides in and seats with a firm clack. |
| `pistol_mag_out.ogg` | 0.3 s |  | Magazine release click, slide out, catch in palm. |
| `pistol_slide.ogg` | 0.5 s |  | Slide racked back and released forward. |
| `power_up.ogg` | 3.6 s |  | Power restored: big electrical hum rising, relays, whine, arc crackle. |
| `quest_update.ogg` | 1.5 s |  | Quest updated: typewriter keystrokes + bell ding. |
| `radio_click.ogg` | 0.3 s |  | Radio power knob click + valve hiss. |
| `radio_static_loop.ogg` | 6.0 s | yes | AM static/crackle between stations. |
| `radio_tune.ogg` | 2.6 s |  | Tuning dial sweep: static, heterodyne whistles, station fragments. |
| `ricochet_1.ogg` | 0.8 s |  | Ricochet: metallic ping + descending whine. |
| `ricochet_2.ogg` | 0.8 s |  | Ricochet: metallic ping + descending whine. |
| `rifle_bolt_close.ogg` | 0.5 s |  | Bolt pushed forward and locked down. |
| `rifle_bolt_open.ogg` | 0.5 s |  | Bolt handle up and drawn back. |
| `rifle_fire_1.ogg` | 2.5 s |  | Bolt-action rifle shot: louder crack, deeper body, receiver ring, longer outdoor echo tail. |
| `rifle_fire_2.ogg` | 2.6 s |  | Bolt-action rifle shot: louder crack, deeper body, receiver ring, longer outdoor echo tail. |
| `rifle_round_in.ogg` | 0.3 s |  | Cartridge pressed into the rifle's magazine. |
| `robot_beep_happy.ogg` | 0.5 s |  | Happy rising chirp. |
| `robot_beep_worried.ogg` | 0.7 s |  | Worried wobbling descending beep. |
| `robot_hover_loop.ogg` | 6.0 s | yes | Tuppence's gentle hover hum. |
| `robot_polish.ogg` | 1.2 s |  | Cloth squeaks: polishing strokes. |
| `robot_servo_1.ogg` | 0.6 s |  | Tuppence servo/actuator whine (warm, brassy). |
| `robot_servo_2.ogg` | 0.7 s |  | Tuppence servo/actuator whine (warm, brassy). |
| `robot_servo_3.ogg` | 0.5 s |  | Tuppence servo/actuator whine (warm, brassy). |
| `robot_zap.ogg` | 0.5 s |  | Tuppence's defensive zap: electric crack + arc buzz + sizzle. |
| `shell_1.ogg` | 0.6 s |  | Brass casing bouncing and rolling on hard ground. |
| `shell_2.ogg` | 0.7 s |  | Brass casing bouncing and rolling on hard ground. |
| `shell_3.ogg` | 0.7 s |  | Brass casing bouncing and rolling on hard ground. |
| `siren_loop.ogg` | 12.0 s | yes | Air-raid siren rising and falling (12 s cycle), distant reverb. |
| `spore_burst.ogg` | 1.1 s |  | Spore pod burst: pop, airy puff, glitter. |
| `step_carpet_1.ogg` | 0.2 s |  | Footstep on carpet/rug: muffled thump. |
| `step_carpet_2.ogg` | 0.2 s |  | Footstep on carpet/rug: muffled thump. |
| `step_carpet_3.ogg` | 0.2 s |  | Footstep on carpet/rug: muffled thump. |
| `step_carpet_4.ogg` | 0.2 s |  | Footstep on carpet/rug: muffled thump. |
| `step_concrete_1.ogg` | 0.2 s |  | Footstep on concrete: heel click, scuff. |
| `step_concrete_2.ogg` | 0.3 s |  | Footstep on concrete: heel click, scuff. |
| `step_concrete_3.ogg` | 0.3 s |  | Footstep on concrete: heel click, scuff. |
| `step_concrete_4.ogg` | 0.2 s |  | Footstep on concrete: heel click, scuff. |
| `step_grass_1.ogg` | 0.2 s |  | Footstep on grass: soft grainy crunch. |
| `step_grass_2.ogg` | 0.2 s |  | Footstep on grass: soft grainy crunch. |
| `step_grass_3.ogg` | 0.2 s |  | Footstep on grass: soft grainy crunch. |
| `step_grass_4.ogg` | 0.2 s |  | Footstep on grass: soft grainy crunch. |
| `step_gravel_1.ogg` | 0.3 s |  | Footstep on gravel: stone-grain crunch. |
| `step_gravel_2.ogg` | 0.3 s |  | Footstep on gravel: stone-grain crunch. |
| `step_gravel_3.ogg` | 0.3 s |  | Footstep on gravel: stone-grain crunch. |
| `step_gravel_4.ogg` | 0.3 s |  | Footstep on gravel: stone-grain crunch. |
| `step_metal_1.ogg` | 0.3 s |  | Footstep on metal grating/deck: clang + rattle. |
| `step_metal_2.ogg` | 0.3 s |  | Footstep on metal grating/deck: clang + rattle. |
| `step_metal_3.ogg` | 0.3 s |  | Footstep on metal grating/deck: clang + rattle. |
| `step_metal_4.ogg` | 0.3 s |  | Footstep on metal grating/deck: clang + rattle. |
| `step_wood_1.ogg` | 0.3 s |  | Footstep on wooden floorboards (variant 3 has a small creak). |
| `step_wood_2.ogg` | 0.3 s |  | Footstep on wooden floorboards (variant 3 has a small creak). |
| `step_wood_3.ogg` | 0.3 s |  | Footstep on wooden floorboards (variant 3 has a small creak). |
| `step_wood_4.ogg` | 0.3 s |  | Footstep on wooden floorboards (variant 3 has a small creak). |
| `sureshot_enter.ogg` | 2.2 s |  | SureShot engage: time-slowing whoosh and tape-stop tone dropping. |
| `sureshot_exit.ogg` | 1.6 s |  | SureShot release: reverse whoosh rising back to real time. |
| `sureshot_fail.ogg` | 0.3 s |  | SureShot not enough Focus: low double buzz. |
| `sureshot_queue.ogg` | 0.2 s |  | SureShot shot queued: two-note confirm blip. |
| `sureshot_target.ogg` | 0.1 s |  | SureShot body-part focus: soft tick. |
| `tea_pour.ogg` | 2.6 s |  | Tea pouring into a cup (resonance rises as it fills). |
| `thornback_charge.ogg` | 3.4 s |  | Thornback charge: accelerating stomps + rising roar. |
| `thornback_death.ogg` | 6.3 s |  | Thornback death: falling roar, collapse, bloom eruption shimmer + shatter cascade. |
| `thornback_roar_1.ogg` | 3.8 s |  | Thornback roar: huge layered growl with sub-octave and crystalline edge. |
| `thornback_roar_2.ogg` | 4.3 s |  | Thornback roar: huge layered growl with sub-octave and crystalline edge. |
| `thornback_stomp.ogg` | 1.6 s |  | Thornback stomp: deep impact, debris, ground rumble. |
| `thunder_far_1.ogg` | 7.0 s |  | Distant thunder: low rolling rumble. |
| `thunder_far_2.ogg` | 7.0 s |  | Distant thunder: low rolling rumble. |
| `thunder_near_1.ogg` | 7.5 s |  | Close thunder: crack then big rolling rumble. |
| `thunder_near_2.ogg` | 7.5 s |  | Close thunder: crack then big rolling rumble. |
| `toaster_pop.ogg` | 0.5 s |  | Toaster pops: spring twang + carriage clank. |
| `tv_off.ogg` | 0.8 s |  | TV off: pop, collapsing whine, discharge crackle. |
| `tv_on.ogg` | 1.9 s |  | Console TV on: knob, CRT degauss thump/hum, faint rising flyback whine, static. |
| `tv_static_loop.ogg` | 4.0 s | yes | Dead-channel TV static with faint 60 Hz buzz. |
| `ui_back.ogg` | 0.2 s |  | Menu back: descending two-blip. |
| `ui_click.ogg` | 0.1 s |  | Menu select: crisp mechanical click. |
| `ui_hover.ogg` | 0.0 s |  | Menu hover: tiny soft tick. |
| `water_spray_loop.ogg` | 6.0 s | yes | Burst hydrant spraying. |
| `wind_gust_1.ogg` | 3.5 s |  | Wind gust swelling and passing. |
| `wind_gust_2.ogg` | 4.2 s |  | Wind gust swelling and passing. |
| `xp_tick.ogg` | 0.1 s |  | XP gained: tiny rising tick. |

## Mixing notes for the game

- The radio records are clean and full-range; route them through the `Radio` bus for the band-pass/crackle.
- `pistol_fire_*` / `rifle_fire_*` already contain a short outdoor slap-back; for interiors play the shot with `gun_tail_indoor` and duck/cut its tail, outdoors optionally layer `gun_tail_outdoor`.
- SFX are peak-normalised individually, so set per-sound volume in game (footsteps around -14 dB, UI around -10 dB, guns/explosions near 0 dB).
- Stingers are designed to play over a ducked music bus.
