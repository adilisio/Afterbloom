class_name SkyWeather
extends Node3D
## Sky, sun/moon lighting, day/night cycle, weather, era grading and the chapter-2 Bloom event.
##
## Add one instance to the world scene, call set_follow_target(camera) and drive it with
## set_weather()/set_era()/set_interior(). See src/world/sky/README.md.

signal hour_changed(hour: int)
signal weather_changed(name: String)
signal lightning(strength: float, distance: float)
signal lights_should_be_on(on: bool)

const WEATHERS: PackedStringArray = ["clear", "cloudy", "overcast", "fog", "rain", "storm", "bloom"]

## Weather presets. Every key is a float and is blended during transitions.
## cov/dark/cirrus: clouds. haze: Mie multiplier. overcast: sky greying. occl: direct-sun occlusion.
## rain/wind/lightning/spores: 0..1. fog_vol: volumetric density. fog_depth: distance fog density.
## wet: wetness target. ocean: sea state. bloom: violet tint amount.
const PRESETS: Dictionary = {
	"clear": {"cov": 0.26, "dark": 0.05, "cirrus": 0.45, "haze": 1.0, "overcast": 0.0, "occl": 0.0,
		"rain": 0.0, "wind": 0.2, "fog_vol": 0.0025, "fog_depth": 0.00035, "lightning": 0.0,
		"spores": 0.0, "wet": 0.0, "ocean": 0.22, "bloom": 0.0},
	"cloudy": {"cov": 0.56, "dark": 0.25, "cirrus": 0.3, "haze": 1.3, "overcast": 0.12, "occl": 0.2,
		"rain": 0.0, "wind": 0.35, "fog_vol": 0.003, "fog_depth": 0.0005, "lightning": 0.0,
		"spores": 0.0, "wet": 0.0, "ocean": 0.38, "bloom": 0.0},
	"overcast": {"cov": 0.93, "dark": 0.45, "cirrus": 0.0, "haze": 2.2, "overcast": 0.8, "occl": 0.85,
		"rain": 0.0, "wind": 0.45, "fog_vol": 0.004, "fog_depth": 0.0011, "lightning": 0.0,
		"spores": 0.0, "wet": 0.05, "ocean": 0.5, "bloom": 0.0},
	"fog": {"cov": 0.85, "dark": 0.2, "cirrus": 0.0, "haze": 5.0, "overcast": 0.85, "occl": 0.75,
		"rain": 0.0, "wind": 0.08, "fog_vol": 0.035, "fog_depth": 0.014, "lightning": 0.0,
		"spores": 0.0, "wet": 0.25, "ocean": 0.12, "bloom": 0.0},
	"rain": {"cov": 0.97, "dark": 0.7, "cirrus": 0.0, "haze": 2.5, "overcast": 0.92, "occl": 0.92,
		"rain": 0.6, "wind": 0.6, "fog_vol": 0.008, "fog_depth": 0.0035, "lightning": 0.0,
		"spores": 0.0, "wet": 1.0, "ocean": 0.68, "bloom": 0.0},
	"storm": {"cov": 1.0, "dark": 0.95, "cirrus": 0.0, "haze": 3.0, "overcast": 1.0, "occl": 0.97,
		"rain": 1.0, "wind": 1.0, "fog_vol": 0.012, "fog_depth": 0.005, "lightning": 1.0,
		"spores": 0.0, "wet": 1.0, "ocean": 1.0, "bloom": 0.0},
	"bloom": {"cov": 0.84, "dark": 0.68, "cirrus": 0.0, "haze": 2.5, "overcast": 0.5, "occl": 0.65,
		"rain": 0.0, "wind": 0.55, "fog_vol": 0.022, "fog_depth": 0.0035, "lightning": 0.0,
		"spores": 1.0, "wet": 0.0, "ocean": 0.5, "bloom": 1.0},
}

const AUTO_WEIGHTS_BEFORE: Dictionary = {"clear": 36, "cloudy": 26, "overcast": 14, "fog": 9, "rain": 10, "storm": 5}
const AUTO_WEIGHTS_AFTER: Dictionary = {"clear": 26, "cloudy": 20, "overcast": 14, "fog": 9, "rain": 10, "storm": 5, "bloom": 16}

const GLOBAL_PARAMS: Array[StringName] = [&"wetness", &"wind_strength", &"sky_darkness", &"bloom_amount"]
const BLOOM_VIOLET := Color(0.55, 0.22, 1.0)
const SUNRISE_HOUR := 6.5
const SUNSET_HOUR := 18.5
const SUN_MAX_ELEVATION_DEG := 42.0
## Wind blows onshore, from the sea (west) towards the town (east, +X).
const WIND_DIR := Vector3(0.94, 0.0, 0.34)

## Hours 0..24. Setting it updates sky and lights immediately.
@export_range(0.0, 24.0, 0.01) var time_of_day: float = 9.0:
	set(v):
		time_of_day = fposmod(v, 24.0)
		if _ready_done:
			_update_hour_signal()
			_apply()
## Game hours advanced per real hour (12 = 1 real minute is 12 game minutes).
@export var day_speed: float = 12.0
@export var time_paused: bool = false
## When true a new weather is picked every 1-3 game hours.
@export var auto_weather: bool = false
## Random lightning during storms (scripted strikes via trigger_lightning() always work).
@export var lightning_enabled: bool = true
@export var start_weather: String = "clear"
@export var start_era: String = "before"
@export_range(0, 2) var start_quality: int = 2

## Current weather name (read-only; use set_weather()).
var weather: String:
	get:
		return _weather
	set(_v):
		push_warning("SkyWeather.weather is read-only, use set_weather()")
## Current era "before"/"after" (read-only; use set_era()).
var era: String:
	get:
		return _era
	set(_v):
		push_warning("SkyWeather.era is read-only, use set_era()")
## Smoothed interior factor 0 (outdoors) .. 1 (indoors). Use for audio muffling.
var interior: float = 0.0
## Current effective wind 0..1 (reduced indoors). Use for wind audio.
var wind_strength: float = 0.0
## Current rain intensity 0..1 (before interior fade). Use for rain audio.
var rain_strength: float = 0.0
var quality: int = 2
## Extra exposure multiplier for the game (e.g. scripted flashes / fades). 1 = neutral.
var exposure_bias: float = 1.0

