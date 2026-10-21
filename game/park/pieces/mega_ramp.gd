class_name MegaRamp
extends RefCounted
## X Games style mega ramp with a drop-in. Footprint x in [0, width], z in [0, length()], ground at y = 0.
##
## THE SKATER TRAVELS ALONG +Z. This is the reverse of the quarterpipe's face: the drop-in deck is at the low-z end,
## and the quarter pipe sits at the high-z end with its bowl facing -Z (toward the skater) and its deck behind the
## coping at +Z. QuarterPipe's bowl faces +Z; this one is mirrored in z.
##
## Sections in z order (all z values come from _layout):
##   start deck  y = start_height, z in [0, DECK_LEN]           drop-in spot; the tower under it is filled to the ground
##   roll-in     60 deg arc from the deck edge down to the ground (body "RollIn"); visual side rails along it
##   flat        short floor
##   kicker      concave arc up to KICK_H at KICK_DEG            body "Kicker"; its lip is at z = lip_z
##   gap         open air from the lip to the landing top edge  gap floor at ground, painted MEGA, zone "mega_gap"
##   landing     30 deg downhill from LAND_H, easing to flat     body "Landing"; its top edge is at z = landing_z
##   run-out     flat floor
##   quarter pipe radius 0.8 * qp_height, coping on the lip at z = qp_lip_z, deck behind (body "QuarterPipe"),
##               GrindRail "Coping" on the lip, zone "mega_qp_air" above the coping.
##
## Pairing zones: "mega_land" (the landing's top, 6 m) and "mega_runout" (the flat before the quarter pipe).
##
## The open air is exactly `gap` metres: the landing top edge sits at lip + gap. The sim (tests in
## /tmp/mega_agent) has the skater leave the lip at about 18 m/s, 35 degrees, clear the top edge by ~1.8 m and come
## down onto the lower part of the 30 degree slope.

const DECK_LEN: float = 4.0  ## start deck depth (z 0 to 4)
const DROP_Z: float = 2.5  ## drop-in spot on the deck: this far from the back edge (1.5 m from the lip)
const ROLL_STEPS: int = 40
const FLAT_LEN: float = 2.0  ## short floor between the roll-in and the kicker
const KICK_H: float = 3.5  ## lip height
const KICK_DEG: float = 35.0  ## lip angle
const KICK_STEPS: int = 16
const LAND_H: float = 3.0  ## landing top edge height
const LAND_DEG: float = 30.0  ## landing slope at its top edge
const LAND_STEPS: int = 24
const RUNOUT_LEN: float = 10.0  ## flat between the landing and the quarter pipe
const RUNOUT_ZONE_START: float = 5.0  ## mega_runout begins this far past the landing, so the Mega Gap combo close (0.35 s) is over first
const QP_RADIUS_FRAC: float = 0.8  ## quarter pipe radius = this * qp_height
const QP_DECK: float = 3.0  ## deck behind the coping
const SIDE_RAIL_H: float = 0.9
const SIDE_RAIL_INSET: float = 0.15
const LADDER_X0: float = 0.4  ## ladder rails sit at these x (inside the footprint)
const LADDER_X1: float = 1.2
const LADDER_RUNG: float = 0.5


## Shared z-positions and radii. build(), length() and drop_in_transform() all read from here.
static func _layout(gap: float, start_height: float, qp_height: float) -> Dictionary:
	var roll_r: float = 2.0 * start_height  # 60 deg arc with drop R * (1 - cos 60) = start_height
	var roll_len: float = roll_r * sin(deg_to_rad(60.0))
	var roll_end: float = DECK_LEN + roll_len
	var kick_z0: float = roll_end + FLAT_LEN
	var kick_r: float = KICK_H / (1.0 - cos(deg_to_rad(KICK_DEG)))
	var lip_z: float = kick_z0 + kick_r * sin(deg_to_rad(KICK_DEG))
	var land_top_z: float = lip_z + gap
	var land_r: float = LAND_H / (1.0 - cos(deg_to_rad(LAND_DEG)))
	var land_bottom_z: float = land_top_z + land_r * sin(deg_to_rad(LAND_DEG))
	var qp_a: float = land_bottom_z + RUNOUT_LEN
	var qp_r: float = qp_height * QP_RADIUS_FRAC
	var qp_lip_z: float = qp_a + qp_r
	var end_z: float = qp_lip_z + QP_DECK
	return {
		"roll_r": roll_r, "roll_end": roll_end, "kick_z0": kick_z0, "kick_r": kick_r, "lip_z": lip_z,
		"land_top_z": land_top_z, "land_r": land_r, "land_bottom_z": land_bottom_z,
		"qp_a": qp_a, "qp_r": qp_r, "qp_lip_z": qp_lip_z, "end_z": end_z,
	}


