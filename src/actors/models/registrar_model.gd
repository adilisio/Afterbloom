class_name RegistrarModel
extends Node3D
## Registrar 9 - Halcyon shelter courier robot (1967). Teal & cream enamel, boxy chest with a
## ticket printer slot, one big green "magic-eye" camera eye, courier cap, wheeled base,
## clipboard in the left hand and a rubber stamp in the right. Origin at floor, faces -Z, ~1.7 m.

signal gesture_finished(gesture_name: String)

const GESTURES := {"bow": 2.2, "stamp": 2.4, "nod": 1.1}
const EYE_GREEN := Color(0.45, 1.0, 0.55)

enum { SP, SR, SY, EL, WR, ARM_N }
const HY := 10
const HP := 11
const HR := 12
const BP := 13
const BY := 14
const CH_N := 15

var _idle := PackedFloat32Array()
var _gp := PackedFloat32Array()
var _gm := PackedFloat32Array()
var _cur := PackedFloat32Array()

var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _iris: Array[Node3D] = []
var _eye_core: MeshInstance3D
var _sh: Array[Node3D] = []
var _el: Array[Node3D] = []
var _wr: Array[Node3D] = []
var _grip: Array[Node3D] = []
var _wheels: Array[Node3D] = []
var _ticket: Node3D
var _beacon: StandardMaterial3D
var _m_eye: StandardMaterial3D
var _m_speaker: StandardMaterial3D
var _eye_light: OmniLight3D

var _t := 0.0
var _talking := false
var _talk := 0.0
var _speed := 0.0
var _g_name := ""
var _g_t := 0.0
var _g_dur := 0.0
var _stamped := false
var _look_active := false
var _look_pos := Vector3.ZERO
var _look_w := 0.0
var _idle_head := Vector3.ZERO
var _idle_head_tgt := Vector3.ZERO
var _idle_timer := 1.0
var _blink := 0.0
var _blink_timer := 3.0
var _ticket_out := 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_noise.seed = _rng.randi()
	_noise.frequency = 0.5
	_idle.resize(CH_N)
	_gp.resize(CH_N)
	_gm.resize(CH_N)
	_cur.resize(CH_N)
	_build()
	_compute_idle(0.0)
	for i in CH_N:
		_cur[i] = _idle[i]
	_apply()


# ----------------------------------------------------------------------------- API

func set_talking(b: bool) -> void:
	_talking = b


func play_gesture(gesture_name: String) -> float:
	if not GESTURES.has(gesture_name):
		push_warning("RegistrarModel: unknown gesture '%s'" % gesture_name)
		return 0.0
	if _g_name != "":
		_end_gesture()
	_g_name = gesture_name
	_g_t = 0.0
	_g_dur = GESTURES[gesture_name]
	_stamped = false
	return _g_dur


func look_at_point(p: Vector3) -> void:
	_look_active = true
	_look_pos = p


func clear_look() -> void:
	_look_active = false


func get_head_node() -> Node3D:
	return _head


## Optional: 0..1 rolling speed (wheels spin, slight lean).
func set_move_speed(v: float) -> void:
	_speed = clampf(v, 0.0, 1.0)


# ----------------------------------------------------------------------------- build

func _teal() -> StandardMaterial3D:
	return ModelKit.enamel("reg_teal", Color(0.13, 0.46, 0.46), 0.32)


func _cream() -> StandardMaterial3D:
	return ModelKit.enamel("reg_cream", Color(0.92, 0.87, 0.74), 0.3)


