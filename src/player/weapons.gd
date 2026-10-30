extends Node3D
## Weapon viewmodels + hitscan shooting: recoil, sway, ADS, reloads, muzzle flash, shells, tracers, impacts.

signal ammo_changed(weapon: String, mag: int, reserve: int)
signal fired
signal hit_confirmed(killed: bool)

const DEFS := {
	"pistol": {
		"name": "Service Pistol", "mag": 8, "dmg": 34.0, "cooldown": 0.17, "reload": 1.55, "ammo": "ammo_38",
		"spread_hip": 2.2, "spread_ads": 0.35, "kick": 0.045, "sound": "pistol_fire",
		"hip": Vector3(0.19, -0.13, -0.62), "ads": Vector3(0.0, -0.066, -0.5), "hip_rot": Vector3(0.06, 0.48, 0.12), "ads_fov": 0.82,
	},
	"rifle": {
		"name": "Bolt-Action Rifle", "mag": 5, "dmg": 95.0, "cooldown": 1.05, "reload": 0.55, "ammo": "ammo_30",
		"spread_hip": 3.0, "spread_ads": 0.05, "kick": 0.11, "sound": "rifle_fire",
		"hip": Vector3(0.16, -0.16, -0.6), "ads": Vector3(0.0, -0.098, -0.42), "hip_rot": Vector3(0.0, 0.16, 0.08), "ads_fov": 0.4,
	},
}

const ViewArm := preload("res://src/player/view_arm.gd")

## First-person hands, per weapon, in rig space. A hand pose is the wrist position, the direction the
## fingers point, the direction the back of the hand faces, and finger curls (ViewArm.apply_pose layout:
## 4 x [spread, mcp, pip, dip] index..little, then thumb [cmc_flex, cmc_swing, cmc_roll, mcp, ip]).
## "elbow_*" are camera-space points below the screen (hip, ADS) that the forearms swing toward, so the
## arms always leave through the bottom edge whatever the gun is doing.
const HANDS := {
	"pistol": {
		"r": {"pos": Vector3(0.0204, -0.0278, 0.0896), "fwd": Vector3(0.15, 0, -1), "up": Vector3(1, 0, 0.15),
			"curl": [5, 12, 25, 10, 0, 26, 50, 35, 0, 19, 59, 28, 0, 7, 45, 22, 21, 40, 70, 52, 29]},
		"l": {"pos": Vector3(-0.0771, -0.0446, 0.0622), "fwd": Vector3(0.5, -0.1, -1), "up": Vector3(-1, 0, -0.5),
			"curl": [3, -5, 55, 40, 0, -5, 62, 35, 0, -5, 58, 40, -3, -5, 50, 40, 3, -18, -45, -10, -10]},
		"l_mag": {"pos": Vector3(-0.0166, -0.0922, 0.0536), "fwd": Vector3(0.4, 0.1, -1), "up": Vector3(0, -1, 0),
			"curl": [4, 12, 18, 10, 0, 12, 20, 10, -4, 14, 22, 12, -8, 16, 24, 14, 10, 10, 0, 8, 6]},
		"elbow_r": [Vector3(0.32, -0.42, 0.02), Vector3(0.22, -0.4, 0.06)],
		"elbow_l": [Vector3(-0.06, -0.44, 0.0), Vector3(-0.2, -0.4, 0.06)],
	},
	"rifle": {
		"r": {"pos": Vector3(0.0535, 0.055, 0.4757), "fwd": Vector3(-0.3, -0.7, -0.65), "up": Vector3(1, 0.2, 0.05),
			"curl": [-15, -8, 38, 60, -5, 11, 62, 49, -5, 10, 50, 24, -5, -8, 35, 20, 8, -4, 70, -10, 18]},
		"l": {"pos": Vector3(-0.0687, -0.018, 0.0975), "fwd": Vector3(0.75, 0.15, -0.65), "up": Vector3(-0.2, -1, 0),
			"curl": [-10, -5, 40, 40, -5, -4, 71, 33, 1, 7, 75, 10, -5, 15, 63, 17, 4, -23, 48, -10, -10]},
		"r_bolt": {"pos": Vector3(0.0833, -0.0786, 0.262), "fwd": Vector3(-0.517, 0.75, -0.413), "up": Vector3(0.215, -0.353, -0.911),
			"curl": [0, 30, 75, 40, 0, 55, 90, 50, 0, 65, 95, 50, 0, 70, 95, 50, 25, 15, 0, 20, 15]},
		"r_load": {"pos": Vector3(0.0903, 0.0006, 0.2894), "fwd": Vector3(-0.119, 0.226, -0.967), "up": Vector3(0.988, -0.067, -0.137),
			"curl": [0, 35, 50, 30, 0, 45, 65, 40, 0, 50, 75, 45, 0, 55, 80, 45, 20, 20, 0, 0, 5]},
		"elbow_r": [Vector3(0.34, -0.32, 0.06), Vector3(0.26, -0.3, 0.08)],
		"elbow_l": [Vector3(-0.1, -0.46, -0.02), Vector3(-0.14, -0.42, 0.0)],
	},
}
const RELAXED := [8, 15, 20, 10, 2, 18, 24, 12, -4, 20, 26, 12, -10, 22, 28, 14, 10, 5, 0, 10, 10]

