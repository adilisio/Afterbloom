class_name ThornbackModel
extends Node3D
## Boss: the Thornback - a huge Bloomed elk/bear quadruped (~2.6 m at the shoulder, ~4.2 m long).
## Heavy shaggy shoulders, head carried low, crystal antlers and a ridge of glowing crystal thorns
## along the spine (the weak point). Built and animated procedurally. Origin at feet, facing -Z.
##
## API: set_locomotion(speed 0..1), play_attack() -> float, play_roar() -> float,
## play_charge_windup() -> float, play_hit(part, from_dir), play_emerge() -> float,
## die(part, impulse), get_part_node(part), get_parts(). Emits `finished` after death.

signal finished

const BODY_Y := 1.62
const NECK_REST := -0.32
const HEAD_REST := -0.05
const LYING_Y := 0.86
const PARTS: Array[String] = ["head", "body", "legs", "thorns"]

## Body cross sections along Z (front = -Z): [z, centre y, half width, top half height, bottom half height]
const SECTIONS := [
	[-1.72, 0.02, 0.10, 0.12, 0.12],
	[-1.58, 0.06, 0.40, 0.50, 0.42],
	[-1.25, 0.18, 0.68, 0.86, 0.64],
	[-0.85, 0.24, 0.76, 0.95, 0.64],
	[-0.30, 0.12, 0.68, 0.70, 0.62],
	[0.30, 0.02, 0.60, 0.58, 0.56],
	[0.80, 0.0, 0.56, 0.52, 0.5],
	[1.20, 0.00, 0.54, 0.52, 0.48],
	[1.52, -0.06, 0.38, 0.40, 0.36],
	[1.70, -0.10, 0.10, 0.12, 0.10],
]

## Head cross sections (head pivot space, snout toward -Z).
const HEAD_SECTIONS := [
	[0.18, 0.02, 0.08, 0.08, 0.08],
	[0.08, 0.04, 0.27, 0.29, 0.27],
	[-0.14, 0.07, 0.33, 0.32, 0.28],
	[-0.36, 0.04, 0.27, 0.27, 0.24],
	[-0.58, -0.02, 0.2, 0.21, 0.19],
	[-0.8, -0.07, 0.17, 0.18, 0.15],
	[-0.93, -0.09, 0.13, 0.13, 0.11],
	[-0.99, -0.1, 0.05, 0.05, 0.05],
]

const HIP_POS: Array[Vector3] = [Vector3(-0.47, -0.12, -1.0), Vector3(0.47, -0.12, -1.0), Vector3(-0.44, -0.1, 0.95), Vector3(0.44, -0.1, 0.95)]
const WALK_OFF: Array[float] = [0.25, 0.75, 0.0, 0.5]
const RUN_OFF: Array[float] = [0.0, 0.12, 0.62, 0.5]
const LIMP_H: Array[float] = [0.45, 0.25, -0.35, -0.1]

enum Act { NONE, ATTACK, ROAR, WINDUP, EMERGE }

var _body: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _tail: Node3D
var _antler_l: Node3D
var _antler_r: Node3D
var _thorn_root: Node3D
var _thorns: Array[MeshInstance3D] = []
var _thorn_tips: Array[Vector3] = []
var _hip: Array[Node3D] = []
var _knee: Array[Node3D] = []
var _foot: Array[Node3D] = []
var _mouth_marker: Node3D
var _nose_marker: Node3D
var _thorn_marker: Node3D
var _body_marker: Node3D
var _light: OmniLight3D
var _thorn_mat: ShaderMaterial
var _eye_mat: StandardMaterial3D
var _mouth_mat: StandardMaterial3D

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _speed := 0.0
var _speed_target := 0.0
var _phase := 0.0

var _act: Act = Act.NONE
var _act_t := 0.0
var _act_dur := 0.0
var _ev := 0

# hit springs (value, velocity)
var _h_pitch := Vector2.ZERO
var _h_roll := Vector2.ZERO
var _h_head := Vector2.ZERO
var _h_hyaw := Vector2.ZERO
var _h_drop := Vector2.ZERO
var _thorn_flash := 0.0

# death
var _dying := false
var _dead_t := 0.0
var _death_part := "body"
var _side := 1.0
var _impulse := Vector3.ZERO
var _impacted := false
var _erupted := false
var _early_erupted := false
var _finished := false

# pose (written every frame, no allocation)
var _p_by := 0.0
var _p_bz := 0.0
var _p_bp := 0.0
var _p_byaw := 0.0
var _p_br := 0.0
var _p_np := 0.0
var _p_ny := 0.0
var _p_hp := 0.0
var _p_hy := 0.0
var _p_hr := 0.0
var _p_jaw := 0.0
var _p_glow := 1.6
var _p_tail := 0.0
var _flat := 1.0
var _p_hip := PackedFloat32Array([0, 0, 0, 0])
var _p_knee := PackedFloat32Array([0, 0, 0, 0])
var _p_foot := PackedFloat32Array([0, 0, 0, 0])
var _p_splay := PackedFloat32Array([0, 0, 0, 0])
var _hip_rest := PackedFloat32Array([0.0, 0.0, 0.18, 0.18])
var _knee_rest := PackedFloat32Array([0.0, 0.0, -0.4, -0.4])


func _ready() -> void:
	_rng.randomize()
	_noise.seed = _rng.randi()
	_noise.frequency = 1.0
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_build()
	_apply()


# ==========================================================================
# Public API
# ==========================================================================

func set_locomotion(speed: float) -> void:
	_speed_target = clampf(speed, 0.0, 1.0)


func play_attack() -> float:
	return _start(Act.ATTACK, 1.7)


func play_roar() -> float:
	return _start(Act.ROAR, 2.4)


func play_charge_windup() -> float:
	return _start(Act.WINDUP, 1.5)


func play_emerge() -> float:
	var d := _start(Act.EMERGE, 3.0)
	_apply_pose_now()
	return d


## from_dir: travel direction of the incoming hit (shooter -> target). The body is pushed along it.
func play_hit(part: String, from_dir: Vector3) -> void:
	if _dying:
		return
	var push := from_dir.normalized() if from_dir.length_squared() > 1e-6 else -global_basis.z
	var lp := global_basis.inverse() * push
	var k := 1.0
	match part:
		"head":
			_h_head.y += 4.5
			_h_hyaw.y += lp.x * 3.0
			k = 0.5
		"legs":
			_h_drop.y -= 1.6
			k = 0.7
		"thorns":
			_thorn_flash = 1.0
			_h_head.y += 2.0
			k = 1.2
	_h_pitch.y += lp.z * 0.9 * k
	_h_roll.y += -lp.x * 1.1 * k
	var n := get_part_node(part)
	var w := ModelKit.world_of(self)
	if n and w:
		BloomKit.spawn_spore_puff(w, n.global_position, 0.9)


