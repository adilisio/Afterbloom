class_name Door
extends Node3D
## Hinged door. Origin = hinge at floor. Slab extends along +X (width), opens by rotating around Y.

signal opened

var width := 0.95
var height := 2.12
var open_angle := -100.0
var is_open := false
var locked := false
var locked_text := "Locked"
var slab: AnimatableBody3D
var use: Interactable
var _tw: Tween


static func make(parent: Node, hinge: Vector3, rot_y: float, w: float, h: float, mat: Material, knob_mat: Material) -> Door:
	var d := Door.new()
	d.width = w
	d.height = h
	parent.add_child(d)
	d.position = hinge
	d.rotation.y = rot_y
	d._build(mat, knob_mat)
	return d


func _build(mat: Material, knob_mat: Material) -> void:
	slab = AnimatableBody3D.new()
	slab.sync_to_physics = false
	slab.set_meta("surface", "wood")
	add_child(slab)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width - 0.02, height, 0.045)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(width * 0.5, height * 0.5, 0)
	slab.add_child(mi)
	# raised panels for detail
	for py in [0.55, 1.45]:
		var pm := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(width * 0.62, 0.62, 0.06)
		pm.mesh = pb
		pm.material_override = mat
		pm.position = Vector3(width * 0.5, py, 0)
		slab.add_child(pm)
	for side in [-1.0, 1.0]:
		var k := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.032
		sm.height = 0.064
		k.mesh = sm
		k.material_override = knob_mat
		k.position = Vector3(width - 0.09, 1.0, side * 0.055)
		slab.add_child(k)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	cs.position = mi.position
	slab.add_child(cs)
	use = Interactable.make(slab, Vector3(width * 0.5, 1.0, 0), Vector3(width, 1.6, 0.25), "Open", "Door")
	use.used.connect(toggle)


func toggle() -> void:
	if locked:
		Game.toast.emit(locked_text)
		Audio.sfx_at("door_knock", global_position + Vector3(0, 1, 0), -10.0)
		return
	set_open(not is_open)


func set_open(o: bool, instant := false) -> void:
	is_open = o
	use.verb = "Close" if o else "Open"
	if _tw:
		_tw.kill()
	var target := deg_to_rad(open_angle if o else 0.0)
	if instant:
		slab.rotation.y = target
		return
	Audio.sfx_at("door_open" if o else "door_close", global_position + Vector3(width * 0.5, 1.0, 0), -4.0, 4.0)
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(slab, "rotation:y", target, 0.7 if o else 0.5)
	if o:
		opened.emit()
