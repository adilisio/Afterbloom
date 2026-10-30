extends Node3D
## Visual test for SkyWeather + Ocean. Builds a little seaside street, a clifftop, a beach and a
## closed room with a window, then renders a list of scenarios to shots/sky/*.png and quits.
## Run:  Godot_v4.7.2-stable_win64_console.exe --path . res://tests/sky/sky_test.tscn [-- --only=a,b] [--keep]

const SHOT_DIR := "shots/sky/"

var sky: SkyWeather
var cam: Camera3D
var ocean: Ocean
var lamp_lights: Array[OmniLight3D] = []
var window_mats: Array[StandardMaterial3D] = []
var wet_mats: Array[StandardMaterial3D] = []

const CAMS: Dictionary = {
	"street": [Vector3(34.0, 3.8, 78.0), Vector3(-40.0, 3.0, 10.0)],
	"street_east": [Vector3(4.0, 3.7, 40.0), Vector3(60.0, 5.0, 0.0)],
	"west_cliff": [Vector3(-26.0, 28.0, -92.0), Vector3(-300.0, 4.0, -20.0)],
	"west_high": [Vector3(-26.0, 28.0, -92.0), Vector3(-300.0, 40.0, -10.0)],
	"beach": [Vector3(-52.0, 1.9, 14.0), Vector3(-300.0, 2.0, -10.0)],
	"sunset": [Vector3(2.0, 7.0, 30.0), Vector3(-300.0, 10.0, 15.0)],
	"interior": [Vector3(82.6, 3.55, 40.6), Vector3(70.0, 3.6, 39.0)],
	"up": [Vector3(30.0, 3.0, 30.0), Vector3(-10.0, 30.0, 40.0)],
	"night_sky": [Vector3(4.0, 3.0, 60.0), Vector3(-20.0, 22.0, 110.0)],
}

# name, time, weather, era, cam, extras
var SHOTS: Array = [
	["noon_clear", 12.5, "clear", "before", "street", {}],
	["noon_cloudy", 12.5, "cloudy", "before", "street", {}],
	["noon_overcast", 12.5, "overcast", "before", "street", {}],
	["noon_fog", 12.5, "fog", "before", "street", {}],
	["noon_rain", 12.5, "rain", "before", "street", {"wet": 1.0}],
	["noon_storm", 12.5, "storm", "before", "street", {"wet": 1.0}],
	["noon_bloom", 12.5, "bloom", "after", "street", {}],
	["morning_clear_east", 8.6, "clear", "before", "street_east", {}],
	["golden_hour", 17.4, "clear", "before", "sunset", {}],
	["sunset", 18.35, "clear", "before", "sunset", {}],
	["dusk", 19.0, "cloudy", "before", "street", {}],
	["night_clear", 23.0, "clear", "before", "street", {}],
	["night_sky", 23.0, "clear", "before", "night_sky", {}],
	["night_rain", 23.0, "rain", "before", "street", {"wet": 1.0}],
	["storm_flash", 16.0, "storm", "before", "west_cliff", {"wet": 1.0, "lightning": true}],
	["bloom_event_0", 9.0, "clear", "before", "west_high", {"bloom_event": 0.0}],
	["bloom_event_03", 9.0, "clear", "before", "west_high", {"bloom_event": 0.3}],
	["bloom_event_07", 9.0, "clear", "before", "west_high", {"bloom_event": 0.7}],
	["bloom_event_10", 9.0, "clear", "before", "west_high", {"bloom_event": 1.0}],
	["interior_rain", 14.0, "rain", "before", "interior", {"interior": 1.0, "wet": 1.0}],
	["interior_day", 10.0, "clear", "before", "interior", {"interior": 1.0}],
	["after_clear", 15.0, "clear", "after", "street", {}],
	["ocean_cliff", 15.5, "clear", "before", "west_cliff", {}],
	["ocean_beach", 15.5, "cloudy", "before", "beach", {}],
	["ocean_storm_beach", 15.5, "storm", "before", "beach", {"wet": 1.0}],
]