func die(part: String, impulse: Vector3) -> void:
	if _dying:
		return
	_dying = true
	_death_part = part
	_impulse = impulse
	var lp := global_basis.inverse() * impulse
	_side = signf(lp.x) if absf(lp.x) > 0.05 else (1.0 if _rng.randf() < 0.5 else -1.0)
	ModelKit.strip_hitboxes(self)
	_do_die.call_deferred(part, impulse)


func get_part_node(part: String) -> Node3D:
	match part:
		"head":
			return _head
		"legs":
			return _knee[0] if _knee.size() > 0 else null
		"thorns":
			return _thorn_marker
		_:
			return _body_marker


func get_parts() -> PackedStringArray:
	return PackedStringArray(PARTS)


# ==========================================================================
# Animation
# ==========================================================================

func _start(a: Act, dur: float) -> float:
	if _dying:
		return 0.0
	_act = a
	_act_t = 0.0
	_act_dur = dur
	_ev = 0
	return dur


func _n(x: float, off: float) -> float:
	return _noise.get_noise_1d(x + off * 137.0)


func _reset_pose() -> void:
	_p_by = 0.0; _p_bz = 0.0; _p_bp = 0.0; _p_byaw = 0.0; _p_br = 0.0
	_p_np = 0.0; _p_ny = 0.0; _p_hp = 0.0; _p_hy = 0.0; _p_hr = 0.0
	_p_jaw = 0.0; _p_tail = 0.0; _flat = 1.0
	for i in 4:
		_p_hip[i] = 0.0; _p_knee[i] = 0.0; _p_foot[i] = 0.0; _p_splay[i] = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _dying:
		_process_death(delta)
		_apply()
		return
	_reset_pose()
	_speed = ModelKit.damp(_speed, _speed_target, 2.5, delta)
	var s := _speed
	var run := smoothstep(0.45, 0.9, s)
	var freq := lerpf(0.5, 1.25, s)
	if s > 0.005:
		_phase = fmod(_phase + delta * freq, 1.0)
	var amp := minf(1.0, s * 5.0)

	# idle life: breathing, head sway, weight shifts
	var breath := sin(_t * 1.3)
	_p_by += breath * 0.018
	_p_bp += breath * 0.008
	_p_np += _n(_t * 0.18, 1.0) * 0.18 + breath * 0.02
	_p_ny += _n(_t * 0.12, 2.0) * 0.35 * (1.0 - run * 0.7)
	_p_hp += _n(_t * 0.25, 3.0) * 0.12
	_p_hy += _n(_t * 0.2, 4.0) * 0.2
	_p_hr += _n(_t * 0.3, 5.0) * 0.08
	_p_jaw += maxf(0.0, _n(_t * 0.4, 6.0)) * 0.12
	_p_tail += _n(_t * 0.7, 7.0) * 0.5
	_p_br += _n(_t * 0.1, 8.0) * 0.02
	_p_glow = 1.5 + 0.35 * (0.5 + 0.5 * sin(_t * 1.3 + 0.8))

	# gait
	var duty := lerpf(0.66, 0.42, run)
	var a_hip := lerpf(0.30, 0.58, run) * amp
	for i in 4:
		var front := i < 2
		var p := fmod(_phase + lerpf(WALK_OFF[i], RUN_OFF[i], run), 1.0)
		var hip := 0.0
		var lift := 0.0
		if p < duty:
			hip = lerpf(a_hip, -a_hip, p / duty)
		else:
			var u := (p - duty) / (1.0 - duty)
			hip = lerpf(-a_hip, a_hip, smoothstep(0.0, 1.0, u))
			lift = sin(u * PI) * amp
		_p_hip[i] += hip
		if front:
			_p_knee[i] += -lift * lerpf(0.9, 1.4, run)
			_p_foot[i] += lift * 0.7
		else:
			_p_hip[i] += lift * 0.15
			_p_knee[i] += -lift * lerpf(0.45, 0.8, run)
			_p_foot[i] += lift * 0.6
	var ph := _phase * TAU
	_p_by += (cos(ph * 2.0) * lerpf(0.035, 0.07, run) - run * 0.06) * amp
	_p_bp += (sin(ph) * 0.07 * run - 0.05 * run) * amp
	_p_br += sin(ph) * 0.035 * (1.0 - run) * amp
	_p_byaw += sin(ph) * 0.03 * amp
	_p_np += (-sin(ph * 2.0) * 0.05 - 0.12 * run) * amp
	_p_hp += sin(ph * 2.0 + 0.6) * 0.05 * amp
	_p_tail += sin(ph * 2.0) * 0.3 * amp

	# actions
	if _act != Act.NONE:
		_act_t += delta
		match _act:
			Act.ATTACK:
				_pose_attack(_act_t)
			Act.ROAR:
				_pose_roar(_act_t)
			Act.WINDUP:
				_pose_windup(_act_t)
			Act.EMERGE:
				_pose_emerge(_act_t)
		if _act_t >= _act_dur:
			_act = Act.NONE

	# hit springs
	_h_pitch = _spring(_h_pitch, 40.0, 7.0, delta)
	_h_roll = _spring(_h_roll, 40.0, 7.0, delta)
	_h_head = _spring(_h_head, 60.0, 8.0, delta)
	_h_hyaw = _spring(_h_hyaw, 60.0, 8.0, delta)
	_h_drop = _spring(_h_drop, 45.0, 7.0, delta)
	_p_bp += _h_pitch.x * 0.12
	_p_br += _h_roll.x * 0.12
	_p_hp += _h_head.x * 0.1
	_p_np += _h_head.x * 0.05
	_p_hy += _h_hyaw.x * 0.1
	_p_by += _h_drop.x * 0.1
	_p_knee[0] += minf(_h_drop.x, 0.0) * 0.4
	_p_knee[1] += minf(_h_drop.x, 0.0) * 0.4
	_thorn_flash = maxf(0.0, _thorn_flash - delta * 2.5)
	_p_glow += _thorn_flash * 3.0
	_apply()


func _spring(v: Vector2, k: float, c: float, dt: float) -> Vector2:
	v.y += (-k * v.x - c * v.y) * dt
	v.x += v.y * dt
	return v


func _once(bit: int) -> bool:
	if _ev & bit:
		return false
	_ev |= bit
	return true


func _pose_attack(t: float) -> void:
	# rear up (0..0.55), slam (0.55..0.75, impact at 0.75 = 44%), recover
	var rear := smoothstep(0.0, 0.55, t) * (1.0 - smoothstep(0.55, 0.75, t))
	var slam := smoothstep(0.55, 0.75, t) * (1.0 - smoothstep(0.95, 1.65, t))
	var pitch := rear * 0.55 - slam * 0.1
	_p_bp += pitch
	_p_by += sin(maxf(pitch, 0.0)) * 0.9 + rear * 0.05 - slam * 0.1
	_p_bz += rear * 0.2
	_p_hip[0] += rear * 0.75 + slam * 0.3
	_p_hip[1] += rear * 0.95 + slam * 0.3
	_p_knee[0] += -rear * 1.4
	_p_knee[1] += -rear * 1.1
	_p_hip[2] += -pitch + rear * 0.15
	_p_hip[3] += -pitch + rear * 0.15
	_p_knee[2] += -rear * 0.2
	_p_knee[3] += -rear * 0.2
	_p_np += rear * 0.45 - slam * 0.45
	_p_hp += rear * 0.25 - slam * 0.25
	_p_jaw += rear * 0.4 + slam * 0.55
	_p_glow += rear * 1.2 + slam * 1.5
	_p_tail += rear * 0.6
	if t >= 0.75 and _once(1):
		var w := ModelKit.world_of(self)
		if w:
			for i in 2:
				var fp := _foot[i].global_position
				fp.y = global_position.y + 0.05
				BloomKit.spawn_spore_puff(w, fp, 1.6)
			var mid := (_foot[0].global_position + _foot[1].global_position) * 0.5
			mid.y = global_position.y + 0.1
			BloomKit.spawn_shards(w, mid, 5, Vector3.UP * 3.5, 0.9)


