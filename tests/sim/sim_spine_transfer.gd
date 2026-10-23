extends "res://tests/sim/sim_base.gd"
## Spine transfer: the shared park spine (Transfers.spine) is two quarter pipes back to back. A skater who rides up one
## face at street-to-park speed must leave the fin with forward travel (the face ends below vertical) and land on the
## OTHER face, instead of going straight up and coming down on the face they left.

const TR := preload("res://game/park/pieces/transfers.gd")
const SPEEDS: Array = [12.0, 14.0]


func _one(v0: float) -> Dictionary:
	var spine: Node3D = TR.spine(10.0, 2.2, 2.4)
	await sandbox([spine])
	var fin_z: float = _fin_z(spine)
	place(Vector3(5.0, 0.0, fin_z + 14.0), Vector3(0, 0, -1), v0)
	await host.get_tree().physics_frame
	var res: Dictionary = {"left_vz": 0.0, "peak": 0.0, "crossed": false, "land_z": 0.0, "landed": "", "fin_z": fin_z}
	var launched: bool = false
	var best_z: float = INF
	for i: int in 480:
		await tick()
		if not launched and sname() == "AIR" and sk.global_position.y > 1.0:
			launched = true
			res["left_vz"] = sk.velocity.z
		if launched:
			res["peak"] = maxf(res["peak"], sk.global_position.y)
			best_z = minf(best_z, sk.global_position.z)
			if sname() != "AIR" and sk.global_position.y < 2.0:
				res["land_z"] = sk.global_position.z
				res["landed"] = landings[landings.size() - 1] if not landings.is_empty() else "none"
				break
	res["crossed"] = launched and res["land_z"] < fin_z - 0.1
	res["bails"] = bails
	res["launched"] = launched
	await clear()
	return res


## z of the fin (the coping line).
func _fin_z(spine: Node3D) -> float:
	var cop: Node = spine.find_child("Coping", true, false)
	for n: Node in cop.find_children("*", "GrindRail", true, false):
		return (n as GrindRail).points[0].z
	return 2.2


func run() -> Array:
	var rows: Array = []
	for v0: float in SPEEDS:
		var r: Dictionary = await _one(v0)
		var ok: bool = r["launched"] and r["crossed"] and r["bails"] == 0 and r["left_vz"] < -1.0
		rows.append(ok_line("spine_transfer_%dms" % int(v0), ok,
			"left the fin with vz %.1f m/s (need < -1.0 toward the far face), peak y %.1f, landed at z %.1f vs fin z %.1f (need past it), landing %s, bails %d"
			% [r["left_vz"], r["peak"], r["land_z"], r["fin_z"], r["landed"], r["bails"]]))
	return rows