## Total footprint length along Z (back of the start tower at z = 0 to the back of the quarter pipe deck).
static func length(width: float = 8.0, start_height: float = 18.0, gap: float = 14.0, qp_height: float = 8.0) -> float:
	return float(_layout(gap, start_height, qp_height)["end_z"])


## Where the skater spawns on the start deck: near the middle of the deck, DROP_Z from the back edge, facing +Z.
## The skater's forward is -basis.z, so the basis is a 180 degree turn about Y.
static func drop_in_transform(width: float = 8.0, start_height: float = 18.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3(width * 0.5, start_height, DROP_Z))


static func build(width: float = 8.0, start_height: float = 18.0, gap: float = 14.0, qp_height: float = 8.0) -> Node3D:
	var root := Node3D.new()
	root.name = "MegaRamp"
	var L: Dictionary = _layout(gap, start_height, qp_height)
	root.add_child(_roll_in(width, start_height, L))
	root.add_child(PieceKit.floor_pad(Vector3(0.0, -0.5, float(L["roll_end"])), Vector3(width, 0.5, FLAT_LEN), PieceKit.CONCRETE, "BaseFloor"))
	root.add_child(_kicker(width, L))
	_gap(root, width, L)
	root.add_child(_landing(width, L))
	# Extra gap zones so the data can pair them: "mega_land" over the landing's top, "mega_runout" over the flat after it.
	root.add_child(PieceKit.gap_zone("mega_land", Vector3(0.0, 0.0, float(L["land_top_z"])), Vector3(width, 6.0, 6.0)))
	root.add_child(PieceKit.gap_zone("mega_runout", Vector3(0.0, 0.0, float(L["land_bottom_z"]) + RUNOUT_ZONE_START), Vector3(width, 2.0, RUNOUT_LEN - RUNOUT_ZONE_START - 2.0)))
	root.add_child(PieceKit.floor_pad(Vector3(0.0, -0.5, float(L["land_bottom_z"])), Vector3(width, 0.5, RUNOUT_LEN), PieceKit.CONCRETE, "RunOutFloor"))
	_quarter_pipe(root, width, qp_height, L)
	return root


## The (y, z) profile of the roll-in arc from the deck edge (y = start_height, z = DECK_LEN) to the ground.
## Each point is Vector2(y, z). The arc turns 60 degrees: slope starts at 60 and eases to flat at the bottom.
static func _roll_curve(start_height: float) -> PackedVector2Array:
	var r: float = 2.0 * start_height
	var a0: float = deg_to_rad(60.0)
	var pts := PackedVector2Array()
	for i: int in ROLL_STEPS + 1:
		var phi: float = a0 * (1.0 - float(i) / float(ROLL_STEPS))
		var z: float = DECK_LEN + r * (sin(a0) - sin(phi))
		var y: float = start_height - r * (cos(phi) - cos(a0))
		pts.append(Vector2(y, z))
	return pts


static func _roll_in(width: float, start_height: float, L: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "RollInPiece"
	# Solid profile (y, z): back bottom, back top, the deck, the roll-in arc, then the ground back to the start.
	# The anchor at z = 0 is the start of a fan that sees the whole region (height is non-increasing in z).
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(start_height, 0.0)])
	var curve: PackedVector2Array = _roll_curve(start_height)
	for p: Vector2 in curve:
		prof.append(p)
	var tower: StaticBody3D = shade_by_height(PieceKit.body(PieceKit.extrude_profile(prof, width), PieceKit.RAMP_SIDE, "RollIn"), PieceKit.RAMP_SIDE, start_height, 0.74, 1.12)
	node.add_child(tower)
	# Visual handrails along the roll-in (no collision, no grind rails).
	for x: float in [SIDE_RAIL_INSET, width - SIDE_RAIL_INSET]:
		var i: int = 0
		while i < ROLL_STEPS:
			var j: int = mini(i + 4, ROLL_STEPS)
			var a := Vector3(x, curve[i].x + SIDE_RAIL_H, curve[i].y)
			var b := Vector3(x, curve[j].x + SIDE_RAIL_H, curve[j].y)
			var rail: Node3D = PieceKit.round_rail(a, b, 0.04, PieceKit.METAL, "SideRail%d" % i)
			rail.get_node("Line").free()
			node.add_child(rail)
			i = j
	# Visual ladder up the back face of the start tower (rails and rungs stick out 0.14 m behind z = 0).
	for lx: float in [LADDER_X0, LADDER_X1]:
		node.add_child(_visual_box(Vector3(lx - 0.06, 0.0, -0.14), Vector3(0.12, start_height, 0.1), PieceKit.METAL, "LadderRail"))
	var rung_y: float = LADDER_RUNG
	while rung_y < start_height - 0.5:
		node.add_child(_visual_box(Vector3(LADDER_X0, rung_y, -0.12), Vector3(LADDER_X1 - LADDER_X0, 0.05, 0.08), PieceKit.METAL, "Rung"))
		rung_y += LADDER_RUNG
	_dress_tower(node, width, start_height, curve)
	return node