var player: Node3D
var current := ""
var mags := {"pistol": 8, "rifle": 5}
var rigs := {}
var _rig: Node3D
var _slide: Node3D
var _bolt: Node3D
var _cool := 0.0
var _reloading := false
var _aim := 0.0
var _switching := false
var _recoil := 0.0
var _recoil_rot := 0.0
var _sway := Vector2.ZERO
var _bob_t := 0.0
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _decals: Array = []
static var _hole_tex: ImageTexture
var lowered := false  # true in safe areas (cozy home)
# first-person arms of the drawn weapon, their poses (see HANDS) and animation blends
var arms := {}  # weapon -> {r, l: ViewArm, xf_*: Transform3D, c_*: PackedFloat32Array, e_*: elbow points}
var _arm_r: ViewArm
var _arm_l: ViewArm
var _buf_r := PackedFloat32Array()
var _buf_l := PackedFloat32Array()
var _anim_rot := Vector3.ZERO  # extra rig rotation / offset for reloads and bolt work, added in _process
var _anim_pos := Vector3.ZERO
const BOLT_TILT := Vector3(0.05, -0.12, 0.32)  # rig tilt while working the bolt (action turned toward the eye)
const BOLT_SHIFT := Vector3(-0.05, 0.04, 0.0)
const RELOAD_TILT := Vector3(0.12, -0.1, 0.75)  # rifle: open action turned up toward the eye while loading
const RELOAD_SHIFT := Vector3(-0.05, 0.07, 0.0)
var _bolt_b: Node3D
var _bolt_rest := Transform3D.IDENTITY  # bolt parts' rest transforms (holder space) and the holder itself
var _bolt_b_rest := Transform3D.IDENTITY
var _holder_xf := Transform3D.IDENTITY
const BOLT_AXIS := Vector3(0, 0.052, 0)  # a point on the rifle bore (rig space); the bolt turns about it
const BOLT_TRAVEL := 0.07
const BOLT_TURN := 1.05  # handle lift, radians
const BOLT_KNOB := Vector3(0.038, 0.022, 0.276)  # bolt handle knob at rest (rig space)
var _bolt_open := 0.0  # 0 = closed, 1 = pulled back
var _bolt_lift := 0.0  # 0 = handle down, 1 = handle up
var _r_bolt := 0.0  # right hand: grip -> bolt handle
var _r_load := 0.0  # right hand: bolt handle -> thumb over the open action
var _r_push := 0.0  # thumb pressing a round down
var _r_away := 0.0  # right hand off screen (fetching a round)
var _l_mag := 0.0  # left hand: support -> palm under the magazine well
var _l_away := 0.0  # left hand off screen (fetching a magazine)
var _trigger := 0.0  # index finger squeeze


const DEPTH_SQUASH := 0.55  # compress viewmodels along the view axis = narrower apparent FOV


func setup(p: Node3D) -> void:
	player = p
	# the viewmodel (gun + arms) lives on its own render layer so the shoulder flashlight, which sits
	# right beside the hands, doesn't blow them out; every other light still reaches it
	if p is Player and (p as Player).flashlight:
		(p as Player).flashlight.light_cull_mask &= ~Player.VM_LAYER
	position = Vector3.ZERO
	scale = Vector3(1, 1, DEPTH_SQUASH)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.45)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 7.0
	_flash_light.shadow_enabled = false
	add_child(_flash_light)
	_flash_mesh = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	_flash_mesh.mesh = qm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_texture = _star_texture()
	fm.albedo_color = Color(1.0, 0.8, 0.5)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_mesh.material_override = fm
	_flash_mesh.visible = false
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash_mesh)


func has_weapon(w: String) -> bool:
	return Game.count(w) > 0


func is_aiming() -> bool:
	return _aim > 0.5 and current != ""


