extends Node3D
const Stage := preload("res://tests/actors/actor_stage.gd")

var cam: Camera3D
var reg: RegistrarModel


func _ready() -> void:
	cam = Stage.build(self)
	reg = RegistrarModel.new()
	add_child(reg)
	cam.fov = 45
	await Stage.wait(get_tree(), 0.8)
	reg.look_at_point(Vector3(-1.2, 1.6, -2.5))
	await _shot("front34", Vector3(-1.2, 1.6, -2.5), Vector3(0, 0.9, 0), 0.6)
	await _shot("side", Vector3(-2.7, 1.3, 0.2), Vector3(0, 0.85, 0), 0.2)
	await _shot("back34", Vector3(1.6, 1.5, 2.2), Vector3(0, 0.9, 0), 0.2)
	reg.look_at_point(Vector3(-0.3, 1.5, -1.1))
	reg.set_talking(true)
	cam.fov = 40
	await _shot("closeup", Vector3(-0.3, 1.5, -1.1), Vector3(0, 1.3, 0), 0.6)
	reg.set_talking(false)
	cam.fov = 45
	Stage.look(cam, Vector3(-1.4, 1.5, -2.4), Vector3(0, 0.95, 0))
	for g: String in ["bow", "stamp", "nod"]:
		var d := reg.play_gesture(g)
		var mid: float = {"bow": 1.0, "stamp": 1.15, "nod": 0.35}[g]
		await Stage.wait(get_tree(), mid)
		await Stage.snap(get_tree(), "registrar_g_" + g)
		if g == "stamp":
			await Stage.wait(get_tree(), 0.6)
			await Stage.snap(get_tree(), "registrar_g_stamp_ticket")
			mid += 0.6
		await Stage.wait(get_tree(), d - mid + 0.3)
	get_tree().quit()


func _shot(n: String, from: Vector3, at: Vector3, settle := 0.05) -> void:
	Stage.look(cam, from, at)
	await Stage.wait(get_tree(), settle)
	await Stage.snap(get_tree(), "registrar_" + n)
