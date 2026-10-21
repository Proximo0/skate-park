class_name AnimeHead
extends RefCounted
## Head of the anime surf-skater girl, built in metres at the Head joint (face toward -Z, chin about 0.035 below the
## joint, crown 0.19 above: 0.225 tall, 0.15 wide, 0.19 deep, so a 1.62 m body is 7.2 heads tall).
## Face: one smooth loft with a soft V jaw, small chin and a tiny nose bump. Eyes, brows, mouth, blush and nose tick
## are thin decals wrapped onto the face surface (sclera, layered iris, pupil, two highlights, thick upper lash with
## an outer flick, thin lower lash, lid crease). Hair: a scalp cap, 10 tapered bangs ending at the brows, 4 side
## locks framing the face, 7 strands gathered to a high ponytail and a 4-lock ponytail with a coral tie, plus a flower
## clip. Hair that should sway hangs from identity "HairSway_*" pivots placed at each lock's root:
## HairSway_SideL, HairSway_SideR and the chain HairSway_Ponytail > HairSway_Ponytail2 > HairSway_Ponytail3.
## Static builders, called by PlaceholderSkater with the Head joint and the palette materials.

const CHIN_Y: float = -0.035
const CROWN_Y: float = 0.19
const EYE_Y: float = 0.062
const EYE_X: float = 0.038
const EYE_W: float = 0.038
const EYE_H: float = 0.0355
const BROW_Y: float = EYE_Y + 0.029
const NOSE_Y: float = 0.031
const MOUTH_Y: float = 0.005
## Head centre, used for radial hair offsets.
const CENTER: Vector3 = Vector3(0.0, 0.08, 0.008)
const PONY_ROOT_Y: float = 0.163
const CAP_T: float = 0.0105

## Head-only colours (spec palette), added to the material set when the palette has no such key.
const COLORS: Dictionary = {
	"head_sclera": Color("f4f1f2"),
	"head_iris_rim": Color("1b3b7a"),
	"head_iris_mid": Color("3a8fd8"),
	"head_iris_glow": Color("9fe0ff"),
	"head_pupil": Color("10203a"),
	"head_shine": Color("ffffff"),
	"head_lash": Color("2a1a1c"),
	"head_lash_low": Color("8a5a48"),
	"head_brow": Color("b8893a"),
	"head_lip": Color("d66f78"),
	"head_lip_light": Color("e58c8c"),
	"hair_base": Color("f5d36b"),
	"hair_mid": Color("e8b94a"),
	"hair_shadow": Color("c88f2e"),
	"hair_deep": Color("9a6a1e"),
	"hair_shine": Color("fff3b0"),
}

static var _w: PackedVector2Array = PackedVector2Array()
static var _zf: PackedVector2Array = PackedVector2Array()
static var _zb: PackedVector2Array = PackedVector2Array()
static var _nf: PackedVector2Array = PackedVector2Array()
static var _hairline: PackedVector2Array = PackedVector2Array()


static func build(head: Node3D, mats: Dictionary) -> void:
	_add_materials(mats)
	var m: Node3D = SkaterParts.joint(head, "HeadModel", Vector3.ZERO)
	SkaterParts.part(m, "HeadMesh", _head_mesh(), Vector3.ZERO, mats, "skin")
	for s: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = SkaterParts.part(m, ("Left" if s < 0.0 else "Right") + "EarMesh", SkaterParts.sphere_small(0.012),
				Vector3(s * 0.071, 0.05, 0.014), mats, "skin")
		ear.scale = Vector3(0.5, 1.3, 0.9)
		ear.rotation.y = s * 0.3
	_build_face(m, mats)
	_build_hair(m, mats)
	_build_ponytail(m, mats)
	_build_flower(m, mats)


static func _add_materials(mats: Dictionary) -> void:
	var skin: Color = Color(1.0, 0.89, 0.83)
	if mats.has("skin"):
		skin = (mats["skin"] as StandardMaterial3D).albedo_color
	var derived: Dictionary = COLORS.duplicate()
	derived["head_blush"] = skin.lerp(Color("ffb3b0"), 0.45)
	derived["head_skin_shadow"] = skin.lerp(Color("d9a090"), 0.55)
	for key: String in derived:
		if not mats.has(key):
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = derived[key]
			mat.roughness = 0.7
			mats[key] = mat


# --- Face surface -------------------------------------------------------------------------------------------------

