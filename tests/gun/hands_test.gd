extends Node3D
## Viewmodel hands test bench. Renders the weapons.gd rigs with their first-person arms in fixed poses.
##   Godot --path . res://tests/gun/hands_test.tscn -- --specs=pistol/hip/day/fp,rifle/bolt/red/oside
## spec = gun / pose / light / view
##   pose: hip ads recoil reload reload_away sprint lowered bolt load equip
##   light: day red dim     view: fp (player camera), oside oleft ofront obottom otop oback (orthographic)
## Writes shots/hands_<gun>_<pose>_<light>_<view>.png

var cam: Camera3D
var holder: Node3D
var w: Node3D
var sun: DirectionalLight3D
var red: OmniLight3D
var env: Environment


func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	we.environment = env
	add_child(we)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor.mesh = pm
	floor.material_override = Mats.color(Color(0.42, 0.36, 0.3), 0.9)
	add_child(floor)
	var wall := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(12, 5, 0.3)
	wall.mesh = bm
	wall.material_override = Mats.color(Color(0.55, 0.52, 0.48), 0.9)
	wall.position = Vector3(0, 2.5, -5)
	add_child(wall)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-38, 35, 0)
	add_child(sun)
	red = OmniLight3D.new()
	red.light_color = Color(1.0, 0.12, 0.08)
	red.light_energy = 2.5
	red.omni_range = 7.0
	red.position = Vector3(0.6, 2.7, -1.2)
	red.shadow_enabled = true
	add_child(red)
	holder = Node3D.new()
	holder.position = Vector3(0, 1.6, 0)
	add_child(holder)
	cam = Camera3D.new()
	cam.near = 0.03
	cam.current = true
	add_child(cam)
	var W: GDScript = load("res://src/player/weapons.gd")
	w = W.new()
	w.name = "Weapons"
	holder.add_child(w)
	w.call("setup", null)
	var specs := String(Game.shot_args.get("specs", "pistol/hip/day/fp")).split(",")
	for spec in specs:
		await _shot(spec)
	get_tree().quit()


