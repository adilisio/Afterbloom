class_name ModelKit
extends RefCounted
## Shared helpers for the procedural actors: cached PBR materials, mesh builders
## (lathe / rounded box / swept tube), rig helpers, hitboxes and debris.
## Everything here is build-time only (no per-frame allocation).

const HITBOX_LAYER := 8 ## physics layer 4

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _tex: Dictionary = {}


# --------------------------------------------------------------------------
# Small math helpers (used by every model's _process)
# --------------------------------------------------------------------------

## Frame-rate independent exponential smoothing.
static func damp(a: float, b: float, rate: float, dt: float) -> float:
	return lerpf(a, b, 1.0 - exp(-rate * dt))


static func damp_v3(a: Vector3, b: Vector3, rate: float, dt: float) -> Vector3:
	return a.lerp(b, 1.0 - exp(-rate * dt))


## Trapezoid envelope: 0 before a, smooth rise to 1 at b, hold, smooth fall to 0 from c to d.
static func env(t: float, a: float, b: float, c: float, d: float) -> float:
	if t <= a or t >= d:
		return 0.0
	if t < b:
		return smoothstep(a, b, t)
	if t > c:
		return 1.0 - smoothstep(c, d, t)
	return 1.0


## Smooth 0..1 ramp between a and b.
static func ramp(t: float, a: float, b: float) -> float:
	return smoothstep(a, b, t)


## Ease-out-back (overshoot) for poppy motion, x in 0..1.
static func ease_back(x: float, s := 1.70158) -> float:
	x = clampf(x, 0.0, 1.0) - 1.0
	return x * x * ((s + 1.0) * x + s) + 1.0


# --------------------------------------------------------------------------
# Textures
# --------------------------------------------------------------------------

## Seamless noise texture (cached). If `ramp` is given it colours the noise.
static func noise_tex(key: String, freq: float, ramp_g: Gradient = null, as_normal := false, bump := 4.0, size := 256, octaves := 4, seed_v := 7) -> NoiseTexture2D:
	if _tex.has(key):
		return _tex[key]
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = octaves
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	t.as_normal_map = as_normal
	t.bump_strength = bump
	if ramp_g:
		t.color_ramp = ramp_g
	_tex[key] = t
	return t


static func grad(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	return g


static func load_tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex[path] = t
	return t


# --------------------------------------------------------------------------
# Materials (cached by key)
# --------------------------------------------------------------------------

static func has_mat(key: String) -> bool:
	return _mats.has(key)


static func get_mat(key: String) -> Material:
	return _mats.get(key)


static func put_mat(key: String, m: Material) -> Material:
	_mats[key] = m
	return m


static func pbr(key: String, albedo: Color, metallic := 0.0, roughness := 0.5) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = roughness
	_mats[key] = m
	return m


## Polished warm brass. Aged = tarnish blotches (patina in low areas of the noise), still shiny.
static func brass(aged := false) -> StandardMaterial3D:
	var key := "brass_aged" if aged else "brass"
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.metallic = 0.92
	m.metallic_specular = 0.6
	m.roughness = 0.3
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3, 3, 3)
	m.uv1_triplanar_sharpness = 2.0
	m.roughness_texture = noise_tex("rough_fine", 0.02, grad([Color(0.62, 0.62, 0.62), Color(1, 1, 1)], [0.0, 1.0]))
	if aged:
		m.albedo_color = Color(1, 1, 1)
		m.albedo_texture = noise_tex("patina", 0.03, grad(
			[Color(0.30, 0.32, 0.22), Color(0.55, 0.45, 0.27), Color(0.78, 0.59, 0.34), Color(0.83, 0.63, 0.36)],
			[0.0, 0.22, 0.4, 1.0]), false, 4.0, 256, 6, 31)
		m.metallic_texture = noise_tex("patina_metal", 0.03, grad(
			[Color(0.4, 0.4, 0.4), Color(1, 1, 1)], [0.18, 0.4]), false, 4.0, 256, 6, 31)
		m.roughness_texture = noise_tex("patina_rough", 0.03, grad(
			[Color(1, 1, 1), Color(0.62, 0.62, 0.62)], [0.18, 0.45]), false, 4.0, 256, 6, 31)
		m.uv1_scale = Vector3(2, 2, 2)
		m.roughness = 0.5
	else:
		m.albedo_color = Color(0.86, 0.65, 0.37)
	_mats[key] = m
	return m


