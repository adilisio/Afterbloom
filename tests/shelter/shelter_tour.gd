extends "res://src/main.gd"
## Shelter No. 9 checks, run on the real world build (reuses main.gd's make_world).
##   Godot --path . res://tests/shelter/shelter_tour.tscn -- --mode=walk|kerb|views|audit [--era=before|after]
##     walk   drives the player (simulated move_forward) out through the portal and back in; prints positions, PASS/FAIL
##     views  captures shots/sh_<era>_<view>.png (optional --only=a,b  --doors=open|closed  --power=0|1  --hour=12)
##     audit  lists props/pickups whose underside is not resting on anything (gap > 4 cm)
##     leaks  casts rays in all directions from points inside every room (doors shut); any ray that escapes the
##            shelter's colliders or reaches the terrain/town is a hole you could see the outside through

const VIEWS := {
	# name: [pos (feet), yaw, pitch]   yaw 0 = north (-Z), 90 = west (-X), -90 = east (+X)
	"hall_out": [Vector3(186, 26, -95), 90.0, 5.0],
	"hall_door_l": [Vector3(181.5, 26, -93.5), 120.0, 12.0],
	"hall_door_r": [Vector3(181.5, 26, -96.5), 60.0, 12.0],
	"hall_in": [Vector3(180.5, 26, -95), -90.0, 0.0],
	"gate_out": [Vector3(170, 26, -95), -90.0, 4.0],
	"gate_close": [Vector3(175.5, 26, -95), -90.0, 12.0],
	"ramp_down": [Vector3(193, 26, -95), -90.0, -12.0],
	"ramp_up": [Vector3(213.5, 20, -95), 90.0, 22.0],
	"ramp_ceil": [Vector3(203, 23, -94), 90.0, 50.0],
	"ramp_ceil2": [Vector3(203, 23, -96), -90.0, 50.0],
	"conc_w": [Vector3(229, 20, -95), 90.0, 4.0],
	"conc_s": [Vector3(222, 20, -100), 180.0, 0.0],
	"conc_n": [Vector3(222, 20, -88), 0.0, 0.0],
	"conc_desk": [Vector3(222, 20, -92.2), 180.0, -32.0],
	"ward_e": [Vector3(220, 20, -112), -90.0, 4.0],
	"ward_se": [Vector3(228, 20, -114), -130.0, 6.0],
	"ward_w": [Vector3(236, 20, -112), 90.0, 2.0],
	"ward_bunk": [Vector3(233, 20, -109.5), 160.0, -30.0],
	"ward_breach": [Vector3(221, 20, -114), 10.0, 0.0],
	"office": [Vector3(218, 20, -82.5), 180.0, -22.0],
	"storage": [Vector3(226, 20, -82.5), 180.0, -10.0],
	"storage_l": [Vector3(226, 20, -79), 90.0, -18.0],
	"storage_r": [Vector3(226, 20, -79), -90.0, -18.0],
	"gen": [Vector3(234, 20, -94), -40.0, 0.0],
	"gen_box": [Vector3(235, 20, -88), 120.0, -10.0],
	"ward_s_gap": [Vector3(236, 20, -112), 180.0, 4.0],
	"ward_s_gap2": [Vector3(234, 20, -110), -150.0, 8.0],
	"ward_posts": [Vector3(229, 20, -112), 146.0, -12.0],
	"intercom": [Vector3(227.8, 20, -110), 168.0, -5.0],
	"breach": [Vector3(218.2, 20, -116.5), 0.0, 2.0],
	"breach_close": [Vector3(218.4, 20, -119.9), -5.0, 8.0],
	"desk": [Vector3(218, 20, -79.4), 180.0, -42.0],
	"crates_e": [Vector3(227.2, 20, -81.3), -90.0, -35.0],
	"crates_w": [Vector3(224.8, 20, -81.85), 90.0, -38.0],
	"powerbox": [Vector3(233.0, 20, -87.6), 150.0, -5.0],
	"alarm": [Vector3(230.8, 20, -97.8), -141.0, -5.0],
	"gate_panel": [Vector3(181, 26, -97), 36.0, -12.0],
	"conc_ne": [Vector3(218, 20, -100), -60.0, 6.0],
}

