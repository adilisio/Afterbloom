class_name HuskModel
extends Node3D
## Bloomed human (~1.8 m upright, hunched to ~1.65 m). Gaunt, tattered 1960s clothes,
## cracked grey-lilac skin with glowing seams, violet crystals from back/shoulder/head and
## a glowing crystalline bloom where the face was. Procedural shamble (left leg drags),
## lurching run, lunge attack, flinches, emerge, and four unique deaths.
## Origin at feet, facing -Z.

signal finished

enum { HIPS, SPINE, CHEST, NECK, HEAD, SH_L, EL_L, WR_L, SH_R, EL_R, WR_R, TH_L, KN_L, FT_L, TH_R, KN_R, FT_R, NJ }

const PARTS := ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r"]
const ATTACK_DUR := 1.2
const EMERGE_DUR := 2.6
const THIGH := 0.45
const SHIN := 0.42
const ANKLE := 0.05
const HIP_DROP := 0.03

## 0 = trench coat + fedora, 1 = dress + cardigan + hair bun, 2 = workman (shirt, braces, rolled sleeves, bald).
@export var variant := 0

static var _cache: Dictionary = {}

var _body: Node3D
var _skirt: Node3D
var _j: Array[Node3D] = []
var _rest := PackedVector3Array()
var _pose := PackedVector3Array()
var _cur := PackedVector3Array()
var _vel := PackedVector3Array()
var _stiff := PackedFloat32Array()
var _dampc := PackedFloat32Array()
var _det := PackedByteArray()
var _off := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

var _t := 0.0
var _phase := 0.0
var _speed := 0.0
var _target_speed := 0.0
var _att_t := -1.0
var _hit_t := -1.0
var _hit_part := ""
var _hit_dir := Vector3.ZERO
var _hit_amp := 1.0
var _em_t := -1.0
var _em_puff2 := false
var _twitch_t := -1.0
var _twitch_kind := 0
var _twitch_sign := 1.0
var _next_twitch := 2.0
var _arm_kmul := 1.0

var _dying := false
var _gone := false
var _death_t := 0.0
var _death_part := ""
var _death_imp := Vector3.ZERO
var _death_stage := 0
var _fall_dir := Vector3.FORWARD

var _bloom_light: OmniLight3D
var _ambient: GPUParticles3D
var _chest_light: OmniLight3D
var _chest_meshes: Array[Node3D] = []
var _spine_meshes: Array[Node3D] = []


# ==========================================================================
# Public API
# ==========================================================================

func set_variant(v: int) -> void:
	variant = clampi(v, 0, 2)


## 0 = idle, ~0.3 = shamble, 1 = lurching run.
func set_locomotion(speed: float) -> void:
	if not _dying:
		_target_speed = clampf(speed, 0.0, 1.0)


## Two-armed lunge. Hit moment at ~45 % (0.54 s). Returns duration.
func play_attack() -> float:
	if _dying:
		return 0.0
	_att_t = 0.0
	return ATTACK_DUR


## from_dir = travel direction of the hit (shooter -> husk), world space.
func play_hit(part: String, from_dir: Vector3) -> void:
	if _dying:
		return
	_hit_t = 0.0
	_hit_part = part
	var d := global_transform.basis.inverse() * from_dir
	d.y = 0.0
	_hit_dir = d.normalized() if d.length_squared() > 1e-6 else Vector3(0, 0, 1)
	_hit_amp = _rng.randf_range(0.85, 1.15)


## Claws its way up out of the ground / crystal bed. Returns duration.
func play_emerge() -> float:
	if _dying:
		return 0.0
	_em_t = 0.0
	_em_puff2 = false
	if is_inside_tree():
		var w := ModelKit.world_of(self)
		BloomKit.spawn_shards(w, global_position + Vector3(0, 0.1, 0), 10, Vector3(0, 3.0, 0), 0.9)
		BloomKit.spawn_spore_puff(w, global_position + Vector3(0, 0.2, 0), 1.4)
	return EMERGE_DUR


## Unique deaths: "head" = bloom bursts, body crumples; "arm_l"/"arm_r"/"leg_l"/"leg_r" = limb snaps
## off and flies, body falls; "torso" (default) = shatters into crystal from the inside.
## `impulse` = world-space push (direction * strength, ~1..10).
func die(part: String, impulse: Vector3) -> void:
	if _dying:
		return
	_dying = true
	_target_speed = 0.0
	_att_t = -1.0
	_hit_t = -1.0
	_em_t = -1.0
	_twitch_t = -1.0
	_death_part = part if part in PARTS else "torso"
	_death_imp = impulse
	_set_hitboxes_enabled(false)
	_do_die.call_deferred()


func get_part_node(part: String) -> Node3D:
	if _j.is_empty():
		return self
	match part:
		"head": return _j[HEAD]
		"torso": return _j[CHEST]
		"arm_l": return _j[EL_L]
		"arm_r": return _j[EL_R]
		"leg_l": return _j[KN_L]
		"leg_r": return _j[KN_R]
	return _j[CHEST]


func get_parts() -> PackedStringArray:
	return PackedStringArray(PARTS)


func is_dead() -> bool:
	return _dying


# ==========================================================================
# Build
# ==========================================================================

func _ready() -> void:
	_rng.randomize()
	variant = clampi(variant, 0, 2)
	_t = _rng.randf() * 20.0
	_phase = _rng.randf()
	_next_twitch = _rng.randf_range(0.8, 3.0)
	_build()


