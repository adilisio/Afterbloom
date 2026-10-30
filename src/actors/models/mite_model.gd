class_name MiteModel
extends Node3D
## Bloom mite: a dog-sized crystalline tick/crab (~0.5 m tall, ~0.9 m long).
## Faceted crystal-shell carapace, glowing violet underbelly, six two-segment legs driven by
## a phased tripod gait + analytic 2-bone IK. Origin at feet, faces -Z.
## Parts: "body", "head", "legs".

signal finished

const PARTS := ["body", "head", "legs"]
const L1 := 0.25 ## femur length
const L2 := 0.36 ## tibia length
const STAND_H := 0.26
const ATK_DUR := 0.9
const EMERGE_DUR := 1.6
const DEAD_REST_H := 0.11
const BELLY_E := 1.15
const HIPS: Array[Vector3] = [
	Vector3(-0.14, -0.02, -0.16), Vector3(0.14, -0.02, -0.16),
	Vector3(-0.17, -0.02, 0.0), Vector3(0.17, -0.02, 0.0),
	Vector3(-0.15, -0.02, 0.15), Vector3(0.15, -0.02, 0.15)]
const FEET: Array[Vector3] = [
	Vector3(-0.42, 0.0, -0.46), Vector3(0.42, 0.0, -0.46),
	Vector3(-0.54, 0.0, -0.02), Vector3(0.54, 0.0, -0.02),
	Vector3(-0.44, 0.0, 0.42), Vector3(0.44, 0.0, 0.42)]
## tripod groups: (L1, R2, L3) vs (R1, L2, R3), with a little per-leg slop
const GAIT_OFF: Array[float] = [0.0, 0.5, 0.52, 0.03, 0.05, 0.47]

var _body: Node3D
var _head: Node3D
var _head_alive := true
var _mand: Array[Node3D] = []
var _hips: Array[Node3D] = []
var _femurs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _leg_alive: Array[bool] = [true, true, true, true, true, true]
var _plates: Array[MeshInstance3D] = []
var _belly_mat: StandardMaterial3D
var _light: OmniLight3D
var _legs_marker: Node3D
var _rng := RandomNumberGenerator.new()

var _speed := 0.0
var _target_speed := 0.0
var _phase := 0.0
var _time := 0.0
var _atk_t := -1.0
var _emerge_t := -1.0
var _hit_off := Vector3.ZERO
var _hit_vel := Vector3.ZERO
var _hit_rot := Vector3.ZERO
var _hit_rvel := Vector3.ZERO
var _flinch := 0.0

var _dying := false
var _dead_t := -1.0
var _curl := 0.0
var _body_y := STAND_H
var _hop_v := 0.0
var _slide := Vector3.ZERO
var _slide_pos := Vector3.ZERO
var _roll := 0.0
var _roll_v := 0.0
var _roll_target := PI
var _dead_pitch := 0.0
var _dead_yaw := 0.0
var _belly_energy := BELLY_E
var _done := false


func _ready() -> void:
	_rng.randomize()
	_phase = _rng.randf()
	_time = _rng.randf() * 10.0
	_build()


# --------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------

func set_locomotion(speed: float) -> void:
	_target_speed = clampf(speed, 0.0, 1.0)


## Rears up, then leaps/snaps forward. Hit moment ~45 % through.
func play_attack() -> float:
	if _dying:
		return 0.0
	_atk_t = 0.0
	return ATK_DUR


## `from_dir`: world direction the hit travels (shooter -> mite); the mite is knocked along it.
func play_hit(part: String, from_dir: Vector3) -> void:
	if _dying:
		return
	var l := global_transform.basis.inverse() * from_dir
	l.y = 0.0
	if l.length_squared() < 1e-6:
		l = Vector3(0, 0, 1)
	l = l.normalized()
	_hit_vel += l * 1.4 + Vector3(0, 0.5, 0)
	_hit_rvel += Vector3(l.z * 7.0, _rng.randf_range(-5.0, 5.0), -l.x * 7.0)
	if part == "head":
		_hit_rvel.x += 9.0
	_flinch = 1.0


