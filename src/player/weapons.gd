extends Node3D
## Weapon viewmodels + hitscan shooting: recoil, sway, ADS, reloads, muzzle flash, shells, tracers, impacts.

signal ammo_changed(weapon: String, mag: int, reserve: int)
signal fired
signal hit_confirmed(killed: bool)

const DEFS := {
	"pistol": {
		"name": "Service Pistol", "mag": 8, "dmg": 34.0, "cooldown": 0.17, "reload": 1.55, "ammo": "ammo_38",
		"spread_hip": 2.2, "spread_ads": 0.35, "kick": 0.045, "sound": "pistol_fire",
		"hip": Vector3(0.19, -0.13, -0.62), "ads": Vector3(0.0, -0.066, -0.5), "hip_rot": Vector3(0.06, 0.48, 0.12), "ads_fov": 0.82,
	},
	"rifle": {
		"name": "Bolt-Action Rifle", "mag": 5, "dmg": 95.0, "cooldown": 1.05, "reload": 0.55, "ammo": "ammo_30",
		"spread_hip": 3.0, "spread_ads": 0.05, "kick": 0.11, "sound": "rifle_fire",
		"hip": Vector3(0.16, -0.16, -0.6), "ads": Vector3(0.0, -0.098, -0.42), "hip_rot": Vector3(0.0, 0.16, 0.08), "ads_fov": 0.4,
	},
}

var player: Node3D
var current := ""
var mags := {"pistol": 8, "rifle": 5}
var rigs := {}
var _rig: Node3D
var _slide: Node3D
var _bolt: Node3D
var _cool := 0.0
var _reloading := false
var _aim := 0.0
var _switching := false
var _recoil := 0.0
var _recoil_rot := 0.0
var _sway := Vector2.ZERO
var _bob_t := 0.0
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _decals: Array = []
static var _hole_tex: ImageTexture
var lowered := false  # true in safe areas (cozy home)


const DEPTH_SQUASH := 0.55  # compress viewmodels along the view axis = narrower apparent FOV


func setup(p: Node3D) -> void:
	player = p
	position = Vector3.ZERO
	scale = Vector3(1, 1, DEPTH_SQUASH)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.45)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 7.0
	_flash_light.shadow_enabled = false
	add_child(_flash_light)
	_flash_mesh = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	_flash_mesh.mesh = qm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_texture = _star_texture()
	fm.albedo_color = Color(1.0, 0.8, 0.5)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_mesh.material_override = fm
	_flash_mesh.visible = false
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash_mesh)


func has_weapon(w: String) -> bool:
	return Game.count(w) > 0


func is_aiming() -> bool:
	return _aim > 0.5 and current != ""


