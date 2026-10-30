class_name Ocean
extends MeshInstance3D
## Large ocean surface at y = 0 (the node's origin is sea level).
##
## The mesh is a camera-following polar grid (dense near the camera, coarse to the horizon), so the
## node can be placed anywhere; `size` + `clip` decide where water is visible. By default the water
## extends to the horizon on the seaward sides and is cut off on the landward (+X local) edge.
## SkyWeather drives every node in the "ocean" group automatically (sea state, tint, sun).

enum Clip { NONE, LANDWARD_EDGE, RECTANGLE }

## Visible water area in local XZ (metres), centred on the node.
@export var size: Vector2 = Vector2(3000.0, 3000.0)
## NONE: infinite water. LANDWARD_EDGE: cut off where local x > size.x/2. RECTANGLE: cut to `size`.
@export var clip: Clip = Clip.LANDWARD_EDGE
## Grid radius (metres). The grid follows the camera, so this is "view distance over water".
@export var grid_radius: float = 24000.0
@export var grid_segments: int = 224
@export_range(0.0, 1.0) var weather_intensity: float = 0.25
## Seconds to blend to a new weather intensity.
@export var intensity_smoothing: float = 8.0

## Gerstner set: wavelength (m), angle from wind (rad), steepness. Steepness sum stays < 1.
const WAVES: Array[Vector3] = [
	Vector3(64.0, 0.0, 0.17),
	Vector3(37.0, 0.42, 0.15),
	Vector3(23.0, -0.35, 0.14),
	Vector3(13.5, 0.85, 0.11),
	Vector3(8.2, -0.75, 0.09),
	Vector3(5.1, 0.2, 0.07),
	Vector3(3.1, 1.15, 0.06),
	Vector3(1.9, -1.05, 0.05),
]
const WIND_DIR := Vector2(0.94, 0.34)

var _mat: ShaderMaterial
var _intensity: float = 0.25
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"ocean")
	_intensity = weather_intensity
	mesh = _build_grid()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r := grid_radius + 100.0
	custom_aabb = AABB(Vector3(-r, -20.0, -r) * 2.0, Vector3(r, 20.0, r) * 4.0)
	extra_cull_margin = 16384.0
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/world/sky/ocean.gdshader")
	var wv: Array[Vector4] = []
	for w in WAVES:
		wv.append(Vector4(w.x, w.y, w.z, 0.0))
	_mat.set_shader_parameter("waves", wv)
	_mat.set_shader_parameter("wind_dir", WIND_DIR)
	_mat.set_shader_parameter("normal_a", _noise_normal(0.012, 512, 6.0, 7))
	_mat.set_shader_parameter("normal_b", _noise_normal(0.03, 256, 5.0, 19))
	_mat.set_shader_parameter("foam_tex", _foam_texture())
	material_override = _mat
	_update_clip()


func _process(delta: float) -> void:
	_time += delta
	_intensity = move_toward(_intensity, weather_intensity, delta / maxf(intensity_smoothing, 0.01))
	_mat.set_shader_parameter("wave_time", _time)
	_mat.set_shader_parameter("storm", _intensity)


## 0 calm .. 1 stormy (blends over `intensity_smoothing` seconds).
func set_weather_intensity(f: float, instant: bool = false) -> void:
	weather_intensity = clampf(f, 0.0, 1.0)
	if instant:
		_intensity = weather_intensity


## Multiplies the water body colour (WHITE = natural). Bloom era: a faint violet.
func set_tint(c: Color) -> void:
	if _mat:
		_mat.set_shader_parameter("tint", Color(c.r, c.g, c.b))


## Called by SkyWeather each frame: sun direction (towards the sun), colour, energy, violet glow 0..1.
func set_sky_state(sun_dir: Vector3, sun_color: Color, sun_energy: float, bloom_glow: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("sun_dir", sun_dir)
	_mat.set_shader_parameter("sun_color", Color(sun_color.r, sun_color.g, sun_color.b))
	_mat.set_shader_parameter("sun_energy", sun_energy)
	_mat.set_shader_parameter("glow", bloom_glow)


## Approximate water surface height (world Y) at a world position, matching the shader's swell.
## Useful for buoys/boats/splash checks.
func get_wave_height(world_pos: Vector3) -> float:
	var p := Vector2(world_pos.x, world_pos.z)
	# one fixed-point step to undo the horizontal Gerstner displacement
	var d := _gerstner(p)
	d = _gerstner(p - Vector2(d.x, d.z))
	return global_position.y + d.y


func _gerstner(p: Vector2) -> Vector3:
	var steep_scale := lerpf(0.1, 0.72, _intensity)
	var len_scale := lerpf(1.0, 1.3, _intensity)
	var disp := Vector3.ZERO
	for i in WAVES.size():
		var w: Vector3 = WAVES[i]
		var wl := w.x * len_scale
		var s := w.z * steep_scale
		var k := TAU / wl
		var c := sqrt(9.81 / k)
		var d := WIND_DIR.rotated(w.y).normalized()
		var f := k * (d.dot(p) - c * _time) + float(i) * 1.7
		var a := s / k
		disp += Vector3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f))
	return disp


func _update_clip() -> void:
	_mat.set_shader_parameter("clip_mode", int(clip))
	_mat.set_shader_parameter("half_size", size * 0.5)


func _build_grid() -> ArrayMesh:
	var radii := PackedFloat32Array([0.0])
	var r := 0.0
	while r < grid_radius:
		r += maxf(0.3, r * 0.05)
		radii.append(minf(r, grid_radius))
	var seg := maxi(grid_segments, 16)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	for ri in range(1, radii.size()):
		for s in seg:
			var a := TAU * float(s) / float(seg)
			verts.append(Vector3(cos(a) * radii[ri], 0.0, sin(a) * radii[ri]))
			normals.append(Vector3.UP)
	# centre fan (clockwise seen from above => front face up in Godot)
	for s in seg:
		var a0 := 1 + s
		var a1 := 1 + (s + 1) % seg
		indices.append_array([0, a0, a1])
	for ri in range(1, radii.size() - 1):
		var base0 := 1 + (ri - 1) * seg
		var base1 := 1 + ri * seg
		for s in seg:
			var s1 := (s + 1) % seg
			var i00 := base0 + s
			var i01 := base0 + s1
			var i10 := base1 + s
			var i11 := base1 + s1
			indices.append_array([i00, i11, i01, i00, i10, i11])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _noise_normal(freq: float, res: int, bump: float, seed_v: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = seed_v
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = res
	t.height = res
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = bump
	t.generate_mipmaps = true
	t.noise = n
	return t


func _foam_texture() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.03
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	n.seed = 3
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.generate_mipmaps = true
	t.normalize = true
	t.noise = n
	return t
