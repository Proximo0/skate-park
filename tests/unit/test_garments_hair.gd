extends TestCase
## Hair styles and head accessories: every catalog hair style builds on each body it allows (no stub warnings, a
## cap, tapered locks), long styles carry sway pivots, head + hair stays under the triangle budget, and the hair
## keeps clear of the shoulders, chest and arms in the riding poses and with the head turned hard either way (the
## sway pivots settled under gravity, as the hair hangs in game).


## These tests check the lofted garments and code parts on the Houdini body (the VRM body wears none of them), so
## bodies built without a "skin" option use it while a test of this file runs.
func _init() -> void:
	PlaceholderSkater.houdini_scopes += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PlaceholderSkater.houdini_scopes -= 1

const BUDGET: int = 25000
## Extra allowed for head accessories on top (the cap hides the hair it covers, so it mostly pays for itself).
const ACC_BUDGET: int = 2500
## Hair may come no closer than this to the upper-body skin (metres, signed: negative is inside).
const CLEARANCE: float = 0.004
## Styles whose long parts must sway: style -> pivot names that must exist.
const SWAY: Dictionary = {
	"hair_long": ["HairSway_SideL", "HairSway_SideR", "HairSway_Back", "HairSway_Back2"],
	"hair_bob": ["HairSway_SideL", "HairSway_SideR"],
	"hair_pigtails": ["HairSway_PigtailL", "HairSway_PigtailL2", "HairSway_PigtailR", "HairSway_PigtailR2",
			"HairSway_SideL", "HairSway_SideR"],
	"hair_bun": ["HairSway_SideL", "HairSway_SideR"],
	"hair_shaggy": ["HairSway_SideL", "HairSway_SideR", "HairSway_Nape"],
	"hair_short_spiky": ["HairSway_Fringe"],
	"hair_undercut": ["HairSway_Fringe"],
}
## [anim, t, crouch, speed, phase]: the held riding poses (the head looks over the lead shoulder) and walking. The
## split-second airborne poses (the ollie pop, grabs) are left out: the hair is mid-swing there, not hanging.
const POSES: Array = [
	["idle_ride", 0.0, 0.0, 0.0, 0.0], ["crouch", 0.0, 1.0, 0.0, 0.0], ["push", 0.5, 0.0, 0.0, 0.0],
	["grind_five_oh", 0.3, 0.6, 0.0, 0.0], ["grind_boardslide", 0.3, 0.6, 0.0, 0.0],
	["manual_manual", 0.3, 0.2, 0.0, 0.0], ["walk", 0.0, 0.0, 1.4, 0.3],
]
## Extra head turns (radians) on top of the standing pose: hard over each shoulder, and tilted.
const TURNS: Array = [Vector3(0.0, 1.2, 0.0), Vector3(0.0, -1.2, 0.0), Vector3(0.15, 0.9, 0.12), Vector3(-0.15, -0.9, -0.12)]
## Skin regions the hair must keep clear of: the shoulders and chest. The neck, the neck base round it and the head
## may be touched (looking up presses the nape on them, skin and all); upper arms raised in a balance pose reach up
## into any hair that hangs past the shoulders, so they are left out.
const CLEAR_OF: PackedStringArray = ["chest_upper", "chest", "bust", "shoulder", "under_bust"]


## Hair style id -> bodies it allows, from the catalog.
static func style_bodies() -> Dictionary:
	var out: Dictionary = {}
	for it: Dictionary in PartCatalog.load_default().all_items():
		if str(it.get("slot", "")) == "hair":
			out[str(it["mesh_builder"])] = Array(it.get("bodies", []))
	return out


static func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c: Node in node.get_children():
		_meshes(c, out)


## Visible, with every ancestor visible (works outside the scene tree).
static func shown(n: Node) -> bool:
	var a: Node = n
	while a != null:
		if a is Node3D and not (a as Node3D).visible:
			return false
		a = a.get_parent()
	return true