## Height of the tower profile at z (the deck, then the roll-in arc), linearly interpolated.
static func _tower_y(curve: PackedVector2Array, start_height: float, z: float) -> float:
	if z <= DECK_LEN:
		return start_height
	for i: int in range(1, curve.size()):
		if z <= curve[i].y:
			var u: float = (z - curve[i - 1].y) / maxf(curve[i].y - curve[i - 1].y, 0.0001)
			return lerpf(curve[i - 1].x, curve[i].x, u)
	return 0.0


## First z at which the tower profile has fallen to y (the deck edge when y is at or above the deck).
static func _tower_z_at(curve: PackedVector2Array, start_height: float, y: float) -> float:
	if y >= start_height:
		return DECK_LEN
	for i: int in range(1, curve.size()):
		if curve[i].x <= y:
			var u: float = (curve[i - 1].x - y) / maxf(curve[i - 1].x - curve[i].x, 0.0001)
			return lerpf(curve[i - 1].y, curve[i].y, u)
	return float(curve[curve.size() - 1].y)


## Scaffolding-style trim and banners on the roll-in tower. Visual only: no collision, no rails.
static func _dress_tower(node: Node3D, width: float, start_height: float, curve: PackedVector2Array) -> void:
	var trim := Node3D.new()
	trim.name = "TowerTrim"
	node.add_child(trim)
	var off: float = 0.05
	# coloured bands on both side faces, each stopping where the roll-in curve passes under it
	var band_h: float = 1.0
	var by: float = 2.0
	var k: int = 0
	while by + band_h < start_height:
		var zc: float = _tower_z_at(curve, start_height, by + band_h) - 0.05
		var col: Color = PieceKit.PAINT_YELLOW if k % 2 == 0 else PieceKit.PAINT_RED
		for x0: float in [-off, width]:
			trim.add_child(_visual_box(Vector3(x0, by, 0.0), Vector3(off, band_h, zc), col, "Band%d" % k))
		by += 4.0
		k += 1
	# scaffold poles and braces on the side faces, just outside the bands
	var pole: float = 0.12
	var pole_zs: Array[float] = [0.3, 4.0, 9.0, 14.0, 19.0]
	for sx: float in [-off - pole, width + off]:
		for pz: float in pole_zs:
			var top: float = _tower_y(curve, start_height, pz)
			if top < 1.0:
				continue
			trim.add_child(_visual_box(Vector3(sx, 0.0, pz - pole * 0.5), Vector3(pole, top, pole), PieceKit.METAL, "Pole"))
		# horizontal rails every 3 m between the first pole and the last pole that reaches that height
		var ry: float = 3.0
		while ry < start_height - 0.5:
			var zend: float = minf(_tower_z_at(curve, start_height, ry), pole_zs[pole_zs.size() - 1])
			if zend > 1.0:
				trim.add_child(_visual_box(Vector3(sx, ry - 0.04, 0.3), Vector3(pole, 0.08, zend - 0.3), PieceKit.METAL, "Brace"))
			ry += 3.0
		# diagonal cross braces in each bay between neighbouring poles
		for bi: int in range(pole_zs.size() - 1):
			var z0: float = pole_zs[bi]
			var z1: float = pole_zs[bi + 1]
			var y_hi: float = minf(_tower_y(curve, start_height, z1), start_height - 0.5)
			var y_lo: float = 0.0
			if y_hi - y_lo < 2.0:
				continue
			var dz: float = z1 - z0
			var dy: float = y_hi - y_lo
			var mi := _visual_box(Vector3(-pole * 0.5, 0.0, -0.04), Vector3(pole, 0.08, sqrt(dz * dz + dy * dy)), PieceKit.METAL, "Cross")
			var dir := Vector3(0.0, dy, dz).normalized()
			mi.transform = Transform3D(Basis.looking_at(dir, Vector3.RIGHT), Vector3(sx + pole * 0.5, (y_lo + y_hi) * 0.5, (z0 + z1) * 0.5))
			trim.add_child(mi)
	# banners on the back face of the tower (z < 0)
	var back: Array = [["MEGA RAMP", PieceKit.PAINT_RED, 0.4], ["DROP IN", PieceKit.PAINT_PURPLE, 0.4]]
	for i: int in back.size():
		var cfg: Array = back[i]
		var bh: float = 3.0
		var y0: float = start_height - 1.2 - bh - float(i) * (bh + 1.0)
		if y0 < 1.5:
			continue
		trim.add_child(_visual_box(Vector3(1.6, y0, -0.3), Vector3(width - 2.0, bh, 0.06), cfg[1], "Banner%d" % i))
		var lbl := Label3D.new()
		lbl.name = "BannerText%d" % i
		lbl.text = str(cfg[0])
		lbl.font_size = 96
		lbl.pixel_size = 0.0095
		lbl.outline_size = 24
		lbl.outline_modulate = Toon.INK
		lbl.modulate = Color.WHITE
		lbl.double_sided = true
		lbl.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		lbl.position = Vector3(1.6 + (width - 2.0) * 0.5, y0 + bh * 0.5, -0.35)
		trim.add_child(lbl)
	# hanging banners on the two side faces, plus pennant flags on the deck corners
	for sx: float in [-off - pole - 0.08, width + off + pole + 0.02]:
		for j: int in 2:
			var col2: Color = PieceKit.PAINT_GREEN if j == 0 else PieceKit.PAINT_PURPLE
			var zb: float = 1.0 + float(j) * 1.9
			var top_y: float = start_height - 0.8
			trim.add_child(_visual_box(Vector3(sx, top_y - 4.0, zb), Vector3(0.06, 4.0, 1.4), col2, "SideBanner"))
	for fx: float in [0.3, width - 0.3]:
		trim.add_child(_visual_box(Vector3(fx - 0.04, start_height, 0.3), Vector3(0.08, 2.4, 0.08), PieceKit.METAL, "FlagPole"))
		trim.add_child(_visual_box(Vector3(fx - 0.02, start_height + 1.5, 0.38), Vector3(0.04, 0.8, 1.1), PieceKit.PAINT_YELLOW, "Flag"))