func equip(w: String) -> void:
	if w == current or _switching or not has_weapon(w):
		return
	_switching = true
	if _rig != null:
		var old := _rig
		var tw := create_tween()
		tw.tween_property(old, "position:y", old.position.y - 0.35, 0.18)
		await tw.finished
		old.visible = false
	current = w
	if not rigs.has(w):
		rigs[w] = _build_rig(w)
	_rig = rigs[w]
	_rig.visible = true
	var d: Dictionary = DEFS[w]
	_rig.position = d.hip + Vector3(0, -0.35, 0)
	Audio.sfx("pistol_slide" if w == "pistol" else "rifle_bolt_close", -8.0)
	var tw2 := create_tween()
	tw2.tween_property(_rig, "position", d.hip, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_switching = false
	_emit_ammo()


func holster() -> void:
	if _rig == null:
		return
	var tw := create_tween()
	tw.tween_property(_rig, "position:y", _rig.position.y - 0.35, 0.18)
	await tw.finished
	_rig.visible = false
	_rig = null
	current = ""
	_emit_ammo()


func _emit_ammo() -> void:
	if current == "":
		ammo_changed.emit("", 0, 0)
	else:
		ammo_changed.emit(current, mags[current], Game.count(DEFS[current].ammo))


# ------------------------------------------------------------------ rigs

func _build_rig(w: String) -> Node3D:
	var rig := Node3D.new()
	rig.name = w
	add_child(rig)
	var holder := Node3D.new()
	rig.add_child(holder)
	if w == "pistol":
		var scene: PackedScene = load(Props.path("service_pistol"))
		var inst := scene.instantiate()
		for n in ["service_pistol_pistol_a", "service_pistol_slide_a", "service_pistol_hammer_a", "service_pistol_trigger_a"]:
			var src: Node3D = inst.find_child(n, true, false)
			if src:
				var dup: Node3D = src.duplicate()
				dup.transform = _rel(inst, src)
				holder.add_child(dup)
				if n.ends_with("slide_a"):
					_slide = dup
		inst.free()
		# barrel points +X in the source; rotate so it points -Z, centre the grip
		holder.rotation_degrees = Vector3(0, 90, 0)
		holder.position = Vector3(0, -0.02, 0.0)
		holder.scale = Vector3.ONE * 1.0
	else:
		var scene2: PackedScene = load(Props.path("bolt_action_rifle_7_62"))
		var inst2 := scene2.instantiate()
		for n in ["bolt_action_rifle_7_62", "bolt_action_rifle_7_62_scope", "bolt_action_rifle_7_62_bolt_a", "bolt_action_rifle_7_62_bolt_b", "bolt_action_rifle_7_62_trigger", "bolt_action_rifle_7_62_wrap"]:
			var src2: Node3D = inst2.find_child(n, true, false)
			if src2:
				var dup2: Node3D = src2.duplicate()
				dup2.transform = _rel(inst2, src2)
				holder.add_child(dup2)
				if n.ends_with("bolt_a"):
					_bolt = dup2
		inst2.free()
		holder.rotation_degrees = Vector3(0, 90, 0)
		holder.position = Vector3(0, 0.0, 0.05)
	for m in rig.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(m as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if Game.shot_args.has("hands"):
		_add_hands(rig, w)
	rig.set_meta("muzzle", Vector3(0, 0.03, -0.2) if w == "pistol" else Vector3(0, 0.03, -0.75))
	return rig


func _add_hands(rig: Node3D, w: String) -> void:
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.22, 0.15, 0.1)
	glove.roughness = 0.65
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color(0.32, 0.3, 0.26)
	sleeve.roughness = 0.95
	var right := Node3D.new()
	rig.add_child(right)
	right.position = Vector3(0.0, -0.075, 0.07) if w == "pistol" else Vector3(0.0, -0.07, 0.12)
	_capsule(right, Vector3(0, 0, 0), Vector3(0.045, 0.1, 0.05), glove, Vector3(-15, 0, 0))
	_capsule(right, Vector3(0.0, -0.03, 0.2), Vector3(0.05, 0.3, 0.05), sleeve, Vector3(-75, 0, 0))
	var left := Node3D.new()
	rig.add_child(left)
	left.position = Vector3(-0.02, -0.08, 0.05) if w == "pistol" else Vector3(-0.0, -0.05, -0.28)
	_capsule(left, Vector3(0, 0, 0), Vector3(0.045, 0.09, 0.05), glove, Vector3(-10, 0, 30))
	_capsule(left, Vector3(-0.08, -0.04, 0.18), Vector3(0.05, 0.3, 0.05), sleeve, Vector3(-70, -25, 0))


func _capsule(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = size.x
	cm.height = size.y + size.x * 2.0
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	mi.rotation_degrees = rot


func _rel(root: Node, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur != null:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


# ------------------------------------------------------------------ update

var _dbg_t := 0.0
func _process(delta: float) -> void:
	var p := player as Player
	if p == null:
		return
	var can: bool = p.controls_enabled() and not Game.flag("_sureshot_active")
	if can:
		if Input.is_action_just_pressed("weapon_1") and has_weapon("pistol"):
			equip("pistol")
		elif Input.is_action_just_pressed("weapon_2") and has_weapon("rifle"):
			equip("rifle")
		elif Input.is_action_just_pressed("holster"):
			holster()
	_cool = maxf(_cool - delta, 0.0)
	var aim_in := can and Input.is_action_pressed("aim") and current != "" and not _reloading and not _switching
	_aim = move_toward(_aim, 1.0 if aim_in else 0.0, delta * (6.0 if current == "pistol" else 4.5))
	var base_fov: float = Game.settings.fov
	if current != "":
		p.cam.fov = lerpf(base_fov, base_fov * float(DEFS[current].ads_fov), _ease(_aim))
	else:
		p.cam.fov = lerpf(p.cam.fov, base_fov, delta * 8.0)
	if _rig == null or _switching:
		return
	if can and current != "":
		if Input.is_action_just_pressed("fire"):
			try_fire()
		if Input.is_action_just_pressed("reload"):
			reload()
	# placement: hip/ads blend + sway + bob + recoil
	var d: Dictionary = DEFS[current]
	var target: Vector3 = (d.hip as Vector3).lerp(d.ads, _ease(_aim))
	var mv := Input.get_last_mouse_velocity() * 0.00003 if can else Vector2.ZERO
	_sway = _sway.lerp(-mv * (0.25 if _aim > 0.5 else 1.0), minf(delta * 8.0, 1.0))
	var hv := Vector2(p.velocity.x, p.velocity.z).length()
	_bob_t += delta * hv * 1.9
	var bob := Vector3(cos(_bob_t) * 0.006, -absf(sin(_bob_t)) * 0.008, 0) * clampf(hv / 4.0, 0, 1.5) * (0.2 if _aim > 0.5 else 1.0)
	_recoil = move_toward(_recoil, 0.0, delta * 0.9)
	_recoil_rot = lerpf(_recoil_rot, 0.0, minf(delta * 10.0, 1.0))
	var low := 0.0
	if lowered and _aim < 0.1:
		low = 1.0
	# pull the gun in when pressed against a wall
	var cam3: Camera3D = (player as Player).cam
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam3.global_position, cam3.global_position - cam3.global_transform.basis.z * 0.7, 1)
	q.exclude = [(player as Player).get_rid()]
	if not space.intersect_ray(q).is_empty():
		low = maxf(low, 0.7)
	var sprinting := Input.is_action_pressed("sprint") and hv > 4.5
	var pos := target + Vector3(_sway.x, _sway.y, 0) + bob + Vector3(0, 0, _recoil)
	if sprinting:
		pos += Vector3(-0.06, -0.06, 0.04)
	pos += Vector3(0, -0.15, 0.05) * low
	_rig.position = _rig.position.lerp(pos, minf(delta * 18.0, 1.0))
	var base_rot: Vector3 = (d.hip_rot as Vector3) * (1.0 - _ease(_aim))
	var rot := base_rot + Vector3(_recoil_rot + (-0.35 * low) + (-0.25 if sprinting else 0.0), _sway.x * 2.0 + (0.4 if sprinting else 0.0), -_sway.x * 1.5 + (0.3 if sprinting else 0.0))
	_rig.rotation = _rig.rotation.lerp(rot, minf(delta * 14.0, 1.0))


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ firing

func try_fire() -> bool:
	if current == "" or _cool > 0.0 or _reloading or _switching:
		return false
	if mags[current] <= 0:
		Audio.sfx("dry_fire", -4.0)
		_cool = 0.3
		if Game.count(DEFS[current].ammo) > 0:
			reload()
		return false
	var dir := _spread_dir(DEFS[current].spread_ads if _aim > 0.5 else DEFS[current].spread_hip)
	_fire_ray(dir, 1.0)
	return true


## Fire at an exact world point (SureShot). hit: whether the roll succeeded.
func fire_at(point: Vector3, hit: bool, dmg_mult := 1.0) -> void:
	if current == "" or mags[current] <= 0:
		return
	var from := (player as Player).cam.global_position
	var dir := (point - from).normalized()
	if not hit:
		dir = (dir + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)) * 0.06).normalized()
	_fire_ray(dir, dmg_mult)


