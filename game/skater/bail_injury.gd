class_name BailInjury
extends RefCounted
## The injury override layer of a bail: for a moment a joint goes past its natural limit (an ankle rolls, a knee or
## elbow bends the wrong way, a wrist folds back, a shoulder pops out, the neck cricks), then on the get-up it snaps
## straight back. It is applied to the code joints after the ragdoll has driven them, so every body skin (the VRM,
## the Houdini body, the code body) shows it: the VRM retargets joint rotations, and its legs follow the code ankle.
## Limbs only turn about their own joint: nothing moves apart, nothing comes off.
##
## weight(): onset snaps in over ONSET_TIME with a small overshoot, holds, and the repair pops back over REPAIR_TIME
## (swinging a touch past normal first, like a joint clicking in). local_rotation() is the joint-space rotation at a
## weight; apply() writes it onto a joint node.

const ONSET_TIME: float = 0.07
const SETTLE_TIME: float = 0.1  ## after the onset, the overshoot settles over this
const ONSET_OVERSHOOT: float = 0.12
const REPAIR_TIME: float = 0.14
const REPAIR_OVERSHOOT: float = 0.2
const WRIST_SCALE: float = 0.78  ## a folded wrist reads as a cartoon fold, not a mitten pointing at the elbow
const SHOULDER_TWIST: float = 0.8  ## the socket turn stays inside what the VRM shoulder mesh can twist without pinching


## 0..~1.1. onset_t: seconds since the injury hit (< 0: not yet). repair_t: seconds since the repair began (< 0: not
## repairing). After a full repair the weight is exactly 0.
static func weight(onset_t: float, repair_t: float) -> float:
	if onset_t < 0.0:
		return 0.0
	var w: float = 1.0
	if onset_t < ONSET_TIME:
		var u: float = onset_t / ONSET_TIME
		w = (1.0 + ONSET_OVERSHOOT) * u * u * (3.0 - 2.0 * u)
	elif onset_t < ONSET_TIME + SETTLE_TIME:
		w = 1.0 + ONSET_OVERSHOOT * (1.0 - (onset_t - ONSET_TIME) / SETTLE_TIME)
	if repair_t < 0.0:
		return w
	if repair_t >= REPAIR_TIME:
		return 0.0
	var r: float = repair_t / REPAIR_TIME
	return w * (1.0 - r) * (1.0 - r) - REPAIR_OVERSHOOT * sin(PI * r) * r


## Current flex of a hinge child (the joint below) against its parent, radians, about the parent's X axis: the same
## measure SkaterRagdoll uses for its elbow and knee limits (elbow + = forearm forward, knee - = shin back).
static func flex(parent_basis: Basis, child_basis: Basis) -> float:
	var rel: Basis = parent_basis.orthonormalized().inverse() * child_basis.orthonormalized()
	return atan2(rel.y.z, rel.y.y)


## Joint-space rotation for injury `inj` (a BailKind.injury() entry) at weight w. cur_flex: the hinge's current flex
## (only "hyper" uses it: it bends from wherever the joint is to angle past straight the wrong way).
static func local_rotation(inj: Dictionary, w: float, cur_flex: float = 0.0) -> Basis:
	if absf(w) < 0.0001:
		return Basis.IDENTITY
	var a: float = float(inj.get("angle", 0.0))
	var side: float = -1.0 if str(inj.get("side", "L")) == "L" else 1.0
	var joint: String = str(inj.get("joint", ""))
	match str(inj.get("how", "")):
		"roll":  # ankle: the sole turns in, the foot rolls over onto its outside edge
			return Basis(Vector3.BACK, side * a * w)
		"hyper":  # knee or elbow past straight, the wrong way
			var wrong: float = a if joint.ends_with("LowerLeg") else -a
			return Basis(Vector3.RIGHT, (wrong - cur_flex) * w)
		"bend":  # wrist folded back over the forearm
			return Basis(Vector3.RIGHT, -WRIST_SCALE * a * w) * Basis(Vector3.BACK, side * 0.25 * a * w)
		"twist":  # shoulder out of its socket: the arm turned and swung back behind the body
			return Basis(Vector3.RIGHT, -0.9 * a * w) * Basis(Vector3.UP, side * SHOULDER_TWIST * a * w)
		"tilt":  # neck crick: the head cocked hard to one side and turned
			return Basis(Vector3.BACK, side * a * w) * Basis(Vector3.UP, -side * 0.45 * a * w)
	return Basis.IDENTITY


## Writes the injury onto the joint node at weight w, turning it about its own origin (the children follow).
## parent: the hinge's parent joint for "hyper" (UpperLeg / UpperArm), else null.
static func apply(node: Node3D, inj: Dictionary, w: float, parent: Node3D = null) -> void:
	if node == null or absf(w) < 0.0001:
		return
	var cur: float = 0.0
	if parent != null:
		cur = flex(parent.global_basis, node.global_basis)
	var g: Transform3D = node.global_transform
	node.global_transform = Transform3D(g.basis * local_rotation(inj, w, cur), g.origin)


## Name of the hinge parent of a joint ("LeftLowerLeg" -> "LeftUpperLeg"), "" when it has none.
static func hinge_parent(joint: String) -> String:
	if joint.ends_with("LowerLeg"):
		return joint.replace("LowerLeg", "UpperLeg")
	if joint.ends_with("LowerArm"):
		return joint.replace("LowerArm", "UpperArm")
	return ""
