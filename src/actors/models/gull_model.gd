class_name GullModel
extends Node3D
## Ambient seagull (~0.6 m wingspan) for flocks. Cheap (~600 tris, shared meshes/materials).
## Origin at the feet (body centre ~0.09 m above), faces -Z.
## set_flap(0..1) = flapping effort (0 = glide), set_glide(true) forces a glide,
## auto_cycle alternates flap bursts and glides with a random phase so flocks never sync.

@export var auto_cycle := true

var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _wing_in: Array[Node3D] = []
var _wing_out: Array[Node3D] = []
var _legs: Node3D
var _folded: Node3D
var _rng := RandomNumberGenerator.new()

var _flap := 0.7
var _force_glide := false
var _perched := false
var _bank := 0.0
var _bank_s := 0.0
var _phase := 0.0
var _time := 0.0
var _amp := 0.0
var _glide_w := 0.0
var _perch_w := 0.0
var _cycle_t := 0.0
var _cycle_gliding := false
var _freq_jit := 1.0


func _ready() -> void:
	_rng.randomize()
	_phase = _rng.randf() * TAU
	_time = _rng.randf() * 20.0
	_freq_jit = _rng.randf_range(0.88, 1.12)
	_cycle_t = _rng.randf_range(0.5, 3.0)
	_cycle_gliding = _rng.randf() < 0.4
	_build()
	_process(0.0)


## 0 = glide, 1 = hard flapping.
func set_flap(v: float) -> void:
	_flap = clampf(v, 0.0, 1.0)


func set_glide(b: bool) -> void:
	_force_glide = b


## Roll into a turn, -1..1 (positive banks right).
func set_bank(v: float) -> void:
	_bank = clampf(v, -1.0, 1.0)


## Standing on a roof/post: wings folded, legs down.
func set_perched(b: bool) -> void:
	_perched = b


# --------------------------------------------------------------------------

static func _mat(key: String, c: Color, rough := 0.85, cull_off := false, vcol := false, backlit := false) -> StandardMaterial3D:
	if ModelKit.has_mat(key):
		return ModelKit.get_mat(key) as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if cull_off:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if vcol:
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if backlit:
		# thin feathers: sunlight shines through, so wings read pale from below
		m.backlight_enabled = true
		m.backlight = Color(0.6, 0.6, 0.6)
	return ModelKit.put_mat(key, m) as StandardMaterial3D