func _ready() -> void:
	_build_world()
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 30000.0
	add_child(cam)
	cam.make_current()

	sky = SkyWeather.new()
	sky.time_paused = true
	sky.start_quality = 2
	add_child(sky)
	sky.set_follow_target(cam)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("[sky_test] viewport ", get_viewport().get_visible_rect().size, " window ", DisplayServer.window_get_size())
	sky.set_exposure_adapt_speed(8.0)
	sky.lights_should_be_on.connect(_on_lights)
	sky.lightning.connect(func(s: float, d: float) -> void: print("[sky_test] lightning ", s, " @ ", d, " m"))

	ocean = Ocean.new()
	ocean.position = Vector3(-1540.0, 0.0, 0.0)
	add_child(ocean)

	var only: PackedStringArray = []
	var keep := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
		if a == "--keep":
			keep = true
		# --custom=name:time:weather:era:cam[:bloom_event]
		if a.begins_with("--custom="):
			for spec in a.substr(9).split(";"):
				var f := spec.split(":")
				var ex := {}
				if f.size() > 5:
					ex["bloom_event"] = float(f[5])
				SHOTS.append([f[0], float(f[1]), f[2], f[3], f[4], ex])
				only.append(f[0])
	await get_tree().create_timer(4.0).timeout
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dbg="):
			for f in a.substr(6).split(","):
				_debug_flag(f)
	for a in OS.get_cmdline_user_args():
		if a == "--perf":
			await _perf_breakdown()
			get_tree().quit()
			return
	for s: Array in SHOTS:
		if only.size() > 0 and not only.has(String(s[0])):
			continue
		await _run_shot(s)
	if not keep:
		get_tree().quit()


var _gpu_acc := 0.0
var _cpu_acc := 0.0
var _gpu_n := 0


func _process(_delta: float) -> void:
	if sky == null:
		return
	var vp := get_viewport().get_viewport_rid()
	_gpu_acc += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	_cpu_acc += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	_gpu_n += 1
	# simulate how game materials would react to the global `wetness`
	var w := sky.get_wetness()
	for m in wet_mats:
		m.roughness = lerpf(1.0, 0.18, w)
		m.albedo_color = Color(1, 1, 1).lerp(Color(0.62, 0.62, 0.64), w)


func _run_shot(s: Array) -> void:
	var shot_name: String = s[0]
	var extras: Dictionary = s[5]
	sky.set_bloom_event(float(extras.get("bloom_event", 0.0)))
	sky.set_era(String(s[3]), 0.0)
	sky.set_weather(String(s[2]), 0.0)
	sky.time_of_day = float(s[1])
	sky.set_interior(float(extras.get("interior", 0.0)), true)
	sky.set_wetness(float(extras.get("wet", 0.0)))
	sky.lightning_enabled = false
	var c: Array = CAMS[String(s[4])]
	cam.global_position = c[0]
	cam.look_at(c[1], Vector3.UP)
	if String(s[4]) == "night_sky":
		# look up at the moon
		var md := sky.get_moon().global_transform.basis.z
		cam.look_at(cam.global_position + md - Vector3(0.0, 0.35, 0.0), Vector3.UP)
	var wait := 2.6
	if extras.get("lightning", false):
		await get_tree().create_timer(wait).timeout
		var f := -cam.global_transform.basis.z
		sky.trigger_lightning(1.0, 900.0, atan2(f.x, -f.z) + 0.25)
		await get_tree().create_timer(0.03).timeout
	else:
		await get_tree().create_timer(wait - 1.2).timeout
		_gpu_acc = 0.0
		_cpu_acc = 0.0
		_gpu_n = 0
		await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	var abs_path := ProjectSettings.globalize_path("res://" + SHOT_DIR + shot_name + ".png")
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	img.save_png(abs_path)
	print("[shot] %-20s fps=%d gpu=%.2fms cpu=%.2fms darkness=%.2f" % [shot_name, Engine.get_frames_per_second(),
		_gpu_acc / maxf(_gpu_n, 1), _cpu_acc / maxf(_gpu_n, 1), sky.darkness()])


func _measure(sec: float) -> float:
	await get_tree().create_timer(0.6).timeout
	_gpu_acc = 0.0
	_gpu_n = 0
	await get_tree().create_timer(sec).timeout
	return _gpu_acc / maxf(_gpu_n, 1)


