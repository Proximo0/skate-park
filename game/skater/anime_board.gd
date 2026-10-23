class_name AnimeBoard
extends RefCounted
## A real street skateboard, built in code: a 7-ply popsicle deck (concave, kicked nose and tail, ply stripes on the
## edge, dark griptape with 8 bolt heads, a surf sunset graphic underneath), Indy-style trucks (riser pad, baseplate
## with mounting nuts, kingpin with bushings, washer and nut, pivot cup, cast hanger with the cross on its face,
## axle with speed rings and axle nuts) and lathe-turned urethane wheels with a core and a bearing in each face.
## Static builders called by PlaceholderSkater.build_board. Long along Z, nose at -Z, wheel bottoms at y = 0; the
## deck top stays at DECK_TOP_Y (0.135) over the flat middle. Notes: /tmp/lead/char_r2/board_research.md.

## The "Deck" proxy box (not drawn): the board's reference size, top at DECK_TOP_Y.
const DECK_LENGTH: float = 0.8
const DECK_WIDTH: float = 0.22
const DECK_THICK: float = 0.03
const DECK_Y: float = 0.12
const DECK_TOP_Y: float = DECK_Y + DECK_THICK * 0.5
## The drawn deck: 1 mm of grip over 7 maple plies.
const VIS_THICK: float = 0.0142
const GRIP_THICK: float = 0.001
const PLY_KEYS: Array[String] = ["ply", "ply_coral", "ply_dark", "ply_teal", "ply_dark", "ply_coral", "ply"]
## The ends start to round off (a half ellipse in plan) and kick up past this |z|.
const KICK_START: float = 0.295
## The kick bends over this distance, then runs straight at its angle to the tip.
const KICK_BEND: float = 0.042
const NOSE_ANGLE: float = 24.0
const TAIL_ANGLE: float = 21.0
## Rails sit this much higher than the centre line (concave across the width).
const CONCAVE: float = 0.006

## Deck shapes by key: length along Z, widest width, where each end starts to round off / kick, kick angles, kick
## bend length, concave depth, half width at the nose and tail (a taper between them), and the end-curve exponent (2 =
## ellipse, higher = squarer). "popsicle" is the constants above. Wheelbase (TRUCK_Z) is the same for every deck.
const DECK_SHAPES: Dictionary = {
	"popsicle": {"len": 0.8, "wid": 0.22, "ks_n": 0.295, "ks_t": 0.295, "ang_n": 24.0, "ang_t": 21.0, "bend": 0.042,
			"conc": 0.006, "hw_n": 0.11, "hw_t": 0.11, "p_n": 2.0, "p_t": 2.0},
	"cruiser": {"len": 0.72, "wid": 0.25, "ks_n": 0.28, "ks_t": 0.285, "ang_n": 10.0, "ang_t": 17.0, "bend": 0.05,
			"conc": 0.003, "hw_n": 0.125, "hw_t": 0.125, "p_n": 2.0, "p_t": 3.2},
	"oldschool": {"len": 0.78, "wid": 0.256, "ks_n": 0.27, "ks_t": 0.298, "ang_n": 16.0, "ang_t": 20.0, "bend": 0.045,
			"conc": 0.005, "hw_n": 0.128, "hw_t": 0.112, "p_n": 2.0, "p_t": 4.5},
}
const GRAPHICS: PackedStringArray = ["sunset", "wave", "face", "checker", "flames", "palm"]
## Truck variants: `drop` is how much the hanger sits closer to the baseplate (a thicker riser keeps the deck top
## at DECK_TOP_Y); `hollow` draws a hollow kingpin and axle with a light accent.
const TRUCKS: Dictionary = {
	"standard": {"drop": 0.0, "hollow": false},
	"low": {"drop": 0.013, "hollow": false},
	"hollow": {"drop": 0.0, "hollow": true},
}
## Wheel variants: radius, width and lathe profile kind. "street" is the original wheel.
const WHEELS: Dictionary = {
	"street": {"r": 0.032, "w": 0.034, "kind": "street"},
	"park": {"r": 0.0335, "w": 0.036, "kind": "park"},
	"cruiser": {"r": 0.0355, "w": 0.040, "kind": "cruiser"},
}

static var _len: float = DECK_LENGTH
static var _wid: float = DECK_WIDTH
static var _ks_n: float = KICK_START
static var _ks_t: float = KICK_START
static var _ang_n: float = NOSE_ANGLE
static var _ang_t: float = TAIL_ANGLE
static var _bend: float = KICK_BEND
static var _conc: float = CONCAVE
static var _hw_n: float = DECK_WIDTH * 0.5
static var _hw_t: float = DECK_WIDTH * 0.5
static var _p_n: float = 2.0
static var _p_t: float = 2.0

## Truck layout (truck frame: origin on the ground under the axle, -Z toward the board's centre, so the kingpin
## faces the middle). Real Indy proportions scaled up about 1.45x in height to meet the game's deck height.
const WHEEL_R: float = 0.032
const WHEEL_W: float = 0.034
const AXLE_Y: float = WHEEL_R
const RISER_TOP: float = DECK_TOP_Y - VIS_THICK
const PLATE_TOP: float = RISER_TOP - 0.008
const PLATE_BOTTOM: float = PLATE_TOP - 0.008
const HANGER_HALF: float = 0.072
## Truck centres at z = +-TRUCK_Z (a 14" wheelbase between the inner mounting holes); wheel centres at x = +-WHEEL_X,
## so the outer wheel faces line up with the deck's rails.
const TRUCK_Z: float = 0.25
const WHEEL_X: float = HANGER_HALF + 0.021
const HANGER_DEPTH: float = 0.0115
## Kingpin direction: down and toward the board's centre, 50 degrees from the baseplate.
const KINGPIN_DIR: Vector3 = Vector3(0.0, -0.766, -0.643)
const KINGPIN_BASE: Vector3 = Vector3(0.0, PLATE_BOTTOM, -0.008)
const PIVOT_CUP: Vector3 = Vector3(0.0, PLATE_BOTTOM - 0.004, 0.03)
## Mounting holes, "new school" pattern (41 x 54 mm real, 1.2x).
const HOLE_X: float = 0.025
const HOLE_Z: float = 0.032


## Resolves a catalog id or short key ("deck_cruiser", "cruiser", "wheel_park_54") to a key of `table`.
static func resolve_key(table: Dictionary, key: String, prefix: String) -> String:
	var k: String = key.trim_prefix(prefix)
	for name: String in table.keys():
		if k == name or k.begins_with(name + "_"):
			return name
	return table.keys()[0]


## Makes the static shape queries (center_y, top_y, ...) describe this deck. PlaceholderSkater.build_board sets the
## deck it builds and puts "popsicle" back afterwards.
static func set_deck(key: String) -> void:
	var d: Dictionary = DECK_SHAPES[resolve_key(DECK_SHAPES, key, "deck_")]
	_len = float(d["len"])
	_wid = float(d["wid"])
	_ks_n = float(d["ks_n"])
	_ks_t = float(d["ks_t"])
	_ang_n = float(d["ang_n"])
	_ang_t = float(d["ang_t"])
	_bend = float(d["bend"])
	_conc = float(d["conc"])
	_hw_n = float(d["hw_n"])
	_hw_t = float(d["hw_t"])
	_p_n = float(d["p_n"])
	_p_t = float(d["p_t"])


