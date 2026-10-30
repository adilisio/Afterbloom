class_name Home
extends Node3D
## The player's cottage on Gull Lane: full interior (living room with fireplace and Starlight TV, kitchen,
## bedroom, den, hall), porch and yard. era "before" (1967) or "after" (1978, tidy inside thanks to Tuppence).
## Local frame: origin = floor centre, front door faces +Z (the street). Footprint x[-7,7] z[-5,5].

const H := 2.7
const T := 0.2
const FLOOR_Y := 0.45

var era := "before"
var tv: StarlightTV
var radio: RadioSet
var front_door: Door
var back_door: Door
var phone_use: Interactable
var curtain_l: Node3D
var curtain_r: Node3D
var kettle: Node3D
var fire_light: OmniLight3D
var bed_spot: Node3D  # where the player wakes
var tuppence_spot: Node3D
var spots := {}  # named markers in world space
var indoor_area: Area3D
var lamps: Array[OmniLight3D] = []
var fill_lights: Array[OmniLight3D] = []
var _fire_t := 0.0

var m_wall_living: Material
var m_wall_bed: Material
var m_wall_kitchen: Material
var m_wall_hall: Material
var m_ext: Material
var m_trim: Material
var m_wood_floor: Material
var m_kitchen_floor: Material
var m_ceiling: Material
var m_furn_wood: Material
var m_brass: Material
var m_glass: Material


func build(p_era: String) -> void:
	era = p_era
	var after := era == "after"
	m_wall_living = Mats.wallpaper("wallpaper_living_aged" if after else "wallpaper_living", Color(0.93, 0.86, 0.72))
	m_wall_bed = Mats.wallpaper("wallpaper_bedroom_aged" if after else "wallpaper_bedroom", Color(0.85, 0.9, 0.88))
	m_wall_kitchen = Mats.wallpaper("wallpaper_kitchen_aged" if after else "wallpaper_kitchen", Color(0.98, 0.94, 0.8))
	m_wall_hall = Mats.tex("painted_plaster_wall", 2.0, Color(0.92, 0.87, 0.78) * (0.85 if after else 1.0))
	m_ext = Mats.tex("white_planks_clean", 2.0, Color(1.0, 0.9, 0.6) if not after else Color(0.72, 0.67, 0.52))
	m_trim = Mats.color(Color(0.95, 0.94, 0.9) if not after else Color(0.78, 0.76, 0.7), 0.5)
	m_wood_floor = Mats.tex("herringbone_parquet", 1.6, Color(1, 0.95, 0.88))
	m_kitchen_floor = Mats.tex("old_linoleum_flooring_01", 1.4)
	m_ceiling = Mats.tex("ceiling_interior", 2.0, Color(1, 0.98, 0.94))
	m_furn_wood = Mats.tex("dark_wood", 1.0, Color(0.95, 0.8, 0.65))
	m_brass = Mats.color(Color(0.8, 0.62, 0.34), 0.28, 1.0)
	m_glass = Mats.glass(Color(0.8, 0.88, 0.92, 0.12), false)
	_shell()
	_living_room()
	_kitchen()
	_bedroom()
	_den_and_hall()
	_exterior()
	_lights()
	_fill_lights()
	_indoor_trigger()


func spot(name: String) -> Vector3:
	return (spots[name] as Node3D).global_position if spots.has(name) else global_position


