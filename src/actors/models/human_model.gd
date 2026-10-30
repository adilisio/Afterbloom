class_name HumanModel
extends Node3D
## 1967 Larkhaven townsfolk: procedural, stylized, skinned humans. One Skeleton3D and one skinned
## mesh per person. Meshes, skins and materials are cached and shared between people who look alike.
## Origin at the feet, facing -Z. The model never moves its own root: the parent does that and tells
## the model how fast with set_move_speed(m/s).
##
## Configure with properties or setup({...}) before add_child (calling setup() later rebuilds).
## Presets: HumanModel.make_preset("june"|"rory"|"warden"). Crowds: HumanModel.random_townsperson(seed).
## See src/actors/models/README.md for the whole API.

signal gesture_finished(gesture_name: String)

enum { HIPS, SPINE, CHEST, NECK, HEAD, JAW, EYE_L, EYE_R, LID_L, LID_R, LLID_L, LLID_R, BROW_L, BROW_R,
	MC_L, MC_R, ULIP, PONY, SK_F, SK_B,
	CLAV_L, UARM_L, FARM_L, HAND_L, FING_L, FING2_L, INDEX_L, INDEX2_L, THUMB_L,
	CLAV_R, UARM_R, FARM_R, HAND_R, FING_R, FING2_R, INDEX_R, INDEX2_R, THUMB_R,
	THIGH_L, SHIN_L, FOOT_L, THIGH_R, SHIN_R, FOOT_R, NB }
const AS := CLAV_R - CLAV_L ## arm bone stride
const LS := THIGH_R - THIGH_L ## leg bone stride

const BONE_NAMES := ["hips", "spine", "chest", "neck", "head", "jaw", "eye_l", "eye_r", "lid_l", "lid_r", "llid_l", "llid_r",
	"brow_l", "brow_r", "mc_l", "mc_r", "ulip", "pony", "skirt_f", "skirt_b",
	"clav_l", "uarm_l", "farm_l", "hand_l", "fing_l", "fing2_l", "index_l", "index2_l", "thumb_l",
	"clav_r", "uarm_r", "farm_r", "hand_r", "fing_r", "fing2_r", "index_r", "index2_r", "thumb_r",
	"thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const BONE_PARENT := [-1, HIPS, SPINE, CHEST, NECK, HEAD, HEAD, HEAD, HEAD, HEAD, HEAD, HEAD,
	HEAD, HEAD, HEAD, HEAD, HEAD, HEAD, HIPS, HIPS,
	CHEST, CLAV_L, UARM_L, FARM_L, HAND_L, FING_L, HAND_L, INDEX_L, HAND_L,
	CHEST, CLAV_R, UARM_R, FARM_R, HAND_R, FING_R, HAND_R, INDEX_R, HAND_R,
	HIPS, THIGH_L, SHIN_L, HIPS, THIGH_R, SHIN_R]

## Gesture durations in seconds.
const GESTURES := {
	"wave": 2.6, "point": 2.2, "nod": 1.1, "shrug": 1.8, "hug_self": 3.0, "beckon": 2.4,
	"laugh": 2.2, "sip": 2.8, "gasp": 2.0, "shake_head": 1.4,
}
enum { G_NONE, G_WAVE, G_POINT, G_NOD, G_SHRUG, G_HUG, G_BECKON, G_LAUGH, G_SIP, G_GASP, G_SHAKE }
const GESTURE_IDS := {"wave": G_WAVE, "point": G_POINT, "nod": G_NOD, "shrug": G_SHRUG, "hug_self": G_HUG,
	"beckon": G_BECKON, "laugh": G_LAUGH, "sip": G_SIP, "gasp": G_GASP, "shake_head": G_SHAKE}

enum { P_STAND, P_SIT, P_LIE, P_GROUND, P_COWER, P_N }
const POSE_IDS := {"stand": P_STAND, "sit": P_SIT, "lie": P_LIE, "sit_ground": P_GROUND, "cower": P_COWER}

enum { E_NEUTRAL, E_HAPPY, E_WORRIED, E_SCARED, E_SAD, E_N }
const EXPR_IDS := {"neutral": E_NEUTRAL, "happy": E_HAPPY, "worried": E_WORRIED, "scared": E_SCARED, "sad": E_SAD}

## Named presets (see the README for the character notes).
const PRESETS := {
	"june": {
		"sex": "f", "age": "adult", "build": "slim", "height": 1.64, "skin_tone": 0.17,
		"hair_style": "ponytail", "hair_color": Color(0.42, 0.21, 0.10), "eye_color": Color(0.33, 0.44, 0.24),
		"outfit": "cardigan", "bottom": "skirt", "top_color": Color(0.93, 0.80, 0.46), "shirt_color": Color(0.96, 0.94, 0.88),
		"bottom_color": Color(0.17, 0.21, 0.36), "shoe_color": Color(0.44, 0.16, 0.10), "accent_color": Color(0.11, 0.47, 0.49),
		"sash": true, "lipstick": true, "mood": "happy", "posture": "proud", "idle_style": 0, "seed_value": 1967,
	},
	"rory": {
		"sex": "m", "age": "adult", "build": "slim", "height": 1.80, "skin_tone": 0.26,
		"hair_style": "mop", "hair_color": Color(0.17, 0.11, 0.07), "eye_color": Color(0.30, 0.19, 0.10),
		"outfit": "sweater_vest", "pattern": "argyle", "top_color": Color(0.74, 0.56, 0.22), "trim_color": Color(0.33, 0.21, 0.14),
		"shirt_color": Color(0.74, 0.82, 0.90), "bottom_color": Color(0.32, 0.24, 0.17), "shoe_color": Color(0.22, 0.13, 0.08),
		"accent_color": Color(0.42, 0.12, 0.11), "glasses": true, "glasses_style": "round", "headphones": true, "mood": "neutral", "posture": "shy", "idle_style": 1,
		"seed_value": 1948,
	},
	"warden": {
		"sex": "m", "age": "adult", "build": "heavy", "height": 1.78, "skin_tone": 0.28,
		"hair_style": "short", "hair_color": Color(0.46, 0.45, 0.43), "eye_color": Color(0.38, 0.47, 0.55),
		"outfit": "halcyon", "hat": "peaked", "facial_hair": "moustache", "shoe_color": Color(0.06, 0.05, 0.05),
		"mood": "neutral", "posture": "proud", "idle_style": 3, "seed_value": 1912,
	},
}

# Head profile (head-local metres): chin -0.047 .. crown CROWN. The cranium above 0.105 is analytic.
const CROWN := 0.195
const HY := [-0.047, -0.044, -0.036, -0.024, -0.010, 0.000, 0.012, 0.025, 0.040, 0.055, 0.070, 0.085, 0.105]
const HRX := [0.0, 0.030, 0.047, 0.057, 0.064, 0.068, 0.073, 0.078, 0.082, 0.084, 0.085, 0.086, 0.086]
const HZF := [0.0, 0.052, 0.072, 0.080, 0.083, 0.085, 0.086, 0.086, 0.085, 0.084, 0.083, 0.085, 0.086]
const HZB := [0.0, 0.015, 0.030, 0.045, 0.060, 0.070, 0.080, 0.088, 0.094, 0.098, 0.100, 0.102, 0.102]
const HROWS := [-0.047, -0.036, -0.026, -0.016, -0.0095, -0.0055, -0.0025, -0.0008, 0.0008, 0.0025, 0.0055, 0.0095, 0.0135,
	0.019, 0.0235, 0.027, 0.0305, 0.034, 0.038, 0.043, 0.049, 0.056, 0.063, 0.070, 0.077, 0.084, 0.091, 0.098, 0.106, 0.116, 0.128,
	0.142, 0.156, 0.169, 0.182, 0.191, 0.195]
const HN := 2.25

# Torso profile (rig metres for an adult man, scaled by vy): y, half-width, front depth, back depth.
const TY := [0.845, 0.865, 0.90, 0.95, 1.01, 1.075, 1.15, 1.24, 1.32, 1.375, 1.41, 1.435, 1.455, 1.47, 1.485]
const TRX := [0.0, 0.085, 0.145, 0.165, 0.158, 0.148, 0.155, 0.168, 0.176, 0.183, 0.183, 0.158, 0.116, 0.08, 0.068]
const TZF := [0.0, 0.06, 0.095, 0.10, 0.10, 0.098, 0.105, 0.115, 0.118, 0.108, 0.09, 0.075, 0.062, 0.055, 0.052]
const TZB := [0.0, 0.07, 0.115, 0.125, 0.11, 0.095, 0.095, 0.105, 0.11, 0.108, 0.095, 0.08, 0.065, 0.058, 0.055]
const TN := 2.3

const SKIN_STOPS := [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]
const SKIN_COLS := [Color(0.97, 0.77, 0.65), Color(0.93, 0.70, 0.56), Color(0.87, 0.62, 0.46), Color(0.77, 0.52, 0.36),
	Color(0.65, 0.42, 0.27), Color(0.50, 0.31, 0.19), Color(0.36, 0.22, 0.13), Color(0.27, 0.16, 0.10)]

# ==========================================================================
# Look parameters. Set them before add_child, or pass them to setup().
# ==========================================================================

## "m" or "f".
var sex := "m"
## "child" (8-12), "adult" or "elder".
var age := "adult"
## "slim", "average" or "heavy".
var build := "average"
## Metres to the crown. 0 = a default for the sex and age.
var height := 0.0
## 0 (very fair) .. 1 (deep brown).
var skin_tone := 0.3
## "short", "side_part", "mop", "bob", "ponytail", "bun", "curly", "balding" or "bald".
var hair_style := "short"
var hair_color := Color(0.24, 0.16, 0.10)
var eye_color := Color(0.36, 0.24, 0.13)
## "cardigan", "shirt_tie", "dress", "sweater", "sweater_vest", "overalls", "fisherman", "warden" or "halcyon".
var outfit := "shirt_tie"
## "" = the outfit's default, otherwise "slacks", "skirt" or "shorts".
var bottom := ""
## A colour with alpha 0 means "use the outfit's default".
var top_color := Color(0, 0, 0, 0)
var shirt_color := Color(0, 0, 0, 0)
var bottom_color := Color(0, 0, 0, 0)
var trim_color := Color(0, 0, 0, 0)
var accent_color := Color(0, 0, 0, 0)
var shoe_color := Color(0, 0, 0, 0)
var hat_color := Color(0, 0, 0, 0)
## Top fabric: "", "gingham", "floral", "dots", "plaid" or "argyle".
var pattern := ""
## "none", "fisherman", "headscarf", "helmet" or "peaked".
var hat := "none"
var glasses := false
## "round" or "square".
var glasses_style := "round"
## Radio headphones resting around the neck.
var headphones := false
## Halcyon open-house volunteer sash.
var sash := false
## "none" or "moustache".
var facial_hair := "none"
var lipstick := false
## Eleven years later: grimy, faded clothes. Can be changed any time with set_dirty().
var dirty := false
## Resting expression: "neutral", "happy", "worried", "scared" or "sad".
var mood := "neutral"
## "normal", "proud", "shy" or "stoop".
var posture := "normal"
## Resting arms: -1 = picked from the seed, 0 relaxed, 1 hands clasped in front, 2 behind the back,
## 3 arms folded, 4 hands in pockets, 5 hands on hips.
var idle_style := -1
## Height of the seat or mattress above the model's feet, in metres, for "sit" and "lie".
var seat_height := 0.45
## Shows a blanket while lying down.
var blanket := false
var blanket_color := Color(0.40, 0.42, 0.36)
## Drives animation desync and small variations. 0 = random.
var seed_value := 0

# ==========================================================================
# Body measurements
# ==========================================================================

class Dims:
	extends RefCounted
	var female := false
	var child := false
	var elder := false
	var heavy := 0.0
	var slim := 0.0
	var vy := 1.0
	var hx := 1.0
	var hs := 1.0
	var hk := 1.0
	var base_h := 1.745
	var ankle_h := 0.075
	var shin := 0.425
	var thigh := 0.435
	var hipj_y := 0.935
	var hip_x := 0.088
	var hips_y := 0.975
	var spine_y := 1.075
	var chest_y := 1.25
	var neck_y := 1.455
	var head_y := 1.545
	var sh_x := 0.178
	var sh_y := 1.405
	var clav_x := 0.025
	var uarm := 0.285
	var farm := 0.255
	var arm_k := 1.0
	var leg_k := 1.0
	var neck_r := 0.052
	var foot_k := 1.0
	var nose_k := 1.0
	var lip_k := 1.0
	var brow_k := 1.0
	var cheek_k := 1.0
	var jaw_k := 1.0
	var ear_k := 1.0
	var eye_r := 0.0122
	var eye := Vector3(0.0315, 0.071, -0.07)
	var mouth_w := 0.022
	var mouth_z := -0.09


class Slot:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var b := PackedInt32Array()
	var w := PackedFloat32Array()
	var i := PackedInt32Array()


class MB:
	extends RefCounted
	var slots: Dictionary = {}
	var order: PackedStringArray = []

	func slot(slot_name: String) -> Slot:
		if not slots.has(slot_name):
			slots[slot_name] = Slot.new()
			order.append(slot_name)
		return slots[slot_name]


static var _cache: Dictionary = {}

# ==========================================================================
# Runtime state
# ==========================================================================

var _built := false
var _d: Dims
var _rs := 1.0
var _rig: Node3D
var _skel: Skeleton3D
var _mi: MeshInstance3D
var _vis: VisibleOnScreenNotifier3D
var _blanket_mi: MeshInstance3D
var _rl := PackedVector3Array() # rest position of every bone, in its parent's space
var _rg := PackedVector3Array() # rest position of every bone, in rig space
var _e := PackedVector3Array() # FK euler per bone for this frame
var _q: Array[Quaternion] = [] # final local rotation per bone
var _rng := RandomNumberGenerator.new()

var _t := 0.0
var _acc := 0.0
var _tgt_spd := 0.0
var _spd := 0.0
var _phase := 0.0
var _pose_id := P_STAND
var _pw := PackedFloat32Array()
var _ex_id := E_NEUTRAL
var _ew := PackedFloat32Array()
var _talking := false
var _talk := 0.0
var _beat_t := 2.0
var _beat_age := 99.0
var _beat_side := 1
var _panic := false
var _panic_w := 0.0
var _look_on := false
var _look_world := Vector3.ZERO
var _look_w := 0.0
var _head_yaw := 0.0
var _head_pitch := 0.0
var _glance := Vector2.ZERO
var _glance_tgt := Vector2.ZERO
var _glance_t := 2.0
var _sacc := Vector2.ZERO
var _sacc_tgt := Vector2.ZERO
var _sacc_t := 1.0
var _eye_y := 0.0
var _eye_p := 0.0
var _blink := 0.0
var _blink_t := 2.0
var _ws := 0.0
var _ws_tgt := 1.0
var _ws_t := 5.0
var _style := 0
var _style_w := 0.0
var _style_t := 20.0
var _breath_ph := 0.0
var _breath_rate := 1.5
var _stance := 0.0
var _ground_var := 0
var _g_id := G_NONE
var _g_name := ""
var _g_t := 0.0
var _g_dur := 0.0
var _g_side := 1
var _jaw := 0.0
var _pony_a := Vector2.ZERO
var _pony_v := Vector2.ZERO
var _prev_hp := Vector3.ZERO

var _held: Array[Node3D] = [null, null]
var _hold_kind := PackedInt32Array([0, 0]) # 0 none, 1 front, 2 carry, 3 chest
var _hold_w := PackedFloat32Array([0.0, 0.0])
var _hold_curl := PackedFloat32Array([0.7, 0.7])
var _att: Array[BoneAttachment3D] = [null, null]
var _grip: Array[Node3D] = [null, null]
var _head_att: BoneAttachment3D

# per-frame accumulators
var _hp := Vector3.ZERO
var _ft := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _ftp := PackedFloat32Array([0.0, 0.0])
var _ft_w := 0.0
var _ik_w := PackedFloat32Array([0.0, 0.0])
var _ik_p := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _ik_h: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY]
var _ik_pole := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _curl := PackedFloat32Array([0.0, 0.0])
var _idx := PackedFloat32Array([0.0, 0.0])
var _thumb := PackedFloat32Array([0.0, 0.0])
var _face_h := 0.0 # gesture expression overrides for this frame
var _face_w := 0.0
var _face_s := 0.0
var _jaw_add := 0.0
var _ik_q1 := Quaternion.IDENTITY
var _ik_q2 := Quaternion.IDENTITY
# torso frame from the last solve (used for look and for chest-space targets)
var _hips_q := Quaternion.IDENTITY
var _hips_p := Vector3.ZERO
var _chest_q := Quaternion.IDENTITY
var _chest_p := Vector3.ZERO
var _head_q := Quaternion.IDENTITY
var _head_p := Vector3.ZERO

# ==========================================================================
# Public API
# ==========================================================================

## Sets look parameters from a dictionary. Returns self so it can be chained:
## `add_child(HumanModel.new().setup({"sex": "f", "outfit": "dress"}))`.
func setup(params: Dictionary) -> HumanModel:
	for k: String in params:
		set(k, params[k])
	if _built:
		_rebuild()
	return self


## A new model with one of the PRESETS: "june", "rory" or "warden".
static func make_preset(preset_name: String) -> HumanModel:
	var m := HumanModel.new()
	if PRESETS.has(preset_name):
		m.setup(PRESETS[preset_name])
	else:
		push_warning("HumanModel: unknown preset '%s'" % preset_name)
	return m


## A new model configured by random_params(seed).
static func random_townsperson(seed_v: int) -> HumanModel:
	return HumanModel.new().setup(random_params(seed_v))


## Metres per second. About 1.3 is a walk, 3.5+ a run. The parent moves the root.
func set_move_speed(v: float) -> void:
	_tgt_spd = maxf(v, 0.0)


func set_talking(b: bool) -> void:
	_talking = b


func is_talking() -> bool:
	return _talking


## "neutral", "happy", "worried", "scared" or "sad".
func set_expression(expr: String) -> void:
	if EXPR_IDS.has(expr):
		_ex_id = EXPR_IDS[expr]
	else:
		push_warning("HumanModel: unknown expression '%s'" % expr)


## Plays a named gesture and returns its duration (0 with a warning if unknown).
func play_gesture(gesture_name: String) -> float:
	if not GESTURES.has(gesture_name):
		push_warning("HumanModel: unknown gesture '%s'" % gesture_name)
		return 0.0
	if _g_id != G_NONE:
		_end_gesture()
	_g_id = GESTURE_IDS[gesture_name]
	_g_name = gesture_name
	_g_t = 0.0
	_g_dur = GESTURES[gesture_name]
	_g_side = 1
	if _g_id == G_SIP and _held[1] == null and _held[0] != null:
		_g_side = 0
	return _g_dur


func is_gesturing() -> bool:
	return _g_id != G_NONE


func look_at_point(world_pos: Vector3) -> void:
	_look_on = true
	_look_world = world_pos


func clear_look() -> void:
	_look_on = false


## "stand", "sit", "lie", "sit_ground" or "cower". `instant` skips the blend (for placing NPCs).
## "sit" and "lie" use seat_height; change it first or pass seat >= 0 here.
func set_pose(pose_name: String, instant := false, seat := -1.0) -> void:
	if not POSE_IDS.has(pose_name):
		push_warning("HumanModel: unknown pose '%s'" % pose_name)
		return
	if seat >= 0.0:
		seat_height = seat
	_pose_id = POSE_IDS[pose_name]
	if instant and _pw.size() == P_N:
		for k in P_N:
			_pw[k] = 1.0 if k == _pose_id else 0.0
	if _blanket_mi:
		_blanket_mi.visible = blanket and _pose_id == P_LIE
		_blanket_mi.position = Vector3(0, seat_height / _rs, 0)


func get_pose() -> String:
	for k: String in POSE_IDS:
		if POSE_IDS[k] == _pose_id:
			return k
	return "stand"


## Panic: frantic glances, shaking and a scared face. Standing still it hugs itself; running it flails.
func set_panic(b: bool) -> void:
	_panic = b


func set_blanket(b: bool) -> void:
	blanket = b
	if _built:
		_ensure_blanket()
		_blanket_mi.visible = blanket and _pose_id == P_LIE


func set_dirty(b: bool) -> void:
	dirty = b
	if _built:
		_apply_materials()


## Puts `node` in a hand ("r" or "l"). The node's origin becomes the grip point and it stays upright
## while held. Optional node metadata: "hold_style" ("front", "carry" or "chest") and "grip_r" (metres
## from the palm to the origin). Pass `style` to override. A previously held node is removed and returned.
func hold(node: Node3D, side := "r", style := "") -> Node3D:
	var s := 0 if side == "l" else 1
	var old: Node3D = release(side)
	if node == null:
		return old
	if style == "":
		style = str(node.get_meta("hold_style", "front"))
	var r: float = node.get_meta("grip_r", 0.03)
	var kind := 1
	if style == "carry":
		kind = 2
	elif style == "chest":
		kind = 3
	_hold_kind[s] = kind
	_hold_curl[s] = float(node.get_meta("grip_curl", 0.72))
	_held[s] = node
	if _built:
		_attach_held(s, r)
	else:
		node.set_meta("_pending_r", r)
	return old


## Takes the held node out of the hand ("r" or "l") and returns it (or null). The caller owns it.
func release(side := "r") -> Node3D:
	var s := 0 if side == "l" else 1
	var n: Node3D = _held[s]
	_held[s] = null
	_hold_kind[s] = 0
	if n and n.get_parent():
		n.get_parent().remove_child(n)
	return n


func get_held(side := "r") -> Node3D:
	return _held[0 if side == "l" else 1]


## Follows the head bone. Handy for dialogue cameras.
func get_head_node() -> Node3D:
	if _skel == null:
		return self
	if _head_att == null:
		_head_att = BoneAttachment3D.new()
		_head_att.bone_name = "head"
		_skel.add_child(_head_att)
	return _head_att


## A node at the palm that follows the hand ("r" or "l").
func get_hand_node(side := "r") -> Node3D:
	if _skel == null:
		return self
	var s := 0 if side == "l" else 1
	_ensure_grip(s)
	return _grip[s]


## Metres from the feet to the crown.
func get_height() -> float:
	if height > 0.0:
		return height
	return default_height(sex, age)


## Capsule for a controller: Vector2(radius, height). The model has no physics of its own.
func get_capsule() -> Vector2:
	var h := get_height()
	var r := 0.27 * h / 1.75
	if build == "heavy":
		r *= 1.15
	elif build == "slim":
		r *= 0.92
	return Vector2(r, h)


## A CollisionShape3D with that capsule, already placed so its base is at the feet.
func make_collision_shape() -> CollisionShape3D:
	var c := get_capsule()
	var cs := CollisionShape3D.new()
	cs.shape = ModelKit.capsule_shape(c.x, c.y)
	cs.position = Vector3(0, c.y * 0.5, 0)
	return cs


static func default_height(sx: String, ag: String) -> float:
	if ag == "child":
		return 1.36 if sx == "m" else 1.34
	if ag == "elder":
		return 1.72 if sx == "m" else 1.59
	return 1.76 if sx == "m" else 1.63


# ==========================================================================
# Crowd generator
# ==========================================================================

const P_TOP_M := [Color(0.86, 0.82, 0.70), Color(0.70, 0.78, 0.86), Color(0.78, 0.62, 0.25), Color(0.42, 0.44, 0.28),
	Color(0.62, 0.30, 0.18), Color(0.16, 0.20, 0.32), Color(0.40, 0.28, 0.18), Color(0.50, 0.50, 0.50),
	Color(0.20, 0.45, 0.45), Color(0.45, 0.15, 0.17), Color(0.20, 0.33, 0.24)]
const P_TOP_F := [Color(0.88, 0.50, 0.42), Color(0.92, 0.82, 0.50), Color(0.60, 0.80, 0.70), Color(0.60, 0.72, 0.86),
	Color(0.90, 0.65, 0.70), Color(0.70, 0.62, 0.80), Color(0.72, 0.16, 0.16), Color(0.25, 0.65, 0.68),
	Color(0.90, 0.86, 0.76), Color(0.90, 0.55, 0.20), Color(0.16, 0.20, 0.34)]
const P_SHIRT := [Color(0.92, 0.91, 0.87), Color(0.92, 0.91, 0.87), Color(0.72, 0.80, 0.88), Color(0.88, 0.84, 0.72)]
const P_LOW_M := [Color(0.20, 0.20, 0.22), Color(0.42, 0.42, 0.42), Color(0.33, 0.25, 0.18), Color(0.60, 0.54, 0.40),
	Color(0.15, 0.18, 0.28), Color(0.30, 0.31, 0.22)]
const P_LOW_F := [Color(0.16, 0.20, 0.34), Color(0.20, 0.20, 0.22), Color(0.66, 0.52, 0.34), Color(0.38, 0.18, 0.30),
	Color(0.20, 0.33, 0.24), Color(0.10, 0.10, 0.11), Color(0.62, 0.16, 0.14), Color(0.45, 0.45, 0.46)]
const P_SHOE := [Color(0.06, 0.05, 0.05), Color(0.18, 0.10, 0.06), Color(0.42, 0.26, 0.14), Color(0.30, 0.08, 0.06)]
const P_TIE := [Color(0.45, 0.10, 0.12), Color(0.14, 0.18, 0.34), Color(0.16, 0.30, 0.20), Color(0.72, 0.56, 0.18), Color(0.08, 0.08, 0.09)]
const P_SCARF := [Color(0.72, 0.18, 0.18), Color(0.20, 0.50, 0.52), Color(0.90, 0.72, 0.30), Color(0.60, 0.42, 0.70), Color(0.88, 0.84, 0.72)]
const P_HAIR_DARK := [Color(0.05, 0.04, 0.035), Color(0.09, 0.06, 0.045), Color(0.14, 0.09, 0.06)]
const P_HAIR_ANY := [Color(0.05, 0.04, 0.035), Color(0.14, 0.09, 0.06), Color(0.28, 0.18, 0.11), Color(0.38, 0.20, 0.10),
	Color(0.50, 0.22, 0.10), Color(0.62, 0.27, 0.12), Color(0.62, 0.50, 0.32), Color(0.80, 0.68, 0.45)]
const P_HAIR_OLD := [Color(0.55, 0.54, 0.52), Color(0.38, 0.37, 0.36), Color(0.85, 0.84, 0.82), Color(0.70, 0.69, 0.66)]
const P_EYES_DARK := [Color(0.22, 0.13, 0.07), Color(0.30, 0.18, 0.09), Color(0.38, 0.23, 0.11)]
const P_EYES_ANY := [Color(0.38, 0.23, 0.11), Color(0.45, 0.38, 0.20), Color(0.30, 0.45, 0.28), Color(0.30, 0.48, 0.70), Color(0.45, 0.55, 0.62)]


## Body shape and outfit come from this many templates; colours, skin, height and mood from the full seed.
const CROWD_TEMPLATES := 23


static func _pick(r: RandomNumberGenerator, a: Array) -> Variant:
	return a[r.randi() % a.size()]


## Picks a key from {key: weight}.
static func _wpick(r: RandomNumberGenerator, t: Dictionary) -> String:
	var tot := 0.0
	for k: String in t:
		tot += float(t[k])
	var x := r.randf() * tot
	for k: String in t:
		x -= float(t[k])
		if x <= 0.0:
			return k
	return t.keys()[0]


