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
| HumanModel | ~6.3–7.9k, average ~7.1k (varies by outfit and hair) |
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

## `HumanModel`: 1967 townsfolk
A stylized, illustrated look: sculpted smooth forms, big readable eyes and painted shading in the skin's vertex colours. About 1.3–1.9 m tall.

Unlike the other models, it is **skinned**: one `Skeleton3D` and one mesh per person, with no seams at the joints and about 10 surfaces instead of dozens of nodes. Meshes, skins and materials are cached and shared. Legs and arms use two-bone IK, so feet stay planted and hands reach what they should.

### Configuring one
Set properties or pass them to `setup({...})` **before** `add_child`. Calling `setup()` later rebuilds the model.

| Property | Values |
|---|---|
| `sex` | `"m"`, `"f"` |
| `age` | `"child"` (8–12), `"adult"`, `"elder"` |
| `build` | `"slim"`, `"average"`, `"heavy"` |
| `height` | Metres to the crown. 0 = a default for the sex and age. |
| `skin_tone` | 0 (very fair) .. 1 (deep brown) |
| `hair_style` | `"short"`, `"side_part"`, `"mop"`, `"bob"`, `"ponytail"`, `"bun"`, `"curly"`, `"balding"`, `"bald"` |
| `hair_color`, `eye_color` | `Color` |
| `outfit` | `"cardigan"`, `"shirt_tie"`, `"dress"`, `"sweater"`, `"sweater_vest"`, `"overalls"`, `"fisherman"`, `"warden"` (Civil Defense: helmet and armband), `"halcyon"` (teal and cream with the amber patch) |
| `bottom` | `""` = the outfit's default, or `"slacks"`, `"skirt"`, `"shorts"` |
| `top_color`, `shirt_color`, `bottom_color`, `trim_color`, `accent_color`, `shoe_color`, `hat_color` | `Color`. Alpha 0 (the default) keeps the outfit's own colour. `accent_color` is the tie, sash, armband or scarf; on a `sweater_vest` it also adds a tie. |
| `pattern` | `""`, `"gingham"`, `"floral"`, `"dots"`, `"plaid"`, `"argyle"` |
| `hat` | `"none"`, `"fisherman"`, `"headscarf"`, `"helmet"`, `"peaked"` |
| `glasses`, `glasses_style` | `bool`; `"round"` or `"square"` |
| `headphones`, `sash`, `lipstick`, `blanket` | `bool` |
| `facial_hair` | `"none"`, `"moustache"` |
| `dirty` | Eleven years later: faded, stained clothes and grimy skin. Change it any time with `set_dirty(b)`. |
| `mood` | Resting expression, as in `set_expression`. |
| `posture` | `"normal"`, `"proud"`, `"shy"`, `"stoop"` |
| `idle_style` | Resting arms. -1 = from the seed, 0 relaxed, 1 hands clasped in front, 2 behind the back, 3 folded, 4 in pockets, 5 on hips. |
| `seat_height` | Seat or mattress height above the model's feet, in metres. |
| `seed_value` | Animation desync and small variations. 0 = random. |

### Making people
- `HumanModel.make_preset("june"|"rory"|"warden") -> HumanModel`
- `HumanModel.random_townsperson(seed) -> HumanModel` and `HumanModel.random_params(seed) -> Dictionary`. Deterministic. Body shape and outfit come from `CROWD_TEMPLATES` (23) templates, so a crowd shares meshes; colours, skin, height and mood come from the full seed, so nobody matches.
- `HumanModel.make_prop("mug"|"pamphlets"|"radio"|"clipboard") -> Node3D`, ready for `hold()`.

### Named characters
- **June** (`june`): the player's younger sister, early 20s, warm and teasing. Slim, 1.64 m, fair skin, green eyes, an auburn ponytail with a side-swept fringe. Butter-yellow knit cardigan over a white blouse, navy A-line skirt, oxblood flats, and the teal Halcyon open-house volunteer sash with an amber rosette. Soft lipstick, a resting smile, an upright stance.
- **Rory** (`rory`): 19, the junior radio DJ, nervous and sweet. Lanky, 1.80 m, a dark brown mop with a fringe, brown eyes, round tortoiseshell glasses. A mustard-and-brown argyle sweater vest over a pale blue shirt with a slim maroon tie, brown slacks, and headphones resting around his neck. Shoulders a little forward, hands clasped in front.
- **Warden Haskell** (`warden`): 50s, runs Shelter No. 9. Heavy, 1.78 m, grey short hair and a grey moustache, grey-blue eyes. Halcyon shelter uniform in teal with cream collar, cuffs and piping, the amber emblem patch on his left breast, a peaked cap with a brass badge. Stands proud with his arms folded.