func _pose_roar(t: float) -> void:
	var a := ModelKit.env(t, 0.0, 0.5, 1.9, 2.4)
	var j := ModelKit.env(t, 0.35, 0.6, 1.8, 2.2)
	var shake := _n(t * 9.0, 11.0) * a
	_p_np += 0.6 * a
	_p_hp += 0.5 * a + shake * 0.08
	_p_hy += sin(t * 23.0) * 0.035 * j
	_p_jaw += 0.6 * j
	_p_bp += 0.1 * a
	_p_bz += 0.15 * a
	_p_by += 0.06 * a
	_p_hip[0] += -0.12 * a
	_p_hip[1] += -0.12 * a
	_p_br += shake * 0.02
	_p_glow += 1.8 * a + absf(shake) * 1.5
	_p_tail += 0.8 * a
	if t >= 0.55 and _once(1):
		BloomKit.attach_spore_trail(_head, _mouth_marker.position, 1.3)


func _pose_windup(t: float) -> void:
	var lo := ModelKit.env(t, 0.0, 0.35, 1.3, 1.5)
	_p_np += -0.12 * lo
	_p_hp += -0.5 * lo
	_p_bp += -0.06 * lo
	_p_bz += 0.25 * lo
	_p_by += -0.14 * lo
	_p_hip[2] += 0.15 * lo
	_p_hip[3] += 0.15 * lo
	_p_knee[2] += -0.25 * lo
	_p_knee[3] += -0.25 * lo
	var e2 := ModelKit.env(t, 0.25, 0.35, 1.05, 1.2)
	var sc := sin((t - 0.3) / 0.42 * TAU)
	_p_hip[1] += (0.35 * sc - 0.05) * e2
	_p_knee[1] += -0.7 * maxf(0.0, sc) * e2
	_p_foot[1] += 0.4 * maxf(0.0, -sc) * e2
	var build := smoothstep(0.2, 1.4, t)
	_p_glow += 2.2 * build
	_p_br += _n(t * 14.0, 12.0) * 0.025 * smoothstep(0.9, 1.4, t)
	_p_hy += _n(t * 12.0, 13.0) * 0.08 * smoothstep(0.9, 1.4, t)
	_p_jaw += 0.2 * lo
	if t >= 0.45 and _once(1):
		_snort()
	if t >= 0.95 and _once(2):
		_snort()


func _snort() -> void:
	var w := ModelKit.world_of(self)
	if w:
		BloomKit.spawn_spore_puff(w, _nose_marker.global_position, 0.45)


func _pose_emerge(t: float) -> void:
	var u := smoothstep(0.0, 2.7, t)
	var down := 1.0 - u
	_p_by += -3.3 * down * down * (1.0 + 0.15 * sin(t * 3.0))
	_p_bp += 0.55 * ModelKit.env(t, 0.0, 0.4, 1.8, 2.9)
	_p_br += _n(t * 3.0, 14.0) * 0.12 * down
	for i in 2:
		_p_hip[i] += (0.6 * sin(t * 5.5 + i * PI) + 0.4) * (1.0 - smoothstep(1.6, 2.6, t))
		_p_knee[i] += -0.7 * maxf(0.0, sin(t * 5.5 + i * PI)) * (1.0 - smoothstep(1.6, 2.6, t))
	_p_np += 0.35 * down + _n(t * 6.0, 15.0) * 0.1 * down
	_p_hp += 0.3 * down
	_p_jaw += 0.5 * ModelKit.env(t, 0.5, 1.0, 2.0, 2.6)
	_p_glow += 1.5 * down
	var w := ModelKit.world_of(self)
	if w == null:
		return
	var fwd := -global_basis.z
	if t >= 0.0 and _once(1):
		BloomKit.spawn_shards(w, global_position + fwd * 1.0 + Vector3.UP * 0.2, 14, Vector3.UP * 4.5, 1.6)
		BloomKit.spawn_spore_puff(w, global_position + Vector3.UP * 0.4, 3.0)
	if t >= 1.1 and _once(2):
		BloomKit.spawn_shards(w, global_position - fwd * 0.8 + Vector3.UP * 0.2, 8, Vector3.UP * 3.0, 1.3)
		BloomKit.spawn_spore_puff(w, global_position + fwd * 1.5 + Vector3.UP * 0.3, 2.0)


func _apply_pose_now() -> void:
	_reset_pose()
	_pose_emerge(0.0001)
	_ev = 0
	_apply()


# ==========================================================================
# Death
# ==========================================================================

func _do_die(part: String, impulse: Vector3) -> void:
	var w := ModelKit.world_of(self)
	if w and get_parent() != w:
		reparent(w, true)
	_act = Act.NONE
	if w == null:
		return
	match part:
		"head":
			BloomKit.spawn_spore_puff(w, _head.global_position, 2.4)
			BloomKit.attach_spore_trail(_head, Vector3(0, 0.1, -0.3), 7.0)
			var up := Vector3.UP * 4.0 + impulse.limit_length(6.0) * 0.6
			if is_instance_valid(_antler_l):
				ModelKit.make_debris(_antler_l, w, up - global_basis.x * 2.0, Vector3(_rng.randf_range(-6, 6), 4, 6), 9.0, 25.0, 2.0)
			if is_instance_valid(_antler_r):
				ModelKit.make_debris(_antler_r, w, up + global_basis.x * 2.0, Vector3(_rng.randf_range(-6, 6), -4, -6), 9.0, 25.0, 2.0)
			BloomKit.spawn_shards(w, _head.global_position + Vector3.UP * 0.3, 8, Vector3.UP * 3.0, 1.2)
		"legs":
			var k := _knee[0] if _side < 0.0 else _knee[1]
			BloomKit.spawn_spore_puff(w, k.global_position, 1.6)
			BloomKit.spawn_shards(w, k.global_position, 6, impulse.limit_length(4.0), 1.0)
		"thorns":
			_thorn_flash = 1.0
		_:
			BloomKit.spawn_spore_puff(w, _body_marker.global_position, 2.0)
			BloomKit.spawn_shards(w, _body_marker.global_position, 8, impulse.limit_length(5.0), 1.2)


