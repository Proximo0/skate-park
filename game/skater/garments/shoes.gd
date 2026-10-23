class_name GarmentShoes
extends RefCounted
## Shoe garments (slot "shoes"). Contract and registration: see Wardrobe (game/skater/wardrobe.gd).
## Built, all on the same "shoe_*" palette keys (SkateShoe.PRESETS; SkaterBuilder maps a loadout colour through
## SkateShoe.colourway_from) and the same foot contract ("<Side>ShoeMesh" under <Side>Foot, sole bottom at -ankle
## height, about 0.31 m long so the feet stay planted on the deck):
## - shoes_low_vulc: SkateShoe, Old Skool style low vulc.
## - shoes_cupsole: ShoeStyles.build_cupsole, Nike SB Dunk Low style stitched cupsole.
## - shoes_puffy: ShoeStyles.build_puffy, 2000s Osiris / DC / es style.
## - shoes_high_top: ShoeStyles.build_high_top, Vans Sk8-Hi style. Its collar is a loft of the calf sections hung on the
##   lower leg joint (named "<Side>Shoe...Mesh" under <Side>LowerLeg, not under the shoe node), so it covers the
##   skin's "ankle" region in every pose.

const STUBS: PackedStringArray = []


static func builders() -> Dictionary:
	return {
		"shoes_low_vulc": GarmentShoes.low_vulc,
		"shoes_cupsole": GarmentShoes.cupsole,
		"shoes_puffy": GarmentShoes.puffy,
		"shoes_high_top": GarmentShoes.high_top,
	}


static func covers(id: String, _body_type: String) -> PackedStringArray:
	if id == "shoes_high_top":
		return PackedStringArray(["ankle_L", "ankle_R"])
	return PackedStringArray()


## Low vulcanised skate shoe on each foot ("<Side>ShoeMesh" under <Side>Foot), sole bottom at -ankle height.
static func low_vulc(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		SkateShoe.build(rig[side + "Foot"], side, float(rig["lengths"]["ankle"]), mats)


## Cupsole skate shoe (Nike SB Dunk Low style): stitched cup wall, overlay panels, side wave, fat tongue.
static func cupsole(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		ShoeStyles.build_cupsole(rig[side + "Foot"], side, float(rig["lengths"]["ankle"]), mats)


## Puffy 2000s skate shoe (Osiris / DC / es style): pillow tongue and collar, bumper sole, badge, lace cover.
static func puffy(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		ShoeStyles.build_puffy(rig[side + "Foot"], side, float(rig["lengths"]["ankle"]), mats)


## High-top skate shoe (Vans Sk8-Hi style): vulc sole, padded collar over the ankle, ankle panels, 8 eyelets. The shaft
## hangs on the lower leg (like a sock) so it follows the shin; the low part hangs on the foot.
static func high_top(rig: Dictionary, _body_type: String, mats: Dictionary) -> void:
	for sd: Array in Wardrobe.sides():
		var side: String = sd[0]
		ShoeStyles.build_high_top(rig[side + "Foot"], rig[side + "LowerLeg"], side, float(rig["lengths"]["ankle"]),
				rig["sections"]["calf"], float(rig["lengths"]["lower_leg"]), mats)