## Deterministic, plausible 1967 townsperson as a dictionary of look parameters.
static func random_params(seed_v: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(seed_v * 7919 + 13)
	var g := RandomNumberGenerator.new()
	g.seed = hash(posmod(seed_v, CROWD_TEMPLATES) * 104729 + 3)
	var d := {}
	var sx := "f" if g.randf() < 0.5 else "m"
	var ar := g.randf()
	var ag := "child" if ar < 0.14 else ("elder" if ar < 0.34 else "adult")
	d["sex"] = sx
	d["age"] = ag
	var bd := _wpick(g, {"slim": 0.32, "average": 0.45, "heavy": 0.23})
	if ag == "child":
		bd = _wpick(g, {"slim": 0.6, "average": 0.4})
	d["build"] = bd
	d["height"] = default_height(sx, ag) * (1.0 + clampf(r.randfn(0.0, 0.032), -0.07, 0.07))
	# skin tone: a Pacific port town, mostly light-to-medium with a real range
	var tone_r := r.randf()
	var tone := r.randf_range(0.04, 0.38)
	if tone_r > 0.86:
		tone = r.randf_range(0.70, 0.98)
	elif tone_r > 0.60:
		tone = r.randf_range(0.38, 0.70)
	d["skin_tone"] = tone
	# hair
	var hc: Color = _pick(r, P_HAIR_DARK if tone > 0.5 else P_HAIR_ANY)
	if ag == "elder":
		hc = _pick(r, P_HAIR_OLD)
	d["hair_color"] = hc
	d["eye_color"] = _pick(r, P_EYES_DARK if (tone > 0.4 or r.randf() < 0.4) else P_EYES_ANY)
	var hs := "short"
	if sx == "m":
		if ag == "child":
			hs = _wpick(g, {"short": 0.5, "mop": 0.3, "side_part": 0.2})
		elif ag == "elder":
			hs = _wpick(g, {"balding": 0.5, "short": 0.25, "side_part": 0.25})
		else:
			hs = _wpick(g, {"short": 0.3, "side_part": 0.3, "curly": 0.14, "mop": 0.14, "balding": 0.12})
	else:
		if ag == "child":
			hs = _wpick(g, {"ponytail": 0.45, "bob": 0.45, "curly": 0.1})
		elif ag == "elder":
			hs = _wpick(g, {"bun": 0.45, "curly": 0.35, "bob": 0.2})
		else:
			hs = _wpick(g, {"bob": 0.38, "ponytail": 0.22, "bun": 0.18, "curly": 0.22})
	d["hair_style"] = hs
	# outfit
	var o := "shirt_tie"
	if ag == "child":
		o = _wpick(g, {"sweater": 0.5, "shirt_tie": 0.2, "overalls": 0.3}) if sx == "m" else _wpick(g, {"dress": 0.65, "cardigan": 0.35})
	elif sx == "m":
		o = _wpick(g, {"shirt_tie": 0.26, "cardigan": 0.12, "sweater": 0.15, "sweater_vest": 0.07, "overalls": 0.13, "fisherman": 0.15, "halcyon": 0.07, "warden": 0.05})
	else:
		o = _wpick(g, {"dress": 0.42, "cardigan": 0.26, "sweater": 0.14, "shirt_tie": 0.08, "halcyon": 0.07, "overalls": 0.03})
	d["outfit"] = o
	d["top_color"] = _pick(r, P_TOP_F if sx == "f" else P_TOP_M)
	d["bottom_color"] = _pick(r, P_LOW_F if sx == "f" else P_LOW_M)
	d["shirt_color"] = _pick(r, P_SHIRT)
	d["shoe_color"] = _pick(r, P_SHOE)
	if o == "shirt_tie":
		d["top_color"] = _pick(r, P_SHIRT)
		d["accent_color"] = _pick(r, P_TIE)
	elif o == "dress":
		d["pattern"] = _wpick(r, {"": 0.3, "gingham": 0.25, "floral": 0.25, "dots": 0.2})
	elif o == "overalls":
		d["shirt_color"] = _pick(r, [Color(0.62, 0.20, 0.16), Color(0.28, 0.40, 0.58), Color(0.30, 0.42, 0.28)])
		d["pattern"] = _wpick(r, {"plaid": 0.6, "": 0.4})
		d.erase("top_color")
		d.erase("bottom_color")
		d.erase("shoe_color")
	elif o == "sweater_vest":
		d["pattern"] = _wpick(r, {"argyle": 0.5, "": 0.5})
		d["trim_color"] = (d["top_color"] as Color).darkened(0.45)
	elif o in ["fisherman", "warden", "halcyon"]:
		d.erase("top_color")
		d.erase("bottom_color")
		d.erase("shoe_color")
		if o == "fisherman":
			d["top_color"] = _pick(r, [Color(0.84, 0.80, 0.68), Color(0.16, 0.20, 0.30), Color(0.46, 0.46, 0.44)])
	# hats, glasses, moustaches, make-up
	var hat_v := "none"
	if o == "warden":
		hat_v = "helmet"
	elif o == "fisherman" and g.randf() < 0.6:
		hat_v = "fisherman"
	elif sx == "f" and ag != "child" and g.randf() < (0.22 if ag == "elder" else 0.1):
		hat_v = "headscarf"
		d["accent_color"] = _pick(r, P_SCARF)
	elif sx == "m" and ag != "child" and g.randf() < 0.07:
		hat_v = "fisherman"
	d["hat"] = hat_v
	d["glasses"] = g.randf() < (0.4 if ag == "elder" else (0.08 if ag == "child" else 0.15))
	d["glasses_style"] = "round" if g.randf() < 0.5 else "square"
	if sx == "m" and ag != "child" and g.randf() < (0.3 if ag == "elder" else 0.18):
		d["facial_hair"] = "moustache"
	if sx == "f" and ag == "adult" and g.randf() < 0.55:
		d["lipstick"] = true
	d["mood"] = _wpick(r, {"neutral": 0.6, "happy": 0.32, "worried": 0.08})
	if ag == "elder":
		d["posture"] = "stoop" if r.randf() < 0.55 else "normal"
	elif ag == "child":
		d["posture"] = "normal"
	else:
		d["posture"] = _wpick(r, {"normal": 0.7, "proud": 0.18, "shy": 0.12})
	d["seed_value"] = seed_v + 1
	return d


# ==========================================================================
# Lifecycle
# ==========================================================================

func _ready() -> void:
	_rng.seed = hash(seed_value * 31 + 7) if seed_value != 0 else randi()
	_t = _rng.randf() * 40.0
	_acc = _rng.randf() * 0.1
	_breath_rate = _rng.randf_range(1.25, 1.7)
	_breath_ph = _rng.randf() * TAU
	_stance = _rng.randf_range(-1.0, 1.0)
	_ws = _rng.randf_range(-0.5, 0.5)
	_ws_tgt = 1.0 if _rng.randf() < 0.5 else -1.0
	_ws_t = _rng.randf_range(2.0, 9.0)
	_blink_t = _rng.randf_range(0.5, 4.0)
	_glance_t = _rng.randf_range(0.5, 4.0)
	_ground_var = _rng.randi() % 2
	_style = idle_style if idle_style >= 0 else _pick_idle_style()
	_style_t = _rng.randf_range(15.0, 45.0)
	_pw.resize(P_N)
	_ew.resize(E_N)
	_pw[_pose_id] = 1.0
	if mood != "neutral" and _ex_id == E_NEUTRAL:
		set_expression(mood)
	_ew[_ex_id] = 1.0
	_build()
	_built = true
	# anything held or posed before add_child
	for s in 2:
		if _held[s]:
			var n: Node3D = _held[s]
			_attach_held(s, float(n.get_meta("_pending_r", n.get_meta("grip_r", 0.03))))
			_hold_w[s] = 1.0
	_update(0.0001, true)


func _pick_idle_style() -> int:
	var x := _rng.randf()
	if age == "elder":
		return 2 if x < 0.4 else (1 if x < 0.7 else 0)
	if age == "child":
		return 0 if x < 0.75 else 4
	if sex == "f":
		return 0 if x < 0.4 else (1 if x < 0.65 else (3 if x < 0.85 else 5))
	return 0 if x < 0.35 else (4 if x < 0.55 else (3 if x < 0.75 else (2 if x < 0.9 else 5)))


func _rebuild() -> void:
	_built = false
	var keep: Array[Node3D] = [_held[0], _held[1]]
	for s in 2:
		if keep[s] and keep[s].get_parent():
			keep[s].get_parent().remove_child(keep[s])
		_grip[s] = null
		_att[s] = null
	_head_att = null
	if _rig:
		_rig.free()
	if _vis:
		_vis.free()
	_blanket_mi = null
	_build()
	_built = true
	for s in 2:
		if keep[s]:
			_attach_held(s, float(keep[s].get_meta("grip_r", 0.03)))
	_update(0.0001, true)


func _process(delta: float) -> void:
	if _skel == null:
		return
	_acc += delta
	var interval := 0.0
	var face := true
	if _vis and not _vis.is_on_screen():
		interval = 0.25
		face = false
	else:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var d2 := cam.global_position.distance_squared_to(global_position)
			if d2 > 900.0:
				interval = 0.1
				face = false
			elif d2 > 196.0:
				interval = 0.033
				face = false
			elif d2 > 64.0:
				interval = 0.02
	if _acc < interval:
		return
	var dt := minf(_acc, 0.3)
	_acc = 0.0
	_update(dt, face)


# ==========================================================================
# Build
# ==========================================================================

func _dims_key() -> String:
	return "%s|%s|%s" % [sex, age, build]


func _mesh_key() -> String:
	return "hm|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [_dims_key(), hair_style, hat, outfit, _bottom_kind(), glasses_style if glasses else "-",
		headphones, sash, facial_hair, lipstick]


func _build() -> void:
	_d = _make_dims()
	_has_skirt = _bottom_kind() == "skirt" or _bottom_kind() == "dress"
	var h := get_height()
	_rs = h / _d.base_h
	_rg = _rest_globals(_d)
	_rl.resize(NB)
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.scale = Vector3.ONE * _rs
	add_child(_rig)
	_skel = Skeleton3D.new()
	_skel.name = "Skeleton"
	_rig.add_child(_skel)
	for i in NB:
		_skel.add_bone(BONE_NAMES[i])
	for i in NB:
		var par: int = BONE_PARENT[i]
		if par >= 0:
			_skel.set_bone_parent(i, par)
		_rl[i] = _rg[i] - (_rg[par] if par >= 0 else Vector3.ZERO)
		_skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, _rl[i]))
	_skel.reset_bone_poses()
	var key := _mesh_key()
	var mesh: ArrayMesh = _cache.get(key)
	if mesh == null:
		var mb := MB.new()
		_build_geometry(mb)
		mesh = _commit(mb)
		_cache[key] = mesh
	var skin_key := "skin|" + _dims_key()
	var sk: Skin = _cache.get(skin_key)
	if sk == null:
		sk = _skel.create_skin_from_rest_transforms()
		_cache[skin_key] = sk
	_mi = MeshInstance3D.new()
	_mi.name = "Body"
	_mi.mesh = mesh
	_mi.skin = sk
	_mi.custom_aabb = AABB(Vector3(-1.1, -0.2, -1.3), Vector3(2.2, 2.6, 2.6))
	_skel.add_child(_mi)
	_mi.skeleton = NodePath("..")
	_apply_materials()
	_vis = VisibleOnScreenNotifier3D.new()
	_vis.name = "Vis"
	_vis.aabb = AABB(Vector3(-1.0, -0.2, -1.2), Vector3(2.0, 2.4, 2.4))
	add_child(_vis)
	_q.resize(NB)
	_e.resize(NB)
	for i in NB:
		_q[i] = Quaternion.IDENTITY
		_e[i] = Vector3.ZERO
	if blanket:
		_ensure_blanket()
		_blanket_mi.visible = _pose_id == P_LIE


func _make_dims() -> Dims:
	var d := Dims.new()
	d.female = sex == "f"
	d.child = age == "child"
	d.elder = age == "elder"
	d.heavy = 1.0 if build == "heavy" else 0.0
	d.slim = 1.0 if build == "slim" else 0.0
	d.hs = 1.1
	d.foot_k = 1.05
	d.eye_r = 0.017
	if d.child:
		d.vy = 0.715
		d.hx = 0.72
		d.hs = 0.99
		d.hk = 0.74
		d.foot_k = 0.74
		d.nose_k = 0.62
		d.brow_k = 0.2
		d.cheek_k = 1.35
		d.jaw_k = 0.9
		d.eye_r = 0.019
	elif d.female:
		d.vy = 0.935
		d.hs = 1.06
		d.hk = 0.88
		d.foot_k = 0.92
		d.nose_k = 0.8
		d.lip_k = 1.25
		d.brow_k = 0.35
		d.cheek_k = 1.1
		d.jaw_k = 0.9
		d.eye_r = 0.0182
	if d.elder:
		d.vy *= 0.985
		d.nose_k *= 1.12
		d.ear_k = 1.15
		d.cheek_k *= 0.7
	var vy := d.vy
	d.ankle_h = 0.075 * vy
	d.shin = 0.425 * vy
	d.thigh = 0.435 * vy
	d.hipj_y = d.ankle_h + d.shin + d.thigh
	d.hips_y = d.hipj_y + 0.04 * vy
	d.spine_y = 1.075 * vy
	d.chest_y = 1.25 * vy
	d.neck_y = 1.455 * vy
	d.head_y = (d.neck_y + 0.105 * vy) if not d.child else d.neck_y + 0.09
	d.hip_x = 0.088 * d.hx * (1.05 if d.female else 1.0)
	d.sh_x = 0.172 * d.hx * (0.89 if d.female else 1.0) * (1.0 + 0.08 * d.heavy - 0.03 * d.slim)
	d.sh_y = 1.4 * vy
	d.clav_x = 0.025 * d.hx
	d.uarm = 0.285 * vy
	d.farm = 0.255 * vy
	d.arm_k = (0.84 if d.female else 1.0) * (0.74 if d.child else 1.0) * (1.0 + 0.15 * d.heavy - 0.1 * d.slim)
	d.leg_k = (0.94 if d.female else 1.0) * (0.74 if d.child else 1.0) * (1.0 + 0.14 * d.heavy - 0.08 * d.slim)
	d.neck_r = (0.046 if d.female else 0.056) * (0.8 if d.child else 1.0) * (1.0 + 0.12 * d.heavy - 0.04 * d.slim)
	d.base_h = d.head_y + CROWN * d.hs
	d.mouth_w = 0.0225 if d.female else 0.0235
	d.eye = Vector3(0.0365, 0.068, 0.0)
	d.eye.z = _head_surf(d, d.eye.x, d.eye.y) + d.eye_r - 0.005
	d.mouth_z = _head_surf(d, 0.0, 0.0)
	return d


static func _rest_globals(d: Dims) -> PackedVector3Array:
	var g := PackedVector3Array()
	g.resize(NB)
	var hs := d.hs
	g[HIPS] = Vector3(0, d.hips_y, 0)
	g[SPINE] = Vector3(0, d.spine_y, -0.004)
	g[CHEST] = Vector3(0, d.chest_y, 0)
	g[NECK] = Vector3(0, d.neck_y, 0.006)
	var h := Vector3(0, d.head_y, 0)
	g[HEAD] = h
	g[JAW] = h + Vector3(0, 0.03, 0.008) * hs
	g[ULIP] = h + Vector3(0, 0.005, d.mouth_z) * hs
	g[PONY] = h + Vector3(0, 0.113, 0.102) * hs
	g[SK_F] = Vector3(0, d.hipj_y, 0)
	g[SK_B] = Vector3(0, d.hipj_y, 0)
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var eye := Vector3(m * d.eye.x, d.eye.y, d.eye.z) * hs
		g[EYE_L + s] = h + eye
		g[LID_L + s] = h + eye
		g[LLID_L + s] = h + eye
		g[BROW_L + s] = h + Vector3(m * 0.037, 0.098, _head_surf(d, 0.037, 0.098) - 0.002) * hs
		g[MC_L + s] = h + Vector3(m * d.mouth_w, 0.0, _head_surf(d, d.mouth_w, 0.0)) * hs
		var o := s * AS
		var sh := Vector3(m * d.sh_x, d.sh_y, 0.005)
		g[CLAV_L + o] = Vector3(m * d.clav_x, d.sh_y + 0.012 * d.vy, 0.0)
		g[UARM_L + o] = sh
		g[FARM_L + o] = sh + Vector3(0, -d.uarm, 0)
		var wr := sh + Vector3(0, -d.uarm - d.farm, 0)
		g[HAND_L + o] = wr
		g[FING_L + o] = wr + Vector3(0, -0.093, 0.004) * d.hk
		g[FING2_L + o] = wr + Vector3(0, -0.133, 0.004) * d.hk
		g[INDEX_L + o] = wr + Vector3(0, -0.093, -0.026) * d.hk
		g[INDEX2_L + o] = wr + Vector3(0, -0.129, -0.026) * d.hk
		g[THUMB_L + o] = wr + Vector3(-m * 0.006, -0.022, -0.026) * d.hk
		var l := s * LS
		g[THIGH_L + l] = Vector3(m * d.hip_x, d.hipj_y, 0)
		g[SHIN_L + l] = Vector3(m * d.hip_x, d.hipj_y - d.thigh, 0)
		g[FOOT_L + l] = Vector3(m * d.hip_x, d.ankle_h, 0)
	return g


# ---------------------------------------------------------------- math

static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Smooth lookup in a table with increasing keys (cubic Hermite).
static func _tab(ys: Array, vs: Array, y: float) -> float:
	var n := ys.size()
	if y <= float(ys[0]):
		return float(vs[0])
	if y >= float(ys[n - 1]):
		return float(vs[n - 1])
	var i := 0
	while i < n - 2 and y > float(ys[i + 1]):
		i += 1
	var y0: float = ys[i]
	var y1: float = ys[i + 1]
	var v0: float = vs[i]
	var v1: float = vs[i + 1]
	var h := y1 - y0
	var t := (y - y0) / h
	var m0 := v1 - v0
	var m1 := v1 - v0
	if i > 0:
		m0 = (v1 - float(vs[i - 1])) / (y1 - float(ys[i - 1])) * h
	if i < n - 2:
		m1 = (float(vs[i + 2]) - v0) / (float(ys[i + 2]) - y0) * h
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * v0 + (t3 - 2.0 * t2 + t) * m0 + (-2.0 * t3 + 3.0 * t2) * v1 + (t3 - t2) * m1


## A rotation followed by a local non-uniform scale.
static func _bs(b: Basis, s: Vector3) -> Basis:
	return b * Basis.from_scale(s)


static func _w1(b: int) -> PackedFloat32Array:
	return PackedFloat32Array([b, 1.0, 0, 0.0, 0, 0.0, 0, 0.0])


static func _w2(b0: int, b1: int, t: float) -> PackedFloat32Array:
	return PackedFloat32Array([b0, 1.0 - t, b1, t, 0, 0.0, 0, 0.0])


## Any number of [bone, weight] pairs: keeps the top 4 and normalises them.
static func _wn(pairs: Array) -> PackedFloat32Array:
	var live: Array = []
	for i in range(0, pairs.size(), 2):
		if float(pairs[i + 1]) > 0.001:
			live.append([int(pairs[i]), float(pairs[i + 1])])
	live.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var out := PackedFloat32Array([0, 0.0, 0, 0.0, 0, 0.0, 0, 0.0])
	var tot := 0.0
	for k in mini(live.size(), 4):
		tot += float(live[k][1])
	if tot <= 0.0:
		out[1] = 1.0
		return out
	for k in mini(live.size(), 4):
		out[k * 2] = float(live[k][0])
		out[k * 2 + 1] = float(live[k][1]) / tot
	return out


# ---------------------------------------------------------------- mesh accumulation

static func _push_vertex(s: Slot, p: Vector3, n: Vector3, col: Color, w8: PackedFloat32Array, wo: int, uv_in := Vector2(-999, -999)) -> void:
	var uv := uv_in
	var an := n.abs()
	var tg: Vector3
	if an.x >= an.y and an.x >= an.z:
		tg = Vector3(0, 0, signf(n.x) if n.x != 0.0 else 1.0)
		if uv_in.x < -900.0:
			uv = Vector2(p.z * tg.z, -p.y)
	elif an.y >= an.z:
		tg = Vector3(1, 0, 0)
		if uv_in.x < -900.0:
			uv = Vector2(p.x, p.z * (signf(n.y) if n.y != 0.0 else 1.0))
	else:
		tg = Vector3(-signf(n.z) if n.z != 0.0 else 1.0, 0, 0)
		if uv_in.x < -900.0:
			uv = Vector2(p.x * tg.x, -p.y)
	tg = tg - n * tg.dot(n)
	if tg.length_squared() < 1e-6:
		tg = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT)
	tg = tg.normalized()
	s.v.append(p)
	s.n.append(n)
	s.uv.append(uv)
	s.c.append(col)
	s.t.append(tg.x)
	s.t.append(tg.y)
	s.t.append(tg.z)
	s.t.append(1.0)
	for k in 4:
		s.b.append(int(w8[wo + k * 2]))
		s.w.append(w8[wo + k * 2 + 1])


static func _tri(s: Slot, a: int, b: int, c: int) -> void:
	var pa := s.v[a]
	var pb := s.v[b]
	var pc := s.v[c]
	var fn := (pc - pa).cross(pb - pa)
	if fn.length_squared() < 1e-18:
		return
	if fn.dot(s.n[a] + s.n[b] + s.n[c]) < 0.0:
		var tmp := b
		b = c
		c = tmp
	s.i.append(a)
	s.i.append(b)
	s.i.append(c)


## Adds a grid of rows*cols points (row-major) with smooth normals.
## W holds 8 floats per vertex (bone, weight x4). Normals point away from each row's centre,
## or from `centers` when given. `skip(row, col)` drops quads. `flip` turns the surface inside out.
static func _grid(mb: MB, sname: String, P: PackedVector3Array, rows: int, cols: int, wrap: bool, W: PackedFloat32Array,
		C: PackedColorArray = PackedColorArray(), skip: Callable = Callable(), flip := false,
		uvs: PackedVector2Array = PackedVector2Array(), centers: PackedVector3Array = PackedVector3Array()) -> void:
	var s := mb.slot(sname)
	var base := s.v.size()
	var cen := PackedVector3Array()
	cen.resize(rows)
	for r in rows:
		if centers.size() == rows:
			cen[r] = centers[r]
		else:
			var acc := Vector3.ZERO
			for c in cols:
				acc += P[r * cols + c]
			cen[r] = acc / float(cols)
	var axis := Vector3.ZERO
	if centers.size() == 0 or rows > 2:
		axis = cen[rows - 1] - cen[0]
		if axis.length_squared() > 1e-8:
			axis = axis.normalized()
	for r in rows:
		var seam := not wrap and cols > 2 and P[r * cols].distance_squared_to(P[r * cols + cols - 1]) < 1e-12
		for c in cols:
			var i := r * cols + c
			var p := P[i]
			var cl := c - 1
			var cr := c + 1
			if wrap:
				cl = (c - 1 + cols) % cols
				cr = (c + 1) % cols
			elif seam:
				if c == 0:
					cl = cols - 2
				elif c == cols - 1:
					cr = 1
			else:
				cl = maxi(cl, 0)
				cr = mini(cr, cols - 1)
			var du := P[r * cols + cr] - P[r * cols + cl]
			var rd := mini(r + 1, rows - 1)
			var ru := maxi(r - 1, 0)
			if axis != Vector3.ZERO:
				if ru != r:
					var dp := P[i] - P[ru * cols + c]
					if absf(dp.dot(axis)) < 0.2 * dp.length() and rd != r:
						ru = r
				if rd != r:
					var dn := P[rd * cols + c] - P[i]
					if absf(dn.dot(axis)) < 0.2 * dn.length() and ru != r:
						rd = r
			var dv := P[rd * cols + c] - P[ru * cols + c]
			var n := du.cross(dv)
			var out := p - cen[r]
			if n.length_squared() < 1e-16:
				var rn := rd if rd != r else ru
				n = p - cen[rn]
				if n.length_squared() < 1e-16:
					n = out if out.length_squared() > 1e-16 else Vector3.UP
			elif n.dot(out) < 0.0:
				n = -n
			n = n.normalized()
			if flip:
				n = -n
			var col := C[i] if C.size() > i else Color.WHITE
			if uvs.size() > i:
				_push_vertex(s, p, n, col, W, i * 8, uvs[i])
			else:
				_push_vertex(s, p, n, col, W, i * 8)
	var ncols := cols if wrap else cols - 1
	for r in rows - 1:
		for c in ncols:
			if skip.is_valid() and skip.call(r, c):
				continue
			var c2 := (c + 1) % cols
			var a := base + r * cols + c
			var b := base + r * cols + c2
			var cc := base + (r + 1) * cols + c
			var dd := base + (r + 1) * cols + c2
			_tri(s, a, b, cc)
			_tri(s, cc, b, dd)


## Adds an existing mesh as a rigid part with the given weights.
static func _rigid(mb: MB, sname: String, mesh: Mesh, xf: Transform3D, w8: PackedFloat32Array, col := Color.WHITE, flip := false) -> void:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var s := mb.slot(sname)
	var base := s.v.size()
	var nb := xf.basis.inverse().transposed()
	for k in verts.size():
		var n := (nb * norms[k]).normalized()
		if flip:
			n = -n
		_push_vertex(s, xf * verts[k], n, col, w8, 0)
	var idx: Variant = arr[Mesh.ARRAY_INDEX]
	if idx != null and (idx as PackedInt32Array).size() > 0:
		var ii: PackedInt32Array = idx
		for k in range(0, ii.size(), 3):
			_tri(s, base + ii[k], base + ii[k + 1], base + ii[k + 2])
	else:
		for k in range(0, verts.size(), 3):
			_tri(s, base + k, base + k + 1, base + k + 2)


static func _commit(mb: MB) -> ArrayMesh:
	var am := ArrayMesh.new()
	for sname: String in mb.order:
		var s: Slot = mb.slots[sname]
		if s.i.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s.v
		arr[Mesh.ARRAY_NORMAL] = s.n
		arr[Mesh.ARRAY_TANGENT] = s.t
		arr[Mesh.ARRAY_TEX_UV] = s.uv
		arr[Mesh.ARRAY_COLOR] = s.c
		arr[Mesh.ARRAY_BONES] = s.b
		arr[Mesh.ARRAY_WEIGHTS] = s.w
		arr[Mesh.ARRAY_INDEX] = s.i
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_name(am.get_surface_count() - 1, sname)
	return am


## Tube sweep: `path` rows, each an ellipse (ra along `side`, rb along `up`). Grid in one call.
static func _sweep(mb: MB, sname: String, path: PackedVector3Array, ra: PackedFloat32Array, rb: PackedFloat32Array, sides: int,
		W: PackedFloat32Array, C: PackedColorArray = PackedColorArray(), side_hint := Vector3.RIGHT) -> void:
	var rows := path.size()
	var P := PackedVector3Array()
	var WW := PackedFloat32Array()
	var CC := PackedColorArray()
	var cen := PackedVector3Array()
	for r in rows:
		var tan: Vector3
		if r == 0:
			tan = path[1] - path[0]
		elif r == rows - 1:
			tan = path[rows - 1] - path[rows - 2]
		else:
			tan = path[r + 1] - path[r - 1]
		tan = tan.normalized()
		var sd := side_hint - tan * side_hint.dot(tan)
		if sd.length_squared() < 1e-6:
			sd = tan.cross(Vector3.BACK)
		sd = sd.normalized()
		var up := tan.cross(sd).normalized()
		cen.append(path[r])
		for c in sides:
			var a := TAU * c / sides
			P.append(path[r] + sd * cos(a) * ra[r] + up * sin(a) * rb[r])
			for k in 8:
				WW.append(W[r * 8 + k])
			if C.size() > 0:
				CC.append(C[r])
	_grid(mb, sname, P, rows, sides, true, WW, CC, Callable(), false, PackedVector2Array(), cen)


## A ribbon lying on a surface: rows of 3 points across, `nrm` is the surface normal for each row.
static func _ribbon(mb: MB, sname: String, path: PackedVector3Array, nrm: PackedVector3Array, widths: PackedFloat32Array, W: PackedFloat32Array, raise := 0.0015) -> void:
	var rows := path.size()
	var P := PackedVector3Array()
	var WW := PackedFloat32Array()
	var cen := PackedVector3Array()
	for r in rows:
		var tan: Vector3
		if r == 0:
			tan = path[1] - path[0]
		elif r == rows - 1:
			tan = path[rows - 1] - path[rows - 2]
		else:
			tan = path[r + 1] - path[r - 1]
		tan = tan.normalized()
		var n := nrm[r].normalized()
		var sd := n.cross(tan).normalized()
		P.append(path[r] - sd * widths[r] * 0.5)
		P.append(path[r] + n * raise)
		P.append(path[r] + sd * widths[r] * 0.5)
		cen.append(path[r] - n * 0.05)
		for k in 3:
			for j in 8:
				WW.append(W[r * 8 + j])
	_grid(mb, sname, P, rows, 3, false, WW, PackedColorArray(), Callable(), false, PackedVector2Array(), cen)


# ==========================================================================
# Head shape
# ==========================================================================

## Returns (half-width, front depth, back depth) of the bare skull at height y.
static func _hprof(d: Dims, y: float) -> Vector3:
	var rx: float
	var zf: float
	var zb: float
	if y >= 0.105:
		var k := sqrt(maxf(0.0, 1.0 - pow((y - 0.105) / (CROWN - 0.105), 2.0)))
		rx = 0.086 * k
		zf = 0.086 * k
		zb = 0.102 * k
	else:
		rx = maxf(_tab(HY, HRX, y), 0.0)
		zf = maxf(_tab(HY, HZF, y), 0.0)
		zb = maxf(_tab(HY, HZB, y), 0.0)
		var low := 1.0 - _ss(-0.02, 0.045, y)
		rx *= lerpf(1.0, d.jaw_k, low)
		var closed := _ss(-0.047, -0.04, y)
		rx += 0.006 * d.heavy * low * closed
		zb += 0.004 * d.heavy * low * closed
		zf += 0.002 * d.heavy * low * closed
	return Vector3(rx, zf, zb)