func _stagger_end() -> float:
	match _death_part:
		"legs":
			return 0.7
		"head":
			return 1.1
	return 1.4


func _process_death(delta: float) -> void:
	_dead_t += delta
	var d := _dead_t
	_reset_pose()
	var se := _stagger_end()
	var ce := se + 1.9
	var st := smoothstep(0.0, se, d)
	var settle := 1.0 - smoothstep(se, ce, d)
	# stagger: wobbling, stumbling steps, head swinging low
	var wob := sin(d * 4.2) * 0.07 * settle
	_p_br += _side * (0.16 * st) + wob
	_p_by += -0.12 * st
	_p_np += -0.25 * st + sin(d * 3.1) * 0.1 * settle
	_p_hy += sin(d * 2.3) * 0.3 * settle
	_p_jaw += 0.35 * st
	for i in 4:
		_p_hip[i] += sin(d * 5.0 + i * 1.7) * 0.22 * settle
		_p_knee[i] += -maxf(0.0, sin(d * 5.0 + i * 1.7)) * 0.4 * settle
	if _death_part == "legs":
		var li := 0 if _side < 0.0 else 1
		_p_knee[li] += -1.2 * st
		_p_hip[li] += 0.4 * st
		_p_bp += -0.12 * st
	if _death_part == "head":
		_p_hp += 0.5 * (1.0 - smoothstep(0.0, 0.8, d)) * smoothstep(0.0, 0.1, d)
	# collapse onto its side (heavy ease-in, then a settle bounce)
	var cr := clampf((d - se) / (ce - se), 0.0, 1.0)
	var c := cr * cr * cr * (cr * (cr * 6.0 - 15.0) + 10.0)
	c = lerpf(cr * cr, c, 0.5)
	var after := maxf(0.0, d - ce)
	var bounce := sin(after * 11.0) * exp(-after * 4.5) * 0.06 if d > ce else 0.0
	_p_br = lerpf(_p_br, _side * 1.38, c) + bounce * _side * 0.5
	_p_by = lerpf(_p_by, LYING_Y - BODY_Y, c) + absf(bounce) * 0.6
	_p_bp = lerpf(_p_bp, -0.05, c)
	_p_np = lerpf(_p_np, -0.15, c)
	_p_hp = lerpf(_p_hp, 0.2, c)
	_p_hr = lerpf(_p_hr, -_side * 0.5, c)
	_p_hy = lerpf(_p_hy, _side * 0.25, c)
	_flat = 1.0 - c
	for i in 4:
		_p_hip[i] = lerpf(_p_hip[i], LIMP_H[i], c)
		_p_knee[i] = lerpf(_p_knee[i], -0.5 - 0.15 * i, c)
		_p_splay[i] = lerpf(0.0, -_side * (0.25 if (HIP_POS[i].x * _side) > 0.0 else -0.1), c)
	# twitches after the fall
	if d > ce + 1.0 and d < ce + 4.0:
		var tw := maxf(0.0, _n(d * 3.0, 20.0) - 0.15) * 1.5
		_p_hip[1] += tw * 0.3
		_p_knee[3] += -tw * 0.4
		_p_hp += tw * 0.15
	# glow
	var erupt_t := ce + 0.25
	if _death_part == "thorns" and d > 0.25 and not _early_erupted:
		_early_erupted = true
		_erupt(false)
	if d >= ce and not _impacted:
		_impacted = true
		var w := ModelKit.world_of(self)
		if w:
			var side_dir := global_basis.x * -_side
			for k in 3:
				var p := global_position + global_basis.z * (-1.2 + k * 1.2) + side_dir * 0.7
				p.y = global_position.y + 0.15
				BloomKit.spawn_spore_puff(w, p, 1.6)
	if d >= erupt_t and not _erupted:
		_erupted = true
		_erupt(true)
	var g := 1.6 + st * 0.8
	if _erupted:
		var f := clampf((d - erupt_t) / 5.0, 0.0, 1.0)
		g = lerpf(4.5, 0.12, sqrt(f))
	_p_glow = g + _thorn_flash * 3.0
	_thorn_flash = maxf(0.0, _thorn_flash - delta * 1.5)
	_p_jaw = lerpf(_p_jaw, 0.45, c)
	_eye_mat.emission_energy_multiplier = lerpf(5.0, 0.0, smoothstep(ce, ce + 3.0, d))
	# sink & shrink away, then finish
	var sink := smoothstep(9.5, 11.5, d)
	if sink > 0.0:
		_p_by -= sink * 1.1
		scale = Vector3.ONE * maxf(0.001, 1.0 - sink * 0.6)
	if d >= 11.5 and not _finished:
		_finished = true
		finished.emit()
		queue_free()


func _erupt(big: bool) -> void:
	var w := ModelKit.world_of(self)
	if w == null:
		return
	var up := global_basis.y.lerp(Vector3.UP, 0.6).normalized()
	var detach_every := 3 if big else 4
	for i in _thorns.size():
		var th := _thorns[i]
		if not is_instance_valid(th) or th.get_parent() != _thorn_root:
			continue
		var tip := th.to_global(_thorn_tips[i] * 0.6)
		if i % 2 == 0:
			BloomKit.spawn_shards(w, tip, 6 if big else 4, up * 4.5, 1.5 if big else 1.1)
		if i % detach_every == 1:
			var v := up * _rng.randf_range(4.0, 7.0) + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
			ModelKit.make_debris(th, w, v, Vector3(_rng.randf_range(-5, 5), _rng.randf_range(-5, 5), _rng.randf_range(-5, 5)), 9.0, 8.0, 3.0)
	for k in 3:
		var p := _body.to_global(Vector3(0, 1.0, -1.0 + k * 0.9))
		BloomKit.spawn_spore_puff(w, p, 3.2 if big else 1.8)
	if big:
		var tw := create_tween()
		tw.tween_property(_light, "light_energy", 9.0, 0.08)
		tw.tween_property(_light, "omni_range", 7.0, 0.1)
		tw.tween_property(_light, "light_energy", 0.0, 4.0).set_ease(Tween.EASE_OUT)


# ==========================================================================
# Pose application
# ==========================================================================

func _apply() -> void:
	_body.position = Vector3(0.0, BODY_Y + _p_by, _p_bz)
	_body.rotation = Vector3(_p_bp, _p_byaw, _p_br)
	_neck.rotation = Vector3(NECK_REST + _p_np, _p_ny, 0.0)
	_head.rotation = Vector3(HEAD_REST + _p_hp, _p_hy, _p_hr)
	_jaw.rotation.x = -0.05 - _p_jaw
	for i in 4:
		var h := _hip_rest[i] + _p_hip[i]
		var k := _knee_rest[i] + _p_knee[i]
		_hip[i].rotation = Vector3(h, 0.0, _p_splay[i])
		_knee[i].rotation.x = k
		_foot[i].rotation.x = (-(h + k) - _p_bp) * _flat + _p_foot[i]
	_tail.rotation = Vector3(-0.6 + _p_tail * 0.3, _p_tail * 0.4, 0.0)
	_thorn_mat.set_shader_parameter(&"glow", _p_glow)
	if not _erupted:
		_light.light_energy = 0.6 + _p_glow * 0.5
	_mouth_mat.emission_energy_multiplier = 0.6 + _p_jaw * 7.0


