extends Node
## Loads every script under res://src so parse/compile errors show up in one run.

func _ready() -> void:
	var n := 0
	for path in _walk("res://src"):
		var s: Resource = load(path)
		n += 1
		if s is GDScript and not (s as GDScript).can_instantiate():
			print("[compile] CANNOT INSTANTIATE ", path)
	print("[compile] checked %d scripts" % n)
	get_tree().quit()

func _walk(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_walk(dir + "/" + d))
	return out
