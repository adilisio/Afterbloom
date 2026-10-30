class_name BloomKit
extends RefCounted
## Visual signature of the Bloom: violet crystal + crystalline flowers, shards and spores.
## All meshes are single-surface with their material baked on the surface, so they can be
## used directly in MultiMeshInstance3D.

const VIOLET := Color(0.62, 0.32, 1.0)
const LILAC := Color(0.85, 0.68, 1.0)

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}

const CRYSTAL_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec3 deep_color : source_color = vec3(0.07, 0.02, 0.16);
uniform vec3 core_color : source_color = vec3(0.62, 0.24, 1.0);
uniform vec3 rim_color : source_color = vec3(0.80, 0.55, 1.0);
uniform float glow = 1.0;
varying vec3 lpos;
varying float hgt;
void vertex() {
	lpos = VERTEX;
	hgt = COLOR.r;
}
void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.6);
	vec3 vw = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	vec3 p = lpos * 11.0 + vw * 0.9;
	float veins = sin(p.x * 1.9 + sin(p.y * 1.3 + p.z) * 2.0) * sin(p.z * 1.7 + p.y * 0.7);
	float inner = 0.55 + 0.45 * veins;
	float pulse = 0.88 + 0.12 * sin(TIME * 1.1 + lpos.x * 4.0 + lpos.z * 3.0 + lpos.y * 2.0);
	ALBEDO = deep_color;
	ROUGHNESS = 0.1;
	SPECULAR = 0.45;
	METALLIC = 0.0;
	float facet = fract(sin(dot(floor(NORMAL * 3.0 + 0.5), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	vec3 core = core_color * (0.08 + 0.92 * hgt * hgt) * inner * (0.75 + 0.5 * facet);
	EMISSION = (core * (0.3 + 0.7 * ndv) * 2.6 + rim_color * fres * 1.1 * (0.4 + 0.6 * hgt)) * glow * pulse;
	BACKLIGHT = core_color * 0.35;
}
"""

const FLOWER_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec3 glow_color : source_color = vec3(0.70, 0.42, 1.0);
uniform float glow = 1.0;
void fragment() {
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = n;
	float ndv = abs(dot(n, VIEW));
	float fres = pow(1.0 - ndv, 2.0);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = mix(0.65, 0.12, COLOR.a);
	SPECULAR = 0.7;
	EMISSION = glow_color * COLOR.a * glow * (0.25 + 0.9 * fres + 1.1 * UV.y * UV.y);
	BACKLIGHT = COLOR.rgb * 0.6 * COLOR.a;
}
"""

const SPORE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float intensity = 3.0;
uniform float core_amount = 1.5;
uniform float soft_dist = 0.25;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = clamp(1.0 - d, 0.0, 1.0);
	a = a * a;
	float core = smoothstep(0.45, 0.0, d);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 vpos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_d = -vpos.z / vpos.w;
	float soft = clamp((scene_d + VERTEX.z) / soft_dist, 0.0, 1.0);
	ALBEDO = COLOR.rgb * intensity * (a + core * core_amount);
	ALPHA = COLOR.a * a * soft;
}
"""


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------

static func crystal_material(glow := 1.0) -> Material:
	var key := "crystal_%.2f" % glow
	if _mats.has(key):
		return _mats[key]
	var sh := _shader("crystal", CRYSTAL_SHADER)
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("glow", glow)
	_mats[key] = m
	return m


static func flower_material(glow := 1.0) -> Material:
	var key := "flower_%.2f" % glow
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = _shader("flower", FLOWER_SHADER)
	m.set_shader_parameter("glow", glow)
	_mats[key] = m
	return m


## Additive glowing mote material (billboarded, for GPUParticles3D draw passes).
static func spore_material(intensity := 3.0, core := 1.5) -> Material:
	var key := "spore_%.2f_%.2f" % [intensity, core]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = _shader("spore", SPORE_SHADER)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("core_amount", core)
	_mats[key] = m
	return m


static func _shader(key: String, code: String) -> Shader:
	var k := "sh_" + key
	if _mats.has(k):
		return _mats[k]
	var s := Shader.new()
	s.code = code
	_mats[k] = s
	return s


# --------------------------------------------------------------------------
# Geometry
# --------------------------------------------------------------------------

## One faceted hexagonal crystal with a pointed tip, appended to `st` (use with crystal_material()).
## Vertex colour R = height (0 base..1 tip), used by the crystal shader for the inner glow gradient.
## The base is sunk by 0.6*radius below `base` so it reads as growing out of a surface.
static func crystal_into(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, radius: float, twist := 0.0) -> void:
	_crystal_raw(st, base, dir, length, radius, twist)

## Builds a crystal with per-vertex height colours (used instead of ModelKit.tri for the gradient).
static func _crystal_raw(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, radius: float, twist: float) -> void:
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	side = side.rotated(dir, twist)
	var side2 := dir.cross(side)
	var tip_len := radius * 1.7
	var body_len := maxf(length - tip_len, radius * 0.5)
	var low := base - dir * radius * 0.6
	var top := base + dir * body_len
	var tip := base + dir * (body_len + tip_len)
	var r_top := radius * 0.86
	var rb: Array[Vector3] = []
	var rt: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0
		var d := side * cos(a) + side2 * sin(a)
		rb.append(low + d * radius)
		rt.append(top + d * r_top)
	var h_top := body_len / (body_len + tip_len)
	for i in 6:
		var j := (i + 1) % 6
		var center := (low + top) * 0.5
		_vtri(st, rb[i], rb[j], rt[i], center, 0.0, 0.0, h_top)
		_vtri(st, rt[i], rb[j], rt[j], center, h_top, 0.0, h_top)
		_vtri(st, rt[i], rt[j], tip, top - dir * radius, h_top, h_top, 1.0)


static func _vtri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, ha: float, hb: float, hc: float) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	# Godot front face: (c-a)x(b-a) points along the normal
	if (c - a).cross(b - a).dot(n) < 0.0:
		var t := b; b = c; c = t
		var th := hb; hb = hc; hc = th
	st.set_normal(n)
	st.set_color(Color(ha, 0, 0)); st.set_uv(Vector2(0, ha)); st.add_vertex(a)
	st.set_color(Color(hb, 0, 0)); st.set_uv(Vector2(1, hb)); st.add_vertex(b)
	st.set_color(Color(hc, 0, 0)); st.set_uv(Vector2(0.5, hc)); st.add_vertex(c)


static func _build_cluster(rng: RandomNumberGenerator, size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := rng.randi_range(3, 9)
	# one dominant crystal, others smaller and leaning outward
	for i in count:
		var main := i == 0
		var ang := rng.randf() * TAU
		var tilt := deg_to_rad(rng.randf_range(4, 14)) if main else deg_to_rad(rng.randf_range(18, 58))
		var dir := Vector3(sin(ang) * sin(tilt), cos(tilt), cos(ang) * sin(tilt))
		var off := Vector3(sin(ang), 0, cos(ang)) * (0.0 if main else rng.randf_range(0.03, 0.14) * size)
		var length := (rng.randf_range(0.75, 1.0) if main else rng.randf_range(0.28, 0.7)) * size
		var radius := length * rng.randf_range(0.11, 0.17)
		_crystal_raw(st, off, dir, length, radius, rng.randf() * TAU)
	var m := st.commit()
	m.surface_set_material(0, crystal_material(1.0))
	return m


## Cached crystal cluster mesh (for MultiMesh). ~20 tris per crystal, max ~170.
static func cluster_mesh(seed_v: int, size: float) -> Mesh:
	var key := "cl_%d_%.3f" % [seed_v, size]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var m := _build_cluster(rng, size)
	_meshes[key] = m
	return m


static func make_crystal_cluster(rng: RandomNumberGenerator, size := 1.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = "CrystalCluster"
	inst.mesh = _build_cluster(rng, size)
	return inst


## Single shard mesh (for debris/props). Cached variants.
static func shard_mesh(variant: int) -> Mesh:
	var key := "shard_%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + variant
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := rng.randf_range(0.10, 0.2)
	_crystal_raw(st, Vector3(0, -length * 0.4, 0), Vector3(rng.randf_range(-0.2, 0.2), 1, rng.randf_range(-0.2, 0.2)), length, length * rng.randf_range(0.18, 0.28), rng.randf() * TAU)
	var m := st.commit()
	m.surface_set_material(0, crystal_material(1.0))
	_meshes[key] = m
	return m


static func _build_flower(rng: RandomNumberGenerator, size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := rng.randf_range(0.17, 0.3) * size
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)) * h
	# stem (curved)
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var cols := PackedColorArray()
	var stem_col := Color(0.14, 0.17, 0.13, 0.0)
	for i in 6:
		var t := float(i) / 5.0
		path.append(Vector3(0, -0.02 * size + t * h, 0) + lean * t * t)
		radii.append(lerpf(0.0065, 0.0038, t) * size)
		cols.append(stem_col.lerp(Color(0.30, 0.22, 0.40, 0.15), t))
	ModelKit.tube_into(st, path, radii, 4, false, cols)
	var top := path[5]
	var up := (path[5] - path[4]).normalized()
	# two leaves
	for k in 2:
		var la := rng.randf() * TAU + k * PI
		var ld := Vector3(cos(la), 0.0, sin(la))
		var lb := path[1 + k]
		var lt := lb + ld * 0.09 * size + Vector3(0, 0.05 * size, 0)
		var lw := ld.cross(Vector3.UP) * 0.022 * size
		var lm := (lb + lt) * 0.5 + Vector3(0, 0.012 * size, 0)
		var lc := Color(0.16, 0.20, 0.15, 0.0)
		ModelKit.flat_tri(st, lb, lm + lw, lm, Vector3.UP, lc)
		ModelKit.flat_tri(st, lm, lm + lw, lt, Vector3.UP, lc)
		ModelKit.flat_tri(st, lb, lm, lm - lw, Vector3.UP, lc)
		ModelKit.flat_tri(st, lm, lt, lm - lw, Vector3.UP, lc)
	# petals: two whorls of faceted crystalline petals, cupped
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var side2 := up.cross(side)
	var whorls := [[rng.randi_range(5, 6), 0.075, 0.032, 0.35], [rng.randi_range(4, 5), 0.05, 0.025, 0.85]]
	var rot0 := rng.randf() * TAU
	for wi in whorls.size():
		var w: Array = whorls[wi]
		var cnt: int = w[0]
		var plen: float = w[1] * size * rng.randf_range(0.85, 1.15)
		var pw: float = w[2] * size
		var lift: float = w[3]
		for p in cnt:
			var a := rot0 + TAU * p / cnt + wi * PI / cnt
			var radial := side * cos(a) + side2 * sin(a)
			var pdir := (radial + up * lift).normalized()
			var pside := radial.cross(up).normalized()
			var pnorm := pside.cross(pdir).normalized()
			if pnorm.dot(up) < 0.0:
				pnorm = -pnorm
			var b := top + radial * 0.006 * size
			var t := b + pdir * plen + up * plen * 0.25
			var m := b + pdir * plen * 0.5
			var l := m + pside * pw * 0.5 - pnorm * pw * 0.12
			var r := m - pside * pw * 0.5 - pnorm * pw * 0.12
			var rib := m + pnorm * pw * 0.12
			var cb := Color(0.22, 0.07, 0.45, 0.45)
			var ct := Color(0.62, 0.42, 0.95, 1.0)
			_ptri(st, b, l, rib, pnorm, cb, cb.lerp(ct, 0.5), cb.lerp(ct, 0.5), 0.0, 0.5, 0.5)
			_ptri(st, b, rib, r, pnorm, cb, cb.lerp(ct, 0.5), cb.lerp(ct, 0.5), 0.0, 0.5, 0.5)
			_ptri(st, l, t, rib, pnorm, cb.lerp(ct, 0.5), ct, cb.lerp(ct, 0.5), 0.5, 1.0, 0.5)
			_ptri(st, rib, t, r, pnorm, cb.lerp(ct, 0.5), ct, cb.lerp(ct, 0.5), 0.5, 1.0, 0.5)
	# glowing pistil crystal
	var cst := Color(1.0, 0.85, 1.0, 1.0)
	var pist := top + up * 0.004 * size
	var pr := 0.011 * size
	for i in 5:
		var a0 := TAU * i / 5.0
		var a1 := TAU * (i + 1) / 5.0
		var p0 := pist + (side * cos(a0) + side2 * sin(a0)) * pr
		var p1 := pist + (side * cos(a1) + side2 * sin(a1)) * pr
		var tip := pist + up * 0.035 * size
		var out := ((p0 + p1) * 0.5 - pist).normalized()
		ModelKit.flat_tri(st, p0, p1, tip, out + up * 0.3, cst)
	var mesh := st.commit()
	mesh.surface_set_material(0, flower_material(1.0))
	return mesh


static func _ptri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, up: Vector3, ca: Color, cb: Color, cc: Color, va: float, vb: float, vc: float) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot(up) < 0.0:
		n = -n
	if (c - a).cross(b - a).dot(n) < 0.0:
		var t := b; b = c; c = t
		var tc := cb; cb = cc; cc = tc
		var tv := vb; vb = vc; vc = tv
	st.set_normal(n)
	st.set_color(ca); st.set_uv(Vector2(0, va)); st.add_vertex(a)
	st.set_color(cb); st.set_uv(Vector2(1, vb)); st.add_vertex(b)
	st.set_color(cc); st.set_uv(Vector2(0.5, vc)); st.add_vertex(c)


## Cached flower mesh for MultiMesh scattering (~130 tris).
static func flower_mesh(seed_v: int) -> Mesh:
	var key := "fl_%d" % seed_v
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var m := _build_flower(rng, 1.0)
	_meshes[key] = m
	return m


static func make_bloom_flower(rng: RandomNumberGenerator, size := 1.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = "BloomFlower"
	inst.mesh = _build_flower(rng, size)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return inst


# --------------------------------------------------------------------------
# FX
# --------------------------------------------------------------------------

## Crystal shards that burst out, tumble, settle and shrink away after ~6 s.
static func spawn_shards(parent: Node, at: Vector3, count: int, impulse: Vector3, scale := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spread := impulse.length() * 0.6 + 2.2
	for i in count:
		var body := DebrisBody.new()
		body.life = rng.randf_range(5.0, 7.0)
		body.mass = 0.15 * scale
		body.collision_layer = 0
		body.collision_mask = 1
		var vis := MeshInstance3D.new()
		vis.mesh = shard_mesh(i % 6)
		var s := scale * rng.randf_range(0.6, 1.3)
		vis.scale = Vector3(s, s, s)
		vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(vis)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.06, 0.16, 0.06) * s
		cs.shape = bs
		body.add_child(cs)
		parent.add_child(body)
		var rnd := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.2), rng.randf_range(-1, 1)).normalized()
		body.global_position = at + rnd * 0.12 * scale
		body.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		body.linear_velocity = impulse + rnd * spread * rng.randf_range(0.4, 1.0)
		body.angular_velocity = Vector3(rng.randf_range(-14, 14), rng.randf_range(-14, 14), rng.randf_range(-14, 14))
		body.register_visual(vis)
	spawn_spore_puff(parent, at, scale * 0.8)


static func _spore_process(kind: String) -> ParticleProcessMaterial:
	var key := "pp_" + kind
	if _mats.has(key):
		return _mats[key]
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.2))
	sc.add_point(Vector2(0.12, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var cr := GradientTexture1D.new()
	match kind:
		"motes":
			pm.emission_sphere_radius = 0.15
			pm.initial_velocity_min = 0.6
			pm.initial_velocity_max = 2.6
			pm.gravity = Vector3(0, 0.35, 0)
			pm.damping_min = 1.6
			pm.damping_max = 3.0
			pm.scale_min = 0.5
			pm.scale_max = 1.5
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.6
			pm.turbulence_noise_scale = 1.5
			cr.gradient = ModelKit.grad([Color(1.0, 0.9, 1.0, 1.0), Color(0.75, 0.45, 1.0, 0.9), Color(0.5, 0.2, 0.9, 0.0)], [0.0, 0.35, 1.0])
		"cloud":
			pm.emission_sphere_radius = 0.2
			pm.initial_velocity_min = 0.3
			pm.initial_velocity_max = 1.2
			pm.gravity = Vector3(0, 0.15, 0)
			pm.damping_min = 1.0
			pm.damping_max = 2.0
			pm.scale_min = 0.8
			pm.scale_max = 1.6
			pm.angle_min = 0
			pm.angle_max = 360
			cr.gradient = ModelKit.grad([Color(0.7, 0.45, 1.0, 0.0), Color(0.6, 0.35, 0.95, 0.5), Color(0.4, 0.2, 0.8, 0.0)], [0.0, 0.12, 1.0])
		"trail":
			pm.emission_sphere_radius = 0.05
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.4
			pm.gravity = Vector3(0, 0.25, 0)
			pm.damping_min = 0.5
			pm.damping_max = 1.0
			pm.scale_min = 0.4
			pm.scale_max = 1.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.3
			cr.gradient = ModelKit.grad([Color(1.0, 0.85, 1.0, 1.0), Color(0.7, 0.4, 1.0, 0.8), Color(0.5, 0.2, 0.9, 0.0)], [0.0, 0.4, 1.0])
	pm.color_ramp = cr
	_mats[key] = pm
	return pm


static func _quad(size: float) -> QuadMesh:
	var key := "quad_%.3f" % size
	if _meshes.has(key):
		return _meshes[key]
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	_meshes[key] = q
	return q


## One-shot glowing spore puff; frees itself.
static func spawn_spore_puff(parent: Node, at: Vector3, scale := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = "SporePuff"
	parent.add_child(root)
	root.global_position = at
	root.scale = Vector3.ONE * maxf(scale, 0.05)
	var motes := GPUParticles3D.new()
	motes.amount = clampi(int(56 * scale), 16, 220)
	motes.lifetime = 2.4
	motes.one_shot = true
	motes.explosiveness = 0.92
	motes.randomness = 0.5
	motes.process_material = _spore_process("motes")
	motes.draw_pass_1 = _quad(0.08)
	motes.material_override = spore_material(4.0, 1.6)
	motes.visibility_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 6, 6))
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(motes)
	var cloud := GPUParticles3D.new()
	cloud.amount = clampi(int(14 * scale), 6, 48)
	cloud.lifetime = 2.0
	cloud.one_shot = true
	cloud.explosiveness = 0.95
	cloud.process_material = _spore_process("cloud")
	cloud.draw_pass_1 = _quad(0.7)
	cloud.material_override = spore_material(1.8, 0.0)
	cloud.visibility_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 6, 6))
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cloud)
	motes.emitting = true
	cloud.emitting = true
	var light := OmniLight3D.new()
	light.light_color = VIOLET
	light.light_energy = 1.5 * minf(scale, 3.0)
	light.omni_range = 1.5 * scale + 0.5
	light.shadow_enabled = false
	root.add_child(light)
	var tw := root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_callback(root.queue_free)


## Continuous trickle of glowing motes from a wound / stump, following `parent`.
static func attach_spore_trail(parent: Node3D, local_pos: Vector3, duration := 3.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "SporeTrail"
	p.amount = 20
	p.lifetime = 1.6
	p.local_coords = false
	p.process_material = _spore_process("trail")
	p.draw_pass_1 = _quad(0.035)
	p.material_override = spore_material(3.0, 1.5)
	p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = local_pos
	parent.add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(duration)
	tw.tween_property(p, "emitting", false, 0.0)
	tw.tween_interval(1.8)
	tw.tween_callback(p.queue_free)
	return p