func _mark(name: String, local: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "spot_" + name
	add_child(n)
	n.position = local
	spots[name] = n
	return n


# ------------------------------------------------------------------ shell

func _shell() -> void:
	var y := FLOOR_Y
	# foundation (brick plinth) + floors
	# plinth top sits under the floor boards; a shared top face z-fought (wood/brick flicker)
	Geo.box(self, Vector3(0, (y - 0.06) * 0.5 - 0.05, 0), Vector3(14.2, y + 0.04, 10.2), Mats.tex("red_brick_03", 1.5, Color(0.85, 0.8, 0.75)), true, "concrete")
	Geo.box(self, Vector3(-3.25, y - 0.02, 0), Vector3(7.5, 0.04, 10.0), m_wood_floor, true, "wood")
	Geo.box(self, Vector3(1.6, y - 0.02, 0), Vector3(2.2, 0.04, 10.0), m_wood_floor, true, "wood")
	Geo.box(self, Vector3(4.85, y - 0.02, 2.5), Vector3(4.3, 0.04, 5.0), m_kitchen_floor, true, "wood")
	Geo.box(self, Vector3(4.85, y - 0.02, -2.5), Vector3(4.3, 0.04, 5.0), m_wood_floor, true, "wood")
	Geo.box(self, Vector3(0, y + H + 0.06, 0), Vector3(14.0, 0.12, 10.0), m_ceiling, true, "wood")
	# exterior walls (inner material per room is approximated by the dominant room on that wall)
	var win := func(at: float, w: float, y0 := 0.85, y1 := 2.2) -> Dictionary: return {"at": at, "w": w, "y0": y0, "y1": y1}
	var f := Vector3(0, y, 0)
	# front wall z=+5 (a = x 7 -> b = x -7): at = 7 - x
	var front_ops := [win.call(7 - (-4.8), 1.8), win.call(7 - (-1.9), 1.1), {"at": 7 - 1.6, "w": 1.0, "y0": 0.0, "y1": 2.15}, win.call(7 - 4.85, 1.4, 1.05, 2.1)]
	_wall_runs(f + Vector3(7, 0, 5), f + Vector3(-7, 0, 5), T, [[4.3, m_wall_kitchen], [14.0, m_wall_living]], m_ext, front_ops)
	for o in front_ops:
		if o.y0 > 0.0:
			Geo.window(self, f + Vector3(7, 0, 5), f + Vector3(-7, 0, 5), T, o, m_trim, m_glass)
	# west wall x=-7 (a z=5 -> b z=-5): at = 5 - z
	var west_ops := [win.call(5 - 4.1, 0.6, 1.0, 2.1), win.call(5 - 0.9, 0.6, 1.0, 2.1), win.call(5 - (-2.5), 1.2)]
	_wall_runs(f + Vector3(-7, 0, 5), f + Vector3(-7, 0, -5), T, [[5.0, m_wall_living], [10.0, m_wall_hall]], m_ext, west_ops)
	for o in west_ops:
		Geo.window(self, f + Vector3(-7, 0, 5), f + Vector3(-7, 0, -5), T, o, m_trim, m_glass)
	# back wall z=-5 (a x=-7 -> b x=7): at = x + 7
	var back_ops := [win.call(-5 + 7, 1.2), win.call(-1.3 + 7, 0.7, 1.4, 2.1), {"at": 1.6 + 7, "w": 0.95, "y0": 0.0, "y1": 2.15}, win.call(4.9 + 7, 1.0)]
	_wall_runs(f + Vector3(-7, 0, -5), f + Vector3(7, 0, -5), T, [[9.7, m_wall_hall], [14.0, m_wall_bed]], m_ext, back_ops)
	for o in back_ops:
		if o.y0 > 0.0:
			Geo.window(self, f + Vector3(-7, 0, -5), f + Vector3(7, 0, -5), T, o, m_trim, m_glass)
	# east wall x=7 (a z=-5 -> b z=5): at = z + 5  — big windows for the morning sun
	var east_ops := [win.call(-2.4 + 5, 1.8, 0.75, 2.25), win.call(2.6 + 5, 1.6, 1.05, 2.15)]
	_wall_runs(f + Vector3(7, 0, -5), f + Vector3(7, 0, 5), T, [[5.0, m_wall_bed], [10.0, m_wall_kitchen]], m_ext, east_ops)
	for o in east_ops:
		Geo.window(self, f + Vector3(7, 0, -5), f + Vector3(7, 0, 5), T, o, m_trim, m_glass)
	# interior walls
	var t2 := 0.12
	# x=0.5 (living|entry, bath|hall): a z=5 -> b z=-5, at = 5 - z
	Geo.wall(self, f + Vector3(0.5, 0, 5), f + Vector3(0.5, 0, -5), H, t2, m_wall_hall, m_wall_living, [{"at": 5 - 2.75, "w": 2.1, "y0": 0.0, "y1": 2.3}, {"at": 5 - (-2.5), "w": 0.9, "y0": 0.0, "y1": 2.1}])
	# x=2.7 (entry|kitchen, hall|bedroom): a z=-5 -> b z=5, at = z + 5
	Geo.wall(self, f + Vector3(2.7, 0, -5), f + Vector3(2.7, 0, 0), H, t2, m_wall_hall, m_wall_bed, [{"at": -2.0 + 5, "w": 0.95, "y0": 0.0, "y1": 2.1}])
	Geo.wall(self, f + Vector3(2.7, 0, 0), f + Vector3(2.7, 0, 5), H, t2, m_wall_hall, m_wall_kitchen, [{"at": 2.6, "w": 1.6, "y0": 0.0, "y1": 2.3}])
	# z=0 west part (living | den+bath): a x=-7 -> b x=0.5, at = x + 7
	Geo.wall(self, f + Vector3(-7, 0, 0), f + Vector3(0.5, 0, 0), H, t2, m_wall_living, m_wall_hall, [{"at": -5.0 + 7, "w": 0.95, "y0": 0.0, "y1": 2.1}])
	# z=0 east part (kitchen | bedroom): a x=2.7 -> b x=7
	Geo.wall(self, f + Vector3(2.7, 0, 0), f + Vector3(7, 0, 0), H, t2, m_wall_kitchen, m_wall_bed, [])
	# den | bath
	Geo.wall(self, f + Vector3(-3, 0, 0), f + Vector3(-3, 0, -5), H, t2, m_wall_hall, m_wall_hall, [])
	# bathroom door (closed, decorative)
	var bath := Door.make(self, f + Vector3(0.44, 0, -2.05), PI * 0.5, 0.9, 2.1, Mats.tex_local("white_planks_clean", 1.0, Color(0.95, 0.95, 0.92)), m_brass)
	bath.locked = true
	bath.locked_text = "The bathroom. Nothing to do in there right now."
	bath.use.title = "Bathroom"
	# trim: skirting + crown in each room (thin boxes along every wall run)
	_trim_runs()
	# doors
	var door_mat := Mats.tex_local("white_planks_clean", 1.0, Color(0.55, 0.75, 0.72) if not era == "after" else Color(0.45, 0.55, 0.52))
	front_door = Door.make(self, f + Vector3(1.1, 0, 5.0), 0.0, 1.0, 2.13, door_mat, m_brass)
	front_door.open_angle = 100.0
	front_door.use.title = "Front Door"
	back_door = Door.make(self, f + Vector3(2.08, 0, -5.0), PI, 0.95, 2.13, door_mat, m_brass)
	back_door.use.title = "Back Door"


## Wall a->b split into runs with different inner materials. runs: [[end_dist, inner_mat], ...] (ascending)
func _wall_runs(a: Vector3, b: Vector3, thick: float, runs: Array, outer: Material, ops: Array) -> void:
	var dir := (b - a).normalized()
	var start := 0.0
	for r in runs:
		var end: float = r[0]
		var sub_ops := []
		for o in ops:
			if o.at > start and o.at < end:
				var o2: Dictionary = o.duplicate()
				o2.at = o.at - start
				sub_ops.append(o2)
		Geo.wall(self, a + dir * start, a + dir * end, H, thick, r[1], outer, sub_ops)
		start = end


func _trim_runs() -> void:
	var y := FLOOR_Y
	var runs := [
		[Vector2(-6.9, 4.9), Vector2(0.44, 4.9)], [Vector2(-6.9, 0.06), Vector2(0.44, 0.06)], [Vector2(-6.9, 0.06), Vector2(-6.9, 4.9)],
		[Vector2(2.76, 4.9), Vector2(6.9, 4.9)], [Vector2(2.76, 0.06), Vector2(6.9, 0.06)], [Vector2(6.9, 0.06), Vector2(6.9, 4.9)],
		[Vector2(2.76, -4.9), Vector2(6.9, -4.9)], [Vector2(2.76, -0.06), Vector2(6.9, -0.06)], [Vector2(6.9, -4.9), Vector2(6.9, -0.06)],
		[Vector2(-6.9, -4.9), Vector2(-3.06, -4.9)], [Vector2(-6.9, -0.06), Vector2(-3.06, -0.06)], [Vector2(-6.9, -4.9), Vector2(-6.9, -0.06)],
	]
	for r in runs:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		Geo.slab(self, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), 0.11, 0.025, m_trim, false)
		Geo.slab(self, Vector3(a.x, y + H - 0.09, a.y), Vector3(b.x, y + H - 0.09, b.y), 0.09, 0.05, m_trim, false)


