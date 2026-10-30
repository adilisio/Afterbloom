class_name Hud
extends CanvasLayer
## In-game HUD: compass with markers, waypoint, health/focus/ammo, XP, quest tracker & banners,
## pickup feed, subtitles, damage indicator, letterbox, fades and chapter cards.

const AMBER := Color(0.97, 0.86, 0.62)
const AMBER_DIM := Color(0.97, 0.86, 0.62, 0.55)
const RED := Color(0.92, 0.32, 0.25)
const VIOLET := Color(0.72, 0.5, 1.0)

var player: Player
var root: Control
var font_ui: Font
var font_title: Font
var font_type: Font

var _compass: Control
var _waypoint: Control
var _hp_bar: ProgressBar
var _focus_bar: ProgressBar
var _ammo: Label
var _prompt: Label
var _cross: Control
var _tracker: VBoxContainer
var _feed: VBoxContainer
var _sub_box: PanelContainer
var _sub: RichTextLabel
var _sub_t := 0.0
var _banner: VBoxContainer
var _banner_t1: Label
var _banner_t2: Label
var _xp_box: Control
var _xp_bar: ProgressBar
var _xp_lbl: Label
var _xp_t := 0.0
var _hurt: ColorRect
var _hurt_a := 0.0
var _hit_dirs: Array = []
var _fade: ColorRect
var _bars: Array[ColorRect] = []
var _card: VBoxContainer
var _hitmark: Control
var _hitmark_t := 0.0
var _hitmark_kill := false
var _vitals: Control
var _radio_lbl: Label
var enemies: Array = []  # set by world: Array of Node3D enemies for compass red ticks
var hide_all := false


func _ready() -> void:
	layer = 10
	add_to_group("hud")
	font_ui = _sysfont(["Bahnschrift", "Segoe UI"], 500)
	font_title = _sysfont(["Georgia", "Times New Roman"], 700)
	font_type = _sysfont(["Courier New", "Consolas"], 400)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var th := Theme.new()
	th.default_font = font_ui
	th.default_font_size = 20
	root.theme = th
	_build()
	Game.item_added.connect(_on_item)
	Game.xp_gained.connect(_on_xp)
	Game.leveled_up.connect(_on_level)
	Game.quest_event.connect(_on_quest_event)
	Game.quests_changed.connect(_refresh_tracker)
	Game.hp_changed.connect(func(h, m): _hp_bar.max_value = m; _hp_bar.value = h)
	Game.focus_changed.connect(func(f, m): _focus_bar.max_value = m; _focus_bar.value = f)
	Game.toast.connect(func(t): _feed_line(t, AMBER))
	Game.location_discovered.connect(_on_discovered)
	Audio.subtitle.connect(_on_subtitle)
	_refresh_tracker()