func _build() -> void:
	var white := _mat("gull_white", Color(0.93, 0.93, 0.91), 0.85, false, false, true)
	var grey := _mat("gull_grey", Color(0.66, 0.69, 0.74))
	var wing_mat := _mat("gull_wing", Color.WHITE, 0.85, false, true, true)
	var tail_mat := _mat("gull_tail", Color(0.93, 0.93, 0.91), 0.85, true, false, true)
	var black := _mat("gull_black", Color(0.05, 0.05, 0.06), 0.6)
	var beak := _mat("gull_beak", Color(0.96, 0.76, 0.16), 0.45)
	var leg_mat := _mat("gull_leg", Color(0.95, 0.52, 0.22), 0.6)
	var eye := _mat("gull_eye", Color(0.02, 0.02, 0.02), 0.15)
	var red := _mat("gull_red", Color(0.85, 0.12, 0.08), 0.4)

	_body = ModelKit.pivot(self, "Body", Vector3(0, 0.09, 0))
	var body_mesh := ModelKit.cached_mesh("gull_body")
	if body_mesh == null:
		body_mesh = ModelKit.cache_mesh("gull_body", ModelKit.lathe(PackedVector2Array([
			Vector2(0.0, -0.15), Vector2(0.01, -0.145), Vector2(0.022, -0.12), Vector2(0.034, -0.085),
			Vector2(0.043, -0.045), Vector2(0.047, -0.01), Vector2(0.046, 0.025), Vector2(0.04, 0.06),
			Vector2(0.03, 0.085), Vector2(0.018, 0.1), Vector2(0.0, 0.108)]), 14))
	# lathe axis +Y -> forward (-Z): rotate -90 deg about X
	ModelKit.mi(_body, body_mesh, white, Vector3.ZERO, Vector3(-90, 0, 0), Vector3(1.0, 1.0, 0.88))
	# grey mantle on the back
	ModelKit.mi(_body, ModelKit.sphere(0.5, 10, 5), grey, Vector3(0, 0.014, 0.01), Vector3.ZERO, Vector3(0.08, 0.05, 0.2))
	# neck filler blends the head into the body
	ModelKit.mi(_body, ModelKit.sphere(0.5, 10, 6), white, Vector3(0, 0.008, -0.08), Vector3(-35, 0, 0), Vector3(0.068, 0.064, 0.1))

	_head = ModelKit.pivot(_body, "Head", Vector3(0, 0.026, -0.098))
	ModelKit.mi(_head, ModelKit.sphere(0.03, 12, 8), white, Vector3(0, 0.008, -0.014), Vector3.ZERO, Vector3(0.92, 0.9, 1.22))
	ModelKit.mi(_head, ModelKit.cyl(0.004, 0.0095, 0.046, 8), beak, Vector3(0, 0.002, -0.062), Vector3(-94, 0, 0), Vector3(0.7, 1.0, 1.25))
	ModelKit.mi(_head, ModelKit.sphere(0.004, 8, 5), beak, Vector3(0, -0.0015, -0.082), Vector3.ZERO, Vector3(0.8, 1.0, 1.1))
	ModelKit.mi(_head, ModelKit.sphere(0.0035, 6, 4), red, Vector3(0, -0.0065, -0.079))
	for s in [-1.0, 1.0]:
		ModelKit.mi(_head, ModelKit.sphere(0.0045, 6, 4), eye, Vector3(0.02 * s, 0.016, -0.03))

	_tail = ModelKit.pivot(_body, "Tail", Vector3(0, 0.008, 0.12))
	ModelKit.mi(_tail, _tail_mesh(), tail_mat)

	for k in 2:
		var s := -1.0 if k == 0 else 1.0
		var wi := ModelKit.pivot(_body, "WingIn", Vector3(0.036 * s, 0.02, -0.02))
		ModelKit.mi(wi, _wing_mesh(s, false), wing_mat)
		var wo := ModelKit.pivot(wi, "WingOut", Vector3(0.12 * s, 0.0, 0.0))
		ModelKit.mi(wo, _wing_mesh(s, true), wing_mat)
		_wing_in.append(wi)
		_wing_out.append(wo)

	# folded wings (shown when perched instead of the spread wings)
	_folded = ModelKit.pivot(_body, "FoldedWings", Vector3.ZERO)
	for s2 in [-1.0, 1.0]:
		ModelKit.mi(_folded, ModelKit.sphere(0.5, 10, 5), grey, Vector3(0.036 * s2, 0.012, 0.035), Vector3(6, 0, 0), Vector3(0.03, 0.032, 0.15))
		ModelKit.mi(_folded, ModelKit.sphere(0.5, 6, 4), black, Vector3(0.022 * s2, 0.02, 0.13), Vector3(10, 0, 0), Vector3(0.018, 0.012, 0.085))
		ModelKit.mi(_folded, ModelKit.sphere(0.0035, 5, 3), white, Vector3(0.026 * s2, 0.025, 0.15))
	_folded.visible = false

	_legs = ModelKit.pivot(_body, "Legs", Vector3(0, -0.035, 0.03))
	for s in [-1.0, 1.0]:
		var leg := ModelKit.pivot(_legs, "Leg", Vector3(0.016 * s, 0, 0))
		ModelKit.mi(leg, ModelKit.cyl(0.0035, 0.0035, 0.06, 5, false), leg_mat, Vector3(0, -0.03, 0))
		ModelKit.mi(leg, ModelKit.box(Vector3(0.02, 0.003, 0.024)), leg_mat, Vector3(0, -0.06, -0.008))