static func build_deck(root: Node3D, mats: Dictionary, deck: String = "popsicle", graphic: String = "sunset") -> void:
	set_deck(deck)
	# "Deck" is the board's reference box (full size, top at DECK_TOP_Y). It is not drawn: the visible deck is the
	# shaped surfaces below.
	var proxy: MeshInstance3D = SkaterParts.part(root, "Deck", SkaterParts.box(Vector3(_wid, DECK_THICK, _len)),
			Vector3(0.0, DECK_Y, 0.0), mats, "grip")
	proxy.visible = false

	var zs: Array = _sample_zs()
	SkaterParts.part(root, "DeckGrip", _patch(_outline_rows(zs, 8), 0.0, true), Vector3.ZERO, mats, "grip")
	SkaterParts.part(root, "DeckBottom", _patch(_outline_rows(zs, 8), 0.0, false), Vector3.ZERO, mats, "deck")
	_build_edge(root, zs, mats)
	match graphic:
		"wave":
			_graphic_wave(root, mats)
		"face":
			_graphic_face(root, mats)
		"checker":
			_graphic_checker(root, mats)
		"flames":
			_graphic_flames(root, mats)
		"palm":
			_graphic_palm(root, mats)
		_:
			_build_graphic(root, mats)


## The side wall: a dark grip band on top, then one band per ply.
static func _build_edge(root: Node3D, zs: Array, mats: Dictionary) -> void:
	var by_key: Dictionary = {}
	var ply_t: float = (VIS_THICK - GRIP_THICK) / float(PLY_KEYS.size())
	var bands: Array = [["grip", 0.0, GRIP_THICK]]
	for i: int in PLY_KEYS.size():
		bands.append([PLY_KEYS[i], GRIP_THICK + ply_t * float(i), GRIP_THICK + ply_t * float(i + 1)])
	for band: Array in bands:
		var key: String = band[0]
		if not by_key.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			by_key[key] = st
		_edge_band(by_key[key], zs, float(band[1]), float(band[2]))
	for key: String in by_key:
		var nm: String = "DeckEdge" if key == "grip" else "DeckPly_" + key
		SkaterParts.part(root, nm, (by_key[key] as SurfaceTool).commit(), Vector3.ZERO, mats, key)


## Sunset over the sea on the bottom: teal sky, a coral sun with a yellow core sinking into a deep teal sea with
## two cream foam lines.
static func _build_graphic(root: Node3D, mats: Dictionary) -> void:
	var sun_c: Vector2 = Vector2(0.0, 0.0)
	SkaterParts.part(root, "DeckSun", _patch(_disc_rows(sun_c, 0.082, 4, 28), 0.0005, false), Vector3.ZERO, mats, "deck_alt")
	SkaterParts.part(root, "DeckSunCore", _patch(_disc_rows(sun_c, 0.056, 3, 28), 0.001, false), Vector3.ZERO, mats, "deck_sun")
	# Sky stripes across the sun's upper half (the retro sunset look).
	var stripes: Array = []
	for i: int in 3:
		var z0: float = 0.022 - 0.019 * float(i)
		var w: float = 0.0045 - 0.0012 * float(i)
		stripes.append(_band_rows(z0 - w, z0 + w, 0.09))
	SkaterParts.part(root, "DeckSunStripes", _patch_multi(stripes, 0.0015), Vector3.ZERO, mats, "deck")
	SkaterParts.part(root, "DeckSea", _patch(_sea_rows(0.0), 0.002, false), Vector3.ZERO, mats, "deck_dark")
	var foam: Array = []
	foam.append(_wave_line(0.0, 0.0045))
	foam.append(_wave_line(0.085, 0.0035))
	foam.append(_wave_line(0.16, 0.003))
	SkaterParts.part(root, "DeckFoam", _patch_multi(foam, 0.0025), Vector3.ZERO, mats, "deck_foam")


## Great-wave graphic: a deck-coloured sky with a pale sun, a deep sea from a rolling horizon to the tail, and a
## curling foam crest with spray dots.
static func _graphic_wave(root: Node3D, mats: Dictionary) -> void:
	_poly_part(root, "DeckSun", [_ellipse(Vector2(0.045, -0.15), 0.05, 0.05, 28)], 0.0005, mats, "deck_alt")
	SkaterParts.part(root, "DeckSea", _patch(_sea_rows(0.02), 0.001, false), Vector3.ZERO, mats, "deck_dark")
	# The crest: a crescent between two arcs, thick at the top and tapering into curled tips.
	var crest: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var a: float = PI + PI * float(i) / 16.0
		crest.append(Vector2(cos(a) * 0.105, 0.075 + sin(a) * 0.115))
	for i: int in 17:
		var a: float = TAU - PI * float(i) / 16.0
		crest.append(Vector2(0.02 + cos(a) * 0.075, 0.088 + sin(a) * 0.085))
	_poly_part(root, "DeckFoam", [crest], 0.0016, mats, "deck_foam")
	var spray: Array = []
	for d: Array in [[-0.092, -0.07, 0.007], [-0.075, -0.098, 0.005], [-0.05, -0.12, 0.0045], [0.075, -0.06, 0.005]]:
		spray.append(_ellipse(Vector2(float(d[0]), float(d[1])), float(d[2]), float(d[2]), 10))
	_poly_part(root, "DeckSpray", spray, 0.0016, mats, "deck_foam")
	# Two foam lines along the sea toward the tail.
	var foam: Array = []
	foam.append(_wave_line(0.11, 0.0035))
	foam.append(_wave_line(0.18, 0.003))
	SkaterParts.part(root, "DeckFoamLines", _patch_multi(foam, 0.0025), Vector3.ZERO, mats, "deck_foam")


## Chibi anime face sticker: a white-bordered round face with a hair fringe, big shiny eyes, blush and a tiny mouth.
static func _graphic_face(root: Node3D, mats: Dictionary) -> void:
	var c: Vector2 = Vector2(0.0, 0.02)
	var ring: Array = [_ellipse(c, 0.1, 0.1, 32)]
	_poly_part(root, "DeckSticker", ring, 0.0005, mats, "deck_dark")
	_poly_part(root, "DeckFace", [_ellipse(c, 0.093, 0.093, 32)], 0.001, mats, "deck_foam")
	# Hair: the upper arc of the face with a zig-zag fringe along the bottom.
	var hair: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var a: float = PI + PI * float(i) / 16.0
		hair.append(c + Vector2(cos(a), sin(a)) * 0.093)
	for f: Array in [[0.088, -0.005], [0.066, -0.04], [0.048, -0.012], [0.024, -0.046], [0.0, -0.016], [-0.024, -0.046],
			[-0.048, -0.012], [-0.066, -0.04], [-0.088, -0.005]]:
		hair.append(c + Vector2(float(f[0]), float(f[1])))
	_poly_part(root, "DeckHair", [hair], 0.0015, mats, "deck_accent")
	var side: Array = [_ellipse(c + Vector2(-0.088, 0.03), 0.014, 0.04, 14), _ellipse(c + Vector2(0.088, 0.03), 0.014, 0.04, 14)]
	_poly_part(root, "DeckHairSide", side, 0.0015, mats, "deck_accent")
	var eyes: Array = [_ellipse(c + Vector2(-0.04, 0.026), 0.017, 0.026, 18), _ellipse(c + Vector2(0.04, 0.026), 0.017, 0.026, 18)]
	_poly_part(root, "DeckEyes", eyes, 0.002, mats, "deck_dark")
	var irises: Array = [_ellipse(c + Vector2(-0.04, 0.032), 0.011, 0.016, 14), _ellipse(c + Vector2(0.04, 0.032), 0.011, 0.016, 14)]
	_poly_part(root, "DeckIris", irises, 0.0025, mats, "deck")
	var glints: Array = [_ellipse(c + Vector2(-0.045, 0.017), 0.0055, 0.0075, 10), _ellipse(c + Vector2(0.035, 0.017), 0.0055, 0.0075, 10),
			_ellipse(c + Vector2(-0.034, 0.04), 0.003, 0.004, 8), _ellipse(c + Vector2(0.046, 0.04), 0.003, 0.004, 8)]
	_poly_part(root, "DeckGlints", glints, 0.003, mats, "deck_foam")
	var cheeks: Array = [_ellipse(c + Vector2(-0.062, 0.066), 0.014, 0.008, 12), _ellipse(c + Vector2(0.062, 0.066), 0.014, 0.008, 12)]
	_poly_part(root, "DeckCheeks", cheeks, 0.002, mats, "deck_accent")
	_poly_part(root, "DeckMouth", [_ellipse(c + Vector2(0.0, 0.074), 0.009, 0.005, 10)], 0.002, mats, "deck_dark")


