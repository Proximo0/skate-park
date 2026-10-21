class_name LoopTrack
extends RefCounted
## Hot Wheels style vertical loop: a flat run-in, a full vertical circle of `radius` standing in the Y-Z plane, then a
## flat run-out. The riding face looks inward (toward the loop centre). The skater goes up the front, over the top
## upside down, and back down the rear. Travel is along -Z, like the other park pieces.
##
## Local frame, metres, origin on the ground (y = 0 is the ground, the riding face sits at y = LIFT):
##   - Run-in starts at (0, LIFT, 0), the back-left corner, and runs along -Z to the loop's tangent point at z = -run_in.
##   - The circle is tangent to the ground there. Its centre is circle_center(radius, run_in) = (0, LIFT + radius, -run_in).
##     That x is the entry edge line; the ribbon itself is width wide, so its centreline sits width / 2 further in +X.
##   - The ribbon's left edge shifts +X by offset * smoothstep(t) over the loop (t = fraction of the circle), so the
##     top of the loop is at x in [offset / 2, offset / 2 + width].
##   - Highest riding-face point: (x = offset / 2 .. +width, y = 2 * radius + LIFT, z = -run_in).
##   - Run-out runs from z = -run_in to z = -run_in - run_out at x in [offset, offset + width].
##   - Riding face, 0.35 m curbs on both edges and the orange slab back form the StaticBody3D "Track" trimesh.
##   - Gap zone "loop_full" covers the loop's box above y = 1 m, x from -0.5 to offset + width + 0.5, and z from
##     -run_in - radius - 0.5 to -run_in + radius + 0.5.


const ORANGE := Color("ff7a00")
const STRIPE := Color("c24e00")
const DASH_COLOUR := Color("ffffff")
const LIFT := 0.02  ## riding face height on every flat part and at the loop's bottom
const CURB_H := 0.35
const CURB_T := 0.08  ## curb thickness across X
const SLAB := 0.1  ## the track is a thin slab, so its outside is orange too
const SHELL_OFF := 0.25  ## how far the outer ribs stand behind the riding face
const RIB_EVERY := 2  ## a rib every this many loop samples (7.5 degrees each at 48 steps)
const SHELL_FROM := 30.0  ## degrees: ribs cover the loop between these angles
const SHELL_TO := 330.0
const STRIPE_W := 0.2
const DASH_LEN := 0.6
const DASH_PERIOD := 1.0
const DASH_W := 0.12
const LEG_R := 0.1
const LEG_DEG: Array[float] = [80.0, 100.0, 260.0, 280.0]  ## kept off the entry and exit ribbons
const DENSE_STEP := 0.05


## Centre of the circle in local space (see the header). Radius and run_in as passed to build().
static func circle_center(radius: float, run_in: float) -> Vector3:
	return Vector3(0.0, LIFT + radius, -run_in)


static func build(radius: float = 4.0, width: float = 3.0, run_in: float = 6.0, run_out: float = 6.0, offset: float = 3.5, steps: int = 48) -> Node3D:
	var n_steps: int = maxi(steps, 8)
	var path: Dictionary = _path(radius, run_in, run_out, offset, n_steps)
	var root := Node3D.new()
	root.name = "HotWheelsLoop"
	root.add_child(PieceKit.body(_track_mesh(path, width), ORANGE, "Track"))
	var dense: Dictionary = _dense(path)
	root.add_child(_visual("EdgeStripes", _edge_mesh(dense, width), STRIPE))
	root.add_child(_visual("Dashes", _dash_mesh(dense, width), DASH_COLOUR))
	root.add_child(_visual("Ribs", _rib_mesh(path, width), ORANGE))
	for deg: float in LEG_DEG:
		root.add_child(_leg(deg, radius, width, offset, run_in))
	root.add_child(PieceKit.gap_zone("loop_full",
		Vector3(-0.5, 1.0, -run_in - radius - 0.5),
		Vector3(offset + width + 1.0, 2.0 * radius - 0.5, 2.0 * radius + 1.0)))
	return root


# --- path ------------------------------------------------------------------------------------------

