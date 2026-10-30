class_name Shelter
extends Node3D
## Halcyon Assured Shelter No. 9, dug into the hill behind the portal (world coords, tunnel runs +X).
## before: bright, cheerful, freshly opened. after: dark, red emergency light, Bloom crystals through a breach.

const Y_TOP := Layout.GATE_Y   # entry hall floor
const Y_LOW := 20.0            # main level floor
const BREACH_X := 218.2        # after: hole in Ward A's north wall, between bunks 21 and 22

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
	# the ceiling ends 1 cm inside the walls' outer faces (0.15 past the wall lines): any wider and it pokes out as a
	# ledge into the neighbouring room whose wall this room shares; flush, its end face z-fights on that wall
	Geo.box(self, Vector3((x0 + x1) * 0.5, y + h + 0.15, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.28, 0.3, z1 - z0 + 0.28), m_ceiling, true, "concrete")
	var walls := {
		"n": [Vector3(x0, y, z0), Vector3(x1, y, z0)],
		"e": [Vector3(x1, y, z0), Vector3(x1, y, z1)],
		"s": [Vector3(x1, y, z1), Vector3(x0, y, z1)],
		"w": [Vector3(x0, y, z1), Vector3(x0, y, z0)],
	}
	for side: String in walls:
		if side in skip:
			continue
		var ops := []
		for o in openings:
			if o.side == side:
				ops.append({"at": o.at, "w": o.w, "y0": 0.0, "y1": o.get("h", 2.4)})
		# walls are built with the inner side (left of a->b) facing the room; a->b runs clockwise viewed from above
		_wall2(walls[side][0], walls[side][1], h, ops)