## Bare skull point at azimuth a (0 = front, +pi/2 = right) and height y.
static func _head_base(d: Dims, a: float, y: float) -> Vector3:
	var p := _hprof(d, y)
	var s := sin(a)
	var c := cos(a)
	var e := 2.0 / HN
	var x := p.x * signf(s) * pow(absf(s), e)
	var z: float
	if c >= 0.0:
		z = -p.y * pow(c, e)
	else:
		z = p.z * pow(-c, e)
	return Vector3(x, y, z)


## Forward displacement of the face (nose, sockets, brow, cheeks, lips, chin).
static func _hdisp(d: Dims, x: float, y: float) -> float:
	var ax := absf(x)
	var out := 0.0
	# nose: a soft button tip on a slim bridge
	var h := _tab([0.02, 0.026, 0.031, 0.037, 0.043, 0.052, 0.062, 0.075, 0.088, 0.098],
		[0.0, 0.007, 0.0145, 0.018, 0.0155, 0.0105, 0.0068, 0.0046, 0.0036, 0.0], y)
	var sg := _tab([0.02, 0.031, 0.04, 0.06, 0.085], [0.015, 0.0115, 0.0098, 0.0072, 0.0072], y)
	out += d.nose_k * maxf(h, 0.0) * exp(-(x * x) / (sg * sg))
	var ala_dx := ax - 0.0135
	var ala_dy := y - 0.0315
	out += d.nose_k * 0.0048 * exp(-(ala_dx * ala_dx) / (0.0052 * 0.0052) - (ala_dy * ala_dy) / (0.0056 * 0.0056))
	# sockets
	var eye_dx := ax - 0.0365
	var eye_dy := y - 0.07
	out -= 0.0085 * exp(-(eye_dx * eye_dx) / (0.021 * 0.021) - (eye_dy * eye_dy) / (0.014 * 0.014))
	# brow ridge
	var brow_dy := y - 0.095
	out += (0.0015 + d.brow_k * 0.0034) * exp(-(brow_dy * brow_dy) / (0.0075 * 0.0075)) * (1.0 - _ss(0.05, 0.072, ax))
	# cheekbones, and a soft hollow under them
	var ch_dx := ax - 0.05
	var ch_dy := y - 0.043
	out += 0.0072 * d.cheek_k * exp(-(ch_dx * ch_dx) / (0.021 * 0.021) - (ch_dy * ch_dy) / (0.0165 * 0.0165))
	var ho_dx := ax - 0.052
	var ho_dy := y - 0.012
	out -= 0.0022 / maxf(d.cheek_k, 0.5) * exp(-(ho_dx * ho_dx) / (0.015 * 0.015) - (ho_dy * ho_dy) / (0.012 * 0.012))
	# lips
	var lw := 1.0 - _ss(0.015, 0.0285, ax)
	var ul := y - 0.0052
	var ll := y + 0.0066
	out += d.lip_k * 0.0032 * exp(-(ul * ul) / (0.0042 * 0.0042)) * lw
	out += d.lip_k * 0.0038 * exp(-(ll * ll) / (0.0048 * 0.0048)) * lw
	out -= 0.002 * exp(-(y * y) / (0.0016 * 0.0016)) * (1.0 - _ss(0.026, 0.032, ax))
	# philtrum, the crease under the lip, the chin
	var ph_y := y - 0.0155
	out -= 0.0009 * exp(-(x * x) / (0.0032 * 0.0032) - (ph_y * ph_y) / (0.0052 * 0.0052))
	var cr_y := y + 0.0155
	out -= 0.0018 * exp(-(cr_y * cr_y) / (0.0036 * 0.0036)) * (1.0 - _ss(0.014, 0.026, ax))
	var cy := y + 0.03
	out += 0.0046 * exp(-(x * x) / (0.015 * 0.015) - (cy * cy) / (0.0095 * 0.0095))
	return out


## z of the face surface at (x, y) in head space (negative = front).
static func _head_surf(d: Dims, x: float, y: float) -> float:
	var p := _hprof(d, y)
	if p.x <= 0.0001:
		return 0.0
	var s := pow(clampf(absf(x) / p.x, 0.0, 0.999), HN * 0.5)
	var c := sqrt(maxf(0.0, 1.0 - s * s))
	return -p.y * pow(c, 2.0 / HN) - _hdisp(d, x, y) * c


## Outward normal of the face surface at (x, y).
static func _head_nrm(d: Dims, x: float, y: float) -> Vector3:
	var e := 0.002
	var fx := (_head_surf(d, x + e, y) - _head_surf(d, x - e, y)) / (2.0 * e)
	var fy := (_head_surf(d, x, y + e) - _head_surf(d, x, y - e)) / (2.0 * e)
	return Vector3(fx, fy, -1.0).normalized()


func _head_col(p: Vector3, a: float) -> Color:
	var d := _d
	var ax := absf(p.x)
	var y := p.y
	var col := Color.WHITE
	var fr := _ss(0.2, 0.7, cos(a))
	# painted shading gives the face its illustrated planes
	var blush_k := 0.5 if not d.female else 0.75
	if d.child:
		blush_k = 0.9
	var bx := ax - 0.052
	var by := y - 0.03
	col = col.lerp(Color(1.0, 0.84, 0.80), exp(-(bx * bx + by * by) / (0.028 * 0.028)) * blush_k * fr * 0.6)
	var ex := ax - d.eye.x
	var ey := y - d.eye.y
	var sock := exp(-(ex * ex) / (0.021 * 0.021) - (ey * ey) / (0.0145 * 0.0145)) * fr
	col = col.lerp(Color(0.80, 0.68, 0.66), sock * (0.85 if d.elder else 0.6))
	var sn_x := ax - 0.0165
	var sn_y := y - 0.06
	col = col.lerp(Color(0.86, 0.74, 0.72), exp(-(sn_x * sn_x) / (0.0065 * 0.0065) - (sn_y * sn_y) / (0.02 * 0.02)) * fr * 0.6)
	var un_y := y - 0.0235
	col = col.lerp(Color(0.86, 0.72, 0.70), exp(-(p.x * p.x) / (0.0125 * 0.0125) - (un_y * un_y) / (0.0028 * 0.0028)) * fr)
	var nx := ax - 0.0072
	var ny := y - 0.027
	col = col.lerp(Color(0.56, 0.40, 0.38), exp(-(nx * nx) / (0.003 * 0.003) - (ny * ny) / (0.002 * 0.002)) * fr)
	var ul_y := y + 0.0155
	col = col.lerp(Color(0.82, 0.68, 0.66), exp(-(ul_y * ul_y) / (0.0036 * 0.0036)) * (1.0 - _ss(0.012, 0.026, ax)) * fr * 0.8)
	col = col.lerp(Color(0.72, 0.58, 0.56), _ss(-0.034, -0.044, y) * 0.8)
	# lips: a cupid's bow on top, a fuller lower lip
	var mw := d.mouth_w * 1.06
	var xk := clampf(ax / mw, 0.0, 1.0)
	var ub := 0.0085 * sqrt(1.0 - xk * xk) * (1.0 - 0.2 * exp(-(p.x * p.x) / (0.0036 * 0.0036))) + 0.0006
	var lb := 0.0108 * pow(1.0 - xk * xk, 0.6) + 0.0006
	var lip_m := 0.0
	if ax < mw:
		lip_m = (1.0 - _ss(ub * 0.72, ub * 1.12, y)) if y >= 0.0 else (1.0 - _ss(lb * 0.72, lb * 1.12, -y))
	lip_m *= fr
	var lip_c := Color(0.90, 0.70, 0.66)
	if d.female:
		lip_c = Color(0.86, 0.60, 0.58)
	if lipstick:
		lip_c = Color(0.80, 0.42, 0.40)
	col = col.lerp(lip_c, lip_m)
	# the line between the lips
	col = col.lerp(Color(0.34, 0.16, 0.15), _ss(0.0032, 0.001, absf(y)) * (1.0 - _ss(mw * 0.85, mw * 1.2, ax)) * fr * 0.85)
	return col


func _w_head(p: Vector3, a: float) -> PackedFloat32Array:
	var d := _d
	var ax := absf(p.x)
	var y := p.y
	var front := _ss(0.012, -0.055, p.z)
	var inside := 1.0 - _ss(d.mouth_w * 0.85, d.mouth_w * 1.3, ax)
	var w_in := 1.0 if y < 0.0 else 0.0
	w_in *= 1.0 - 0.7 * _ss(d.mouth_w * 0.75, d.mouth_w * 1.05, ax)
	var w_out := _ss(0.004, -0.02, y)
	var wj := lerpf(w_out, w_in, inside) * front
	var cx := ax - d.mouth_w
	var cy := y * 1.3
	var wm := exp(-(cx * cx + cy * cy) / (0.011 * 0.011)) * 0.85 * _ss(0.3, 0.8, cos(a))
	var ul := y - 0.004
	var wu := 0.0
	if y > 0.0:
		wu = exp(-(ul * ul) / (0.006 * 0.006)) * (1.0 - _ss(d.mouth_w * 0.7, d.mouth_w * 1.2, ax)) * front * 0.9
	var mc := MC_R if p.x > 0.0 else MC_L
	var total := wj + wm + wu
	if total > 1.0:
		wj /= total
		wm /= total
		wu /= total
		total = 1.0
	return _wn([HEAD, 1.0 - total, JAW, wj, mc, wm, ULIP, wu])


func _b_head(mb: MB) -> void:
	var d := _d
	var H := _rg[HEAD]
	var rows := HROWS.size()
	var cols := 36
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var C := PackedColorArray()
	var ang := PackedFloat32Array()
	var mw := d.mouth_w
	var r_lo := HROWS.find(-0.0008)
	for c in cols:
		var t := float(c) / cols * 2.0 - 1.0
		ang.append(PI * signf(t) * pow(absf(t), 1.6))
	for r in rows:
		var y: float = HROWS[r]
		for c in cols:
			var a: float = ang[c]
			var bp := _head_base(d, a, y)
			var fr := clampf(cos(a), 0.0, 1.0)
			var p := bp
			p.z -= _hdisp(d, bp.x, y) * fr
			var mk := absf(p.x) / mw
			p.y += 0.0013 * minf(mk * mk, 1.4) * _ss(0.016, 0.003, absf(y)) * fr
			W.append_array(_w_head(p, a))
			C.append(_head_col(p, a))
			if r == r_lo or r == r_lo + 1:
				var ax := absf(p.x)
				var inner := 1.0 - _ss(mw * 0.72, mw * 0.98, ax)
				if r == r_lo:
					p.y += 0.0012 * inner + 0.0008 * (1.0 - inner) * (1.0 - _ss(mw * 1.0, mw * 1.3, ax))
					p.z += 0.0015 * inner
				else:
					p.y -= 0.0012 * inner + 0.0008 * (1.0 - inner) * (1.0 - _ss(mw * 1.0, mw * 1.3, ax))
					p.z += 0.0011 * inner
			P.append(H + p * d.hs)
	var style := _hair_eff()
	var covered := style != "bald" and style != "balding"
	var skip := func(r: int, c: int) -> bool:
		var c2 := (c + 1) % cols
		if r == r_lo:
			var xm := (P[r * cols + c].x + P[r * cols + c2].x) * 0.5
			if absf(xm) < mw * d.hs:
				return true
		# skull that sits under the hair is never seen
		if covered and float(HROWS[r]) > 0.03:
			var y0: float = HROWS[r]
			return y0 > _hair_edge(ang[c], style) + 0.016 and y0 > _hair_edge(ang[c2], style) + 0.016
		return false
	_grid(mb, "skin", P, rows, cols, true, W, C, skip)
	_b_mouth_inside(mb)


func _b_mouth_inside(mb: MB) -> void:
	var d := _d
	var H := _rg[HEAD]
	var hs := d.hs
	var mw := d.mouth_w
	var z0 := d.mouth_z
	# inward-facing dark pocket behind the lips
	var rows := 6
	var cols := 8
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var C := PackedColorArray()
	var ctr := Vector3(0, -0.002, z0 + 0.024)
	for r in rows:
		var b := PI * float(r) / (rows - 1)
		for c in cols:
			var a := TAU * c / cols
			var l := Vector3(sin(b) * cos(a) * mw * 1.15, cos(b) * 0.017, sin(b) * sin(a) * 0.021)
			P.append(H + (ctr + l) * hs)
			W.append_array(_w2(HEAD, JAW, _ss(0.004, -0.007, l.y)))
			C.append(Color(0.15, 0.045, 0.045))
	_grid(mb, "vc", P, rows, cols, true, W, C, Callable(), true)
	# teeth: a strip behind each lip that follows the face, hidden while the mouth is shut
	for jaw_side in 2:
		var tp := PackedVector3Array()
		var tw := PackedFloat32Array()
		var tc := PackedColorArray()
		var cen := PackedVector3Array()
		var y0 := 0.0055 if jaw_side == 0 else -0.0025
		var y1 := -0.0024 if jaw_side == 0 else -0.009
		var inset := 0.006 if jaw_side == 0 else 0.0085
		for r in 2:
			var yy := y0 if r == 0 else y1
			cen.append(H + Vector3(0, yy, z0 + 0.04) * hs)
			for c in 7:
				var u := (float(c) / 6.0) * 2.0 - 1.0
				var x := u * mw * 0.78
				var z := _head_surf(d, x, 0.0) + inset + 0.002 * u * u
				tp.append(H + Vector3(x, yy, z) * hs)
				tw.append_array(_w1(HEAD if jaw_side == 0 else JAW))
				tc.append(Color(0.86, 0.84, 0.78))
		_grid(mb, "vc", tp, 2, 7, false, tw, tc, Callable(), false, PackedVector2Array(), cen)


func _b_eyes(mb: MB) -> void:
	var d := _d
	var hs := d.hs
	var r_eye := d.eye_r
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var E := _rg[EYE_L + s]
		# eyeball
		var rows := 6
		var cols := 10
		var P := PackedVector3Array()
		var W := PackedFloat32Array()
		var UV := PackedVector2Array()
		var betas := [0.0, 0.28, 0.56, 0.86, 1.2, 1.7]
		for r in rows:
			var b: float = betas[r]
			for c in cols:
				var a := TAU * c / cols
				var l := Vector3(sin(b) * cos(a), sin(b) * sin(a), -cos(b))
				P.append(E + l * r_eye * hs)
				W.append_array(_w1(EYE_L + s))
				UV.append(Vector2(0.5 + l.x * 0.5, 0.5 - l.y * 0.5))
		var cen := PackedVector3Array()
		for r in rows:
			cen.append(E)
		_grid(mb, "eye", P, rows, cols, true, W, PackedColorArray(), Callable(), false, UV, cen)
		# lids, gently turned outward to wrap the face
		var yaw := -m * 0.12
		_b_lid(mb, s, true, r_eye, yaw, E, hs)
		_b_lid(mb, s, false, r_eye, yaw, E, hs)


func _b_lid(mb: MB, s: int, upper: bool, r_eye: float, yaw: float, E: Vector3, hs: float) -> void:
	var cols := 11 if upper else 9
	var a_max := 1.22
	var m := -1.0 if s == 0 else 1.0
	var lash := Color(0.12, 0.085, 0.075)
	if _d.female or _d.child:
		lash = Color(0.06, 0.045, 0.04)
	var shadow := Color(0.97, 0.93, 0.92)
	if lipstick:
		shadow = Color(0.90, 0.88, 0.95)
	var rows_def: Array
	if upper:
		# beta offset from the lid edge, radius added to the eye, colour, lid-bone weight
		rows_def = [[0.0, 0.0002, lash, 1.0], [0.0, 0.0023, lash, 1.0], [0.085, 0.0027, Color(0.42, 0.33, 0.31), 1.0],
			[0.19, 0.0025, shadow, 1.0], [0.34, 0.0022, Color(0.74, 0.60, 0.58), 0.95], [0.5, 0.0024, Color(0.97, 0.92, 0.90), 0.8], [-1.0, 0.0016, Color.WHITE, 0.1]]
	else:
		rows_def = [[0.0, 0.0002, Color(0.52, 0.36, 0.34), 1.0], [0.0, 0.0012, Color(0.84, 0.66, 0.64), 1.0],
			[-0.11, 0.0015, Color(0.96, 0.88, 0.86), 0.9], [-1.0, 0.001, Color.WHITE, 0.12]]
	var bone := (LID_L if upper else LLID_L) + s
	var nrows := rows_def.size()
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var C := PackedColorArray()
	var cen := PackedVector3Array()
	for r in nrows:
		var def: Array = rows_def[r]
		cen.append(E)
		for c in cols:
			var al := -a_max + 2.0 * a_max * c / (cols - 1)
			var k := al / a_max
			var edge := 0.50 - 0.60 * k * k if upper else -0.58 + 0.46 * k * k
			edge += 0.1 * k * m # the outer corners sit a little higher than the inner ones
			var beta: float
			if float(def[0]) == -1.0:
				beta = 1.35 if upper else -1.2
			else:
				beta = edge + float(def[0])
			var rr := r_eye + float(def[1])
			var dir := Vector3(sin(al) * cos(beta), sin(beta), -cos(al) * cos(beta))
			dir = dir.rotated(Vector3.UP, yaw)
			P.append(E + dir * rr * hs)
			W.append_array(_w2(HEAD, bone, float(def[3])))
			C.append(def[2])
	_grid(mb, "skin", P, nrows, cols, false, W, C, Callable(), false, PackedVector2Array(), cen)


func _b_face_bits(mb: MB) -> void:
	var d := _d
	var H := _rg[HEAD]
	var hs := d.hs
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		# eyebrow
		var path := PackedVector3Array()
		var ra := PackedFloat32Array()
		var rb := PackedFloat32Array()
		var W := PackedFloat32Array()
		var thick := 1.0 if not d.female else 0.68
		if d.child:
			thick = 0.68
		if d.elder and not d.female:
			thick = 1.2
		var n_pts := 6
		for i in n_pts:
			var u := float(i) / (n_pts - 1)
			var x := lerpf(0.0135, 0.062, u)
			var y := 0.0925 + 0.0088 * sin(pow(u, 0.8) * PI * 0.92) - 0.0035 * u
			var z := _head_surf(d, x, y) - 0.0013
			path.append(H + Vector3(m * x, y, z) * hs)
			var hh := lerpf(0.0052, 0.0016, u * u) * thick
			ra.append(hh * hs)
			rb.append(0.0015 * hs)
			W.append_array(_w1(BROW_L + s))
		_sweep(mb, "brow", path, ra, rb, 5, W, PackedColorArray(), Vector3.UP)
		# ear
		var ey := 0.056
		var ep := _hprof(d, ey)
		var ek := d.ear_k
		var b := Basis.from_euler(Vector3(deg_to_rad(-8.0), m * deg_to_rad(-20.0), m * deg_to_rad(-10.0)))
		b = _bs(b, Vector3(0.0085, 0.028, 0.0175) * ek * hs)
		_rigid(mb, "skin", ModelKit.sphere(1.0, 8, 5), Transform3D(b, H + Vector3(m * (ep.x + 0.0015), ey, 0.012) * hs), _w1(HEAD), Color(0.94, 0.80, 0.78))
	if facial_hair == "moustache":
		var path := PackedVector3Array()
		var ra := PackedFloat32Array()
		var rb := PackedFloat32Array()
		var W := PackedFloat32Array()
		var n_pts := 9
		for i in n_pts:
			var u := (float(i) / (n_pts - 1)) * 2.0 - 1.0
			var x := u * 0.031
			var y := 0.0135 - 0.007 * u * u
			var z := _head_surf(d, x, y) - 0.0026
			path.append(H + Vector3(x, y, z) * hs)
			var rr := lerpf(0.0052, 0.0016, u * u)
			ra.append(rr * hs)
			rb.append(rr * 0.62 * hs)
			W.append_array(_w1(HEAD))
		_sweep(mb, "brow", path, ra, rb, 6, W, PackedColorArray(), Vector3.UP)


# ==========================================================================
# Hair
# ==========================================================================

func _hair_edge(a: float, style: String) -> float:
	var sa := wrapf(a, -PI, PI)
	var ax := absf(sa)
	match style:
		"mop":
			return _tab([0.0, 0.62, 0.92, 1.22, 1.42, 1.72, 2.2, PI], [0.112, 0.112, 0.097, 0.06, 0.072, 0.062, 0.02, -0.004], ax) + 0.0035 * sin(sa * 16.0) * (1.0 - _ss(0.7, 1.0, ax))
		"bob":
			return _tab([0.0, 0.5, 0.74, 1.0, 1.5, 2.3, PI], [0.116, 0.122, 0.085, -0.012, -0.018, -0.022, -0.024], ax) + 0.0028 * sin(sa * 14.0) * (1.0 - _ss(0.4, 0.62, ax))
		"ponytail", "bun":
			var y := _tab([0.0, 0.42, 0.85, 1.25, 1.5, 1.9, 2.4, PI], [0.128, 0.128, 0.11, 0.082, 0.078, 0.068, 0.012, 0.002], ax)
			if style == "ponytail":
				var sw := sa - 0.28
				y -= 0.019 * exp(-(sw * sw) / (0.52 * 0.52))
			return y
		"curly":
			return _tab([0.0, 0.5, 0.95, 1.25, 1.5, 2.0, 2.5, PI], [0.132, 0.128, 0.1, 0.066, 0.056, 0.03, 0.0, -0.008], ax)
		_:
			return _tab([0.0, 0.55, 0.95, 1.2, 1.32, 1.45, 1.85, 2.2, 2.6, PI], [0.14, 0.135, 0.108, 0.06, 0.065, 0.094, 0.088, 0.05, 0.02, 0.012], ax)


func _hair_th(a: float, y: float, t: float, style: String) -> float:
	var front := maxf(cos(a), 0.0)
	# broad sculpted locks running with the hair, only where the columns are dense enough to show them
	var locks := sin(a * 14.0 + sin(y * 30.0) * 0.7) * (1.0 - _ss(0.9, 1.5, absf(wrapf(a, -PI, PI)))) * (1.0 - _ss(0.14, 0.175, y))
	var v := 0.006
	match style:
		"short":
			v = 0.0052 + 0.011 * _ss(0.11, 0.165, y) * (1.0 + 0.4 * front)
			var qy := y - 0.15
			v += 0.0065 * exp(-(qy * qy) / (0.02 * 0.02)) * front * front + 0.0009 * locks * _ss(0.09, 0.13, y)
		"side_part":
			v = 0.005 + 0.016 * _ss(0.105, 0.16, y) * (1.0 + 0.25 * front) + 0.0012 * locks * _ss(0.1, 0.14, y)
			var da := wrapf(a + 0.62, -PI, PI)
			v -= 0.011 * exp(-(da * da) / (0.07 * 0.07)) * _ss(0.13, 0.155, y)
			if a > -0.62 and a < 2.0:
				var sw := (a - 0.2) / 0.9
				v += 0.0065 * _ss(0.12, 0.165, y) * exp(-sw * sw)
		"mop":
			v = 0.0058 + 0.015 * _ss(0.075, 0.16, y) + 0.005 * front * (1.0 - _ss(0.11, 0.14, y)) + 0.0014 * locks
		"bob":
			v = 0.012 + 0.014 * _ss(0.1, 0.165, y) + 0.004 * front * (1.0 - _ss(0.12, 0.15, y)) + 0.0013 * locks
		"ponytail", "bun":
			var cy := y - 0.16
			v = 0.0062 + 0.0075 * _ss(0.09, 0.16, y) + 0.0055 * exp(-(cy * cy) / (0.03 * 0.03)) + 0.0008 * locks * _ss(0.1, 0.14, y)
		"curly":
			var bump := (0.5 + 0.5 * sin(11.0 * a + 3.0 * sin(50.0 * y))) * (0.5 + 0.5 * sin(55.0 * y + 2.0 * a))
			v = 0.012 + 0.012 * _ss(0.05, 0.14, y) + 0.008 * bump * (1.0 - 0.3 * t)
		"balding":
			var ax := absf(wrapf(a, -PI, PI))
			var yb := _tab([0.0, 1.0, 2.0, PI], [0.092, 0.112, 0.135, 0.145], ax)
			return lerpf(0.0045, -0.006, _ss(yb - 0.008, yb + 0.004, y))
	if hat in ["fisherman", "peaked", "helmet"] and y > 0.112:
		v = minf(v, 0.005)
	return v


## The hair actually built (a headscarf hides most of the style).
func _hair_eff() -> String:
	if hat == "headscarf" and hair_style != "bald":
		return "ponytail"
	return hair_style


## Skull normal, used to push hair outward.
static func _skull_n(p: Vector3) -> Vector3:
	return Vector3(p.x / (0.086 * 0.086), (p.y - 0.09) / (0.105 * 0.105), p.z / (0.097 * 0.097)).normalized()


func _b_hair(mb: MB) -> void:
	var d := _d
	var style := _hair_eff()
	if style == "bald":
		return
	var H := _rg[HEAD]
	var hs := d.hs
	var n_up := 8
	var cols := 36
	if style == "curly":
		n_up = 11
	elif style == "balding":
		n_up = 7
	var ang := PackedFloat32Array()
	for c in cols:
		var u := float(c) / cols * 2.0 - 1.0
		ang.append(PI * signf(u) * pow(absf(u), 1.22))
	var rows := n_up + 1
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var hide_mask := PackedByteArray()
	for r in rows:
		var t := 0.0 if r == 0 else float(r - 1) / float(n_up - 1)
		var yk := sin(t * PI * 0.5)
		for c in cols:
			var a: float = ang[c]
			var ye := _hair_edge(a, style)
			var y := lerpf(ye, CROWN, yk)
			var base := _head_base(d, a, y)
			base.z -= _hdisp(d, base.x, y) * maxf(cos(a), 0.0)
			var th := _hair_th(a, y, t, style)
			hide_mask.append(1 if th < 0.0 else 0)
			var n := _skull_n(base)
			var p := base
			if r == 0:
				p = base - n * 0.007
			else:
				p = base + n * th
			if style == "bob" and r > 0:
				# the hair hangs straight down from the widest part of the skull
				var y_ref := 0.09
				if y < y_ref:
					var bref := _head_base(d, a, y_ref)
					var dir := Vector2(bref.x, bref.z).normalized()
					var R := Vector2(bref.x, bref.z).length() + th * 0.7 + (y_ref - y) * 0.12 + 0.012 * _ss(0.012, -0.018, y)
					if R > Vector2(p.x, p.z).length():
						p.x = dir.x * R
						p.z = dir.y * R
			P.append(H + p * hs)
			W.append_array(_w1(HEAD))
	var skip := Callable()
	if style == "balding":
		skip = func(r: int, c: int) -> bool:
			var c2 := (c + 1) % cols
			var r2 := r + 1
			return hide_mask[r * cols + c] == 1 and hide_mask[r * cols + c2] == 1 and hide_mask[r2 * cols + c] == 1 and hide_mask[r2 * cols + c2] == 1
	_grid(mb, "hair", P, rows, cols, true, W, PackedColorArray(), skip)
	if style == "ponytail" and hat == "none":
		var path := PackedVector3Array([Vector3(0, 0.116, 0.086), Vector3(0, 0.113, 0.103), Vector3(0, 0.098, 0.13), Vector3(0, 0.06, 0.147),
			Vector3(0, 0.012, 0.149), Vector3(0, -0.04, 0.14), Vector3(0, -0.088, 0.128), Vector3(0, -0.125, 0.122)])
		var rr := [0.013, 0.0175, 0.028, 0.033, 0.033, 0.027, 0.016, 0.0005]
		var pp := PackedVector3Array()
		var ra := PackedFloat32Array()
		var rb := PackedFloat32Array()
		var ww := PackedFloat32Array()
		for i in path.size():
			pp.append(H + path[i] * hs)
			ra.append(float(rr[i]) * hs)
			rb.append(float(rr[i]) * 0.82 * hs)
			ww.append_array(_w2(HEAD, PONY, _ss(0.0, 2.0, float(i))))
		_sweep(mb, "hair", pp, ra, rb, 8, ww)
		var band := _bs(Basis(Vector3.RIGHT, deg_to_rad(68.0)), Vector3.ONE * hs)
		_rigid(mb, "accent", ModelKit.torus(0.0135, 0.0245, 12, 5), Transform3D(band, H + Vector3(0, 0.113, 0.102) * hs), _w1(HEAD))
	elif style == "bun" and hat == "none":
		var b := Basis.from_scale(Vector3(0.036, 0.032, 0.033) * hs)
		_rigid(mb, "hair", ModelKit.sphere(1.0, 12, 7), Transform3D(b, H + Vector3(0, 0.15, 0.092) * hs), _w1(HEAD))