static func _kicker(width: float, L: Dictionary) -> StaticBody3D:
	# Concave arc from the ground at kick_z0 (horizontal) up to KICK_H at the lip (KICK_DEG). Solid below it.
	# Anchor at the lip's ground point: the height rises with z, so this fan sees the whole region.
	var r: float = float(L["kick_r"])
	var z0: float = float(L["kick_z0"])
	var th: float = deg_to_rad(KICK_DEG)
	var prof := PackedVector2Array([Vector2(0.0, float(L["lip_z"]))])
	for i: int in KICK_STEPS + 1:
		var a: float = th * float(i) / float(KICK_STEPS)
		prof.append(Vector2(r * (1.0 - cos(a)), z0 + r * sin(a)))
	return shade_by_height(PieceKit.body(PieceKit.extrude_profile(prof, width), PieceKit.PAINT_YELLOW, "Kicker"), PieceKit.PAINT_YELLOW, KICK_H, 0.78, 1.0)


static func _landing(width: float, L: Dictionary) -> StaticBody3D:
	# Convex-down valley: from the top edge (LAND_H at land_top_z, 30 deg down) easing to flat at land_bottom_z.
	# Anchor at the top edge's ground point: height falls with z, so this fan sees the whole region.
	var r: float = float(L["land_r"])
	var top_z: float = float(L["land_top_z"])
	var bottom_z: float = float(L["land_bottom_z"])
	var th: float = deg_to_rad(LAND_DEG)
	var prof := PackedVector2Array([Vector2(0.0, top_z)])
	for i: int in LAND_STEPS + 1:
		var b: float = th * (1.0 - float(i) / float(LAND_STEPS))
		prof.append(Vector2(r * (1.0 - cos(b)), bottom_z - r * sin(b)))
	return shade_by_height(PieceKit.body(PieceKit.extrude_profile(prof, width), PieceKit.RAMP_WOOD, "Landing"), PieceKit.RAMP_WOOD, LAND_H, 0.8, 1.05)