### API
| Call | Notes |
|---|---|
| `set_move_speed(mps)` | Metres per second. About 1.3 walks, 3.5+ runs. The parent moves the root. |
| `set_talking(b)`, `is_talking()` | Jaw and lips move in syllable-like bursts, the head bobs, and one hand makes occasional beats. |
| `set_expression(name)` | `"neutral"`, `"happy"`, `"worried"`, `"scared"`, `"sad"`. Blends over about 0.3 s. |
| `play_gesture(name) -> float`, `is_gesturing()` | Returns the duration; an unknown name returns 0 with a warning. Emits `gesture_finished(name)`. |
| `look_at_point(world_pos)`, `clear_look()` | Eyes lead and the head follows. Head yaw ±69°, pitch -40° to +32°. Eyes add ±29° and -22° to +18°. A target far behind them is given up on. |
| `set_pose(name, instant := false, seat := -1.0)`, `get_pose()` | `"stand"`, `"sit"`, `"lie"`, `"sit_ground"`, `"cower"`. Use `instant` when placing NPCs. |
| `set_panic(b)` | Scared face and shaking. Standing still, hands to the chest. Running, flailing arms and glances back. Lasts until turned off. |
| `set_blanket(b)` | Shows a blanket while lying down. |
| `hold(node, "r"\|"l", style := "") -> Node3D` | The node's origin becomes the grip and it stays upright. Style is `"front"`, `"carry"` or `"chest"`; otherwise it comes from the node's `hold_style` meta. `grip_r` and `grip_curl` metas are optional. Returns whatever was in that hand before. |
| `release("r"\|"l") -> Node3D`, `get_held(side)` | Removes it from the hand; the caller owns it. |
| `get_head_node()`, `get_hand_node(side)` | Follow the bones. Good for dialogue cameras. |
| `get_height()`, `get_capsule() -> Vector2(radius, height)`, `make_collision_shape()` | For a controller. The model has no physics of its own. |

Gesture durations in seconds: `wave` 2.6, `point` 2.2 (toward the look target if there is one), `nod` 1.1, `shrug` 1.8, `hug_self` 3.0, `beckon` 2.4, `laugh` 2.2, `sip` 2.8 (with something in a hand), `gasp` 2.0, `shake_head` 1.4.

### Placing seated and lying people
The root stays on the floor under the pelvis.
- **`sit`:** hips at `seat_height` plus the flesh under them. Put the root about 0.15–0.25 m behind the seat's front edge. Feet reach for the floor and dangle if the seat is too tall. The Poly Haven `painted_wooden_bench` seat is about 0.445 m.
- **`lie`:** on the back with the **head toward +Z** and feet toward -Z, on a mattress at `seat_height`. The root is under the pelvis, so a 2 m bed wants the root about 0.8 m from the headboard end.
- **`sit_ground`:** on the floor, either knees up with arms around them or leaning back on the hands, picked from the seed.
- **`cower`:** crouched with hands over the head. The feet stay on the floor at the root.

### Performance
A crowd of 30, all on screen, costs about **1.1–1.2 ms per frame** on the bare test stage (RTX 4060 laptop at 1440p, vsync off, sun shadows on). `_update` takes about 43 µs per person at full detail.

The model updates less when it matters less: every frame up to 8 m, 50 Hz to 14 m, 30 Hz with no face to 30 m, 10 Hz beyond that, and 4 Hz with no face while off screen.

Building costs about 60–110 ms per **new** mesh, on the main thread. Build crowds during a load, not mid-scene. Each person draws about 10 surfaces per pass, shadows included.

### Known limits
- Lips go soft at under about 0.5 m: the head mesh has few rows there.
- `dots`, `gingham` and `plaid` patterns break slightly where a garment turns from front to side.
- A long gesture on a held item moves the item with the hand; nothing stops it passing through the body.
- There is no collision with the world: hands and feet will go through furniture that isn't where the pose expects it.
- Wrists don't twist the forearm, so extreme hand turns pinch the bare wrist a little.

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
- `test_human.tscn -- --only=gallery|presets|faces|expr|poses|walk|gestures|outfits|crowd|dirty|panic|api|world|light|perf`. Writes `shots/human_*.png`. `api` prints PASS or FAIL lines, `perf` prints frame costs, and `world` puts people beside real Poly Haven props.
- `test_bloomkit.tscn`
- `tri_count.tscn`: run headless; add `-- --detail` for a breakdown by mesh.
- `sheet.py`: builds contact sheets (needs Pillow).

Example:
`Godot_v4.7.2-stable_win64_console.exe --path . res://tests/actors/test_tuppence.tscn -- --scenario=gestures`