static func copper(aged := false) -> StandardMaterial3D:
	var key := "copper_aged" if aged else "copper"
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.80, 0.47, 0.33) if not aged else Color(0.62, 0.40, 0.30)
	m.metallic = 0.9
	m.roughness = 0.32 if not aged else 0.45
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3, 3, 3)
	m.roughness_texture = noise_tex("rough_fine", 0.02, grad([Color(0.62, 0.62, 0.62), Color(1, 1, 1)], [0.0, 1.0]))
	_mats[key] = m
	return m


static func chrome() -> StandardMaterial3D:
	var m := pbr("chrome", Color(0.80, 0.80, 0.82), 1.0, 0.14)
	return m


## Glossy vitreous enamel (clearcoated paint).
static func enamel(key: String, color: Color, roughness := 0.3) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.0
	m.roughness = roughness
	m.clearcoat_enabled = true
	m.clearcoat = 0.7
	m.clearcoat_roughness = 0.12
	_mats[key] = m
	return m


static func rubber() -> StandardMaterial3D:
	if _mats.has("rubber"):
		return _mats["rubber"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.055, 0.05, 0.048)
	m.roughness = 0.72
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(6, 6, 6)
	m.normal_enabled = true
	m.normal_texture = noise_tex("rubber_n", 0.08, null, true, 2.0)
	m.normal_scale = 0.25
	_mats["rubber"] = m
	return m


static func glass(key := "glass", tint := Color(0.9, 0.95, 1.0, 0.1)) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = tint
	m.metallic = 0.0
	m.roughness = 0.04
	m.metallic_specular = 1.0
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.2
	_mats[key] = m
	return m


## Emissive (self-lit) material. Not cached if `unique` (so its energy can be animated).
static func glow(key: String, color: Color, energy := 3.0, unique := false) -> StandardMaterial3D:
	if not unique and _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.3)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	if not unique:
		_mats[key] = m
	return m


## Dull woven fabric. Uses the project's fabric normal map if present.
static func fabric(key: String, color: Color, roughness := 0.92, tex_scale := 3.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(tex_scale, tex_scale, tex_scale)
	var n := load_tex("res://assets/textures/fabric_pattern_05/fabric_pattern_05_nor_gl.jpg")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.8
	m.albedo_texture = noise_tex("fabric_mottle", 0.03, grad([Color(0.78, 0.78, 0.78), Color(1, 1, 1)], [0.0, 1.0]))
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	_mats[key] = m
	return m


# --------------------------------------------------------------------------
# Primitive meshes (cached)
# --------------------------------------------------------------------------

static func sphere(r: float, segs := 16, rings := 10) -> SphereMesh:
	var key := "sph_%.4f_%d_%d" % [r, segs, rings]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = rings
	_meshes[key] = m
	return m


static func hemisphere(r: float, segs := 16, rings := 8) -> SphereMesh:
	var key := "hsph_%.4f_%d_%d" % [r, segs, rings]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r
	m.is_hemisphere = true
	m.radial_segments = segs
	m.rings = rings
	_meshes[key] = m
	return m


static func cyl(r_top: float, r_bot: float, h: float, segs := 16, caps := true) -> CylinderMesh:
	var key := "cyl_%.4f_%.4f_%.4f_%d_%s" % [r_top, r_bot, h, segs, caps]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	m.cap_top = caps
	m.cap_bottom = caps
	_meshes[key] = m
	return m


static func capsule(r: float, h: float, segs := 12, rings := 4) -> CapsuleMesh:
	var key := "cap_%.4f_%.4f_%d_%d" % [r, h, segs, rings]
	if _meshes.has(key):
		return _meshes[key]
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = segs
	m.rings = rings
	_meshes[key] = m
	return m


static func box(size: Vector3) -> BoxMesh:
	var key := "box_%s" % [size]
	if _meshes.has(key):
		return _meshes[key]
	var m := BoxMesh.new()
	m.size = size
	_meshes[key] = m
	return m


static func torus(inner: float, outer: float, rings := 24, ring_segs := 8) -> TorusMesh:
	var key := "tor_%.4f_%.4f_%d_%d" % [inner, outer, rings, ring_segs]
	if _meshes.has(key):
		return _meshes[key]
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = ring_segs
	_meshes[key] = m
	return m


## Cheap domed rivet / bolt head (18 tris), dome along +Y.
static func rivet(r: float) -> ArrayMesh:
	var key := "rivet_%.4f" % r
	if _meshes.has(key):
		return _meshes[key]
	var m := lathe(PackedVector2Array([Vector2(r, -r * 0.2), Vector2(r, 0.0), Vector2(r * 0.72, r * 0.55), Vector2(0.0, r * 0.75)]), 6)
	_meshes[key] = m
	return m


static func cached_mesh(key: String) -> Mesh:
	return _meshes.get(key)


static func cache_mesh(key: String, m: Mesh) -> Mesh:
	_meshes[key] = m
	return m


# --------------------------------------------------------------------------
# Custom mesh builders
# --------------------------------------------------------------------------

## Adds a triangle, flipping winding if needed so the face points along the supplied normals.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, col := Color.WHITE) -> void:
	var fn := (c - a).cross(b - a)
	if fn.dot(na + nb + nc) < 0.0:
		var tv := b; b = c; c = tv
		var tn := nb; nb = nc; nc = tn
		var tu := ub; ub = uc; uc = tu
	st.set_color(col)
	st.set_normal(na); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(nb); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(nc); st.set_uv(uc); st.add_vertex(c)


## Flat-shaded triangle (normal from geometry, oriented away from `outward_hint` origin).
static func flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out_dir: Vector3, col := Color.WHITE) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot(out_dir) < 0.0:
		n = -n
	tri(st, a, b, c, n, n, n, Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), col)