func _build() -> void:
	var v := variant
	_body = ModelKit.pivot(self, "Body")
	_j.resize(NJ)
	var hips := ModelKit.pivot(_body, "Hips", Vector3(0, 0.95, 0))
	_j[HIPS] = hips
	_j[SPINE] = ModelKit.pivot(hips, "Spine", Vector3(0, 0.02, 0))
	_j[CHEST] = ModelKit.pivot(_j[SPINE], "Chest", Vector3(0, 0.26, 0))
	_j[NECK] = ModelKit.pivot(_j[CHEST], "Neck", Vector3(0, 0.275, -0.005))
	_j[HEAD] = ModelKit.pivot(_j[NECK], "Head", Vector3(0, 0.1, -0.01))
	_j[SH_L] = ModelKit.pivot(_j[CHEST], "ShoulderL", Vector3(-0.178, 0.222, 0.012))
	_j[EL_L] = ModelKit.pivot(_j[SH_L], "ElbowL", Vector3(0, -0.29, 0))
	_j[WR_L] = ModelKit.pivot(_j[EL_L], "WristL", Vector3(0, -0.26, 0))
	_j[SH_R] = ModelKit.pivot(_j[CHEST], "ShoulderR", Vector3(0.178, 0.222, 0.012))
	_j[EL_R] = ModelKit.pivot(_j[SH_R], "ElbowR", Vector3(0, -0.29, 0))
	_j[WR_R] = ModelKit.pivot(_j[EL_R], "WristR", Vector3(0, -0.26, 0))
	_j[TH_L] = ModelKit.pivot(hips, "HipL", Vector3(-0.095, -HIP_DROP, 0))
	_j[KN_L] = ModelKit.pivot(_j[TH_L], "KneeL", Vector3(0, -THIGH, 0))
	_j[FT_L] = ModelKit.pivot(_j[KN_L], "AnkleL", Vector3(0, -SHIN, 0))
	_j[TH_R] = ModelKit.pivot(hips, "HipR", Vector3(0.095, -HIP_DROP, 0))
	_j[KN_R] = ModelKit.pivot(_j[TH_R], "KneeR", Vector3(0, -THIGH, 0))
	_j[FT_R] = ModelKit.pivot(_j[KN_R], "AnkleR", Vector3(0, -SHIN, 0))
	_skirt = ModelKit.pivot(hips, "Skirt", Vector3(0, 0.0, 0))

	_rest.resize(NJ)
	_rest[HIPS] = Vector3(-0.06, 0, 0)
	_rest[SPINE] = Vector3(-0.25, 0, 0)
	_rest[CHEST] = Vector3(-0.2, 0, 0)
	_rest[NECK] = Vector3(0.32, 0, 0)
	_rest[HEAD] = Vector3(0.14, 0, 0.12)
	_rest[SH_L] = Vector3(0.54, 0, -0.06)
	_rest[EL_L] = Vector3(0.26, 0, 0)
	_rest[WR_L] = Vector3(0.12, 0, 0)
	_rest[SH_R] = Vector3(0.5, 0, 0.07)
	_rest[EL_R] = Vector3(0.32, 0, 0)
	_rest[WR_R] = Vector3(0.1, 0, 0)
	_rest[TH_L] = Vector3(0.1, 0.18, -0.04)
	_rest[KN_L] = Vector3(-0.2, 0, 0)
	_rest[FT_L] = Vector3.ZERO
	_rest[TH_R] = Vector3(0.14, 0, 0.03)
	_rest[KN_R] = Vector3(-0.24, 0, 0)
	_rest[FT_R] = Vector3.ZERO
	_pose = _rest.duplicate()
	_cur = _rest.duplicate()
	_vel.resize(NJ)
	_det.resize(NJ)
	_stiff.resize(NJ)
	_dampc.resize(NJ)
	var stiff := [0.0, 260.0, 220.0, 170.0, 120.0, 65.0, 85.0, 60.0, 65.0, 85.0, 60.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var dmul := [0.0, 1.6, 1.5, 1.3, 1.2, 1.0, 1.05, 1.0, 1.0, 1.05, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in NJ:
		_stiff[i] = stiff[i]
		_dampc[i] = dmul[i] * sqrt(stiff[i])
		_vel[i] = Vector3.ZERO
		_det[i] = 0
		_j[i].rotation = _rest[i]

	_build_meshes(v)
	_build_hitboxes()


# ---------------------------------------------------------------- materials

static func _skin() -> StandardMaterial3D:
	if _cache.has("skin"):
		return _cache["skin"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.6, 0.62)
	m.albedo_texture = ModelKit.noise_tex("husk_mottle", 0.035, ModelKit.grad(
		[Color(0.55, 0.52, 0.62), Color(0.80, 0.80, 0.82), Color(0.95, 0.94, 0.92)], [0.0, 0.5, 1.0]), false, 4.0, 256, 4, 77)
	m.roughness = 0.62
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2.6, 2.6, 2.6)
	m.uv1_triplanar_sharpness = 3.0
	m.emission_enabled = true
	m.emission = Color(0.72, 0.36, 1.0)
	m.emission_energy_multiplier = 0.75
	m.emission_texture = _crack_tex(false)
	m.normal_enabled = true
	m.normal_texture = _crack_tex(true)
	m.normal_scale = 0.6
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.3
	_cache["skin"] = m
	return m


static func _crack_tex(as_normal: bool) -> NoiseTexture2D:
	var key := "crack_n" if as_normal else "crack_e"
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.frequency = 0.03
	n.seed = 1234
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	if as_normal:
		t.as_normal_map = true
		t.bump_strength = 5.0
	else:
		t.color_ramp = ModelKit.grad([Color(1, 0.9, 1), Color(0.4, 0.2, 0.65), Color(0, 0, 0)], [0.0, 0.016, 0.042])
	_cache[key] = t
	return t


static func _cloth(key: String, col: Color, tex := "", tex_scale := 3.0) -> StandardMaterial3D:
	var k := "cloth_" + key
	if _cache.has(k):
		return _cache[k]
	var m := ModelKit.fabric("husk_fab_" + key, col, 0.94, tex_scale).duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex != "":
		var tx := ModelKit.load_tex(tex)
		if tx:
			m.albedo_texture = tx
	_cache[k] = m
	return m


static func _leather() -> StandardMaterial3D:
	var m := ModelKit.pbr("husk_leather", Color(0.11, 0.08, 0.065), 0.0, 0.48)
	return m


static func _hair() -> StandardMaterial3D:
	if _cache.has("hair"):
		return _cache["hair"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.33, 0.30, 0.29)
	m.roughness = 0.8
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(8, 2, 8)
	m.normal_enabled = true
	m.normal_texture = ModelKit.noise_tex("husk_hair_n", 0.08, null, true, 6.0, 256, 3, 9)
	_cache["hair"] = m
	return m


static func _fungus() -> StandardMaterial3D:
	if _cache.has("fungus"):
		return _cache["fungus"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.83, 0.86)
	m.roughness = 0.85
	m.emission_enabled = true
	m.emission = Color(0.6, 0.4, 0.9)
	m.emission_energy_multiplier = 0.25
	m.rim_enabled = true
	m.rim = 0.5
	_cache["fungus"] = m
	return m


# ---------------------------------------------------------------- meshes

static func _prof_r(profile: PackedVector2Array, y: float) -> float:
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if y >= a.y and y <= b.y and b.y > a.y:
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return profile[profile.size() - 1].x


static func _cached(key: String, builder: Callable) -> Mesh:
	if _cache.has(key):
		return _cache[key]
	var m: Mesh = builder.call()
	_cache[key] = m
	return m


static func _tube2(a: Vector3, b: Vector3, ra: float, rb: float, sides := 10, rings := 4) -> ArrayMesh:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in rings + 1:
		var t := float(i) / rings
		path.append(a.lerp(b, t))
		radii.append(lerpf(ra, rb, t))
	return ModelKit.tube(path, radii, sides, true)


## A skirt/coat-tail lathe with a torn, jagged hem.
static func _hem_lathe(profile: PackedVector2Array, segs: int, a0: float, a1: float, seed_off: float) -> ArrayMesh:
	var hem_y := profile[0].y
	var deform := func(p: Vector3) -> Vector3:
		if p.y < hem_y + 0.001:
			var a := atan2(p.x, -p.z)
			p.y += 0.055 * absf(sin(a * 5.0 + seed_off)) + 0.03 * absf(sin(a * 13.0 + seed_off * 2.3)) - 0.01
		return p
	return ModelKit.lathe(profile, segs, a0, a1, deform)


static func _hand_mesh(curl_sign: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var palm := ModelKit.rounded_box(Vector3(0.026, 0.092, 0.072), 0.012, 2)
	st.append_from(palm, 0, Transform3D(Basis(), Vector3(0, -0.05, 0)))
	for f in 4:
		var z := -0.027 + f * 0.018
		var l := 1.0 - absf(f - 1.2) * 0.12
		var path := PackedVector3Array([
			Vector3(0, -0.09, z),
			Vector3(curl_sign * 0.006, -0.135 * l, z - 0.006),
			Vector3(curl_sign * 0.022, -0.175 * l, z - 0.012),
			Vector3(curl_sign * 0.045, -0.195 * l, z - 0.016),
		])
		var radii := PackedFloat32Array([0.0095, 0.0085, 0.0068, 0.0025])
		ModelKit.tube_into(st, path, radii, 6, true)
	var th := PackedVector3Array([
		Vector3(curl_sign * 0.006, -0.03, -0.03),
		Vector3(curl_sign * 0.018, -0.06, -0.05),
		Vector3(curl_sign * 0.034, -0.09, -0.055),
		Vector3(curl_sign * 0.046, -0.11, -0.05),
	])
	ModelKit.tube_into(st, th, PackedFloat32Array([0.011, 0.009, 0.007, 0.003]), 6, true)
	st.generate_tangents()
	return st.commit()


static func _crystal_mesh(key: String, specs: Array, seed_v: int) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spec: Array in specs:
		var base: Vector3 = spec[0]
		var dir: Vector3 = (spec[1] as Vector3).normalized()
		var count: int = spec[2]
		var length: float = spec[3]
		var spread: float = spec[4]
		for i in count:
			var rv := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			var d := (dir + rv * spread * (0.3 if i == 0 else 1.0)).normalized()
			var ln := length * (1.0 if i == 0 else rng.randf_range(0.35, 0.8))
			var b := base + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.022
			BloomKit.crystal_into(st, b, d, ln, ln * rng.randf_range(0.13, 0.19), rng.randf() * TAU)
	var m := st.commit()
	m.surface_set_material(0, BloomKit.crystal_material(1.0))
	_cache[key] = m
	return m


## The bloom that replaced the face: three whorls of cupped crystalline petals + glowing pistils, facing -Z.
static func _face_bloom_mesh() -> ArrayMesh:
	if _cache.has("face_bloom"):
		return _cache["face_bloom"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f := Vector3(0, 0, -1)
	# count, length, width, lift, curl, base radius, angle offset
	var whorls := [
		[9, 0.1, 0.046, 0.25, 0.75, 0.025, 0.0],
		[7, 0.085, 0.045, 0.55, 0.3, 0.018, 0.4],
		[5, 0.055, 0.034, 0.95, -0.1, 0.01, 0.9],
	]
	var cb := Color(0.12, 0.02, 0.30, 0.35)
	var ct := Color(0.55, 0.30, 0.95, 0.95)
	var ws := PackedFloat32Array([0.25, 1.0, 0.8, 0.0])
	var ss := PackedFloat32Array([0.0, 0.38, 0.72, 1.0])
	for w: Array in whorls:
		var cnt: int = w[0]
		var plen: float = w[1]
		var pw: float = w[2]
		var lift: float = w[3]
		var curl: float = w[4]
		var br: float = w[5]
		var aoff: float = w[6]
		for p in cnt:
			var a := aoff + TAU * p / cnt + sin(p * 3.7) * 0.12
			var r := Vector3(cos(a), sin(a), 0)
			var tg := Vector3(-sin(a), cos(a), 0)
			var ll := plen * (1.0 + 0.12 * sin(p * 2.3 + aoff))
			var rows_l: Array[Vector3] = []
			var rows_c: Array[Vector3] = []
			var rows_r: Array[Vector3] = []
			for i in 4:
				var s := ss[i]
				var c := r * (br + ll * s) + f * ll * (lift * s - curl * s * s)
				var hw := pw * 0.5 * ws[i]
				rows_c.append(c)
				rows_l.append(c + tg * hw + f * hw * 0.5)
				rows_r.append(c - tg * hw + f * hw * 0.5)
			for i in 3:
				var c0 := cb.lerp(ct, ss[i])
				var c1 := cb.lerp(ct, ss[i + 1])
				_btri(st, rows_l[i], rows_c[i], rows_l[i + 1], f, c0, c0, c1, ss[i], ss[i], ss[i + 1])
				_btri(st, rows_c[i], rows_c[i + 1], rows_l[i + 1], f, c0, c1, c1, ss[i], ss[i + 1], ss[i + 1])
				_btri(st, rows_c[i], rows_r[i], rows_c[i + 1], f, c0, c0, c1, ss[i], ss[i], ss[i + 1])
				_btri(st, rows_r[i], rows_r[i + 1], rows_c[i + 1], f, c0, c1, c1, ss[i], ss[i + 1], ss[i + 1])
	# glowing pistils
	var cp := Color(1.0, 0.86, 1.0, 1.0)
	for k in 6:
		var a := TAU * k / 6.0
		var base := Vector3(cos(a), sin(a), 0) * 0.008
		var tip := base * 2.2 + f * 0.04 + Vector3(cos(a), sin(a), 0) * 0.006
		for e in 3:
			var a0 := TAU * e / 3.0
			var a1 := TAU * (e + 1) / 3.0
			var p0 := base + Vector3(cos(a0), sin(a0), 0) * 0.004
			var p1 := base + Vector3(cos(a1), sin(a1), 0) * 0.004
			_btri(st, p0, p1, tip, f, cp, cp, cp, 0.8, 0.8, 1.0)
	var m := st.commit()
	m.surface_set_material(0, BloomKit.flower_material(0.75))
	_cache["face_bloom"] = m
	return m


static func _btri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, up: Vector3, ca: Color, cb: Color, cc: Color, va: float, vb: float, vc: float) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
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


func _build_meshes(v: int) -> void:
	var skin := _skin()
	# --- palette per variant
	var top_m: StandardMaterial3D
	var low_m: StandardMaterial3D
	var sleeve_m: StandardMaterial3D
	var leg_m: StandardMaterial3D
	match v:
		0:
			top_m = _cloth("trench", Color(0.47, 0.41, 0.30))
			low_m = top_m
			sleeve_m = top_m
			leg_m = _cloth("charcoal", Color(0.17, 0.17, 0.19))
		1:
			top_m = _cloth("cardigan", Color(0.56, 0.50, 0.40), "", 5.0)
			low_m = _cloth("dress", Color(0.8, 0.8, 0.74), "res://assets/textures/gingham_check/gingham_check_diff.jpg", 2.5)
			sleeve_m = top_m
			leg_m = _cloth("stocking", Color(0.48, 0.44, 0.50), "", 8.0)
		_:
			top_m = _cloth("shirt", Color(0.52, 0.58, 0.64), "", 4.0)
			low_m = top_m
			sleeve_m = top_m
			leg_m = _cloth("brown", Color(0.26, 0.21, 0.16))

	# --- torso
	var up_prof := PackedVector2Array([Vector2(0.0, -0.12), Vector2(0.128, -0.11), Vector2(0.146, -0.02), Vector2(0.16, 0.08),
		Vector2(0.168, 0.16), Vector2(0.163, 0.22), Vector2(0.14, 0.265), Vector2(0.095, 0.3), Vector2(0.05, 0.322), Vector2(0.0, 0.326)])
	var low_prof := PackedVector2Array([Vector2(0.0, -0.11), Vector2(0.12, -0.1), Vector2(0.135, -0.03), Vector2(0.128, 0.07),
		Vector2(0.118, 0.16), Vector2(0.13, 0.25), Vector2(0.14, 0.3), Vector2(0.0, 0.32)])
	var chest := _j[CHEST]
	var spine := _j[SPINE]
	var hips := _j[HIPS]
	_chest_meshes.append(_m(chest, _cached("up_torso", func() -> Mesh: return ModelKit.lathe(up_prof, 22)), top_m, Vector3.ZERO, Vector3.ZERO, Vector3(1.12, 1, 0.64)))
	# hunched upper back
	_chest_meshes.append(_m(chest, ModelKit.sphere(0.1, 14, 8), top_m, Vector3(0, 0.17, 0.055), Vector3(-20, 0, 0), Vector3(1.55, 1.25, 0.95)))
	_spine_meshes.append(_m(spine, _cached("low_torso", func() -> Mesh: return ModelKit.lathe(low_prof, 20)), low_m, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.72)))
	# pelvis
	_m(hips, ModelKit.sphere(0.15, 16, 8), leg_m if v != 1 else low_m, Vector3(0, -0.03, 0.0), Vector3.ZERO, Vector3(1.0, 0.72, 0.78))
	# neck
	_m(_j[NECK], _cached("neck", func() -> Mesh: return _tube2(Vector3(0, -0.06, 0.01), Vector3(0, 0.1, 0), 0.042, 0.034, 10, 3)), skin)

	match v:
		0:
			# trench coat tails (open front), belt, collar, buttons
			var skirt_prof := PackedVector2Array([Vector2(0.27, -0.66), Vector2(0.245, -0.5), Vector2(0.205, -0.3), Vector2(0.172, -0.12), Vector2(0.158, 0.0), Vector2(0.15, 0.1)])
			_m(_skirt, _cached("coat_tail", func() -> Mesh: return _hem_lathe(skirt_prof, 26, 0.42, TAU - 0.42, 0.7)), top_m, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.86))
			_spine_meshes.append(_m(spine, ModelKit.torus(0.126, 0.146, 22, 6), _cloth("belt", Color(0.36, 0.31, 0.22)), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.74)))
			var col_prof := PackedVector2Array([Vector2(0.12, 0.25), Vector2(0.115, 0.3), Vector2(0.1, 0.355), Vector2(0.09, 0.38)])
			_chest_meshes.append(_m(chest, _cached("collar", func() -> Mesh: return ModelKit.lathe(col_prof, 18, 0.55, TAU - 0.55)), top_m, Vector3(0, 0, 0.005), Vector3.ZERO, Vector3(1.05, 1, 0.85)))
			var btn := ModelKit.pbr("husk_button", Color(0.12, 0.1, 0.08), 0.0, 0.4)
			for i in 3:
				var y := 0.02 + i * 0.075
				var rr := _prof_r(up_prof, y)
				_chest_meshes.append(_m(chest, ModelKit.sphere(0.011, 8, 4), btn, Vector3(-0.04, y, -rr * 0.66 - 0.002), Vector3.ZERO, Vector3(1, 1, 0.5)))
		1:
			var dress_prof := PackedVector2Array([Vector2(0.29, -0.58), Vector2(0.265, -0.42), Vector2(0.21, -0.22), Vector2(0.165, -0.05), Vector2(0.145, 0.06)])
			_m(_skirt, _cached("dress_skirt", func() -> Mesh: return _hem_lathe(dress_prof, 28, 0.0, TAU, 2.1)), low_m, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
			var col_prof := PackedVector2Array([Vector2(0.11, 0.27), Vector2(0.1, 0.31), Vector2(0.075, 0.33)])
			_chest_meshes.append(_m(chest, _cached("cardi_col", func() -> Mesh: return ModelKit.lathe(col_prof, 16)), top_m, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 1, 0.8)))
		_:
			# braces (suspenders) front and back, trouser waistband
			var brace := ModelKit.pbr("husk_brace", Color(0.20, 0.13, 0.09), 0.0, 0.6)
			for sx in [-1.0, 1.0]:
				var pf := PackedVector3Array()
				var pb := PackedVector3Array()
				var rr := PackedFloat32Array()
				for i in 7:
					var y := -0.05 + i * 0.05
					var r := _prof_r(up_prof, y)
					var x: float = sx * lerpf(0.075, 0.1, float(i) / 6.0)
					var zf := -sqrt(maxf(r * r - x * x, 0.0001)) * 0.66 - 0.004
					pf.append(Vector3(x, y, zf))
					pb.append(Vector3(x * 0.8, y, -zf))
					rr.append(0.009)
				_chest_meshes.append(_m(chest, ModelKit.tube(pf, rr, 4), brace, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 1, 1)))
				_chest_meshes.append(_m(chest, ModelKit.tube(pb, rr, 4), brace, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 1, 1)))
			var col_prof := PackedVector2Array([Vector2(0.105, 0.27), Vector2(0.1, 0.31), Vector2(0.08, 0.335)])
			_chest_meshes.append(_m(chest, _cached("shirt_col", func() -> Mesh: return ModelKit.lathe(col_prof, 16, 0.4, TAU - 0.4)), top_m, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 1, 0.8)))

	# --- arms
	for side in 2:
		var sh := _j[SH_L] if side == 0 else _j[SH_R]
		var el := _j[EL_L] if side == 0 else _j[EL_R]
		var wr := _j[WR_L] if side == 0 else _j[WR_R]
		var curl := 1.0 if side == 0 else -1.0
		_m(sh, ModelKit.sphere(0.056, 12, 6), sleeve_m, Vector3(0, -0.022, 0))
		_m(sh, _cached("upper_arm", func() -> Mesh: return _tube2(Vector3(0, -0.01, 0), Vector3(0, -0.3, 0), 0.053, 0.045, 10, 4)), sleeve_m)
		_m(el, ModelKit.sphere(0.045, 10, 6), sleeve_m if v != 2 else skin)
		if v == 2:
			_m(el, _cached("rolled", func() -> Mesh: return _tube2(Vector3(0, 0.03, 0), Vector3(0, -0.04, 0), 0.056, 0.05, 10, 1)), sleeve_m)
			_m(el, _cached("forearm_bare", func() -> Mesh: return _tube2(Vector3(0, 0, 0), Vector3(0, -0.26, 0), 0.036, 0.025, 8, 4)), skin)
		else:
			_m(el, _cached("sleeve", func() -> Mesh: return _tube2(Vector3(0, 0.0, 0), Vector3(0, -0.24, 0), 0.047, 0.041, 10, 4)), sleeve_m)
			_m(el, _cached("cuff", func() -> Mesh: return _tube2(Vector3(0, -0.21, 0), Vector3(0, -0.255, 0), 0.042, 0.046, 10, 1)), sleeve_m)
			_m(el, _cached("wrist", func() -> Mesh: return _tube2(Vector3(0, -0.2, 0), Vector3(0, -0.27, 0), 0.026, 0.022, 8, 1)), skin)
		_m(wr, _cached("hand_%d" % side, func() -> Mesh: return _hand_mesh(curl)), skin)

	# --- legs
	for side in 2:
		var th := _j[TH_L] if side == 0 else _j[TH_R]
		var kn := _j[KN_L] if side == 0 else _j[KN_R]
		var ft := _j[FT_L] if side == 0 else _j[FT_R]
		if v == 1:
			_m(th, _cached("thigh_thin", func() -> Mesh: return _tube2(Vector3(0, 0.03, 0), Vector3(0, -THIGH, 0), 0.068, 0.046, 10, 4)), leg_m)
			_m(kn, ModelKit.sphere(0.046, 10, 6), leg_m)
			_m(kn, _cached("shin_thin", _shin_thin_mesh), leg_m)
			_m(ft, _cached("shoe_heel", func() -> Mesh: return ModelKit.rounded_box(Vector3(0.075, 0.055, 0.21), 0.025, 2)), _leather(), Vector3(0, -0.015, -0.05), Vector3(-6, 0, 0))
			_m(ft, ModelKit.box(Vector3(0.04, 0.05, 0.04)), _leather(), Vector3(0, -0.025, 0.04))
		else:
			_m(th, _cached("thigh", func() -> Mesh: return _tube2(Vector3(0, 0.04, 0), Vector3(0, -THIGH, 0), 0.084, 0.06, 10, 4)), leg_m)
			_m(kn, ModelKit.sphere(0.06, 10, 6), leg_m)
			_m(kn, _cached("shin", func() -> Mesh: return _tube2(Vector3(0, 0, 0), Vector3(0, -SHIN + 0.02, 0), 0.058, 0.052, 10, 4)), leg_m)
			_m(kn, _cached("trouser_hem", func() -> Mesh: return _tube2(Vector3(0, -SHIN + 0.07, 0), Vector3(0, -SHIN + 0.0, 0), 0.053, 0.06, 10, 1)), leg_m)
			_m(ft, _cached("shoe", func() -> Mesh: return ModelKit.rounded_box(Vector3(0.092, 0.075, 0.27), 0.032, 2)), _leather(), Vector3(0, -0.012, -0.06))

	# --- head
	var head := _j[HEAD]
	_m(head, ModelKit.sphere(0.1, 18, 12), skin, Vector3(0, 0.07, 0.012), Vector3.ZERO, Vector3(0.9, 1.1, 1.02))
	_m(head, ModelKit.sphere(0.06, 12, 8), skin, Vector3(0, 0.005, -0.035), Vector3(10, 0, 0), Vector3(1.0, 0.85, 1.0))
	var bloom := _m(head, _face_bloom_mesh(), null, Vector3(0, 0.06, -0.085), Vector3(-8, 0, 0))
	bloom.name = "FaceBloom"
	_bloom_light = OmniLight3D.new()
	_bloom_light.light_color = Color(0.68, 0.38, 1.0)
	_bloom_light.light_energy = 0.3
	_bloom_light.omni_range = 0.9
	_bloom_light.shadow_enabled = false
	_bloom_light.position = Vector3(0, 0.06, -0.17)
	head.add_child(_bloom_light)
	match v:
		0:
			var felt := _cloth("felt", Color(0.24, 0.21, 0.19))
			var hat := ModelKit.pivot(head, "Hat", Vector3(0.01, 0.14, 0.02), Vector3(-6, 0, -9))
			_m(hat, ModelKit.cyl(0.078, 0.096, 0.075, 18), felt, Vector3(0, 0.038, 0), Vector3.ZERO, Vector3(1, 1, 1.12))
			_m(hat, ModelKit.cyl(0.097, 0.099, 0.022, 18, false), _cloth("hatband", Color(0.08, 0.07, 0.07)), Vector3(0, 0.013, 0), Vector3.ZERO, Vector3(1, 1, 1.12))
			_m(hat, ModelKit.lathe(PackedVector2Array([Vector2(0.17, 0.012), Vector2(0.165, -0.002), Vector2(0.09, 0.0), Vector2(0.09, 0.008), Vector2(0.165, 0.008), Vector2(0.17, 0.012)]), 22), felt, Vector3.ZERO, Vector3(0, 0, 0), Vector3(1, 1, 0.9))
		1:
			_m(head, ModelKit.sphere(0.106, 16, 10), _hair(), Vector3(0, 0.095, 0.03), Vector3(-10, 0, 0), Vector3(0.95, 1.0, 1.0))
			_m(head, ModelKit.sphere(0.052, 12, 8), _hair(), Vector3(0, 0.13, 0.1), Vector3.ZERO, Vector3(1.0, 0.9, 0.95))
			_m(head, ModelKit.torus(0.02, 0.04, 14, 6), _hair(), Vector3(0, 0.135, 0.108), Vector3(70, 0, 0))

	# --- crystal growths
	var cm := BloomKit.crystal_material(1.0)
	var specs_chest: Array
	var specs_head: Array
	var specs_arm: Array
	match v:
		0:
			specs_chest = [[Vector3(0.03, 0.19, 0.11), Vector3(0.2, 1, 0.9), 5, 0.28, 0.45],
				[Vector3(0.15, 0.25, 0.04), Vector3(0.7, 1, 0.3), 4, 0.21, 0.4],
				[Vector3(-0.05, 0.06, 0.12), Vector3(-0.3, 0.3, 1), 3, 0.13, 0.5]]
			specs_head = [[Vector3(-0.085, 0.08, 0.0), Vector3(-1, 0.5, 0.15), 4, 0.14, 0.4]]
			specs_arm = [[Vector3(0.035, -0.1, 0.01), Vector3(1, 0.15, 0.4), 3, 0.1, 0.45]]
		1:
			specs_chest = [[Vector3(-0.15, 0.24, 0.04), Vector3(-0.7, 1, 0.4), 5, 0.24, 0.4],
				[Vector3(0.0, 0.12, 0.12), Vector3(0, 0.35, 1), 4, 0.16, 0.5],
				[Vector3(0.03, 0.23, 0.1), Vector3(0.25, 1, 0.9), 3, 0.18, 0.4]]
			specs_head = [[Vector3(-0.07, 0.12, 0.03), Vector3(-0.8, 1, 0.3), 3, 0.12, 0.4]]
			specs_arm = [[Vector3(-0.035, -0.12, 0.01), Vector3(-1, 0.1, 0.3), 2, 0.09, 0.4]]
		_:
			specs_chest = [[Vector3(0.0, 0.18, 0.11), Vector3(0, 1, 0.85), 7, 0.36, 0.5],
				[Vector3(0.16, 0.25, 0.0), Vector3(0.8, 1, 0.2), 3, 0.17, 0.4],
				[Vector3(-0.03, 0.0, 0.13), Vector3(0, 0.2, 1), 3, 0.12, 0.5]]
			specs_head = [[Vector3(-0.03, 0.15, 0.02), Vector3(-0.45, 1, 0.25), 5, 0.17, 0.45]]
			specs_arm = [[Vector3(0.03, -0.12, 0.01), Vector3(1, 0.1, 0.3), 3, 0.1, 0.45]]
	_chest_meshes.append(_m(chest, _crystal_mesh("cr_chest_%d" % v, specs_chest, 11 + v), cm))
	_m(head, _crystal_mesh("cr_head_%d" % v, specs_head, 21 + v), cm)
	var arm_el := _j[EL_L] if v == 1 else _j[EL_R]
	_m(arm_el, _crystal_mesh("cr_arm_%d" % v, specs_arm, 31 + v), cm)

	# --- small bloom flowers + pale fungal nodules sprouting from the clothes
	var fung := _fungus()
	var sprout_pts := [[Vector3(-0.14, 0.24, 0.07), Vector3(-0.5, 1, 0.5)], [Vector3(0.09, 0.08, 0.12), Vector3(0.3, 0.4, 1)]]
	for i in sprout_pts.size():
		var sp: Array = sprout_pts[i]
		var fl := _m(chest, BloomKit.flower_mesh(40 + v * 3 + i), null, sp[0])
		fl.basis = _basis_up(sp[1]).scaled(Vector3.ONE * 0.38)
		_chest_meshes.append(fl)
	for i in 7:
		var a := float(i) * 0.9 + v
		var p := Vector3(cos(a) * 0.11, 0.2 + sin(a * 1.7) * 0.06, 0.09 + absf(sin(a)) * 0.03)
		_chest_meshes.append(_m(chest, ModelKit.sphere(0.018 + 0.01 * absf(sin(a * 3.1)), 8, 5), fung, p, Vector3.ZERO, Vector3(1, 0.6, 1)))

	# drifting motes off the bloom
	_ambient = BloomKit.attach_spore_trail(head, Vector3(0, 0.07, -0.12), 1.0e7)
	_ambient.amount = 10


