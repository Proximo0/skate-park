class_name GarmentAccessories
extends RefCounted
## Accessories (slot "accessory", several at once). Contract and registration: see Wardrobe
## (game/skater/wardrobe.gd). Built: acc_wristbands (palette keys "band" and "trim"), acc_cap (a curved-brim skate
## cap worn backwards; cap_forward() wears it brim-forward), acc_headband, acc_sunnies (pushed up on the head;
## sunnies_on_eyes() wears them, and they drop onto the eyes when a cap is worn too).
## Head accessories hang under rig["HeadModel"] (built after the hair) and keep the hair from poking through: the cap
## and headband tuck every hair vertex inside them under their inner surface and hide locks they cover entirely
## (tuck_hair). pokes_through_cap() is the test's check.
## Palette keys: "acc_cap" (+ derived "acc_cap_brim", "acc_cap_seam", "acc_cap_logo"), "acc_headband" (+
## "acc_headband_stripe"), "acc_sunnies" (frame; + "acc_sunnies_lens", "acc_sunnies_shine"). Derived keys are made
## from the item colour when the palette has none.

const STUBS: PackedStringArray = []
## Cap shell over the skin (outer surface) and the radius the hair is tucked to under it.
const CAP_OUT: float = 0.03
const CAP_IN: float = 0.026
## Headband: inner radius over the skin, thickness, half height.
const BAND_IN: float = 0.021
const BAND_T: float = 0.0055
const BAND_HH: float = 0.0115

## Radius table of the head surface from AnimeHead.CENTER by (azimuth, elevation), per body type.
const AZ_STEP: float = 10.0
const EL_MIN: float = -40.0
const EL_STEP: float = 6.0
const EL_N: int = 23
static var _tables: Dictionary = {}


static func builders() -> Dictionary:
	return {
		"acc_wristbands": GarmentAccessories.wristbands,
		"acc_cap": GarmentAccessories.cap,
		"acc_headband": GarmentAccessories.headband,
		"acc_sunnies": GarmentAccessories.sunnies,
	}


static func covers(_id: String, _body_type: String) -> PackedStringArray:
	return PackedStringArray()


