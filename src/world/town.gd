class_name Town
extends Node3D
## Larkhaven: roads, neighbour houses, the town square, street furniture, cars, vegetation, the pier,
## the Shelter No. 9 portal and the lighthouse. era "before" (1967) or "after" (1978).

var era := "before"
var after := false
var world: Node
var rng := RandomNumberGenerator.new()
var street_lights: Array[Light3D] = []
var window_glows: Array[StandardMaterial3D] = []
var spots := {}
var shelter_door_l: Node3D
var shelter_door_r: Node3D
var shelter_klaxon: OmniLight3D
var lighthouse_beam: Node3D
var lh_intercom: Interactable
var cd_locker: Interactable
var crash_spot: Vector3
var hydrant_spray: CPUParticles3D

var m_asphalt: Material
var m_walk: Material
var m_curb: Material
var m_line: Material
var m_concrete: Material
var m_wood_post: Material


func build(p_era: String, p_world: Node) -> void:
	era = p_era
	after = era == "after"
	world = p_world
	rng.seed = 1967 if not after else 1978
	m_asphalt = Mats.tex("road_damaged" if after else "asphalt_02", 6.0, Color(0.9, 0.9, 0.9) if not after else Color(0.85, 0.82, 0.8))
	m_walk = Mats.tex("concrete_pavement", 2.5, Color(0.92, 0.9, 0.86) if not after else Color(0.7, 0.68, 0.64))
	m_curb = Mats.tex("concrete_wall_008", 1.5, Color(0.85, 0.84, 0.8))
	m_line = Mats.color(Color(0.95, 0.78, 0.25) if not after else Color(0.55, 0.5, 0.35), 0.6)
	m_concrete = Mats.tex("concrete_wall_008", 3.0, Color(0.85, 0.84, 0.8))
	m_wood_post = Mats.tex("dark_wood", 1.0, Color(0.55, 0.45, 0.38))
	for step in ["_roads", "_gull_lane_houses", "_square", "_street_furniture", "_cars", "_coast", "_shelter_portal", "_lighthouse", "_vegetation", "_bloom_growth"]:
		if step == "_bloom_growth" and not after:
			continue
		var t := Time.get_ticks_msec()
		call(step)
		if Game.shot_args.has("timing"):
			print("[build]   town.%s %d ms" % [step, Time.get_ticks_msec() - t])


func spot(name: String) -> Vector3:
	return spots.get(name, Vector3.ZERO)


func gy(x: float, z: float) -> float:
	return Layout.height(x, z)


func lights_on(on: bool) -> void:
	for l in street_lights:
		if is_instance_valid(l):
			l.visible = on
	for m in window_glows:
		m.emission_energy_multiplier = 0.9 if on else 0.0


# ------------------------------------------------------------------ roads

func _roads() -> void:
	for r in Layout.ROADS:
		var pts: Array = r.pts
		var w: float = r.w
		var samples := _sample_poly(pts, 2.0)
		var mat := m_asphalt
		if r.kind == "path":
			mat = Mats.tex("dirt", 3.0)
		_ribbon(samples, -w * 0.5, w * 0.5, 0.05, mat, true, "concrete" if r.kind != "path" else "gravel")
		if r.walk:
			_ribbon(samples, w * 0.5, w * 0.5 + 2.2, 0.16, m_walk, true, "concrete")
			_ribbon(samples, -w * 0.5 - 2.2, -w * 0.5, 0.16, m_walk, true, "concrete")
			_curb(samples, w * 0.5)
			_curb(samples, -w * 0.5)
		if r.kind != "path" and (not after or rng.randf() < 1.0):
			_dashes(samples)


func _sample_poly(pts: Array, step: float) -> Array:
	var out := []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(int(a.distance_to(b) / step), 1)
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	out.append(pts[pts.size() - 1])
	return out


func _perp(samples: Array, i: int) -> Vector2:
	var a: Vector2 = samples[maxi(i - 1, 0)]
	var b: Vector2 = samples[mini(i + 1, samples.size() - 1)]
	var d := (b - a).normalized()
	return Vector2(-d.y, d.x)