## Two-tone wall run a->b (room on the left of a->b viewed from above): teal lower band, cream upper band, and an
## amber rail between them. The rail is split at openings so it never runs across a doorway.
func _wall2(a: Vector3, b: Vector3, h: float, ops: Array) -> void:
	var low_h := 1.25
	var ops_low := []
	var ops_up := []
	for o in ops:
		ops_low.append({"at": o.at, "w": o.w, "y0": 0.0, "y1": minf(o.y1, low_h) + 0.01})
		if o.y1 > low_h:
			ops_up.append({"at": o.at, "w": o.w, "y0": 0.0, "y1": o.y1 - low_h})
	Geo.wall(self, a, b, low_h, 0.3, m_lower, m_lower, ops_low, "concrete")
	Geo.wall(self, a + Vector3(0, low_h, 0), b + Vector3(0, low_h, 0), h - low_h, 0.3, m_upper, m_upper, ops_up, "concrete")
	var rail := Mats.color(Color(0.85, 0.6, 0.15) if not after else Color(0.45, 0.35, 0.15), 0.5)
	var d := b - a
	d.y = 0.0
	var length := d.length()
	var dir := d / length
	var cuts := []
	for o in ops:
		if o.y1 > low_h - 0.06:
			cuts.append([o.at - o.w * 0.5, o.at + o.w * 0.5])
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var s := 0.0
	cuts.append([length, length])
	for c: Array in cuts:
		if c[0] > s + 0.01:
			Geo.slab(self, a + dir * s + Vector3(0, low_h - 0.03, 0), a + dir * float(c[0]) + Vector3(0, low_h - 0.03, 0), 0.06, 0.34, rail, false)
		s = maxf(s, c[1])


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
	# welcome dressing (decals 2 cm off the wall faces at z -98.8 / -91.2 / x 193.8)
	Geo.decal_quad(self, Vector3(188, y + 2.6, -98.78), Vector2(1.4, 2.1), Mats.gen("poster_shelter_aged" if after else "poster_shelter"))
	Geo.decal_quad(self, Vector3(184, y + 2.6, -91.22), Vector2(1.4, 2.1), Mats.gen("poster_civil_defense_aged" if after else "poster_civil_defense"), Vector3(0, PI, 0))
	Geo.decal_quad(self, Vector3(193.78, y + 4.2, -95), Vector2(3.0, 0.75), Mats.gen("sign_shelter9_aged" if after else "sign_shelter9"), Vector3(0, -PI * 0.5, 0))
	Props.spawn(self, "painted_wooden_bench", Vector3(186, y, -98.5), 0.0)
	spots["entry"] = Vector3(184, y, -95)
	spots["gate_inside"] = Vector3(180.5, y, -95)
	# door control panel on the hall wall, clear of the portal pier jamb (pier inner face x 179.3)
	gate_panel = Interactable.make(self, Vector3(179.75, y + 1.4, -98.4), Vector3(0.5, 0.6, 0.4), "Open", "Shelter Door")
	gate_panel.enabled = false
	Geo.box(self, Vector3(179.75, y + 1.4, -98.74), Vector3(0.4, 0.55, 0.12), Mats.color(Color(0.8, 0.65, 0.15), 0.5, 0.4), false)
	Geo.box(self, Vector3(179.75, y + 1.45, -98.67), Vector3(0.12, 0.12, 0.05), Mats.emissive(Color(1.0, 0.2, 0.1), 2.0), false)
	# ramp down: x 194..212, z -97..-93, from Y_TOP to Y_LOW
	var rise := Y_TOP - Y_LOW
	var ang := atan2(rise, 18.0)
	Geo.stairs(self, Vector3(212, Y_LOW, -95), Vector3(-1, 0, 0), rise, 18.0, 4.0, m_floor)
	var chrome := Mats.color(Color(0.85, 0.85, 0.85), 0.3, 0.9)
	for side in [-1.0, 1.0]:
		Geo.box(self, Vector3(203, Y_LOW + 4.6, -95 + side * 2.2), Vector3(18.4, 9.2, 0.4), m_upper, true)
		# handrail 0.9 m above the stair nosings, following the slope, on short wall brackets
		var hr := Geo.box(self, Vector3(203, Y_LOW + rise * 0.5 + 0.9, -95 + side * 1.9), Vector3(18.0 / cos(ang), 0.05, 0.05), chrome, false)
		hr.rotation.z = -ang
		for k in 5:
			var bx := 196.0 + k * 3.5
			Geo.box(self, Vector3(bx, Y_TOP - (bx - 194.0) / 18.0 * rise + 0.86, -95 + side * 1.95), Vector3(0.03, 0.08, 0.12), chrome, false)
	# ramp ceiling: one sloped slab 3.2 m above the stair line, from the hall's east wall into the concourse's west
	# wall (the old stepped boxes left open risers you could see the sky through)
	var ceil := Geo.box(self, Vector3(203, Y_TOP + 3.2 - rise * 0.5 + 0.15 / cos(ang), -95), Vector3(18.3 / cos(ang), 0.3, 4.4), m_ceiling, true)
	ceil.rotation.z = -ang
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
	# desk top: box top at 1.10, amber counter 1.10..1.15 (things on the counter rest at y + 1.15)
	Geo.box(self, Vector3(222, y + 1.125, -90), Vector3(3.8, 0.05, 0.9), Mats.color(Color(0.85, 0.6, 0.15), 0.4), true, "wood")
	Props.spawn(self, "clipboard", Vector3(221.5, y + 1.15, -90), 20.0, {"collide": false, "ground": true})
	Props.spawn(self, "binder_notebook", Vector3(222.6, y + 1.15, -90.1), -10.0, {"collide": false, "pick": "binder_notebook_closed"})
	Props.spawn(self, "metal_stool_01", Vector3(222, y, -89), 0.0, {"ground": true})
	Geo.decal_quad(self, Vector3(222, y + 3.4, -105.83), Vector2(2.2, 0.55), Mats.gen("logo_halcyon_color"))
	for k in 5:
		Geo.box(self, Vector3(212.45, y + 1.0, -100 + k * 0.62), Vector3(0.5, 2.0, 0.58), Mats.color(Color(0.35, 0.5, 0.48) if not after else Color(0.3, 0.32, 0.3), 0.5, 0.6), true, "metal")
	Props.spawn(self, "painted_wooden_bench", Vector3(228, y, -86.5), 180.0, {"ground": true})
	Props.spawn(self, "korean_fire_extinguisher_01", Vector3(231.6, y, -98), -90.0, {"ground": true})
	# pull station screwed to the east wall (inner face x 231.85; the picked mesh is 3 cm deep, centred)
	Props.spawn(self, "fire_alarm", Vector3(231.84, y + 1.5, -96.5), -90.0, {"collide": false, "pick": "fire_alarm"})
	Geo.decal_quad(self, Vector3(229.6, y + 2.2, -84.17), Vector2(1.2, 1.8), Mats.gen("poster_valet_mk2_aged" if after else "poster_valet_mk2"), Vector3(0, PI, 0))
	spots["concourse"] = Vector3(222, y, -95)


