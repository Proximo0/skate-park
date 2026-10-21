class_name GarmentShoes
extends RefCounted
## Shoe garments (slot "shoes"). Contract and registration: see Wardrobe (game/skater/wardrobe.gd).
## Built: shoes_low_vulc (SkateShoe, Old Skool style). Colours come from the "shoe_*" palette keys (SkateShoe.PRESETS;
## SkaterBuilder maps a loadout colour through SkateShoe.colourway_from).

const STUBS: PackedStringArray = ["shoes_cupsole", "shoes_puffy", "shoes_high_top"]


static func builders() -> Dictionary:
	return {
		"shoes_low_vulc": GarmentShoes.low_vulc,
		"shoes_cupsole": GarmentShoes._stub.bind("shoes_cupsole"),
		"shoes_puffy": GarmentShoes._stub.bind("shoes_puffy"),
		"shoes_high_top": GarmentShoes._stub.bind("shoes_high_top"),
	}


static func covers(_id: String, _body_type: String) -> PackedStringArray:
	return PackedStringArray()


static func _stub(rig: Dictionary, body_type: String, mats: Dictionary, id: String) -> void:
	Wardrobe.stub(rig, body_type, mats, "shoes", id, GarmentShoes.low_vulc)


## Low vulcanised skate shoe on each foot ("<Side>ShoeMesh" under <Side>Foot), sole bottom at -ankle height.
static func low_vulc(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		SkateShoe.build(rig[side + "Foot"], side, float(rig["lengths"]["ankle"]), mats)