# ==========================================================================
# Construction
# ==========================================================================

func _hide_mat() -> StandardMaterial3D:
	if ModelKit.has_mat("tb_hide"):
		return ModelKit.get_mat("tb_hide")
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.33, 0.27, 0.23)
	var dif := ModelKit.load_tex("res://assets/textures/curly_teddy_natural/curly_teddy_natural_diff.jpg")
	if dif:
		m.albedo_texture = dif
	var nrm := ModelKit.load_tex("res://assets/textures/curly_teddy_natural/curly_teddy_natural_nor_gl.jpg")
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 1.4
	var rough := ModelKit.load_tex("res://assets/textures/curly_teddy_natural/curly_teddy_natural_rough.jpg")
	if rough:
		m.roughness_texture = rough
	m.roughness = 1.0
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.4, 1.4, 1.4)
	m.uv1_triplanar_sharpness = 2.0
	# pale lichen-like growth patches
	m.detail_enabled = true
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.detail_mask = ModelKit.noise_tex("tb_lichen_mask", 0.012, ModelKit.grad([Color(0, 0, 0), Color(0, 0, 0), Color(0.6, 0.6, 0.6)], [0.0, 0.7, 0.85]), false, 4.0, 256, 5, 77)
	m.detail_albedo = ModelKit.noise_tex("tb_lichen_alb", 0.09, ModelKit.grad([Color(0.42, 0.45, 0.38), Color(0.66, 0.68, 0.60), Color(0.62, 0.56, 0.70)], [0.0, 0.6, 1.0]), false, 4.0, 256, 4, 78)
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	ModelKit.put_mat("tb_hide", m)
	return m


func _shag_mat() -> StandardMaterial3D:
	if ModelKit.has_mat("tb_shag"):
		return ModelKit.get_mat("tb_shag")
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.23, 0.2)
	var dif := ModelKit.load_tex("res://assets/textures/curly_teddy_natural/curly_teddy_natural_diff.jpg")
	if dif:
		m.albedo_texture = dif
	var nrm := ModelKit.load_tex("res://assets/textures/curly_teddy_natural/curly_teddy_natural_nor_gl.jpg")
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2.5, 2.5, 2.5)
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	ModelKit.put_mat("tb_shag", m)
	return m


func _build() -> void:
	var hide := _hide_mat()
	var shag := _shag_mat()
	var dark := ModelKit.pbr("tb_dark", Color(0.07, 0.06, 0.06), 0.0, 0.5)
	var pale := ModelKit.pbr("tb_lichen", Color(0.78, 0.80, 0.72), 0.0, 0.85)
	var crystal := BloomKit.crystal_material(1.0)
	_thorn_mat = (BloomKit.crystal_material(1.0) as ShaderMaterial).duplicate() as ShaderMaterial
	_eye_mat = ModelKit.glow("tb_eye", Color(0.78, 0.5, 1.0), 5.0, true)
	_mouth_mat = ModelKit.glow("tb_mouth", Color(0.62, 0.3, 1.0), 1.0, true)

	_body = ModelKit.pivot(self, "Body", Vector3(0, BODY_Y, 0))
	_body_marker = ModelKit.pivot(_body, "BodyCenter", Vector3(0, 0.1, -0.1))
	ModelKit.mi(_body, _loft(SECTIONS, 28, 4, 0.82), hide, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, "Torso")
	ModelKit.mi(_body, _body_fringe(), shag, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, "Shag")
	_build_growths(pale)

	# tail
	_tail = ModelKit.pivot(_body, "Tail", Vector3(0, 0.12, 1.62))
	var tst := SurfaceTool.new()
	tst.begin(Mesh.PRIMITIVE_TRIANGLES)
	ModelKit.tube_into(tst, PackedVector3Array([Vector3(0, 0, -0.1), Vector3(0, 0, 0.18), Vector3(0, 0, 0.42)]), PackedFloat32Array([0.11, 0.09, 0.0]), 8, false)
	for k in 6:
		var a := TAU * k / 6.0
		var b := Vector3(cos(a) * 0.07, sin(a) * 0.07, 0.15 + k * 0.03)
		_tuft(tst, b, Vector3(cos(a) * 0.3, -0.4 + sin(a) * 0.3, 1.0), 0.28, 0.04)
	ModelKit.mi(_tail, tst.commit(), hide)

	# thorn ridge (weak point)
	_thorn_root = ModelKit.pivot(_body, "Thorns")
	_thorn_marker = ModelKit.pivot(_thorn_root, "ThornCenter", Vector3(0, 1.35, -0.6))
	var zs: Array[float] = [-1.3, -1.06, -0.82, -0.58, -0.34, -0.1, 0.14, 0.38, 0.62, 0.86, 1.1, 1.32]
	for i in zs.size():
		var z := zs[i]
		var h := 0.28 + 0.82 * exp(-pow(z + 0.75, 2.0) / 0.55)
		var sec := _sec_at(z)
		var base := Vector3(_rng.randf_range(-0.03, 0.03), sec[1] + sec[3] - 0.06, z)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var dir := Vector3(_rng.randf_range(-0.12, 0.12), 1.0, 0.5).normalized()
		BloomKit.crystal_into(st, Vector3.ZERO, dir, h, h * 0.11 + 0.035, _rng.randf() * TAU)
		for sgn in [-1.0, 1.0]:
			var sd := Vector3(0.55 * sgn, 1.0, 0.3).normalized()
			BloomKit.crystal_into(st, Vector3(0.07 * sgn, -0.02, 0.05), sd, h * _rng.randf_range(0.35, 0.55), h * 0.07 + 0.02, _rng.randf() * TAU)
		var th := ModelKit.mi(_thorn_root, st.commit(), _thorn_mat, base, Vector3.ZERO, Vector3.ONE, "Thorn%d" % i)
		_thorns.append(th)
		_thorn_tips.append(dir * h)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.66, 0.36, 1.0)
	_light.light_energy = 1.4
	_light.omni_range = 3.6
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.75, -0.4)
	_thorn_root.add_child(_light)

	# neck + head
	_neck = ModelKit.pivot(_body, "Neck", Vector3(0, 0.26, -1.28))
	var nst := SurfaceTool.new()
	nst.begin(Mesh.PRIMITIVE_TRIANGLES)
	ModelKit.tube_into(nst, PackedVector3Array([Vector3(0, 0.06, 0.4), Vector3(0, 0.03, 0.0), Vector3(0, -0.02, -0.45), Vector3(0, 0.0, -0.9), Vector3(0, 0.02, -1.08)]),
		PackedFloat32Array([0.55, 0.52, 0.43, 0.31, 0.2]), 18, false)
	ModelKit.mi(_neck, nst.commit(), hide)
	ModelKit.mi(_neck, _neck_mane(), shag)
	_head = ModelKit.pivot(_neck, "Head", Vector3(0, 0, -0.92))
	_build_head(hide, dark, crystal)

	# legs
	for i in 4:
		_build_leg(i, hide, dark, crystal)

	# hitboxes
	ModelKit.add_hitbox(_body, "body", self, ModelKit.box_shape(Vector3(1.4, 1.45, 3.1)), Transform3D(Basis(), Vector3(0, 0.05, 0.0)))
	ModelKit.add_hitbox(_thorn_root, "thorns", self, ModelKit.box_shape(Vector3(0.6, 0.95, 1.5)), Transform3D(Basis(), Vector3(0, 1.45, -0.62)))
	ModelKit.add_hitbox(_thorn_root, "thorns", self, ModelKit.box_shape(Vector3(0.5, 0.55, 1.35)), Transform3D(Basis(), Vector3(0, 0.95, 0.75)))
	ModelKit.add_hitbox(_head, "head", self, ModelKit.box_shape(Vector3(0.62, 0.62, 1.15)), Transform3D(Basis(), Vector3(0, -0.02, -0.45)))