## Wing segment, vertex coloured. side -1 = left. Outer has black tip with a white "mirror".
func _wing_mesh(side: float, outer: bool) -> Mesh:
	var key := "gull_wing_%s_%d" % ["o" if outer else "i", int(side)]
	var cached := ModelKit.cached_mesh(key)
	if cached:
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := Color(0.68, 0.71, 0.76)
	var w := Color(0.93, 0.93, 0.92)
	var b := Color(0.05, 0.05, 0.06)
	var pts: Array[Vector3] = []
	var cols: Array[Color] = []
	var tris: Array[int] = []
	if not outer:
		# leading edge, camber line, trailing edge  x: 0 .. 0.12
		pts = [Vector3(0, 0.004, -0.036), Vector3(0.06, 0.005, -0.035), Vector3(0.126, 0.004, -0.03),
			Vector3(0, 0.012, 0.0), Vector3(0.06, 0.011, 0.0), Vector3(0.126, 0.008, 0.0),
			Vector3(0, 0.0, 0.07), Vector3(0.06, 0.0, 0.06), Vector3(0.126, 0.0, 0.05)]
		cols = [g, g, g, g, g, g, w, w.lerp(g, 0.3), w.lerp(g, 0.3)]
		tris = [0, 1, 4, 0, 4, 3, 1, 2, 5, 1, 5, 4, 3, 4, 7, 3, 7, 6, 4, 5, 8, 4, 8, 7]
	else:
		pts = [Vector3(0, 0.004, -0.03), Vector3(0.07, 0.003, -0.024), Vector3(0.155, 0.0, 0.012),
			Vector3(0, 0.008, 0.0), Vector3(0.07, 0.006, 0.006),
			Vector3(0, 0.0, 0.05), Vector3(0.07, 0.0, 0.045), Vector3(0.11, 0.0, 0.034)]
		var gb := g.lerp(b, 0.85)
		cols = [g, gb, b, g, gb, w.lerp(g, 0.4), b, b]
		tris = [0, 1, 4, 0, 4, 3, 1, 2, 4, 3, 4, 6, 3, 6, 5, 4, 2, 7, 4, 7, 6]
	for i in pts.size():
		pts[i].x *= side
	# underside: paler (gull wings are white/light grey below), tips stay dark
	var under: Array[Color] = []
	for c0 in cols:
		under.append(c0.lerp(Color(0.88, 0.89, 0.9), 0.75) if c0.r > 0.3 else c0.lerp(Color(0.3, 0.3, 0.32), 0.3))
	for pass_i in 2:
		var off := Vector3(0, -0.0015 * pass_i, 0)
		for t in range(0, tris.size(), 3):
			var a := pts[tris[t]] + off
			var bb := pts[tris[t + 1]] + off
			var c := pts[tris[t + 2]] + off
			var n := (bb - a).cross(c - a).normalized()
			if (n.y < 0.0) != (pass_i == 1):
				n = -n
			var cs := cols if pass_i == 0 else under
			_wtri(st, a, bb, c, n, cs[tris[t]], cs[tris[t + 1]], cs[tris[t + 2]])
	# white "mirror" spot near the tip
	if outer:
		var sp := Vector3(0.115 * side, 0.0025, 0.012)
		var sn := Vector3.UP
		for k in 5:
			var a0 := TAU * k / 5.0
			var a1 := TAU * (k + 1) / 5.0
			var p0 := sp + Vector3(cos(a0) * 0.012, 0, sin(a0) * 0.008)
			var p1 := sp + Vector3(cos(a1) * 0.012, 0, sin(a1) * 0.008)
			ModelKit.tri(st, sp, p0, p1, sn, sn, sn, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, w)
	return ModelKit.cache_mesh(key, st.commit())


## Triangle with per-vertex colours (+UV so it can share a surface with ModelKit.tri).
static func _wtri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if (c - a).cross(b - a).dot(n) < 0.0:
		var tv := b; b = c; c = tv
		var tc := cb; cb = cc; cc = tc
	st.set_normal(n); st.set_uv(Vector2.ZERO); st.set_color(ca); st.add_vertex(a)
	st.set_normal(n); st.set_uv(Vector2.ZERO); st.set_color(cb); st.add_vertex(b)
	st.set_normal(n); st.set_uv(Vector2.ZERO); st.set_color(cc); st.add_vertex(c)


