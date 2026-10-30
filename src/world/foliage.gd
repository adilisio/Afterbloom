class_name Foliage
extends RefCounted
## Procedural vegetation: deciduous trees (autumn), coastal pines, dead trees, and chunked grass MultiMeshes.

static var _tree_cache := {}
static var _mats := {}

const AUTUMN := [
	[Color(0.72, 0.18, 0.06), Color(0.95, 0.42, 0.1)],
	[Color(0.85, 0.45, 0.08), Color(0.98, 0.75, 0.2)],
	[Color(0.55, 0.42, 0.1), Color(0.85, 0.68, 0.18)],
	[Color(0.3, 0.42, 0.12), Color(0.62, 0.62, 0.18)],
]
const AFTER := [
	[Color(0.45, 0.35, 0.42), Color(0.7, 0.55, 0.62)],
	[Color(0.5, 0.42, 0.22), Color(0.72, 0.6, 0.35)],
]


static func leaf_mat(ca: Color, cb: Color, tex := "leaf_cluster", grass := false) -> ShaderMaterial:
	var key := "%s%s%s%s" % [ca.to_html(), cb.to_html(), tex, grass]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://src/world/shaders/foliage.gdshader")
	m.set_shader_parameter("alpha_tex", load("res://assets/textures/foliage/%s.png" % tex))
	m.set_shader_parameter("color_a", ca)
	m.set_shader_parameter("color_b", cb)
	m.set_shader_parameter("is_grass", 1.0 if grass else 0.0)
	m.set_shader_parameter("sway_height", 6.0)
	_mats[key] = m
	return m


static func _card(st: SurfaceTool, c: Vector3, size: float, nrm: Vector3, rng: RandomNumberGenerator) -> void:
	# random-oriented quad, normal pushed outward from the canopy centre for soft volumetric shading
	var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized() * size * 0.5
	var v := axis.cross(u).normalized() * size * 0.5
	var corners := [c - u - v, c + u - v, c + u + v, c - u + v]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(nrm)
		st.set_uv(uvs[idx])
		st.add_vertex(corners[idx])


static func _branch(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, seg := 6) -> void:
	var d := (b - a).normalized()
	var u := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := d.cross(u).normalized()
	var len := a.distance_to(b)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var n0 := u * cos(a0) + v * sin(a0)
		var n1 := u * cos(a1) + v * sin(a1)
		var p00 := a + n0 * r0
		var p01 := a + n1 * r0
		var p10 := b + n0 * r1
		var p11 := b + n1 * r1
		var uu0 := float(i) / seg
		var uu1 := float(i + 1) / seg
		for e in [[p00, n0, Vector2(uu0, 0)], [p10, n0, Vector2(uu0, len)], [p11, n1, Vector2(uu1, len)], [p00, n0, Vector2(uu0, 0)], [p11, n1, Vector2(uu1, len)], [p01, n1, Vector2(uu1, 0)]]:
			st.set_normal(e[1])
			st.set_uv(e[2] * Vector2(1, 0.5))
			st.add_vertex(e[0])


## Deciduous tree mesh (2 surfaces: bark, leaves). Cached per (seed, palette, scale).
static func tree_mesh(seed: int, palette: Array, height := 8.0, leaves := true) -> ArrayMesh:
	var key := "%d:%s:%s:%s" % [seed, palette[0].to_html(), height, leaves]
	if _tree_cache.has(key):
		return _tree_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lf := SurfaceTool.new()
	lf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_h := height * rng.randf_range(0.38, 0.5)
	var top := Vector3(rng.randf_range(-0.3, 0.3), trunk_h, rng.randf_range(-0.3, 0.3))
	var r := height * 0.035
	_branch(bark, Vector3.ZERO, top, r, r * 0.7, 8)
	var crown_c := top + Vector3(0, height * 0.22, 0)
	var crown_r := height * rng.randf_range(0.3, 0.38)
	var tips: Array[Vector3] = []
	for i in rng.randi_range(5, 7):
		var ang := TAU * i / 6.0 + rng.randf_range(-0.4, 0.4)
		var up := rng.randf_range(0.35, 0.9)
		var tip := top + Vector3(cos(ang) * crown_r * 0.85, height * 0.28 * up + 0.4, sin(ang) * crown_r * 0.85)
		_branch(bark, top - Vector3(0, rng.randf_range(0.0, 0.8), 0), tip, r * 0.6, r * 0.18, 5)
		tips.append(tip)
		var mid := (top + tip) * 0.5 + Vector3(0, 0.3, 0)
		var twig := mid + Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.0), rng.randf_range(-1, 1)) * crown_r * 0.45
		_branch(bark, mid, twig, r * 0.25, r * 0.08, 4)
		tips.append(twig)
	if leaves:
		var cards := int(height * 26)
		for i in cards:
			var tip: Vector3 = tips[rng.randi() % tips.size()]
			var p := tip + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.9), rng.randf_range(-1, 1)) * crown_r * rng.randf_range(0.25, 0.75)
			var n := (p - crown_c).normalized()
			n = (n + Vector3.UP * 0.4).normalized()
			_card(lf, p, crown_r * rng.randf_range(0.6, 0.95), n, rng)
	bark.generate_tangents()
	var mesh := bark.commit()
	mesh.surface_set_material(0, Mats.tex("bark_brown_02", 1.2, Color(0.85, 0.8, 0.75)))
	if leaves:
		lf.commit(mesh)
		mesh.surface_set_material(1, leaf_mat(palette[0], palette[1]))
	_tree_cache[key] = mesh
	return mesh