func _build_head(hide: Material, dark: Material, crystal: Material) -> void:
	var h := _head
	ModelKit.mi(h, _loft(HEAD_SECTIONS, 22, 3, 0.9), hide, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, "Skull")
	ModelKit.mi(h, ModelKit.sphere(0.13, 14, 8), dark, Vector3(0, -0.1, -0.93), Vector3(-15, 0, 0), Vector3(1.15, 0.8, 0.7))
	_nose_marker = ModelKit.pivot(h, "Nose", Vector3(0, -0.12, -0.98))
	for sgn in [-1.0, 1.0]:
		ModelKit.mi(h, ModelKit.sphere(0.05, 10, 6), _eye_mat, Vector3(0.235 * sgn, 0.12, -0.36))
		ModelKit.mi(h, ModelKit.sphere(0.08, 10, 6), hide, Vector3(0.29 * sgn, 0.25, 0.02), Vector3(0, 0, -40.0 * sgn), Vector3(0.6, 1.5, 0.4))
	# crystal growth over the left eye and cheek
	var cst := SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	BloomKit.crystal_into(cst, Vector3(-0.24, 0.16, -0.32), Vector3(-0.6, 0.7, -0.3), 0.2, 0.03)
	BloomKit.crystal_into(cst, Vector3(-0.27, 0.06, -0.28), Vector3(-1.0, 0.2, -0.2), 0.14, 0.025)
	BloomKit.crystal_into(cst, Vector3(0.2, 0.0, -0.55), Vector3(0.8, 0.3, -0.3), 0.12, 0.022)
	# fangs
	for sgn in [-1.0, 1.0]:
		BloomKit.crystal_into(cst, Vector3(0.11 * sgn, -0.12, -0.72), Vector3(0.1 * sgn, -1.0, -0.15), 0.12, 0.02)
	ModelKit.mi(h, cst.commit(), crystal)
	# jaw
	_jaw = ModelKit.pivot(h, "Jaw", Vector3(0, -0.15, -0.18))
	var jst := SurfaceTool.new()
	jst.begin(Mesh.PRIMITIVE_TRIANGLES)
	ModelKit.tube_into(jst, PackedVector3Array([Vector3(0, 0, 0.05), Vector3(0, -0.05, -0.35), Vector3(0, -0.06, -0.6), Vector3(0, -0.055, -0.66)]), PackedFloat32Array([0.17, 0.13, 0.09, 0.0]), 12, false)
	for k in 6:
		var b := Vector3(_rng.randf_range(-0.07, 0.07), -0.12, lerpf(-0.02, -0.36, float(k) / 5.0))
		_tuft(jst, b, Vector3(0, -1, 0.5), _rng.randf_range(0.14, 0.24), 0.05)
	ModelKit.mi(_jaw, jst.commit(), hide)
	ModelKit.mi(_jaw, ModelKit.box(Vector3(0.15, 0.03, 0.5)), _mouth_mat, Vector3(0, 0.06, -0.3))
	ModelKit.mi(h, ModelKit.box(Vector3(0.2, 0.03, 0.55)), _mouth_mat, Vector3(0, -0.15, -0.5))
	_mouth_marker = ModelKit.pivot(h, "Mouth", Vector3(0, -0.2, -0.75))
	# crystal antlers
	_antler_l = ModelKit.pivot(h, "AntlerL", Vector3(-0.19, 0.27, -0.06))
	_antler_r = ModelKit.pivot(h, "AntlerR", Vector3(0.19, 0.27, -0.06))
	ModelKit.mi(_antler_l, _antler_mesh(-1.0), crystal)
	ModelKit.mi(_antler_r, _antler_mesh(1.0), crystal)


