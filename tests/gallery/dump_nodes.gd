extends SceneTree
## Lists mesh nodes (name, local AABB size, center) of each model; writes shots/gallery/nodes.txt

func _init() -> void:
	var out := PackedStringArray()
	var dirs := DirAccess.get_directories_at("res://assets/models")
	for id in dirs:
		for f in DirAccess.get_files_at("res://assets/models/" + id):
			if not f.ends_with(".gltf"):
				continue
			var root: Node3D = load("res://assets/models/%s/%s" % [id, f]).instantiate()
			var meshes := root.find_children("*", "MeshInstance3D", true, false)
			out.append("%s  [%s] meshes=%d" % [id, f, meshes.size()])
			if meshes.size() > 1:
				for m in meshes:
					var mi := m as MeshInstance3D
					var t := _xf(root, mi)
					var b := t * mi.get_aabb()
					out.append("    %s  size=(%.2f,%.2f,%.2f) center=(%.2f,%.2f,%.2f)" % [_path(root, mi), b.size.x, b.size.y, b.size.z, b.get_center().x, b.get_center().y, b.get_center().z])
			root.free()
	var fa := FileAccess.open("res://shots/gallery/nodes.txt", FileAccess.WRITE)
	fa.store_string("\n".join(out))
	fa.close()
	quit()

func _xf(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur != null:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

func _path(root: Node, n: Node) -> String:
	return str(root.get_path_to(n))