static func _shin_thin_mesh() -> Mesh:
	var path := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, -0.1, 0.012), Vector3(0, -0.25, 0.008), Vector3(0, -SHIN, 0)])
	return ModelKit.tube(path, PackedFloat32Array([0.044, 0.046, 0.034, 0.026]), 10)


func _m(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	return ModelKit.mi(parent, mesh, mat, pos, rot, scl)


static func _basis_up(up: Vector3) -> Basis:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


func _build_hitboxes() -> void:
	ModelKit.add_hitbox(_j[HEAD], "head", self, ModelKit.sphere_shape(0.14), Transform3D(Basis(), Vector3(0, 0.07, -0.03)))
	ModelKit.add_hitbox(_j[SPINE], "torso", self, ModelKit.capsule_shape(0.17, 0.42), Transform3D(Basis(), Vector3(0, 0.12, 0.0)))
	ModelKit.add_hitbox(_j[CHEST], "torso", self, ModelKit.capsule_shape(0.2, 0.46), Transform3D(Basis(), Vector3(0, 0.14, 0.02)))
	for side in 2:
		var sfx := "_l" if side == 0 else "_r"
		ModelKit.add_hitbox(_j[SH_L if side == 0 else SH_R], "arm" + sfx, self, ModelKit.capsule_shape(0.065, 0.36), Transform3D(Basis(), Vector3(0, -0.14, 0)))
		ModelKit.add_hitbox(_j[EL_L if side == 0 else EL_R], "arm" + sfx, self, ModelKit.capsule_shape(0.06, 0.48), Transform3D(Basis(), Vector3(0, -0.21, -0.01)))
		ModelKit.add_hitbox(_j[TH_L if side == 0 else TH_R], "leg" + sfx, self, ModelKit.capsule_shape(0.09, 0.52), Transform3D(Basis(), Vector3(0, -0.21, 0)))
		ModelKit.add_hitbox(_j[KN_L if side == 0 else KN_R], "leg" + sfx, self, ModelKit.capsule_shape(0.07, 0.5), Transform3D(Basis(), Vector3(0, -0.21, -0.02)))


func _set_hitboxes_enabled(on: bool, n: Node = null) -> void:
	if n == null:
		n = self
	for c in n.get_children():
		if c is Area3D and c.has_meta("part"):
			(c as Area3D).set_deferred("monitorable", on)
			for cs in c.get_children():
				if cs is CollisionShape3D:
					(cs as CollisionShape3D).set_deferred("disabled", not on)
		else:
			_set_hitboxes_enabled(on, c)


# ==========================================================================
# Animation
# ==========================================================================

func _add(i: int, x: float, y := 0.0, z := 0.0) -> void:
	_pose[i] = _pose[i] + Vector3(x, y, z)


func _blend_rest(i: int, w: float) -> void:
	_pose[i] = _pose[i].lerp(_rest[i], w)


## Sharp onset then decaying tremor (twitches, hits).
static func _jerk(t: float) -> float:
	if t < 0.05:
		return t / 0.05
	return exp(-(t - 0.05) * 6.5) * (1.0 + 0.25 * sin(t * 55.0))


func _process(delta: float) -> void:
	var dt := minf(delta, 0.25)
	_t += dt
	if _dying:
		_death_t += delta
		if _death_t >= 10.0:
			finished.emit()
			queue_free()
			return
	if _gone:
		return
	_speed = ModelKit.damp(_speed, _target_speed, 8.0 if _dying else 3.0, dt)
	for i in NJ:
		_pose[i] = _rest[i]
	_off = Vector3.ZERO
	_arm_kmul = ModelKit.damp(_arm_kmul, 5.0 if _att_t >= 0.0 else 1.0, 10.0, dt)
	_locomotion(dt)
	_idle(dt)
	if _att_t >= 0.0:
		_attack(dt)
	if _hit_t >= 0.0:
		_hit(dt)
	if _em_t >= 0.0:
		_emerge(dt)
	if _dying:
		_death(dt)
	_apply(dt)


func _locomotion(dt: float) -> void:
	var walk := smoothstep(0.02, 0.2, _speed)
	var run := smoothstep(0.5, 1.0, _speed)
	if walk <= 0.0:
		return
	var freq := lerpf(0.8, 1.7, run)
	_phase = fposmod(_phase + dt * freq, 1.0)
	var ph := _phase * TAU
	var amp := lerpf(0.42, 0.78, run) * walk
	var sr := sin(ph)
	var cr := cos(ph)
	var sl := -sr
	var cl := -cr
	var drag := 1.0 - run * 0.65
	# right (good) leg
	_add(TH_R, amp * sr)
	var kr := lerpf(0.8, 1.45, run) * pow(maxf(cr, 0.0), 1.5) * walk
	_add(KN_R, -kr)
	# left (dragging) leg: short stride, stiff knee, toe scraping
	var ampl := amp * lerpf(1.0, 0.5, drag)
	_add(TH_L, ampl * sl, 0.12 * drag * walk, -0.05 * drag * walk)
	var kl := lerpf(0.8, 1.45, run) * lerpf(1.0, 0.3, drag) * pow(maxf(cl, 0.0), 1.5) * walk
	_add(KN_L, -kl - 0.1 * drag * walk)
	_add(FT_L, -0.45 * drag * walk * (0.4 + 0.6 * maxf(cl, 0.0)))
	# pelvis & torso
	var limp := drag * walk * maxf(sr, 0.0)
	_add(HIPS, 0.0, 0.16 * sr * amp, (0.05 * sr) * walk + 0.08 * limp)
	_add(SPINE, -0.32 * run * walk - 0.06 * walk, -0.12 * sr * amp, -0.06 * limp)
	_add(CHEST, 0.03 * sin(ph * 2.0) * walk, -0.14 * sr * amp, -0.06 * sr * walk)
	_add(NECK, 0.2 * run * walk, 0.0, 0.0)
	_add(HEAD, 0.07 * walk * sin(ph * 2.0 + 0.6), 0.05 * sr * walk, 0.07 * sl * walk)
	# arms: loose swing at the walk, reaching & flailing at the run
	var sw := lerpf(0.35, 0.5, run) * walk
	_add(SH_R, -sw * sr * 0.9 + run * (1.05 + 0.3 * sin(ph * 2.0 + 0.8)), 0.0, 0.12 * run)
	_add(SH_L, -sw * sl * 0.45 + run * (0.85 + 0.3 * sin(ph * 2.0 + 2.4)), 0.0, -0.12 * run)
	_add(EL_R, 0.15 * walk + 0.35 * run)
	_add(EL_L, 0.08 * walk + 0.3 * run)
	_add(WR_R, -0.2 * run)
	_add(WR_L, -0.2 * run)
	_off.y += 0.025 * run * sin(ph * 2.0)


func _idle(dt: float) -> void:
	var idle := 1.0 - smoothstep(0.0, 0.3, _speed)
	if _dying:
		idle *= 0.3
	_add(CHEST, 0.025 * sin(_t * 1.15))
	_add(HIPS, 0.0, 0.0, 0.035 * sin(_t * 0.53) * idle)
	_add(SPINE, 0.035 * sin(_t * 0.71) * idle, 0.06 * sin(_t * 0.37) * idle, 0.0)
	_add(HEAD, 0.09 * sin(_t * 0.43) * idle, 0.28 * sin(_t * 0.29) * idle, 0.15 * sin(_t * 0.61 + 1.0) * idle)
	_add(SH_L, 0.06 * sin(_t * 0.9) * idle, 0.0, -0.03 * sin(_t * 0.7))
	_add(SH_R, 0.05 * sin(_t * 0.8 + 2.0) * idle, 0.0, 0.03 * sin(_t * 0.65))
	_add(KN_L, -0.04 * (0.5 + 0.5 * sin(_t * 0.53)) * idle)
	_add(KN_R, -0.04 * (0.5 - 0.5 * sin(_t * 0.53)) * idle)
	# twitches
	if _dying:
		return
	_next_twitch -= dt
	if _next_twitch <= 0.0:
		_twitch_t = 0.0
		_twitch_kind = _rng.randi() % 4
		_twitch_sign = 1.0 if _rng.randf() < 0.5 else -1.0
		_next_twitch = _rng.randf_range(1.2, 4.5) * (1.0 if idle > 0.5 else 1.8)
	if _twitch_t >= 0.0:
		_twitch_t += dt
		var k := _jerk(_twitch_t)
		var s := _twitch_sign
		match _twitch_kind:
			0:
				_add(HEAD, -0.15 * k, 0.35 * s * k, 0.55 * s * k)
				_add(NECK, 0.0, 0.0, 0.2 * s * k)
			1:
				_add(SH_L if s > 0.0 else SH_R, 0.2 * k, 0.0, -0.4 * s * k)
				_add(CHEST, 0.0, 0.1 * s * k, 0.12 * s * k)
			2:
				_add(EL_R if s > 0.0 else EL_L, 0.9 * k)
				_add(WR_R if s > 0.0 else WR_L, -0.8 * k)
				_add(SH_R if s > 0.0 else SH_L, 0.3 * k)
			_:
				_add(SPINE, 0.12 * k, 0.0, 0.12 * s * k * sin(_twitch_t * 40.0))
				_add(HEAD, 0.25 * k)
		if _twitch_t > 0.7:
			_twitch_t = -1.0


func _attack(dt: float) -> void:
	_att_t += dt
	var ta := _att_t / ATTACK_DUR
	if ta >= 1.0:
		_att_t = -1.0
		return
	var w := ModelKit.env(ta, 0.0, 0.12, 0.75, 1.0)
	var wind := ModelKit.env(ta, 0.0, 0.3, 0.36, 0.46)
	var lunge := ModelKit.env(ta, 0.36, 0.45, 0.62, 0.95)
	_blend_rest(SH_L, w)
	_blend_rest(SH_R, w)
	_blend_rest(EL_L, w)
	_blend_rest(EL_R, w)
	_add(SPINE, 0.32 * wind - 0.6 * lunge, 0.1 * wind)
	_add(CHEST, 0.2 * wind - 0.22 * lunge)
	_add(NECK, -0.2 * wind + 0.3 * lunge)
	_add(HEAD, -0.15 * wind + 0.25 * lunge)
	_add(SH_L, 2.4 * wind + 1.25 * lunge, 0.0, -0.45 * wind - 0.12 * lunge)
	_add(SH_R, 2.4 * wind + 1.25 * lunge, 0.0, 0.45 * wind + 0.12 * lunge)
	_add(EL_L, 0.9 * wind - 0.15 * lunge)
	_add(EL_R, 0.9 * wind - 0.15 * lunge)
	_add(WR_L, -0.6 * wind + 0.3 * lunge)
	_add(WR_R, -0.6 * wind + 0.3 * lunge)
	_add(TH_R, 0.7 * lunge)
	_add(KN_R, -0.5 * lunge - 0.2 * wind)
	_add(TH_L, -0.3 * lunge + 0.1 * wind)
	_add(KN_L, -0.25 * wind - 0.1 * lunge)
	_off.z -= 0.38 * lunge


func _hit(dt: float) -> void:
	_hit_t += dt
	if _hit_t > 0.9:
		_hit_t = -1.0
		return
	var k := _jerk(_hit_t) * _hit_amp
	var d := _hit_dir
	match _hit_part:
		"head":
			_add(NECK, 0.45 * d.z * k, 0.0, -0.3 * d.x * k)
			_add(HEAD, 0.6 * d.z * k, 0.3 * d.x * k, -0.5 * d.x * k)
		"arm_l":
			_add(SH_L, -0.9 * k, 0.3 * k, -0.5 * k)
			_add(EL_L, 0.6 * k)
			_add(CHEST, 0.0, -0.25 * k, 0.1 * k)
		"arm_r":
			_add(SH_R, -0.9 * k, -0.3 * k, 0.5 * k)
			_add(EL_R, 0.6 * k)
			_add(CHEST, 0.0, 0.25 * k, -0.1 * k)
		"leg_l":
			_add(TH_L, 0.35 * k)
			_add(KN_L, -0.75 * k)
			_add(HIPS, 0.0, 0.0, 0.14 * k)
			_add(SPINE, -0.15 * k, 0.0, -0.15 * k)
		"leg_r":
			_add(TH_R, 0.35 * k)
			_add(KN_R, -0.75 * k)
			_add(HIPS, 0.0, 0.0, -0.14 * k)
			_add(SPINE, -0.15 * k, 0.0, 0.15 * k)
		_:
			_add(SPINE, 0.35 * d.z * k, 0.15 * d.x * k, -0.3 * d.x * k)
			_add(CHEST, 0.25 * d.z * k, 0.0, -0.15 * d.x * k)
			_add(SH_L, -0.4 * k, 0.0, -0.3 * k)
			_add(SH_R, -0.4 * k, 0.0, 0.3 * k)
	_add(SPINE, 0.12 * d.z * k, 0.0, -0.1 * d.x * k)
	_off += Vector3(d.x, 0.0, d.z) * 0.07 * k


func _emerge(dt: float) -> void:
	_em_t += dt
	var p := _em_t / EMERGE_DUR
	if p >= 1.0:
		_em_t = -1.0
		return
	var rise := smoothstep(0.0, 0.88, p)
	rise = clampf(rise + 0.035 * sin(p * 37.0) * (1.0 - p), 0.0, 1.0)
	_off.y += -1.75 * (1.0 - rise)
	var reach := ModelKit.env(p, 0.0, 0.08, 0.38, 0.58)
	var push := ModelKit.env(p, 0.35, 0.5, 0.68, 0.9)
	var crouch := 1.0 - smoothstep(0.55, 1.0, p)
	var claw := sin(_t * 9.0)
	_add(SH_L, 2.5 * reach + 0.35 * claw * reach - 0.1 * push, 0.0, -0.25 * reach)
	_add(SH_R, 2.6 * reach - 0.35 * claw * reach - 0.1 * push, 0.0, 0.25 * reach)
	_add(EL_L, 0.3 * reach + 1.1 * push)
	_add(EL_R, 0.3 * reach + 1.1 * push)
	_add(WR_L, -0.8 * push)
	_add(WR_R, -0.8 * push)
	_add(SPINE, -0.45 * push + 0.15 * reach, 0.0, 0.1 * claw * reach)
	_add(NECK, 0.35 * reach - 0.1 * push)
	_add(HEAD, 0.3 * reach, 0.35 * sin(_t * 17.0) * ModelKit.env(p, 0.8, 0.85, 0.9, 1.0))
	_add(TH_L, 1.0 * crouch)
	_add(TH_R, 1.2 * crouch)
	_add(KN_L, -1.7 * crouch)
	_add(KN_R, -1.9 * crouch)
	if p > 0.45 and not _em_puff2:
		_em_puff2 = true
		BloomKit.spawn_spore_puff(ModelKit.world_of(self), global_position + Vector3(0, 0.3, 0), 1.0)


func _apply(dt: float) -> void:
	# feet stay roughly flat
	_add(FT_L, -(_pose[TH_L].x + _pose[KN_L].x + _pose[HIPS].x) * 0.9)
	_add(FT_R, -(_pose[TH_R].x + _pose[KN_R].x + _pose[HIPS].x) * 0.9)
	# springy joints, sub-stepped for stability
	var steps := maxi(1, ceili(dt / 0.016))
	var h := dt / steps
	for i in NJ:
		if _det[i] != 0:
			continue
		var k := _stiff[i]
		if k > 0.0:
			var c := _dampc[i]
			if i >= SH_L and i <= WR_R:
				k *= _arm_kmul
				c *= sqrt(_arm_kmul)
			var decay := exp(-c * h)
			var v := _vel[i]
			var p := _cur[i]
			for _s in steps:
				v = (v + (_pose[i] - p) * (k * h)) * decay
				p += v * h
			_vel[i] = v
			_cur[i] = p
		else:
			_cur[i] = _pose[i]
		_j[i].rotation = _cur[i]
	# keep the lowest foot on the ground
	var hx := _cur[HIPS].x
	var hy := 0.0
	if _det[TH_L] == 0:
		hy = maxf(hy, THIGH * cos(hx + _cur[TH_L].x) * cos(_cur[TH_L].z) + SHIN * cos(hx + _cur[TH_L].x + _cur[KN_L].x))
	if _det[TH_R] == 0:
		hy = maxf(hy, THIGH * cos(hx + _cur[TH_R].x) * cos(_cur[TH_R].z) + SHIN * cos(hx + _cur[TH_R].x + _cur[KN_R].x))
	if hy <= 0.0:
		hy = THIGH + SHIN
	_j[HIPS].position.y = hy + HIP_DROP + ANKLE
	_body.position = _off
	# coat tails / skirt follow the legs a little
	var avg := 0.0
	if _det[TH_L] == 0 and _det[TH_R] == 0:
		avg = (_cur[TH_L].x + _cur[TH_R].x) * 0.5
	_skirt.rotation.x = ModelKit.damp(_skirt.rotation.x, avg * 0.35, 6.0, dt)
	_skirt.rotation.z = ModelKit.damp(_skirt.rotation.z, (_cur[TH_R].x - _cur[TH_L].x) * 0.05, 6.0, dt)
	if is_instance_valid(_bloom_light):
		_bloom_light.light_energy = 0.3 + 0.08 * sin(_t * 2.1) + 0.04 * sin(_t * 7.3)


# ==========================================================================
# Death
# ==========================================================================

func _mark_detached(from: int, to: int) -> void:
	for i in range(from, to + 1):
		_det[i] = 1


func _do_die() -> void:
	if not is_inside_tree():
		return
	ModelKit.strip_hitboxes(self)
	var w := ModelKit.world_of(self)
	if w and get_parent() != w:
		reparent(w, true)
	if is_instance_valid(_ambient):
		_ambient.queue_free()
		_ambient = null
	var imp := _death_imp
	var horiz := Vector3(imp.x, 0, imp.z)
	_fall_dir = horiz.normalized() if horiz.length() > 0.3 else -global_transform.basis.z
	match _death_part:
		"head":
			var head := _j[HEAD]
			var hp := head.to_global(Vector3(0, 0.07, -0.03))
			_det[HEAD] = 1
			var tw := head.create_tween()
			tw.tween_property(head, "scale", Vector3.ONE * 1.35, 0.07).set_ease(Tween.EASE_OUT)
			tw.tween_callback(head.queue_free)
			BloomKit.spawn_spore_puff(w, hp, 2.0)
			BloomKit.spawn_shards(w, hp, 10, imp * 0.35 + Vector3(0, 1.5, 0), 0.75)
			BloomKit.attach_spore_trail(_j[NECK], Vector3(0, 0.03, 0), 5.0)
			# head shot knocks the body back: fall away from the shooter unless pushed sideways
		"arm_l", "arm_r":
			var left := _death_part == "arm_l"
			var sh := _j[SH_L] if left else _j[SH_R]
			var sp := sh.global_position
			var side := global_transform.basis.x * (-1.0 if left else 1.0)
			_mark_detached(SH_L if left else SH_R, WR_L if left else WR_R)
			var vel := imp * 0.45 + side * 2.2 + Vector3(0, 2.6, 0)
			var ang := Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-9, 9), _rng.randf_range(-9, 9))
			ModelKit.make_debris(sh, w, vel, ang, 8.0, 4.0, 3.5)
			BloomKit.attach_spore_trail(_j[CHEST], _j[CHEST].to_local(sp), 4.0)
			BloomKit.spawn_shards(w, sp, 6, side * 1.5 + Vector3(0, 1, 0), 0.6)
			BloomKit.spawn_spore_puff(w, sp, 0.9)
			_fall_dir = (side + _fall_dir * 0.5).normalized()
		"leg_l", "leg_r":
			var left := _death_part == "leg_l"
			var th := _j[TH_L] if left else _j[TH_R]
			var tp := th.global_position
			var side := global_transform.basis.x * (-1.0 if left else 1.0)
			_mark_detached(TH_L if left else TH_R, FT_L if left else FT_R)
			var vel := imp * 0.4 + side * 1.2 + Vector3(0, 2.0, 0)
			var ang := global_transform.basis.x * _rng.randf_range(6, 10) + Vector3(0, _rng.randf_range(-4, 4), 0)
			ModelKit.make_debris(th, w, vel, ang, 8.0, 7.0, 3.5)
			BloomKit.attach_spore_trail(_j[HIPS], _j[HIPS].to_local(tp), 4.0)
			BloomKit.spawn_shards(w, tp, 6, side + Vector3(0, 1, 0), 0.6)
			BloomKit.spawn_spore_puff(w, tp, 0.9)
			_fall_dir = (side * 1.0 + _fall_dir * 0.4).normalized()
		_:
			_chest_light = OmniLight3D.new()
			_chest_light.light_color = Color(0.7, 0.4, 1.0)
			_chest_light.light_energy = 0.0
			_chest_light.omni_range = 2.5
			_chest_light.shadow_enabled = false
			_chest_light.position = Vector3(0, 0.12, 0)
			_j[CHEST].add_child(_chest_light)