# ==========================================================================
# Torso
# ==========================================================================

## (half-width, front depth, back depth) of the bare torso at rig height y.
func _tprof(y: float) -> Vector3:
	var d := _d
	var ya := y / d.vy
	var rx := maxf(_tab(TY, TRX, ya), 0.0)
	var zf := maxf(_tab(TY, TZF, ya), 0.0)
	var zb := maxf(_tab(TY, TZB, ya), 0.0)
	if d.female:
		rx *= _tab([0.85, 0.95, 1.01, 1.075, 1.15, 1.24, 1.32, 1.40, 1.485], [1.0, 1.05, 0.95, 0.85, 0.88, 0.90, 0.90, 0.87, 0.85], ya)
		if not d.child:
			zf += 0.03 * exp(-pow((ya - 1.275) / 0.045, 2.0))
			zf *= 1.0 - 0.08 * exp(-pow((ya - 1.075) / 0.06, 2.0))
			zb += 0.012 * exp(-pow((ya - 0.95) / 0.05, 2.0))
	var closed := _ss(0.845, 0.87, ya)
	if d.heavy > 0.0:
		rx *= 1.0 + 0.1 * closed
		rx += 0.02 * exp(-pow((ya - 1.08) / 0.09, 2.0))
		zf += 0.055 * exp(-pow((ya - 1.1) / 0.09, 2.0))
		zb *= 1.0 + 0.08 * closed
	if d.slim > 0.0:
		rx *= 0.93
		zf *= 0.93
		zb *= 0.93
	if d.elder:
		zf += 0.018 * exp(-pow((ya - 1.1) / 0.08, 2.0))
	return Vector3(rx * d.hx, zf * (0.72 if d.child else 1.0), zb * (0.72 if d.child else 1.0))


func _tpt(y: float, a: float, off: float) -> Vector3:
	var p := _tprof(y)
	var s := sin(a)
	var c := cos(a)
	var e := 2.0 / TN
	var k := 1.0
	if p.x < 0.02:
		k = p.x / 0.02
	var x := (p.x + off * k) * signf(s) * pow(absf(s), e)
	var z: float
	if c >= 0.0:
		z = -(p.y + off * k) * pow(c, e)
	else:
		z = (p.z + off * k) * pow(-c, e)
	return Vector3(x, y, z)


## Surface normal of the torso at (y, a), by finite differences.
func _tnrm(y: float, a: float, off: float) -> Vector3:
	var pa := _tpt(y, a + 0.03, off) - _tpt(y, a - 0.03, off)
	var py := _tpt(y + 0.006, a, off) - _tpt(y - 0.006, a, off)
	var n := pa.cross(py).normalized()
	var p0 := _tpt(y, a, off)
	if n.dot(p0 - Vector3(0, y, 0)) < 0.0:
		n = -n
	return n


func _w_torso(p: Vector3) -> PackedFloat32Array:
	var d := _d
	var y := p.y
	var vy := d.vy
	var ax := absf(p.x)
	var m_side := 1 if p.x > 0.0 else 0
	var w_h := 1.0 - _ss(d.hipj_y + 0.03 * vy, d.spine_y + 0.02 * vy, y)
	var w_c := _ss(d.spine_y + 0.03 * vy, d.chest_y + 0.02 * vy, y)
	var w_s := clampf(1.0 - w_h - w_c, 0.0, 1.0)
	var w_n := _ss(d.neck_y - 0.005 * vy, d.neck_y + 0.03 * vy, y) * 0.5
	var w_cl := _ss(d.chest_y + 0.06 * vy, d.sh_y, y) * _ss(0.06 * d.hx, 0.14 * d.hx, ax) * 0.85
	var w_t := (1.0 - _ss(d.hipj_y - 0.075 * vy, d.hipj_y, y)) * _ss(0.015, 0.06, ax) * 0.45
	return _wn([HIPS, w_h * (1.0 - w_t), THIGH_L + m_side * LS, w_h * w_t, SPINE, w_s,
		CHEST, w_c * (1.0 - w_cl) * (1.0 - w_n), CLAV_L + m_side * AS, w_c * w_cl, NECK, w_c * w_n])


## Rows between two rig heights following the torso's control points.
func _torso_rows(y0: float, y1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.append(y0)
	for i in TY.size():
		var yy: float = float(TY[i]) * _d.vy
		if yy > y0 + 0.012 and yy < y1 - 0.012:
			out.append(yy)
		if _d.female and float(TY[i]) == 1.24:
			for extra: float in [1.28, 1.3]:
				if extra * _d.vy > y0 + 0.012 and extra * _d.vy < y1 - 0.012:
					out.append(extra * _d.vy)
	return _append_end(out, y1)


static func _append_end(rows: PackedFloat32Array, y1: float) -> PackedFloat32Array:
	rows.append(y1)
	return rows


## Lofted garment over the torso. v_y >= 0 cuts a V at the front above that height.
## a_span > 0 instead keeps only the front +-a_span.
func _loft(mb: MB, sname: String, y0: float, y1: float, off: float, v_y := -1.0, a_max := 0.0, a_span := 0.0, cols := 24, hem_off := -1.0, close_neck := false) -> void:
	var rows_y := _torso_rows(y0, y1)
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var wrap := v_y < 0.0 and a_span <= 0.0
	var rows := rows_y.size()
	var extra := 1 if hem_off >= 0.0 else 0
	var ny := 1 if close_neck else 0
	var cen := PackedVector3Array()
	for r in rows + extra + ny:
		var y: float
		var o := off
		var neck := r == rows + extra
		if neck:
			y = y1 + 0.002
		elif extra == 1 and r == 0:
			y = rows_y[0]
			o = hem_off
		else:
			y = rows_y[r - extra]
		cen.append(Vector3(0, y, 0.0))
		for c in cols:
			var a: float
			if a_span > 0.0:
				a = -a_span + 2.0 * a_span * c / (cols - 1)
			elif v_y >= 0.0:
				var ac := 0.0
				if y > v_y:
					ac = a_max * pow(minf((y - v_y) / maxf(y1 - v_y, 0.001), 1.0), 0.72)
				a = ac + (TAU - 2.0 * ac) * c / (cols - 1)
			else:
				a = TAU * c / cols
			var p: Vector3
			if neck:
				p = Vector3(sin(a) * _d.neck_r * 0.98, y, 0.012 - cos(a) * _d.neck_r * 0.98)
			else:
				p = _tpt(y, a, o)
			P.append(p)
			W.append_array(_w_torso(p))
	_grid(mb, sname, P, rows + extra + ny, cols, wrap, W, PackedColorArray(), Callable(), false, PackedVector2Array(), cen)


func _b_neck(mb: MB) -> void:
	var d := _d
	var y0 := d.neck_y - 0.04 * d.vy
	var y1 := d.head_y + 0.03 * d.hs
	var path := PackedVector3Array()
	var ra := PackedFloat32Array()
	var rb := PackedFloat32Array()
	var W := PackedFloat32Array()
	var C := PackedColorArray()
	var n_rows := 5
	for i in n_rows:
		var t := float(i) / (n_rows - 1)
		var y := lerpf(y0, y1, t)
		path.append(Vector3(0, y, lerpf(0.012, 0.018, t)))
		var r := d.neck_r * lerpf(1.1, 0.97, t)
		ra.append(r)
		rb.append(r * 0.98)
		var w_n := _ss(d.neck_y - 0.03 * d.vy, d.neck_y + 0.01 * d.vy, y)
		var w_h := _ss(d.head_y - 0.03 * d.vy, d.head_y + 0.005, y)
		W.append_array(_wn([CHEST, 1.0 - w_n, NECK, w_n * (1.0 - w_h), HEAD, w_n * w_h]))
		C.append(Color(0.9, 0.82, 0.8).lerp(Color(0.62, 0.48, 0.46), _ss(0.3, 0.8, t)))
	_sweep(mb, "skin", path, ra, rb, 10, W, C)


# ---------------------------------------------------------------- what each outfit is made of

func _bottom_kind() -> String:
	if bottom != "":
		return bottom
	match outfit:
		"dress":
			return "dress"
		"overalls":
			return "overalls"
		"fisherman", "warden":
			return "slacks"
		"sweater", "shirt_tie", "cardigan", "sweater_vest":
			if age == "child":
				return "shorts" if sex == "m" else "skirt"
			return "skirt" if sex == "f" else "slacks"
		"halcyon":
			return "skirt" if sex == "f" else "slacks"
	return "slacks"


func _garment() -> Dictionary:
	var d := _d
	var tie_v := accent_color.a > 0.0 and sex == "m"
	var vy := d.vy
	var g := {
		"top_off": 0.004, "hem": d.spine_y - 0.012 * vy, "hem_off": 0.0, "vcut": false, "under": false, "collar": "shirt",
		"collar_slot": "top", "sleeve": "long", "sleeve_slot": "top", "bottom": _bottom_kind(), "bottom_off": 0.008,
		"shoes": "oxford", "tie": false, "belt": true, "bib": false, "armband": false, "patch": false, "piping": false,
		"buttons": false, "pockets": false, "rib": false, "waistband": false,
	}
	if sex == "f":
		g["shoes"] = "flats"
	if age == "child":
		g["shoes"] = "sneakers"
	match outfit:
		"cardigan":
			g["top_off"] = 0.012
			g["hem"] = d.hipj_y + 0.022 * vy
			g["vcut"] = true
			g["under"] = true
			g["collar"] = "peter" if sex == "f" else "shirt"
			g["collar_slot"] = "shirt"
			g["belt"] = false
			g["buttons"] = true
			g["rib"] = true
		"shirt_tie":
			g["tie"] = sex == "m"
			g["collar"] = "shirt" if sex == "m" else "peter"
			g["collar_slot"] = "top" if sex == "m" else "trim"
			if age == "child":
				g["tie"] = false
		"dress":
			g["top_off"] = 0.003
			g["collar"] = "peter"
			g["collar_slot"] = "trim"
			g["sleeve"] = "short"
			g["belt"] = false
		"sweater":
			g["top_off"] = 0.012
			g["hem"] = d.hipj_y + 0.03 * vy
			g["collar"] = "crew"
			g["belt"] = false
			g["rib"] = true
		"sweater_vest":
			g["top_off"] = 0.012
			g["hem"] = d.hipj_y + 0.05 * vy
			g["vcut"] = true
			g["under"] = true
			g["collar"] = "shirt"
			g["collar_slot"] = "shirt"
			g["sleeve_slot"] = "shirt"
			g["belt"] = false
			g["rib"] = true
			g["tie"] = tie_v
		"overalls":
			g["top_off"] = 0.004
			g["sleeve"] = "rolled"
			g["bib"] = true
			g["belt"] = false
			if age != "child":
				g["shoes"] = "boots"
		"fisherman":
			g["top_off"] = 0.017
			g["hem"] = d.hipj_y + 0.018 * vy
			g["collar"] = "roll"
			g["belt"] = false
			g["shoes"] = "boots"
			g["rib"] = true
		"warden":
			g["top_off"] = 0.012
			g["hem"] = d.hipj_y + 0.07 * vy
			g["collar"] = "jacket"
			g["armband"] = true
			g["belt"] = false
			g["shoes"] = "boots"
			g["buttons"] = true
			g["pockets"] = true
			g["waistband"] = true
		"halcyon":
			g["top_off"] = 0.012
			g["hem"] = d.hipj_y + 0.06 * vy
			g["collar"] = "jacket"
			g["collar_slot"] = "trim"
			g["patch"] = true
			g["piping"] = true
			g["belt"] = false
			g["waistband"] = true
			g["shoes"] = "oxford" if sex == "m" else "flats"
	return g


func _b_torso(mb: MB, g: Dictionary) -> void:
	var d := _d
	var vy := d.vy
	var y_crotch := 0.845 * vy
	var y_waist := d.spine_y
	var y_top := 1.485 * vy
	var top_off: float = g["top_off"]
	var bot_off: float = g["bottom_off"]
	var bk: String = g["bottom"]
	var low_slot := "top" if bk == "dress" else "bottom"
	var under_skirt: bool = bk in ["skirt", "dress"]
	_loft(mb, low_slot, y_crotch, y_waist + 0.028 * vy, 0.0 if under_skirt else bot_off, -1.0, 0.0, 0.0, 14 if under_skirt else 24)
	var hem: float = g["hem"]
	var tucked: bool = hem > y_waist - 0.03 * vy
	var v_y := -1.0
	if g["vcut"]:
		v_y = d.chest_y + 0.075 * vy
	_loft(mb, "top", hem, y_top, top_off, v_y, 0.6, 0.0, 26 if g["vcut"] else 24, 0.002 if tucked else bot_off + 0.003, true)
	if g["under"]:
		_loft(mb, "shirt", v_y - 0.045 * vy, y_top + 0.002, 0.0, -1.0, 0.0, 0.86, 13)
		if not g["tie"]:
			var pc := PackedVector3Array()
			var pn := PackedVector3Array()
			var pw := PackedFloat32Array()
			var pwt := PackedFloat32Array()
			for i in 5:
				var y := lerpf(v_y - 0.01 * vy, d.neck_y, float(i) / 4.0)
				var p := _tpt(y, 0.0, 0.0012)
				pc.append(p)
				pn.append(_tnrm(y, 0.0, 0.0))
				pw.append(0.015)
				pwt.append_array(_w_torso(p))
			_ribbon(mb, "trim2", pc, pn, pw, pwt, 0.0008)
	if g["rib"]:
		_band(mb, "trim", hem - 0.004 * vy, hem + 0.045 * vy, top_off + 0.0035, top_off - 0.002)
	if g["waistband"]:
		_band(mb, "trim" if g["piping"] else "top", hem - 0.002 * vy, hem + 0.05 * vy, top_off + 0.0045, top_off - 0.002)
	if g["belt"] and not bk in ["skirt", "dress", "overalls"]:
		_b_belt(mb, y_waist + 0.008 * vy, bot_off + 0.004, 0.034 * vy)
	if bk == "dress" or (bk == "skirt" and outfit == "dress"):
		_b_belt(mb, y_waist + 0.004 * vy, top_off + 0.003, 0.02 * vy, "trim")


## A band around the torso. Its columns line up with the lofts so layers never cut through each other.
func _band(mb: MB, sname: String, y0: float, y1: float, off: float, off_in: float) -> void:
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var ys := [y0, y0, y1, y1]
	var os := [off_in, off, off, off_in]
	for r in ys.size():
		for c in 24:
			var p := _tpt(float(ys[r]), TAU * c / 24.0, float(os[r]))
			P.append(p)
			W.append_array(_w_torso(p))
	_grid(mb, sname, P, ys.size(), 24, true, W)


func _b_belt(mb: MB, y: float, off: float, h: float, sname := "shoe") -> void:
	_band(mb, sname, y - h * 0.5, y + h * 0.5, off, off - 0.002)
	if sname == "shoe":
		var fr := _tpt(y, 0.0, off + 0.002)
		_rigid(mb, "metal", ModelKit.rounded_box(Vector3(0.042, 0.036, 0.008), 0.003, 1), Transform3D(Basis.IDENTITY, fr), _w_torso(fr))


# ---------------------------------------------------------------- collars

func _b_collar(mb: MB, g: Dictionary) -> void:
	var d := _d
	var kind: String = g["collar"]
	var sname: String = g["collar_slot"]
	var top_off: float = g["top_off"]
	var ny := d.neck_y + 0.012 * d.vy
	var nr := d.neck_r
	var zc := 0.012
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var cen := PackedVector3Array()
	match kind:
		"shirt", "jacket", "peter":
			var a0 := 0.2
			var flap := 0.03
			var tip_len := 0.03
			var neck_w := 0.4
			if kind == "jacket":
				a0 = 0.34
				flap = 0.04
				tip_len = 0.04
			elif kind == "peter":
				a0 = 0.13
				flap = 0.036
				tip_len = -0.016
			var cols := 17
			var rows := 5
			for r in rows:
				cen.append(Vector3(0, ny - 0.1, zc) if r > 1 else Vector3(0, ny + 0.01, zc))
				for c in cols:
					var a := a0 + (TAU - 2.0 * a0) * c / (cols - 1)
					var fa := absf(wrapf(a, -PI, PI))
					var tip := _ss(1.0, 0.25, fa)
					# walk down the torso until the collar has reached its width
					var limit := nr + flap + tip * tip_len * 0.75
					var yy := ny + 0.012 * d.vy
					var edge := _tpt(yy, a, top_off + 0.0045)
					while yy > d.chest_y and Vector2(edge.x, edge.z - zc).length() < limit:
						yy -= 0.004
						edge = _tpt(yy, a, top_off + 0.0045)
					if tip > 0.0 and kind != "peter":
						edge.y -= tip * tip_len * 0.5
					var fold := Vector3(sin(a) * (nr + 0.0105), ny + 0.031 * d.vy, zc - cos(a) * (nr + 0.0105))
					var p: Vector3
					match r:
						0:
							p = Vector3(sin(a) * (nr + 0.0035), ny - 0.012 * d.vy, zc - cos(a) * (nr + 0.0035))
						1:
							p = Vector3(sin(a) * (nr + 0.0055), ny + 0.026 * d.vy, zc - cos(a) * (nr + 0.0055))
						2:
							p = fold
						3:
							p = fold.lerp(edge, 0.55) + Vector3(sin(a), 0.55, -cos(a)).normalized() * 0.006
						_:
							p = edge + Vector3(sin(a), 0.5, -cos(a)).normalized() * 0.002
					P.append(p)
					var nk := neck_w * (1.0 - float(r) / 4.0)
					W.append_array(_wn([CHEST, 1.0 - nk, NECK, nk]))
			_grid(mb, sname, P, rows, cols, false, W, PackedColorArray(), Callable(), false, PackedVector2Array(), cen)
		"crew":
			var cols := 24
			var rows := 6
			var y_c := 1.478 * d.vy
			for r in rows:
				var phi := lerpf(-1.8, 1.8, float(r) / (rows - 1))
				var y := y_c + 0.009 * cos(phi)
				cen.append(Vector3(0, y, 0))
				for c in cols:
					var p := _tpt(y_c, TAU * c / cols, top_off + 0.002 + 0.0065 * sin(phi))
					p.y = y
					P.append(p)
					W.append_array(_wn([CHEST, 0.7, NECK, 0.3]))
			_grid(mb, "trim", P, rows, cols, true, W, PackedColorArray(), Callable(), false, PackedVector2Array(), cen)
		"roll":
			var cols := 22
			var prof := [[-0.005, 0.006], [0.05, 0.007], [0.064, 0.013], [0.06, 0.023], [0.03, 0.03], [-0.012, 0.034]]
			for r in prof.size():
				var def: Array = prof[r]
				var y := ny + float(def[0]) * d.vy
				var rr := nr + float(def[1])
				cen.append(Vector3(0, y, zc))
				for c in cols:
					var a := TAU * c / cols
					P.append(Vector3(sin(a) * rr, y, zc - cos(a) * rr))
					var wn := _ss(ny, ny + 0.06, y)
					W.append_array(_wn([CHEST, 1.0 - wn, NECK, wn]))
			_grid(mb, "trim", P, prof.size(), cols, true, W, PackedColorArray(), Callable(), false, PackedVector2Array(), cen)


# ==========================================================================
# Arms and hands
# ==========================================================================

func _w_arm(s: int, l: float, to_hand := true) -> PackedFloat32Array:
	var d := _d
	var o := s * AS
	var w_clav := minf(_ss(0.02, -0.05, l), 0.7)
	var w_f := _ss(d.uarm - 0.035, d.uarm + 0.035, l)
	var w_h := _ss(d.uarm + d.farm - 0.03, d.uarm + d.farm + 0.012, l) if to_hand else 0.0
	return _wn([UARM_L + o, (1.0 - w_f) * (1.0 - w_clav), CLAV_L + o, w_clav, FARM_L + o, w_f * (1.0 - w_h), HAND_L + o, w_h])


func _arm_tube(mb: MB, sname: String, s: int, ls: Array, rs: Array, close_top: bool, turn_in := false, k := 1.0) -> void:
	var d := _d
	var J := _rg[UARM_L + s * AS]
	var path := PackedVector3Array()
	var ra := PackedFloat32Array()
	var rb := PackedFloat32Array()
	var W := PackedFloat32Array()
	for i in ls.size():
		var l: float = float(ls[i]) * d.vy
		var r: float = float(rs[i]) * d.arm_k * k
		path.append(J + Vector3(0, -l, 0))
		ra.append(r * 0.93)
		rb.append(r)
		W.append_array(_w_arm(s, l, sname == "skin"))
	if turn_in:
		var l_end: float = float(ls[ls.size() - 1]) * d.vy
		var r_end: float = float(rs[rs.size() - 1]) * d.arm_k * k
		path.append(J + Vector3(0, -l_end + 0.004 * d.vy, 0))
		ra.append(r_end * 0.62)
		rb.append(r_end * 0.66)
		W.append_array(_w_arm(s, l_end, sname == "skin"))
	_sweep(mb, sname, path, ra, rb, 10, W, PackedColorArray(), Vector3.RIGHT)


func _b_arms(mb: MB, g: Dictionary) -> void:
	var sleeve: String = g["sleeve"]
	var slot: String = g["sleeve_slot"]
	var cuff_slot: String = "trim" if outfit in ["halcyon", "sweater", "fisherman", "cardigan"] else slot
	const CAP_L := [-0.043, -0.036, -0.018, 0.01]
	const CAP_R := [0.0005, 0.027, 0.044, 0.052]
	const BARE_L := [0.04, 0.12, 0.2, 0.27, 0.3, 0.36, 0.44, 0.5, 0.54, 0.56]
	const BARE_R := [0.047, 0.044, 0.04, 0.035, 0.036, 0.038, 0.032, 0.026, 0.025, 0.024]
	var bulk := 1.08 if outfit in ["fisherman", "warden", "halcyon"] else 1.0
	for s in 2:
		match sleeve:
			"long":
				_arm_tube(mb, slot, s, CAP_L + [0.05, 0.12, 0.2, 0.26, 0.29, 0.33, 0.40, 0.47, 0.525],
					CAP_R + [0.053, 0.05, 0.047, 0.044, 0.044, 0.044, 0.041, 0.037, 0.036], false, true, bulk)
				_arm_tube(mb, "skin", s, [0.49, 0.525, 0.558], [0.026, 0.026, 0.024], false)
				if cuff_slot != slot or outfit in ["sweater", "fisherman", "cardigan"]:
					_arm_tube(mb, cuff_slot, s, [0.48, 0.5, 0.525], [0.039, 0.041, 0.041], false, true, bulk * 1.02)
			"short":
				_arm_tube(mb, slot, s, CAP_L + [0.05, 0.1, 0.135], CAP_R + [0.052, 0.052, 0.055], false, true)
				_arm_tube(mb, "skin", s, BARE_L, BARE_R, false)
			"rolled":
				_arm_tube(mb, slot, s, CAP_L + [0.05, 0.12, 0.2, 0.26], CAP_R + [0.053, 0.05, 0.047, 0.045], false, true)
				_arm_tube(mb, slot, s, [0.232, 0.25, 0.272, 0.29], [0.048, 0.052, 0.052, 0.047], false, true)
				_arm_tube(mb, "skin", s, [0.24, 0.3, 0.36, 0.44, 0.5, 0.54, 0.56], [0.036, 0.036, 0.038, 0.032, 0.026, 0.025, 0.024], false)


func _b_hands(mb: MB) -> void:
	var d := _d
	var hk := d.hk
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var o := s * AS
		var W0 := _rg[HAND_L + o]
		# palm: rounded loft down the hand
		var ys := [0.012, 0.0, -0.025, -0.055, -0.08, -0.095, -0.102]
		var hz := [0.028, 0.030, 0.036, 0.040, 0.041, 0.037, 0.0]
		var hx := [0.017, 0.016, 0.015, 0.014, 0.0125, 0.0105, 0.0]
		var cols := 8
		var P := PackedVector3Array()
		var W := PackedFloat32Array()
		for r in ys.size():
			var y: float = ys[r]
			for c in cols:
				var a := TAU * c / cols
				var ca := cos(a)
				var sa := sin(a)
				var ee := 2.0 / 2.7
				var lx := float(hx[r]) * signf(ca) * pow(absf(ca), ee)
				var lz := float(hz[r]) * signf(sa) * pow(absf(sa), ee)
				P.append(W0 + Vector3(lx * m, y, lz) * hk)
				W.append_array(_w2(FARM_L + o, HAND_L + o, _ss(0.012, -0.012, y)))
		_grid(mb, "skin", P, ys.size(), cols, true, W)
		# fingers (right-hand coordinates: the palm side is -x)
		var zs := [-0.0275, -0.0085, 0.0095, 0.0265]
		var lens := [0.07, 0.078, 0.072, 0.057]
		var rad := [0.0095, 0.0098, 0.0092, 0.0082]
		for f in 4:
			var fz: float = zs[f]
			var fl: float = lens[f]
			var fr: float = rad[f]
			var b1 := (INDEX_L if f == 0 else FING_L) + o
			var b2 := (INDEX2_L if f == 0 else FING2_L) + o
			var y_b1 := -0.093
			var y_b2 := -0.129 if f == 0 else -0.133
			var path := PackedVector3Array()
			var ra := PackedFloat32Array()
			var rb := PackedFloat32Array()
			var FW := PackedFloat32Array()
			var us := [0.0, 0.38, 0.72, 0.96, 1.0]
			for i in us.size():
				var u: float = us[i]
				var y := -0.084 - fl * u
				var x := -0.001 - 0.016 * u * u
				path.append(W0 + Vector3(x * m, y, fz) * hk)
				var rr := fr * lerpf(1.0, 0.78, u)
				if i == us.size() - 1:
					rr = 0.0004
				ra.append(rr * 0.9 * hk)
				rb.append(rr * hk)
				var w1 := _ss(y_b1 + 0.006, y_b1 - 0.008, y)
				var w2 := _ss(y_b2 + 0.006, y_b2 - 0.006, y)
				FW.append_array(_wn([HAND_L + o, 1.0 - w1, b1, w1 * (1.0 - w2), b2, w2]))
			_sweep(mb, "skin", path, ra, rb, 4, FW, PackedColorArray(), Vector3.RIGHT)
		# thumb
		var tp := PackedVector3Array([Vector3(-0.004, -0.012, -0.022), Vector3(-0.012, -0.035, -0.04), Vector3(-0.018, -0.058, -0.05),
			Vector3(-0.021, -0.075, -0.052), Vector3(-0.022, -0.083, -0.051)])
		var tr := [0.0125, 0.0115, 0.0098, 0.0082, 0.0004]
		var path := PackedVector3Array()
		var ra := PackedFloat32Array()
		var rb := PackedFloat32Array()
		var TW := PackedFloat32Array()
		for i in tp.size():
			path.append(W0 + Vector3(tp[i].x * m, tp[i].y, tp[i].z) * hk)
			ra.append(float(tr[i]) * hk)
			rb.append(float(tr[i]) * 0.9 * hk)
			TW.append_array(_w2(HAND_L + o, THUMB_L + o, 0.4 if i == 0 else 1.0))
		_sweep(mb, "skin", path, ra, rb, 5, TW, PackedColorArray(), Vector3.RIGHT)


# ==========================================================================
# Legs and shoes
# ==========================================================================

func _w_leg(s: int, l: float) -> PackedFloat32Array:
	var d := _d
	var o := s * LS
	var w_h := minf(_ss(0.03, -0.06, l), 0.7)
	var w_k := _ss(d.thigh - 0.04 * d.vy, d.thigh + 0.04 * d.vy, l)
	var w_f := _ss(d.thigh + d.shin - 0.03 * d.vy, d.thigh + d.shin, l)
	return _wn([THIGH_L + o, (1.0 - w_k) * (1.0 - w_h), HIPS, w_h, SHIN_L + o, w_k * (1.0 - w_f), FOOT_L + o, w_k * w_f])


func _leg_tube(mb: MB, sname: String, s: int, ls: Array, rs: Array, close_top: bool, turn_in: bool) -> void:
	var d := _d
	var J := _rg[THIGH_L + s * LS]
	var path := PackedVector3Array()
	var ra := PackedFloat32Array()
	var rb := PackedFloat32Array()
	var W := PackedFloat32Array()
	var lk := (d.thigh + d.shin) / 0.86
	for i in ls.size():
		var l: float = float(ls[i]) * lk
		var r: float = float(rs[i]) * d.leg_k
		path.append(J + Vector3(0, -l, 0.0))
		ra.append(r * 0.95)
		rb.append(r)
		W.append_array(_w_leg(s, l))
	if turn_in:
		var l_end: float = float(ls[ls.size() - 1]) * lk
		var r_end: float = float(rs[rs.size() - 1]) * d.leg_k
		path.append(J + Vector3(0, -l_end + 0.005, 0))
		ra.append(r_end * 0.66)
		rb.append(r_end * 0.68)
		W.append_array(_w_leg(s, l_end))
	if close_top:
		ra[0] = 0.0005
		rb[0] = 0.0005
	_sweep(mb, sname, path, ra, rb, 10, W, PackedColorArray(), Vector3.RIGHT)


func _b_legs(mb: MB, g: Dictionary) -> void:
	var d := _d
	var bk: String = g["bottom"]
	const BARE_L := [-0.09, -0.05, 0.0, 0.1, 0.22, 0.36, 0.435, 0.5, 0.58, 0.7, 0.8, 0.875]
	const BARE_R := [0.04, 0.078, 0.082, 0.074, 0.063, 0.052, 0.046, 0.049, 0.05, 0.039, 0.031, 0.029]
	for s in 2:
		match bk:
			"slacks", "overalls":
				var wide := 1.04 if bk == "overalls" else 1.0
				_leg_tube(mb, "bottom", s, [-0.09, -0.05, 0.0, 0.14, 0.3, 0.42, 0.5, 0.64, 0.78, 0.855],
					[0.05, 0.08 * wide, 0.09 * wide, 0.09 * wide, 0.078 * wide, 0.068 * wide, 0.067 * wide, 0.064 * wide, 0.063 * wide, 0.069 * wide], true, true)
			"shorts":
				_leg_tube(mb, "bottom", s, [-0.09, -0.05, 0.0, 0.1, 0.2, 0.25], [0.05, 0.08, 0.09, 0.092, 0.09, 0.094], true, true)
				_leg_tube(mb, "skin", s, [0.16, 0.22, 0.36, 0.435, 0.5, 0.58, 0.7, 0.8, 0.875], [0.066, 0.063, 0.052, 0.046, 0.049, 0.05, 0.039, 0.031, 0.029], false, false)
				_leg_tube(mb, "trim", s, [0.58, 0.63, 0.7, 0.8, 0.86], [0.053, 0.052, 0.044, 0.036, 0.034], false, false)
			_:
				_leg_tube(mb, "skin", s, BARE_L, BARE_R, true, false)
	if bk == "skirt" or bk == "dress":
		_b_skirt(mb, "top2s" if bk == "dress" else "bottom2s", g)


func _b_skirt(mb: MB, sname: String, g: Dictionary) -> void:
	var d := _d
	var vy := d.vy
	var y_top := d.spine_y + 0.022 * vy
	var y_hip := d.hipj_y + 0.03 * vy
	var y_hem := d.hipj_y - d.thigh * 0.86
	var flare := 0.075 if age != "child" else 0.06
	var ys := PackedFloat32Array([y_hem, y_hem, y_hem + (y_hip - y_hem) * 0.25, y_hem + (y_hip - y_hem) * 0.5, y_hem + (y_hip - y_hem) * 0.75, y_hip, (y_hip + y_top) * 0.5, y_top])
	var cols := 26
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var hip := _tprof(y_hip)
	for r in ys.size():
		var y: float = ys[r]
		var t := clampf((y_hip - y) / (y_hip - y_hem), 0.0, 1.0)
		var prof := _tprof(y)
		var rx: float
		var zf: float
		var zb: float
		if y >= y_hip:
			rx = prof.x + 0.009
			zf = prof.y + 0.009
			zb = prof.z + 0.009
		else:
			rx = hip.x + 0.012 + flare * t
			zf = hip.y + 0.012 + flare * t * 1.1
			zb = hip.z + 0.012 + flare * t * 1.0
		if r == 0:
			rx -= 0.012
			zf -= 0.012
			zb -= 0.012
		for c in cols:
			var a := TAU * c / cols
			var sa := sin(a)
			var ca := cos(a)
			var wav := 0.004 * sin(a * 7.0 + 0.8) * t
			var p := Vector3((rx + wav) * sa, y, -(zf + wav) * ca if ca >= 0.0 else (zb + wav) * -ca)
			P.append(p)
			# the sides ride on the thighs, the front and back panels on their own bones
			var tk := _ss(y_hip + 0.02 * vy, y_hem, y) * 0.96
			var wf := _ss(-0.3, 0.3, ca)
			W.append_array(_wn([HIPS, 1.0 - tk, SK_F, tk * wf, SK_B, tk * (1.0 - wf)]))
	_grid(mb, sname, P, ys.size(), cols, true, W)


func _b_shoes(mb: MB, g: Dictionary) -> void:
	var d := _d
	var kind: String = g["shoes"]
	var zs: Array
	var ws: Array
	var tops: Array
	match kind:
		"boots":
			zs = [0.066, 0.058, 0.03, -0.015, -0.06, -0.11, -0.155, -0.186, -0.192]
			ws = [0.0, 0.04, 0.05, 0.051, 0.05, 0.05, 0.044, 0.028, 0.0]
			tops = [0.09, 0.14, 0.15, 0.13, -0.012, -0.034, -0.04, -0.05, -0.06]
		"flats":
			zs = [0.056, 0.05, 0.028, -0.02, -0.07, -0.115, -0.155, -0.18, -0.186]
			ws = [0.0, 0.026, 0.033, 0.034, 0.038, 0.037, 0.03, 0.015, 0.0]
			tops = [-0.03, -0.014, -0.022, -0.034, -0.042, -0.05, -0.056, -0.06, -0.063]
		"sneakers":
			zs = [0.06, 0.052, 0.03, -0.02, -0.07, -0.12, -0.16, -0.182, -0.188]
			ws = [0.0, 0.034, 0.042, 0.045, 0.048, 0.05, 0.045, 0.03, 0.0]
			tops = [0.0, 0.016, 0.02, 0.008, -0.022, -0.034, -0.038, -0.044, -0.056]
		_:
			zs = [0.062, 0.055, 0.03, -0.02, -0.07, -0.12, -0.16, -0.185, -0.19]
			ws = [0.0, 0.03, 0.041, 0.043, 0.047, 0.046, 0.04, 0.025, 0.0]
			tops = [-0.02, 0.0, 0.01, 0.002, -0.025, -0.04, -0.045, -0.052, -0.06]
	var bot := -d.ankle_h
	var fk := d.foot_k
	var sole_c := Color(0.32, 0.30, 0.28)
	if kind == "sneakers":
		sole_c = Color(1.2, 1.2, 1.15)
	for s in 2:
		var J := _rg[FOOT_L + s * LS]
		var cols := 8
		var P := PackedVector3Array()
		var W := PackedFloat32Array()
		var C := PackedColorArray()
		var cen := PackedVector3Array()
		for r in zs.size():
			var z: float = float(zs[r]) * fk
			var hw: float = float(ws[r]) * fk
			var top: float = lerpf(bot, float(tops[r]) * (fk if kind != "boots" else 1.0), 1.0)
			var yc := (top + bot) * 0.5
			var hh := (top - bot) * 0.5
			cen.append(J + Vector3(0, yc, z))
			for c in cols:
				var a := TAU * c / cols
				var ca := cos(a)
				var sa := sin(a)
				var ee := 2.0 / 3.0
				var lx := hw * signf(ca) * pow(absf(ca), ee)
				var ly := hh * signf(sa) * pow(absf(sa), ee)
				var yy := yc + ly
				P.append(J + Vector3(lx, yy, z))
				W.append_array(_w1(FOOT_L + s * LS))
				C.append(sole_c if yy < bot + 0.012 else Color.WHITE)
		_grid(mb, "shoe", P, zs.size(), cols, true, W, C, Callable(), false, PackedVector2Array(), cen)


# ==========================================================================
# Accessories
# ==========================================================================

func _on_torso(y: float, a: float, off: float) -> Transform3D:
	var p := _tpt(y, a, off)
	var n := _tnrm(y, a, off)
	# local -Z along the surface normal, +Y up the torso
	var z := -n
	var x := Vector3.UP.cross(z).normalized()
	var yy := z.cross(x).normalized()
	return Transform3D(Basis(x, yy, z), p)


func _b_accessories(mb: MB, g: Dictionary) -> void:
	var d := _d
	var vy := d.vy
	var H := _rg[HEAD]
	var hs := d.hs
	var top_off: float = g["top_off"]
	# --- tie
	if g["tie"]:
		var y0 := d.neck_y + 0.002 * vy
		var y_tip := d.spine_y + 0.03 * vy
		if g["vcut"]:
			top_off = 0.0
			y_tip = d.chest_y + 0.06 * vy
		var path := PackedVector3Array()
		var nrm := PackedVector3Array()
		var wid := PackedFloat32Array()
		var W := PackedFloat32Array()
		var n_r := 8
		for i in n_r:
			var t := float(i) / (n_r - 1)
			var y := lerpf(y0, y_tip, t)
			var p := _tpt(y, 0.0, top_off + 0.0035)
			path.append(p)
			nrm.append(_tnrm(y, 0.0, top_off))
			wid.append(lerpf(0.02, 0.066, _ss(0.0, 0.85, t)) * (1.0 - _ss(0.92, 1.0, t) * 0.98))
			W.append_array(_w_torso(p))
		_ribbon(mb, "accent", path, nrm, wid, W, 0.0025)
		var kp := _tpt(y0 + 0.002, 0.0, top_off + 0.012)
		_rigid(mb, "accent", ModelKit.rounded_box(Vector3(0.026, 0.026, 0.016), 0.006, 1), Transform3D(Basis.IDENTITY, kp), _w_torso(kp))
		top_off = g["top_off"]
	# --- buttons on the front (cardigans, jackets)
	if g["buttons"]:
		var y_t: float = (d.chest_y + 0.06 * vy) if g["vcut"] else (d.neck_y - 0.06 * vy)
		var y_b: float = float(g["hem"]) + 0.05 * vy
		var col := Color(0.82, 0.78, 0.68)
		if outfit == "warden":
			col = Color(0.72, 0.56, 0.26)
		var nb := 5
		for i in nb:
			var y := lerpf(y_t, y_b, float(i) / (nb - 1))
			var xf := _on_torso(y, 0.0, top_off + 0.002)
			xf.basis = _bs(xf.basis, Vector3(0.0075, 0.0075, 0.0035))
			_rigid(mb, "vc", ModelKit.sphere(1.0, 6, 2), xf, _w_torso(xf.origin), col)
		# the button band down the front and up the V
		if g["vcut"]:
			for side in 2:
				var m := -1.0 if side == 0 else 1.0
				var path := PackedVector3Array()
				var nrm := PackedVector3Array()
				var wid := PackedFloat32Array()
				var W := PackedFloat32Array()
				var v_y := d.chest_y + 0.075 * vy
				var y1 := 1.485 * vy
				var n_r := 8
				for i in n_r:
					var t := float(i) / (n_r - 1)
					var y := lerpf(v_y, y1, t)
					var ac := 0.6 * pow(maxf(t, 0.0), 0.72)
					var a := m * maxf(ac, 0.005)
					var p := _tpt(y, a, top_off + 0.0015)
					path.append(p)
					nrm.append(_tnrm(y, a, top_off))
					wid.append(0.016)
					W.append_array(_w_torso(p))
				_ribbon(mb, "trim", path, nrm, wid, W)
			var path := PackedVector3Array()
			var nrm := PackedVector3Array()
			var wid := PackedFloat32Array()
			var W := PackedFloat32Array()
			var y_v := d.chest_y + 0.075 * vy
			for i in 6:
				var y := lerpf(y_v, float(g["hem"]) + 0.03 * vy, float(i) / 5.0)
				var p := _tpt(y, 0.0, top_off + 0.0012)
				path.append(p)
				nrm.append(_tnrm(y, 0.0, top_off))
				wid.append(0.019)
				W.append_array(_w_torso(p))
			_ribbon(mb, "trim", path, nrm, wid, W, 0.001)
	# --- chest pocket flaps
	if g["pockets"]:
		for side in 2:
			var m := -1.0 if side == 0 else 1.0
			var xf := _on_torso(d.chest_y + 0.085 * vy, m * 0.52, top_off + 0.002)
			_rigid(mb, "top", ModelKit.rounded_box(Vector3(0.078, 0.03, 0.007), 0.0035, 1), xf, _w_torso(xf.origin))
	# --- cream piping down a Halcyon jacket
	if g["piping"]:
		var path := PackedVector3Array()
		var nrm := PackedVector3Array()
		var wid := PackedFloat32Array()
		var W := PackedFloat32Array()
		for i in 8:
			var y := lerpf(d.neck_y - 0.002 * vy, float(g["hem"]) + 0.05 * vy, float(i) / 7.0)
			var p := _tpt(y, 0.0, top_off + 0.0012)
			path.append(p)
			nrm.append(_tnrm(y, 0.0, top_off))
			wid.append(0.012)
			W.append_array(_w_torso(p))
		_ribbon(mb, "trim", path, nrm, wid, W, 0.001)
	# --- amber Halcyon patch on the left breast (the model's left is -x)
	if g["patch"]:
		_b_patch(mb, d.chest_y + 0.085 * vy, -0.5, top_off + 0.003)
	# --- overall bib and straps
	if g["bib"]:
		var bo := top_off + 0.008
		_loft(mb, "bottom", d.spine_y - 0.02 * vy, d.chest_y + 0.075 * vy, bo, -1.0, 0.0, 0.62, 9)
		for side in 2:
			var m := -1.0 if side == 0 else 1.0
			var ctrl := [[d.chest_y + 0.07 * vy, 0.5], [1.375 * vy, 0.72], [1.435 * vy, 1.15], [1.46 * vy, PI * 0.5], [1.435 * vy, PI - 0.95],
				[1.37 * vy, PI - 0.55], [1.25 * vy, PI - 0.3], [d.spine_y + 0.04 * vy, PI - 0.22]]
			var path := PackedVector3Array()
			var nrm := PackedVector3Array()
			var wid := PackedFloat32Array()
			var W := PackedFloat32Array()
			for c: Array in ctrl:
				var y: float = c[0]
				var a: float = float(c[1]) * m
				var p := _tpt(y, a, top_off + 0.0035)
				path.append(p)
				nrm.append(_tnrm(y, a, top_off))
				wid.append(0.036 * (0.85 if d.child else 1.0))
				W.append_array(_w_torso(p))
			_ribbon(mb, "bottom", path, nrm, wid, W, 0.0015)
			var bx := _on_torso(d.chest_y + 0.062 * vy, m * 0.5, bo + 0.003)
			bx.basis = _bs(bx.basis, Vector3(0.009, 0.009, 0.004))
			_rigid(mb, "metal", ModelKit.sphere(1.0, 8, 4), bx, _w_torso(bx.origin))
	# --- volunteer sash: over the right shoulder to the left hip
	if sash:
		var ctrl: Array = [[0.975, 4.09], [1.06, 3.85], [1.16, 3.55], [1.26, 3.2], [1.35, 2.8], [1.415, 2.28], [1.452, 1.75],
			[1.452, 1.25], [1.415, 0.92], [1.34, 0.55], [1.25, 0.2], [1.16, -0.1], [1.07, -0.42], [0.99, -0.72], [0.96, -0.95]]
		var path := PackedVector3Array()
		var nrm := PackedVector3Array()
		var wid := PackedFloat32Array()
		var W := PackedFloat32Array()
		for c: Array in ctrl:
			var y := float(c[0]) * vy
			var a := float(c[1])
			var p := _tpt(y, a, top_off + 0.0065)
			path.append(p)
			nrm.append(_tnrm(y, a, top_off + 0.0065))
			wid.append(0.062)
			W.append_array(_w_torso(p))
		_ribbon(mb, "accent", path, nrm, wid, W, 0.001)
		# rosette where it crosses the chest
		var rx := _on_torso(1.33 * vy, 0.52, top_off + 0.008)
		var b1 := _bs(rx.basis, Vector3(0.03, 0.03, 0.006))
		_rigid(mb, "vc", ModelKit.sphere(1.0, 10, 2), Transform3D(b1, rx.origin), _w_torso(rx.origin), Color(0.94, 0.66, 0.16))
		var b2 := _bs(rx.basis, Vector3(0.016, 0.016, 0.005))
		_rigid(mb, "vc", ModelKit.sphere(1.0, 8, 2), Transform3D(b2, rx.origin - rx.basis.z * 0.005), _w_torso(rx.origin), Color(0.96, 0.92, 0.80))
	# --- armband on the left arm
	if g["armband"]:
		_arm_tube(mb, "accent", 0, [0.075, 0.1, 0.14, 0.165], [0.054, 0.057, 0.055, 0.052], false, false, 1.08)
		var J := _rg[UARM_L]
		var l := 0.118 * vy
		var r := 0.056 * d.arm_k * 1.08 * 0.93
		var b := _bs(Basis(Vector3.UP, PI * 0.5), Vector3(0.022, 0.022, 0.003))
		var at := J + Vector3(-r - 0.001, -l, 0)
		_rigid(mb, "vc", ModelKit.sphere(1.0, 12, 4), Transform3D(b, at), _w1(UARM_L), Color(0.14, 0.24, 0.56))
		_b_cd_triangle(mb, at + Vector3(-0.0025, 0, 0), Basis(Vector3.UP, PI * 0.5), 0.016, _w1(UARM_L))
	# --- headgear
	match hat:
		"fisherman":
			_b_cap(mb, "hat", [[0.0, 0.205], [0.05, 0.208], [0.088, 0.202], [0.106, 0.186], [0.106, 0.163], [0.098, 0.146], [0.095, 0.128]], 7.0, true, 1.0)
		"peaked":
			_b_cap(mb, "hat", [[0.0, 0.207], [0.094, 0.209], [0.107, 0.204], [0.102, 0.184], [0.097, 0.164], [0.095, 0.128]], 6.0, false, 1.0)
			_b_cap_band(mb, "trim", 0.126, 0.146, 0.0955, 6.0)
			_b_visor(mb, 0.13, 0.095, 6.0, 0.06)
			var bx := _bs(Basis(Vector3.RIGHT, deg_to_rad(5.0)), Vector3(0.012, 0.014, 0.003) * hs)
			_rigid(mb, "metal", ModelKit.sphere(1.0, 10, 4), Transform3D(bx, H + Vector3(0, 0.156, -0.114) * hs), _w1(HEAD))
		"helmet":
			_b_helmet(mb)
		"headscarf":
			_b_scarf(mb)
	# --- glasses
	if glasses:
		_b_glasses(mb)
	# --- headphones around the neck
	if headphones:
		_b_headphones(mb, g)


## Disc with the round Halcyon emblem from logo_halcyon_color.png and an amber rim.
func _b_patch(mb: MB, y: float, a: float, off: float) -> void:
	var xf := _on_torso(y, a, off)
	var rings := 4
	var cols := 14
	var r_patch := 0.03
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var UV := PackedVector2Array()
	var cen := PackedVector3Array()
	var wt := _w_torso(xf.origin)
	# emblem centre and radius in texture space (the image is 2048x640)
	var uc := Vector2(268.0 / 2048.0, 282.0 / 640.0)
	var ur := Vector2(200.0 / 2048.0, 200.0 / 640.0)
	for r in rings:
		var k := float(r) / (rings - 1)
		cen.append(xf.origin + xf.basis.z * 0.03)
		for c in cols:
			var ang := TAU * c / cols
			var l := Vector3(cos(ang), sin(ang), 0.0) * k * r_patch
			P.append(xf * l + xf.basis.z * 0.0005)
			W.append_array(wt)
			UV.append(uc + Vector2(cos(ang) * ur.x, -sin(ang) * ur.y) * k)
	_grid(mb, "patch", P, rings, cols, true, W, PackedColorArray(), Callable(), false, UV, cen)
	# amber rim
	var b := _bs(xf.basis, Vector3(0.036, 0.036, 0.0032))
	_rigid(mb, "vc", ModelKit.sphere(1.0, 12, 2), Transform3D(b, xf.origin + xf.basis.z * 0.0018), wt, Color(0.92, 0.60, 0.13))


## The white Civil Defense triangle, slightly domed.
func _b_cd_triangle(mb: MB, at: Vector3, b: Basis, size: float, w8: PackedFloat32Array) -> void:
	var s := mb.slot("vc")
	var base := s.v.size()
	var n := -(b * Vector3.BACK).normalized()
	var w := Color(0.95, 0.94, 0.90)
	var f := -(b * Vector3.BACK).normalized()
	for k in 3:
		var ang := PI * 0.5 + TAU * k / 3.0
		var l := b * Vector3(cos(ang), sin(ang), 0.0) * size
		_push_vertex(s, at + l + f * 0.0002, n, w, w8, 0)
	_tri(s, base, base + 1, base + 2)


func _b_cap(mb: MB, sname: String, prof: Array, tilt_deg: float, visor: bool, zk: float) -> void:
	var d := _d
	var H := _rg[HEAD]
	var pts := PackedVector2Array()
	for i in range(prof.size() - 1, -1, -1):
		var pr: Array = prof[i]
		pts.append(Vector2(float(pr[0]), float(pr[1])))
	var m := ModelKit.lathe(pts, 22)
	var b := _bs(Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg)), Vector3(1.0, 1.0, 1.1 * zk) * d.hs)
	_rigid(mb, sname, m, Transform3D(b, H + Vector3(0, 0.0, 0.002) * d.hs), _w1(HEAD))
	if visor:
		_b_visor(mb, 0.128, 0.092, tilt_deg, 0.05)


