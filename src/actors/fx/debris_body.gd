class_name DebrisBody
extends RigidBody3D
## A detached chunk of an actor (or a crystal shard). Tumbles, settles, then
## sinks/shrinks away after `life` seconds and frees itself.

var life := 9.0
var shrink_time := 1.4
var _t := 0.0
var _visuals: Array[Node3D] = []
var _scales: Array[Vector3] = []
var _dying := false


func _init() -> void:
	can_sleep = true
	continuous_cd = false
	linear_damp = 0.05
	angular_damp = 0.4
	physics_material_override = _phys_mat()


static var _pm: PhysicsMaterial
static func _phys_mat() -> PhysicsMaterial:
	if _pm == null:
		_pm = PhysicsMaterial.new()
		_pm.friction = 0.8
		_pm.bounce = 0.15
	return _pm


func register_visual(n: Node3D) -> void:
	_visuals.append(n)
	_scales.append(n.scale)


func _process(delta: float) -> void:
	_t += delta
	if global_position.y < -200.0:
		queue_free()
		return
	if _t < life:
		return
	if not _dying:
		_dying = true
		freeze = true
		for c in get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).set_deferred("disabled", true)
	var k := 1.0 - (_t - life) / shrink_time
	if k <= 0.0:
		queue_free()
		return
	var e := k * k * (3.0 - 2.0 * k)
	for i in _visuals.size():
		if is_instance_valid(_visuals[i]):
			_visuals[i].scale = _scales[i] * maxf(e, 0.001)
	global_position.y -= delta * 0.05
