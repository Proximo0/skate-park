class_name SchoolLevel
extends Level
## School: a STUB for the level builder to replace (see README.md here and docs/levels.md). It already fulfils the
## Level contract: a skateable ground, boundary walls, a spawn on the floor, one ramp from the existing pieces and
## its mood preset (LevelRegistry sets mood_id; setup_environment() builds the sky, sun and fog).

## Half size of the riding square (x and z in [-HALF, HALF]).
const HALF: float = 50.0
const SPAWN_POS := Vector3(0.0, 0.1, 25.0)

func _init() -> void:
	spawn = Transform3D(Basis.IDENTITY, SPAWN_POS)  # facing -Z, toward the ramp
	bounds = Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	kill_y = Level.DEFAULT_KILL_Y


func _ready() -> void:
	setup_environment()
	var ground: StaticBody3D = add_ground(bounds.grow(8.0), 0.0, Color("9aa2ad"))
	WorldSurface.apply(ground, "concrete", Color("9aa2ad"))
	add_boundary()
	add_backdrop("grass", Color("79a352"))
	put(QuarterPipe.build(12.0, 3.0, 3.2, 1.5), Vector3(-6.0, 0.0, -HALF + 2.0), 0.0, "QuarterPipe")