func _b_cap_band(mb: MB, sname: String, y0: float, y1: float, r: float, tilt_deg: float) -> void:
	var d := _d
	var pts := PackedVector2Array([Vector2(r + 0.0015, y0), Vector2(r + 0.002, (y0 + y1) * 0.5), Vector2(r + 0.0015, y1)])
	var b := _bs(Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg)), Vector3(1.0, 1.0, 1.1) * d.hs)
	_rigid(mb, sname, ModelKit.lathe(pts, 22), Transform3D(b, _rg[HEAD] + Vector3(0, 0, 0.002) * d.hs), _w1(HEAD))


func _b_visor(mb: MB, y: float, r: float, tilt_deg: float, len_v: float) -> void:
	var d := _d
	var H := _rg[HEAD]
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg))
	var rows := 4
	var cols := 13
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	var C := PackedColorArray()
	var cen := PackedVector3Array()
	for rr in rows:
		var t := float(rr) / (rows - 1)
		cen.append(H + tilt * Vector3(0, y - 0.4, 0) * d.hs)
		for c in cols:
			var a := -1.3 + 2.6 * c / (cols - 1)
			var edge := 1.0 - pow(absf(a) / 1.3, 2.4)
			var rad := r - 0.004 + (len_v + 0.004) * t * edge
			var yy := y + 0.002 - 0.024 * t * edge
			var l := Vector3(sin(a) * rad, yy, -cos(a) * rad * 1.1)
			P.append(H + tilt * l * d.hs)
			W.append_array(_w1(HEAD))
			C.append(Color(0.05, 0.05, 0.055))
	_grid(mb, "vc2s", P, rows, cols, false, W, C, Callable(), false, PackedVector2Array(), cen)


func _b_helmet(mb: MB) -> void:
	var d := _d
	var H := _rg[HEAD]
	var hs := d.hs
	var pts := PackedVector2Array([Vector2(0.112, 0.112), Vector2(0.155, 0.097), Vector2(0.157, 0.104), Vector2(0.119, 0.118),
		Vector2(0.116, 0.14), Vector2(0.107, 0.17), Vector2(0.087, 0.2), Vector2(0.052, 0.221), Vector2(0.0, 0.228)])
	var b := Basis.from_scale(Vector3(1.0, 1.0, 1.1) * hs)
	_rigid(mb, "helmet", ModelKit.lathe(pts, 22), Transform3D(b, H + Vector3(0, 0, 0.002) * hs), _w1(HEAD))
	var at := H + Vector3(0, 0.168, -0.1185) * hs
	var bb := Basis(Vector3.RIGHT, deg_to_rad(28.0))
	_rigid(mb, "vc", ModelKit.sphere(1.0, 12, 4), Transform3D(_bs(bb, Vector3(0.026, 0.026, 0.003) * hs), at), _w1(HEAD), Color(0.14, 0.24, 0.56))
	_b_cd_triangle(mb, at + bb * Vector3(0, 0, -0.0028) * hs, bb, 0.019 * hs, _w1(HEAD))


func _b_scarf(mb: MB) -> void:
	var d := _d
	var H := _rg[HEAD]
	var hs := d.hs
	var cols := 32
	var rows := 10
	var P := PackedVector3Array()
	var W := PackedFloat32Array()
	for r in rows:
		var t := 0.0 if r == 0 else float(r - 1) / float(rows - 2)
		var yk := sin(t * PI * 0.5)
		for c in cols:
			var a := -PI + TAU * c / cols
			var ax := absf(a)
			var ye := _tab([0.0, 0.45, 0.72, 1.0, 1.5, PI], [0.142, 0.134, 0.08, -0.04, -0.05, -0.03], ax)
			var y := lerpf(ye, CROWN, yk)
			var base := _head_base(d, a, y)
			var n := _skull_n(base)
			var th := 0.02 + 0.006 * _ss(0.1, 0.18, y)
			var p := base + n * (th if r > 0 else 0.0)
			var y_ref := 0.08
			if y < y_ref and r > 0:
				var bref := _head_base(d, a, y_ref)
				var dir := Vector2(bref.x, bref.z).normalized()
				var R := Vector2(bref.x, bref.z).length() + th * 0.7
				if R > Vector2(p.x, p.z).length():
					p.x = dir.x * R
					p.z = dir.y * R
			P.append(H + p * hs)
			W.append_array(_w1(HEAD))
	_grid(mb, "accent", P, rows, cols, true, W)
	var kb := Basis.from_scale(Vector3(0.018, 0.015, 0.016) * hs)
	_rigid(mb, "accent", ModelKit.sphere(1.0, 10, 6), Transform3D(kb, H + Vector3(0, -0.058, -0.046) * hs), _w1(HEAD))
	var kb2 := _bs(Basis(Vector3.RIGHT, 0.35), Vector3(0.011, 0.024, 0.008) * hs)
	_rigid(mb, "accent", ModelKit.sphere(1.0, 8, 5), Transform3D(kb2, H + Vector3(-0.012, -0.082, -0.05) * hs), _w1(HEAD))
	_rigid(mb, "accent", ModelKit.sphere(1.0, 8, 5), Transform3D(kb2, H + Vector3(0.012, -0.082, -0.05) * hs), _w1(HEAD))


func _b_glasses(mb: MB) -> void:
	var d := _d
	var H := _rg[HEAD]
	var hs := d.hs
	var round_f := glasses_style == "round"
	var col := Color(0.15, 0.08, 0.04) if round_f else Color(0.04, 0.035, 0.03)
	var tube_r := 0.0012 if round_f else 0.0018
	var ex: float = d.eye.x
	var ey: float = d.eye.y + 0.001
	var zf: float = d.eye.z - d.eye_r - 0.0088
	var w8 := _w1(HEAD)
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var path := PackedVector3Array()
		var ra := PackedFloat32Array()
		var rb := PackedFloat32Array()
		var W := PackedFloat32Array()
		var n_p := 23
		for i in n_p:
			var a := TAU * i / (n_p - 1)
			var rx := 0.0205 if round_f else 0.0225
			var ry := 0.0195 if round_f else 0.0165
			var e := 1.0 if round_f else 0.72
			var cx := signf(cos(a)) * pow(absf(cos(a)), e) * rx
			var cy := signf(sin(a)) * pow(absf(sin(a)), e) * ry
			var zz := zf + (absf(cx) / rx) * 0.0022
			path.append(H + Vector3(m * ex + cx, ey + cy, zz) * hs)
			ra.append(tube_r * hs)
			rb.append(tube_r * hs)
			W.append_array(w8)
		_sweep(mb, "glasses", path, ra, rb, 4, W, PackedColorArray(), Vector3.BACK)
		# temple arm
		var tp := PackedVector3Array()
		var tra := PackedFloat32Array()
		var trb := PackedFloat32Array()
		var tw := PackedFloat32Array()
		var outer := ex + (0.0205 if round_f else 0.0225)
		tp.append(H + Vector3(m * outer, ey + 0.004, zf + 0.002) * hs)
		for a: float in [0.8, 1.05, 1.3, 1.52]:
			var bp := _head_base(d, a, ey + 0.002)
			bp += _skull_n(bp) * 0.0035
			tp.append(H + Vector3(m * bp.x, bp.y, bp.z) * hs)
		for i in tp.size():
			tra.append(tube_r * 0.9 * hs)
			trb.append(tube_r * 0.9 * hs)
			tw.append_array(w8)
		_sweep(mb, "glasses", tp, tra, trb, 4, tw, PackedColorArray(), Vector3.UP)
	# bridge
	var br := PackedVector3Array()
	var bra := PackedFloat32Array()
	var brb := PackedFloat32Array()
	var bw := PackedFloat32Array()
	var inner := ex - (0.0205 if round_f else 0.0225)
	for i in 5:
		var u := (float(i) / 4.0) * 2.0 - 1.0
		br.append(H + Vector3(u * inner, ey + 0.0045 + 0.002 * (1.0 - u * u), zf - 0.002 * (1.0 - u * u)) * hs)
		bra.append(tube_r * hs)
		brb.append(tube_r * hs)
		bw.append_array(w8)
	_sweep(mb, "glasses", br, bra, brb, 4, bw, PackedColorArray(), Vector3.BACK)


