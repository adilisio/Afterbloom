extends Node3D
## Renders contact sheets of every model in assets/models (8 per sheet) with name labels and sizes.

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.37, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var ids: Array[String] = []
	for d in DirAccess.get_directories_at("res://assets/models"):
		ids.append(d)
	ids.sort()
	var cam := Camera3D.new()
	add_child(cam)
	var page := 0
	var i := 0
	var sizes := []
	while i < ids.size():
		var holder := Node3D.new()
		add_child(holder)
		var cols := 4
		for k in 8:
			if i >= ids.size():
				break
			var id := ids[i]
			i += 1
			var path := ""
			for f in DirAccess.get_files_at("res://assets/models/" + id):
				if f.ends_with(".gltf"):
					path = "res://assets/models/%s/%s" % [id, f]
			if path == "":
				continue
			var inst: Node3D = load(path).instantiate()
			holder.add_child(inst)
			var aabb := _aabb(inst)
			var s := aabb.size
			var fit := 1.6 / maxf(maxf(s.x, s.y), maxf(s.z, 0.001))
			inst.scale = Vector3.ONE * fit
			var cx := float(k % cols) * 2.4 - 3.6
			var cy := -float(k / cols) * 2.6 + 1.3
			inst.position = Vector3(cx, cy, 0) - (aabb.position + Vector3(s.x * 0.5, 0, s.z * 0.5)) * fit
			var lbl := Label3D.new()
			lbl.text = "%s\n%.2f x %.2f x %.2f m" % [id, s.x, s.y, s.z]
			lbl.font_size = 40
			lbl.pixel_size = 0.004
			lbl.position = Vector3(cx, cy - 0.25, 0.5)
			holder.add_child(lbl)
			sizes.append("%s %.2f %.2f %.2f" % [id, s.x, s.y, s.z])
		cam.position = Vector3(0, 0.2, 9.5)
		cam.fov = 50
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/gallery/sheet_%02d.png" % page))
		page += 1
		holder.queue_free()
	var f := FileAccess.open("res://shots/gallery/sizes.txt", FileAccess.WRITE)
	f.store_string("\n".join(sizes))
	f.close()
	get_tree().quit()

func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.get_aabb()
		var t := (n as Node3D).global_transform.affine_inverse() * mi.global_transform
		b = t * b
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out
