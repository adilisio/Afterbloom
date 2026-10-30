# Handoff, 2026-10-30

Where Afterbloom stands after playtest 2. Read `AGENTS.md` first for how to run, test and extend the game; this file only
covers what's current.

## State

- **Branch:** `playtest-2-fixes`, pushed to `origin`. `main` is still the initial commit.
- **Build:** `Play Afterbloom.bat` runs `build/Afterbloom.exe`, exported 2026-10-30 09:40. It has every playtest 2 fix. It
  doesn't include `HumanModel`, which nothing in the game uses yet. `build/` isn't committed, so re-export on a new machine.
- **Waiting on:** the owner's next playtest, or their go-ahead for the new opening.

## Done this round

| Playtest 2 note | Result |
|---|---|
| Stuck in the shelter after opening the doors | Fixed. Door leaves now move their colliders; floor gap, ledge and dirt slope fixed |
| Ramp and door gaps, plank across doorways, floating items, hole by the bunk | Fixed in `shelter.gd` and `town.gd`; leak test finds 0 holes, audit finds 0 floating items |
| Radio, TV and Tuppence all at once; subtitles during conversations | TV and radio duck when anyone talks and their subtitles are hidden (`Audio.foreground_busy`) |
| Registrar clipping through the clipboard and scenery | Fixed in `registrar_model.gd`; new exit route in `story.gd` `_registrar_leave` |
| Floating pistol | First-person hands (`view_arm.gd`). Owner: "good enough for now" |
| SureShot is a bad VATS | Removed. Perks that used it now affect recoil, headshot damage and healing |
| Screenshot notes request | F12 saves a screenshot and note to `playtest/<date>/` (`feedback.gd`) |

Also fixed, found along the way: kerbs and ledges up to 36 cm can be stepped up (`Player.STEP`), and the front-yard fence and
path no longer stand on Gull Lane.

## Not done

- **New opening (approved, not started):** `docs/PLAN_new_opening.md`. Don't start until the owner says go. It answers three
  playtest notes: the intro is too like FO4, "why did I rest for 11 years?", and the empty shelter. Those three stay
  unanswered in the game until it's built.
- **Shelter population:** the owner wanted to clarify something about this and never said what. Ask before building the
  crowded shelter in the plan.
- **"Lots of visual mistakes":** only the items the owner listed were fixed. F12 notes should catch the rest next round.

## HumanModel (built, not wired in)

`src/actors/models/human_model.gd`; API in `src/actors/models/README.md`. Tested only on the test stage: compile clean, 20/20
API checks, about 1.1 ms per frame for 30 people on an RTX 4060 laptop at 1440p. It averages 7,062 tris against a target of
about 7k.

Fix before close-up dialogue uses it:
- Jagged triangles at June's collar and a rough edge on her fringe (seen in `human_face_june_34.png`).
- Lips go soft closer than about 0.5 m.
- Polka dots and other patterns break where a garment turns from front to side.

Also, each new mesh takes 60–110 ms to build on the main thread, so build crowds during a load.

## Verification

Last run 2026-10-30:
- Compile check: clean, 47 scripts.
- `--story=test_gun --auto --enemy=husk`, `--story=ch1 --auto`, `--story=ch3b --auto`: no script errors. These ran before
  `HumanModel` landed; it's unused, so only the compile check covers it.
- `tests/shelter/shelter_tour.tscn`: `walk` and `kerb` pass.

**No person has played these fixes yet.** All of the above is automated.

## First steps next session

1. Check `playtest/<date>/notes.md` for new F12 notes. Each one has a `repro` line; rerun it with
   `--shot=view --view=x,y,z,yaw,pitch --era= --hour=` to see the same view. `playtest/` is gitignored, so notes only exist on
   the machine that took them.
2. On a fresh clone, run `git lfs install` before cloning, then `--headless --import --path .` once. New `class_name`s need that
   import too.
3. ElevenLabs credits are real money. Run `tools/.venv/Scripts/python tools/eleven_api.py` before any voice batch; the opening
   needs a lot of new lines.