func _ribbon(samples: Array, off0: float, off1: float, lift: float, mat: Material, collide: bool, surface: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in samples.size():
		var p: Vector2 = samples[i]
		var n := _perp(samples, i)
		var pl := p + n * off0
		var pr := p + n * off1
		var c := Layout.road_center_h(p)
		var l3 := Vector3(pl.x, c + lift, pl.y)
		var r3 := Vector3(pr.x, c + lift, pr.y)
		if i > 0:
			dist += samples[i].distance_to(samples[i - 1])
			for e in [[prev_l, 0.0], [r3, 1.0], [prev_r, 1.0], [prev_l, 0.0], [l3, 0.0], [r3, 1.0]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(e[1], dist))
				st.add_vertex(e[0])
		prev_l = l3
		prev_r = r3
	st.generate_tangents()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.set_meta("surface", surface)
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		mi.add_child(body)


func _curb(samples: Array, off: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, samples.size()):
		var a: Vector2 = samples[i - 1] + _perp(samples, i - 1) * off
		var b: Vector2 = samples[i] + _perp(samples, i) * off
		var ha := Layout.road_center_h(samples[i - 1])
		var hb := Layout.road_center_h(samples[i])
		var n3 := Vector3(_perp(samples, i).x, 0, _perp(samples, i).y) * (-signf(off))
		var q := [Vector3(a.x, ha + 0.05, a.y), Vector3(b.x, hb + 0.05, b.y), Vector3(b.x, hb + 0.16, b.y), Vector3(a.x, ha + 0.16, a.y)]
		for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
			st.set_normal(n3)
			st.set_uv(Vector2(q[idx].x + q[idx].z, q[idx].y))
			st.add_vertex(q[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m_curb
	add_child(mi)


func _dashes(samples: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc := 0.0
	for i in range(1, samples.size()):
		acc += 2.0
		if fmod(acc, 6.0) >= 3.0:
			continue
		var a: Vector2 = samples[i - 1]
		var b: Vector2 = samples[i]
		var n := _perp(samples, i) * 0.07
		var ha := Layout.road_center_h(a) + 0.065
		var hb := Layout.road_center_h(b) + 0.065
		var q := [Vector3(a.x - n.x, ha, a.y - n.y), Vector3(a.x + n.x, ha, a.y + n.y), Vector3(b.x + n.x, hb, b.y + n.y), Vector3(b.x - n.x, hb, b.y - n.y)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(q[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m_line
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ houses

const HOUSE_COLORS := [Color(0.62, 0.8, 0.78), Color(0.95, 0.75, 0.72), Color(0.7, 0.8, 0.92), Color(0.96, 0.95, 0.9), Color(0.85, 0.9, 0.7), Color(0.95, 0.85, 0.6), Color(0.8, 0.72, 0.85)]


func _gull_lane_houses() -> void:
	var lots := [
		[Vector2(-50, -16), 0.0], [Vector2(-26, -16), 0.0], [Vector2(26, -16), 0.0], [Vector2(50, -16), 0.0],
		[Vector2(-50, 16), 180.0], [Vector2(6, 16), 180.0], [Vector2(30, 16), 180.0], [Vector2(54, 16), 180.0],
	]
	for i in lots.size():
		var c: Vector2 = lots[i][0]
		_house(Vector3(c.x, gy(c.x, c.y), c.y), lots[i][1], 11.0 + (i % 3), 8.0 + (i % 2), HOUSE_COLORS[i % HOUSE_COLORS.size()], i)
	# a few houses along Main Street and the coast road
	var extra := [[Vector2(-40, 45), 90.0], [Vector2(-8, 42), -90.0], [Vector2(-52, 80), 70.0], [Vector2(-74, 30), 90.0], [Vector2(-76, -40), 90.0]]
	for j in extra.size():
		var c2: Vector2 = extra[j][0]
		_house(Vector3(c2.x, gy(c2.x, c2.y), c2.y), extra[j][1], 10.0, 8.0, HOUSE_COLORS[(j + 3) % HOUSE_COLORS.size()], 20 + j)


## Exterior-only neighbour house. facing: 0 = front faces +Z.
func _house(pos: Vector3, facing: float, w: float, d: float, col: Color, seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 31 + 7
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation_degrees.y = facing
	var fy := 0.45
	var tint := col if not after else col.darkened(0.35).lerp(Color(0.5, 0.5, 0.48), 0.4)
	var ext := Mats.tex("white_planks_clean" if seed % 3 != 1 else "whitewashed_brick", 2.0, tint)
	var inner := Mats.color(Color(0.18, 0.16, 0.14), 0.9)
	var trim := Mats.color(Color(0.95, 0.94, 0.9) if not after else Color(0.65, 0.63, 0.58), 0.5)
	var glass := Mats.glass(Color(0.6, 0.7, 0.75, 0.35), after)
	Geo.box(root, Vector3(0, fy * 0.5 - 0.1, 0), Vector3(w + 0.2, fy + 0.2, d + 0.2), Mats.tex("red_brick_03", 1.5, Color(0.8, 0.75, 0.7)), true)
	var hw := w * 0.5
	var hd := d * 0.5
	var f := Vector3(0, fy, 0)
	var ops_front := [{"at": hw - (-hw * 0.5), "w": 1.6, "y0": 0.85, "y1": 2.2}, {"at": hw - 0.6, "w": 1.0, "y0": 0.0, "y1": 2.15}, {"at": hw - hw * 0.6, "w": 1.3, "y0": 0.9, "y1": 2.2}]
	Geo.wall(root, f + Vector3(hw, 0, hd), f + Vector3(-hw, 0, hd), 2.7, 0.2, inner, ext, ops_front)
	var ops_side := [{"at": d * 0.5, "w": 1.2, "y0": 0.9, "y1": 2.1}]
	Geo.wall(root, f + Vector3(-hw, 0, hd), f + Vector3(-hw, 0, -hd), 2.7, 0.2, inner, ext, ops_side)
	Geo.wall(root, f + Vector3(hw, 0, -hd), f + Vector3(hw, 0, hd), 2.7, 0.2, inner, ext, ops_side)
	Geo.wall(root, f + Vector3(-hw, 0, -hd), f + Vector3(hw, 0, -hd), 2.7, 0.2, inner, ext, [{"at": w * 0.3, "w": 1.0, "y0": 0.9, "y1": 2.1}, {"at": w * 0.7, "w": 1.0, "y0": 0.9, "y1": 2.1}])
	Geo.box(root, Vector3(0, fy + 2.76, 0), Vector3(w, 0.12, d), inner, false)
	# windows: frames, glass, a lit blind behind (glows at night)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.85, 0.75, 0.55) if not after else Color(0.2, 0.18, 0.16)
	glow.roughness = 0.9
	glow.emission_enabled = not after
	glow.emission = Color(1.0, 0.72, 0.4)
	glow.emission_energy_multiplier = 0.0
	if not after:
		window_glows.append(glow)
	for o in ops_front:
		if o.y0 > 0.0:
			var broken: bool = after and r.randf() < 0.45
			Geo.window(root, f + Vector3(hw, 0, hd), f + Vector3(-hw, 0, hd), 0.2, o, trim, glass, broken)
			var c := Vector3(hw - float(o.at), fy + (o.y0 + o.y1) * 0.5, hd - 0.18)
			Geo.box(root, c, Vector3(o.w - 0.1, o.y1 - o.y0 - 0.1, 0.02), glow, false)
			if after and broken and r.randf() < 0.6:
				for k in 3:
					var pl := Geo.box(root, c + Vector3(0, -0.4 + k * 0.4, 0.2), Vector3(o.w + 0.2, 0.16, 0.03), Mats.tex("worn_planks", 1.0), false)
					pl.rotation.z = r.randf_range(-0.15, 0.15)
	for side in [-1.0, 1.0]:
		var c2 := Vector3(side * (hw - 0.18), fy + 1.5, 0)
		var gb := Geo.box(root, c2, Vector3(0.02, 1.1, 1.1), glow, false)
	Geo.window(root, f + Vector3(-hw, 0, hd), f + Vector3(-hw, 0, -hd), 0.2, ops_side[0], trim, glass, after and r.randf() < 0.4)
	Geo.window(root, f + Vector3(hw, 0, -hd), f + Vector3(hw, 0, hd), 0.2, ops_side[0], trim, glass, after and r.randf() < 0.4)
	# front door slab (closed) and porch
	var door_col: Color = [Color(0.75, 0.25, 0.2), Color(0.2, 0.4, 0.5), Color(0.9, 0.75, 0.3), Color(0.3, 0.5, 0.35)][seed % 4]
	Geo.box(root, Vector3(hw - (hw - 0.6), fy + 1.07, hd - 0.05), Vector3(0.95, 2.13, 0.06), Mats.color(door_col if not after else door_col.darkened(0.5), 0.5), true, "wood")
	var deck := Mats.tex("brown_planks_03", 1.5, Color(0.85, 0.8, 0.75))
	Geo.box(root, Vector3(0.6, fy - 0.06, hd + 1.0), Vector3(2.6, 0.12, 2.0), deck, true, "wood")
	Geo.box(root, Vector3(0.6, fy - 0.25, hd + 2.2), Vector3(1.6, 0.15, 0.4), deck, true, "wood")
	var roof_col: Color = [Color(0.45, 0.35, 0.32), Color(0.35, 0.38, 0.42), Color(0.5, 0.42, 0.35)][seed % 3]
	Geo.gable_roof(root, -hw - 0.1, hw + 0.1, -hd - 0.1, hd + 0.1, fy + 2.82, 2.0, 0.45, Mats.tex("grey_roof_tiles", 2.0, roof_col if not after else roof_col.darkened(0.3)), ext)
	if seed % 2 == 0:
		Geo.box(root, Vector3(-hw * 0.55, fy + 4.2, -hd * 0.3), Vector3(0.6, 2.6, 0.6), Mats.tex("red_brick_03", 1.2), false)
	# yard: hedge or fence, a mailbox, maybe a tree
	var yard_z := hd + 6.0
	for k in 2:
		var sx := -hw + 1.2 + k * (w - 2.4)
		var hp := root.to_global(Vector3(sx, 0, yard_z - 1.5))
		if Props.exists("shrub_04"):
			Props.spawn(self, "shrub_04", Vector3(hp.x, gy(hp.x, hp.z), hp.z), r.randf() * 360.0, {"collide": false, "scale": 1.4})
	var tp := root.to_global(Vector3(-hw * 0.7, 0, hd + 4.0))
	if r.randf() < 0.75:
		Foliage.place_tree(self, Vector3(tp.x, gy(tp.x, tp.z), tp.z), "dead" if after and r.randf() < 0.4 else "maple", seed, after)
	if after and r.randf() < 0.5:
		var cp := root.to_global(Vector3(hw * 0.4, 0, hd + 3.5))
		_crystals_at(Vector3(cp.x, gy(cp.x, cp.z), cp.z), 3, 1.0)


# ------------------------------------------------------------------ town square

func _square() -> void:
	var c := Layout.SQUARE
	var y := gy(c.x, c.z)
	spots["square"] = Vector3(c.x, y, c.z)
	# paved plaza
	var paving := Mats.tex("patterned_paving" if not after else "overgrown_concrete_pavers", 3.0)
	Geo.box(self, Vector3(c.x, y + 0.02, c.z), Vector3(30, 0.1, 22), paving, true, "concrete")
	# bandstand
	var bs := Node3D.new()
	add_child(bs)
	bs.position = Vector3(c.x, y, c.z)
	var white := Mats.color(Color(0.95, 0.94, 0.9) if not after else Color(0.65, 0.63, 0.6), 0.6)
	var plat := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.0
	cyl.bottom_radius = 4.2
	cyl.height = 0.7
	cyl.radial_segments = 8
	plat.mesh = cyl
	plat.material_override = Mats.tex("brown_planks_03", 1.5)
	plat.position.y = 0.35
	bs.add_child(plat)
	var pb := StaticBody3D.new()
	pb.set_meta("surface", "wood")
	var pcs := CollisionShape3D.new()
	var pcyl := CylinderShape3D.new()
	pcyl.radius = 4.1
	pcyl.height = 0.7
	pcs.shape = pcyl
	pb.add_child(pcs)
	plat.add_child(pb)
	for k in 8:
		var a := TAU * k / 8.0
		Geo.box(bs, Vector3(cos(a) * 3.7, 2.0, sin(a) * 3.7), Vector3(0.15, 2.6, 0.15), white, true, "wood")
	var roof := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.2
	rc.bottom_radius = 4.6
	rc.height = 1.8
	rc.radial_segments = 8
	roof.mesh = rc
	roof.material_override = Mats.tex("roof_tiles", 1.5, Color(0.7, 0.35, 0.3) if not after else Color(0.45, 0.35, 0.33))
	roof.position.y = 4.2
	bs.add_child(roof)
	# shops around the square
	_shop(Vector3(c.x - 18, 0, c.z - 16), 0.0, 14.0, 9.0, "sign_diner", Mats.tex("whitewashed_brick", 2.0, Color(0.95, 0.85, 0.8)), Color(0.85, 0.25, 0.2), true)
	_shop(Vector3(c.x + 2, 0, c.z - 17), 0.0, 13.0, 8.0, "sign_general", Mats.tex("red_brick_03", 2.0), Color(0.2, 0.45, 0.4), false)
	_shop(Vector3(c.x + 21, 0, c.z + 8), -90.0, 12.0, 9.0, "sign_cd_post", Mats.tex("concrete_wall_008", 2.5), Color(0.25, 0.3, 0.35), false)
	_shop(Vector3(c.x - 4, 0, c.z + 17), 180.0, 18.0, 10.0, "sign_showroom", Mats.tex("white_rough_plaster", 2.0, Color(0.95, 0.95, 0.92)), Color(0.18, 0.5, 0.5), true)
	spots["diner"] = Vector3(c.x - 18, y, c.z - 10)
	spots["cd_post"] = Vector3(c.x + 15, y, c.z + 8)
	spots["showroom"] = Vector3(c.x - 4, y, c.z + 11)
	# Halcyon billboard
	var bb := Node3D.new()
	add_child(bb)
	bb.position = Vector3(c.x - 22, gy(c.x - 22, c.z + 12), c.z + 12)
	bb.rotation_degrees.y = 60.0
	for px in [-3.5, 3.5]:
		Geo.box(bb, Vector3(px, 3.0, 0), Vector3(0.25, 6.0, 0.25), m_wood_post, true, "wood")
	Geo.box(bb, Vector3(0, 6.0, -0.06), Vector3(8.4, 4.3, 0.1), Mats.color(Color(0.3, 0.3, 0.3)), false)
	Geo.decal_quad(bb, Vector3(0, 6.0, 0.0), Vector2(8.0, 4.0), Mats.gen("billboard_halcyon_aged" if after else "billboard_halcyon", 0.7))
	# benches, lamps, picnic tables, a flagpole
	for k in 4:
		var a2 := TAU * k / 4.0 + PI * 0.25
		var bp := Vector3(c.x + cos(a2) * 8.0, y + 0.07, c.z + sin(a2) * 8.0)
		Props.spawn(self, "painted_wooden_bench", bp, rad_to_deg(-a2) + 90.0)
	Props.spawn(self, "wooden_picnic_table", Vector3(c.x + 10, y + 0.07, c.z - 6), 20.0)
	Geo.box(self, Vector3(c.x + 11, y + 5.0, c.z + 3), Vector3(0.12, 10.0, 0.12), Mats.color(Color(0.85, 0.85, 0.85), 0.3, 0.8), true, "metal")
	if not after:
		var flag := Geo.decal_quad(self, Vector3(c.x + 11.75, y + 9.3, c.z + 3), Vector2(1.5, 0.95), Mats.gen("logo_halcyon_color", 0.8), Vector3(0, PI * 0.5, 0))
	var welcome := Node3D.new()
	add_child(welcome)
	var wp := Vector3(-24, 0, 30)
	welcome.position = Vector3(wp.x - 6, gy(wp.x - 6, wp.z), wp.z)
	welcome.rotation_degrees.y = 90.0
	for px in [-1.6, 1.6]:
		Geo.box(welcome, Vector3(px, 1.2, 0), Vector3(0.15, 2.4, 0.15), m_wood_post, true, "wood")
	Geo.decal_quad(welcome, Vector3(0, 2.0, 0.08), Vector2(3.6, 1.8), Mats.gen("sign_welcome_aged" if after else "sign_welcome", 0.7))
	Geo.decal_quad(welcome, Vector3(0, 2.0, -0.08), Vector2(3.6, 1.8), Mats.gen("sign_welcome_aged" if after else "sign_welcome", 0.7), Vector3(0, PI, 0))


func _shop(local_pos: Vector3, facing: float, w: float, d: float, sign: String, wall_mat: Material, awning: Color, big_windows: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	var y := gy(local_pos.x, local_pos.z)
	root.position = Vector3(local_pos.x, y, local_pos.z)
	root.rotation_degrees.y = facing
	var hw := w * 0.5
	var hd := d * 0.5
	var h := 4.2
	var inner := Mats.tex("white_rough_plaster", 2.0, Color(0.6, 0.58, 0.55) if after else Color(0.9, 0.88, 0.82))
	var glass := Mats.glass(Color(0.6, 0.72, 0.78, 0.25), after)
	var trim := Mats.color(Color(0.2, 0.2, 0.22), 0.4, 0.6)
	var ops := [{"at": hw - (-hw * 0.55), "w": w * 0.32, "y0": 0.6, "y1": 3.0}, {"at": hw, "w": 1.6, "y0": 0.0, "y1": 2.6}, {"at": hw - hw * 0.55, "w": w * 0.32, "y0": 0.6, "y1": 3.0}]
	Geo.box(root, Vector3(0, 0.05, 0), Vector3(w, 0.2, d), Mats.tex("square_tiles" if not after else "damaged_concrete_floor", 1.5), true, "concrete")
	Geo.wall(root, Vector3(hw, 0, hd), Vector3(-hw, 0, hd), h, 0.25, inner, wall_mat, ops)
	Geo.wall(root, Vector3(-hw, 0, hd), Vector3(-hw, 0, -hd), h, 0.25, inner, wall_mat)
	Geo.wall(root, Vector3(hw, 0, -hd), Vector3(hw, 0, hd), h, 0.25, inner, wall_mat)
	Geo.wall(root, Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, 0.25, inner, wall_mat)
	Geo.box(root, Vector3(0, h + 0.1, 0), Vector3(w + 0.3, 0.25, d + 0.3), Mats.color(Color(0.3, 0.3, 0.3)), true)
	Geo.box(root, Vector3(0, h + 0.5, hd + 0.05), Vector3(w + 0.3, 0.8, 0.15), wall_mat, false)
	for o in ops:
		if o.y0 > 0.0:
			Geo.window(root, Vector3(hw, 0, hd), Vector3(-hw, 0, hd), 0.25, o, trim, glass, after)
	# striped awning
	var aw := Geo.box(root, Vector3(0, 3.35, hd + 0.75), Vector3(w * 0.9, 0.06, 1.5), Mats.color(awning if not after else awning.darkened(0.4), 0.8), false)
	aw.rotation.x = 0.28
	# sign board
	Geo.decal_quad(root, Vector3(0, h + 0.5, hd + 0.14), Vector2(minf(w * 0.7, 8.0), minf(w * 0.7, 8.0) * 0.25), Mats.gen(sign + ("_aged" if after else ""), 0.6, 0.0))
	# interior dressing: counter + shelves
	Geo.box(root, Vector3(0, 0.5, -hd + 2.0), Vector3(w * 0.6, 1.0, 0.7), Mats.tex("dark_wood", 1.0), true, "wood")
	if Props.exists("steel_frame_shelves_01"):
		pass
	if sign == "sign_diner":
		for k in 4:
			Props.spawn(root, "bar_chair_round_01" if Props.exists("bar_chair_round_01") else "metal_stool_01", Vector3(-w * 0.25 + k * w * 0.17, 0.1, -hd + 2.8), 0.0)
	var light := Geo.omni(root, Vector3(0, 3.6, 0), Color(1.0, 0.85, 0.6), 0.0 if after else 0.0, 10.0, false)
	street_lights.append(light)
	if sign == "sign_cd_post":
		spots["cd_locker"] = root.to_global(Vector3(-hw + 0.8, 0.1, -hd + 1.2))
		var locker := Geo.box(root, Vector3(-hw + 0.5, 1.0, -hd + 1.2), Vector3(0.6, 2.0, 1.2), Mats.color(Color(0.3, 0.4, 0.32), 0.5, 0.6), true, "metal")
		cd_locker = Interactable.make(root, Vector3(-hw + 0.9, 1.0, -hd + 1.2), Vector3(0.4, 1.6, 1.2), "Open", "Weapons Locker")


# ------------------------------------------------------------------ furniture

func _street_furniture() -> void:
	var lamp_i := 0
	for r in Layout.ROADS:
		if r.kind == "path":
			continue
		var samples := _sample_poly(r.pts, 2.0)
		var hw: float = r.w * 0.5
		for i in range(4, samples.size(), 14):
			var p: Vector2 = samples[i]
			var n := _perp(samples, i)
			var side := 1.0 if lamp_i % 2 == 0 else -1.0
			lamp_i += 1
			var lp := p + n * side * (hw + 1.4)
			var ly := Layout.road_center_h(p) + 0.16
			var lamp := Props.spawn(self, "street_lamp_01", Vector3(lp.x, ly, lp.y), rad_to_deg(atan2(n.x, n.y)) + (180.0 if side > 0 else 0.0), {"shrink": 0.0})
			if lamp:
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.78, 0.5)
				l.light_energy = 2.2
				l.omni_range = 16.0
				l.shadow_enabled = false
				l.position = Vector3(0, 3.6, 0)
				l.visible = false
				lamp.add_child(l)
				if not after or rng.randf() < 0.0:
					street_lights.append(l)
		# utility poles + wires on the far side
		if r.name in ["gull_lane", "coast_road", "bluff_road"]:
			var prev_tops: Array = []
			for i in range(0, samples.size(), 18):
				var p2: Vector2 = samples[i]
				var n2 := _perp(samples, i)
				var pp := p2 - n2 * (hw + (3.4 if r.walk else 2.2))
				var py := Layout.height(pp.x, pp.y)
				var pole := Node3D.new()
				add_child(pole)
				pole.position = Vector3(pp.x, py, pp.y)
				pole.rotation.y = atan2(n2.x, n2.y)
				var pm := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.11
				cm.bottom_radius = 0.15
				cm.height = 8.5
				pm.mesh = cm
				pm.material_override = Mats.tex("pine_bark", 1.0, Color(0.55, 0.45, 0.4))
				pm.position.y = 4.25
				pole.add_child(pm)
				if after and rng.randf() < 0.15:
					pole.rotation.z = rng.randf_range(-0.2, 0.2)
				Geo.box(pole, Vector3(0, 7.8, 0), Vector3(2.0, 0.12, 0.12), m_wood_post, false)
				var tops := []
				for wx in [-0.85, 0.0, 0.85]:
					tops.append(pole.to_global(Vector3(wx, 7.86, 0)))
				var body := StaticBody3D.new()
				var cs := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.15
				cyl.height = 8.5
				cs.shape = cyl
				cs.position.y = 4.25
				body.add_child(cs)
				pole.add_child(body)
				if not prev_tops.is_empty():
					for k in 3:
						_wire(prev_tops[k], tops[k])
				prev_tops = tops
	# hydrants & trash cans along Gull Lane
	for x in [-38.0, 14.0, 44.0]:
		Props.spawn(self, "fire_hydrant", Vector3(x, Layout.road_center_h(Vector2(x, 0)) + 0.16, 4.5), 0.0, {"pick": "fire_hydrant", "shrink": 0.0})
	crash_spot = Vector3(14.0, Layout.road_center_h(Vector2(14, 0)) + 0.16, 4.5)
	for x in [-30.0, 36.0]:
		Props.spawn(self, "metal_trash_can", Vector3(x, Layout.road_center_h(Vector2(x, 0)) + 0.16, -4.8), 0.0, {"pick": "metal_trash_can_rust" if after else "metal_trash_can"})
	# street signs
	var sg := Node3D.new()
	add_child(sg)
	sg.position = Vector3(-26.0, Layout.road_center_h(Vector2(-22, 0)) + 0.16, 4.8)
	Geo.box(sg, Vector3(0, 1.4, 0), Vector3(0.06, 2.8, 0.06), Mats.color(Color(0.6, 0.6, 0.6), 0.4, 0.8), true, "metal")
	Geo.decal_quad(sg, Vector3(0, 2.75, 0.04), Vector2(1.2, 0.3), Mats.gen("sign_gull_lane_aged" if after else "sign_gull_lane"))
	Geo.decal_quad(sg, Vector3(0, 2.75, -0.04), Vector2(1.2, 0.3), Mats.gen("sign_gull_lane_aged" if after else "sign_gull_lane"), Vector3(0, PI, 0))
	for sp in [Vector3(66, 0, 4.6), Vector3(100, 0, -6), Vector3(128, 0, -55)]:
		var s2 := Node3D.new()
		add_child(s2)
		s2.position = Vector3(sp.x, gy(sp.x, sp.z), sp.z)
		s2.rotation_degrees.y = 200.0
		Geo.box(s2, Vector3(0, 1.2, 0), Vector3(0.06, 2.4, 0.06), Mats.color(Color(0.6, 0.6, 0.6), 0.4, 0.8), true, "metal")
		Geo.decal_quad(s2, Vector3(0, 2.2, 0.04), Vector2(1.4, 0.35), Mats.gen("sign_shelter_arrow_aged" if after else "sign_shelter_arrow"))


func _wire(a: Vector3, b: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var sag := a.distance_to(b) * 0.035
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		var up := Vector3(0, 0.012, 0)
		var q := [prev - up, p - up, p + up, prev + up]
		for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(q[idx])
		prev = p
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Mats.color(Color(0.05, 0.05, 0.05), 0.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ cars

const CAR_COLORS := [Color(0.55, 0.78, 0.75), Color(0.85, 0.3, 0.28), Color(0.95, 0.88, 0.7), Color(0.3, 0.42, 0.6), Color(0.92, 0.65, 0.7), Color(0.95, 0.95, 0.92)]


func _cars() -> void:
	var parked := [[Vector3(-44, 0, 2.6), 90.0], [Vector3(20, 0, -2.6), -90.0], [Vector3(58, 0, 2.6), 90.0], [Vector3(-23.5, 0, 30), 0.0], [Vector3(-60, 0, 118), 30.0], [Vector3(-40, 0, 138), -80.0], [Vector3(-95, 0, 80), 5.0]]
	for i in parked.size():
		var p: Vector3 = parked[i][0]
		p.y = Layout.road_center_h(Vector2(p.x, p.z)) + 0.05
		make_car(self, p, parked[i][1], CAR_COLORS[i % CAR_COLORS.size()], after)
	# driveway car at home (covered in the after era)
	var dp := Vector3(10.5, gy(10.5, -14), -14)
	if after:
		Props.spawn(self, "covered_car", dp, 0.0)
	else:
		make_car(self, dp, 0.0, Color(0.55, 0.78, 0.75), false)
	spots["crash"] = crash_spot


static func make_car(parent: Node, pos: Vector3, rot_deg: float, col: Color, aged: bool) -> Node3D:
	var car := Node3D.new()
	parent.add_child(car)
	car.position = pos
	car.rotation_degrees.y = rot_deg
	var paint := StandardMaterial3D.new()
	paint.albedo_color = col if not aged else col.darkened(0.35).lerp(Color(0.45, 0.32, 0.25), 0.35)
	paint.metallic = 0.35 if not aged else 0.1
	paint.roughness = 0.22 if not aged else 0.75
	paint.clearcoat_enabled = not aged
	paint.clearcoat = 0.8
	var chrome := Mats.color(Color(0.9, 0.9, 0.92) if not aged else Color(0.5, 0.45, 0.4), 0.12 if not aged else 0.6, 1.0)
	var glass := Mats.glass(Color(0.4, 0.5, 0.55, 0.45), aged)
	var tire := Mats.color(Color(0.06, 0.06, 0.06), 0.85)
	# lower body (long, with a slight wedge)
	Geo.box(car, Vector3(0, 0.62, 0), Vector3(1.9, 0.55, 5.0), paint, true, "metal")
	Geo.box(car, Vector3(0, 0.95, -0.15), Vector3(1.86, 0.14, 4.7), paint, false)
	# cabin: tapered greenhouse from a custom mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b0 := [Vector3(-0.9, 1.0, -1.0), Vector3(0.9, 1.0, -1.0), Vector3(0.9, 1.0, 1.1), Vector3(-0.9, 1.0, 1.1)]
	var t0 := [Vector3(-0.78, 1.5, -0.55), Vector3(0.78, 1.5, -0.55), Vector3(0.78, 1.5, 0.75), Vector3(-0.78, 1.5, 0.75)]
	var faces := [[b0[0], b0[1], t0[1], t0[0]], [b0[1], b0[2], t0[2], t0[1]], [b0[2], b0[3], t0[3], t0[2]], [b0[3], b0[0], t0[0], t0[3]]]
	for f in faces:
		var nrm: Vector3 = ((f[1] - f[0]).cross(f[3] - f[0])).normalized()
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(-nrm)
			st.add_vertex(f[idx])
	var cabin := MeshInstance3D.new()
	cabin.mesh = st.commit()
	cabin.material_override = glass
	car.add_child(cabin)
	Geo.box(car, Vector3(0, 1.53, 0.1), Vector3(1.6, 0.06, 1.35), paint, false)
	for px in [-0.84, 0.84]:
		for pz in [-0.55, 0.75]:
			var pil := Geo.box(car, Vector3(px * 0.95, 1.25, pz), Vector3(0.05, 0.5, 0.06), paint, false)
	# fins, bumpers, lights, grille
	for side in [-1.0, 1.0]:
		var fin := Geo.box(car, Vector3(side * 0.88, 1.08, 2.1), Vector3(0.08, 0.28, 0.9), paint, false)
		fin.rotation.x = -0.12
		Geo.box(car, Vector3(side * 0.62, 0.78, -2.51), Vector3(0.28, 0.22, 0.04), Mats.emissive(Color(1.0, 0.95, 0.8), 0.3), false)
		Geo.box(car, Vector3(side * 0.75, 0.9, 2.51), Vector3(0.2, 0.22, 0.04), Mats.emissive(Color(0.9, 0.15, 0.1), 0.4), false)
	Geo.box(car, Vector3(0, 0.45, -2.56), Vector3(2.0, 0.14, 0.12), chrome, false)
	Geo.box(car, Vector3(0, 0.45, 2.56), Vector3(2.0, 0.14, 0.12), chrome, false)
	Geo.box(car, Vector3(0, 0.7, -2.52), Vector3(0.9, 0.2, 0.04), chrome, false)
	Geo.box(car, Vector3(0, 0.8, 0), Vector3(1.92, 0.04, 4.6), chrome, false)
	for wx in [-0.88, 0.88]:
		for wz in [-1.6, 1.55]:
			var wh := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.36
			cm.bottom_radius = 0.36
			cm.height = 0.24
			wh.mesh = cm
			wh.material_override = tire
			wh.rotation.z = PI * 0.5
			wh.position = Vector3(wx, 0.36 if not aged else 0.3, wz)
			car.add_child(wh)
			var hub := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.2
			hm.bottom_radius = 0.2
			hm.height = 0.26
			hub.mesh = hm
			hub.material_override = chrome
			hub.rotation.z = PI * 0.5
			hub.position = wh.position
			car.add_child(hub)
	if aged:
		car.position.y -= 0.06
		car.rotation.z = randf_range(-0.03, 0.03)
	return car


# ------------------------------------------------------------------ coast, pier

func _coast() -> void:
	# wooden pier off the beach west of the square
	var start := Vector3(-102, 0, 126)
	var pier := Node3D.new()
	add_child(pier)
	var planks := Mats.tex("worn_planks" if after else "brown_planks_03", 1.5, Color(0.8, 0.75, 0.7))
	var len := 44.0
	var deck_y := 2.6
	for i in int(len / 4.0):
		var x := start.x - i * 4.0 - 2.0
		if after and i == 7:
			continue
		Geo.box(pier, Vector3(x, deck_y, start.z), Vector3(4.0, 0.18, 3.2), planks, true, "wood")
		for pz in [-1.5, 1.5]:
			var post := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.14
			cm.bottom_radius = 0.16
			cm.height = 8.0
			post.mesh = cm
			post.material_override = m_wood_post
			post.position = Vector3(x - 2.0, deck_y - 3.0, start.z + pz)
			pier.add_child(post)
			Geo.box(pier, Vector3(x, deck_y + 0.9, start.z + pz), Vector3(4.0, 0.08, 0.08), m_wood_post, false)
	Props.spawn(pier, "lifebuoy", Vector3(start.x - 12, deck_y + 0.6, start.z + 1.62), 0.0, {"collide": false})
	Props.spawn(self, "ocean_buoy", Vector3(-190, -0.4, 150), 0.0)
	Props.spawn(self, "lateral_sea_marker", Vector3(-175, -0.3, 60), 0.0)
	spots["pier"] = Vector3(start.x - 20, deck_y + 0.1, start.z)
	# beach rocks
	for i in 26:
		var z := rng.randf_range(-250, 200)
		var x := Layout.shore_x(z) + rng.randf_range(-6, 14)
		var s := rng.randf_range(0.6, 2.4)
		Props.spawn(self, "boulder_01", Vector3(x, Layout.height(x, z) - 0.3 * s, z), rng.randf() * 360.0, {"scale": s})
	# guard rail posts along the coast road (sea side)
	var samples := _sample_poly(Layout.ROADS[3].pts, 4.0)
	for i in range(3, samples.size() - 2):
		var p: Vector2 = samples[i]
		var n := _perp(samples, i)
		var gp := p + n * -4.0
		if gp.x > -85.0:
			continue
		Geo.box(self, Vector3(gp.x, Layout.road_center_h(p) + 0.45, gp.y), Vector3(0.12, 0.9, 0.12), m_wood_post, true, "wood")


# ------------------------------------------------------------------ shelter portal

func _shelter_portal() -> void:
	var p := Layout.SHELTER_PORTAL
	var y := Layout.GATE_Y
	var root := Node3D.new()
	root.name = "ShelterPortal"
	add_child(root)
	root.position = Vector3(p.x, y, p.z)
	var conc := Mats.tex("concrete_wall_008", 3.0, Color(0.82, 0.8, 0.76) if not after else Color(0.6, 0.6, 0.58))
	# retaining walls of the cut (stepped boxes rising toward the portal)
	for side in [-1.0, 1.0]:
		# one long wall whose top edge slopes from 2 m (road end) up to 13 m at the portal; the base sinks underground
		var ang := atan2(11.0, 28.0)
		var w := Geo.box(root, Vector3(-14.0, 7.5 - 9.0, side * 8.4), Vector3(30.2, 18.0, 1.2), conc, true)
		w.rotation.z = ang
		w.position = Vector3(-14.0, 7.5 - 9.0 / cos(ang), side * 8.4)
		Geo.box(root, Vector3(-14.0, 7.6, side * 8.4), Vector3(30.4, 0.3, 1.5), conc, false).rotation.z = ang
	# portal face
	Geo.box(root, Vector3(0.5, 7.0, -6.0), Vector3(1.6, 14.0, 5.0), conc, true)
	Geo.box(root, Vector3(0.5, 7.0, 6.0), Vector3(1.6, 14.0, 5.0), conc, true)
	Geo.box(root, Vector3(0.5, 10.0, 0), Vector3(1.6, 8.0, 7.2), conc, true)
	# lintel stripe tight under the header (the opening is z -3.5..3.5, y 0..6; clear height below the stripe 5.4)
	Geo.box(root, Vector3(-0.4, 5.7, 0), Vector3(0.4, 0.6, 7.4), Mats.color(Color(0.85, 0.65, 0.15), 0.6), false)
	# Walkable threshold from the road end (x 176, road top 26.05) to the hall floor (x 178.8, 26.0). Without it the
	# terrain collider stopped at x 178 (NaN hole over the shelter) leaving a 0.8 m gap, and the terrain here sits 8 cm
	# under the road, so the road's end was a 13 cm ledge the player capsule could not climb (>50 deg contact).
	Geo.box(root, Vector3(-1.45, -0.12, 0), Vector3(2.3, 0.36, 6.5), conc, true, "concrete")  # apron x 175.4..177.7, top 26.06
	Geo.box(root, Vector3(0.35, -0.11, 0), Vector3(1.3, 0.3, 7.0), Mats.tex("metal_plate", 1.0, Color(0.45, 0.45, 0.42)), true, "metal")  # sill, top 26.04
	for side in [-1.0, 1.0]:
		# invisible chamfers so the apron's 14 cm sides can be walked onto from the cut floor
		var ch := StaticBody3D.new()
		ch.set_meta("surface", "concrete")
		var chs := CollisionShape3D.new()
		var chb := BoxShape3D.new()
		chb.size = Vector3(2.4, 0.1, 0.85)
		chs.shape = chb
		ch.add_child(chs)
		root.add_child(ch)
		ch.position = Vector3(-1.4, -0.07, side * 3.65)
		ch.rotation.x = side * atan2(0.16, 0.8)
	# sign + emblem
	Geo.decal_quad(root, Vector3(-0.32, 8.2, 0), Vector2(6.0, 1.5), Mats.gen("sign_shelter9_aged" if after else "sign_shelter9"), Vector3(0, -PI * 0.5, 0))
	# blast doors (slide apart along z). Each body is itself the moving node: an AnimatableBody3D only syncs its
	# collider when its own transform changes, so moving a parent left the closed colliders behind (players got stuck).
	var door_mat := Mats.tex("metal_plate", 1.5, Color(0.6, 0.62, 0.6) if not after else Color(0.5, 0.45, 0.4))
	var stripe := Mats.color(Color(0.9, 0.7, 0.1), 0.6)
	var logo := Mats.gen("logo_halcyon_color")
	shelter_door_l = AnimatableBody3D.new()
	shelter_door_r = AnimatableBody3D.new()
	root.add_child(shelter_door_l)
	root.add_child(shelter_door_r)
	for pair in [[shelter_door_l, -1.0], [shelter_door_r, 1.0]]:
		var dn: Node3D = pair[0]
		var s: float = pair[1]
		dn.set_meta("surface", "metal")
		# closed: each leaf spans 0..3.6 from the centre line, 0.1 into the side pier and 0.15 up into the header
		dn.position = Vector3(0.3, 0, s * DOOR_CLOSED_Z)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 6.15, 3.6)
		mi.mesh = bm
		mi.material_override = door_mat
		mi.position = Vector3(0, 6.15 * 0.5, 0)
		dn.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		cs.position = mi.position
		dn.add_child(cs)
		for k in 5:
			var sb := Geo.box(dn, Vector3(-0.36, 0.5 + k * 1.1, 0), Vector3(0.02, 0.25, 3.4), stripe, false)
			sb.rotation.x = 0.5 * s
		# each leaf carries its half of the emblem, so it parts with the doors instead of hanging in the doorway
		var half := logo.duplicate() as StandardMaterial3D
		half.uv1_scale = Vector3(0.5, 1, 1)
		half.uv1_offset = Vector3(0.0 if s < 0 else 0.5, 0, 0)
		Geo.decal_quad(dn, Vector3(-0.38, 3.4, -s * (DOOR_CLOSED_Z - 0.55)), Vector2(1.1, 2.2), half, Vector3(0, -PI * 0.5, 0))
	spots["shelter_logo"] = root.to_global(Vector3(-0.08, 3.4, 0))
	# floodlights + klaxon
	for side in [-1.0, 1.0]:
		var fl := SpotLight3D.new()
		fl.light_color = Color(1.0, 0.92, 0.8)
		fl.light_energy = 4.0
		fl.spot_range = 30.0
		fl.spot_angle = 40.0
		fl.shadow_enabled = false
		root.add_child(fl)
		fl.position = Vector3(-1.5, 12.0, side * 5.0)
		fl.rotation_degrees = Vector3(-55, 90, 0)
		fl.visible = false
		street_lights.append(fl)
		Props.spawn(root, "security_light", Vector3(-0.6, 12.0, side * 5.0), -90.0, {"collide": false})
	shelter_klaxon = OmniLight3D.new()
	shelter_klaxon.light_color = Color(1.0, 0.2, 0.1)
	shelter_klaxon.light_energy = 0.0
	shelter_klaxon.omni_range = 14.0
	shelter_klaxon.position = Vector3(-1.0, 6.4, 0)
	root.add_child(shelter_klaxon)
	Geo.box(root, Vector3(-0.5, 6.4, 0), Vector3(0.3, 0.3, 0.3), Mats.emissive(Color(1.0, 0.2, 0.1), 0.6), false)
	spots["shelter_outside"] = root.to_global(Vector3(-6.0, 0.1, 0))
	spots["shelter_inside"] = root.to_global(Vector3(4.0, 0.1, 0))
	spots["shelter_gate"] = root.to_global(Vector3(-1.5, 0.1, 0))
	spots["bluff_view"] = root.to_global(Vector3(-24.0, 0.1, 0))


const DOOR_CLOSED_Z := 1.8  # leaf centre offset when shut (leaves 3.6 wide; opening half-width 3.5)
const DOOR_OPEN_Z := 5.45   # leaf spans 3.65..7.25: fully inside the side pier (z 3.5..8.5)


func open_shelter_doors(open: bool, dur := 5.0) -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(shelter_door_l, "position:z", -(DOOR_OPEN_Z if open else DOOR_CLOSED_Z), dur)
	tw.tween_property(shelter_door_r, "position:z", DOOR_OPEN_Z if open else DOOR_CLOSED_Z, dur)


# ------------------------------------------------------------------ lighthouse

func _lighthouse() -> void:
	var p := Layout.LIGHTHOUSE
	var y := gy(p.x, p.z)
	var root := Node3D.new()
	root.name = "Lighthouse"
	add_child(root)
	root.position = Vector3(p.x, y - 0.3, p.z)
	var white := Mats.tex("white_rough_plaster", 2.0, Color(0.96, 0.95, 0.92) if not after else Color(0.78, 0.76, 0.72))
	var red := Mats.tex("white_rough_plaster", 2.0, Color(0.75, 0.15, 0.12) if not after else Color(0.5, 0.2, 0.18))
	var segs := [[0.0, 8.0, 3.3, 2.9, white], [8.0, 4.0, 2.9, 2.7, red], [12.0, 7.0, 2.7, 2.3, white], [19.0, 2.5, 2.3, 2.2, red]]
	for s in segs:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.bottom_radius = s[2]
		cm.top_radius = s[3]
		cm.height = s[1]
		cm.radial_segments = 32
		mi.mesh = cm
		mi.material_override = s[4]
		mi.position.y = s[0] + s[1] * 0.5
		root.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.2
	cyl.height = 21.5
	cs.shape = cyl
	cs.position.y = 10.75
	body.add_child(cs)
	root.add_child(body)
	# gallery + lantern
	var gal := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 3.2
	gm.bottom_radius = 3.0
	gm.height = 0.3
	gal.mesh = gm
	gal.material_override = Mats.color(Color(0.15, 0.15, 0.15), 0.6, 0.6)
	gal.position.y = 21.6
	root.add_child(gal)
	for k in 20:
		var a := TAU * k / 20.0
		Geo.box(root, Vector3(cos(a) * 3.05, 22.25, sin(a) * 3.05), Vector3(0.05, 1.0, 0.05), Mats.color(Color(0.1, 0.1, 0.1), 0.5, 0.7), false)
	var lantern := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 1.6
	lm.bottom_radius = 1.6
	lm.height = 2.4
	lantern.mesh = lm
	lantern.material_override = Mats.glass(Color(0.9, 0.85, 0.6, 0.35), after)
	lantern.position.y = 23.0
	root.add_child(lantern)
	var cap := MeshInstance3D.new()
	var capm := SphereMesh.new()
	capm.radius = 1.75
	capm.height = 1.8
	capm.is_hemisphere = true
	cap.mesh = capm
	cap.material_override = Mats.color(Color(0.2, 0.25, 0.22), 0.4, 0.8)
	cap.position.y = 24.2
	root.add_child(cap)
	var lamp := MeshInstance3D.new()
	var lsm := SphereMesh.new()
	lsm.radius = 0.5
	lsm.height = 1.0
	lamp.mesh = lsm
	lamp.material_override = Mats.emissive(Color(1.0, 0.92, 0.7), 6.0)
	lamp.position.y = 23.0
	root.add_child(lamp)
	lighthouse_beam = Node3D.new()
	lighthouse_beam.position.y = 23.0
	root.add_child(lighthouse_beam)
	for s2 in [0.0, PI]:
		var sl := SpotLight3D.new()
		sl.light_color = Color(1.0, 0.93, 0.75)
		sl.light_energy = 14.0
		sl.spot_range = 400.0
		sl.spot_angle = 6.0
		sl.light_volumetric_fog_energy = 4.0
		sl.shadow_enabled = false
		sl.rotation.y = s2
		lighthouse_beam.add_child(sl)
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.9, 0.7)
	ol.light_energy = 3.0
	ol.omni_range = 18.0
	ol.position.y = 23.0
	root.add_child(ol)
	spots["lighthouse_top"] = root.to_global(Vector3(0, 23.0, 0))
	# keeper's cottage / radio station
	var cp := Layout.LH_COTTAGE
	_house(Vector3(cp.x, gy(cp.x, cp.z), cp.z), 135.0, 10.0, 7.0, Color(0.92, 0.9, 0.85), 42)
	var cot := Node3D.new()
	add_child(cot)
	cot.position = Vector3(cp.x, gy(cp.x, cp.z), cp.z)
	cot.rotation_degrees.y = 135.0
	Geo.decal_quad(cot, Vector3(0, 3.6, 3.62), Vector2(4.0, 1.0), Mats.gen("sign_radio_aged" if after else "sign_radio"))
	spots["lh_door"] = cot.to_global(Vector3(-0.4, 0.5, 5.6))
	lh_intercom = Interactable.make(cot, Vector3(0.5, 1.6, 3.7), Vector3(0.6, 0.6, 0.4), "Press", "Intercom")
	lh_intercom.enabled = false
	Geo.box(cot, Vector3(0.5, 1.6, 3.62), Vector3(0.2, 0.28, 0.06), Mats.color(Color(0.7, 0.6, 0.4), 0.3, 0.9), false)
	# radio mast with blinking light
	var mast := Node3D.new()
	add_child(mast)
	var mp := cot.to_global(Vector3(-4.5, 0, -2.5))
	mast.position = Vector3(mp.x, gy(mp.x, mp.z), mp.z)
	for k in 3:
		var a := TAU * k / 3.0
		var leg := Geo.box(mast, Vector3(cos(a) * 0.35, 9.0, sin(a) * 0.35), Vector3(0.06, 18.0, 0.06), Mats.color(Color(0.65, 0.65, 0.65), 0.5, 0.8), false)
	for k in 9:
		Geo.box(mast, Vector3(0, 1.0 + k * 2.0, 0), Vector3(0.7, 0.04, 0.7), Mats.color(Color(0.65, 0.65, 0.65), 0.5, 0.8), false)
	var red_l := OmniLight3D.new()
	red_l.light_color = Color(1, 0.1, 0.05)
	red_l.omni_range = 6.0
	red_l.position.y = 18.2
	red_l.name = "MastLight"
	mast.add_child(red_l)
	Geo.box(mast, Vector3(0, 18.1, 0), Vector3(0.2, 0.2, 0.2), Mats.emissive(Color(1, 0.1, 0.05), 3.0), false)
	spots["mast"] = mast.global_position


func _process(delta: float) -> void:
	if lighthouse_beam:
		lighthouse_beam.rotation.y += delta * 0.6
	if shelter_klaxon and shelter_klaxon.get_meta("on", false):
		shelter_klaxon.light_energy = 3.0 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))


# ------------------------------------------------------------------ vegetation

func _vegetation() -> void:
	# street trees along Main Street and in the square
	for t in [Vector2(-30, 25), Vector2(-14, 26), Vector2(-33, 60), Vector2(-18, 62), Vector2(-46, 96), Vector2(-28, 100), Vector2(-75, 132), Vector2(-38, 150)]:
		Foliage.place_tree(self, Vector3(t.x, gy(t.x, t.y), t.y), "dead" if after and rng.randf() < 0.3 else "maple", int(t.x * 7 + t.y), after)
	# pines on the bluff, hills and headland
	var placed := 0
	var tries := 0
	while placed < 140 and tries < 2000:
		tries += 1
		var x := rng.randf_range(-200, 300)
		var z := rng.randf_range(-380, 300)
		var h := Layout.height(x, z)
		if h < 4.0:
			continue
		if Layout.road_edge_dist(x, z) < 6.0 or not Layout.pad_at(x, z).is_empty():
			continue
		if Vector2(x, z).distance_to(Vector2(-10, 50)) < 95.0 and rng.randf() < 0.85:
			continue
		if Vector2(x, z).distance_to(Vector2(195, -95)) < 25.0:
			continue
		var kind := "pine" if (x > 80 or z < -120 or rng.randf() < 0.5) else "maple"
		if after and rng.randf() < 0.25:
			kind = "dead"
		Foliage.place_tree(self, Vector3(x, h, z), kind, placed + 300, after, rng.randf_range(0.9, 1.4))
		placed += 1
	# shrubs and ferns scattered
	for i in 60:
		var x2 := rng.randf_range(-90, 140)
		var z2 := rng.randf_range(-80, 170)
		if Layout.road_edge_dist(x2, z2) < 3.0 or not Layout.pad_at(x2, z2).is_empty():
			continue
		var id: String = ["shrub_02", "fern_02", "shrub_03", "shrub_04"][i % 4]
		var pick := ""
		if id == "shrub_02":
			pick = ["shrub_02_a", "shrub_02_b", "shrub_02_c", "shrub_02_d"][i % 4]
		elif id == "fern_02":
			pick = ["fern_02_a", "fern_02_b", "fern_02_c", "fern_02_d"][i % 4]
		elif id == "shrub_03":
			pick = "shrub_03_a"
		var opts := {"collide": false}
		if pick != "":
			opts.pick = pick
		Props.spawn(self, id, Vector3(x2, Layout.height(x2, z2), z2), rng.randf() * 360.0, opts)
	# grass
	var accept := func(x: float, z: float) -> bool:
		var h := Layout.height(x, z)
		if h < 3.3:
			return false
		if Layout.road_edge_dist(x, z) < 0.0:
			return false
		var pd := Layout.pad_at(x, z)
		if not pd.is_empty() and pd.d < -1.0:
			return false
		if absf(x - Layout.SQUARE.x) < 16 and absf(z - Layout.SQUARE.z) < 12:
			return false
		return true
	Foliage.grass_field(self, Rect2(-110, -60, 260, 230), 0.55 if not after else 0.8, accept, after, 3)
	Foliage.grass_field(self, Rect2(-175, -300, 80, 120), 0.45, accept, after, 4)


# ------------------------------------------------------------------ bloom (after era)

func _crystals_at(pos: Vector3, n: int, size: float) -> void:
	if not ResourceLoader.exists("res://src/actors/fx/bloom_kit.gd"):
		return
	var r := RandomNumberGenerator.new()
	r.seed = int(pos.x * 13 + pos.z * 7)
	for i in n:
		var c: Node3D = BloomKit.make_crystal_cluster(r, size * r.randf_range(0.6, 1.4))
		add_child(c)
		var off := Vector3(r.randf_range(-1.5, 1.5), 0, r.randf_range(-1.5, 1.5))
		c.global_position = pos + off + Vector3(0, -0.1, 0)
		c.rotation = Vector3(r.randf_range(-0.3, 0.3), r.randf() * TAU, r.randf_range(-0.3, 0.3))


func _bloom_growth() -> void:
	if not ResourceLoader.exists("res://src/actors/fx/bloom_kit.gd"):
		return
	# MultiMesh scatter of crystal clusters + glowing flowers over the whole town
	var cluster_mesh: Mesh = BloomKit.cluster_mesh(7, 1.0)
	var flower_mesh: Mesh = BloomKit.flower_mesh(3)
	var xf_c: Array[Transform3D] = []
	var xf_f: Array[Transform3D] = []
	for i in 2600:
		var x := rng.randf_range(-170, 200)
		var z := rng.randf_range(-300, 190)
		var h := Layout.height(x, z)
		if h < 2.5:
			continue
		if Layout.road_edge_dist(x, z) < 0.0 and rng.randf() < 0.8:
			continue
		var s := rng.randf_range(0.4, 1.6)
		var b := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)).scaled(Vector3.ONE * s)
		if i % 3 == 0:
			xf_c.append(Transform3D(b, Vector3(x, h - 0.15, z)))
		else:
			xf_f.append(Transform3D(b.scaled(Vector3.ONE * 0.7), Vector3(x, h - 0.02, z)))
	for pair in [[cluster_mesh, xf_c], [flower_mesh, xf_f]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[0]
		var arr: Array = pair[1]
		mm.instance_count = arr.size()
		for k in arr.size():
			mm.set_instance_transform(k, arr[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 160.0
		add_child(mmi)
	# hero growths at landmarks
	for p in [Vector3(-40, 0, 110), Vector3(-70, 0, 140), Vector3(120, 0, -60), Vector3(30, 0, 8), Vector3(-90, 0, -100), Vector3(-120, 0, -200)]:
		_crystals_at(Vector3(p.x, gy(p.x, p.z), p.z), 6, 1.8)