func _antler_mesh(sgn: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d1 := Vector3(sgn * 0.8, 0.5, 0.32).normalized()
	BloomKit.crystal_into(st, Vector3.ZERO, d1, 0.72, 0.09, 0.3)
	var p1 := d1 * 0.56
	var d2 := Vector3(sgn * 0.5, 0.85, -0.05).normalized()
	BloomKit.crystal_into(st, p1, d2, 0.78, 0.075, 1.1)
	var p2 := p1 + d2 * 0.6
	BloomKit.crystal_into(st, d1 * 0.15, Vector3(sgn * 0.25, 0.35, -0.9), 0.38, 0.042, 0.5)
	BloomKit.crystal_into(st, p1, Vector3(sgn * 0.15, 0.7, -0.7), 0.46, 0.045, 0.2)
	BloomKit.crystal_into(st, p1 + d2 * 0.3, Vector3(sgn * 0.9, 0.5, 0.25), 0.36, 0.04, 2.0)
	BloomKit.crystal_into(st, p2, Vector3(sgn * 0.7, 0.7, 0.2), 0.36, 0.04, 0.7)
	BloomKit.crystal_into(st, p2, Vector3(sgn * 0.1, 1.0, -0.35), 0.42, 0.04, 1.4)
	BloomKit.crystal_into(st, p2, Vector3(sgn * 0.35, 0.6, -0.7), 0.3, 0.035, 2.4)
	return st.commit()


func _build_leg(i: int, hide: Material, dark: Material, crystal: Material) -> void:
	var front := i < 2
	var sgn := signf(HIP_POS[i].x)
	var hip := ModelKit.pivot(_body, "Hip%d" % i, HIP_POS[i])
	var l1 := 0.72
	var l2 := 0.6 if front else 0.66
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if front:
		ModelKit.tube_into(st, PackedVector3Array([Vector3(0, 0.2, 0.0), Vector3(0, -0.3, -0.04), Vector3(0, -l1, 0)]), PackedFloat32Array([0.4, 0.31, 0.21]), 14, false)
		for k in 9:
			var y := lerpf(-0.05, -0.55, float(k) / 8.0)
			var a := _rng.randf_range(-1.2, 1.2) + (PI * 0.5 * sgn)
			var b := Vector3(sin(a) * 0.24, y, cos(a) * 0.24 + 0.05)
			_tuft(st, b, Vector3(sin(a) * 0.5, -1.0, 0.5), _rng.randf_range(0.2, 0.32), 0.05)
	else:
		ModelKit.tube_into(st, PackedVector3Array([Vector3(0, 0.25, 0.1), Vector3(0, -0.25, 0.0), Vector3(0, -l1, 0)]), PackedFloat32Array([0.44, 0.33, 0.19]), 14, false)
	ModelKit.mi(hip, st.commit(), hide)
	var knee := ModelKit.pivot(hip, "Knee", Vector3(0, -l1, 0))
	var lst := SurfaceTool.new()
	lst.begin(Mesh.PRIMITIVE_TRIANGLES)
	if front:
		ModelKit.tube_into(lst, PackedVector3Array([Vector3(0, 0.08, 0), Vector3(0, -l2 * 0.5, -0.01), Vector3(0, -l2, 0)]), PackedFloat32Array([0.22, 0.17, 0.155]), 12, false)
	else:
		ModelKit.tube_into(lst, PackedVector3Array([Vector3(0, 0.08, 0.02), Vector3(0, -l2 * 0.5, 0), Vector3(0, -l2, 0)]), PackedFloat32Array([0.18, 0.14, 0.12]), 12, false)
	ModelKit.mi(knee, lst.commit(), hide)
	var foot := ModelKit.pivot(knee, "Foot", Vector3(0, -l2, 0))
	var cst := SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	if front:
		ModelKit.mi(foot, ModelKit.sphere(0.17, 14, 8), hide, Vector3(0, -0.07, -0.06), Vector3.ZERO, Vector3(1.15, 0.55, 1.35))
		ModelKit.mi(foot, ModelKit.sphere(0.15, 12, 6), dark, Vector3(0, -0.12, -0.05), Vector3.ZERO, Vector3(1.0, 0.3, 1.2))
		for c in 4:
			var x := (float(c) - 1.5) * 0.075
			BloomKit.crystal_into(cst, Vector3(x, -0.09, -0.24), Vector3(x * 0.8, -0.45, -1.0), 0.15, 0.022, float(c))
	else:
		ModelKit.mi(foot, ModelKit.sphere(0.16, 14, 8), hide, Vector3(0, -0.07, -0.05), Vector3.ZERO, Vector3(1.05, 0.5, 1.4))
		ModelKit.mi(foot, ModelKit.sphere(0.14, 12, 6), dark, Vector3(0, -0.115, -0.05), Vector3.ZERO, Vector3(0.95, 0.3, 1.25))
		for c in 3:
			var x := (float(c) - 1.0) * 0.075
			BloomKit.crystal_into(cst, Vector3(x, -0.09, -0.24), Vector3(x * 0.8, -0.45, -1.0), 0.12, 0.02, float(c))
	ModelKit.mi(foot, cst.commit(), crystal)
	_hip.append(hip)
	_knee.append(knee)
	_foot.append(foot)
	ModelKit.add_hitbox(hip, "legs", self, ModelKit.capsule_shape(0.24 if front else 0.26, l1 + 0.2), Transform3D(Basis(), Vector3(0, -l1 * 0.45, 0)))
	ModelKit.add_hitbox(knee, "legs", self, ModelKit.capsule_shape(0.15, l2 + 0.15), Transform3D(Basis(), Vector3(0, -l2 * 0.5, 0)))


## Pale lichen knobs + small crystal clusters on shoulders/flanks.
func _build_growths(pale: Material) -> void:
	var xf: Array[Transform3D] = []
	for c in 9:
		var z := _rng.randf_range(-1.3, 1.2)
		var a := _rng.randf_range(0.5, 1.9) * (1.0 if c % 2 == 0 else -1.0)
		var sp := _surf(z, a)
		for k in 5:
			var o := Vector3(_rng.randf_range(-0.09, 0.09), _rng.randf_range(-0.09, 0.09), _rng.randf_range(-0.09, 0.09))
			var s := _rng.randf_range(0.5, 1.4)
			xf.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.7, s)), sp[0] + o - sp[1] * 0.01))
	ModelKit.multimesh(_body, ModelKit.sphere(0.05, 7, 4), pale, xf)
	var spots: Array[Vector2] = [Vector2(-1.0, 1.1), Vector2(-0.6, -1.25), Vector2(0.4, 1.4), Vector2(0.9, -1.0), Vector2(-1.35, -0.8)]
	for k in spots.size():
		var sp := _surf(spots[k].x, spots[k].y)
		var n: Vector3 = sp[1]
		var mi := MeshInstance3D.new()
		mi.mesh = BloomKit.cluster_mesh(300 + k, 0.38)
		var up := n.normalized()
		var side := up.cross(Vector3.FORWARD).normalized()
		mi.transform = Transform3D(Basis(side, up, side.cross(up)), sp[0] - up * 0.02)
		_body.add_child(mi)


# --------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------

## Linear interpolation of SECTIONS at z -> [z, cy, rx, ryt, ryb]
func _sec_at(z: float) -> PackedFloat32Array:
	var out := PackedFloat32Array([z, 0, 0, 0, 0])
	for i in SECTIONS.size() - 1:
		var a: Array = SECTIONS[i]
		var b: Array = SECTIONS[i + 1]
		if z >= float(a[0]) and z <= float(b[0]):
			var t := (z - float(a[0])) / (float(b[0]) - float(a[0]))
			for c in range(1, 5):
				out[c] = lerpf(float(a[c]), float(b[c]), t)
			return out
	var e: Array = SECTIONS[0] if z < float(SECTIONS[0][0]) else SECTIONS[SECTIONS.size() - 1]
	for c in range(1, 5):
		out[c] = float(e[c])
	return out


func _ring_pt(sec: PackedFloat32Array, a: float, expo: float) -> Vector3:
	var s := sin(a)
	var c := cos(a)
	var x := sec[2] * signf(s) * pow(absf(s), expo)
	var ry := sec[3] if c > 0.0 else sec[4]
	var y := sec[1] + ry * signf(c) * pow(absf(c), expo)
	return Vector3(x, y, sec[0])


## Surface point and approx outward normal at (z, angle from top).
func _surf(z: float, a: float) -> Array:
	var sec := _sec_at(z)
	var p := _ring_pt(sec, a, 0.82)
	var p2 := _ring_pt(sec, a + 0.01, 0.82)
	var tng := p2 - p
	var n := Vector3(tng.y, -tng.x, 0).normalized()
	if n.dot(p - Vector3(0, sec[1], z)) < 0.0:
		n = -n
	return [p, n]


