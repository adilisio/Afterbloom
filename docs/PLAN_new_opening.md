# Planned: new opening (from playtest 2) — approved, NOT started

Status: the owner approved this outline on 2026-10-30 and asked to keep it for future work. Don't start it until they say so.

## Why

Playtest 2 notes:
- "Intro is too similar to FO4": the narrated cold open, waking in bed with the robot butler, and the shelter
  rep's questionnaire at the door.
- "Why did I rest for 11 years?"
- "Shelter is weird, no other people?"

The owner picked all four changes: new cold open, cut the door questionnaire, rework the sleep, change the morning.

## Outline

1. **Prologue: Comet Night (playable; replaces the narrated slideshow `co_1..co_4`).**
   - Friday 13 Oct 1967, ~22:00, on the bluff meadow above town (near the Shelter No. 9 portal / `bluff_view`).
     Townsfolk are out on blankets with thermoses.
   - You arrive with Tuppence, who carries the picnic basket. Tuppence asks how to address you (move `tp_addr_q`
     here; the "firmware update" joke still works).
   - Meet **June** in person. She's volunteering at tomorrow's Shelter 9 open house.
   - Meet **Rory** (19), doing a live "Comet Watch" remote for Larkhaven Free Radio. He puts you on air.
   - **Traits come from these conversations** (June, Rory), not from a questionnaire.
   - Registrar 9 stays as a background robot at an open-house table, handing out resident cards (you get No. 31).
     No quiz.
   - The comet passes, the crowd cheers, and its tail sheds a faint violet shimmer over the sea (foreshadowing).
     June: "See you tomorrow. Bring Tuppence's cookies." Fade, then the title logo.
2. **Saturday morning (no waking in bed).**
   - Start on the harbor pier with Tuppence. Fishermen show you the violet "glitter" on the water.
   - Walk home through a busy Gull Lane: neighbours out, TV in a shop window, Dot on radios through open windows.
   - At home, the cozy part stays (the owner liked the decorations): TV, radio, tea, magazines, photos. Pick up the
     cookie tin for June.
   - June's phone call (rewrite: she's at the open house), the TV turns grave, sirens.
3. **Ch.2 dash:** as now, but townsfolk run for the gate too, and shelter staff wave people in.
4. **The sleep, reworked (answers "why 11 years").**
   - The Bloom's leading edge catches you at the gate: violet screen, coughing.
   - Inside, the shelter is crowded (townsfolk, kids, Warden Haskell, staff), and June is there in person.
   - A medic sees violet veins on your hands (the first-person hands exist now). Somnol stasis slows the Bloom, so
     they put you in a stasis pod in a new **infirmary** room. June holds your hand: "I'll be right here when you
     wake up."
   - Montage: PA date stamps plus June's visits ("Day 40, your readings are stable", "Year 3, they say waking you
     would let it bloom").
   - Year 11: the Bloom in your blood goes inert (or pod power fails), and the emergency wake fires.
5. **Ch.3 wake:**
   - You wake in the pod in the infirmary.
   - Ward A is now the dormitory, with 11 years of abandoned life: cots, laundry lines, kids' drawings, a calendar
     stopped in 1976.
   - Rewrite June's note ("waking you would have killed you... we're going to the lighthouse") and the warden's logs.
   - Then the pistol, mites, power and exit, as now.

## What it needs

- **HumanModel** (procedural townsfolk, plus June, Rory and Warden presets): `src/actors/models/human_model.gd`,
  built 2026-10-30, not wired in. Close-up flaws to fix first are listed in `docs/HANDOFF.md`.
- **New voice lines** in `data/lines.txt`: the prologue (June, Rory, Tuppence), fishermen and townsfolk, a medic,
  June's visits, and rewritten June/warden/PA lines. New speakers need `CAST` entries in `tools/gen_voice_eleven.py`.
  Check ElevenLabs credits first (`tools/eleven_api.py`).
- **World:**
  - Night comet in the sky (sky_weather) and the bluff picnic set dressing.
  - An infirmary room and stasis pod in `shelter.gd`. It must stay inside the terrain NaN hole (x 178..262,
    z -128..-68); rerun `tests/shelter/shelter_tour.tscn` leaks/audit/walk.
  - Crowd placement for ch1/ch2/ch3.
- **Story:** new checkpoints (e.g. `prologue`), rewrite of `cold_open`, `ch1_*` and `ch3_*`, and the autopilot hooks.
- **Removes:** the narrated cold open, the bed wake-up, the Registrar quiz (`rg_q*`), and bunk-31 cryo as a choice.
- **Fixes known issue 4** (Ward B didn't exist).