## Bursts up out of the ground / crystal bed.
func play_emerge() -> float:
	if _dying:
		return 0.0
	_emerge_t = 0.0
	if is_inside_tree():
		var w := ModelKit.world_of(self)
		BloomKit.spawn_spore_puff(w, global_position + Vector3(0, 0.1, 0), 0.9)
		BloomKit.spawn_shards(w, global_position + Vector3(0, 0.05, 0), 5, Vector3(0, 2.5, 0), 0.6)
	return EMERGE_DUR


func die(part: String, impulse: Vector3) -> void:
	if _dying:
		return
	_dying = true
	_atk_t = -1.0
	_emerge_t = -1.0
	ModelKit.strip_hitboxes(self)
	_do_die.call_deferred(part, impulse)


func get_part_node(part: String) -> Node3D:
	match part:
		"head":
			return _head if _head_alive else _body
		"legs":
			return _legs_marker
		_:
			return _body


func get_parts() -> PackedStringArray:
	return PackedStringArray(PARTS)


# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------

func _chitin() -> StandardMaterial3D:
	if ModelKit.has_mat("mite_chitin"):
		return ModelKit.get_mat("mite_chitin") as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.075, 0.055, 0.1)
	m.roughness = 0.28
	m.metallic = 0.15
	m.clearcoat_enabled = true
	m.clearcoat = 0.8
	m.clearcoat_roughness = 0.1
	m.rim_enabled = true
	m.rim = 0.4
	m.rim_tint = 0.6
	return ModelKit.put_mat("mite_chitin", m) as StandardMaterial3D