func _build() -> void:
	var teal := _teal()
	var cream := _cream()
	var chrome := ModelKit.chrome()
	var rubber := ModelKit.rubber()
	var dark := ModelKit.pbr("reg_dark", Color(0.03, 0.03, 0.032), 0.2, 0.4)
	_body = ModelKit.pivot(self, "Body")
	# ---- wheeled base ----
	var base := ModelKit.pivot(_body, "Base")
	ModelKit.mi(base, ModelKit.rounded_box(Vector3(0.5, 0.2, 0.42), 0.08, 3), teal, Vector3(0, 0.21, 0))
	ModelKit.mi(base, ModelKit.rounded_box(Vector3(0.44, 0.04, 0.38), 0.018, 2), chrome, Vector3(0, 0.32, 0))
	ModelKit.mi(base, ModelKit.rounded_box(Vector3(0.52, 0.035, 0.44), 0.015, 2), rubber, Vector3(0, 0.115, 0))
	for side in 2:
		var sx := -1.0 if side == 0 else 1.0
		var w := ModelKit.pivot(base, "Wheel%d" % side, Vector3(sx * 0.255, 0.12, 0.02))
		ModelKit.mi(w, ModelKit.cyl(0.12, 0.12, 0.07, 32), rubber, Vector3.ZERO, Vector3(0, 0, 90))
		ModelKit.mi(w, ModelKit.torus(0.085, 0.125, 28, 7), rubber, Vector3.ZERO, Vector3(0, 0, 90), Vector3(1.0, 0.6, 1.0))
		ModelKit.mi(w, ModelKit.cyl(0.075, 0.085, 0.012, 28), chrome, Vector3(sx * 0.037, 0, 0), Vector3(0, 0, 90))
		ModelKit.mi(w, ModelKit.sphere(0.03, 14, 8), chrome, Vector3(sx * 0.044, 0, 0), Vector3.ZERO, Vector3(0.5, 1, 1))
		for k in 5:
			var a := TAU * k / 5.0
			ModelKit.mi(w, ModelKit.cyl(0.006, 0.006, 0.006, 8), dark, Vector3(sx * 0.045, sin(a) * 0.05, cos(a) * 0.05), Vector3(0, 0, 90))
		_wheels.append(w)
	# front caster
	var cast := ModelKit.pivot(base, "Caster", Vector3(0, 0.05, -0.17))
	ModelKit.mi(cast, ModelKit.cyl(0.045, 0.045, 0.03, 20), rubber, Vector3.ZERO, Vector3(0, 0, 90))
	ModelKit.mi(cast, ModelKit.box(Vector3(0.05, 0.06, 0.03)), chrome, Vector3(0, 0.04, 0))
	# headlamp on the base front
	ModelKit.mi(base, ModelKit.torus(0.022, 0.032, 20, 6), chrome, Vector3(0, 0.22, -0.21), Vector3(90, 0, 0))
	ModelKit.mi(base, ModelKit.sphere(0.024, 14, 8), ModelKit.glow("reg_lamp", Color(1.0, 0.85, 0.55), 2.0), Vector3(0, 0.22, -0.205), Vector3.ZERO, Vector3(1, 1, 0.5))
	# ---- torso ----
	_torso = ModelKit.pivot(_body, "Torso", Vector3(0, 0.34, 0))
	ModelKit.mi(_torso, ModelKit.cyl(0.11, 0.14, 0.06, 24), chrome, Vector3(0, 0.02, 0))
	ModelKit.mi(_torso, ModelKit.rounded_box(Vector3(0.54, 0.62, 0.36), 0.07, 3), teal, Vector3(0, 0.38, 0))
	# cream front panel
	ModelKit.mi(_torso, ModelKit.rounded_box(Vector3(0.42, 0.48, 0.02), 0.012, 2), cream, Vector3(0, 0.39, -0.177))
	# chrome trim strips
	ModelKit.mi(_torso, ModelKit.rounded_box(Vector3(0.55, 0.02, 0.37), 0.008, 2), chrome, Vector3(0, 0.1, 0))
	ModelKit.mi(_torso, ModelKit.rounded_box(Vector3(0.55, 0.02, 0.37), 0.008, 2), chrome, Vector3(0, 0.67, 0))
	# printer slot with ticket
	ModelKit.mi(_torso, ModelKit.rounded_box(Vector3(0.26, 0.05, 0.02), 0.01, 2), chrome, Vector3(0, 0.555, -0.186))
	ModelKit.mi(_torso, ModelKit.box(Vector3(0.22, 0.012, 0.02)), dark, Vector3(0, 0.555, -0.19))
	_ticket = ModelKit.pivot(_torso, "Ticket", Vector3(0, 0.555, -0.19))
	var paper := ModelKit.pbr("reg_paper", Color(0.95, 0.93, 0.86), 0.0, 0.85)
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	ModelKit.mi(_ticket, ModelKit.box(Vector3(0.18, 0.12, 0.0015)), paper, Vector3(0, -0.06, -0.003))
	_ticket.scale = Vector3(1, 0.001, 1)
	# speaker grille (round) with light
	ModelKit.mi(_torso, ModelKit.torus(0.05, 0.062, 28, 6), chrome, Vector3(-0.1, 0.36, -0.188), Vector3(90, 0, 0))
	ModelKit.mi(_torso, ModelKit.cyl(0.05, 0.05, 0.006, 24), dark, Vector3(-0.1, 0.36, -0.188), Vector3(90, 0, 0))
	_m_speaker = ModelKit.glow("reg_speaker", Color(1.0, 0.6, 0.25), 0.4, true)
	for k in 4:
		ModelKit.mi(_torso, ModelKit.box(Vector3(0.07 - absf(k - 1.5) * 0.018, 0.007, 0.004)), _m_speaker, Vector3(-0.1, 0.336 + k * 0.016, -0.193))
	# dials + indicator lamps
	for k in 3:
		var lamp_col: Color = [Color(1.0, 0.3, 0.2), Color(1.0, 0.75, 0.2), Color(0.4, 1.0, 0.4)][k]
		ModelKit.mi(_torso, ModelKit.sphere(0.012, 12, 6), ModelKit.glow("reg_lamp%d" % k, lamp_col, 1.8), Vector3(0.06 + k * 0.04, 0.4, -0.19), Vector3.ZERO, Vector3(1, 1, 0.6))
		ModelKit.mi(_torso, ModelKit.torus(0.011, 0.016, 16, 5), chrome, Vector3(0.06 + k * 0.04, 0.4, -0.188), Vector3(90, 0, 0))
	for k in 2:
		ModelKit.mi(_torso, ModelKit.cyl(0.018, 0.021, 0.02, 18), dark, Vector3(0.08 + k * 0.06, 0.31, -0.195), Vector3(90, 0, 0))
		ModelKit.mi(_torso, ModelKit.box(Vector3(0.004, 0.016, 0.004)), chrome, Vector3(0.08 + k * 0.06, 0.315, -0.207))
	# badge + stencils
	var badge := ModelKit.pivot(_torso, "Badge", Vector3(0, 0.215, -0.19))
	ModelKit.mi(badge, ModelKit.rounded_box(Vector3(0.24, 0.055, 0.008), 0.02, 2), chrome)
	var lbl := Label3D.new()
	lbl.text = "HALCYON"
	lbl.font_size = 64
	lbl.pixel_size = 0.0005
	lbl.modulate = Color(0.08, 0.28, 0.3)
	lbl.shaded = true
	lbl.outline_size = 0
	lbl.position = Vector3(0, 0, -0.0045)
	lbl.rotation_degrees = Vector3(0, 180, 0)
	badge.add_child(lbl)
	var reg := Label3D.new()
	reg.text = "REGISTRAR  9"
	reg.font_size = 40
	reg.pixel_size = 0.0005
	reg.modulate = Color(0.9, 0.86, 0.72)
	reg.shaded = true
	reg.outline_size = 0
	reg.position = Vector3(0, 0.12, 0.181)
	_torso.add_child(reg)
	var side_lbl := Label3D.new()
	side_lbl.text = "SHELTER No. 9\nCOURIER SERVICE"
	side_lbl.font_size = 32
	side_lbl.pixel_size = 0.0005
	side_lbl.modulate = Color(0.9, 0.86, 0.72)
	side_lbl.shaded = true
	side_lbl.outline_size = 0
	side_lbl.position = Vector3(0.271, 0.45, 0)
	side_lbl.rotation_degrees = Vector3(0, 90, 0)
	_torso.add_child(side_lbl)
	# back service hatch with vents and rivets
	ModelKit.mi(_torso, ModelKit.rounded_box(Vector3(0.36, 0.4, 0.02), 0.02, 2), cream, Vector3(0, 0.4, 0.175))
	for k in 5:
		ModelKit.mi(_torso, ModelKit.rounded_box(Vector3(0.24, 0.014, 0.012), 0.006, 1), dark, Vector3(0, 0.5 - k * 0.03, 0.186))
	ModelKit.mi(_torso, ModelKit.cyl(0.035, 0.035, 0.02, 20), chrome, Vector3(0, 0.27, 0.19), Vector3(90, 0, 0))
	ModelKit.mi(_torso, ModelKit.box(Vector3(0.05, 0.008, 0.012)), dark, Vector3(0, 0.27, 0.2))
	var brivs: Array[Transform3D] = []
	for cx in [-1.0, 1.0]:
		for cy in [0.22, 0.58]:
			brivs.append(Transform3D(Basis(Quaternion(Vector3.UP, Vector3.BACK)), Vector3(cx * 0.16, cy, 0.186)))
	ModelKit.multimesh(_torso, ModelKit.rivet(0.007), chrome, brivs)
	# rivets on chest corners
	var rivs: Array[Transform3D] = []
	for cx in [-1.0, 1.0]:
		for cy in [0.17, 0.61]:
			rivs.append(Transform3D(Basis(Quaternion(Vector3.UP, Vector3.FORWARD)), Vector3(cx * 0.19, cy, -0.188)))
	ModelKit.multimesh(_torso, ModelKit.rivet(0.007), chrome, rivs)
	# shoulders
	for side in 2:
		var sx := -1.0 if side == 0 else 1.0
		ModelKit.mi(_torso, ModelKit.sphere(0.07, 14, 8), chrome, Vector3(sx * 0.29, 0.6, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	# neck
	for k in 3:
		ModelKit.mi(_torso, ModelKit.torus(0.035, 0.06, 18, 5), rubber, Vector3(0, 0.705 + k * 0.025, 0))
	# ---- head: drum camera ----
	_head = ModelKit.pivot(_torso, "Head", Vector3(0, 0.82, 0))
	_build_head(_head, teal, cream, chrome, dark)
	# ---- arms ----
	for side in 2:
		_build_arm(side, chrome, rubber, teal)
	_build_props(chrome, dark)


func _build_head(h: Node3D, teal: StandardMaterial3D, cream: StandardMaterial3D, chrome: StandardMaterial3D, dark: StandardMaterial3D) -> void:
	ModelKit.mi(h, ModelKit.cyl(0.075, 0.09, 0.05, 24), chrome, Vector3(0, -0.035, 0))
	var drum := ModelKit.pivot(h, "Drum", Vector3(0, 0.13, 0))
	ModelKit.mi(drum, ModelKit.cyl(0.165, 0.165, 0.26, 40), teal, Vector3(0, 0, 0.0), Vector3(90, 0, 0))
	ModelKit.mi(drum, ModelKit.torus(0.155, 0.172, 36, 6), chrome, Vector3(0, 0, -0.13), Vector3(90, 0, 0))
	ModelKit.mi(drum, ModelKit.torus(0.155, 0.172, 36, 6), chrome, Vector3(0, 0, 0.13), Vector3(90, 0, 0))
	ModelKit.mi(drum, ModelKit.cyl(0.158, 0.158, 0.01, 40), cream, Vector3(0, 0, 0.13), Vector3(90, 0, 0))
	# back of the drum: vents + stencilled unit number
	for k in 4:
		ModelKit.mi(drum, ModelKit.rounded_box(Vector3(0.14 - absf(k - 1.5) * 0.03, 0.012, 0.01), 0.005, 1), dark, Vector3(0, 0.05 - k * 0.025, 0.135))
	var num := Label3D.new()
	num.text = "9"
	num.font_size = 96
	num.pixel_size = 0.0007
	num.modulate = Color(0.1, 0.3, 0.32)
	num.shaded = true
	num.outline_size = 0
	num.position = Vector3(0, -0.075, 0.137)
	drum.add_child(num)
	# side ear discs
	for sx in [-1.0, 1.0]:
		ModelKit.mi(drum, ModelKit.cyl(0.05, 0.055, 0.03, 20), chrome, Vector3(sx * 0.175, 0, 0), Vector3(0, 0, 90))
		ModelKit.mi(drum, ModelKit.cyl(0.006, 0.006, 0.08, 8), chrome, Vector3(sx * 0.19, 0.08, 0.0), Vector3(0, 0, -sx * 25.0))
		ModelKit.mi(drum, ModelKit.sphere(0.012, 10, 6), ModelKit.glow("reg_tip", Color(1.0, 0.4, 0.2), 2.0), Vector3(sx * 0.207, 0.117, 0))
	# big camera lens: stepped chrome barrel, dark glass, glowing magic-eye iris
	var lens := ModelKit.pivot(drum, "Lens", Vector3(0, 0, -0.13))
	var barrel := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.13, 0.0), Vector2(0.13, 0.02), Vector2(0.13, 0.02),
		Vector2(0.115, 0.022), Vector2(0.115, 0.045), Vector2(0.115, 0.045), Vector2(0.1, 0.048), Vector2(0.1, 0.06), Vector2(0.1, 0.06), Vector2(0.088, 0.06)])
	ModelKit.mi(lens, ModelKit.lathe(barrel, 40), chrome, Vector3.ZERO, Vector3(-90, 0, 0))
	ModelKit.mi(lens, ModelKit.cyl(0.089, 0.089, 0.004, 36), dark, Vector3(0, 0, -0.045), Vector3(90, 0, 0))
	_m_eye = ModelKit.glow("reg_eye", EYE_GREEN, 1.6, true)
	# magic-eye tube: a glowing green target with two dark "shadow" wedges that open and close
	var iris_root := ModelKit.pivot(lens, "Iris", Vector3(0, 0, -0.047))
	var disc := ModelKit.mi(iris_root, ModelKit.cyl(0.072, 0.072, 0.003, 40), _m_eye, Vector3.ZERO, Vector3(90, 0, 0))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shade := ModelKit.pbr("reg_eye_shade", Color(0.02, 0.05, 0.03), 0.0, 0.3)
	for k in 2:
		var blade := ModelKit.pivot(iris_root, "Shadow%d" % k)
		var wedge := ModelKit.mi(blade, ModelKit.cyl(0.0, 0.05, 0.072, 3), shade, Vector3(0, 0.036, -0.002), Vector3(0, 0, 180), Vector3(1, 1, 0.08))
		wedge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_iris.append(blade)
	for r in [0.03, 0.05]:
		var rf: float = r
		ModelKit.mi(iris_root, ModelKit.torus(rf - 0.0012, rf + 0.0012, 36, 4), shade, Vector3(0, 0, -0.0025), Vector3(90, 0, 0))
	_eye_core = ModelKit.mi(iris_root, ModelKit.cyl(0.016, 0.016, 0.004, 20), dark, Vector3(0, 0, -0.003), Vector3(90, 0, 0))
	ModelKit.mi(iris_root, ModelKit.sphere(0.006, 10, 6), ModelKit.glow("reg_eye_hot", Color(0.8, 1.0, 0.8), 3.0), Vector3(0, 0, -0.005))
	ModelKit.mi(lens, ModelKit.hemisphere(0.09, 32, 6), ModelKit.glass("reg_lens", Color(0.7, 0.9, 0.8, 0.12)), Vector3(0, 0, -0.05), Vector3(-90, 0, 0), Vector3(1, 1, 0.35))
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = EYE_GREEN
	_eye_light.light_energy = 0.4
	_eye_light.omni_range = 0.6
	_eye_light.position = Vector3(0, 0, -0.15)
	lens.add_child(_eye_light)
	# courier cap with visor and beacon
	var cap := ModelKit.pivot(drum, "Cap", Vector3(0, 0.15, 0))
	var cap_prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.13, 0.0), Vector2(0.135, 0.05), Vector2(0.14, 0.075),
		Vector2(0.14, 0.075), Vector2(0.12, 0.085), Vector2(0.0, 0.088)])
	var cap_m := ModelKit.mi(cap, ModelKit.lathe(cap_prof, 32), ModelKit.enamel("reg_cap", Color(0.08, 0.2, 0.22), 0.35))
	cap_m.scale = Vector3(1, 1, 1.12)
	ModelKit.mi(cap, ModelKit.torus(0.126, 0.138, 32, 6), ModelKit.chrome(), Vector3(0, 0.012, 0), Vector3.ZERO, Vector3(1, 1, 1.12))
	var visor := ModelKit.mi(cap, ModelKit.cyl(0.12, 0.12, 0.008, 24, true), ModelKit.pbr("reg_visor", Color(0.03, 0.03, 0.03), 0.0, 0.2), Vector3(0, 0.005, -0.12), Vector3(-12, 0, 0), Vector3(1, 1, 0.55))
	visor.name = "Visor"
	_beacon = ModelKit.glow("reg_beacon", Color(1.0, 0.6, 0.15), 2.5, true)
	ModelKit.mi(cap, ModelKit.cyl(0.02, 0.025, 0.012, 16), ModelKit.chrome(), Vector3(0, 0.094, 0))
	ModelKit.mi(cap, ModelKit.hemisphere(0.02, 16, 6), _beacon, Vector3(0, 0.1, 0))
	var badge := ModelKit.mi(cap, ModelKit.cyl(0.018, 0.018, 0.004, 6), ModelKit.brass(false), Vector3(0, 0.045, -0.148), Vector3(80, 0, 0))
	badge.name = "CapBadge"


