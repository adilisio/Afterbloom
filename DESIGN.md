# AFTERBLOOM — Design

A first-person story game (Godot 4.7, Forward+, GDScript) built from the player's notes on what
makes the first 20 minutes of a classic post-apocalyptic RPG work. **Original universe.**

## Pillars (from the notes)

| Note | How Afterbloom delivers it |
|---|---|
| Cozy start, warm & familiar | Sunny autumn morning in a seaside cottage. Toast, kettle, radio, cat-clock ticking. |
| Polished, believable home & props | Real CC0 photoscanned furniture/props (Poly Haven), PBR, SSAO/SSIL/SDFGI, sunbeams through windows. |
| Fun robot to own, cheery opposite of bleak world | **Tuppence**, a brass Halcyon Valet Mk II. Voiced, animated, chatty, makes tea, zaps monsters, polishes things. |
| TV feels ambient | Halcyon **Starlight** console TV with a live 2D show (morning program, ads, then emergency broadcast) on a CRT shader. |
| "Radiation King feels legit" | **Halcyon Electric Co.** — one brand on everything: TV, radio, robot, shelter, posters, magazine ads, manuals. Slogan: *"Halcyon — Tomorrow, Made Gentle."* |
| Dash to the vault feels real | Sirens, PA loudspeakers, a violet wall of Bloom rolling in from the bay, a 90s gate countdown, the gate slamming behind you. |
| Story starts quick & grabs you | Narrated cold open, the event happens ~5 min in, wake 11 years later to an empty shelter and your sister's note. |
| Quest guidance | Compass bar with markers, in-world waypoint diamond with distance, objective tracker, quest-start/complete banners. |
| Collecting items feels like progress | Loot feed, XP for pickups/discoveries/kills, level-ups, magazines with perks, journal inventory. |
| Combat solid, guns feel real | Photoscanned service pistol & bolt-action rifle, recoil/kick, ADS, reload anims, shells, impacts, layered gunshot audio with tails. |
| VATS is cool | **SureShot** (Halcyon targeting monocle): time nearly stops, body parts show hit %, queue shots with Focus, cinematic execution. |
| Unique enemy deaths | Husks shatter into crystal shards, limbs/heads burst off, mites pop in spore puffs, the Thornback collapses in a bloom eruption. |
| Good camera for dialogue | Cinematic framing on speaker, letterbox, shallow DOF, 4 choices. |
| Radio & DJ | Pocket transistor radio. **Larkhaven Free Radio**: DJ Rory Tuck, nervous & sweet, broadcasting alone from the lighthouse. Songs + DJ breaks. |
| Magazines are cool | 8 collectible magazines with full covers; each grants a permanent perk. |
| Day/night, weather | Real sky with sun/moon/stars/clouds; clear, overcast, rain, storm (lightning), and the setting's own **Bloom squall** (violet glowing spores). |
| Voiced lines | Neural TTS for every character line; robot/radio/TV processed through audio buses. |
| Music not too bleak | Warm, hopeful exploration score (piano, strings, vibes) contrasting the ruined town; jaunty 1950s-60s radio songs. |

## World

- **Larkhaven**, a small Pacific coast town, autumn of an alternate **1967** (retro-futurist: valve electronics, robots, chrome).
- **Halcyon Electric Co.** makes everything; sells "Halcyon Assured" community shelters (No. 9 is in the bluff above town).
- **The Bloom**: the night before, the Larkspur Comet passed close. At dawn, violet dust falls on the Pacific. By mid-morning
  a luminous violet spore fog rolls in from the sea. Living things caught in it become **Bloomed** — crystal-flowered husks.
- **11 years later (1978)**: the Bloom has thinned to drifting motes; violet crystal flowers grow everywhere; the town is overgrown.

### Cast (voice = edge-tts neural voice)

| Who | Role | Voice | Bus |
|---|---|---|---|
| Tuppence | Halcyon Valet Mk II, the player's robot. Cheerful, proper, a little anxious, endlessly optimistic. | en-GB-RyanNeural | Robot |
| June | Player's younger sister. Warm, teasing, brave. Phone call + recorded message. | en-US-AvaNeural | Phone |
| Rory Tuck | Junior DJ in 1967; in 1978 the lone voice of Larkhaven Free Radio, from the lighthouse. | en-US-AndrewNeural | Radio |
| Dot Calloway | 1967 morning DJ, sunny. | en-US-EmmaNeural | Radio |
| Hal Brightwater | TV anchor, "Larkhaven Morning" / emergency broadcast. | en-US-ChristopherNeural | TV |
| Registrar 9 | Halcyon shelter courier robot at the door. | en-US-EricNeural | Robot |
| Shelter PA | "Halcyon Assurance" automated voice. | en-US-AriaNeural | PA |
| Civil Defense | Town loudspeakers. | en-US-GuyNeural | PA |

