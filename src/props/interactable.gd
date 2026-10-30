class_name Interactable
extends Area3D
## Something the player can use with E. Emits `used`. Put a CollisionShape3D child on it (or call make_box).

signal used

@export var verb := "Use"
@export var title := ""
var enabled := true
var once := false


func _init() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true


static func make(parent: Node, pos: Vector3, size: Vector3, p_verb: String, p_title: String) -> Interactable:
	var it := Interactable.new()
	it.verb = p_verb
	it.title = p_title
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	it.add_child(cs)
	parent.add_child(it)
	it.position = pos
	return it


func prompt() -> String:
	return "%s %s" % [verb, title] if title != "" else verb


func use() -> void:
	if not enabled:
		return
	if once:
		enabled = false
	used.emit()
