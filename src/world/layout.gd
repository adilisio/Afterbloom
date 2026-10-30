class_name Layout
extends RefCounted
## The map of Larkhaven: one height function, the road network, building lots and landmark positions.
## +X east (inland, toward the bluff), -X west (the sea), -Z north (toward the lighthouse), +Z south.

const MIN_X := -420.0
const MAX_X := 330.0
const MIN_Z := -420.0
const MAX_Z := 330.0
const CELL := 2.0

const HOME := Vector3(0, 0, -17)          # player's house lot centre (front faces +Z, the street)
const SHELTER_PORTAL := Vector3(178, 0, -95)  # gate face (tunnel goes +X into the hill)
const SQUARE := Vector3(-55, 0, 128)
const LIGHTHOUSE := Vector3(-158, 0, -282)
const LH_COTTAGE := Vector3(-138, 0, -262)
const CD_POST := Vector3(-34, 0, 142)
const DINER := Vector3(-78, 0, 108)
const GATE_Y := 26.0

## Roads: {pts: [Vector2(x,z)...], w: width, kind: "street"|"road"|"path", walk: sidewalks}
const ROADS := [
	{"name": "gull_lane", "pts": [Vector2(-92, 0), Vector2(-60, 0), Vector2(0, 0), Vector2(60, 0), Vector2(74, -2)], "w": 7.0, "kind": "street", "walk": true},
	{"name": "bluff_road", "pts": [Vector2(74, -2), Vector2(96, -14), Vector2(114, -36), Vector2(124, -62), Vector2(140, -86), Vector2(160, -95), Vector2(176, -95)], "w": 6.5, "kind": "road", "walk": false},
	{"name": "main_street", "pts": [Vector2(-22, 0), Vector2(-24, 40), Vector2(-36, 85), Vector2(-50, 112)], "w": 7.0, "kind": "street", "walk": true},
	{"name": "coast_road", "pts": [Vector2(-60, 140), Vector2(-86, 120), Vector2(-92, 60), Vector2(-92, 0), Vector2(-94, -60), Vector2(-104, -130), Vector2(-118, -200), Vector2(-130, -245), Vector2(-138, -258)], "w": 6.0, "kind": "road", "walk": false},
	{"name": "lh_path", "pts": [Vector2(-138, -258), Vector2(-150, -272), Vector2(-156, -278)], "w": 3.0, "kind": "path", "walk": false},
]

## Flat building pads: centre (x,z), size (x,z), height offset added to the natural height (0 = auto)
const PADS := [
	{"c": Vector2(0, -17), "s": Vector2(26, 22)},
	{"c": Vector2(-50, -16), "s": Vector2(18, 18)}, {"c": Vector2(-26, -16), "s": Vector2(18, 18)},
	{"c": Vector2(26, -16), "s": Vector2(18, 18)}, {"c": Vector2(50, -16), "s": Vector2(18, 18)},
	{"c": Vector2(-50, 16), "s": Vector2(18, 18)}, {"c": Vector2(6, 16), "s": Vector2(18, 18)},
	{"c": Vector2(30, 16), "s": Vector2(18, 18)}, {"c": Vector2(54, 16), "s": Vector2(18, 18)},
	{"c": Vector2(-55, 128), "s": Vector2(64, 46)},
	{"c": Vector2(164.5, -95), "s": Vector2(28, 16), "h": 26.0, "blend": 1.5},
	{"c": Vector2(-144, -268), "s": Vector2(40, 34)},
]

static var _road_h_cache := {}


static func shore_x(z: float) -> float:
	var s := -112.0 + 10.0 * sin(z * 0.011 + 0.5) + 6.0 * sin(z * 0.031)
	s -= 62.0 * exp(-pow(z + 278.0, 2.0) / (48.0 * 48.0))
	return s


static func _noise(x: float, z: float) -> float:
	return (sin(x * 0.043 + sin(z * 0.021) * 2.0) * 0.5 + sin(z * 0.037 + x * 0.013) * 0.35
		+ sin((x + z) * 0.11) * 0.12 + sin(x * 0.19 - z * 0.23) * 0.06)


## Natural height without roads/pads.
static func natural_h(x: float, z: float) -> float:
	var d := x - shore_x(z)
	var h: float
	if d < 0.0:
		h = maxf(d * 0.16, -14.0)
	else:
		h = minf(d * 0.11, 3.0) + smoothstep(30.0, 75.0, d) * 2.2
	h += 21.0 * smoothstep(92.0, 140.0, x)
	h += 16.0 * exp(-(pow(x - 215.0, 2.0) + pow(z + 95.0, 2.0)) / (55.0 * 55.0))
	var lh := exp(-(pow(x - LIGHTHOUSE.x, 2.0) + pow(z - LIGHTHOUSE.z, 2.0)) / (75.0 * 75.0))
	h += 9.5 * lh * smoothstep(-6.0, 10.0, d)
	# outskirts: rolling hills toward the map edges (not the sea)
	var edge := maxf(smoothstep(200.0, 330.0, absf(z + 40.0)), smoothstep(230.0, 320.0, x))
	h += edge * 22.0 * smoothstep(10.0, 60.0, d)
	var town := 1.0 - smoothstep(60.0, 160.0, Vector2(x + 20.0, z - 40.0).length())
	h += _noise(x, z) * lerpf(2.8, 0.7, town) * smoothstep(0.0, 25.0, d)
	return h


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> Array:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var q := a + ab * t
	return [p.distance_to(q), q]


