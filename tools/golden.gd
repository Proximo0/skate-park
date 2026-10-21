extends SceneTree
## Screenshot golden compare. Headless:
##   godot --headless --path . -s res://tools/golden.gd -- --actual=<dir> --golden=<dir>
## Every PNG in the golden dir is compared with the same name in the actual dir.
## Exit 0 when all pass; 1 on any fail or missing actual image (or no goldens at all).

const MEAN_LIMIT: float = 3.0  # mean absolute channel difference, 0..255 scale (3/255 as a fraction)
const OVER_LIMIT_PCT: float = 2.0  # percent of pixels with any RGB channel differing by more than PIXEL_DELTA
const PIXEL_DELTA: int = 24
const DIFF_GAIN: int = 4


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if not args.has("actual") or not args.has("golden"):
		printerr("golden: usage: godot --headless --path . -s res://tools/golden.gd -- --actual=<dir> --golden=<dir>")
		return 2
	var actual_dir: String = args["actual"]
	var golden_dir: String = args["golden"]

	var names: PackedStringArray = _list_pngs(golden_dir)
	if names.is_empty():
		print("GOLDEN summary fail: no PNG goldens in %s; run tools/golden.sh --bless" % golden_dir)
		return 1

	var pass_n: int = 0
	var fail_n: int = 0
	var missing_n: int = 0
	for file_name: String in names:
		var view: String = file_name.get_basename()
		var golden_path: String = golden_dir.path_join(file_name)
		var actual_path: String = actual_dir.path_join(file_name)
		if not FileAccess.file_exists(actual_path):
			print("GOLDEN %s missing actual=%s" % [view, actual_path])
			missing_n += 1
			continue

		var golden: Image = Image.load_from_file(golden_path)
		var actual: Image = Image.load_from_file(actual_path)
		if golden == null or actual == null or golden.is_empty() or actual.is_empty():
			print("GOLDEN %s fail mean=n/a over=n/a unreadable image" % view)
			fail_n += 1
			continue
		if golden.get_size() != actual.get_size():
			print("GOLDEN %s fail mean=n/a over=n/a size golden=%dx%d actual=%dx%d" % [
				view, golden.get_width(), golden.get_height(), actual.get_width(), actual.get_height()])
			fail_n += 1
			continue

		var metrics: Dictionary = _compare(golden, actual)
		var mean: float = metrics["mean"]
		var over_pct: float = metrics["over_pct"]
		var failed: bool = mean > MEAN_LIMIT or over_pct > OVER_LIMIT_PCT
		print("GOLDEN %s %s mean=%.3f over=%.2f%%" % [view, "fail" if failed else "pass", mean, over_pct])
		if failed:
			fail_n += 1
			_write_diff(metrics["diff"], golden.get_width(), golden.get_height(),
				actual_dir.path_join(view + ".diff.png"))
		else:
			pass_n += 1

	print("GOLDEN summary pass=%d fail=%d missing=%d" % [pass_n, fail_n, missing_n])
	return 0 if fail_n == 0 and missing_n == 0 else 1


func _parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for arg: String in args:
		if arg.begins_with("--actual="):
			out["actual"] = arg.trim_prefix("--actual=")
		elif arg.begins_with("--golden="):
			out["golden"] = arg.trim_prefix("--golden=")
	return out


func _list_pngs(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if file_name.ends_with(".png") and not file_name.ends_with(".diff.png"):
			out.append(file_name)
	out.sort()
	return out


## Both images must be the same size. Returns mean (0..255 scale), over_pct, and the diff pixels (RGBA8).
func _compare(golden: Image, actual: Image) -> Dictionary:
	golden.convert(Image.FORMAT_RGBA8)
	actual.convert(Image.FORMAT_RGBA8)
	var gb: PackedByteArray = golden.get_data()
	var ab: PackedByteArray = actual.get_data()
	var count: int = golden.get_width() * golden.get_height()
	var diff: PackedByteArray = PackedByteArray()
	diff.resize(count * 4)
	var sum: int = 0
	var over: int = 0
	for i: int in count:
		var o: int = i * 4
		var worst: int = 0
		for c: int in 3:
			var d: int = absi(gb[o + c] - ab[o + c])
			sum += d
			worst = maxi(worst, d)
			diff[o + c] = mini(d * DIFF_GAIN, 255)
		diff[o + 3] = 255
		if worst > PIXEL_DELTA:
			over += 1
	return {
		"mean": float(sum) / float(count * 3),
		"over_pct": 100.0 * float(over) / float(count),
		"diff": diff,
	}


func _write_diff(diff: PackedByteArray, width: int, height: int, path: String) -> void:
	var img: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, diff)
	if img == null or img.save_png(path) != OK:
		printerr("golden: could not write diff %s" % path)
