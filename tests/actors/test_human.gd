extends Node3D
## HumanModel test. Run with a window: `-- --only=gallery|presets|faces|expr|poses|walk|gestures|outfits|crowd|dirty|panic|api|world|light|perf`
## Screenshots go to shots/human_<name>.png.
const Stage := preload("res://tests/actors/actor_stage.gd")

var cam: Camera3D


func _ready() -> void:
	cam = Stage.build(self)
	var only := Stage.arg("only", "presets")
	match only:
		"presets": await _presets()
		"faces": await _faces()
		"expr": await _expr()
		"poses": await _poses()
		"walk": await _walk()
		"gestures": await _gestures()
		"outfits": await _outfits()
		"crowd": await _crowd()
		"gallery": await _gallery()
		"dirty": await _dirty()
		"panic": await _panic()
		"api": await _api()
		"world": await _world_props()
		"light": await _light()
		"perf": await _perf()
	get_tree().quit()


func _snap(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := ProjectSettings.globalize_path("res://shots/human_" + file_name + ".png")
	img.save_png(p)
	print("[shot] ", p)


func _at(m: HumanModel, pos: Vector3, yaw_deg := 0.0) -> HumanModel:
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	add_child(m)
	return m


func _trio() -> Array[HumanModel]:
	var j := _at(HumanModel.make_preset("june"), Vector3(-0.8, 0, 0), 180.0)
	var r := _at(HumanModel.make_preset("rory"), Vector3(0, 0, 0), 180.0)
	var w := _at(HumanModel.make_preset("warden"), Vector3(0.8, 0, 0), 180.0)
	return [j, r, w]


func _presets() -> void:
	var t := _trio()
	Stage.look(cam, Vector3(0, 1.1, 3.6), Vector3(0, 0.95, 0))
	await Stage.wait(get_tree(), 2.0)
	await _snap("presets_front")
	Stage.look(cam, Vector3(2.8, 1.25, 2.2), Vector3(0, 0.95, 0))
	await Stage.wait(get_tree(), 0.2)
	await _snap("presets_34")
	Stage.look(cam, Vector3(0, 1.3, -3.2), Vector3(0, 0.95, 0))
	await Stage.wait(get_tree(), 0.2)
	await _snap("presets_back")
	for i in 3:
		var p := t[i].global_position
		Stage.look(cam, p + Vector3(0.0, 1.25, 1.35), p + Vector3(0, 1.08, 0))
		await Stage.wait(get_tree(), 0.2)
		await _snap("torso_%d" % i)
	for m in t:
		print(m.get_height())


func _faces() -> void:
	var t := _trio()
	var names := ["june", "rory", "warden"]
	await Stage.wait(get_tree(), 1.5)
	for i in 3:
		var m := t[i]
		var head := m.get_head_node().global_position + Vector3(0, 0.07, 0)
		for mm in t:
			mm.look_at_point(head + Vector3(0.0, 0.0, 0.8) + (Vector3(0, 0, 0) if mm == m else Vector3.ZERO))
		Stage.look(cam, head + Vector3(0, 0.0, 0.62), head)
		await Stage.wait(get_tree(), 1.0)
		await _snap("face_%s_front" % names[i])
		Stage.look(cam, head + Vector3(0.42, 0.03, 0.42), head)
		await Stage.wait(get_tree(), 0.3)
		await _snap("face_%s_34" % names[i])
		Stage.look(cam, head + Vector3(0.6, 0.0, 0.0), head)
		await Stage.wait(get_tree(), 0.3)
		await _snap("face_%s_side" % names[i])


func _expr() -> void:
	var m := _at(HumanModel.make_preset("june"), Vector3(-0.45, 0, 0), 180.0)
	var r := _at(HumanModel.make_preset("rory"), Vector3(0.45, 0, 0), 180.0)
	await Stage.wait(get_tree(), 1.2)
	var ex := ["neutral", "happy", "worried", "scared", "sad"]
	for e: String in ex:
		m.set_expression(e)
		r.set_expression(e)
		await Stage.wait(get_tree(), 1.0)
		var h := (m.get_head_node().global_position + r.get_head_node().global_position) * 0.5 + Vector3(0, 0.07, 0)
		Stage.look(cam, h + Vector3(0, 0, 1.25), h)
		await Stage.wait(get_tree(), 0.15)
		await _snap("expr_" + e)
	m.set_expression("neutral")
	r.set_expression("neutral")
	m.set_talking(true)
	r.set_talking(true)
	await Stage.wait(get_tree(), 1.0)
	for i in 3:
		await _snap("talk_%d" % i)
		await Stage.wait(get_tree(), 0.14)


func _poses() -> void:
	# a bench, a bed and a picnic blanket
	var bench_h := 0.46
	var bench := MeshInstance3D.new()
	bench.mesh = ModelKit.rounded_box(Vector3(2.2, 0.07, 0.5), 0.02, 2)
	bench.material_override = ModelKit.pbr("t_bench", Color(0.42, 0.28, 0.16), 0.0, 0.7)
	bench.position = Vector3(-1.8, bench_h - 0.035, 0.05)
	add_child(bench)
	var a := _at(HumanModel.make_preset("june"), Vector3(-2.3, 0, 0), 180.0)
	a.set_pose("sit", true, bench_h)
	var b := _at(HumanModel.make_preset("rory"), Vector3(-1.3, 0, 0), 180.0)
	b.set_pose("sit", true, bench_h)
	b.hold(HumanModel.make_prop("mug"), "r")
	# a bed
	var bed_h := 0.52
	var bed := MeshInstance3D.new()
	bed.mesh = ModelKit.rounded_box(Vector3(0.95, 0.5, 2.05), 0.04, 2)
	bed.material_override = ModelKit.pbr("t_bed", Color(0.66, 0.66, 0.60), 0.0, 0.9)
	bed.position = Vector3(1.0, bed_h - 0.25, 0.2)
	add_child(bed)
	var pillow := MeshInstance3D.new()
	pillow.mesh = ModelKit.rounded_box(Vector3(0.6, 0.12, 0.36), 0.05, 2)
	pillow.material_override = ModelKit.pbr("t_pillow", Color(0.86, 0.85, 0.80), 0.0, 0.9)
	pillow.position = Vector3(1.0, bed_h + 0.05, 0.98)
	add_child(pillow)
	var c := _at(HumanModel.random_townsperson(9), Vector3(1.0, 0, 0.1), 0.0)
	c.set_blanket(true)
	c.set_pose("lie", true, bed_h)
	# a picnic blanket
	var blanket := MeshInstance3D.new()
	blanket.mesh = ModelKit.box(Vector3(2.2, 0.01, 1.8))
	blanket.material_override = ModelKit.pbr("t_blanket", Color(0.62, 0.22, 0.18), 0.0, 0.95)
	blanket.position = Vector3(-1.0, 0.005, 2.7)
	add_child(blanket)
	var d := _at(HumanModel.random_townsperson(3), Vector3(-1.6, 0, 2.5), 180.0)
	d._ground_var = 0
	d.set_pose("sit_ground", true)
	var e := _at(HumanModel.random_townsperson(8), Vector3(-0.5, 0, 2.5), 180.0)
	e._ground_var = 1
	e.set_pose("sit_ground", true)
	var f := _at(HumanModel.random_townsperson(14), Vector3(2.8, 0, 2.6), 180.0)
	f.set_pose("cower", true)
	await Stage.wait(get_tree(), 1.5)
	Stage.look(cam, Vector3(-1.8, 1.25, 3.0), Vector3(-1.8, 0.7, 0))
	await Stage.wait(get_tree(), 0.3)
	await _snap("pose_bench")
	Stage.look(cam, Vector3(2.9, 1.65, 1.1), Vector3(1.0, 0.55, 0.3))
	await Stage.wait(get_tree(), 0.3)
	await _snap("pose_bed")
	Stage.look(cam, Vector3(-1.0, 1.1, 5.2), Vector3(-1.0, 0.35, 2.5))
	await Stage.wait(get_tree(), 0.3)
	await _snap("pose_ground")
	Stage.look(cam, Vector3(1.6, 1.0, 4.4), Vector3(2.8, 0.45, 2.6))
	await Stage.wait(get_tree(), 0.3)
	await _snap("pose_cower")
	Stage.look(cam, Vector3(-4.2, 1.1, 0.8), Vector3(-1.8, 0.75, 0))
	await Stage.wait(get_tree(), 0.3)
	await _snap("pose_bench_side")


var _movers: Array = []


func _process(delta: float) -> void:
	for mv: Array in _movers:
		var m: HumanModel = mv[0]
		var v: float = mv[1]
		m.position.z = wrapf(m.position.z + v * delta, -9.0, 9.0)


func _walk() -> void:
	var a := _at(HumanModel.make_preset("june"), Vector3(-0.9, 0, -7.0), 180.0)
	a.set_move_speed(1.3)
	_movers.append([a, 1.3])
	var b := _at(HumanModel.make_preset("rory"), Vector3(0.1, 0, -7.0), 180.0)
	b.set_move_speed(3.8)
	_movers.append([b, 3.8])
	var c := _at(HumanModel.make_preset("warden"), Vector3(1.1, 0, -7.0), 180.0)
	c.set_move_speed(1.3)
	c.set_panic(false)
	_movers.append([c, 1.3])
	await Stage.wait(get_tree(), 2.0)
	# follow from the side
	for i in 8:
		var z: float = a.position.z
		Stage.look(cam, Vector3(-4.2, 1.1, z), Vector3(0.0, 0.9, z))
		await RenderingServer.frame_post_draw
		await _snap("walk_%d" % i)
		await Stage.wait(get_tree(), 0.14)
	# the runner from the side
	for i in 4:
		var z: float = b.position.z
		Stage.look(cam, Vector3(3.6, 1.1, z), Vector3(0.1, 0.9, z))
		await RenderingServer.frame_post_draw
		await _snap("run_%d" % i)
		await Stage.wait(get_tree(), 0.09)
	# from the front
	a.position.z = -3.0
	await Stage.wait(get_tree(), 0.05)
	Stage.look(cam, Vector3(-0.9, 1.1, a.position.z + 3.0), Vector3(-0.9, 1.0, a.position.z))
	await Stage.wait(get_tree(), 0.05)
	await _snap("walk_front")


func _gestures() -> void:
	var names := ["wave", "point", "shrug", "hug_self", "beckon", "laugh", "gasp", "nod"]
	var times := [1.2, 1.1, 0.9, 1.5, 1.2, 0.8, 0.8, 0.3]
	var people: Array[HumanModel] = []
	for i in names.size():
		var col := i % 4
		var row := i / 4
		var m: HumanModel = _at(HumanModel.random_townsperson(30 + i), Vector3(-2.4 + col * 1.6, 0, -row * 1.7), 180.0)
		people.append(m)
	await Stage.wait(get_tree(), 1.5)
	Stage.look(cam, Vector3(0, 1.5, 3.9), Vector3(0, 0.95, -0.8))
	for i in names.size():
		var nm: String = names[i]
		people[i].play_gesture(nm)
	await Stage.wait(get_tree(), 1.0)
	await _snap("gestures")
	# each close up
	for i in names.size():
		var nm: String = names[i]
		var m: HumanModel = people[i]
		m.play_gesture(nm)
		await Stage.wait(get_tree(), float(times[i]))
		var p := m.global_position
		Stage.look(cam, p + Vector3(0.5, 1.25, 1.75), p + Vector3(0, 1.0, 0))
		await Stage.wait(get_tree(), 0.05)
		await _snap("g_" + nm)
	# props
	var a: HumanModel = people[0]
	var b: HumanModel = people[1]
	var c: HumanModel = people[2]
	var d: HumanModel = people[3]
	a.hold(HumanModel.make_prop("mug"), "r")
	b.hold(HumanModel.make_prop("pamphlets"), "r")
	c.hold(HumanModel.make_prop("radio"), "r")
	d.hold(HumanModel.make_prop("clipboard"), "l")
	await Stage.wait(get_tree(), 1.2)
	Stage.look(cam, Vector3(0, 1.3, 2.5), Vector3(0, 1.0, 0))
	await Stage.wait(get_tree(), 0.05)
	await _snap("props")
	a.play_gesture("sip")
	await Stage.wait(get_tree(), 1.3)
	var p := a.global_position
	Stage.look(cam, p + Vector3(0.7, 1.45, 1.2), p + Vector3(0, 1.3, 0))
	await Stage.wait(get_tree(), 0.05)
	await _snap("sip")


func _outfits() -> void:
	var specs := [
		{"sex": "m", "outfit": "cardigan", "hair_style": "side_part", "age": "elder", "hair_color": Color(0.7, 0.69, 0.66), "glasses": true, "glasses_style": "square", "posture": "stoop"},
		{"sex": "m", "outfit": "shirt_tie", "hair_style": "side_part", "build": "average"},
		{"sex": "f", "outfit": "dress", "hair_style": "bob", "pattern": "gingham", "top_color": Color(0.72, 0.2, 0.2), "hair_color": Color(0.75, 0.62, 0.4)},
		{"sex": "f", "outfit": "dress", "hair_style": "bun", "pattern": "floral", "age": "elder", "hair_color": Color(0.8, 0.79, 0.77), "build": "heavy"},
		{"sex": "m", "outfit": "sweater", "hair_style": "curly", "top_color": Color(0.2, 0.33, 0.24), "skin_tone": 0.82, "hair_color": Color(0.05, 0.04, 0.03)},
		{"sex": "m", "outfit": "overalls", "hair_style": "balding", "pattern": "plaid", "hair_color": Color(0.3, 0.22, 0.14), "build": "heavy"},
		{"sex": "m", "outfit": "fisherman", "hat": "fisherman", "facial_hair": "moustache", "skin_tone": 0.42},
		{"sex": "m", "outfit": "warden", "hat": "helmet"},
		{"sex": "f", "outfit": "halcyon", "hair_style": "bob", "hair_color": Color(0.1, 0.07, 0.05), "skin_tone": 0.55},
		{"sex": "f", "outfit": "cardigan", "bottom": "slacks", "hat": "headscarf", "accent_color": Color(0.72, 0.18, 0.18)},
		{"sex": "m", "age": "child", "outfit": "sweater", "hair_style": "mop", "top_color": Color(0.62, 0.3, 0.18), "bottom_color": Color(0.33, 0.25, 0.18)},
		{"sex": "f", "age": "child", "outfit": "dress", "hair_style": "ponytail", "pattern": "dots", "top_color": Color(0.25, 0.65, 0.68), "hair_color": Color(0.5, 0.22, 0.1)},
	]
	var row_w := 6
	var ppl: Array[HumanModel] = []
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var col := i % row_w
		var row := i / row_w
		var m: HumanModel = _at(HumanModel.new().setup(spec), Vector3(-2.75 + col * 1.1, 0, -row * 1.5), 180.0)
		ppl.append(m)
	await Stage.wait(get_tree(), 2.0)
	Stage.look(cam, Vector3(0, 1.1, 4.0), Vector3(0, 0.95, -0.2))
	await Stage.wait(get_tree(), 0.1)
	await _snap("outfits_a")
	for x in ppl.size():
		ppl[x].visible = x >= row_w
	Stage.look(cam, Vector3(0, 1.1, 2.6), Vector3(0, 0.9, -1.5))
	await Stage.wait(get_tree(), 0.2)
	await _snap("outfits_b")


func _spawn_crowd(n: int) -> Array[HumanModel]:
	var out: Array[HumanModel] = []
	var t0 := Time.get_ticks_msec()
	var cols := 8
	for i in n:
		var m := HumanModel.random_townsperson(100 + i)
		m.position = Vector3(-(cols - 1) * 0.7 + (i % cols) * 1.4, 0, -float(i / cols) * 1.6 - 0.2 * (i % 2))
		m.rotation_degrees.y = 180.0 + (i * 37) % 40 - 20
		add_child(m)
		out.append(m)
	print("[crowd] built %d people in %d ms" % [n, Time.get_ticks_msec() - t0])
	return out


func _crowd() -> void:
	_spawn_crowd(24)
	await Stage.wait(get_tree(), 2.5)
	Stage.look(cam, Vector3(0, 1.6, 4.5), Vector3(0, 1.0, -1.5))
	await Stage.wait(get_tree(), 0.2)
	await _snap("crowd_day")


## The named characters in front and a labelled crowd row behind them.
func _gallery() -> void:
	var names := ["june", "rory", "warden"]
	for i in 3:
		var m := _at(HumanModel.make_preset(names[i]), Vector3(-1.0 + i, 0, 1.2), 180.0)
		var lbl := Label3D.new()
		lbl.text = names[i]
		lbl.font_size = 44
		lbl.pixel_size = 0.004
		lbl.position = Vector3(0, 0.12, 0.45)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		m.add_child(lbl)
	for i in 10:
		var m := _at(HumanModel.random_townsperson(200 + i), Vector3(-4.05 + i * 0.9, 0, -0.4), 180.0)
		var lbl := Label3D.new()
		lbl.text = "seed %d" % (200 + i)
		lbl.font_size = 30
		lbl.pixel_size = 0.004
		lbl.position = Vector3(0, 0.08, 0.45)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		m.add_child(lbl)
	await Stage.wait(get_tree(), 2.5)
	Stage.look(cam, Vector3(0, 1.35, 5.1), Vector3(0, 0.9, 0))
	await Stage.wait(get_tree(), 0.2)
	await _snap("gallery")


## Panic on the spot and on the run, and eyes and head following a moving target.
func _panic() -> void:
	var a := _at(HumanModel.random_townsperson(205), Vector3(-1.1, 0, 0), 180.0)
	a.set_panic(true)
	var b := _at(HumanModel.make_preset("june"), Vector3(0.1, 0, -6.0), 180.0)
	b.set_panic(true)
	b.set_move_speed(4.2)
	_movers.append([b, 4.2])
	var c := _at(HumanModel.make_preset("rory"), Vector3(1.4, 0, 0), 180.0)
	var tgt := Vector3(3.0, 1.2, 2.5)
	c.look_at_point(tgt)
	await Stage.wait(get_tree(), 1.6)
	Stage.look(cam, Vector3(-0.3, 1.1, 3.3), Vector3(-0.3, 1.0, 0))
	await _snap("panic_0")
	await Stage.wait(get_tree(), 0.25)
	await _snap("panic_1")
	var h := c.get_head_node().global_position + Vector3(0, 0.07, 0)
	for i in 4:
		var targets := [Vector3(3.0, 1.2, 2.5), Vector3(-3.0, 2.8, 2.0), Vector3(-1.5, 0.2, 2.0), Vector3(0.0, 1.5, -3.0)]
		c.look_at_point(targets[i])
		await Stage.wait(get_tree(), 1.1)
		Stage.look(cam, h + Vector3(0, 0, 0.75), h)
		await Stage.wait(get_tree(), 0.05)
		await _snap("look_%d" % i)


## People beside the real Poly Haven props the shelter and the town use, seated by the bench's measured height.
func _world_props() -> void:
	var bench := Props.spawn(self, "painted_wooden_bench", Vector3(-0.9, 0, 0), 0.0, {"ground": true})
	var box := AABB()
	var first := true
	for m in bench.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	print("[world] bench aabb ", box)
	# the seat is the bench's mid height: a bench's back reaches well above it
	var seat := box.position.y + box.size.y * 0.5
	var chair_z := box.get_center().z
	var a := _at(HumanModel.make_preset("june"), Vector3(box.get_center().x - 0.33, 0, chair_z), 180.0)
	a.set_pose("sit", true, seat)
	var b2 := _at(HumanModel.make_preset("rory"), Vector3(box.get_center().x + 0.33, 0, chair_z), 180.0)
	b2.set_pose("sit", true, seat)
	b2.hold(HumanModel.make_prop("mug"), "r")
	Props.spawn(self, "WoodenTable_01", Vector3(1.5, 0, 0.5), 0.0, {"ground": true})
	Props.spawn(self, "metal_trash_can", Vector3(-2.6, 0, 0.3), 0.0, {"ground": true})
	_at(HumanModel.make_preset("warden"), Vector3(1.5, 0, 1.4), 180.0)
	_at(HumanModel.random_townsperson(203), Vector3(2.6, 0, 0.9), 200.0)
	var bed := Props.spawn(self, "old_bed_frame", Vector3(-1.2, 0, -3.4), 0.0, {"ground": true})
	print("[world] bed ", bed != null)
	for k: String in ["day", "warm"]:
		_set_light(k)
		Stage.look(cam, Vector3(0.0, 1.35, 4.4), Vector3(0.0, 0.85, 0.0))
		await Stage.wait(get_tree(), 2.0)
		await _snap("world_" + k)
	_set_light("day")
	Stage.look(cam, Vector3(-3.2, 1.0, 1.8), Vector3(box.get_center().x, 0.72, chair_z))
	await Stage.wait(get_tree(), 0.6)
	await _snap("world_bench_side")


## Exercises the public API. Runs headless; prints PASS or FAIL lines.
func _api() -> void:
	var ok := func(label: String, c: bool) -> void:
		print("[api] %s %s" % ["PASS" if c else "FAIL", label])
	var m := _at(HumanModel.make_preset("june"), Vector3.ZERO)
	ok.call("preset height", is_equal_approx(m.get_height(), 1.64))
	var cap := m.get_capsule()
	var cs := m.make_collision_shape()
	ok.call("capsule", cap.x > 0.15 and cap.y > 1.5 and cs.position.y > 0.5 and cs.shape is CapsuleShape3D)
	# the same seed gives the same person
	ok.call("deterministic", str(HumanModel.random_params(42)) == str(HumanModel.random_params(42)))
	var same := 0
	for i in 40:
		if str(HumanModel.random_params(i)) == str(HumanModel.random_params(i + 1)):
			same += 1
	ok.call("seeds differ", same == 0)
	# gestures: duration, signal, unknown names
	var got: Array[String] = []
	m.gesture_finished.connect(func(n: String) -> void: got.append(n))
	ok.call("gesture duration", absf(m.play_gesture("nod") - 1.1) < 0.01 and m.is_gesturing())
	ok.call("unknown gesture", m.play_gesture("backflip") == 0.0)
	# count frames, not seconds: the first frames can spend whole seconds compiling shaders
	for i in 900:
		if not m.is_gesturing():
			break
		await get_tree().process_frame
	ok.call("gesture_finished", got.has("nod") and not m.is_gesturing())
	# hold and release
	var mug := HumanModel.make_prop("mug")
	m.hold(mug, "r")
	await get_tree().process_frame
	ok.call("hold", m.get_held("r") == mug and mug.is_inside_tree())
	var hand: Vector3 = m.get_hand_node("r").global_position
	ok.call("hold reaches the hand", mug.global_position.distance_to(hand) < 0.25)
	var back := m.release("r")
	ok.call("release", back == mug and m.get_held("r") == null and mug.get_parent() == null)
	mug.free()
	# seat height: the hips sit at the right height
	m.set_pose("sit", true, 0.6)
	await get_tree().process_frame
	await get_tree().process_frame
	var hips_y: float = m._skel.get_bone_global_pose(HumanModel.HIPS).origin.y * m._rs
	ok.call("seat height (hips %.3f)" % hips_y, absf(hips_y - (0.6 + 0.135 * m._d.vy * m._rs)) < 0.03)
	var feet_y: float = m._skel.get_bone_global_pose(HumanModel.FOOT_L).origin.y * m._rs
	ok.call("feet on the floor while sitting (%.3f)" % feet_y, absf(feet_y - m._d.ankle_h * m._rs) < 0.04)
	for p: String in ["lie", "sit_ground", "cower", "stand"]:
		m.set_pose(p, true)
		await get_tree().process_frame
		ok.call("pose " + p, m.get_pose() == p)
	# rebuild after add_child, and shared meshes
	var r1 := _at(HumanModel.random_townsperson(1), Vector3(2, 0, 0))
	var r2 := _at(HumanModel.random_townsperson(1 + HumanModel.CROWD_TEMPLATES), Vector3(3, 0, 0))
	ok.call("templates share a mesh", r1._mi.mesh == r2._mi.mesh)
	r1.setup({"outfit": "warden", "hat": "helmet"})
	ok.call("setup rebuilds", r1.get_node_or_null("Rig/Skeleton/Body") != null and r1._mi.mesh != r2._mi.mesh)
	await get_tree().process_frame
	r1.set_dirty(true)
	r1.set_expression("sad")
	r1.set_talking(true)
	r1.set_panic(true)
	r1.set_move_speed(3.0)
	await Stage.wait(get_tree(), 0.3)
	ok.call("survives everything at once", is_instance_valid(r1))
	# a crowd far away and out of view does less work
	cam.global_position = Vector3(0, 2, 500)
	cam.look_at(Vector3(0, 2, 1000))
	await Stage.wait(get_tree(), 0.3)
	var t0 := r1._t
	var frames := 10
	for i in frames:
		await get_tree().process_frame
	print("[api] offscreen: %.3f s of animation time over %d frames" % [r1._t - t0, frames])
	ok.call("no missing bones", r1._skel.get_bone_count() == HumanModel.NB)


## Clean and aged side by side.
func _dirty() -> void:
	var specs := [HumanModel.PRESETS["june"], HumanModel.PRESETS["rory"], HumanModel.random_params(205)]
	for i in 3:
		_at(HumanModel.new().setup(specs[i]), Vector3(-2.2 + i * 0.75, 0, 0), 180.0)
		var d := _at(HumanModel.new().setup(specs[i]), Vector3(0.7 + i * 0.75, 0, 0), 180.0)
		d.set_dirty(true)
		d.set_expression("sad")
	await Stage.wait(get_tree(), 2.0)
	Stage.look(cam, Vector3(0, 1.1, 3.3), Vector3(0, 1.0, 0))
	await Stage.wait(get_tree(), 0.2)
	await _snap("dirty")


## Environment presets on the shared stage: "day", "warm", "red".
func _set_light(kind: String) -> void:
	var we: WorldEnvironment = null
	var sun: DirectionalLight3D = null
	for c in get_children():
		if c is WorldEnvironment:
			we = c
		elif c is DirectionalLight3D:
			sun = c
		elif c.has_meta("test_light"):
			c.queue_free()
	var env := we.environment
	match kind:
		"day":
			sun.visible = true
			env.background_mode = Environment.BG_SKY
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = 1.0
		"warm", "red":
			sun.visible = false
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.02, 0.018, 0.015)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.55, 0.42, 0.32) if kind == "warm" else Color(0.5, 0.12, 0.1)
			env.ambient_light_energy = 0.07 if kind == "warm" else 0.09
			for x: float in [-2.0, 2.0]:
				var l := OmniLight3D.new()
				l.set_meta("test_light", true)
				l.position = Vector3(x, 2.6, 1.0)
				l.light_color = Color(1.0, 0.72, 0.42) if kind == "warm" else Color(1.0, 0.12, 0.07)
				l.light_energy = 2.2 if kind == "warm" else 2.5
				l.omni_range = 7.5
				l.shadow_enabled = true
				add_child(l)


