class_name Player
extends CharacterBody3D
## First-person player: movement, head-bob, surface footsteps, interaction, flashlight, damage.

signal died

const WALK := 3.4
const RUN := 6.4
const CROUCH := 1.8
const ACCEL := 11.0
const AIR_ACCEL := 2.5
const JUMP := 4.4
const GRAVITY := 13.0
const EYE := 1.62
const CROUCH_EYE := 1.0
const STEP := 0.36  # tallest ledge (kerb, stair, door sill) the player walks up without jumping
const VM_LAYER := 1 << 19
const VM_FOV := 52.0

var head: Node3D
var cam: Camera3D
var flashlight: SpotLight3D
var weapons: Node3D
var ray: RayCast3D
var focus_target: Interactable = null
var indoors := 0.0  # 0..1, set by world triggers
var vm_viewport: SubViewport
var vm_cam: Camera3D
var _vm_env_t := 0.0

var _yaw := 0.0
var _pitch := 0.0
var _bob_t := 0.0
var _step_acc := 0.0
var _crouch := 0.0
var _crouch_held := false  # toggle-crouch state
var _step_smooth := 0.0  # camera lag after a step-up, eased back to 0
var _kick := Vector2.ZERO
var _shake := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _cine_tween: Tween
var _hurt_cd := 0.0
var dead := false
var allow_sprint := true
var speed_mult := 1.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	cam = Camera3D.new()
	cam.fov = Game.settings.fov
	cam.near = 0.03
	cam.far = 1600.0
	head.add_child(cam)
	cam.current = true
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.93, 0.8)
	flashlight.light_energy = 3.0
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 30.0
	flashlight.spot_angle_attenuation = 0.8
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.18, -0.12, 0.0)
	flashlight.visible = false
	cam.add_child(flashlight)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.6)
	ray.collision_mask = 1 | 16
	ray.collide_with_areas = true
	ray.add_exception(self)
	cam.add_child(ray)
	var Weapons: GDScript = load("res://src/player/weapons.gd")
	weapons = Weapons.new()
	weapons.name = "Weapons"
	cam.add_child(weapons)
	weapons.call("setup", self)
	Game.settings_changed.connect(func(): cam.fov = Game.settings.fov)


## Weapons render through a second camera with a narrow FOV (no wide-angle distortion, no wall clipping).
func _setup_viewmodel() -> void:
	cam.cull_mask = cam.cull_mask & ~VM_LAYER
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	vm_viewport = SubViewport.new()
	vm_viewport.transparent_bg = true
	vm_viewport.msaa_3d = Viewport.MSAA_2X
	vm_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vm_viewport.size = get_viewport().get_visible_rect().size
	layer.add_child(vm_viewport)
	vm_cam = Camera3D.new()
	vm_cam.cull_mask = VM_LAYER
	vm_cam.fov = VM_FOV
	vm_cam.near = 0.01
	vm_cam.far = 5.0
	vm_viewport.add_child(vm_cam)
	vm_cam.current = true
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = vm_viewport.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(tr)
	get_viewport().size_changed.connect(func(): vm_viewport.size = get_viewport().get_visible_rect().size)


func _update_viewmodel_cam(delta: float) -> void:
	if vm_cam == null:
		return
	vm_cam.global_transform = cam.global_transform
	vm_cam.fov = VM_FOV * (cam.fov / maxf(Game.settings.fov, 1.0))
	vm_cam.attributes = cam.attributes if cam.attributes else get_viewport().get_camera_3d().attributes if get_viewport().get_camera_3d() else null
	_vm_env_t -= delta
	if _vm_env_t <= 0.0:
		_vm_env_t = 0.5
		var we := get_tree().current_scene.find_children("*", "WorldEnvironment", true, false)
		if not we.is_empty() and (we[0] as WorldEnvironment).environment:
			var e: Environment = (we[0] as WorldEnvironment).environment.duplicate()
			e.background_mode = Environment.BG_CLEAR_COLOR
			e.sdfgi_enabled = false
			e.volumetric_fog_enabled = false
			e.fog_enabled = false
			e.ssr_enabled = false
			e.ssil_enabled = false
			e.ssao_enabled = false
			e.glow_enabled = false
			vm_cam.environment = e
			if vm_cam.attributes == null and (we[0] as WorldEnvironment).camera_attributes:
				vm_cam.attributes = (we[0] as WorldEnvironment).camera_attributes