func _build_arm(side: int, chrome: StandardMaterial3D, rubber: StandardMaterial3D, teal: StandardMaterial3D) -> void:
	var sx := -1.0 if side == 0 else 1.0
	var sh := ModelKit.pivot(_torso, "Shoulder%d" % side, Vector3(sx * 0.31, 0.6, 0))
	ModelKit.mi(sh, ModelKit.cyl(0.035, 0.032, 0.2, 18), teal, Vector3(0, -0.11, 0))
	ModelKit.mi(sh, ModelKit.torus(0.032, 0.04, 18, 6), chrome, Vector3(0, -0.03, 0))
	var el := ModelKit.pivot(sh, "Elbow", Vector3(0, -0.22, 0))
	for k in 3:
		ModelKit.mi(el, ModelKit.torus(0.018, 0.036, 16, 6), rubber, Vector3(0, 0.012 - k * 0.014, 0))
	ModelKit.mi(el, ModelKit.cyl(0.03, 0.026, 0.18, 18), chrome, Vector3(0, -0.12, 0))
	var wr := ModelKit.pivot(el, "Wrist", Vector3(0, -0.215, 0))
	ModelKit.mi(wr, ModelKit.cyl(0.032, 0.032, 0.03, 16), teal, Vector3(0, 0.005, 0))
	# two-jaw clamp hand
	for k in 2:
		var jaw := ModelKit.mi(wr, ModelKit.rounded_box(Vector3(0.012, 0.07, 0.03), 0.005, 2), chrome, Vector3((k * 2 - 1) * 0.022, -0.045, 0), Vector3(0, 0, (k * 2 - 1) * -8.0))
		jaw.name = "Jaw%d" % k
		ModelKit.mi(wr, ModelKit.box(Vector3(0.006, 0.02, 0.026)), rubber, Vector3((k * 2 - 1) * 0.015, -0.07, 0))
	var grip := ModelKit.pivot(wr, "Grip", Vector3(0, -0.06, 0))
	_grip.append(grip)
	_sh.append(sh)
	_el.append(el)
	_wr.append(wr)