var _ready_done := false
var _weather := "clear"
var _era := "before"
var _era_f := 0.0
var _era_target := 0.0
var _era_speed := 0.5
var _p: Dictionary = {}
var _p_from: Dictionary = {}
var _p_to: Dictionary = {}
var _wt := 1.0
var _wdur := 1.0
var _interior_target := 0.0
var _wetness := 0.0
var _bloom_event := 0.0
var _auto_hours_left := 2.0
var _last_hour := -1
var _lights_on := false
var _lights_known := false
var _cloud_off := Vector2.ZERO
var _cirrus_off := Vector2(13.0, 7.0)
var _anim_time := 0.0
var _rng := RandomNumberGenerator.new()

# lightning
var _next_strike := 6.0
var _strike_t := 99.0
var _strike_strength := 0.0
var _strike_dist := 1000.0
var _bolt_az := 0.0
var _bolt_seed := 0.0
var _bolt_height := 0.3
var _flash := 0.0

# nodes
var _world_env: WorldEnvironment
var _env: Environment
var _cam_attr: CameraAttributesPractical
var _sky: Sky
var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _flash_light: DirectionalLight3D
var _bloom_light: DirectionalLight3D
var _follow: Node3D
var _fx_root: Node3D
var _rain: GPUParticles3D
var _splash: GPUParticles3D
var _spores: GPUParticles3D
var _motes: GPUParticles3D
var _heightfield: GPUParticlesCollisionHeightField3D
var _rain_mat: ShaderMaterial
var _splash_mat: ShaderMaterial
var _spore_mat: ShaderMaterial
var _mote_mat: ShaderMaterial
var _grade: Gradient
var _grade_tex: GradientTexture1D
var _grade_key := Vector2(-1.0, -1.0)
var _rain_pm: ParticleProcessMaterial
var _spore_pm: ParticleProcessMaterial

# cached per-frame values
var _sun_dir := Vector3.UP
var _moon_dir := Vector3.DOWN
var _sun_el := 45.0
var _night := 0.0


func _init() -> void:
	_register_globals()


func _ready() -> void:
	_rng.randomize()
	_bolt_seed = _rng.randf() * 100.0
	_build_environment()
	_build_lights()
	_build_particles()
	_weather = start_weather if PRESETS.has(start_weather) else "clear"
	_p = (PRESETS[_weather] as Dictionary).duplicate()
	_p_from = _p.duplicate()
	_p_to = _p.duplicate()
	_era = start_era
	_era_target = 1.0 if _era == "after" else 0.0
	_era_f = _era_target
	_wetness = float(_p["wet"])
	_ready_done = true
	set_quality(start_quality)
	_last_hour = int(time_of_day)
	_apply()
	call_deferred("_emit_initial")


func _emit_initial() -> void:
	weather_changed.emit(_weather)
	hour_changed.emit(int(time_of_day))
	_update_lights_signal(true)


# ======================================================================================
# Public API
# ======================================================================================

func set_weather(name: String, transition_sec: float = 20.0) -> void:
	if not PRESETS.has(name):
		push_warning("SkyWeather: unknown weather '%s'" % name)
		return
	_p_from = _p.duplicate()
	_p_to = (PRESETS[name] as Dictionary).duplicate()
	_wdur = maxf(transition_sec, 0.0)
	_wt = 0.0
	if _wdur <= 0.001:
		_wt = 1.0
		_p = _p_to.duplicate()
	var changed := name != _weather
	_weather = name
	if _wdur <= 0.001 and _ready_done:
		# instant switch (cutscenes / loading): drop live particles of the previous weather
		_apply()
		for ps: GPUParticles3D in [_rain, _splash, _spores]:
			ps.restart()
	if _p_to["lightning"] > 0.0:
		_next_strike = _rng.randf_range(2.0, 6.0)
	if changed:
		weather_changed.emit(name)
	if _ready_done:
		_apply()


func set_era(e: String, transition_sec: float = 2.0) -> void:
	_era = e
	_era_target = 1.0 if e == "after" else 0.0
	if transition_sec <= 0.001:
		_era_f = _era_target
	_era_speed = 1.0 / maxf(transition_sec, 0.001)
	if _ready_done:
		_apply()


func set_follow_target(n: Node3D) -> void:
	_follow = n


## 0 outdoors .. 1 indoors. Fades rain/motes, reduces wind. Smoothed over ~0.6 s.
func set_interior(f: float, instant: bool = false) -> void:
	_interior_target = clampf(f, 0.0, 1.0)
	if instant:
		interior = _interior_target


## Chapter-2 catastrophe, 0 = normal .. 1 = apocalyptic violet glow over the sea (west).
func set_bloom_event(t: float) -> void:
	_bloom_event = clampf(t, 0.0, 1.0)
	if _ready_done:
		_apply()


func get_bloom_event() -> float:
	return _bloom_event


func get_environment() -> Environment:
	return _env


func get_sun() -> DirectionalLight3D:
	return _sun


func get_moon() -> DirectionalLight3D:
	return _moon


func get_camera_attributes() -> CameraAttributesPractical:
	return _cam_attr


func get_wetness() -> float:
	return _wetness


func set_wetness(f: float) -> void:
	_wetness = clampf(f, 0.0, 1.0)


## Seconds-ish adaptation speed of auto exposure (higher = faster). Default 0.8.
## Use a low value (e.g. 0.25) right before the "exit the shelter" moment for a long blinding adapt.
func set_exposure_adapt_speed(s: float) -> void:
	_cam_attr.auto_exposure_speed = maxf(s, 0.01)


func set_auto_exposure(enabled: bool) -> void:
	_cam_attr.auto_exposure_enabled = enabled


## 0 = deep day .. 1 = deep night (heavy weather adds a bit).
func darkness() -> float:
	var d := 1.0 - smoothstep(-10.0, 8.0, _sun_el)
	var wd := float(_p.get("occl", 0.0)) * 0.35
	d = d + (1.0 - d) * wd
	d += _bloom_event * 0.2
	return clampf(d, 0.0, 1.0)


