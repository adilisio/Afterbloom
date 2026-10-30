# Procedural actors (`src/actors/models/`, `src/actors/fx/`)

Every character is assembled in code from primitive meshes and custom `SurfaceTool` geometry, without CSG or rigged assets. Each one is animated procedurally in `_process`.

Every model:
- `extends Node3D`, has a `class_name`, and builds itself in `_ready()`.
- Has its origin at the feet and faces **-Z**.
- Has no per-frame allocations in its hot loops.

Triangle counts (from `tests/actors/tri_count.tscn`):

| Class | Tris |
|---|---|
| TuppenceModel | ~30.8k |
| RegistrarModel | ~20.6k |
| ThornbackModel | ~13.6k |
| HuskModel | ~7.2–8.2k (varies by variant) |
| MiteModel | ~4.3k |
| GullModel | ~1.2k |

## Conventions shared by all enemies

- **Hitboxes:** one or more `Area3D` per part, parented to the animated bone so they follow it.
  - Layer and mask: `collision_layer = 8` (layer 4), `collision_mask = 0`.
  - Flags: `monitoring = false`, `monitorable = true`.
  - Metadata: `meta("part")` is the part name and `meta("actor")` is the model.
  - The game's hitscan should raycast with mask 8 (plus world) and read `collider.get_meta("part")` and `collider.get_meta("actor")`.
- **Hit direction:** `play_hit(part, from_dir)` and `die(part, impulse)` take a **world** direction that points the way the shot travels (shooter → target). The actor is knocked along it, and the length of `impulse` scales the effect.
- **Death:**
  - `die()` is safe to call from physics callbacks. It disables the hitboxes at once and defers the rest.
  - The model then **reparents itself to `get_tree().current_scene`** (keeping its global transform), so the controller or `CharacterBody3D` that owned it can be freed right away.
  - Debris is made of `DebrisBody` rigid bodies on collision layer 0 with mask 1 (they collide with world geometry only). Debris shrinks away after about 6–10 s.
  - After about 9–11 s the model emits `signal finished` and calls `queue_free()` on itself.
- **Timing:** `play_attack()` returns its duration, and the hit lands at about 40–50% of it.
- **Movement:** models never move their own root. The game moves the parent; at most the body lunges forward inside the model's own space.

## Shared helpers

### `BloomKit` (`src/actors/fx/bloom_kit.gd`): the look of the Bloom
| Function | What it does |
|---|---|
| `crystal_material(glow := 1.0) -> Material` | Cached violet crystal shader. Opaque, with a fresnel rim, an inner glow that grows toward the tips (vertex colour R), faceted sparkle and a slow pulse. |
| `flower_material(glow := 1.0)` | Two-sided crystalline petal shader driven by vertex colour (rgb is albedo, a is the glow mask). |
| `spore_material(intensity, core)` | Additive billboard mote material with a soft depth fade, for `GPUParticles3D`. |
| `make_crystal_cluster(rng, size := 1.0) -> MeshInstance3D` | 3–9 faceted hexagonal crystals with pointed tips (at most about 170 tris). |
| `make_bloom_flower(rng, size := 1.0) -> MeshInstance3D` | A glowing violet flower with a stem, leaves, two whorls of faceted petals and a glowing pistil (about 100 tris). |
| `cluster_mesh(seed, size) -> Mesh` / `flower_mesh(seed) -> Mesh` | Cached and single-surface, with the material already baked onto the surface, so they can go straight into `MultiMeshInstance3D`. |
| `crystal_into(st, base, dir, length, radius, twist)` | Appends one crystal to your own `SurfaceTool`; use it with `crystal_material()`. |
| `shard_mesh(variant)` | Single shard meshes, 6 cached variants. |
| `spawn_shards(parent, at, count, impulse, scale := 1.0)` | Rigid-body shards that tumble, settle and shrink away after about 6 s, plus a spore puff. |
| `spawn_spore_puff(parent, at, scale := 1.0)` | A one-shot burst of glowing motes plus a soft cloud and a violet light flash. Frees itself. |
| `attach_spore_trail(node, local_pos, duration)` | A trickle of glowing motes from a wound or stump that follows `node`. |

