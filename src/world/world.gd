class_name World
extends Node3D
## Assembles the environment for an era: sky/weather, terrain, ocean, the town, the home, the shelter.

var era := "before"
var sky: Node3D  # SkyWeather when available
var env: WorldEnvironment
var sun: DirectionalLight3D
var terrain: Terrain
var home: Home
var town: Town
var shelter: Shelter
var ocean: Node3D
var player: Player


func build(p_era: String, parts := ["terrain", "home", "town", "shelter", "ocean"]) -> void:
	era = p_era
	var t := Time.get_ticks_msec()
	_build_sky()
	_lap("sky", t)
	if "terrain" in parts:
		terrain = Terrain.new()
		terrain.name = "Terrain"
		add_child(terrain)
		t = Time.get_ticks_msec()
		terrain.build(era)
		_lap("terrain", t)
	if "ocean" in parts:
		_build_ocean()
	if "home" in parts:
		home = Home.new()
		home.name = "Home"
		add_child(home)
		home.position = Vector3(Layout.HOME.x, Layout.height(Layout.HOME.x, Layout.HOME.z), Layout.HOME.z)
		t = Time.get_ticks_msec()
		home.build(era)
		_lap("home", t)
	if "town" in parts:
		town = Town.new()
		town.name = "Town"
		add_child(town)
		t = Time.get_ticks_msec()
		town.build(era, self)
		_lap("town", t)
	if "shelter" in parts:
		shelter = Shelter.new()
		shelter.name = "Shelter"
		add_child(shelter)
		t = Time.get_ticks_msec()
		shelter.build(era)
		_lap("shelter", t)


func _lap(what: String, t: int) -> void:
	if Game.shot_args.has("timing"):
		print("[build] %s %d ms" % [what, Time.get_ticks_msec() - t])


func _sky_available() -> bool:
	return ResourceLoader.exists("res://src/world/sky/sky_weather.gd") and not Game.shot_args.has("nosky")


func _build_sky() -> void:
	if _sky_available():
		var S: GDScript = load("res://src/world/sky/sky_weather.gd")
		if S != null and S.can_instantiate():
			sky = S.new()
			sky.name = "SkyWeather"
			add_child(sky)
			if sky.has_method("set_era"):
				sky.call("set_era", era)
			env = null
			return
	# fallback environment
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.55, 0.85)
	sm.sky_horizon_color = Color(0.75, 0.82, 0.9)
	sm.ground_horizon_color = Color(0.6, 0.65, 0.7)
	var skyr := Sky.new()
	skyr.sky_material = sm
	e.sky = skyr
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.ssao_enabled = true
	e.ssil_enabled = true
	e.sdfgi_enabled = true
	e.glow_enabled = true
	e.fog_enabled = true
	e.fog_density = 0.0015
	e.fog_light_color = Color(0.75, 0.8, 0.88)
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.006
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.rotation_degrees = Vector3(-28, -95, 0)
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_ocean() -> void:
	if ResourceLoader.exists("res://src/world/sky/ocean.gd") and not Game.shot_args.has("nosky"):
		var O: GDScript = load("res://src/world/sky/ocean.gd")
		if O != null and O.can_instantiate():
			ocean = O.new()
			ocean.name = "Ocean"
			add_child(ocean)
			ocean.position = Vector3(-700, 0, 0)
			if era == "after" and ocean.has_method("set_tint"):
				ocean.call("set_tint", Color(0.75, 0.6, 1.0))
			return
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.2, 0.28)
	m.roughness = 0.08
	m.metallic = 0.2
	mi.material_override = m
	mi.position = Vector3(-900, 0, 0)
	add_child(mi)
	ocean = mi


func set_time(hour: float) -> void:
	if sky:
		sky.set("time_of_day", hour)
	elif sun:
		var t := (hour - 6.5) / 12.0
		sun.rotation_degrees = Vector3(-sin(t * PI) * 60.0 - 3.0, -95.0 + t * 10.0, 0)


func set_weather(w: String, dur := 0.0) -> void:
	if sky and sky.has_method("set_weather"):
		sky.call("set_weather", w, dur)


func follow(target: Node3D) -> void:
	if sky and sky.has_method("set_follow_target"):
		sky.call("set_follow_target", target)


func set_interior(f: float) -> void:
	if sky and sky.has_method("set_interior"):
		sky.call("set_interior", f)