func _build() -> void:
	var crystal := BloomKit.crystal_material(1.0)
	var shell := BloomKit.crystal_material(0.42)
	var chitin := _chitin()
	var dot_mat := ModelKit.glow("mite_eye", Color(0.85, 0.6, 1.0), 6.0)

	_body = ModelKit.pivot(self, "Body", Vector3(0, STAND_H, 0))

	# glowing underbelly (unique material so it can pulse / fade on death)
	_belly_mat = ModelKit.glow("mite_belly", Color(0.5, 0.14, 1.0), _belly_energy, true)
	_belly_mat.albedo_color = Color(0.16, 0.05, 0.3)
	_belly_mat.emission_texture = ModelKit.noise_tex("mite_belly_n", 0.03, ModelKit.grad([Color(0.25, 0.25, 0.25), Color(1, 1, 1)], [0.3, 0.75]), false, 4.0, 128, 3, 5)
	_belly_mat.uv1_scale = Vector3(3, 2, 1)
	_belly_mat.roughness = 0.35
	var belly := ModelKit.mi(_body, ModelKit.sphere(0.5, 16, 10), _belly_mat, Vector3(0, -0.005, 0.03), Vector3.ZERO, Vector3(0.34, 0.2, 0.72), "Belly")
	belly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# belly segment ridges
	for k in 4:
		var z := -0.17 + k * 0.11
		var w := 0.17 - absf(z - 0.03) * 0.25
		ModelKit.mi(_body, ModelKit.torus(w - 0.012, w + 0.004, 18, 4), chitin, Vector3(0, -0.035, z), Vector3(0, 0, 0), Vector3(1.0, 0.6, 0.55))

	# carapace plates: thorax + two abdomen segments (faceted crystal shell)
	var plate_defs := [
		[Vector3(0, 0.0, -0.13), Vector3(0.18, 0.12, 0.17), 11],
		[Vector3(0, 0.01, 0.06), Vector3(0.225, 0.165, 0.15), 12],
		[Vector3(0, 0.0, 0.22), Vector3(0.21, 0.15, 0.17), 13]]
	for i in plate_defs.size():
		var d: Array = plate_defs[i]
		var mesh := _facet_dome("mite_plate_%d" % i, d[1], 12, 5, d[2], 0.012, -0.32, 0.12, 0.42)
		var plate := ModelKit.mi(_body, mesh, shell, d[0], Vector3.ZERO, Vector3.ONE, "Plate%d" % i)
		_plates.append(plate)
	# crystal growth on the abdomen + a ridge of small spikes
	var c1 := MeshInstance3D.new()
	c1.mesh = _crystal_mesh("mite_crys_a", 21, [
		[Vector3(0.02, 0.13, 0.0), Vector3(0.1, 1, 0.45), 0.22, 0.034],
		[Vector3(-0.07, 0.11, 0.03), Vector3(-0.6, 1, 0.35), 0.15, 0.026],
		[Vector3(0.08, 0.11, -0.03), Vector3(0.7, 1, 0.1), 0.12, 0.022],
		[Vector3(-0.02, 0.12, -0.06), Vector3(-0.15, 1, -0.2), 0.1, 0.02]])
	c1.material_override = crystal
	_plates[1].add_child(c1)
	var c2 := MeshInstance3D.new()
	c2.mesh = _crystal_mesh("mite_crys_b", 22, [
		[Vector3(0.0, 0.11, 0.03), Vector3(0.0, 1, 0.9), 0.16, 0.026],
		[Vector3(0.07, 0.09, 0.0), Vector3(0.8, 1, 0.5), 0.1, 0.018],
		[Vector3(-0.08, 0.08, 0.05), Vector3(-0.9, 0.8, 0.6), 0.09, 0.016]])
	c2.material_override = crystal
	_plates[2].add_child(c2)
	var c3 := MeshInstance3D.new()
	c3.mesh = _crystal_mesh("mite_crys_c", 23, [
		[Vector3(0.0, 0.1, 0.04), Vector3(0.0, 1, 0.5), 0.07, 0.014],
		[Vector3(0.06, 0.08, 0.02), Vector3(0.6, 1, 0.3), 0.05, 0.01],
		[Vector3(-0.06, 0.08, 0.02), Vector3(-0.6, 1, 0.3), 0.05, 0.01]])
	c3.material_override = crystal
	_plates[0].add_child(c3)

	# head
	_head = ModelKit.pivot(_body, "Head", Vector3(0, -0.005, -0.29))
	ModelKit.mi(_head, _facet_dome("mite_head", Vector3(0.095, 0.07, 0.1), 10, 4, 31, 0.008, -0.6, 0.15, 0.5), shell, Vector3(0, 0, -0.04))
	var eye_pos: Array[Vector3] = [Vector3(-0.032, 0.05, -0.115), Vector3(0.032, 0.05, -0.115), Vector3(-0.062, 0.035, -0.095), Vector3(0.062, 0.035, -0.095)]
	for k in eye_pos.size():
		ModelKit.mi(_head, ModelKit.sphere(0.013 if k < 2 else 0.009, 8, 5), dot_mat, eye_pos[k])
	for s in [-1.0, 1.0]:
		var mp := ModelKit.pivot(_head, "Mandible", Vector3(0.032 * s, -0.025, -0.12))
		var path := PackedVector3Array([Vector3.ZERO, Vector3(0.012 * s, -0.008, -0.04), Vector3(0.0, -0.018, -0.075), Vector3(-0.022 * s, -0.022, -0.1)])
		var radii := PackedFloat32Array([0.016, 0.014, 0.009, 0.0])
		var key := "mite_mand_%d" % int(s)
		var mm := ModelKit.cached_mesh(key)
		if mm == null:
			mm = ModelKit.cache_mesh(key, ModelKit.tube(path, radii, 6))
		ModelKit.mi(mp, mm, chitin)
		_mand.append(mp)
		# palp
		var pp := PackedVector3Array([Vector3(0.05 * s, -0.01, -0.09), Vector3(0.075 * s, -0.04, -0.13), Vector3(0.07 * s, -0.08, -0.16)])
		var pk := "mite_palp_%d" % int(s)
		var pm := ModelKit.cached_mesh(pk)
		if pm == null:
			pm = ModelKit.cache_mesh(pk, ModelKit.tube(pp, PackedFloat32Array([0.009, 0.007, 0.0]), 5))
		ModelKit.mi(_head, pm, chitin)

	# legs
	var femur_mesh := ModelKit.cached_mesh("mite_femur")
	if femur_mesh == null:
		femur_mesh = ModelKit.cache_mesh("mite_femur", ModelKit.tube(
			PackedVector3Array([Vector3(-0.02, 0, 0), Vector3(0.05, 0.014, 0), Vector3(0.17, 0.014, 0), Vector3(L1, 0, 0)]),
			PackedFloat32Array([0.026, 0.034, 0.028, 0.021]), 6))
	var tibia_mesh := ModelKit.cached_mesh("mite_tibia")
	if tibia_mesh == null:
		tibia_mesh = ModelKit.cache_mesh("mite_tibia", ModelKit.tube(
			PackedVector3Array([Vector3(0, 0, 0), Vector3(0.07, -0.006, 0), Vector3(0.2, -0.006, 0), Vector3(0.31, 0, 0), Vector3(L2, 0, 0)]),
			PackedFloat32Array([0.022, 0.025, 0.017, 0.008, 0.0]), 6))
	var spur_mesh := _crystal_mesh("mite_spur", 41, [
		[Vector3(0.15, 0.025, 0.0), Vector3(-0.2, 1, 0.15), 0.07, 0.012],
		[Vector3(0.21, 0.02, 0.0), Vector3(0.3, 1, -0.2), 0.05, 0.009]])
	var knee_mat := ModelKit.glow("mite_knee", Color(0.62, 0.3, 1.0), 2.5)
	for i in 6:
		var hip := ModelKit.pivot(_body, "Leg%d" % i, HIPS[i])
		var fem := ModelKit.pivot(hip, "Femur", Vector3.ZERO)
		ModelKit.mi(fem, femur_mesh, chitin)
		var spur := ModelKit.mi(fem, spur_mesh, crystal)
		spur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var knee := ModelKit.pivot(fem, "Knee", Vector3(L1, 0, 0))
		ModelKit.mi(knee, ModelKit.sphere(0.03, 10, 6), chitin)
		ModelKit.mi(knee, ModelKit.torus(0.026, 0.034, 12, 4), knee_mat, Vector3(0.012, 0, 0), Vector3(0, 0, 90))
		ModelKit.mi(knee, tibia_mesh, chitin)
		_hips.append(hip)
		_femurs.append(fem)
		_knees.append(knee)
		# hitboxes along both segments
		var cap_x := Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(L1 * 0.5, 0, 0))
		ModelKit.add_hitbox(fem, "legs", self, ModelKit.capsule_shape(0.05, L1 + 0.06), cap_x)
		var cap_t := Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(L2 * 0.5, 0, 0))
		ModelKit.add_hitbox(knee, "legs", self, ModelKit.capsule_shape(0.045, L2), cap_t)

	ModelKit.add_hitbox(_body, "body", self, ModelKit.box_shape(Vector3(0.44, 0.3, 0.7)), Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0.04)))
	ModelKit.add_hitbox(_head, "head", self, ModelKit.sphere_shape(0.1), Transform3D(Basis.IDENTITY, Vector3(0, 0.01, -0.06)))

	_legs_marker = ModelKit.pivot(self, "LegsMarker", Vector3(0, 0.3, 0))

	_light = OmniLight3D.new()
	_light.light_color = Color(0.62, 0.32, 1.0)
	_light.light_energy = 0.7
	_light.omni_range = 1.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, -0.14, 0.02)
	_body.add_child(_light)
	_process(0.0)