## Centreline samples of the riding face at the left edge: pos (Vector3), nrm (inward normal) and theta (loop angle
## in radians, or -1 on the flat parts). The run-out ends at z = -run_in - run_out.
static func _path(radius: float, run_in: float, run_out: float, offset: float, steps: int) -> Dictionary:
	var pos: Array = []
	var nrm: Array = []
	var theta: Array = []
	var zb: float = -run_in
	pos.append(Vector3(0.0, LIFT, 0.0))
	nrm.append(Vector3.UP)
	theta.append(-1.0)
	pos.append(Vector3(0.0, LIFT, zb))
	nrm.append(Vector3.UP)
	theta.append(-1.0)
	for i: int in range(1, steps + 1):
		var th: float = TAU * float(i) / float(steps)
		pos.append(Vector3(offset * _smooth01(th / TAU), LIFT + radius * (1.0 - cos(th)), zb - radius * sin(th)))
		nrm.append(Vector3(0.0, cos(th), sin(th)))
		theta.append(th)
	for i: int in [1, 2]:
		pos.append(Vector3(offset, LIFT, zb - run_out * float(i) * 0.5))
		nrm.append(Vector3.UP)
		theta.append(-1.0)
	return {"pos": pos, "nrm": nrm, "theta": theta}


## The path resampled every DENSE_STEP metres, with arc length s, for the dashes and edge stripes.
static func _dense(path: Dictionary) -> Dictionary:
	var pos: Array = path["pos"]
	var nrm: Array = path["nrm"]
	var out_pos: Array = []
	var out_nrm: Array = []
	var out_s: Array = []
	var s: float = 0.0
	for j: int in range(pos.size() - 1):
		var a: Vector3 = pos[j]
		var b: Vector3 = pos[j + 1]
		var seg: float = a.distance_to(b)
		var m: int = maxi(1, ceili(seg / DENSE_STEP))
		for k: int in range(m):
			var t: float = float(k) / float(m)
			out_pos.append(a.lerp(b, t))
			out_nrm.append((nrm[j] as Vector3).lerp(nrm[j + 1], t).normalized())
			out_s.append(s + seg * t)
		s += seg
	out_pos.append(pos[pos.size() - 1])
	out_nrm.append(nrm[nrm.size() - 1])
	out_s.append(s)
	return {"pos": out_pos, "nrm": out_nrm, "s": out_s}


# --- meshes ----------------------------------------------------------------------------------------