func _death(_dt: float) -> void:
	var t := _death_t
	match _death_part:
		"head":
			_crumple(smoothstep(0.0, 0.65, t), 0.0)
			_add(SPINE, 0.25 * ModelKit.env(t, 0.0, 0.08, 0.15, 0.4))
			if t > 0.7 and _death_stage == 0:
				_death_stage = 1
				_collapse(_fall_dir, 2.2)
		"arm_l", "arm_r":
			var s := 1.0 if _death_part == "arm_r" else -1.0
			var stag := ModelKit.env(t, 0.0, 0.15, 0.5, 0.9)
			_add(SPINE, 0.2 * stag, 0.5 * s * stag, -0.35 * s * stag)
			_add(HEAD, -0.3 * stag, 0.3 * s * stag, 0.0)
			_add(SH_L if s > 0.0 else SH_R, 0.9 * stag, 0.0, -0.6 * s * stag)
			_add(TH_L, 0.4 * stag * (1.0 if s > 0.0 else 0.0))
			_add(TH_R, 0.4 * stag * (1.0 if s < 0.0 else 0.0))
			_crumple(smoothstep(0.55, 1.2, t), s)
			if t > 1.2 and _death_stage == 0:
				_death_stage = 1
				_collapse(_fall_dir, 2.0)
		"leg_l", "leg_r":
			var s := 1.0 if _death_part == "leg_r" else -1.0
			_add(SPINE, 0.0, 0.0, 0.5 * s * smoothstep(0.0, 0.2, t))
			_add(SH_L, 1.2 * smoothstep(0.0, 0.2, t), 0.0, -0.6)
			_add(SH_R, 1.2 * smoothstep(0.0, 0.2, t), 0.0, 0.6)
			if t > 0.18 and _death_stage == 0:
				_death_stage = 1
				_collapse(_fall_dir, 3.0)
		_:
			var seize := smoothstep(0.0, 0.3, t)
			var shake := sin(t * 70.0) * 0.06 * seize
			_add(SPINE, 0.45 * seize + shake, 0.0, shake)
			_add(CHEST, 0.2 * seize)
			_add(NECK, -0.4 * seize)
			_add(SH_L, 1.4 * seize, 0.0, -1.0 * seize + shake)
			_add(SH_R, 1.4 * seize, 0.0, 1.0 * seize - shake)
			_add(EL_L, -0.2 * seize)
			_add(EL_R, -0.2 * seize)
			if _chest_light:
				_chest_light.light_energy = 9.0 * seize * seize
			if t > 0.38 and _death_stage == 0:
				_death_stage = 1
				_shatter_torso()
			if t > 0.75 and _death_stage == 1:
				_death_stage = 2
				_collapse(_fall_dir, 1.4)