# ------------------------------------------------------------------ rooms

func _living_room() -> void:
	var y := FLOOR_Y
	var after := era == "after"
	# fireplace on the west wall
	var brick := Mats.tex("red_brick_03", 1.2, Color(0.9, 0.78, 0.7))
	Geo.box(self, Vector3(-6.72, y + 0.6, 2.5), Vector3(0.36, 1.2, 1.9), brick, true)
	Geo.box(self, Vector3(-6.56, y + 0.4, 2.5), Vector3(0.1, 0.62, 0.9), Mats.color(Color(0.04, 0.03, 0.03), 0.9), false)
	Geo.box(self, Vector3(-6.5, y + 1.25, 2.5), Vector3(0.48, 0.07, 2.15), m_furn_wood, true, "wood")
	Geo.box(self, Vector3(-6.3, y + 0.02, 2.5), Vector3(0.6, 0.04, 1.6), Mats.tex("stone_wall", 1.0, Color(0.7, 0.68, 0.66)), true)
	Geo.box(self, Vector3(-6.82, y + 1.95, 2.5), Vector3(0.16, 1.4, 1.1), brick, false)
	if not after:
		var logs := Mats.tex("dark_wood", 0.6, Color(0.5, 0.35, 0.25))
		for i in 3:
			var lg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.07
			cm.height = 0.55
			lg.mesh = cm
			lg.material_override = logs
			add_child(lg)
			lg.position = Vector3(-6.6 + i * 0.03, y + 0.1 + (0.1 if i == 2 else 0.0), 2.5 + (i - 1) * 0.1)
			lg.rotation = Vector3(PI * 0.5, 0.2 * (i - 1), 0)
		fire_light = Geo.omni(self, Vector3(-6.3, y + 0.45, 2.5), Color(1.0, 0.55, 0.22), 1.6, 5.5, true)
		var fl := CPUParticles3D.new()
		fl.amount = 28
		fl.lifetime = 0.7
		var qm := QuadMesh.new()
		qm.size = Vector2(0.16, 0.22)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		fm.vertex_color_use_as_albedo = true
		fm.albedo_texture = Fx._soft_tex()
		qm.material = fm
		fl.mesh = qm
		fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		fl.emission_box_extents = Vector3(0.05, 0.02, 0.22)
		fl.direction = Vector3.UP
		fl.spread = 8.0
		fl.gravity = Vector3(0, 0.8, 0)
		fl.initial_velocity_min = 0.25
		fl.initial_velocity_max = 0.5
		fl.scale_amount_min = 0.6
		fl.scale_amount_max = 1.2
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.7, 0.3, 0.9))
		g.add_point(0.5, Color(1.0, 0.35, 0.08, 0.6))
		g.set_color(g.get_point_count() - 1, Color(0.4, 0.1, 0.02, 0.0))
		fl.color_ramp = g
		add_child(fl)
		fl.position = Vector3(-6.58, y + 0.22, 2.5)
		Audio.loop_on(fl, "fire_crackle_loop" if Audio.has_sfx("fire_crackle_loop") else "amb_house_morning_loop", -18.0, 2.0)
	# mantel dressing
	Props.spawn(self, "mantel_clock_01", Vector3(-6.5, y + 1.29, 2.5), 90.0, {"collide": false})
	_photo(Vector3(-6.48, y + 1.42, 1.85), 90.0, "photo_parents", Vector2(0.2, 0.26), true)
	_photo(Vector3(-6.48, y + 1.4, 3.1), 90.0, "photo_beach", Vector2(0.26, 0.2), true)
	Props.spawn(self, "ceramic_vase_01", Vector3(-6.5, y + 1.29, 3.4), 0.0, {"collide": false, "scale": 0.7})
	Props.spawn(self, "brass_candleholders" if Props.exists("brass_candleholders") else "wooden_bowl_01", Vector3(-6.5, y + 1.29, 1.55), 0.0, {"collide": false})
	_photo(Vector3(-6.85, y + 2.05, 2.5), 90.0, "poster_comet_picnic" if after else "photo_lighthouse", Vector2(0.75, 0.55), false)
	# TV + seating
	tv = StarlightTV.new()
	add_child(tv)
	tv.position = Vector3(-2.6, y, 0.42)
	tv.build(Mats.tex_local("dark_wood", 0.8, Color(0.85, 0.62, 0.45)), after)
	_mark("tv", Vector3(-2.6, y, 1.6))
	Props.spawn(self, "Sofa_01", Vector3(-2.5, y, 4.05), 180.0, {"shrink": 0.08})
	Props.spawn(self, "throw_pillows_01", Vector3(-2.4, y + 0.45, 4.05), 180.0, {"collide": false, "pick": "throw_pillows_01_pillow02", "scale": 0.8})
	Props.spawn(self, "ArmChair_01", Vector3(-5.5, y, 1.1), 55.0)
	Props.spawn(self, "mid_century_lounge_chair", Vector3(-0.6, y, 2.3), -110.0)
	Props.spawn(self, "CoffeeTable_01", Vector3(-2.5, y, 2.55), 0.0)
	_rug(Vector3(-2.6, y, 2.6), Vector2(3.4, 2.4), "floral_jacquard", Color(0.95, 0.75, 0.65))
	Props.spawn(self, "side_table_01", Vector3(-4.0, y, 4.45), 0.0, {"scale": 0.95})
	Props.spawn(self, "vintage_oil_lamp", Vector3(-4.0, y + 0.47, 4.45), 0.0, {"collide": false})
	var lamp := Geo.omni(self, Vector3(-4.0, y + 1.1, 4.4), Color(1.0, 0.75, 0.45), 0.8 if after else 0.5, 4.0, false)
	lamps.append(lamp)
	Props.spawn(self, "wooden_bookshelf_worn" if Props.exists("wooden_bookshelf_worn") else "drawer_cabinet", Vector3(-0.35, y, 0.4), 180.0)
	Props.spawn(self, "potted_plant_02", Vector3(-6.4, y, 4.4), 0.0)
	Props.spawn(self, "Ottoman_01", Vector3(-4.8, y, 2.4), 20.0, {"scale": 0.8})
	Props.spawn(self, "chess_set", Vector3(-2.2, y + 0.53, 2.45), 15.0, {"collide": false, "scale": 0.8})
	_photo(Vector3(-3.18, y + 1.65, 4.86), 180.0, "photo_june", Vector2(0.42, 0.56), false)
	_photo(Vector3(-1.9, y + 1.85, 0.08), 0.0, "photo_tuppence", Vector2(0.5, 0.38), false)
	_mark("sofa", Vector3(-2.5, y, 3.3))
	_mark("fireplace", Vector3(-5.6, y, 2.5))
	_mark("living", Vector3(-3.0, y, 2.2))
	_mark("photo_june", Vector3(-3.18, y, 4.0))
	# curtains on living room windows
	_curtain_pair(Vector3(-4.8, y, 4.86), 0.0, 1.8, "floral_jacquard", Color(1.0, 0.8, 0.7), false)
	_curtain_pair(Vector3(-1.9, y, 4.86), 0.0, 1.1, "floral_jacquard", Color(1.0, 0.8, 0.7), false)