static func _ensure_profiles() -> void:
	if not _w.is_empty():
		return
	# y, half width, front z, back z, front superellipse exponent (higher = fuller, flatter face front).
	var rows: Array = [
		[-0.036, 0.0, -0.071, -0.071, 2.0],
		[-0.033, 0.012, -0.075, -0.06, 1.9],
		[-0.026, 0.023, -0.079, -0.044, 1.95],
		[-0.014, 0.035, -0.082, -0.02, 2.05],
		[0.0, 0.0465, -0.084, 0.008, 2.2],
		[0.018, 0.0585, -0.086, 0.042, 2.45],
		[0.038, 0.066, -0.087, 0.076, 2.7],
		[0.062, 0.0725, -0.088, 0.096, 2.9],
		[0.09, 0.075, -0.087, 0.105, 2.8],
		[0.12, 0.0745, -0.082, 0.105, 2.5],
		[0.15, 0.068, -0.068, 0.094, 2.2],
		[0.17, 0.054, -0.05, 0.074, 2.0],
		[0.182, 0.036, -0.032, 0.05, 2.0],
		[0.188, 0.019, -0.016, 0.03, 2.0],
		[0.19, 0.0, 0.006, 0.006, 2.0],
	]
	var pw: PackedVector2Array = PackedVector2Array()
	var pf: PackedVector2Array = PackedVector2Array()
	var pb: PackedVector2Array = PackedVector2Array()
	var pn: PackedVector2Array = PackedVector2Array()
	for r: Array in rows:
		pw.append(Vector2(float(r[1]), float(r[0])))
		pf.append(Vector2(float(r[2]), float(r[0])))
		pb.append(Vector2(float(r[3]), float(r[0])))
		pn.append(Vector2(float(r[4]), float(r[0])))
	_w = SkaterParts.smooth2d(pw, 3)
	_zf = SkaterParts.smooth2d(pf, 3)
	_zb = SkaterParts.smooth2d(pb, 3)
	_nf = SkaterParts.smooth2d(pn, 3)
	# Hairline height by angle from the front (degrees): forehead, temple, sideburn, over the ear, nape.
	_hairline = SkaterParts.smooth2d(PackedVector2Array([
		Vector2(0.14, 0.0), Vector2(0.132, 35.0), Vector2(0.112, 60.0), Vector2(0.072, 78.0), Vector2(0.074, 92.0),
		Vector2(0.045, 110.0), Vector2(0.006, 135.0), Vector2(-0.006, 180.0),
	]), 3)


## Point of the head surface at angle a (0 = front, -Z; positive toward +X) and height y.
static func head_point(a: float, y: float) -> Vector3:
	_ensure_profiles()
	var w: float = maxf(SkaterParts.profile_r(_w, y), 0.0)
	var zf: float = SkaterParts.profile_r(_zf, y)
	var zb: float = SkaterParts.profile_r(_zb, y)
	var s: float = sin(a)
	var c: float = cos(a)
	var front: bool = c >= 0.0
	var n: float = SkaterParts.profile_r(_nf, y) if front else 2.1
	var zm: float = lerpf(zf, zb, 0.45)
	var x: float = w * signf(s) * pow(absf(s), 2.0 / n)
	var z: float = zm + ((zf - zm) if front else (zb - zm)) * pow(absf(c), 2.0 / n)
	if front:
		z += _bump(x, y)
	return Vector3(x, y, z)


## Z of the face surface at (x, y) (negative, toward the nose).
static func face_z(x: float, y: float) -> float:
	_ensure_profiles()
	var w: float = maxf(SkaterParts.profile_r(_w, y), 0.001)
	var zf: float = SkaterParts.profile_r(_zf, y)
	var zb: float = SkaterParts.profile_r(_zb, y)
	var n: float = SkaterParts.profile_r(_nf, y)
	var zm: float = lerpf(zf, zb, 0.45)
	var s: float = pow(clampf(absf(x) / w, 0.0, 1.0), n * 0.5)
	var c: float = sqrt(maxf(1.0 - s * s, 0.0))
	return zm + (zf - zm) * pow(c, 2.0 / n) + _bump(x, y)


## Outward face normal at (x, y).
static func face_normal(x: float, y: float) -> Vector3:
	var h: float = 0.0008
	var fx: float = (face_z(x + h, y) - face_z(x - h, y)) / (2.0 * h)
	var fy: float = (face_z(x, y + h) - face_z(x, y - h)) / (2.0 * h)
	return Vector3(fx, fy, -1.0).normalized()


## Tiny nose and soft lip/chin relief, as a forward (-Z) offset on the face front.
static func _bump(x: float, y: float) -> float:
	var k: float = 0.0
	if y < NOSE_Y:
		k = smoothstep(NOSE_Y - 0.009, NOSE_Y, y)
	else:
		k = pow(clampf(1.0 - (y - NOSE_Y) / 0.038, 0.0, 1.0), 1.6)
	var nose: float = 0.0042 * exp(-pow(x / (0.0055 + 0.003 * k), 2.0)) * k
	var lip: float = 0.0012 * exp(-pow(x / 0.012, 2.0)) * exp(-pow((y - MOUTH_Y + 0.003) / 0.006, 2.0))
	var chin: float = 0.0015 * exp(-pow(x / 0.012, 2.0)) * exp(-pow((y + 0.026) / 0.007, 2.0))
	return -(nose + lip + chin)


static func _head_mesh() -> ArrayMesh:
	_ensure_profiles()
	var rows: Array = []
	var cols: int = 48
	for p: Vector2 in _w:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			ring.append(head_point(-PI + TAU * float(k) / float(cols), p.y))
		rows.append(ring)
	return _oriented_grid(rows, true, CENTER)


## Grid with smooth normals whose faces look away from `inside`.
static func _oriented_grid(rows: Array, closed: bool, inside: Vector3) -> ArrayMesh:
	var mid: int = rows.size() / 2
	var r0: PackedVector3Array = rows[mid]
	var r1: PackedVector3Array = rows[mid + 1]
	var k: int = r0.size() / 2
	var n: Vector3 = (r0[k + 1] - r0[k]).cross(r1[k] - r0[k])
	return SkaterParts.grid(rows, closed, n.dot(r0[k] - inside) > 0.0)


# --- Face decals --------------------------------------------------------------------------------------------------

