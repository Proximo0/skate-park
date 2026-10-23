class_name ShoeShape
extends RefCounted
## The footprint and profile of a skate shoe's upper, shared by SkateShoe (the low vulc) and ShoeStyles (cupsole,
## puffy, high top). The upper is lofted from superellipse sections (flat top, near-vertical sides, boxy rounded toe)
## along a PLAN table, on a sole stack that starts at FOX_TOP. Geometry is in ground space: y = 0 at the sole bottom,
## heel at +Z (heel_z), toe toward -Z. Every method is pure, so a style only changes the fields.

const D_LENGTH: float = 0.302  ## heel to toe of the upper (the sole is a little longer)
const D_HEEL_Z: float = 0.08  ## z of the back of the upper's heel
const D_EXP: float = 0.72  ## 2 / superellipse exponent (~2.8): flat top, near-vertical sides
const D_FOX_TOP: float = 0.033  ## top of the foxing band, where the upper starts
const D_TUCK: float = 0.007  ## how far the upper runs down inside the foxing
const D_TOE_R: float = 0.058  ## plan-view toe rounding length
const D_TOE_V: float = 0.042  ## side-view toe rounding length
const D_HEEL_R: float = 0.03  ## plan-view heel rounding length
const D_G_SOLE: float = 0.0055
const D_G_FOX: float = 0.0038
## Upper plan before the end rounding: distance from heel, half width, height above fox_top.
const D_PLAN: Array = [
	[0.0, 0.036, 0.093], [0.03, 0.038, 0.093], [0.08, 0.041, 0.085], [0.13, 0.0455, 0.069],
	[0.17, 0.0495, 0.053], [0.21, 0.0525, 0.041], [0.25, 0.0515, 0.034], [0.302, 0.049, 0.031],
]

var length: float = D_LENGTH
var heel_z: float = D_HEEL_Z
var exp: float = D_EXP
var fox_top: float = D_FOX_TOP
var tuck: float = D_TUCK
var toe_r: float = D_TOE_R
var toe_v: float = D_TOE_V
var heel_r: float = D_HEEL_R
var g_sole: float = D_G_SOLE
var g_fox: float = D_G_FOX
var spring: float = 0.0095  ## toe spring: the front lifts this much
var plan: Array = D_PLAN
var exp_heel: float = -1.0  ## when >= 0: the exponent at the heel (boxier), blending to `exp` between d = 0.06 and 0.15
var cap_back: float = 0.21  ## toe cap back edge at the top centre
var cap_sweep: float = 0.05  ## how far the toe cap's edge sweeps back down the sides


## Catmull-Rom through plan column `col` (1 half width, 2 height) at distance d from the heel.
func plan_at(d: float, col: int) -> float:
	var n: int = plan.size()
	var dd: float = clampf(d, 0.0, float(plan[n - 1][0]))
	var i: int = 0
	while i < n - 2 and dd > float(plan[i + 1][0]):
		i += 1
	var t: float = (dd - float(plan[i][0])) / (float(plan[i + 1][0]) - float(plan[i][0]))
	var p0: float = float(plan[maxi(i - 1, 0)][col])
	var p1: float = float(plan[i][col])
	var p2: float = float(plan[i + 1][col])
	var p3: float = float(plan[mini(i + 2, n - 1)][col])
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## Half width of the upper at d, grown by g (the heel and toe ends move out by g too).
func hw(d: float, g: float) -> float:
	var tt: float = clampf((d - (length - toe_r)) / (toe_r + g), 0.0, 1.0)
	var th: float = clampf((heel_r - d) / (heel_r + g), 0.0, 1.0)
	return (plan_at(d, 1) + g) * pow(1.0 - pow(tt, 2.6), 1.0 / 2.6) * pow(1.0 - pow(th, 2.4), 1.0 / 2.4)


## Height of the upper's section at d above its tucked base (fox_top - tuck), grown by g.
func ht(d: float, g: float) -> float:
	var tv: float = clampf((d - (length - toe_v)) / (toe_v + g), 0.0, 1.0)
	return (plan_at(d, 2) + tuck + g) * pow(1.0 - pow(tv, 2.2), 1.0 / 2.2)