## Faceted (flat-shaded, jittered) half-ellipsoid shell for the crystal shader.
## Vertex colour R = glow factor (glow_lo at lip .. glow_hi at crown).
func _facet_dome(key: String, radii: Vector3, su: int, sv: int, seed_v: int, jitter: float, lip: float, glow_lo: float, glow_hi: float) -> Mesh:
	var cached := ModelKit.cached_mesh(key)
	if cached:
		return cached
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var rows: Array[PackedVector3Array] = []
	var hs := PackedFloat32Array()
	for iv in sv:
		var t := float(iv) / sv
		var phi := lerpf(lip, PI * 0.5, t * 0.92)
		var row := PackedVector3Array()
		for iu in su:
			var th := TAU * (float(iu) + 0.5 * (iv % 2)) / su
			var p := Vector3(cos(phi) * sin(th) * radii.x, sin(phi) * radii.y, -cos(phi) * cos(th) * radii.z)
			if iv > 0:
				p += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * jitter
			row.append(p)
		rows.append(row)
		hs.append(lerpf(glow_lo, glow_hi, t))
	var apex := Vector3(rng.randf_range(-1, 1) * jitter, radii.y, rng.randf_range(-1, 1) * jitter)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inside := Vector3(0, radii.y * 0.1, 0)
	for iv in sv - 1:
		var shifted_up := (iv + 1) % 2 == 1
		for iu in su:
			var j := (iu + 1) % su
			var a := rows[iv][iu]
			var b := rows[iv][j]
			if shifted_up:
				var c := rows[iv + 1][iu]
				var cprev := rows[iv + 1][(iu - 1 + su) % su]
				_ft(st, a, b, c, inside, hs[iv], hs[iv], hs[iv + 1])
				_ft(st, a, c, cprev, inside, hs[iv], hs[iv + 1], hs[iv + 1])
			else:
				var c := rows[iv + 1][iu]
				var d := rows[iv + 1][j]
				_ft(st, a, b, c, inside, hs[iv], hs[iv], hs[iv + 1])
				_ft(st, b, d, c, inside, hs[iv], hs[iv + 1], hs[iv + 1])
	var top := rows[sv - 1]
	for iu in su:
		_ft(st, top[iu], top[(iu + 1) % su], apex, inside, hs[sv - 1], hs[sv - 1], glow_hi)
	return ModelKit.cache_mesh(key, st.commit())