var _sh: Shelter


func _ready() -> void:
	hud = Hud.new()
	add_child(hud)
	dialogue = Dialogue.new()
	dialogue.hud = hud
	add_child(dialogue)
	reader = Reader.new()
	add_child(reader)
	_in_game = true
	Game.set_flag("god")
	var era: String = Game.shot_args.get("era", "after")
	await make_world(era)
	_sh = world.shelter
	world.set_time(float(Game.shot_args.get("hour", "12")))
	world.set_weather("clear", 0.0)
	match String(Game.shot_args.get("mode", "views")):
		"walk":
			await _walk()
		"kerb":
			await _kerb()
		"audit":
			await _audit()
		"leaks":
			await _leaks()
		_:
			await _views(era)
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


## Hold move_forward for dur seconds from pos facing yaw; returns the final position.
func _drive(pos: Vector3, yaw: float, dur: float, label: String) -> Vector3:
	player.teleport(pos, yaw)
	await _wait(0.5)
	Input.action_press("move_forward")
	var t := 0.0
	while t < dur:
		await _wait(0.25)
		t += 0.25
		var p := player.global_position
		var hits := ""
		for i in player.get_slide_collision_count():
			var c := player.get_slide_collision(i)
			if absf(c.get_normal().y) < 0.7:
				hits += " wall:%s n=%s at=%s" % [(c.get_collider() as Node).get_path(), c.get_normal(), c.get_position()]
		print("[walk] %s t=%.2f pos=(%.2f, %.2f, %.2f) floor=%s locked=%d%s" % [label, t, p.x, p.y, p.z, player.is_on_floor(), Game.input_locked, hits])
	Input.action_release("move_forward")
	await _wait(0.3)
	return player.global_position


## Player step-up: walk across Gull Lane (lawn -> sidewalk -> kerb -> road -> kerb -> sidewalk -> lawn), both ways.
func _kerb() -> void:
	await _wait(4.0)
	var ok := true
	for x in [10.0, 38.0]:
		for dir in [[-8.5, 180.0, 1.0], [8.5, 0.0, -1.0]]:
			var z0: float = dir[0]
			var p := await _drive(Vector3(x, Layout.height(x, z0) + 0.1, z0), dir[1], 4.5, "kerb x=%d" % int(x))
			var crossed: bool = p.z * float(dir[2]) > 6.0
			ok = ok and crossed
			print("[walk] KERB x=%d from z=%.1f %s final=%s" % [int(x), z0, "PASS" if crossed else "FAIL", p])
	print("[walk] RESULT ", "PASS" if ok else "FAIL")