func _spread_dir(deg: float) -> Vector3:
	var cam: Camera3D = (player as Player).cam
	var b := cam.global_transform.basis
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 1.0
	var s := deg_to_rad(deg * (1.6 if moving else 1.0))
	var a := randf() * TAU
	var r := sqrt(randf()) * s
	return (-b.z + b.x * cos(a) * r + b.y * sin(a) * r).normalized()


func _fire_ray(dir: Vector3, dmg_mult: float) -> void:
	var d: Dictionary = DEFS[current]
	mags[current] -= 1
	_cool = d.cooldown
	var p := player as Player
	var from := p.cam.global_position
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0, 1 | 8)
	q.collide_with_areas = true
	q.exclude = [p.get_rid()]
	var hit := space.intersect_ray(q)
	# feedback
	var loud := 0.0 if current == "pistol" else 3.0
	Audio.sfx(d.sound, loud, 0.05)
	var indoor := p.indoors > 0.5
	Audio.sfx("gun_tail_indoor" if indoor else "gun_tail_outdoor", -6.0 + loud, 0.1)
	p.kick(d.kick * (0.5 if _aim > 0.5 else 1.0), randf_range(-0.01, 0.01))
	p.shake(0.25 if current == "pistol" else 0.45)
	_recoil = 0.05 if current == "pistol" else 0.09
	_recoil_rot = 0.18 if current == "pistol" else 0.22
	_muzzle_flash()
	if _slide:
		var tw := create_tween()
		var sp := _slide.position
		tw.tween_property(_slide, "position", sp + Vector3(-0.035, 0, 0), 0.03)
		tw.tween_property(_slide, "position", sp, 0.07)
		_eject_shell(Vector3(0.03, 0.04, -0.08))
	get_tree().call_group("enemies", "on_gunshot", p.global_position)
	fired.emit()
	var end := from + dir * 120.0
	if not hit.is_empty():
		end = hit.position
		var col: Object = hit.collider
		if col is Area3D and col.has_meta("actor"):
			var actor: Object = col.get_meta("actor")
			var part: String = col.get_meta("part")
			var dmg: float = d.dmg * dmg_mult * (1.1 if Game.traits.has("selfreliant") else 1.0)
			if is_instance_valid(actor):
				var target: Node = actor
				# models may report themselves; the controller is their owner/parent
				while target != null and not target.has_method("take_hit"):
					target = target.get_parent()
				if target != null:
					var killed: bool = target.call("take_hit", part, dmg, dir, hit.position)
					hit_confirmed.emit(killed)
			_impact(hit.position, hit.normal, "crystal")
		else:
			var surf := "concrete"
			if col is Node and (col as Node).has_meta("surface"):
				surf = (col as Node).get_meta("surface")
			_impact(hit.position, hit.normal, surf)
			_bullet_hole(hit.position, hit.normal, col as Node)
	_tracer(_muzzle_world(), end)
	_emit_ammo()
	if current == "rifle" and mags[current] > 0:
		_cycle_bolt()
	elif mags[current] == 0 and Game.count(d.ammo) > 0:
		get_tree().create_timer(0.35).timeout.connect(reload)


