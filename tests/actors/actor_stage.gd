extends RefCounted
## Shared test-stage helpers for actor test scenes (lighting, ground, camera, screenshots).
## Usage: const Stage := preload("res://tests/actors/actor_stage.gd")


static func build(root: Node3D, sun_deg := Vector3(-38, -35, 0), ground := true) -> Camera3D:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.36, 0.52, 0.78)
	psm.sky_horizon_color = Color(0.72, 0.76, 0.82)
	psm.ground_horizon_color = Color(0.55, 0.55, 0.55)
	psm.ground_bottom_color = Color(0.25, 0.24, 0.22)
	psm.sun_angle_max = 20.0
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_deg
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_blur = 1.0
	root.add_child(sun)

	if ground:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(60, 1, 60)
		cs.shape = bs
		cs.position = Vector3(0, -0.5, 0)
		body.add_child(cs)
		var gm := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(60, 60)
		gm.mesh = pm
		var mat := StandardMaterial3D.new()
		var found := _find_tex("res://assets/textures/concrete_floor_worn_001/", "_diff")
		if found != "":
			mat.albedo_texture = load(found)
			mat.uv1_scale = Vector3(30, 30, 30)
			var nrm := _find_tex("res://assets/textures/concrete_floor_worn_001/", "_nor_gl")
			if nrm != "":
				mat.normal_enabled = true
				mat.normal_texture = load(nrm)
		else:
			mat.albedo_color = Color(0.45, 0.44, 0.42)
		mat.albedo_color = Color(0.85, 0.85, 0.85)
		mat.roughness = 0.9
		gm.material_override = mat
		body.add_child(gm)
		root.add_child(body)

	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.03
	root.add_child(cam)
	cam.current = true
	return cam


static func _find_tex(dir: String, contains: String) -> String:
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	for f in d.get_files():
		if f.ends_with(".import") and f.contains(contains):
			return dir + f.trim_suffix(".import")
	return ""


static func look(cam: Camera3D, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


## Saves the current frame to res://shots/actors/<name>.png
static func snap(tree: SceneTree, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := tree.root.get_viewport().get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path("res://shots/actors/" + file_name + ".png")
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	img.save_png(abs_path)
	print("[shot] ", abs_path)


static func wait(tree: SceneTree, sec: float) -> void:
	await tree.create_timer(sec, true, false, true).timeout


## Reads a `--key=value` user argument (after `--` on the command line).
static func arg(key: String, default := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.split("=", true, 1)[1]
	return default