## Mesh from rows of 2D face points (x, y), wrapped onto the face and lifted `lift` along its normal.
static func _face_mesh(rows2d: Array, closed: bool, lift: float) -> ArrayMesh:
	var rows: Array = []
	var nrows: Array = []
	for r: PackedVector2Array in rows2d:
		var pr: PackedVector3Array = PackedVector3Array()
		var nr: PackedVector3Array = PackedVector3Array()
		for q: Vector2 in r:
			var nn: Vector3 = face_normal(q.x, q.y)
			pr.append(Vector3(q.x, q.y, face_z(q.x, q.y)) + nn * lift)
			nr.append(nn)
		rows.append(pr)
		nrows.append(nr)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in rows.size() - 1:
		var a_row: PackedVector3Array = rows[i]
		var b_row: PackedVector3Array = rows[i + 1]
		var cols: int = a_row.size() if closed else a_row.size() - 1
		for k: int in cols:
			var k2: int = (k + 1) % a_row.size()
			_face_tri(st, [a_row[k], a_row[k2], b_row[k]], [nrows[i][k], nrows[i][k2], nrows[i + 1][k]])
			_face_tri(st, [a_row[k2], b_row[k2], b_row[k]], [nrows[i][k2], nrows[i + 1][k2], nrows[i + 1][k]])
	return st.commit()


static func _face_tri(st: SurfaceTool, p: Array, n: Array) -> void:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var c: Vector3 = p[2]
	var order: Array = [0, 1, 2]
	if (b - a).cross(c - a).dot(n[0] as Vector3) > 0.0:
		order = [0, 2, 1]
	for i: int in order:
		st.set_normal(n[i])
		st.add_vertex(p[i])


## Filled shape: fan rows from the centroid to the outline.
static func _fill_rows(outline: PackedVector2Array) -> Array:
	var c: Vector2 = Vector2.ZERO
	for q: Vector2 in outline:
		c += q
	c /= float(outline.size())
	var rows: Array = []
	for f: float in [0.0, 0.4, 0.75, 1.0]:
		var r: PackedVector2Array = PackedVector2Array()
		for q: Vector2 in outline:
			r.append(c + (q - c) * f)
		rows.append(r)
	return rows


## Strip rows (left edge, centre, right edge) along a 2D centre line with per-point half widths.
static func _strip_rows(center: PackedVector2Array, hw: PackedFloat32Array) -> Array:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var n: int = center.size()
	for i: int in n:
		var t: Vector2 = (center[mini(i + 1, n - 1)] - center[maxi(i - 1, 0)]).normalized()
		var perp: Vector2 = Vector2(-t.y, t.x)
		left.append(center[i] + perp * hw[i])
		right.append(center[i] - perp * hw[i])
	return [left, center, right]


static func _ellipse(c: Vector2, rx: float, ry: float, segs: int = 24) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in segs:
		var a: float = TAU * float(i) / float(segs)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## Eye opening, in eye-local u (-1 inner corner .. 1 outer corner): top and bottom lid heights.
static func _eye_top(u: float) -> float:
	var v: float = clampf(1.0 - u * u, 0.0, 1.0)
	return EYE_H * 0.5 * pow(v, 0.42) * (1.0 + 0.1 * u) - 0.0015 * maxf(-u, 0.0)


static func _eye_bot(u: float) -> float:
	var v: float = clampf(1.0 - u * u, 0.0, 1.0)
	return -EYE_H * 0.5 * pow(v, 0.75) * (0.86 - 0.08 * u)