func _walk() -> void:
	await _wait(4.0)  # shader hitches
	var town := world.town
	town.open_shelter_doors(true, 0.1)
	await _wait(0.5)
	var outside: Vector3 = town.spot("shelter_outside")
	var gate_in: Vector3 = _sh.spot("gate_inside")
	var ok := true
	# out: from the gate panel spot toward -X, past the portal and onto the road
	var p := await _drive(gate_in + Vector3(0, 0.05, 0), 90.0, 4.0, "out")
	var out_ok := p.x < outside.x + 3.0 and absf(p.y - outside.y) < 1.0
	print("[walk] OUT %s final=%s outside=%s" % ["PASS" if out_ok else "FAIL", p, outside])
	ok = ok and out_ok
	# out at an angle from deeper in the hall, brushing the door jamb
	p = await _drive(_sh.spot("entry") + Vector3(0, 0.05, 2.5), 75.0, 5.0, "out_diag")
	var diag_ok := p.x < 177.0 and p.y > 25.0
	print("[walk] OUT_DIAG %s final=%s" % ["PASS" if diag_ok else "FAIL", p])
	ok = ok and diag_ok
	# onto the apron from the cut floor beside it (north side, walking south)
	p = await _drive(Vector3(176.6, 26.1, -100.5), 180.0, 1.6, "side")
	var side_ok := p.z > -97.5 and p.y > 26.03
	print("[walk] SIDE %s final=%s" % ["PASS" if side_ok else "FAIL", p])
	ok = ok and side_ok
	# in: from the road into the hall
	p = await _drive(outside + Vector3(0, 0.05, 0), -90.0, 4.0, "in")
	var in_ok := p.x > 184.0 and absf(p.y - 26.0) < 0.5
	print("[walk] IN %s final=%s" % ["PASS" if in_ok else "FAIL", p])
	ok = ok and in_ok
	# in, then on down the ramp to the concourse
	p = await _drive(Vector3(186, 26.05, -95), -90.0, 10.0, "ramp")
	var ramp_ok := p.x > 210.0 and absf(p.y - 20.0) < 0.5
	print("[walk] RAMP %s final=%s" % ["PASS" if ramp_ok else "FAIL", p])
	ok = ok and ramp_ok
	# shut: the doors' colliders must close with the leaves (they used to stay wherever the doors were built)
	town.open_shelter_doors(false, 0.1)
	await _wait(0.5)
	p = await _drive(gate_in + Vector3(0, 0.05, 0), 90.0, 2.0, "shut")
	var shut_ok := p.x > 178.6
	print("[walk] SHUT %s final=%s" % ["PASS" if shut_ok else "FAIL", p])
	ok = ok and shut_ok
	print("[walk] RESULT ", "PASS" if ok else "FAIL")


func _views(era: String) -> void:
	var doors: String = Game.shot_args.get("doors", "closed")
	world.town.open_shelter_doors(doors == "open", 0.1)
	if Game.shot_args.get("power", "1") == "1":
		_sh.set_power(true)
	player.set_physics_process(false)
	_story_pickups()
	var only: Array = Array(String(Game.shot_args.get("only", "")).split(",", false))
	var first := true
	for name: String in VIEWS:
		if not only.is_empty() and not only.has(name):
			continue
		var v: Array = VIEWS[name]
		player.teleport(v[0], v[1])
		player.set_look(v[1], v[2])
		player.flashlight.visible = Game.shot_args.get("flash", "0") == "1"
		await ShotUtil.capture(get_tree(), "shots/sh_%s_%s.png" % [era, name], 12.0 if first else 1.2, false)
		first = false


## The pickups ch3_wake places (after era), at the shelter's surface spots (same calls as story.gd).
func _story_pickups() -> void:
	if world.era != "after":
		return
	Pickup.spawn_note(world, _sh.spot("bunk31_crate_top"), "note_june", "A note from June", "june_note")
	Pickup.spawn_magazine(world, _sh.spot("desk_top"), "astounding", 30.0)
	Pickup.spawn_item(world, _sh.spot("shelf_top"), "pep_tonic", 1, "")
	Pickup.spawn_item(world, _sh.spot("beans"), "beans", 1, "long_life_food", "long_life_food_beans")
	Pickup.spawn_item(world, _sh.spot("fuse"), "fuse", 1, "medical_tape")