func _build_props(chrome: StandardMaterial3D, dark: StandardMaterial3D) -> void:
	# clipboard in the left hand
	var cb := ModelKit.pivot(_grip[0], "Clipboard", Vector3(0.0, 0.03, -0.03))
	cb.rotation_degrees = Vector3(0, -90, 0)
	var board := ModelKit.pbr("reg_board", Color(0.42, 0.27, 0.14), 0.0, 0.6)
	var paper := ModelKit.pbr("reg_paper", Color(0.95, 0.93, 0.86), 0.0, 0.85)
	ModelKit.mi(cb, ModelKit.rounded_box(Vector3(0.006, 0.24, 0.18), 0.003, 1), board, Vector3(0.0, -0.06, 0.0))
	ModelKit.mi(cb, ModelKit.box(Vector3(0.002, 0.2, 0.15)), paper, Vector3(-0.004, -0.075, 0.0))
	ModelKit.mi(cb, ModelKit.rounded_box(Vector3(0.012, 0.03, 0.08), 0.004, 1), chrome, Vector3(-0.004, 0.045, 0.0))
	for k in 6:
		ModelKit.mi(cb, ModelKit.box(Vector3(0.0005, 0.004, 0.11 - (k % 3) * 0.02)), dark, Vector3(-0.0055, -0.01 - k * 0.025, -0.01))
	# rubber stamp in the right hand
	var st := ModelKit.pivot(_grip[1], "Stamp", Vector3(0, -0.01, 0))
	var wood := ModelKit.pbr("reg_wood", Color(0.45, 0.25, 0.11), 0.0, 0.5)
	ModelKit.mi(st, ModelKit.sphere(0.022, 14, 8), wood, Vector3(0, 0.02, 0))
	ModelKit.mi(st, ModelKit.cyl(0.011, 0.014, 0.06, 12), wood, Vector3(0, -0.02, 0))
	ModelKit.mi(st, ModelKit.box(Vector3(0.06, 0.018, 0.04)), wood, Vector3(0, -0.058, 0))
	ModelKit.mi(st, ModelKit.box(Vector3(0.056, 0.006, 0.036)), ModelKit.pbr("reg_ink", Color(0.5, 0.05, 0.05), 0.0, 0.6), Vector3(0, -0.07, 0))


