class_name Geo
extends RefCounted
## Geometry helpers for building architecture in code: boxes, walls with openings, windows, roofs.
## Static bodies get meta "surface" (wood/concrete/metal/carpet/grass/gravel) for footsteps & impacts.


static func box(parent: Node, center: Vector3, size: Vector3, mat: Material, collide := true, surface := "concrete", rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = center
	mi.rotation.y = rot_y
	if collide:
		var body := StaticBody3D.new()
		body.set_meta("surface", surface)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Box spanning from a to b on the floor plane (x,z), with given base y, height and thickness.
static func slab(parent: Node, a: Vector3, b: Vector3, height: float, thick: float, mat: Material, collide := true, surface := "concrete") -> MeshInstance3D:
	var d := b - a
	d.y = 0
	var len := d.length()
	var mid := (a + b) * 0.5
	mid.y = a.y + height * 0.5
	var ang := atan2(-d.z, d.x)
	return box(parent, mid, Vector3(len, height, thick), mat, collide, surface, ang)


## Wall from a to b (y = floor level). openings: [{at: dist from a to opening centre, w, y0, y1}]
## Two halves: inner side (left of a->b when looking from above with +y up... use side_in = +1 for normal = (-d.z, d.x)) gets mat_in.
static func wall(parent: Node, a: Vector3, b: Vector3, height: float, thick: float, mat_in: Material, mat_out: Material, openings := [], surface := "wood") -> void:
	var d := b - a
	d.y = 0
	var len := d.length()
	var dir := d / len
	var nrm := Vector3(-dir.z, 0, dir.x)  # points to the "inner" side
	var segs := []  # [x0, x1, y0, y1] in wall-local coords
	var ops := openings.duplicate()
	ops.sort_custom(func(p, q): return p.at < q.at)
	var x := 0.0
	for o in ops:
		var ox0: float = o.at - o.w * 0.5
		var ox1: float = o.at + o.w * 0.5
		if ox0 > x + 0.001:
			segs.append([x, ox0, 0.0, height])
		if o.y0 > 0.001:
			segs.append([ox0, ox1, 0.0, o.y0])
		if o.y1 < height - 0.001:
			segs.append([ox0, ox1, o.y1, height])
		x = ox1
	if x < len - 0.001:
		segs.append([x, len, 0.0, height])
	var ang := atan2(-dir.z, dir.x)
	for s in segs:
		var cx: float = (s[0] + s[1]) * 0.5
		var cy: float = (s[2] + s[3]) * 0.5
		var size := Vector3(s[1] - s[0], s[3] - s[2], thick * 0.5)
		var base := a + dir * cx + Vector3(0, cy, 0)
		box(parent, base + nrm * thick * 0.25, size, mat_in, true, surface, ang)
		box(parent, base - nrm * thick * 0.25, size, mat_out, true, surface, ang)


## Window frame + glass + sill placed in a wall opening. a/b = wall endpoints, o = opening dict.
static func window(parent: Node, a: Vector3, b: Vector3, thick: float, o: Dictionary, frame_mat: Material, glass_mat: Material, broken := false) -> void:
	var d := b - a
	d.y = 0
	var dir := d.normalized()
	var ang := atan2(-dir.z, dir.x)
	var c: Vector3 = a + dir * float(o.at)
	var w: float = o.w
	var y0: float = o.y0
	var y1: float = o.y1
	var h := y1 - y0
	var ft := 0.06
	var depth := thick + 0.02
	box(parent, c + Vector3(0, y0 + ft * 0.5, 0), Vector3(w, ft, depth), frame_mat, false, "wood", ang)
	box(parent, c + Vector3(0, y1 - ft * 0.5, 0), Vector3(w, ft, depth), frame_mat, false, "wood", ang)
	box(parent, c + dir * (w * 0.5 - ft * 0.5) + Vector3(0, y0 + h * 0.5, 0), Vector3(ft, h, depth), frame_mat, false, "wood", ang)
	box(parent, c - dir * (w * 0.5 - ft * 0.5) + Vector3(0, y0 + h * 0.5, 0), Vector3(ft, h, depth), frame_mat, false, "wood", ang)
	# muntins: one vertical + one horizontal bar
	box(parent, c + Vector3(0, y0 + h * 0.5, 0), Vector3(0.035, h, 0.04), frame_mat, false, "wood", ang)
	box(parent, c + Vector3(0, y0 + h * 0.55, 0), Vector3(w, 0.035, 0.04), frame_mat, false, "wood", ang)
	# sill (sticks out on both sides)
	box(parent, c + Vector3(0, y0 - 0.03, 0), Vector3(w + 0.12, 0.05, thick + 0.16), frame_mat, true, "wood", ang)
	if not broken:
		var g := box(parent, c + Vector3(0, y0 + h * 0.5, 0), Vector3(w - ft, h - ft, 0.01), glass_mat, true, "glass", ang)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var g := box(parent, c + Vector3(0, y0 + h * 0.2, 0), Vector3(w - ft, h * 0.3, 0.01), glass_mat, false, "glass", ang)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var blocker := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(w, h, 0.1)
		cs.shape = bs
		blocker.add_child(cs)
		parent.add_child(blocker)
		blocker.position = c + Vector3(0, y0 + h * 0.5, 0)
		blocker.rotation.y = ang


## Gable roof over rectangle [x0,x1]x[z0,z1] at eave height y; ridge along X. Returns the roof node.
static func gable_roof(parent: Node, x0: float, x1: float, z0: float, z1: float, y: float, pitch_h: float, overhang: float, mat_roof: Material, mat_gable: Material, ridge_along_x := true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var w := (z1 - z0) if ridge_along_x else (x1 - x0)
	var l := (x1 - x0) if ridge_along_x else (z1 - z0)
	var half := w * 0.5 + overhang
	var slope_len := sqrt(half * half + pitch_h * pitch_h)
	var ang := atan2(pitch_h, half)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var th := 0.12
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(l + overhang * 2.0, th, slope_len)
		mi.mesh = bm
		mi.material_override = mat_roof
		root.add_child(mi)
		var off: float = side * half * 0.5
		mi.position = Vector3(cx, y + pitch_h * 0.5 - 0.02 + th * 0.5, cz + off) if ridge_along_x else Vector3(cx + off, y + pitch_h * 0.5 - 0.02 + th * 0.5, cz)
		if ridge_along_x:
			mi.rotation.x = side * ang
		else:
			mi.rotation.y = PI * 0.5
			mi.rotation.x = side * ang
			mi.rotation_order = EULER_ORDER_YXZ
		var body := StaticBody3D.new()
		body.set_meta("surface", "wood")
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		body.add_child(cs)
		mi.add_child(body)
	# gable triangles
	var hw := w * 0.5
	for end in [0, 1]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var e: float = (x0 if end == 0 else x1) if ridge_along_x else (z0 if end == 0 else z1)
		var p0: Vector3
		var p1: Vector3
		var p2: Vector3
		if ridge_along_x:
			p0 = Vector3(e, y, cz - hw)
			p1 = Vector3(e, y, cz + hw)
			p2 = Vector3(e, y + pitch_h * (hw / half), cz)
		else:
			p0 = Vector3(cx - hw, y, e)
			p1 = Vector3(cx + hw, y, e)
			p2 = Vector3(cx, y + pitch_h * (hw / half), e)
		for tri in [[p0, p1, p2], [p0, p2, p1]]:
			for v: Vector3 in tri:
				st.set_uv(Vector2(v.x + v.z, v.y))
				st.add_vertex(v)
		st.generate_normals()
		var gm := MeshInstance3D.new()
		gm.mesh = st.commit()
		gm.material_override = mat_gable
		root.add_child(gm)
	return root


## Straight staircase from base (bottom front centre) going toward dir, total rise/run, width.
static func stairs(parent: Node, base: Vector3, dir: Vector3, rise: float, run: float, width: float, mat: Material, surface := "concrete") -> void:
	var steps := int(ceil(rise / 0.18))
	var sh := rise / steps
	var sd := run / steps
	var ang := atan2(-dir.z, dir.x)
	for i in steps:
		var c := base + dir * (sd * (i + 0.5)) + Vector3(0, sh * (i + 0.5), 0)
		box(parent, c - Vector3(0, sh * i * 0.5, 0), Vector3(sd, sh * (i + 1), width), mat, false, surface, ang)
	# smooth ramp collider so the player glides up
	var body := StaticBody3D.new()
	body.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var slope := sqrt(rise * rise + run * run)
	bs.size = Vector3(slope, 0.1, width)
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)
	body.position = base + dir * run * 0.5 + Vector3(0, rise * 0.5 - 0.02, 0)
	body.rotation = Vector3(0, ang, atan2(rise, run))
	body.rotation_order = EULER_ORDER_YXZ


static func omni(parent: Node, pos: Vector3, color: Color, energy: float, rng: float, shadow := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadow
	l.light_bake_mode = Light3D.BAKE_DYNAMIC
	parent.add_child(l)
	l.position = pos
	return l


static func label(parent: Node, pos: Vector3, text: String, size := 64, rot_y := 0.0, col := Color(0.1, 0.1, 0.1)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0025
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	parent.add_child(l)
	l.position = pos
	l.rotation.y = rot_y
	return l


## Flat quad showing a generated texture (posters, signs). size in metres; faces +Z locally.
static func decal_quad(parent: Node, pos: Vector3, size: Vector2, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	mi.rotation = rot
	return mi