## Knees buckle, body slumps. c 0..1; s = sideways lean sign.
func _crumple(c: float, s: float) -> void:
	_add(TH_L, 1.25 * c)
	_add(TH_R, 1.1 * c)
	_add(KN_L, -2.2 * c)
	_add(KN_R, -2.05 * c)
	_add(SPINE, -0.45 * c, 0.0, 0.25 * s * c)
	_add(CHEST, -0.2 * c)
	_add(NECK, 0.25 * c)
	_add(HEAD, 0.45 * c, 0.0, 0.35 * c)
	_add(SH_L, -0.25 * c, 0.0, -0.1 * c)
	_add(SH_R, -0.25 * c, 0.0, 0.1 * c)
	_add(EL_L, -0.2 * c)
	_add(EL_R, -0.2 * c)


## Hands the remaining body to physics: one tumbling rigid body that tips over along `dir`.
func _collapse(dir: Vector3, tip: float) -> void:
	_gone = true
	var w := ModelKit.world_of(self)
	if w == null:
		return
	var ang := Vector3.UP.cross(dir).normalized() * tip + Vector3(0, _rng.randf_range(-0.6, 0.6), 0)
	# particles would inflate the debris collision box: hide them while it is measured
	var parts: Array[GPUParticles3D] = []
	_find_particles(_j[HIPS], parts)
	for p in parts:
		p.visible = false
	ModelKit.make_debris(_j[HIPS], w, dir * 0.6 + Vector3(0, 0.4, 0), ang, 8.0, 45.0, 0.0)
	for p in parts:
		p.visible = true
	for i in NJ:
		_det[i] = 1


