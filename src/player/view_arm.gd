extends Skeleton3D
## One first-person arm for the weapon viewmodels (driven by weapons.gd): a skinned hand with jointed
## fingers and thumb, wrist, forearm and a rolled-up cardigan sleeve, built in code as one mesh with
## two surfaces (skin, knit) and ~2.6k triangles.
##
## The node itself is the wrist. weapons.gd parents it to the gun rig (inside the depth-squashed Weapons
## node), places it with `transform`, curls the fingers with apply_pose() and swings the forearm toward
## an elbow point below the screen with aim_forearm(), so the arm always leaves through the bottom edge.
##
## Hand space (right hand): wrist at the origin, fingers along -Z, back of the hand +Y, thumb on -X.
## A left arm is the mirror image (thumb on +X). Pose angles are always written as for a right hand.

const B_HAND := 0
const B_FORE := 1
const B_FINGER := 2  ## index, middle, ring, little: 3 bones each (proximal, middle, distal)
const B_THUMB := 14  ## metacarpal, proximal, distal
const BONES := 17
## apply_pose() layout, degrees: 4 x [spread, mcp, pip, dip] then thumb [cmc_flex, cmc_swing, cmc_roll, mcp, ip].
## Positive spread swings a finger toward the thumb; positive flex curls toward the palm.
const POSE_SIZE := 21
const MAX_BEND := 1.35  ## radians the wrist may bend between hand and forearm
const SIZE := 0.9  ## overall scale of the hand and arm (the tables below are a large adult hand)

## knuckle (MCP) position, segment lengths (proximal, middle, distal), base radius
const FINGERS := [
	[Vector3(-0.0245, 0.003, -0.086), Vector3(0.040, 0.025, 0.020), 0.0089],
	[Vector3(-0.0065, 0.004, -0.090), Vector3(0.044, 0.028, 0.021), 0.0093],
	[Vector3(0.0115, 0.003, -0.086), Vector3(0.041, 0.026, 0.020), 0.0087],
	[Vector3(0.0275, 0.000, -0.078), Vector3(0.032, 0.020, 0.018), 0.0076],
]
const THUMB_BASE := Vector3(-0.017, -0.010, -0.018)
const THUMB_DIR := Vector3(-0.55, -0.30, -0.78)
const THUMB_NAIL := Vector3(-0.75, 0.62, 0.0)
const THUMB_LEN := Vector3(0.048, 0.034, 0.029)
const THUMB_R := 0.0104

## Palm, wrist and forearm cross-sections from the elbow end forward: z, half-width,
## half-height on the back of the hand, half-height on the palm side, squareness exponent.
const BODY := [
	[0.44, 0.036, 0.030, 0.030, 2.0],
	[0.30, 0.037, 0.031, 0.031, 2.0],
	[0.20, 0.035, 0.029, 0.029, 2.0],
	[0.13, 0.032, 0.025, 0.026, 2.0],
	[0.08, 0.029, 0.021, 0.022, 2.1],
	[0.045, 0.027, 0.0185, 0.019, 2.2],
	[0.018, 0.0285, 0.0170, 0.0170, 2.4],
	[-0.005, 0.0325, 0.0160, 0.0175, 2.6],
	[-0.030, 0.0375, 0.0155, 0.0170, 2.8],
	[-0.055, 0.0405, 0.0150, 0.0155, 3.0],
	[-0.072, 0.0415, 0.0145, 0.0135, 3.0],
	[-0.084, 0.0405, 0.0135, 0.0110, 2.8],
	[-0.092, 0.0365, 0.0105, 0.0080, 2.5],
	[-0.097, 0.0280, 0.0065, 0.0050, 2.2],
	[-0.0995, 0.0150, 0.0030, 0.0025, 2.0],
]
## Rolled cardigan sleeve: z, extra thickness over the forearm.
const SLEEVE := [
	[0.098, -0.001], [0.102, 0.006], [0.108, 0.012], [0.118, 0.016], [0.130, 0.0155], [0.139, 0.011],
	[0.145, 0.0105], [0.152, 0.015], [0.164, 0.0165], [0.174, 0.012], [0.181, 0.0105], [0.190, 0.013],
	[0.215, 0.015], [0.26, 0.016], [0.33, 0.018], [0.44, 0.018],
]

const SKIN := Color(0.93, 0.93, 0.93)
const SKIN_PALM := Color(1.0, 0.94, 0.92)
const SKIN_KNUCKLE := Color(0.95, 0.76, 0.72)
const SKIN_NAIL := Color(1.0, 0.92, 0.9)

var left := false