func _tail_mesh() -> Mesh:
	var cached := ModelKit.cached_mesh("gull_tail")
	if cached:
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := Color(0.93, 0.93, 0.92)
	var o := Vector3(0, 0, -0.01)
	var n := Vector3.UP
	var pts: Array[Vector3] = [Vector3(-0.035, 0, 0.06), Vector3(-0.015, 0, 0.072), Vector3(0.015, 0, 0.072), Vector3(0.035, 0, 0.06)]
	for i in 3:
		ModelKit.tri(st, o, pts[i], pts[i + 1], n, n, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, w)
	return ModelKit.cache_mesh("gull_tail", st.commit())


# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	# flap / glide cycling
	var want_glide := _force_glide or _flap < 0.02
	if auto_cycle and not want_glide:
		_cycle_t -= delta
		if _cycle_t <= 0.0:
			_cycle_gliding = not _cycle_gliding
			_cycle_t = _rng.randf_range(1.5, 4.0) if _cycle_gliding else _rng.randf_range(1.2, 3.5)
		want_glide = _cycle_gliding
	_glide_w = ModelKit.damp(_glide_w, 1.0 if want_glide else 0.0, 3.0, delta)
	_perch_w = ModelKit.damp(_perch_w, 1.0 if _perched else 0.0, 5.0, delta)
	var effort := maxf(_flap, 0.25)
	_amp = ModelKit.damp(_amp, effort * (1.0 - _glide_w), 4.0, delta)
	var freq := lerpf(2.6, 4.2, effort) * _freq_jit
	_phase = fposmod(_phase + delta * TAU * freq * (0.3 + 0.7 * (1.0 - _glide_w)), TAU)
	var s := sin(_phase)
	var s_lag := sin(_phase - 0.7)
	var fly := 1.0 - _perch_w

	# body
	_bank_s = ModelKit.damp(_bank_s, _bank, 2.0, delta)
	var glide_sway := sin(_time * 0.9) * 0.08 + sin(_time * 2.3) * 0.03
	_body.position = Vector3(0, 0.09 + (-s * 0.012 * _amp + sin(_time * 1.3) * 0.004 * _glide_w) * fly, 0)
	_body.rotation = Vector3(
		(0.05 + s * 0.04 * _amp) * fly + 0.12 * _perch_w,
		sin(_time * 0.7) * 0.03 * fly,
		(-_bank_s * 0.7 + glide_sway * _glide_w) * fly)

	# wings
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var inner_z := (0.14 + s * 0.95 * _amp) * (1.0 - _glide_w) + (0.12 + sin(_time * 3.1 + k) * 0.03) * _glide_w
		var outer_z := (s_lag * 0.7 * _amp - maxf(0.0, -s) * 0.0 + 0.04) * (1.0 - _glide_w) + (-0.06 + sin(_time * 2.7 + k) * 0.03) * _glide_w
		var outer_y := (maxf(0.0, s_lag) * 0.35 * _amp) # sweep back on upstroke
		var twist := -s * 0.25 * _amp
		var wi := _wing_in[k]
		var wo := _wing_out[k]
		wi.rotation = Vector3(twist, side * 0.12 * _glide_w, side * inner_z)
		wo.rotation = Vector3(twist * 0.6, side * outer_y + side * -0.15 * _glide_w, side * outer_z)
		# perched: spread wings shrink into the body while the folded wings appear
		var ws := maxf(0.001, 1.0 - _perch_w * 1.4)
		wi.scale = Vector3(ws, ws, ws)
	_folded.visible = _perch_w > 0.3

	# head stays stable-ish (birds hold their head steady), looks around a little
	_head.rotation = Vector3(
		-_body.rotation.x * 0.8 + sin(_time * 0.6) * 0.05,
		sin(_time * 0.43 + 1.0) * 0.35 * (0.3 + 0.7 * _perch_w),
		-_body.rotation.z * 0.6)
	_tail.rotation = Vector3(0.1 + s * 0.08 * _amp, 0, 0)
	_legs.rotation = Vector3(lerpf(1.25, 0.0, _perch_w), 0, 0)