func _cycle_bolt() -> void:
	await get_tree().create_timer(0.3).timeout
	if _bolt == null or current != "rifle":
		return
	Audio.sfx("rifle_bolt_open", -4.0)
	var tw := create_tween()
	var bp := _bolt.position
	tw.tween_property(_rig, "rotation:z", 0.25, 0.12)
	tw.parallel().tween_property(_bolt, "position", bp + Vector3(-0.07, 0, 0), 0.15)
	tw.tween_callback(func(): _eject_shell(Vector3(0.03, 0.05, -0.15)))
	tw.tween_callback(func(): Audio.sfx("rifle_bolt_close", -4.0))
	tw.tween_property(_bolt, "position", bp, 0.15)
	tw.parallel().tween_property(_rig, "rotation:z", 0.0, 0.2)


func reload() -> void:
	if current == "" or _reloading:
		return
	var d: Dictionary = DEFS[current]
	if mags[current] >= d.mag or Game.count(d.ammo) <= 0:
		return
	_reloading = true
	var speed := 1.2 if Game.traits.has("steady") else 1.0
	var rig := _rig
	if current == "pistol":
		Audio.sfx("pistol_mag_out", -3.0)
		var tw := create_tween()
		tw.tween_property(rig, "rotation", Vector3(0.5, 0.25, 0.45), 0.25 / speed)
		await tw.finished
		await get_tree().create_timer(0.45 / speed).timeout
		Audio.sfx("pistol_mag_in", -3.0)
		await get_tree().create_timer(0.35 / speed).timeout
		Audio.sfx("pistol_slide", -3.0)
		var need: int = d.mag - mags[current]
		var take: int = mini(need, Game.count(d.ammo))
		Game.remove_item(d.ammo, take)
		mags[current] += take
		var tw2 := create_tween()
		tw2.tween_property(rig, "rotation", Vector3.ZERO, 0.25 / speed)
		await tw2.finished
	else:
		Audio.sfx("rifle_bolt_open", -3.0)
		var tw3 := create_tween()
		tw3.tween_property(rig, "rotation", Vector3(0.25, 0.1, 0.5), 0.25 / speed)
		await tw3.finished
		while mags["rifle"] < d.mag and Game.count(d.ammo) > 0 and current == "rifle":
			await get_tree().create_timer(d.reload / speed).timeout
			Audio.sfx("rifle_round_in", -3.0)
			Game.remove_item(d.ammo, 1)
			mags["rifle"] += 1
			_emit_ammo()
			if Input.is_action_pressed("fire"):
				break
		Audio.sfx("rifle_bolt_close", -3.0)
		var tw4 := create_tween()
		tw4.tween_property(rig, "rotation", Vector3.ZERO, 0.25 / speed)
		await tw4.finished
	_reloading = false
	_emit_ammo()