func _audit() -> void:
	await _wait(2.0)
	_story_pickups()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := world.get_world_3d().direct_space_state
	var roots: Array[Node3D] = []
	for n in _sh.get_children():
		if n is Node3D and (Props.exists(String(n.name)) or n is Pickup):
			roots.append(n)
	for n in world.get_children():
		if n is Pickup:
			roots.append(n)
	var bad := 0
	for n in roots:
		var lb := Props.local_aabb(n)
		if lb.size.length() < 0.001:
			continue
		var gb: AABB = n.global_transform * lb
		var bottom := gb.position.y
		var excl: Array[RID] = []
		for b in n.find_children("*", "CollisionObject3D", true, false):
			excl.append((b as CollisionObject3D).get_rid())
		var best := -INF
		var c := gb.get_center()
		for o in [Vector2(0, 0), Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
			var from := Vector3(c.x + o.x * gb.size.x, bottom + 0.03, c.z + o.y * gb.size.z)
			var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -3.0, 0), 1)
			q.exclude = excl
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				best = maxf(best, (hit.position as Vector3).y)
		var gap := bottom - best
		var tag := "ok"
		if best == -INF or gap > 0.04:
			tag = "FLOAT"
			# wall-mounted? (a wall within 4 cm of the bounds along +-x or +-z)
			for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
				var half := absf(d.dot(gb.size)) * 0.5
				var q2 := PhysicsRayQueryParameters3D.create(c, c + d * (half + 0.04), 1)
				q2.exclude = excl
				if not space.intersect_ray(q2).is_empty():
					tag = "wall"
			if tag == "FLOAT":
				bad += 1
		elif gap < -0.04:
			tag = "SUNK"
		print("[audit] %-6s %-28s bottom=%.3f surface=%.3f gap=%.3f top=%.3f at (%.2f, %.2f)" % [tag, n.name, bottom, best, gap, gb.end.y, c.x, c.z])
	print("[audit] %d of %d float" % [bad, roots.size()])


func _leaks() -> void:
	if Game.shot_args.get("doors", "closed") == "open":
		world.town.open_shelter_doors(true, 0.1)  # sanity check: the hall points should then leak
	await _wait(1.0)
	var space := world.get_world_3d().direct_space_state
	var pts := [
		Vector3(181, 27.6, -95), Vector3(186, 30.5, -97.5), Vector3(192, 27.6, -93), Vector3(197, 26.8, -95), Vector3(203, 24.5, -95.5), Vector3(209, 22.6, -94),
		Vector3(214, 21.6, -104), Vector3(222, 23.5, -95), Vector3(230, 21.6, -86), Vector3(230, 24.2, -105.5),
		Vector3(215, 21.6, -121), Vector3(227, 23.2, -114), Vector3(239, 21.6, -107), Vector3(239, 23.3, -121), Vector3(233, 21.0, -110),
		Vector3(218, 21.6, -80), Vector3(215, 23.2, -77), Vector3(226, 21.6, -80), Vector3(229.5, 23.2, -83.5),
		Vector3(238, 21.6, -92), Vector3(243.5, 23.8, -99.5), Vector3(233, 21.6, -85),
	]
	if world.era == "after":
		pts.append(Vector3(Shelter.BREACH_X, 21.0, -122.6))  # inside the breach's rock pocket
	var n := 0
	var golden := PI * (3.0 - sqrt(5.0))
	for p: Vector3 in pts:
		var bad := 0
		for i in 1200:
			var yv := 1.0 - (i + 0.5) / 1200.0 * 2.0
			var r := sqrt(1.0 - yv * yv)
			var dir := Vector3(cos(golden * i) * r, yv, sin(golden * i) * r)
			var q := PhysicsRayQueryParameters3D.create(p, p + dir * 80.0, 1)
			var hit := space.intersect_ray(q)
			var leak := ""
			if hit.is_empty():
				leak = "escapes"
			else:
				var col: Node = hit.collider
				var path := String(col.get_path())
				if not path.contains("/Shelter/") and not path.contains("ShelterPortal"):
					leak = "hits " + path
			if leak != "":
				bad += 1
				if bad <= 6:
					print("[leak] from %s dir %s %s at %s" % [p, dir.snapped(Vector3.ONE * 0.01), leak, hit.get("position", p + dir * 80.0)])
		n += bad
		print("[leak] point %s: %d of 1200 rays leak" % [p, bad])
	print("[leak] TOTAL ", n)