func equip(w: String) -> void:
	if w == current or _switching or not has_weapon(w):
		return
	_switching = true
	if _rig != null:
		var old := _rig
		var tw := create_tween()
		tw.tween_property(old, "position:y", old.position.y - 0.35, 0.18)
		await tw.finished
		old.visible = false
	current = w
	if not rigs.has(w):
		rigs[w] = _build_rig(w)
	_rig = rigs[w]
	_rig.visible = true
	_use_arms(w)
	var d: Dictionary = DEFS[w]
	_rig.position = d.hip + Vector3(0, -0.35, 0)
	Audio.sfx("pistol_slide" if w == "pistol" else "rifle_bolt_close", -8.0)
	var tw2 := create_tween()
	tw2.tween_property(_rig, "position", d.hip, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_switching = false
	_emit_ammo()


func holster() -> void:
	if _rig == null:
		return
	var tw := create_tween()
	tw.tween_property(_rig, "position:y", _rig.position.y - 0.35, 0.18)
	await tw.finished
	_rig.visible = false
	_rig = null
	current = ""
	_emit_ammo()


func _emit_ammo() -> void:
	if current == "":
		ammo_changed.emit("", 0, 0)
	else:
		ammo_changed.emit(current, mags[current], Game.count(DEFS[current].ammo))


# ------------------------------------------------------------------ rigs

func _build_rig(w: String) -> Node3D:
	var rig := Node3D.new()
	rig.name = w
	add_child(rig)
	var holder := Node3D.new()
	rig.add_child(holder)
	if w == "pistol":
		var scene: PackedScene = load(Props.path("service_pistol"))
		var inst := scene.instantiate()
		for n in ["service_pistol_pistol_a", "service_pistol_slide_a", "service_pistol_hammer_a", "service_pistol_trigger_a"]:
			var src: Node3D = inst.find_child(n, true, false)
			if src:
				var dup: Node3D = src.duplicate()
				dup.transform = _rel(inst, src)
				holder.add_child(dup)
				if n.ends_with("slide_a"):
					_slide = dup
		inst.free()
		# barrel points +X in the source; rotate so it points -Z, centre the grip
		holder.rotation_degrees = Vector3(0, 90, 0)
		holder.position = Vector3(0, -0.02, 0.0)
		holder.scale = Vector3.ONE * 1.0
	else:
		var scene2: PackedScene = load(Props.path("bolt_action_rifle_7_62"))
		var inst2 := scene2.instantiate()
		for n in ["bolt_action_rifle_7_62", "bolt_action_rifle_7_62_scope", "bolt_action_rifle_7_62_bolt_a", "bolt_action_rifle_7_62_bolt_b", "bolt_action_rifle_7_62_trigger", "bolt_action_rifle_7_62_wrap"]:
			var src2: Node3D = inst2.find_child(n, true, false)
			if src2:
				var dup2: Node3D = src2.duplicate()
				dup2.transform = _rel(inst2, src2)
				holder.add_child(dup2)
				if n.ends_with("bolt_a"):
					_bolt = dup2
					_bolt_rest = dup2.transform
				elif n.ends_with("bolt_b"):
					_bolt_b = dup2
					_bolt_b_rest = dup2.transform
		inst2.free()
		holder.rotation_degrees = Vector3(0, 90, 0)
		holder.position = Vector3(0, 0.0, 0.05)
		_holder_xf = holder.transform
	for m in rig.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(m as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		(m as GeometryInstance3D).layers = Player.VM_LAYER
	_add_arms(rig, w)
	rig.set_meta("muzzle", Vector3(0, 0.03, -0.2) if w == "pistol" else Vector3(0, 0.03, -0.75))
	return rig


# ------------------------------------------------------------------ arms

static func _skin_mat() -> Material:
	if ModelKit.has_mat("vm_skin"):
		return ModelKit.get_mat("vm_skin")
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.8, 0.58, 0.47)
	m.roughness = 0.6
	m.metallic_specular = 0.42
	m.roughness_texture = ModelKit.noise_tex("vm_skin_rough", 0.08, ModelKit.grad([Color(0.7, 0.7, 0.7), Color(1, 1, 1)], [0.0, 1.0]), false, 4.0, 128, 4, 11)
	m.normal_enabled = true
	m.normal_texture = ModelKit.noise_tex("vm_skin_n", 0.25, null, true, 1.0, 128, 3, 12)
	m.normal_scale = 0.15
	m.uv1_scale = Vector3(3, 6, 1)
	# skin: screen-space subsurface scattering plus a little back-light so thin fingers glow red against a light
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.35
	m.subsurf_scatter_skin_mode = true
	m.backlight_enabled = true
	m.backlight = Color(0.25, 0.07, 0.04)
	return ModelKit.put_mat("vm_skin", m)


static func _knit_mat() -> Material:
	if ModelKit.has_mat("vm_knit"):
		return ModelKit.get_mat("vm_knit")
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.31, 0.26)
	m.roughness = 0.95
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.albedo_texture = ModelKit.noise_tex("fabric_mottle", 0.03, ModelKit.grad([Color(0.78, 0.78, 0.78), Color(1, 1, 1)], [0.0, 1.0]))
	var n := ModelKit.load_tex("res://assets/textures/fabric_pattern_05/fabric_pattern_05_nor_gl.jpg")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 1.0
	m.uv1_scale = Vector3(5, 3, 1)
	return ModelKit.put_mat("vm_knit", m)


static func _hand_xf(h: Dictionary) -> Transform3D:
	var z: Vector3 = -(h.fwd as Vector3).normalized()
	var y: Vector3 = h.up
	y = (y - z * y.dot(z)).normalized()
	return Transform3D(Basis(y.cross(z), y, z), h.pos)


