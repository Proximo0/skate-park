class_name WorldDemo
extends Level
## A small city crossroads showing the whole world kit working together: two-way traffic on block loops with signals,
## pedestrians on the sidewalks (walkers, a chatting group, idlers), swaying trees, pigeons and a steam vent. Not a
## playable level (it is not in LevelRegistry); it is the worked example docs/levels.md points at, and the scene the
## world-kit renders and the traffic/pedestrian sims use. Read its _ready() top to bottom as a recipe.

const ROAD_HALF: float = 4.0  ## a road is 8 m wide: two 4 m lanes
const WALK_W: float = 3.0  ## sidewalk width
const CURB: float = 0.15
const BLOCK := Rect2(-60.0, -40.0, 120.0, 80.0)  ## road centre lines: x = -60, 0, 60 and z = -40, 40

var traffic: Traffic
var crowd: Pedestrians


func _init() -> void:
	spawn = Transform3D(Basis.IDENTITY, Vector3(-20.0, 0.1, 0.0))
	bounds = Rect2(-70.0, -50.0, 140.0, 100.0)
	if mood_id == "":
		mood_id = "city_afternoon"


func _ready() -> void:
	setup_environment()
	_ground()
	add_boundary()
	_traffic()
	_people()
	_dressing()


## Asphalt everywhere, raised concrete sidewalk slabs round each block.
func _ground() -> void:
	var road: StaticBody3D = add_ground(bounds.grow(60.0), 0.0, Color("4a4e5a"), "Road")
	WorldSurface.apply(road, "asphalt")
	for block: Rect2 in [Rect2(-60.0, -40.0, 60.0, 80.0), Rect2(0.0, -40.0, 60.0, 80.0)]:
		var inner: Rect2 = block.grow(-ROAD_HALF)
		var walk: StaticBody3D = PieceKit.box(Vector3(inner.position.x, 0.0, inner.position.y), Vector3(inner.size.x, CURB, inner.size.y), Color("a7adb8"), "Sidewalk")
		WorldSurface.apply(walk, "concrete", Color("b3b8c2"), 0.5)
		add_child(walk)
		var lawn_r: Rect2 = inner.grow(-WALK_W)
		var lawn: StaticBody3D = PieceKit.box(Vector3(lawn_r.position.x, 0.0, lawn_r.position.y), Vector3(lawn_r.size.x, CURB + 0.02, lawn_r.size.y), Color("79a352"), "Lawn")
		WorldSurface.apply(lawn, "grass")
		add_child(lawn)
	# zebra crossings at the two junctions on the middle road (visual only)
	for z: float in [-40.0, 40.0]:
		for i: int in 7:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 0.02, 3.2)
			bar.mesh = bm
			bar.position = Vector3(-ROAD_HALF + 0.6 + float(i) * 1.15, 0.01, z + (-ROAD_HALF - 2.0 if z < 0.0 else ROAD_HALF + 2.0))
			bar.material_override = Toon.material(Color("e8e6e0"), false)
			add_child(bar)


## Two block loops sharing the middle road, each car on the right of its road; signals at the two T-junctions.
func _traffic() -> void:
	traffic = Traffic.new()
	traffic.name = "Traffic"
	add_child(traffic)
	var west: LanePath = LanePath.block_loop(Rect2(-60.0, -40.0, 60.0, 80.0), 0.0, 9.0, true).offset(2.0)
	var east: LanePath = LanePath.block_loop(Rect2(0.0, -40.0, 60.0, 80.0), 0.0, 9.0, false).offset(2.0)
	traffic.add_cars(traffic.add_lane(west, 10.0), 6)
	traffic.add_cars(traffic.add_lane(east, 10.0), 6)
	for z: float in [-40.0, 40.0]:
		traffic.add_signal_poles(traffic.add_intersection(Vector3(0.0, 0.0, z), 9.0, 0.0 if z < 0.0 else 5.0))


## Walkers on the sidewalks, a group chatting on the corner and a couple of idlers.
func _people() -> void:
	crowd = Pedestrians.new()
	crowd.name = "Pedestrians"
	add_child(crowd)
	var y: float = CURB
	var mid: float = ROAD_HALF + WALK_W * 0.5  # sidewalk centre line, from the road centre
	var west_walk := PackedVector3Array([Vector3(-60.0 + mid, y, -40.0 + mid), Vector3(-mid, y, -40.0 + mid), Vector3(-mid, y, 40.0 - mid), Vector3(-60.0 + mid, y, 40.0 - mid)])
	crowd.add_walkers(LanePath.from_points(west_walk, true, 2.0), 6)
	var east_walk := PackedVector3Array([Vector3(mid, y, -40.0 + mid), Vector3(mid, y, 40.0 - mid), Vector3(60.0 - mid, y, 40.0 - mid)])
	crowd.add_walkers(LanePath.from_points(east_walk, false, 2.0), 5)
	crowd.add_group(Vector3(-mid - 0.2, y, 12.0), 3)
	crowd.add_idler(Vector3(mid + 0.4, y, -8.0), PI * 0.5, "phone")
	crowd.add_idler(Vector3(mid + 0.4, y, 4.0), -PI * 0.5, "idle")


func _dressing() -> void:
	var trees := SwayTrees.new()
	trees.name = "Trees"
	for i: int in 6:
		trees.add("round", Vector3(-48.0 + float(i) * 8.0, CURB, -24.0))
		trees.add("round", Vector3(12.0 + float(i) * 8.0, CURB, 24.0))
	trees.add("palm", Vector3(-30.0, CURB, 20.0))
	trees.add("pine", Vector3(40.0, CURB, -20.0))
	add_child(trees)
	add_child(Birds.flock("pigeon", 12, Vector3(0.0, 9.0, 0.0), 16.0))
	var vent: SteamVent = SteamVent.create()
	vent.position = Vector3(2.0, 0.05, 10.0)
	add_child(vent)