## Height of the road surface at a point on/near a road (smooth, no noise).
static func road_center_h(q: Vector2) -> float:
	var k := Vector2i(roundi(q.x * 2.0), roundi(q.y * 2.0))
	if _road_h_cache.has(k):
		return _road_h_cache[k]
	# average natural height around q to smooth bumps
	var s := 0.0
	for o in [Vector2(0, 0), Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
		s += natural_h(q.x + o.x, q.y + o.y)
	var h := s / 5.0
	h = maxf(h, 2.2)
	var pd := pad_at(q.x, q.y)
	if not pd.is_empty():
		h = lerpf(pd.h, h, smoothstep(0.0, 8.0, pd.d))
	_road_h_cache[k] = h
	return h


## Nearest road info: {dist, h, road}
static func nearest_road(x: float, z: float) -> Dictionary:
	var p := Vector2(x, z)
	var best := {"dist": 1e9, "h": 0.0, "road": {}}
	for r in ROADS:
		var pts: Array = r.pts
		for i in pts.size() - 1:
			var res := _seg_dist(p, pts[i], pts[i + 1])
			if res[0] < best.dist:
				best = {"dist": res[0], "q": res[1], "road": r}
	if best.has("q"):
		best.h = road_center_h(best.q)
	return best


static func pad_at(x: float, z: float) -> Dictionary:
	for p in PADS:
		var c: Vector2 = p.c
		var s: Vector2 = p.s
		var dx := absf(x - c.x) - s.x * 0.5
		var dz := absf(z - c.y) - s.y * 0.5
		var d := maxf(dx, dz)
		var bl: float = p.get("blend", 8.0)
		if d < bl:
			return {"d": d * 8.0 / bl, "h": pad_h(p)}
	return {}


static var _pad_h_cache := {}


static func pad_h(p: Dictionary) -> float:
	var c: Vector2 = p.c
	if p.has("h"):
		return p.h
	if _pad_h_cache.has(c):
		return _pad_h_cache[c]
	var s := 0.0
	for o in [Vector2(0, 0), Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
		s += natural_h(c.x + o.x, c.y + o.y)
	var h := maxf(s / 5.0, 3.0)
	_pad_h_cache[c] = h
	return h


# ---------------------------------------------------------------- cached grid (height + road distance)
const CACHE_PATH := "res://data/terrain_cache.bin"
static var _grid_h := PackedFloat32Array()
static var _grid_r := PackedFloat32Array()
static var _gnx := 0
static var _gnz := 0


static func _layout_key() -> int:
	return hash(str(ROADS) + str(PADS) + "v4")


## Loads (or builds and saves) the height + road-distance grid. Call once before building the world.
static func ensure_cache() -> void:
	if not _grid_h.is_empty():
		return
	_gnx = int((MAX_X - MIN_X) / CELL) + 1
	_gnz = int((MAX_Z - MIN_Z) / CELL) + 1
	if FileAccess.file_exists(CACHE_PATH):
		var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
		if f.get_64() == _layout_key():
			_grid_h = f.get_var()
			_grid_r = f.get_var()
			if _grid_h.size() == _gnx * _gnz:
				return
	_grid_h.resize(_gnx * _gnz)
	_grid_r.resize(_gnx * _gnz)
	for j in _gnz:
		var z := MIN_Z + j * CELL
		for i in _gnx:
			var x := MIN_X + i * CELL
			_grid_h[j * _gnx + i] = height_exact(x, z)
			var nr := nearest_road(x, z)
			var hw: float = nr.road.get("w", 6.0) * 0.5 + (2.6 if nr.road.get("walk", false) else 0.7)
			_grid_r[j * _gnx + i] = nr.dist - hw
	var w := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if w:
		w.store_64(_layout_key())
		w.store_var(_grid_h)
		w.store_var(_grid_r)


static func _bilerp(arr: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x - MIN_X) / CELL, 0.0, _gnx - 1.001)
	var fz := clampf((z - MIN_Z) / CELL, 0.0, _gnz - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := arr[j * _gnx + i]
	var b := arr[j * _gnx + i + 1]
	var c := arr[(j + 1) * _gnx + i]
	var d := arr[(j + 1) * _gnx + i + 1]
	if tx >= tz:
		return a + (b - a) * tx + (d - b) * tz
	return a + (d - c) * tx + (c - a) * tz


## Signed distance to the nearest road edge (negative = on the road/sidewalk). Fast (cached grid).
static func road_edge_dist(x: float, z: float) -> float:
	if _grid_r.is_empty():
		var nr := nearest_road(x, z)
		return nr.dist - (nr.road.get("w", 6.0) * 0.5 + (2.6 if nr.road.get("walk", false) else 0.7))
	return _bilerp(_grid_r, x, z)


## Terrain height (fast, from the cached grid when available; matches the terrain mesh triangulation).
static func height(x: float, z: float) -> float:
	if not _grid_h.is_empty():
		return _bilerp(_grid_h, x, z)
	return height_exact(x, z)


static func grid_heights() -> PackedFloat32Array:
	ensure_cache()
	return _grid_h


## Exact terrain height (slow: evaluates roads and pads).
static func height_exact(x: float, z: float) -> float:
	var h := natural_h(x, z)
	var pd := pad_at(x, z)
	if not pd.is_empty():
		h = lerpf(pd.h, h, smoothstep(0.0, 8.0, pd.d))
	var r := nearest_road(x, z)
	var hw: float = r.road.get("w", 6.0) * 0.5 + (2.5 if r.road.get("walk", false) else 0.8)
	# (the bluff road ends at the shelter portal: its rounded end must not dish the hill behind the portal face, or
	# the terrain mesh comes up through the shelter's entry hall floor)
	if r.dist < hw + 9.0 and not (x > SHELTER_PORTAL.x + 0.5 and absf(z - SHELTER_PORTAL.z) < 24.0):
		h = lerpf(r.h - 0.08, h, smoothstep(hw, hw + 9.0, r.dist))
	return h


static func ground(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)
