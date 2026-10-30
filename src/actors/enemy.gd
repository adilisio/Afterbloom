class_name Enemy
extends CharacterBody3D
## Enemy controller for Bloom creatures (mite / husk / thornback): perception, chase, attacks, damage, loot.

signal died(enemy: Enemy)
signal aggroed

const STATS := {
	"mite": {"hp": 45.0, "speed": 6.2, "dmg": 8.0, "range": 1.7, "aggro": 20.0, "xp": 15, "cool": 1.3, "radius": 0.45, "height": 0.6},
	"husk": {"hp": 95.0, "speed": 2.4, "run": 4.6, "dmg": 15.0, "range": 1.9, "aggro": 24.0, "xp": 25, "cool": 1.6, "radius": 0.35, "height": 1.8},
	"thornback": {"hp": 650.0, "speed": 3.2, "run": 9.0, "dmg": 32.0, "range": 3.6, "aggro": 45.0, "xp": 220, "cool": 2.4, "radius": 1.2, "height": 2.6},
}
const PART_MULT := {"head": 2.0, "thorns": 2.6, "legs": 0.75, "leg_l": 0.75, "leg_r": 0.75, "arm_l": 0.8, "arm_r": 0.8, "torso": 1.0, "body": 1.0}

var kind := "husk"
var model: Node3D
var player: Player
var hp := 100.0
var alive := true
var aggro := false
var dormant := false  # waits for wake() (ambushes)
var stats: Dictionary
var _attack_cd := 0.0
var _attacking := false
var _stagger := 0.0
var _sound_cd := 2.0
var _charge := 0.0
var _charge_cd := 6.0
var _strafe := 0.0


static func spawn(parent: Node, p_kind: String, pos: Vector3, p_player: Player, p_dormant := false, variant := 0) -> Enemy:
	var e := Enemy.new()
	e.kind = p_kind
	e.player = p_player
	e.dormant = p_dormant
	parent.add_child(e)
	e.global_position = pos
	e.rotation.y = randf() * TAU
	e._build(variant)
	return e


func _build(variant: int) -> void:
	stats = STATS[kind]
	hp = stats.hp
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.5
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = stats.radius
	cap.height = maxf(stats.height, stats.radius * 2.0 + 0.01)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	match kind:
		"mite":
			model = MiteModel.new()
		"thornback":
			model = ThornbackModel.new()
		_:
			model = HuskModel.new()
			if model.has_method("set_variant"):
				model.call("set_variant", variant)
	add_child(model)
	if dormant:
		model.visible = false
		cs.disabled = true


func wake(emerge := true) -> void:
	if not dormant:
		return
	dormant = false
	model.visible = true
	(get_child(0) as CollisionShape3D).disabled = false
	if emerge:
		var d: float = model.call("play_emerge")
		_stagger = d
		Audio.sfx_at("spore_burst", global_position, -4.0, 6.0)
	_set_aggro()


func _set_aggro() -> void:
	if aggro:
		return
	aggro = true
	aggroed.emit()
	_growl()


func on_gunshot(from: Vector3) -> void:
	if alive and not dormant and from.distance_to(global_position) < 40.0:
		_set_aggro()


func _growl() -> void:
	var s := {"mite": "mite_chitter", "husk": "husk_groan", "thornback": "thornback_roar"}[kind] as String
	Audio.sfx_at(s, global_position + Vector3(0, 1, 0), 0.0 if kind != "mite" else -4.0, 8.0 if kind == "thornback" else 5.0)


func _physics_process(delta: float) -> void:
	if not alive or dormant or player == null:
		return
	if not is_on_floor():
		velocity.y -= 14.0 * delta
	else:
		velocity.y = -0.5
	var to := player.global_position - global_position
	to.y = 0
	var dist := to.length()
	if not aggro and dist < stats.aggro and (dist < stats.aggro * 0.5 or _can_see()):
		_set_aggro()
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_stagger = maxf(_stagger - delta, 0.0)
	_sound_cd -= delta
	if _sound_cd <= 0.0:
		_sound_cd = randf_range(3.0, 7.0)
		if aggro or randf() < 0.3:
			_growl()
	var move := Vector3.ZERO
	var spd := 0.0
	if aggro and _stagger <= 0.0 and not _attacking and not player.dead:
		var dir := to.normalized()
		spd = stats.speed
		if stats.has("run") and dist > 3.0:
			spd = stats.run
		if kind == "mite":
			_strafe += delta * 2.5
			dir = (dir + dir.cross(Vector3.UP) * sin(_strafe) * 0.45).normalized()
		if kind == "thornback":
			_charge_cd -= delta
			if _charge > 0.0:
				_charge -= delta
				spd = stats.run * 1.6
			elif _charge_cd <= 0.0 and dist > 8.0 and dist < 25.0:
				_charge_cd = randf_range(7.0, 10.0)
				_windup_charge()
				return
		move = dir * spd
		if dist <= stats.range and _attack_cd <= 0.0:
			_attack()
		elif dist <= stats.range * 0.8:
			move = Vector3.ZERO
		# face the player
		var yaw := atan2(-to.x, -to.z)
		rotation.y = lerp_angle(rotation.y, yaw, minf(delta * (10.0 if kind == "mite" else 5.0), 1.0))
	elif not aggro:
		# idle sway in place
		pass
	velocity.x = lerpf(velocity.x, move.x, minf(delta * 6.0, 1.0))
	velocity.z = lerpf(velocity.z, move.z, minf(delta * 6.0, 1.0))
	move_and_slide()
	var hv := Vector2(velocity.x, velocity.z).length()
	model.call("set_locomotion", clampf(hv / maxf(float(stats.get("run", stats.speed)), 0.1), 0.0, 1.0))


