class_name Fx
extends RefCounted
## One-shot particle effects (CPU particles: cheap to spawn, no shader compile hitches).

static var _mats := {}


static func _mat(c: Color, additive: bool, soft := true) -> StandardMaterial3D:
	var key := "%s%s%s" % [c.to_html(), additive, soft]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if additive else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if soft:
		m.albedo_texture = _soft_tex()
	m.proximity_fade_enabled = soft
	m.proximity_fade_distance = 0.3
	_mats[key] = m
	return m


static var _soft: ImageTexture
static func _soft_tex() -> ImageTexture:
	if _soft:
		return _soft
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length() / (s / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0, 1) ** 1.6))
	_soft = ImageTexture.create_from_image(img)
	return _soft


static func _emit(parent: Node, pos: Vector3, p: CPUParticles3D, life: float) -> void:
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.emitting = true
	parent.add_child(p)
	p.global_position = pos
	p.get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


static func smoke_puff(parent: Node, pos: Vector3, size := 0.5, col := Color(0.8, 0.78, 0.75, 0.35)) -> void:
	var p := CPUParticles3D.new()
	p.amount = 6
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.material = _mat(col, false)
	p.mesh = qm
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, 0.3, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	_emit(parent, pos, p, 1.2)


static func sparks(parent: Node, pos: Vector3, nrm: Vector3, col: Color, n := 12) -> void:
	var p := CPUParticles3D.new()
	p.amount = n
	var bm := BoxMesh.new()
	bm.size = Vector3(0.01, 0.01, 0.06)
	bm.material = _mat(col * 3.0, true, false)
	p.mesh = bm
	p.particle_flag_align_y = true
	p.direction = nrm
	p.spread = 50.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	_emit(parent, pos + nrm * 0.02, p, 0.45)


static func debris(parent: Node, pos: Vector3, nrm: Vector3, col: Color, n := 8) -> void:
	var p := CPUParticles3D.new()
	p.amount = n
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, 0.025)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.vertex_color_use_as_albedo = false
	bm.material = m
	p.mesh = bm
	p.direction = nrm
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.8, 0)
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3
	_emit(parent, pos + nrm * 0.02, p, 0.9)


static func glow_motes(parent: Node, pos: Vector3, col: Color, n := 24, spread_r := 0.6) -> void:
	var p := CPUParticles3D.new()
	p.amount = n
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	qm.material = _mat(col, true)
	p.mesh = qm
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread_r
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.2, 0)
	p.damping_min = 0.5
	p.damping_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	_emit(parent, pos, p, 2.2)