func _kitchen() -> void:
	var y := FLOOR_Y
	var after := era == "after"
	var cab := Mats.tex_local("white_planks_clean", 1.0, Color(0.62, 0.82, 0.76))
	var top := Mats.color(Color(0.95, 0.88, 0.62), 0.35)
	var chrome := Mats.color(Color(0.85, 0.86, 0.88), 0.15, 1.0)
	# counters along east wall (x 6.6) z 0.3..3.9 and along back z 0.35 from x 4.4..6.9
	Geo.box(self, Vector3(6.6, y + 0.44, 2.1), Vector3(0.6, 0.88, 3.6), cab, true, "wood")
	Geo.box(self, Vector3(6.58, y + 0.9, 2.1), Vector3(0.66, 0.04, 3.64), top, false)
	Geo.box(self, Vector3(5.4, y + 0.44, 0.4), Vector3(1.8, 0.88, 0.6), cab, true, "wood")
	Geo.box(self, Vector3(5.4, y + 0.9, 0.42), Vector3(1.84, 0.04, 0.66), top, false)
	for dz in [0.6, 1.2, 1.8, 2.4, 3.0, 3.6]:
		Geo.box(self, Vector3(6.29, y + 0.47, dz), Vector3(0.02, 0.62, 0.52), cab, false)
		Geo.box(self, Vector3(6.27, y + 0.7, dz + 0.18), Vector3(0.02, 0.1, 0.02), chrome, false)
	# sink under the east window
	Geo.box(self, Vector3(6.6, y + 0.88, 2.6), Vector3(0.45, 0.06, 0.7), Mats.color(Color(0.9, 0.9, 0.9), 0.2, 0.6), false)
	var tap := Geo.box(self, Vector3(6.82, y + 1.05, 2.6), Vector3(0.03, 0.3, 0.03), chrome, false)
	Geo.box(self, Vector3(6.72, y + 1.18, 2.6), Vector3(0.22, 0.03, 0.03), chrome, false)
	# upper cabinets on the back wall
	Geo.box(self, Vector3(5.4, y + 1.85, 0.25), Vector3(1.8, 0.7, 0.35), cab, true, "wood")
	for dx in [-0.6, 0.0, 0.6]:
		Geo.box(self, Vector3(5.4 + dx, y + 1.85, 0.43), Vector3(0.54, 0.6, 0.02), cab, false)
		Geo.box(self, Vector3(5.4 + dx + 0.2, y + 1.65, 0.45), Vector3(0.02, 0.1, 0.02), chrome, false)
	# retro fridge
	var fridge := Node3D.new()
	add_child(fridge)
	fridge.position = Vector3(3.15, y, 0.5)
	var fcol := Mats.color(Color(0.72, 0.9, 0.84) if not after else Color(0.6, 0.72, 0.66), 0.35)
	var fb := Geo.box(fridge, Vector3(0, 0.82, 0), Vector3(0.78, 1.64, 0.7), fcol, true, "metal")
	var fr := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.36
	cap.height = 0.78
	fr.mesh = cap
	fr.material_override = fcol
	fr.rotation.z = PI * 0.5
	fr.scale = Vector3(0.35, 1.0, 0.95)
	fr.position = Vector3(0, 1.64, 0)
	fridge.add_child(fr)
	Geo.box(fridge, Vector3(0.28, 1.15, 0.37), Vector3(0.04, 0.32, 0.05), chrome, false)
	Geo.box(fridge, Vector3(0, 1.2, 0.351), Vector3(0.78, 0.01, 0.01), Mats.color(Color(0.3, 0.3, 0.3)), false)
	var badge := Label3D.new()
	badge.text = "Halcyon"
	badge.font_size = 40
	badge.pixel_size = 0.0012
	badge.modulate = Color(0.75, 0.6, 0.35)
	badge.position = Vector3(0, 1.48, 0.356)
	fridge.add_child(badge)
	Audio.loop_on(fridge, "fridge_hum_loop", -30.0, 1.5)
	# stove + kettle
	if Props.exists("electric_stove"):
		Props.spawn(self, "electric_stove", Vector3(4.45, y, 0.48), 0.0)
	kettle = Props.spawn(self, "vintage_electric_kettle", Vector3(5.6, y + 0.92, 0.45), -20.0, {"collide": false})
	_mark("kettle", Vector3(5.5, y, 1.3))
	# toaster
	var toaster := Node3D.new()
	add_child(toaster)
	toaster.position = Vector3(6.55, y + 0.92, 0.9)
	Geo.box(toaster, Vector3(0, 0.1, 0), Vector3(0.26, 0.2, 0.17), chrome, false)
	Geo.box(toaster, Vector3(0, 0.205, 0), Vector3(0.18, 0.012, 0.1), Mats.color(Color(0.05, 0.05, 0.05)), false)
	# food & dressing
	Props.spawn(self, "wooden_cutting_board", Vector3(6.55, y + 0.92, 3.5), 90.0, {"collide": false})
	if not after:
		Props.spawn(self, "croissant", Vector3(6.55, y + 0.94, 3.45), 30.0, {"collide": false})
		Props.spawn(self, "bananas", Vector3(5.0, y + 0.92, 0.42), 10.0, {"collide": false, "pick": "bananas_bunch"})
		Props.spawn(self, "lemon", Vector3(6.6, y + 0.92, 3.75), 0.0, {"collide": false})
	Props.spawn(self, "jug_01", Vector3(6.6, y + 0.92, 1.3), 0.0, {"collide": false, "scale": 0.8})
	# radio on the counter
	radio = RadioSet.new()
	add_child(radio)
	radio.position = Vector3(6.55, y + 0.92, 1.75)
	radio.rotation.y = -PI * 0.5
	radio.build(Mats.tex_local("dark_wood", 0.5, Color(0.85, 0.55, 0.35)))
	radio.station = "lfr_1978" if after else "lfr_1967"
	# dining table with gingham cloth
	var tbl := Node3D.new()
	add_child(tbl)
	tbl.position = Vector3(4.6, y, 3.3)
	Geo.box(tbl, Vector3(0, 0.74, 0), Vector3(1.3, 0.04, 0.85), m_furn_wood, true, "wood")
	Geo.box(tbl, Vector3(0, 0.765, 0), Vector3(1.38, 0.008, 0.93), Mats.tex("gingham_check", 0.5, Color(1, 0.9, 0.9)), false)
	for lx in [-0.58, 0.58]:
		for lz in [-0.35, 0.35]:
			Geo.box(tbl, Vector3(lx, 0.37, lz), Vector3(0.05, 0.74, 0.05), m_furn_wood, false)
	Props.spawn(self, "dining_chair_02", Vector3(4.2, y, 2.65), 0.0)
	Props.spawn(self, "dining_chair_02", Vector3(5.0, y, 3.95), 180.0)
	Props.spawn(self, "dining_chair_02", Vector3(3.6, y, 3.4), 90.0)
	Props.spawn(self, "tea_set_01", Vector3(4.7, y + 0.775, 3.3), 0.0, {"collide": false, "pick": "tea_set_01_teapot_01"})
	Props.spawn(self, "tea_set_01", Vector3(4.7, y + 0.775 + 0.11, 3.3), 0.0, {"collide": false, "pick": "tea_set_01_teapot_01_lid"})
	Props.spawn(self, "tea_set_01", Vector3(4.35, y + 0.775, 3.1), 0.0, {"collide": false, "pick": "tea_set_01_saucer_circular_03"})
	Props.spawn(self, "tea_set_01", Vector3(4.35, y + 0.79, 3.1), 0.0, {"collide": false, "pick": "tea_set_01_cup_small_01"})
	if not after:
		Props.spawn(self, "carrot_cake", Vector3(5.0, y + 0.775, 3.45), 0.0, {"collide": false})
	Props.spawn(self, "wicker_basket_01", Vector3(4.3, y + 0.775, 3.55), 0.0, {"collide": false, "scale": 0.6})
	_mark("table", Vector3(4.6, y, 2.4))
	_rug(Vector3(4.6, y, 3.3), Vector2(2.2, 1.8), "curly_teddy_natural", Color(0.9, 0.85, 0.75))
	_curtain_pair(Vector3(6.86, y, 2.6), -90.0, 1.6, "gingham_check", Color(1.0, 0.85, 0.85), false, 1.05, 2.15)
	_curtain_pair(Vector3(4.85, y, 4.86), 0.0, 1.4, "gingham_check", Color(1.0, 0.85, 0.85), false, 1.05, 2.1)
	var kl := Geo.omni(self, Vector3(4.8, y + 2.3, 2.4), Color(1.0, 0.85, 0.65), 0.0 if not after else 0.9, 6.0, true)
	lamps.append(kl)
	Props.spawn(self, "modern_ceiling_lamp_01", Vector3(4.8, y + H, 2.4), 0.0, {"collide": false, "scale": 0.6, "hang": true})


