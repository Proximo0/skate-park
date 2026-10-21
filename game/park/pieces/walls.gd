class_name Walls
extends RefCounted
## Wall-type park pieces: a painted wallride wall, a straight bank, a chain-link fence and a sign on two posts.
## Each builder returns a Node3D whose origin is at ground level at the back-left corner. Footprints are x in
## [0, length] (or width) and z in [0, depth], with the riding face toward +Z. Visual-only decoration has no
## collision; collision comes from solid bodies only (see PieceKit).

const WALL_PAINT: Color = Color("fff4df")
const COPING_CAP_HEIGHT: float = 0.12
const WALL_THICKNESS: float = 0.4
const BANK_DECK: float = 1.5
const FENCE_POST_SPACING: float = 2.0
const FENCE_THICKNESS: float = 0.1
const CHAIN_TILE_PX: int = 32
const MURAL_STEP: float = 0.012
const SIGN_POST_HEIGHT: float = 3.4


## A tall painted wall for wallrides, along X. The top front edge carries a "ledge" GrindRail.
static func wallride_wall(length: float = 10.0, height: float = 3.5, thickness: float = WALL_THICKNESS, zone_id: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "WallrideWall"
	root.add_child(PieceKit.box(Vector3.ZERO, Vector3(length, height, thickness), WALL_PAINT, "Wall"))
	root.add_child(PieceKit.box(Vector3(0.0, height, 0.0), Vector3(length, COPING_CAP_HEIGHT, thickness), PieceKit.METAL, "Cap"))
	var cap_top: float = height + COPING_CAP_HEIGHT
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, cap_top, thickness), Vector3(length, cap_top, thickness)]), "ledge", "WallLedge"))
	_add_mural(root, length, height, thickness)
	if zone_id != "":
		root.add_child(PieceKit.gap_zone(zone_id, Vector3(0.0, 0.5, thickness), Vector3(length, 2.5, 1.2)))
	return root


## A straight bank. Its lip is at z = BANK_DECK (top edge at y = height), the flat deck runs back to z = 0, and the
## slope falls toward +Z to the ground. Ride it going -Z from the +Z side. The "coping" GrindRail sits on the lip.
static func bank(width: float = 6.0, length: float = 4.0, height: float = 1.6, zone_id: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "Bank"
	var far: float = BANK_DECK + length
	# profile in (y, z): ground at the far edge, slope up to the lip, flat deck back to z = 0
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, far), Vector2(height, BANK_DECK), Vector2(height, 0.0)])
	root.add_child(PieceKit.body(PieceKit.extrude_profile(prof, width), PieceKit.RAMP_WOOD, "Ramp"))
	root.add_child(PieceKit.rail(PackedVector3Array([Vector3(0.0, height, BANK_DECK), Vector3(width, height, BANK_DECK)]), "coping", "Coping"))
	if zone_id != "":
		root.add_child(PieceKit.gap_zone(zone_id, Vector3(0.0, height, BANK_DECK - 0.5), Vector3(width, 2.5, 2.0)))
	return root


## A chain-link style fence along X: posts, rails and a semi-transparent diamond-mesh panel. Visual only: the park's
## invisible boundary walls (Park.boundary_walls) keep the skater in, so the fence has no collision to snag on.
static func fence(length: float = 10.0, height: float = 1.4) -> Node3D:
	var root := Node3D.new()
	root.name = "Fence"
	var mid_z: float = FENCE_THICKNESS * 0.5
	var spans: int = maxi(int(ceilf(length / FENCE_POST_SPACING)), 1)
	for i: int in spans + 1:
		var x: float = clampf(length * float(i) / float(spans), 0.03, length - 0.03)
		root.add_child(_visual_box(Vector3(x, height * 0.5, mid_z), Vector3(0.06, height + 0.05, 0.06), PieceKit.METAL, "Post%d" % i))
	root.add_child(_visual_box(Vector3(length * 0.5, height, mid_z), Vector3(length, 0.05, 0.05), PieceKit.METAL, "TopRail"))
	root.add_child(_visual_box(Vector3(length * 0.5, 0.05, mid_z), Vector3(length, 0.05, 0.05), PieceKit.METAL, "BottomRail"))
	var quad := QuadMesh.new()
	quad.size = Vector2(length, height)
	var panel := MeshInstance3D.new()
	panel.name = "ChainLink"
	panel.mesh = quad
	panel.position = Vector3(length * 0.5, height * 0.5, mid_z)
	panel.material_override = _chain_material(length, height)
	root.add_child(panel)
	return root