# ------------------------------------------------------------------ fx

func _muzzle_world() -> Vector3:
	if _rig == null:
		return global_position
	return _rig.to_global(_rig.get_meta("muzzle"))


func _muzzle_flash() -> void:
	var m := _muzzle_world()
	_flash_light.global_position = m
	_flash_light.light_energy = 6.0
	_flash_mesh.global_position = m
	_flash_mesh.visible = true
	_flash_mesh.rotation.z = randf() * TAU
	_flash_mesh.scale = Vector3.ONE * randf_range(0.8, 1.3) * (1.0 if current == "pistol" else 1.6)
	var tw := create_tween()
	tw.tween_property(_flash_light, "light_energy", 0.0, 0.07)
	tw.parallel().tween_callback(func(): _flash_mesh.visible = false).set_delay(0.035)
	Fx.smoke_puff(get_tree().current_scene, m + (player as Player).get_look_dir() * 0.25, 0.09, Color(0.85, 0.83, 0.8, 0.18))


func _eject_shell(local_off: Vector3) -> void:
	if _rig == null:
		return
	var shell := RigidBody3D.new()
	shell.collision_layer = 32
	shell.collision_mask = 1
	shell.mass = 0.02
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.006
	cy.height = 0.03 if current == "pistol" else 0.06
	cs.shape = cy
	shell.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0055
	cm.bottom_radius = 0.0055
	cm.height = cy.height
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = Mats.color(Color(0.85, 0.62, 0.3), 0.3, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_child(mi)
	get_tree().current_scene.add_child(shell)
	shell.global_transform = Transform3D(_rig.global_transform.basis.orthonormalized().rotated(Vector3.FORWARD, 1.4), _rig.to_global(local_off))
	var b := (player as Player).cam.global_transform.basis
	shell.linear_velocity = player.velocity + b.x * randf_range(1.6, 2.4) + b.y * randf_range(1.2, 2.0) + b.z * 0.4
	shell.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	var pos := shell
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(pos):
			Audio.sfx_at("shell", pos.global_position, -12.0, 2.0))
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(pos):
			pos.queue_free())


