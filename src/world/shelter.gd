class_name Shelter
extends Node3D
## Halcyon Assured Shelter No. 9, dug into the hill behind the portal (world coords, tunnel runs +X).
## before: bright, cheerful, freshly opened. after: dark, red emergency light, Bloom crystals through a breach.

const Y_TOP := Layout.GATE_Y   # entry hall floor
const Y_LOW := 20.0            # main level floor

var era := "before"
var after := false
var spots := {}
var lights_main: Array[Light3D] = []
var lights_emergency: Array[OmniLight3D] = []
var fluoro_mats: Array[StandardMaterial3D] = []
var bunk31: Interactable
var terminal: Interactable
var locker: Interactable
var fusebox: Interactable
var gate_panel: Interactable
var powered := true
var _flicker_t := 0.0

var m_lower: Material
var m_upper: Material
var m_floor: Material
var m_ceiling: Material
var m_metal: Material


func build(p_era: String) -> void:
	era = p_era
	after = era == "after"
	powered = not after
	var teal := Color(0.36, 0.62, 0.6) if not after else Color(0.26, 0.38, 0.37)
	var cream := Color(0.93, 0.9, 0.8) if not after else Color(0.55, 0.52, 0.46)
	m_lower = Mats.tex("white_rough_plaster", 2.0, teal)
	m_upper = Mats.tex("white_rough_plaster", 2.5, cream)
	m_floor = Mats.tex("concrete_floor_worn_001" if not after else "damaged_concrete_floor", 3.0, Color(0.85, 0.85, 0.82))
	m_ceiling = Mats.tex("concrete_wall_008", 3.0, Color(0.8, 0.8, 0.78) if not after else Color(0.45, 0.44, 0.42))
	m_metal = Mats.tex("metal_plate", 1.5, Color(0.7, 0.72, 0.7))
	_entry_and_ramp()
	_concourse()
	_ward()
	_office_storage_generator()
	_lighting()
	if after:
		_decay()
	set_power(not after)


func contains(p: Vector3) -> bool:
	return p.x > 178.6 and p.x < 258.0 and p.z > -124.0 and p.z < -74.0 and p.y < 32.0


func spot(name: String) -> Vector3:
	return spots.get(name, Vector3.ZERO)


## Room box: floor, ceiling and 4 walls (two-tone) with openings: {side: "n"/"s"/"e"/"w", at, w, h}
func _room(x0: float, x1: float, z0: float, z1: float, y: float, h: float, openings := [], skip := []) -> void:
	Geo.box(self, Vector3((x0 + x1) * 0.5, y - 0.1, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.2, z1 - z0), m_floor, true, "concrete")
	Geo.box(self, Vector3((x0 + x1) * 0.5, y + h + 0.15, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.6, 0.3, z1 - z0 + 0.6), m_ceiling, true, "concrete")
	var walls := {
		"n": [Vector3(x0, y, z0), Vector3(x1, y, z0)],
		"e": [Vector3(x1, y, z0), Vector3(x1, y, z1)],
		"s": [Vector3(x1, y, z1), Vector3(x0, y, z1)],
		"w": [Vector3(x0, y, z1), Vector3(x0, y, z0)],
	}
	for side: String in walls:
		if side in skip:
			continue
		var a: Vector3 = walls[side][0]
		var b: Vector3 = walls[side][1]
		var ops := []
		for o in openings:
			if o.side == side:
				ops.append({"at": o.at, "w": o.w, "y0": 0.0, "y1": o.get("h", 2.4)})
		# two-tone: lower band then upper band, each its own wall run
		var low_h := 1.25
		var ops_low := []
		var ops_up := []
		for o in ops:
			ops_low.append({"at": o.at, "w": o.w, "y0": 0.0, "y1": minf(o.y1, low_h) + 0.01})
			if o.y1 > low_h:
				ops_up.append({"at": o.at, "w": o.w, "y0": 0.0, "y1": o.y1 - low_h})
		# walls are built with the inner side (left of a->b) facing the room; a->b runs clockwise viewed from above
		Geo.wall(self, a, b, low_h, 0.3, m_lower, m_lower, ops_low, "concrete")
		Geo.wall(self, a + Vector3(0, low_h, 0), b + Vector3(0, low_h, 0), h - low_h, 0.3, m_upper, m_upper, ops_up, "concrete")
		Geo.slab(self, a + Vector3(0, low_h - 0.03, 0), b + Vector3(0, low_h - 0.03, 0), 0.06, 0.34, Mats.color(Color(0.85, 0.6, 0.15) if not after else Color(0.45, 0.35, 0.15), 0.5), false)