func _light() -> void:
	var t := _trio()
	var extra := _at(HumanModel.random_townsperson(14), Vector3(1.6, 0, 0.1), 180.0)
	var extra2 := _at(HumanModel.random_townsperson(22), Vector3(-1.6, 0, 0.1), 180.0)
	extra.set_talking(true)
	extra2.set_expression("happy")
	await Stage.wait(get_tree(), 1.5)
	for k: String in ["day", "warm", "red"]:
		_set_light(k)
		Stage.look(cam, Vector3(0, 1.15, 3.7), Vector3(0, 0.95, 0))
		await Stage.wait(get_tree(), 1.2)
		await _snap("light_%s_full" % k)
		var h: Vector3 = t[0].get_head_node().global_position + Vector3(0, 0.07, 0)
		Stage.look(cam, h + Vector3(0.14, -0.02, 0.62), h)
		await Stage.wait(get_tree(), 0.6)
		await _snap("light_%s_face" % k)


## Prints real frame costs for a 30-person crowd, with vsync off, against an empty stage.
func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Stage.look(cam, Vector3(0, 1.7, 5.0), Vector3(0, 1.0, -2.0))
	await Stage.wait(get_tree(), 2.0)
	var base := await _measure("empty stage")
	var people := _spawn_crowd(30)
	await Stage.wait(get_tree(), 5.0)
	var idle := await _measure("30 idle, all on screen")
	print("[perf] crowd frame cost: %.2f ms" % (idle - base))
	for i in people.size():
		if i % 3 == 0:
			people[i].set_move_speed(1.3)
		if i % 3 == 1:
			people[i].set_talking(true)
	await Stage.wait(get_tree(), 2.0)
	var act := await _measure("30 walking/talking")
	print("[perf] crowd frame cost: %.2f ms" % (act - base))
	# CPU share of the models alone: run their updates in a tight loop.
	var t0 := Time.get_ticks_usec()
	var loops := 200
	for k in loops:
		for m in people:
			m._update(0.016, true)
	var us := float(Time.get_ticks_usec() - t0) / loops
	print("[perf] _update CPU, all full LOD: %.0f us per frame for 30 people (%.1f us each)" % [us, us / 30.0])
	var tris := 0
	var surfaces := 0
	var hi := 0
	var lo := 999999
	for m in people:
		var mi: MeshInstance3D = m.get_node("Rig/Skeleton/Body")
		var one := 0
		for s in mi.mesh.get_surface_count():
			one += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			surfaces += 1
		tris += one
		hi = maxi(hi, one)
		lo = mini(lo, one)
	print("[perf] tris avg %.0f (min %d, max %d), surfaces %.1f avg" % [float(tris) / people.size(), lo, hi, float(surfaces) / people.size()])
	var keys := {}
	for m in people:
		keys[m._mesh_key()] = true
	print("[perf] unique meshes: %d of %d" % [keys.size(), people.size()])


## Returns the average frame time in ms.
func _measure(label: String) -> float:
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 4000000:
		await get_tree().process_frame
		frames += 1
	var sec := float(Time.get_ticks_usec() - t0) / 1e6
	var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var pr := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("[perf] %s: %.1f fps (%.2f ms), %d draw calls, %d prims" % [label, frames / sec, sec / frames * 1000.0, dc, pr])
	return sec / frames * 1000.0