func _add_arms(rig: Node3D, w: String) -> void:
	var h: Dictionary = HANDS[w]
	var a := {}
	for side in ["r", "l"]:
		var arm := ViewArm.new()
		arm.name = "arm_" + side
		rig.add_child(arm)
		arm.build(side == "l", _skin_mat(), _knit_mat(), Player.VM_LAYER)
		a[side] = arm
	for k in h:
		var v: Variant = h[k]
		if v is Dictionary:
			a["xf_" + k] = _hand_xf(v)
			a["c_" + k] = PackedFloat32Array(v.curl)
		else:
			a["e_" + k] = v
	a["c_relax"] = PackedFloat32Array(RELAXED)
	arms[w] = a


func _use_arms(w: String) -> void:
	var a: Dictionary = arms[w]
	_arm_r = a.r
	_arm_l = a.l
	_buf_r.resize(ViewArm.POSE_SIZE)
	_buf_l.resize(ViewArm.POSE_SIZE)
	_bolt_open = 0.0
	_bolt_lift = 0.0
	_r_bolt = 0.0
	_r_load = 0.0
	_r_push = 0.0
	_r_away = 0.0
	_l_mag = 0.0
	_l_away = 0.0
	_anim_rot = Vector3.ZERO
	_anim_pos = Vector3.ZERO
	_update_arms()


## Places both hands on the current gun, blends the reload / bolt poses, and swings the forearms toward
## their elbow points so the arms leave through the bottom of the screen. No allocations.
func _update_arms() -> void:
	if _arm_r == null or _rig == null:
		return
	var a: Dictionary = arms[current]
	var aim := _ease(_aim)
	var to_rig := _rig.transform.basis.inverse()
	# right hand
	var xr: Transform3D = a.xf_r
	var cr: PackedFloat32Array = a.c_r
	for i in ViewArm.POSE_SIZE:
		_buf_r[i] = cr[i]
	if a.has("xf_r_bolt") and _r_bolt > 0.0:
		# the hand rides the knob but only turns a little with it, so the forearm still drops off screen
		var knob := _bolt_delta() * BOLT_KNOB
		var hr := Basis(Vector3.BACK, 0.3 * BOLT_TURN * _bolt_lift)
		var xb: Transform3D = Transform3D(hr, knob - hr * BOLT_KNOB) * (a.xf_r_bolt as Transform3D)
		var cb: PackedFloat32Array = a.c_r_bolt
		if _r_load > 0.0:
			var xl: Transform3D = a.xf_r_load
			xl.origin += Vector3(0, -0.014 * _r_push, -0.01 * _r_push)
			xb = xb.interpolate_with(xl, _r_load)
		xr = xr.interpolate_with(xb, _r_bolt)
		var cl: PackedFloat32Array = a.c_r_load
		for i in ViewArm.POSE_SIZE:
			_buf_r[i] = lerpf(cr[i], lerpf(cb[i], cl[i], _r_load), _r_bolt)
	if _r_away > 0.0:
		xr.origin += to_rig * Vector3(0.12, -0.32, 0.1) * _r_away
	_buf_r[2] += 14.0 * _trigger
	_buf_r[3] += 10.0 * _trigger
	_arm_r.transform = xr
	_arm_r.apply_pose(_buf_r)
	# left hand
	var xl2: Transform3D = a.xf_l
	var cl2: PackedFloat32Array = a.c_l
	if a.has("xf_l_mag") and _l_mag > 0.0:
		xl2 = xl2.interpolate_with(a.xf_l_mag, _l_mag)
	var cm: PackedFloat32Array = a.get("c_l_mag", cl2)
	var cx: PackedFloat32Array = a.c_relax
	for i in ViewArm.POSE_SIZE:
		_buf_l[i] = lerpf(lerpf(cl2[i], cm[i], _l_mag), cx[i], _l_away)
	if _l_away > 0.0:
		xl2.origin += to_rig * Vector3(-0.06, -0.34, 0.08) * _l_away
	_arm_l.transform = xl2
	_arm_l.apply_pose(_buf_l)
	# forearms toward the elbows (camera space, which is this node's parent)
	var cam_xf := (get_parent() as Node3D).global_transform
	var er_h: Vector3 = (a.e_elbow_r as Array)[0]
	var er_a: Vector3 = (a.e_elbow_r as Array)[1]
	var el_h: Vector3 = (a.e_elbow_l as Array)[0]
	var el_a: Vector3 = (a.e_elbow_l as Array)[1]
	_arm_r.aim_forearm(_arm_r.global_transform.affine_inverse() * (cam_xf * er_h.lerp(er_a, aim)))
	_arm_l.aim_forearm(_arm_l.global_transform.affine_inverse() * (cam_xf * el_h.lerp(el_a, aim)))
	if _bolt != null and current == "rifle":
		var hinv := _holder_xf.affine_inverse()
		_bolt.transform = hinv * _bolt_delta() * _holder_xf * _bolt_rest
		if _bolt_b != null:
			_bolt_b.transform = hinv * Transform3D(Basis.IDENTITY, Vector3(0, 0, BOLT_TRAVEL * _bolt_open)) * _holder_xf * _bolt_b_rest