## Riding face (top) plus the two curbs. This is the collision trimesh too.
static func _track_mesh(path: Dictionary, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos: Array = path["pos"]
	var nrm: Array = path["nrm"]
	var w := Vector3(width, 0.0, 0.0)
	var t := Vector3(CURB_T, 0.0, 0.0)
	for j: int in range(pos.size() - 1):
		var a: Vector3 = pos[j]
		var b: Vector3 = pos[j + 1]
		var na: Vector3 = nrm[j]
		var nb: Vector3 = nrm[j + 1]
		var want: Vector3 = (na + nb).normalized()
		var ha: Vector3 = na * CURB_H
		var hb: Vector3 = nb * CURB_H
		# riding face
		_quad(st, [a, b, b + w, a + w], [na, nb, nb, na], want)
		# underside, facing outward (the slab's back)
		var sa: Vector3 = -na * SLAB
		var sb: Vector3 = -nb * SLAB
		_quad(st, [a + sa, a + sa + w, b + sb + w, b + sb], [-na, -na, -nb, -nb], -want)
		# left curb: inner face (track side is +X), outer face, top
		_quad(st, [a, b, b + hb, a + ha], [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT], Vector3.RIGHT)
		_quad(st, [a - t, a - t + ha, b - t + hb, b - t], [Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT], Vector3.LEFT)
		_quad(st, [a + ha, b + hb, b - t + hb, a - t + ha], [na, nb, nb, na], want)
		# right curb: inner face (track side is -X), outer face, top
		var ra: Vector3 = a + w
		var rb: Vector3 = b + w
		_quad(st, [ra, rb, rb + hb, ra + ha], [Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT], Vector3.LEFT)
		_quad(st, [ra + t, rb + t, rb + t + hb, ra + t + ha], [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT], Vector3.RIGHT)
		_quad(st, [ra + ha, rb + hb, rb + t + hb, ra + t + ha], [na, nb, nb, na], want)
	return st.commit()


## Thin darker-orange stripes along both edges of the riding face, and white dashes down the middle.
static func _edge_mesh(dense: Dictionary, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_band(st, dense, 0.0, STRIPE_W, 0.006, false)
	_band(st, dense, width - STRIPE_W, width, 0.006, false)
	return st.commit()


static func _dash_mesh(dense: Dictionary, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_band(st, dense, width * 0.5 - DASH_W * 0.5, width * 0.5 + DASH_W * 0.5, 0.008, true)
	return st.commit()


## Radial ribs behind the loop's upper part, from the riding face out to SHELL_OFF, so it reads as a structure rather
## than a floating ribbon. Each rib is a double-sided plate spanning the width.
static func _rib_mesh(path: Dictionary, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos: Array = path["pos"]
	var nrm: Array = path["nrm"]
	var theta: Array = path["theta"]
	var w := Vector3(width, 0.0, 0.0)
	for j: int in range(1, pos.size() - 1):
		if not _in_shell(theta[j]) or j % RIB_EVERY != 0:
			continue
		var out: Vector3 = -(nrm[j] as Vector3)
		var p: Vector3 = pos[j]
		var a: Vector3 = p
		var b: Vector3 = p + w
		var c: Vector3 = p + w + out * SHELL_OFF
		var d: Vector3 = p + out * SHELL_OFF
		var t: Vector3 = w.cross(out).normalized()
		_quad(st, [a, b, c, d], [t, t, t, t], t)
		_quad(st, [a, b, c, d], [-t, -t, -t, -t], -t)
	return st.commit()


static func _visual(node_name: String, mesh: Mesh, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = Toon.material(colour)
	return mi


## A decorative column from the ground to the outer ribs at `deg` around the loop (no collision).
static func _leg(deg: float, radius: float, width: float, offset: float, run_in: float) -> MeshInstance3D:
	var th: float = deg_to_rad(deg)
	var x: float = offset * _smooth01(th / TAU) + width * 0.5
	var y: float = LIFT + radius * (1.0 - cos(th)) - SHELL_OFF * cos(th)
	var z: float = -run_in - (radius + SHELL_OFF) * sin(th)
	var cyl := CylinderMesh.new()
	cyl.top_radius = LEG_R
	cyl.bottom_radius = LEG_R
	cyl.height = y
	cyl.radial_segments = 8
	var mi := _visual("Leg", cyl, PieceKit.METAL)
	mi.position = Vector3(x, y * 0.5, z)
	return mi


# --- helpers ---------------------------------------------------------------------------------------

## A strip across the riding face from lateral `lat0` to `lat1`, lifted off the surface. `dashes_only` keeps only the
## dash windows along the arc.
static func _band(st: SurfaceTool, dense: Dictionary, lat0: float, lat1: float, lift: float, dashes_only: bool) -> void:
	var pos: Array = dense["pos"]
	var nrm: Array = dense["nrm"]
	var s: Array = dense["s"]
	var l0 := Vector3(lat0, 0.0, 0.0)
	var l1 := Vector3(lat1, 0.0, 0.0)
	for i: int in range(pos.size() - 1):
		if dashes_only and not (_dash_on(s[i]) and _dash_on(s[i + 1])):
			continue
		var pa: Vector3 = pos[i]
		var pb: Vector3 = pos[i + 1]
		var na: Vector3 = nrm[i]
		var nb: Vector3 = nrm[i + 1]
		var ua: Vector3 = na * lift
		var ub: Vector3 = nb * lift
		_quad(st, [pa + l0 + ua, pb + l0 + ub, pb + l1 + ub, pa + l1 + ua], [na, nb, nb, na], (na + nb).normalized())


static func _dash_on(arc: float) -> bool:
	return fposmod(arc - 0.3, DASH_PERIOD) < DASH_LEN


static func _in_shell(th: float) -> bool:
	return th >= deg_to_rad(SHELL_FROM) and th <= deg_to_rad(SHELL_TO)


static func _smooth01(t: float) -> float:
	var u: float = clampf(t, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _vert(st: SurfaceTool, p: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(p)


## Emit quad v (in loop order) with per-corner normals n. Godot treats clockwise as front-facing, so the triangles go out
## clockwise as seen from the side `want` (the direction the face should point). Flat normals, not shared.
static func _quad(st: SurfaceTool, v: Array, n: Array, want: Vector3) -> void:
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var c: Vector3 = v[2]
	var flip: bool = (b - a).cross(c - a).dot(want) < 0.0
	var idx: Array = [0, 3, 2, 1] if flip else [0, 1, 2, 3]
	var i0: int = idx[0]
	var i1: int = idx[1]
	var i2: int = idx[2]
	var i3: int = idx[3]
	_vert(st, v[i0], n[i0])
	_vert(st, v[i2], n[i2])
	_vert(st, v[i1], n[i1])
	_vert(st, v[i0], n[i0])
	_vert(st, v[i3], n[i3])
	_vert(st, v[i2], n[i2])