func _b_headphones(mb: MB, g: Dictionary) -> void:
	var d := _d
	var vy := d.vy
	var top_off: float = g["top_off"]
	var ny := d.neck_y + 0.012 * vy
	var nr := d.neck_r
	var zc := 0.012
	var chest_w := _wn([CHEST, 1.0])
	var cups: Array[Vector3] = []
	var cup := ModelKit.lathe(PackedVector2Array([Vector2(0.0, 0.0125), Vector2(0.02, 0.0125), Vector2(0.0275, 0.008), Vector2(0.0295, 0.0), Vector2(0.026, -0.011), Vector2(0.0, -0.012)]), 12)
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var y_c := 1.452 * vy
		var a_c := m * 0.76
		var at := _tpt(y_c, a_c, top_off + 0.016)
		var n := _tnrm(y_c, a_c, top_off)
		cups.append(at)
		var bc := Basis(_arc(Vector3.UP, n))
		_rigid(mb, "vc", cup, Transform3D(bc, at), chest_w, Color(0.055, 0.05, 0.05))
		_rigid(mb, "metal", ModelKit.sphere(1.0, 8, 3), Transform3D(_bs(bc, Vector3(0.011, 0.002, 0.011)), at + n * 0.0125), chest_w)
	# the band: up from one cup, around the back of the neck, down to the other
	var path := PackedVector3Array()
	var ra := PackedFloat32Array()
	var rb := PackedFloat32Array()
	var W := PackedFloat32Array()
	var C := PackedColorArray()
	var n_p := 13
	for i in n_p:
		var u := float(i) / (n_p - 1)
		var ang := lerpf(0.76, TAU - 0.76, u)
		var rr := nr + 0.024
		var y := ny + 0.012 + 0.012 * sin(u * PI)
		var p := Vector3(sin(ang) * rr, y, zc - cos(ang) * rr)
		var k := _ss(0.16, 0.0, u) + _ss(0.84, 1.0, u)
		if u < 0.5:
			p = p.lerp(cups[1], k)
		else:
			p = p.lerp(cups[0], k)
		path.append(p)
		ra.append(0.0042)
		rb.append(0.0078)
		W.append_array(_wn([CHEST, 0.8, NECK, 0.2]))
		C.append(Color(0.08, 0.08, 0.085))
	_sweep(mb, "vc", path, ra, rb, 6, W, C, Vector3.UP)


func _build_geometry(mb: MB) -> void:
	var g := _garment()
	_b_head(mb)
	_b_eyes(mb)
	_b_face_bits(mb)
	_b_hair(mb)
	_b_neck(mb)
	_b_torso(mb, g)
	_b_collar(mb, g)
	_b_arms(mb, g)
	_b_hands(mb)
	_b_legs(mb, g)
	_b_shoes(mb, g)
	_b_accessories(mb, g)


# ==========================================================================
# Materials
# ==========================================================================

static func _qc(c: Color) -> String:
	return "%d_%d_%d" % [roundi(c.r * 40.0), roundi(c.g * 40.0), roundi(c.b * 40.0)]


static func _skin_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	for i in SKIN_STOPS.size() - 1:
		var a: float = SKIN_STOPS[i]
		var b: float = SKIN_STOPS[i + 1]
		if t <= b:
			var ca: Color = SKIN_COLS[i]
			var cb: Color = SKIN_COLS[i + 1]
			return ca.lerp(cb, (t - a) / (b - a))
	return SKIN_COLS[SKIN_COLS.size() - 1]


static func _grime(skin: bool) -> NoiseTexture2D:
	if skin:
		return ModelKit.noise_tex("hm_grime_skin", 0.012, ModelKit.grad([Color(0.74, 0.70, 0.66), Color(0.90, 0.87, 0.84), Color(1, 1, 1)], [0.15, 0.45, 0.7]), false, 4.0, 256, 5, 43)
	return ModelKit.noise_tex("hm_grime", 0.012, ModelKit.grad([Color(0.58, 0.54, 0.49), Color(0.80, 0.77, 0.72), Color(1, 1, 1)], [0.12, 0.42, 0.72]), false, 4.0, 256, 5, 41)


static func _add_grime(m: StandardMaterial3D, skin := false) -> void:
	m.detail_enabled = true
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_albedo = _grime(skin)
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.uv2_triplanar = true
	m.uv2_scale = Vector3(2.6, 2.6, 2.6) if skin else Vector3(1.7, 1.7, 1.7)


static func _skin_mat(tone: float, dirty_v: bool) -> StandardMaterial3D:
	var q := roundi(clampf(tone, 0.0, 1.0) * 24.0)
	var key := "skin_%d_%s" % [q, dirty_v]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = _skin_color(float(q) / 24.0)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.56
	m.metallic_specular = 0.38
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.3
	m.subsurf_scatter_skin_mode = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.rim_enabled = true
	m.rim = 0.1
	m.rim_tint = 0.65
	m.normal_enabled = true
	m.normal_texture = ModelKit.noise_tex("hm_skin_n", 0.3, null, true, 1.2, 256, 3, 5)
	m.normal_scale = 0.1
	m.uv1_scale = Vector3(14.0, 14.0, 14.0)
	if dirty_v:
		m.albedo_color = m.albedo_color.darkened(0.05).lerp(Color(0.62, 0.55, 0.47), 0.1)
		_add_grime(m, true)
	_cache[key] = m
	return m


static func _eye_mat(iris: Color) -> StandardMaterial3D:
	var key := "eye_" + _qc(iris)
	if _cache.has(key):
		return _cache[key]
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var sclera := Color(0.95, 0.94, 0.905)
	var light := iris.lightened(0.34)
	var dark := iris.darkened(0.42)
	for py in n:
		for px in n:
			var dx := (px + 0.5) / n - 0.5
			var dy := (py + 0.5) / n - 0.5
			var r := sqrt(dx * dx + dy * dy) * 2.0
			var c: Color
			if r < 0.25:
				c = Color(0.012, 0.01, 0.01)
			elif r < 0.64:
				var u := (r - 0.25) / 0.39
				c = light.lerp(iris, _ss(0.0, 0.5, u)).lerp(dark, _ss(0.55, 1.0, u))
				c = c.lerp(Color(0.012, 0.01, 0.01), 1.0 - _ss(0.0, 0.07, u))
				var ang := atan2(dy, dx)
				c = c.lightened(0.09 * sin(ang * 23.0) * sin(ang * 9.0 + 1.0) * (1.0 - u))
				# the lid shades the top of the iris, the light pools at the bottom
				c = c.darkened(0.3 * _ss(0.0, -0.3, dy)).lightened(0.14 * _ss(0.05, 0.3, dy))
			else:
				var u := (r - 0.64) / 0.1
				c = Color(0.085, 0.06, 0.05).lerp(sclera, clampf(u, 0.0, 1.0))
				c = c.darkened(0.12 * _ss(0.75, 1.0, r))
			# a painted highlight keeps the eye alive in dim rooms
			var h1 := Vector2(dx + 0.085, dy + 0.11).length()
			var h2 := Vector2(dx - 0.07, dy - 0.095).length()
			c = c.lerp(Color(1.0, 0.99, 0.96), 1.0 - _ss(0.032, 0.05, h1))
			c = c.lerp(Color(0.9, 0.9, 0.88), 0.4 * (1.0 - _ss(0.016, 0.028, h2)))
			img.set_pixel(px, py, c)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.07
	m.metallic_specular = 0.7
	_cache[key] = m
	return m


static func _hair_mat(col: Color, dirty_v: bool) -> StandardMaterial3D:
	var key := "hair_%s_%s" % [_qc(col), dirty_v]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.5
	m.metallic_specular = 0.42
	m.albedo_texture = ModelKit.noise_tex("hm_hair_a", 0.09, ModelKit.grad([Color(0.78, 0.78, 0.78), Color(1.0, 1.0, 1.0)], [0.3, 0.7]), false, 4.0, 256, 3, 21)
	m.normal_enabled = true
	m.normal_texture = ModelKit.noise_tex("hm_hair_n", 0.1, null, true, 6.0, 256, 3, 9)
	m.normal_scale = 0.3
	m.uv1_scale = Vector3(46.0, 4.5, 1.0)
	m.rim_enabled = true
	m.rim = 0.18
	m.rim_tint = 0.8
	if dirty_v:
		m.roughness = 0.75
		m.albedo_color = col.darkened(0.12).lerp(Color(0.34, 0.31, 0.27), 0.18)
	_cache[key] = m
	return m