func _bedroom() -> void:
	var y := FLOOR_Y
	var after := era == "after"
	# bed against the back wall (z=-5), head at back, foot toward z=-2.6
	var bed := Node3D.new()
	add_child(bed)
	bed.position = Vector3(4.2, y, -3.85)
	var frame := Mats.tex_local("dark_wood", 0.8, Color(0.75, 0.55, 0.4))
	Geo.box(bed, Vector3(0, 0.25, 0), Vector3(1.5, 0.22, 2.05), frame, true, "wood")
	Geo.box(bed, Vector3(0, 0.6, -1.03), Vector3(1.56, 1.2, 0.07), frame, true, "wood")
	Geo.box(bed, Vector3(0, 0.42, 1.03), Vector3(1.56, 0.5, 0.06), frame, true, "wood")
	Geo.box(bed, Vector3(0, 0.46, 0), Vector3(1.42, 0.2, 1.98), Mats.color(Color(0.95, 0.94, 0.9), 0.9), false)
	var quilt := Mats.tex("fabric_pattern_05", 0.7, Color(0.85, 0.75, 1.0) if not after else Color(0.75, 0.7, 0.8))
	var q := Geo.box(bed, Vector3(0, 0.575, 0.28), Vector3(1.5, 0.07, 1.45), quilt, false)
	q.rotation.x = -0.02
	Geo.box(bed, Vector3(0, 0.6, -0.42), Vector3(1.48, 0.06, 0.32), Mats.color(Color(0.96, 0.95, 0.92), 0.9), false)
	for px in [-0.36, 0.36]:
		var pil := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.11
		cm.height = 0.62
		pil.mesh = cm
		pil.material_override = Mats.color(Color(0.97, 0.96, 0.93), 0.95)
		pil.rotation.z = PI * 0.5
		pil.scale = Vector3(1, 1, 0.55)
		pil.position = Vector3(px, 0.66, -0.8)
		bed.add_child(pil)
	bed_spot = _mark("bed", Vector3(4.2, y + 0.55, -4.1))
	Props.spawn(self, "ClassicNightstand_01", Vector3(5.45, y, -4.55), 0.0)
	Props.spawn(self, "alarm_clock_01", Vector3(5.4, y + 0.7, -4.5), -20.0, {"collide": false})
	Props.spawn(self, "round_spectacles", Vector3(5.6, y + 0.7, -4.45), 30.0, {"collide": false})
	Props.spawn(self, "drawer_cabinet", Vector3(3.75, y, -0.34), 180.0)
	Props.spawn(self, "vintage_suitcase", Vector3(6.4, y, -0.5), -90.0, {"pick": "vintage_suitcase"} if false else {})
	Props.spawn(self, "potted_plant_04", Vector3(6.6, y + 0.0, -4.6), 0.0, {"collide": false})
	_rug(Vector3(4.6, y, -2.0), Vector2(2.2, 1.4), "curly_teddy_natural", Color(1.0, 0.9, 0.85))
	_photo(Vector3(4.2, y + 1.75, -4.88), 0.0, "photo_beach", Vector2(0.5, 0.38), false)
	_photo(Vector3(2.78, y + 1.6, -3.0), 90.0, "poster_valet_mk2", Vector2(0.5, 0.75), false)
	var bl := Geo.omni(self, Vector3(5.4, y + 1.0, -4.4), Color(1.0, 0.75, 0.45), 0.0, 3.0, false)
	lamps.append(bl)
	# east window curtains that Tuppence opens
	var pair := _curtain_pair(Vector3(6.86, y, -2.4), -90.0, 1.8, "floral_jacquard", Color(1.0, 0.82, 0.7), not after, 0.75, 2.25)
	curtain_l = pair[0]
	curtain_r = pair[1]
	_mark("bedroom_window", Vector3(6.0, y, -2.4))
	_mark("bedroom", Vector3(4.6, y, -1.6))
	tuppence_spot = _mark("tuppence_wake", Vector3(5.6, y, -2.0))


