class_name GarmentSocks
extends RefCounted
## Sock garments (slot "socks"). Contract and registration: see Wardrobe (game/skater/wardrobe.gd).
## Built: socks_crew (high crew sock with three stripes under the cuff). Palette keys: "sock", "sock_stripe",
## "sock_stripe2".

const STUBS: PackedStringArray = ["socks_tube", "socks_ankle", "socks_striped"]
const CUFF_ABOVE_ANKLE: float = 0.15  ## crew cuff height above the ankle joint (about 0.27 above the soles)


static func builders() -> Dictionary:
	return {
		"socks_crew": GarmentSocks.crew,
		"socks_tube": GarmentSocks._stub.bind("socks_tube"),
		"socks_ankle": GarmentSocks._stub.bind("socks_ankle"),
		"socks_striped": GarmentSocks._stub.bind("socks_striped"),
	}


static func covers(id: String, _body_type: String) -> PackedStringArray:
	if id == "socks_crew":
		return PackedStringArray(["calf_low_L", "calf_low_R", "ankle_L", "ankle_R"])
	return PackedStringArray()


static func _stub(rig: Dictionary, body_type: String, mats: Dictionary, id: String) -> void:
	Wardrobe.stub(rig, body_type, mats, "socks", id, GarmentSocks.crew)


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