## Surface of revolution around +Y. `profile` = (radius, y) points, bottom -> top.
## Repeat a point to make a hard crease. Angle 0 faces -Z; a0..a1 can build partial panels.
static func lathe(profile: PackedVector2Array, segments := 32, a0 := 0.0, a1 := TAU, deform: Callable = Callable()) -> ArrayMesh:
	var n := profile.size()
	var nrm := PackedVector2Array()
	nrm.resize(n)
	var vlen := PackedFloat32Array()
	vlen.resize(n)
	var acc := 0.0
	for i in n:
		var p := profile[i]
		var has_prev := i > 0 and not profile[i - 1].is_equal_approx(p)
		var has_next := i < n - 1 and not profile[i + 1].is_equal_approx(p)
		var t := Vector2.ZERO
		if has_prev:
			t += (p - profile[i - 1]).normalized()
		if has_next:
			t += (profile[i + 1] - p).normalized()
		if t.length_squared() < 1e-8:
			t = Vector2(0, 1)
		t = t.normalized()
		nrm[i] = Vector2(t.y, -t.x)
		if i > 0:
			acc += p.distance_to(profile[i - 1])
		vlen[i] = acc
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var full := is_equal_approx(a1 - a0, TAU)
	for i in n - 1:
		var pa := profile[i]
		var pb := profile[i + 1]
		if pa.is_equal_approx(pb):
			continue
		for j in segments:
			var ang0 := a0 + (a1 - a0) * float(j) / segments
			var ang1 := a0 + (a1 - a0) * float(j + 1) / segments
			if full and j == segments - 1:
				ang1 = a0 + TAU
			var d0 := Vector3(sin(ang0), 0, -cos(ang0))
			var d1 := Vector3(sin(ang1), 0, -cos(ang1))
			var v00 := d0 * pa.x + Vector3(0, pa.y, 0)
			var v01 := d1 * pa.x + Vector3(0, pa.y, 0)
			var v10 := d0 * pb.x + Vector3(0, pb.y, 0)
			var v11 := d1 * pb.x + Vector3(0, pb.y, 0)
			var n00 := (d0 * nrm[i].x + Vector3(0, nrm[i].y, 0)).normalized()
			var n01 := (d1 * nrm[i].x + Vector3(0, nrm[i].y, 0)).normalized()
			var n10 := (d0 * nrm[i + 1].x + Vector3(0, nrm[i + 1].y, 0)).normalized()
			var n11 := (d1 * nrm[i + 1].x + Vector3(0, nrm[i + 1].y, 0)).normalized()
			if deform.is_valid():
				v00 = deform.call(v00); v01 = deform.call(v01); v10 = deform.call(v10); v11 = deform.call(v11)
			var u0 := float(j) / segments
			var u1 := float(j + 1) / segments
			var va := vlen[i] / maxf(acc, 0.0001)
			var vb := vlen[i + 1] / maxf(acc, 0.0001)
			if pa.x > 1e-5:
				tri(st, v00, v01, v10, n00, n01, n10, Vector2(u0, va), Vector2(u1, va), Vector2(u0, vb))
			if pb.x > 1e-5:
				tri(st, v10, v01, v11, n10, n01, n11, Vector2(u0, vb), Vector2(u1, va), Vector2(u1, vb))
	st.generate_tangents()
	return st.commit()


