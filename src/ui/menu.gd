extends CanvasLayer
## Title screen, pause menu and settings.

const AMBER := Color(0.97, 0.86, 0.62)

var main: Node
var _title: Control
var _pause: Control
var _settings: Control
var _bg: TextureRect
var _font_title: Font
var _font_ui: Font
var _slides := ["tv_comet", "photo_lighthouse", "poster_comet_picnic_aged", "billboard_halcyon_aged", "photo_beach"]
var _slide_i := 0
var _paused := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	_font_title = _sys(["Georgia"], 700)
	_font_ui = _sys(["Bahnschrift", "Segoe UI"], 500)
	_build_title()
	_build_pause()
	_build_settings()


func _sys(names: Array, w: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = w
	return f


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", _font_title)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(AMBER.r, AMBER.g, AMBER.b, 0.82))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.mouse_entered.connect(func(): Audio.sfx("ui_hover", -14.0); b.grab_focus())
	b.pressed.connect(func(): Audio.sfx("ui_click", -6.0); cb.call())
	return b


func _panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.025, 0.82)
	sb.border_color = Color(AMBER.r, AMBER.g, AMBER.b, 0.3)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(28)
	sb.set_corner_radius_all(4)
	return sb


# ------------------------------------------------------------------ title

func _build_title() -> void:
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_title)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_child(black)
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.modulate = Color(0.55, 0.5, 0.48)
	_title.add_child(_bg)
	var vign := ColorRect.new()
	vign.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float v = smoothstep(0.2, 0.95, length((UV - vec2(0.3, 0.5)) * vec2(1.4, 1.0))); COLOR = vec4(0.0, 0.0, 0.0, 0.25 + v * 0.65); }"
	sm.shader = sh
	vign.material = sm
	_title.add_child(vign)
	var logo := TextureRect.new()
	if ResourceLoader.exists("res://assets/textures/gen/logo_title.png"):
		logo.texture = load("res://assets/textures/gen/logo_title.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_left = 0.05
	logo.anchor_right = 0.55
	logo.anchor_top = 0.08
	logo.anchor_bottom = 0.32
	_title.add_child(logo)
	var vb := VBoxContainer.new()
	vb.anchor_left = 0.08
	vb.anchor_top = 0.42
	vb.anchor_right = 0.4
	vb.anchor_bottom = 0.9
	vb.add_theme_constant_override("separation", 8)
	_title.add_child(vb)
	var cont := _button("Continue", func(): _start(true))
	cont.name = "Continue"
	vb.add_child(cont)
	vb.add_child(_button("New Game", func(): _start(false)))
	vb.add_child(_button("Settings", func(): _open_settings()))
	vb.add_child(_button("Quit", func(): get_tree().quit()))
	var foot := Label.new()
	foot.text = "WASD move · Mouse look · E use · Tab journal · F flashlight · T radio · Esc pause"
	foot.add_theme_font_override("font", _font_ui)
	foot.add_theme_font_size_override("font_size", 16)
	foot.add_theme_color_override("font_color", Color(AMBER.r, AMBER.g, AMBER.b, 0.5))
	foot.anchor_left = 0.08
	foot.anchor_top = 0.94
	foot.anchor_right = 0.95
	_title.add_child(foot)
	_title.visible = false


func show_title() -> void:
	get_tree().paused = false
	_title.visible = true
	_pause.visible = false
	_settings.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in _title.find_children("Continue", "Button", true, false):
		(c as Button).visible = Game.has_save()
	Audio.music("title_loop", 2.0, -2.0)
	_next_slide()


func _next_slide() -> void:
	if not _title.visible:
		return
	var p := "res://assets/textures/gen/%s.png" % _slides[_slide_i % _slides.size()]
	_slide_i += 1
	if ResourceLoader.exists(p):
		_bg.texture = load(p)
	_bg.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_bg.scale = Vector2.ONE * 1.04
	_bg.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 1.0, 2.0)
	tw.parallel().tween_property(_bg, "scale", Vector2.ONE * 1.14, 12.0)
	tw.tween_property(_bg, "modulate:a", 0.0, 1.5).set_delay(-1.5)
	tw.tween_callback(_next_slide)