## Faceted triangle; normals are a blend of the flat facet normal and the smooth radial
## normal so facets read without hard white specular flashes.
func _ft(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, ha: float, hb: float, hc: float) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	if (c - a).cross(b - a).dot(n) < 0.0:
		var tv := b; b = c; c = tv
		var th := hb; hb = hc; hc = th
	st.set_color(Color(ha, 0, 0)); st.set_uv(Vector2(0, ha)); st.set_normal((n * 0.6 + (a - inside).normalized() * 0.4).normalized()); st.add_vertex(a)
	st.set_color(Color(hb, 0, 0)); st.set_uv(Vector2(1, hb)); st.set_normal((n * 0.6 + (b - inside).normalized() * 0.4).normalized()); st.add_vertex(b)
	st.set_color(Color(hc, 0, 0)); st.set_uv(Vector2(0.5, hc)); st.set_normal((n * 0.6 + (c - inside).normalized() * 0.4).normalized()); st.add_vertex(c)


## defs: [[base, dir, length, radius], ...]
func _crystal_mesh(key: String, seed_v: int, defs: Array) -> Mesh:
	var cached := ModelKit.cached_mesh(key)
	if cached:
		return cached
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for d: Array in defs:
		BloomKit.crystal_into(st, d[0], d[1], d[2], d[3], rng.randf() * TAU)
	return ModelKit.cache_mesh(key, st.commit())