func _den_and_hall() -> void:
	var y := FLOOR_Y
	# den (x -7..-3, z -5..0)
	var desk := Node3D.new()
	add_child(desk)
	desk.position = Vector3(-5.0, y, -4.45)
	Geo.box(desk, Vector3(0, 0.75, 0), Vector3(1.3, 0.04, 0.6), m_furn_wood, true, "wood")
	Geo.box(desk, Vector3(-0.45, 0.37, 0), Vector3(0.4, 0.74, 0.58), m_furn_wood, false)
	Geo.box(desk, Vector3(0.6, 0.37, 0), Vector3(0.05, 0.74, 0.58), m_furn_wood, false)
	Props.spawn(self, "desk_lamp_arm_01", Vector3(-5.5, y + 0.77, -4.6), 30.0, {"collide": false})
	Props.spawn(self, "dining_chair_02", Vector3(-4.9, y, -3.7), 180.0)
	Props.spawn(self, "office_notepads", Vector3(-5.0, y + 0.77, -4.4), 0.0, {"collide": false, "pick": "office_notepads_yellow_pad"})
	Props.spawn(self, "book_encyclopedia_set_01", Vector3(-6.6, y + 0.0, -1.0), 90.0, {"collide": false})
	Props.spawn(self, "Ukulele_01", Vector3(-3.25, y, -4.7), 200.0, {"collide": false})
	Props.spawn(self, "vintage_cabinet_01", Vector3(-6.62, y, -2.6), 90.0, {"scale": 0.85})
	Props.spawn(self, "ArmChair_01", Vector3(-3.8, y, -1.0), 200.0)
	var dl := Geo.omni(self, Vector3(-5.4, y + 1.1, -4.4), Color(1.0, 0.78, 0.5), 0.6 if era == "after" else 0.0, 3.5, false)
	lamps.append(dl)
	_mark("den", Vector3(-5.0, y, -2.5))
	# hall: grandfather clock, wall phone, mirror, coat hooks
	var gclock := Props.spawn(self, "vintage_grandfather_clock_01", Vector3(0.75, y, -4.6), 90.0)
	if gclock:
		Audio.loop_on(gclock, "clock_tick_loop", -16.0, 2.5)
	var phone := Props.spawn(self, "vintage_telephone_wall_clock", Vector3(2.58, y + 1.25, 3.8), -90.0, {"collide": false})
	phone_use = Interactable.make(self, Vector3(2.45, y + 1.45, 3.8), Vector3(0.4, 0.6, 0.5), "Answer", "Telephone")
	phone_use.enabled = false
	_mark("phone", Vector3(1.7, y, 3.8))
	Props.spawn(self, "ornate_mirror_01", Vector3(0.58, y + 1.15, 3.6), 90.0, {"collide": false})
	_rug(Vector3(1.6, y, 1.0), Vector2(1.2, 6.5), "floral_jacquard", Color(0.7, 0.5, 0.45))
	_mark("entry", Vector3(1.6, y, 3.6))
	_mark("hall", Vector3(1.6, y, -1.5))
	_mark("front_door_in", Vector3(1.6, y, 4.3))
	_mark("front_door_out", Vector3(1.6, y, 6.3))
	_mark("porch", Vector3(1.6, y, 6.0))


# ------------------------------------------------------------------ exterior