## Checker band across the middle of the deck with a stripe near each end.
static func _graphic_checker(root: Node3D, mats: Dictionary) -> void:
	var half: float = _body_hw(0.0) - 0.0035
	var cw: float = half / 3.0
	var dark: Array = []
	var light: Array = []
	for i: int in 6:
		for j: int in 6:
			var x0: float = -half + cw * float(i)
			var z0: float = -cw * 3.0 + cw * float(j)
			var sq: PackedVector2Array = PackedVector2Array([Vector2(x0, z0), Vector2(x0 + cw, z0), Vector2(x0 + cw, z0 + cw),
					Vector2(x0, z0 + cw)])
			if (i + j) % 2 == 0:
				dark.append(sq)
			else:
				light.append(sq)
	_poly_part(root, "DeckCheckDark", dark, 0.001, mats, "deck_dark")
	_poly_part(root, "DeckCheckLight", light, 0.001, mats, "deck_foam")
	var bands: Array = []
	var thin: Array = []
	for sd: float in [-1.0, 1.0]:
		var zc: float = sd * (cw * 3.0 + 0.045)
		bands.append(_rect(-half, zc - 0.014, half, zc + 0.014))
		thin.append(_rect(-half, zc + sd * 0.03, half, zc + sd * 0.036))
	_poly_part(root, "DeckStripes", bands, 0.001, mats, "deck_accent")
	_poly_part(root, "DeckStripesThin", thin, 0.001, mats, "deck_alt")


## Flames licking in from the nose and the tail: a solid cap with tongues of flame and a hot yellow core.
static func _graphic_flames(root: Node3D, mats: Dictionary) -> void:
	var outer: Array = []
	var inner: Array = []
	for tail: bool in [false, true]:
		var sd: float = 1.0 if tail else -1.0
		var base: float = sd * 0.225
		SkaterParts.part(root, "DeckFlameCap" + ("Tail" if tail else "Nose"), _patch(_cap_rows(base, tail), 0.001, false),
				Vector3.ZERO, mats, "deck_accent")
		var hw: float = (_hw_t if tail else _hw_n) - 0.012
		for i: int in 5:
			var x0: float = lerpf(-hw, hw, float(i) / 4.0)
			var len_: float = [0.15, 0.21, 0.28, 0.2, 0.14][i]
			var lean: float = 0.012 * (1.0 if i % 2 == 0 else -1.0)
			outer.append(_flame(x0, base + sd * 0.012, -sd, len_, hw * 0.42, lean))
			inner.append(_flame(x0, base + sd * 0.012, -sd, len_ * 0.6, hw * 0.24, lean * 0.6))
	_poly_part(root, "DeckFlames", outer, 0.001, mats, "deck_accent")
	_poly_part(root, "DeckFlameCore", inner, 0.0015, mats, "deck_sun")


## One flame tongue: from (x0, z0) toward dir (+1 / -1 along Z), tapering to a curled tip.
static func _flame(x0: float, z0: float, dir: float, length: float, half_w: float, lean: float) -> PackedVector2Array:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i: int in 11:
		var t: float = float(i) / 10.0
		var cx: float = x0 + lean * sin(t * PI * 1.3) * (1.0 + t) * 1.6
		var w: float = half_w * pow(1.0 - t, 0.85) * (1.0 + 0.35 * sin(t * PI))
		var zz: float = z0 + dir * length * t
		left.append(Vector2(cx - w, zz))
		right.append(Vector2(cx + w, zz))
	var out: PackedVector2Array = PackedVector2Array()
	out.append_array(left)
	for i: int in range(right.size() - 2, -1, -1):
		out.append(right[i])
	return out


## Palm tree on a sandbar with a setting sun, the trunk leaning, seven drooping fronds and a bunch of coconuts.
static func _graphic_palm(root: Node3D, mats: Dictionary) -> void:
	_poly_part(root, "DeckSun", [_ellipse(Vector2(0.045, -0.115), 0.058, 0.058, 28)], 0.0005, mats, "deck_alt")
	SkaterParts.part(root, "DeckSea", _patch(_cap_rows(0.15, true), 0.001, false), Vector3.ZERO, mats, "deck_dark")
	_poly_part(root, "DeckSand", [_ellipse(Vector2(0.0, 0.152), 0.092, 0.026, 24)], 0.0015, mats, "deck_sun")
	# Trunk: a tapering ribbon along a leaning curve.
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var crown: Vector2 = Vector2(-0.025, -0.07)
	for i: int in 13:
		var t: float = float(i) / 12.0
		var cx: float = lerpf(0.02, crown.x, t) + 0.03 * sin(t * PI)
		var zz: float = lerpf(0.15, crown.y, t)
		var w: float = lerpf(0.0085, 0.0052, t)
		left.append(Vector2(cx - w, zz))
		right.append(Vector2(cx + w, zz))
	var trunk: PackedVector2Array = PackedVector2Array()
	trunk.append_array(left)
	for i: int in range(right.size() - 1, -1, -1):
		trunk.append(right[i])
	_poly_part(root, "DeckTrunk", [trunk], 0.002, mats, "ply_dark")
	var fronds: Array = []
	for a: float in [-172.0, -140.0, -108.0, -72.0, -40.0, -8.0, 28.0, 152.0]:
		fronds.append(_frond(crown, deg_to_rad(a), 0.115))
	_poly_part(root, "DeckFronds", fronds, 0.0025, mats, "deck_dark")
	var nuts: Array = [_ellipse(crown + Vector2(-0.009, 0.012), 0.0065, 0.0065, 10), _ellipse(crown + Vector2(0.008, 0.013), 0.0065, 0.0065, 10),
			_ellipse(crown + Vector2(0.0, 0.021), 0.0065, 0.0065, 10)]
	_poly_part(root, "DeckCoconuts", nuts, 0.003, mats, "deck_accent")


## A palm frond from p along angle a (0 = +X, +90 deg = +Z), drooping toward the tail.
static func _frond(p: Vector2, a: float, length: float) -> PackedVector2Array:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var dir: Vector2 = Vector2(cos(a), sin(a))
	for i: int in 11:
		var t: float = float(i) / 10.0
		var q: Vector2 = p + dir * length * t + Vector2(0.0, length * 0.55 * t * t)
		var tangent: Vector2 = dir * length + Vector2(0.0, length * 1.1 * t)
		var n: Vector2 = Vector2(-tangent.y, tangent.x).normalized()
		var w: float = 0.0105 * sin(PI * pow(t, 0.7)) + 0.0004
		left.append(q + n * w)
		right.append(q - n * w)
	var out: PackedVector2Array = PackedVector2Array()
	out.append_array(left)
	for i: int in range(right.size() - 1, -1, -1):
		out.append(right[i])
	return out


## Rows from a straight line at z = start to the end of the nose or the tail outline.
static func _cap_rows(start: float, tail: bool) -> Array:
	var rows: Array = []
	var hw: float = (_hw_t if tail else _hw_n) - 0.0001
	var sd: float = 1.0 if tail else -1.0
	for i: int in 9:
		var v: float = float(i) / 8.0
		var row: PackedVector2Array = PackedVector2Array()
		for j: int in 23:
			var x: float = lerpf(-hw, hw, float(j) / 22.0)
			row.append(Vector2(x, lerpf(start, sd * (_end_z(x, tail) - 0.0004), v)))
		rows.append(row)
	return rows