## Rig-space motion of the bolt: handle turned up about the bore, then drawn back.
func _bolt_delta() -> Transform3D:
	var r := Basis(Vector3.BACK, BOLT_TURN * _bolt_lift)
	return Transform3D(r, BOLT_AXIS - r * BOLT_AXIS + Vector3(0, 0, BOLT_TRAVEL * _bolt_open))


func _rel(root: Node, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur != null:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


# ------------------------------------------------------------------ update

var _dbg_t := 0.0
func _process(delta: float) -> void:
	var p := player as Player
	if p == null:
		return
	var can: bool = p.controls_enabled()
	if can:
		if Input.is_action_just_pressed("weapon_1") and has_weapon("pistol"):
			equip("pistol")
		elif Input.is_action_just_pressed("weapon_2") and has_weapon("rifle"):
			equip("rifle")
		elif Input.is_action_just_pressed("holster"):
			holster()
	_cool = maxf(_cool - delta, 0.0)
	var aim_in := can and Input.is_action_pressed("aim") and current != "" and not _reloading and not _switching
	_aim = move_toward(_aim, 1.0 if aim_in else 0.0, delta * (6.0 if current == "pistol" else 4.5))
	var base_fov: float = Game.settings.fov
	if current != "":
		p.cam.fov = lerpf(base_fov, base_fov * float(DEFS[current].ads_fov), _ease(_aim))
	else:
		p.cam.fov = lerpf(p.cam.fov, base_fov, delta * 8.0)
	if _rig == null:
		return
	if _switching:
		_update_arms()
		return
	if can and current != "":
		if Input.is_action_just_pressed("fire"):
			try_fire()
		if Input.is_action_just_pressed("reload"):
			reload()
	# placement: hip/ads blend + sway + bob + recoil
	var d: Dictionary = DEFS[current]
	var target: Vector3 = (d.hip as Vector3).lerp(d.ads, _ease(_aim))
	var mv := Input.get_last_mouse_velocity() * 0.00003 if can else Vector2.ZERO
	_sway = _sway.lerp(-mv * (0.25 if _aim > 0.5 else 1.0), minf(delta * 8.0, 1.0))
	var hv := Vector2(p.velocity.x, p.velocity.z).length()
	_bob_t += delta * hv * 1.9
	var bob := Vector3(cos(_bob_t) * 0.006, -absf(sin(_bob_t)) * 0.008, 0) * clampf(hv / 4.0, 0, 1.5) * (0.2 if _aim > 0.5 else 1.0)
	_recoil = move_toward(_recoil, 0.0, delta * 0.9)
	_recoil_rot = lerpf(_recoil_rot, 0.0, minf(delta * 10.0, 1.0))
	var low := 0.0
	if lowered and _aim < 0.1:
		low = 1.0
	# pull the gun in when pressed against a wall
	var cam3: Camera3D = (player as Player).cam
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam3.global_position, cam3.global_position - cam3.global_transform.basis.z * 0.7, 1)
	q.exclude = [(player as Player).get_rid()]
	if not space.intersect_ray(q).is_empty():
		low = maxf(low, 0.7)
	var sprinting := Input.is_action_pressed("sprint") and hv > 4.5
	var pos := target + Vector3(_sway.x, _sway.y, 0) + bob + Vector3(0, 0, _recoil) + _anim_pos
	if sprinting:
		pos += Vector3(-0.06, -0.06, 0.04)
	pos += Vector3(0, -0.15, 0.05) * low
	_rig.position = _rig.position.lerp(pos, minf(delta * 18.0, 1.0))
	var base_rot: Vector3 = (d.hip_rot as Vector3) * (1.0 - _ease(_aim))
	var rot := base_rot + Vector3(_recoil_rot + (-0.35 * low) + (-0.25 if sprinting else 0.0), _sway.x * 2.0 + (0.4 if sprinting else 0.0), -_sway.x * 1.5 + (0.3 if sprinting else 0.0))
	_rig.rotation = _rig.rotation.lerp(rot + _anim_rot, minf(delta * 14.0, 1.0))
	_trigger = move_toward(_trigger, 0.0, delta * 8.0)
	_update_arms()


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ firing

func try_fire() -> bool:
	if current == "" or _cool > 0.0 or _reloading or _switching:
		return false
	if mags[current] <= 0:
		Audio.sfx("dry_fire", -4.0)
		_cool = 0.3
		if Game.count(DEFS[current].ammo) > 0:
			reload()
		return false
	var dir := _spread_dir(DEFS[current].spread_ads if _aim > 0.5 else DEFS[current].spread_hip)
	_fire_ray(dir, 1.0)
	return true


func _spread_dir(deg: float) -> Vector3:
	var cam: Camera3D = (player as Player).cam
	var b := cam.global_transform.basis
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 1.0
	var s := deg_to_rad(deg * (1.6 if moving else 1.0))
	var a := randf() * TAU
	var r := sqrt(randf()) * s
	return (-b.z + b.x * cos(a) * r + b.y * sin(a) * r).normalized()


