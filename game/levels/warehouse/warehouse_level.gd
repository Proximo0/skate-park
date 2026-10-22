class_name WarehouseLevel
extends Level
## Creepy Warehouse: a STUB for the level builder to replace (see README.md here and docs/levels.md). It already fulfils the
## Level contract: a skateable ground, boundary walls, a spawn on the floor, one ramp from the existing pieces and
## its mood preset (LevelRegistry sets mood_id; setup_environment() builds the sky, sun and fog).

## Half size of the riding square (x and z in [-HALF, HALF]).
const HALF: float = 45.0
const SPAWN_POS := Vector3(0.0, 0.1, 25.0)

func _init() -> void:
	spawn = Transform3D(Basis.IDENTITY, SPAWN_POS)  # facing -Z, toward the ramp
	bounds = Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	kill_y = Level.DEFAULT_KILL_Y


func _ready() -> void:
	setup_environment()
	var ground: StaticBody3D = add_ground(bounds.grow(8.0), 0.0, Color("5d6470"))
	WorldSurface.apply(ground, "concrete", Color("5d6470"))
	add_boundary()
	add_backdrop("concrete", Color("4d535e"))
	put(QuarterPipe.build(12.0, 3.0, 3.2, 1.5), Vector3(-6.0, 0.0, -HALF + 2.0), 0.0, "QuarterPipe")
	# A taste of the mood: two sodium lamps over the floor, one of them failing.
	var lamp_a := FlickerLight.sodium_lamp(6.0, false)
	lamp_a.position = Vector3(-8.0, 0.0, 6.0)
	add_child(lamp_a)
	var lamp_b := FlickerLight.sodium_lamp(6.0, true)
	lamp_b.position = Vector3(9.0, 0.0, -12.0)
	add_child(lamp_b)
