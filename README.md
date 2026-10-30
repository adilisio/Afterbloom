# Afterbloom

A first-person story game set in Larkhaven, a small seaside town in an alternate 1967. It's a cozy Saturday morning with your
brass robot butler, Tuppence, until a violet cloud called the Bloom rolls in off the sea. You reach Shelter No. 9 just in time,
and wake up eleven years later, alone.

## How to play

Double-click **`Play Afterbloom.bat`**, or run `build\Afterbloom.exe` directly.
To work on it, open this folder in Godot 4.7 and press F5. The game starts in fullscreen; change that under Settings.

## Controls

| Key | Action |
|---|---|
| W A S D | Move |
| Mouse | Look |
| Shift | Sprint |
| Ctrl / C | Crouch |
| Space | Jump |
| E | Use / talk / read / skip a line |
| 1–4 | Pick a dialogue choice |
| 1 / 2 | Pistol / rifle (once you have them) |
| H | Holster |
| Left mouse | Fire |
| Right mouse | Aim (rifle: scope) |
| R | Reload |
| Q | **SureShot**: freeze time and target body parts (costs Focus). In SureShot: click a part or press 1–4 to queue shots, A/D to switch target, Space to fire, Q to cancel |
| X | Use the best healing item |
| F | Flashlight |
| T | Pocket radio (once Tuppence gives it back) |
| Tab | Field Journal: quests, items, magazines, character, radio |
| Esc | Pause / settings |

## What's in it

- **Cozy start:** wake up in your cottage. Tuppence opens the curtains and asks how to address you. He makes tea, tells jokes and
  comments on things.
- **Your home:** the Halcyon Starlight TV plays the morning show. The kitchen radio plays Dot Calloway's show on Larkhaven Free
  Radio. There's a newspaper to read and magazines to find.
- **The Registrar:** a robot comes to the door and asks three questions. Your answers set your starting traits.
- **The dash:** sirens, Civil Defense loudspeakers, a car crash, gulls fleeing, and a violet wall of Bloom rolling across the bay
  while you race to the shelter gate.
- **Shelter No. 9:** you go to sleep and wake 11 years later. Find June's note and the warden's recordings, take the pistol,
  fight Bloom mites, and restore power to the door.
- **Larkhaven, 1978:** go home and find Tuppence, who has waited for you all this time. He joins you and returns your pocket
  radio. Follow Rory Tuck's broadcast to the lighthouse, fight Husks in the town square, find the rifle at the Civil Defense
  post, and face the Thornback. After the ending you can keep exploring.
- **Systems:** compass and waypoint quest guidance, XP and levels, 8 magazines with perks, unique enemy deaths, cinematic
  dialogue camera, day/night cycle, and weather (clear, cloudy, rain, storm, fog, and violet Bloom squalls).

## Credits and tools

- **3D models and PBR textures:** [Poly Haven](https://polyhaven.com) (CC0).
- **Robot and creatures:** built procedurally in code.
- **2D art:** magazines, posters, signs, TV graphics and wallpapers, generated with Python/Pillow (`tools/art`).
- **Music:** composed in code and rendered with the GeneralUser GS SoundFont (see `assets/audio/AUDIO.md`).
- **Sound effects:** synthesized (`tools/audio`).
- **Voices:** Microsoft neural TTS via `edge-tts` (`tools/gen_voice.py`). To regenerate after editing `data/lines.txt`, run
  `tools\.venv\Scripts\python tools\gen_voice.py`.

## For development

- Design notes: `DESIGN.md`.
- Screenshot harness:
  - `Godot_v4.7.2-stable_win64_console.exe --path . -- --shot=home_living,street` renders named views (see `SHOTS` in `src/main.gd`).
  - `--story=ch2 --auto --times=10,30` runs the story with an autopilot and captures frames.
- After changing roads or building lots in `src/world/layout.gd`, delete `data/terrain_cache.bin`; it is rebuilt on the next run.
- Export: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/Afterbloom.exe`
