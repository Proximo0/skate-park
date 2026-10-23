class_name BailKind
extends RefCounted
## Bail classification: which way the slam goes, how hard it is, and what it does to the skater (the "Hall of Meat"
## readout). Pure logic: no Node, no clock, no randf(). The Skater fills a context when a bail starts; classify() turns
## it into a plan that SkaterRagdoll (fall style: initial pose and impulse) and BailFx (injuries, readout) consume.
##
## Context keys (all optional): "cause" ("land", "flip", "wall", "grind", "manual", "lip"), "velocity" (impact
## velocity, m/s), "normal" (surface normal), "facing" (board forward), "board_up", "spin_deg" (signed air spin),
## "lean" (balance angle, + right), "drop" (m to the ground beside a rail), "rail_speed" (m/s), "stairs" (bool),
## "impact" (m/s, overrides the speed estimate), "kind" (forces a kind, for captures and tests).
##
## Cartoon slams with twists and sprains that pop straight back: no blood, no gore, limbs never come off.

## Kind -> title shown on the readout, fall style, and the injury pool (most likely first).
const KINDS: Dictionary = {
	"over_rotated": {"title": "OVER-ROTATED", "style": "tumble", "pool": ["shoulder", "neck", "wrist"]},
	"under_rotated": {"title": "UNDER-ROTATED", "style": "knee_slide", "pool": ["knee", "ankle", "wrist"]},
	"heel_catch": {"title": "HEELSIDE SLAM", "style": "butt_slide", "pool": ["wrist", "elbow", "neck"]},
	"toe_catch": {"title": "TOESIDE FACEPLANT", "style": "faceplant", "pool": ["wrist", "elbow", "neck"]},
	"back_slam": {"title": "BACK SLAM", "style": "back_slam", "pool": ["neck", "shoulder", "elbow"]},
	"nose_dive": {"title": "NOSE DIVE", "style": "faceplant", "pool": ["neck", "wrist", "shoulder"]},
	"primo": {"title": "PRIMO SLAM", "style": "cartwheel", "pool": ["ankle", "knee", "shoulder"]},
	"big_drop": {"title": "FLAILED THE DROP", "style": "flail", "pool": ["knee", "ankle", "wrist"]},
	"stair_slam": {"title": "STAIR SLAM", "style": "tumble", "pool": ["knee", "elbow", "neck"]},
	"wall_slam": {"title": "WALL SPLAT", "style": "wall_splat", "pool": ["elbow", "shoulder", "neck"]},
	"grind_tip": {"title": "TIPPED OFF THE RAIL", "style": "cartwheel", "pool": ["shoulder", "ankle", "wrist"]},
	"racked": {"title": "RACKED!", "style": "racked", "pool": ["knee", "ankle", "neck"]},
	"manual_back": {"title": "LOOPED OUT", "style": "back_slam", "pool": ["elbow", "wrist", "neck"]},
	"manual_front": {"title": "MANUAL FACEPLANT", "style": "faceplant", "pool": ["wrist", "elbow", "neck"]},
	"lip_fall": {"title": "HUNG UP", "style": "back_slam", "pool": ["shoulder", "neck", "elbow"]},
	"flip_tangle": {"title": "TANGLED IN THE FLIP", "style": "knee_slide", "pool": ["ankle", "knee", "wrist"]},
}

## Fall styles: ragdoll set-up. spin: initial angular velocity (rad/s) in the body frame, x = about the rider's right
## (+ tips the head back), y = about up, z = about the rider's facing (+ rolls toward the left side). up: extra
## upward m/s. keep: share of the travel velocity kept. arms / legs: initial pose ("reach", "up", "back", "brace",
## "spread", "tuck"). guide: torque (N m s per second) along the spin for the first GUIDE_TIME, so the fall reads.
## board: board kick ("forward", "back", "up", "roll").
const STYLES: Dictionary = {
	"tumble": {"spin": Vector3(-4.5, 0.0, 1.0), "up": 1.2, "keep": 0.95, "arms": "spread", "legs": "tuck", "guide": 10.0, "board": "forward"},
	"knee_slide": {"spin": Vector3(-2.0, 0.6, 0.0), "up": 0.2, "keep": 0.9, "arms": "reach", "legs": "kneel", "guide": 5.0, "board": "forward"},
	"butt_slide": {"spin": Vector3(2.6, 0.0, 0.0), "up": 0.3, "keep": 0.9, "arms": "brace", "legs": "tuck", "guide": 7.0, "board": "forward"},
	"faceplant": {"spin": Vector3(-3.4, 0.0, 0.0), "up": 0.6, "keep": 0.92, "arms": "reach", "legs": "straight", "guide": 9.0, "board": "back"},
	"back_slam": {"spin": Vector3(3.6, 0.0, 0.0), "up": 1.0, "keep": 0.9, "arms": "up", "legs": "straight", "guide": 9.0, "board": "up"},
	"cartwheel": {"spin": Vector3(0.0, 0.5, 4.5), "up": 1.4, "keep": 0.9, "arms": "spread", "legs": "spread", "guide": 9.0, "board": "roll"},
	"flail": {"spin": Vector3(-1.2, 1.2, 0.8), "up": 0.0, "keep": 0.85, "arms": "up", "legs": "spread", "guide": 4.0, "board": "up"},
	"wall_splat": {"spin": Vector3(2.0, 0.0, 0.6), "up": 0.8, "keep": 1.0, "arms": "reach", "legs": "straight", "guide": 5.0, "board": "back"},
	"racked": {"spin": Vector3(0.0, 0.3, 3.0), "up": 0.4, "keep": 0.7, "arms": "spread", "legs": "spread", "guide": 6.0, "board": "forward"},
}