func _entry_and_ramp() -> void:
	var y := Y_TOP
	# entry hall x 178.8..194, z -99..-91 (open at the portal end; the blast doors close it)
	Geo.box(self, Vector3(186.4, y - 0.1, -95), Vector3(15.2, 0.2, 8.0), m_floor, true, "concrete")
	Geo.box(self, Vector3(186.4, y + 5.6, -95), Vector3(15.6, 0.3, 8.6), m_ceiling, true)
	Geo.wall(self, Vector3(178.8, y, -99), Vector3(194, y, -99), 5.5, 0.4, m_upper, m_ceiling)
	Geo.wall(self, Vector3(194, y, -91), Vector3(178.8, y, -91), 5.5, 0.4, m_upper, m_ceiling)
	Geo.wall(self, Vector3(194, y, -99), Vector3(194, y, -91), 5.5, 0.4, m_upper, m_ceiling, [{"at": 4.0, "w": 4.0, "y0": 0.0, "y1": 3.2}])
	Geo.box(self, Vector3(186.4, y + 0.6, -98.8), Vector3(15.0, 1.2, 0.05), m_lower, false)
	Geo.box(self, Vector3(186.4, y + 0.6, -91.2), Vector3(15.0, 1.2, 0.05), m_lower, false)
	# welcome dressing
	Geo.decal_quad(self, Vector3(188, y + 2.6, -98.72), Vector2(1.4, 2.1), Mats.gen("poster_shelter_aged" if after else "poster_shelter"))
	Geo.decal_quad(self, Vector3(184, y + 2.6, -91.28), Vector2(1.4, 2.1), Mats.gen("poster_civil_defense_aged" if after else "poster_civil_defense"), Vector3(0, PI, 0))
	Geo.decal_quad(self, Vector3(193.75, y + 4.2, -95), Vector2(3.0, 0.75), Mats.gen("sign_shelter9_aged" if after else "sign_shelter9"), Vector3(0, -PI * 0.5, 0))
	Props.spawn(self, "painted_wooden_bench", Vector3(186, y, -98.2), 0.0)
	spots["entry"] = Vector3(184, y, -95)
	spots["gate_inside"] = Vector3(180.5, y, -95)
	gate_panel = Interactable.make(self, Vector3(179.4, y + 1.4, -98.4), Vector3(0.5, 0.6, 0.4), "Open", "Shelter Door")
	gate_panel.enabled = false
	Geo.box(self, Vector3(179.3, y + 1.4, -98.75), Vector3(0.4, 0.55, 0.12), Mats.color(Color(0.8, 0.65, 0.15), 0.5, 0.4), false)
	Geo.box(self, Vector3(179.3, y + 1.45, -98.68), Vector3(0.12, 0.12, 0.05), Mats.emissive(Color(1.0, 0.2, 0.1), 2.0), false)
	# ramp down: x 194..212, z -97..-93, from Y_TOP to Y_LOW
	var rise := Y_TOP - Y_LOW
	Geo.stairs(self, Vector3(212, Y_LOW, -95), Vector3(-1, 0, 0), rise, 18.0, 4.0, m_floor)
	for side in [-1.0, 1.0]:
		Geo.box(self, Vector3(203, Y_LOW + 4.6, -95 + side * 2.2), Vector3(18.4, 9.2, 0.4), m_upper, true)
		Geo.box(self, Vector3(203, Y_LOW + 3.0, -95 + side * 1.98), Vector3(18.0, 0.05, 0.04), Mats.color(Color(0.85, 0.85, 0.85), 0.3, 0.9), false)
	for k in 6:
		var x := 195.5 + k * 3.0
		var ch := Y_TOP + 3.2 - (x - 194.0) / 18.0 * rise
		Geo.box(self, Vector3(x, ch + 0.15, -95), Vector3(3.1, 0.3, 4.4), m_ceiling, true)
	spots["ramp_top"] = Vector3(195, Y_TOP, -95)
	spots["ramp_bottom"] = Vector3(213.5, Y_LOW, -95)