## Coastal pine: tall trunk with tiers of drooping branch cards.
static func pine_mesh(seed: int, height := 11.0, after := false) -> ArrayMesh:
	var key := "pine:%d:%s:%s" % [seed, height, after]
	if _tree_cache.has(key):
		return _tree_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lf := SurfaceTool.new()
	lf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := height * 0.028
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	_branch(bark, Vector3.ZERO, Vector3(0, height, 0) + lean, r, r * 0.25, 8)
	var tiers := int(height * 1.6)
	for t in tiers:
		var f := float(t) / tiers
		var y := height * (0.28 + f * 0.72)
		var reach := height * 0.3 * (1.0 - f * 0.85) + 0.4
		var count := int(lerpf(7, 3, f))
		for k in count:
			var ang := TAU * k / count + rng.randf() * 1.2 + t * 0.7
			var dir := Vector3(cos(ang), 0, sin(ang))
			var base := Vector3(0, y, 0) + lean * (y / height)
			# branch card: a quad from the trunk outwards, drooping
			var tip := base + dir * reach + Vector3(0, -reach * 0.35, 0)
			var side := dir.cross(Vector3.UP).normalized() * reach * 0.45
			var nrm := (dir + Vector3.UP * 0.6).normalized()
			var corners := [base - side * 0.3, tip - side, tip + side, base + side * 0.3]
			var uvs := [Vector2(0, 0.0), Vector2(1, 0.0), Vector2(1, 1.0), Vector2(0, 1.0)]
			for idx in [0, 1, 2, 0, 2, 3]:
				lf.set_normal(nrm)
				lf.set_uv(uvs[idx])
				lf.add_vertex(corners[idx])
			# a crossing card for volume
			var up2 := Vector3.UP * reach * 0.35
			var c2 := [base - up2 * 0.3, tip - up2, tip + up2, base + up2 * 0.3]
			for idx in [0, 1, 2, 0, 2, 3]:
				lf.set_normal(nrm)
				lf.set_uv(uvs[idx])
				lf.add_vertex(c2[idx])
	bark.generate_tangents()
	var mesh := bark.commit()
	mesh.surface_set_material(0, Mats.tex("pine_bark", 1.5))
	lf.commit(mesh)
	var ca := Color(0.12, 0.22, 0.12) if not after else Color(0.25, 0.22, 0.2)
	var cb := Color(0.25, 0.38, 0.18) if not after else Color(0.42, 0.36, 0.33)
	mesh.surface_set_material(1, leaf_mat(ca, cb, "pine_branch"))
	_tree_cache[key] = mesh
	return mesh


static func place_tree(parent: Node, pos: Vector3, kind: String, seed: int, after := false, scale := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	match kind:
		"pine":
			mi.mesh = pine_mesh(seed % 4, 10.0 + (seed % 4) * 1.5, after)
		"dead":
			mi.mesh = tree_mesh(seed % 3 + 100, AUTUMN[0], 7.0, false)
		_:
			var pal: Array = AFTER[seed % AFTER.size()] if after else AUTUMN[seed % AUTUMN.size()]
			mi.mesh = tree_mesh(seed % 5, pal, 7.0 + (seed % 3) * 1.2, true)
	mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	mi.visibility_range_end = 380.0
	parent.add_child(mi)
	mi.position = pos - Vector3(0, 0.15, 0)
	mi.rotation.y = rng.randf() * TAU
	mi.scale = Vector3.ONE * scale * rng.randf_range(0.85, 1.15)
	# trunk collider
	var body := StaticBody3D.new()
	body.set_meta("surface", "wood")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.28 * scale
	cyl.height = 4.0
	cs.shape = cyl
	cs.position.y = 2.0
	body.add_child(cs)
	mi.add_child(body)
	return mi


static func grass_clump_mesh() -> ArrayMesh:
	if _tree_cache.has("grass"):
		return _tree_cache["grass"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := PI * k / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.38
		var h := 0.5
		var corners := [-d, d, d + Vector3(0, h, 0), -d + Vector3(0, h, 0)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])
	var m := st.commit()
	_tree_cache["grass"] = m
	return m


## Scatter grass clumps over a rectangle, in chunks with distance culling. accept(x,z)->bool filters spots.
static func grass_field(parent: Node, rect: Rect2, density: float, accept: Callable, after := false, seed := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var chunk := 24.0
	var mat := leaf_mat(Color(0.5, 0.55, 0.26), Color(0.82, 0.78, 0.45), "grass_blades", true) if not after else leaf_mat(Color(0.55, 0.5, 0.42), Color(0.82, 0.74, 0.6), "grass_blades", true)
	var mesh := grass_clump_mesh()
	var cx := rect.position.x
	while cx < rect.end.x:
		var cz := rect.position.y
		while cz < rect.end.y:
			var xfs: Array[Transform3D] = []
			var n := int(chunk * chunk * density)
			for i in n:
				var x := cx + rng.randf() * chunk
				var z := cz + rng.randf() * chunk
				if not accept.call(x, z):
					continue
				var y := Layout.height(x, z)
				var s := rng.randf_range(0.45, 0.9) * (1.5 if after else 1.0)
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
				xfs.append(Transform3D(b, Vector3(x, y - 0.03, z)))
			if not xfs.is_empty():
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mesh
				mm.instance_count = xfs.size()
				for i in xfs.size():
					mm.set_instance_transform(i, xfs[i])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = mat
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 70.0
				mmi.visibility_range_end_margin = 10.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				parent.add_child(mmi)
			cz += chunk
		cx += chunk
