class_name AnimeHead
extends RefCounted
## Head of the anime skaters, built in metres at the Head joint (face toward -Z, chin about 0.035 below the joint,
## crown 0.19 above: 0.225 tall, 0.15 wide, 0.19 deep, so a 1.62 m body is 7.2 heads tall).
## Face: one smooth loft with a jaw (soft V on the female face, square on the male), small chin and a tiny nose bump.
## Eyes, brows, mouth, blush and nose tick are thin decals wrapped onto the face surface (sclera, layered iris,
## pupil, two highlights, upper lash, lower lash, lid crease). The female face has big round eyes with a thick lash
## and an outer flick and thin arched brows; the male face has narrower, sharper eyes with a fine lash line, smaller
## irises, and thicker, straighter brows.
## Hair is a separate layer: build() calls the hair builder registered in Wardrobe (slot "hair", HairStyles in
## game/skater/garments/hair.gd). The surface helpers below (cap_point, face_z, face_normal, lock_mesh, pivot_lock,
## cap_mesh, radial_normals) are public for those builders.
## HAIR SWAY CONVENTION: hair that should sway hangs from identity-rotation "HairSway_<Name>" Node3D pivots under
## HeadModel, placed at each lock's root; chains number on ("HairSway_Ponytail" > "HairSway_Ponytail2" >
## "HairSway_Ponytail3"); side locks are "HairSway_SideL" / "HairSway_SideR" (L = -X).
## The face shape depends on the body type: build() selects it (use_body()), and the surface helpers answer for the
## face last selected, so hair builders called from build() see the right head.

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