static func _body_hw(z: float) -> float:
	return lerpf(_hw_n, _hw_t, clampf((z + _ks_n) / (_ks_n + _ks_t), 0.0, 1.0))


static func _ellipse(c: Vector2, rx: float, rz: float, segs: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in segs:
		var a: float = TAU * float(i) / float(segs)
		out.append(c + Vector2(cos(a) * rx, sin(a) * rz))
	return out


static func _rect(x0: float, z0: float, x1: float, z1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])


## A part made of flat polygons (x, z) lying on the deck bottom, `off` below it. Points are kept inside the outline.
static func _poly_part(root: Node3D, part_name: String, polys: Array, off: float, mats: Dictionary, key: String) -> void:
	var st: SurfaceTool = _new_st()
	for poly: PackedVector2Array in polys:
		_poly_into(st, poly, off)
	SkaterParts.part(root, part_name, st.commit(), Vector3.ZERO, mats, key)


static func _poly_into(st: SurfaceTool, poly: PackedVector2Array, off: float) -> void:
	var clipped: PackedVector2Array = PackedVector2Array()
	var zmax: float = _len * 0.5 - 0.004
	for q: Vector2 in poly:
		var zz: float = clampf(q.y, -zmax, zmax)
		var hwz: float = maxf(_half_width(zz) - 0.002, 0.0)
		clipped.append(Vector2(clampf(q.x, -hwz, hwz), zz))
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(clipped)
	for t: int in range(0, idx.size(), 3):
		_sub_tri(st, clipped[idx[t]], clipped[idx[t + 1]], clipped[idx[t + 2]], off, 0)


## Emits a triangle on the bottom surface, split into four until its edges are short enough to follow the concave.
static func _sub_tri(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, off: float, depth: int) -> void:
	var longest: float = maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
	if longest > 0.04 and depth < 4:
		var ab: Vector2 = (a + b) * 0.5
		var bc: Vector2 = (b + c) * 0.5
		var ca: Vector2 = (c + a) * 0.5
		_sub_tri(st, a, ab, ca, off, depth + 1)
		_sub_tri(st, ab, b, bc, off, depth + 1)
		_sub_tri(st, ca, bc, c, off, depth + 1)
		_sub_tri(st, ab, bc, ca, off, depth + 1)
		return
	var v: Array = []
	var n: Array = []
	for q: Vector2 in [a, b, c]:
		v.append(Vector3(q.x, top_y(q.x, q.y) - VIS_THICK - off, q.y))
		n.append(-_surface_normal(q.x, q.y))
	_tri(st, v[0], v[1], v[2], n[0], n[1], n[2])


## Truck (ground at y = 0, wheel axle at the wheel radius). `opts` takes "truck" and "wheel" keys. The baseplate and
## riser hang from the deck (the deck top is fixed), the hanger and axle sit on the wheel radius, and the kingpin
## stack and neck bridge the gap, so a low truck or a bigger wheel only changes how the pieces overlap.
static func build_truck(board: Node3D, truck_name: String, z: float, mats: Dictionary, opts: Dictionary = {}) -> void:
	var tdef: Dictionary = TRUCKS[resolve_key(TRUCKS, str(opts.get("truck", "standard")), "truck_")]
	var wdef: Dictionary = WHEELS[resolve_key(WHEELS, str(opts.get("wheel", "street")), "wheel_")]
	var drop: float = float(tdef["drop"])
	var hollow: bool = bool(tdef["hollow"])
	var axle_y: float = float(wdef["r"])
	var hw: float = float(wdef["w"]) * 0.5
	var dh: float = axle_y - WHEEL_R  # hanger-side parts shift up for a bigger wheel
	var hy: Vector3 = Vector3(0.0, dh, 0.0)
	var pb: float = PLATE_BOTTOM - drop  # the baseplate drops with a low truck (a thicker riser keeps the deck top)
	var pt: float = PLATE_TOP - drop
	var kbase: Vector3 = KINGPIN_BASE + Vector3(0.0, -drop, 0.0)
	var cup: Vector3 = PIVOT_CUP + Vector3(0.0, -drop, 0.0)

	var truck: Node3D = SkaterParts.joint(board, "Truck_" + truck_name, Vector3(0.0, 0.0, z))
	var body: Node3D = SkaterParts.joint(truck, "TruckBody", Vector3.ZERO)
	if z < 0.0:
		body.rotation.y = PI  # both kingpins face the middle of the board
	var b: Dictionary = {}

	# Riser pad and baseplate, with the 4 mounting nuts and bolt ends under the plate and 4 bolt heads on the grip.
	_prism(_st(b, "riser"), _rounded_rect(0.038, 0.05, 0.008, 4), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			pt, RISER_TOP, 0.0)
	var plate: PackedVector2Array = _plate_outline()
	_prism(_st(b, "baseplate"), plate, Vector3.RIGHT, Vector3.BACK, Vector3.UP, pb, pt, 0.0025)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var hole: Vector3 = Vector3(sx * HOLE_X, 0.0, sz * HOLE_Z)
			_cyl(_st(b, "hardware"), hole + Vector3(0.0, pb, 0.0), hole + Vector3(0.0, pb - 0.004, 0.0),
					0.0052, 0.0052, 6, false, true, true)
			_cyl(_st(b, "hardware"), hole + Vector3(0.0, pb - 0.004, 0.0), hole + Vector3(0.0, pb - 0.0065, 0.0),
					0.0024, 0.0024, 6, false, true)
			var top: float = DECK_TOP_Y + _concave(hole.x)
			_cyl(_st(b, "hardware"), hole + Vector3(0.0, top - 0.0004, 0.0), hole + Vector3(0.0, top + 0.0011, 0.0),
					0.0058, 0.0048, 8, false, true)
			_cyl(_st(b, "truck_dark"), hole + Vector3(0.0, top + 0.0009, 0.0), hole + Vector3(0.0, top + 0.0014, 0.0),
					0.0022, 0.0022, 6, false, true, true)

	# Kingpin boss (the wedge under the plate that holds the kingpin) and the pivot cup housing.
	var k: Vector3 = KINGPIN_DIR
	_cyl(_st(b, "baseplate"), Vector3(0.0, pb + 0.002, -0.004), kbase + k * 0.01, 0.017, 0.0125, 16, false, true)
	_cyl(_st(b, "baseplate"), Vector3(0.0, pb + 0.002, 0.028), cup + k * 0.006, 0.011, 0.0095, 14, false, true)
	_cyl(_st(b, "bushings"), cup + k * 0.005, cup + k * 0.008, 0.0075, 0.0075, 12, false, true)

	# Kingpin stack, from the boss down: bottom (boardside) bushing, the hanger's bushing seat, top (roadside)
	# bushing, cup washer, kingpin nut and the bolt's threaded end. It rides with the hanger.
	var p: Callable = func(s: float) -> Vector3: return KINGPIN_BASE + hy + k * s
	_cyl(_st(b, "hardware"), p.call(0.008), p.call(0.0105), 0.0145, 0.0145, 16, true, true)
	_cyl(_st(b, "bushings"), p.call(0.0105), p.call(0.0235), 0.0125, 0.0132, 16, true, true)
	_cyl(_st(b, "trucks"), p.call(0.0235), p.call(0.0355), 0.0165, 0.0165, 18, true, true)
	_cyl(_st(b, "bushings"), p.call(0.0355), p.call(0.0475), 0.0128, 0.0105, 16, true, true)
	_cyl(_st(b, "hardware"), p.call(0.0475), p.call(0.0505), 0.0128, 0.0128, 16, true, true)
	if hollow:
		# Hollow kingpin: a light tube with a dark bore showing at the end.
		_cyl(_st(b, "truck_accent"), p.call(0.0505), p.call(0.0665), 0.0082, 0.0082, 14, true, true)
		_cyl(_st(b, "truck_dark"), p.call(0.0665), p.call(0.0672), 0.0054, 0.0054, 12, false, true)
	else:
		_cyl(_st(b, "hardware"), p.call(0.0505), p.call(0.0575), 0.0078, 0.0078, 6, true, true, true)
		_cyl(_st(b, "hardware"), p.call(0.0575), p.call(0.0625), 0.0042, 0.0042, 10, false, true)

	# Hanger: the cast front-view profile (grinding bar over the axle, a tent rising in the middle, a rounded belly),
	# the neck up to the bushing seat, the pivot nub up into the pivot cup, and the cross on both faces.
	_prism(_st(b, "trucks"), _up(_hanger_profile(), dh), Vector3.RIGHT, Vector3.UP, Vector3.BACK, -HANGER_DEPTH, HANGER_DEPTH, 0.003)
	var web: PackedVector2Array = _up(PackedVector2Array([Vector2(0.0115, 0.044), Vector2(0.007, 0.056), Vector2(-0.02, 0.081),
			Vector2(-0.035, 0.075), Vector2(-0.027, 0.058), Vector2(-0.0115, 0.046)]), dh)
	_prism(_st(b, "trucks"), web, Vector3.BACK, Vector3.UP, Vector3.RIGHT, -0.0125, 0.0125, 0.003)
	_cyl(_st(b, "trucks"), Vector3(0.0, 0.054 + dh, 0.005), cup + k * 0.004, 0.0062, 0.0048, 10, true, true)
	if hollow:
		# Lightening holes through the hanger instead of the cross.
		for sd: float in [-1.0, 1.0]:
			for hx: float in [-0.024, 0.024]:
				var face: float = sd * (HANGER_DEPTH + 0.0002)
				_cyl(_st(b, "truck_dark"), Vector3(hx, 0.0285 + dh, face), Vector3(hx, 0.0285 + dh, face + sd * 0.0004),
						0.0072, 0.0072, 12, false, true)
	else:
		var cross: PackedVector2Array = _cross_outline(Vector2(0.0, 0.034 + dh), 0.0118, 0.0024, 0.0062)
		_prism(_st(b, "truck_dark"), cross, Vector3.RIGHT, Vector3.UP, Vector3.BACK, -HANGER_DEPTH - 0.0006, -HANGER_DEPTH + 0.001, 0.0)
		_prism(_st(b, "truck_dark"), cross, Vector3.RIGHT, Vector3.UP, Vector3.BACK, HANGER_DEPTH - 0.001, HANGER_DEPTH + 0.0006, 0.0)

	# Axle through the hanger, a speed ring each side of each wheel, and the axle nuts (a hollow axle shows its bore).
	var wx: float = WHEEL_X
	var ring_key: String = "truck_accent" if hollow else "hardware"
	var ay: float = axle_y
	_cyl(_st(b, "hardware"), Vector3(-wx - hw - 0.002, ay, 0.0), Vector3(wx + hw + 0.002, ay, 0.0),
			0.0052 if hollow else 0.0042, 0.0052 if hollow else 0.0042, 10, true, true)
	for s: float in [-1.0, 1.0]:
		_cyl(_st(b, ring_key), Vector3(s * (HANGER_HALF - 0.001), ay, 0.0), Vector3(s * (wx - hw + 0.0018), ay, 0.0),
				0.0062, 0.0062, 12, true, true)
		_cyl(_st(b, ring_key), Vector3(s * (wx + hw - 0.0018), ay, 0.0), Vector3(s * (wx + hw + 0.0005), ay, 0.0),
				0.0062, 0.0062, 12, true, true)
		if hollow:
			_cyl(_st(b, "truck_accent"), Vector3(s * (wx + hw + 0.0005), ay, 0.0), Vector3(s * (wx + hw + 0.0085), ay, 0.0),
					0.0074, 0.0074, 14, true, true)
			_cyl(_st(b, "truck_dark"), Vector3(s * (wx + hw + 0.0085), ay, 0.0), Vector3(s * (wx + hw + 0.0089), ay, 0.0),
					0.0048, 0.0048, 12, false, true)
		else:
			_cyl(_st(b, "hardware"), Vector3(s * (wx + hw + 0.0005), ay, 0.0), Vector3(s * (wx + hw + 0.0075), ay, 0.0),
					0.0068, 0.0068, 6, true, true, true)

	var names: Dictionary = {"trucks": "TruckHangerMesh", "baseplate": "TruckBaseMesh", "hardware": "TruckAxleMesh",
			"bushings": "TruckBushingsMesh", "riser": "TruckRiserMesh", "truck_dark": "TruckCrossMesh",
			"truck_accent": "TruckAccentMesh"}
	for key: String in b:
		SkaterParts.part(body, names.get(key, "Truck_" + key), (b[key] as SurfaceTool).commit(), Vector3.ZERO, mats, key)