static func _gap(root: Node3D, width: float, L: Dictionary) -> void:
	var lip: float = float(L["lip_z"])
	var top: float = float(L["land_top_z"])
	var span: float = top - lip
	root.add_child(PieceKit.floor_pad(Vector3(0.0, -0.5, lip), Vector3(width, 0.5, span), PieceKit.CONCRETE, "GapFloor"))
	var mid: float = (lip + top) * 0.5
	# Painted MEGA stripe on the gap floor (visual only).
	root.add_child(_visual_box(Vector3(0.5, 0.0, mid - 1.6), Vector3(width - 1.0, 0.02, 3.2), PieceKit.PAINT_RED, "MegaStripe"))
	var lbl := Label3D.new()
	lbl.name = "MegaLabel"
	lbl.text = "MEGA"
	lbl.font_size = 200
	lbl.pixel_size = 0.012
	lbl.outline_size = 24
	lbl.outline_modulate = Toon.INK
	lbl.double_sided = true
	lbl.modulate = Color.WHITE
	lbl.position = Vector3(width * 0.5, 0.03, mid)
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(lbl)
	root.add_child(PieceKit.gap_zone("mega_gap", Vector3(0.0, 0.5, lip), Vector3(width, 8.0, span)))


static func _quarter_pipe(root: Node3D, width: float, qp_height: float, L: Dictionary) -> void:
	var a: float = float(L["qp_a"])
	var r: float = float(L["qp_r"])
	var lip_z: float = float(L["qp_lip_z"])
	var end_z: float = float(L["end_z"])
	# Mirror of QuarterPipe's profile in z (its bowl faces +Z; this one faces -Z). Anchor at the back deck end.
	var prof := PackedVector2Array([Vector2(0.0, end_z), Vector2(0.0, a)])
	for i: int in range(1, 25):
		var th: float = deg_to_rad(90.0) * float(i) / 24.0
		prof.append(Vector2(r * (1.0 - cos(th)), a + r * sin(th)))
	prof.append(Vector2(qp_height, lip_z))
	prof.append(Vector2(qp_height, end_z))
	root.add_child(shade_by_height(PieceKit.body(PieceKit.extrude_profile(prof, width), PieceKit.RAMP_WOOD, "QuarterPipe"), PieceKit.RAMP_WOOD, qp_height, 0.72, 1.05))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, qp_height, lip_z), Vector3(width, qp_height, lip_z)]), "coping", "Coping"))
	var pipe: Node3D = PieceKit.round_rail(Vector3(0.0, qp_height, lip_z), Vector3(width, qp_height, lip_z), 0.05, PieceKit.COPING, "CopingPipe")
	# the visual pipe only; the GrindRail above is the coping line
	pipe.get_node("Line").free()
	root.add_child(pipe)
	root.add_child(PieceKit.gap_zone("mega_qp_air", Vector3(0.0, qp_height, lip_z - 1.0), Vector3(width, 3.0, 2.0)))


## Gives a body's mesh a vertical gradient through vertex colour: a darker, cooler base where the surface meets the
## ground, and a lighter tone near the top (coping), so big flat surfaces read as form instead of one flat colour.
static func shade_by_height(sb: StaticBody3D, color: Color, top_y: float, base_mul: float = 0.66, top_mul: float = 1.1) -> StaticBody3D:
	var mi: MeshInstance3D = sb.get_node("Mesh") as MeshInstance3D
	var src: ArrayMesh = mi.mesh as ArrayMesh
	if src == null or src.get_surface_count() == 0:
		return sb
	var arrays: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for i: int in verts.size():
		var t: float = clampf(verts[i].y / maxf(top_y, 0.01), 0.0, 1.0)
		var m: float = lerpf(base_mul, top_mul, smoothstep(0.0, 1.0, t))
		# darker bases also shift cooler/more saturated, lighter tops warm up a touch
		cols[i] = Color(clampf(m * lerpf(0.92, 1.03, t), 0.0, 1.5), clampf(m, 0.0, 1.5), clampf(m * lerpf(1.04, 0.97, t), 0.0, 1.5))
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = out
	mi.material_override = Toon.material_vc(color)
	return sb


static func _visual_box(min_corner: Vector3, size: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Toon.material(color)
	mi.position = min_corner + size * 0.5
	return mi