## Injury -> code joint (side-less for limbs: the side is chosen per bail), readout label, angle range in degrees
## (at severity 0 and 1) and how the joint goes wrong: "roll" turns it about the limb's facing axis, "hyper" bends a
## hinge past straight the wrong way, "bend" folds it about its hinge axis, "twist" turns it about the limb, "tilt"
## cricks it sideways.
const INJURIES: Dictionary = {
	"ankle": {"joint": "Foot", "label": "ROLLED ANKLE", "deg": Vector2(62.0, 88.0), "how": "roll"},
	"knee": {"joint": "LowerLeg", "label": "HYPEREXTENDED KNEE", "deg": Vector2(24.0, 38.0), "how": "hyper"},
	"wrist": {"joint": "Hand", "label": "BROKEN WRIST", "deg": Vector2(85.0, 105.0), "how": "bend"},
	"elbow": {"joint": "LowerArm", "label": "BENT-BACK ELBOW", "deg": Vector2(40.0, 60.0), "how": "hyper"},
	"shoulder": {"joint": "UpperArm", "label": "DISLOCATED SHOULDER", "deg": Vector2(70.0, 100.0), "how": "twist"},
	"neck": {"joint": "Head", "label": "NECK CRICK", "deg": Vector2(28.0, 42.0), "how": "tilt"},
}

const SEVERITY_FLOOR: float = 5.0  ## m/s impact where severity starts
const SEVERITY_SPAN: float = 13.0  ## m/s from the floor to full severity (18 m/s)
const INJURY_MIN_SEVERITY: float = 0.12  ## softer slams are plain bails (about 6.6 m/s)
const TWO_INJURIES: float = 0.55
const THREE_INJURIES: float = 0.85
const BIG_DROP_FALL: float = 12.5  ## m/s straight into the ground (about a 4.3 m drop at gravity 18)
const PRIMO_ROLL: float = 0.95  ## board-up share along the rider's sides: on its edge (tipped past ~72 degrees)
const SPIN_MIN_DEG: float = 60.0  ## less spin than this is not a rotation bail
const GRAVITY: float = 18.0
const MEAT_BASE: int = 250
const MEAT_SPAN: int = 2200


## 0..1 from the impact speed (m/s).
static func severity(impact: float) -> float:
	return clampf((impact - SEVERITY_FLOOR) / SEVERITY_SPAN, 0.0, 1.0)


## Number of injuries at this severity (0 to 3).
static func injury_count(sev: float) -> int:
	if sev < INJURY_MIN_SEVERITY:
		return 0
	if sev < TWO_INJURIES:
		return 1
	return 2 if sev < THREE_INJURIES else 3


## Readout points for the bail: each injury is worth more the harder the slam, with a bonus for stacking them.
static func meat(sev: float, injuries: int) -> int:
	if injuries <= 0:
		return 0
	var each: float = float(MEAT_BASE) + float(MEAT_SPAN) * sev
	return int(roundf(each * float(injuries) * (1.0 + 0.25 * float(injuries - 1)) / 10.0)) * 10


## Impact speed (m/s) estimated from the context.
static func impact_speed(ctx: Dictionary) -> float:
	if ctx.has("impact"):
		return float(ctx["impact"])
	var v: Vector3 = ctx.get("velocity", Vector3.ZERO)
	var cause: String = str(ctx.get("cause", ""))
	match cause:
		"grind":
			var h: Vector3 = Vector3(v.x, 0.0, v.z)
			var drop: float = maxf(float(ctx.get("drop", 0.0)), 0.0)
			var rail: float = absf(float(ctx.get("rail_speed", h.length())))
			return sqrt(rail * rail * 0.5 + 2.0 * GRAVITY * minf(drop, 6.0))
		"lip":
			return v.length() + 6.0  # the fall back into the ramp
		"manual":
			return v.length() * 0.9
	return v.length()


## The kind of bail for this context (a key of KINDS).
static func kind_of(ctx: Dictionary) -> String:
	var forced: String = str(ctx.get("kind", ""))
	if KINDS.has(forced):
		return forced
	var cause: String = str(ctx.get("cause", "land"))
	match cause:
		"wall":
			return "wall_slam"
		"manual":
			return "manual_back" if float(ctx.get("lean", 0.0)) < 0.0 else "manual_front"
		"lip":
			return "lip_fall"
		"grind":
			return "racked" if float(ctx.get("drop", 99.0)) > 1.6 and absf(float(ctx.get("rail_speed", 0.0))) < 3.0 \
					else "grind_tip"
		"flip":
			return "flip_tangle"
	return _landing_kind(ctx)