func _shot(spec: String) -> void:
	var p := spec.split("/")
	var gun := p[0]
	var pose := p[1] if p.size() > 1 else "hip"
	var light := p[2] if p.size() > 2 else "day"
	var view := p[3] if p.size() > 3 else "fp"
	# lighting
	sun.visible = light == "day"
	red.visible = light == "red"
	env.background_energy_multiplier = 1.0 if light == "day" else 0.05
	env.ambient_light_energy = 1.0 if light == "day" else (0.06 if light == "red" else 0.25)
	# rig
	var rigs: Dictionary = w.get("rigs")
	for k in rigs:
		(rigs[k] as Node3D).visible = false
	if not rigs.has(gun):
		rigs[gun] = w.call("_build_rig", gun)
	var rig: Node3D = rigs[gun]
	rig.visible = true
	w.set("current", gun)
	w.set("_rig", rig)
	for k in ["_bolt_open", "_bolt_lift", "_r_bolt", "_r_load", "_r_push", "_r_away", "_l_mag", "_l_away", "_trigger", "_aim"]:
		w.set(k, 0.0)
	w.set("_anim_rot", Vector3.ZERO)
	w.call("_use_arms", gun)
	var d: Dictionary = w.DEFS[gun]
	var pos: Vector3 = d.hip
	var rot: Vector3 = d.hip_rot
	cam.fov = 78.0
	match pose:
		"ads":
			pos = d.ads
			rot = Vector3.ZERO
			w.set("_aim", 1.0)
			cam.fov = 78.0 * float(d.ads_fov)
		"recoil":
			pos += Vector3(0, 0, 0.05 if gun == "pistol" else 0.09)
			rot += Vector3(0.15 if gun == "pistol" else 0.2, 0, 0)
			w.set("_trigger", 1.0)
		"reload":
			if gun == "pistol":
				rot += Vector3(0.45, -0.25, 0.35)
				w.set("_l_mag", 1.0)
			else:
				rot += w.RELOAD_TILT
				pos += w.RELOAD_SHIFT
				w.set("_r_bolt", 1.0)
				w.set("_bolt_open", 1.0)
				w.set("_bolt_lift", 1.0)
				w.set("_r_load", 1.0)
				w.set("_r_push", 0.6)
		"reload_away":
			if gun == "pistol":
				rot += Vector3(0.45, -0.25, 0.35)
				w.set("_l_mag", 1.0)
				w.set("_l_away", 1.0)
			else:
				rot += w.RELOAD_TILT
				pos += w.RELOAD_SHIFT
				w.set("_r_bolt", 1.0)
				w.set("_bolt_open", 1.0)
				w.set("_bolt_lift", 1.0)
				w.set("_r_load", 1.0)
				w.set("_r_away", 1.0)
		"bolt":
			rot += w.BOLT_TILT
			pos += w.BOLT_SHIFT
			w.set("_r_bolt", 1.0)
			w.set("_bolt_open", float(Game.shot_args.get("open", "1")))
			w.set("_bolt_lift", float(Game.shot_args.get("lift", "1")))
		"sprint":
			pos += Vector3(-0.06, -0.06, 0.04)
			rot += Vector3(-0.25, 0.4, 0.3)
		"lowered":
			pos += Vector3(0, -0.15, 0.05)
			rot += Vector3(-0.35, 0, 0)
		"equip":
			pos += Vector3(0, -0.2, 0)
	rig.position = pos
	rig.rotation = rot
	(rig.get_node("arm_l") as Node3D).visible = not Game.shot_args.has("hideleft")
	(rig.get_node("arm_r") as Node3D).visible = not Game.shot_args.has("hideright")
	if gun == "rifle" and Game.shot_args.has("hidebolt"):
		(w.get("_bolt") as Node3D).visible = false
	if gun == "rifle" and Game.shot_args.has("dbg"):
		var b: Node3D = w.get("_bolt")
		for mi in rig.find_children("*bolt*", "", true, false):
			if mi is MeshInstance3D:
				print(mi.name, " aabb ", rig.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb(), " xf ", (mi as Node3D).transform)
		print("bolt pos ", b.position, " rest ", w.get("_bolt_rest"), " parent ", b.get_parent().name, " gt ", rig.global_transform.affine_inverse() * b.global_position)
	w.call("_update_arms")
	# camera
	if view == "fp":
		w.scale = Vector3(1, 1, w.DEPTH_SQUASH)
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.global_transform = holder.global_transform
		cam.near = 0.03
	else:
		w.scale = Vector3.ONE
		w.call("_update_arms")
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(Game.shot_args.get("osize", "0.32" if gun == "pistol" else "0.6"))
		cam.near = 0.01
		var focus: Vector3 = rig.to_global(Vector3(0, -0.02, 0.03) if gun == "pistol" else Vector3(0, -0.02, 0.2))
		if Game.shot_args.has("focus"):
			var fz := String(Game.shot_args.focus).split(":")
			focus = rig.to_global(Vector3(float(fz[0]), float(fz[1]), float(fz[2])))
		var bx := rig.global_transform.basis.orthonormalized()
		var dir: Vector3
		var up := bx.y
		match view:
			"oside": dir = bx.x
			"oleft": dir = -bx.x
			"ofront": dir = -bx.z
			"oback": dir = bx.z
			"obottom":
				dir = -bx.y
				up = -bx.z
			"otop":
				dir = bx.y
				up = -bx.z
		cam.global_transform = Transform3D(Basis.looking_at(-dir, up), focus + dir * 1.0)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://shots/hands_%s_%s_%s_%s.png" % [gun, pose, light, view])
	get_viewport().get_texture().get_image().save_png(path)
	print("[hands] saved ", path)