# ----------------------------------------------------------------------------- animation

func _nz(x: float, y: float) -> float:
	return _noise.get_noise_2d(x, y)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	_talk = ModelKit.damp(_talk, 1.0 if _talking else 0.0, 6.0, delta)
	_compute_idle(delta)
	for i in CH_N:
		_gp[i] = 0.0
		_gm[i] = 0.0
	var w := 0.0
	if _g_name != "":
		_g_t += delta
		if _g_t >= _g_dur:
			_end_gesture()
		else:
			_eval_gesture(_g_name, _g_t, _g_dur)
			w = ModelKit.env(_g_t, 0.0, 0.3, _g_dur - 0.35, _g_dur)
	for i in CH_N:
		var tgt := lerpf(_idle[i], _gp[i], w * _gm[i]) if i < HY else _idle[i] + _gp[i] * w
		_cur[i] = ModelKit.damp(_cur[i], tgt, 15.0, delta)
	_apply()
	_update_fx(delta)


func _end_gesture() -> void:
	var n := _g_name
	_g_name = ""
	gesture_finished.emit(n)


func _compute_idle(delta: float) -> void:
	var t := _t
	_idle[SP] = 0.22 + _nz(t * 0.3, 1.0) * 0.04
	_idle[SR] = 0.12
	_idle[SY] = 0.3
	_idle[EL] = 1.35 + _nz(t * 0.25, 2.0) * 0.05
	_idle[WR] = 0.0
	_idle[ARM_N + SP] = 0.08 + _nz(t * 0.3, 3.0) * 0.05
	_idle[ARM_N + SR] = 0.1
	_idle[ARM_N + SY] = 0.1
	_idle[ARM_N + EL] = 0.45 + _nz(t * 0.25, 4.0) * 0.06
	_idle[ARM_N + WR] = 0.0
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = _rng.randf_range(2.0, 5.0)
		_idle_head_tgt = Vector3(_rng.randf_range(-0.08, 0.06), _rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.06, 0.06))
		if _look_active:
			_idle_head_tgt *= 0.3
	_idle_head = ModelKit.damp_v3(_idle_head, _idle_head_tgt, 2.5, delta)
	_look_w = ModelKit.damp(_look_w, 1.0 if _look_active else 0.0, 4.0, delta)
	var look := Vector2.ZERO
	if _look_w > 0.001 and _head.is_inside_tree():
		var tb := _torso.global_transform.basis.orthonormalized()
		var d := tb.inverse() * (_look_pos - (_head.global_position + tb.y * 0.13))
		look = Vector2(clampf(atan2(-d.x, -d.z), -1.1, 1.1), clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.5, 0.45)) * _look_w
	_idle[HY] = look.x + _idle_head.y
	_idle[HP] = look.y + _idle_head.x + sin(t * 8.0) * 0.025 * _talk
	_idle[HR] = _idle_head.z
	_idle[BP] = -0.06 * _speed + _nz(t * 0.4, 5.0) * 0.012
	_idle[BY] = look.x * 0.15


