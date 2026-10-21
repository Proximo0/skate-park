class_name AnimeOutfit
extends RefCounted
## Outfit parts of the anime skater girl: hoodie, sleeves, shorts, socks and shoes. Static builders called by
## PlaceholderSkater with the joint to attach to and the palette materials.

## Hoodie torso geometry (chest joint space): the chest sphere's centre height and half sizes, to seat front
## details on its surface.
const TORSO_CENTER_Y: float = 0.04
const TORSO_HALF_Y: float = 0.1725
const TORSO_HALF_Z: float = 0.1425
const TORSO_HALF_X: float = 0.168


## Front of the hoodie: a kangaroo pocket flush on the belly, two drawstrings hanging from the collar and a shell
## necklace that follows the chest curve.
static func build_hoodie_front(chest: Node3D, mats: Dictionary) -> void:
	var pocket_y: float = -0.045
	var pocket: MeshInstance3D = SkaterParts.part(chest, "PocketMesh", SkaterParts.sphere(0.05),
			Vector3(0.0, pocket_y, front_z(0.0, pocket_y) - 0.004), mats, "shirt_dark")
	pocket.scale = Vector3(1.5, 0.78, 0.36)
	# Hem rib band around the bottom of the hoodie.
	# Drawstrings: two cords along the surface from the collar, ending in small beads.
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var pts: PackedVector3Array = PackedVector3Array()
		var radii: PackedFloat32Array = PackedFloat32Array()
		for i: int in 5:
			var y: float = 0.145 - 0.02 * float(i)
			var x: float = s * (0.03 + 0.004 * float(i))
			pts.append(Vector3(x, y, front_z(x, y) - 0.005))
			radii.append(0.0042)
		SkaterParts.part(chest, "Drawstring" + side + "Mesh", SkaterParts.tube(pts, radii, 6), Vector3.ZERO, mats, "trim")
		var bx: float = s * 0.046
		var bead: MeshInstance3D = SkaterParts.part(chest, "DrawstringBead" + side + "Mesh", SkaterParts.sphere(0.009),
				Vector3(bx, 0.058, front_z(bx, 0.058) - 0.006), mats, "trim")
		bead.scale = Vector3(1.0, 1.4, 1.0)
	# Necklace: a string of small shells hanging from the neck in a U, with one bigger shell pendant.
	for i: int in 7:
		var t: float = -1.0 + float(i) / 3.0
		var x: float = t * 0.07
		var y: float = 0.155 - 0.05 * (1.0 - t * t)
		var shell: MeshInstance3D = SkaterParts.part(chest, "ShellNecklace%dMesh" % i, SkaterParts.sphere(0.0105),
				Vector3(x, y, front_z(x, y) - 0.005), mats, "shell")
		shell.scale = Vector3(1.0, 0.85, 0.55)
	var pendant: MeshInstance3D = SkaterParts.part(chest, "ShellPendantMesh", SkaterParts.sphere(0.02),
			Vector3(0.0, 0.092, front_z(0.0, 0.092) - 0.008), mats, "shell")
	pendant.scale = Vector3(1.0, 0.85, 0.4)


## Front surface of the hoodie torso at chest-local (x, y) (z is negative, toward the nose).
static func front_z(x: float, y: float) -> float:
	var k: float = (y - TORSO_CENTER_Y) / TORSO_HALF_Y
	var kx: float = x / TORSO_HALF_X
	return -TORSO_HALF_Z * sqrt(maxf(1.0 - k * k - kx * kx, 0.0))


## Hood bunched at the back of the neck: a rolled rim around the neck (higher at the back) plus a fat soft bunch and
## two fold lumps behind it, lined with the darker hoodie tone.
static func build_hood(chest: Node3D, mats: Dictionary) -> void:
	var roll: MeshInstance3D = SkaterParts.part(chest, "HoodRollMesh", SkaterParts.torus(0.062, 0.13),
			Vector3(0.0, 0.16, 0.012), mats, "shirt")
	roll.rotation.x = -0.3
	var bunch: MeshInstance3D = SkaterParts.part(chest, "HoodBunchMesh", SkaterParts.sphere(0.075),
			Vector3(0.0, 0.17, 0.105), mats, "shirt")
	bunch.scale = Vector3(1.35, 0.8, 0.85)
	for s: float in [-1.0, 1.0]:
		var side: String = "Left" if s < 0.0 else "Right"
		var fold: MeshInstance3D = SkaterParts.part(chest, "HoodFold" + side + "Mesh", SkaterParts.sphere(0.04),
				Vector3(s * 0.085, 0.16, 0.085), mats, "shirt_dark")
		fold.scale = Vector3(1.0, 0.9, 1.1)
	var lining: MeshInstance3D = SkaterParts.part(chest, "HoodLiningMesh", SkaterParts.sphere(0.05),
			Vector3(0.0, 0.215, 0.115), mats, "shirt_dark")
	lining.scale = Vector3(1.5, 0.4, 0.75)