## A big cartoon sign on two solid posts. Only the posts collide. The label is outlined for readability.
static func billboard_sign(text: String = "SKATE PARK", width: float = 6.0) -> Node3D:
	var root := Node3D.new()
	root.name = "BillboardSign"
	root.add_child(PieceKit.box(Vector3(0.2, 0.0, 0.0), Vector3(0.3, SIGN_POST_HEIGHT, 0.3), PieceKit.METAL, "PostLeft"))
	root.add_child(PieceKit.box(Vector3(width - 0.5, 0.0, 0.0), Vector3(0.3, SIGN_POST_HEIGHT, 0.3), PieceKit.METAL, "PostRight"))
	root.add_child(_visual_box(Vector3(width * 0.5, 2.6, 0.2), Vector3(width + 0.16, 1.76, 0.12), PieceKit.PAINT_RED, "Frame"))
	root.add_child(_visual_box(Vector3(width * 0.5, 2.6, 0.27), Vector3(width, 1.6, 0.12), PieceKit.PAINT_YELLOW, "Face"))
	var label := Label3D.new()
	label.name = "Text"
	label.text = text
	label.font_size = 80
	label.pixel_size = 0.01
	label.outline_size = 16
	label.outline_modulate = Color.WHITE
	label.modulate = Toon.INK
	label.position = Vector3(width * 0.5, 2.6, 0.34)
	root.add_child(label)
	return root


## Cartoon mural on the riding face: a smiley sun, a star, a dot, a zig-zag and a dot of paint. Flat shapes sit a
## few millimetres in front of the face, stacked with small depth steps so they do not z-fight.
static func _add_mural(root: Node3D, length: float, height: float, thickness: float) -> void:
	var s: float = height / 3.5
	var z: float = thickness + 0.03
	# smiley sun
	var sun := Vector2(length * 0.15, height * 0.66)
	root.add_child(_face_poly(sun, _ring(sun, 0.8 * s, 28), PieceKit.PAINT_YELLOW, z, "MuralSun"))
	for ex: float in [-0.28, 0.28]:
		var eye := Vector2(sun.x + ex * s, sun.y + 0.2 * s)
		root.add_child(_face_poly(eye, _ring(eye, 0.09 * s, 14), Toon.INK, z + MURAL_STEP * 0.5, "MuralSunEye"))
	var smile_pts := PackedVector2Array()
	for i: int in 6:
		var ang: float = deg_to_rad(lerpf(-150.0, -30.0, float(i) / 5.0))
		smile_pts.append(sun + Vector2(cos(ang), sin(ang)) * 0.42 * s)
	for i: int in smile_pts.size() - 1:
		root.add_child(_bar(smile_pts[i], smile_pts[i + 1], 0.09 * s, Toon.INK, z + MURAL_STEP, "MuralSmile%d" % i))
	# big star
	var star_c := Vector2(length * 0.45, height * 0.3)
	root.add_child(_face_poly(star_c, _star_ring(star_c, 0.7 * s, 0.32 * s, 5), PieceKit.PAINT_PURPLE, z, "MuralStar"))
	# circle
	var circle_c := Vector2(length * 0.72, height * 0.72)
	root.add_child(_face_poly(circle_c, _ring(circle_c, 0.5 * s, 24), PieceKit.PAINT_GREEN, z, "MuralCircle"))
	# zig-zag
	var zz: PackedVector2Array = PackedVector2Array()
	for i: int in 6:
		var x: float = lerpf(length * 0.55, length * 0.95, float(i) / 5.0)
		var y: float = height * 0.5 + (0.3 * s if i % 2 == 0 else -0.3 * s)
		zz.append(Vector2(x, y))
	for i: int in zz.size() - 1:
		root.add_child(_bar(zz[i], zz[i + 1], 0.18 * s, PieceKit.PAINT_RED, z + MURAL_STEP, "MuralZig%d" % i))
	# paint dot
	var dot_c := Vector2(length * 0.92, height * 0.2)
	root.add_child(_face_poly(dot_c, _ring(dot_c, 0.4 * s, 16), PieceKit.PAINT_RED, z, "MuralDot"))