func set_look(yaw_deg: float, pitch_deg := 0.0) -> void:
	_yaw = deg_to_rad(yaw_deg)
	_pitch = deg_to_rad(pitch_deg)
	rotation.y = _yaw
	head.rotation.x = _pitch


func get_look_dir() -> Vector3:
	return -cam.global_transform.basis.z


func controls_enabled() -> bool:
	return Game.input_locked == 0 and not dead and not get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled():
		var sens: float = Game.settings.mouse_sens * 0.01
		if weapons.call("is_aiming"):
			sens *= 0.55
		var inv := -1.0 if Game.settings.invert_y else 1.0
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens * inv, deg_to_rad(-86), deg_to_rad(86))
		rotation.y = _yaw
	if not controls_enabled():
		return
	if event.is_action_pressed("interact") and focus_target != null:
		focus_target.use()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		Audio.sfx("light_switch", -6.0)
	elif event.is_action_pressed("use_aid"):
		var id := Game.best_aid()
		if id != "" and Game.use_aid(id):
			Game.toast.emit("Used " + Game.item_name(id))


func _physics_process(delta: float) -> void:
	if dead:
		return
	var input := Vector2.ZERO
	var can := controls_enabled()
	if can:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not can:
		_crouch_held = false
	elif bool(Game.settings.get("crouch_toggle", true)):
		if Input.is_action_just_pressed("crouch"):
			_crouch_held = not _crouch_held
		elif Input.is_action_just_pressed("sprint") or Input.is_action_just_pressed("jump"):
			_crouch_held = false
	else:
		_crouch_held = Input.is_action_pressed("crouch")
	var crouching := _crouch_held
	_crouch = move_toward(_crouch, 1.0 if crouching else 0.0, delta * 5.0)
	var sprint: bool = can and allow_sprint and Input.is_action_pressed("sprint") and input.y < 0.1 and not crouching and not weapons.call("is_aiming")
	var spd := RUN if sprint else WALK
	if Game.magazines.has("outdoorsman") and sprint:
		spd *= 1.12
	if crouching:
		spd = CROUCH
	if weapons.call("is_aiming"):
		spd = minf(spd, 2.4)
	spd *= speed_mult
	var wish := (transform.basis * Vector3(input.x, 0, input.y))
	wish.y = 0
	wish = wish.normalized() * spd * minf(input.length(), 1.0)
	var acc := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = lerpf(velocity.x, wish.x, minf(acc * delta, 1.0))
	velocity.z = lerpf(velocity.z, wish.z, minf(acc * delta, 1.0))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	elif can and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP
		Audio.sfx("jump", -10.0)
	if is_on_floor() and velocity.y <= 0.0:
		_step_up(delta)
	move_and_slide()
	# landing
	if is_on_floor() and not _was_on_floor:
		if _fall_speed > 3.5:
			Audio.sfx("land", -6.0)
			_kick.y += 0.03 * minf(_fall_speed / 6.0, 1.5)
			_footstep(0.0)
		if _fall_speed > 13.0:
			take_damage((_fall_speed - 13.0) * 8.0, global_position)
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()
	# footsteps + head bob
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		_bob_t += delta * hspeed * 1.9
		_step_acc += hspeed * delta
		var stride := 1.55 if sprint else 1.05
		if _step_acc > stride:
			_step_acc = 0.0
			_footstep(-14.0 + (4.0 if sprint else 0.0) - (6.0 if crouching else 0.0))
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, delta * 4.0)
	var bob_amt := clampf(hspeed / RUN, 0.0, 1.0) * (0.045 if sprint else 0.03)
	var eye := lerpf(EYE, CROUCH_EYE, _crouch)
	_step_smooth = move_toward(_step_smooth, 0.0, delta * maxf(1.2, -_step_smooth * 10.0))
	head.position.y = eye + sin(_bob_t * 2.0) * bob_amt * 0.6 + _step_smooth
	head.position.x = cos(_bob_t) * bob_amt * 0.5
	# camera kick recovery + shake
	_kick = _kick.lerp(Vector2.ZERO, minf(delta * 9.0, 1.0))
	_shake = maxf(_shake - delta * 1.6, 0.0)
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake * 0.05
	head.rotation.x = _pitch + _kick.y + sh.y
	head.rotation.z = sh.x * 0.5 + (-input.x * 0.012 if can else 0.0)
	cam.rotation.y = _kick.x + sh.x
	_hurt_cd = maxf(_hurt_cd - delta, 0.0)
	_update_focus()