func _concourse() -> void:
	var y := Y_LOW
	# x 212..232, z -106..-84 ; openings: west (ramp), north (ward), south x2 (office, storage), east (generator)
	_room(212, 232, -106, -84, y, 4.5, [
		{"side": "w", "at": 11.0, "w": 4.0, "h": 3.2},
		{"side": "n", "at": 15.0, "w": 2.4, "h": 2.6},
		{"side": "s", "at": 14.0, "w": 1.4, "h": 2.3},
		{"side": "s", "at": 6.0, "w": 1.4, "h": 2.3},
		{"side": "e", "at": 14.0, "w": 1.6, "h": 2.4},
	])
	# reception desk, banners, lockers, benches
	Geo.box(self, Vector3(222, y + 0.55, -90), Vector3(3.6, 1.1, 0.8), Mats.tex("dark_wood", 1.0, Color(0.6, 0.45, 0.35)), true, "wood")
	Geo.box(self, Vector3(222, y + 1.12, -90), Vector3(3.8, 0.05, 0.9), Mats.color(Color(0.85, 0.6, 0.15), 0.4), false)
	Props.spawn(self, "clipboard", Vector3(221.5, y + 1.15, -90), 20.0, {"collide": false})
	Props.spawn(self, "binder_notebook", Vector3(222.6, y + 1.15, -90.1), -10.0, {"collide": false, "pick": "binder_notebook_closed"})
	Props.spawn(self, "metal_stool_01", Vector3(222, y, -89), 0.0)
	Geo.decal_quad(self, Vector3(222, y + 3.4, -105.82), Vector2(2.2, 0.55), Mats.gen("logo_halcyon_color"))
	for k in 5:
		Geo.box(self, Vector3(213.0, y + 1.0, -100 + k * 0.62), Vector3(0.5, 2.0, 0.58), Mats.color(Color(0.35, 0.5, 0.48) if not after else Color(0.3, 0.32, 0.3), 0.5, 0.6), true, "metal")
	Props.spawn(self, "painted_wooden_bench", Vector3(228, y, -86.5), 180.0)
	Props.spawn(self, "korean_fire_extinguisher_01", Vector3(231.6, y, -98), -90.0)
	Props.spawn(self, "fire_alarm", Vector3(231.8, y + 1.5, -96.5), -90.0, {"collide": false, "pick": "fire_alarm"})
	Geo.decal_quad(self, Vector3(226, y + 2.2, -84.32), Vector2(1.2, 1.8), Mats.gen("poster_valet_mk2_aged" if after else "poster_valet_mk2"), Vector3(0, PI, 0))
	spots["concourse"] = Vector3(222, y, -95)


func _ward() -> void:
	var y := Y_LOW
	# Ward A: x 214..240, z -122..-106 (door on the south wall at x 227 shared with the concourse)
	_room(214, 240, -122, -106, y, 3.6, [{"side": "s", "at": 13.0, "w": 2.4, "h": 2.6}], ["s"])
	var linen := Mats.color(Color(0.92, 0.9, 0.85) if not after else Color(0.55, 0.52, 0.48), 0.9)
	var blanket := Mats.tex("fabric_pattern_05", 0.8, Color(0.45, 0.6, 0.62) if not after else Color(0.35, 0.38, 0.38))
	var n := 21
	for row in 2:
		for k in 7:
			var x := 216.5 + k * 3.4
			var z := -120.6 if row == 0 else -107.6
			var rot := 0.0 if row == 0 else 180.0
			Props.spawn(self, "old_bed_frame", Vector3(x, y, z + (1.0 if row == 0 else -1.0)), rot, {"shrink": 0.05})
			Geo.box(self, Vector3(x, y + 0.52, z + (1.0 if row == 0 else -1.0)), Vector3(0.8, 0.14, 1.85), linen, false)
			if not (after and randf() < 0.5):
				Geo.box(self, Vector3(x, y + 0.6, z + (1.3 if row == 0 else -1.3)), Vector3(0.84, 0.05, 1.1), blanket, false)
			var num := n + row * 7 + k
			var lbl := Label3D.new()
			lbl.text = "No. %d" % num
			lbl.font_size = 48
			lbl.pixel_size = 0.004
			lbl.modulate = Color(0.15, 0.15, 0.15) if not after else Color(0.4, 0.35, 0.3)
			lbl.position = Vector3(x, y + 1.6, z - 0.25 if row == 0 else z + 0.25)
			lbl.rotation.y = 0.0 if row == 0 else PI
			add_child(lbl)
			if num == 31:
				spots["bunk31"] = Vector3(x, y + 0.6, z + (1.0 if row == 0 else -1.0))
				spots["bunk31_side"] = Vector3(x + 0.95, y, z + (1.0 if row == 0 else -1.0))
				spots["bunk31_crate"] = Vector3(x - 0.75, y, z + (0.4 if row == 0 else -0.4))
				bunk31 = Interactable.make(self, Vector3(x, y + 0.7, z + (1.0 if row == 0 else -1.0)), Vector3(0.9, 0.6, 2.0), "Lie down on", "Bunk No. 31")
				bunk31.enabled = false
				Props.spawn(self, "wooden_crate_02" if Props.exists("wooden_crate_02") else "cardboard_box_01", spots["bunk31_crate"], 0.0, {"scale": 0.7})
				var intercom := Geo.box(self, Vector3(x + 0.6, y + 1.3, z - 0.42 if row == 0 else z + 0.42), Vector3(0.25, 0.3, 0.06), Mats.color(Color(0.75, 0.6, 0.3), 0.3, 0.8), false)
				spots["intercom"] = intercom.global_position
	Geo.decal_quad(self, Vector3(239.82, y + 2.0, -114), Vector2(2.0, 0.5), Mats.gen("logo_halcyon_color"), Vector3(0, -PI * 0.5, 0))
	var wl := Label3D.new()
	wl.text = "REST WARD  A"
	wl.font_size = 96
	wl.pixel_size = 0.004
	wl.modulate = Color(0.2, 0.2, 0.2) if not after else Color(0.4, 0.35, 0.3)
	wl.position = Vector3(227, y + 2.9, -106.32)
	wl.rotation.y = PI
	add_child(wl)
	# the breach (after): a crack in the north wall with crystals pouring through
	spots["breach"] = Vector3(219.5, y, -120.5)
	spots["ward"] = Vector3(227, y, -110)


