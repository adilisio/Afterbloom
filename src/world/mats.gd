class_name Mats
extends RefCounted
## Cached material library. PBR textures from assets/textures/<id>/ use world triplanar mapping.

static var _cache := {}


## Poly Haven PBR texture as a world-triplanar material. tile_m = metres per texture repeat.
static func tex(id: String, tile_m := 2.0, tint := Color.WHITE, rough_mul := 1.0) -> StandardMaterial3D:
	var key := "tex:%s:%s:%s:%s" % [id, tile_m, tint.to_html(), rough_mul]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var base := "res://assets/textures/%s/%s_" % [id, id]
	if ResourceLoader.exists(base + "diff.jpg"):
		m.albedo_texture = load(base + "diff.jpg")
	if ResourceLoader.exists(base + "nor_gl.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(base + "nor_gl.jpg")
		m.normal_scale = 1.0
	if ResourceLoader.exists(base + "rough.jpg"):
		m.roughness_texture = load(base + "rough.jpg")
		m.roughness = rough_mul
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / tile_m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


## Same as tex() but box-UV (object space) so it moves with animated objects (doors etc).
static func tex_local(id: String, tile_m := 1.0, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "texl:%s:%s:%s" % [id, tile_m, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m: StandardMaterial3D = tex(id, tile_m, tint).duplicate()
	m.uv1_world_triplanar = false
	_cache[key] = m
	return m


static func color(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var key := "col:%s:%s:%s" % [c.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_cache[key] = m
	return m


static func emissive(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "emi:%s:%s" % [c.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


static func glass(tint := Color(0.75, 0.85, 0.9, 0.18), dirty := false) -> StandardMaterial3D:
	var key := "glass:%s:%s" % [tint.to_html(), dirty]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = tint
	m.roughness = 0.35 if dirty else 0.04
	m.metallic = 0.0
	m.metallic_specular = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if dirty:
		m.albedo_color = Color(0.55, 0.52, 0.45, 0.45)
	_cache[key] = m
	return m


## Generated 2D art (assets/textures/gen/<name>.png) as an unlit-ish printed surface.
static func gen(name: String, rough := 0.8, emissive_amt := 0.0) -> StandardMaterial3D:
	var key := "gen:%s:%s:%s" % [name, rough, emissive_amt]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var p := "res://assets/textures/gen/%s.png" % name
	if ResourceLoader.exists(p):
		m.albedo_texture = load(p)
	else:
		m.albedo_color = Color(0.85, 0.8, 0.7)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if emissive_amt > 0.0 and m.albedo_texture != null:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = emissive_amt
	if m.albedo_texture != null and name.begins_with("logo"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_cache[key] = m
	return m


static func gen_exists(name: String) -> bool:
	return ResourceLoader.exists("res://assets/textures/gen/%s.png" % name)


## Wallpaper: generated tile if available, else a plaster texture tinted.
static func wallpaper(name: String, fallback_tint: Color) -> StandardMaterial3D:
	var key := "wp:%s" % name
	if _cache.has(key):
		return _cache[key]
	var m: StandardMaterial3D
	var p := "res://assets/textures/gen/%s.png" % name
	if ResourceLoader.exists(p):
		m = tex("painted_plaster_wall", 1.6, Color.WHITE).duplicate()
		m.albedo_texture = load(p)
		m.uv1_scale = Vector3.ONE / 1.2
		m.normal_scale = 0.35
	else:
		m = tex("painted_plaster_wall", 2.0, fallback_tint)
	_cache[key] = m
	return m
