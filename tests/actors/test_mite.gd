extends Node3D
const Stage := preload("res://tests/actors/actor_stage.gd")

var cam: Camera3D

func _mite(pos: Vector3, yaw_deg := 0.0) -> MiteModel:
	var m := MiteModel.new()
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	add_child(m)
	return m

func _ready() -> void:
	cam = Stage.build(self)
	var only := Stage.arg("only", "")
	var a := _mite(Vector3(0, 0, 0), 30)
	await Stage.wait(get_tree(), 1.0)
	print("mite tris: ", _tris(a))
	if only == "" or only == "look":
		Stage.look(cam, Vector3(1.4, 1.6, -1.6), Vector3(0, 0.25, 0))
		await Stage.wait(get_tree(), 0.1)
		await Stage.snap(get_tree(), "mite_34")
		Stage.look(cam, Vector3(-0.5, 0.35, -1.1), Vector3(0, 0.25, 0))
		await Stage.wait(get_tree(), 0.1)
		await Stage.snap(get_tree(), "mite_low")
		Stage.look(cam, Vector3(-1.8, 0.7, 0.3), Vector3(0, 0.25, 0))
		await Stage.wait(get_tree(), 0.1)
		await Stage.snap(get_tree(), "mite_side")
	if only == "" or only == "walk":
		a.rotation_degrees.y = 0
		Stage.look(cam, Vector3(-1.9, 0.5, 0.0), Vector3(0, 0.22, 0))
		a.set_locomotion(0.5)
		await Stage.wait(get_tree(), 1.0)
		for k in 3:
			await Stage.snap(get_tree(), "mite_walk_%d" % k)
			await Stage.wait(get_tree(), 0.09)
		a.set_locomotion(1.0)
		await Stage.wait(get_tree(), 1.0)
		await Stage.snap(get_tree(), "mite_run_0")
		await Stage.wait(get_tree(), 0.06)
		await Stage.snap(get_tree(), "mite_run_1")
		a.set_locomotion(0.0)
		await Stage.wait(get_tree(), 0.8)
	if only == "" or only == "attack":
		a.rotation_degrees.y = 0
		Stage.look(cam, Vector3(-1.8, 0.6, -0.6), Vector3(0, 0.3, -0.2))
		var d := a.play_attack()
		await Stage.wait(get_tree(), d * 0.25)
		await Stage.snap(get_tree(), "mite_attack_rear")
		await Stage.wait(get_tree(), d * 0.2)
		await Stage.snap(get_tree(), "mite_attack_hit")
		await Stage.wait(get_tree(), 1.0)
		a.play_hit("body", Vector3(1, 0, 0))
		await Stage.wait(get_tree(), 0.06)
		await Stage.snap(get_tree(), "mite_hit")
		await Stage.wait(get_tree(), 0.6)
		var e := a.play_emerge()
		await Stage.wait(get_tree(), e * 0.35)
		await Stage.snap(get_tree(), "mite_emerge")
		await Stage.wait(get_tree(), e * 0.7)
	if only == "" or only == "death":
		a.queue_free()
		var b := _mite(Vector3(-1.2, 0, 0), 10)
		var c := _mite(Vector3(0, 0, 0), -20)
		var dm := _mite(Vector3(1.2, 0, 0), 0)
		b.set_locomotion(0.6); c.set_locomotion(0.3)
		Stage.look(cam, Vector3(0, 1.6, -2.6), Vector3(0, 0.2, 0))
		await Stage.wait(get_tree(), 0.8)
		await Stage.snap(get_tree(), "mite_group")
		var fin := [0]
		dm.finished.connect(func() -> void: fin[0] += 1)
		b.die("head", Vector3(0, 0, 4))
		c.die("body", Vector3(0, 0, 4))
		dm.die("legs", Vector3(-3, 0, 2))
		await Stage.wait(get_tree(), 0.18)
		await Stage.snap(get_tree(), "mite_death_burst")
		await Stage.wait(get_tree(), 0.4)
		await Stage.snap(get_tree(), "mite_death_mid")
		await Stage.wait(get_tree(), 2.5)
		await Stage.snap(get_tree(), "mite_death_settled")
		Stage.look(cam, Vector3(0.4, 0.9, -1.4), Vector3(0, 0.1, 0))
		await Stage.wait(get_tree(), 0.1)
		await Stage.snap(get_tree(), "mite_death_close")
		await Stage.wait(get_tree(), 11.0)
		print("finished signals: ", fin[0], " remaining children: ", get_child_count(), " valid: ", is_instance_valid(dm), " t: ", dm._dead_t if is_instance_valid(dm) else -9.0)
	get_tree().quit()

func _tris(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			t += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	for c in n.get_children():
		t += _tris(c)
	return t