## Measures GPU ms of the storm scene while switching features off one at a time.
func _perf_breakdown() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	sky.set_weather("storm", 0.0)
	sky.time_of_day = 12.5
	var c: Array = CAMS["street"]
	cam.global_position = c[0]
	cam.look_at(c[1], Vector3.UP)
	await get_tree().create_timer(3.0).timeout
	var e := sky.get_environment()
	var steps: Array = [
		["baseline (q2)", func() -> void: pass],
		["- ssr", func() -> void: e.ssr_enabled = false],
		["- ssil", func() -> void: e.ssil_enabled = false],
		["- sdfgi", func() -> void: e.sdfgi_enabled = false],
		["- volumetric fog", func() -> void: e.volumetric_fog_enabled = false],
		["- ssao", func() -> void: e.ssao_enabled = false],
		["- glow", func() -> void: e.glow_enabled = false],
		["- ocean", func() -> void: ocean.visible = false],
		["- weather particles", func() -> void: sky.get_node("WeatherFX").visible = false],
		["- sky realtime (incremental)", func() -> void: e.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL],
		["- sun shadows", func() -> void: sky.get_sun().shadow_enabled = false],
		["- sky shader (bg colour)", func() -> void: e.background_mode = Environment.BG_COLOR],
		["- tonemap/adjust/fog", func() -> void:
			e.adjustment_enabled = false
			e.fog_enabled = false],
		["- auto exposure", func() -> void: sky.set_auto_exposure(false)],
	]
	for st: Array in steps:
		(st[1] as Callable).call()
		var ms := await _measure(2.0)
		print("[perf] %-32s gpu=%.2f ms  fps=%d" % [st[0], ms, Engine.get_frames_per_second()])
	# quality presets
	e.ssao_enabled = true
	e.glow_enabled = true
	ocean.visible = true
	sky.get_node("WeatherFX").visible = true
	e.sky.process_mode = Sky.PROCESS_MODE_REALTIME
	e.background_mode = Environment.BG_SKY
	e.adjustment_enabled = true
	e.fog_enabled = true
	sky.set_auto_exposure(true)
	sky.get_sun().shadow_enabled = true
	for q in [0, 1, 2]:
		sky.set_quality(q)
		var ms := await _measure(2.5)
		print("[perf] quality %d                        gpu=%.2f ms  fps=%d" % [q, ms, Engine.get_frames_per_second()])
	# bloom squall (heaviest particles + violet fog), high quality
	sky.set_weather("bloom", 0.0)
	print("[perf] bloom q2                         gpu=%.2f ms  fps=%d" % [await _measure(2.5), Engine.get_frames_per_second()])
	sky.set_bloom_event(1.0)
	print("[perf] bloom_event=1 q2                 gpu=%.2f ms  fps=%d" % [await _measure(2.5), Engine.get_frames_per_second()])


func _debug_flag(f: String) -> void:
	var e := sky.get_environment()
	match f:
		"novol": e.volumetric_fog_enabled = false
		"nofog": e.fog_enabled = false
		"noglow": e.glow_enabled = false
		"noexp": sky.set_auto_exposure(false)
		"nosdfgi": e.sdfgi_enabled = false
		"nossil": e.ssil_enabled = false
		"nossr": e.ssr_enabled = false
		"noadj": e.adjustment_enabled = false
		"noocean": ocean.visible = false
		"nosun": sky.get_sun().light_cull_mask = 0
		"noflashlight": sky.get_node("LightningFlash").light_cull_mask = 0
		"notemporal": e.volumetric_fog_temporal_reprojection_enabled = false
		"q0": sky.set_quality(0)
		"q1": sky.set_quality(1)


func _on_lights(on: bool) -> void:
	for l in lamp_lights:
		l.visible = on
	for m in window_mats:
		m.emission_energy_multiplier = 2.2 if on else 0.0


