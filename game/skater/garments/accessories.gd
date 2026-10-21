class_name GarmentAccessories
extends RefCounted
## Accessories (slot "accessory", several at once). Contract and registration: see Wardrobe
## (game/skater/wardrobe.gd). Built: acc_wristbands (palette keys "band" and "trim").
## Accessory stubs only warn: there is no reference accessory to fall back on.

const STUBS: PackedStringArray = ["acc_cap", "acc_headband", "acc_sunnies"]


static func builders() -> Dictionary:
	return {
		"acc_wristbands": GarmentAccessories.wristbands,
		"acc_cap": GarmentAccessories._stub.bind("acc_cap"),
		"acc_headband": GarmentAccessories._stub.bind("acc_headband"),
		"acc_sunnies": GarmentAccessories._stub.bind("acc_sunnies"),
	}


static func covers(_id: String, _body_type: String) -> PackedStringArray:
	return PackedStringArray()


static func _stub(rig: Dictionary, body_type: String, mats: Dictionary, id: String) -> void:
	Wardrobe.stub(rig, body_type, mats, "accessory", id, Callable())


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