func _exterior() -> void:
	var y := FLOOR_Y
	var after := era == "after"
	var roof := Mats.tex("grey_roof_tiles" if not after else "roof_tiles", 2.0, Color(0.55, 0.42, 0.38) if not after else Color(0.45, 0.42, 0.4))
	Geo.gable_roof(self, -7.1, 7.1, -5.1, 5.1, y + H + 0.12, 2.3, 0.5, roof, m_ext)
	# fascia boards
	Geo.box(self, Vector3(0, y + H + 0.06, 5.55), Vector3(15.2, 0.22, 0.05), m_trim, false)
	Geo.box(self, Vector3(0, y + H + 0.06, -5.55), Vector3(15.2, 0.22, 0.05), m_trim, false)
	# chimney
	var brick := Mats.tex("red_brick_03", 1.2, Color(0.9, 0.78, 0.7))
	Geo.box(self, Vector3(-7.35, y + 2.4, 2.5), Vector3(0.6, 4.8 + y, 1.1), brick, true)
	Geo.box(self, Vector3(-7.35, y + 4.85, 2.5), Vector3(0.72, 0.12, 1.22), Mats.color(Color(0.5, 0.48, 0.46)), false)
	# corner boards
	for cx in [-7.08, 7.08]:
		for cz in [-5.08, 5.08]:
			Geo.box(self, Vector3(cx, y + H * 0.5, cz), Vector3(0.14, H, 0.14), m_trim, false)
	# front porch with steps, posts, little roof, porch light, bench
	var deck := Mats.tex("worn_planks" if after else "brown_planks_03", 1.5, Color(0.9, 0.85, 0.8))
	Geo.box(self, Vector3(1.6, y - 0.05, 6.3), Vector3(4.2, 0.12, 2.4), deck, true, "wood")
	for i in 3:
		Geo.box(self, Vector3(1.6, y - 0.15 - i * 0.15, 7.7 + i * 0.3), Vector3(1.8, 0.15, 0.32), deck, true, "wood")
	for px in [-0.4, 3.6]:
		Geo.box(self, Vector3(px, y + 1.25, 7.35), Vector3(0.12, 2.5, 0.12), m_trim, true, "wood")
	Geo.box(self, Vector3(1.6, y + 2.55, 6.35), Vector3(4.6, 0.1, 2.6), roof, true, "wood")
	Geo.box(self, Vector3(1.6, y + 2.47, 7.4), Vector3(4.4, 0.12, 0.1), m_trim, false)
	var pl := Geo.omni(self, Vector3(0.7, y + 2.0, 5.3), Color(1.0, 0.78, 0.5), 0.0, 5.0, true)
	pl.name = "PorchLight"
	lamps.append(pl)
	Geo.box(self, Vector3(0.7, y + 2.0, 5.15), Vector3(0.14, 0.24, 0.14), Mats.emissive(Color(1.0, 0.85, 0.6), 0.6), false)
	Props.spawn(self, "painted_wooden_bench", Vector3(-0.0, y, 6.2), 90.0, {"scale": 0.9})
	Props.spawn(self, "planter_box_01", Vector3(3.3, y, 6.6), 90.0, {"scale": 0.7})
	Geo.box(self, Vector3(1.6, y + 0.005, 5.6), Vector3(0.9, 0.01, 0.5), Mats.tex("hessian_230" if false else "fabric_pattern_05", 0.5, Color(0.55, 0.4, 0.3)), false)
	# path from porch to sidewalk (the lot ends at local z ~11.2, where the sidewalk starts)
	var path_mat := Mats.tex("concrete_pavement", 2.0, Color(0.95, 0.93, 0.9))
	for i in 3:
		var pz := 8.9 + i * 1.0
		var gp := global_transform * Vector3(1.6, 0, pz)
		Geo.box(self, Vector3(1.6, Layout.height(gp.x, gp.z) - global_position.y + 0.06, pz), Vector3(1.4, 0.1, 0.85), path_mat, true, "concrete")
	_mark("path_end", Vector3(1.6, 0, 11.8))
	# picket fence along the front of the lot (z = +11 local) with a gate gap at the path
	var fence_mat := m_trim if not after else Mats.color(Color(0.6, 0.6, 0.55), 0.8)
	for i in range(-11, 12):
		var fx := i * 0.62
		if absf(fx - 1.6) < 0.9:
			continue
		if after and randf() < 0.15:
			continue
		var gp2 := global_transform * Vector3(fx, 0, 11.0)
		var gy := Layout.height(gp2.x, gp2.z) - global_position.y
		var pk := Geo.box(self, Vector3(fx, gy + 0.45, 11.0), Vector3(0.09, 0.9, 0.03), fence_mat, false)
		if after:
			pk.rotation.z = randf_range(-0.15, 0.15)
	for rail_y in [0.25, 0.7]:
		var a := global_transform * Vector3(-6.8, 0, 11.0)
		Geo.box(self, Vector3(-3.7, Layout.height(a.x, a.z) - global_position.y + rail_y, 10.98), Vector3(6.4, 0.06, 0.03), fence_mat, false)
		Geo.box(self, Vector3(4.65, Layout.height(a.x + 9, a.z) - global_position.y + rail_y, 10.98), Vector3(4.3, 0.06, 0.03), fence_mat, false)
	# yard props
	var g := global_transform * Vector3(-3.5, 0, 9.5)
	Props.spawn(self, "garden_gnome", Vector3(-3.5, Layout.height(g.x, g.z) - global_position.y, 9.5), 160.0, {"collide": false})
	var mb := global_transform * Vector3(3.2, 0, 11.4)
	_mailbox(Vector3(3.2, Layout.height(mb.x, mb.z) - global_position.y, 11.4))
	if not after:
		var s := global_transform * Vector3(-5.5, 0, 12.0)
		Props.spawn(self, "garden_sprinkler_01", Vector3(-5.5, Layout.height(s.x, s.z) - global_position.y, 12.0), 0.0, {"collide": false})


