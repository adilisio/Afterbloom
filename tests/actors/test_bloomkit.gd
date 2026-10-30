extends Node3D
const Stage := preload("res://tests/actors/actor_stage.gd")

func _ready() -> void:
	var cam := Stage.build(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 6:
		var c := BloomKit.make_crystal_cluster(rng, rng.randf_range(0.5, 1.2))
		c.position = Vector3(-2.5 + i * 1.0, 0, -1.5 + (i % 2) * 0.6)
		add_child(c)
	for i in 14:
		var f := BloomKit.make_bloom_flower(rng, rng.randf_range(0.9, 1.4))
		f.position = Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(0.0, 1.2))
		f.rotation.y = rng.randf() * TAU
		add_child(f)
	# multimesh field
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BloomKit.flower_mesh(3)
	mm.instance_count = 300
	for i in 300:
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-8, -3))))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	print("cluster tris approx: ", BloomKit.cluster_mesh(1, 1.0).get_faces().size() / 3, " flower tris: ", BloomKit.flower_mesh(3).get_faces().size() / 3)
	Stage.look(cam, Vector3(0, 1.4, 3.6), Vector3(0, 0.3, -0.5))
	await Stage.wait(get_tree(), 1.0)
	await Stage.snap(get_tree(), "bloomkit_overview")
	Stage.look(cam, Vector3(0.3, 0.45, 1.6), Vector3(0, 0.15, 0.6))
	await Stage.wait(get_tree(), 0.2)
	await Stage.snap(get_tree(), "bloomkit_flowers_close")
	Stage.look(cam, Vector3(0, 1.2, 3.0), Vector3(0, 0.6, 0))
	BloomKit.spawn_shards(self, Vector3(0, 1.0, 0), 14, Vector3(0, 2, 0), 1.0)
	ZapArc.spawn(self, Vector3(-1.5, 1.2, 0.5), Vector3(1.5, 0.6, 0.0), 1.0)
	await Stage.wait(get_tree(), 0.25)
	await Stage.snap(get_tree(), "bloomkit_burst")
	await Stage.wait(get_tree(), 2.0)
	await Stage.snap(get_tree(), "bloomkit_settled")
	get_tree().quit()
