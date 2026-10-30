extends Node3D
## Prints triangle counts per model (run headless).

func _count(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as MeshInstance3D).is_visible_in_tree():
		var m := (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			c += (idx.size() if idx.size() > 0 else verts.size()) / 3
	elif n is MultiMeshInstance3D:
		var mm := (n as MultiMeshInstance3D).multimesh
		var m := mm.mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			c += (idx.size() if idx.size() > 0 else verts.size()) / 3 * mm.instance_count
	for ch in n.get_children():
		c += _count(ch)
	return c


func _collect(n: Node, rows: Array) -> void:
	if n is MeshInstance3D or n is MultiMeshInstance3D:
		var own := _count_self(n)
		rows.append([own, str(n.get_path()).get_slice("/", 3) + ".../" + str(n.name) + " " + (str((n as MeshInstance3D).mesh.get_class()) if n is MeshInstance3D else "MM")])
	for ch in n.get_children():
		_collect(ch, rows)


func _count_self(n: Node) -> int:
	var c := 0
	var m: Mesh = (n as MeshInstance3D).mesh if n is MeshInstance3D else (n as MultiMeshInstance3D).multimesh.mesh
	var mul := 1 if n is MeshInstance3D else (n as MultiMeshInstance3D).multimesh.instance_count
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		c += (idx.size() if idx.size() > 0 else verts.size()) / 3 * mul
	return c


func _ready() -> void:
	var models: Array[Node3D] = [TuppenceModel.new(), RegistrarModel.new(), MiteModel.new(), HuskModel.new(), ThornbackModel.new(), GullModel.new()]
	for m in models:
		add_child(m)
	await get_tree().process_frame
	for m in models:
		print("%s tris: %d" % [m.get_script().get_global_name(), _count(m)])
	if OS.get_cmdline_user_args().has("--detail"):
		for m in [models[0], models[1]]:
			var rows: Array = []
			_collect(m, rows)
			rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			for r in rows.slice(0, 25):
				print("   ", r[0], "  ", r[1])
	get_tree().quit()