# --------------------------------------------------------------------------
# Animation
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if _dead_t >= 0.0:
		_process_dead(delta)
		return
	if _dying:
		return
	_speed = ModelKit.damp(_speed, _target_speed, 5.0, delta)
	var freq := lerpf(1.2, 5.5, _speed)
	_phase = fposmod(_phase + delta * freq * clampf(_speed * 6.0, 0.15, 1.0), 1.0)
	var stride := 0.36 * _speed
	var lift_h := 0.045 + 0.06 * _speed
	var move_k := clampf(_speed * 5.0, 0.0, 1.0)

	var by := STAND_H + sin(_phase * TAU * 2.0) * 0.014 * _speed + sin(_time * 2.1) * 0.004
	var pitch := -0.07 * _speed + sin(_time * 1.7) * 0.012
	var roll := sin(_phase * TAU) * 0.05 * _speed
	var yaw := sin(_phase * TAU) * 0.05 * _speed + sin(_time * 0.6) * 0.03 * (1.0 - _speed)
	var bz := 0.0
	var front_lift := 0.0
	var front_fwd := 0.0
	var chit := pow(maxf(0.0, sin(_time * 0.9)), 6.0)
	var mand_open := 0.18 + chit * 0.22 * sin(_time * 34.0) + 0.1 * _speed

	if _atk_t >= 0.0:
		_atk_t += delta
		var t := _atk_t / ATK_DUR
		if t >= 1.0:
			_atk_t = -1.0
		else:
			var rear := ModelKit.env(t, 0.0, 0.3, 0.4, 0.62)
			var lunge := ModelKit.env(t, 0.33, 0.45, 0.55, 0.92)
			pitch += rear * 0.62 - lunge * 0.3
			by += rear * 0.1 + lunge * 0.08
			bz += rear * 0.06 - lunge * 0.45
			front_lift = rear * (1.0 - lunge)
			front_fwd = lunge
			var snap := ModelKit.ramp(t, 0.42, 0.47) * (1.0 - ModelKit.ramp(t, 0.7, 0.95))
			mand_open = lerpf(mand_open, 0.75, rear) * (1.0 - snap) - 0.12 * snap
			roll += sin(t * 40.0) * 0.03 * rear

	var out_k := 1.0
	if _emerge_t >= 0.0:
		_emerge_t += delta
		var e := _emerge_t / EMERGE_DUR
		if e >= 1.0:
			_emerge_t = -1.0
		else:
			out_k = ModelKit.ease_back(clampf(e * 1.15, 0.0, 1.0), 1.2)
			var under := 1.0 - out_k
			by -= under * 0.5
			pitch += under * 0.8
			roll += sin(_time * 38.0) * 0.06 * under
			front_lift = maxf(front_lift, sin(clampf(e * 1.6, 0.0, 1.0) * PI) * 0.8)

	# hit springs
	_hit_vel += (-_hit_off * 160.0 - _hit_vel * 13.0) * delta
	_hit_off += _hit_vel * delta
	_hit_rvel += (-_hit_rot * 170.0 - _hit_rvel * 12.0) * delta
	_hit_rot += _hit_rvel * delta
	_flinch = maxf(0.0, _flinch - delta * 3.5)

	_body.position = Vector3(_hit_off.x, by + _hit_off.y, bz + _hit_off.z)
	_body.rotation = Vector3(pitch + _hit_rot.x, yaw + _hit_rot.y, roll + _hit_rot.z)

	if _head_alive:
		_head.rotation = Vector3(sin(_time * 1.3) * 0.06 - front_lift * 0.2, sin(_time * 0.8 + 1.0) * 0.12 * (1.0 - _speed), sin(_time * 1.1) * 0.05)
		for k in _mand.size():
			var s := -1.0 if k == 0 else 1.0
			_mand[k].rotation = Vector3(0, -s * mand_open, 0)

	var e_pulse := 1.0 + 0.18 * sin(_time * 2.4) + 0.12 * _speed
	_belly_mat.emission_energy_multiplier = _belly_energy * e_pulse
	_light.light_energy = 0.7 * e_pulse * out_k

	var inv := _body.transform.affine_inverse()
	var mx := Vector3.ZERO
	var mc := 0
	for i in 6:
		if not _leg_alive[i]:
			continue
		var p := fposmod(_phase + GAIT_OFF[i], 1.0)
		var fx := 0.0
		var fy := 0.0
		if p < 0.45:
			var s := p / 0.45
			fx = lerpf(-0.5, 0.5, s * s * (3.0 - 2.0 * s))
			fy = sin(s * PI) * lift_h
		else:
			fx = lerpf(0.5, -0.5, (p - 0.45) / 0.55)
		var foot := FEET[i] + Vector3(0, fy * move_k, -fx * stride)
		var tw := maxf(0.0, sin(_time * (1.1 + i * 0.37) + i * 1.7) - 0.9) * 10.0 * (1.0 - move_k)
		foot += Vector3(0, tw * 0.05, -tw * 0.03)
		if i < 2:
			foot += Vector3(0, front_lift * 0.34, -front_lift * 0.06 - front_fwd * 0.42)
			foot.y += front_fwd * 0.04
		elif out_k < 1.0:
			foot.y -= (1.0 - out_k) * 0.45
		if _flinch > 0.0:
			foot = foot.lerp(Vector3(HIPS[i].x * 2.2, STAND_H * 0.5, HIPS[i].z * 1.5), _flinch * 0.35)
		_solve_leg(i, inv * foot)
		mx += _knees[i].global_position
		mc += 1
	if mc > 0:
		_legs_marker.global_position = mx / mc