## Section exponent at d.
func exp_at(d: float) -> float:
	if exp_heel < 0.0:
		return exp
	return lerpf(exp_heel, exp, smoothstep(0.06, 0.15, d))


## Toe spring at d.
func lift(d: float) -> float:
	return spring * pow(smoothstep(length - 0.08, length + 0.006, d), 1.5)


## Point on the upper's surface (grown by g) at distance d from the heel and section angle phi
## (0 = top centre, +PI/2 = the +X side's base, -PI/2 = the -X side's base).
func pt(d: float, phi: float, g: float) -> Vector3:
	var s: float = sin(phi)
	var c: float = cos(phi)
	var e: float = exp_at(d)
	var x: float = hw(d, g) * signf(s) * pow(absf(s), e)
	var y: float = fox_top - tuck + ht(d, g) * pow(absf(c), e)
	return Vector3(x, y + lift(d), heel_z - d)


## Section angle where the surface (grown by g) is at x.
func phi_at_x(d: float, x: float, g: float) -> float:
	var r: float = clampf(absf(x) / maxf(hw(d, g), 0.00001), 0.0, 1.0)
	return signf(x) * asin(pow(r, 1.0 / exp_at(d)))


## Section angle (+X side) where the surface (grown by g) is v above fox_top.
func phi_at_v(d: float, v: float, g: float) -> float:
	var c: float = clampf((v + tuck) / maxf(ht(d, g), 0.00001), 0.0, 1.0)
	return acos(pow(c, 1.0 / exp_at(d)))


## y of the upper's top centre at d.
func top_y(d: float, g: float) -> float:
	return pt(d, 0.0, g).y


## Point `clear` above the upper's surface at (d, x).
func over(d: float, x: float, clear: float) -> Vector3:
	return pt(d, phi_at_x(d, x, 0.0), 0.0) + Vector3(0.0, clear, 0.0)


## Toe cap back edge (distance from heel) at section angle phi: highest on top, sweeping back down the sides.
func cap_edge(phi: float) -> float:
	return cap_back - cap_sweep * pow(absf(sin(phi)), 1.6)


## Distances from the heel for the lengthwise rows: dense at the rounded heel and toe.
func d_samples(g: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for i: int in 5:
		out.append(lerpf(-g, heel_r, 1.0 - cos(float(i) / 5.0 * PI * 0.5)))
	var mid: int = 13
	for i: int in mid:
		out.append(lerpf(heel_r, length - toe_r, float(i) / float(mid)))
	for i: int in 10:
		out.append(lerpf(length - toe_r, length + g, sin(float(i) / 9.0 * PI * 0.5)))
	return out


## Closed plan outline of the upper's footprint grown by g, at height y (plus toe spring).
func outline(g: float, y: float) -> PackedVector3Array:
	var ds: PackedFloat32Array = d_samples(g)
	var out: PackedVector3Array = PackedVector3Array()
	for d: float in ds:
		out.append(Vector3(hw(d, g), y + lift(d), heel_z - d))
	for i: int in range(ds.size() - 2, 0, -1):
		var d: float = ds[i]
		out.append(Vector3(-hw(d, g), y + lift(d), heel_z - d))
	return out


## Per-row reference points inside the shoe at height ref_y, under each row's mean z.
func refs(rows: Array, ref_y: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for r: PackedVector3Array in rows:
		var z: float = 0.0
		for p: Vector3 in r:
			z += p.z
		z /= float(maxi(r.size(), 1))
		out.append(Vector3(0.0, ref_y, clampf(z, heel_z - length + 0.05, heel_z - 0.04)))
	return out


## One stitch dash on the surface grown by g, from (da, pa) to (db, pb), 1.2 mm wide.
func dash(st: SurfaceTool, da: float, pa: float, db: float, pb: float, g: float) -> void:
	var a: Vector3 = pt(da, pa, g)
	var b: Vector3 = pt(db, pb, g)
	var n: Vector3 = (pt(da, pa, g + 0.01) - a).normalized()
	var w: Vector3 = (b - a).cross(n).normalized() * 0.0006
	ShoeKit.quad_into(st, a - w, a + w, b - w, b + w, a - n * 0.01)