func _office_storage_generator() -> void:
	var y := Y_LOW
	# warden's office x 214..222, z -84..-76 (door north wall at x 218)
	_room(214, 222, -84, -76, y, 3.4, [{"side": "n", "at": 4.0, "w": 1.4, "h": 2.3}], ["n"])
	if Props.exists("metal_office_desk"):
		Props.spawn(self, "metal_office_desk", Vector3(218, y, -78.0), 180.0)
	Props.spawn(self, "metal_stool_01", Vector3(218, y, -79.2), 0.0)
	Props.spawn(self, "retro_multimeter", Vector3(217.2, y + 0.8, -77.8), 20.0, {"collide": false})
	Props.spawn(self, "office_notepads", Vector3(218.6, y + 0.8, -77.9), 0.0, {"collide": false, "pick": "office_notepads_yellow_pad"})
	# terminal = reel-to-reel log recorder
	var rec := Node3D.new()
	add_child(rec)
	rec.position = Vector3(215.0, y, -78.0)
	Geo.box(rec, Vector3(0, 0.6, 0), Vector3(0.7, 1.2, 0.5), Mats.color(Color(0.4, 0.45, 0.42), 0.5, 0.5), true, "metal")
	for rx in [-0.15, 0.15]:
		var reel := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.11
		cm.bottom_radius = 0.11
		cm.height = 0.02
		reel.mesh = cm
		reel.material_override = Mats.color(Color(0.15, 0.12, 0.1), 0.4)
		reel.rotation.x = PI * 0.5
		reel.position = Vector3(rx, 0.95, 0.26)
		reel.name = "reel%d" % (0 if rx < 0 else 1)
		rec.add_child(reel)
	Geo.box(rec, Vector3(0, 0.62, 0.252), Vector3(0.4, 0.12, 0.01), Mats.emissive(Color(1.0, 0.6, 0.2), 0.0), false)
	terminal = Interactable.make(rec, Vector3(0, 0.9, 0.3), Vector3(0.7, 0.6, 0.4), "Play", "Warden's Log Recorder")
	terminal.enabled = false
	spots["recorder"] = rec.global_position
	spots["office"] = Vector3(218, y, -80.5)
	# locker with the pistol
	Geo.box(self, Vector3(221.5, y + 1.0, -80), Vector3(0.6, 2.0, 0.9), Mats.color(Color(0.32, 0.38, 0.36), 0.5, 0.6), true, "metal")
	locker = Interactable.make(self, Vector3(221.0, y + 1.0, -80), Vector3(0.4, 1.6, 0.9), "Open", "Warden's Locker")
	locker.enabled = false
	spots["locker"] = Vector3(220.6, y + 0.9, -80)
	Geo.decal_quad(self, Vector3(214.18, y + 1.8, -80), Vector2(0.9, 1.35), Mats.gen("poster_shelter_aged" if after else "poster_shelter"), Vector3(0, PI * 0.5, 0))
	# storage x 222..230, z -84..-76 (door north wall at x 226)
	_room(222, 230, -84, -76, y, 3.4, [{"side": "n", "at": 4.0, "w": 1.4, "h": 2.3}], ["n"])
	for k in 3:
		Props.spawn(self, "steel_frame_shelves_01" if false else "wooden_military_crate", Vector3(223.2, y, -82.8 + k * 1.1), 90.0)
		Props.spawn(self, "old_military_crate", Vector3(228.8, y, -82.5 + k * 1.2), -90.0, {"pick": "old_military_crate_a"})
	Props.spawn(self, "long_life_food", Vector3(228.8, y + 0.27, -81.3), 0.0, {"collide": false, "pick": "long_life_food_beans"})
	Props.spawn(self, "metal_jerrycan", Vector3(226, y, -77.0), 30.0)
	spots["storage"] = Vector3(226, y, -80)
	spots["fuse"] = Vector3(228.8, y + 0.28, -82.5)
	spots["storage_shelf"] = Vector3(223.2, y + 0.75, -81.7)
	# generator room x 232..244, z -100..-84 (door west wall)
	_room(232, 244, -100, -84, y, 4.0, [{"side": "w", "at": 8.0, "w": 1.6, "h": 2.4}], ["w"])
	var gen := Node3D.new()
	add_child(gen)
	gen.position = Vector3(239.5, y, -92)
	Geo.box(gen, Vector3(0, 1.0, 0), Vector3(3.2, 2.0, 1.8), Mats.color(Color(0.4, 0.5, 0.45) if not after else Color(0.3, 0.32, 0.3), 0.5, 0.6), true, "metal")
	for gz in [-0.5, 0.0, 0.5]:
		var cyl := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.25
		cm2.bottom_radius = 0.25
		cm2.height = 1.0
		cyl.mesh = cm2
		cyl.material_override = Mats.color(Color(0.7, 0.7, 0.7), 0.3, 0.9)
		cyl.position = Vector3(-0.8, 2.4, gz)
		gen.add_child(cyl)
	Geo.decal_quad(gen, Vector3(-1.61, 1.2, 0), Vector2(1.0, 0.5), Mats.gen("logo_halcyon_color"), Vector3(0, -PI * 0.5, 0))
	spots["generator"] = Vector3(237, y, -92)
	Props.spawn(self, "power_box_01", Vector3(233.0, y + 1.0, -86.0), 90.0, {"collide": false})
	fusebox = Interactable.make(self, Vector3(233.3, y + 1.25, -86.0), Vector3(0.5, 0.6, 0.6), "Insert Fuse into", "Main Breaker")
	fusebox.enabled = false
	spots["fusebox"] = Vector3(233.3, y + 1.25, -86.0)
	Props.spawn(self, "metal_tool_chest", Vector3(243.2, y, -98.5), -90.0)
	Props.spawn(self, "WetFloorSign_01", Vector3(235, y, -97), 30.0)