func _solve_leg(i: int, target: Vector3) -> void:
	var v := target - HIPS[i]
	var yaw := atan2(-v.z, v.x)
	var dxz := sqrt(v.x * v.x + v.z * v.z)
	var h := v.y
	var dd := clampf(sqrt(dxz * dxz + h * h), 0.08, L1 + L2 - 0.002)
	var a := atan2(h, dxz)
	var alpha := acos(clampf((L1 * L1 + dd * dd - L2 * L2) / (2.0 * L1 * dd), -1.0, 1.0))
	var beta := acos(clampf((L1 * L1 + L2 * L2 - dd * dd) / (2.0 * L1 * L2), -1.0, 1.0))
	var e := a + alpha
	var k := -(PI - beta)
	if _curl > 0.0:
		var rest_yaw := atan2(-HIPS[i].z * 2.0, HIPS[i].x)
		var tw := sin(_dead_t * 23.0 + i * 2.3) * 0.35 * exp(-_dead_t * 0.9)
		yaw = lerp_angle(yaw, rest_yaw, _curl)
		e = lerpf(e, 1.05 + tw, _curl)
		k = lerpf(k, -2.55 + tw * 0.6, _curl)
	_hips[i].rotation = Vector3(0, yaw, 0)
	_femurs[i].rotation = Vector3(0, 0, e)
	_knees[i].rotation = Vector3(0, 0, k)


# --------------------------------------------------------------------------
# Death
# --------------------------------------------------------------------------