## Box with rounded edges/corners (radius r), smooth normals.
static func rounded_box(size: Vector3, r: float, seg := 3) -> ArrayMesh:
	var key := "rbox_%s_%.4f_%d" % [size, r, seg]
	if _meshes.has(key):
		return _meshes[key]
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.999)
	var inner := h - Vector3(r, r, r)
	var cx := _rb_coords(h.x, r, seg)
	var cy := _rb_coords(h.y, r, seg)
	var cz := _rb_coords(h.z, r, seg)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var ua := (axis + 1) % 3
			var va := (axis + 2) % 3
			var cu: PackedFloat32Array = [cx, cy, cz][ua]
			var cv: PackedFloat32Array = [cx, cy, cz][va]
			for iu in cu.size() - 1:
				for iv in cv.size() - 1:
					var q: Array[Vector3] = []
					var qn: Array[Vector3] = []
					for k in 4:
						var pu := cu[iu + (1 if k == 1 or k == 2 else 0)]
						var pv := cv[iv + (1 if k >= 2 else 0)]
						var p := Vector3.ZERO
						p[axis] = h[axis] * sgn
						p[ua] = pu
						p[va] = pv
						var c := p.clamp(-inner, inner)
						var d := p - c
						var dn := d.normalized()
						q.append(c + dn * r)
						qn.append(dn)
					var uv := func(p: Vector3) -> Vector2: return Vector2(p[ua] / size[ua] + 0.5, p[va] / size[va] + 0.5)
					tri(st, q[0], q[1], q[2], qn[0], qn[1], qn[2], uv.call(q[0]), uv.call(q[1]), uv.call(q[2]))
					tri(st, q[0], q[2], q[3], qn[0], qn[2], qn[3], uv.call(q[0]), uv.call(q[2]), uv.call(q[3]))
	st.generate_tangents()
	var m := st.commit()
	_meshes[key] = m
	return m


static func _rb_coords(h: float, r: float, seg: int) -> PackedFloat32Array:
	var inner := h - r
	var out := PackedFloat32Array()
	for k in range(seg, 0, -1):
		out.append(-inner - r * tan(float(k) / seg * PI * 0.25))
	out.append(-inner)
	out.append(inner)
	for k in range(1, seg + 1):
		out.append(inner + r * tan(float(k) / seg * PI * 0.25))
	return out


