class_name Dialogue
extends CanvasLayer
## Conversations: cinematic camera framing the speaker, letterbox, voiced lines, numbered choices.

signal _chosen(i: int)
signal _skip

var hud: Hud
var player: Player
var cam: Camera3D
var _active := false
var _choices: VBoxContainer
var _choice_panel: PanelContainer
var _cam_tween: Tween
var _can_skip := false
var _speaker: Node3D
var _drift := 0.0
var _base_xf: Transform3D


func _ready() -> void:
	layer = 11
	_choice_panel = PanelContainer.new()
	_choice_panel.anchor_left = 0.5
	_choice_panel.anchor_right = 0.5
	_choice_panel.anchor_top = 1.0
	_choice_panel.anchor_bottom = 1.0
	_choice_panel.offset_left = -360
	_choice_panel.offset_right = 360
	_choice_panel.offset_top = -330
	_choice_panel.offset_bottom = -100
	_choice_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.72)
	sb.border_color = Color(0.97, 0.86, 0.62, 0.35)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(16)
	sb.set_corner_radius_all(4)
	_choice_panel.add_theme_stylebox_override("panel", sb)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	_choice_panel.add_child(_choices)
	_choice_panel.visible = false
	add_child(_choice_panel)
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.03
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 2.4
	attrs.dof_blur_far_transition = 2.5
	attrs.dof_blur_amount = 0.06
	attrs.auto_exposure_enabled = false
	cam.attributes = attrs


func is_active() -> bool:
	return _active


## Start a conversation framed on speaker (a Node3D whose `get_head_node()` or itself is the focus).
func begin(speaker: Node3D, cinematic := true) -> void:
	if _active:
		_speaker = speaker
		if cinematic:
			_frame(speaker, 0.8)
		return
	_active = true
	_speaker = speaker
	Game.input_locked += 1
	hud.letterbox(true)
	if cinematic and speaker != null:
		if cam.get_parent() == null:
			get_tree().current_scene.add_child(cam)
		cam.global_transform = player.cam.global_transform
		cam.fov = player.cam.fov
		cam.current = true
		_frame(speaker, 0.9)


func end() -> void:
	if not _active:
		return
	_active = false
	_choice_panel.visible = false
	hud.letterbox(false)
	if cam.current:
		if _cam_tween:
			_cam_tween.kill()
		_cam_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_cam_tween.tween_property(cam, "global_transform", player.cam.global_transform, 0.6)
		_cam_tween.parallel().tween_property(cam, "fov", player.cam.fov, 0.6)
		await _cam_tween.finished
		player.cam.current = true
	if _speaker != null and is_instance_valid(_speaker) and _speaker.has_method("set_talking"):
		_speaker.call("set_talking", false)
	Game.input_locked = maxi(Game.input_locked - 1, 0)


func _focus_point(n: Node3D) -> Vector3:
	if n.has_method("get_head_node"):
		var h: Node3D = n.call("get_head_node")
		if h != null:
			return h.global_position
	return n.global_position + Vector3(0, 1.4, 0)


func _frame(speaker: Node3D, dur: float) -> void:
	var head := _focus_point(speaker)
	var eye := player.cam.global_position
	var v := eye - head
	v.y = 0
	if v.length() < 0.2:
		v = Vector3(0, 0, 1)
	v = v.normalized()
	var right := Vector3.UP.cross(v).normalized()
	var dist := clampf(eye.distance_to(head) * 0.6, 1.05, 1.6)
	var pos := head + v * dist - right * 0.32 + Vector3(0, -0.06, 0)
	var xf := Transform3D(Basis(), pos).looking_at(head + right * 0.08 + Vector3(0, -0.04, 0), Vector3.UP)
	_base_xf = xf
	_drift = 0.0
	(cam.attributes as CameraAttributesPractical).dof_blur_far_distance = dist + 0.6
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(cam, "global_transform", xf, dur)
	_cam_tween.parallel().tween_property(cam, "fov", 40.0, dur)


func _process(delta: float) -> void:
	if _active and cam.current and (_cam_tween == null or not _cam_tween.is_running()):
		# slow push-in drift keeps the shot alive
		_drift += delta
		var push := minf(_drift * 0.02, 0.18)
		var xf := _base_xf
		xf.origin += -xf.basis.z * push + xf.basis.x * sin(_drift * 0.3) * 0.02
		cam.global_transform = cam.global_transform.interpolate_with(xf, minf(delta * 2.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _choice_panel.visible:
		for i in 4:
			if event.is_action_pressed("choice_%d" % (i + 1)) and i < _choices.get_child_count():
				_pick(i)
				get_viewport().set_input_as_handled()
				return
	elif _can_skip and (event.is_action_pressed("interact") or event.is_action_pressed("execute") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
		_skip.emit()
		get_viewport().set_input_as_handled()


## Play a line; if speaker given it "talks". Waits for the line (skippable). Returns after a short gap.
func say(id: String, speaker: Node3D = null, positional := true, gap := 0.25) -> void:
	if speaker != null and speaker.has_method("set_talking"):
		speaker.call("set_talking", true)
	var dur := Audio.voice(id, speaker if positional else null)
	if Game.shot_args.has("auto"):
		dur = minf(dur, 0.6)
	_can_skip = false
	var t := get_tree().create_timer(dur + gap)
	get_tree().create_timer(0.5).timeout.connect(func(): _can_skip = true)
	var skipped := [false]
	var cb := func(): skipped[0] = true
	_skip.connect(cb)
	while t.time_left > 0.0 and not skipped[0]:
		await get_tree().process_frame
	_skip.disconnect(cb)
	_can_skip = false
	if skipped[0]:
		Audio.stop_voices()
	if speaker != null and is_instance_valid(speaker) and speaker.has_method("set_talking"):
		speaker.call("set_talking", false)


func choose(options: Array) -> int:
	for c in _choices.get_children():
		c.free()
	for i in options.size():
		var b := Button.new()
		b.text = "%d.   %s" % [i + 1, options[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color(0.97, 0.86, 0.62))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
		b.add_theme_font_override("font", hud.font_ui)
		var idx := i
		b.pressed.connect(func(): _pick(idx))
		b.mouse_entered.connect(func(): Audio.sfx("ui_hover", -14.0); b.grab_focus())
		_choices.add_child(b)
	_choice_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.shot_args.has("auto"):
		get_tree().create_timer(0.4).timeout.connect(func(): _pick(0))
	var i: int = await _chosen
	return i


func _pick(i: int) -> void:
	Audio.sfx("ui_click", -8.0)
	_choice_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_chosen.emit(i)
