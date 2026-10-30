# Sky, weather & ocean (`src/world/sky/`)

| File | What |
|---|---|
| `sky_weather.gd` | `class_name SkyWeather extends Node3D`: creates WorldEnvironment, camera attributes (auto exposure), sun/moon/flash/bloom lights, sky material, weather particles, lightning. |
| `sky.gdshader` | Sky: single-scattering Rayleigh/Mie atmosphere, sun disc, phased moon, twinkling stars + faint milky band, 2 drifting cloud layers, lightning bolts, Bloom tint and the chapter-2 violet cloud wall. |
| `ocean.gd` / `ocean.gdshader` | `class_name Ocean extends MeshInstance3D`: Gerstner sea with shoreline foam, refraction, glints and crest foam. |
| `rain.gdshader`, `splash.gdshader`, `glow_particle.gdshader` | Draw materials for rain streaks, splash rings, and spores/motes. |
| `tests/sky/sky_test.tscn` | Visual test. It renders 25 scenarios to `shots/sky/` and then quits. |

## Integration

```gdscript
var sky := SkyWeather.new()
sky.start_weather = "clear"     # optional, before add_child
sky.start_era = "before"        # "before" (1967) / "after" (1978)
sky.start_quality = 2           # 0 low, 1 medium, 2 high
world.add_child(sky)
sky.time_of_day = 8.67          # 8:40 AM
sky.set_follow_target(player_camera)    # rain/spores/motes are centred on this

var ocean := Ocean.new()        # origin = sea level (y = 0)
ocean.position = Vector3(-1500, 0, 0)   # centred off the coast, to the west
ocean.size = Vector2(3000, 3000)        # landward (+X local) edge is clipped at size.x/2
world.add_child(ocean)          # SkyWeather finds it automatically (group "ocean")
```

* Use one SkyWeather per world scene. Do **not** add another WorldEnvironment or DirectionalLight3D.
* SkyWeather owns `WorldEnvironment.camera_attributes`, which holds the auto exposure. A camera that has its
  own `attributes` (for example dialogue DOF) overrides it, so for those cameras copy the exposure settings:
  `var a := sky.get_camera_attributes().duplicate()`, then set your DOF on `a`.
* Interiors: call `sky.set_interior(1.0)` when the player enters a building and `0.0` when they leave.
  It fades rain and motes over about 0.6 s, reduces wind, and adds a little volumetric dust for light shafts.
  Rain is also kept off covered areas by a `GPUParticlesCollisionHeightField3D` that follows the player.
  For dusty sunbeams in a room, add a `FogVolume` inside it.
* The shelter exit in Ch.4: inside the dark shelter, call `sky.set_exposure_adapt_speed(0.25)`. Opening the
  gate then blows out to white and adapts over a few seconds. Restore it with `set_exposure_adapt_speed(0.8)`.
* Scripted moments: call `set_weather(name, 0.0)` for an instant switch (it also drops live particles).
  `sky.lightning_enabled = false` stops random strikes, and `trigger_lightning(strength, distance, azimuth)`
  fires one on cue.

## Public API

### Time

| Member | Notes |
|---|---|
| `time_of_day: float` | Hours, 0..24. Setting it updates the sky and lights immediately. |
| `day_speed: float = 12.0` | Game hours per real hour, so 12 means 1 real minute is 12 game minutes. |
| `time_paused: bool` | Stops the clock. |
| `signal hour_changed(hour: int)` | Fires on each new game hour. |
| `darkness() -> float` | 0 is full day, 1 is deep night. Heavy weather adds up to +0.35 and the Bloom event up to +0.2. |
| `signal lights_should_be_on(on: bool)` | Comes on around 18.5 h and off around 6.5 h, earlier in storms, with hysteresis. It is emitted once at startup. |
| `get_sun_direction() -> Vector3` | Direction towards the sun. |

The sun rises in the east (+X) at 6:30, peaks in the south (+Z) at 42°, and sets over the sea (−X) at 18:30.
The moon is a waxing gibbous: it is up from mid-afternoon to about 4:00 and is high in the south-west at
midnight. Only one directional light casts shadows at a time (the sun, or the moon at night).

### Weather

| Member | Notes |
|---|---|
| `set_weather(name, transition_sec := 20.0)` | `clear`, `cloudy`, `overcast`, `fog`, `rain`, `storm`, `bloom`. Every parameter blends smoothly. |
| `weather: String` | Read-only. |
| `auto_weather: bool` | Picks a new weather every 1–3 game hours with weighted odds. `bloom` is only possible in the "after" era. A storm never follows a clear sky directly. |
| `signal weather_changed(name)` | |
| `signal lightning(strength: float, distance: float)` | Delay thunder by `distance / 343.0` s, set its volume from `strength`, and use a deeper rumble when far away. |
| `trigger_lightning(strength := 1.0, distance := 1500.0, azimuth := INF)` | Azimuth is in radians: 0 is north (−Z), PI/2 is east. |
| `lightning_enabled: bool` | Random strikes during storms. |
| `get_wetness() -> float` / `set_wetness(f)` | Rain soaks things in about 1 min and they dry in about 5 min (faster in sun). |
| `wind_strength`, `rain_strength`, `interior` | Read these each frame for audio: wind loop, rain loop, and a low-pass when `interior` → 1. |