func _ward() -> void:
	var y := Y_LOW
	# Ward A: x 214..240, z -122..-106. The concourse's north wall (x 212..232, door at x 227) doubles as the ward's
	# south wall, so the room skips its own; the stretch x 232..240 past the concourse gets its own wall below.
	# after: the breach is a hole in the north wall at x 218.2 between bunks 21 and 22, backed by a rock pocket.
	var ops := [{"side": "s", "at": 13.0, "w": 2.4, "h": 2.6}]
	if after:
		ops.append({"side": "n", "at": BREACH_X - 214.0, "w": 1.8, "h": 2.2})
	_room(214, 240, -122, -106, y, 3.6, ops, ["s"])
	_wall2(Vector3(240, y, -106), Vector3(232, y, -106), 3.6, [])
	var linen := Mats.color(Color(0.92, 0.9, 0.85) if not after else Color(0.55, 0.52, 0.48), 0.9)
	var blanket := Mats.tex("fabric_pattern_05", 0.8, Color(0.45, 0.6, 0.62) if not after else Color(0.35, 0.38, 0.38))
	var steel := Mats.color(Color(0.42, 0.44, 0.43) if not after else Color(0.32, 0.3, 0.28), 0.4, 0.8)
	var enamel := Mats.color(Color(0.92, 0.9, 0.82) if not after else Color(0.5, 0.47, 0.4), 0.5)
	var n := 21
	for row in 2:
		for k in 7:
			var x := 216.5 + k * 3.4
			var z := -120.6 if row == 0 else -107.6  # head end of the bed (toward the wall)
			var f := 1.0 if row == 0 else -1.0       # toward the foot / the middle aisle
			var rot := 0.0 if row == 0 else 180.0
			Props.spawn(self, "old_bed_frame", Vector3(x, y, z + f), rot, {"shrink": 0.05, "ground": true})
			Geo.box(self, Vector3(x, y + 0.52, z + f), Vector3(0.8, 0.14, 1.85), linen, false)
			if not (after and randf() < 0.5):
				Geo.box(self, Vector3(x, y + 0.6, z + f * 1.3), Vector3(0.84, 0.05, 1.1), blanket, false)
			# bunk number plate on a bedside post at the head corner (was a label hanging in mid-air)
			var num := n + row * 7 + k
			var post := Vector3(x + 0.6, y, z + f * 0.05)
			Geo.box(self, post + Vector3(0, 0.74, 0), Vector3(0.05, 1.48, 0.05), steel, false)
			Geo.box(self, post + Vector3(0, 1.48, 0), Vector3(0.12, 0.03, 0.12), steel, false)
			Geo.box(self, post + Vector3(0, 1.36, f * 0.035), Vector3(0.46, 0.18, 0.02), enamel, false)
			var lbl := Label3D.new()
			lbl.text = "No. %d" % num
			lbl.font_size = 34
			lbl.pixel_size = 0.004
			lbl.modulate = Color(0.15, 0.15, 0.15) if not after else Color(0.3, 0.26, 0.22)
			lbl.position = post + Vector3(0, 1.36, f * 0.047)
			lbl.rotation.y = 0.0 if row == 0 else PI
			add_child(lbl)
			if num == 31:
				spots["bunk31"] = Vector3(x, y + 0.6, z + f)
				spots["bunk31_side"] = Vector3(x + 0.95, y, z + f)
				var cp := Vector3(x - 0.75, y, z + f * 0.4)
				spots["bunk31_crate"] = cp
				bunk31 = Interactable.make(self, Vector3(x, y + 0.7, z + f), Vector3(0.9, 0.6, 2.0), "Lie down on", "Bunk No. 31")
				bunk31.enabled = false
				var crate := Props.spawn(self, "wooden_crate_02" if Props.exists("wooden_crate_02") else "cardboard_box_01", cp, 0.0, {"scale": 0.7, "ground": true})
				spots["bunk31_crate_top"] = Vector3(cp.x, _top_of(crate), cp.z)  # June's note lies here
				# the intercom June calls on is mounted on the bunk's post, under the number plate
				var intercom := Geo.box(self, post + Vector3(0, 1.1, f * 0.055), Vector3(0.22, 0.26, 0.06), Mats.color(Color(0.75, 0.6, 0.3), 0.3, 0.8), false)
				spots["intercom"] = intercom.position
	Geo.decal_quad(self, Vector3(239.83, y + 2.0, -114), Vector2(2.0, 0.5), Mats.gen("logo_halcyon_color"), Vector3(0, -PI * 0.5, 0))
	var wl := Label3D.new()
	wl.text = "REST WARD  A"
	wl.font_size = 96
	wl.pixel_size = 0.004
	wl.modulate = Color(0.2, 0.2, 0.2) if not after else Color(0.4, 0.35, 0.3)
	wl.position = Vector3(227, y + 2.9, -106.16)
	wl.rotation.y = PI
	add_child(wl)
	spots["breach"] = Vector3(BREACH_X, y, -120.6)
	spots["ward"] = Vector3(227, y, -110)


