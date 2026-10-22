class_name BeachLevel
extends Level
## Beachfront: a STUB for the level builder to replace (see README.md here and docs/levels.md). It already fulfils the
## Level contract: a skateable ground, boundary walls, a spawn on the floor, one ramp from the existing pieces and
## its mood preset (LevelRegistry sets mood_id; setup_environment() builds the sky, sun and fog).

## Half size of the riding square (x and z in [-HALF, HALF]).
const HALF: float = 50.0
const SPAWN_POS := Vector3(0.0, 0.1, 25.0)
## World z of the still-water line on the sand (the sea lies toward +Z) and the sea level below the slab top.
const SHORE_Z: float = 78.0
const SEA_DROP: float = 1.2


func _init() -> void:
	spawn = Transform3D(Basis.IDENTITY, SPAWN_POS)  # facing -Z, toward the ramp
	bounds = Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	kill_y = Level.DEFAULT_KILL_Y
	preview_view = [Vector3(-18.0, 6.0, 30.0), Vector3(10.0, -1.0, 120.0)]


func _ready() -> void:
	setup_environment()
	var ground: StaticBody3D = add_ground(bounds.grow(8.0), 0.0, Color("a9b4bf"))
	WorldSurface.apply(ground, "concrete", Color("a9b4bf"))
	add_boundary()
	put(QuarterPipe.build(12.0, 3.0, 3.2, 1.5), Vector3(-6.0, 0.0, -HALF + 2.0), 0.0, "QuarterPipe")
	# The sea rolls in from the south (+Z), 1.2 m under the slab; its sand runs from under the slab's edge out to sea.
	var ocean := Ocean.new()
	ocean.name = "Ocean"
	ocean.position = Vector3(0.0, -SEA_DROP, SHORE_Z)
	ocean.berm = SEA_DROP - 0.05  # the dry sand tucks just under the slab top
	add_child(ocean)
	ocean.add_beach(900.0, SHORE_Z + 400.0, 80.0)  # sand all the way inland past the slab
	_bay_dressing()


## The bay round the sea: headlands either side, an island on the horizon, a sailboat and a few palms (kit pieces).
func _bay_dressing() -> void:
	var kit: LevelKit = LevelKit.open("beach")
	var sea_y: float = -SEA_DROP
	kit.place(self, "headland_left", Vector3(-185.0, sea_y - 0.5, SHORE_Z + 60.0), deg_to_rad(-20.0), {"collide": false})
	kit.place(self, "headland_right", Vector3(180.0, sea_y - 0.5, SHORE_Z + 45.0), deg_to_rad(15.0), {"collide": false})
	kit.place(self, "distant_island", Vector3(-60.0, sea_y - 0.5, SHORE_Z + 700.0), 0.0, {"collide": false, "scale": 2.0, "shadow": false})
	kit.place(self, "sailboat", Vector3(70.0, sea_y - 0.3, SHORE_Z + 160.0), deg_to_rad(70.0), {"collide": false})
	for p: Vector3 in [Vector3(-38.0, 0.0, 44.0), Vector3(-31.0, 0.0, 47.0), Vector3(34.0, 0.0, 45.0)]:
		kit.place(self, ["palm_tree_a", "palm_tree_b", "palm_tree_c"][int(absf(p.x)) % 3], p, p.x * 0.1)
