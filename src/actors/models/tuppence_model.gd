class_name TuppenceModel
extends Node3D
## Tuppence - Halcyon Valet Mk II. Brass barrel-bodied robot butler with a glass-dome head,
## filament face, bow tie, tea towel and a hovering thruster base. Built and animated in code.
## Origin at the floor, facing -Z, ~1.55 m tall (antenna bulb ~1.62 m).

signal gesture_finished(gesture_name: String)

const EYE_AMBER := Color(1.0, 0.58, 0.18)
const EYE_ZAP := Color(0.45, 0.88, 1.0)
const HOVER_H := 0.15
const WAIST_Y := 0.57
const SHOULDER_Y := 1.0
const SHOULDER_X := 0.285
const HEAD_Y := 1.165

const GESTURES := {
	"wave": 2.6, "bow": 2.2, "tea": 3.8, "polish": 3.6, "zap": 1.5,
	"fret": 2.8, "celebrate": 2.8, "point": 2.0, "curtains": 2.6, "nod": 1.1,
}

## 11-years-later look (tarnish, dent). Set before add_child or call set_aged().
var aged := false

# --- pose channels -------------------------------------------------------
enum { SP, SR, ST, EL, FT, WX, WZ, CURL, IDX, ARM_N }
const HY := 18
const HP := 19
const HR := 20
const BP := 21
const BR := 22
const BY := 23
const SPIN := 24
const LIFT := 25
const CH_N := 26

var _idle := PackedFloat32Array()
var _gp := PackedFloat32Array()
var _gm := PackedFloat32Array()
var _cur := PackedFloat32Array()

# --- rig -------------------------------------------------------------------
var _hover: Node3D
var _base: Node3D
var _torso: Node3D
var _head: Node3D
var _face: Node3D
var _eyes: Array[Node3D] = []
var _eye_glows: Array[MeshInstance3D] = []
var _brows: Array[Node3D] = []
var _mouth: Array[MeshInstance3D] = []
var _antenna: Node3D
var _key: Node3D
var _needle: Node3D
var _sh: Array[Node3D] = []
var _tw: Array[Node3D] = []
var _el: Array[Node3D] = []
var _ft: Array[Node3D] = []
var _wr: Array[Node3D] = []
var _hand_grip: Array[Node3D] = []
var _fing: Array[Node3D] = [] # [side*6 + finger*2 + seg]  finger 0 index, 1 middle, 2 thumb
var _towel_pivot: Node3D
var _towel: MeshInstance3D
var _rag: Node3D
var _cup: Node3D
var _steam: GPUParticles3D
var _thrust_light: OmniLight3D
var _head_light: OmniLight3D
var _torso_mesh: MeshInstance3D

# --- materials ---------------------------------------------------------------
var _m_eye: StandardMaterial3D
var _m_mouth: StandardMaterial3D
var _m_bulb: StandardMaterial3D
var _m_thrust: StandardMaterial3D
var _m_plume: ShaderMaterial
var _brass_list: Array[GeometryInstance3D] = []
var _copper_list: Array[GeometryInstance3D] = []
var _cream_list: Array[GeometryInstance3D] = []
var _torso_plain: Mesh
var _torso_dented: Mesh

# --- state -------------------------------------------------------------------
var _t := 0.0
var _speed := 0.0
var _speed_s := 0.0
var _talking := false
var _talk_amt := 0.0
var _talk_gest_t := 2.0
var _talk_gest_side := 1
var _talk_gest_age := 99.0
var _g_name := ""
var _g_t := 0.0
var _g_dur := 0.0
var _zap_fired := false
var _look_active := false
var _look_pos := Vector3.ZERO
var _look_w := 0.0
var _idle_head := Vector3.ZERO
var _idle_head_tgt := Vector3.ZERO
var _idle_head_timer := 1.0
var _blink_timer := 2.0
var _blink := 0.0
var _eye_col := EYE_AMBER
var _eye_col_user := EYE_AMBER
var _eye_cur := EYE_AMBER
var _happy := 0.0
var _worry := 0.0
var _expr_happy := 0.0
var _expr_worry := 0.0
var _hs := 0.0
var _ws := 0.0
var _mouth_lv := PackedFloat32Array()
var _ant_ang := Vector2.ZERO
var _ant_vel := Vector2.ZERO
var _prev_pos := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _prev_yaw := 0.0
var _towel_ang := 0.0
var _flicker := 0.0
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
	_mouth_lv.resize(7)
	_build()
	_apply_aged()
	_prev_pos = global_position
	_compute_idle(0.0)
	for i in CH_N:
		_cur[i] = _idle[i]
	_apply_pose()


# =============================================================================
# Public API
# =============================================================================

func set_aged(b: bool) -> void:
	aged = b
	if is_inside_tree() and _torso_mesh:
		_apply_aged()


## 0..1 travel speed: leans forward, thruster brighter, arms swing.
func set_move_speed(v: float) -> void:
	_speed = clampf(v, 0.0, 1.0)


func set_talking(b: bool) -> void:
	_talking = b


func is_talking() -> bool:
	return _talking


## Plays a named gesture; returns its duration (0 if unknown).
func play_gesture(gesture_name: String) -> float:
	if not GESTURES.has(gesture_name):
		push_warning("TuppenceModel: unknown gesture '%s'" % gesture_name)
		return 0.0
	if _g_name != "":
		_end_gesture()
	_g_name = gesture_name
	_g_t = 0.0
	_g_dur = GESTURES[gesture_name]
	_zap_fired = false
	return _g_dur


func is_gesturing() -> bool:
	return _g_name != ""


func look_at_point(world_pos: Vector3) -> void:
	_look_active = true
	_look_pos = world_pos


func clear_look() -> void:
	_look_active = false


func set_eye_color(c: Color) -> void:
	_eye_col_user = c


## Extra: "neutral", "happy", "worried".
func set_expression(expr: String) -> void:
	_expr_happy = 1.0 if expr == "happy" else 0.0
	_expr_worry = 1.0 if expr == "worried" else 0.0


func get_head_node() -> Node3D:
	return _head


func get_hand_node(right := true) -> Node3D:
	return _hand_grip[1 if right else 0]


# =============================================================================
# Build
# =============================================================================

func _brass() -> StandardMaterial3D:
	return ModelKit.brass(aged)


func _reg(list: Array[GeometryInstance3D], g: GeometryInstance3D) -> GeometryInstance3D:
	list.append(g)
	return g


