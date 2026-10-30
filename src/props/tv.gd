class_name StarlightTV
extends Node3D
## Halcyon Starlight console television: wooden cabinet on legs, CRT screen fed by a SubViewport
## "broadcast" (art cards + voiced segments), speaker grille, knobs, brass nameplate.

var on := true
var mode := "morning"  # morning | emergency | static
var viewport: SubViewport
var _screen_mat: ShaderMaterial
var _pic: TextureRect
var _lower: Label
var _lower_bg: ColorRect
var _cards := {}
var _seg := 0
var _busy := false
var _power := 1.0
var _hum: AudioStreamPlayer3D
var use: Interactable
var speaker: Node3D

const MORNING := [
	["tv_larkhaven_morning", "", 5.0, "LARKHAVEN MORNING  ·  CHANNEL 4"],
	["tv_anchor", "tv_m1", 0.0, "HAL BRIGHTWATER"],
	["tv_comet", "tv_m2", 0.0, "LAST NIGHT ON THE BLUFF"],
	["tv_weather_map", "tv_m3", 0.0, "TODAY: SUNNY  64°"],
	["tv_ad_starlight", "tv_ad_1", 0.0, ""],
	["tv_harbor_dust", "tv_m4", 0.0, "GULL POINT HARBOR"],
	["tv_ad_sweetcorn", "tv_ad_2", 0.0, ""],
	["tv_anchor", "tv_m5", 0.0, "HAL BRIGHTWATER"],
	["tv_ad_valet", "tv_ad_3", 0.0, ""],
]
const EMERGENCY := [
	["tv_emergency", "tv_e1", 0.0, "CIVIL DEFENSE EMERGENCY"],
	["tv_anchor_grave", "tv_e2", 0.0, "THIS IS NOT A TEST"],
	["tv_emergency", "tv_e3", 0.0, "PROCEED TO YOUR SHELTER"],
	["tv_cloud", "tv_e4", 0.0, "LIVE: LARKHAVEN BAY"],
	["tv_emergency", "", 6.0, "PROCEED TO YOUR SHELTER"],
]


func build(wood: Material, aged := false) -> void:
	var brass := Mats.color(Color(0.78, 0.6, 0.32), 0.3, 1.0)
	var dark := Mats.color(Color(0.05, 0.045, 0.04), 0.5)
	var grille := Mats.tex("fabric_pattern_05", 0.4, Color(0.75, 0.62, 0.45))
	# cabinet
	Geo.box(self, Vector3(0, 0.7, 0), Vector3(1.3, 0.78, 0.52), wood, true, "wood")
	Geo.box(self, Vector3(0, 1.1, 0), Vector3(1.34, 0.03, 0.55), wood, false)
	for lx in [-0.58, 0.58]:
		for lz in [-0.2, 0.2]:
			var leg := Geo.box(self, Vector3(lx, 0.155, lz), Vector3(0.045, 0.31, 0.045), wood, false)
			leg.rotation.z = 0.12 * signf(lx)
			for c in leg.get_children():
				c.queue_free()
	# screen bezel + CRT
	Geo.box(self, Vector3(-0.17, 0.72, 0.262), Vector3(0.8, 0.62, 0.01), dark, false)
	var crt := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.72, 0.54)
	qm.subdivide_width = 16
	qm.subdivide_depth = 12
	crt.mesh = qm
	crt.position = Vector3(-0.17, 0.72, 0.27)
	add_child(crt)
	# speaker grille + knobs + nameplate
	Geo.box(self, Vector3(0.45, 0.66, 0.262), Vector3(0.3, 0.5, 0.01), grille, false)
	for ky in [0.98, 0.9]:
		var k := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.028
		cm.bottom_radius = 0.032
		cm.height = 0.03
		k.mesh = cm
		k.material_override = brass
		k.rotation.x = PI * 0.5
		k.position = Vector3(0.38 + (ky - 0.9) * 1.5, ky - 0.0, 0.275)
		add_child(k)
	var plate := Geo.box(self, Vector3(0.45, 0.4, 0.268), Vector3(0.24, 0.05, 0.006), brass, false)
	var lbl := Label3D.new()
	lbl.text = "HALCYON  STARLIGHT"
	lbl.font_size = 22
	lbl.pixel_size = 0.0006
	lbl.modulate = Color(0.15, 0.1, 0.05)
	lbl.position = Vector3(0, 0, 0.004)
	plate.add_child(lbl)
	# broadcast viewport
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.09)
	bg.size = Vector2(640, 480)
	viewport.add_child(bg)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pic.size = Vector2(640, 480)
	_pic.pivot_offset = Vector2(320, 240)
	viewport.add_child(_pic)
	_lower_bg = ColorRect.new()
	_lower_bg.color = Color(0.05, 0.05, 0.1, 0.75)
	_lower_bg.position = Vector2(0, 392)
	_lower_bg.size = Vector2(640, 52)
	viewport.add_child(_lower_bg)
	_lower = Label.new()
	_lower.position = Vector2(24, 398)
	_lower.size = Vector2(600, 40)
	_lower.add_theme_font_size_override("font_size", 28)
	_lower.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "Arial"])
	f.font_weight = 700
	_lower.add_theme_font_override("font", f)
	viewport.add_child(_lower)
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = load("res://src/props/crt.gdshader")
	_screen_mat.set_shader_parameter("screen", viewport.get_texture())
	_screen_mat.set_shader_parameter("aged", 1.0 if aged else 0.0)
	crt.material_override = _screen_mat
	speaker = Node3D.new()
	speaker.position = Vector3(0.0, 0.8, 0.3)
	add_child(speaker)
	_hum = Audio.loop_on(speaker, "tv_static_loop", -34.0, 2.0, "TV")
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.8, 1.0)
	light.light_energy = 0.35
	light.omni_range = 3.0
	light.position = Vector3(-0.17, 0.75, 0.6)
	light.name = "ScreenLight"
	add_child(light)
	use = Interactable.make(self, Vector3(0, 0.75, 0.2), Vector3(1.3, 0.8, 0.6), "Turn Off", "Halcyon Starlight TV")
	use.used.connect(func(): set_on(not on))
	for c in ["tv_larkhaven_morning", "tv_anchor", "tv_anchor_grave", "tv_comet", "tv_weather_map", "tv_ad_starlight", "tv_ad_valet", "tv_ad_sweetcorn", "tv_harbor_dust", "tv_cloud", "tv_emergency", "tv_test_pattern", "tv_please_stand_by"]:
		var p := "res://assets/textures/gen/%s.png" % c
		if ResourceLoader.exists(p):
			_cards[c] = load(p)