# ------------------------------------------------------------------------------------------
func _tex_mat(id: String, scale: float, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base := "res://assets/textures/%s/%s_" % [id, id]
	m.albedo_texture = load(base + "diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load(base + "nor_gl.jpg")
	m.roughness_texture = load(base + "rough.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


func _model(id: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> Node3D:
	var path := "res://assets/models/%s/%s_1k.gltf" % [id, id]
	var ps: PackedScene = load(path)
	if ps == null:
		push_warning("missing model " + path)
		return null
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * scale
	add_child(n)
	return n


func _build_world() -> void:
	var grass := _tex_mat("leafy_grass", 0.25)
	var asphalt := _tex_mat("asphalt_02", 0.2)
	var pave := _tex_mat("concrete_pavement", 0.3)
	var sand := _tex_mat("coast_sand_01", 0.2)
	var cliff := _tex_mat("cliff_side", 0.06)
	var siding := _tex_mat("weathered_plank_siding", 0.35, Color(0.95, 0.92, 0.85))
	var siding_b := _tex_mat("weathered_plank_siding", 0.35, Color(0.7, 0.82, 0.9))
	var plaster := _tex_mat("white_rough_plaster", 0.4)
	var roof := _tex_mat("clay_roof_tiles", 0.35)
	var floor_m := _tex_mat("wood_floor_worn", 0.4)
	wet_mats.append_array([grass, asphalt, pave, sand])

	# land plateau (top y = 2), road, sidewalk
	_box(Vector3(320.0, 4.0, 420.0), Vector3(130.0, 0.0, 0.0), grass)
	_box(Vector3(9.0, 0.1, 420.0), Vector3(12.0, 2.05, 0.0), asphalt)
	_box(Vector3(3.0, 0.24, 420.0), Vector3(18.0, 2.12, 0.0), pave)
	# beach sloping into the sea
	var slope := atan2(7.0, 90.0)
	_box(Vector3(92.0, 1.0, 420.0), Vector3(-74.0, -1.9, 0.0), sand, Vector3(0, 0, slope))
	# headland / cliff
	_box(Vector3(60.0, 30.0, 60.0), Vector3(-6.0, 11.0, -112.0), cliff)
	_box(Vector3(30.0, 22.0, 34.0), Vector3(-40.0, 5.0, -118.0), cliff, Vector3(0, 0.4, 0))

	# houses along the road
	var houses := [Vector3(30, 0, -40), Vector3(30, 0, -18), Vector3(31, 0, 6), Vector3(30, 0, 30), Vector3(46, 0, 52), Vector3(-2, 0, -20)]
	var i := 0
	for h: Vector3 in houses:
		var w := 8.0
		var d := 10.0
		var ht := 5.0
		var mat := siding if i % 2 == 0 else siding_b
		_box(Vector3(w, ht, d), Vector3(h.x, 2.0 + ht * 0.5, h.z), mat)
		var pr := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(w + 0.8, 2.6, d + 0.8)
		pr.mesh = pm
		pr.material_override = roof
		pr.position = Vector3(h.x, 2.0 + ht + 1.3, h.z)
		pr.rotation.y = PI * 0.5
		add_child(pr)
		# lit windows on the road-facing (west) side
		for wz: float in [-2.5, 2.5]:
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.08, 0.07, 0.06)
			wm.emission_enabled = true
			wm.emission = Color(1.0, 0.72, 0.4)
			wm.emission_energy_multiplier = 0.0
			wm.roughness = 0.1
			window_mats.append(wm)
			var side := -1.0 if h.x > 10.0 else 1.0
			_box(Vector3(0.05, 1.3, 1.2), Vector3(h.x + side * (w * 0.5 + 0.03), 4.4, h.z + wz), wm)
		i += 1

	# street lamps with lights
	for z in range(-60, 100, 24):
		_model("street_lamp_01", Vector3(17.6, 2.24, float(z)), PI * 0.5)
		var l := OmniLight3D.new()
		l.position = Vector3(17.0, 6.6, float(z))
		l.light_color = Color(1.0, 0.78, 0.5)
		l.light_energy = 2.4
		l.omni_range = 16.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		lamp_lights.append(l)
	_model("fire_hydrant", Vector3(18.2, 2.24, 12.0))
	_model("covered_car", Vector3(14.0, 2.1, 20.0), 0.1)
	_model("painted_wooden_bench", Vector3(19.0, 2.24, 36.0), -PI * 0.5)
	_model("shrub_03", Vector3(24.0, 2.0, 18.0))
	_model("shrub_02", Vector3(25.0, 2.0, -6.0))
	_model("boulder_01", Vector3(-48.0, -0.2, 22.0), 0.4, 2.0)
	_model("boulder_01", Vector3(-62.0, -1.4, -8.0), 1.4, 3.0)
	_model("lifebuoy", Vector3(19.0, 3.0, 47.0), 0.0)
	_model("wooden_picnic_table", Vector3(-12.0, 2.0, 40.0), 0.3)

	# closed room with a west-facing window: floor y=2, interior 6x6x3
	var rx := 80.0
	var rz := 40.0
	_box(Vector3(6.4, 0.2, 6.4), Vector3(rx, 2.1, rz), floor_m)
	_box(Vector3(6.4, 0.2, 6.4), Vector3(rx, 5.3, rz), plaster)
	_box(Vector3(0.2, 3.2, 6.4), Vector3(rx + 3.1, 3.7, rz), plaster)  # east
	_box(Vector3(6.4, 3.2, 0.2), Vector3(rx, 3.7, rz - 3.1), plaster)  # north
	_box(Vector3(6.4, 3.2, 0.2), Vector3(rx, 3.7, rz + 3.1), plaster)  # south
	# west wall with window 1.8 wide (z 39.1..40.9), y 3.0..4.4
	_box(Vector3(0.2, 3.2, 2.2), Vector3(rx - 3.1, 3.7, rz - 2.0), plaster)
	_box(Vector3(0.2, 3.2, 2.2), Vector3(rx - 3.1, 3.7, rz + 2.0), plaster)
	_box(Vector3(0.2, 0.8, 1.8), Vector3(rx - 3.1, 2.6, rz), plaster)
	_box(Vector3(0.2, 0.9, 1.8), Vector3(rx - 3.1, 4.85, rz), plaster)
	# exterior skin (roof) so the heightfield sees a roof
	_box(Vector3(7.2, 0.3, 7.2), Vector3(rx, 5.55, rz), roof)
	_model("Sofa_01", Vector3(rx + 1.9, 2.2, rz + 0.3), -PI * 0.5)
	_model("WoodenTable_01", Vector3(rx + 0.3, 2.2, rz - 1.8))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(rx + 2.4, 3.4, rz - 2.4)
	lamp.light_color = Color(1.0, 0.7, 0.42)
	lamp.light_energy = 0.7
	lamp.omni_range = 5.0
	lamp.shadow_enabled = true
	add_child(lamp)