func _set_arm(side: int, sp: float, sr: float, sy: float, el: float, wr: float) -> void:
	var o := side * ARM_N
	_gp[o + SP] = sp
	_gp[o + SR] = sr
	_gp[o + SY] = sy
	_gp[o + EL] = el
	_gp[o + WR] = wr
	for c in ARM_N:
		_gm[o + c] = 1.0


func _eval_gesture(g: String, t: float, dur: float) -> void:
	match g:
		"bow":
			var k := ModelKit.env(t, 0.2, 0.7, 1.3, 1.9)
			_gp[BP] = -0.42 * k
			_gp[HP] = -0.25 * k
			_set_arm(1, 0.5, -0.05, 0.7, 1.5, 0.0)
		"stamp":
			# lift clipboard flat, raise stamp, slam at ~1.1 s, ticket prints
			_set_arm(0, 0.45, 0.1, 0.55, 1.3, 0.0)
			var lift := ModelKit.env(t, 0.25, 0.75, 0.95, 1.08)
			var slam := ModelKit.env(t, 0.95, 1.08, 1.3, 1.7)
			_set_arm(1, 0.5 + lift * 0.75 + slam * 0.25, 0.05, 0.75, 0.75 + lift * 0.55 + slam * 0.1, 0.0)
			_gp[HP] = -0.3 * ModelKit.env(t, 0.3, 0.7, dur - 0.6, dur - 0.2)
			_gp[BP] = -0.05 * slam
			if t > 1.08 and not _stamped:
				_stamped = true
				_ticket_out = 0.001
		"nod":
			var k := ModelKit.env(t, 0.05, 0.15, dur - 0.2, dur)
			_gp[HP] = -0.22 * maxf(0.0, sin(t * TAU * 1.9)) * k


