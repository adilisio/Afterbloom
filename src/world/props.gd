class_name Props
extends RefCounted
## Spawns Poly Haven models by id. Can extract a single piece ("pick") from multi-object sets.

static var _paths := {}
static var _scenes := {}


static func path(id: String) -> String:
	if _paths.has(id):
		return _paths[id]
	var dir := "res://assets/models/" + id
	var found := ""
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			f = f.trim_suffix(".import")
			if f.ends_with(".gltf"):
				found = dir + "/" + f
				break
	_paths[id] = found
	return found


static func exists(id: String) -> bool:
	return path(id) != ""


## opts: pick (String node name), collide (bool, default true), scale (float), shrink (collision margin, m)
static func spawn(parent: Node, id: String, pos: Vector3, rot_y_deg := 0.0, opts := {}) -> Node3D:
	var p := path(id)
	if p == "":
		push_warning("Props: missing model " + id)
		return null
	if not _scenes.has(p):
		_scenes[p] = load(p)
	var inst: Node3D = (_scenes[p] as PackedScene).instantiate()
	var root := inst
	if opts.has("pick"):
		root = _pick(inst, String(opts.pick))
		inst.free()
		if root == null:
			push_warning("Props: no node %s in %s" % [opts.pick, id])
			return null
	root.name = id
	parent.add_child(root)
	var s: float = opts.get("scale", 1.0)
	root.scale = Vector3.ONE * s
	root.position = pos
	root.rotation_degrees.y = rot_y_deg
	if opts.get("shadow", true) == false:
		for m in root.find_children("*", "GeometryInstance3D", true, false):
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if opts.get("hang", false):
		# place so the top of the model touches pos (ceiling fixtures)
		var b := local_aabb(root)
		root.position.y = pos.y - (b.position.y + b.size.y) * s
	elif opts.get("ground", false):
		var b2 := local_aabb(root)
		root.position.y = pos.y - b2.position.y * s
	if opts.get("collide", true):
		add_box_collision(root, float(opts.get("shrink", 0.02)))
	return root


static func _pick(inst: Node3D, node_name: String) -> Node3D:
	var target: Node3D = inst.find_child(node_name, true, false)
	if target == null:
		return null
	var xf := Transform3D.IDENTITY
	var cur: Node = target
	while cur != inst and cur != null:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	var holder := Node3D.new()
	var dup: Node3D = target.duplicate()
	holder.add_child(dup)
	dup.transform = xf
	var b := local_aabb(holder)
	var off := Vector3(b.get_center().x, b.position.y, b.get_center().z)
	dup.transform = Transform3D(Basis(), -off) * xf
	return holder


static func local_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != n and cur != null:
			t = (cur as Node3D).transform * t
			cur = cur.get_parent()
		var b := t * mi.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


static func add_box_collision(n: Node3D, shrink := 0.02) -> StaticBody3D:
	var b := local_aabb(n)
	if b.size.length() < 0.05:
		return null
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = (b.size - Vector3.ONE * shrink * 2.0).max(Vector3.ONE * 0.02)
	cs.shape = bs
	cs.position = b.get_center()
	body.add_child(cs)
	n.add_child(body)
	return body


## Tints every surface (used for aged/dusty looks). Duplicates materials.
static func tint(n: Node, c: Color, extra_rough := 0.0) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var d: StandardMaterial3D = mat.duplicate()
				d.albedo_color = d.albedo_color * c
				d.roughness = clampf(d.roughness + extra_rough, 0.0, 1.0)
				mi.set_surface_override_material(i, d)