## Top (y) of a spawned prop's bounds, in shelter coordinates (the shelter sits at the world origin).
func _top_of(n: Node3D) -> float:
	if n == null:
		return Y_LOW
	return (n.transform * Props.local_aabb(n)).end.y


func _office_storage_generator() -> void:
	var y := Y_LOW
	# warden's office x 214..222, z -84..-76 (door north wall at x 218)
	_room(214, 222, -84, -76, y, 3.4, [{"side": "n", "at": 4.0, "w": 1.4, "h": 2.3}], ["n"])
	var desk_y := y + 0.79
	if Props.exists("metal_office_desk"):
		desk_y = _top_of(Props.spawn(self, "metal_office_desk", Vector3(218, y, -78.0), 180.0, {"ground": true}))
	Props.spawn(self, "metal_stool_01", Vector3(218, y, -79.2), 0.0, {"ground": true})
	Props.spawn(self, "retro_multimeter", Vector3(217.2, desk_y, -77.8), 20.0, {"collide": false, "ground": true})
	Props.spawn(self, "office_notepads", Vector3(218.6, desk_y, -77.9), 0.0, {"collide": false, "pick": "office_notepads_yellow_pad"})
	spots["desk_top"] = Vector3(218.6, desk_y + 0.003, -78.3)  # the magazine (its 6 mm board is centred on the spot)
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
	Geo.box(self, Vector3(221.54, y + 1.0, -80), Vector3(0.6, 2.0, 0.9), Mats.color(Color(0.32, 0.38, 0.36), 0.5, 0.6), true, "metal")
	locker = Interactable.make(self, Vector3(221.0, y + 1.0, -80), Vector3(0.4, 1.6, 0.9), "Open", "Warden's Locker")
	locker.enabled = false
	spots["locker"] = Vector3(220.6, y + 0.9, -80)
	Geo.decal_quad(self, Vector3(214.18, y + 1.8, -80), Vector2(0.9, 1.35), Mats.gen("poster_shelter_aged" if after else "poster_shelter"), Vector3(0, PI * 0.5, 0))
	# storage x 222..230, z -84..-76 (door north wall at x 226)
	_room(222, 230, -84, -76, y, 3.4, [{"side": "n", "at": 4.0, "w": 1.4, "h": 2.3}], ["n"])
	# west: three long crates (1.24 m, so 1.3 m apart; they used to overlap). east: three ammo crates with their lids on
	var long_top := y + 0.46
	for k in 3:
		var lc := Props.spawn(self, "wooden_military_crate", Vector3(223.2, y, -83.15 + k * 1.3), 90.0, {"ground": true})
		if k == 1:
			long_top = _top_of(lc)
		Props.spawn(self, "old_military_crate", Vector3(228.8, y, -82.5 + k * 1.2), -90.0, {"pick": "old_military_crate_a"})
		Props.spawn(self, "old_military_crate", Vector3(228.8, y + 0.24, -82.5 + k * 1.2), -90.0, {"pick": "old_military_crate_lid_a"})
	var lid_y := y + 0.3
	Props.spawn(self, "long_life_food", Vector3(228.75, lid_y, -81.25), 0.0, {"collide": false, "pick": "long_life_food_beans"})
	Props.spawn(self, "metal_jerrycan", Vector3(226, y, -76.6), 30.0, {"ground": true})
	spots["storage"] = Vector3(226, y, -80)
	spots["fuse"] = Vector3(228.8, lid_y + 0.013, -82.5)  # the tape roll model is centred on its origin
	spots["beans"] = Vector3(228.8, lid_y, -80.1)
	spots["shelf_top"] = Vector3(223.2, long_top, -81.85)  # pep tonic on the middle long crate
	spots["storage_shelf"] = spots["shelf_top"]
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
	# main breaker on the west wall (inner face x 232.15; the box is centred on its origin, 9 cm deep, door open)
	Props.spawn(self, "power_box_01", Vector3(232.2, y + 1.25, -86.0), 90.0, {"collide": false})
	fusebox = Interactable.make(self, Vector3(232.45, y + 1.25, -86.0), Vector3(0.5, 0.6, 0.6), "Insert Fuse into", "Main Breaker")
	fusebox.enabled = false
	spots["fusebox"] = Vector3(232.45, y + 1.25, -86.0)
	Props.spawn(self, "metal_tool_chest", Vector3(243.6, y, -98.5), -90.0, {"ground": true})
	Props.spawn(self, "WetFloorSign_01", Vector3(235, y, -97), 30.0, {"ground": true})