## An outline moved up by dy.
static func _up(pts: PackedVector2Array, dy: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in pts:
		out.append(q + Vector2(0.0, dy))
	return out


## Urethane wheel (bottom at y = 0, so the centre is at the wheel radius): a lathe-turned tyre with rounded lips
## and a recessed face, a cream core ring on each face (children of the wheel, so they spin with it), and the
## bearing in the "_Hub" sibling: a coloured shield between a steel outer race and inner race. `kind` picks the
## profile: street (the original, narrow and square-shouldered), park (conical, a narrow contact patch) or cruiser
## (wide, soft and fully rounded).
static func build_wheel(board: Node3D, wheel_name: String, x: float, z: float, mats: Dictionary, kind: String = "street") -> void:
	var wdef: Dictionary = WHEELS[resolve_key(WHEELS, kind, "wheel_")]
	var h: float = float(wdef["w"]) * 0.5
	var r: float = float(wdef["r"])
	var prof: PackedVector2Array = _wheel_profile(str(wdef["kind"]), r, h)
	var tyre: SurfaceTool = _new_st()
	_lathe(tyre, prof, 20 if str(wdef["kind"]) != "cruiser" else 24)
	var wheel: MeshInstance3D = SkaterParts.part(board, wheel_name, tyre.commit(), Vector3(x, r, z), mats, "wheels")
	wheel.rotation.z = PI * 0.5
	var face: float = h - 0.0022
	var core: SurfaceTool = _new_st()
	for s: float in [-1.0, 1.0]:
		_ring(core, Vector3(0.0, s * face, 0.0), Vector3(0.0, s, 0.0), 0.0108, 0.0168, 20)
	SkaterParts.part(wheel, wheel_name + "_Core", core.commit(), Vector3.ZERO, mats, "core")

	var shield: SurfaceTool = _new_st()
	var races: SurfaceTool = _new_st()
	for s: float in [-1.0, 1.0]:
		var c: Vector3 = Vector3(0.0, s * (face + 0.0003), 0.0)
		_ring(shield, c, Vector3(0.0, s, 0.0), 0.0056, 0.0094, 16)
		_ring(races, c, Vector3(0.0, s, 0.0), 0.0094, 0.0112, 16)
		_ring(races, c, Vector3(0.0, s, 0.0), 0.0041, 0.0056, 8)
	var hub: MeshInstance3D = SkaterParts.part(board, wheel_name + "_Hub", shield.commit(), Vector3(x, r, z), mats, "hubs")
	hub.rotation.z = PI * 0.5
	SkaterParts.part(hub, wheel_name + "_Races", races.commit(), Vector3.ZERO, mats, "hardware")


## Closed (radius, y) profile of a wheel of radius r and half width h.
static func _wheel_profile(kind: String, r: float, h: float) -> PackedVector2Array:
	var pts: Array = []
	if kind == "park":
		# Conical: the tread is a narrow band and the shoulders slope away, with a large chamfer.
		pts = [Vector2(0.0112, -h + 0.0024), Vector2(0.0205, -h + 0.0024), Vector2(0.0226, -h + 0.0006), Vector2(0.0268, -h),
				Vector2(r - 0.0085, -h + 0.0012), Vector2(r - 0.0034, -h + 0.0058), Vector2(r - 0.0004, -0.0072),
				Vector2(r, -0.0045), Vector2(r, 0.0045), Vector2(r - 0.0004, 0.0072), Vector2(r - 0.0034, h - 0.0058),
				Vector2(r - 0.0085, h - 0.0012), Vector2(0.0268, h), Vector2(0.0226, h - 0.0006), Vector2(0.0205, h - 0.0024),
				Vector2(0.0112, h - 0.0024), Vector2(0.0112, -h + 0.0024)]
	elif kind == "cruiser":
		# Wide, soft and fully rounded: the tread is one big arc from lip to lip.
		pts = [Vector2(0.0114, -h + 0.0026), Vector2(0.0212, -h + 0.0026), Vector2(0.0234, -h + 0.0008)]
		var arc: Array = []
		for i: int in 9:
			var a: float = PI * 0.5 * float(i) / 8.0
			arc.append(Vector2(0.0284 + (r - 0.0284) * pow(sin(a), 0.6), -h * cos(a)))
		pts.append_array(arc)
		for i: int in range(arc.size() - 2, -1, -1):
			var q: Vector2 = arc[i]
			pts.append(Vector2(q.x, -q.y))
		pts.append_array([Vector2(0.0234, h - 0.0008), Vector2(0.0212, h - 0.0026), Vector2(0.0114, h - 0.0026),
				Vector2(0.0114, -h + 0.0026)])
	else:
		pts = [Vector2(0.0112, -h + 0.0024), Vector2(0.0205, -h + 0.0024), Vector2(0.0222, -h + 0.0006), Vector2(0.0262, -h),
				Vector2(0.0293, -h + 0.0012), Vector2(0.0311, -h + 0.0042), Vector2(r, -h + 0.009), Vector2(r, h - 0.009),
				Vector2(0.0311, h - 0.0042), Vector2(0.0293, h - 0.0012), Vector2(0.0262, h), Vector2(0.0222, h - 0.0006),
				Vector2(0.0205, h - 0.0024), Vector2(0.0112, h - 0.0024), Vector2(0.0112, -h + 0.0024)]
	return PackedVector2Array(pts)


## Deck centre line height at z: flat in the middle, then a short bend into a straight kick at the nose (-Z) and
## tail (+Z) angles.
static func center_y(z: float) -> float:
	var base: float = DECK_TOP_Y - VIS_THICK * 0.5
	var d: float = absf(z) - (_ks_n if z < 0.0 else _ks_t)
	if d <= 0.0:
		return base
	var t: float = tan(deg_to_rad(_ang_n if z < 0.0 else _ang_t))
	if d < _bend:
		return base + t * d * d / (2.0 * _bend)
	return base + t * (d - _bend * 0.5)


## Top surface height (grip) at (x, z): the centre line plus the concave lift toward the rails.
static func top_y(x: float, z: float) -> float:
	return center_y(z) + VIS_THICK * 0.5 + _concave(x)


static func _concave(x: float) -> float:
	var u: float = clampf(x / (_wid * 0.5), -1.0, 1.0)
	return _conc * u * u


## Half width at z: full in the middle, a half ellipse over the ends.
static func _half_width(z: float) -> float:
	var ks: float = _ks_n if z < 0.0 else _ks_t
	var d: float = maxf(absf(z) - ks, 0.0) / (_len * 0.5 - ks)
	var t: float = clampf((z + _ks_n) / (_ks_n + _ks_t), 0.0, 1.0)
	return lerpf(_hw_n, _hw_t, t) * _superellipse(d, _p_n if z < 0.0 else _p_t)


## (1 - d^p)^(1/p): the end-curve of the outline (an ellipse at p = 2).
static func _superellipse(d: float, p: float) -> float:
	if p == 2.0:
		return sqrt(maxf(1.0 - d * d, 0.0))
	return pow(maxf(1.0 - pow(d, p), 0.0), 1.0 / p)


## |z| where the end outline crosses x (inverse of _half_width over the ends).
static func _end_z(x: float, tail: bool = true) -> float:
	var ks: float = _ks_t if tail else _ks_n
	var u: float = clampf(absf(x) / (_hw_t if tail else _hw_n), 0.0, 1.0)
	return ks + (_len * 0.5 - ks) * _superellipse(u, _p_t if tail else _p_n)


## z samples from nose to tail: even in the middle, arc-spaced over the rounded ends so the tips stay round.
static func _sample_zs() -> Array:
	var out: Array = []
	var arc: int = 14 if _p_n == 2.0 and _p_t == 2.0 else 22
	for i: int in arc + 1:
		var phi: float = (PI * 0.5) * (1.0 - float(i) / float(arc))
		out.append(-(_ks_n + (_len * 0.5 - _ks_n) * sin(phi)))
	var mid: int = 10
	for i: int in range(1, mid):
		out.append(-_ks_n + (_ks_n + _ks_t) * float(i) / float(mid))
	for i: int in arc + 1:
		var phi: float = (PI * 0.5) * float(i) / float(arc)
		out.append(_ks_t + (_len * 0.5 - _ks_t) * sin(phi))
	return out


## Rows of (x, z) points across the deck outline, one row per z sample.
static func _outline_rows(zs: Array, cols: int) -> Array:
	var rows: Array = []
	for z: float in zs:
		var hw: float = _half_width(z)
		var row: PackedVector2Array = PackedVector2Array()
		for j: int in cols + 1:
			row.append(Vector2(lerpf(-hw, hw, float(j) / float(cols)), z))
		rows.append(row)
	return rows


## Concentric rings of (x, z) points filling a disc.
static func _disc_rows(c: Vector2, radius: float, rings: int, segs: int) -> Array:
	var rows: Array = []
	for i: int in rings + 1:
		var rr: float = radius * float(i) / float(rings)
		var row: PackedVector2Array = PackedVector2Array()
		for k: int in segs + 1:
			var a: float = TAU * float(k) / float(segs)
			row.append(c + Vector2(cos(a), sin(a)) * rr)
		rows.append(row)
	return rows


## Two rows spanning a straight band across the board between z0 and z1, x within +-half.
static func _band_rows(z0: float, z1: float, half: float) -> Array:
	var a: PackedVector2Array = PackedVector2Array()
	var b: PackedVector2Array = PackedVector2Array()
	for j: int in 9:
		var x: float = lerpf(-half, half, float(j) / 8.0)
		a.append(Vector2(x, z0))
		b.append(Vector2(x, z1))
	return [a, b]


## Wave crest z at x, offset toward the tail by `shift`.
static func _wave_z(x: float, shift: float) -> float:
	return 0.035 + shift + 0.016 * sin(x * 48.0 + shift * 30.0) + 0.006 * sin(x * 110.0 + 1.3)


## The sea: from the first crest to the tail's outline.
static func _sea_rows(shift: float) -> Array:
	var rows: Array = []
	var cols: int = 22
	var rows_n: int = 8
	var hw: float = _hw_t - 0.0001
	for i: int in rows_n + 1:
		var v: float = float(i) / float(rows_n)
		var row: PackedVector2Array = PackedVector2Array()
		for j: int in cols + 1:
			var x: float = lerpf(-hw, hw, float(j) / float(cols))
			row.append(Vector2(x, lerpf(_wave_z(x, shift), _end_z(x) - 0.0004, v)))
		rows.append(row)
	return rows


## A foam line (two rows) along a crest, half width w.
static func _wave_line(shift: float, w: float) -> Array:
	var a: PackedVector2Array = PackedVector2Array()
	var b: PackedVector2Array = PackedVector2Array()
	var hw: float = _hw_t - 0.0015
	for j: int in 33:
		var x: float = lerpf(-hw, hw, float(j) / 32.0)
		a.append(Vector2(x, _wave_z(x, shift) - w))
		b.append(Vector2(x, _wave_z(x, shift) + w))
	return [a, b]


## A surface following the deck (top or bottom) over a grid of (x, z) rows, lifted `off` off it (outward).
static func _patch(rows: Array, off: float, facing_up: bool) -> ArrayMesh:
	var st: SurfaceTool = _new_st()
	_patch_into(st, rows, off, facing_up)
	return st.commit()


## Several two-row strips on the bottom, `off` below it.
static func _patch_multi(strips: Array, off: float) -> ArrayMesh:
	var st: SurfaceTool = _new_st()
	for rows: Array in strips:
		_patch_into(st, rows, off, false)
	return st.commit()


static func _patch_into(st: SurfaceTool, rows: Array, off: float, facing_up: bool) -> void:
	var sgn: float = 1.0 if facing_up else -1.0
	for i: int in rows.size() - 1:
		var r0: PackedVector2Array = rows[i]
		var r1: PackedVector2Array = rows[i + 1]
		for j: int in r0.size() - 1:
			var q: Array = [r0[j], r0[j + 1], r1[j], r1[j + 1]]
			var v: Array = []
			var n: Array = []
			for p: Vector2 in q:
				var y: float = top_y(p.x, p.y) + off if facing_up else top_y(p.x, p.y) - VIS_THICK - off
				v.append(Vector3(p.x, y, p.y))
				n.append(_surface_normal(p.x, p.y) * sgn)
			_tri(st, v[0], v[1], v[2], n[0], n[1], n[2])
			_tri(st, v[1], v[3], v[2], n[1], n[3], n[2])


static func _surface_normal(x: float, z: float) -> Vector3:
	var e: float = 0.002
	var dx: float = (top_y(x + e, z) - top_y(x - e, z)) / (2.0 * e)
	var dz: float = (center_y(z + e) - center_y(z - e)) / (2.0 * e)
	return Vector3(-dx, 1.0, -dz).normalized()


## One horizontal band of the edge wall, from `d0` to `d1` below the top surface, all round the outline.
static func _edge_band(st: SurfaceTool, zs: Array, d0: float, d1: float) -> void:
	var loop: Array = []
	for z: float in zs:
		loop.append(Vector2(_half_width(z), z))
	for i: int in range(zs.size() - 1, -1, -1):
		loop.append(Vector2(-_half_width(zs[i]), zs[i]))
	for i: int in loop.size():
		var p0: Vector2 = loop[i]
		var p1: Vector2 = loop[(i + 1) % loop.size()]
		if p0.distance_to(p1) < 0.0001:
			continue
		var out0: Vector3 = _outward(loop, i)
		var out1: Vector3 = _outward(loop, (i + 1) % loop.size())
		var a: Vector3 = Vector3(p0.x, top_y(p0.x, p0.y) - d0, p0.y)
		var b: Vector3 = Vector3(p1.x, top_y(p1.x, p1.y) - d0, p1.y)
		var c: Vector3 = Vector3(p0.x, top_y(p0.x, p0.y) - d1, p0.y)
		var d: Vector3 = Vector3(p1.x, top_y(p1.x, p1.y) - d1, p1.y)
		_tri(st, a, b, c, out0, out1, out0)
		_tri(st, b, d, c, out1, out1, out0)


static func _outward(loop: Array, i: int) -> Vector3:
	var n: int = loop.size()
	var prev: Vector2 = loop[(i - 1 + n) % n]
	var next: Vector2 = loop[(i + 1) % n]
	var t: Vector2 = next - prev
	var normal: Vector2 = Vector2(t.y, -t.x).normalized()
	var p: Vector2 = loop[i]
	if normal.dot(Vector2(p.x, p.y)) < 0.0:
		normal = -normal
	return Vector3(normal.x, 0.0, normal.y)


## Baseplate outline in (x, z): wide at the kingpin end (-Z), tapering toward the pivot end, rounded corners.
static func _plate_outline() -> PackedVector2Array:
	var corners: Array = [Vector2(-0.036, -0.047), Vector2(0.036, -0.047), Vector2(0.03, 0.044), Vector2(-0.03, 0.044)]
	return _round_corners(corners, 0.011, 4)


static func _rounded_rect(hx: float, hz: float, r: float, steps: int) -> PackedVector2Array:
	return _round_corners([Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)], r, steps)