func _b(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := ModelKit.mi(parent, mesh, ModelKit.brass(false), pos, rot, scl)
	_brass_list.append(m)
	return m


func _c(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := ModelKit.mi(parent, mesh, ModelKit.copper(false), pos, rot, scl)
	_copper_list.append(m)
	return m


func _cr(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := ModelKit.mi(parent, mesh, _cream_mat(false), pos, rot, scl)
	_cream_list.append(m)
	return m


func _cream_mat(old: bool) -> StandardMaterial3D:
	if old:
		var m := ModelKit.enamel("tup_cream_aged", Color(0.86, 0.80, 0.66), 0.42)
		if m.albedo_texture == null:
			m.albedo_texture = ModelKit.noise_tex("cream_grime", 0.02, ModelKit.grad([Color(0.82, 0.78, 0.7), Color(1, 1, 1)], [0.0, 0.6]))
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(2, 2, 2)
		return m
	return ModelKit.enamel("tup_cream", Color(0.93, 0.86, 0.70), 0.3)


const TORSO_PROFILE := [
	Vector2(0.0, 0.575), Vector2(0.172, 0.575), Vector2(0.172, 0.575), Vector2(0.186, 0.592),
	Vector2(0.214, 0.632), Vector2(0.240, 0.69), Vector2(0.256, 0.75), Vector2(0.264, 0.81),
	Vector2(0.266, 0.86), Vector2(0.261, 0.92), Vector2(0.248, 0.975), Vector2(0.228, 1.025),
	Vector2(0.204, 1.065), Vector2(0.184, 1.095), Vector2(0.170, 1.112), Vector2(0.170, 1.112),
	Vector2(0.0, 1.112),
]


func _torso_r(y: float) -> float:
	for i in range(2, TORSO_PROFILE.size() - 2):
		var a: Vector2 = TORSO_PROFILE[i]
		var b: Vector2 = TORSO_PROFILE[i + 1]
		if y >= a.y and y <= b.y and b.y > a.y:
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return 0.17


func _on_torso(y: float, ang: float, out := 0.0) -> Vector3:
	var r := _torso_r(y) + out
	return Vector3(sin(ang) * r, y, -cos(ang) * r)


func _build() -> void:
	_hover = ModelKit.pivot(self, "Hover")
	_base = ModelKit.pivot(_hover, "Base")
	_torso = ModelKit.pivot(_hover, "Torso", Vector3(0, WAIST_Y, 0))
	var tg := ModelKit.pivot(_torso, "TorsoGeo", Vector3(0, -WAIST_Y, 0))
	_build_base()
	_build_torso(tg)
	_head = ModelKit.pivot(tg, "Head", Vector3(0, HEAD_Y, 0))
	_head.scale = Vector3.ONE * 1.08
	_build_head(_head)
	for side in 2:
		_build_arm(tg, side)
	_build_props()


func _build_base() -> void:
	var cream := _cream_mat(false)
	# tapered enamel skirt
	var skirt := PackedVector2Array([
		Vector2(0.092, 0.205), Vector2(0.092, 0.205), Vector2(0.11, 0.25), Vector2(0.135, 0.32),
		Vector2(0.16, 0.40), Vector2(0.182, 0.47), Vector2(0.196, 0.52), Vector2(0.196, 0.52),
		Vector2(0.18, 0.535), Vector2(0.0, 0.535)])
	var sk := ModelKit.mi(_base, ModelKit.lathe(skirt, 40), cream)
	_cream_list.append(sk)
	# brass rim at top of skirt and collar at bottom
	_b(_base, ModelKit.torus(0.186, 0.206, 36, 6), Vector3(0, 0.522, 0))
	_b(_base, ModelKit.torus(0.084, 0.102, 28, 8), Vector3(0, 0.21, 0))
	# three vertical brass ribs
	for i in 3:
		var a := TAU * i / 3.0 + PI / 3.0
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for k in 6:
			var y := lerpf(0.23, 0.505, k / 5.0)
			var r := lerpf(0.104, 0.192, (y - 0.205) / 0.315) + 0.004
			pts.append(Vector3(sin(a) * r, y, -cos(a) * r))
			rad.append(0.009)
		_b(_base, ModelKit.tube(pts, rad, 6))
	# copper thruster nozzle
	var noz := PackedVector2Array([
		Vector2(0.05, 0.15), Vector2(0.075, 0.152), Vector2(0.09, 0.168), Vector2(0.095, 0.19),
		Vector2(0.094, 0.21), Vector2(0.094, 0.21), Vector2(0.06, 0.21), Vector2(0.0, 0.21)])
	_c(_base, ModelKit.lathe(noz, 32))
	# glowing thruster ring + core
	_m_thrust = ModelKit.glow("tup_thrust", Color(1.0, 0.55, 0.2), 4.0, true)
	ModelKit.mi(_base, ModelKit.torus(0.052, 0.074, 32, 8), _m_thrust, Vector3(0, 0.152, 0))
	ModelKit.mi(_base, ModelKit.cyl(0.052, 0.052, 0.004, 24), _m_thrust, Vector3(0, 0.151, 0))
	# soft additive plume under the nozzle
	_m_plume = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.5, 0.18, 1.0);
uniform float intensity = 1.0;
varying float vy;
void vertex() { vy = VERTEX.y; }
void fragment() {
	float f = clamp((vy + 0.07) / 0.14, 0.0, 1.0);
	float edge = abs(dot(NORMAL, VIEW));
	float a = f * f * f * edge * edge;
	ALBEDO = color.rgb * intensity * a;
	ALPHA = a;
}
"""
	_m_plume.shader = sh
	var plume := ModelKit.mi(_base, ModelKit.cyl(0.055, 0.1, 0.14, 24, false), _m_plume, Vector3(0, 0.08, 0))
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_thrust_light = OmniLight3D.new()
	_thrust_light.light_color = Color(1.0, 0.6, 0.3)
	_thrust_light.light_energy = 0.8
	_thrust_light.omni_range = 1.1
	_thrust_light.omni_attenuation = 1.6
	_thrust_light.position = Vector3(0, 0.1, 0)
	_thrust_light.shadow_enabled = false
	_base.add_child(_thrust_light)


func _build_torso(tg: Node3D) -> void:
	var rubber := ModelKit.rubber()
	# rubber waist gasket between skirt and barrel
	ModelKit.mi(tg, ModelKit.torus(0.15, 0.19, 32, 7), rubber, Vector3(0, 0.56, 0))
	# barrel body
	var prof := PackedVector2Array()
	for p in TORSO_PROFILE:
		prof.append(p)
	_torso_plain = ModelKit.lathe(prof, 48)
	_torso_dented = ModelKit.dent_mesh(_torso_plain, _on_torso(0.79, 1.15), 0.065, 0.014)
	_torso_mesh = _b(tg, _torso_plain)
	# copper bands
	_c(tg, ModelKit.torus(_torso_r(0.655) - 0.006, _torso_r(0.655) + 0.012, 48, 6), Vector3(0, 0.655, 0))
	_c(tg, ModelKit.torus(_torso_r(1.0) - 0.006, _torso_r(1.0) + 0.012, 48, 6), Vector3(0, 1.0, 0))
	# shoulder cap ring at the top
	_b(tg, ModelKit.torus(0.15, 0.185, 40, 6), Vector3(0, 1.11, 0))
	# rivets on the bands
	var rivs: Array[Transform3D] = []
	for band in [0.655, 1.0]:
		var by: float = band
		var r := _torso_r(by) + 0.012
		for i in 32:
			var a := TAU * (i + 0.5) / 32.0
			if band > 0.9 and absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.22:
				continue
			if band > 0.9 and absf(wrapf(a + PI * 0.5, -PI, PI)) < 0.22:
				continue
			var p := Vector3(sin(a) * r, by, -cos(a) * r)
			rivs.append(Transform3D(Basis(Quaternion(Vector3.UP, Vector3(sin(a), 0, -cos(a)))), p))
	var riv_mm := ModelKit.multimesh(tg, ModelKit.rivet(0.0065), ModelKit.brass(false), rivs)
	riv_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brass_list.append(riv_mm)
	# --- front cream panel (curved, proud of the barrel) ---
	var pa := 0.72
	var y0 := 0.70
	var y1 := 0.975
	var panel := PackedVector2Array()
	panel.append(Vector2(_torso_r(y0) - 0.003, y0))
	panel.append(Vector2(_torso_r(y0) + 0.005, y0))
	panel.append(Vector2(_torso_r(y0) + 0.005, y0))
	for k in 9:
		var y := lerpf(y0, y1, k / 8.0)
		panel.append(Vector2(_torso_r(y) + 0.005, y))
	panel.append(Vector2(_torso_r(y1) + 0.005, y1))
	panel.append(Vector2(_torso_r(y1) - 0.003, y1))
	_cr(tg, ModelKit.lathe(panel, 28, -pa, pa))
	# brass trim around the panel
	_trim_loop(tg, y0, y1, pa, 0.0075, 0.0055)
	# grille: dark recess + chrome slats following the curve
	var ga := 0.32
	var gy0 := 0.865
	var gy1 := 0.948
	var gprof := PackedVector2Array([Vector2(_torso_r(gy0) + 0.004, gy0), Vector2(_torso_r(gy0) + 0.007, gy0), Vector2(_torso_r(gy0) + 0.007, gy0),
		Vector2(_torso_r(gy1) + 0.007, gy1), Vector2(_torso_r(gy1) + 0.007, gy1), Vector2(_torso_r(gy1) + 0.004, gy1)])
	ModelKit.mi(tg, ModelKit.lathe(gprof, 16, -ga, ga), ModelKit.enamel("tup_black", Color(0.025, 0.022, 0.02), 0.35))
	for s in 5:
		var y := lerpf(gy0 + 0.012, gy1 - 0.012, s / 4.0)
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for k in 9:
			pts.append(_on_torso(y, lerpf(-ga + 0.02, ga - 0.02, k / 8.0), 0.011))
			rad.append(0.0042)
		ModelKit.mi(tg, ModelKit.tube(pts, rad, 6), ModelKit.chrome())
	_trim_loop(tg, gy0, gy1, ga, 0.012, 0.005)
	# pressure gauge (left of centre) with moving needle
	var gp := _on_torso(0.80, -0.2, 0.006)
	var gauge := ModelKit.pivot(tg, "Gauge", gp)
	gauge.basis = Basis.looking_at(Vector3(gp.x, -0.05, gp.z).normalized()) # local -Z points outward
	_b(gauge, ModelKit.torus(0.026, 0.034, 28, 8), Vector3(0, 0, -0.004), Vector3(90, 0, 0))
	ModelKit.mi(gauge, ModelKit.cyl(0.027, 0.027, 0.004, 24), _cream_mat(false), Vector3(0, 0, -0.002), Vector3(90, 0, 0))
	ModelKit.mi(gauge, ModelKit.cyl(0.006, 0.006, 0.004, 12), ModelKit.enamel("tup_red", Color(0.62, 0.06, 0.05), 0.3), Vector3(0.012, 0.012, -0.0045), Vector3(90, 0, 0))
	for k in 7:
		var ta := lerpf(-2.2, 2.2, k / 6.0)
		ModelKit.mi(gauge, ModelKit.box(Vector3(0.0018, 0.006, 0.001)), ModelKit.enamel("tup_black", Color(0.025, 0.022, 0.02), 0.35),
			Vector3(sin(ta) * 0.02, cos(ta) * 0.02, -0.0045), Vector3(0, 0, -rad_to_deg(ta)))
	_needle = ModelKit.pivot(gauge, "Needle", Vector3(0, 0, -0.006))
	ModelKit.mi(_needle, ModelKit.box(Vector3(0.0022, 0.022, 0.0012)), ModelKit.enamel("tup_red", Color(0.62, 0.06, 0.05), 0.3), Vector3(0, 0.009, 0))
	_b(_needle, ModelKit.cyl(0.003, 0.003, 0.003, 10), Vector3.ZERO, Vector3(90, 0, 0))
	ModelKit.mi(gauge, ModelKit.cyl(0.027, 0.027, 0.002, 24), ModelKit.glass("tup_gauge_glass", Color(0.9, 0.95, 1.0, 0.08)), Vector3(0, 0, -0.008), Vector3(90, 0, 0))
	# bakelite knobs (right of centre)
	for k in 2:
		var kp := _on_torso(0.815 - k * 0.0, 0.13 + k * 0.13, 0.004)
		var knob := ModelKit.pivot(tg, "Knob%d" % k, kp)
		knob.basis = Basis.looking_at(Vector3(kp.x, -0.05, kp.z).normalized())
		ModelKit.mi(knob, ModelKit.cyl(0.013, 0.016, 0.014, 16), ModelKit.enamel("tup_bakelite", Color(0.16, 0.05, 0.03), 0.25), Vector3(0, 0, -0.007), Vector3(90, 0, 0))
		_b(knob, ModelKit.cyl(0.0035, 0.0035, 0.003, 8), Vector3(0, 0.008, -0.0145), Vector3(90, 0, 0))
	# nameplate
	var np := _on_torso(0.735, 0.0, 0.006)
	var plate := ModelKit.pivot(tg, "Nameplate", np)
	plate.basis = Basis.looking_at(Vector3(0, -0.22, -1).normalized())
	_b(plate, ModelKit.rounded_box(Vector3(0.13, 0.03, 0.006), 0.0028, 2))
	var lbl := Label3D.new()
	lbl.text = "TUPPENCE"
	lbl.font_size = 48
	lbl.pixel_size = 0.00042
	lbl.outline_size = 0
	lbl.modulate = Color(0.10, 0.06, 0.03)
	lbl.shaded = true
	lbl.double_sided = false
	lbl.position = Vector3(0, -0.0005, -0.0035)
	lbl.rotation_degrees = Vector3(0, 180, 0)
	lbl.no_depth_test = false
	plate.add_child(lbl)
	for sx in [-1.0, 1.0]:
		_b(plate, ModelKit.hemisphere(0.0025, 8, 3), Vector3(sx * 0.058, 0, -0.003), Vector3(-90, 0, 0))
	# shoulder sockets
	for side in 2:
		var sx := -1.0 if side == 0 else 1.0
		var sock := ModelKit.pivot(tg, "Socket%d" % side, Vector3(sx * (SHOULDER_X - 0.035), SHOULDER_Y, 0))
		_c(sock, ModelKit.cyl(0.066, 0.066, 0.03, 28), Vector3.ZERO, Vector3(0, 0, 90))
		_b(sock, ModelKit.torus(0.058, 0.07, 28, 6), Vector3(sx * 0.014, 0, 0), Vector3(0, 0, 90))
	# back hatch + wind-up key
	var hp := _on_torso(0.84, PI, 0.002)
	var hatch := ModelKit.pivot(tg, "Hatch", hp)
	hatch.basis = Basis.looking_at(Vector3(0, 0, -1)) # local -Z points toward body
	_b(hatch, ModelKit.rounded_box(Vector3(0.12, 0.14, 0.01), 0.008, 2), Vector3(0, 0, 0.002))
	for cx in [-1.0, 1.0]:
		for cy in [-1.0, 1.0]:
			_b(hatch, ModelKit.hemisphere(0.004, 8, 3), Vector3(cx * 0.049, cy * 0.059, 0.007), Vector3(90, 0, 0))
	_key = ModelKit.pivot(hatch, "Key", Vector3(0, 0, 0.007))
	_b(_key, ModelKit.cyl(0.009, 0.009, 0.06, 12), Vector3(0, 0, 0.03), Vector3(90, 0, 0))
	_b(_key, ModelKit.cyl(0.016, 0.016, 0.01, 16), Vector3(0, 0, 0.012), Vector3(90, 0, 0))
	for sgn in [-1.0, 1.0]:
		_b(_key, ModelKit.torus(0.018, 0.03, 24, 8), Vector3(sgn * 0.034, 0.0, 0.07), Vector3(0, 0, 0), Vector3(1, 1, 1))
	_b(_key, ModelKit.cyl(0.008, 0.008, 0.04, 10), Vector3(0, 0, 0.07), Vector3(0, 0, 90))
	# neck: rubber bellows + bow tie
	for k in 3:
		ModelKit.mi(tg, ModelKit.torus(0.05, 0.078, 20, 6), rubber, Vector3(0, 1.122 + k * 0.016, 0))
	_build_bowtie(tg)


func _trim_loop(parent: Node3D, y0: float, y1: float, ang: float, out: float, r: float) -> void:
	var pts := PackedVector3Array()
	var steps := 14
	for k in steps + 1:
		pts.append(_on_torso(y0, lerpf(-ang, ang, float(k) / steps), out))
	for k in range(1, 9):
		pts.append(_on_torso(lerpf(y0, y1, k / 8.0), ang, out))
	for k in range(1, steps + 1):
		pts.append(_on_torso(y1, lerpf(ang, -ang, float(k) / steps), out))
	for k in range(1, 9):
		pts.append(_on_torso(lerpf(y1, y0, k / 8.0), -ang, out))
	var rad := PackedFloat32Array()
	for i in pts.size():
		rad.append(r)
	_b(parent, ModelKit.tube(pts, rad, 6, false))


func _build_bowtie(tg: Node3D) -> void:
	var satin := ModelKit.pbr("tup_bowtie", Color(0.42, 0.04, 0.06), 0.0, 0.42)
	satin.clearcoat_enabled = true
	satin.clearcoat = 0.3
	var bow := ModelKit.pivot(tg, "BowTie", Vector3(0, 1.128, -0.083))
	bow.rotation_degrees = Vector3(-12, 0, 0)
	for sx in [-1.0, 1.0]:
		var w := ModelKit.mi(bow, ModelKit.cyl(0.009, 0.026, 0.046, 4), satin, Vector3(sx * 0.026, 0, 0), Vector3(45, 0, sx * 90.0))
		w.scale = Vector3(1, 1, 0.55)
	ModelKit.mi(bow, ModelKit.rounded_box(Vector3(0.02, 0.021, 0.014), 0.005, 2), satin, Vector3(0, 0, -0.004))


func _build_head(h: Node3D) -> void:
	# brass collar
	var collar := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.088, 0.0), Vector2(0.122, 0.012), Vector2(0.145, 0.032),
		Vector2(0.154, 0.052), Vector2(0.155, 0.072), Vector2(0.155, 0.072), Vector2(0.146, 0.076), Vector2(0.0, 0.076)])
	_b(h, ModelKit.lathe(collar, 48))
	_c(h, ModelKit.torus(0.150, 0.162, 40, 5), Vector3(0, 0.062, 0))
	var rivs: Array[Transform3D] = []
	for i in 20:
		var a := TAU * (i + 0.5) / 20.0
		if absf(sin(a)) > 0.9:
			continue
		rivs.append(Transform3D(Basis(Quaternion(Vector3.UP, Vector3(sin(a), 0.6, -cos(a)).normalized())), Vector3(sin(a) * 0.137, 0.024, -cos(a) * 0.137)))
	var rm := ModelKit.multimesh(h, ModelKit.rivet(0.0055), ModelKit.brass(false), rivs)
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brass_list.append(rm)
	# dark floor inside the bell jar
	ModelKit.mi(h, ModelKit.cyl(0.142, 0.142, 0.004, 40), ModelKit.pbr("tup_floor", Color(0.05, 0.045, 0.04), 0.0, 0.7), Vector3(0, 0.077, 0))
	# ear cans
	for sx in [-1.0, 1.0]:
		var ear := ModelKit.pivot(h, "Ear", Vector3(sx * 0.155, 0.05, 0.0))
		_b(ear, ModelKit.cyl(0.04, 0.044, 0.034, 28), Vector3(sx * 0.01, 0, 0), Vector3(0, 0, 90))
		ModelKit.mi(ear, ModelKit.cyl(0.032, 0.032, 0.004, 24), ModelKit.enamel("tup_black", Color(0.025, 0.022, 0.02), 0.35), Vector3(sx * 0.0275, 0, 0), Vector3(0, 0, 90))
		for rr in [0.014, 0.024]:
			var rf: float = rr
			ModelKit.mi(ear, ModelKit.torus(rf - 0.0025, rf + 0.0015, 20, 4), ModelKit.chrome(), Vector3(sx * 0.029, 0, 0), Vector3(0, 0, 90))
		_b(ear, ModelKit.sphere(0.007, 10, 6), Vector3(sx * 0.03, 0, 0))
	# face assembly inside the dome
	_face = ModelKit.pivot(h, "Face", Vector3(0, 0.168, 0.0))
	var dark := ModelKit.pbr("tup_face", Color(0.035, 0.03, 0.028), 0.0, 0.32)
	var dish := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.088, 0.0), Vector2(0.088, 0.0), Vector2(0.09, 0.006), Vector2(0.088, 0.012),
		Vector2(0.088, 0.012), Vector2(0.075, 0.011), Vector2(0.04, 0.006), Vector2(0.0, 0.0045)])
	var plate := ModelKit.mi(_face, ModelKit.lathe(dish, 40), dark, Vector3(0, 0, 0.012), Vector3(-90, 0, 0))
	plate.name = "FacePlate"
	_b(_face, ModelKit.torus(0.085, 0.096, 40, 6), Vector3(0, 0, 0.006), Vector3(90, 0, 0))
	_b(_face, ModelKit.cyl(0.092, 0.092, 0.008, 40), Vector3(0, 0, 0.017), Vector3(90, 0, 0))
	# filament support posts (valve look)
	for sx in [-1.0, 1.0]:
		_c(_face, ModelKit.cyl(0.0025, 0.0025, 0.1, 6), Vector3(sx * 0.07, -0.06, 0.02))
	_m_eye = ModelKit.glow("tup_eye", EYE_AMBER, 5.0, true)
	for side in 2:
		var sx := -1.0 if side == 0 else 1.0
		var eye := ModelKit.pivot(_face, "Eye%d" % side, Vector3(sx * 0.04, 0.016, 0.0))
		_b(eye, ModelKit.torus(0.0205, 0.0265, 28, 5), Vector3(0, 0, 0.002), Vector3(90, 0, 0))
		var g := ModelKit.mi(eye, ModelKit.sphere(0.0195, 20, 8), _m_eye, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.3))
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# filament coil glint inside the eye
		var coil := ModelKit.mi(eye, ModelKit.torus(0.004, 0.0058, 12, 4), ModelKit.glow("tup_filament", Color(1.0, 0.85, 0.6), 4.5), Vector3(0, 0, -0.006), Vector3(90, 0, 0))
		coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eyes.append(eye)
		_eye_glows.append(g)
	_m_mouth = ModelKit.glow("tup_mouth", EYE_AMBER, 3.0, true)
	# glowing eyebrow bars (expressions)
	for side in 2:
		var sx := -1.0 if side == 0 else 1.0
		var bp := ModelKit.pivot(_face, "Brow%d" % side, Vector3(sx * 0.04, 0.049, 0.0))
		var bm := ModelKit.mi(bp, ModelKit.capsule(0.0028, 0.03, 8, 2), _m_mouth, Vector3.ZERO, Vector3(0, 0, 90))
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_brows.append(bp)
	for i in 7:
		var x := (i - 3) * 0.0068
		var seg := ModelKit.mi(_face, ModelKit.capsule(0.0046, 0.016, 8, 2), _m_mouth, Vector3(x, -0.046, 0.0))
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mouth.append(seg)
	_head_light = OmniLight3D.new()
	_head_light.light_color = Color(1.0, 0.7, 0.4)
	_head_light.light_energy = 0.2
	_head_light.omni_range = 0.32
	_head_light.position = Vector3(0, 0.2, -0.11)
	_head_light.shadow_enabled = false
	h.add_child(_head_light)
	# glass dome
	var dome := PackedVector2Array()
	dome.append(Vector2(0.146, 0.072))
	for k in range(0, 13):
		var phi := float(k) / 12.0 * PI * 0.5
		dome.append(Vector2(0.146 * cos(phi), 0.074 + 0.225 * sin(phi)))
	var dm := ModelKit.mi(h, ModelKit.lathe(dome, 36), ModelKit.glass("tup_dome", Color(0.92, 0.95, 1.0, 0.07)))
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dm.name = "Dome"
	# finial + springy antenna
	var fin := PackedVector2Array([Vector2(0.0, 0.29), Vector2(0.03, 0.29), Vector2(0.032, 0.296), Vector2(0.024, 0.306), Vector2(0.011, 0.314), Vector2(0.009, 0.322), Vector2(0.0, 0.324)])
	_b(h, ModelKit.lathe(fin, 24))
	_antenna = ModelKit.pivot(h, "Antenna", Vector3(0, 0.318, 0))
	ModelKit.mi(_antenna, ModelKit.cyl(0.0028, 0.0035, 0.095, 8), ModelKit.chrome(), Vector3(0, 0.047, 0))
	_b(_antenna, ModelKit.cyl(0.006, 0.0045, 0.008, 12), Vector3(0, 0.094, 0))
	_m_bulb = ModelKit.glow("tup_bulb", Color(1.0, 0.35, 0.15), 3.0, true)
	ModelKit.mi(_antenna, ModelKit.sphere(0.0125, 16, 8), _m_bulb, Vector3(0, 0.108, 0))


func _build_arm(tg: Node3D, side: int) -> void:
	var sx := -1.0 if side == 0 else 1.0
	var rubber := ModelKit.rubber()
	var sh := ModelKit.pivot(tg, "Shoulder%d" % side, Vector3(sx * SHOULDER_X, SHOULDER_Y, 0))
	_b(sh, ModelKit.sphere(0.047, 16, 10))
	var tw := ModelKit.pivot(sh, "Twist")
	# upper arm: brass tube with a cream enamel sleeve band
	_b(tw, ModelKit.cyl(0.03, 0.027, 0.17, 18), Vector3(0, -0.1, 0))
	_cr(tw, ModelKit.cyl(0.0325, 0.0325, 0.05, 18), Vector3(0, -0.075, 0))
	_c(tw, ModelKit.torus(0.029, 0.036, 16, 5), Vector3(0, -0.05, 0))
	_c(tw, ModelKit.torus(0.029, 0.036, 16, 5), Vector3(0, -0.1, 0))
	var el := ModelKit.pivot(tw, "Elbow", Vector3(0, -0.205, 0))
	ModelKit.mi(el, ModelKit.sphere(0.033, 12, 8), rubber)
	_b(el, ModelKit.cyl(0.036, 0.036, 0.016, 18), Vector3.ZERO, Vector3(0, 0, 90))
	var ft := ModelKit.pivot(el, "Forearm")
	# forearm: tapered brass with flared cuff
	var fa := PackedVector2Array([Vector2(0.0, -0.182), Vector2(0.03, -0.182), Vector2(0.039, -0.178), Vector2(0.039, -0.178),
		Vector2(0.037, -0.17), Vector2(0.03, -0.15), Vector2(0.027, -0.12), Vector2(0.028, -0.06), Vector2(0.026, -0.03), Vector2(0.0, -0.03)])
	_b(ft, ModelKit.lathe(fa, 20))
	_cr(ft, ModelKit.cyl(0.0305, 0.0305, 0.03, 18), Vector3(0, -0.085, 0))
	var wr := ModelKit.pivot(ft, "Wrist", Vector3(0, -0.188, 0))
	ModelKit.mi(wr, ModelKit.sphere(0.02, 10, 6), rubber)
	# hand
	var palm := ModelKit.pivot(wr, "Palm", Vector3(0, -0.035, 0))
	_b(palm, ModelKit.rounded_box(Vector3(0.026, 0.052, 0.052), 0.011, 2))
	var grip := ModelKit.pivot(palm, "Grip", Vector3(-sx * 0.03, -0.012, 0))
	_hand_grip.append(grip)
	var finger_pos := [Vector3(0, -0.026, -0.0145), Vector3(0, -0.026, 0.0145), Vector3(-sx * 0.009, -0.0, -0.028)]
	for f in 3:
		var base := ModelKit.pivot(palm, "Finger%d" % f, finger_pos[f])
		if f == 2:
			base.rotation_degrees = Vector3(-55, 0, 0)
		var l1 := 0.026 if f < 2 else 0.022
		var l2 := 0.022 if f < 2 else 0.018
		_c(base, ModelKit.capsule(0.0085, l1 + 0.017, 8, 2), Vector3(0, -l1 * 0.5, 0))
		var seg2 := ModelKit.pivot(base, "Tip", Vector3(0, -l1, 0))
		_c(seg2, ModelKit.capsule(0.0078, l2 + 0.012, 8, 2), Vector3(0, -l2 * 0.45, 0))
		ModelKit.mi(seg2, ModelKit.sphere(0.0084, 8, 4), rubber, Vector3(0, -l2 * 0.9, 0), Vector3.ZERO, Vector3(1, 1.1, 1))
		_fing.append(base)
		_fing.append(seg2)
	_sh.append(sh)
	_tw.append(tw)
	_el.append(el)
	_ft.append(ft)
	_wr.append(wr)


func _build_props() -> void:
	# --- tea towel draped over the left forearm (green gingham) ---
	var cloth := StandardMaterial3D.new()
	var tex := ModelKit.load_tex("res://assets/textures/gingham_check/gingham_check_diff.jpg")
	if tex:
		cloth.albedo_texture = tex
	cloth.albedo_color = Color(1, 1, 1)
	cloth.roughness = 0.95
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.uv1_scale = Vector3(1.6, 1.6, 1)
	var nrm := ModelKit.load_tex("res://assets/textures/gingham_check/gingham_check_nor_gl.jpg")
	if nrm:
		cloth.normal_enabled = true
		cloth.normal_texture = nrm
	cloth.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	ModelKit.put_mat("tup_towel", cloth)
	_towel_pivot = ModelKit.pivot(_ft[0], "TowelPivot", Vector3(0, -0.105, 0))
	_towel = ModelKit.mi(_towel_pivot, _towel_mesh(), cloth)
	# --- polishing rag (right hand; shown during "polish") ---
	_rag = ModelKit.pivot(_hand_grip[1], "Rag")
	var rag_m := ModelKit.mi(_rag, _rag_mesh(), cloth, Vector3(0.0, -0.01, 0))
	rag_m.rotation_degrees = Vector3(0, 0, 90)
	_rag.scale = Vector3.ONE * 0.001
	_rag.visible = false
	# --- teacup + saucer (right hand; shown during "tea") ---
	_cup = ModelKit.pivot(_hand_grip[1], "TeaCup")
	_cup.rotation_degrees = Vector3(0, 0, 90)
	var cup_root := ModelKit.pivot(_cup, "CupRoot", Vector3(0, 0.004, 0))
	var china := ModelKit.enamel("tup_china", Color(0.96, 0.95, 0.92), 0.12)
	var saucer := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.032, 0.002), Vector2(0.06, 0.009),
		Vector2(0.066, 0.013), Vector2(0.066, 0.013), Vector2(0.063, 0.014), Vector2(0.036, 0.008), Vector2(0.0, 0.007)])
	ModelKit.mi(cup_root, ModelKit.lathe(saucer, 32), china)
	_b(cup_root, ModelKit.torus(0.0625, 0.0665, 32, 4), Vector3(0, 0.0125, 0))
	var cup := PackedVector2Array([Vector2(0.0, 0.008), Vector2(0.018, 0.008), Vector2(0.02, 0.011), Vector2(0.022, 0.011),
		Vector2(0.03, 0.022), Vector2(0.037, 0.04), Vector2(0.041, 0.056), Vector2(0.041, 0.056), Vector2(0.038, 0.056),
		Vector2(0.035, 0.042), Vector2(0.028, 0.026), Vector2(0.0, 0.022)])
	ModelKit.mi(cup_root, ModelKit.lathe(cup, 32), china)
	_b(cup_root, ModelKit.torus(0.037, 0.042, 32, 4), Vector3(0, 0.0555, 0))
	ModelKit.mi(cup_root, ModelKit.torus(0.009, 0.0135, 16, 6), china, Vector3(0.042, 0.036, 0), Vector3(90, 0, 0))
	var tea := ModelKit.pbr("tup_tea", Color(0.28, 0.12, 0.04), 0.0, 0.05)
	ModelKit.mi(cup_root, ModelKit.cyl(0.036, 0.036, 0.002, 24), tea, Vector3(0, 0.047, 0))
	_steam = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.04
	pm.initial_velocity_max = 0.08
	pm.gravity = Vector3(0, 0.04, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var cr := GradientTexture1D.new()
	cr.gradient = ModelKit.grad([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0)], [0.0, 0.3, 1.0])
	pm.color_ramp = cr
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.2
	pm.turbulence_noise_scale = 0.4
	_steam.process_material = pm
	_steam.amount = 14
	_steam.lifetime = 1.6
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = _soft_dot()
	sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = sm
	_steam.draw_pass_1 = q
	_steam.local_coords = false
	_steam.emitting = false
	_steam.position = Vector3(0, 0.05, 0)
	_steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cup_root.add_child(_steam)
	_cup.scale = Vector3.ONE * 0.001
	_cup.visible = false


func _soft_dot() -> Texture2D:
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	g.gradient = ModelKit.grad([Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 1.0])
	g.width = 32
	g.height = 32
	return g


## Tea towel draped over a bar along local Y (the forearm). Hangs toward +X of its pivot.
func _towel_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rb := 0.036
	var l1 := 0.17
	var l2 := 0.12
	var w := 0.075
	var cols := 8
	var sect := PackedVector2Array() # (x,z) cross-section, s param
	var steps1 := 8
	for k in steps1 + 1:
		var x := l1 * (1.0 - float(k) / steps1)
		sect.append(Vector2(x, -rb - x * 0.18))
	for k in range(1, 8):
		var t := float(k) / 8.0 * PI
		sect.append(Vector2(-rb * sin(t), -rb * cos(t)))
	var steps2 := 6
	for k in steps2 + 1:
		var x := l2 * float(k) / steps2
		sect.append(Vector2(x, rb + x * 0.12))
	var n := sect.size()
	var acc := PackedFloat32Array()
	acc.resize(n)
	for i in range(1, n):
		acc[i] = acc[i - 1] + sect[i].distance_to(sect[i - 1])
	var grid: Array[PackedVector3Array] = []
	for c in cols + 1:
		var y := lerpf(-w, w, float(c) / cols)
		var row := PackedVector3Array()
		for i in n:
			var p := sect[i]
			var hang := clampf(p.x / l1, 0.0, 1.0)
			var wave := sin(y * 55.0 + float(i) * 0.3) * 0.006 * hang
			var flare := y * 0.25 * hang
			row.append(Vector3(p.x, y + flare, p.y + wave * signf(p.y)))
		grid.append(row)
	for c in cols:
		for i in n - 1:
			var a := grid[c][i]
			var b := grid[c + 1][i]
			var cc := grid[c][i + 1]
			var d := grid[c + 1][i + 1]
			var nrm := (b - a).cross(cc - a).normalized()
			var ua := Vector2(float(c) / cols, acc[i] / acc[n - 1])
			var ub := Vector2(float(c + 1) / cols, acc[i] / acc[n - 1])
			var uc := Vector2(float(c) / cols, acc[i + 1] / acc[n - 1])
			var ud := Vector2(float(c + 1) / cols, acc[i + 1] / acc[n - 1])
			ModelKit.tri(st, a, b, cc, nrm, nrm, nrm, ua, ub, uc)
			ModelKit.tri(st, cc, b, d, nrm, nrm, nrm, uc, ub, ud)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _rag_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6
	for i in n:
		for j in n:
			var p := func(a: int, b: int) -> Vector3:
				var u := float(a) / n - 0.5
				var v := float(b) / n - 0.5
				return Vector3(u * 0.09, -0.012 * (1.0 - 4.0 * (u * u + v * v)) + sin(u * 20.0) * 0.004, v * 0.07)
			var a: Vector3 = p.call(i, j)
			var b: Vector3 = p.call(i + 1, j)
			var c: Vector3 = p.call(i, j + 1)
			var d: Vector3 = p.call(i + 1, j + 1)
			var nn := (c - a).cross(b - a).normalized()
			ModelKit.tri(st, a, b, c, nn, nn, nn, Vector2(float(i) / n, float(j) / n), Vector2(float(i + 1) / n, float(j) / n), Vector2(float(i) / n, float(j + 1) / n))
			ModelKit.tri(st, c, b, d, nn, nn, nn, Vector2(float(i) / n, float(j + 1) / n), Vector2(float(i + 1) / n, float(j) / n), Vector2(float(i + 1) / n, float(j + 1) / n))
	st.generate_normals()
	return st.commit()


func _apply_aged() -> void:
	var bm := ModelKit.brass(aged)
	for g in _brass_list:
		g.material_override = bm
	var cm := ModelKit.copper(aged)
	for g in _copper_list:
		g.material_override = cm
	var em := _cream_mat(aged)
	for g in _cream_list:
		g.material_override = em
	_torso_mesh.mesh = _torso_dented if aged else _torso_plain
	var tm := ModelKit.get_mat("tup_towel") as StandardMaterial3D
	if tm and aged:
		var old := tm.duplicate() as StandardMaterial3D
		old.albedo_color = Color(0.82, 0.8, 0.72)
		_towel.material_override = old


# =============================================================================
# Animation
# =============================================================================

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	_speed_s = ModelKit.damp(_speed_s, _speed, 3.0, delta)
	_talk_amt = ModelKit.damp(_talk_amt, 1.0 if _talking else 0.0, 6.0, delta)
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
			w = ModelKit.env(_g_t, 0.0, 0.32, _g_dur - 0.4, _g_dur)
	for i in CH_N:
		var tgt: float
		if i < HY:
			tgt = lerpf(_idle[i], _gp[i], w * _gm[i])
		else:
			tgt = _idle[i] + _gp[i] * w
		_cur[i] = ModelKit.damp(_cur[i], tgt, 16.0, delta)
	_apply_pose()
	_update_face(delta)
	_update_secondary(delta)


func _end_gesture() -> void:
	var n := _g_name
	_g_name = ""
	_g_t = 0.0
	_cup.visible = false
	_cup.scale = Vector3.ONE * 0.001
	_steam.emitting = false
	_rag.visible = false
	_towel.visible = true
	gesture_finished.emit(n)


func _nz(x: float, y := 0.0) -> float:
	return _noise.get_noise_2d(x, y)


func _compute_idle(delta: float) -> void:
	var t := _t
	var spd := _speed_s
	# --- arms: right relaxed, left in butler pose carrying the towel ---
	var swing := sin(t * (2.0 + spd * 3.0)) * spd
	var talk := _talk_amt
	# occasional talking hand gesture (one arm lifts, palm open, then settles)
	_talk_gest_age += delta
	_talk_gest_t -= delta
	if _talking and _talk_gest_t <= 0.0 and _g_name == "":
		_talk_gest_t = _rng.randf_range(2.4, 5.0)
		_talk_gest_age = 0.0
		_talk_gest_side = 1 if _rng.randf() < 0.7 else 0
	var tg := ModelKit.env(_talk_gest_age, 0.0, 0.45, 1.3, 2.0) * talk
	for side in 2:
		var o := side * ARM_N
		var ph := float(side) * 1.7
		var drift := _nz(t * 0.35 + ph, 3.0)
		var drift2 := _nz(t * 0.27 + ph, 7.0)
		if side == 1:
			_idle[o + SP] = 0.1 + drift * 0.08 - swing * 0.28
			_idle[o + SR] = 0.15 + drift2 * 0.05 + spd * 0.06
			_idle[o + ST] = 0.1
			_idle[o + EL] = 0.38 + drift2 * 0.1 + spd * 0.2
			_idle[o + FT] = 0.0
			_idle[o + WX] = 0.15 + drift * 0.1
			_idle[o + WZ] = 0.0
			_idle[o + CURL] = 0.4 + drift * 0.1
			_idle[o + IDX] = 0.3 + drift * 0.1
		else:
			_idle[o + SP] = 0.18 + drift * 0.04 + swing * 0.12
			_idle[o + SR] = 0.12 + drift2 * 0.03
			_idle[o + ST] = 0.62
			_idle[o + EL] = 1.5 + drift2 * 0.05
			_idle[o + FT] = 0.0
			_idle[o + WX] = 0.05
			_idle[o + WZ] = 0.15
			_idle[o + CURL] = 0.5
			_idle[o + IDX] = 0.45
		if side == _talk_gest_side and tg > 0.0:
			var k := tg * (0.7 + 0.3 * sin(_talk_gest_age * 5.0))
			_idle[o + SP] += 0.35 * k
			_idle[o + EL] += (0.9 if side == 1 else 0.1) * k
			_idle[o + FT] += -0.9 * k
			_idle[o + CURL] -= 0.3 * k
			_idle[o + SR] += 0.1 * k
	# --- head: look target, random tilts, talking bob ---
	_idle_head_timer -= delta
	if _idle_head_timer <= 0.0:
		_idle_head_timer = _rng.randf_range(1.6, 4.5)
		_idle_head_tgt = Vector3(_rng.randf_range(-0.12, 0.08), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.13, 0.13))
		if _look_active:
			_idle_head_tgt *= 0.35
	_idle_head = ModelKit.damp_v3(_idle_head, _idle_head_tgt, 2.2, delta)
	var look := Vector2.ZERO
	_look_w = ModelKit.damp(_look_w, 1.0 if _look_active else 0.0, 4.0, delta)
	if _look_w > 0.001 and _head.is_inside_tree():
		var tb := _torso.global_transform.basis.orthonormalized()
		var d := tb.inverse() * (_look_pos - _head.global_position - tb.y * 0.17)
		var yaw := atan2(-d.x, -d.z)
		var pitch := atan2(d.y, Vector2(d.x, d.z).length())
		look = Vector2(clampf(yaw, -1.25, 1.25), clampf(pitch, -0.6, 0.55)) * _look_w
	var bob := sin(t * 7.5) * 0.03 * talk + _nz(t * 3.0, 11.0) * 0.03 * talk
	_idle[HY] = look.x + _idle_head.y
	_idle[HP] = look.y + _idle_head.x + bob - spd * 0.05
	_idle[HR] = _idle_head.z + sin(t * 0.7) * 0.02
	_idle[BP] = -0.03 * talk + _nz(t * 0.4, 13.0) * 0.02
	_idle[BR] = _nz(t * 0.3, 17.0) * 0.025
	_idle[BY] = look.x * 0.18 + _nz(t * 0.25, 19.0) * 0.04
	_idle[SPIN] = 0.0
	_idle[LIFT] = 0.0


func _set_arm(side: int, ch: int, v: float) -> void:
	_gp[side * ARM_N + ch] = v
	_gm[side * ARM_N + ch] = 1.0


func _arm_pose(side: int, sp: float, sr: float, st: float, el: float, ft := 0.0, wx := 0.0, wz := 0.0, curl := 0.3, idx := -1.0) -> void:
	_set_arm(side, SP, sp)
	_set_arm(side, SR, sr)
	_set_arm(side, ST, st)
	_set_arm(side, EL, el)
	_set_arm(side, FT, ft)
	_set_arm(side, WX, wx)
	_set_arm(side, WZ, wz)
	_set_arm(side, CURL, curl)
	_set_arm(side, IDX, curl if idx < 0.0 else idx)


func _eval_gesture(g: String, t: float, dur: float) -> void:
	match g:
		"wave":
			var osc := sin((t - 0.3) * 9.0) * ModelKit.env(t, 0.35, 0.6, dur - 0.6, dur - 0.3)
			_arm_pose(1, 0.3, 1.32, -1.5, 1.45 + osc * 0.32, 0.0, 0.0, osc * 0.25, 0.05)
			_gp[HR] = 0.14
			_gp[HY] = -0.08
			_gp[BR] = -0.04
			_happy = 1.0
		"bow":
			var k := ModelKit.env(t, 0.2, 0.75, 1.25, 1.95)
			_arm_pose(1, 0.55, -0.05, 0.85, 1.65, 0.0, 0.2, 0.0, 0.3)
			_arm_pose(0, -0.35, 0.12, 0.0, 0.45, 0.0, 0.0, 0.0, 0.4)
			_gp[BP] = -0.45 * k
			_gp[HP] = -0.2 * k
		"tea":
			_arm_pose(1, 0.62, 0.02, 0.55, 1.05, -1.5, -0.1, 0.0, 0.15)
			var k := ModelKit.env(t, 0.3, 0.8, dur - 0.9, dur - 0.4)
			_gp[BP] = -0.1 * k
			_gp[HP] = -0.22 * ModelKit.env(t, 0.3, 0.7, 1.3, 1.8) + 0.05 * k
			_gp[HR] = 0.1 * ModelKit.env(t, 1.4, 1.8, dur - 0.8, dur - 0.3)
			_happy = ModelKit.env(t, 1.2, 1.6, dur - 0.6, dur)
		"polish":
			var w := TAU * 1.5 * t
			var k := ModelKit.env(t, 0.4, 0.7, dur - 0.6, dur - 0.3)
			_arm_pose(1, 0.72 + cos(w) * 0.16 * k, 0.05, 0.35 + sin(w) * 0.32 * k, 0.95 - cos(w) * 0.12 * k, -0.4, 0.35, 0.0, 0.6)
			_gp[HP] = -0.3
			_gp[HY] = -0.12 + sin(w) * 0.05 * k
			_gp[HR] = 0.1
			_gp[BP] = -0.12
			_gp[BY] = sin(w) * 0.04 * k
			_happy = 0.7
		"zap":
			var wind := ModelKit.env(t, 0.0, 0.3, 0.38, 0.5)
			var thrust := ModelKit.ramp(t, 0.36, 0.48)
			_arm_pose(1, lerpf(0.4 + 0.3 * wind, 1.52, thrust), 0.08, 0.05, lerpf(1.5, 0.04, thrust), lerpf(-0.3, -1.2, thrust), lerpf(-0.3, 0.15, thrust), 0.0, lerpf(0.7, 0.0, thrust))
			var recoil := ModelKit.env(t, 0.45, 0.5, 0.7, 1.0)
			_gp[BP] = 0.06 * wind + 0.08 * recoil
			_gp[HP] = 0.02
			_gp[LIFT] = 0.03 * recoil
			if t > 0.45 and not _zap_fired:
				_zap_fired = true
				_fire_zap()
			_eye_col = EYE_ZAP if t > 0.25 and t < dur - 0.3 else _eye_col_user
		"fret":
			var w := TAU * 2.2 * t
			for side in 2:
				var s := 1.0 if side == 1 else -1.0
				_arm_pose(side, 0.72, -0.08, 0.85, 1.6, sin(w + s) * 0.45, 0.25 * sin(w * 0.5 + s), 0.0, 0.65)
			var sh := ModelKit.env(t, 0.3, 0.6, dur - 0.6, dur - 0.2)
			_gp[HY] = sin(TAU * 1.7 * t) * 0.32 * sh
			_gp[HP] = -0.12
			_gp[BP] = -0.05
			_gp[BR] = sin(t * 31.0) * 0.012
			_worry = 1.0
		"celebrate":
			var pump := sin(t * 11.0) * ModelKit.env(t, 0.4, 0.6, dur - 0.7, dur - 0.4)
			for side in 2:
				_arm_pose(side, 2.55 + pump * 0.12, 0.42, 0.2, 0.35 - pump * 0.2, 0.0, 0.0, 0.0, 0.1)
			_gp[SPIN] = TAU * ModelKit.ramp(t, 0.55, 1.9)
			_gp[LIFT] = 0.09 * ModelKit.env(t, 0.3, 0.8, 1.7, 2.3) + absf(pump) * 0.02
			_gp[HP] = 0.18
			_happy = 1.0
		"point":
			_arm_pose(1, 1.45, 0.06, 0.1, 0.06, -0.15, 0.05, 0.0, 0.95, 0.0)
			_gp[BP] = -0.05
			_gp[BY] = -0.08
			_gp[HP] = 0.04
		"curtains":
			var p := ModelKit.ramp(t, 0.7, 1.5)
			for side in 2:
				_arm_pose(side, lerpf(1.15, 0.95, p), lerpf(-0.42, 1.25, p), lerpf(0.5, -0.3, p), lerpf(0.55, 0.15, p), lerpf(0.0, -0.6, p), 0.0, 0.0, lerpf(0.6, 0.15, p))
			_gp[BP] = lerpf(-0.06, 0.06, p)
			_gp[HP] = 0.14 * p
			_gp[LIFT] = 0.03 * p
			_happy = p
		"nod":
			var k := ModelKit.env(t, 0.05, 0.15, dur - 0.2, dur)
			_gp[HP] = -0.24 * maxf(0.0, sin(t * TAU * 1.9)) * k
			_gp[BP] = -0.03 * k


func _fire_zap() -> void:
	var hand := _hand_grip[1]
	var from := hand.global_position + _wr[1].global_basis.y * -0.07
	var dir := -_torso.global_basis.z
	var to := from + dir * 2.6
	if _look_active:
		to = _look_pos
	var z := ZapArc.spawn(self, from, to, 0.55, EYE_ZAP)
	z.follow_from = hand


func _apply_pose() -> void:
	_hover.position.y = sin(_t * 1.7) * 0.018 + _nz(_t * 0.8, 23.0) * 0.012 + _cur[LIFT]
	_hover.rotation.x = -0.16 * _speed_s + sin(_t * 1.3) * 0.012
	_hover.rotation.z = sin(_t * 0.9) * 0.014 + _nz(_t * 0.5, 29.0) * 0.015
	_hover.rotation.y = _cur[SPIN]
	_torso.rotation = Vector3(_cur[BP], _cur[BY], _cur[BR])
	_head.rotation = Vector3(_cur[HP], _cur[HY], _cur[HR])
	for side in 2:
		var o := side * ARM_N
		var m := -1.0 if side == 0 else 1.0
		_sh[side].rotation = Vector3(_cur[o + SP], 0.0, _cur[o + SR] * m)
		_tw[side].rotation = Vector3(0.0, _cur[o + ST] * m, 0.0)
		_el[side].rotation = Vector3(_cur[o + EL], 0.0, 0.0)
		_ft[side].rotation = Vector3(0.0, _cur[o + FT] * m, 0.0)
		_wr[side].rotation = Vector3(_cur[o + WX], 0.0, _cur[o + WZ] * m)
		var curl := _cur[o + CURL]
		var idx := _cur[o + IDX]
		for f in 3:
			var c := idx if f == 0 else curl
			var base := _fing[side * 6 + f * 2]
			var tip := _fing[side * 6 + f * 2 + 1]
			if f == 2:
				base.rotation = Vector3(-0.95 + c * 0.5, 0.0, -m * (0.25 + c * 0.6))
				tip.rotation = Vector3(0.0, 0.0, -m * c * 0.7)
			else:
				base.rotation = Vector3(0.0, 0.0, -m * c * 1.1)
				tip.rotation = Vector3(0.0, 0.0, -m * c * 1.3)


func _update_face(delta: float) -> void:
	# expressions (gestures set _happy/_worry for this frame; external set_expression persists)
	var happy_t := maxf(_happy, _expr_happy)
	var worry_t := maxf(_worry, _expr_worry)
	_happy = 0.0
	_worry = 0.0
	if _g_name != "zap":
		_eye_col = _eye_col_user
	_eye_cur = Color(ModelKit.damp(_eye_cur.r, _eye_col.r, 8.0, delta), ModelKit.damp(_eye_cur.g, _eye_col.g, 8.0, delta), ModelKit.damp(_eye_cur.b, _eye_col.b, 8.0, delta))
	# blink
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = _rng.randf_range(2.2, 5.5)
		if _rng.randf() < 0.2:
			_blink_timer = 0.28 # double blink
		_blink = 1.0
	_blink = maxf(0.0, _blink - delta / 0.16)
	var lid := 1.0 - sin(_blink * PI)
	# smoothed expression amounts stored in face scale
	_hs = ModelKit.damp(_hs, happy_t, 6.0, delta)
	_ws = ModelKit.damp(_ws, worry_t, 6.0, delta)
	var hs := _hs
	var ws := _ws
	# eye look offset (pupils drift toward look direction a little)
	var ex := clampf(-_cur[HY] * 0.004, -0.004, 0.004) + _nz(_t * 0.6, 31.0) * 0.002
	var ey := clampf(_cur[HP] * 0.006, -0.004, 0.004)
	for side in 2:
		var m := -1.0 if side == 0 else 1.0
		var eye := _eyes[side]
		eye.position = Vector3(m * 0.04 + ex, 0.016 + ey + hs * 0.003 + ws * 0.002, 0.0)
		var g := _eye_glows[side]
		g.scale = Vector3(1.0 + hs * 0.08, lid * lerpf(1.0, 0.45, hs) * lerpf(1.0, 0.86, ws), 0.3)
		g.position.y = hs * 0.005
		var zap := 1.0 if _eye_col == EYE_ZAP else 0.0
		var brow := _brows[side]
		brow.position = Vector3(m * 0.041 + ex * 0.5, 0.047 + hs * 0.004 + ws * 0.003 - zap * 0.006 + ey * 0.5, 0.0)
		brow.rotation.z = -m * ws * 0.42 + m * zap * 0.3 + m * hs * 0.12
	# eye energy, with an aged bulb's occasional flicker
	var energy := 3.2 + _talk_amt * 0.5
	if aged:
		_flicker -= delta
		if _flicker < -_rng.randf_range(3.0, 9.0):
			_flicker = 0.12
		if _flicker > 0.0:
			energy *= 0.35 + 0.65 * absf(sin(_t * 90.0))
	if worry_t > 0.0 or ws > 0.05:
		energy *= 1.0 - ws * 0.25
	_m_eye.emission = _eye_cur
	_m_eye.albedo_color = _eye_cur.darkened(0.4)
	_m_eye.emission_energy_multiplier = energy
	# mouth: VU-meter style talking, smile when idle
	var talk := _talk_amt
	var syll := maxf(0.0, sin(_t * 13.0) * 0.5 + 0.5 + _nz(_t * 6.0, 37.0) * 0.9)
	var pause := smoothstep(-0.35, 0.1, _nz(_t * 1.1, 41.0))
	var lvl := talk * syll * pause
	for i in 7:
		var u := (float(i) - 3.0) / 3.6
		var c := 1.0 - u * u
		var tgt := 0.3 + lvl * c * (1.6 + 0.25 * _nz(_t * 14.0 + i * 3.1, 43.0))
		_mouth_lv[i] = ModelKit.damp(_mouth_lv[i], tgt, 22.0, delta)
		_mouth[i].scale = Vector3(1.0, maxf(_mouth_lv[i], 0.2), 1.0)
		var mx := (i - 3) * 0.0068
		_mouth[i].rotation.z = -mx * 11.0 * (1.0 + hs * 0.5 - ws * 2.6) * (1.0 - minf(lvl * 2.0, 1.0))
		var smile := 0.006 * pow(absf(mx) / 0.0204, 2.0) * (1.0 + hs * 0.8 - ws * 2.6) * (1.0 - minf(lvl * 1.5, 0.8))
		_mouth[i].position.y = -0.046 + smile
	_m_mouth.emission = _eye_cur
	_m_mouth.emission_energy_multiplier = 2.0 + lvl * 2.0
	_head_light.light_color = _eye_cur
	_head_light.light_energy = 0.18 + lvl * 0.2
	_m_bulb.emission_energy_multiplier = 2.2 + 1.5 * absf(sin(_t * 2.1)) + lvl * 3.0
	_m_bulb.emission = EYE_ZAP if _eye_col == EYE_ZAP else Color(1.0, 0.35, 0.15)


func _update_secondary(delta: float) -> void:
	# thruster
	var flick := 0.88 + 0.12 * _nz(_t * 9.0, 47.0)
	_m_thrust.emission_energy_multiplier = (3.5 + _speed_s * 4.0) * flick
	_m_plume.set_shader_parameter("intensity", (0.9 + _speed_s * 1.4) * flick)
	_thrust_light.light_energy = (0.7 + _speed_s * 0.9) * flick
	# gauge needle tracks "steam pressure" (speed + talk + jitter)
	_needle.rotation.z = -lerpf(-1.9, 1.9, clampf(0.3 + _speed_s * 0.5 + _talk_amt * 0.12 + _nz(_t * 2.0, 53.0) * 0.06, 0.0, 1.0))
	# wind-up key turns slowly
	_key.rotation.z = _t * 0.8
	# antenna spring driven by body acceleration and head motion
	var pos := global_position
	var vel := (pos - _prev_pos) / delta
	var acc := (vel - _prev_vel) / delta
	_prev_pos = pos
	_prev_vel = vel
	var yaw := _cur[SPIN] + global_rotation.y
	var yaw_v := wrapf(yaw - _prev_yaw, -PI, PI) / delta
	_prev_yaw = yaw
	var local_acc := global_basis.inverse() * acc
	local_acc = local_acc.limit_length(30.0)
	var force := Vector2(local_acc.z * 0.012 - _cur[HP] * 0.0, -local_acc.x * 0.012 + yaw_v * 0.01)
	force += Vector2(_nz(_t * 1.3, 59.0), _nz(_t * 1.1, 61.0)) * 0.6
	_ant_vel += (force * 60.0 - _ant_ang * 110.0) * delta
	_ant_vel *= exp(-5.0 * delta)
	_ant_ang += _ant_vel * delta
	_ant_ang = _ant_ang.clamp(Vector2(-0.6, -0.6), Vector2(0.6, 0.6))
	_antenna.rotation = Vector3(_ant_ang.x, 0.0, _ant_ang.y)
	# towel hangs toward world-down around the forearm axis
	var fb := _ft[0].global_basis.orthonormalized()
	var d := fb.inverse() * Vector3.DOWN
	if Vector2(d.x, d.z).length() > 0.15:
		var ang := atan2(-d.z, d.x)
		_towel_ang = lerp_angle(_towel_ang, ang, 1.0 - exp(-10.0 * delta))
	_towel_pivot.rotation = Vector3(0.0, _towel_ang, sin(_t * 1.9) * 0.03)
	# props for gestures
	if _g_name == "tea":
		_cup.visible = true
		var s := ModelKit.ease_back((_g_t - 0.45) / 0.35) * (1.0 - ModelKit.ramp(_g_t, _g_dur - 0.75, _g_dur - 0.45))
		_cup.scale = Vector3.ONE * maxf(s, 0.001)
		_steam.emitting = s > 0.5
	elif _g_name == "polish":
		_rag.visible = true
		_towel.visible = _g_t < 0.35 or _g_t > _g_dur - 0.35
		var s := ModelKit.ease_back((_g_t - 0.3) / 0.3) * (1.0 - ModelKit.ramp(_g_t, _g_dur - 0.45, _g_dur - 0.3))
		_rag.scale = Vector3.ONE * maxf(s, 0.001)
