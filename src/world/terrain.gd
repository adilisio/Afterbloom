class_name Terrain
extends Node3D
## Heightmap terrain from Layout.height(): chunked meshes, a HeightMapShape3D collider, splat shader.

const CHUNK := 32  # cells per chunk side

var era := "before"
var _heights := PackedFloat32Array()
var _nx := 0
var _nz := 0
var _mat: ShaderMaterial


func build(p_era: String) -> void:
	era = p_era
	_nx = int((Layout.MAX_X - Layout.MIN_X) / Layout.CELL) + 1
	_nz = int((Layout.MAX_Z - Layout.MIN_Z) / Layout.CELL) + 1
	_heights = Layout.grid_heights()
	_mat = _make_material()
	for cj in range(0, _nz - 1, CHUNK):
		for ci in range(0, _nx - 1, CHUNK):
			_build_chunk(ci, cj)
	_build_collision()


func h_at(x: float, z: float) -> float:
	var fx := (x - Layout.MIN_X) / Layout.CELL
	var fz := (z - Layout.MIN_Z) / Layout.CELL
	var i := clampi(int(fx), 0, _nx - 2)
	var j := clampi(int(fz), 0, _nz - 2)
	var tx := clampf(fx - i, 0.0, 1.0)
	var tz := clampf(fz - j, 0.0, 1.0)
	var h00 := _heights[j * _nx + i]
	var h10 := _heights[j * _nx + i + 1]
	var h01 := _heights[(j + 1) * _nx + i]
	var h11 := _heights[(j + 1) * _nx + i + 1]
	# match the triangulation used by the mesh (diagonal from 00 to 11)
	if tx >= tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


func _vert(i: int, j: int) -> Vector3:
	return Vector3(Layout.MIN_X + i * Layout.CELL, _heights[j * _nx + i], Layout.MIN_Z + j * Layout.CELL)


func _normal(i: int, j: int) -> Vector3:
	var hl := _heights[j * _nx + maxi(i - 1, 0)]
	var hr := _heights[j * _nx + mini(i + 1, _nx - 1)]
	var hd := _heights[maxi(j - 1, 0) * _nx + i]
	var hu := _heights[mini(j + 1, _nz - 1) * _nx + i]
	return Vector3(hl - hr, 2.0 * Layout.CELL, hd - hu).normalized()


func _build_chunk(ci: int, cj: int) -> void:
	var i1 := mini(ci + CHUNK, _nx - 1)
	var j1 := mini(cj + CHUNK, _nz - 1)
	var w := i1 - ci + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tans := PackedFloat32Array()
	var idx := PackedInt32Array()
	var all_under := true
	for j in range(cj, j1 + 1):
		for i in range(ci, i1 + 1):
			var v := _vert(i, j)
			if v.y > -6.0:
				all_under = false
			verts.append(v)
			norms.append(_normal(i, j))
			uvs.append(Vector2(v.x, v.z))
			tans.append_array([1.0, 0.0, 0.0, 1.0])
	if all_under:
		return
	for j in range(0, j1 - cj):
		for i in range(0, i1 - ci):
			# notch where the shelter portal pierces the hillside: the grid quad x 178..180 slopes from the road
			# (26 m) up to the hill and would otherwise stand across the open doorway as a dirt ramp
			var qx := Layout.MIN_X + (ci + i) * Layout.CELL
			var qz := Layout.MIN_Z + (cj + j) * Layout.CELL
			if qx >= 177.9 and qx < 179.9 and qz >= -100.1 and qz < -90.1:
				continue
			var a := j * w + i
			var b := a + 1
			var c := a + w
			var d := c + 1
			idx.append_array([a, b, d, a, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = _mat
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(mi)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.set_meta("surface", "grass")
	body.set_meta("terrain", true)
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = _nx
	hs.map_depth = _nz
	# uniform scale only (non-uniform collision scaling is unsupported), so heights are pre-divided
	var scaled := _heights.duplicate()
	for k in scaled.size():
		scaled[k] = scaled[k] / Layout.CELL
	# hole over Shelter No. 9 (underground rooms would otherwise be pushed out of the heightmap)
	for j in _nz:
		var z := Layout.MIN_Z + j * Layout.CELL
		if z < -128.0 or z > -68.0:
			continue
		for i in _nx:
			var x := Layout.MIN_X + i * Layout.CELL
			if x > 178.0 and x < 262.0:
				scaled[j * _nx + i] = NAN
	hs.map_data = scaled
	cs.shape = hs
	cs.scale = Vector3.ONE * Layout.CELL
	cs.position = Vector3((Layout.MIN_X + Layout.MAX_X) * 0.5, 0, (Layout.MIN_Z + Layout.MAX_Z) * 0.5)
	body.add_child(cs)
	add_child(body)


func _tex(id: String, kind: String) -> Texture2D:
	var p := "res://assets/textures/%s/%s_%s.jpg" % [id, id, kind]
	return load(p) if ResourceLoader.exists(p) else null


func _make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/world/shaders/terrain.gdshader")
	var after := era == "after"
	m.set_shader_parameter("grass_alb", _tex("withered_grass" if after else "leafy_grass", "diff"))
	m.set_shader_parameter("grass_nrm", _tex("withered_grass" if after else "leafy_grass", "nor_gl"))
	m.set_shader_parameter("grass2_alb", _tex("dry_decay_leaves" if after else "sparse_grass", "diff"))
	m.set_shader_parameter("dirt_alb", _tex("forest_ground_04", "diff"))
	m.set_shader_parameter("dirt_nrm", _tex("forest_ground_04", "nor_gl"))
	m.set_shader_parameter("sand_alb", _tex("coast_sand_01", "diff"))
	m.set_shader_parameter("sand_nrm", _tex("coast_sand_01", "nor_gl"))
	m.set_shader_parameter("rock_alb", _tex("rock_face", "diff"))
	m.set_shader_parameter("rock_nrm", _tex("rock_face", "nor_gl"))
	var n := FastNoiseLite.new()
	n.frequency = 0.004
	n.fractal_octaves = 4
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.noise = n
	m.set_shader_parameter("macro", nt)
	m.set_shader_parameter("after", 1.0 if after else 0.0)
	return m