## Transform of node in the space of `ancestor`, composed by hand (no scene tree needed).
static func rel(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var a: Node3D = node
	while a != null and a != ancestor:
		t = a.transform * t
		a = a.get_parent() as Node3D
	return t


static func tris(mi: MeshInstance3D) -> int:
	var t: int = 0
	for s: int in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			t += (idx as PackedInt32Array).size() / 3
		else:
			t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


## Visible triangles under HeadModel and every HairSway_ pivot (the long hair can hang from the neck).
static func head_tris(body: Node3D) -> int:
	var seen: Dictionary = {}
	var t: int = 0
	var roots: Array = [body.find_child("HeadModel", true, false)]
	roots.append_array(body.find_children("HairSway_*", "Node3D", true, false))
	for r: Node in roots:
		var ms: Array[MeshInstance3D] = []
		_meshes(r, ms)
		for mi: MeshInstance3D in ms:
			if shown(mi) and not seen.has(mi):
				seen[mi] = true
				t += tris(mi)
	return t


## Hair meshes: visible meshes whose palette key starts with "hair".
static func hair_meshes(body: Node3D) -> Array[MeshInstance3D]:
	var all: Array[MeshInstance3D] = []
	_meshes(body, all)
	var out: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in all:
		if shown(mi) and str(mi.get_meta("palette", "")).begins_with("hair"):
			out.append(mi)
	return out


## Smallest signed distance (metres) of any hair vertex from the upper-body skin, as [distance, mesh name]. Each hair
## vertex is measured against its nearest skin vertex along that vertex's normal (negative = inside the skin).
static func clearance(body: Node3D) -> Array:
	var cell: float = 0.03
	var grid: Dictionary = {}
	var all: Array[MeshInstance3D] = []
	_meshes(body, all)
	for mi: MeshInstance3D in all:
		if not mi.has_meta("region"):
			continue
		var reg: String = str(mi.get_meta("region")).trim_suffix("_L").trim_suffix("_R")
		if not CLEAR_OF.has(reg):
			continue
		var xf: Transform3D = mi.global_transform
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i: int in vs.size():
			var p: Vector3 = xf * vs[i]
			var key: Vector3i = Vector3i((p / cell).floor())
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append([p, (xf.basis * ns[i]).normalized(), reg])
	var best: float = 1.0
	var who: String = ""
	for mi: MeshInstance3D in hair_meshes(body):
		var xf: Transform3D = mi.global_transform
		for s: int in mi.mesh.get_surface_count():
			var vs: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in vs:
				var p: Vector3 = xf * v
				var key: Vector3i = Vector3i((p / cell).floor())
				var near_d: float = 0.06
				var near: Array = []
				for dx: int in range(-1, 2):
					for dy: int in range(-1, 2):
						for dz: int in range(-1, 2):
							var k: Vector3i = key + Vector3i(dx, dy, dz)
							if not grid.has(k):
								continue
							for e: Array in grid[k]:
								var d: float = p.distance_to(e[0] as Vector3)
								if d < near_d:
									near_d = d
									near = e
				if near.is_empty():
					continue
				var sd: float = (p - (near[0] as Vector3)).dot(near[1] as Vector3)
				if sd < best:
					best = sd
					who = "%s in %s" % [mi.name, near[2]]
	return [best, who]


## Builds a body on a board under a poser in the scene tree: [holder, body, poser].
static func posed_body(opts: Dictionary) -> Array:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var holder: Node3D = Node3D.new()
	tree.root.add_child(holder)
	var body: Node3D = PlaceholderSkater.build_body({}, opts)
	holder.add_child(body)
	var board: Node3D = Node3D.new()
	holder.add_child(board)
	var poser: SkaterPoser = SkaterPoser.new()
	poser.body = body
	poser.board = board
	poser.set_process(false)
	holder.add_child(poser)
	poser._capture_rest()
	return [holder, body, poser]


## Lets the hair settle under gravity in the current pose (SecondaryMotion, about 1.5 s of fixed ticks), as it
## hangs in game when the skater holds a pose.
## Pivots with meta "sway_fwd_limit_deg" (hair_long's back curtain, which rests on the back) go back to rest: the
## current SecondaryMotion does not read that limit yet, and they clear the back at rest.
static func settle(sm: SecondaryMotion) -> void:
	sm.reset()
	for i: int in 90:
		sm.tick()
	for n: Node3D in sm.pivot_nodes():
		if n.has_meta("sway_fwd_limit_deg"):
			n.basis = Basis.IDENTITY


## Worst clearance over the pose list and the head turns, with the hair settled: [distance, "pose: mesh"].
static func worst_clearance(opts: Dictionary) -> Array:
	var made: Array = posed_body(opts)
	var holder: Node3D = made[0]
	var body: Node3D = made[1]
	var poser: SkaterPoser = made[2]
	var sm: SecondaryMotion = SecondaryMotion.new()
	sm.follow_settings = false
	sm.bind(body)
	var head: Node3D = body.find_child("Head", true, false)
	var worst: Array = [1.0, ""]
	for p: Array in POSES:
		poser._apply(SkaterPoser.pose_for(p[0], p[1], p[2], 0.0, false, p[3], p[4]))
		settle(sm)
		var c: Array = clearance(body)
		if float(c[0]) < float(worst[0]):
			worst = [c[0], "%s: %s" % [p[0], c[1]]]
	poser._apply(SkaterPoser.pose_for("walk", 0.0, 0.0, 0.0, false, 0.0, 0.0))
	var rest: Vector3 = head.rotation
	for t: Vector3 in TURNS:
		head.rotation = rest + t
		settle(sm)
		var c: Array = clearance(body)
		if float(c[0]) < float(worst[0]):
			worst = [c[0], "turn %s: %s" % [t, c[1]]]
	head.rotation = rest
	sm.free()
	holder.free()
	return worst


func test_every_style_builds_on_its_bodies() -> void:
	var styles: Dictionary = style_bodies()
	assert_true(styles.size() >= 10, "catalog lists the hair styles")
	for id: String in styles:
		assert_false(HairStyles.STUBS.has(id), id + " is built, not a stub")
		assert_true(Wardrobe.has_builder("hair", id), id + " is registered")
		for b: Variant in styles[id]:
			var body: Node3D = PlaceholderSkater.build_body({}, {"body": str(b), "hair": id})
			var model: Node3D = body.find_child("HeadModel", true, false)
			assert_true(model.find_child("HairCapMesh", true, false) != null, "%s on %s has a scalp cap" % [id, b])
			var locks: int = 0
			for mi: MeshInstance3D in hair_meshes(body):
				if str(mi.name) != "HairCapMesh":
					locks += 1
			assert_true(locks >= 12, "%s on %s is built from locks (%d)" % [id, b, locks])
			for n: Node in body.find_children("HairSway_*", "Node3D", true, false):
				assert_true((n as Node3D).basis.is_equal_approx(Basis.IDENTITY), "%s %s starts at identity" % [id, n.name])
			body.free()


func test_sway_pivots_for_long_styles() -> void:
	var styles: Dictionary = style_bodies()
	for id: String in SWAY:
		for b: Variant in styles[id]:
			var body: Node3D = PlaceholderSkater.build_body({}, {"body": str(b), "hair": id})
			for pn: String in SWAY[id]:
				var p: Node3D = body.find_child(pn, true, false)
				assert_true(p != null, "%s on %s has %s" % [id, b, pn])
				if p != null:
					var ms: Array[MeshInstance3D] = []
					_meshes(p, ms)
					assert_true(not ms.is_empty(), "%s carries locks" % pn)
				if p != null and pn.right(1).is_valid_int():
					var parent_name: String = str(p.get_parent().name)
					assert_true(parent_name.begins_with("HairSway_"), "%s chains under %s" % [pn, parent_name])
			var sm: SecondaryMotion = SecondaryMotion.new()
			sm.bind(body)
			assert_true(sm.pivot_count() >= (SWAY[id] as Array).size(), "%s pivots found by secondary motion" % id)
			sm.free()
			body.free()


func test_triangle_budget() -> void:
	var styles: Dictionary = style_bodies()
	for id: String in styles:
		for b: Variant in styles[id]:
			for accs: Array in [[], ["acc_cap"], ["acc_headband", "acc_sunnies"]]:
				var body: Node3D = PlaceholderSkater.build_body({}, {"body": str(b), "hair": id, "accessories": accs})
				var t: int = head_tris(body)
				var limit: int = BUDGET if accs.is_empty() else BUDGET + ACC_BUDGET
				assert_true(t < limit, "%s on %s %s: %d head + hair triangles" % [id, b, accs, t])
				body.free()


func test_hair_clears_the_shoulders() -> void:
	var styles: Dictionary = style_bodies()
	for id: String in styles:
		for b: Variant in styles[id]:
			var w: Array = worst_clearance({"body": str(b), "hair": id, "top": "none", "accessories": []})
			assert_true(float(w[0]) >= CLEARANCE, "%s on %s clears the shoulders: %.4f at %s" % [id, b, w[0], w[1]])


func test_bangs_end_above_the_brows() -> void:
	for id: String in style_bodies():
		for b: Variant in style_bodies()[id]:
			var body: Node3D = PlaceholderSkater.build_body({}, {"body": str(b), "hair": id})
			var model: Node3D = body.find_child("HeadModel", true, false)
			var face: Dictionary = AnimeHead.FACES[str(b)]
			var brow_y: float = float(face["brow_y"])
			var eye_y: float = float(face["eye_y"])
			var eye_x: float = float(face["eye_x"]) + float(face["eye_w"]) * 0.5
			var low: float = 1.0
			for mi: MeshInstance3D in hair_meshes(body):
				var xf: Transform3D = rel(model, body).affine_inverse() * rel(mi, body)
				for v: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					var p: Vector3 = xf * v
					# In front of the face, over the eyes (side locks under the chin are not bangs).
					if p.z < -0.06 and absf(p.x) < eye_x and p.y > eye_y - 0.03:
						low = minf(low, p.y)
			assert_true(low >= brow_y - 0.008, "%s on %s: bangs end at %.3f, brows at %.3f" % [id, b, low, brow_y])
			body.free()


func test_cap_and_accessories_build() -> void:
	for b: String in ["female", "male"]:
		var hair: String = "hair_long" if b == "female" else "hair_shaggy"
		var body: Node3D = PlaceholderSkater.build_body({}, {"body": b, "hair": hair,
				"accessories": ["acc_cap", "acc_sunnies", "acc_wristbands"]})
		assert_true(body.find_child("AccCapCrownMesh", true, false) != null, b + " cap")
		assert_true(body.find_child("AccCapBrimMesh", true, false) != null, b + " cap brim")
		assert_true(body.find_child("AccSunniesFrameMesh", true, false) != null, b + " sunnies")
		var cap_holder: Node3D = body.find_child("AccCap", true, false)
		assert_true(cap_holder != null and str(cap_holder.get_meta("cap_style", "")) == "backwards", "the cap is worn backwards")
		body.free()
		var hb: Node3D = PlaceholderSkater.build_body({}, {"body": b, "accessories": ["acc_headband"]})
		assert_true(hb.find_child("AccHeadbandMesh", true, false) != null, b + " headband")
		hb.free()
	for id: String in ["acc_cap", "acc_headband", "acc_sunnies", "acc_wristbands"]:
		assert_false(GarmentAccessories.STUBS.has(id), id + " is built")


## The cap hides or tucks the hair under it: no hair vertex pokes out through the crown.
func test_hair_stays_under_the_cap() -> void:
	var styles: Dictionary = style_bodies()
	for id: String in styles:
		for b: Variant in styles[id]:
			for fwd: bool in [false, true]:
				var body: Node3D = PlaceholderSkater.build_body({}, {"body": str(b), "hair": id})
				var rig: Dictionary = PlaceholderSkater.rig_of(body)
				var mats: Dictionary = {}
				if fwd:
					GarmentAccessories.cap_forward(rig, str(b), mats)
				else:
					GarmentAccessories.cap(rig, str(b), mats)
				var model: Node3D = rig["HeadModel"]
				var out: int = 0
				for mi: MeshInstance3D in hair_meshes(body):
					var xf: Transform3D = rel(model, body).affine_inverse() * rel(mi, body)
					for v: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
						if GarmentAccessories.pokes_through_cap(xf * v, fwd, str(b)):
							out += 1
				assert_eq(out, 0, "%s on %s (%s cap): hair vertices through the cap" % [id, b, "forward" if fwd else "backwards"])
				body.free()
