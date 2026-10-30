extends Node3D
## Husk test: `-- --scenario=look|anim|death`
const Stage := preload("res://tests/actors/actor_stage.gd")

var cam: Camera3D


func _ready() -> void:
	cam = Stage.build(self)
	var sc := Stage.arg("scenario", "look")
	match sc:
		"look": await _look()
		"anim": await _anim()
		"death": await _death()
	get_tree().quit()


func _husk(v: int, pos: Vector3, yaw_deg := 0.0) -> HuskModel:
	var h := HuskModel.new()
	h.variant = v
	h.position = pos
	h.rotation_degrees.y = yaw_deg
	add_child(h)
	return h


func _tris(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		c += (n as MeshInstance3D).mesh.get_faces().size() / 3
	for ch in n.get_children():
		c += _tris(ch)
	return c


func _look() -> void:
	var a := _husk(0, Vector3(-1.1, 0, 0), 0)
	var b := _husk(1, Vector3(0, 0, 0), 0)
	var c := _husk(2, Vector3(1.1, 0, 0), 0)
	print("tris v0=", _tris(a), " v1=", _tris(b), " v2=", _tris(c))
	Stage.look(cam, Vector3(0, 1.6, -3.6), Vector3(0, 0.95, 0))
	await Stage.wait(get_tree(), 1.5)
	await Stage.snap(get_tree(), "husk_variants")
	Stage.look(cam, Vector3(-1.1 + 1.6, 1.6, -2.5), Vector3(-1.1, 0.9, 0))
	await Stage.wait(get_tree(), 0.3)
	await Stage.snap(get_tree(), "husk_v0_34")
	Stage.look(cam, Vector3(0.6, 1.5, -1.0), Vector3(0, 1.45, 0))
	await Stage.wait(get_tree(), 0.3)
	await Stage.snap(get_tree(), "husk_v1_face")
	Stage.look(cam, Vector3(-1.1 - 0.45, 1.6, -0.75), Vector3(-1.1, 1.45, 0))
	await Stage.wait(get_tree(), 0.3)
	await Stage.snap(get_tree(), "husk_v0_face")
	Stage.look(cam, Vector3(0.3, 1.7, 3.2), Vector3(0, 0.95, 0))
	await Stage.wait(get_tree(), 0.3)
	await Stage.snap(get_tree(), "husk_back")
	Stage.look(cam, Vector3(3.4, 1.4, 0.0), Vector3(0, 0.9, 0))
	await Stage.wait(get_tree(), 0.3)
	await Stage.snap(get_tree(), "husk_side")


func _anim() -> void:
	var h := _husk(0, Vector3(0, 0, 0), 0)
	var r := _husk(2, Vector3(0, 0, 2.2), 0)
	var a := _husk(1, Vector3(0, 0, -2.2), 0)
	h.set_locomotion(0.35)
	r.set_locomotion(1.0)
	cam.global_position = Vector3(-4.2, 1.6, 0.0)
	cam.look_at(Vector3(0, 0.9, 0))
	await Stage.wait(get_tree(), 2.0)
	for i in 3:
		await Stage.snap(get_tree(), "husk_walk_%d" % i)
		await Stage.wait(get_tree(), 0.25)
	cam.global_position = Vector3(-3.2, 1.5, 2.2)
	cam.look_at(Vector3(0, 0.9, 2.2))
	for i in 2:
		await Stage.snap(get_tree(), "husk_run_%d" % i)
		await Stage.wait(get_tree(), 0.18)
	cam.global_position = Vector3(-3.0, 1.5, -2.2)
	cam.look_at(Vector3(0, 1.0, -2.2))
	a.play_attack()
	await Stage.wait(get_tree(), 0.3)
	await Stage.snap(get_tree(), "husk_attack_wind")
	while a._att_t >= 0.0 and a._att_t < 0.56:
		await get_tree().process_frame
	await Stage.snap(get_tree(), "husk_attack_lunge")
	await Stage.wait(get_tree(), 0.8)
	a.play_hit("torso", Vector3(1, 0, 0))
	await Stage.wait(get_tree(), 0.1)
	await Stage.snap(get_tree(), "husk_hit_torso")
	await Stage.wait(get_tree(), 0.9)
	a.play_hit("head", Vector3(1, 0, 0))
	await Stage.wait(get_tree(), 0.12)
	await Stage.snap(get_tree(), "husk_hit_head")
	await Stage.wait(get_tree(), 0.9)
	a.play_emerge()
	await Stage.wait(get_tree(), 0.6)
	await Stage.snap(get_tree(), "husk_emerge_a")
	await Stage.wait(get_tree(), 0.7)
	await Stage.snap(get_tree(), "husk_emerge_b")


func _death() -> void:
	var parts := ["head", "arm_r", "leg_l", "torso"]
	var hs: Array[HuskModel] = []
	for i in 4:
		hs.append(_husk(i % 3, Vector3(-3.0 + i * 2.0, 0, 0), 0))
	cam.global_position = Vector3(0, 1.8, -5.5)
	cam.look_at(Vector3(0, 0.8, 0))
	await Stage.wait(get_tree(), 1.0)
	for i in 4:
		hs[i].finished.connect(func() -> void: print("finished ", parts[i]))
		hs[i].die(parts[i], Vector3(0, 0, 4.0))
	var times := [0.12, 0.3, 0.6, 1.2, 2.5]
	var last := 0.0
	for k in times.size():
		await Stage.wait(get_tree(), times[k] - last)
		last = times[k]
		await Stage.snap(get_tree(), "husk_death_%d" % k)
	cam.global_position = Vector3(1.0, 1.4, -1.8)
	cam.look_at(Vector3(1.0, 0.3, 0))
	await Stage.snap(get_tree(), "husk_death_close")
	await Stage.wait(get_tree(), 5.0)
	await Stage.snap(get_tree(), "husk_death_end")
	for k in 120:
		if not is_instance_valid(hs[3]):
			break
		await Stage.wait(get_tree(), 0.1)
	print("fps=", Engine.get_frames_per_second())
	for x in hs:
		print("valid=", is_instance_valid(x), " t=", x._death_t if is_instance_valid(x) else -1.0)
	print("children left: ", get_child_count())