func _lighting() -> void:
	var fl_mat := StandardMaterial3D.new()
	fl_mat.albedo_color = Color(0.95, 0.98, 1.0)
	fl_mat.emission_enabled = true
	fl_mat.emission = Color(0.85, 0.95, 1.0)
	fl_mat.emission_energy_multiplier = 3.0
	fluoro_mats.append(fl_mat)
	# ceiling fixtures: [x, z, ceiling underside y, ceiling slope (rad, about z)]; each hangs flush under its ceiling
	var ramp_ang := atan2(Y_TOP - Y_LOW, 18.0)
	var points := [
		[183.0, -95.0, Y_TOP + 5.45, 0.0], [190.0, -95.0, Y_TOP + 5.45, 0.0], [203.0, -95.0, Y_TOP + 3.2 - (Y_TOP - Y_LOW) * 0.5, -ramp_ang],
		[217.0, -95.0, Y_LOW + 4.5, 0.0], [227.0, -95.0, Y_LOW + 4.5, 0.0], [222.0, -88.0, Y_LOW + 4.5, 0.0], [222.0, -102.0, Y_LOW + 4.5, 0.0],
		[219.0, -114.0, Y_LOW + 3.6, 0.0], [227.0, -114.0, Y_LOW + 3.6, 0.0], [235.0, -114.0, Y_LOW + 3.6, 0.0],
		[218.0, -80.0, Y_LOW + 3.4, 0.0], [226.0, -80.0, Y_LOW + 3.4, 0.0], [238.0, -92.0, Y_LOW + 4.0, 0.0],
	]
	for i in points.size():
		var pt: Array = points[i]
		var fix := Node3D.new()
		add_child(fix)
		fix.position = Vector3(pt[0], pt[2], pt[1])
		fix.rotation.z = pt[3]
		Geo.box(fix, Vector3(0, -0.03, 0), Vector3(1.4, 0.06, 0.3), m_metal, false)
		Geo.box(fix, Vector3(0, -0.075, 0), Vector3(1.3, 0.05, 0.22), fl_mat, false)
		var l := OmniLight3D.new()
		l.light_color = Color(0.9, 0.95, 1.0)
		l.light_energy = 1.6
		l.omni_range = 9.0
		l.omni_attenuation = 1.0
		l.shadow_enabled = i >= 2 and i % 2 == 0
		add_child(l)
		l.position = fix.position + Vector3(0, -0.38, 0)
		lights_main.append(l)
	# emergency lights (red, pulsing) for the after era: [point on a wall face, the wall's normal into the room]
	var mounts := [
		[Vector3(186, Y_TOP + 4.0, -98.8), Vector3(0, 0, 1)], [Vector3(203, Y_LOW + 5.4, -97.0), Vector3(0, 0, 1)],
		[Vector3(213, Y_LOW + 3.0, -105.85), Vector3(0, 0, 1)], [Vector3(231.85, Y_LOW + 3.0, -92), Vector3(-1, 0, 0)],
		[Vector3(239.85, Y_LOW + 3.0, -107), Vector3(-1, 0, 0)], [Vector3(215, Y_LOW + 3.0, -121.85), Vector3(0, 0, 1)],
		[Vector3(221.85, Y_LOW + 2.8, -77), Vector3(-1, 0, 0)],
	]
	for m: Array in mounts:
		var wp: Vector3 = m[0]
		var nrm: Vector3 = m[1]
		var el := OmniLight3D.new()
		el.light_color = Color(1.0, 0.18, 0.1)
		el.light_energy = 0.0
		el.omni_range = 8.0
		el.shadow_enabled = false
		add_child(el)
		el.position = wp + nrm * 0.3
		lights_emergency.append(el)
		Geo.box(self, wp + nrm * 0.1, Vector3(0.2, 0.12, 0.2), Mats.emissive(Color(1.0, 0.15, 0.08), 1.5), false)
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
	# debris in the ward's middle aisle (clear of the bunks), crystals pouring through the breach
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 14:
		var p := Vector3(rng.randf_range(214.6, 239.2), Y_LOW, rng.randf_range(-118.0, -110.4))
		Props.spawn(self, ["cardboard_box_01", "trashbag", "can_rusted", "plastic_bottle_gallon"][i % 4], p, rng.randf() * 360.0, {"collide": i % 4 == 0, "scale": 0.8, "ground": true})
	_breach(rng)
	if ResourceLoader.exists("res://src/actors/fx/bloom_kit.gd"):
		# a few Bloom flowers on the floors of the ward and the concourse
		for i in 5:
			var f: Node3D = BloomKit.make_bloom_flower(rng, rng.randf_range(0.6, 1.2))
			add_child(f)
			if i < 3:
				f.position = Vector3(rng.randf_range(214.6, 239.2), Y_LOW, rng.randf_range(-118.0, -110.4))
			else:
				f.position = Vector3(rng.randf_range(213.0, 231.0), Y_LOW, rng.randf_range(-105.0, -85.0))