## Swept tube along a polyline with per-point radius (radius 0 = pointed tip).
## Uses parallel-transport frames. Optional vertex colour per point.
static func tube(path: PackedVector3Array, radii: PackedFloat32Array, sides := 8, cap_start := true, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	tube_into(st, path, radii, sides, cap_start, colors)
	st.generate_tangents()
	return st.commit()


static func tube_into(st: SurfaceTool, path: PackedVector3Array, radii: PackedFloat32Array, sides := 8, cap_start := true, colors: PackedColorArray = PackedColorArray()) -> void:
	var n := path.size()
	if n < 2:
		return
	var tangents: Array[Vector3] = []
	for i in n:
		var t: Vector3
		if i == 0:
			t = path[1] - path[0]
		elif i == n - 1:
			t = path[n - 1] - path[n - 2]
		else:
			t = path[i + 1] - path[i - 1]
		tangents.append(t.normalized())
	var normals: Array[Vector3] = []
	var nrm0 := tangents[0].cross(Vector3.UP)
	if nrm0.length_squared() < 1e-4:
		nrm0 = tangents[0].cross(Vector3.RIGHT)
	nrm0 = nrm0.normalized()
	normals.append(nrm0)
	for i in range(1, n):
		var prev := normals[i - 1]
		var axis := tangents[i - 1].cross(tangents[i])
		if axis.length_squared() > 1e-10:
			var ang := tangents[i - 1].angle_to(tangents[i])
			prev = prev.rotated(axis.normalized(), ang)
		normals.append((prev - tangents[i] * prev.dot(tangents[i])).normalized())
	var rings: Array[PackedVector3Array] = []
	var rnorms: Array[PackedVector3Array] = []
	for i in n:
		var b := tangents[i].cross(normals[i])
		var ring := PackedVector3Array()
		var rn := PackedVector3Array()
		for s in sides:
			var a := TAU * s / sides
			var dir := normals[i] * cos(a) + b * sin(a)
			ring.append(path[i] + dir * radii[i])
			rn.append(dir)
		rings.append(ring)
		rnorms.append(rn)
	for i in n - 1:
		var c0 := colors[i] if colors.size() > i else Color.WHITE
		var c1 := colors[i + 1] if colors.size() > i + 1 else Color.WHITE
		for s in sides:
			var s2 := (s + 1) % sides
			var u0 := float(s) / sides
			var u1 := float(s + 1) / sides
			var v0 := float(i) / (n - 1)
			var v1 := float(i + 1) / (n - 1)
			var na := rnorms[i][s]; var nb := rnorms[i][s2]; var nc := rnorms[i + 1][s]; var nd := rnorms[i + 1][s2]
			if radii[i + 1] < 1e-5:
				nc = (nc + tangents[i + 1] * 0.6).normalized(); nd = (nd + tangents[i + 1] * 0.6).normalized()
			if radii[i] > 1e-5:
				tri(st, rings[i][s], rings[i][s2], rings[i + 1][s], na, nb, nc, Vector2(u0, v0), Vector2(u1, v0), Vector2(u0, v1), c0.lerp(c1, 0.0))
			if radii[i + 1] > 1e-5 or radii[i] > 1e-5:
				tri(st, rings[i + 1][s], rings[i][s2], rings[i + 1][s2], nc, nb, nd, Vector2(u0, v1), Vector2(u1, v0), Vector2(u1, v1), c1)
	if cap_start and radii[0] > 1e-5:
		var cn := -tangents[0]
		for s in sides:
			tri(st, path[0], rings[0][s], rings[0][(s + 1) % sides], cn, cn, cn, Vector2(0.5, 0.5), Vector2.ZERO, Vector2.ZERO, colors[0] if colors.size() > 0 else Color.WHITE)
	if radii[n - 1] > 1e-5:
		var en := tangents[n - 1]
		for s in sides:
			tri(st, path[n - 1], rings[n - 1][(s + 1) % sides], rings[n - 1][s], en, en, en, Vector2(0.5, 0.5), Vector2.ZERO, Vector2.ZERO, colors[n - 1] if colors.size() > n - 1 else Color.WHITE)


## Gently pushes vertices of a mesh inward around `center` (a dent). Returns a new ArrayMesh.
static func dent_mesh(src: Mesh, center: Vector3, radius: float, depth: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			var d := verts[i].distance_to(center)
			if d < radius:
				var f := 1.0 - d / radius
				f = f * f * (3.0 - 2.0 * f)
				verts[i] -= norms[i] * depth * f
				var side := (verts[i] - center)
				side -= norms[i] * side.dot(norms[i])
				norms[i] = (norms[i] + side.normalized() * f * 0.9 * (depth / radius) * 6.0).normalized()
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, src.surface_get_material(si))
	return out


# --------------------------------------------------------------------------
# Scene-graph helpers
# --------------------------------------------------------------------------

static func pivot(parent: Node3D, node_name: String, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> Node3D:
	var p := Node3D.new()
	p.name = node_name
	p.position = pos
	p.rotation_degrees = rot_deg
	parent.add_child(p)
	return p


static func mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE, node_name := "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	if mat:
		m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot_deg
	m.scale = scl
	if node_name != "":
		m.name = node_name
	parent.add_child(m)
	return m


## Places a mesh (whose long axis is +Y, centred) spanning from a to b in parent space.
static func mi_between(parent: Node3D, mesh: Mesh, mat: Material, a: Vector3, b: Vector3, scl_xz := 1.0) -> MeshInstance3D:
	var m := mi(parent, mesh, mat)
	var d := b - a
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	m.transform = Transform3D(Basis(side * scl_xz, up, fwd * scl_xz), (a + b) * 0.5)
	return m


## Many copies of one small mesh (rivets, bolts...) as a single draw call.
static func multimesh(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat:
		inst.material_override = mat
	parent.add_child(inst)
	return inst


## Hitbox Area3D for the game's hitscan (layer 4). Follows `parent` (an animated bone).
static func add_hitbox(parent: Node3D, part: String, actor: Node, shape: Shape3D, local := Transform3D.IDENTITY) -> Area3D:
	var a := Area3D.new()
	a.name = "Hit_" + part
	a.collision_layer = HITBOX_LAYER
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = true
	a.set_meta("part", part)
	a.set_meta("actor", actor)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = local
	a.add_child(cs)
	parent.add_child(a)
	return a


static func capsule_shape(r: float, h: float) -> CapsuleShape3D:
	var s := CapsuleShape3D.new()
	s.radius = r
	s.height = maxf(h, r * 2.0)
	return s


static func box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


static func sphere_shape(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


## The node debris should live under once an actor dies.
static func world_of(n: Node) -> Node:
	var tree := n.get_tree()
	if tree == null:
		return null
	if tree.current_scene:
		return tree.current_scene
	return tree.root


## Removes all hitbox areas below `n` (call when dying).
static func strip_hitboxes(n: Node) -> void:
	for c in n.get_children():
		if c is Area3D and c.has_meta("part"):
			c.queue_free()
		else:
			strip_hitboxes(c)


## Local AABB of all visible meshes under `n`, expressed in `n`'s space.
static func local_aabb(n: Node3D) -> AABB:
	var res := AABB()
	var first := true
	var inv := n.global_transform.affine_inverse()
	for vi in _collect_visuals(n):
		var ab: AABB = vi.get_aabb()
		var x: Transform3D = inv * vi.global_transform
		var tab := x * ab
		if first:
			res = tab
			first = false
		else:
			res = res.merge(tab)
	if first:
		res = AABB(Vector3(-0.05, -0.05, -0.05), Vector3(0.1, 0.1, 0.1))
	return res


static func _collect_visuals(n: Node, out: Array[VisualInstance3D] = []) -> Array[VisualInstance3D]:
	if (n is MeshInstance3D or n is MultiMeshInstance3D) and (n as GeometryInstance3D).visible:
		out.append(n)
	for c in n.get_children():
		_collect_visuals(c, out)
	return out


## Detaches `node` (keeping its look) into a tumbling RigidBody3D in `world`.
## The body uses a box fitted to the visuals, collides with world (mask 1) only,
## and shrinks away after `life` seconds. Returns the DebrisBody.
static func make_debris(node: Node3D, world: Node, lin_vel: Vector3, ang_vel: Vector3, life := 9.0, mass := 2.0, spore_trail := 0.0) -> RigidBody3D:
	strip_hitboxes(node)
	var gt := node.global_transform
	var ab := local_aabb(node)
	var body := DebrisBody.new()
	body.life = life
	body.mass = mass
	body.collision_layer = 0
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# shape lives in body space (orthonormal basis, no scale)
	var ortho := Transform3D(gt.basis.orthonormalized(), gt.origin)
	var to_body := ortho.affine_inverse() * gt
	var bab := to_body * ab
	bs.size = (bab.size * 0.9).max(Vector3(0.04, 0.04, 0.04))
	cs.shape = bs
	cs.position = bab.get_center()
	body.add_child(cs)
	if node.get_parent():
		node.get_parent().remove_child(node)
	body.add_child(node)
	node.transform = to_body
	world.add_child(body)
	body.global_transform = ortho
	body.linear_velocity = lin_vel
	body.angular_velocity = ang_vel
	body.register_visual(node)
	if spore_trail > 0.0:
		BloomKit.attach_spore_trail(body, bab.get_center(), spore_trail)
	return body