func _tracer(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 2.0:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, minf(len, 14.0))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.85, 0.55, 0.6)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	var dir := (b - a).normalized()
	mi.global_position = a + dir * minf(len, 14.0) * 0.5
	mi.look_at(b, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", b - dir * minf(len, 14.0) * 0.5, minf(len / 400.0, 0.12))
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(mi.queue_free)


func _impact(pos: Vector3, nrm: Vector3, surf: String) -> void:
	var scene := get_tree().current_scene
	match surf:
		"crystal":
			Audio.sfx_at("impact_crystal", pos, 0.0, 5.0)
			Fx.sparks(scene, pos, nrm, Color(0.75, 0.5, 1.0), 14)
		"metal":
			Audio.sfx_at("impact_metal", pos, -2.0, 5.0)
			Fx.sparks(scene, pos, nrm, Color(1.0, 0.75, 0.4), 10)
			if randf() < 0.35:
				Audio.sfx_at("ricochet", pos, -4.0, 6.0)
		"wood", "carpet":
			Audio.sfx_at("impact_wood", pos, -2.0, 5.0)
			Fx.debris(scene, pos, nrm, Color(0.45, 0.32, 0.2), 8)
		"grass", "gravel", "dirt":
			Audio.sfx_at("impact_dirt", pos, -2.0, 5.0)
			Fx.debris(scene, pos, nrm, Color(0.35, 0.3, 0.22), 10)
			Fx.smoke_puff(scene, pos, 0.5, Color(0.45, 0.4, 0.33, 0.6))
		"glass":
			Audio.sfx_at("glass_break", pos, -6.0, 5.0)
			Fx.debris(scene, pos, nrm, Color(0.8, 0.9, 1.0), 10)
		_:
			Audio.sfx_at("impact_concrete", pos, -2.0, 5.0)
			Fx.debris(scene, pos, nrm, Color(0.6, 0.58, 0.55), 9)
			Fx.smoke_puff(scene, pos, 0.4, Color(0.6, 0.58, 0.55, 0.5))


func _bullet_hole(pos: Vector3, nrm: Vector3, col: Node) -> void:
	if col == null or not col is StaticBody3D:
		return
	if _hole_tex == null:
		_hole_tex = _make_hole_texture()
	var dcl := Decal.new()
	dcl.texture_albedo = _hole_tex
	dcl.size = Vector3(0.09, 0.1, 0.09)
	dcl.cull_mask = 1
	get_tree().current_scene.add_child(dcl)
	dcl.global_position = pos
	var up := nrm
	var ref := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	dcl.global_transform.basis = Basis(x, up, z).rotated(up, randf() * TAU)
	_decals.append(dcl)
	if _decals.size() > 60:
		var old: Node = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func _make_hole_texture() -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0, y - s / 2.0).length() / (s / 2.0)
			var a := 0.0
			var c := Color(0.05, 0.04, 0.03)
			if d < 0.22:
				a = 1.0
			elif d < 0.7:
				a = (1.0 - (d - 0.22) / 0.48) * 0.55 * (0.6 + 0.4 * sin(atan2(y - s / 2.0, x - s / 2.0) * 7.0))
				c = Color(0.18, 0.16, 0.14)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(a, 0, 1)))
	return ImageTexture.create_from_image(img)


static func _star_texture() -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var v := Vector2(x - s / 2.0, y - s / 2.0) / (s / 2.0)
			var r := v.length()
			var ang := atan2(v.y, v.x)
			var star := pow(absf(cos(ang * 3.0)), 18.0) * (1.0 - r)
			var core := clampf(1.0 - r * 2.2, 0, 1)
			var a := clampf(core + star * 1.4, 0, 1)
			img.set_pixel(x, y, Color(1, 0.9, 0.7, a))
	return ImageTexture.create_from_image(img)