### `ModelKit` (`src/actors/models/model_kit.gd`)
- **Materials (cached):** `brass(aged)`, `copper(aged)`, `chrome()`, `enamel(key, color, rough)`, `rubber()`, `glass(key, tint)`, `glow(key, color, energy, unique)`, `fabric(key, color)`, `pbr(key, ...)` and `noise_tex(...)`.
- **Mesh builders:**
  - `lathe(profile, segs, a0, a1)`: a surface of revolution; repeat a point to make a crease, and use partial arcs for panels.
  - `rounded_box(size, r)`
  - `tube(path, radii, sides)`: a swept tube using parallel-transport frames.
  - `dent_mesh()`
  - `rivet(r)`
- **Cached primitives:** `sphere`, `cyl`, `capsule`, `torus`, `box`.
- **Rig and debris helpers:** `pivot()`, `mi()`, `multimesh()`, `add_hitbox(bone, part, actor, shape)`, `make_debris(node, world, lin_vel, ang_vel, life)`, `world_of()` and `strip_hitboxes()`.
- **Animation math:** `damp()`, `env()`, `ramp()` and `ease_back()`.

### `DebrisBody` (`src/actors/fx/debris_body.gd`)
A `RigidBody3D` that keeps the look of the part it detached from, then freezes and shrinks away after `life` seconds and frees itself.

### `ZapArc` (`src/actors/fx/zap_arc.gd`)
- `ZapArc.spawn(parent, from_world, to_world, duration := 0.4, color := cyan) -> ZapArc` draws a flickering electric arc made of camera-facing ribbons, with branching forks and a flash light.
- Set `follow_from` to a node to keep the start of the arc attached to it.
- Tuppence's `zap` gesture uses it, and the game can use it for the actual damage effect too.

---

## `TuppenceModel`: the Halcyon Valet Mk II
About 1.55 m to the top of the dome and about 1.62 m to the antenna bulb. He hovers about 15 cm off the floor on a thruster base.

**Looks:**
- Polished brass "samovar" barrel body with copper rivet bands.
- Cream enamel front panel with a chrome grille, a pressure gauge whose needle moves, Bakelite knobs and a "TUPPENCE" nameplate.
- Glass bell-jar head with a filament face: amber eyes with glowing brows, and a smile or VU-style talk bar for a mouth.
- Ear cans, a springy antenna with a bulb, a red bow tie and a wind-up key on his back that turns.
- Three-fingered arms, a green gingham tea towel draped over the left forearm, and a glowing thruster with a plume and a warm light on the ground.

| API | Notes |
|---|---|
| `var aged := false` / `set_aged(b)` | 11 years later: patina on the brass and copper, grimy enamel, a dent in the right flank, a greyed towel and an eye bulb that occasionally flickers. Can be changed at any time. |
| `set_move_speed(v)` 0..1 | Leans forward, the thruster and plume get brighter, the arms swing and the antenna lags. |
| `set_talking(b)` | Mouth bar opens in syllable-like bursts with pauses, the head bobs, he makes occasional hand gestures and the inner light pulses. |
| `play_gesture(name) -> float` | One of `wave`, `bow`, `tea`, `polish`, `zap`, `fret`, `celebrate`, `point`, `curtains`, `nod`. Returns the duration; an unknown name returns 0 with a warning. Emits `gesture_finished(name)`. |
| `look_at_point(world_pos)` / `clear_look()` | Head (yaw ±72°, pitch -34° to +31°) and eyes track the point smoothly, and the torso follows slightly. |
| `set_eye_color(c)` | Normal is `TuppenceModel.EYE_AMBER`. Use paler for worried. The zap sets cyan automatically, and the mouth, inner light and brows follow the eye colour. |
| `set_expression("neutral"/"happy"/"worried")` | Extra. Happy squints the eyes and raises the brows; worried tilts the brows and turns the mouth down. Some gestures set these temporarily. |
| `get_head_node()`, `get_hand_node(right := true)` | The hand node is a grip point at the palm (the teacup and rag attach there). |
| `is_gesturing()`, `is_talking()` | |

