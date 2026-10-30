class_name ZapArc
extends Node3D
## Flickering electric arc between two world points (camera-facing ribbons + flash light).
## Used by Tuppence's "zap"; the game can also spawn it for the real attack.

const ARC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float intensity = 6.0;
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float core = smoothstep(0.35, 0.0, x);
	float halo = pow(1.0 - x, 2.0);
	ALBEDO = (color.rgb * halo + vec3(1.0) * core) * intensity * COLOR.a;
	ALPHA = clamp(halo + core, 0.0, 1.0) * COLOR.a;
}
"""

static var _shader: Shader

var from_pos := Vector3.ZERO
var to_pos := Vector3.FORWARD
var duration := 0.4
var color := Color(0.45, 0.85, 1.0)
var width := 0.03
var follow_from: Node3D ## optional: arc start follows this node

var _t := 0.0
var _jitter_t := 0.0
var _im := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _mat := ShaderMaterial.new()
var _rng := RandomNumberGenerator.new()
var _pts := PackedVector3Array()


static func spawn(parent: Node, from: Vector3, to: Vector3, dur := 0.4, col := Color(0.45, 0.85, 1.0)) -> ZapArc:
	var z := ZapArc.new()
	z.from_pos = from
	z.to_pos = to
	z.duration = dur
	z.color = col
	parent.add_child(z)
	return z


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	if _shader == null:
		_shader = Shader.new()
		_shader.code = ARC_SHADER
	_mat.shader = _shader
	_mat.set_shader_parameter("color", color)
	_mi.mesh = _im
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 16.0
	add_child(_mi)
	_light.light_color = color
	_light.light_energy = 4.0
	_light.omni_range = 3.0
	_light.shadow_enabled = false
	add_child(_light)
	_rng.randomize()
	_rebuild()


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(follow_from):
		from_pos = follow_from.global_position
	if _t >= duration:
		queue_free()
		return
	_jitter_t -= delta
	if _jitter_t <= 0.0:
		_jitter_t = 0.035
		_rebuild()
	var k := 1.0 - _t / duration
	_light.light_energy = (3.0 + _rng.randf() * 3.0) * k
	_light.global_position = from_pos.lerp(to_pos, 0.3)


func _bolt(a: Vector3, b: Vector3, segs: int, amp: float, w: float, alpha: float, cam: Vector3) -> void:
	_pts.clear()
	var d := b - a
	var dist := d.length()
	var dir := d / maxf(dist, 0.0001)
	var s1 := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var s2 := dir.cross(s1)
	for i in segs + 1:
		var t := float(i) / segs
		var env := sin(t * PI)
		var off := (s1 * _rng.randf_range(-1, 1) + s2 * _rng.randf_range(-1, 1)) * amp * dist * env
		_pts.append(a + d * t + off)
	for i in segs:
		var p0 := _pts[i]
		var p1 := _pts[i + 1]
		var side := (p1 - p0).cross(cam - p0).normalized() * w
		_im.surface_set_color(Color(1, 1, 1, alpha))
		_im.surface_set_uv(Vector2(0, 0)); _im.surface_add_vertex(p0 - side)
		_im.surface_set_uv(Vector2(1, 0)); _im.surface_add_vertex(p0 + side)
		_im.surface_set_uv(Vector2(0, 1)); _im.surface_add_vertex(p1 - side)
		_im.surface_set_uv(Vector2(1, 0)); _im.surface_add_vertex(p0 + side)
		_im.surface_set_uv(Vector2(1, 1)); _im.surface_add_vertex(p1 + side)
		_im.surface_set_uv(Vector2(0, 1)); _im.surface_add_vertex(p1 - side)


func _rebuild() -> void:
	var cam_pos := from_pos + Vector3(0, 0, 5)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		cam_pos = cam.global_position
	var k := clampf(1.0 - _t / maxf(duration, 0.001), 0.0, 1.0)
	var alpha := (0.55 + _rng.randf() * 0.45) * (0.4 + 0.6 * k)
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_bolt(from_pos, to_pos, 22, 0.05, width, alpha, cam_pos)
	_bolt(from_pos, to_pos, 16, 0.08, width * 0.5, alpha * 0.6, cam_pos)
	# a couple of short forks
	for f in 2:
		var t := _rng.randf_range(0.2, 0.7)
		var a := from_pos.lerp(to_pos, t)
		var b := a + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() * from_pos.distance_to(to_pos) * 0.22
		_bolt(a, b, 4, 0.2, width * 0.4, alpha * 0.5, cam_pos)
	_im.surface_end()