func _fire_ray(dir: Vector3, dmg_mult: float) -> void:
	var d: Dictionary = DEFS[current]
	mags[current] -= 1
	_cool = d.cooldown
	var p := player as Player
	var from := p.cam.global_position
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0, 1 | 8)
	q.collide_with_areas = true
	q.exclude = [p.get_rid()]
	var hit := space.intersect_ray(q)
	# feedback
	var loud := 0.0 if current == "pistol" else 3.0
	Audio.sfx(d.sound, loud, 0.05)
	var indoor := p.indoors > 0.5
	Audio.sfx("gun_tail_indoor" if indoor else "gun_tail_outdoor", -6.0 + loud, 0.1)
	var rk := 0.65 if Game.magazines.has("steady_hand") else 1.0
	p.kick(d.kick * (0.5 if _aim > 0.5 else 1.0) * rk, randf_range(-0.01, 0.01) * rk)
	p.shake(0.25 if current == "pistol" else 0.45)
	_recoil = (0.05 if current == "pistol" else 0.09) * rk
	_recoil_rot = (0.18 if current == "pistol" else 0.22) * rk
	_trigger = 1.0
	_muzzle_flash()
	if _slide:
		var tw := create_tween()
		var sp := _slide.position
		tw.tween_property(_slide, "position", sp + Vector3(-0.035, 0, 0), 0.03)
		tw.tween_property(_slide, "position", sp, 0.07)
		_eject_shell(Vector3(0.03, 0.04, -0.08))
	get_tree().call_group("enemies", "on_gunshot", p.global_position)
	fired.emit()
	var end := from + dir * 120.0
	if not hit.is_empty():
		end = hit.position
		var col: Object = hit.collider
		if col is Area3D and col.has_meta("actor"):
			var actor: Object = col.get_meta("actor")
			var part: String = col.get_meta("part")
			var dmg: float = d.dmg * dmg_mult * (1.1 if Game.traits.has("selfreliant") else 1.0)
			if part == "head":
				dmg *= 1.0 + (0.5 if Game.magazines.has("detective") else 0.0) + (0.2 if Game.traits.has("keen") else 0.0)
			if is_instance_valid(actor):
				var target: Node = actor
				# models may report themselves; the controller is their owner/parent
				while target != null and not target.has_method("take_hit"):
					target = target.get_parent()
				if target != null:
					var killed: bool = target.call("take_hit", part, dmg, dir, hit.position)
					hit_confirmed.emit(killed)
			_impact(hit.position, hit.normal, "crystal")
		else:
			var surf := "concrete"
			if col is Node and (col as Node).has_meta("surface"):
				surf = (col as Node).get_meta("surface")
			_impact(hit.position, hit.normal, surf)
			_bullet_hole(hit.position, hit.normal, col as Node)
	_tracer(_muzzle_world(), end)
	_emit_ammo()
	if current == "rifle" and mags[current] > 0:
		_cycle_bolt()
	elif mags[current] == 0 and Game.count(d.ammo) > 0:
		get_tree().create_timer(0.35).timeout.connect(reload)