## Points on a circle, as a closed ring.
static func _ring(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for i: int in segments:
		var ang: float = TAU * float(i) / float(segments)
		ring.append(center + Vector2(cos(ang), sin(ang)) * radius)
	return ring


## A star outline alternating outer and inner radii, starting at the top. Star-shaped about its centre.
static func _star_ring(center: Vector2, r_outer: float, r_inner: float, points: int) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for i: int in points * 2:
		var r: float = r_outer if i % 2 == 0 else r_inner
		var ang: float = PI * 0.5 + PI * float(i) / float(points)
		ring.append(center + Vector2(cos(ang), sin(ang)) * r)
	return ring


## A flat fan-triangulated shape in the wall's X-Y plane at depth z. Both windings are emitted so it shows from the
## front whatever the cull convention, with normal +Z. No ink outline: a flat shape's inverted hull would paint it black.
static func _face_poly(center: Vector2, ring: PackedVector2Array, color: Color, z: float, node_name: String) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: Vector3 = Vector3(0.0, 0.0, 1.0)
	var c := Vector3(center.x, center.y, z)
	for i: int in ring.size():
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		var pa := Vector3(a.x, a.y, z)
		var pb := Vector3(b.x, b.y, z)
		st.set_normal(n)
		st.add_vertex(c)
		st.set_normal(n)
		st.add_vertex(pa)
		st.set_normal(n)
		st.add_vertex(pb)
		st.set_normal(n)
		st.add_vertex(c)
		st.set_normal(n)
		st.add_vertex(pb)
		st.set_normal(n)
		st.add_vertex(pa)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = Toon.material(color, false)
	return mi


## A flat rectangle from a to b in the X-Y plane at depth z (a stroke for the smile and the zig-zag).
static func _bar(a: Vector2, b: Vector2, width: float, color: Color, z: float, node_name: String) -> MeshInstance3D:
	var d: Vector2 = b - a
	var m := BoxMesh.new()
	m.size = Vector3(d.length(), width, 0.02)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = m
	mi.material_override = Toon.material(color, false)
	var mid: Vector2 = (a + b) * 0.5
	mi.transform = Transform3D(Basis(Vector3(0.0, 0.0, 1.0), d.angle()), Vector3(mid.x, mid.y, z))
	return mi


## A decorative box without collision.
static func _visual_box(center: Vector3, size: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = m
	mi.position = center
	mi.material_override = Toon.material(color)
	return mi


## Semi-transparent chain-link material: a generated tile of crossed diagonal wires, repeated over the panel.
static func _chain_material(length: float, height: float) -> StandardMaterial3D:
	var img := Image.create(CHAIN_TILE_PX, CHAIN_TILE_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var last: int = CHAIN_TILE_PX - 1
	var wire := Color(1.0, 1.0, 1.0, 1.0)
	for i: int in CHAIN_TILE_PX:
		var j: int = mini(i + 1, last)
		img.set_pixel(i, i, wire)
		img.set_pixel(j, i, wire)
		img.set_pixel(i, last - i, wire)
		img.set_pixel(j, last - i, wire)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.albedo_color = Color(0.85, 0.92, 1.0, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(length * 2.0, height * 2.0, 1.0)
	mat.metallic = 0.3
	mat.roughness = 0.5
	return mat
