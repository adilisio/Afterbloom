class_name Feedback
extends CanvasLayer
## Playtest notes: F12 grabs a screenshot, pauses, and asks for a note. Each note is saved as a JPG plus an entry in
## notes.md (for reading) and notes.jsonl (position, chapter, objective... so a dev can reproduce the view).
## Saved under <project>/playtest/<date>/ when the project folder is next to the game, else user://playtest/<date>/.

const KEY := KEY_F12

var _panel: ColorRect
var _shot: TextureRect
var _text: TextEdit
var _where: Label
var _open := false
var _img: Image
var _ctx := {}
var _was_paused := false
var _was_mouse := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	_panel.color = Color(0.02, 0.015, 0.01, 0.86)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(1100, 0)
	vb.offset_left = -550
	vb.offset_right = 550
	vb.offset_top = -380
	vb.offset_bottom = 380
	vb.add_theme_constant_override("separation", 14)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "PLAYTEST NOTE"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Hud.AMBER)
	vb.add_child(title)
	_shot = TextureRect.new()
	_shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shot.custom_minimum_size = Vector2(1100, 470)
	vb.add_child(_shot)
	_where = Label.new()
	_where.add_theme_font_size_override("font_size", 16)
	_where.add_theme_color_override("font_color", Hud.AMBER_DIM)
	vb.add_child(_where)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(1100, 130)
	_text.placeholder_text = "What's wrong (or right) here?"
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.add_theme_font_size_override("font_size", 22)
	_text.gui_input.connect(_on_text_input)
	vb.add_child(_text)
	var hint := Label.new()
	hint.text = "[Enter]  Save        [Shift+Enter]  New line        [Esc]  Discard"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Hud.AMBER_DIM)
	vb.add_child(hint)
	_panel.visible = false
	if Game.shot_args.has("feedback-test"):
		# harness self-test: take a note N seconds in, as if F12 + typing + Enter
		await get_tree().create_timer(float(Game.shot_args["feedback-test"])).timeout
		_begin()
		_text.text = "Harness test note."
		await get_tree().create_timer(0.5).timeout
		_finish(true)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if not _open and k.physical_keycode == KEY:
		get_viewport().set_input_as_handled()
		_begin()
	elif _open and k.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish(false)


func _on_text_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and not k.shift_pressed:
		_text.accept_event()
		_finish(true)


func _begin() -> void:
	# the last rendered frame, HUD included, before this panel draws over it
	_img = get_viewport().get_texture().get_image()
	_ctx = _context()
	_open = true
	_was_paused = get_tree().paused
	_was_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_shot.texture = ImageTexture.create_from_image(_img)
	_where.text = "%s   ·   %s" % [_ctx.get("chapter", ""), _ctx.get("objective", "")]
	_text.text = ""
	_panel.visible = true
	_text.grab_focus()


func _finish(save: bool) -> void:
	var note := _text.text.strip_edges()
	_panel.visible = false
	_open = false
	_text.release_focus()
	get_tree().paused = _was_paused
	Input.mouse_mode = _was_mouse
	if save:
		var n := _save(note)
		Game.toast.emit("Playtest note %d saved" % n if n > 0 else "Couldn't save the playtest note")
	_img = null
	_shot.texture = null


func _context() -> Dictionary:
	var main := get_tree().current_scene
	var d := {
		"time": Time.get_datetime_string_from_system(false, true),
		"checkpoint": Game.checkpoint,
		"chapter": _chapter(),
		"play_time_min": snappedf(Game.play_time / 60.0, 0.1),
		"game_hour": snappedf(Game.game_hour, 0.01),
		"fps": Engine.get_frames_per_second(),
		"objective": "",
	}
	var q := Game.quest(Game.tracked_quest)
	if not q.is_empty():
		d.quest = q.title
		for o in q.objectives:
			if not o.done:
				d.objective = o.text
	var w: Variant = main.get("world") if main else null
	if w is World:
		d.era = (w as World).era
		if (w as World).sky:
			d.game_hour = snappedf(float((w as World).sky.get("time_of_day")), 0.01)
			d.weather = str((w as World).sky.get("weather"))
	var p: Variant = main.get("player") if main else null
	if p is Player and is_instance_valid(p):
		var pl := p as Player
		var pos := pl.global_position
		d.pos = [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)]
		d.yaw = snappedf(rad_to_deg(pl.rotation.y), 0.1)
		d.pitch = snappedf(rad_to_deg(pl.head.rotation.x), 0.1)
		d.repro = "--shot=view --view=%.2f,%.2f,%.2f,%.1f,%.1f --era=%s --hour=%.2f" % [pos.x, pos.y, pos.z, d.yaw, d.pitch, d.get("era", "before"), d.game_hour]
	return d


func _chapter() -> String:
	for f in [["ch4", "Ch.4 Afterbloom"], ["ch3", "Ch.3 Shelter"], ["ch2", "Ch.2 The Bloom"]]:
		if Game.flag(f[0]):
			return f[1]
	return "Ch.1 Good Morning" if Game.checkpoint != "" else "Title"


## Folder for this session's notes. Prefers the project folder (so the dev sees them next to the code).
static func folder() -> String:
	var root := ""
	if OS.has_feature("editor"):
		root = ProjectSettings.globalize_path("res://")
	else:
		var up := OS.get_executable_path().get_base_dir().path_join("..")
		if FileAccess.file_exists(up.path_join("project.godot")):
			root = up.simplify_path()
	if root == "":
		root = ProjectSettings.globalize_path("user://")
	var base := root.path_join("playtest")
	var dir := base.path_join(Time.get_date_string_from_system())
	DirAccess.make_dir_recursive_absolute(dir)
	# keep Godot from importing the screenshots as project assets
	if not FileAccess.file_exists(base.path_join(".gdignore")):
		var g := FileAccess.open(base.path_join(".gdignore"), FileAccess.WRITE)
		if g:
			g.close()
	return dir


func _save(note: String) -> int:
	var dir := folder()
	var stamp := Time.get_time_string_from_system().replace(":", "")
	var file := "%s.jpg" % stamp
	var k := 2
	while FileAccess.file_exists(dir.path_join(file)):
		file = "%s_%d.jpg" % [stamp, k]
		k += 1
	if _img == null or _img.save_jpg(dir.path_join(file), 0.9) != OK:
		return 0
	_ctx.image = file
	_ctx.note = note
	var md_path := dir.path_join("notes.md")
	var md := FileAccess.open(md_path, FileAccess.READ_WRITE if FileAccess.file_exists(md_path) else FileAccess.WRITE)
	var jl_path := dir.path_join("notes.jsonl")
	var jl := FileAccess.open(jl_path, FileAccess.READ_WRITE if FileAccess.file_exists(jl_path) else FileAccess.WRITE)
	if md == null or jl == null:
		return 0
	md.seek_end()
	if md.get_position() == 0:
		md.store_string("# Playtest notes, %s\n\n" % Time.get_date_string_from_system())
	md.store_string("## %s · %s\n\n%s\n\n![](%s)\n\n" % [_ctx.time.substr(11), _ctx.chapter, note if note != "" else "_(no note)_", file])
	md.store_string("<sub>%s · objective: %s · pos %s · `%s`</sub>\n\n" % [_ctx.get("era", ""), _ctx.objective, str(_ctx.get("pos", "")), _ctx.get("repro", "")])
	jl.seek_end()
	jl.store_line(JSON.stringify(_ctx))
	md.close()
	jl.close()
	# count entries for the toast
	return FileAccess.get_file_as_string(jl_path).count("\n")