static func _build_face(head: Node3D, mats: Dictionary) -> void:
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var ex: float = s * EYE_X
		var hx: float = EYE_W * 0.5
		# Eye coordinates: x = ex + s * u * hx (u = 1 is the outer corner).
		var sclera: PackedVector2Array = PackedVector2Array()
		var segs: int = 20
		for i: int in segs + 1:
			var u: float = -1.0 + 2.0 * float(i) / float(segs)
			sclera.append(Vector2(ex + s * u * hx, EYE_Y + _eye_top(u)))
		for i: int in range(segs - 1, 0, -1):
			var u: float = -1.0 + 2.0 * float(i) / float(segs)
			sclera.append(Vector2(ex + s * u * hx, EYE_Y + _eye_bot(u)))
		SkaterParts.part(head, "Eye" + side + "Mesh", _face_mesh(_fill_rows(sclera), true, 0.0004), Vector3.ZERO, mats,
				"head_sclera")
		# Iris: upright oval, its top tucked under the upper lid; darker rim, a lighter body set lower, a glow below
		# and the pupil.
		var ic: Vector2 = Vector2(ex + s * 0.0008, EYE_Y + 0.0012)
		var irx: float = EYE_W * 0.31
		var iry: float = EYE_H * 0.43
		var layers: Array = [
			["Iris", Vector2(0.0, 0.0), 1.0, 1.0, "head_iris_rim", 0.0008],
			["IrisMid", Vector2(0.0, -0.0022), 0.8, 0.8, "head_iris_mid", 0.0012],
			["IrisGlow", Vector2(0.0, -0.0062), 0.62, 0.38, "head_iris_glow", 0.0016],
			["Pupil", Vector2(0.0, 0.0012), 0.4, 0.46, "head_pupil", 0.002],
		]
		for ly: Array in layers:
			var c: Vector2 = ic + (ly[1] as Vector2)
			var shape: PackedVector2Array = _ellipse(c, irx * float(ly[2]), iry * float(ly[3]))
			SkaterParts.part(head, str(ly[0]) + side + "Mesh", _face_mesh(_fill_rows(_clip_to_eye(shape, ex, s)), true,
					float(ly[5])), Vector3.ZERO, mats, str(ly[4]))
		# Highlights on the same side in both eyes: a big one upper +X, a small one lower -X.
		SkaterParts.part(head, "EyeShine" + side + "Mesh", _face_mesh(_fill_rows(_ellipse(
				ic + Vector2(irx * 0.42, iry * 0.38), 0.0034, 0.0041, 16)), true, 0.0026), Vector3.ZERO, mats, "head_shine")
		SkaterParts.part(head, "EyeShineSmall" + side + "Mesh", _face_mesh(_fill_rows(_ellipse(
				ic + Vector2(-irx * 0.4, -iry * 0.5), 0.0016, 0.0016, 12)), true, 0.0026), Vector3.ZERO, mats, "head_shine")
		# Upper lash: thick dark arc along the top lid, thickest toward the outer corner, ending in a flick.
		var lash: PackedVector2Array = PackedVector2Array()
		var lash_w: PackedFloat32Array = PackedFloat32Array()
		for i: int in 17:
			var u: float = -1.03 + 1.96 * float(i) / 16.0
			var hw: float = lerpf(0.0006, 0.0025, smoothstep(-1.0, 0.6, u))
			lash.append(Vector2(ex + s * u * hx, EYE_Y + _eye_top(clampf(u, -1.0, 1.0)) + hw * 0.5))
			lash_w.append(hw)
		lash.append(Vector2(ex + s * (hx + 0.0026), EYE_Y + 0.0075))
		lash_w.append(0.0014)
		lash.append(Vector2(ex + s * (hx + 0.0062), EYE_Y + 0.0102))
		lash_w.append(0.0002)
		SkaterParts.part(head, "Lash" + side + "Mesh", _face_mesh(_strip_rows(lash, lash_w), false, 0.003), Vector3.ZERO,
				mats, "head_lash")
		# Lid crease, thin lower lash at the outer half.
		var crease: PackedVector2Array = PackedVector2Array()
		var crease_w: PackedFloat32Array = PackedFloat32Array()
		for i: int in 9:
			var u: float = -0.45 + 1.35 * float(i) / 8.0
			crease.append(Vector2(ex + s * u * hx, EYE_Y + _eye_top(clampf(u, -1.0, 0.98)) + 0.0052 - 0.001 * u))
			crease_w.append(0.00045 * sin(PI * float(i) / 8.0) + 0.00005)
		SkaterParts.part(head, "LidCrease" + side + "Mesh", _face_mesh(_strip_rows(crease, crease_w), false, 0.0005),
				Vector3.ZERO, mats, "head_skin_shadow")
		var low: PackedVector2Array = PackedVector2Array()
		var low_w: PackedFloat32Array = PackedFloat32Array()
		for i: int in 9:
			var u: float = 0.1 + 0.92 * float(i) / 8.0
			low.append(Vector2(ex + s * u * hx, EYE_Y + _eye_bot(clampf(u, -1.0, 1.0)) - 0.0004))
			low_w.append(0.00055 * sin(PI * (0.15 + 0.85 * float(i) / 8.0)) + 0.00005)
		SkaterParts.part(head, "LowerLash" + side + "Mesh", _face_mesh(_strip_rows(low, low_w), false, 0.0007),
				Vector3.ZERO, mats, "head_lash_low")
		# Brow: thin, gently arched, tapering out; the inner end is level, never angled down (stern).
		var brow: PackedVector2Array = PackedVector2Array()
		var brow_w: PackedFloat32Array = PackedFloat32Array()
		for i: int in 11:
			var t: float = float(i) / 10.0
			brow.append(Vector2(s * (0.019 + 0.043 * t), BROW_Y + 0.0045 * sin(PI * (0.12 + 0.8 * t)) - 0.003 * t * t))
			brow_w.append(lerpf(0.0011, 0.0003, t * t) * (0.6 + 0.4 * sin(PI * minf(t * 1.6, 1.0) * 0.5 + 0.0)))
		SkaterParts.part(head, "Brow" + side + "Mesh", _face_mesh(_strip_rows(brow, brow_w), false, 0.0006), Vector3.ZERO,
				mats, "head_brow")
		SkaterParts.part(head, "Blush" + side + "Mesh", _face_mesh(_fill_rows(_ellipse(
				Vector2(s * 0.045, EYE_Y - 0.026), 0.0115, 0.0045)), true, 0.0003), Vector3.ZERO, mats, "head_blush")

	# Nose: a tiny low-contrast tick beside and under the tip.
	var nose: PackedVector2Array = PackedVector2Array([
		Vector2(0.0035, NOSE_Y + 0.004), Vector2(0.004, NOSE_Y), Vector2(0.002, NOSE_Y - 0.0035), Vector2(-0.0015, NOSE_Y - 0.004),
	])
	SkaterParts.part(head, "NoseMesh", _face_mesh(_strip_rows(nose, PackedFloat32Array([0.0001, 0.0006, 0.0006, 0.0001])),
			false, 0.0005), Vector3.ZERO, mats, "head_skin_shadow")
	# Mouth: a small gentle smile with a soft lower-lip hint.
	var mouth: PackedVector2Array = PackedVector2Array()
	var mouth_w: PackedFloat32Array = PackedFloat32Array()
	for i: int in 13:
		var t: float = -1.0 + 2.0 * float(i) / 12.0
		mouth.append(Vector2(t * 0.0165, MOUTH_Y + 0.0032 * t * t * (0.6 + 0.4 * absf(t))))
		mouth_w.append(0.00095 * (1.0 - 0.6 * t * t) + 0.00015)
	SkaterParts.part(head, "MouthMesh", _face_mesh(_strip_rows(mouth, mouth_w), false, 0.0006), Vector3.ZERO, mats, "head_lip")
	var lip: PackedVector2Array = PackedVector2Array()
	var lip_w: PackedFloat32Array = PackedFloat32Array()
	for i: int in 7:
		var t: float = -1.0 + 2.0 * float(i) / 6.0
		lip.append(Vector2(t * 0.0055, MOUTH_Y - 0.0045 + 0.0008 * t * t))
		lip_w.append(0.0005 * (1.0 - t * t) + 0.00005)
	SkaterParts.part(head, "LipMesh", _face_mesh(_strip_rows(lip, lip_w), false, 0.0005), Vector3.ZERO, mats, "head_lip_light")