Gesture durations in seconds:

| Gesture | Duration | Notes |
|---|---|---|
| wave | 2.6 | |
| bow | 2.2 | |
| tea | 3.8 | Holds out a cup and saucer with steam. |
| polish | 3.6 | Circles a rag; the towel leaves his arm. |
| zap | 1.5 | Arc fires at 0.45 s, toward the look target if one is set, otherwise 2.6 m forward. |
| fret | 2.8 | |
| celebrate | 2.8 | Arms up and a full spin. |
| point | 2.0 | |
| curtains | 2.6 | |
| nod | 1.1 | |

When he's idle he never stands still: the hover bobs and sways, the head makes random tilts and glances, he blinks (sometimes twice), his arms drift, the antenna springs, the needle jitters and the key turns.

## `RegistrarModel`: Registrar 9, the shelter courier
About 1.7 m tall.

**Looks:**
- Teal and cream enamel with chrome trim.
- Boxy chest with a ticket printer slot, a speaker grille that lights up when it talks, indicator lamps, dials and a "HALCYON" badge.
- A drum head with one big green "magic-eye" camera lens whose shadow wedges move when it talks or blinks.
- A courier cap with a beacon, a wheeled base with a front caster, a clipboard in the left hand and a rubber stamp in the right.

**API:**
- `set_talking(b)`
- `play_gesture("bow" | "stamp" | "nod") -> float`, lasting 2.2, 2.4 and 1.1 s. During `stamp` the stamp hits the clipboard at about 1.1 s and a ticket prints out of the chest slot.
- `look_at_point(p)` and `clear_look()`
- `get_head_node()`
- Extra: `set_move_speed(v)` spins the wheels, and the signal `gesture_finished(name)`.

## `MiteModel`: Bloom mite
A crystalline tick or crab about 0.9 m long.

**Looks:**
- A faceted crystal-shell carapace with crystals growing from the abdomen.
- A glowing, pulsing violet underbelly plus a small under-light.
- Four glowing eyes and mandibles that chitter.
- Six two-segment legs.

**Movement:** a tripod gait using two-bone IK, so the feet stay planted while the body bobs, sways and pitches.

**API:**
- `set_locomotion(s)`
- `play_attack()`, 0.9 s: rears up, then lunges and snaps; the hit lands at about 45%.
- `play_hit(part, from_dir)`
- `play_emerge()`, 1.6 s
- `die(part, impulse)`, `get_part_node()`, `get_parts()` and the signal `finished`.

**Parts:**
- `body`: one box hitbox.
- `head`: one sphere hitbox.
- `legs`: 12 capsule hitboxes, one per leg segment. `get_part_node("legs")` returns a marker at the average knee position.

**Deaths:** the mite flips onto its back and curls its legs while they twitch, then the belly glow fades.
- `head`: the head flies off trailing spores.
- `legs`: the two legs on the hit side sever and it rolls onto that side.
- `body`: the shell plates burst off in shards and a spore puff.

## `HuskModel`: Bloomed human
About 1.8 m tall, gaunt and hunched.

**Looks:** cracked grey-lilac skin with glowing seams, violet crystals on the back, shoulder, head and one forearm, fungal nodules and small flowers, and a glowing bloom where the face was.

**Variants:** `@export var variant := 0..2`, or `set_variant(v)` before `add_child`.
- 0: trench coat and pork-pie hat.
- 1: gingham dress, cardigan and hair bun.
- 2: shirt, braces, bare forearms and a crystal crown.