## Walk up a short ledge in front of us: rise, check the way is clear, settle on top. The camera eases up after.
func _step_up(delta: float) -> void:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.0005:
		return
	var xf := global_transform
	var col := KinematicCollision3D.new()
	if not test_move(xf, motion, col) or col.get_normal().y >= 0.7:
		return  # nothing ahead, or a walkable slope move_and_slide handles itself
	var up := Vector3(0.0, STEP, 0.0)
	if test_move(xf, up, col):
		up = col.get_travel()
		if up.y < 0.05:
			return
	var raised := xf.translated(up)
	var fwd := motion.normalized() * maxf(motion.length(), 0.1)
	if test_move(raised, fwd):
		return  # taller than a step
	if not test_move(raised.translated(fwd), -up - Vector3(0.0, 0.05, 0.0), col) or col.get_normal().y < 0.7:
		return  # nothing to stand on up there
	var rise := up.y + col.get_travel().y + 0.01
	if rise < 0.02 or rise > STEP + 0.01:
		return
	global_position.y += rise
	_step_smooth -= rise


func _process(_delta: float) -> void:
	pass


func _update_focus() -> void:
	var t: Interactable = null
	if controls_enabled() and ray.is_colliding():
		var c := ray.get_collider()
		if c is Interactable and (c as Interactable).enabled:
			t = c
	focus_target = t


func surface_below() -> String:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.5, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return "grass"
	var c: Object = hit.collider
	var s := "concrete"
	if c.has_meta("surface"):
		s = c.get_meta("surface")
	if c.has_meta("terrain") and Layout.road_edge_dist(global_position.x, global_position.z) < 0.5:
		s = "concrete"
	return s


func _footstep(vol: float) -> void:
	var s := surface_below()
	var name: String = "step_" + {"wood": "wood", "carpet": "carpet", "metal": "metal", "grass": "grass", "gravel": "gravel", "glass": "concrete"}.get(s, "concrete")
	Audio.sfx(name, vol, 0.08, "Interior" if indoors > 0.5 else "SFX")


func kick(pitch: float, yaw: float) -> void:
	_kick += Vector2(yaw, pitch)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func take_damage(amount: float, from: Vector3) -> void:
	if dead or Game.flag("god"):
		return
	Game.damage_hp(amount)
	shake(0.6)
	var dir := (from - global_position)
	dir.y = 0
	var side := (transform.basis.x).dot(dir.normalized())
	kick(0.04, -side * 0.05)
	if _hurt_cd <= 0.0:
		Audio.sfx("hurt", -2.0)
		_hurt_cd = 0.5
	get_tree().call_group("hud", "on_player_hurt", amount, from)
	if Game.hp <= 0.0:
		dead = true
		died.emit()


## Smoothly turns the view to face a world point (for cutscenes). Returns the tween.
func look_toward(p: Vector3, dur := 0.8) -> Tween:
	var d := p - head.global_position
	var target_yaw := atan2(-d.x, -d.z)
	var target_pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var cur := _yaw
	target_yaw = cur + wrapf(target_yaw - cur, -PI, PI)
	if _cine_tween:
		_cine_tween.kill()
	_cine_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	_cine_tween.tween_method(func(v: float): _yaw = v; rotation.y = v, cur, target_yaw, dur)
	_cine_tween.tween_method(func(v: float): _pitch = v, _pitch, clampf(target_pitch, -1.2, 1.2), dur)
	return _cine_tween


func teleport(pos: Vector3, yaw_deg: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	set_look(yaw_deg, 0.0)
