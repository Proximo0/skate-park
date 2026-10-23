class_name SchoolPickup
extends Collectible
## The School level's pickups: the usual letter coins, plus the secret tape (a video cassette) and the lost textbooks.
## Same pickup behaviour as Collectible (spin, bob, fade near the camera, pop when taken); only the visual differs.

const TAPE_BODY := Color("2a2a33")
const TAPE_LABEL := Color("f2b632")
const BOOK_COLOURS: Array[Color] = [Color("d9483b"), Color("3f7fd1"), Color("4fae5a"), Color("8a5cc7"), Color("e88a2a")]


func _build_letter() -> void:
	if item == "tape":
		_build_tape()
	elif item == "book":
		_build_book()
	else:
		super._build_letter()


func _build_tape() -> void:
	_part(Vector3(0.0, 0.0, 0.0), Vector3(0.62, 0.36, 0.08), TAPE_BODY)
	_part(Vector3(0.0, 0.07, 0.042), Vector3(0.44, 0.13, 0.01), TAPE_LABEL)
	for x: float in [-0.13, 0.13]:
		_part(Vector3(x, -0.06, 0.042), Vector3(0.09, 0.09, 0.01), Color("e9e4da"))
	# a gold ring round it so it reads as a pickup from afar
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.47
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = Toon.material(COIN_COLOR)
	_visual.add_child(ring)


func _build_book() -> void:
	var c: Color = BOOK_COLOURS[posmod(int(position.x * 3.0 + position.z), BOOK_COLOURS.size())]
	_part(Vector3(0.0, 0.0, 0.0), Vector3(0.46, 0.6, 0.12), c)
	_part(Vector3(0.012, 0.0, 0.0), Vector3(0.43, 0.56, 0.1), Color("f4efe2"))
	_part(Vector3(-0.2, 0.0, 0.0), Vector3(0.06, 0.6, 0.13), c.darkened(0.25))
	_part(Vector3(0.0, 0.12, 0.062), Vector3(0.3, 0.08, 0.005), Color("f4efe2"))


func _part(pos: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = Toon.material(c)
	_visual.add_child(mi)