**API:**
- `set_locomotion(s)`: a shamble where the left leg drags, the hips limp and the arms swing, with idle twitches. At 1.0 it becomes a lurching run with the arms reaching forward.
- `play_attack()`, 1.2 s: a two-arm lunge; the hit lands at 0.54 s.
- `play_hit(part, from_dir)`: a reaction for each part.
- `play_emerge()`, 2.6 s: claws up from 1.75 m below the ground.
- `die(part, impulse)`, `get_part_node(part)`, `get_parts()`, `is_dead()` and the signal `finished`.

**Parts:** `head`, `torso`, `arm_l`, `arm_r`, `leg_l`, `leg_r`. The hitboxes are a sphere for the head, two capsules for the torso, and two capsules for each limb.

**Deaths:**
- `head`: the bloom swells and bursts into spores and shards, the neck trails spores, and the body crumples to its knees and topples.
- `arm_*` or `leg_*`: that limb snaps off and flies, trailing spores. The body staggers and falls, toward the missing leg if a leg was hit.
- `torso`: violet light builds in the chest, then the body shatters from the inside. The head and arms fly off, crystal chunks burst out and the legs topple.

## `ThornbackModel`: the boss
A Bloomed elk and bear hybrid, about 2.7 m at the shoulder and about 4.2 m long. It has heavy shoulders and a low head, crystal antlers, a ridge of large glowing crystal thorns along its spine (the weak point), and a shaggy dark hide with pale lichen.

**API:**
- `set_locomotion(s)`: a walk that becomes a gallop above about 0.45.
- `play_attack()`, 1.7 s: rears up and slams; the hit lands at 0.75 s, with shards and spores at the paws.
- `play_roar()`, 2.4 s: jaw open with a glowing mouth, a spore breath, and the thorns flare.
- `play_charge_windup()`, 1.5 s: head down, paw scrapes and snorts, the thorn glow builds, then a shudder.
- `play_emerge()`, 3.0 s
- `play_hit(part, from_dir)`, `die(part, impulse)`, `get_part_node()`, `get_parts()` and the signal `finished`.

**Parts:**
- `head`: one box hitbox.
- `body`: one box hitbox.
- `legs`: 8 capsule hitboxes.
- `thorns`: 2 boxes along the ridge; this is the weak point.

**Death:** it staggers and collapses onto its side over about 3.3 s, the thorn ridge erupts (shards, big spore puffs and thorns flying off), and the glow fades. The carcass sinks and shrinks, then `finished` fires at about 11.5 s.
- `head`: shatters the antlers off.
- `legs`: buckles that leg.
- `thorns`: the eruption starts early.

## `GullModel`: ambient seagull
About 0.6 m wingspan. White body, grey wings with black tips, a yellow beak with a red spot, and orange legs. Its meshes and materials are shared across a flock.

**API:**
- `set_flap(0..1)`, where 0 means glide.
- `set_glide(b)` and `set_bank(-1..1)`.
- `set_perched(b)`: wings folded and legs down.
- `@export var auto_cycle := true`: alternates bursts of flapping with glides. Each bird gets a random phase so a flock never flaps in sync.

---

## Tests
All tests are in `tests/actors/`. Screenshots are written to `shots/actors/`.

- Shared lighting stage: `actor_stage.gd`.
- `test_tuppence.tscn -- --scenario=beauty|gestures|motion|aged`
- `test_registrar.tscn`
- `test_mite.tscn -- --only=look|walk|attack|death`
- `test_husk.tscn -- --scenario=look|anim|death`
- `test_thornback.tscn -- --only=idle|move|acts|die --part=...`
- `test_gull.tscn`
- `test_bloomkit.tscn`
- `tri_count.tscn`: run headless; add `-- --detail` for a breakdown by mesh.
- `sheet.py`: builds contact sheets (needs Pillow).

Example:
`Godot_v4.7.2-stable_win64_console.exe --path . res://tests/actors/test_tuppence.tscn -- --scenario=gestures`
