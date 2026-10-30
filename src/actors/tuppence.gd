class_name Tuppence
extends Node3D
## Companion controller driving TuppenceModel: goto/follow/stay movement, look-at, barks, zapper.

signal talk_requested
signal arrived

var model: TuppenceModel
var player: Player
var mode := "stay"  # stay | goto | follow
var target := Vector3.ZERO
var path: Array[Vector3] = []
var speed := 2.2
var talk: Interactable
var zap_enabled := false
var _vel := Vector3.ZERO
var _bark_cd := 8.0
var _zap_cd := 3.0
var _hover: AudioStreamPlayer3D
var _last_barks := {}
var look_player := true


func setup(p: Player, aged: bool) -> void:
	player = p
	model = TuppenceModel.new()
	model.aged = aged
	add_child(model)
	talk = Interactable.make(self, Vector3(0, 1.0, 0), Vector3(0.9, 1.6, 0.9), "Talk to", "Tuppence")
	talk.used.connect(func(): talk_requested.emit())
	_hover = Audio.loop_on(self, "robot_hover_loop", -20.0, 2.0)


func get_head_node() -> Node3D:
	return model.get_head_node()


func set_talking(b: bool) -> void:
	model.set_talking(b)


func gesture(name: String) -> float:
	Audio.sfx_at("robot_servo", global_position + Vector3(0, 1.2, 0), -10.0, 2.0)
	return model.play_gesture(name)


func go(p: Vector3, spd := 2.2) -> void:
	path.clear()
	target = p
	speed = spd
	mode = "goto"


func go_path(points: Array, spd := 2.2) -> void:
	path.assign(points)
	target = path.pop_front()
	speed = spd
	mode = "goto"


func follow(spd := 4.0) -> void:
	mode = "follow"
	speed = spd


func stay() -> void:
	mode = "stay"


func place(p: Vector3, yaw_deg := 0.0) -> void:
	global_position = p
	rotation.y = deg_to_rad(yaw_deg)
	_vel = Vector3.ZERO


## Plays a bark line if not on cooldown and not repeated recently.
func bark(id: String, force := false) -> void:
	if not force and (_bark_cd > 0.0 or _last_barks.has(id)):
		return
	if Game.input_locked > 0 and not force:
		return
	_last_barks[id] = true
	_bark_cd = 14.0
	model.set_talking(true)
	var d := Audio.voice(id, self)
	get_tree().create_timer(d).timeout.connect(func():
		if is_instance_valid(model):
			model.set_talking(false))


func _ground_y(p: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 4.0, 1)
	var hit := space.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else Layout.height(p.x, p.z)


func _process(delta: float) -> void:
	if model == null or player == null:
		return
	_bark_cd = maxf(_bark_cd - delta, 0.0)
	_zap_cd = maxf(_zap_cd - delta, 0.0)
	var goal := global_position
	var spd := speed
	match mode:
		"goto":
			goal = target
			if Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 0.3:
				if path.is_empty():
					mode = "stay"
					arrived.emit()
				else:
					target = path.pop_front()
		"follow":
			var back := -player.global_transform.basis.z
			back.y = 0
			back = back.normalized()
			var right := back.cross(Vector3.UP)
			goal = player.global_position - back * 2.2 + right * 1.3
			var d := Vector2(goal.x - global_position.x, goal.z - global_position.z).length()
			spd = clampf(d * 1.6, 0.0, 7.5)
			if d < 0.8:
				spd = 0.0
			# catch up if left far behind and out of view
			if global_position.distance_to(player.global_position) > 26.0 and player.cam.is_position_behind(global_position):
				var tp := player.global_position - back * 4.0
				global_position = Vector3(tp.x, _ground_y(tp), tp.z)
	var to := goal - global_position
	to.y = 0
	var desired := Vector3.ZERO
	if to.length() > 0.15 and mode != "stay":
		desired = to.normalized() * minf(spd, to.length() * 3.0)
	_vel = _vel.lerp(desired, minf(delta * 4.0, 1.0))
	global_position += _vel * delta
	# stay at floor height (he hovers; the model adds the bob)
	var gy := _ground_y(global_position)
	global_position.y = lerpf(global_position.y, gy, minf(delta * 8.0, 1.0))
	model.set_move_speed(clampf(_vel.length() / 5.0, 0.0, 1.0))
	# facing
	var face_dir := _vel
	if _vel.length() < 0.3:
		face_dir = player.global_position - global_position if look_player else -global_transform.basis.z
	face_dir.y = 0
	if face_dir.length() > 0.05:
		var target_yaw := atan2(-face_dir.x, -face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 4.0, 1.0))
	if look_player and player.global_position.distance_to(global_position) < 8.0:
		model.look_at_point(player.cam.global_position)
	if zap_enabled:
		_combat()


func _combat() -> void:
	if _zap_cd > 0.0:
		return
	var best: Node3D = null
	var bd := 11.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.get("alive") or not e.get("aggro"):
			continue
		var d := (e as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	_zap_cd = 6.5 / (1.3 if Game.traits.has("neighborly") else 1.0)
	look_player = false
	var dir := best.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	model.set_eye_color(Color(0.5, 0.9, 1.0))
	gesture("zap")
	if randf() < 0.5:
		bark(["tp_c7", "tp_c6"][randi() % 2], true)
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(best) or not best.get("alive"):
		look_player = true
		return
	Audio.sfx_at("robot_zap", global_position + Vector3(0, 1.2, 0), 0.0, 6.0)
	var hand := model.get_hand_node(true)
	if hand and ResourceLoader.exists("res://src/actors/fx/zap_arc.gd"):
		var ZA: GDScript = load("res://src/actors/fx/zap_arc.gd")
		if ZA.has_method("spawn"):
			ZA.call("spawn", get_tree().current_scene, hand.global_position, best.global_position + Vector3(0, 0.6, 0))
	Fx.sparks(get_tree().current_scene, best.global_position + Vector3(0, 0.8, 0), Vector3.UP, Color(0.5, 0.85, 1.0), 16)
	var dmg := 28.0 * (1.6 if Game.magazines.has("tinker") else 1.0)
	best.call("take_hit", "torso", dmg, (best.global_position - global_position).normalized(), best.global_position + Vector3(0, 0.8, 0))
	await get_tree().create_timer(0.6).timeout
	model.set_eye_color(Color(1.0, 0.7, 0.3))
	look_player = true