func _sysfont(names: Array, weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_LCD if false else TextServer.FONT_ANTIALIASING_GRAY
	return f


func _label(text: String, size: int, col := AMBER, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 5)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(col: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.border_color = Color(col.r, col.g, col.b, 0.6)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build() -> void:
	# vignette for damage
	_hurt = ColorRect.new()
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float amount = 0.0;
uniform float lowhp = 0.0;
void fragment() {
	vec2 c = UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(c * vec2(1.0, 0.8)));
	COLOR = vec4(0.55, 0.02, 0.02, v * clamp(amount + lowhp * (0.5 + 0.5 * sin(TIME * 4.0)) * 0.6, 0.0, 0.9));
}"""
	sm.shader = sh
	_hurt.material = sm
	root.add_child(_hurt)

	# crosshair
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_cross)
	root.add_child(_cross)
	_hitmark = Control.new()
	_hitmark.set_anchors_preset(Control.PRESET_CENTER)
	_hitmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hitmark.draw.connect(_draw_hitmark)
	root.add_child(_hitmark)

	# interaction prompt
	_prompt = _label("", 24)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-300, 60)
	_prompt.size = Vector2(600, 40)
	root.add_child(_prompt)

	# compass
	_compass = Control.new()
	_compass.anchor_left = 0.5
	_compass.anchor_right = 0.5
	_compass.anchor_top = 1.0
	_compass.anchor_bottom = 1.0
	_compass.offset_left = -320
	_compass.offset_right = 320
	_compass.offset_top = -62
	_compass.offset_bottom = -26
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	root.add_child(_compass)

	# waypoint overlay
	_waypoint = Control.new()
	_waypoint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waypoint.draw.connect(_draw_waypoint)
	root.add_child(_waypoint)

	# vitals (bottom-left health, bottom-right focus/ammo)
	_vitals = Control.new()
	_vitals.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vitals)
	var hpbox := VBoxContainer.new()
	hpbox.anchor_top = 1.0
	hpbox.anchor_bottom = 1.0
	hpbox.offset_left = 36
	hpbox.offset_top = -78
	_vitals.add_child(hpbox)
	hpbox.add_child(_label("HEALTH", 15, AMBER_DIM))
	_hp_bar = _bar(AMBER, 240, 12)
	_hp_bar.max_value = Game.max_hp()
	_hp_bar.value = Game.hp
	hpbox.add_child(_hp_bar)
	var rbox := VBoxContainer.new()
	rbox.anchor_left = 1.0
	rbox.anchor_right = 1.0
	rbox.anchor_top = 1.0
	rbox.anchor_bottom = 1.0
	rbox.offset_left = -276
	rbox.offset_top = -112
	rbox.alignment = BoxContainer.ALIGNMENT_END
	_vitals.add_child(rbox)
	_ammo = _label("", 30)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo.custom_minimum_size = Vector2(240, 0)
	rbox.add_child(_ammo)
	var fl := _label("FOCUS  [Q] SureShot", 15, AMBER_DIM)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rbox.add_child(fl)
	_focus_bar = _bar(Color(0.55, 0.85, 0.95), 240, 12)
	_focus_bar.max_value = Game.max_focus()
	_focus_bar.value = Game.focus
	rbox.add_child(_focus_bar)
	_radio_lbl = _label("", 16, AMBER_DIM)
	_radio_lbl.anchor_left = 1.0
	_radio_lbl.anchor_right = 1.0
	_radio_lbl.offset_left = -560
	_radio_lbl.offset_right = -36
	_radio_lbl.anchor_top = 1.0
	_radio_lbl.anchor_bottom = 1.0
	_radio_lbl.offset_top = -140
	_radio_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vitals.add_child(_radio_lbl)

	# XP bar (appears when gaining xp)
	_xp_box = VBoxContainer.new()
	_xp_box.anchor_left = 0.5
	_xp_box.anchor_right = 0.5
	_xp_box.anchor_top = 1.0
	_xp_box.anchor_bottom = 1.0
	_xp_box.offset_left = -170
	_xp_box.offset_right = 170
	_xp_box.offset_top = -150
	_xp_box.modulate.a = 0.0
	root.add_child(_xp_box)
	_xp_lbl = _label("", 18)
	_xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_box.add_child(_xp_lbl)
	_xp_bar = _bar(AMBER, 340, 8)
	_xp_box.add_child(_xp_bar)

	# quest tracker
	_tracker = VBoxContainer.new()
	_tracker.anchor_left = 1.0
	_tracker.anchor_right = 1.0
	_tracker.offset_left = -440
	_tracker.offset_right = -36
	_tracker.offset_top = 36
	_tracker.add_theme_constant_override("separation", 4)
	root.add_child(_tracker)

	# pickup feed
	_feed = VBoxContainer.new()
	_feed.offset_left = 36
	_feed.anchor_top = 0.5
	_feed.anchor_bottom = 0.5
	_feed.offset_top = -40
	_feed.add_theme_constant_override("separation", 2)
	root.add_child(_feed)

	# subtitles
	_sub_box = PanelContainer.new()
	_sub_box.anchor_left = 0.5
	_sub_box.anchor_right = 0.5
	_sub_box.anchor_top = 1.0
	_sub_box.anchor_bottom = 1.0
	_sub_box.offset_left = -480
	_sub_box.offset_right = 480
	_sub_box.offset_top = -200
	_sub_box.offset_bottom = -110
	_sub_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = Color(0, 0, 0, 0.0)
	_sub_box.add_theme_stylebox_override("panel", sbs)
	_sub = RichTextLabel.new()
	_sub.bbcode_enabled = true
	_sub.fit_content = true
	_sub.scroll_active = false
	_sub.add_theme_font_size_override("normal_font_size", 23)
	_sub.add_theme_font_size_override("bold_font_size", 23)
	_sub.add_theme_color_override("default_color", Color(1, 0.97, 0.9))
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_sub.add_theme_constant_override("outline_size", 6)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_box.add_child(_sub)
	_sub_box.modulate.a = 0.0
	root.add_child(_sub_box)

	# banners
	_banner = VBoxContainer.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = 120
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_banner_t1 = _label("", 20, AMBER_DIM)
	_banner_t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_t1)
	_banner_t2 = _label("", 38, AMBER, font_title)
	_banner_t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_t2)

	# letterbox bars
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if i == 0:
			bar.offset_bottom = 0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
		root.add_child(bar)
		_bars.append(bar)

	# chapter card
	_card = VBoxContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -600
	_card.offset_right = 600
	_card.offset_top = -80
	_card.offset_bottom = 80
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.modulate.a = 0.0
	root.add_child(_card)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	root.move_child(_card, root.get_child_count() - 1)


# ------------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	var show := not hide_all and player != null and Game.input_locked == 0
	_vitals.visible = show and not Game.flag("hide_vitals")
	_compass.visible = show
	_tracker.visible = show
	_waypoint.visible = show
	_cross.visible = show and not (player.weapons.call("is_aiming") and player.weapons.current == "rifle")
	_compass.queue_redraw()
	_waypoint.queue_redraw()
	_cross.queue_redraw()
	if player:
		var ft := player.focus_target
		_prompt.text = ("[E]  " + ft.prompt()) if ft != null and show else ""
		var w: String = player.weapons.current
		if w != "":
			_ammo.text = "%d / %d" % [player.weapons.mags[w], Game.count(player.weapons.DEFS[w].ammo)]
		else:
			_ammo.text = ""
		var rad: Node = player.get_node_or_null("PocketRadio")
		_radio_lbl.text = ("♪  " + Audio.radio_title("lfr_1978")) if rad != null and rad.get("on") else ""
	_hurt_a = maxf(_hurt_a - delta * 1.2, 0.0)
	var low := 1.0 - clampf(Game.hp / (Game.max_hp() * 0.3), 0.0, 1.0)
	(_hurt.material as ShaderMaterial).set_shader_parameter("amount", _hurt_a)
	(_hurt.material as ShaderMaterial).set_shader_parameter("lowhp", low if Game.hp > 0 else 0.0)
	for h in _hit_dirs:
		h.t -= delta
	_hit_dirs = _hit_dirs.filter(func(h): return h.t > 0.0)
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			create_tween().tween_property(_sub_box, "modulate:a", 0.0, 0.3)
	if _xp_t > 0.0:
		_xp_t -= delta
		if _xp_t <= 0.0:
			create_tween().tween_property(_xp_box, "modulate:a", 0.0, 0.6)
	_hitmark_t = maxf(_hitmark_t - delta, 0.0)
	_hitmark.queue_redraw()


func _draw_cross() -> void:
	var c := Color(1, 0.95, 0.85, 0.8)
	if player and player.focus_target != null:
		_cross.draw_circle(Vector2.ZERO, 4.0, c)
		return
	if player and player.weapons.current != "":
		var g := 7.0
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			_cross.draw_line(d * g, d * (g + 7.0), Color(0, 0, 0, 0.5), 3.0)
			_cross.draw_line(d * g, d * (g + 7.0), c, 1.5)
	else:
		_cross.draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1, 0.55))


func _draw_hitmark() -> void:
	if _hitmark_t <= 0.0:
		return
	var a := _hitmark_t / 0.25
	var c := (RED if _hitmark_kill else Color(1, 1, 1)) * Color(1, 1, 1, a)
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_hitmark.draw_line(d * 6.0, d * 13.0, c, 2.0)


func hitmarker(killed: bool) -> void:
	_hitmark_t = 0.25
	_hitmark_kill = killed


func _draw_compass() -> void:
	if player == null:
		return
	var w := _compass.size.x
	var h := _compass.size.y
	_compass.draw_rect(Rect2(0, h * 0.5 - 1, w, 2), Color(AMBER.r, AMBER.g, AMBER.b, 0.35))
	var fwd := player.get_look_dir()
	var yaw := atan2(fwd.x, -fwd.z)  # 0 = north (-Z), +90 east
	var span := deg_to_rad(110.0)
	var marks := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
	for deg in range(0, 360, 15):
		var rel := wrapf(deg_to_rad(deg) - yaw, -PI, PI)
		if absf(rel) > span * 0.5:
			continue
		var x := w * 0.5 + rel / (span * 0.5) * w * 0.5
		var fade := 1.0 - absf(rel) / (span * 0.5)
		if marks.has(deg):
			var s: String = marks[deg]
			var fs := 22 if s.length() == 1 else 16
			_compass.draw_string(font_ui, Vector2(x - (7 if s.length() == 1 else 11), h * 0.5 + 8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(AMBER.r, AMBER.g, AMBER.b, fade))
		else:
			_compass.draw_line(Vector2(x, h * 0.5 - 5), Vector2(x, h * 0.5 + 5), Color(AMBER.r, AMBER.g, AMBER.b, fade * 0.6), 1.5)
	# quest markers
	for t in Game.active_targets():
		var d: Vector3 = t.pos - player.global_position
		var ang := atan2(d.x, -d.z)
		var rel2 := wrapf(ang - yaw, -PI, PI)
		var cl := clampf(rel2, -span * 0.5, span * 0.5)
		var x2 := w * 0.5 + cl / (span * 0.5) * w * 0.5
		var col := AMBER if t.main else AMBER_DIM
		var pts := PackedVector2Array([Vector2(x2, h * 0.5 - 13), Vector2(x2 + 7, h * 0.5 - 6), Vector2(x2, h * 0.5 + 1), Vector2(x2 - 7, h * 0.5 - 6)])
		_compass.draw_colored_polygon(pts, col)
	# enemy ticks
	for e in enemies:
		if not is_instance_valid(e) or not e.get("alive"):
			continue
		var d2: Vector3 = (e as Node3D).global_position - player.global_position
		if d2.length() > 45.0:
			continue
		var rel3 := wrapf(atan2(d2.x, -d2.z) - yaw, -PI, PI)
		if absf(rel3) > span * 0.5:
			continue
		var x3 := w * 0.5 + rel3 / (span * 0.5) * w * 0.5
		_compass.draw_rect(Rect2(x3 - 2, h * 0.5 + 6, 4, 8), RED)


func _draw_waypoint() -> void:
	if player == null:
		return
	var cam := player.cam
	var vp := _waypoint.get_viewport_rect().size
	for t in Game.active_targets():
		if not t.main:
			continue
		var p: Vector3 = t.pos + Vector3(0, 1.0, 0)
		var dist := player.global_position.distance_to(t.pos)
		if dist < 2.5 or cam.is_position_behind(p):
			continue
		var s := cam.unproject_position(p)
		s.x = clampf(s.x, 40, vp.x - 40)
		s.y = clampf(s.y, 40, vp.y - 120)
		var a := clampf((dist - 2.5) / 4.0, 0.0, 1.0) * 0.9
		var c := Color(AMBER.r, AMBER.g, AMBER.b, a)
		var pts := PackedVector2Array([s + Vector2(0, -9), s + Vector2(7, 0), s + Vector2(0, 9), s + Vector2(-7, 0)])
		_waypoint.draw_colored_polygon(pts, Color(0, 0, 0, a * 0.4))
		_waypoint.draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.0)
		_waypoint.draw_string(font_ui, s + Vector2(-30, 26), "%d m" % int(dist), HORIZONTAL_ALIGNMENT_CENTER, 60, 15, c)
	# damage direction arcs
	for hd in _hit_dirs:
		var d: Vector3 = hd.from - player.global_position
		var fwd := player.get_look_dir()
		var ang := atan2(d.x, -d.z) - atan2(fwd.x, -fwd.z)
		var c2 := vp * 0.5
		var r := 140.0
		var dir := Vector2(sin(ang), -cos(ang))
		var col2 := Color(RED.r, RED.g, RED.b, hd.t)
		_waypoint.draw_arc(c2, r, ang - PI * 0.5 - 0.35, ang - PI * 0.5 + 0.35, 16, col2, 5.0)
		_waypoint.draw_circle(c2 + dir * (r + 10), 3, col2)


# ------------------------------------------------------------------ events

func on_player_hurt(amount: float, from: Vector3) -> void:
	_hurt_a = minf(_hurt_a + amount / 40.0, 0.8)
	_hit_dirs.append({"from": from, "t": 1.0})


func _on_item(id: String, n: int) -> void:
	var txt := Game.item_name(id)
	if n > 1:
		txt += "  (%d)" % n
	_feed_line("+  " + txt, AMBER)
	Audio.sfx("pickup_ammo" if id.begins_with("ammo") else "pickup", -6.0)


func _feed_line(text: String, col: Color) -> void:
	var l := _label(text, 19, col)
	_feed.add_child(l)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	while _feed.get_child_count() > 6:
		_feed.get_child(0).free()


func _on_xp(amount: int, _total: int) -> void:
	_xp_lbl.text = "+%d XP        LEVEL %d" % [amount, Game.level]
	_xp_bar.max_value = 1.0
	_xp_bar.step = 0.001
	var tw := create_tween()
	_xp_box.modulate.a = 1.0
	tw.tween_property(_xp_bar, "value", Game.xp_progress(), 0.6).set_trans(Tween.TRANS_CUBIC)
	_xp_t = 3.0
	Audio.sfx("xp_tick", -10.0)


func _on_level(lvl: int) -> void:
	banner("LEVEL UP", "Level %d" % lvl, 3.0)
	Audio.sting("sting_levelup")


func _on_quest_event(kind: String, title: String) -> void:
	match kind:
		"start":
			banner("QUEST STARTED", title, 3.5)
			Audio.sting("sting_quest_start", -3.0)
		"done":
			banner("QUEST COMPLETED", title, 3.5)
			Audio.sting("sting_quest_done", -3.0)
		"update":
			Audio.sfx("quest_update", -8.0)


func _on_discovered(name: String) -> void:
	banner("DISCOVERED", name, 3.5)
	Audio.sting("sting_discover", -4.0)


func banner(top: String, big: String, dur := 3.0) -> void:
	_banner_t1.text = top
	_banner_t2.text = big
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(dur)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _on_subtitle(who: String, text: String, dur: float) -> void:
	if not Game.settings.subtitles:
		return
	var name := ("[b][color=#f2d39b]%s:[/color][/b]  " % who) if who != "" else ""
	_sub.text = "[center]%s%s[/center]" % [name, text]
	_sub_t = dur + 0.4
	_sub_box.modulate.a = 1.0


func _refresh_tracker() -> void:
	for c in _tracker.get_children():
		c.queue_free()
	var q := Game.quest(Game.tracked_quest)
	if q.is_empty() or q.done:
		return
	var t := _label(q.title, 22, AMBER, font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tracker.add_child(t)
	for o in q.objectives:
		if o.done:
			continue
		var txt: String = ("☐  " if not o.done else "☑  ") + o.text
		if o.optional:
			txt = "(Optional)  " + o.text
		var l := _label(txt, 17, AMBER_DIM if o.done or o.optional else AMBER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(400, 0)
		_tracker.add_child(l)


# ------------------------------------------------------------------ cinematics

func letterbox(on: bool, dur := 0.6) -> void:
	var h := 90.0 if on else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bars[0], "offset_bottom", h, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bars[1], "offset_top", -h, dur).set_trans(Tween.TRANS_SINE)


func fade(to_alpha: float, dur := 1.0, col := Color.BLACK) -> Tween:
	_fade.color = Color(col.r, col.g, col.b, _fade.color.a)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to_alpha, dur)
	return tw


var _loading: Label


func loading(on: bool, era := "before") -> void:
	if _loading == null:
		_loading = _label("", 26, AMBER_DIM, font_title)
		_loading.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_loading.offset_left = -520
		_loading.offset_top = -90
		_loading.offset_right = -48
		_loading.offset_bottom = -40
		_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		root.add_child(_loading)
	_loading.text = ("Larkhaven, 1967 ..." if era == "before" else "Larkhaven, 1978 ...") if on else ""
	root.move_child(_loading, root.get_child_count() - 1)


func set_fade(a: float, col := Color.BLACK) -> void:
	_fade.color = Color(col.r, col.g, col.b, a)


## Big centred title card (chapter titles, "11 years later", ending). Awaitable via the returned tween.
func card(lines: Array, hold := 3.0, sizes := [56, 22]) -> Tween:
	for c in _card.get_children():
		c.queue_free()
	for i in lines.size():
		var l := _label(lines[i], sizes[mini(i, sizes.size() - 1)], AMBER if i == 0 else AMBER_DIM, font_title if i == 0 else font_ui)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card.add_child(l)
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 1.0)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 1.0)
	return tw