## Knit stitches ("knit"), vertical cables ("cable") or ribbing ("rib") as a normal map.
static func _knit_normal(kind: String) -> ImageTexture:
	var key := "knit_n_" + kind
	if _cache.has(key):
		return _cache[key]
	var w := 128
	var img := Image.create_empty(w, w, false, Image.FORMAT_RGB8)
	for py in w:
		for px in w:
			var u := float(px) / w
			var v := float(py) / w
			var h := 0.0
			match kind:
				"rib":
					h = 0.5 + 0.5 * sin(u * TAU * 8.0)
				_:
					var cu := fposmod(u * 8.0, 1.0)
					var cv := fposmod(v * 8.0, 1.0)
					for leg: float in [-1.0, 1.0]:
						var dx := (cu - 0.5 - leg * 0.22) + leg * (cv - 0.5) * 0.36
						var dy := cv - 0.5
						h = maxf(h, exp(-(dx * dx) / 0.018 - (dy * dy) / 0.13))
					if kind == "cable":
						var bx := fposmod(u * 2.0, 1.0)
						var band := _ss(0.17, 0.25, bx) * (1.0 - _ss(0.75, 0.83, bx))
						var rope := 0.0
						for k: float in [0.0, 0.5]:
							var cx := 0.5 + 0.17 * sin((v * 3.0 + k) * TAU)
							var dd := bx - cx
							rope = maxf(rope, exp(-(dd * dd) / 0.0065))
						var hc := 0.2 + 0.95 * rope
						h = lerpf(h * 0.6, hc, band)
			img.set_pixel(px, py, Color(h, h, h))
	img.bump_map_to_normal_map(3.5)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func _pattern_tex(pat: String, a: Color, b: Color) -> ImageTexture:
	var key := "pat_%s_%s_%s" % [pat, _qc(a), _qc(b)]
	if _cache.has(key):
		return _cache[key]
	var n := 96
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	for py in n:
		for px in n:
			var u := float(px) / n
			var v := float(py) / n
			var c := a
			match pat:
				"gingham":
					var vx := 1.0 if fposmod(u * 2.0, 1.0) < 0.5 else 0.0
					var vy := 1.0 if fposmod(v * 2.0, 1.0) < 0.5 else 0.0
					c = b.lerp(a, (vx + vy) * 0.5)
				"dots":
					var du := fposmod(u * 2.0, 1.0) - 0.5
					var dv := fposmod(v * 2.0 + floorf(u * 2.0) * 0.5, 1.0) - 0.5
					c = a if du * du + dv * dv < 0.04 else b
				"plaid":
					var vx := 0.5 + 0.5 * cos(u * TAU * 2.0)
					var vy := 0.5 + 0.5 * cos(v * TAU * 2.0)
					var thin := 1.0 if absf(fposmod(u * 4.0, 1.0) - 0.5) < 0.05 or absf(fposmod(v * 4.0, 1.0) - 0.5) < 0.05 else 0.0
					var mix_v := clampf(pow(vx, 3.0) + pow(vy, 3.0), 0.0, 1.0)
					c = b.lerp(a, mix_v).lerp(Color(0.95, 0.92, 0.8), thin * 0.28)
				"argyle":
					var du := absf(fposmod(u, 1.0) - 0.5) * 2.0
					var dv := absf(fposmod(v, 1.0) - 0.5) * 2.0
					var diamond := du + dv
					c = b if diamond < 1.0 else a
					var thin2 := absf(fposmod(u + v, 0.5) - 0.25)
					var thin3 := absf(fposmod(u - v, 0.5) - 0.25)
					if thin2 < 0.012 or thin3 < 0.012:
						c = a.lerp(Color(0.92, 0.9, 0.82), 0.75)
			img.set_pixel(px, py, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## kind: "cotton", "twill", "wool", "knit", "cable", "rib", "denim" or "canvas".
static func _fab(kind: String, col: Color, pat: String, dirty_v: bool, two_sided := false, col2 := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var key := "fab_%s_%s_%s_%s_%s_%s" % [kind, _qc(col), pat, dirty_v, two_sided, _qc(col2)]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	m.metallic_specular = 0.25
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var uvk := 10.0
	match kind:
		"knit", "cable", "rib":
			m.normal_enabled = true
			m.normal_texture = _knit_normal(kind)
			m.normal_scale = 0.55
			uvk = 17.0 if kind != "rib" else 26.0
			m.roughness = 0.96
			m.metallic_specular = 0.15
		"wool":
			m.normal_enabled = true
			m.normal_texture = ModelKit.noise_tex("hm_wool_n", 0.18, null, true, 3.0, 256, 3, 15)
			m.normal_scale = 0.45
			uvk = 14.0
			m.roughness = 0.97
		"denim":
			var n := ModelKit.load_tex("res://assets/textures/fabric_pattern_05/fabric_pattern_05_nor_gl.jpg")
			if n:
				m.normal_enabled = true
				m.normal_texture = n
				m.normal_scale = 0.5
			uvk = 26.0
			m.roughness = 0.82
			m.albedo_texture = ModelKit.noise_tex("hm_denim_a", 0.05, ModelKit.grad([Color(0.84, 0.86, 0.9), Color(1, 1, 1)], [0.1, 0.9]), false, 4.0, 256, 4, 18)
		_:
			var n := ModelKit.load_tex("res://assets/textures/fabric_pattern_05/fabric_pattern_05_nor_gl.jpg")
			if n:
				m.normal_enabled = true
				m.normal_texture = n
				m.normal_scale = 0.3
			uvk = 30.0 if kind == "twill" else 38.0
			m.roughness = 0.84 if kind == "twill" else 0.88
			m.albedo_texture = ModelKit.noise_tex("hm_mottle", 0.03, ModelKit.grad([Color(0.94, 0.94, 0.94), Color(1, 1, 1)], [0.0, 1.0]), false, 4.0, 256, 4, 7)
	var patk := 0.0
	match pat:
		"gingham":
			m.albedo_texture = _pattern_tex("gingham", col, Color(0.97, 0.96, 0.92))
			patk = 2.6
		"dots":
			m.albedo_texture = _pattern_tex("dots", Color(0.96, 0.95, 0.90), col)
			patk = 5.5
		"plaid":
			m.albedo_texture = _pattern_tex("plaid", col, col.darkened(0.55) if col2.a == 0.0 else col2)
			patk = 2.5
		"argyle":
			m.albedo_texture = _pattern_tex("argyle", col, col.darkened(0.5) if col2.a == 0.0 else col2)
			patk = 5.5
		"floral":
			var t := ModelKit.load_tex("res://assets/textures/floral_jacquard/floral_jacquard_diff.jpg")
			if t:
				m.albedo_texture = t
				m.normal_enabled = false
				m.albedo_color = col.lerp(Color.WHITE, 0.62)
				patk = 4.0
	if patk > 0.0:
		# one UV scale per material: the pattern sets it, and the weave normal scales with it
		uvk = patk
		if pat != "floral":
			m.albedo_color = Color.WHITE
		if kind in ["knit", "cable", "rib"]:
			m.normal_enabled = false
	m.uv1_scale = Vector3(uvk, uvk, uvk)
	if dirty_v:
		m.albedo_color = m.albedo_color.darkened(0.14).lerp(Color(0.36, 0.33, 0.28), 0.22)
		_add_grime(m)
	_cache[key] = m
	return m


static func _leather_mat(col: Color, dirty_v: bool) -> StandardMaterial3D:
	var key := "leather_%s_%s" % [_qc(col), dirty_v]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.38
	m.metallic_specular = 0.5
	m.clearcoat_enabled = true
	m.clearcoat = 0.3
	m.clearcoat_roughness = 0.25
	if dirty_v:
		m.roughness = 0.72
		m.clearcoat_enabled = false
		m.albedo_color = col.lerp(Color(0.34, 0.30, 0.25), 0.3)
		_add_grime(m)
	_cache[key] = m
	return m


static func _vc_mat() -> StandardMaterial3D:
	if _cache.has("vc"):
		return _cache["vc"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.42
	m.metallic_specular = 0.45
	_cache["vc"] = m
	return m


static func _vc2s_mat() -> StandardMaterial3D:
	if _cache.has("vc2s"):
		return _cache["vc2s"]
	var m := _vc_mat().duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["vc2s"] = m
	return m


static func _glasses_mat(col: Color) -> StandardMaterial3D:
	var key := "glasses_" + _qc(col)
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.22
	m.metallic_specular = 0.6
	_cache[key] = m
	return m


static func _patch_mat() -> StandardMaterial3D:
	if _cache.has("patch"):
		return _cache["patch"]
	var m := StandardMaterial3D.new()
	var t := ModelKit.load_tex("res://assets/textures/gen/logo_halcyon_color.png")
	if t:
		m.albedo_texture = t
	else:
		m.albedo_color = Color(0.92, 0.60, 0.13)
	m.roughness = 0.8
	_cache["patch"] = m
	return m


func _pick_col(user: Color, fallback: Color) -> Color:
	return user if user.a > 0.0 else fallback


func _mat_for(slot: String) -> Material:
	var f := sex == "f"
	var top_k := "cotton"
	var top_c := Color(0.88, 0.87, 0.82)
	var trim_k := "cotton"
	var trim_c := Color(0.95, 0.94, 0.90)
	var shirt_k := "cotton"
	var shirt_c := Color(0.92, 0.91, 0.87)
	var low_k := "wool"
	var low_c := Color(0.24, 0.24, 0.26) if not f else Color(0.17, 0.20, 0.33)
	var acc_c := Color(0.45, 0.10, 0.12)
	var shoe_c := Color(0.08, 0.06, 0.05)
	var hat_c := Color(0.13, 0.17, 0.27)
	var top_pat := ""
	var shirt_pat := ""
	match outfit:
		"cardigan":
			top_k = "knit"
			top_c = _pick_col(top_color, Color(0.60, 0.38, 0.24))
			trim_k = "rib"
			trim_c = top_c.darkened(0.14)
			shirt_c = _pick_col(shirt_color, shirt_c)
		"shirt_tie":
			top_c = _pick_col(top_color, Color(0.92, 0.91, 0.87))
			top_pat = pattern
			acc_c = _pick_col(accent_color, acc_c)
		"dress":
			top_c = _pick_col(top_color, Color(0.72, 0.30, 0.28))
			top_pat = pattern
			trim_c = Color(0.96, 0.95, 0.91)
			acc_c = trim_c
		"sweater":
			top_k = "knit"
			top_c = _pick_col(top_color, Color(0.30, 0.38, 0.46))
			trim_k = "rib"
			trim_c = top_c.darkened(0.1)
		"sweater_vest":
			top_k = "knit"
			top_c = _pick_col(top_color, Color(0.60, 0.46, 0.20))
			top_pat = pattern
			trim_k = "rib"
			trim_c = _pick_col(trim_color, top_c.darkened(0.45))
			shirt_c = _pick_col(shirt_color, Color(0.76, 0.84, 0.90))
		"overalls":
			top_c = _pick_col(shirt_color, Color(0.62, 0.20, 0.16))
			top_pat = pattern
			low_k = "denim"
			low_c = _pick_col(bottom_color, Color(0.20, 0.31, 0.48))
			shoe_c = Color(0.24, 0.15, 0.09)
		"fisherman":
			top_k = "cable"
			top_c = _pick_col(top_color, Color(0.84, 0.80, 0.68))
			trim_k = "rib"
			trim_c = top_c.darkened(0.08)
			low_c = _pick_col(bottom_color, Color(0.13, 0.16, 0.24))
			shoe_c = Color(0.08, 0.075, 0.07)
		"warden":
			top_k = "twill"
			top_c = _pick_col(top_color, Color(0.50, 0.46, 0.31))
			trim_c = top_c.darkened(0.1)
			trim_k = "twill"
			low_k = "twill"
			low_c = _pick_col(bottom_color, Color(0.46, 0.42, 0.29))
			acc_c = _pick_col(accent_color, Color(0.93, 0.92, 0.87))
			shoe_c = Color(0.12, 0.08, 0.05)
		"halcyon":
			top_k = "twill"
			top_c = _pick_col(top_color, Color(0.10, 0.41, 0.43))
			trim_k = "cotton"
			trim_c = _pick_col(trim_color, Color(0.92, 0.88, 0.76))
			low_k = "twill"
			low_c = _pick_col(bottom_color, Color(0.09, 0.34, 0.36))
			hat_c = top_c
			shoe_c = Color(0.06, 0.05, 0.05)
	low_c = _pick_col(bottom_color, low_c) if outfit != "overalls" else low_c
	shoe_c = _pick_col(shoe_color, shoe_c)
	acc_c = _pick_col(accent_color, acc_c)
	hat_c = _pick_col(hat_color, hat_c)
	if trim_color.a > 0.0:
		trim_c = trim_color
	if shirt_color.a > 0.0 and outfit != "overalls":
		shirt_c = shirt_color
	match slot:
		"skin":
			return _skin_mat(skin_tone, dirty)
		"eye":
			return _eye_mat(eye_color)
		"hair":
			return _hair_mat(hair_color, dirty)
		"brow":
			var bc := hair_color.darkened(0.25)
			if hair_color.get_luminance() > 0.45:
				bc = hair_color.darkened(0.42)
			return _hair_mat(bc, dirty)
		"top":
			return _fab(top_k, top_c, top_pat, dirty, false, trim_color)
		"top2s":
			return _fab(top_k, top_c, top_pat, dirty, true, trim_color)
		"trim":
			return _fab(trim_k, trim_c, "", dirty)
		"trim2":
			return _fab(shirt_k, shirt_c.darkened(0.1), "", dirty)
		"shirt":
			return _fab(shirt_k, shirt_c, shirt_pat, dirty)
		"bottom":
			return _fab(low_k, low_c, "", dirty)
		"bottom2s":
			return _fab(low_k, low_c, "", dirty, true)
		"shoe":
			return _leather_mat(shoe_c, dirty)
		"accent":
			return _fab("cotton", acc_c, "", dirty)
		"hat":
			return _fab("wool", hat_c, "", dirty)
		"vc":
			return _vc_mat()
		"vc2s":
			return _vc2s_mat()
		"metal":
			return ModelKit.chrome()
		"glasses":
			return _glasses_mat(Color(0.15, 0.08, 0.04) if glasses_style == "round" else Color(0.04, 0.035, 0.03))
		"patch":
			return _patch_mat()
		"helmet":
			return ModelKit.enamel("hm_helmet", Color(0.90, 0.89, 0.84), 0.4)
	return _vc_mat()


func _apply_materials() -> void:
	if _mi == null:
		return
	var m: ArrayMesh = _mi.mesh
	for i in m.get_surface_count():
		_mi.set_surface_override_material(i, _mat_for(m.surface_get_name(i)))
	if _blanket_mi:
		_blanket_mi.material_override = _fab("wool", blanket_color, "", dirty)


# ---------------------------------------------------------------- blanket

## A draped blanket for a lying body, head toward +Z. Origin on the mattress under the pelvis.
static func _blanket_mesh(d: Dims) -> ArrayMesh:
	var key := "blanket_%.2f_%.2f" % [d.vy, d.hx]
	if _cache.has(key):
		return _cache[key]
	var rows := 18
	var cols := 13
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 0.46 * d.hx
	var z0 := -(d.thigh + d.shin + 0.2 * d.vy)
	var z1 := 0.34 * d.vy
	var bump := (0.285 + 0.05 * d.heavy) * lerpf(0.8, 1.0, d.vy)
	var pts := PackedVector3Array()
	for r in rows:
		var v := float(r) / (rows - 1)
		var z := lerpf(z0, z1, v)
		for c in cols:
			var u := float(c) / (cols - 1) * 2.0 - 1.0
			var x := u * hw
			var body_w := 0.34 * d.hx
			var legs := _ss(z0 + 0.1, 0.0, z)
			var body_h := bump * lerpf(0.78, 1.0, legs)
			var y := 0.008 + body_h * exp(-pow(absf(x) / body_w, 2.4))
			y -= 0.12 * _ss(0.72, 1.0, absf(u))
			pts.append(Vector3(x, y, z))
	var idx := func(r: int, c: int) -> int: return r * cols + c
	for r in rows - 1:
		for c in cols - 1:
			var a: Vector3 = pts[idx.call(r, c)]
			var b: Vector3 = pts[idx.call(r, c + 1)]
			var e: Vector3 = pts[idx.call(r + 1, c)]
			var f: Vector3 = pts[idx.call(r + 1, c + 1)]
			var n1 := _pt_n(pts, rows, cols, r, c)
			var n2 := _pt_n(pts, rows, cols, r, c + 1)
			var n3 := _pt_n(pts, rows, cols, r + 1, c)
			var n4 := _pt_n(pts, rows, cols, r + 1, c + 1)
			ModelKit.tri(st, a, b, e, n1, n2, n3, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(e.x, e.z))
			ModelKit.tri(st, e, b, f, n3, n2, n4, Vector2(e.x, e.z), Vector2(b.x, b.z), Vector2(f.x, f.z))
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


static func _pt_n(pts: PackedVector3Array, rows: int, cols: int, r: int, c: int) -> Vector3:
	var a := pts[r * cols + mini(c + 1, cols - 1)] - pts[r * cols + maxi(c - 1, 0)]
	var b := pts[mini(r + 1, rows - 1) * cols + c] - pts[maxi(r - 1, 0) * cols + c]
	var n := a.cross(b).normalized()
	return -n if n.y < 0.0 else n


func _ensure_blanket() -> void:
	if _blanket_mi != null:
		return
	_blanket_mi = MeshInstance3D.new()
	_blanket_mi.name = "Blanket"
	_blanket_mi.mesh = _blanket_mesh(_d)
	_blanket_mi.material_override = _fab("wool", blanket_color, "", dirty)
	_blanket_mi.position = Vector3(0, seat_height / _rs, 0)
	_rig.add_child(_blanket_mi)


# ==========================================================================
# Holding things
# ==========================================================================

func _ensure_grip(s: int) -> void:
	if _grip[s] != null:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = BONE_NAMES[HAND_L + s * AS]
	_skel.add_child(att)
	_att[s] = att
	var g := Node3D.new()
	g.name = "Grip"
	att.add_child(g)
	_grip[s] = g
	var m := -1.0 if s == 0 else 1.0
	g.position = Vector3(-m * 0.016, -0.066, -0.004) * _d.hk
	g.scale = Vector3.ONE / _rs


## The hand's orientation (in the chest or rig frame) while holding: fingers forward, palm inward.
func _front_hand_q(s: int) -> Quaternion:
	var m := -1.0 if s == 0 else 1.0
	return _hand_q(Vector3(0, 0, -1), Vector3(-m, 0, 0), m)


func _attach_held(s: int, r: float) -> void:
	_ensure_grip(s)
	var n: Node3D = _held[s]
	if n == null:
		return
	if n.get_parent():
		n.get_parent().remove_child(n)
	_grip[s].add_child(n)
	var m := -1.0 if s == 0 else 1.0
	var kind := _hold_kind[s]
	var pos: Vector3
	if kind == 2:
		pos = Vector3(-m * 0.012, -0.102, 0.0) * _d.hk
		n.transform = Transform3D.IDENTITY
	else:
		pos = Vector3(-m * (0.012 + r), -0.068, -0.004) * _d.hk
		n.transform = Transform3D(Basis(_front_hand_q(s)).inverse(), Vector3.ZERO)
	_grip[s].position = pos


static func _mug_mesh() -> ArrayMesh:
	if _cache.has("prop_mug"):
		return _cache["prop_mug"]
	var m := ModelKit.lathe(PackedVector2Array([Vector2(0.0, -0.047), Vector2(0.036, -0.047), Vector2(0.04, -0.043), Vector2(0.04, 0.047),
		Vector2(0.036, 0.049), Vector2(0.034, 0.042), Vector2(0.034, -0.03), Vector2(0.0, -0.03)]), 18)
	_cache["prop_mug"] = m
	return m


## A prop ready for hold(): "mug", "pamphlets", "radio" or "clipboard".
static func make_prop(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind.capitalize()
	match kind:
		"mug":
			root.set_meta("hold_style", "front")
			root.set_meta("grip_r", 0.04)
			root.set_meta("grip_curl", 0.62)
			var cer := ModelKit.enamel("hm_mug", Color(0.92, 0.88, 0.76), 0.28)
			ModelKit.mi(root, _mug_mesh(), cer)
			ModelKit.mi(root, ModelKit.torus(0.0395, 0.0408, 18, 4), ModelKit.enamel("hm_mug_band", Color(0.12, 0.45, 0.46), 0.28), Vector3(0, 0.028, 0))
			ModelKit.mi(root, ModelKit.torus(0.0165, 0.0225, 12, 5), cer, Vector3(0, 0, 0.045), Vector3(0, 90, 90), Vector3(1.0, 1.0, 1.25))
			ModelKit.mi(root, ModelKit.cyl(0.0335, 0.0335, 0.002, 16), ModelKit.pbr("hm_coffee", Color(0.11, 0.06, 0.035), 0.0, 0.15), Vector3(0, 0.03, 0))
		"pamphlets":
			root.set_meta("hold_style", "front")
			root.set_meta("grip_r", 0.006)
			root.set_meta("grip_curl", 0.55)
			var paper := ModelKit.pbr("hm_pamphlet", Color(0.92, 0.89, 0.78), 0.0, 0.85)
			var band := ModelKit.pbr("hm_pamphlet_b", Color(0.11, 0.44, 0.46), 0.0, 0.8)
			var amber := ModelKit.pbr("hm_pamphlet_a", Color(0.92, 0.62, 0.15), 0.0, 0.75)
			for i in 3:
				var y_r := -3.0 + i * 4.0
				var leaf := ModelKit.pivot(root, "Leaf%d" % i, Vector3(0.002 * (i - 1), 0.008 * (i - 1), 0.0035 * (i - 1)), Vector3(0, y_r, -2.0 + i * 2.0))
				ModelKit.mi(leaf, ModelKit.box(Vector3(0.1, 0.21, 0.0025)), paper, Vector3(0, 0.03, 0))
				ModelKit.mi(leaf, ModelKit.box(Vector3(0.1, 0.052, 0.003)), band, Vector3(0, 0.106, 0))
				ModelKit.mi(leaf, ModelKit.box(Vector3(0.1, 0.006, 0.003)), amber, Vector3(0, 0.077, 0))
		"radio":
			root.set_meta("hold_style", "carry")
			root.set_meta("grip_curl", 0.92)
			var body := ModelKit.enamel("hm_radio", Color(0.60, 0.17, 0.13), 0.35)
			var dark := ModelKit.pbr("hm_radio_d", Color(0.09, 0.08, 0.075), 0.2, 0.55)
			var cream := ModelKit.pbr("hm_radio_c", Color(0.88, 0.84, 0.72), 0.0, 0.5)
			ModelKit.mi(root, ModelKit.rounded_box(Vector3(0.24, 0.15, 0.07), 0.018, 2), body, Vector3(0, -0.105, 0))
			ModelKit.mi(root, ModelKit.rounded_box(Vector3(0.125, 0.11, 0.008), 0.003, 1), ModelKit.chrome(), Vector3(-0.045, -0.105, -0.035))
			for i in 7:
				ModelKit.mi(root, ModelKit.box(Vector3(0.11, 0.004, 0.003)), dark, Vector3(-0.045, -0.15 + i * 0.015, -0.0395))
			ModelKit.mi(root, ModelKit.rounded_box(Vector3(0.07, 0.03, 0.005), 0.002, 1), cream, Vector3(0.07, -0.075, -0.0355))
			ModelKit.mi(root, ModelKit.cyl(0.016, 0.018, 0.012, 12), dark, Vector3(0.07, -0.128, -0.04), Vector3(90, 0, 0))
			var handle_path := PackedVector3Array([Vector3(-0.08, -0.032, 0), Vector3(-0.07, 0.0, 0), Vector3(-0.03, 0.012, 0), Vector3(0.03, 0.012, 0), Vector3(0.07, 0.0, 0), Vector3(0.08, -0.032, 0)])
			var radii := PackedFloat32Array([0.006, 0.006, 0.006, 0.006, 0.006, 0.006])
			ModelKit.mi(root, ModelKit.tube(handle_path, radii, 6), dark)
		"clipboard":
			root.set_meta("hold_style", "chest")
			root.set_meta("grip_r", 0.006)
			root.set_meta("grip_curl", 0.5)
			var board := ModelKit.pbr("hm_clipboard", Color(0.34, 0.22, 0.12), 0.0, 0.6)
			var paper := ModelKit.pbr("hm_clip_paper", Color(0.93, 0.91, 0.84), 0.0, 0.85)
			ModelKit.mi(root, ModelKit.rounded_box(Vector3(0.23, 0.32, 0.005), 0.002, 1), board, Vector3(0, 0.12, 0))
			ModelKit.mi(root, ModelKit.box(Vector3(0.205, 0.27, 0.002)), paper, Vector3(0, 0.105, -0.0035))
			ModelKit.mi(root, ModelKit.rounded_box(Vector3(0.07, 0.024, 0.014), 0.003, 1), ModelKit.chrome(), Vector3(0, 0.27, -0.005))
		_:
			push_warning("HumanModel: unknown prop '%s'" % kind)
	return root


# ==========================================================================
# Animation
# ==========================================================================

func _end_gesture() -> void:
	var n := _g_name
	_g_id = G_NONE
	_g_name = ""
	_g_t = 0.0
	gesture_finished.emit(n)


## Hand orientation: fingers and the palm's facing direction, in the frame they are given in.
## m = +1 for the right hand, -1 for the left.
static func _hand_q(fingers: Vector3, palm: Vector3, m: float) -> Quaternion:
	var f := fingers.normalized()
	var q := _arc(Vector3.DOWN, f)
	var p0 := q * Vector3(-m, 0, 0)
	var pp := palm - f * palm.dot(f)
	if pp.length_squared() < 1e-6:
		return q
	pp = pp.normalized()
	return Quaternion(f, p0.signed_angle_to(pp, f)) * q


static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	if from.dot(to) < -0.9995:
		return Quaternion(Vector3.RIGHT, PI)
	return Quaternion(from, to)


## Adds an arm IK request (target in rig space). Later requests blend over earlier ones.
func _req(s: int, tgt: Vector3, hand: Quaternion, pole: Vector3, w: float) -> void:
	if w <= 0.0:
		return
	var old := _ik_w[s]
	if old <= 0.0:
		_ik_p[s] = tgt
		_ik_h[s] = hand
		_ik_pole[s] = pole
		_ik_w[s] = w
		return
	_ik_p[s] = _ik_p[s].lerp(tgt, w)
	_ik_h[s] = _ik_h[s].slerp(hand, w)
	_ik_pole[s] = _ik_pole[s].lerp(pole, w)
	_ik_w[s] = old + (1.0 - old) * w


## Same, with target, hand and pole given in the chest's frame.
func _req_c(s: int, tgt: Vector3, hand: Quaternion, pole: Vector3, w: float) -> void:
	_req(s, _chest_p + _chest_q * tgt, _chest_q * hand, _chest_q * pole, w)


## Rest position of a shoulder joint in the chest's frame.
func _sh_c(s: int) -> Vector3:
	return _rl[CLAV_L + s * AS] + _rl[UARM_L + s * AS]


## Two-bone IK. Both bones hang along -Y at rest and hinge about +X. Result in _ik_q1 (global) and _ik_q2 (local).
func _ik(root: Vector3, tgt: Vector3, pole: Vector3, l1: float, l2: float, knee: bool) -> void:
	var dv := tgt - root
	var len_v := dv.length()
	var dist := clampf(len_v, absf(l1 - l2) + 0.01, l1 + l2 - 0.0005)
	var dn := dv / len_v if len_v > 1e-5 else Vector3.DOWN
	var pp := pole - dn * pole.dot(dn)
	if pp.length_squared() < 1e-6:
		pp = Vector3.BACK - dn * dn.z
		if pp.length_squared() < 1e-6:
			pp = Vector3.RIGHT
	pp = pp.normalized()
	var ca := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var sa := sqrt(1.0 - ca * ca)
	var u := dn * ca + pp * sa
	var e := root + u * l1
	var l := root + dn * dist - e
	l = l.normalized()
	var h := l.cross(u) if knee else u.cross(l)
	if h.length_squared() < 1e-5:
		h = (-pp).cross(u) if knee else u.cross(-pp)
	h = h.normalized()
	var q1 := _arc(Vector3.DOWN, u)
	var hx := q1 * Vector3.RIGHT
	q1 = Quaternion(u, hx.signed_angle_to(h, u)) * q1
	var ll := q1.inverse() * l
	_ik_q1 = q1
	_ik_q2 = Quaternion(Vector3.RIGHT, atan2(-ll.z, -ll.y))


func _timers(dt: float) -> void:
	_blink_t -= dt
	if _blink_t <= 0.0:
		_blink = 1.0
		_blink_t = _rng.randf_range(2.0, 5.5)
		if _rng.randf() < 0.18:
			_blink_t = 0.3
		if _panic:
			_blink_t *= 0.5
	_blink = maxf(0.0, _blink - dt / 0.17)
	_ws_t -= dt
	if _ws_t <= 0.0:
		_ws_t = _rng.randf_range(5.0, 13.0)
		_ws_tgt = -signf(_ws_tgt) if _ws_tgt != 0.0 else 1.0
		_ws_tgt *= _rng.randf_range(0.65, 1.0)
	_ws = ModelKit.damp(_ws, _ws_tgt, 1.1, dt)
	_glance_t -= dt
	if _glance_t <= 0.0:
		var k := 2.4 if _panic else 1.0
		_glance_t = _rng.randf_range(2.0, 6.0) / (3.0 if _panic else 1.0)
		_glance_tgt = Vector2(_rng.randf_range(-0.42, 0.42) * k, _rng.randf_range(-0.14, 0.12))
		if _rng.randf() < 0.3:
			_glance_tgt = Vector2.ZERO
	_glance = _glance.lerp(_glance_tgt, 1.0 - exp(-(8.0 if _panic else 2.6) * dt))
	_sacc_t -= dt
	if _sacc_t <= 0.0:
		_sacc_t = _rng.randf_range(0.5, 2.4) / (2.0 if _panic else 1.0)
		_sacc_tgt = Vector2(_rng.randf_range(-0.16, 0.16), _rng.randf_range(-0.07, 0.07))
	_sacc = _sacc.lerp(_sacc_tgt, 1.0 - exp(-26.0 * dt))
	_style_t -= dt
	if _style_t <= 0.0:
		_style_t = _rng.randf_range(18.0, 45.0)
		if idle_style < 0:
			_style = _pick_idle_style()
			_style_w = 0.0
	_style_w = ModelKit.damp(_style_w, 1.0, 1.6, dt)
	_breath_ph = fposmod(_breath_ph + dt * _breath_rate * (2.2 if _panic else 1.0), TAU)


func _update(dt: float, face: bool) -> void:
	_t += dt
	_timers(dt)
	var look_rig := Vector3.ZERO
	if _look_on:
		look_rig = _rig.global_transform.affine_inverse() * _look_world
	_spd = ModelKit.damp(_spd, _tgt_spd, 5.0, dt)
	var wsum := 0.0
	for k in P_N:
		_pw[k] = ModelKit.damp(_pw[k], 1.0 if k == _pose_id else 0.0, 3.2, dt)
		wsum += _pw[k]
	wsum = maxf(wsum, 0.001)
	_talk = ModelKit.damp(_talk, 1.0 if _talking else 0.0, 7.0, dt)
	_panic_w = ModelKit.damp(_panic_w, 1.0 if _panic else 0.0, 5.0, dt)
	_look_w = ModelKit.damp(_look_w, 1.0 if _look_on else 0.0, 4.0, dt)
	# reset this frame's accumulators
	for i in NB:
		_e[i] = Vector3.ZERO
	_hp = Vector3.ZERO
	_ft_w = 0.0
	_face_h = 0.0
	_face_w = 0.0
	_face_s = 0.0
	_jaw_add = 0.0
	for s in 2:
		_ik_w[s] = 0.0
		_ft[s] = Vector3.ZERO
		_ftp[s] = 0.0
		_curl[s] = 0.36
		_idx[s] = 0.27
		_thumb[s] = 0.25
	# poses
	if _pw[P_STAND] > 0.001:
		_pose_stand(dt, _pw[P_STAND] / wsum)
	if _pw[P_SIT] > 0.001:
		_pose_sit(_pw[P_SIT] / wsum)
	if _pw[P_LIE] > 0.001:
		_pose_lie(_pw[P_LIE] / wsum)
	if _pw[P_GROUND] > 0.001:
		_pose_ground(_pw[P_GROUND] / wsum)
	if _pw[P_COWER] > 0.001:
		_pose_cower(_pw[P_COWER] / wsum)
	_layer_common(dt)
	_layer_hold(dt)
	_layer_talk(dt)
	if _g_id != G_NONE:
		_layer_gesture(dt)
	_layer_look(dt, look_rig)
	_solve(dt)
	if face:
		_update_face(dt, look_rig)
	_push(face)


func _pose_stand(dt: float, w: float) -> void:
	var d := _d
	var v := _spd / _rs
	var walk := _ss(0.05, 0.6, _spd)
	var run := _ss(2.2, 3.6, _spd)
	var idle := 1.0 - walk
	var legk := (d.thigh + d.shin) / 0.86
	var hy := d.hips_y - 0.012 * d.vy
	var hipx := 0.0
	var hp_e := Vector3.ZERO
	# weight shift: the hips drift, and the planted feet make one knee bend
	var ws := _ws * idle
	hipx += ws * 0.03 * d.hx
	hy -= absf(ws) * 0.009
	hp_e.z += ws * 0.05
	_e[SPINE] += w * Vector3(0, 0, -ws * 0.055)
	_e[CHEST] += w * Vector3(0, 0, -ws * 0.02)
	_e[HEAD] += w * Vector3(0, 0, ws * 0.018)
	var f0 := Vector3(-(d.hip_x + 0.012), d.ankle_h, 0.012 * _stance + 0.008)
	var f1 := Vector3(d.hip_x + 0.012, d.ankle_h, -0.03 * _stance)
	var fp0 := 0.0
	var fp1 := 0.0
	if walk > 0.001:
		var stride_max := lerpf(1.08, 2.3, run) * legk
		var fmin := lerpf(0.75, 1.3, run)
		var fc := maxf(fmin, v / stride_max)
		var duty := lerpf(0.6, 0.36, run)
		var S := v * duty / fc
		_phase = fposmod(_phase + dt * fc, 1.0)
		for s in 2:
			var ph := fposmod(_phase + 0.5 * s, 1.0)
			var m := -1.0 if s == 0 else 1.0
			var z: float
			var y := d.ankle_h
			var pitch := 0.0
			var heel_h := (0.05 + 0.04 * run) * legk
			if ph < duty:
				var u := ph / duty
				z = lerpf(-0.42 * S, 0.58 * S, u)
				var heel := _ss(0.62, 1.0, u)
				y += heel * heel_h
				pitch = 0.2 * (1.0 - _ss(0.0, 0.16, u)) * (1.0 - run) - heel * (0.5 + 0.3 * run)
			else:
				var u := (ph - duty) / (1.0 - duty)
				var e := u * u * (3.0 - 2.0 * u)
				z = lerpf(0.58 * S, -0.42 * S, e)
				y += sin(u * PI) * lerpf(0.07, 0.17, run) * legk + (1.0 - _ss(0.0, 0.35, u)) * heel_h
				pitch = lerpf(-0.5 - 0.3 * run, 0.2 * (1.0 - run), _ss(0.0, 0.85, u))
			var cyc := Vector3(m * (d.hip_x - 0.008), y, z)
			if s == 0:
				f0 = f0.lerp(cyc, walk)
				fp0 = lerpf(fp0, pitch, walk)
			else:
				f1 = f1.lerp(cyc, walk)
				fp1 = lerpf(fp1, pitch, walk)
		var p2 := _phase * TAU
		var cp := cos(p2)
		var sp := sin(p2)
		hy -= (0.028 * (1.0 - run) + 0.036 * run) * walk * legk
		hy += 0.015 * -cos(2.0 * p2) * walk * legk
		hipx += -0.018 * sin(p2 + 0.5) * walk * (1.0 - run)
		hp_e += Vector3(-0.05 * run, -0.11 * cp * walk * (1.0 + 0.5 * run), 0.04 * sp * walk)
		_e[SPINE] += w * Vector3(-0.03 * walk - 0.17 * run, 0.05 * cp * walk, 0)
		_e[CHEST] += w * Vector3(-0.02 * run, 0.13 * cp * walk * (1.0 + 0.4 * run), -0.02 * sp * walk)
		_e[NECK] += w * Vector3(0.04 * walk + 0.13 * run, -0.08 * cp * walk, 0)
		_e[HEAD] += w * Vector3(0.015 * walk + 0.05 * run + 0.018 * sin(2.0 * p2) * walk, -0.04 * cp * walk, 0)
		var A := lerpf(0.3, 0.72, run) * walk
		for s in 2:
			var m := -1.0 if s == 0 else 1.0
			var o := s * AS
			var sw := m * cp
			_e[UARM_L + o] += w * Vector3(A * sw + 0.08 * run, 0, m * 0.08 * run)
			_e[FARM_L + o] += w * Vector3(0.14 * walk + 1.22 * run + 0.26 * maxf(sw, 0.0) * walk, 0, 0)
			_curl[s] = lerpf(_curl[s], 0.72, run)
			_idx[s] = lerpf(_idx[s], 0.68, run)
			_thumb[s] = lerpf(_thumb[s], 0.5, run)
	_ft[0] += w * f0
	_ft[1] += w * f1
	_ftp[0] += w * fp0
	_ftp[1] += w * fp1
	_ft_w += w
	_hp += w * Vector3(hipx, hy, 0.0)
	_e[HIPS] += w * hp_e
	# arms hang
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var o := s * AS
		var sway := sin(_t * 0.61 + float(s) * 1.9)
		_e[UARM_L + o] += w * Vector3(0.04 + 0.018 * sway * idle, 0, m * (0.085 + 0.06 * d.heavy))
		_e[FARM_L + o] += w * Vector3(0.24 + 0.03 * sway * idle, 0, 0)
		_e[HAND_L + o] += w * Vector3(0.05, 0, m * 0.06)
	# posture
	match posture:
		"stoop":
			_hp.y -= w * 0.015 * d.vy
			_e[SPINE] += w * Vector3(-0.13, 0, 0)
			_e[CHEST] += w * Vector3(-0.12, 0, 0)
			_e[NECK] += w * Vector3(0.16, 0, 0)
			_e[HEAD] += w * Vector3(0.09, 0, 0)
		"proud":
			_e[CHEST] += w * Vector3(0.055, 0, 0)
			_e[SPINE] += w * Vector3(0.02, 0, 0)
			_e[NECK] += w * Vector3(-0.02, 0, 0)
		"shy":
			_e[SPINE] += w * Vector3(-0.035, 0, 0)
			_e[CHEST] += w * Vector3(-0.05, 0, 0)
			_e[NECK] += w * Vector3(-0.015, 0, 0)
			_e[HEAD] += w * Vector3(-0.05, 0, 0.03)
			for s in 2:
				var m := -1.0 if s == 0 else 1.0
				_e[CLAV_L + s * AS] += w * Vector3(0, m * 0.08, m * 0.05)
	# resting arms
	var st_w := w * idle * _style_w
	if st_w > 0.001 and _style != 0:
		_idle_arms(st_w)


func _idle_arms(w: float) -> void:
	var d := _d
	var L := (d.uarm + d.farm) / 0.54
	var top_extra := 0.02 + 0.012 * d.heavy
	for s in 2:
		if _held[s] != null:
			continue
		var m := -1.0 if s == 0 else 1.0
		var sh := _sh_c(s)
		var tgt: Vector3
		var fing: Vector3
		var palm: Vector3
		var pole := Vector3(m * 0.5, -0.1, 1.0)
		var curl := 0.45
		match _style:
			1: # clasped low in front, clear of the belly
				var y := sh.y - 0.495 * L
				var pr := _tprof(d.chest_y + y)
				tgt = Vector3(m * 0.012, y, -(pr.y + top_extra + 0.035))
				fing = Vector3(-m * 0.85, -0.45, -0.1)
				palm = Vector3(0, 0.15, 1.0)
				curl = 0.5
			2: # behind the back
				var y := sh.y - 0.47 * L
				var pr := _tprof(d.chest_y + y)
				tgt = Vector3(m * 0.02, y, pr.z + top_extra + 0.045)
				fing = Vector3(-m * 0.8, -0.5, 0.2)
				palm = Vector3(0, 0.0, -1.0)
				pole = Vector3(m * 1.0, 0.0, 0.5)
				curl = 0.5
			3: # arms folded on the chest
				var pr := _tprof(d.chest_y + sh.y - 0.2 * L)
				var z := -(pr.y + top_extra + 0.03)
				if s == 1:
					tgt = Vector3(-0.1 * L, sh.y - 0.2 * L, z - 0.012)
					fing = Vector3(-1.0, 0.15, 0.1)
					palm = Vector3(0, -0.25, 1.0)
				else:
					tgt = Vector3(0.1 * L, sh.y - 0.16 * L, z + 0.01)
					fing = Vector3(1.0, 0.1, 0.15)
					palm = Vector3(0, 0.0, 1.0)
				pole = Vector3(m * 1.0, -0.65, 0.25)
				curl = 0.35
			4: # hands in pockets, at the side of the hip
				var y := sh.y - 0.49 * L
				var pr := _tprof(d.chest_y + y)
				tgt = Vector3(m * (pr.x + 0.008), y, -0.012)
				fing = Vector3(-m * 0.05, -1.0, -0.12)
				palm = Vector3(-m, 0, 0)
				pole = Vector3(m * 1.0, 0.0, 0.8)
				curl = 0.3
			_: # hands on hips
				var y := sh.y - 0.335 * L
				var pr := _tprof(d.chest_y + y)
				tgt = Vector3(m * (pr.x + top_extra + 0.012), y, 0.012)
				fing = Vector3(-m * 0.45, -0.75, -0.35)
				palm = Vector3(-m, 0.0, 0.25)
				pole = Vector3(m * 1.0, 0.0, 0.2)
				curl = 0.15
		_req_c(s, tgt, _hand_q(fing, palm, m), pole, w)
		_curl[s] = lerpf(_curl[s], curl, w)
		_idx[s] = lerpf(_idx[s], curl, w)


func _pose_sit(w: float) -> void:
	var d := _d
	var sh := seat_height / _rs
	var hj := sh + 0.095 * d.vy
	_hp += w * Vector3(0, hj + 0.04 * d.vy, 0.015)
	_e[HIPS] += w * Vector3(0.14, 0, 0)
	_e[SPINE] += w * Vector3(-0.1, 0, 0)
	_e[CHEST] += w * Vector3(-0.05, 0, 0)
	_e[NECK] += w * Vector3(0.02, 0, 0)
	if posture == "stoop":
		_e[SPINE] += w * Vector3(-0.1, 0, 0)
		_e[CHEST] += w * Vector3(-0.08, 0, 0)
		_e[NECK] += w * Vector3(0.14, 0, 0)
	var sway := 0.01 * sin(_t * 0.4 + 1.2)
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var ftz := -(d.thigh * 0.97) + 0.012 * _stance * m
		_ft[s] += w * Vector3(m * (d.hip_x + 0.022), d.ankle_h, ftz)
		_ftp[s] += 0.0
		# hands rest on the thighs or the lap
		var tgt := Vector3(m * (d.hip_x + 0.03 - 0.008 * d.slim), hj + 0.082 * d.vy * d.leg_k, -0.235 * d.vy + sway)
		var fing := Vector3(-m * 0.08, -0.12, -1.0)
		var palm := Vector3(-m * 0.1, -1.0, 0.1)
		if _style == 1 or _style == 2:
			tgt = Vector3(m * 0.04, hj + 0.09 * d.vy * d.leg_k, -0.2 * d.vy + sway)
			fing = Vector3(-m * 0.75, -0.1, -0.6)
			palm = Vector3(-m * 0.3, -1.0, 0.0)
		_req(s, tgt, _hand_q(fing, palm, m), Vector3(m * 0.5, 0.0, 1.0), w)
	_ft_w += w


func _pose_lie(w: float) -> void:
	var d := _d
	var sh := seat_height / _rs
	_hp += w * Vector3(0, sh + 0.105 * d.vy * (1.0 + 0.2 * d.heavy), 0)
	_e[HIPS] += w * Vector3(PI * 0.5, 0, 0)
	_e[SPINE] += w * Vector3(0.015, 0, 0)
	_e[NECK] += w * Vector3(-0.2, 0, 0)
	_e[HEAD] += w * Vector3(-0.14, 0, 0.02 * sin(_t * 0.15))
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var l := s * LS
		var o := s * AS
		_e[THIGH_L + l] += w * Vector3(0.015, 0, m * 0.055)
		_e[SHIN_L + l] += w * Vector3(-0.05, 0, 0)
		_e[FOOT_L + l] += w * Vector3(-0.8, m * -0.3, 0)
		_e[UARM_L + o] += w * Vector3(0.03, 0, m * 0.08)
		_e[FARM_L + o] += w * Vector3(0.16, 0, 0)
		_e[HAND_L + o] += w * Vector3(-0.08, 0, m * 0.1)
		_curl[s] = lerpf(_curl[s], 0.42, w)
		_idx[s] = lerpf(_idx[s], 0.38, w)


func _pose_ground(w: float) -> void:
	var d := _d
	var hj := 0.1 * d.vy
	_hp += w * Vector3(0, hj + 0.04 * d.vy, 0)
	var legk := (d.thigh + d.shin) / 0.86
	if _ground_var == 0:
		# knees up, arms around them
		_e[HIPS] += w * Vector3(0.32, 0, 0)
		_e[SPINE] += w * Vector3(-0.3, 0, 0)
		_e[CHEST] += w * Vector3(-0.16, 0, 0)
		_e[NECK] += w * Vector3(0.08, 0, 0)
		_e[HEAD] += w * Vector3(0.1, 0, 0)
		for s in 2:
			var m := -1.0 if s == 0 else 1.0
			_ft[s] += w * Vector3(m * (d.hip_x + 0.02), d.ankle_h, -0.46 * legk)
			var tgt := Vector3(m * 0.07 * d.hx, 0.28 * legk + hj, -0.46 * legk)
			var fing := Vector3(-m, 0.05, 0.05)
			var palm := Vector3(0, -0.1, 1.0)
			_req(s, tgt, _hand_q(fing, palm, m), Vector3(m * 0.9, -0.4, 0.1), w)
			_curl[s] = lerpf(_curl[s], 0.55, w)
			_idx[s] = lerpf(_idx[s], 0.55, w)
	else:
		# legs out, leaning back on the hands
		_e[HIPS] += w * Vector3(0.1, 0, 0)
		_e[SPINE] += w * Vector3(0.16, 0, 0)
		_e[CHEST] += w * Vector3(0.05, 0, 0)
		_e[NECK] += w * Vector3(-0.12, 0, 0)
		_e[HEAD] += w * Vector3(-0.08, 0, 0)
		for s in 2:
			var m := -1.0 if s == 0 else 1.0
			var bend := 0.08 if s == 0 else 0.2
			_ft[s] += w * Vector3(m * (d.hip_x + 0.06), d.ankle_h, -(0.74 - bend) * legk)
			var tgt := Vector3(m * (d.sh_x + 0.05), 0.012 + 0.062 * d.hk, 0.2 * d.vy)
			var fing := Vector3(m * 0.25, 0.0, 1.0)
			var palm := Vector3(0, -1.0, 0)
			_req(s, tgt, _hand_q(fing, palm, m), Vector3(m * 0.3, 0.0, 1.0), w)
			_curl[s] = lerpf(_curl[s], 0.1, w)
			_idx[s] = lerpf(_idx[s], 0.1, w)
	_ft_w += w


func _pose_cower(w: float) -> void:
	var d := _d
	var legk := (d.thigh + d.shin) / 0.86
	var hj := 0.42 * legk
	var tremble := sin(_t * 31.0) * 0.012 + sin(_t * 23.0) * 0.008
	_hp += w * Vector3(tremble * 0.5, hj + 0.04 * d.vy, 0.11 * legk)
	_e[HIPS] += w * Vector3(-0.36, 0, 0)
	_e[SPINE] += w * Vector3(-0.42 + tremble, 0, 0)
	_e[CHEST] += w * Vector3(-0.3, 0, tremble)
	_e[NECK] += w * Vector3(-0.28, 0, 0)
	_e[HEAD] += w * Vector3(-0.2 + tremble * 2.0, 0, 0)
	var L := (d.uarm + d.farm) / 0.54
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		_ft[s] += w * Vector3(m * (d.hip_x + 0.04), d.ankle_h, (-0.05 if s == 0 else 0.03) * legk)
		_ftp[s] += w * (-0.12 if s == 1 else 0.0)
		var sh := _sh_c(s)
		var tgt := Vector3(m * 0.035, sh.y + 0.21 * L, sh.z - 0.08 * L)
		var fing := Vector3(-m * 0.55, 0.05, 0.85)
		var palm := Vector3(0, -1.0, 0.1)
		_req_c(s, tgt, _hand_q(fing, palm, m), Vector3(m * 0.9, 0.2, -0.9), w)
		_curl[s] = lerpf(_curl[s], 0.42, w)
		_idx[s] = lerpf(_idx[s], 0.42, w)
		_e[CLAV_L + s * AS] += w * Vector3(0, m * 0.12, m * 0.09)
	_ft_w += w
	_face_s = maxf(_face_s, w)


## Breathing, head wander and panic, on top of any pose.
func _layer_common(_dt: float) -> void:
	var br := sin(_breath_ph)
	var br_k := 1.0 + 1.3 * _panic_w
	_e[CHEST] += Vector3(-0.012 * br * br_k, 0, 0)
	_e[SPINE] += Vector3(0.005 * br * br_k, 0, 0)
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		_e[CLAV_L + s * AS] += Vector3(0, 0, m * (0.012 + 0.006 * sin(_t * 0.37 + float(s))) * br * br_k)
	_e[HEAD] += Vector3(0.012 * sin(_t * 0.43), 0.012 * sin(_t * 0.29), 0.016 * sin(_t * 0.61 + 1.0))
	if _panic_w > 0.001:
		var pw := _panic_w
		var tr := sin(_t * 29.0) * 0.012 + sin(_t * 41.0) * 0.008
		_e[SPINE] += pw * Vector3(-0.06 + tr, 0, tr)
		_e[HEAD] += pw * Vector3(tr, tr * 1.5, 0)
		_face_s = maxf(_face_s, pw)
		var still := pw * (1.0 - _ss(0.1, 0.7, _spd)) * _pw[P_STAND]
		if still > 0.001:
			for s in 2:
				if _held[s] != null:
					continue
				var m := -1.0 if s == 0 else 1.0
				var tgt := Vector3(m * 0.055, 0.075 + tr, -_d.vy * 0.135)
				_req_c(s, tgt, _hand_q(Vector3(-m * 0.4, 0.82, -0.05), Vector3(-m * 0.15, 0.1, 1.0), m), Vector3(m * 0.8, -0.6, 0.2), still)
				_curl[s] = lerpf(_curl[s], 0.62, still)
				_idx[s] = lerpf(_idx[s], 0.62, still)
		var run_w := pw * _ss(1.5, 3.0, _spd)
		if run_w > 0.001:
			var wob := sin(_t * 13.0)
			for s in 2:
				var m := -1.0 if s == 0 else 1.0
				_e[UARM_L + s * AS] += run_w * Vector3(0.34 + 0.14 * wob * m, 0, m * 0.26)
				_e[FARM_L + s * AS] += run_w * Vector3(-0.3, 0, 0)
				_curl[s] = lerpf(_curl[s], 0.2, run_w)
				_idx[s] = lerpf(_idx[s], 0.15, run_w)
			# a look back over the shoulder every few seconds
			var gl := _ss(0.72, 0.92, sin(_t * 1.35))
			_e[NECK] += run_w * Vector3(0, 0.55 * gl, 0)
			_e[HEAD] += run_w * Vector3(0, 0.55 * gl, 0)


func _layer_hold(dt: float) -> void:
	var L := (_d.uarm + _d.farm) / 0.54
	for s in 2:
		var want := 1.0 if _held[s] != null else 0.0
		_hold_w[s] = ModelKit.damp(_hold_w[s], want, 6.0, dt)
		var w := _hold_w[s]
		if w < 0.001 or _hold_kind[s] == 0:
			continue
		var m := -1.0 if s == 0 else 1.0
		var sh := _sh_c(s)
		var lying := _pw[P_LIE]
		w *= 1.0 - lying
		match _hold_kind[s]:
			2:
				var tgt := Vector3(sh.x + m * 0.05, sh.y - (_d.uarm + _d.farm) * 0.985, sh.z + 0.012)
				_req_c(s, tgt, _chest_q.inverse() * _hand_q(Vector3.DOWN, Vector3(-m, 0, 0), m), Vector3(m * 0.25, 0.0, 1.0), w)
			3:
				var tgt := Vector3(sh.x - m * 0.15 * L, sh.y - 0.32 * L, sh.z - 0.2 * L)
				_req_c(s, tgt, _chest_q.inverse() * _front_hand_q(s), Vector3(m * 0.8, -0.4, 0.9), w)
			_:
				var tgt := Vector3(sh.x - m * 0.0, sh.y - 0.31 * L, sh.z - 0.3 * L)
				_req_c(s, tgt, _chest_q.inverse() * _front_hand_q(s), Vector3(m * 0.5, -0.5, 1.0), w)
		_curl[s] = lerpf(_curl[s], _hold_curl[s], w)
		_idx[s] = lerpf(_idx[s], _hold_curl[s], w)
		_thumb[s] = lerpf(_thumb[s], 0.65, w)


func _layer_talk(dt: float) -> void:
	_beat_age += dt
	_beat_t -= dt
	if _talk < 0.01:
		return
	var talk := _talk
	var syl := maxf(0.0, sin(_t * 12.5) * 0.5 + 0.5 + sin(_t * 7.7 + 1.0) * 0.35)
	var pause := _ss(-0.65, -0.1, sin(_t * 1.13) + sin(_t * 0.71 + 2.0) * 0.5)
	var lv := talk * syl * pause
	_jaw_add += lv * 0.17
	_e[HEAD] += talk * Vector3(0.014 * sin(_t * 6.3) + 0.012 * sin(_t * 3.1), 0.012 * sin(_t * 2.3), 0.014 * sin(_t * 1.7))
	_e[NECK] += talk * Vector3(0.01 * sin(_t * 3.7), 0, 0)
	if _beat_t <= 0.0 and _g_id == G_NONE:
		_beat_t = _rng.randf_range(2.0, 4.6)
		_beat_age = 0.0
		_beat_side = 1 if _rng.randf() < 0.64 else 0
	var e := ModelKit.env(_beat_age, 0.0, 0.42, 1.25, 1.9) * talk * (1.0 - _pw[P_LIE]) * (1.0 - _panic_w)
	if e > 0.001 and _pw[P_COWER] < 0.3:
		var L := (_d.uarm + _d.farm) / 0.54
		var beat := 0.012 * sin(_beat_age * 8.0) * L
		for s in 2:
			if s != _beat_side or _held[s] != null:
				continue
			var m := -1.0 if s == 0 else 1.0
			var sh := _sh_c(s)
			var tgt := Vector3(sh.x + m * 0.02 * L, sh.y - 0.27 * L + beat, sh.z - 0.27 * L)
			_req_c(s, tgt, _hand_q(Vector3(m * 0.22, 0.2, -0.95), Vector3(-m * 0.5, 0.86, 0.0), m), Vector3(m * 0.55, -0.55, 1.0), e)
			_curl[s] = lerpf(_curl[s], 0.2, e)
			_idx[s] = lerpf(_idx[s], 0.12, e)
			_thumb[s] = lerpf(_thumb[s], 0.1, e)


func _layer_gesture(dt: float) -> void:
	_g_t += dt
	if _g_t >= _g_dur:
		_end_gesture()
		return
	var t := _g_t
	var dur := _g_dur
	var w := ModelKit.env(t, 0.0, 0.32, dur - 0.4, dur)
	var L := (_d.uarm + _d.farm) / 0.54
	var sh_r := _sh_c(1)
	var sh_l := _sh_c(0)
	match _g_id:
		G_WAVE:
			var osc := sin((t - 0.35) * 9.0) * ModelKit.env(t, 0.32, 0.55, dur - 0.6, dur - 0.3)
			var tgt := sh_r + Vector3(0.17 + 0.05 * osc, 0.27, -0.09) * L
			var palm := Vector3(0.25 * osc, 0.0, -1.0)
			_req_c(1, tgt, _hand_q(Vector3(0.25 * osc, 1.0, -0.05), palm, 1.0), Vector3(0.9, -0.5, 0.45), w)
			_curl[1] = lerpf(_curl[1], 0.04, w)
			_idx[1] = lerpf(_idx[1], 0.02, w)
			_thumb[1] = lerpf(_thumb[1], 0.0, w)
			_e[CLAV_R] += w * Vector3(0, 0, 0.09)
			_e[HEAD] += w * Vector3(0.02, 0.03, -0.05)
			_e[CHEST] += w * Vector3(0, 0, -0.03)
			_face_h = maxf(_face_h, w)
		G_POINT:
			var dir := Vector3(0, 0.1, -1.0).normalized()
			if _look_on:
				var lp := _rig.global_transform.affine_inverse() * _look_world
				var dd := _chest_q.inverse() * (lp - (_chest_p + _chest_q * sh_r))
				if dd.length_squared() > 0.01:
					dir = dd.normalized()
					if dir.z > -0.1:
						dir = Vector3(dir.x, dir.y, -0.1).normalized()
			var tgt := sh_r + dir * 0.53 * L
			var fing := dir
			var palm := Vector3(-0.6, -0.8, 0.0)
			_req_c(1, tgt, _hand_q(fing, palm, 1.0), Vector3(0.9, -0.7, 0.2), w)
			_curl[1] = lerpf(_curl[1], 1.0, w)
			_idx[1] = lerpf(_idx[1], 0.0, w)
			_thumb[1] = lerpf(_thumb[1], 0.85, w)
			_e[CHEST] += w * Vector3(0, -0.06, 0)
			_e[CLAV_R] += w * Vector3(0, -0.07, 0.03)
		G_NOD:
			var k := sin(t / dur * TAU * 2.0)
			_e[HEAD] += w * Vector3(-0.17 * maxf(k, -0.3) - 0.03, 0, 0)
			_e[NECK] += w * Vector3(-0.08 * maxf(k, -0.3), 0, 0)
		G_SHRUG:
			var k := ModelKit.env(t, 0.1, 0.5, dur - 0.65, dur - 0.1)
			for s in 2:
				var m := -1.0 if s == 0 else 1.0
				var sh := sh_r if s == 1 else sh_l
				var tgt := sh + Vector3(m * 0.14, -0.3, -0.2) * L
				_req_c(s, tgt, _hand_q(Vector3(m * 0.55, 0.12, -0.82), Vector3(m * 0.18, 1.0, 0.1), m), Vector3(m * 0.95, -0.35, 0.65), w)
				_curl[s] = lerpf(_curl[s], 0.12, w)
				_idx[s] = lerpf(_idx[s], 0.08, w)
				_thumb[s] = lerpf(_thumb[s], 0.05, w)
				_e[CLAV_L + s * AS] += k * Vector3(0, 0, m * 0.2)
			_e[HEAD] += k * Vector3(0.02, 0, 0.12)
			_face_w = maxf(_face_w, k * 0.55)
		G_HUG:
			for s in 2:
				var m := -1.0 if s == 0 else 1.0
				var tgt := Vector3(-m * 0.12 * L, sh_r.y - 0.1 * L - float(s) * 0.03, -0.128 * _d.vy - float(s) * 0.012)
				var fing := Vector3(-m * 0.9, 0.35, 0.12)
				_req_c(s, tgt, _hand_q(fing, Vector3(0, -0.15, 1.0), m), Vector3(m * 0.85, -0.75, 0.05), w)
				_curl[s] = lerpf(_curl[s], 0.42, w)
				_idx[s] = lerpf(_idx[s], 0.42, w)
				_e[CLAV_L + s * AS] += w * Vector3(0, m * 0.13, m * 0.08)
			_e[SPINE] += w * Vector3(-0.08, 0, 0)
			_e[CHEST] += w * Vector3(-0.07, 0, 0)
			_e[HEAD] += w * Vector3(-0.15, 0, 0.05)
			_face_w = maxf(_face_w, w)
		G_BECKON:
			var osc := 0.5 + 0.5 * sin((t - 0.3) * TAU * 2.2)
			var tgt := sh_r + Vector3(0.05, -0.22, -0.31) * L
			_req_c(1, tgt, _hand_q(Vector3(-0.12, 0.28, -0.95), Vector3(-0.15, 1.0, 0.2), 1.0), Vector3(0.65, -0.6, 0.85), w)
			var c := lerpf(0.05, 1.05, osc)
			_curl[1] = lerpf(_curl[1], c, w)
			_idx[1] = lerpf(_idx[1], c, w)
			_thumb[1] = lerpf(_thumb[1], 0.3, w)
			_e[HEAD] += w * Vector3(0.03, 0.05, -0.08)
			_e[CHEST] += w * Vector3(-0.02, 0, 0)
			_face_h = maxf(_face_h, w)
		G_LAUGH:
			var k := ModelKit.env(t, 0.05, 0.3, dur - 0.5, dur)
			var bounce := sin(t * TAU * 3.2)
			_e[HEAD] += k * Vector3(0.2 * sin(t / dur * PI) + 0.022 * bounce, 0, 0.05)
			_e[NECK] += k * Vector3(0.05, 0, 0)
			_e[SPINE] += k * Vector3(0.05 * sin(t / dur * PI) - 0.015 * bounce, 0, 0)
			for s in 2:
				var m := -1.0 if s == 0 else 1.0
				_e[CLAV_L + s * AS] += k * Vector3(0, 0, m * (0.05 + 0.04 * bounce))
			if _held[1] == null:
				var tgt := Vector3(0.05 * L, sh_r.y - 0.44 * L, -0.17 * _d.vy)
				_req_c(1, tgt, _hand_q(Vector3(-0.8, -0.3, -0.25), Vector3(-0.15, 0.1, 1.0), 1.0), Vector3(0.9, -0.5, 0.3), k * 0.8)
				_curl[1] = lerpf(_curl[1], 0.4, k)
			_jaw_add += k * (0.12 + 0.07 * maxf(bounce, 0.0))
			_face_h = maxf(_face_h, k)
		G_SIP:
			var s := _g_side
			var m := -1.0 if s == 0 else 1.0
			var k := ModelKit.env(t, 0.1, 0.85, 1.65, 2.5)
			var ht := _rl[NECK] + _rl[HEAD]
			var mouth := ht + Vector3(0, -0.005, -0.12) * _d.hs
			var grip := Vector3(-m * 0.05, 0.0, 0.0) + Vector3(0, -0.038, 0.026)
			_req_c(s, mouth + grip, _chest_q.inverse() * _front_hand_q(s), Vector3(m * 0.85, -0.7, 0.35), k)
			_e[HEAD] += k * Vector3(0.14, 0, 0)
		G_GASP:
			var k := ModelKit.env(t, 0.03, 0.2, dur - 0.5, dur)
			var ht := _rl[NECK] + _rl[HEAD]
			for s in 2:
				var m := -1.0 if s == 0 else 1.0
				var tgt := ht + Vector3(m * 0.038, -0.058, -0.145) * _d.hs
				_req_c(s, tgt, _hand_q(Vector3(-m * 0.3, 0.92, -0.2), Vector3(-m * 0.2, 0.1, 1.0), m), Vector3(m * 0.75, -0.75, 0.25), k)
				_curl[s] = lerpf(_curl[s], 0.3, k)
				_idx[s] = lerpf(_idx[s], 0.25, k)
				_e[CLAV_L + s * AS] += k * Vector3(0, m * 0.08, m * 0.08)
			_e[HEAD] += k * Vector3(0.05, 0, 0)
			_e[CHEST] += k * Vector3(0.05, 0, 0)
			_face_s = maxf(_face_s, k)
			_jaw_add += k * 0.13
		G_SHAKE:
			var osc := sin(t * TAU * 2.4)
			_e[HEAD] += w * Vector3(-0.03, 0.26 * osc, 0)
			_e[NECK] += w * Vector3(0, 0.1 * osc, 0)
			_face_w = maxf(_face_w, w * 0.5)


func _layer_look(dt: float, look_rig: Vector3) -> void:
	var yaw := 0.0
	var pitch := 0.0
	if _look_w > 0.001:
		var eye := _hips_p + _hips_q * Vector3(0, _d.head_y - _d.hips_y + 0.07 * _d.hs, -0.06)
		var dir := _hips_q.inverse() * (look_rig - eye)
		yaw = atan2(-dir.x, -dir.z)
		pitch = atan2(dir.y, Vector2(dir.x, dir.z).length())
		# out of reach behind them: don't strain, ease back toward the front
		if absf(yaw) > 2.3:
			yaw *= 1.0 - _ss(2.3, 2.9, absf(yaw))
		yaw = clampf(yaw, -1.2, 1.2) * _look_w
		pitch = clampf(pitch, -0.7, 0.55) * _look_w
	var g := (1.0 - 0.72 * _look_w) * (1.0 - _spd * 0.25 if _spd < 4.0 else 0.0)
	var ty := yaw + _glance.x * g
	var tp := pitch + _glance.y * g
	_head_yaw = ModelKit.damp(_head_yaw, ty, 5.0, dt)
	_head_pitch = ModelKit.damp(_head_pitch, tp, 5.0, dt)
	_e[CHEST] += Vector3(0.05 * _head_pitch, 0.17 * _head_yaw, 0)
	_e[NECK] += Vector3(0.38 * _head_pitch, 0.34 * _head_yaw, 0)
	_e[HEAD] += Vector3(0.57 * _head_pitch, 0.49 * _head_yaw, -0.03 * _head_yaw)


func _solve(dt: float) -> void:
	var d := _d
	# torso chain
	var qh := Quaternion.from_euler(_e[HIPS])
	var ph := _hp
	_q[HIPS] = qh
	var ql := Quaternion.from_euler(_e[SPINE])
	_q[SPINE] = ql
	var qs := qh * ql
	var ps := ph + qh * _rl[SPINE]
	ql = Quaternion.from_euler(_e[CHEST])
	_q[CHEST] = ql
	var qc := qs * ql
	var pc := ps + qs * _rl[CHEST]
	ql = Quaternion.from_euler(_e[NECK])
	_q[NECK] = ql
	var qn := qc * ql
	var pn := pc + qc * _rl[NECK]
	ql = Quaternion.from_euler(_e[HEAD])
	_q[HEAD] = ql
	_head_q = qn * ql
	_head_p = pn + qn * _rl[HEAD]
	_hips_q = qh
	_hips_p = ph
	_chest_q = qc
	_chest_p = pc
	# legs
	var leg_w := clampf(_ft_w, 0.0, 1.0)
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var o := s * LS
		var th := THIGH_L + o
		var q_t := Quaternion.from_euler(_e[th])
		var q_k := Quaternion.from_euler(_e[th + 1])
		var q_f := Quaternion.from_euler(_e[th + 2])
		if leg_w > 0.001:
			var tgt := _ft[s] / maxf(_ft_w, 0.001)
			var pitch := _ftp[s] / maxf(_ft_w, 0.001)
			var hj := ph + qh * _rl[th]
			var pole := qh * Vector3(m * 0.1, 0.0, -1.0)
			_ik(hj, tgt, pole, d.thigh, d.shin, true)
			var qg := _ik_q1 * _ik_q2
			var foot := Quaternion(Vector3.UP, -m * 0.17) * Quaternion(Vector3.RIGHT, pitch)
			q_t = q_t.slerp(qh.inverse() * _ik_q1, leg_w)
			q_k = q_k.slerp(_ik_q2, leg_w)
			q_f = q_f.slerp(qg.inverse() * foot, leg_w)
		_q[th] = q_t
		_q[th + 1] = q_k
		_q[th + 2] = q_f
	# skirt panels follow whichever thigh is pushing them
	var vl: Vector3 = _q[THIGH_L] * Vector3.DOWN
	var vr: Vector3 = _q[THIGH_R] * Vector3.DOWN
	var pl := atan2(-vl.z, -vl.y)
	var pr := atan2(-vr.z, -vr.y)
	var pmax := maxf(pl, pr)
	var pmin := minf(pl, pr)
	# both thighs forward = sitting: the skirt lies over the lap and narrows. Mid-stride it only swings.
	var both := _ss(0.5, 1.2, pmin)
	_q[SK_F] = Quaternion(Vector3.RIGHT, clampf(pmax, -0.2, 2.3) * lerpf(0.58, 0.94, both))
	_q[SK_B] = Quaternion(Vector3.RIGHT, clampf(pmin, -1.0, 1.6) * lerpf(0.82, 0.62, both))
	_skirt_x = lerpf(1.0, 0.56, both)
	# arms
	for s in 2:
		var m := -1.0 if s == 0 else 1.0
		var o := s * AS
		var q_cl := Quaternion.from_euler(_e[CLAV_L + o])
		_q[CLAV_L + o] = q_cl
		var qcg := qc * q_cl
		var pcl := pc + qc * _rl[CLAV_L + o]
		var q_u := Quaternion.from_euler(_e[UARM_L + o])
		var q_e := Quaternion.from_euler(_e[FARM_L + o])
		var q_w := Quaternion.from_euler(_e[HAND_L + o])
		var w := _ik_w[s]
		if w > 0.001:
			var sh := pcl + qcg * _rl[UARM_L + o]
			_ik(sh, _ik_p[s], _ik_pole[s], d.uarm, d.farm, false)
			var fg := _ik_q1 * _ik_q2
			q_u = q_u.slerp(qcg.inverse() * _ik_q1, w)
			q_e = q_e.slerp(_ik_q2, w)
			q_w = q_w.slerp(fg.inverse() * _ik_h[s], w)
		_q[UARM_L + o] = q_u
		_q[FARM_L + o] = q_e
		_q[HAND_L + o] = q_w
		# fingers
		var c := _curl[s]
		var i_c := _idx[s]
		_q[FING_L + o] = Quaternion(Vector3.BACK, -m * c * 1.2)
		_q[FING2_L + o] = Quaternion(Vector3.BACK, -m * c * 1.35)
		_q[INDEX_L + o] = Quaternion(Vector3.BACK, -m * i_c * 1.2)
		_q[INDEX2_L + o] = Quaternion(Vector3.BACK, -m * i_c * 1.35)
		_q[THUMB_L + o] = Quaternion.from_euler(Vector3(-0.15 * _thumb[s], m * 0.8 * _thumb[s], -m * 0.3 * _thumb[s]))
	# ponytail: a damped spring that lags behind the head
	if hair_style == "ponytail" and hat == "none":
		var hv := (ph - _prev_hp) / maxf(dt, 0.001)
		_prev_hp = ph
		var tgt := Vector2(-hv.z * 0.07 - _spd * 0.05 / _rs, hv.x * 0.1)
		tgt.x += 0.035 * sin(_t * 1.1)
		var acc := (tgt - _pony_a) * 55.0 - _pony_v * 7.0
		_pony_v += acc * dt
		_pony_a += _pony_v * dt
		_pony_a = _pony_a.clamp(Vector2(-0.5, -0.45), Vector2(0.5, 0.45))
		_q[PONY] = Quaternion.from_euler(Vector3(_pony_a.x, 0, _pony_a.y))


func _update_face(dt: float, look_rig: Vector3) -> void:
	var d := _d
	# expression blend
	for k in E_N:
		_ew[k] = ModelKit.damp(_ew[k], 1.0 if k == _ex_id else 0.0, 5.0, dt)
	var happy := maxf(_ew[E_HAPPY], _face_h)
	var worried := maxf(_ew[E_WORRIED], _face_w)
	var scared := maxf(_ew[E_SCARED], _face_s)
	var sad := _ew[E_SAD]
	var total := happy + worried + scared + sad
	if total > 1.0:
		happy /= total
		worried /= total
		scared /= total
		sad /= total
	# jaw
	var tj := _jaw_add + scared * 0.075
	_jaw = ModelKit.damp(_jaw, tj, 24.0, dt)
	_q[JAW] = Quaternion(Vector3.RIGHT, -_jaw)
	# eyes
	var hq_inv := _head_q.inverse()
	var eye_y := _sacc.x + clampf(_glance.x * 0.6, -0.3, 0.3)
	var eye_p := _sacc.y + _glance.y * 0.5
	var tgt_y := 0.0
	var tgt_p := 0.0
	if _look_w > 0.001:
		var eye_mid := _head_p + _head_q * Vector3(0, d.eye.y, d.eye.z) * d.hs
		var dir := hq_inv * (look_rig - eye_mid)
		tgt_y = atan2(-dir.x, -dir.z)
		tgt_p = atan2(dir.y, Vector2(dir.x, dir.z).length())
		if absf(tgt_y) > 2.2:
			tgt_y = 0.0
		tgt_y = clampf(tgt_y, -0.5, 0.5) + _sacc.x * 0.25
		tgt_p = clampf(tgt_p, -0.38, 0.32) + _sacc.y * 0.3
		eye_y = lerpf(eye_y, tgt_y, _look_w)
		eye_p = lerpf(eye_p, tgt_p, _look_w)
	_eye_y = ModelKit.damp(_eye_y, eye_y, 26.0, dt)
	_eye_p = ModelKit.damp(_eye_p, eye_p, 26.0, dt)
	# converge slightly on close targets by a small yaw offset per eye
	for s in 2:
		_q[EYE_L + s] = Quaternion.from_euler(Vector3(_eye_p, _eye_y, 0))
	# lids
	var bl := sin(clampf(_blink, 0.0, 1.0) * PI)
	var sip_close := 0.0
	if _g_id == G_SIP:
		sip_close = ModelKit.env(_g_t, 0.7, 1.0, 1.6, 2.0) * 0.55
	var up := 0.08 * worried + 0.26 * scared - 0.2 * sad - 0.13 * happy + 0.42 * _eye_p
	up = lerpf(up, -1.02, clampf(bl + sip_close, 0.0, 1.0))
	var low := 0.24 * happy + 0.07 * worried - 0.09 * scared + 0.06 * sad + 0.22 * _eye_p
	for s in 2:
		_q[LID_L + s] = Quaternion(Vector3.RIGHT, up)
		_q[LLID_L + s] = Quaternion(Vector3.RIGHT, low + bl * 0.1)
	# brows and mouth corners (positions are applied in _push)
	_br_y = 0.0022 * happy + 0.0026 * worried + 0.0062 * scared - 0.0012 * sad
	_br_r = 0.42 * worried + 0.26 * scared + 0.5 * sad - 0.05 * happy
	_mc = Vector3(0.0022 * happy - 0.0006 * worried + 0.0018 * scared - 0.0008 * sad,
		0.0085 * happy - 0.0034 * worried - 0.0024 * scared - 0.0052 * sad,
		0.0026 * happy)
	_ul_y = 0.0024 * clampf(_jaw * 7.0, 0.0, 1.0) + 0.001 * happy


var _skirt_x := 1.0
var _has_skirt := false
var _br_y := 0.0
var _br_r := 0.0
var _mc := Vector3.ZERO
var _ul_y := 0.0


func _push(face: bool) -> void:
	var sk := _skel
	sk.set_bone_pose_position(HIPS, _hp)
	if _has_skirt:
		var sc := Vector3(_skirt_x, 1.0, 1.0)
		sk.set_bone_pose_scale(SK_F, sc)
		sk.set_bone_pose_scale(SK_B, sc)
	var q := _q
	for i in NB:
		if i >= JAW and i <= ULIP and not face:
			continue
		sk.set_bone_pose_rotation(i, q[i])
	if face:
		var hs := _d.hs
		for s in 2:
			var m := -1.0 if s == 0 else 1.0
			sk.set_bone_pose_position(BROW_L + s, _rl[BROW_L + s] + Vector3(0, _br_y, 0) * hs)
			sk.set_bone_pose_rotation(BROW_L + s, Quaternion(Vector3.BACK, -m * _br_r))
			sk.set_bone_pose_position(MC_L + s, _rl[MC_L + s] + Vector3(m * _mc.x, _mc.y, _mc.z) * hs)
		sk.set_bone_pose_position(ULIP, _rl[ULIP] + Vector3(0, _ul_y, 0) * hs)