func get_sun_direction() -> Vector3:
	return _sun_dir


## Fire a lightning strike now (also used internally during storms).
## azimuth: radians, 0 = north (-Z), PI/2 = east (+X); INF = random.
func trigger_lightning(strength: float = 1.0, distance: float = 1500.0, azimuth: float = INF) -> void:
	_strike_strength = clampf(strength, 0.05, 1.5)
	_strike_dist = distance
	_strike_t = 0.0
	_bolt_az = _rng.randf_range(-PI, PI) if is_inf(azimuth) else azimuth
	_bolt_seed = _rng.randf() * 100.0
	_bolt_height = lerpf(0.42, 0.16, clampf(distance / 6000.0, 0.0, 1.0))
	lightning.emit(_strike_strength, distance)


func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	if _env == null:
		return
	_env.sdfgi_enabled = quality >= 1
	# 4 cascades: 0.25 m cells near the player, ~400 m reach (q2); coarser on q1
	_env.sdfgi_cascades = 4
	_env.sdfgi_min_cell_size = 0.25 if quality >= 2 else 0.4
	_env.ssil_enabled = quality >= 2
	_env.ssr_enabled = quality >= 2
	_env.ssr_max_steps = 32
	_env.ssao_enabled = true
	# Global screen-space effect cost (these are RenderingServer-wide settings).
	var rs := RenderingServer
	rs.gi_set_use_half_resolution(true)
	match quality:
		0:
			rs.environment_set_ssao_quality(rs.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 2, 50.0, 300.0)
		1:
			rs.environment_set_ssao_quality(rs.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)
		_:
			rs.environment_set_ssao_quality(rs.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
			rs.environment_set_ssil_quality(rs.ENV_SSIL_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)
	_env.volumetric_fog_enabled = quality >= 1
	_env.volumetric_fog_length = 96.0 if quality >= 2 else 64.0
	_sky_mat.set_shader_parameter("quality", quality)
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality >= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 160.0 if quality >= 2 else (120.0 if quality == 1 else 80.0)
	_moon.directional_shadow_mode = _sun.directional_shadow_mode
	_moon.directional_shadow_max_distance = _sun.directional_shadow_max_distance * 0.6
	var mult: float = [0.35, 0.6, 1.0][quality]
	_rain.amount = int(9000 * mult)
	_splash.amount = int(1600 * mult)
	_spores.amount = int(3000 * mult)
	_motes.amount = int(360 * mult)
	_heightfield.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512 if quality >= 2 else GPUParticlesCollisionHeightField3D.RESOLUTION_256


# ======================================================================================
# Construction
# ======================================================================================

static var _globals_registered := false


## Registers the global shader uniforms at runtime (no project.godot edits needed).
static func _register_globals() -> void:
	if _globals_registered:
		return
	_globals_registered = true
	for n: StringName in GLOBAL_PARAMS:
		if not ProjectSettings.has_setting("shader_globals/" + String(n)):
			RenderingServer.global_shader_parameter_add(n, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)


func _build_environment() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://src/world/sky/sky.gdshader")
	_sky = Sky.new()
	_sky.sky_material = _sky_mat
	_sky.process_mode = Sky.PROCESS_MODE_REALTIME
	_sky.radiance_size = Sky.RADIANCE_SIZE_256

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = _sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.ambient_light_sky_contribution = 1.0
	_env.ambient_light_energy = 1.0
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.tonemap_exposure = 1.0
	_env.tonemap_agx_white = 12.0
	_env.tonemap_agx_contrast = 1.15

	_env.ssao_enabled = true
	_env.ssao_radius = 1.4
	_env.ssao_intensity = 1.8
	_env.ssao_power = 1.4
	_env.ssao_light_affect = 0.15
	_env.ssil_enabled = true
	_env.ssil_radius = 4.0
	_env.ssil_intensity = 0.8
	_env.ssr_enabled = true
	_env.ssr_max_steps = 48
	_env.ssr_fade_in = 0.15
	_env.ssr_fade_out = 2.0

	_env.sdfgi_enabled = true
	_env.sdfgi_use_occlusion = true
	_env.sdfgi_read_sky_light = true
	_env.sdfgi_bounce_feedback = 0.45
	_env.sdfgi_cascades = 5
	_env.sdfgi_min_cell_size = 0.2
	_env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	_env.sdfgi_energy = 1.0
	_env.sdfgi_normal_bias = 1.1
	_env.sdfgi_probe_bias = 1.1

	_env.glow_enabled = true
	_env.glow_normalized = false
	_env.set("glow_levels/1", 0.0)
	_env.set("glow_levels/2", 0.6)
	_env.set("glow_levels/3", 1.0)
	_env.set("glow_levels/4", 0.8)
	_env.set("glow_levels/5", 0.6)
	_env.glow_intensity = 0.55
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.04
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.glow_hdr_threshold = 1.1
	_env.glow_hdr_scale = 2.0

	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_aerial_perspective = 0.85
	_env.fog_sky_affect = 0.0
	_env.fog_density = 0.0004

	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.003
	_env.volumetric_fog_anisotropy = 0.6
	_env.volumetric_fog_length = 96.0
	_env.volumetric_fog_detail_spread = 2.0
	_env.volumetric_fog_gi_inject = 0.6
	_env.volumetric_fog_ambient_inject = 0.0
	_env.volumetric_fog_sky_affect = 0.0
	# temporal reprojection is OFF on purpose: combined with auto exposure it posterizes the sky
	# (Godot 4.7). detail_spread + density are tuned so the fog stays stable without it.
	_env.volumetric_fog_temporal_reprojection_enabled = false

	_env.adjustment_enabled = true
	_grade = Gradient.new()
	_grade_tex = GradientTexture1D.new()
	_grade_tex.width = 256
	_grade_tex.gradient = _grade
	_env.adjustment_color_correction = _grade_tex

	_cam_attr = CameraAttributesPractical.new()
	_cam_attr.auto_exposure_enabled = true
	_cam_attr.auto_exposure_scale = 0.38
	_cam_attr.auto_exposure_speed = 0.8
	_cam_attr.auto_exposure_min_sensitivity = 120.0
	_cam_attr.auto_exposure_max_sensitivity = 1000.0

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = _env
	_world_env.camera_attributes = _cam_attr
	add_child(_world_env)


func _make_dir_light(n: String, shadows: bool) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = n
	l.shadow_enabled = shadows
	l.directional_shadow_blend_splits = true
	l.directional_shadow_fade_start = 0.85
	l.shadow_bias = 0.03
	l.shadow_normal_bias = 1.2
	l.shadow_blur = 1.0
	add_child(l)
	return l


func _build_lights() -> void:
	_sun = _make_dir_light("Sun", true)
	_sun.light_angular_distance = 0.6
	_sun.light_volumetric_fog_energy = 1.0
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_moon = _make_dir_light("Moon", false)
	_moon.light_angular_distance = 0.6
	_moon.light_volumetric_fog_energy = 1.5
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_flash_light = _make_dir_light("LightningFlash", false)
	_flash_light.light_color = Color(0.78, 0.84, 1.0)
	_flash_light.light_volumetric_fog_energy = 0.2
	_flash_light.light_energy = 0.0
	_flash_light.visible = false
	_flash_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_bloom_light = _make_dir_light("BloomLight", false)
	_bloom_light.light_color = BLOOM_VIOLET
	_bloom_light.light_energy = 0.0
	_bloom_light.visible = false
	_bloom_light.light_specular = 0.3
	_bloom_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY


func _quad(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q


func _fade_ramp(fade_in: float, fade_out: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, fade_in, 1.0 - fade_out, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _build_particles() -> void:
	_fx_root = Node3D.new()
	_fx_root.name = "WeatherFX"
	_fx_root.top_level = true
	add_child(_fx_root)

	# collision heightfield: rain stops on roofs / doesn't fall indoors
	_heightfield = GPUParticlesCollisionHeightField3D.new()
	_heightfield.name = "RainOcclusion"
	_heightfield.size = Vector3(56.0, 60.0, 56.0)
	_heightfield.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	_heightfield.follow_camera_enabled = false
	_fx_root.add_child(_heightfield)

	# --- splash (sub emitter) ---
	_splash = GPUParticles3D.new()
	_splash.name = "Splash"
	_splash.local_coords = false
	_splash.lifetime = 0.32
	_splash.visibility_aabb = AABB(Vector3(-30, -40, -30), Vector3(60, 80, 60))
	var spm := ParticleProcessMaterial.new()
	spm.gravity = Vector3.ZERO
	spm.initial_velocity_min = 0.0
	spm.initial_velocity_max = 0.0
	spm.scale_min = 0.6
	spm.scale_max = 1.3
	_splash.process_material = spm
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.22, 0.22)
	_splash_mat = ShaderMaterial.new()
	_splash_mat.shader = preload("res://src/world/sky/splash.gdshader")
	plane.material = _splash_mat
	_splash.draw_pass_1 = plane
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx_root.add_child(_splash)

	# --- rain ---
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.local_coords = false
	_rain.lifetime = 1.6
	_rain.amount = 9000
	_rain.amount_ratio = 0.0
	_rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_rain.visibility_aabb = AABB(Vector3(-30, -40, -30), Vector3(60, 80, 60))
	_rain.collision_base_size = 0.02
	_rain_pm = ParticleProcessMaterial.new()
	_rain_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_pm.emission_box_extents = Vector3(22.0, 1.0, 22.0)
	_rain_pm.direction = Vector3(0, -1, 0)
	_rain_pm.spread = 3.0
	_rain_pm.initial_velocity_min = 19.0
	_rain_pm.initial_velocity_max = 24.0
	_rain_pm.gravity = Vector3(0, -6.0, 0)
	_rain_pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_rain_pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	_rain_pm.sub_emitter_amount_at_collision = 1
	_rain_pm.scale_min = 0.8
	_rain_pm.scale_max = 1.2
	_rain.process_material = _rain_pm
	var rq := _quad(Vector2(0.016, 0.7))
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = preload("res://src/world/sky/rain.gdshader")
	rq.material = _rain_mat
	_rain.draw_pass_1 = rq
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx_root.add_child(_rain)
	_rain.sub_emitter = _rain.get_path_to(_splash)

	# --- bloom spores ---
	_spores = GPUParticles3D.new()
	_spores.name = "Spores"
	_spores.local_coords = false
	_spores.lifetime = 9.0
	_spores.preprocess = 9.0
	_spores.amount = 3000
	_spores.amount_ratio = 0.0
	_spores.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	_spores.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	_spore_pm = ParticleProcessMaterial.new()
	_spore_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_spore_pm.emission_box_extents = Vector3(24.0, 10.0, 24.0)
	_spore_pm.direction = Vector3(1, 0, 0)
	_spore_pm.spread = 180.0
	_spore_pm.initial_velocity_min = 0.2
	_spore_pm.initial_velocity_max = 1.0
	_spore_pm.gravity = Vector3(0, -0.12, 0)
	_spore_pm.turbulence_enabled = true
	_spore_pm.turbulence_noise_strength = 4.0
	_spore_pm.turbulence_noise_scale = 5.0
	_spore_pm.turbulence_noise_speed = Vector3(0.3, 0.15, 0.0)
	_spore_pm.turbulence_influence_min = 0.06
	_spore_pm.turbulence_influence_max = 0.18
	_spore_pm.scale_min = 0.05
	_spore_pm.scale_max = 0.14
	_spore_pm.color_ramp = _fade_ramp(0.15, 0.25)
	_spore_pm.hue_variation_min = -0.04
	_spore_pm.hue_variation_max = 0.05
	_spores.process_material = _spore_pm
	var sq := _quad(Vector2(1, 1))
	_spore_mat = ShaderMaterial.new()
	_spore_mat.shader = preload("res://src/world/sky/glow_particle.gdshader")
	_spore_mat.set_shader_parameter("tint", Color(0.62, 0.3, 1.0))
	_spore_mat.set_shader_parameter("energy", 5.0)
	_spore_mat.set_shader_parameter("near_fade", 0.8)
	sq.material = _spore_mat
	_spores.draw_pass_1 = sq
	_spores.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx_root.add_child(_spores)

	# --- era motes (sparse, always present after the Bloom) ---
	_motes = GPUParticles3D.new()
	_motes.name = "Motes"
	_motes.local_coords = false
	_motes.lifetime = 14.0
	_motes.preprocess = 14.0
	_motes.amount = 260
	_motes.amount_ratio = 0.0
	_motes.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	_motes.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var mpm := ParticleProcessMaterial.new()
	mpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mpm.emission_box_extents = Vector3(11.0, 4.0, 11.0)
	mpm.spread = 180.0
	mpm.initial_velocity_min = 0.03
	mpm.initial_velocity_max = 0.2
	mpm.gravity = Vector3(0, -0.04, 0)
	mpm.turbulence_enabled = true
	mpm.turbulence_noise_strength = 1.5
	mpm.turbulence_noise_scale = 8.0
	mpm.turbulence_influence_min = 0.02
	mpm.turbulence_influence_max = 0.06
	mpm.scale_min = 0.06
	mpm.scale_max = 0.13
	mpm.color_ramp = _fade_ramp(0.2, 0.3)
	_motes.process_material = mpm
	var mq := _quad(Vector2(1, 1))
	_mote_mat = ShaderMaterial.new()
	_mote_mat.shader = preload("res://src/world/sky/glow_particle.gdshader")
	_mote_mat.set_shader_parameter("tint", Color(0.7, 0.45, 1.0))
	_mote_mat.set_shader_parameter("energy", 3.0)
	_mote_mat.set_shader_parameter("near_fade", 0.5)
	mq.material = _mote_mat
	_motes.draw_pass_1 = mq
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx_root.add_child(_motes)


# ======================================================================================
# Update
# ======================================================================================

func _process(delta: float) -> void:
	var game_hours := 0.0
	if not time_paused and day_speed != 0.0:
		game_hours = delta * day_speed / 3600.0
		time_of_day = fposmod(time_of_day + game_hours, 24.0)

	# weather transition
	if _wt < 1.0:
		_wt = minf(_wt + delta / maxf(_wdur, 0.001), 1.0)
		var k := smoothstep(0.0, 1.0, _wt)
		for key: String in _p_to.keys():
			_p[key] = lerpf(float(_p_from[key]), float(_p_to[key]), k)

	# auto weather
	if auto_weather and game_hours > 0.0:
		_auto_hours_left -= game_hours
		if _auto_hours_left <= 0.0:
			_auto_hours_left = _rng.randf_range(1.0, 3.0)
			set_weather(_pick_auto_weather(), 45.0)

	_era_f = move_toward(_era_f, _era_target, delta * _era_speed)
	interior = move_toward(interior, _interior_target, delta / 0.6)
	_anim_time += delta

	# wetness: soaks in ~1 min of real rain, dries over ~5 min (faster in sun)
	var wet_target := float(_p["wet"]) if float(_p["rain"]) > 0.05 else float(_p["wet"]) * 0.3
	if _wetness < wet_target:
		_wetness = minf(_wetness + delta / 60.0 * maxf(float(_p["rain"]), 0.3), wet_target)
	else:
		var dry_rate := (1.0 / 300.0) * (1.0 + (1.0 - darkness()) * (1.0 - float(_p["occl"])) * 2.0)
		_wetness = maxf(_wetness - delta * dry_rate, wet_target)

	# clouds drift (real time)
	var w := float(_p["wind"])
	var wind2 := Vector2(WIND_DIR.x, WIND_DIR.z)
	_cloud_off += wind2 * (0.006 + w * 0.03) * delta
	_cirrus_off += wind2 * (0.003 + w * 0.01) * delta

	_update_lightning(delta)
	_update_hour_signal()
	_apply()
	_update_follow()


func _pick_auto_weather() -> String:
	var weights: Dictionary = AUTO_WEIGHTS_AFTER if _era == "after" else AUTO_WEIGHTS_BEFORE
	var total := 0
	for k: String in weights.keys():
		total += int(weights[k])
	var r := _rng.randi_range(0, total - 1)
	var pick := "clear"
	for k: String in weights.keys():
		r -= int(weights[k])
		if r < 0:
			pick = k
			break
	# no sudden storm from a clear sky: go through rain first
	if pick == "storm" and (_weather == "clear" or _weather == "fog" or _weather == "bloom"):
		pick = "rain"
	return pick


func _update_hour_signal() -> void:
	var h := int(time_of_day)
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
	_update_lights_signal(false)


func _update_lights_signal(force: bool) -> void:
	var d := darkness()
	var on := _lights_on
	if d > 0.40:
		on = true
	elif d < 0.36:
		on = false
	if force or not _lights_known or on != _lights_on:
		_lights_on = on
		_lights_known = true
		lights_should_be_on.emit(on)


func _update_lightning(delta: float) -> void:
	var rate := float(_p["lightning"])
	if rate > 0.05 and lightning_enabled:
		_next_strike -= delta * rate
		if _next_strike <= 0.0:
			_next_strike = _rng.randf_range(5.0, 16.0)
			var dist := _rng.randf_range(350.0, 6000.0)
			var strength := clampf(1.25 - dist / 6000.0, 0.25, 1.0) * _rng.randf_range(0.75, 1.0)
			trigger_lightning(strength, dist)
	_strike_t += delta
	var t := _strike_t
	var f := 0.0
	if t < 1.2:
		# main flash + 2 re-strikes, flicker
		f += exp(-t * 14.0)
		f += 0.75 * exp(-maxf(t - 0.11, 0.0) * 18.0) * float(t > 0.11)
		f += 0.5 * exp(-maxf(t - 0.27, 0.0) * 10.0) * float(t > 0.27)
		f *= _strike_strength
	_flash = f


func _update_follow() -> void:
	var pos := Vector3.ZERO
	var fwd := Vector3.FORWARD
	if is_instance_valid(_follow):
		pos = _follow.global_position
		fwd = -_follow.global_transform.basis.z
	else:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam:
			pos = cam.global_position
			fwd = -cam.global_transform.basis.z
	var flat_fwd := Vector3(fwd.x, 0.0, fwd.z)
	if flat_fwd.length() > 0.01:
		flat_fwd = flat_fwd.normalized()
	# rain box above and slightly ahead; wind pushes the streaks, so offset upwind
	var wind := float(_p["wind"])
	_rain.global_position = pos + Vector3(0.0, 14.0, 0.0) + flat_fwd * 6.0 - WIND_DIR * wind * 6.0
	_spores.global_position = pos + flat_fwd * 6.0
	_motes.global_position = pos + flat_fwd * 4.0
	_heightfield.global_position = Vector3(snappedf(pos.x, 2.0), pos.y + 10.0, snappedf(pos.z, 2.0))


# --------------------------------------------------------------------------------------
func _sun_direction(t: float) -> Vector3:
	var th := (t - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR) * PI
	var tilt := deg_to_rad(SUN_MAX_ELEVATION_DEG)
	return Vector3(cos(th), sin(th) * sin(tilt), sin(th) * cos(tilt)).normalized()


func _moon_direction(t: float) -> Vector3:
	# waxing gibbous: rises in the east mid-afternoon, high in the south-west at midnight, sets ~4:00
	var th := (t - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR) * PI + PI * 1.2
	var tilt := deg_to_rad(52.0)
	return Vector3(cos(th), sin(th) * sin(tilt), sin(th) * cos(tilt) * 0.9 - 0.15).normalized()


static func _ramp(x: float, keys: PackedFloat32Array, vals: Array) -> Variant:
	if x <= keys[0]:
		return vals[0]
	for i in range(1, keys.size()):
		if x <= keys[i]:
			var k := (x - keys[i - 1]) / (keys[i] - keys[i - 1])
			return lerp(vals[i - 1], vals[i], k)
	return vals[vals.size() - 1]


const _SUN_KEYS: PackedFloat32Array = [-6.0, -2.0, 0.0, 3.0, 8.0, 15.0, 25.0, 40.0]
var _sun_cols: Array = [Color(1.0, 0.28, 0.10), Color(1.0, 0.34, 0.12), Color(1.0, 0.42, 0.18), Color(1.0, 0.55, 0.30),
	Color(1.0, 0.72, 0.48), Color(1.0, 0.85, 0.68), Color(1.0, 0.93, 0.82), Color(1.0, 0.97, 0.92)]


## Per-channel 1D LUT: "before" = warm, clean 1967 film; "after" = lifted violet shadows, cooler highs.
func _update_grade(era_f: float, bloom_f: float) -> void:
	var key := Vector2(snappedf(era_f, 0.01), snappedf(bloom_f, 0.01))
	if key == _grade_key:
		return
	_grade_key = key
	var lo := Color(0.0, 0.0, 0.0).lerp(Color(0.025, 0.004, 0.05), era_f).lerp(Color(0.04, 0.0, 0.07), bloom_f * 0.6)
	var mid := Color(0.5, 0.49, 0.47).lerp(Color(0.49, 0.48, 0.515), era_f)
	var hi := Color(1.0, 0.985, 0.95).lerp(Color(0.97, 0.96, 1.0), era_f)
	_grade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_grade.colors = PackedColorArray([lo, mid, hi])


static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


static func _look_basis(dir_to_light: Vector3) -> Basis:
	var fwd := -dir_to_light.normalized()
	var up := Vector3.UP if absf(fwd.y) < 0.98 else Vector3.FORWARD
	return Basis.looking_at(fwd, up)


func _apply() -> void:
	if _env == null:
		return
	var p := _p
	var be := _bloom_event
	var era_f := _era_f
	var bw := float(p["bloom"])
	var occl := clampf(float(p["occl"]) + be * 0.35, 0.0, 1.0)
	var storm_dark := float(p["dark"])

	_sun_dir = _sun_direction(time_of_day)
	_moon_dir = _moon_direction(time_of_day)
	_sun_el = rad_to_deg(asin(_sun_dir.y))
	var moon_el := rad_to_deg(asin(_moon_dir.y))
	_night = 1.0 - smoothstep(-14.0, -2.0, _sun_el)
	var daylight := smoothstep(-8.0, 12.0, _sun_el)

	# ---------------- sun ----------------
	var sun_col: Color = _ramp(_sun_el, _SUN_KEYS, _sun_cols)
	sun_col = sun_col.lerp(Color(0.92, 0.62, 1.0), be * 0.55)
	var sun_up := smoothstep(-3.0, 5.0, _sun_el)
	var sun_energy := 2.1 * sun_up * (0.72 + 0.28 * smoothstep(8.0, 35.0, _sun_el))
	sun_energy *= (1.0 - occl * 0.97) * (1.0 - be * 0.45)
	_sun.basis = _look_basis(_sun_dir)
	_sun.light_color = sun_col
	_sun.light_energy = sun_energy
	_sun.shadow_opacity = clampf(1.0 - occl * 0.85, 0.0, 1.0)
	_sun.light_angular_distance = lerpf(0.6, 4.0, occl)
	_sun.light_volumetric_fog_energy = lerpf(1.0, 0.4, occl)
	_sun.light_specular = 1.0 - smoothstep(0.45, 0.9, occl)   # no sharp glints under a cloud deck
	var sun_active := sun_energy > 0.004 and _sun_el > -4.0
	_sun.visible = sun_active
	_sun.shadow_enabled = sun_active

	# ---------------- moon ----------------
	var moon_up := smoothstep(-2.0, 8.0, moon_el)
	var moon_energy := 0.16 * moon_up * _night * (1.0 - occl * 0.85)
	_moon.basis = _look_basis(_moon_dir)
	_moon.light_color = Color(0.5, 0.64, 1.0)
	_moon.light_energy = moon_energy
	_moon.visible = moon_energy > 0.002
	_moon.shadow_enabled = _moon.visible and not sun_active
	_moon.shadow_opacity = clampf(1.0 - occl, 0.0, 1.0) * 0.85

	# ---------------- lightning flash light ----------------
	var near_k := clampf(1.0 - _strike_dist / 7000.0, 0.15, 1.0)
	var flash_e := _flash * near_k * (1.0 - interior * 0.5)
	_flash_light.visible = flash_e > 0.01
	_flash_light.light_energy = flash_e * 3.0
	_flash_light.basis = _look_basis(Vector3(sin(_bolt_az), 1.4, -cos(_bolt_az)).normalized())

	# ---------------- bloom light (violet fill from the sea / squall) ----------------
	var bl_e := be * 0.9 + bw * 0.22 * (0.4 + 0.6 * daylight) + era_f * 0.0
	_bloom_light.visible = bl_e > 0.005
	_bloom_light.light_energy = bl_e
	_bloom_light.basis = _look_basis(Vector3(-1.0, lerpf(0.9, 0.25, be), 0.15).normalized())

	# ---------------- sky shader ----------------
	var m := _sky_mat
	m.set_shader_parameter("sun_dir", _sun_dir)
	var disc_col := sun_col
	m.set_shader_parameter("sun_color", _lin(disc_col))
	m.set_shader_parameter("sun_disc_energy", 45.0 * pow(1.0 - occl, 2.0))
	m.set_shader_parameter("sun_visibility", 1.0 - be * 0.7)
	m.set_shader_parameter("moon_dir", _moon_dir)
	m.set_shader_parameter("moon_energy", smoothstep(-0.6, 0.2, _night) * (1.0 - float(p["overcast"]) * 0.6) + 0.15)
	m.set_shader_parameter("moon_phase", 0.75)
	m.set_shader_parameter("night", _night)
	m.set_shader_parameter("star_energy", (1.0 - float(p["cov"]) * 0.7) * (1.0 - float(p["fog_depth"]) * 60.0))
	m.set_shader_parameter("haze", float(p["haze"]) + era_f * 0.4 + be * 1.5)
	var ov := float(p["overcast"])
	m.set_shader_parameter("overcast", ov)
	var grey_day := lerpf(0.66, 0.24, storm_dark) * daylight * (0.35 + 0.65 * smoothstep(-2.0, 25.0, _sun_el))
	var grey_col := Color(grey_day * 0.97, grey_day, grey_day * 1.04)
	grey_col = grey_col.lerp(Color(grey_day * 0.62, grey_day * 0.5, grey_day * 0.82), bw)
	# colours are authored in sRGB-ish space and converted; night terms are added in linear space
	var grey_lin := _lin(grey_col) + Vector3(0.0009, 0.0012, 0.0024) * _night + Vector3(0.020, 0.023, 0.034) * _night * ov
	m.set_shader_parameter("overcast_color", grey_lin)
	m.set_shader_parameter("cloud_coverage", float(p["cov"]))
	m.set_shader_parameter("cloud_darkness", storm_dark)
	m.set_shader_parameter("cirrus", float(p["cirrus"]))
	m.set_shader_parameter("cloud_offset", _cloud_off)
	m.set_shader_parameter("cirrus_offset", _cirrus_off)
	var cl_sun := smoothstep(-5.0, 3.0, _sun_el)
	var cl_col := Color(sun_col.r, sun_col.g * 0.97, sun_col.b * 0.97)
	if _sun_el < 4.0:
		cl_col = cl_col.lerp(Color(1.0, 0.45, 0.5), smoothstep(4.0, -3.0, _sun_el) * 0.5)  # pink undersides
	var cloud_light := Color(cl_col.r, cl_col.g, cl_col.b) * (1.5 * cl_sun * (1.0 - occl * 0.55))
	m.set_shader_parameter("cloud_light", _lin(cloud_light) + Vector3(0.004, 0.005, 0.008) * _night * moon_up)
	var amb_day := Color(0.40, 0.46, 0.56).lerp(Color(0.42, 0.34, 0.42), smoothstep(14.0, 0.0, _sun_el) * daylight)
	var amb := amb_day * daylight * lerpf(1.0, 0.55, storm_dark)
	# overcast nights: clouds catch a little moon + town glow so the player can still navigate
	var amb_lin := _lin(amb) + Vector3(0.0009, 0.0012, 0.0026) * _night + Vector3(0.024, 0.026, 0.036) * _night * ov
	m.set_shader_parameter("cloud_ambient", amb_lin)
	var gc := Color(0.3, 0.33, 0.35) * (daylight * (1.0 - storm_dark * 0.4))
	m.set_shader_parameter("ground_color", _lin(gc) + Vector3(0.0006, 0.0009, 0.0016) + Vector3(0.006, 0.007, 0.01) * _night * ov)
	m.set_shader_parameter("flash", _flash * (0.4 + 0.6 * near_k))
	m.set_shader_parameter("bolt_alpha", clampf(_flash * 1.5, 0.0, 1.0) * float(_strike_t < 0.45 and _strike_dist < 4000.0))
	m.set_shader_parameter("bolt_azimuth", _bolt_az)
	m.set_shader_parameter("bolt_seed", _bolt_seed)
	m.set_shader_parameter("bolt_height", _bolt_height)
	m.set_shader_parameter("bloom_weather", bw)
	m.set_shader_parameter("bloom_event", be)
	m.set_shader_parameter("era_after", era_f)
	m.set_shader_parameter("anim_time", _anim_time)
	m.set_shader_parameter("bloom_color", BLOOM_VIOLET)

	# ---------------- mood exposure: auto exposure would normalise storms back to "daylight" ----------------
	var mood := lerpf(1.0, lerpf(0.62, 0.9, _night), storm_dark * float(p["cov"])) * (1.0 - be * 0.3) * (1.0 - bw * 0.25)
	_cam_attr.exposure_multiplier = mood * exposure_bias

	# ---------------- environment ----------------
	var e := _env
	# indoor ambient control only matters without SDFGI (SDFGI occludes the sky itself)
	var amb_e := 1.0
	if not e.sdfgi_enabled:
		amb_e = lerpf(1.0, 0.4, interior)
	e.ambient_light_energy = amb_e
	e.sdfgi_energy = 1.0
	# distance fog
	var fog_d := float(p["fog_depth"]) + era_f * 0.0004 + be * 0.0016
	if not e.volumetric_fog_enabled:
		fog_d += float(p["fog_vol"]) * 0.15
	e.fog_density = fog_d
	e.fog_sky_affect = clampf((float(p["fog_depth"]) - 0.0008) / 0.01, 0.0, 0.9) * (1.0 - bw * 0.7)
	e.fog_aerial_perspective = lerpf(0.85, 0.45, clampf(float(p["fog_depth"]) / 0.012, 0.0, 1.0))
	var fog_col := Color(0.62, 0.68, 0.76) * (0.12 + 0.88 * daylight) * lerpf(1.0, 0.55, storm_dark)
	fog_col = fog_col.lerp(Color(0.55, 0.42, 0.78) * (0.2 + 0.8 * daylight), clampf(bw * 0.6 + be * 0.8 + era_f * 0.18, 0.0, 1.0))
	fog_col += Color(0.006, 0.009, 0.018) * _night
	e.fog_light_color = fog_col
	e.fog_light_energy = 1.0
	e.fog_sun_scatter = 0.12 * daylight * (1.0 - occl)
	e.fog_height = 6.0
	e.fog_height_density = lerpf(0.0, 0.08, clampf((float(p["fog_depth"]) - 0.004) / 0.01, 0.0, 1.0))
	# volumetric fog
	var vd := float(p["fog_vol"]) + era_f * 0.0015 + be * 0.016 + interior * 0.004
	e.volumetric_fog_density = vd
	var v_alb := Color(0.88, 0.9, 0.94).lerp(Color(0.78, 0.6, 1.0), clampf(bw + be + era_f * 0.25, 0.0, 1.0))
	e.volumetric_fog_albedo = v_alb
	var v_em := clampf(bw * 0.05 + be * 0.12 + era_f * 0.012, 0.0, 1.0)
	e.volumetric_fog_emission = BLOOM_VIOLET * v_em * (0.5 + 0.5 * daylight)
	e.volumetric_fog_emission_energy = 1.0
	e.volumetric_fog_sky_affect = clampf(float(p["fog_vol"]) * 18.0 * (1.0 - bw * 0.8) + be * 0.12, 0.0, 1.0)
	e.volumetric_fog_anisotropy = lerpf(0.6, 0.3, occl)
	e.volumetric_fog_ambient_inject = lerpf(0.0, 0.5, clampf(float(p["fog_vol"]) * 30.0, 0.0, 1.0))
	# grading
	e.adjustment_saturation = lerpf(1.05, 0.86, era_f) - ov * 0.12 * (1.0 - bw) + be * 0.25 + bw * 0.12
	_update_grade(era_f, maxf(bw, be))
	e.adjustment_contrast = 1.0 + be * 0.06
	e.adjustment_brightness = 1.0

	# ---------------- weather FX ----------------
	var rain := float(p["rain"])
	rain_strength = rain
	var wind := float(p["wind"]) + be * 0.4
	wind_strength = clampf(wind * (1.0 - interior * 0.85), 0.0, 1.2)
	var rain_vis := rain * (1.0 - interior * 0.6)
	_rain.emitting = rain_vis > 0.002
	_rain.amount_ratio = clampf(rain_vis, 0.0, 1.0)
	_rain_pm.direction = Vector3(WIND_DIR.x * wind * 0.4, -1.0, WIND_DIR.z * wind * 0.4).normalized()
	var rain_light := (0.22 + 0.55 * daylight) * (1.0 - storm_dark * 0.35) + _flash * 1.5
	var rain_c := Color(0.62, 0.68, 0.75) * rain_light
	_rain_mat.set_shader_parameter("rain_color", rain_c)
	_rain_mat.set_shader_parameter("opacity", lerpf(0.32, 0.42, rain))
	_splash_mat.set_shader_parameter("rain_color", rain_c)
	_splash.emitting = _rain.emitting

	var spore_amt := clampf(maxf(float(p["spores"]), be * 0.9) * (1.0 - interior), 0.0, 1.0)
	_spores.emitting = spore_amt > 0.002
	_spores.amount_ratio = spore_amt
	_spore_pm.gravity = Vector3(WIND_DIR.x * wind * 0.6, -0.12 - be * 0.5, WIND_DIR.z * wind * 0.6)
	_spore_mat.set_shader_parameter("energy", lerpf(1.8, 3.2, daylight))
	var mote_amt := clampf(era_f * (1.0 - float(p["spores"]) * 0.7) * (1.0 - interior * 0.9), 0.0, 1.0)
	_motes.emitting = mote_amt > 0.002
	_motes.amount_ratio = mote_amt
	_mote_mat.set_shader_parameter("energy", lerpf(1.6, 3.4, daylight))

	# ---------------- global shader params ----------------
	RenderingServer.global_shader_parameter_set(&"wetness", _wetness)
	RenderingServer.global_shader_parameter_set(&"wind_strength", wind_strength)
	RenderingServer.global_shader_parameter_set(&"sky_darkness", darkness())
	RenderingServer.global_shader_parameter_set(&"bloom_amount", clampf(maxf(bw, be) + era_f * 0.2, 0.0, 1.0))

	# ---------------- ocean(s) ----------------
	if is_inside_tree():
		for o in get_tree().get_nodes_in_group(&"ocean"):
			if o.has_method("set_weather_intensity"):
				o.call("set_weather_intensity", clampf(float(p["ocean"]) + be * 0.3, 0.0, 1.0))
			if o.has_method("set_tint"):
				var tint := Color(1, 1, 1).lerp(Color(0.86, 0.72, 1.0), clampf(era_f * 0.35 + bw * 0.5 + be * 0.9, 0.0, 1.0))
				o.call("set_tint", tint)
			if o.has_method("set_sky_state"):
				o.call("set_sky_state", _sun_dir, sun_col, sun_energy + _moon.light_energy, clampf(bw * 0.4 + be, 0.0, 1.0) * 0.8 + era_f * 0.05)