## Keeps a shape inside the eye opening (the lids cut it), with a hair of margin.
static func _clip_to_eye(shape: PackedVector2Array, ex: float, s: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var hx: float = EYE_W * 0.5
	for q: Vector2 in shape:
		var u: float = clampf((q.x - ex) * s / hx, -0.98, 0.98)
		var top: float = EYE_Y + _eye_top(u) - 0.0003
		var bot: float = EYE_Y + _eye_bot(u) + 0.0003
		out.append(Vector2(q.x, clampf(q.y, bot, top)))
	return out


# --- Hair ---------------------------------------------------------------------------------------------------------

## Head surface point pushed out radially (from CENTER) by t.
static func _out(p: Vector3, t: float) -> Vector3:
	var d: Vector3 = p - CENTER
	return CENTER + d * (1.0 + t / maxf(d.length(), 0.001))


static func _hairline_y(a: float) -> float:
	_ensure_profiles()
	return SkaterParts.profile_r(_hairline, absf(rad_to_deg(wrapf(a, -PI, PI))))


## Scalp point at angle a and height y, offset t over the skin.
static func cap_point(a: float, y: float, t: float = CAP_T) -> Vector3:
	return _out(head_point(a, y), t)


static func _cap_mesh() -> ArrayMesh:
	var cols: int = 48
	var fr: Array = [-0.03, 0.0, 0.05, 0.12, 0.22, 0.34, 0.46, 0.58, 0.69, 0.79, 0.87, 0.93, 0.97, 1.0]
	var rows: Array = []
	for f: float in fr:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			var a: float = -PI + TAU * float(k) / float(cols)
			var yb: float = _hairline_y(a)
			var y: float = lerpf(yb, CROWN_Y, maxf(f, 0.0))
			var t: float = 0.0 if f < 0.0 else lerpf(0.004, CAP_T, smoothstep(0.0, 0.15, f))
			if f < 0.0:
				y = yb + 0.002
			ring.append(cap_point(a, minf(y, CROWN_Y), t + 0.0004))
		rows.append(ring)
	return _oriented_grid(rows, true, CENTER)


## Tapered hair lock along a centre line: a lens section (width along the surface, thin across it) whose edges curl
## back toward `normals` (outward directions per point). Points and sizes are resampled smoothly.
static func _lock_mesh(pts: PackedVector3Array, widths: PackedFloat32Array, thick: PackedFloat32Array,
		normals: PackedVector3Array, curl: float, sides: int = 10, sub: int = 4) -> ArrayMesh:
	var p: PackedVector3Array = _smooth(pts, sub)
	var w: PackedFloat32Array = _smooth_r(widths, sub)
	var th: PackedFloat32Array = _smooth_r(thick, sub)
	var nn: PackedVector3Array = _smooth(normals, sub)
	return _lock_from(p, w, th, nn, curl, sides)


static func _lock_from(p: PackedVector3Array, w: PackedFloat32Array, th: PackedFloat32Array, nn: PackedVector3Array,
		curl: float, sides: int) -> ArrayMesh:
	var n: int = p.size()
	var rows: Array = []
	for i: int in n:
		var t: Vector3 = (p[mini(i + 1, n - 1)] - p[maxi(i - 1, 0)]).normalized()
		var nv: Vector3 = nn[i] - t * nn[i].dot(t)
		if nv.length() < 0.0001:
			nv = t.cross(Vector3.RIGHT)
		nv = nv.normalized()
		var b: Vector3 = t.cross(nv).normalized()
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in sides:
			var ph: float = TAU * float(k) / float(sides)
			var cph: float = cos(ph)
			ring.append(p[i] + b * (w[i] * cph) + nv * (th[i] * sin(ph) - curl * w[i] * cph * cph))
		rows.append(ring)
	var mid: int = n / 2
	var r0: PackedVector3Array = rows[mid]
	var r1: PackedVector3Array = rows[mid + 1]
	var tri: Vector3 = (r0[1] - r0[0]).cross(r1[0] - r0[0])
	return SkaterParts.grid(rows, true, tri.dot(r0[0] - p[mid]) > 0.0)


static func _radial_normals(pts: PackedVector3Array, c: Vector3, horizontal: bool = false) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for q: Vector3 in pts:
		var d: Vector3 = q - c
		if horizontal:
			d.y = 0.0
		out.append(d.normalized())
	return out


static func _build_hair(head: Node3D, mats: Dictionary) -> void:
	SkaterParts.part(head, "HairCapMesh", _cap_mesh(), Vector3.ZERO, mats, "hair_mid")
	_build_bangs(head, mats)
	_build_gathered(head, mats)
	for s: float in [-1.0, 1.0]:
		_build_side(head, mats, s)


## Bangs: x_root, x_tip, y_tip, half width, palette key, lift over the cap.
static func _build_bangs(head: Node3D, mats: Dictionary) -> void:
	var specs: Array = [
		[-0.014, -0.034, 0.09, 0.0125, "hair_shadow", 0.0],
		[0.008, 0.016, 0.093, 0.0125, "hair_shadow", 0.0],
		[0.026, 0.05, 0.087, 0.0125, "hair_shadow", 0.0],
		[-0.032, -0.066, 0.078, 0.0135, "hair_base", 0.003],
		[-0.022, -0.046, 0.093, 0.0125, "hair_base", 0.003],
		[-0.01, -0.022, 0.099, 0.0115, "hair_base", 0.003],
		[0.002, 0.003, 0.095, 0.0115, "hair_base", 0.003],
		[0.013, 0.026, 0.1, 0.0115, "hair_base", 0.003],
		[0.023, 0.047, 0.093, 0.0125, "hair_base", 0.003],
		[0.032, 0.066, 0.078, 0.0135, "hair_base", 0.003],
	]
	for i: int in specs.size():
		var b: Array = specs[i]
		var xr: float = float(b[0])
		var xt: float = float(b[1])
		var yt: float = float(b[2])
		var hw: float = float(b[3])
		var lift: float = float(b[5])
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var n_pts: int = 7
		for k: int in n_pts:
			var t: float = float(k) / float(n_pts - 1)
			var y: float = lerpf(0.176, yt, t)
			var x: float = lerpf(xr, xt, t * t * (3.0 - 2.0 * t))
			var d: float = lerpf(0.005, 0.0125 + lift, smoothstep(0.0, 0.25, t)) - 0.007 * pow(t, 3.0)
			var base: Vector3 = Vector3(x, y, face_z(x, y))
			pts.append(base + face_normal(x, y) * d)
			ws.append(hw * (0.75 + 0.35 * sin(PI * minf(t * 1.4, 1.0) * 0.5)) * (1.0 - pow(t, 2.2)) + 0.0004)
			ts.append(0.0028 * (1.0 - t * 0.8) + 0.0004)
		var key: String = str(b[4])
		SkaterParts.part(head, "Bang%dMesh" % i, _lock_mesh(pts, ws, ts, _radial_normals(pts, CENTER), 0.22, 10, 3),
				Vector3.ZERO, mats, key)


## Strands over the back and sides of the scalp, gathered up to the ponytail tie.
static func _build_gathered(head: Node3D, mats: Dictionary) -> void:
	var tie: Vector3 = cap_point(PI, PONY_ROOT_Y, CAP_T)
	# start angle (deg), start height, half width, key
	var specs: Array = [
		[112.0, 0.036, 0.013, "hair_base"], [130.0, 0.008, 0.014, "hair_mid"], [146.0, -0.008, 0.014, "hair_base"],
		[163.0, -0.016, 0.014, "hair_mid"], [180.0, -0.018, 0.014, "hair_base"], [-163.0, -0.016, 0.014, "hair_mid"],
		[-146.0, -0.008, 0.014, "hair_base"], [-130.0, 0.008, 0.014, "hair_mid"], [-112.0, 0.036, 0.013, "hair_base"],
		[72.0, 0.13, 0.009, "hair_base", 0.45], [-72.0, 0.13, 0.009, "hair_base", 0.45],
	]
	for i: int in specs.size():
		var sp: Array = specs[i]
		var a0: float = deg_to_rad(float(sp[0]))
		var y0: float = float(sp[1])
		var a1: float = PI if a0 > 0.0 else -PI
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var n_pts: int = 7
		for k: int in n_pts:
			var t: float = float(k) / float(n_pts - 1)
			var a: float = lerpf(a0, a1, pow(t, 1.6))
			var y: float = lerpf(y0, PONY_ROOT_Y - 0.004, t)
			var flat: float = float(sp[4]) if sp.size() > 4 else 1.0
			var q: Vector3 = cap_point(a, y, CAP_T + (0.0016 + 0.0025 * sin(PI * t)) * flat - 0.004 * pow(1.0 - t, 4.0))
			if k == n_pts - 1:
				q = tie
			pts.append(q)
			var wt: float = float(sp[2]) * (0.25 + 0.75 * smoothstep(0.0, 0.3, t)) * (1.0 - 0.45 * t)
			ws.append(wt)
			ts.append(0.0032 * flat * (0.4 + 0.6 * smoothstep(0.0, 0.3, t)))
		SkaterParts.part(head, "HairStrand%dMesh" % i, _lock_mesh(pts, ws, ts, _radial_normals(pts, CENTER), 0.3, 8, 4),
				Vector3.ZERO, mats, str(sp[3]))
	# Angel-ring sheen: short soft streaks a third of the way down the crown.
	for i: int in 4:
		var a: float = deg_to_rad([-100.0, -55.0, 55.0, 100.0][i])
		var pts: PackedVector3Array = PackedVector3Array()
		for k: int in 4:
			var aa: float = a + deg_to_rad(-9.0 + 6.0 * float(k))
			var y: float = 0.158 + 0.003 * sin(PI * float(k) / 3.0) - 0.012 * absf(sin(a))
			pts.append(cap_point(aa, y, CAP_T + 0.0075))
		var ws: PackedFloat32Array = PackedFloat32Array([0.0006, 0.0028, 0.0028, 0.0006])
		var ts: PackedFloat32Array = PackedFloat32Array([0.0006, 0.0012, 0.0012, 0.0006])
		SkaterParts.part(head, "HairShine%dMesh" % i, _lock_mesh(pts, ws, ts, _radial_normals(pts, CENTER), 0.0, 8, 3),
				Vector3.ZERO, mats, "hair_shine")


## Three locks per side framing the face (a long front lock curling in at the collarbone, a shorter one beside it and
## a shadow lock behind), hanging from a HairSway_Side pivot at the temple.
static func _build_side(head: Node3D, mats: Dictionary, s: float) -> void:
	var tag: String = "L" if s < 0.0 else "R"
	var root: Vector3 = Vector3(s * 0.068, 0.128, -0.046)
	var pivot: Node3D = SkaterParts.joint(head, "HairSway_Side" + tag, root)
	var front: PackedVector3Array = PackedVector3Array([
		Vector3(s * 0.058, 0.142, -0.054), Vector3(s * 0.071, 0.115, -0.068), Vector3(s * 0.075, 0.075, -0.073),
		Vector3(s * 0.074, 0.035, -0.066), Vector3(s * 0.079, -0.004, -0.055), Vector3(s * 0.078, -0.04, -0.054),
		Vector3(s * 0.066, -0.068, -0.064), Vector3(s * 0.052, -0.081, -0.077), Vector3(s * 0.043, -0.081, -0.087),
	])
	var fw: PackedFloat32Array = PackedFloat32Array([0.0065, 0.0095, 0.0105, 0.0105, 0.0102, 0.009, 0.0065, 0.003, 0.0004])
	var ft: PackedFloat32Array = PackedFloat32Array([0.0028, 0.0034, 0.0036, 0.0034, 0.0032, 0.0028, 0.002, 0.0012, 0.0004])
	_pivot_lock(pivot, "SideLock" + tag + "Mesh", mats, "hair_base", front, fw, ft, 0.35, true, 0.55)
	var mid: PackedVector3Array = PackedVector3Array([
		Vector3(s * 0.066, 0.136, -0.036), Vector3(s * 0.08, 0.105, -0.046), Vector3(s * 0.087, 0.06, -0.04),
		Vector3(s * 0.087, 0.015, -0.042), Vector3(s * 0.083, -0.022, -0.05), Vector3(s * 0.078, -0.045, -0.054),
		Vector3(s * 0.072, -0.054, -0.06),
	])
	var mw: PackedFloat32Array = PackedFloat32Array([0.008, 0.011, 0.012, 0.011, 0.008, 0.004, 0.0004])
	var mt: PackedFloat32Array = PackedFloat32Array([0.0028, 0.0034, 0.0035, 0.0032, 0.0026, 0.0016, 0.0004])
	_pivot_lock(pivot, "SideLockMid" + tag + "Mesh", mats, "hair_mid", mid, mw, mt, 0.35, true, 0.3)
	var back: PackedVector3Array = PackedVector3Array([
		Vector3(s * 0.07, 0.128, -0.018), Vector3(s * 0.084, 0.09, -0.024), Vector3(s * 0.089, 0.045, -0.02),
		Vector3(s * 0.087, 0.005, -0.014), Vector3(s * 0.08, -0.025, -0.016), Vector3(s * 0.074, -0.038, -0.026),
	])
	var bw: PackedFloat32Array = PackedFloat32Array([0.01, 0.0135, 0.014, 0.012, 0.007, 0.0004])
	var bt: PackedFloat32Array = PackedFloat32Array([0.003, 0.0034, 0.0034, 0.003, 0.002, 0.0004])
	_pivot_lock(pivot, "SideLockBack" + tag + "Mesh", mats, "hair_shadow", back, bw, bt, 0.3, true)


## Builds a lock given in head space under a pivot (identity rotation), so its mesh is relative to the pivot.
static func _pivot_lock(pivot: Node3D, part_name: String, mats: Dictionary, key: String, pts: PackedVector3Array,
		ws: PackedFloat32Array, ts: PackedFloat32Array, curl: float, horizontal: bool, twist: float = 0.0) -> MeshInstance3D:
	var local: PackedVector3Array = PackedVector3Array()
	for q: Vector3 in pts:
		local.append(q - pivot.position)
	var nrm: PackedVector3Array = _radial_normals(pts, CENTER, horizontal)
	# Twist toward the front along the lock, so its broad side turns to face forward as it falls.
	for i: int in nrm.size():
		var t: float = float(i) / float(nrm.size() - 1)
		nrm[i] = nrm[i].lerp(Vector3(0.0, 0.0, -1.0), twist * t * t).normalized()
	return SkaterParts.part(pivot, part_name, _lock_mesh(local, ws, ts, nrm, curl, 10, 4), Vector3.ZERO, mats, key)


## High ponytail: a coral tie at the back of the crown and four locks (main mass, two side locks, an under lock) that
## rise, arc back and fall to the upper back. Split over the sway chain HairSway_Ponytail > 2 > 3.
static func _build_ponytail(head: Node3D, mats: Dictionary) -> void:
	var root: Vector3 = cap_point(PI, PONY_ROOT_Y, CAP_T) + Vector3(0.0, 0.0, 0.004)
	var base: Array = [
		Vector3(0.0, 0.0, -0.01), Vector3(0.0, 0.018, 0.036), Vector3(0.0, 0.014, 0.08), Vector3(0.0, -0.022, 0.112),
		Vector3(0.0, -0.09, 0.126), Vector3(0.0, -0.17, 0.12), Vector3(0.0, -0.25, 0.108), Vector3(0.0, -0.32, 0.104),
		Vector3(0.0, -0.37, 0.114),
	]
	var p1: Node3D = SkaterParts.joint(head, "HairSway_Ponytail", root)
	var p2: Node3D = SkaterParts.joint(p1, "HairSway_Ponytail2", base[3] as Vector3)
	var p3: Node3D = SkaterParts.joint(p2, "HairSway_Ponytail3", (base[5] as Vector3) - (base[3] as Vector3))
	var tie: MeshInstance3D = SkaterParts.part(p1, "HairTieMesh", SkaterParts.torus(0.016, 0.024), Vector3(0.0, 0.004, 0.008),
			mats, "hair_tie")
	tie.rotation.x = PI * 0.5 - 1.1
	var wbase: PackedFloat32Array = PackedFloat32Array([0.017, 0.024, 0.031, 0.035, 0.036, 0.032, 0.025, 0.014, 0.0006])
	# name, x offset, z offset, width scale, length scale, wave amplitude, wave phase, key, thickness ratio
	var specs: Array = [
		["PonytailMesh", 0.0, 0.0, 0.92, 1.0, 0.005, 0.0, "hair_base", 0.62],
		["PonytailLockL", -0.023, -0.006, 0.55, 0.92, 0.013, 1.7, "hair_mid", 0.55],
		["PonytailLockR", 0.023, -0.004, 0.55, 0.97, 0.013, 3.4, "hair_mid", 0.55],
		["PonytailUnder", 0.0, -0.01, 0.62, 0.84, 0.008, 5.0, "hair_mid", 0.6],
	]
	var sub: int = 4
	for sp: Array in specs:
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var nrm: PackedVector3Array = PackedVector3Array()
		for k: int in base.size():
			var t: float = float(k) / float(base.size() - 1)
			var b: Vector3 = base[k]
			var spread: float = smoothstep(0.0, 0.3, t)
			var fan: float = 1.0 + 0.9 * smoothstep(0.55, 1.0, t)
			var q: Vector3 = Vector3(float(sp[1]) * spread * fan + float(sp[5]) * sin(t * 6.5 + float(sp[6])) * t,
					b.y * float(sp[4]), b.z + float(sp[2]) * spread)
			if k == 0:
				q = b
			pts.append(q)
			ws.append(wbase[k] * float(sp[3]))
			ts.append(wbase[k] * float(sp[3]) * float(sp[8]) + 0.0004)
			var away: Vector3 = Vector3(0.0, 0.25, 1.0).normalized() if k < 3 else Vector3(0.0, 0.0, 1.0)
			nrm.append((away + Vector3(float(sp[1]) * 30.0, 0.0, 0.0)).normalized())
		var p: PackedVector3Array = _smooth(pts, sub)
		var w: PackedFloat32Array = _smooth_r(ws, sub)
		var th: PackedFloat32Array = _smooth_r(ts, sub)
		var nn: PackedVector3Array = _smooth(nrm, sub)
		# Split at the pivots (control points 3 and 5), overlapping one sample.
		var cuts: Array = [[0, 3 * sub + 1, p1, Vector3.ZERO], [3 * sub - 1, 5 * sub + 1, p2, base[3]],
				[5 * sub - 1, p.size() - 1, p3, base[5]]]
		for ci: int in cuts.size():
			var c: Array = cuts[ci]
			var off: Vector3 = c[3]
			var sp_pts: PackedVector3Array = PackedVector3Array()
			var sp_w: PackedFloat32Array = PackedFloat32Array()
			var sp_t: PackedFloat32Array = PackedFloat32Array()
			var sp_n: PackedVector3Array = PackedVector3Array()
			for i: int in range(int(c[0]), int(c[1]) + 1):
				sp_pts.append(p[i] - off)
				sp_w.append(w[i])
				sp_t.append(th[i])
				sp_n.append(nn[i])
			var part_name: String = str(sp[0]) + ("" if ci == 0 else str(ci + 1))
			SkaterParts.part(c[2] as Node3D, part_name, _lock_from(sp_pts, sp_w, sp_t, sp_n, 0.06, 10), Vector3.ZERO,
					mats, str(sp[7]))


## Small white flower hair clip above the left temple.
static func _build_flower(head: Node3D, mats: Dictionary) -> void:
	var a: float = deg_to_rad(-58.0)
	var c: Vector3 = cap_point(a, 0.142, CAP_T + 0.006)
	var holder: Node3D = SkaterParts.joint(head, "FlowerClip", c)
	var outward: Vector3 = (c - CENTER).normalized()
	holder.basis = Basis.looking_at(outward, Vector3.UP)
	for i: int in 5:
		var ang: float = TAU * float(i) / 5.0
		var pet: MeshInstance3D = SkaterParts.part(holder, "FlowerPetal%dMesh" % i, SkaterParts.sphere_small(0.0085),
				Vector3(sin(ang) * 0.0085, cos(ang) * 0.0085, -0.001), mats, "flower")
		pet.scale = Vector3(0.85, 1.1, 0.45)
		pet.rotation.z = -ang
	SkaterParts.part(holder, "FlowerCenterMesh", SkaterParts.sphere_small(0.0045), Vector3(0.0, 0.0, -0.003), mats,
			"flower_center")


## Catmull-Rom resample: `sub` points per original segment, passing through every original point.
static func _smooth(pts: PackedVector3Array, sub: int) -> PackedVector3Array:
	return SkaterParts.smooth3d(pts, sub)


## Linear resample of per-point radii to match _smooth.
static func _smooth_r(radii: PackedFloat32Array, sub: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var n: int = radii.size()
	for i: int in n - 1:
		for k: int in sub:
			out.append(lerpf(radii[i], radii[i + 1], float(k) / float(sub)))
	out.append(radii[n - 1])
	return out