func _do_die(part: String, impulse: Vector3) -> void:
	if not is_inside_tree():
		return
	var world := ModelKit.world_of(self)
	if world and get_parent() != world:
		reparent(world, true)
	_dead_t = 0.0
	var local_imp := global_transform.basis.inverse() * impulse
	local_imp.y = 0.0
	var push_side := 1.0 if local_imp.x >= 0.0 else -1.0
	_body_y = _body.position.y
	_hop_v = 1.7 + clampf(impulse.length() * 0.08, 0.0, 1.2)
	_slide = local_imp.limit_length(4.0) * 0.35
	_slide_pos = Vector3(_body.position.x, 0, _body.position.z)
	_roll = _body.rotation.z
	_dead_pitch = _body.rotation.x
	_dead_yaw = _body.rotation.y
	_roll_target = -push_side * PI
	var c := _body.global_position
	var up := global_transform.basis.y
	var shard_n := 8
	var crack: Array[int] = []
	match part:
		"head":
			if _head_alive:
				_head_alive = false
				var hp := _head.global_position
				var dir := (impulse.normalized() if impulse.length_squared() > 0.01 else -global_transform.basis.z)
				ModelKit.make_debris(_head, world, dir * 2.5 + up * 3.0, _rand_v(12.0), 8.5, 0.5, 2.5)
				BloomKit.spawn_spore_puff(world, hp, 1.5)
				BloomKit.spawn_shards(world, hp, 5, dir * 1.5 + up * 1.5, 0.6)
			crack = [0]
			BloomKit.spawn_spore_puff(world, c, 0.9)
		"legs":
			var hit_side := -push_side
			var cut := 0
			for i in 6:
				if signf(HIPS[i].x) == hit_side and cut < 2:
					_leg_alive[i] = false
					var lp := _knees[i].global_position
					var out := global_transform.basis * Vector3(hit_side, 0, 0)
					ModelKit.make_debris(_hips[i], world, out * 2.5 + up * 2.5 + impulse * 0.2, _rand_v(14.0), 8.5, 0.25, 1.5)
					BloomKit.spawn_spore_puff(world, lp, 0.6)
					cut += 1
			_roll_target = -hit_side * 1.45
			_hop_v *= 0.6
			crack = [1]
			shard_n = 6
			BloomKit.spawn_spore_puff(world, c, 1.0)
		_:
			crack = [0, 1, 2]
			shard_n = 14
			BloomKit.spawn_spore_puff(world, c, 1.8)
	for ci in crack:
		var plate := _plates[ci]
		if plate == null or not is_instance_valid(plate) or plate.get_parent() != _body:
			continue
		var pc := plate.global_position
		var out_dir := (pc - c)
		out_dir.y = 0.0
		var v := out_dir.normalized() * 1.8 + up * (3.0 + _rng.randf() * 1.5) + impulse * 0.15
		ModelKit.make_debris(plate, world, v, _rand_v(9.0), 8.5, 0.7, 0.0)
	BloomKit.spawn_shards(world, c + up * 0.12, shard_n, impulse * 0.25 + up * 2.2, 0.85)
	BloomKit.attach_spore_trail(_body, Vector3(0, 0.02, 0.04), 4.0)


func _rand_v(m: float) -> Vector3:
	return Vector3(_rng.randf_range(-m, m), _rng.randf_range(-m, m), _rng.randf_range(-m, m))


func _process_dead(delta: float) -> void:
	_dead_t += delta
	_curl = minf(1.0, _dead_t * 2.2)
	# ballistic hop + bounce, then rest on its back
	_hop_v -= 9.8 * delta
	_body_y += _hop_v * delta
	if _body_y < DEAD_REST_H:
		_body_y = DEAD_REST_H
		_hop_v = -_hop_v * 0.3 if absf(_hop_v) > 0.8 else 0.0
	_slide_pos += _slide * delta
	_slide = _slide.lerp(Vector3.ZERO, 1.0 - exp(-3.0 * delta))
	# springy roll toward the flipped pose
	_roll_v += ((_roll_target - _roll) * 60.0 - _roll_v * 7.0) * delta
	_roll += _roll_v * delta
	_dead_pitch = ModelKit.damp(_dead_pitch, 0.12, 4.0, delta)
	var shrink := 1.0
	if _dead_t > 8.5:
		shrink = maxf(0.001, 1.0 - (_dead_t - 8.5) / 1.0)
	_body.position = Vector3(_slide_pos.x, _body_y - (1.0 - shrink) * 0.08, _slide_pos.z)
	_body.rotation = Vector3(_dead_pitch, _dead_yaw, _roll)
	_body.scale = Vector3.ONE * shrink
	_belly_energy = BELLY_E * exp(-_dead_t * 0.45)
	_belly_mat.emission_energy_multiplier = _belly_energy * (1.0 + 0.5 * sin(_dead_t * 17.0) * exp(-_dead_t))
	_light.light_energy = 0.7 * _belly_energy / BELLY_E
	if _head_alive:
		for k in _mand.size():
			var s := -1.0 if k == 0 else 1.0
			_mand[k].rotation = Vector3(0, -s * (0.5 + 0.3 * sin(_dead_t * 30.0) * exp(-_dead_t * 1.5)), 0)
	for i in 6:
		if _leg_alive[i]:
			_solve_leg(i, FEET[i])
	if _dead_t > 9.5 and not _done:
		_done = true
		finished.emit()
		queue_free()