func _lighting() -> void:
	var fl_mat := StandardMaterial3D.new()
	fl_mat.albedo_color = Color(0.95, 0.98, 1.0)
	fl_mat.emission_enabled = true
	fl_mat.emission = Color(0.85, 0.95, 1.0)
	fl_mat.emission_energy_multiplier = 3.0
	fluoro_mats.append(fl_mat)
	var points := [
		Vector3(183, Y_TOP + 5.3, -95), Vector3(190, Y_TOP + 5.3, -95), Vector3(203, Y_LOW + 4.6, -95),
		Vector3(217, Y_LOW + 4.3, -95), Vector3(227, Y_LOW + 4.3, -95), Vector3(222, Y_LOW + 4.3, -88), Vector3(222, Y_LOW + 4.3, -102),
		Vector3(219, Y_LOW + 3.4, -114), Vector3(227, Y_LOW + 3.4, -114), Vector3(235, Y_LOW + 3.4, -114),
		Vector3(218, Y_LOW + 3.2, -80), Vector3(226, Y_LOW + 3.2, -80), Vector3(238, Y_LOW + 3.8, -92),
	]
	for p in points:
		Geo.box(self, p + Vector3(0, 0.0, 0), Vector3(1.3, 0.05, 0.22), fl_mat, false)
		Geo.box(self, p + Vector3(0, 0.05, 0), Vector3(1.4, 0.06, 0.3), m_metal, false)
		var l := OmniLight3D.new()
		l.light_color = Color(0.9, 0.95, 1.0)
		l.light_energy = 1.6
		l.omni_range = 9.0
		l.omni_attenuation = 1.0
		l.shadow_enabled = p.y < Y_TOP and points.find(p) % 2 == 0
		add_child(l)
		l.position = p + Vector3(0, -0.3, 0)
		lights_main.append(l)
	# emergency lights (red, pulsing) for the after era
	for p in [Vector3(186, Y_TOP + 4.0, -98.6), Vector3(203, Y_LOW + 4.0, -96.8), Vector3(213, Y_LOW + 3.0, -105.6), Vector3(231.6, Y_LOW + 3.0, -92), Vector3(239.6, Y_LOW + 3.0, -107), Vector3(215, Y_LOW + 3.0, -121.6), Vector3(221.6, Y_LOW + 2.8, -77)]:
		var el := OmniLight3D.new()
		el.light_color = Color(1.0, 0.18, 0.1)
		el.light_energy = 0.0
		el.omni_range = 8.0
		el.shadow_enabled = false
		add_child(el)
		el.position = p
		lights_emergency.append(el)
		Geo.box(self, p, Vector3(0.2, 0.12, 0.2), Mats.emissive(Color(1.0, 0.15, 0.08), 1.5), false)
	# ambience
	var hum := Node3D.new()
	add_child(hum)
	hum.position = Vector3(222, Y_LOW + 2, -95)
	Audio.loop_on(hum, "amb_shelter_hum_loop", -8.0 if not after else -16.0, 12.0)
	if after:
		var drip := Node3D.new()
		add_child(drip)
		drip.position = Vector3(220, Y_LOW + 2, -115)
		Audio.loop_on(drip, "amb_shelter_drip_loop", -6.0, 8.0)


