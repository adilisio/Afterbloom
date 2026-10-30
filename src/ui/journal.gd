extends CanvasLayer
## The Field Journal (Tab): a leather notebook with tabs for Quests, Items, Magazines, Character and Radio.

const INK := Color(0.16, 0.12, 0.09)
const INK_SOFT := Color(0.3, 0.24, 0.18)
const RED := Color(0.6, 0.15, 0.1)

var _root: Control
var _page: VBoxContainer
var _tab := "quests"
var _tabs := {}
var _open := false
var _font_title: Font
var _font_hand: Font
var _font_type: Font


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font_title = _sys(["Georgia"], 700)
	_font_hand = _sys(["Ink Free", "Segoe Print", "Georgia"], 400)
	_font_type = _sys(["Courier New"], 600)
	_build()
	_root.visible = false


func _sys(names: Array, w: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = w
	return f


func _tex(name: String) -> Texture2D:
	var p := "res://assets/textures/gen/%s.png" % name
	return load(p) if ResourceLoader.exists(p) else null


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	# leather cover
	var cover := PanelContainer.new()
	var lsb := StyleBoxTexture.new()
	lsb.texture = _tex("ui_leather")
	lsb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	lsb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	lsb.set_content_margin_all(26)
	if lsb.texture == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.25, 0.15, 0.1)
		flat.set_content_margin_all(26)
		cover.add_theme_stylebox_override("panel", flat)
	else:
		cover.add_theme_stylebox_override("panel", lsb)
	cover.set_anchors_preset(Control.PRESET_CENTER)
	cover.offset_left = -640
	cover.offset_right = 640
	cover.offset_top = -380
	cover.offset_bottom = 380
	_root.add_child(cover)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	cover.add_child(hb)
	# tab column
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(150, 0)
	tabs.add_theme_constant_override("separation", 8)
	hb.add_child(tabs)
	var heading := Label.new()
	heading.text = "Field\nJournal"
	heading.add_theme_font_override("font", _font_title)
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	tabs.add_child(heading)
	for t in [["quests", "Quests", "icon_quests"], ["items", "Items", "icon_items"], ["mags", "Magazines", "icon_mags"], ["char", "Character", "icon_settings"], ["radio", "Radio", "icon_radio"]]:
		var b := Button.new()
		b.text = "  " + t[1]
		b.icon = _tex(t[2])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_font_override("font", _font_title)
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 0.75))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
		var id: String = t[0]
		b.pressed.connect(func(): Audio.sfx("page_turn", -6.0); show_tab(id))
		tabs.add_child(b)
		_tabs[id] = b
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var hint := Label.new()
	hint.text = "[Tab] close"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 0.5))
	tabs.add_child(hint)
	# paper page
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var psb := StyleBoxTexture.new()
	psb.texture = _tex("ui_paper")
	psb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	psb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	psb.set_content_margin_all(30)
	if psb.texture == null:
		var flat2 := StyleBoxFlat.new()
		flat2.bg_color = Color(0.95, 0.9, 0.8)
		flat2.set_content_margin_all(30)
		paper.add_theme_stylebox_override("panel", flat2)
	else:
		paper.add_theme_stylebox_override("panel", psb)
	hb.add_child(paper)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 8)
	scroll.add_child(_page)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if _open:
			close()
		elif Game.input_locked == 0 and not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if get_parent().get("player") == null:
		return
	_open = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.sfx("journal_open", -4.0)
	show_tab(_tab)


func close() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.sfx("journal_close", -6.0)


func _clear() -> void:
	for c in _page.get_children():
		c.queue_free()


func _h(text: String, size := 34) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font_title)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	_page.add_child(l)
	return l


func _p(text: String, col := INK_SOFT, font: Font = null, size := 20) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(900, 0)
	l.add_theme_font_override("font", font if font else _font_hand)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	_page.add_child(l)
	return l


func show_tab(id: String) -> void:
	_tab = id
	_clear()
	for k in _tabs:
		(_tabs[k] as Button).add_theme_color_override("font_color", Color(1, 0.95, 0.8) if k == id else Color(0.95, 0.85, 0.6, 0.7))
	match id:
		"quests":
			_quests()
		"items":
			_items()
		"mags":
			_mags()
		"char":
			_char()
		"radio":
			_radio()


func _quests() -> void:
	_h("Quests")
	if Game.quests.is_empty():
		_p("Nothing written down yet.")
	var ordered := Game.quests.duplicate()
	ordered.sort_custom(func(a, b): return int(a.done) < int(b.done))
	for q in ordered:
		var t := _p(("✓  " if q.done else "◆  ") + q.title, INK if not q.done else Color(0.45, 0.4, 0.35), _font_title, 26)
		if q.desc != "" and not q.done:
			_p("    " + q.desc, INK_SOFT, null, 19)
		if not q.done:
			for o in q.objectives:
				if o.done and o.optional:
					continue
				var mark := "☑" if o.done else "☐"
				_p("        %s  %s%s" % [mark, o.text, "  (optional)" if o.optional else ""], Color(0.5, 0.45, 0.4) if o.done else INK, _font_type, 18)


