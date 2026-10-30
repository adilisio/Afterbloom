extends Node3D
const Stage := preload("res://tests/actors/actor_stage.gd")

var cam: Camera3D
var tb: ThornbackModel


func _spawn() -> ThornbackModel:
	var m := ThornbackModel.new()
	add_child(m)
	return m


func _tris(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		c += (n as MeshInstance3D).mesh.get_faces().size() / 3
	elif n is MultiMeshInstance3D:
		var mm := (n as MultiMeshInstance3D).multimesh
		c += mm.mesh.get_faces().size() / 3 * mm.instance_count
	for ch in n.get_children():
		c += _tris(ch)
	return c


func _shot(name: String, from: Vector3, at: Vector3, wait := 0.0) -> void:
	if wait > 0.0:
		await Stage.wait(get_tree(), wait)
	Stage.look(cam, from, at)
	await Stage.snap(get_tree(), "thornback_" + name)
	if is_instance_valid(tb):
		print(name, " dead_t=", tb._dead_t, " fps=", Engine.get_frames_per_second(), " ticks=", Time.get_ticks_msec())


func _ready() -> void:
	cam = Stage.build(self)
	var only := Stage.arg("only", "")
	tb = _spawn()
	print("thornback tris: ", _tris(tb))
	await Stage.wait(get_tree(), 1.2)
	var c := Vector3(0, 1.3, 0)
	if only == "" or only == "idle":
		await _shot("idle_34front", Vector3(-5.0, 1.6, -5.5), c)
		await _shot("idle_34front_r", Vector3(5.5, 1.6, -4.5), c)
		await _shot("side", Vector3(8.0, 1.6, 0.0), c)
		await _shot("rear34", Vector3(5.0, 2.2, 6.0), c)
		await _shot("head_close", Vector3(-1.6, 1.8, -3.6), tb.get_part_node("head").global_position)
		await _shot("ridge_close", Vector3(-2.6, 3.4, -0.5), Vector3(0, 2.4, 0))
	if only == "" or only == "move":
		tb.set_locomotion(0.35)
		await Stage.wait(get_tree(), 2.0)
		await _shot("walk_0", Vector3(8.0, 1.6, 0.0), c)
		await _shot("walk_1", Vector3(8.0, 1.6, 0.0), c, 0.3)
		await _shot("walk_2", Vector3(8.0, 1.6, 0.0), c, 0.3)
		tb.set_locomotion(1.0)
		await Stage.wait(get_tree(), 2.0)
		await _shot("run_0", Vector3(8.0, 1.6, 0.0), c)
		await _shot("run_1", Vector3(8.0, 1.6, 0.0), c, 0.2)
		tb.set_locomotion(0.0)
		await Stage.wait(get_tree(), 2.0)
	if only == "" or only == "acts":
		tb.play_roar()
		await _shot("roar", Vector3(-4.0, 1.6, -6.0), c, 1.0)
		await Stage.wait(get_tree(), 1.8)
		tb.play_charge_windup()
		await _shot("windup", Vector3(-4.0, 1.6, -6.0), c, 0.9)
		await Stage.wait(get_tree(), 1.0)
		tb.play_attack()
		await _shot("attack_rear", Vector3(-6.5, 1.6, -3.0), c, 0.55)
		await _shot("attack_slam", Vector3(-6.5, 1.6, -3.0), c, 0.22)
		await Stage.wait(get_tree(), 1.2)
		tb.play_hit("thorns", Vector3(1, 0, 0))
		await _shot("hit_thorns", Vector3(-5.0, 1.6, -5.5), c, 0.12)
		await Stage.wait(get_tree(), 1.0)
		tb.play_emerge()
		await _shot("emerge_mid", Vector3(-5.0, 1.6, -5.5), c, 1.2)
		await Stage.wait(get_tree(), 2.5)
	if only == "" or only == "die":
		var part := Stage.arg("part", "thorns")
		var fin := [false]
		tb.finished.connect(func() -> void: fin[0] = true)
		tb.die(part, Vector3(3, 1, 0))
		var cam_p := Vector3(-6.0, 1.6, -5.0)
		for pair in [[0.8, "stagger"], [2.4, "collapse"], [3.75, "erupt"], [5.0, "after"], [9.0, "late"]]:
			while is_instance_valid(tb) and tb._dead_t < float(pair[0]):
				await get_tree().process_frame
			await _shot("die_%s_%s" % [pair[1], part], cam_p, c)
		var guard := 0
		while not fin[0] and guard < 2000:
			guard += 1
			await get_tree().process_frame
		print("finished emitted: ", fin[0], " model freed: ", not is_instance_valid(tb))
	get_tree().quit()