### Era, Bloom, quality

| Member | Notes |
|---|---|
| `set_era(e, transition_sec := 2.0)` | `after`: slightly desaturated, lifted violet shadows (1D LUT), faint violet horizon haze, and sparse glowing motes near the camera in every weather. |
| `set_bloom_event(t: float)` | 0..1, the chapter-2 catastrophe (see below). Tween it from your cutscene script. |
| `set_follow_target(n: Node3D)` | Usually the player camera. Without one, the active camera is used. |
| `set_interior(f, instant := false)` | 0..1, smoothed. |
| `set_quality(level)` | 0: no SDFGI/SSIL/SSR/volumetrics, fewer particles. 1: SDFGI (coarse) and volumetric fog. 2: everything. **Note:** this also sets the global RenderingServer SSAO/SSIL quality and half-resolution GI. |
| `set_exposure_adapt_speed(s)`, `set_auto_exposure(bool)`, `exposure_bias` | |
| `get_environment()`, `get_sun()`, `get_moon()`, `get_camera_attributes()` | |

**Bloom event** (`set_bloom_event`), viewed looking west over the sea:

* 0.0: a normal morning.
* 0.3: a glowing violet band low over the sea, with the base of a cloud wall on the horizon.
* 0.7: a towering cumulonimbus wall with a luminous base, internal violet flashes, the sky tinting violet, the sun dimming, and spores starting to fall.
* 1.0: the wall fills the western sky, everything is violet, there is violet volumetric fog, and the sea glows.

Darkness rises slightly as the event grows. A violet fill light shines from the sea.

### Global shader uniforms

These are registered at runtime, so no `project.godot` change is needed:

* `wetness` (0..1)
* `wind_strength`
* `sky_darkness` (= `darkness()`)
* `bloom_amount` (0..1, use it for crystal-flora glow)

Use them in your shaders with, for example, `global uniform float wetness;`. The SkyWeather node must be
created before any material that reads them is compiled; when in doubt, add it first in the world scene.
For wet surfaces, a typical recipe is `ROUGHNESS = mix(ROUGHNESS, 0.15, wetness * up_facing);
ALBEDO *= mix(1.0, 0.65, wetness);`.

### Ocean

| Member | Notes |
|---|---|
| `set_weather_intensity(f, instant := false)` | 0 calm .. 1 storm, blended over `intensity_smoothing` seconds. SkyWeather drives it. |
| `set_tint(c: Color)` | Multiplies the water body colour. SkyWeather sets a faint violet in the after era and for Bloom. |
| `set_sky_state(sun_dir, sun_color, sun_energy, bloom_glow)` | Called by SkyWeather each frame. |
| `get_wave_height(world_pos) -> float` | Approximate surface Y. Use it for buoys and floating props. |
| `size`, `clip` | `LANDWARD_EDGE` (default) clips local x > size.x/2 and extends to the horizon elsewhere. `RECTANGLE` clips to `size`. `NONE` is infinite. |

The mesh is a polar grid that follows the camera (dense near it, 24 km radius), so it always reaches the
horizon. Waves shoal and die down in shallow water. The shader reads the depth buffer for this, so beaches
need no extra data. Foam forms where the water meets geometry.

## Performance

Measured on an RTX 4060 laptop at 1600x900 in the test scene, storm weather. The test scene's own floor is
about 5 ms, which includes the project's 2× MSAA.

| Quality | GPU frame |
|---|---|
| 2 | ~13.5 ms |
| 1 | ~11 ms |
| 0 | ~9.5 ms |

At q2 the biggest costs are SSAO ~1.5 ms, SDFGI (half-res) ~1.5–2 ms, SSIL ~1.4 ms, the sky shader ~1.2 ms
and the ocean ~1 ms. Heavy game scenes on a laptop GPU should default to q1.

Run `--perf` to print a per-feature breakdown:

```
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1600x900 res://tests/sky/sky_test.tscn -- --perf
```

## Notes and gotchas

* **Volumetric fog temporal reprojection is off.** In Godot 4.7, temporal reprojection together with auto
  exposure posterized the whole sky. Fog density is low enough that it is stable without it.
* **SDFGI** uses 4 cascades at 0.25 m (q2) or 0.4 m (q1) cells, which reaches about 400 m, with occlusion on
  to limit leaks. Thin walls (under 0.2 m) can still leak sky light indoors. Make walls at least 0.2 m thick,
  or lower `get_environment().sdfgi_energy` while `interior` is 1. Without SDFGI (q0), indoor ambient is
  scaled by `interior` automatically.
* Sky colours are authored as sRGB-ish values and converted on the script side. Shader uniforms the script
  feeds are linear (no `source_color`).
* Test runner options:
  * `-- --only=name1,name2`
  * `-- --custom=name:hour:weather:era:cam[:bloom_event]`
  * `-- --dbg=novol,nofog,noexp,q0,...`
  * `-- --keep` (doesn't quit)