static func _landing_kind(ctx: Dictionary) -> String:
	var n: Vector3 = (ctx.get("normal", Vector3.UP) as Vector3).normalized()
	var v: Vector3 = ctx.get("velocity", Vector3.ZERO)
	var fwd: Vector3 = ctx.get("facing", Vector3.FORWARD)
	var up: Vector3 = (ctx.get("board_up", Vector3.UP) as Vector3).normalized()
	var fall: float = -v.dot(n)
	# Rider frame on the surface: forward along the board, right = toe side for a regular rider.
	var f: Vector3 = fwd.slide(n)
	f = f.normalized() if f.length() > 0.01 else n.cross(Vector3.RIGHT).normalized()
	var right: Vector3 = f.cross(n).normalized()
	var roll: float = up.dot(right)
	var pitch: float = up.dot(f)  # + : the board's up leans forward, the nose dips in
	var up_dot: float = up.dot(n)
	if up_dot < 0.5 and absf(roll) >= PRIMO_ROLL:
		return "primo"
	if fall > BIG_DROP_FALL:
		return "big_drop"
	if bool(ctx.get("stairs", false)):
		return "stair_slam"
	if up_dot < 0.5:
		if up_dot < -0.2:
			return "back_slam"  # landed on the board upside down: the feet fly out
		if absf(roll) > absf(pitch):
			return "toe_catch" if roll > 0.0 else "heel_catch"
		if pitch > 0.0:
			return "nose_dive" if n.y < 0.93 else "over_rotated"
		return "back_slam"
	# Upright board, heading across the travel: a spin that went too far or not far enough.
	var spin: float = float(ctx.get("spin_deg", 0.0))
	var err: float = heading_error(f, v, n)
	if absf(spin) < SPIN_MIN_DEG:
		return "under_rotated"
	return "over_rotated" if signf(err) == signf(spin) else "under_rotated"


## Signed angle (degrees, -90..90, + counter-clockwise about the normal) from the nearest of rolling forward or
## fakie to the board's heading. Zero when there is no travel.
static func heading_error(f: Vector3, v: Vector3, n: Vector3) -> float:
	var flat: Vector3 = v.slide(n)
	if flat.length() < 0.1 or f.length() < 0.01:
		return 0.0
	var a: float = rad_to_deg(flat.normalized().signed_angle_to(f.normalized(), n.normalized()))
	if a > 90.0:
		a -= 180.0
	elif a < -90.0:
		a += 180.0
	return a


## The full plan for a bail. injuries_on false: a plain ragdoll (no injuries, no meat).
static func classify(ctx: Dictionary, injuries_on: bool = true) -> Dictionary:
	var kind: String = kind_of(ctx)
	var info: Dictionary = KINDS[kind]
	var impact: float = impact_speed(ctx)
	var sev: float = severity(impact)
	var picked: Array[Dictionary] = []
	if injuries_on:
		var pool: Array = info["pool"]
		var count: int = mini(injury_count(sev), pool.size())
		var side: String = pick_side(ctx)
		for i: int in count:
			picked.append(injury(str(pool[i]), side if i % 2 == 0 else ("R" if side == "L" else "L"), sev))
	return {
		"kind": kind, "title": str(info["title"]), "style": str(info["style"]), "severity": sev, "impact": impact,
		"injuries": picked, "meat": meat(sev, picked.size()),
		"ground_y": (ctx.get("normal", Vector3.UP) as Vector3).normalized().y,
	}


## One injury entry: {id, joint (full joint name), label, how, angle (radians), side}.
static func injury(id: String, side: String, sev: float) -> Dictionary:
	var d: Dictionary = INJURIES[id]
	var j: String = str(d["joint"])
	if j != "Head":
		j = ("Left" if side == "L" else "Right") + j
	var rng: Vector2 = d["deg"]
	return {"id": id, "joint": j, "label": str(d["label"]), "how": str(d["how"]),
		"angle": deg_to_rad(lerpf(rng.x, rng.y, clampf(sev, 0.0, 1.0))), "side": side}


## "L" or "R": the side that takes the hit. Leans pick their side; otherwise a stable hash of the velocity.
static func pick_side(ctx: Dictionary) -> String:
	if ctx.has("lean") and absf(float(ctx["lean"])) > 0.01:
		return "R" if float(ctx["lean"]) > 0.0 else "L"
	var v: Vector3 = ctx.get("velocity", Vector3.ZERO)
	var h: int = absi(hash(Vector3i(roundi(v.x * 10.0), roundi(v.y * 10.0), roundi(v.z * 10.0))))
	return "L" if h % 2 == 0 else "R"


## Readout lines: the injuries (or the kind's title when none) and the meat total.
static func readout(plan: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for inj: Dictionary in plan.get("injuries", []):
		out.append(str(inj["label"]))
	return out