func _mailbox(pos: Vector3) -> void:
	var post := Geo.box(self, pos + Vector3(0, 0.55, 0), Vector3(0.09, 1.1, 0.09), m_furn_wood, true, "wood")
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.13
	cm.height = 0.5
	body.mesh = cm
	body.material_override = Mats.color(Color(0.25, 0.4, 0.55) if era == "before" else Color(0.3, 0.32, 0.33), 0.5, 0.4)
	body.rotation.x = PI * 0.5
	body.position = pos + Vector3(0, 1.18, 0)
	add_child(body)
	var flag := Geo.box(self, pos + Vector3(0.14, 1.3, 0.05), Vector3(0.02, 0.18, 0.06), Mats.color(Color(0.8, 0.2, 0.15)), false)
	var lbl := Label3D.new()
	lbl.text = "No. 12"
	lbl.font_size = 40
	lbl.pixel_size = 0.0015
	lbl.modulate = Color(0.95, 0.9, 0.8)
	lbl.position = pos + Vector3(0, 1.18, 0.255)
	add_child(lbl)


# ------------------------------------------------------------------ helpers

func _photo(pos: Vector3, rot_deg: float, tex: String, size: Vector2, standing: bool) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	n.rotation.y = deg_to_rad(rot_deg)
	var frame := Mats.color(Color(0.35, 0.22, 0.12), 0.4) if not standing else m_brass
	var fw := 0.03
	Geo.box(n, Vector3(0, 0, -0.012), Vector3(size.x + fw * 2, size.y + fw * 2, 0.02), frame, false)
	Geo.box(n, Vector3(0, 0, -0.005), Vector3(size.x + 0.01, size.y + 0.01, 0.012), Mats.color(Color(0.95, 0.93, 0.88)), false)
	var q := Geo.decal_quad(n, Vector3(0, 0, 0.003), size * 0.92, Mats.gen(tex, 0.6), Vector3.ZERO)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if standing:
		n.rotation.x = -0.12
		n.position.y += size.y * 0.5


func _rug(pos: Vector3, size: Vector2, tex: String, tint: Color) -> void:
	Geo.box(self, pos + Vector3(0, 0.006, 0), Vector3(size.x, 0.012, size.y), Mats.tex(tex, 1.2, tint), false)


## Two curtain panels inside a window. rot_deg: wall facing. Returns [left, right] pivot nodes.
func _curtain_pair(pos: Vector3, rot_deg: float, w: float, tex: String, tint: Color, closed: bool, y0 := 0.85, y1 := 2.2) -> Array:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation.y = deg_to_rad(rot_deg)
	var mat := Mats.tex(tex, 0.8, tint)
	var h := (y1 - y0) + 0.5
	var out := []
	Geo.box(root, Vector3(0, y1 + 0.22, -0.12), Vector3(w + 0.6, 0.03, 0.03), m_brass, false)
	for side in [-1.0, 1.0]:
		var piv := Node3D.new()
		root.add_child(piv)
		piv.position = Vector3(side * (w * 0.5 + 0.22), 0, -0.13)
		var panel := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.0, h)
		pm.orientation = PlaneMesh.FACE_Z
		pm.subdivide_width = 10
		panel.mesh = pm
		var sm := ShaderMaterial.new()
		sm.shader = load("res://src/world/shaders/curtain.gdshader")
		sm.set_shader_parameter("albedo_tex", (mat as StandardMaterial3D).albedo_texture)
		sm.set_shader_parameter("tint", tint)
		panel.material_override = sm
		piv.add_child(panel)
		panel.position = Vector3(-side * 0.5, y1 + 0.2 - h * 0.5, 0)
		var open_w := 0.32
		var closed_w := w * 0.5 + 0.25
		piv.scale.x = closed_w if closed else open_w
		piv.set_meta("open_w", open_w)
		piv.set_meta("closed_w", closed_w)
		out.append(piv)
	return out


func open_curtains(dur := 1.4) -> void:
	for c in [curtain_l, curtain_r]:
		if c:
			create_tween().tween_property(c, "scale:x", float(c.get_meta("open_w")), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Audio.sfx_at("curtain_open", spot("bedroom_window") + Vector3(0, 1.4, 0), -4.0)


func _lights() -> void:
	var y := FLOOR_Y
	for p in [Vector3(-3.0, 0, 2.5), Vector3(1.6, 0, 1.0), Vector3(4.6, 0, -2.5), Vector3(-5.0, 0, -2.5)]:
		Props.spawn(self, "modern_ceiling_lamp_01", Vector3(p.x, y + H, p.z), 0.0, {"collide": false, "scale": 0.6, "hang": true})
	var main_l := Geo.omni(self, Vector3(-3.0, y + H - 0.55, 2.5), Color(1.0, 0.8, 0.55), 0.0, 7.0, true)
	lamps.append(main_l)


func _fill_lights() -> void:
	var y := FLOOR_Y + 1.9
	var warm := Color(1.0, 0.86, 0.7)
	for p in [Vector3(-3.5, y, 2.5), Vector3(4.8, y, 2.5), Vector3(4.8, y, -2.5), Vector3(-5.0, y, -2.5), Vector3(1.6, y, 0.0)]:
		var l := Geo.omni(self, p, warm, 0.45 if era == "before" else 0.35, 6.5, false)
		l.light_specular = 0.0
		l.light_indirect_energy = 0.0
		fill_lights.append(l)


func set_lamps(on: bool, energy := 0.9) -> void:
	for l in lamps:
		if is_instance_valid(l):
			l.light_energy = energy if on else 0.0


func _indoor_trigger() -> void:
	indoor_area = Area3D.new()
	indoor_area.collision_layer = 0
	indoor_area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(13.8, 3.0, 9.8)
	cs.shape = bs
	indoor_area.add_child(cs)
	add_child(indoor_area)
	indoor_area.position = Vector3(0, FLOOR_Y + 1.5, 0)


func _process(delta: float) -> void:
	if fire_light:
		_fire_t += delta
		fire_light.light_energy = 1.4 + sin(_fire_t * 13.0) * 0.12 + sin(_fire_t * 7.3) * 0.18 + randf() * 0.1