func _apply() -> void:
	_body.position.y = sin(_t * 2.0) * 0.003
	_torso.rotation = Vector3(_cur[BP], _cur[BY], sin(_t * 0.8) * 0.01)
	_head.rotation = Vector3(_cur[HP], _cur[HY], _cur[HR])
	for side in 2:
		var o := side * ARM_N
		var m := -1.0 if side == 0 else 1.0
		_sh[side].rotation = Vector3(_cur[o + SP], _cur[o + SY] * m, _cur[o + SR] * m)
		_el[side].rotation = Vector3(_cur[o + EL], 0.0, 0.0)
		_wr[side].rotation = Vector3(_cur[o + WR], 0.0, 0.0)


func _update_fx(delta: float) -> void:
	# magic-eye iris: blades breathe, pulse with speech, blink = close
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = _rng.randf_range(3.0, 7.0)
		_blink = 1.0
	_blink = maxf(0.0, _blink - delta / 0.25)
	var speech := _talk * (0.5 + 0.5 * sin(_t * 15.0) * (0.6 + 0.4 * _nz(_t * 5.0, 9.0)))
	var open := 1.0 - sin(_blink * PI) * 0.85
	# shadow wedges: narrow when "focused"/talking, wide when blinking
	var ang := (0.5 + 0.12 * _nz(_t * 0.7, 11.0) - speech * 0.3) * (2.0 - open)
	_iris[0].rotation.z = ang * 0.5
	_iris[1].rotation.z = -ang * 0.5
	_iris[0].scale = Vector3(0.6 + ang, 1.0, 1.0)
	_iris[1].scale = Vector3(0.6 + ang, 1.0, 1.0)
	_eye_core.scale = Vector3.ONE * (0.8 + 0.4 * (1.0 - open) + speech * 0.2)
	_m_eye.emission_energy_multiplier = (1.4 + speech * 1.6) * (0.4 + 0.6 * open)
	_eye_light.light_energy = 0.3 + speech * 0.5
	_m_speaker.emission_energy_multiplier = 0.3 + speech * 4.0
	_beacon.emission_energy_multiplier = 1.0 + 2.5 * maxf(0.0, sin(_t * 3.5))
	for w in _wheels:
		w.rotation.x -= _speed * delta * 9.0
	if _ticket_out > 0.0:
		_ticket_out += delta
		var k := ModelKit.ramp(_ticket_out, 0.0, 0.6) * (1.0 - ModelKit.ramp(_ticket_out, 2.4, 2.8))
		_ticket.scale = Vector3(1, maxf(k, 0.001), 1)
		if _ticket_out > 2.8:
			_ticket_out = 0.0