class Loft:
	var sides := 12
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var centers := PackedVector3Array()
	var ba := PackedInt32Array()
	var bb := PackedInt32Array()
	var w := PackedFloat32Array()
	var cap_start := false
	var tip := false
	var tip_pos := Vector3.ZERO
	var tip_col := Color.WHITE

	func _init(s: int) -> void:
		sides = s

	func rings() -> int:
		return centers.size()


func build(is_left: bool, skin_mat: Material, knit_mat: Material, layer := 1) -> void:
	left = is_left
	# ---- bones (rest written for a right hand, mirrored for the left)
	var rest: Array[Transform3D] = []
	var parent := PackedInt32Array()
	rest.resize(BONES)
	parent.resize(BONES)
	rest[B_HAND] = Transform3D.IDENTITY
	parent[B_HAND] = -1
	rest[B_FORE] = Transform3D.IDENTITY
	parent[B_FORE] = B_HAND
	for f in 4:
		var d: Array = FINGERS[f]
		var ln: Vector3 = d[1]
		var b := B_FINGER + f * 3
		rest[b] = Transform3D(Basis.IDENTITY, d[0])
		parent[b] = B_HAND
		rest[b + 1] = Transform3D(Basis.IDENTITY, Vector3(0, 0, -ln.x))
		parent[b + 1] = b
		rest[b + 2] = Transform3D(Basis.IDENTITY, Vector3(0, 0, -ln.y))
		parent[b + 2] = b + 1
	var tz := -THUMB_DIR.normalized()
	var ty := (THUMB_NAIL - tz * THUMB_NAIL.dot(tz)).normalized()
	rest[B_THUMB] = Transform3D(Basis(ty.cross(tz), ty, tz), THUMB_BASE)
	parent[B_THUMB] = B_HAND
	rest[B_THUMB + 1] = Transform3D(Basis.IDENTITY, Vector3(0, 0, -THUMB_LEN.x))
	parent[B_THUMB + 1] = B_THUMB
	rest[B_THUMB + 2] = Transform3D(Basis.IDENTITY, Vector3(0, 0, -THUMB_LEN.y))
	parent[B_THUMB + 2] = B_THUMB + 1
	var glob: Array[Transform3D] = []
	glob.resize(BONES)
	for i in BONES:
		glob[i] = rest[i] if parent[i] < 0 else glob[parent[i]] * rest[i]
		add_bone("b%d" % i)
	for i in BONES:
		set_bone_parent(i, parent[i])
		var r := rest[i]
		r.origin *= SIZE
		set_bone_rest(i, _mirror_xf(r) if left else r)
	reset_bone_poses()

	# ---- skin surface: palm/wrist/forearm, four fingers, thumb
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vc := 0
	vc = _emit(st, _body_loft(), vc)
	for f in 4:
		var d: Array = FINGERS[f]
		var b := B_FINGER + f * 3
		var bones := PackedInt32Array([B_HAND, b, b + 1, b + 2])
		vc = _emit(st, _digit_loft(glob[b], d[1], d[2], bones, -0.013, false), vc)
	vc = _emit(st, _digit_loft(glob[B_THUMB], THUMB_LEN, THUMB_R, PackedInt32Array([B_HAND, B_THUMB, B_THUMB + 1, B_THUMB + 2]), -0.006, true), vc)
	var mesh := st.commit()
	# ---- knit surface: the rolled sleeve
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_emit(st2, _sleeve_loft(), 0)
	st2.commit(mesh)
	mesh.surface_set_material(0, skin_mat)
	mesh.surface_set_material(1, knit_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.skin = create_skin_from_rest_transforms()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.extra_cull_margin = 0.5
	mi.layers = layer
	add_child(mi)
	mi.skeleton = NodePath("..")


## Sets every finger joint from a POSE_SIZE array (degrees, right-hand convention).
func apply_pose(p: PackedFloat32Array) -> void:
	var m := -1.0 if left else 1.0
	for f in 4:
		var o := f * 4
		var b := B_FINGER + f * 3
		set_bone_pose_rotation(b, Quaternion.from_euler(Vector3(-deg_to_rad(p[o + 1]), deg_to_rad(p[o]) * m, 0.0)))
		set_bone_pose_rotation(b + 1, Quaternion(Vector3.RIGHT, -deg_to_rad(p[o + 2])))
		set_bone_pose_rotation(b + 2, Quaternion(Vector3.RIGHT, -deg_to_rad(p[o + 3])))
	set_bone_pose_rotation(B_THUMB, Quaternion.from_euler(Vector3(-deg_to_rad(p[16]), deg_to_rad(p[17]) * m, deg_to_rad(p[18]) * m)))
	set_bone_pose_rotation(B_THUMB + 1, Quaternion(Vector3.RIGHT, -deg_to_rad(p[19])))
	set_bone_pose_rotation(B_THUMB + 2, Quaternion(Vector3.RIGHT, -deg_to_rad(p[20])))


## Swings the forearm (it rests along +Z from the wrist) toward `target`, given in this node's space.
func aim_forearm(target: Vector3) -> void:
	if target.length_squared() < 1e-8:
		return
	var d := target.normalized()
	var ang := acos(clampf(d.z, -1.0, 1.0))
	if ang > MAX_BEND:
		d = Vector3.BACK.slerp(d, MAX_BEND / ang)
	set_bone_pose_rotation(B_FORE, Quaternion(Vector3.BACK, d))


# ------------------------------------------------------------------ geometry

static func _mirror_xf(t: Transform3D) -> Transform3D:
	var b := t.basis
	return Transform3D(Basis(Vector3(b.x.x, -b.x.y, -b.x.z), Vector3(-b.y.x, b.y.y, b.y.z), Vector3(-b.z.x, b.z.y, b.z.z)), Vector3(-t.origin.x, t.origin.y, t.origin.z))


static func _sq(c: float, e: float) -> float:
	return signf(c) * pow(absf(c), 2.0 / e)


static func _body_ab(z: float) -> Vector3:
	# forearm half-width / half-heights at z (for the sleeve)
	for i in BODY.size() - 1:
		var a: Array = BODY[i]
		var b: Array = BODY[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			var t := (z - float(a[0])) / (float(b[0]) - float(a[0]))
			return Vector3(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t))
	var l: Array = BODY[0]
	return Vector3(l[1], l[2], l[3])


func _body_loft() -> Loft:
	var lf := Loft.new(16)
	lf.cap_start = true
	for r in BODY:
		var z: float = r[0]
		var ring_c := Vector3(0, 0, z)
		var wf := smoothstep(-0.006, 0.042, z)  # forearm weight
		for s in lf.sides:
			var th := TAU * s / lf.sides
			var c := cos(th)
			var sn := sin(th)
			var x: float = _sq(c, r[4]) * float(r[1])
			var y: float = _sq(sn, r[4]) * (float(r[2]) if sn > 0.0 else float(r[3]))
			var zz := z + 0.25 * x * smoothstep(-0.035, -0.075, z)  # knuckle line slopes back toward the little finger
			# a little hollow in the palm, fuller heel
			if sn < 0.0 and z < -0.02:
				y += 0.0025 * sn * sn * (1.0 - absf(c))
			lf.pos.append(Vector3(x, y, zz))
			var dors := maxf(sn, 0.0)
			var colr := SKIN.lerp(SKIN_PALM, maxf(-sn, 0.0) * smoothstep(0.03, -0.01, z))
			colr = colr.lerp(SKIN_KNUCKLE, dors * smoothstep(-0.075, -0.092, z) * 0.55 * (0.6 + 0.4 * absf(sin(x * 170.0))))
			# baked occlusion: finger webs, the wrist crease, and the shadow inside the sleeve
			var occ := 1.0
			for g in [-0.0155, 0.0025, 0.0195]:
				occ -= 0.22 * exp(-pow((x - float(g)) / 0.0045, 2.0)) * smoothstep(-0.078, -0.094, z)
			occ -= 0.1 * maxf(-sn, 0.0) * exp(-pow((z - 0.016) / 0.006, 2.0))
			occ *= lerpf(1.0, 0.62, smoothstep(0.075, 0.1, z))
			lf.col.append(Color(colr.r * occ, colr.g * occ, colr.b * occ))
		lf.centers.append(ring_c)
		lf.ba.append(B_HAND)
		lf.bb.append(B_FORE)
		lf.w.append(wf)
	return lf


## A finger or the thumb: one tube from inside the palm to a rounded tip, skinned across three joints.
## `xf` is the digit's first bone in hand space; `bones` = [hand, proximal, middle, distal].
func _digit_loft(xf: Transform3D, ln: Vector3, r0: float, bones: PackedInt32Array, s0: float, thumb: bool) -> Loft:
	var lf := Loft.new(10)
	var j1 := ln.x
	var j2 := ln.x + ln.y
	var lt := ln.x + ln.y + ln.z
	var rt := r0 * (0.86 if thumb else 0.80)
	var joints := PackedFloat32Array([0.0, j1, j2])
	var half := PackedFloat32Array([0.014 if thumb else 0.0065, 0.0055, 0.0045])
	var bulge := PackedFloat32Array([0.0 if thumb else 0.16, 0.13, 0.08])
	var stations := PackedFloat32Array([s0, s0 * 0.45, 0.005, 0.3 * j1, 0.62 * j1, j1 - 0.005, j1, j1 + 0.005,
		j1 + 0.5 * ln.y, j2 - 0.004, j2, j2 + 0.004, j2 + 0.38 * ln.z])
	for u in [0.3, 0.58, 0.8, 0.94]:
		stations.append(lt - rt * (1.0 - float(u)))
	for s in stations:
		# radius and cross-section
		var r := r0 * (1.04 if s < 0.0 else 1.0 - 0.2 * clampf(s / lt, 0.0, 1.0))
		if thumb and s < j1:
			r = r0 * lerpf(1.3, 1.0, clampf(s / j1, 0.0, 1.0))  # thenar mound
		var tipk := 1.0
		if s > lt - rt:
			var u := (s - (lt - rt)) / rt
			tipk = sqrt(maxf(1.0 - u * u, 0.0))
		var kj := 0.0
		for k in 3:
			var q := (s - joints[k]) / 0.0045
			kj = maxf(kj, exp(-q * q) * bulge[k] / 0.16)
		var seg_frac := 0.0
		if s > 0.0 and s < j1:
			seg_frac = s / j1
		elif s >= j1 and s < j2:
			seg_frac = (s - j1) / ln.y
		elif s >= j2:
			seg_frac = clampf((s - j2) / ln.z, 0.0, 1.0)
		var pad := 0.08 * sin(PI * seg_frac)
		var a := r * 1.06 * tipk
		var up := r * (0.9 + 0.16 * kj) * tipk
		var dn := r * (0.97 + pad - 0.06 * kj) * tipk
		var nailz := 0.0
		if s > j2 + 0.3 * ln.z:
			up *= 0.9
			nailz = smoothstep(j2 + 0.3 * ln.z, j2 + 0.45 * ln.z, s) * (1.0 - smoothstep(lt - 0.45 * rt, lt - 0.1 * rt, s))
		# bone weights: blend across the nearest joint
		var bi := 0
		var bj := 0
		var wt := 0.0
		for k in 3:
			if s >= joints[k] + half[k]:
				bi = k + 1
				bj = k + 1
		for k in 3:
			if absf(s - joints[k]) < half[k]:
				bi = k
				bj = k + 1
				wt = smoothstep(-half[k], half[k], s - joints[k])
		for i in lf.sides:
			var th := TAU * i / lf.sides
			var c := cos(th)
			var sn := sin(th)
			var x := _sq(c, 2.3) * a
			var y := _sq(sn, 2.3) * (up if sn > 0.0 else dn)
			lf.pos.append(xf * Vector3(x, y, -s))
			var dors := maxf(sn, 0.0)
			var colr := SKIN.lerp(SKIN_PALM, maxf(-sn, 0.0) * 0.8)
			colr = colr.lerp(SKIN_KNUCKLE, clampf(kj * dors * 0.8 + smoothstep(lt - 1.6 * rt, lt, s) * 0.45, 0.0, 1.0))
			colr = colr.lerp(SKIN_NAIL, nailz * smoothstep(0.55, 0.85, dors))
			# baked occlusion: palm-side joint creases and the sides of the finger roots
			var occ := 1.0 - 0.14 * kj * maxf(-sn, 0.0) - 0.2 * absf(c) * (1.0 - smoothstep(-0.004, 0.012, s))
			lf.col.append(Color(colr.r * occ, colr.g * occ, colr.b * occ))
		lf.centers.append(xf * Vector3(0, 0, -s))
		lf.ba.append(bones[bi])
		lf.bb.append(bones[bj])
		lf.w.append(wt)
	lf.tip = true
	lf.tip_pos = xf * Vector3(0, -rt * 0.05, -lt)
	lf.tip_col = SKIN_KNUCKLE.lerp(SKIN, 0.5)
	return lf


func _sleeve_loft() -> Loft:
	var lf := Loft.new(16)
	lf.tip = true
	for r in SLEEVE:
		var z: float = r[0]
		var add: float = r[1]
		var ab := _body_ab(z)
		for s in lf.sides:
			var th := TAU * s / lf.sides
			var c := cos(th)
			var sn := sin(th)
			var wob := 1.0 + 0.16 * sin(3.0 * th + z * 47.0) + (0.12 * sin(5.0 * th + z * 90.0) if z > 0.19 else 0.0)
			var e := maxf(add, 0.0) * wob + minf(add, 0.0)
			var x := c * (ab.x + e)
			var y := sn * ((ab.y if sn > 0.0 else ab.z) + e)
			lf.pos.append(Vector3(x, y, z))
			lf.col.append(Color.WHITE)
		lf.centers.append(Vector3(0, 0, z))
		lf.ba.append(B_FORE)
		lf.bb.append(B_FORE)
		lf.w.append(0.0)
	var last: Array = SLEEVE[SLEEVE.size() - 1]
	lf.tip_pos = Vector3(0, 0, float(last[0]) + 0.01)
	return lf


## Writes a loft (rings of `sides` vertices) into `st` with smooth normals, colours and skin weights.
func _emit(st: SurfaceTool, lf: Loft, base: int) -> int:
	var n := lf.rings()
	var S := lf.sides
	var mx := -1.0 if left else 1.0
	var pos := lf.pos
	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	for i in n:
		for s in S:
			var around := pos[i * S + (s + 1) % S] - pos[i * S + (s - 1 + S) % S]
			var along := pos[mini(i + 1, n - 1) * S + s] - pos[maxi(i - 1, 0) * S + s]
			var nn := around.cross(along)
			if nn.length_squared() < 1e-14:
				nn = pos[i * S + s] - lf.centers[i]
			nn = nn.normalized()
			if nn.dot(pos[i * S + s] - lf.centers[i]) < 0.0:
				nn = -nn
			nrm[i * S + s] = nn
	var finals := PackedVector3Array()
	finals.resize(pos.size())
	for i in n:
		var bones := PackedInt32Array([lf.ba[i], lf.bb[i], 0, 0])
		var wts := PackedFloat32Array([1.0 - lf.w[i], lf.w[i], 0.0, 0.0])
		for s in S:
			var p := pos[i * S + s]
			var q := nrm[i * S + s]
			p.x *= mx
			p *= SIZE
			q.x *= mx
			finals[i * S + s] = p
			st.set_color(lf.col[i * S + s])
			st.set_normal(q)
			st.set_uv(Vector2(float(s) / S, float(i) / maxf(n - 1, 1)))
			st.set_bones(bones)
			st.set_weights(wts)
			st.add_vertex(p)
	var count := pos.size()
	for i in n - 1:
		for s in S:
			var a := i * S + s
			var b := i * S + (s + 1) % S
			var c := (i + 1) * S + s
			var d := (i + 1) * S + (s + 1) % S
			_tri(st, finals, nrm, base, a, c, b, mx)
			_tri(st, finals, nrm, base, b, c, d, mx)
	if lf.tip:
		var tp := lf.tip_pos * SIZE
		tp.x *= mx
		var lastc := lf.centers[n - 1]
		var tn := (lf.tip_pos - lastc).normalized()
		tn.x *= mx
		var bones2 := PackedInt32Array([lf.bb[n - 1] if lf.w[n - 1] > 0.5 else lf.ba[n - 1], 0, 0, 0])
		st.set_color(lf.tip_col)
		st.set_normal(tn)
		st.set_uv(Vector2(0.5, 1.0))
		st.set_bones(bones2)
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.add_vertex(tp)
		finals.append(tp)
		nrm.append(tn * Vector3(mx, 1, 1))
		var ti := count
		for s in S:
			_tri(st, finals, nrm, base, (n - 1) * S + s, (n - 1) * S + (s + 1) % S, ti, mx)
		count += 1
	if lf.cap_start:
		var cp := lf.centers[0] * SIZE
		var cn := (lf.centers[0] - lf.centers[1]).normalized()
		cp.x *= mx
		cn.x *= mx
		st.set_color(lf.col[0])
		st.set_normal(cn)
		st.set_uv(Vector2(0.5, 0.0))
		st.set_bones(PackedInt32Array([lf.bb[0] if lf.w[0] > 0.5 else lf.ba[0], 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.add_vertex(cp)
		finals.append(cp)
		nrm.append(cn * Vector3(mx, 1, 1))
		var ci := count
		for s in S:
			_tri(st, finals, nrm, base, s, (s + 1) % S, ci, mx)
		count += 1
	return base + count


## Adds one indexed triangle, wound so its face agrees with the (unmirrored-space) vertex normals.
static func _tri(st: SurfaceTool, p: PackedVector3Array, nrm: PackedVector3Array, base: int, a: int, b: int, c: int, mx: float) -> void:
	var fn := (p[c] - p[a]).cross(p[b] - p[a])
	var nsum := nrm[a] + nrm[b] + nrm[c]
	nsum.x *= mx
	if fn.dot(nsum) < 0.0:
		var t := b
		b = c
		c = t
	st.add_index(base + a)
	st.add_index(base + b)
	st.add_index(base + c)
