class_name GarmentSocks
extends RefCounted
## Sock garments (slot "socks"). Contract and registration: see Wardrobe (game/skater/wardrobe.gd).
## Built: socks_crew (high crew sock with three stripes under the cuff), socks_tube (tall, two bands at the top),
## socks_ankle (low, mostly hidden by the shoe) and socks_striped (mid-calf, three thin zig-zag stripes spread down the
## leg). Palette keys: "sock", "sock_stripe", "sock_stripe2".

const STUBS: PackedStringArray = []
const TUBE_TOP_Y: float = -0.07  ## tube sock top, LowerLeg y (just under the knee)
const ZIG_TOP_Y: float = -0.115  ## zig-zag sock top (mid-calf; the crew cuff is at about -0.18)
const ANKLE_TOP_ABOVE: float = 0.045  ## ankle sock top above the ankle joint (the shoe collar reaches about 0.01 above it)
const CUFF_ABOVE_ANKLE: float = 0.15  ## crew cuff height above the ankle joint (about 0.27 above the soles)


static func builders() -> Dictionary:
	return {
		"socks_crew": GarmentSocks.crew,
		"socks_tube": GarmentSocks.tube,
		"socks_ankle": GarmentSocks.ankle,
		"socks_striped": GarmentSocks.striped,
	}


static func covers(id: String, _body_type: String) -> PackedStringArray:
	match id:
		"socks_crew", "socks_tube", "socks_striped":
			return PackedStringArray(["calf_low_L", "calf_low_R", "ankle_L", "ankle_R"])
		"socks_ankle":
			return PackedStringArray(["ankle_L", "ankle_R"])
	return PackedStringArray()