func _cycle_bolt() -> void:
	await get_tree().create_timer(0.18).timeout
	if _bolt == null or current != "rifle" or _reloading:
		return
	# right hand up to the bolt: lift, pull back (shell out), push home, turn down, back to the grip
	var tw := create_tween()
	tw.tween_property(self, "_r_bolt", 1.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_anim_rot", BOLT_TILT, 0.13)
	tw.parallel().tween_property(self, "_anim_pos", BOLT_SHIFT, 0.13)
	tw.tween_property(self, "_bolt_lift", 1.0, 0.06)
	tw.tween_callback(func(): Audio.sfx("rifle_bolt_open", -4.0))
	tw.tween_property(self, "_bolt_open", 1.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _eject_shell(Vector3(0.03, 0.05, -0.15)))
	tw.tween_callback(func(): Audio.sfx("rifle_bolt_close", -4.0))
	tw.tween_property(self, "_bolt_open", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_bolt_lift", 0.0, 0.06)
	tw.tween_property(self, "_r_bolt", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "_anim_rot", Vector3.ZERO, 0.2)
	tw.parallel().tween_property(self, "_anim_pos", Vector3.ZERO, 0.2)


func reload() -> void:
	if current == "" or _reloading:
		return
	var d: Dictionary = DEFS[current]
	if mags[current] >= d.mag or Game.count(d.ammo) <= 0:
		return
	_reloading = true
	var speed := 1.2 if Game.traits.has("steady") else 1.0
	var w := current
	if w == "pistol":
		# tip the gun in, left hand drops away for a fresh magazine, slaps it home, rack, back to grip
		Audio.sfx("pistol_mag_out", -3.0)
		var tw := create_tween()
		tw.tween_property(self, "_anim_rot", Vector3(0.45, -0.25, 0.35), 0.25 / speed).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(self, "_l_away", 1.0, 0.25 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "_l_mag", 1.0, 0.25 / speed)
		await tw.finished
		await get_tree().create_timer(0.2 / speed).timeout
		var tw1 := create_tween()
		tw1.tween_property(self, "_l_away", 0.0, 0.25 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tw1.finished
		Audio.sfx("pistol_mag_in", -3.0)
		var tw2 := create_tween()
		tw2.tween_property(self, "_anim_rot:x", 0.55, 0.06)
		tw2.tween_property(self, "_anim_rot:x", 0.45, 0.12)
		tw2.tween_property(self, "_l_mag", 0.0, 0.17 / speed).set_trans(Tween.TRANS_SINE)
		await tw2.finished
		Audio.sfx("pistol_slide", -3.0)
		if _slide and w == current:
			var sp: Vector3 = _slide.position
			var tws := create_tween()
			tws.tween_property(_slide, "position", sp + Vector3(-0.035, 0, 0), 0.06)
			tws.tween_property(_slide, "position", sp, 0.06)
		var need: int = d.mag - mags[w]
		var take: int = mini(need, Game.count(d.ammo))
		Game.remove_item(d.ammo, take)
		mags[w] += take
		var tw3 := create_tween()
		tw3.tween_property(self, "_anim_rot", Vector3.ZERO, 0.25 / speed).set_trans(Tween.TRANS_SINE)
		await tw3.finished
	else:
		# right hand opens the bolt, thumbs rounds in one by one, closes it
		var tw4 := create_tween()
		tw4.tween_property(self, "_anim_rot", RELOAD_TILT, 0.25 / speed).set_trans(Tween.TRANS_SINE)
		tw4.parallel().tween_property(self, "_anim_pos", RELOAD_SHIFT, 0.25 / speed).set_trans(Tween.TRANS_SINE)
		tw4.parallel().tween_property(self, "_r_bolt", 1.0, 0.15 / speed).set_trans(Tween.TRANS_SINE)
		tw4.tween_property(self, "_bolt_lift", 1.0, 0.05 / speed)
		tw4.tween_callback(func(): Audio.sfx("rifle_bolt_open", -3.0))
		tw4.tween_property(self, "_bolt_open", 1.0, 0.12 / speed)
		tw4.tween_property(self, "_r_load", 1.0, 0.15 / speed).set_trans(Tween.TRANS_SINE)
		await tw4.finished
		var t: float = d.reload / speed
		while mags["rifle"] < d.mag and Game.count(d.ammo) > 0 and current == "rifle":
			var tw5 := create_tween()
			tw5.tween_property(self, "_r_away", 1.0, t * 0.3).set_trans(Tween.TRANS_SINE)
			tw5.tween_property(self, "_r_away", 0.0, t * 0.32).set_trans(Tween.TRANS_SINE)
			tw5.tween_property(self, "_r_push", 1.0, t * 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw5.tween_property(self, "_r_push", 0.0, t * 0.2)
			await get_tree().create_timer(t * 0.8).timeout
			Audio.sfx("rifle_round_in", -3.0)
			Game.remove_item(d.ammo, 1)
			mags["rifle"] += 1
			_emit_ammo()
			await get_tree().create_timer(t * 0.2).timeout
			if Input.is_action_pressed("fire"):
				break
		var tw6 := create_tween()
		tw6.tween_property(self, "_r_load", 0.0, 0.12 / speed).set_trans(Tween.TRANS_SINE)
		tw6.tween_callback(func(): Audio.sfx("rifle_bolt_close", -3.0))
		tw6.tween_property(self, "_bolt_open", 0.0, 0.12 / speed)
		tw6.tween_property(self, "_bolt_lift", 0.0, 0.05 / speed)
		tw6.tween_property(self, "_r_bolt", 0.0, 0.2 / speed).set_trans(Tween.TRANS_SINE)
		tw6.parallel().tween_property(self, "_anim_rot", Vector3.ZERO, 0.25 / speed).set_trans(Tween.TRANS_SINE)
		tw6.parallel().tween_property(self, "_anim_pos", Vector3.ZERO, 0.25 / speed).set_trans(Tween.TRANS_SINE)
		await tw6.finished
	_reloading = false
	_emit_ammo()


# ------------------------------------------------------------------ fx

func _muzzle_world() -> Vector3:
	if _rig == null:
		return global_position
	return _rig.to_global(_rig.get_meta("muzzle"))


func _muzzle_flash() -> void:
	var m := _muzzle_world()
	_flash_light.global_position = m
	_flash_light.light_energy = 6.0
	_flash_mesh.global_position = m
	_flash_mesh.visible = true
	_flash_mesh.rotation.z = randf() * TAU
	_flash_mesh.scale = Vector3.ONE * randf_range(0.8, 1.3) * (1.0 if current == "pistol" else 1.6)
	var tw := create_tween()
	tw.tween_property(_flash_light, "light_energy", 0.0, 0.07)
	tw.parallel().tween_callback(func(): _flash_mesh.visible = false).set_delay(0.035)
	Fx.smoke_puff(get_tree().current_scene, m + (player as Player).get_look_dir() * 0.25, 0.09, Color(0.85, 0.83, 0.8, 0.18))


func _eject_shell(local_off: Vector3) -> void:
	if _rig == null:
		return
	var shell := RigidBody3D.new()
	shell.collision_layer = 32
	shell.collision_mask = 1
	shell.mass = 0.02
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.006
	cy.height = 0.03 if current == "pistol" else 0.06
	cs.shape = cy
	shell.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0055
	cm.bottom_radius = 0.0055
	cm.height = cy.height
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = Mats.color(Color(0.85, 0.62, 0.3), 0.3, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_child(mi)
	get_tree().current_scene.add_child(shell)
	shell.global_transform = Transform3D(_rig.global_transform.basis.orthonormalized().rotated(Vector3.FORWARD, 1.4), _rig.to_global(local_off))
	var b := (player as Player).cam.global_transform.basis
	shell.linear_velocity = player.velocity + b.x * randf_range(1.6, 2.4) + b.y * randf_range(1.2, 2.0) + b.z * 0.4
	shell.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	var pos := shell
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(pos):
			Audio.sfx_at("shell", pos.global_position, -12.0, 2.0))
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(pos):
			pos.queue_free())


func _tracer(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 2.0:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, minf(len, 14.0))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.85, 0.55, 0.6)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	var dir := (b - a).normalized()
	mi.global_position = a + dir * minf(len, 14.0) * 0.5
	mi.look_at(b, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", b - dir * minf(len, 14.0) * 0.5, minf(len / 400.0, 0.12))
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(mi.queue_free)


func _impact(pos: Vector3, nrm: Vector3, surf: String) -> void:
	var scene := get_tree().current_scene
	match surf:
		"crystal":
			Audio.sfx_at("impact_crystal", pos, 0.0, 5.0)
			Fx.sparks(scene, pos, nrm, Color(0.75, 0.5, 1.0), 14)
		"metal":
			Audio.sfx_at("impact_metal", pos, -2.0, 5.0)
			Fx.sparks(scene, pos, nrm, Color(1.0, 0.75, 0.4), 10)
			if randf() < 0.35:
				Audio.sfx_at("ricochet", pos, -4.0, 6.0)
		"wood", "carpet":
			Audio.sfx_at("impact_wood", pos, -2.0, 5.0)
			Fx.debris(scene, pos, nrm, Color(0.45, 0.32, 0.2), 8)
		"grass", "gravel", "dirt":
			Audio.sfx_at("impact_dirt", pos, -2.0, 5.0)
			Fx.debris(scene, pos, nrm, Color(0.35, 0.3, 0.22), 10)
			Fx.smoke_puff(scene, pos, 0.5, Color(0.45, 0.4, 0.33, 0.6))
		"glass":
			Audio.sfx_at("glass_break", pos, -6.0, 5.0)
			Fx.debris(scene, pos, nrm, Color(0.8, 0.9, 1.0), 10)
		_:
			Audio.sfx_at("impact_concrete", pos, -2.0, 5.0)
			Fx.debris(scene, pos, nrm, Color(0.6, 0.58, 0.55), 9)
			Fx.smoke_puff(scene, pos, 0.4, Color(0.6, 0.58, 0.55, 0.5))


func _bullet_hole(pos: Vector3, nrm: Vector3, col: Node) -> void:
	if col == null or not col is StaticBody3D:
		return
	if _hole_tex == null:
		_hole_tex = _make_hole_texture()
	var dcl := Decal.new()
	dcl.texture_albedo = _hole_tex
	dcl.size = Vector3(0.09, 0.1, 0.09)
	dcl.cull_mask = 1
	get_tree().current_scene.add_child(dcl)
	dcl.global_position = pos
	var up := nrm
	var ref := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	dcl.global_transform.basis = Basis(x, up, z).rotated(up, randf() * TAU)
	_decals.append(dcl)
	if _decals.size() > 60:
		var old: Node = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func _make_hole_texture() -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0, y - s / 2.0).length() / (s / 2.0)
			var a := 0.0
			var c := Color(0.05, 0.04, 0.03)
			if d < 0.22:
				a = 1.0
			elif d < 0.7:
				a = (1.0 - (d - 0.22) / 0.48) * 0.55 * (0.6 + 0.4 * sin(atan2(y - s / 2.0, x - s / 2.0) * 7.0))
				c = Color(0.18, 0.16, 0.14)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(a, 0, 1)))
	return ImageTexture.create_from_image(img)


static func _star_texture() -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var v := Vector2(x - s / 2.0, y - s / 2.0) / (s / 2.0)
			var r := v.length()
			var ang := atan2(v.y, v.x)
			var star := pow(absf(cos(ang * 3.0)), 18.0) * (1.0 - r)
			var core := clampf(1.0 - r * 2.2, 0, 1)
			var a := clampf(core + star * 1.4, 0, 1)
			img.set_pixel(x, y, Color(1, 0.9, 0.7, a))
	return ImageTexture.create_from_image(img)