func start(p_mode: String) -> void:
	mode = p_mode
	_seg = 0
	if mode == "static":
		_show("tv_please_stand_by", "")
		_screen_mat.set_shader_parameter("noise_amt", 0.55)
		Audio.loop_on(speaker, "tv_static_loop", -16.0, 2.0, "TV")
		return
	if not _busy:
		_run()


func emergency() -> void:
	mode = "emergency"
	_seg = 0
	Audio.stop_voices()
	set_on(true)


func set_on(o: bool) -> void:
	on = o
	use.verb = "Turn Off" if o else "Turn On"
	Audio.sfx_at("tv_on" if o else "tv_off", global_position + Vector3(0, 0.8, 0), -6.0, 3.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): _power = v; _screen_mat.set_shader_parameter("power", v), _power, 1.0 if o else 0.0, 0.5 if o else 0.35)
	(get_node("ScreenLight") as OmniLight3D).visible = o
	if o and not _busy:
		_run()


func _show(card: String, lower: String) -> void:
	if _cards.has(card):
		_pic.texture = _cards[card]
	_lower.text = lower
	_lower_bg.visible = lower != ""
	_pic.scale = Vector2.ONE * 1.02
	_pic.position = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_pic, "scale", Vector2.ONE * 1.12, 14.0)
	tw.parallel().tween_property(_pic, "position", Vector2(randf_range(-20, 20), randf_range(-12, 12)), 14.0)


func _run() -> void:
	_busy = true
	while on and is_inside_tree() and mode != "static":
		var list: Array = MORNING if mode == "morning" else EMERGENCY
		var seg: Array = list[_seg % list.size()]
		var cur_mode := mode
		_show(seg[0], seg[3])
		var dur: float = seg[2]
		if seg[1] != "":
			var near := get_viewport().get_camera_3d() != null and get_viewport().get_camera_3d().global_position.distance_to(global_position) < 7.0
			dur = Audio.voice(seg[1], speaker, "TV", -2.0, near) + 1.2
		elif cur_mode == "emergency":
			Audio.sfx_at("pa_chime", speaker.global_position, -4.0, 3.0, 0.0, "TV")
		var t := 0.0
		while t < dur and on and mode == cur_mode and is_inside_tree():
			await get_tree().process_frame
			t += get_process_delta_time()
		if mode == cur_mode:
			_seg += 1
	_busy = false