func set_power(on: bool) -> void:
	powered = on
	for l in lights_main:
		l.visible = on
	for m in fluoro_mats:
		m.emission_energy_multiplier = 3.0 if on else 0.0
	for e in lights_emergency:
		e.light_energy = 0.0 if (on and not after) else 1.4


func _process(delta: float) -> void:
	_flicker_t += delta
	if after:
		for i in lights_emergency.size():
			lights_emergency[i].light_energy = (0.9 + 0.6 * sin(_flicker_t * 2.2 + i)) if not powered else 0.25
		if powered and lights_main.size() > 4:
			var f := lights_main[4]
			f.visible = fmod(_flicker_t, 3.7) > 0.25 and fmod(_flicker_t * 7.3, 1.0) > 0.08


func _decay() -> void:
	# debris, crystals through the breach, a toppled bench
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 14:
		var p := Vector3(rng.randf_range(214, 238), Y_LOW, rng.randf_range(-121, -107))
		Props.spawn(self, ["cardboard_box_01", "trashbag", "can_rusted", "plastic_bottle_gallon"][i % 4], p, rng.randf() * 360.0, {"collide": i % 4 == 0, "scale": 0.8})
	var b := spots["breach"] as Vector3
	Geo.box(self, b + Vector3(0, 1.3, -1.4), Vector3(2.6, 2.6, 0.5), Mats.color(Color(0.05, 0.04, 0.06), 0.9), false)
	if ResourceLoader.exists("res://src/actors/fx/bloom_kit.gd"):
		for i in 9:
			var c: Node3D = BloomKit.make_crystal_cluster(rng, rng.randf_range(0.6, 1.4))
			add_child(c)
			c.global_position = b + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-0.8, 1.2))
			c.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		for i in 5:
			var f: Node3D = BloomKit.make_bloom_flower(rng, rng.randf_range(0.6, 1.2))
			add_child(f)
			f.global_position = Vector3(rng.randf_range(214, 238), Y_LOW, rng.randf_range(-121, -86))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.65, 0.4, 1.0)
	glow.light_energy = 1.5
	glow.omni_range = 7.0
	add_child(glow)
	glow.global_position = b + Vector3(0, 1.2, 0.5)