static func _find_particles(n: Node, out: Array[GPUParticles3D]) -> void:
	for c in n.get_children():
		if c is GPUParticles3D:
			out.append(c)
		else:
			_find_particles(c, out)


func _shatter_torso() -> void:
	var w := ModelKit.world_of(self)
	var chest := _j[CHEST]
	var cp := chest.to_global(Vector3(0, 0.12, 0.0))
	var imp := _death_imp
	BloomKit.spawn_shards(w, cp, 26, imp * 0.35 + Vector3(0, 1.8, 0), 1.25)
	BloomKit.spawn_spore_puff(w, cp, 2.4)
	var bx := global_transform.basis.x
	# head flies up
	if is_instance_valid(_j[HEAD]) and _det[HEAD] == 0:
		_det[HEAD] = 1
		_det[NECK] = 1
		ModelKit.make_debris(_j[NECK], w, imp * 0.3 + Vector3(0, 4.2, 0) + bx * _rng.randf_range(-1, 1),
			Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8)), 8.0, 4.0, 3.0)
	# arms thrown out
	for side in 2:
		var sh := SH_L if side == 0 else SH_R
		if _det[sh] != 0:
			continue
		var sgn := -1.0 if side == 0 else 1.0
		_mark_detached(sh, sh + 2)
		ModelKit.make_debris(_j[sh], w, imp * 0.3 + bx * sgn * 3.2 + Vector3(0, 2.5, 0),
			Vector3(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10), _rng.randf_range(-10, 10)), 8.0, 4.0, 2.5)
	# crystal chunks burst out of the chest
	for i in 4:
		var chunk := MeshInstance3D.new()
		chunk.mesh = BloomKit.cluster_mesh(500 + i, 0.32)
		chest.add_child(chunk)
		chunk.position = Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(0.0, 0.25), _rng.randf_range(-0.05, 0.08))
		chunk.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		var dir := (chunk.global_position - cp).normalized() + Vector3(_rng.randf_range(-0.5, 0.5), 0.6, _rng.randf_range(-0.5, 0.5))
		ModelKit.make_debris(chunk, w, imp * 0.3 + dir.normalized() * _rng.randf_range(3.0, 5.0),
			Vector3(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12), _rng.randf_range(-12, 12)), 7.0, 2.0, 0.0)
	# the chest itself is gone; a jagged crystal stump erupts from the waist
	for m in _chest_meshes:
		if is_instance_valid(m):
			m.queue_free()
	for m in _spine_meshes:
		if is_instance_valid(m):
			m.visible = false
	_chest_meshes.clear()
	var stump := MeshInstance3D.new()
	stump.mesh = BloomKit.cluster_mesh(77, 0.45)
	_j[SPINE].add_child(stump)
	stump.position = Vector3(0, 0.05, 0)
	if _chest_light:
		var tw := _chest_light.create_tween()
		tw.tween_property(_chest_light, "light_energy", 0.0, 0.5)
		tw.tween_callback(_chest_light.queue_free)
		_chest_light = null
	_det[CHEST] = 1
	BloomKit.attach_spore_trail(_j[SPINE], Vector3(0, 0.2, 0), 5.0)