static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Smooth lofted torso through SECTIONS (Catmull-Rom between sections, superellipse rings).
func _loft(secs: Array, sides: int, sub: int, expo: float) -> ArrayMesh:
	var rings: Array[PackedFloat32Array] = []
	var n := secs.size()
	for i in n - 1:
		var p0: Array = secs[maxi(i - 1, 0)]
		var p1: Array = secs[i]
		var p2: Array = secs[i + 1]
		var p3: Array = secs[mini(i + 2, n - 1)]
		for k in sub:
			var t := float(k) / sub
			var r := PackedFloat32Array([0, 0, 0, 0, 0])
			for c in 5:
				r[c] = _cr(float(p0[c]), float(p1[c]), float(p2[c]), float(p3[c]), t)
			rings.append(r)
	var last: Array = secs[n - 1]
	rings.append(PackedFloat32Array([float(last[0]), float(last[1]), float(last[2]), float(last[3]), float(last[4])]))
	var grid: Array[PackedVector3Array] = []
	for r in rings:
		var ring := PackedVector3Array()
		for j in sides:
			ring.append(_ring_pt(r, TAU * j / sides, expo))
		grid.append(ring)
	var nr := grid.size()
	var norms: Array[PackedVector3Array] = []
	for i in nr:
		var rn := PackedVector3Array()
		var ctr := Vector3(0, rings[i][1], rings[i][0])
		for j in sides:
			var da := grid[i][(j + 1) % sides] - grid[i][(j - 1 + sides) % sides]
			var ds := grid[mini(i + 1, nr - 1)][j] - grid[maxi(i - 1, 0)][j]
			var nn := da.cross(ds).normalized()
			if nn.dot(grid[i][j] - ctr) < 0.0:
				nn = -nn
			rn.append(nn)
		norms.append(rn)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nr - 1:
		for j in sides:
			var j2 := (j + 1) % sides
			var u0 := float(j) / sides
			var u1 := float(j + 1) / sides
			var v0 := float(i) / (nr - 1)
			var v1 := float(i + 1) / (nr - 1)
			ModelKit.tri(st, grid[i][j], grid[i][j2], grid[i + 1][j], norms[i][j], norms[i][j2], norms[i + 1][j], Vector2(u0, v0), Vector2(u1, v0), Vector2(u0, v1))
			ModelKit.tri(st, grid[i + 1][j], grid[i][j2], grid[i + 1][j2], norms[i + 1][j], norms[i][j2], norms[i + 1][j2], Vector2(u0, v1), Vector2(u1, v0), Vector2(u1, v1))
	for e in 2:
		var ri := 0 if e == 0 else nr - 1
		var ctr := Vector3(0, rings[ri][1], rings[ri][0] + (-0.03 if e == 0 else 0.03))
		var cn := Vector3(0, 0, -1 if e == 0 else 1)
		for j in sides:
			ModelKit.tri(st, ctr, grid[ri][j], grid[ri][(j + 1) % sides], cn, norms[ri][j], norms[ri][(j + 1) % sides])
	st.generate_tangents()
	return st.commit()


## A tapered hair tuft (cone) appended to st.
func _tuft(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, radius: float) -> void:
	var d := dir.normalized()
	var mid := base + d * length * 0.45 + Vector3(0, -length * 0.1, 0)
	var tip := base + d * length + Vector3(0, -length * 0.25, 0)
	ModelKit.tube_into(st, PackedVector3Array([base - d * radius, mid, tip]), PackedFloat32Array([radius * 1.3, radius * 0.75, 0.0]), 5, false)


## A layered fur card hanging from the body surface at angle `a` (0 = top, PI = belly),
## between z0 and z1, with a jagged hem. Double sided (shag material has culling off).
func _skirt(st: SurfaceTool, a: float, z0: float, z1: float, len_min: float, len_max: float, step := 0.07, flare := 0.25) -> void:
	var prev: Array[Vector3] = []
	var prev_n := Vector3.ZERO
	var z := z0
	while z <= z1 + 0.001:
		var sp := _surf(z, a)
		var p: Vector3 = sp[0]
		var n: Vector3 = sp[1]
		var hang := (n * flare + Vector3(0, -1, 0.18)).normalized()
		var taper := sin(clampf((z - z0) / maxf(z1 - z0, 0.01), 0.0, 1.0) * PI) * 0.5 + 0.5
		var l := _rng.randf_range(len_min, len_max) * taper
		var top := p - n * 0.05
		var mid := p + hang * l * 0.5 + n * 0.035
		var tip := p + hang * l + n * 0.02
		var cur: Array[Vector3] = [top, mid, tip]
		if prev.size() == 3:
			for r in 2:
				ModelKit.tri(st, prev[r], cur[r], prev[r + 1], prev_n, n, prev_n)
				ModelKit.tri(st, prev[r + 1], cur[r], cur[r + 1], prev_n, n, n)
		prev = cur
		prev_n = n
		z += step * _rng.randf_range(0.7, 1.3)


## Shaggy fur: belly/chest skirts, a heavy layered mane over the shoulders, rough haunches.
func _body_fringe() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sgn in [-1.0, 1.0]:
		# chest + belly skirt
		_skirt(st, sgn * 2.25, -1.55, -0.45, 0.4, 0.62, 0.06, 0.15)
		_skirt(st, sgn * 2.35, -0.6, 1.25, 0.18, 0.34, 0.07, 0.15)
		_skirt(st, sgn * 2.8, -1.4, 0.9, 0.2, 0.36, 0.08, 0.1)
		# shoulder mane, layered
		_skirt(st, sgn * 0.55, -1.5, -0.35, 0.28, 0.42, 0.06, 0.6)
		_skirt(st, sgn * 1.05, -1.5, -0.2, 0.32, 0.5, 0.06, 0.55)
		_skirt(st, sgn * 1.6, -1.45, -0.1, 0.32, 0.5, 0.06, 0.45)
		# haunch shag
		_skirt(st, sgn * 1.75, 0.3, 1.45, 0.14, 0.26, 0.08, 0.3)
	st.generate_tangents()
	return st.commit()

## Shaggy mane under/over the neck (cards around the neck tube, hanging down).
func _neck_mane() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var angs: Array[float] = [0.0, 0.7, -0.7, 1.5, -1.5, 2.3, -2.3, PI]
	for ai in angs.size():
		var a := angs[ai]
		var prev: Array[Vector3] = []
		var prev_n := Vector3.ZERO
		var z := 0.3
		while z >= -0.85:
			var r := lerpf(0.53, 0.33, (0.3 - z) / 1.15)
			var n := Vector3(sin(a), cos(a), 0)
			var p := Vector3(0, 0.03 - (0.3 - z) * 0.03, z) + n * r
			var hang := (n * 0.3 + Vector3(0, -1, 0.35)).normalized()
			var l := _rng.randf_range(0.25, 0.42) * (1.4 if absf(a) > 2.0 else 1.0)
			var cur: Array[Vector3] = [p - n * 0.05, p + hang * l * 0.5 + n * 0.035, p + hang * l]
			if prev.size() == 3:
				for k in 2:
					ModelKit.tri(st, prev[k], cur[k], prev[k + 1], prev_n, n, prev_n)
					ModelKit.tri(st, prev[k + 1], cur[k], cur[k + 1], prev_n, n, n)
			prev = cur
			prev_n = n
			z -= 0.07 * _rng.randf_range(0.7, 1.3)
	st.generate_tangents()
	return st.commit()