## Replaces each corner of a convex polygon with an arc of radius r.
static func _round_corners(corners: Array, r: float, steps: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = corners.size()
	for i: int in n:
		var p: Vector2 = corners[i]
		var a: Vector2 = (corners[(i - 1 + n) % n] - p).normalized()
		var b: Vector2 = (corners[(i + 1) % n] - p).normalized()
		var p0: Vector2 = p + a * r
		var p1: Vector2 = p + b * r
		for k: int in steps + 1:
			var t: float = float(k) / float(steps)
			# Quadratic Bezier through the corner: a smooth fillet.
			out.append(p0.lerp(p, t).lerp(p.lerp(p1, t), t))
	return out


## Front view of the hanger in (x, y): the grinding bar with rounded ends round the axle, a tent rising in the
## middle toward the bushing seat, and a rounded belly under the middle.
static func _hanger_profile() -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var end_x: float = HANGER_HALF - 0.012
	# Right end: an arc round the axle from the top to the bottom.
	for k: int in 7:
		var a: float = PI * 0.5 - PI * float(k) / 6.0
		pts.append(Vector2(end_x + 0.012 * cos(a), AXLE_Y + 0.0125 * sin(a)))
	# Underside sweeping down to the belly, round the bottom, and up to the left end.
	var under: Array = [Vector2(0.046, 0.0195), Vector2(0.028, 0.0165), Vector2(0.016, 0.0135), Vector2(0.008, 0.0118),
			Vector2(0.0, 0.0113), Vector2(-0.008, 0.0118), Vector2(-0.016, 0.0135), Vector2(-0.028, 0.0165), Vector2(-0.046, 0.0195)]
	for p: Vector2 in under:
		pts.append(p)
	for k: int in 7:
		var a: float = -PI * 0.5 - PI * float(k) / 6.0
		pts.append(Vector2(-end_x + 0.012 * cos(a), AXLE_Y + 0.0125 * sin(a)))
	# Top: the flat grinding bar, then the tent.
	var top: Array = [Vector2(-0.038, 0.0448), Vector2(-0.026, 0.047), Vector2(-0.014, 0.0545), Vector2(-0.006, 0.058),
			Vector2(0.006, 0.058), Vector2(0.014, 0.0545), Vector2(0.026, 0.047), Vector2(0.038, 0.0448)]
	for p: Vector2 in top:
		pts.append(p)
	return pts


## The Indy-style cross: four arms flaring out from the centre.
static func _cross_outline(c: Vector2, arm: float, inner: float, outer: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var dirs: Array = [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]
	for i: int in 4:
		var d: Vector2 = dirs[i]
		var nxt: Vector2 = dirs[(i + 1) % 4]
		var prv: Vector2 = dirs[(i + 3) % 4]
		pts.append(c + d * arm + prv * outer)
		pts.append(c + d * (arm - 0.0018))
		pts.append(c + d * arm + nxt * outer)
		pts.append(c + (d + nxt) * inner)
	return pts


## Extrudes a 2D outline (u, v axes) along `axis` from d0 to d1, with the caps inset by `bevel` for a soft edge.
static func _prism(st: SurfaceTool, outline: PackedVector2Array, u: Vector3, v: Vector3, axis: Vector3, d0: float, d1: float,
		bevel: float) -> void:
	var n: int = outline.size()
	var area: float = 0.0
	for i: int in n:
		area += outline[i].cross(outline[(i + 1) % n])
	var ccw: bool = area > 0.0
	var normals: Array = []
	var inset: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var e0: Vector2 = outline[i] - outline[(i - 1 + n) % n]
		var e1: Vector2 = outline[(i + 1) % n] - outline[i]
		var n0: Vector2 = Vector2(e0.y, -e0.x).normalized()
		var n1: Vector2 = Vector2(e1.y, -e1.x).normalized()
		if not ccw:
			n0 = -n0
			n1 = -n1
		var nn: Vector2 = (n0 + n1).normalized()
		normals.append(nn)
		var miter: float = maxf(nn.dot(n1), 0.5)
		inset.append(outline[i] - nn * bevel / miter)
	var to3: Callable = func(p: Vector2, d: float) -> Vector3: return u * p.x + v * p.y + axis * d
	var b: float = minf(bevel, (d1 - d0) * 0.45)
	var layers: Array = [[inset, d0, -1.0], [outline, d0 + b, 0.0], [outline, d1 - b, 0.0], [inset, d1, 1.0]]
	if bevel <= 0.0:
		layers = [[outline, d0, 0.0], [outline, d1, 0.0]]
	for li: int in layers.size() - 1:
		var la: Array = layers[li]
		var lb: Array = layers[li + 1]
		for i: int in n:
			var j: int = (i + 1) % n
			var pa: PackedVector2Array = la[0]
			var pb: PackedVector2Array = lb[0]
			var ni: Vector2 = normals[i]
			var nj: Vector2 = normals[j]
			var nai: Vector3 = (u * ni.x + v * ni.y + axis * float(la[2])).normalized()
			var naj: Vector3 = (u * nj.x + v * nj.y + axis * float(la[2])).normalized()
			var nbi: Vector3 = (u * ni.x + v * ni.y + axis * float(lb[2])).normalized()
			var nbj: Vector3 = (u * nj.x + v * nj.y + axis * float(lb[2])).normalized()
			var a: Vector3 = to3.call(pa[i], float(la[1]))
			var bb: Vector3 = to3.call(pa[j], float(la[1]))
			var c: Vector3 = to3.call(pb[i], float(lb[1]))
			var d: Vector3 = to3.call(pb[j], float(lb[1]))
			_tri(st, a, bb, c, nai, naj, nbi)
			_tri(st, bb, d, c, naj, nbj, nbi)
	var cap: PackedVector2Array = inset if bevel > 0.0 else outline
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(cap)
	for t: int in range(0, idx.size(), 3):
		for side: float in [-1.0, 1.0]:
			var d: float = d1 if side > 0.0 else d0
			var nrm: Vector3 = axis * side
			_tri(st, to3.call(cap[idx[t]], d), to3.call(cap[idx[t + 1]], d), to3.call(cap[idx[t + 2]], d), nrm, nrm, nrm)


## Cylinder (or cone) from a to b with radii ra and rb. Flat-shaded sides when `flat` (hex nuts).
static func _cyl(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, segs: int, cap_a: bool, cap_b: bool,
		flat: bool = false) -> void:
	var axis: Vector3 = (b - a).normalized()
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up: Vector3 = side.cross(axis).normalized()
	var slope: float = (ra - rb) / maxf(a.distance_to(b), 0.00001)
	for k: int in segs:
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var d0: Vector3 = side * cos(a0) + up * sin(a0)
		var d1: Vector3 = side * cos(a1) + up * sin(a1)
		var n0: Vector3 = (d0 + axis * slope).normalized()
		var n1: Vector3 = (d1 + axis * slope).normalized()
		if flat:
			n0 = ((d0 + d1) * 0.5 + axis * slope).normalized()
			n1 = n0
		_tri(st, a + d0 * ra, a + d1 * ra, b + d0 * rb, n0, n1, n0)
		_tri(st, a + d1 * ra, b + d1 * rb, b + d0 * rb, n1, n1, n0)
		if cap_a:
			_tri(st, a, a + d0 * ra, a + d1 * ra, -axis, -axis, -axis)
		if cap_b:
			_tri(st, b, b + d1 * rb, b + d0 * rb, axis, axis, axis)


## Flat ring (annulus) centred on c, facing `normal`, around the Y axis.
static func _ring(st: SurfaceTool, c: Vector3, normal: Vector3, r0: float, r1: float, segs: int) -> void:
	for k: int in segs:
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var d0: Vector3 = Vector3(sin(a0), 0.0, -cos(a0))
		var d1: Vector3 = Vector3(sin(a1), 0.0, -cos(a1))
		_tri(st, c + d0 * r0, c + d1 * r0, c + d0 * r1, normal, normal, normal)
		_tri(st, c + d1 * r0, c + d1 * r1, c + d0 * r1, normal, normal, normal)


## Surface of revolution around Y from a closed (radius, y) profile. Normals are smooth round the turn and across
## gentle profile corners, split at sharp ones.
static func _lathe(st: SurfaceTool, prof: PackedVector2Array, segs: int) -> void:
	var m: int = prof.size()
	var cx: Vector2 = Vector2.ZERO
	for p: Vector2 in prof:
		cx += p
	cx /= float(m)
	var seg_n: Array = []
	for i: int in m - 1:
		var t: Vector2 = prof[i + 1] - prof[i]
		var nn: Vector2 = Vector2(t.y, -t.x).normalized()
		var mid: Vector2 = (prof[i] + prof[i + 1]) * 0.5
		if nn.dot(mid - cx) < 0.0:
			nn = -nn
		seg_n.append(nn)
	for i: int in m - 1:
		var na: Vector2 = seg_n[i]
		var nb: Vector2 = seg_n[i]
		if i > 0 and (seg_n[i - 1] as Vector2).dot(seg_n[i]) > 0.64:
			na = ((seg_n[i - 1] as Vector2) + (seg_n[i] as Vector2)).normalized()
		if i < m - 2 and (seg_n[i + 1] as Vector2).dot(seg_n[i]) > 0.64:
			nb = ((seg_n[i + 1] as Vector2) + (seg_n[i] as Vector2)).normalized()
		for k: int in segs:
			var a0: float = TAU * float(k) / float(segs)
			var a1: float = TAU * float(k + 1) / float(segs)
			var d0: Vector3 = Vector3(sin(a0), 0.0, -cos(a0))
			var d1: Vector3 = Vector3(sin(a1), 0.0, -cos(a1))
			var p0: Vector2 = prof[i]
			var p1: Vector2 = prof[i + 1]
			var v00: Vector3 = d0 * p0.x + Vector3.UP * p0.y
			var v01: Vector3 = d1 * p0.x + Vector3.UP * p0.y
			var v10: Vector3 = d0 * p1.x + Vector3.UP * p1.y
			var v11: Vector3 = d1 * p1.x + Vector3.UP * p1.y
			var n00: Vector3 = (d0 * na.x + Vector3.UP * na.y).normalized()
			var n01: Vector3 = (d1 * na.x + Vector3.UP * na.y).normalized()
			var n10: Vector3 = (d0 * nb.x + Vector3.UP * nb.y).normalized()
			var n11: Vector3 = (d1 * nb.x + Vector3.UP * nb.y).normalized()
			_tri(st, v00, v01, v10, n00, n01, n10)
			_tri(st, v01, v11, v10, n01, n11, n10)


static func _new_st() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## The SurfaceTool for one palette key in a builder dictionary, made on first use.
static func _st(builders: Dictionary, key: String) -> SurfaceTool:
	if not builders.has(key):
		builders[key] = _new_st()
	return builders[key]


## Adds a triangle wound clockwise as seen from the side its normals point to (Godot's front face).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face: Vector3 = (b - a).cross(c - a)
	var avg: Vector3 = na + nb + nc
	if face.length() < 0.0000001:
		return
	if face.dot(avg) > 0.0:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nc)
		st.add_vertex(c)
		st.set_normal(nb)
		st.add_vertex(b)
	else:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nb)
		st.add_vertex(b)
		st.set_normal(nc)
		st.add_vertex(c)
