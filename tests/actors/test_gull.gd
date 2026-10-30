extends Node3D
const Stage := preload("res://tests/actors/actor_stage.gd")

var cam: Camera3D
var flock: Array[GullModel] = []
var circling := true
var t := 0.0

func _ready() -> void:
	cam = Stage.build(self, Vector3(-50, -35, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 9:
		var g := GullModel.new()
		g.set_meta("r", rng.randf_range(3.0, 7.0))
		g.set_meta("h", rng.randf_range(4.0, 7.0))
		g.set_meta("a", rng.randf() * TAU)
		g.set_flap(rng.randf_range(0.4, 1.0))
		add_child(g)
		flock.append(g)
	await Stage.wait(get_tree(), 1.5)
	print("gull tris: ", _tris(flock[0]))
	Stage.look(cam, Vector3(0, 1.6, 9), Vector3(0, 5.0, 0))
	await Stage.snap(get_tree(), "gull_flock")
	await Stage.wait(get_tree(), 0.7)
	await Stage.snap(get_tree(), "gull_flock_b")
	# close-ups: stop circling, pin one gull in front of the camera
	circling = false
	var g0 := flock[0]
	for g in flock:
		g.visible = g == g0
	g0.position = Vector3(0, 1.5, 0)
	g0.rotation = Vector3(0, deg_to_rad(35), 0)
	g0.auto_cycle = false
	g0.set_flap(1.0)
	Stage.look(cam, Vector3(0.45, 1.75, -0.55), Vector3(0, 1.58, 0))
	await Stage.wait(get_tree(), 0.6)
	for k in 4:
		await Stage.snap(get_tree(), "gull_flap_%d" % k)
		await Stage.wait(get_tree(), 0.06)
	g0.set_glide(true)
	await Stage.wait(get_tree(), 1.5)
	await Stage.snap(get_tree(), "gull_glide")
	Stage.look(cam, Vector3(0.7, 1.4, 0.4), Vector3(0, 1.58, 0))
	await Stage.wait(get_tree(), 0.1)
	await Stage.snap(get_tree(), "gull_glide_below")
	g0.set_glide(false)
	g0.set_perched(true)
	g0.position = Vector3(0, 0, 0)
	Stage.look(cam, Vector3(0.45, 0.25, -0.5), Vector3(0, 0.08, 0))
	await Stage.wait(get_tree(), 1.2)
	await Stage.snap(get_tree(), "gull_perched")
	get_tree().quit()

func _process(delta: float) -> void:
	t += delta
	if not circling:
		return
	for g in flock:
		var r: float = g.get_meta("r")
		var a: float = g.get_meta("a") + t * 4.0 / r
		var h: float = g.get_meta("h")
		g.position = Vector3(cos(a) * r, h + sin(t * 0.7 + r) * 0.3, sin(a) * r)
		# tangent direction (counter-clockwise), model faces -Z
		var fwd := Vector3(-sin(a), 0, cos(a))
		g.basis = Basis.looking_at(fwd, Vector3.UP)
		g.set_bank(-0.5)

func _tris(n: Node) -> int:
	var tc := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tc += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	for c in n.get_children():
		tc += _tris(c)
	return tc
