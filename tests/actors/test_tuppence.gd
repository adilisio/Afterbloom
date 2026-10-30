extends Node3D
## Tuppence test: `-- --scenario=beauty|gestures|motion|aged`
const Stage := preload("res://tests/actors/actor_stage.gd")

var cam: Camera3D
var tup: TuppenceModel


func _ready() -> void:
	cam = Stage.build(self)
	tup = TuppenceModel.new()
	add_child(tup)
	var sc := Stage.arg("scenario", "beauty")
	print("scenario ", sc)
	await Stage.wait(get_tree(), 0.8)
	match sc:
		"beauty":
			await _beauty()
		"gestures":
			await _gestures()
		"motion":
			await _motion()
		"aged":
			await _aged()
		"top":
			for g: String in ["point", "tea", "zap"]:
				var d := tup.play_gesture(g)
				Stage.look(cam, Vector3(0.0, 3.2, -0.01), Vector3(0, 0.8, 0))
				await Stage.wait(get_tree(), 1.0 if g != "zap" else 0.62)
				await Stage.snap(get_tree(), "tuppence_top_" + g)
				await Stage.wait(get_tree(), d)
	get_tree().quit()


func _shot(n: String, from: Vector3, at: Vector3, settle := 0.05) -> void:
	Stage.look(cam, from, at)
	await Stage.wait(get_tree(), settle)
	await Stage.snap(get_tree(), "tuppence_" + n)


func _beauty() -> void:
	cam.fov = 45
	tup.look_at_point(Vector3(-1.2, 1.6, -2.4))
	await _shot("front34", Vector3(-1.2, 1.6, -2.4), Vector3(0, 0.85, 0), 0.6)
	await _shot("side", Vector3(-2.6, 1.3, 0.0), Vector3(0, 0.8, 0), 0.3)
	await _shot("back34", Vector3(1.6, 1.5, 2.0), Vector3(0, 0.85, 0), 0.3)
	tup.look_at_point(Vector3(-0.35, 1.45, -1.0))
	tup.set_talking(true)
	cam.fov = 40
	await _shot("closeup", Vector3(-0.35, 1.45, -1.0), Vector3(0, 1.3, 0), 0.8)
	await _shot("closeup_b", Vector3(-0.35, 1.45, -1.0), Vector3(0, 1.3, 0), 0.23)
	tup.set_talking(false)
	cam.fov = 35
	await _shot("chest", Vector3(0.0, 1.0, -0.8), Vector3(0, 0.88, 0), 0.4)


func _gestures() -> void:
	cam.fov = 45
	var names := ["wave", "bow", "tea", "polish", "zap", "fret", "celebrate", "point", "curtains", "nod"]
	var mids := {"wave": 1.2, "bow": 1.0, "tea": 2.0, "polish": 1.6, "zap": 0.62, "fret": 1.3, "celebrate": 1.1, "point": 1.0, "curtains": 1.6, "nod": 0.35}
	Stage.look(cam, Vector3(-1.3, 1.45, -2.3), Vector3(0, 0.95, 0))
	tup.look_at_point(cam.global_position)
	for n: String in names:
		var d := tup.play_gesture(n)
		await Stage.wait(get_tree(), float(mids[n]))
		await Stage.snap(get_tree(), "tuppence_g_" + n)
		await Stage.wait(get_tree(), d - float(mids[n]) + 0.3)


func _motion() -> void:
	cam.fov = 45
	Stage.look(cam, Vector3(-2.4, 1.3, -1.2), Vector3(0, 0.85, 0))
	tup.set_move_speed(1.0)
	await Stage.wait(get_tree(), 1.2)
	for i in 3:
		await Stage.snap(get_tree(), "tuppence_move_%d" % i)
		await Stage.wait(get_tree(), 0.25)
	tup.set_move_speed(0.0)
	tup.set_talking(true)
	await Stage.wait(get_tree(), 1.0)
	for i in 3:
		await _shot("talk_%d" % i, Vector3(-0.3, 1.45, -1.0), Vector3(0, 1.3, 0), 0.17)
	tup.set_talking(false)
	tup.set_expression("worried")
	tup.set_eye_color(Color(1.0, 0.85, 0.6))
	await _shot("worried", Vector3(-0.3, 1.45, -1.0), Vector3(0, 1.3, 0), 0.6)
	tup.set_expression("happy")
	tup.set_eye_color(TuppenceModel.EYE_AMBER)
	await _shot("happy", Vector3(-0.3, 1.45, -1.0), Vector3(0, 1.3, 0), 0.6)


func _aged() -> void:
	var t2 := TuppenceModel.new()
	t2.aged = true
	t2.position = Vector3(0.9, 0, 0)
	add_child(t2)
	tup.position = Vector3(-0.9, 0, 0)
	cam.fov = 45
	await _shot("aged_pair", Vector3(0, 1.5, -3.2), Vector3(0, 0.85, 0), 0.6)
	await _shot("aged_close", Vector3(0.75, 1.1, -0.9), Vector3(0.9, 0.95, 0), 0.3)