## after: the hole in Ward A's north wall (x BREACH_X +-0.9, 2.2 m tall) opens into a pocket of dark rock packed
## with Bloom crystals, so the breach reads as rock and crystal rather than a window onto the outside.
func _breach(rng: RandomNumberGenerator) -> void:
	var b := spots["breach"] as Vector3
	var rock := Mats.tex("rock_face", 1.2, Color(0.2, 0.18, 0.22))
	var zw := -122.15  # outer face of the north wall
	# pocket: back, sides, roof and a rubble floor, all overlapping the wall so no seam shows
	Geo.box(self, Vector3(b.x, Y_LOW + 1.3, zw - 1.9), Vector3(3.2, 3.0, 0.4), rock, true)
	for sx in [-1.0, 1.0]:
		Geo.box(self, Vector3(b.x + sx * 1.3, Y_LOW + 1.3, zw - 1.0), Vector3(0.6, 3.0, 2.2), rock, true)
	Geo.box(self, Vector3(b.x, Y_LOW + 2.55, zw - 1.0), Vector3(3.2, 0.5, 2.2), rock, true)
	Geo.box(self, Vector3(b.x, Y_LOW - 0.1, zw - 1.0), Vector3(3.2, 0.4, 2.2), rock, true)
	# broken chunks jutting into the opening and spilling onto the ward floor
	for i in 7:
		var s := rng.randf_range(0.3, 0.6)
		var c := Geo.box(self, Vector3(b.x + rng.randf_range(-0.9, 0.9), Y_LOW + s * 0.35, zw - rng.randf_range(0.2, 1.4)), Vector3(s, s * 0.8, s), rock, false)
		c.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
	for i in 5:
		var s2 := rng.randf_range(0.12, 0.3)
		var d := Geo.box(self, Vector3(b.x + rng.randf_range(-1.1, 1.1), Y_LOW + s2 * 0.3, rng.randf_range(-121.75, -120.9)), Vector3(s2, s2 * 0.7, s2), rock, false)
		d.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
	if ResourceLoader.exists("res://src/actors/fx/bloom_kit.gd"):
		# crystals: packed in the pocket, a few pushing out through the hole (kept between bunks 21 and 22)
		for i in 9:
			var c2: Node3D = BloomKit.make_crystal_cluster(rng, rng.randf_range(0.6, 1.4) if i < 5 else rng.randf_range(0.5, 0.9))
			add_child(c2)
			var cz := rng.randf_range(zw - 1.6, zw - 0.3) if i < 5 else rng.randf_range(-121.8, -120.9)
			c2.position = Vector3(b.x + rng.randf_range(-0.9, 0.9) * (1.0 if i < 5 else 0.7), Y_LOW, cz)
			c2.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.65, 0.4, 1.0)
	glow.light_energy = 1.5
	glow.omni_range = 7.0
	add_child(glow)
	glow.position = Vector3(b.x, Y_LOW + 1.2, -121.0)
	var inner := OmniLight3D.new()
	inner.light_color = Color(0.7, 0.45, 1.0)
	inner.light_energy = 1.0
	inner.omni_range = 2.5
	add_child(inner)
	inner.position = Vector3(b.x, Y_LOW + 1.4, zw - 1.0)