## Hoodie torso: hem, chest, collar and the front details.
static func build_torso(spine: Node3D, chest: Node3D, mats: Dictionary) -> void:
	var hem: MeshInstance3D = SkaterParts.part(spine, "SpineMesh", SkaterParts.sphere(0.12), Vector3.ZERO, mats, "shirt")
	hem.scale = Vector3(1.12, 0.85, 0.95)
	var torso: MeshInstance3D = SkaterParts.part(chest, "ChestMesh", SkaterParts.sphere(0.15), Vector3(0.0, TORSO_CENTER_Y, 0.0), mats, "shirt")
	torso.scale = Vector3(1.12, 1.15, 0.95)
	SkaterParts.part(chest, "HoodieCollarMesh", SkaterParts.torus(0.058, 0.084), Vector3(0.0, 0.17, 0.0), mats, "shirt")
	build_hoodie_front(chest, mats)
	build_hood(chest, mats)
	var hem_rib: MeshInstance3D = SkaterParts.part(spine, "HoodieHemMesh", SkaterParts.torus(0.06, 0.1), Vector3(0.0, -0.065, 0.0), mats, "shirt_dark")
	hem_rib.scale = Vector3(1.12, 1.0, 0.95)


## Oversized hoodie sleeve and mint wristband on an arm.
static func build_sleeve(upper: Node3D, side: String, mats: Dictionary) -> void:
	SkaterParts.part(upper, side + "SleeveMesh", SkaterParts.capsule(0.068, 0.17), Vector3(0.0, -0.085, 0.0), mats, "shirt")
	SkaterParts.part(upper, side + "SleeveCuffMesh", SkaterParts.torus(0.048, 0.076), Vector3(0.0, -0.125, 0.0), mats, "shirt_dark")


static func build_wristband(lower: Node3D, side: String, mats: Dictionary) -> void:
	SkaterParts.part(lower, side + "WristbandMesh", SkaterParts.torus(0.03, 0.05), Vector3(0.0, -0.165, 0.0), mats, "band")


## Cargo shorts: a hem band and a patch pocket on the thigh.
static func build_shorts(upper: Node3D, side: String, upper_leg: float, mats: Dictionary) -> void:
	SkaterParts.part(upper, side + "ShortsHemMesh", SkaterParts.cylinder(0.066, 0.05), Vector3(0.0, -upper_leg + 0.035, 0.0), mats, "pants_dark")
	SkaterParts.part(upper, side + "CargoPocketMesh", SkaterParts.box(Vector3(0.05, 0.07, 0.02)), Vector3(0.0, -0.15, -0.062), mats, "pants_dark")


## Tall striped sock over the whole shin (the capsule) with three stripes at the top.
static func build_sock(lower: Node3D, side: String, lower_leg: float, mats: Dictionary) -> void:
	SkaterParts.part(lower, side + "LowerLegMesh", SkaterParts.capsule(0.048, lower_leg), Vector3(0.0, -lower_leg * 0.5, 0.0), mats, "sock")
	for j: int in 3:
		SkaterParts.part(lower, side + "SockStripe%dMesh" % j, SkaterParts.torus(0.044, 0.058), Vector3(0.0, -0.02 - 0.03 * float(j), 0.0),
				mats, "sock_stripe")


## Chunky skate shoe: coral upper, mint toe cap, thick white sole. The sole bottom sits at -ankle_height (flat on
## the ground).
static func build_shoe(foot: Node3D, side: String, ankle_height: float, mats: Dictionary) -> void:
	var shoe: MeshInstance3D = SkaterParts.part(foot, side + "ShoeMesh", SkaterParts.capsule(ankle_height * 0.5, 0.27),
			Vector3(0.0, -ankle_height * 0.5, -0.05), mats, "shoes")
	shoe.rotation.x = PI * 0.5
	# Rounded rubber sole: a flattened capsule along Z, bottom at -ankle_height.
	var sole: MeshInstance3D = SkaterParts.part(foot, side + "SoleMesh", SkaterParts.capsule(0.03, 0.29),
			Vector3(0.0, -ankle_height + 0.03, -0.05), mats, "sole")
	sole.rotation.x = PI * 0.5
	sole.scale = Vector3(2.2, 1.0, 1.0)
	var toe: MeshInstance3D = SkaterParts.part(foot, side + "ToeCapMesh", SkaterParts.sphere(0.06), Vector3(0.0, -0.06, -0.14), mats, "toe")
	toe.scale = Vector3(1.0, 0.8, 1.0)