func _start(cont: bool) -> void:
	_title.visible = false
	Audio.music("", 1.5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if cont:
		main.call("continue_game")
	else:
		main.call("new_game")


# ------------------------------------------------------------------ pause

func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _panel_box())
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.offset_left = -220
	pc.offset_right = 220
	pc.offset_top = -210
	pc.offset_bottom = 210
	_pause.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)
	var t := Label.new()
	t.text = "Paused"
	t.add_theme_font_override("font", _font_title)
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", AMBER)
	vb.add_child(t)
	vb.add_child(_button("Resume", func(): toggle_pause()))
	vb.add_child(_button("Journal", func(): toggle_pause(); if main.journal: main.journal.call("open")))
	vb.add_child(_button("Settings", func(): _open_settings()))
	vb.add_child(_button("Quit to Title", func(): toggle_pause(); main.call("quit_to_title")))
	vb.add_child(_button("Quit to Desktop", func(): get_tree().quit()))
	_pause.visible = false


func toggle_pause() -> void:
	if _title.visible:
		return
	if _settings.visible:
		_close_settings()
		return
	_paused = not _paused
	_pause.visible = _paused
	get_tree().paused = _paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _paused else Input.MOUSE_MODE_CAPTURED
	Audio.sfx("journal_open" if _paused else "journal_close", -8.0)


func is_paused() -> bool:
	return _paused


# ------------------------------------------------------------------ settings

var _rows := {}


func _build_settings() -> void:
	_settings = Control.new()
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_settings)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(dim)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _panel_box())
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.offset_left = -360
	pc.offset_right = 360
	pc.offset_top = -330
	pc.offset_bottom = 330
	_settings.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var t := Label.new()
	t.text = "Settings"
	t.add_theme_font_override("font", _font_title)
	t.add_theme_font_size_override("font_size", 38)
	t.add_theme_color_override("font_color", AMBER)
	vb.add_child(t)
	_slider(vb, "Mouse sensitivity", "mouse_sens", 0.03, 0.4, 0.01)
	_slider(vb, "Field of view", "fov", 60.0, 100.0, 1.0)
	_slider(vb, "Master volume", "vol_master", 0.0, 1.0, 0.05)
	_slider(vb, "Music volume", "vol_music", 0.0, 1.0, 0.05)
	_slider(vb, "Effects volume", "vol_sfx", 0.0, 1.0, 0.05)
	_slider(vb, "Voice volume", "vol_voice", 0.0, 1.0, 0.05)
	_slider(vb, "Graphics quality (0 low · 2 high)", "quality", 0.0, 2.0, 1.0)
	_check(vb, "Fullscreen", "fullscreen")
	_check(vb, "Subtitles", "subtitles")
	_check(vb, "Invert mouse Y", "invert_y")
	_check(vb, "Crouch key toggles", "crouch_toggle")
	vb.add_child(_button("Back", func(): _close_settings()))
	_settings.visible = false


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_override("font", _font_ui)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	return l


func _slider(parent: Node, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	hb.add_child(_row_label(text))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(320, 24)
	s.value = float(Game.settings.get(key, lo))
	s.value_changed.connect(func(v: float):
		Game.settings[key] = int(v) if key == "quality" else v
		Game.apply_settings()
		Audio.apply_volumes()
		_apply_quality())
	hb.add_child(s)
	_rows[key] = s


func _check(parent: Node, text: String, key: String) -> void:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	hb.add_child(_row_label(text))
	var c := CheckBox.new()
	c.button_pressed = bool(Game.settings.get(key, false))
	c.toggled.connect(func(v: bool):
		Game.settings[key] = v
		Game.apply_settings())
	hb.add_child(c)
	_rows[key] = c


func _apply_quality() -> void:
	if main.world and main.world.sky and main.world.sky.has_method("set_quality"):
		main.world.sky.call("set_quality", int(Game.settings.quality))


func _open_settings() -> void:
	for k in _rows:
		var r: Control = _rows[k]
		if r is HSlider:
			(r as HSlider).set_value_no_signal(float(Game.settings[k]))
		elif r is CheckBox:
			(r as CheckBox).set_pressed_no_signal(bool(Game.settings[k]))
	_settings.visible = true
	_pause.visible = false


func _close_settings() -> void:
	Game.save_settings()
	_settings.visible = false
	if _paused:
		_pause.visible = true