func _can_see() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * stats.height * 0.8, player.cam.global_position, 1)
	return space.intersect_ray(q).is_empty()


func _windup_charge() -> void:
	_attacking = true
	var d: float = model.call("play_charge_windup")
	Audio.sfx_at("thornback_charge", global_position, 2.0, 10.0)
	await get_tree().create_timer(d).timeout
	_attacking = false
	_charge = 1.6


func _attack() -> void:
	_attacking = true
	_attack_cd = stats.cool * randf_range(0.85, 1.2)
	var dur: float = model.call("play_attack")
	var atk := {"mite": "mite_attack", "husk": "husk_attack", "thornback": "thornback_stomp"}[kind] as String
	Audio.sfx_at(atk, global_position + Vector3(0, 1, 0), 0.0, 6.0)
	if kind == "mite":
		var lunge := (player.global_position - global_position)
		lunge.y = 0
		velocity += lunge.normalized() * 6.0 + Vector3.UP * 3.0
	await get_tree().create_timer(dur * 0.45).timeout
	if not alive or not is_inside_tree():
		return
	var to := player.global_position - global_position
	to.y = 0
	if to.length() < stats.range + 0.6 and not player.dead:
		player.take_damage(stats.dmg * randf_range(0.85, 1.15), global_position)
		if kind == "thornback":
			player.velocity += to.normalized() * 9.0 + Vector3.UP * 3.0
			player.shake(1.0)
	await get_tree().create_timer(dur * 0.55).timeout
	_attacking = false


## Called by weapons / Tuppence. Returns true if this hit killed.
func take_hit(part: String, dmg: float, dir: Vector3, at: Vector3) -> bool:
	if not alive:
		return false
	if dormant:
		wake(false)
	_set_aggro()
	var mult: float = PART_MULT.get(part, 1.0)
	hp -= dmg * mult
	Fx.glow_motes(get_tree().current_scene, at, Color(0.75, 0.5, 1.0), 10, 0.15)
	if hp <= 0.0:
		_die(part, dir * (6.0 if kind != "thornback" else 3.0) + Vector3.UP * 2.0)
		return true
	model.call("play_hit", part, dir)
	if dmg * mult > stats.hp * 0.25 or part == "head":
		_stagger = 0.45 if kind != "thornback" else 0.6
	if kind == "thornback" and part == "thorns":
		Audio.sfx_at("thornback_roar", global_position, 0.0, 10.0)
	return false


func _die(part: String, impulse: Vector3) -> void:
	alive = false
	aggro = false
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	var death := {"mite": "mite_death", "husk": "husk_death", "thornback": "thornback_death"}[kind] as String
	Audio.sfx_at(death, global_position + Vector3(0, 1, 0), 2.0, 8.0)
	Audio.sfx_at("crystal_shatter", global_position + Vector3(0, 1, 0), -2.0, 6.0)
	Game.add_xp(stats.xp, "Kill")
	_drop_loot()
	model.call("die", part, impulse)
	died.emit(self)
	await get_tree().create_timer(0.2).timeout
	queue_free()


func _drop_loot() -> void:
	var r := randf()
	var at := global_position + Vector3(randf_range(-0.4, 0.4), 0.05, randf_range(-0.4, 0.4))
	at.y = global_position.y + 0.05
	var scene := get_tree().current_scene
	if kind == "thornback":
		Pickup.spawn_item(scene, at, "pep_tonic", 2, "plastic_bottle_gallon")
		Pickup.spawn_item(scene, at + Vector3(0.6, 0, 0), "scrip", 120, "")
		return
	if r < 0.35:
		Pickup.spawn_item(scene, at, "ammo_38", randi_range(4, 8), "ammo_box", "ammo_box")
	elif r < 0.5:
		Pickup.spawn_item(scene, at, "scrip", randi_range(5, 25), "")
	elif r < 0.58:
		Pickup.spawn_item(scene, at, "pep_tonic", 1, "")