func _items() -> void:
	_h("Items")
	_p("Health  %d / %d        Halcyon Scrip  %d" % [int(Game.hp), int(Game.max_hp()), Game.count("scrip")], INK, _font_type, 19)
	var cats := [["aid", "Aid  (click to use)"], ["weapon", "Weapons"], ["ammo", "Ammunition"], ["key", "Keepsakes & Keys"], ["junk", "Odds & Ends"]]
	for c in cats:
		var ids := []
		for id in Game.inventory:
			if Game.ITEMS.has(id) and Game.ITEMS[id].cat == c[0] and id != "scrip":
				ids.append(id)
		if ids.is_empty():
			continue
		_h(c[1], 24)
		for id in ids:
			var b := Button.new()
			b.text = "    %s  ×%d   —   %s" % [Game.item_name(id), Game.count(id), Game.ITEMS[id].desc]
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(900, 0)
			b.add_theme_font_override("font", _font_type)
			b.add_theme_font_size_override("font_size", 17)
			b.add_theme_color_override("font_color", INK)
			b.add_theme_color_override("font_hover_color", RED)
			var item: String = id
			if c[0] == "aid":
				b.pressed.connect(func():
					if Game.use_aid(item):
						Game.toast.emit("Used " + Game.item_name(item))
					show_tab("items"))
			elif item == "june_note":
				b.pressed.connect(func(): close(); Reader.show_doc("note_june", "A note from June", ""))
			elif item == "reg_card":
				b.pressed.connect(func(): close(); Reader.show_doc("note_registrar", "Shelter Registration Card", ""))
			_page.add_child(b)


func _mags() -> void:
	_h("Magazines  —  %d of %d" % [Game.magazines.size(), Game.MAGAZINES.size()])
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	_page.add_child(grid)
	for id in Game.MAGAZINES:
		var m: Dictionary = Game.MAGAZINES[id]
		var have := Game.magazines.has(id)
		var vb := VBoxContainer.new()
		vb.custom_minimum_size = Vector2(220, 0)
		var tr := TextureRect.new()
		tr.texture = _tex("mag_" + id)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(210, 260)
		tr.modulate = Color.WHITE if have else Color(0.15, 0.13, 0.12, 0.5)
		vb.add_child(tr)
		var l := Label.new()
		l.text = (m.title + "\n" + m.perk) if have else "???\nNot yet found"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(210, 0)
		l.add_theme_font_override("font", _font_hand)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", INK if have else Color(0.5, 0.45, 0.4))
		vb.add_child(l)
		if have:
			var mid: String = id
			tr.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed:
					close()
					Reader.show_doc("mag_" + mid, m.title, "Perk:  " + m.perk, true))
		grid.add_child(vb)


func _char() -> void:
	_h("Character")
	var addr: String = Game.ADDR_WORDS.get(Game.addr, "sir")
	_p("Resident No. 31 of Halcyon Assured Shelter No. 9.  Tuppence calls you \"%s\"." % addr, INK, null, 22)
	_p("Level %d     XP %d     Next level at %s" % [Game.level, Game.xp, str(Game.XP_LEVELS[Game.level]) if Game.level < Game.XP_LEVELS.size() else "—"], INK, _font_type, 19)
	_p("Health %d / %d" % [int(Game.hp), int(Game.max_hp())], INK, _font_type, 19)
	_h("Traits", 24)
	if Game.traits.is_empty():
		_p("None yet.")
	for t in Game.traits:
		_p("  •  %s — %s" % [Game.TRAITS[t].name, Game.TRAITS[t].desc])
	_h("Perks from magazines", 24)
	if Game.magazines.is_empty():
		_p("Read magazines to learn new tricks.")
	for m in Game.magazines:
		_p("  •  %s — %s" % [Game.MAGAZINES[m].title, Game.MAGAZINES[m].perk])
	_h("Places discovered", 24)
	_p(", ".join(Game.discovered) if not Game.discovered.is_empty() else "None yet.")


func _radio() -> void:
	_h("Radio")
	var player: Node = get_parent().get("player")
	var rad: Node = player.get_node_or_null("PocketRadio") if player else null
	if Game.count("pocket_radio") == 0 or rad == null:
		_p("You don't have a radio. Maybe someone at home kept yours.")
		return
	_p("Halcyon Pocket Transistor  ·  Larkhaven Free Radio, 1340 AM", INK, _font_type, 19)
	_p("Now playing:  " + Audio.radio_title("lfr_1978"), INK_SOFT, null, 22)
	var b := Button.new()
	b.text = "Turn radio OFF" if rad.get("on") else "Turn radio ON"
	b.add_theme_font_override("font", _font_title)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", RED)
	b.flat = true
	b.pressed.connect(func(): rad.call("set_on", not rad.get("on")); show_tab("radio"))
	_page.add_child(b)
	_p("Tip: press T anywhere to toggle the radio.", INK_SOFT, null, 17)