## Face profile rows: y, half width, front z, back z, front superellipse exponent (higher = fuller, flatter front).
const FEMALE_ROWS: Array = [
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
## Male: a squarer jaw that stays wide down to a broad, flat chin, a slightly longer face and a flatter cheek.
const MALE_ROWS: Array = [
	[-0.041, 0.0, -0.071, -0.071, 2.2],
	[-0.039, 0.019, -0.075, -0.06, 2.6],
	[-0.033, 0.031, -0.079, -0.044, 2.9],
	[-0.022, 0.043, -0.081, -0.024, 3.1],
	[-0.006, 0.0535, -0.083, 0.004, 3.2],
	[0.014, 0.061, -0.085, 0.04, 3.1],
	[0.038, 0.0675, -0.086, 0.076, 3.0],
	[0.062, 0.0735, -0.087, 0.097, 2.9],
	[0.09, 0.0765, -0.086, 0.106, 2.8],
	[0.12, 0.076, -0.082, 0.106, 2.5],
	[0.15, 0.069, -0.068, 0.095, 2.2],
	[0.17, 0.055, -0.05, 0.075, 2.0],
	[0.182, 0.037, -0.032, 0.05, 2.0],
	[0.188, 0.019, -0.016, 0.03, 2.0],
	[0.19, 0.0, 0.006, 0.006, 2.0],
]
## Face styles: eye size and placement, iris shape, and which brow, lash and mouth style to draw.
const FACES: Dictionary = {
	"female": {"rows": FEMALE_ROWS, "eye_x": EYE_X, "eye_y": EYE_Y, "eye_w": EYE_W, "eye_h": EYE_H, "brow_y": BROW_Y,
			"iris_rx": 0.31, "iris_ry": 0.43, "top_pow": 0.42, "bot_pow": 0.75, "male": false},
	"male": {"rows": MALE_ROWS, "eye_x": 0.0395, "eye_y": 0.06, "eye_w": 0.0365, "eye_h": 0.0235, "brow_y": 0.0835,
			"iris_rx": 0.27, "iris_ry": 0.56, "top_pow": 0.3, "bot_pow": 0.5, "male": true},
}

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
## Hair style built when build() is given none, per body type.
const DEFAULT_HAIR: Dictionary = {"female": "hair_ponytail", "male": "hair_messy"}

static var _kind: String = ""
static var _f: Dictionary = FACES["female"]
static var _w: PackedVector2Array = PackedVector2Array()
static var _zf: PackedVector2Array = PackedVector2Array()
static var _zb: PackedVector2Array = PackedVector2Array()
static var _nf: PackedVector2Array = PackedVector2Array()
static var _hairline: PackedVector2Array = PackedVector2Array()


## Builds the head under the Head joint: "HeadModel" with the skin, ears, face decals and the hair style
## (Wardrobe slot "hair"; "" = the body's default, "none" = no hair). body_type: "female" or
## "male". rig: the body's Wardrobe rig, if any (HeadModel is added to it); otherwise a small one is made.
## Material keys build() adds when missing: the COLORS keys, plus "head_blush" and "head_skin_shadow" from "skin".
static func build(head: Node3D, mats: Dictionary, hair_style: String = "", body_type: String = "female", rig: Dictionary = {}) -> void:
	use_body(body_type)
	_add_materials(mats)
	var m: Node3D = SkaterParts.joint(head, "HeadModel", Vector3.ZERO)
	SkaterParts.tag_region(SkaterParts.part(m, "HeadMesh", _head_mesh(), Vector3.ZERO, mats, "skin"), "head")
	for s: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = SkaterParts.part(m, ("Left" if s < 0.0 else "Right") + "EarMesh", SkaterParts.sphere_small(0.012),
				Vector3(s * 0.071 * (1.02 if _f["male"] else 1.0), 0.05, 0.014), mats, "skin")
		ear.scale = Vector3(0.5, 1.3, 0.9)
		ear.rotation.y = s * 0.3
		SkaterParts.tag_region(ear, "head")
	_build_face(m, mats)
	if rig.is_empty():
		rig = {"Head": head, "body_type": body_type}
	rig["HeadModel"] = m
	if not rig.has("body_type"):
		rig["body_type"] = body_type
	var style: String = hair_style if hair_style != "" else str(DEFAULT_HAIR.get(body_type, "hair_ponytail"))
	Wardrobe.build_item("hair", style, rig, body_type, mats)


## Selects the face shape the surface helpers use ("female" or "male").
static func use_body(body_type: String) -> void:
	var kind: String = body_type if FACES.has(body_type) else "female"
	if kind == _kind:
		return
	_kind = kind
	_f = FACES[kind]
	_w = PackedVector2Array()


static func _add_materials(mats: Dictionary) -> void:
	var skin: Color = Color(1.0, 0.89, 0.83)
	if mats.has("skin"):
		skin = (mats["skin"] as StandardMaterial3D).albedo_color
	var derived: Dictionary = COLORS.duplicate()
	derived["head_blush"] = skin.lerp(Color("ffb3b0"), 0.45)
	derived["head_skin_shadow"] = skin.lerp(Color("d9a090"), 0.55)
	derived["head_mouth"] = skin.lerp(Color("8a4a3e"), 0.55)
	for key: String in derived:
		if not mats.has(key):
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = derived[key]
			mat.roughness = 0.7
			mats[key] = mat


# --- Face surface -------------------------------------------------------------------------------------------------

static func _ensure_profiles() -> void:
	if _kind == "":
		use_body("female")
	if not _w.is_empty():
		return
	var rows: Array = _f["rows"]
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
	var eh: float = float(_f["eye_h"])
	if _f["male"]:
		# Sharper male eye: a flat top lid that dips toward the inner corner, highest just outside the middle.
		return eh * 0.5 * pow(v, float(_f["top_pow"])) * (1.0 + 0.16 * u) - 0.0025 * maxf(-u, 0.0)
	return eh * 0.5 * pow(v, float(_f["top_pow"])) * (1.0 + 0.1 * u) - 0.0015 * maxf(-u, 0.0)


static func _eye_bot(u: float) -> float:
	var v: float = clampf(1.0 - u * u, 0.0, 1.0)
	var eh: float = float(_f["eye_h"])
	if _f["male"]:
		return -eh * 0.5 * pow(v, float(_f["bot_pow"])) * (0.8 - 0.12 * u)
	return -eh * 0.5 * pow(v, float(_f["bot_pow"])) * (0.86 - 0.08 * u)


static func _build_face(head: Node3D, mats: Dictionary) -> void:
	var male: bool = _f["male"]
	var eye_x: float = float(_f["eye_x"])
	var eye_y: float = float(_f["eye_y"])
	var eye_w: float = float(_f["eye_w"])
	var eye_h: float = float(_f["eye_h"])
	var brow_y: float = float(_f["brow_y"])
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var ex: float = s * eye_x
		var hx: float = eye_w * 0.5
		# Eye coordinates: x = ex + s * u * hx (u = 1 is the outer corner).
		var sclera: PackedVector2Array = PackedVector2Array()
		var segs: int = 20
		for i: int in segs + 1:
			var u: float = -1.0 + 2.0 * float(i) / float(segs)
			sclera.append(Vector2(ex + s * u * hx, eye_y + _eye_top(u)))
		for i: int in range(segs - 1, 0, -1):
			var u: float = -1.0 + 2.0 * float(i) / float(segs)
			sclera.append(Vector2(ex + s * u * hx, eye_y + _eye_bot(u)))
		SkaterParts.part(head, "Eye" + side + "Mesh", _face_mesh(_fill_rows(sclera), true, 0.0004), Vector3.ZERO, mats,
				"head_sclera")
		# Iris: an oval, its top tucked under the upper lid; darker rim, a lighter body set lower, a glow below and
		# the pupil. The male iris is smaller and rounder, cut by both lids.
		var ic: Vector2 = Vector2(ex + s * 0.0008, eye_y + (0.0012 if not male else 0.0004))
		var irx: float = eye_w * float(_f["iris_rx"])
		var iry: float = eye_h * float(_f["iris_ry"])
		var layers: Array = [
			["Iris", Vector2(0.0, 0.0), 1.0, 1.0, "head_iris_rim", 0.0008],
			["IrisMid", Vector2(0.0, -0.0022 if not male else -0.0012), 0.8, 0.8, "head_iris_mid", 0.0012],
			["IrisGlow", Vector2(0.0, -0.0062 if not male else -0.0052), 0.62, 0.38, "head_iris_glow", 0.0016],
			["Pupil", Vector2(0.0, 0.0012 if not male else 0.0006), 0.4 if not male else 0.36, 0.46 if not male else 0.38,
					"head_pupil", 0.002],
		]
		for ly: Array in layers:
			var c: Vector2 = ic + (ly[1] as Vector2)
			var shape: PackedVector2Array = _ellipse(c, irx * float(ly[2]), iry * float(ly[3]))
			SkaterParts.part(head, str(ly[0]) + side + "Mesh", _face_mesh(_fill_rows(_clip_to_eye(shape, ex, s)), true,
					float(ly[5])), Vector3.ZERO, mats, str(ly[4]))
		# Highlights on the same side in both eyes: a big one upper +X, a small one lower -X.
		var shine: Vector2 = Vector2(0.0034, 0.0041) if not male else Vector2(0.0024, 0.0026)
		var shine_shape: PackedVector2Array = _ellipse(ic + Vector2(irx * 0.42, iry * (0.38 if not male else 0.28)), shine.x, shine.y, 16)
		if male:
			shine_shape = _clip_to_eye(shine_shape, ex, s)
		SkaterParts.part(head, "EyeShine" + side + "Mesh", _face_mesh(_fill_rows(shine_shape), true, 0.0026), Vector3.ZERO, mats,
				"head_shine")
		SkaterParts.part(head, "EyeShineSmall" + side + "Mesh", _face_mesh(_fill_rows(_ellipse(
				ic + Vector2(-irx * 0.4, -iry * 0.5), 0.0016 if not male else 0.0011, 0.0016 if not male else 0.0011, 12)),
				true, 0.0026), Vector3.ZERO, mats, "head_shine")
		# Upper lash: the female lash is a thick dark arc, thickest toward the outer corner, ending in a flick; the
		# male lash is a fine, even line with a short angled tick at the outer corner.
		var lash: PackedVector2Array = PackedVector2Array()
		var lash_w: PackedFloat32Array = PackedFloat32Array()
		for i: int in 17:
			var u: float = -1.03 + 1.96 * float(i) / 16.0
			var hw: float = lerpf(0.0006, 0.0025, smoothstep(-1.0, 0.6, u)) if not male else lerpf(0.0005, 0.0013, smoothstep(-1.0, 0.8, u))
			lash.append(Vector2(ex + s * u * hx, eye_y + _eye_top(clampf(u, -1.0, 1.0)) + hw * 0.5))
			lash_w.append(hw)
		if male:
			lash.append(Vector2(ex + s * (hx + 0.002), eye_y + _eye_top(0.98) - 0.0008))
			lash_w.append(0.0009)
			lash.append(Vector2(ex + s * (hx + 0.0042), eye_y + _eye_top(0.98) - 0.0026))
			lash_w.append(0.0002)
		else:
			lash.append(Vector2(ex + s * (hx + 0.0026), eye_y + 0.0075))
			lash_w.append(0.0014)
			lash.append(Vector2(ex + s * (hx + 0.0062), eye_y + 0.0102))
			lash_w.append(0.0002)
		SkaterParts.part(head, "Lash" + side + "Mesh", _face_mesh(_strip_rows(lash, lash_w), false, 0.003), Vector3.ZERO,
				mats, "head_lash")
		# Lid crease, thin lower lash at the outer half.
		var crease: PackedVector2Array = PackedVector2Array()
		var crease_w: PackedFloat32Array = PackedFloat32Array()
		for i: int in 9:
			var u: float = -0.45 + 1.35 * float(i) / 8.0
			crease.append(Vector2(ex + s * u * hx, eye_y + _eye_top(clampf(u, -1.0, 0.98)) + (0.0052 if not male else 0.0042) - 0.001 * u))
			crease_w.append(0.00045 * sin(PI * float(i) / 8.0) + 0.00005)
		SkaterParts.part(head, "LidCrease" + side + "Mesh", _face_mesh(_strip_rows(crease, crease_w), false, 0.0005),
				Vector3.ZERO, mats, "head_skin_shadow")
		var low: PackedVector2Array = PackedVector2Array()
		var low_w: PackedFloat32Array = PackedFloat32Array()
		for i: int in 9:
			var u: float = 0.1 + 0.92 * float(i) / 8.0 if not male else 0.35 + 0.65 * float(i) / 8.0
			low.append(Vector2(ex + s * u * hx, eye_y + _eye_bot(clampf(u, -1.0, 1.0)) - 0.0004))
			low_w.append((0.00055 if not male else 0.0004) * sin(PI * (0.15 + 0.85 * float(i) / 8.0)) + 0.00005)
		SkaterParts.part(head, "LowerLash" + side + "Mesh", _face_mesh(_strip_rows(low, low_w), false, 0.0007),
				Vector3.ZERO, mats, "head_lash_low")
		# Brow: female thin, gently arched, tapering out, the inner end level; male thick and nearly straight, set
		# low over the eye, its inner end a touch lower (confident, not angry), tapering at the tail.
		var brow: PackedVector2Array = PackedVector2Array()
		var brow_w: PackedFloat32Array = PackedFloat32Array()
		for i: int in 11:
			var t: float = float(i) / 10.0
			if male:
				brow.append(Vector2(s * (0.017 + 0.047 * t), brow_y - 0.0016 + 0.0042 * sin(PI * minf(t * 0.75, 1.0)) - 0.0028 * t * t))
				brow_w.append(lerpf(0.0021, 0.0007, pow(t, 1.6)) * (0.75 + 0.25 * sin(PI * minf(t * 2.0, 1.0) * 0.5)))
			else:
				brow.append(Vector2(s * (0.019 + 0.043 * t), brow_y + 0.0045 * sin(PI * (0.12 + 0.8 * t)) - 0.003 * t * t))
				brow_w.append(lerpf(0.0011, 0.0003, t * t) * (0.6 + 0.4 * sin(PI * minf(t * 1.6, 1.0) * 0.5 + 0.0)))
		SkaterParts.part(head, "Brow" + side + "Mesh", _face_mesh(_strip_rows(brow, brow_w), false, 0.0006), Vector3.ZERO,
				mats, "head_brow")
		if not male:
			SkaterParts.part(head, "Blush" + side + "Mesh", _face_mesh(_fill_rows(_ellipse(
					Vector2(s * 0.045, eye_y - 0.026), 0.0115, 0.0045)), true, 0.0003), Vector3.ZERO, mats, "head_blush")

	# Nose: a tiny low-contrast tick beside and under the tip (a little longer on the male face).
	var nk: float = 1.0 if not male else 1.35
	var nose: PackedVector2Array = PackedVector2Array([
		Vector2(0.0035, NOSE_Y + 0.004 * nk), Vector2(0.004, NOSE_Y), Vector2(0.002, NOSE_Y - 0.0035), Vector2(-0.0015, NOSE_Y - 0.004),
	])
	SkaterParts.part(head, "NoseMesh", _face_mesh(_strip_rows(nose, PackedFloat32Array([0.0001, 0.0006, 0.0006, 0.0001])),
			false, 0.0005), Vector3.ZERO, mats, "head_skin_shadow")
	if male:
		# Mouth: a short, nearly straight line with a slight smirk at one corner, and a faint lower-lip shadow.
		var mouth_m: PackedVector2Array = PackedVector2Array()
		var mouth_mw: PackedFloat32Array = PackedFloat32Array()
		for i: int in 11:
			var t: float = -1.0 + 2.0 * float(i) / 10.0
			mouth_m.append(Vector2(t * 0.0135, MOUTH_Y + 0.0012 * t * t + 0.0012 * maxf(t, 0.0) * t))
			mouth_mw.append(0.0007 * (1.0 - 0.55 * t * t) + 0.00012)
		SkaterParts.part(head, "MouthMesh", _face_mesh(_strip_rows(mouth_m, mouth_mw), false, 0.0006), Vector3.ZERO, mats, "head_mouth")
		var lip_m: PackedVector2Array = PackedVector2Array()
		var lip_mw: PackedFloat32Array = PackedFloat32Array()
		for i: int in 7:
			var t: float = -1.0 + 2.0 * float(i) / 6.0
			lip_m.append(Vector2(t * 0.0045, MOUTH_Y - 0.0055 + 0.0006 * t * t))
			lip_mw.append(0.0004 * (1.0 - t * t) + 0.00005)
		SkaterParts.part(head, "LipMesh", _face_mesh(_strip_rows(lip_m, lip_mw), false, 0.0005), Vector3.ZERO, mats, "head_skin_shadow")
		return
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
	var hx: float = float(_f["eye_w"]) * 0.5
	var eye_y: float = float(_f["eye_y"])
	for q: Vector2 in shape:
		var u: float = clampf((q.x - ex) * s / hx, -0.98, 0.98)
		var top: float = eye_y + _eye_top(u) - 0.0003
		var bot: float = eye_y + _eye_bot(u) + 0.0003
		out.append(Vector2(q.x, clampf(q.y, bot, top)))
	return out


# --- Hair ---------------------------------------------------------------------------------------------------------

## Head surface point pushed out radially (from CENTER) by t.
static func _out(p: Vector3, t: float) -> Vector3:
	var d: Vector3 = p - CENTER
	return CENTER + d * (1.0 + t / maxf(d.length(), 0.001))


static func hairline_y(a: float) -> float:
	_ensure_profiles()
	return SkaterParts.profile_r(_hairline, absf(rad_to_deg(wrapf(a, -PI, PI))))


## Scalp point at angle a and height y, offset t over the skin.
static func cap_point(a: float, y: float, t: float = CAP_T) -> Vector3:
	return _out(head_point(a, y), t)


static func cap_mesh() -> ArrayMesh:
	var cols: int = 48
	var fr: Array = [-0.03, 0.0, 0.05, 0.12, 0.22, 0.34, 0.46, 0.58, 0.69, 0.79, 0.87, 0.93, 0.97, 1.0]
	var rows: Array = []
	for f: float in fr:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			var a: float = -PI + TAU * float(k) / float(cols)
			var yb: float = hairline_y(a)
			var y: float = lerpf(yb, CROWN_Y, maxf(f, 0.0))
			var t: float = 0.0 if f < 0.0 else lerpf(0.004, CAP_T, smoothstep(0.0, 0.15, f))
			if f < 0.0:
				y = yb + 0.002
			ring.append(cap_point(a, minf(y, CROWN_Y), t + 0.0004))
		rows.append(ring)
	return _oriented_grid(rows, true, CENTER)


## Tapered hair lock along a centre line: a lens section (width along the surface, thin across it) whose edges curl
## back toward `normals` (outward directions per point). Points and sizes are resampled smoothly.
static func lock_mesh(pts: PackedVector3Array, widths: PackedFloat32Array, thick: PackedFloat32Array,
		normals: PackedVector3Array, curl: float, sides: int = 10, sub: int = 4) -> ArrayMesh:
	var p: PackedVector3Array = smooth(pts, sub)
	var w: PackedFloat32Array = smooth_r(widths, sub)
	var th: PackedFloat32Array = smooth_r(thick, sub)
	var nn: PackedVector3Array = smooth(normals, sub)
	return lock_from(p, w, th, nn, curl, sides)


static func lock_from(p: PackedVector3Array, w: PackedFloat32Array, th: PackedFloat32Array, nn: PackedVector3Array,
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


static func radial_normals(pts: PackedVector3Array, c: Vector3, horizontal: bool = false) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for q: Vector3 in pts:
		var d: Vector3 = q - c
		if horizontal:
			d.y = 0.0
		out.append(d.normalized())
	return out


## Builds a lock given in head space under a pivot (identity rotation), so its mesh is relative to the pivot.
static func pivot_lock(pivot: Node3D, part_name: String, mats: Dictionary, key: String, pts: PackedVector3Array,
		ws: PackedFloat32Array, ts: PackedFloat32Array, curl: float, horizontal: bool, twist: float = 0.0) -> MeshInstance3D:
	var local: PackedVector3Array = PackedVector3Array()
	for q: Vector3 in pts:
		local.append(q - pivot.position)
	var nrm: PackedVector3Array = radial_normals(pts, CENTER, horizontal)
	# Twist toward the front along the lock, so its broad side turns to face forward as it falls.
	for i: int in nrm.size():
		var t: float = float(i) / float(nrm.size() - 1)
		nrm[i] = nrm[i].lerp(Vector3(0.0, 0.0, -1.0), twist * t * t).normalized()
	return SkaterParts.part(pivot, part_name, lock_mesh(local, ws, ts, nrm, curl, 10, 4), Vector3.ZERO, mats, key)


## Catmull-Rom resample: `sub` points per original segment, passing through every original point.
static func smooth(pts: PackedVector3Array, sub: int) -> PackedVector3Array:
	return SkaterParts.smooth3d(pts, sub)


## Linear resample of per-point radii to match _smooth.
static func smooth_r(radii: PackedFloat32Array, sub: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var n: int = radii.size()
	for i: int in n - 1:
		for k: int in sub:
			out.append(lerpf(radii[i], radii[i + 1], float(k) / float(sub)))
	out.append(radii[n - 1])
	return out