## High-crew striped sock over the lower calf and ankle, down into the shoe collar.
static func crew(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	Wardrobe.mat(mats, "sock", Color(0.97, 0.96, 0.92))
	Wardrobe.mat(mats, "sock_stripe", Color(1.0, 0.48, 0.3))
	Wardrobe.mat(mats, "sock_stripe2", Color(0.08, 0.72, 0.74))
	var ll: float = float(rig["lengths"]["lower_leg"])
	var secs: Array = rig["sections"]["calf"]
	var top: float = -ll + CUFF_ABOVE_ANKLE
	var bottom: float = float(secs[secs.size() - 1][0])
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var lower: Node3D = rig[side + "LowerLeg"]
		var sock: Array = AnimeOutfit.clip_desc(secs, top, bottom)
		var toe: Array = (sock[sock.size() - 1] as Array).duplicate()
		toe[0] = bottom - 0.008  ## past the skin's end, so the ankle stays inside the sock
		sock.append(toe)
		SkaterParts.part(lower, side + "SockMesh", SkaterParts.loft(sock, 16, 0.003, true),
				Vector3.ZERO, mats, "sock")
		SkaterParts.part(lower, side + "SockCuffMesh", SkaterParts.loft_ring(secs, top, 0.004, 0.004, 24), Vector3.ZERO, mats, "sock")
		var keys: Array = ["sock_stripe", "sock_stripe2", "sock_stripe"]
		for i: int in 3:
			SkaterParts.part(lower, side + "SockStripe%dMesh" % i, SkaterParts.loft_ring(secs, top - 0.014 - 0.015 * float(i), 0.0035,
					0.0042, 24), Vector3.ZERO, mats, keys[i])


static func _mats(mats: Dictionary) -> void:
	Wardrobe.mat(mats, "sock", Color(0.97, 0.96, 0.92))
	Wardrobe.mat(mats, "sock_stripe", Color(1.0, 0.48, 0.3))
	Wardrobe.mat(mats, "sock_stripe2", Color(0.08, 0.72, 0.74))


## The sock body on one lower leg from y `top` down into the shoe: a loft of the calf sections (clearance `grow`) closed
## by a toe ring past the skin's end, and a cuff ring at the top.
static func _sock_body(lower: Node3D, side: String, secs: Array, top: float, grow: float, cuff_grow: float, mats: Dictionary) -> void:
	var bottom: float = float(secs[secs.size() - 1][0])
	var sock: Array = AnimeOutfit.clip_desc(secs, top, bottom)
	var toe: Array = (sock[sock.size() - 1] as Array).duplicate()
	toe[0] = bottom - 0.008
	sock.append(toe)
	SkaterParts.part(lower, side + "SockMesh", SkaterParts.loft(sock, 20, grow, true), Vector3.ZERO, mats, "sock")
	SkaterParts.part(lower, side + "SockCuffMesh", SkaterParts.loft_ring(secs, top, cuff_grow, 0.004, 28), Vector3.ZERO, mats, "sock")


## A woven band round the sock between heights y0 > y1, standing a little proud of the sock.
static func _band(lower: Node3D, part_name: String, secs: Array, y0: float, y1: float, grow: float, mats: Dictionary, key: String) -> void:
	SkaterParts.part(lower, part_name, SkaterParts.loft(AnimeOutfit.clip_desc(secs, y0, y1), 28, grow, true), Vector3.ZERO, mats, key)


## Tall tube sock: up under the knee, a ribbed cuff and two bands (sock_stripe, sock_stripe2) near the top.
static func tube(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	var secs: Array = rig["sections"]["calf"]
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var lower: Node3D = rig[side + "LowerLeg"]
		_sock_body(lower, side, secs, TUBE_TOP_Y, 0.0035, 0.0055, mats)
		_band(lower, side + "TubeSockBand0Mesh", secs, TUBE_TOP_Y - 0.016, TUBE_TOP_Y - 0.036, 0.0046, mats, "sock_stripe")
		_band(lower, side + "TubeSockBand1Mesh", secs, TUBE_TOP_Y - 0.05, TUBE_TOP_Y - 0.07, 0.0046, mats, "sock_stripe2")


## Ankle sock: just over the shoe collar, a sporty band round the top edge.
static func ankle(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	var secs: Array = rig["sections"]["calf"]
	var top: float = -float(rig["lengths"]["lower_leg"]) + ANKLE_TOP_ABOVE
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var lower: Node3D = rig[side + "LowerLeg"]
		_sock_body(lower, side, secs, top, 0.003, 0.0045, mats)
		_band(lower, side + "AnkleSockBandMesh", secs, top - 0.005, top - 0.014, 0.0042, mats, "sock_stripe")


## Mid-calf sock (higher than the crew's cuff) with three thin zig-zag stripes spaced down the leg (not clustered at
## the cuff), alternating sock_stripe / sock_stripe2 / sock_stripe, and a plain cuff.
static func striped(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	_mats(mats)
	var secs: Array = rig["sections"]["calf"]
	var keys: Array = ["sock_stripe", "sock_stripe2", "sock_stripe"]
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		var lower: Node3D = rig[side + "LowerLeg"]
		_sock_body(lower, side, secs, ZIG_TOP_Y, 0.0033, 0.005, mats)
		for i: int in 3:
			var y: float = ZIG_TOP_Y - 0.03 - 0.034 * float(i)
			var pts: PackedVector3Array = PackedVector3Array()
			var radii: PackedFloat32Array = PackedFloat32Array()
			var n: int = 48
			for k: int in n + 1:
				var a: float = TAU * float(k) / float(n)
				var zig: float = absf(fposmod(a * 4.0 / TAU * 2.0, 2.0) - 1.0) - 0.5  ## triangle wave, 8 teeth round
				pts.append(SkaterParts.section_point(SkaterParts.section_at(secs, y + 0.011 * zig), a, 0.0042))
				radii.append(0.0026)
			SkaterParts.part(lower, side + "SockZigZag%dMesh" % i, SkaterParts.tube(pts, radii, 5), Vector3.ZERO, mats, keys[i])