## Story & flow (~25 min)

1. **Cold open** — black screen, Rory (older) narrates over a gentle piano: *"Everybody in Larkhaven remembers what they were doing that
   morning..."* Title card.
2. **Ch.1 Good Morning** (house + Gull Lane, 1967, 8:40 AM, clear). Tuppence opens the curtains. Pick how he addresses you.
   Objectives: get up → (optional: tea, TV, radio, magazine, photos) → answer the door (Registrar 9; 3 playful questions → starting
   perk) → phone rings (June: meet her at Shelter No. 9's open house / the comet dust is weird) → TV news turns grave.
3. **Ch.2 The Bloom** — sirens. Emergency broadcast. Tuppence: shelters are residents-only, "appliances remain above ground".
   He pushes you out the door. Dash up Gull Lane and the bluff road: loudspeakers, car crash, birds fleeing, violet wall
   rolling across the bay, gate countdown. Gate slams. Tuppence's voice through the closing gap: "I'll keep the kettle warm!"
4. **Ch.3 Shelter No. 9** — PA welcome, assigned bunk, Somnol rest cycle. Fade. Montage of years (PA date stamps, radio
   fragments). Wake: red emergency light, silence, crystal growth through a breach. June's bunk is empty; her note: *"They said we
   couldn't wake you. We're going to the lighthouse — Rory's radio. Follow the music. — J."* Find the service pistol in the
   warden's office, fight mites, restore door power, open the gate.
5. **Ch.4 Afterbloom** — blinding daylight (auto-exposure), overgrown Larkhaven below. Go home. Tuppence, polishing the
   same spot for 11 years, is overjoyed. He joins you and gives you your pocket radio. Rory's broadcast mentions survivors
   at the lighthouse. Journey through Harbor Square (husks, loot, rifle at the Civil Defense post, magazines) along the coast
   road to the lighthouse. **Thornback** ambush → SureShot showdown. Rory over the intercom; the door opens; June's voice.
   *"To be continued."* Then free roam continues with day/night and weather.

## Systems

- **Player**: walk/sprint/jump/crouch, head-bob, surface footsteps, interact (E), flashlight (F), journal (Tab), radio (R hold / journal).
- **Weapons**: service pistol (8 rnd), bolt-action rifle (5 rnd, scope zoom). Hitscan, per-part damage, impact FX per surface.
- **SureShot** (Q): Focus meter; time scale 0.03; target parts with %; click to queue; Space to execute.
- **Enemies**: Bloom mite (small, fast, leap), Husk (shambling humanoid, lunge), Thornback (boss quadruped, charge).
- **Companion**: Tuppence follows, idles, barks, zaps enemies (cooldown), "make tea" heals once per in-game hour.
- **Quests**: data-driven; compass + waypoint + tracker; banners.
- **Inventory/XP**: items with weight-free categories (Aid, Ammo, Junk, Magazines, Keys); XP, levels (+max HP).
- **Time & weather**: 1 real min = 12 game min (adjustable). Weather state machine.
- **Save**: checkpoint autosave at chapter starts + manual save in journal; Continue on title.

## Audio buses

`Master` → `Music`, `SFX`, `Ambience`, `Voice` (dry), `Robot` (EQ + light chorus/distortion), `Radio` (band-pass + crunch),
`TV` (band-pass + small room), `PA` (band-pass + long delay/reverb), `Phone` (narrow band-pass).

## Project layout

```
assets/models/<polyhaven_id>/        CC0 models (gltf)
assets/textures/<polyhaven_id>/      CC0 PBR textures
assets/textures/gen/                 generated 2D art (magazines, posters, signs, logos)
assets/audio/music|sfx|voice/        generated audio
data/lines.json                      every voiced line (id, speaker, text)
src/autoload/                        game.gd, audio.gd
src/player/ src/actors/ src/world/ src/ui/ src/props/
tools/                               python generators (audio, voice, art, asset fetch)
```

## Testing

`Godot_v4.7.2-stable_win64_console.exe --path . -- --shot=<scenario>` renders a scenario and writes `shots/<scenario>.png`.
