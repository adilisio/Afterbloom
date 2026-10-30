class_name Reader
extends CanvasLayer
## Full-screen document viewer for magazines, notes, newspapers. Pauses the game while open.

signal closed

static var instance: Reader
var _panel: Control
var _tex: TextureRect
var _title: Label
var _body: Label
var _open := false


func _ready() -> void:
	instance = self
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	(_panel as ColorRect).color = Color(0.02, 0.015, 0.01, 0.82)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 48)
	_panel.add_child(hb)
	_tex = TextureRect.new()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.custom_minimum_size = Vector2(560, 760)
	hb.add_child(_tex)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.custom_minimum_size = Vector2(440, 0)
	hb.add_child(vb)
	var tf := SystemFont.new()
	tf.font_names = PackedStringArray(["Georgia"])
	tf.font_weight = 700
	_title = Label.new()
	_title.add_theme_font_override("font", tf)
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(0.97, 0.86, 0.62))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 24)
	_body.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_body)
	var hint := Label.new()
	hint.text = "\n[E]  Close"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.97, 0.86, 0.62, 0.6))
	vb.add_child(hint)
	_panel.visible = false


static func show_doc(tex: String, title: String, body: String, perk := false) -> void:
	if instance == null:
		return
	instance._show(tex, title, body, perk)


static func is_open() -> bool:
	return instance != null and instance._open


func _show(tex: String, title: String, body: String, perk: bool) -> void:
	var p := "res://assets/textures/gen/%s.png" % tex
	_tex.texture = load(p) if ResourceLoader.exists(p) else null
	_title.text = title
	_body.text = body
	_body.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0) if perk else Color(0.95, 0.92, 0.85))
	_panel.visible = true
	_open = true
	get_tree().paused = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.25)
	if Game.shot_args.has("auto"):
		get_tree().create_timer(0.6, true).timeout.connect(_close)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("execute"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if not _open:
		return
	_open = false
	_panel.visible = false
	get_tree().paused = false
	Audio.sfx("page_turn", -8.0)
	closed.emit()