## Terry wristband round the wrist end of each forearm, with a trim line at its hand edge.
static func wristbands(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	Wardrobe.mat(mats, "band", Color(0.1, 0.72, 0.74))
	Wardrobe.mat(mats, "trim", Color(1.0, 0.97, 0.9))
	var ll: float = float(rig["lengths"]["lower_arm"])
	var secs: Array = rig["sections"]["forearm"]
	var y0: float = -0.86 * ll
	var y1: float = -1.0 * ll + 0.004
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var lower: Node3D = rig[side + "LowerArm"]
		SkaterParts.part(lower, side + "WristbandMesh", SkaterParts.loft(AnimeOutfit.clip_desc(secs, y0, y1), 16, 0.0045, true),
				Vector3.ZERO, mats, "band")
		SkaterParts.part(lower, side + "WristbandTrimMesh", SkaterParts.loft_ring(secs, y1 + 0.003, 0.0058, 0.0025, 20), Vector3.ZERO,
				mats, "trim")


# --- head surface table -------------------------------------------------------------------------------------

static func _dir(az: float, el: float) -> Vector3:
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


static func _table(body_type: String) -> PackedFloat32Array:
	var kind: String = body_type if AnimeHead.FACES.has(body_type) else "female"
	if _tables.has(kind):
		return _tables[kind]
	AnimeHead.use_body(kind)
	var t: PackedFloat32Array = PackedFloat32Array()
	var naz: int = int(360.0 / AZ_STEP) + 1
	for i: int in naz:
		for j: int in EL_N:
			var d: Vector3 = _dir(deg_to_rad(-180.0 + AZ_STEP * float(i)), deg_to_rad(minf(EL_MIN + EL_STEP * float(j), 89.0)))
			t.append((HairStyles._on_head(d, 0.0) - AnimeHead.CENTER).length())
	_tables[kind] = t
	return t


## Head surface radius from AnimeHead.CENTER toward (azimuth, elevation), radians (bilinear in the table).
static func head_r(body_type: String, az: float, el: float) -> float:
	var t: PackedFloat32Array = _table(body_type)
	var naz: int = int(360.0 / AZ_STEP) + 1
	var fa: float = (rad_to_deg(wrapf(az, -PI, PI)) + 180.0) / AZ_STEP
	var fe: float = clampf((rad_to_deg(el) - EL_MIN) / EL_STEP, 0.0, float(EL_N - 1) - 0.001)
	var i: int = clampi(int(fa), 0, naz - 2)
	var j: int = int(fe)
	var u: float = fa - float(i)
	var v: float = fe - float(j)
	var r00: float = t[i * EL_N + j]
	var r01: float = t[i * EL_N + j + 1]
	var r10: float = t[(i + 1) * EL_N + j]
	var r11: float = t[(i + 1) * EL_N + j + 1]
	return lerpf(lerpf(r00, r01, v), lerpf(r10, r11, v), u)


## Azimuth (0 = front, +X positive) and elevation of a head-space point seen from AnimeHead.CENTER.
static func _az_el(p: Vector3) -> Vector2:
	var d: Vector3 = p - AnimeHead.CENTER
	return Vector2(atan2(d.x, -d.z), asin(clampf(d.y / maxf(d.length(), 0.0001), -1.0, 1.0)))


## Point at azimuth az whose height is y, `off` over the head surface (bisects the elevation).
static func _at_height(body_type: String, az: float, y: float, off: float) -> Vector3:
	var lo: float = deg_to_rad(EL_MIN)
	var hi: float = deg_to_rad(89.0)
	for k: int in 20:
		var mid: float = (lo + hi) * 0.5
		var p: Vector3 = AnimeHead.CENTER + _dir(az, mid) * (head_r(body_type, az, mid) + off)
		if p.y < y:
			lo = mid
		else:
			hi = mid
	var el: float = (lo + hi) * 0.5
	return AnimeHead.CENTER + _dir(az, el) * (head_r(body_type, az, el) + off)


# --- hair tucking -------------------------------------------------------------------------------------------

## Transform of node in the space of `ancestor`, composed by hand (works before the body enters the tree).
static func _rel(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var a: Node3D = node
	while a != null and a != ancestor:
		t = a.transform * t
		a = a.get_parent() as Node3D
	return t


static func _hair_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and str(n.get_meta("palette", "")).begins_with("hair"):
		out.append(n)
	for c: Node in n.get_children():
		_hair_meshes(c, out)


## Pulls every hair vertex under HeadModel that `limit` constrains in to the radius it returns: limit(p) gives the
## largest allowed distance from AnimeHead.CENTER for head-space point p (or -1 when p is unconstrained). Hides a
## mesh whose every vertex is constrained (fully covered) when hide_covered is set. Also hides other HeadModel
## children named in `hide_nodes` when `covered` says their origin is under the accessory.
static func tuck_hair(rig: Dictionary, limit: Callable, hide_covered: bool) -> void:
	var model: Node3D = rig["HeadModel"]
	var meshes: Array[MeshInstance3D] = []
	_hair_meshes(model, meshes)
	var c: Vector3 = AnimeHead.CENTER
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null or not mi.visible:
			continue
		var xf: Transform3D = _rel(mi, model)
		var inv: Transform3D = xf.affine_inverse()
		var out: ArrayMesh = ArrayMesh.new()
		var changed: bool = false
		var all_in: bool = true
		for s: int in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i: int in vs.size():
				var p: Vector3 = xf * vs[i]
				var r_max: float = float(limit.call(p))
				if r_max < 0.0:
					all_in = false
					continue
				var d: Vector3 = p - c
				if d.length() > r_max:
					vs[i] = inv * (c + d.normalized() * r_max)
					changed = true
			arr[Mesh.ARRAY_VERTEX] = vs
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if hide_covered and all_in:
			mi.visible = false
			mi.set_meta("hidden_by_accessory", true)
		elif changed:
			mi.mesh = out


# --- cap ----------------------------------------------------------------------------------------------------

## Height of the cap's lower edge at azimuth az. The brim side sits lower; the rear has the snapback opening, an
## arch over the hairline. Backwards: brim over the nape, the opening over the forehead (the bangs show through).
static func cap_band_y(az: float, forward: bool) -> float:
	var brim_az: float = 0.0 if forward else PI
	var d: float = absf(wrapf(az - brim_az, -PI, PI))
	var k: float = (1.0 - cos(d)) * 0.5
	var y_brim: float = 0.122 if forward else 0.072
	var y_rear: float = 0.07 if forward else 0.128
	var y: float = lerpf(y_brim, y_rear, k)
	var rear: float = PI - d
	if rear < 0.5:
		y += 0.03 * pow(cos(rear / 0.5 * PI * 0.5), 0.8)
	return y


## True when head-space point p is above the cap's lower edge and outside its inner surface (hair poking through).
static func pokes_through_cap(p: Vector3, forward: bool, body_type: String = "") -> bool:
	var bt: String = body_type if body_type != "" else _current_kind()
	var ae: Vector2 = _az_el(p)
	if p.y < cap_band_y(ae.x, forward) + 0.002:
		return false
	return (p - AnimeHead.CENTER).length() > head_r(bt, ae.x, ae.y) + CAP_IN + 0.0015


static func _current_kind() -> String:
	return "male" if AnimeHead._f.get("male", false) else "female"


## Skate cap worn backwards (the default look).
static func cap(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	_build_cap(rig, body_type, mats, false)


## The same cap worn brim-forward.
static func cap_forward(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	_build_cap(rig, body_type, mats, true)


static func _build_cap(rig: Dictionary, body_type: String, mats: Dictionary, forward: bool) -> void:
	var base: Color = Wardrobe.mat(mats, "acc_cap", Color("FF5A5F")).albedo_color
	Wardrobe.mat(mats, "acc_cap_brim", base.darkened(0.18))
	Wardrobe.mat(mats, "acc_cap_seam", base.darkened(0.35) if base.get_luminance() > 0.2 else base.lightened(0.35))
	Wardrobe.mat(mats, "acc_cap_logo", Color(1.0, 0.97, 0.9) if base.get_luminance() < 0.75 else Color(0.12, 0.12, 0.2))
	var bt: String = body_type if AnimeHead.FACES.has(body_type) else "female"
	AnimeHead.use_body(bt)
	var model: Node3D = rig["HeadModel"]
	var old: Node = model.get_node_or_null("AccCap")
	if old != null:
		model.remove_child(old)
		old.free()
	var holder: Node3D = SkaterParts.joint(model, "AccCap", Vector3.ZERO)
	holder.set_meta("cap_style", "forward" if forward else "backwards")
	# Tuck the hair under the crown; hide locks it covers completely (and a flower clip under it).
	var limit: Callable = func(p: Vector3) -> float:
		var ae: Vector2 = _az_el(p)
		if p.y < cap_band_y(ae.x, forward) - 0.004:
			return -1.0
		return head_r(bt, ae.x, ae.y) + CAP_IN
	tuck_hair(rig, limit, true)
	var flower: Node3D = model.get_node_or_null("FlowerClip") as Node3D
	if flower != null and flower.position.y > cap_band_y(_az_el(flower.position).x, forward) - 0.01:
		flower.visible = false
	var cols: int = 48
	var rows: Array = []
	var fr: Array = [-1.0, 0.0, 0.08, 0.2, 0.34, 0.48, 0.61, 0.73, 0.83, 0.91, 0.97, 1.0]
	var band_el: PackedFloat32Array = PackedFloat32Array()
	for k: int in cols:
		var az: float = -PI + TAU * float(k) / float(cols)
		band_el.append(_az_el(_at_height(bt, az, cap_band_y(az, forward), CAP_OUT)).y)
	for f: float in fr:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			var az: float = -PI + TAU * float(k) / float(cols)
			var el0: float = band_el[k]
			var el: float = lerpf(el0, deg_to_rad(89.5), maxf(f, 0.0))
			# Crown fullness: a little extra height toward the top, like a structured cap.
			var off: float = CAP_OUT + 0.004 * sin(PI * clampf(f, 0.0, 1.0) * 0.8)
			if f < 0.0:
				off = CAP_IN - 0.002
			ring.append(AnimeHead.CENTER + _dir(az, el) * (head_r(bt, az, el) + off))
		rows.append(ring)
	SkaterParts.part(holder, "AccCapCrownMesh", _closed_grid(rows), Vector3.ZERO, mats, "acc_cap")
	_cap_details(holder, mats, bt, forward, band_el)


## Grid with faces outward from AnimeHead.CENTER.
static func _closed_grid(rows: Array) -> ArrayMesh:
	var r0: PackedVector3Array = rows[rows.size() / 2]
	var r1: PackedVector3Array = rows[rows.size() / 2 + 1]
	var n: Vector3 = (r0[1] - r0[0]).cross(r1[0] - r0[0])
	return SkaterParts.grid(rows, true, n.dot(r0[0] - AnimeHead.CENTER) > 0.0)


## Brim, panel seams, top button, front logo patch and the snapback strap across the opening.
static func _cap_details(holder: Node3D, mats: Dictionary, bt: String, forward: bool, band_el: PackedFloat32Array) -> void:
	var brim_az: float = 0.0 if forward else PI
	# Brim: a crescent from the band outward, curved down at its sides, thin, with rounded edges.
	var nu: int = 17
	var nv: int = 6
	var top_rows: Array = []
	var span: float = deg_to_rad(54.0)
	for j: int in nv:
		var v: float = float(j) / float(nv - 1)
		var row: PackedVector3Array = PackedVector3Array()
		for i: int in nu:
			var u: float = -1.0 + 2.0 * float(i) / float(nu - 1)
			var az: float = brim_az + u * span
			var root: Vector3 = _at_height(bt, az, cap_band_y(az, forward) + 0.002, CAP_OUT - 0.002)
			var outward: Vector3 = Vector3(sin(az), 0.0, -cos(az))
			var length: float = 0.074 * pow(maxf(1.0 - u * u, 0.0), 0.75) * (1.0 if forward else 0.92)
			var p: Vector3 = root + outward * (length * v)
			p.y -= length * v * (0.22 if forward else 0.05) + 0.016 * u * u * v + 0.006 * v * v
			row.append(p)
		top_rows.append(row)
	var th: float = 0.0042
	var slab: Array = []
	for j: int in nv:
		var top: PackedVector3Array = top_rows[j]
		var ring: PackedVector3Array = PackedVector3Array()
		var t: float = th * (1.0 - 0.45 * float(j) / float(nv - 1))
		for i: int in nu:
			ring.append(top[i])
		for i: int in range(nu - 1, -1, -1):
			ring.append(top[i] - Vector3(0.0, t, 0.0))
		slab.append(ring)
	# Close the outer edge: a last row pinched to the rim line.
	var last: PackedVector3Array = slab[nv - 1]
	var tip: PackedVector3Array = PackedVector3Array()
	for i: int in last.size():
		var k: int = i if i < nu else 2 * nu - 1 - i
		tip.append((top_rows[nv - 1] as PackedVector3Array)[k] - Vector3(0.0, th * 0.27, 0.0))
	slab.append(tip)
	var mid: PackedVector3Array = slab[2]
	var nrm: Vector3 = (mid[1] - mid[0]).cross((slab[3] as PackedVector3Array)[0] - mid[0])
	SkaterParts.part(holder, "AccCapBrimMesh", SkaterParts.grid(slab, true, nrm.y < 0.0), Vector3.ZERO, mats, "acc_cap_brim")
	# Seams: six panels meeting at the button.
	for s: int in 6:
		var az: float = brim_az + deg_to_rad(30.0 + 60.0 * float(s))
		var el0: float = _az_el(_at_height(bt, az, cap_band_y(az, forward), CAP_OUT)).y
		var pts: PackedVector3Array = PackedVector3Array()
		var ws: PackedFloat32Array = PackedFloat32Array()
		var ts: PackedFloat32Array = PackedFloat32Array()
		var nn: PackedVector3Array = PackedVector3Array()
		for k: int in 6:
			var f: float = float(k) / 5.0
			var el: float = lerpf(el0 + 0.03, deg_to_rad(86.0), f)
			var d: Vector3 = _dir(az, el)
			pts.append(AnimeHead.CENTER + d * (head_r(bt, az, el) + CAP_OUT + 0.004 * sin(PI * f * 0.8) + 0.0008))
			ws.append(0.0011)
			ts.append(0.0005)
			nn.append(d)
		SkaterParts.part(holder, "AccCapSeam%dMesh" % s, AnimeHead.lock_mesh(pts, ws, ts, nn, 0.0, 4, 2), Vector3.ZERO, mats,
				"acc_cap_seam")
	var top_p: Vector3 = AnimeHead.CENTER + Vector3.UP * (head_r(bt, 0.0, deg_to_rad(89.0)) + CAP_OUT + 0.003)
	var button: MeshInstance3D = SkaterParts.part(holder, "AccCapButtonMesh", SkaterParts.sphere_small(0.0065), top_p, mats, "acc_cap_seam")
	button.scale = Vector3(1.0, 0.45, 1.0)
	# Logo patch on the front panel (above the brim).
	var le: float = deg_to_rad(28.0)
	var lp: Vector3 = AnimeHead.CENTER + _dir(brim_az, le) * (head_r(bt, brim_az, le) + CAP_OUT + 0.003)
	var logo: MeshInstance3D = SkaterParts.part(holder, "AccCapLogoMesh", SkaterParts.sphere_small(0.013), lp, mats, "acc_cap_logo")
	logo.basis = Basis.looking_at(_dir(brim_az, le), Vector3.UP)
	logo.scale = Vector3(1.0, 0.8, 0.12)
	# Snapback strap across the bottom of the opening, with a snap.
	var rear: float = brim_az + PI
	var strap: PackedVector3Array = PackedVector3Array()
	var sw: PackedFloat32Array = PackedFloat32Array()
	var st: PackedFloat32Array = PackedFloat32Array()
	var sn: PackedVector3Array = PackedVector3Array()
	for k: int in 7:
		var az: float = rear + deg_to_rad(-30.0 + 10.0 * float(k))
		var y: float = cap_band_y(rear + deg_to_rad(31.0), forward) + 0.004
		var p: Vector3 = _at_height(bt, az, y, CAP_OUT - 0.001)
		strap.append(p)
		sw.append(0.0042)
		st.append(0.0012)
		sn.append((p - AnimeHead.CENTER).normalized())
	SkaterParts.part(holder, "AccCapStrapMesh", AnimeHead.lock_mesh(strap, sw, st, sn, 0.0, 6, 2), Vector3.ZERO, mats, "acc_cap_seam")
	SkaterParts.part(holder, "AccCapSnapMesh", SkaterParts.sphere_small(0.0035), strap[3] + sn[3] * 0.002, mats, "acc_cap_logo")
	var sun: Node3D = holder.get_parent().get_node_or_null("AccSunnies") as Node3D
	if sun != null and str(sun.get_meta("sunnies_style", "")) == "pushed_up":
		# Sunglasses pushed up would sit through the crown: wear them instead.
		var mats_ref: Dictionary = mats
		holder.get_parent().remove_child(sun)
		sun.free()
		_build_sunnies({"HeadModel": holder.get_parent()}, bt, mats_ref, true)


# --- headband -----------------------------------------------------------------------------------------------

## Height of the headband's middle at azimuth az: across the forehead above the bangs' roots, lower at the back.
static func headband_y(az: float) -> float:
	return lerpf(0.146, 0.098, (1.0 - cos(az)) * 0.5)


## Terry sweatband round the head over the hair, a stripe round its middle; the hair under it is tucked in.
static func headband(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	var base: Color = Wardrobe.mat(mats, "acc_headband", Color("FF7EB6")).albedo_color
	Wardrobe.mat(mats, "acc_headband_stripe", Color(1.0, 0.98, 0.95) if base.get_luminance() < 0.8 else Color(1.0, 0.45, 0.6))
	var bt: String = body_type if AnimeHead.FACES.has(body_type) else "female"
	AnimeHead.use_body(bt)
	var model: Node3D = rig["HeadModel"]
	var holder: Node3D = SkaterParts.joint(model, "AccHeadband", Vector3.ZERO)
	var limit: Callable = func(p: Vector3) -> float:
		var ae: Vector2 = _az_el(p)
		var dy: float = absf(p.y - headband_y(ae.x))
		if dy > BAND_HH + 0.01:
			return -1.0
		var k: float = smoothstep(BAND_HH + 0.01, BAND_HH, dy)
		return head_r(bt, ae.x, ae.y) + BAND_IN + (1.0 - k) * 0.02
	tuck_hair(rig, limit, false)
	var cols: int = 48
	var prof: Array = [[-1.0, 0.0], [-1.0, 1.0], [0.0, 1.25], [1.0, 1.0], [1.0, 0.0]]
	var rows: Array = []
	for pr: Array in prof:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			var az: float = -PI + TAU * float(k) / float(cols)
			var y: float = headband_y(az) + float(pr[0]) * BAND_HH
			ring.append(_at_height(bt, az, y, BAND_IN + BAND_T * float(pr[1])))
		rows.append(ring)
	rows.append(rows[0])
	SkaterParts.part(holder, "AccHeadbandMesh", SkaterParts.grid(rows, true, false), Vector3.ZERO, mats, "acc_headband")
	var stripe: Array = []
	for f: float in [-0.22, 0.22]:
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in cols:
			var az: float = -PI + TAU * float(k) / float(cols)
			ring.append(_at_height(bt, az, headband_y(az) + f * BAND_HH, BAND_IN + BAND_T * 1.25 + 0.0014))
		stripe.append(ring)
	var s0: PackedVector3Array = stripe[0]
	var s1: PackedVector3Array = stripe[1]
	var nrm: Vector3 = (s0[1] - s0[0]).cross(s1[0] - s0[0])
	SkaterParts.part(holder, "AccHeadbandStripeMesh", SkaterParts.grid(stripe, true, nrm.dot(s0[0] - AnimeHead.CENTER) > 0.0),
			Vector3.ZERO, mats, "acc_headband_stripe")


# --- sunnies ------------------------------------------------------------------------------------------------

## Anime shades pushed up on the head (eyes show); worn on the eyes instead when the skater also wears a cap.
static func sunnies(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	var model: Node3D = rig["HeadModel"]
	_build_sunnies(rig, body_type, mats, model.get_node_or_null("AccCap") != null)


## The shades worn over the eyes.
static func sunnies_on_eyes(rig: Dictionary, body_type: String, mats: Dictionary) -> void:
	_build_sunnies(rig, body_type, mats, true)


## Lens outline in face coordinates for side s: a soft wide shape, flat on top, rounder below, the outer top corner
## pointed up a touch.
static func _lens_outline(s: float, eye_x: float, eye_y: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var cx: float = s * (eye_x + 0.002)
	var cy: float = eye_y + 0.001
	var n: int = 20
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var c: float = cos(a)
		var sn: float = sin(a)
		var rx: float = 0.0235
		var ry: float = 0.0145 if sn > 0.0 else 0.0175
		var x: float = signf(c) * pow(absf(c), 0.6) * rx
		var y: float = signf(sn) * pow(absf(sn), 0.75 if sn > 0.0 else 0.9) * ry
		y += 0.0035 * maxf(c * s, 0.0) * maxf(sn, 0.0)
		out.append(Vector2(cx + s * x * signf(s), cy + y))
	return out


static func _face_pt(q: Vector2, lift: float) -> Vector3:
	return Vector3(q.x, q.y, AnimeHead.face_z(q.x, q.y)) + AnimeHead.face_normal(q.x, q.y) * lift


static func _build_sunnies(rig: Dictionary, body_type: String, mats: Dictionary, worn: bool) -> void:
	var frame: Color = Wardrobe.mat(mats, "acc_sunnies", Color("1B1B2F")).albedo_color
	Wardrobe.mat(mats, "acc_sunnies_lens", Color(0.1, 0.11, 0.18).lerp(frame, 0.25))
	Wardrobe.mat(mats, "acc_sunnies_shine", Color(0.82, 0.92, 1.0))
	var bt: String = body_type if AnimeHead.FACES.has(body_type) else "female"
	AnimeHead.use_body(bt)
	var f: Dictionary = AnimeHead.FACES[bt]
	var eye_x: float = float(f["eye_x"])
	var eye_y: float = float(f["eye_y"])
	var model: Node3D = rig["HeadModel"]
	var holder: Node3D = SkaterParts.joint(model, "AccSunnies", Vector3.ZERO)
	holder.set_meta("sunnies_style", "worn" if worn else "pushed_up")
	var front: Node3D = SkaterParts.joint(holder, "AccSunniesFront", Vector3.ZERO)
	var lift: float = 0.014
	var hinge: Array = []
	var frame_pts: PackedVector3Array = PackedVector3Array()
	for s: float in [-1.0, 1.0]:
		var tag: String = "L" if s < 0.0 else "R"
		var outline: PackedVector2Array = _lens_outline(s, eye_x, eye_y)
		var c2: Vector2 = Vector2.ZERO
		for q: Vector2 in outline:
			c2 += q
		c2 /= float(outline.size())
		# Lens: filled from its centre, both faces.
		var rows: Array = []
		for k: float in [0.0, 0.5, 1.0]:
			var ring: PackedVector3Array = PackedVector3Array()
			for q: Vector2 in outline:
				ring.append(_face_pt(c2 + (q - c2) * k, lift))
			rows.append(ring)
		SkaterParts.part(front, "AccSunniesLens" + tag + "Mesh", _two_sided(rows), Vector3.ZERO, mats, "acc_sunnies_lens")
		# Shine: a slanted streak across the upper lens.
		var shine: Array = []
		for k: int in 2:
			var ring: PackedVector3Array = PackedVector3Array()
			for i: int in 5:
				var u: float = -1.0 + 0.5 * float(i)
				var q: Vector2 = c2 + Vector2(u * 0.014 + (0.004 if k == 1 else 0.0) * s, 0.005 - u * 0.006 + (0.0035 if k == 1 else 0.0))
				ring.append(_face_pt(q, lift + 0.0006))
			shine.append(ring)
		SkaterParts.part(front, "AccSunniesShine" + tag + "Mesh", _two_sided(shine, false), Vector3.ZERO, mats, "acc_sunnies_shine")
		# Rim: a closed loop round the lens, thicker on top (a brow bar).
		var rim: PackedVector3Array = PackedVector3Array()
		var rw: PackedFloat32Array = PackedFloat32Array()
		var rt: PackedFloat32Array = PackedFloat32Array()
		var rn: PackedVector3Array = PackedVector3Array()
		for i: int in outline.size() + 1:
			var q: Vector2 = outline[i % outline.size()]
			var p: Vector3 = _face_pt(q, lift - 0.0004)
			rim.append(p)
			var top: float = clampf((q.y - c2.y) / 0.012, 0.0, 1.0)
			rw.append(0.0013 + 0.0012 * top)
			rt.append(0.0016 + 0.0006 * top)
			rn.append(AnimeHead.face_normal(q.x, q.y))
		SkaterParts.part(front, "AccSunniesRim" + tag + "Mesh", AnimeHead.lock_mesh(rim, rw, rt, rn, 0.0, 6, 2), Vector3.ZERO, mats,
				"acc_sunnies")
		var outer: Vector2 = Vector2(s * (eye_x + 0.0245), eye_y + 0.007)
		hinge.append(_face_pt(outer, lift - 0.002))
		frame_pts.append(_face_pt(Vector2(s * 0.016, eye_y + 0.009), lift - 0.0004))
	# Bridge over the nose.
	var bridge: PackedVector3Array = PackedVector3Array([frame_pts[0], _face_pt(Vector2(0.0, eye_y + 0.011), lift + 0.0005), frame_pts[1]])
	SkaterParts.part(front, "AccSunniesFrameMesh", AnimeHead.lock_mesh(bridge, PackedFloat32Array([0.0016, 0.0014, 0.0016]),
			PackedFloat32Array([0.0014, 0.0012, 0.0014]), PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD]), 0.0, 6, 4),
			Vector3.ZERO, mats, "acc_sunnies")
	if not worn:
		# Pushed up: the front swings up over the forehead to sit on the hair, facing up and forward.
		var tilt: float = deg_to_rad(52.0)
		var b: Basis = Basis(Vector3.RIGHT, tilt)
		var lens_c: Vector3 = _face_pt(Vector2(0.0, eye_y), lift)
		var target_el: float = deg_to_rad(44.0)
		var target: Vector3 = AnimeHead.CENTER + _dir(0.0, target_el) * (head_r(bt, 0.0, target_el) + 0.034)
		front.transform = Transform3D(b, target - b * lens_c)
		for i: int in hinge.size():
			hinge[i] = front.transform * (hinge[i] as Vector3)
	# Arms: from each hinge back along the side of the head to behind the ear (under the hair).
	for i: int in 2:
		var s: float = -1.0 if i == 0 else 1.0
		var tag: String = "L" if s < 0.0 else "R"
		var h: Vector3 = hinge[i]
		var pts: PackedVector3Array = PackedVector3Array([h])
		var nn: PackedVector3Array = PackedVector3Array([Vector3(s, 0.0, 0.0)])
		var az_h: float = _az_el(h).x
		for k: int in range(1, 6):
			var t: float = float(k) / 5.0
			var az: float = lerpf(az_h, s * deg_to_rad(112.0), t)
			var y: float = lerpf(h.y, 0.066 if worn else 0.112, t) - (0.012 * pow(t, 3.0) if worn else 0.0)
			var p: Vector3 = _at_height(bt, az, y, 0.004 if worn else 0.02)
			pts.append(p.lerp(h, pow(1.0 - t, 3.0) * 0.6))
			nn.append((p - AnimeHead.CENTER).normalized())
		var ws: PackedFloat32Array = PackedFloat32Array([0.0018, 0.0016, 0.0015, 0.0014, 0.0013, 0.0011])
		var ts: PackedFloat32Array = PackedFloat32Array([0.0012, 0.0011, 0.001, 0.001, 0.001, 0.0009])
		SkaterParts.part(holder, "AccSunniesArm" + tag + "Mesh", AnimeHead.lock_mesh(pts, ws, ts, nn, 0.0, 6, 3), Vector3.ZERO, mats,
				"acc_sunnies")


## Grid seen from both sides (a front copy and a flipped back copy).
static func _two_sided(rows: Array, _closed: bool = true) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for flip: bool in [false, true]:
		for i: int in rows.size() - 1:
			var r0: PackedVector3Array = rows[i]
			var r1: PackedVector3Array = rows[i + 1]
			var cols: int = r0.size() if _closed else r0.size() - 1
			for k: int in cols:
				var k2: int = (k + 1) % r0.size()
				var quad: Array = [[r0[k], r0[k2], r1[k]], [r0[k2], r1[k2], r1[k]]]
				for tri: Array in quad:
					var a: Vector3 = tri[0]
					var b: Vector3 = tri[1]
					var c: Vector3 = tri[2]
					var n: Vector3 = (b - a).cross(c - a).normalized()
					if flip:
						n = -n
						var tmp: Vector3 = b
						b = c
						c = tmp
					st.set_normal(n)
					st.add_vertex(a)
					st.set_normal(n)
					st.add_vertex(b)
					st.set_normal(n)
					st.add_vertex(c)
	return st.commit()
