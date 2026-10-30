class_name SureShot
extends CanvasLayer
## Halcyon SureShot(tm) targeting: time nearly stops, enemy body parts show hit chances,
## queue shots with Focus, then watch them play out in slow motion.

const COST := 25.0
const SLOW := 0.04

var player: Player
var active := false
var executing := false
var targets: Array = []  # visible enemies sorted by screen distance to centre
var target_idx := 0
var queue: Array = []  # [{enemy, part, chance}]
var _overlay: ColorRect
var _labels: Control
var _info: Label
var _prev_focus := 0.0


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float amt = 0.0;
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 g = mix(c, vec3(l) * vec3(0.85, 1.0, 1.08), 0.75);
	float v = smoothstep(0.85, 0.3, length(UV - 0.5));
	g *= mix(0.55, 1.0, v);
	float scan = 0.96 + 0.04 * sin(SCREEN_UV.y * 900.0);
	COLOR = vec4(mix(c, g * scan, amt), 1.0);
}"""
	sm.shader = sh
	_overlay.material = sm
	_overlay.visible = false
	add_child(_overlay)
	_labels = Control.new()
	_labels.set_anchors_preset(Control.PRESET_FULL_RECT)
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.draw.connect(_draw)
	add_child(_labels)
	_info = Label.new()
	_info.anchor_left = 0.5
	_info.anchor_right = 0.5
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = -400
	_info.offset_right = 400
	_info.offset_top = -190
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_color", Color(0.6, 0.92, 1.0))
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_info.add_theme_constant_override("outline_size", 5)
	_info.visible = false
	add_child(_info)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or executing:
		return
	if event.is_action_pressed("sureshot"):
		if active:
			_cancel()
		elif player.controls_enabled():
			_enter()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event.is_action_pressed("execute") or event.is_action_pressed("interact"):
		_execute()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_RIGHT:
			_cycle(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle(-1)
	elif event.is_action_pressed("move_right"):
		_cycle(1)
	elif event.is_action_pressed("move_left"):
		_cycle(-1)
	else:
		for i in 4:
			if event.is_action_pressed("choice_%d" % (i + 1)):
				var parts := _parts_of(_cur())
				if i < parts.size():
					_queue(_cur(), parts[i])
	get_viewport().set_input_as_handled()


func _cur() -> Node:
	if targets.is_empty():
		return null
	return targets[clampi(target_idx, 0, targets.size() - 1)]


func _gather() -> void:
	targets.clear()
	var cam := player.cam
	var vp := get_viewport().get_visible_rect().size
	var space := player.get_world_3d().direct_space_state
	var scored := []
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if not e.get("alive") or e.get("dormant"):
			continue
		var p: Vector3 = (e as Node3D).global_position + Vector3(0, 0.8, 0)
		if cam.is_position_behind(p) or p.distance_to(cam.global_position) > 70.0:
			continue
		var s := cam.unproject_position(p)
		if s.x < 0 or s.y < 0 or s.x > vp.x or s.y > vp.y:
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
		if not space.intersect_ray(q).is_empty():
			continue
		scored.append([s.distance_to(vp * 0.5), e])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	for s2 in scored:
		targets.append(s2[1])


func _enter() -> void:
	if player.weapons.current == "":
		Game.toast.emit("SureShot needs a weapon drawn  [1] [2]")
		return
	if Game.focus < COST:
		Audio.sfx("sureshot_fail", -4.0)
		Game.toast.emit("Not enough Focus")
		return
	_gather()
	if targets.is_empty():
		Audio.sfx("sureshot_fail", -4.0)
		Game.toast.emit("SureShot: no targets in view")
		return
	active = true
	Game.set_flag("_sureshot_active", true)
	_prev_focus = Game.focus
	target_idx = 0
	queue.clear()
	Audio.sfx("sureshot_enter", 0.0, 0.0)
	_overlay.visible = true
	_info.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float): (_overlay.material as ShaderMaterial).set_shader_parameter("amt", v), 0.0, 1.0, 0.25)
	tw.tween_method(func(v: float): Engine.time_scale = v, 1.0, SLOW, 0.25)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_aim_at_current()


func _aim_at_current() -> void:
	var e := _cur()
	if e and is_instance_valid(e):
		var tw := player.look_toward((e as Node3D).global_position + Vector3(0, 0.9, 0), 0.25)
		tw.set_speed_scale(1.0 / maxf(Engine.time_scale, 0.01))


func _cycle(d: int) -> void:
	if targets.is_empty():
		return
	target_idx = wrapi(target_idx + d, 0, targets.size())
	Audio.sfx("sureshot_target", -6.0, 0.0)
	_aim_at_current()


func _parts_of(e: Node) -> PackedStringArray:
	if e == null or not is_instance_valid(e) or e.get("model") == null:
		return PackedStringArray()
	return e.get("model").call("get_parts")


func chance(e: Node, part: String) -> float:
	var d: float = (e as Node3D).global_position.distance_to(player.global_position)
	var base := 0.95 - d * 0.012
	var size_mult: float = {"head": 0.7, "thorns": 0.8, "legs": 0.85, "leg_l": 0.8, "leg_r": 0.8, "arm_l": 0.78, "arm_r": 0.78}.get(part, 1.0)
	var c := base * size_mult
	if player.weapons.current == "rifle":
		c += 0.1
	if Game.magazines.has("steady_hand"):
		c += 0.1
	if Game.traits.has("keen"):
		c += 0.05
	return clampf(c, 0.05, 0.95)


func _queue(e: Node, part: String) -> void:
	var ammo_left: int = player.weapons.mags[player.weapons.current]
	if Game.focus < COST or queue.size() >= ammo_left:
		Audio.sfx("sureshot_fail", -4.0, 0.0)
		return
	Game.set_focus(Game.focus - COST)
	queue.append({"enemy": e, "part": part, "chance": chance(e, part)})
	Audio.sfx("sureshot_queue", -4.0, 0.0)


func _click(pos: Vector2) -> void:
	var e := _cur()
	if e == null:
		return
	var best := ""
	var bd := 60.0
	for part in _parts_of(e):
		var n: Node3D = e.get("model").call("get_part_node", part)
		if n == null:
			continue
		var s := player.cam.unproject_position(n.global_position)
		var dd := s.distance_to(pos)
		if dd < bd:
			bd = dd
			best = part
	if best != "":
		_queue(e, best)
	else:
		# clicking another enemy selects it
		for i in targets.size():
			var t: Node3D = targets[i]
			if is_instance_valid(t) and player.cam.unproject_position(t.global_position + Vector3(0, 0.9, 0)).distance_to(pos) < 80.0:
				target_idx = i
				_aim_at_current()


func _cancel() -> void:
	Game.set_focus(_prev_focus)
	queue.clear()
	_exit()


func _exit() -> void:
	active = false
	Game.set_flag("_sureshot_active", false)
	Audio.sfx("sureshot_exit", -2.0, 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float): (_overlay.material as ShaderMaterial).set_shader_parameter("amt", v), 1.0, 0.0, 0.3)
	tw.tween_method(func(v: float): Engine.time_scale = v, Engine.time_scale, 1.0, 0.3)
	tw.chain().tween_callback(func(): _overlay.visible = false)
	_info.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _execute() -> void:
	if queue.is_empty():
		_cancel()
		return
	executing = true
	_info.visible = false
	Engine.time_scale = 0.3
	var shots := queue.duplicate()
	queue.clear()
	var last_kill: Node3D = null
	for s in shots:
		var e: Node3D = s.enemy
		if not is_instance_valid(e) or not e.get("alive"):
			continue
		var n: Node3D = e.get("model").call("get_part_node", s.part)
		var aim: Vector3 = n.global_position if n != null else e.global_position + Vector3(0, 0.9, 0)
		var tw := player.look_toward(aim, 0.12)
		tw.set_speed_scale(1.0 / maxf(Engine.time_scale, 0.01))
		await get_tree().create_timer(0.14, true, false, true).timeout
		if not is_instance_valid(e):
			continue
		n = e.get("model").call("get_part_node", s.part)
		aim = n.global_position if n != null else aim
		var hit := randf() < float(s.chance)
		var crit := randf() < 0.2
		var mult := 1.0 + (0.5 if crit and Game.magazines.has("detective") else (0.25 if crit else 0.0))
		player.weapons.call("fire_at", aim, hit, mult)
		if is_instance_valid(e) and not e.get("alive"):
			last_kill = e
		await get_tree().create_timer(0.38 if player.weapons.current == "pistol" else 1.0, true, false, true).timeout
	if last_kill != null:
		# kill-cam beat
		Engine.time_scale = 0.12
		await get_tree().create_timer(0.9, true, false, true).timeout
	executing = false
	_exit()


func _process(_delta: float) -> void:
	_labels.queue_redraw()
	if active:
		var e := _cur()
		var name := ""
		if e != null and is_instance_valid(e):
			name = String(e.get("kind")).capitalize()
		_info.text = "SURESHOT  ·  %s  ·  Queued %d   ·   [1-4]/Click part  ·  [A/D] target  ·  [SPACE] execute  ·  [Q] cancel" % [name, queue.size()]
		# drop dead targets
		targets = targets.filter(func(t): return is_instance_valid(t) and t.get("alive"))
		if targets.is_empty() and not executing:
			_cancel()


func _draw() -> void:
	if not active or player == null:
		return
	var font := ThemeDB.fallback_font
	var cyan := Color(0.55, 0.92, 1.0)
	for i in targets.size():
		var t: Node3D = targets[i]
		if not is_instance_valid(t):
			continue
		var s := player.cam.unproject_position(t.global_position + Vector3(0, 0.9, 0))
		if i == target_idx:
			_labels.draw_arc(s, 46.0, 0, TAU, 32, Color(cyan.r, cyan.g, cyan.b, 0.5), 2.0)
		else:
			_labels.draw_arc(s, 30.0, 0, TAU, 24, Color(1, 1, 1, 0.25), 1.5)
	var e := _cur()
	if e == null or not is_instance_valid(e):
		return
	var parts := _parts_of(e)
	for k in parts.size():
		var part := parts[k]
		var n: Node3D = e.get("model").call("get_part_node", part)
		if n == null:
			continue
		var s2 := player.cam.unproject_position(n.global_position)
		var c := chance(e, part)
		var queued := 0
		for q in queue:
			if q.enemy == e and q.part == part:
				queued += 1
		var label := "%d  %s  %d%%" % [k + 1, part.replace("_", " ").to_upper(), int(c * 100)]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 16
		var r := Rect2(s2 + Vector2(14, -14), Vector2(w, 26))
		_labels.draw_rect(r, Color(0.02, 0.08, 0.1, 0.75))
		_labels.draw_rect(r, cyan, false, 1.5)
		_labels.draw_line(s2, r.position + Vector2(0, 13), Color(cyan.r, cyan.g, cyan.b, 0.6), 1.0)
		_labels.draw_circle(s2, 4.0, cyan)
		_labels.draw_string(font, r.position + Vector2(8, 19), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1))
		for qn in queued:
			_labels.draw_circle(r.position + Vector2(w + 10 + qn * 12, 13), 4.5, Color(1.0, 0.8, 0.3))
