class_name GraffitiArt
extends RefCounted
## Procedural graffiti textures, drawn in code at load time: no image files. Everything is painted with solid spans into an Image
## at twice the final size, then shrunk (that is the anti-aliasing) and given mipmaps. Crew names are invented.
## `texture(id)` builds and caches one ImageTexture; `ids()` lists them. Headless runs (tests, the bot) get a 4 x 4 stand-in,
## since nothing is rendered there and painting costs real time.
##
## Styles: "throw" bubble-letter throw-ups with outline, shadow and highlight; "tag" slanted wildstyle-ish tags with a swoosh;
## "chibi" anime-style character stickers; and motifs (wave, sun, palm, deck, skull and flower, koi).

const SS: int = 2  ## supersampling factor
const INK := Color("22183a")
const WHITE := Color("fff8ee")
const SPECS: Dictionary = {
	# id: [width px, height px, kind, text or motif, fill, accent]
	"throw_waxy": [384, 192, "throw", "WAXY", Color("ffd23f"), Color("ff5a8a")],
	"throw_mochi": [384, 192, "throw", "MOCHI", Color("ff8ec7"), Color("5ad1e6")],
	"throw_tide": [320, 192, "throw", "TIDE", Color("3fd0d4"), Color("ffd23f")],
	"throw_bonz": [320, 192, "throw", "BONZ", Color("ff8a3d"), Color("7b5cff")],
	"throw_yuzu": [320, 192, "throw", "YUZU", Color("f3e25b"), Color("ff6b6b")],
	"throw_ramen": [384, 192, "throw", "RAMEN", Color("ff5a5f"), Color("ffe08a")],
	"tag_spud": [320, 160, "tag", "SPUD", Color("2a1f5c"), Color("ff5a8a")],
	"tag_koi": [320, 160, "tag", "KOI", Color("ff7a45"), Color("22183a")],
	"tag_zest": [320, 160, "tag", "ZEST", Color("7b5cff"), Color("ffd23f")],
	"tag_flux": [320, 160, "tag", "FLUX", Color("1fa6b8"), Color("22183a")],
	"tag_drip": [320, 160, "tag", "DRIP", Color("e63e7a"), Color("22183a")],
	"chibi_blue": [256, 256, "chibi", "blue", Color("5aa9ff"), Color("ffcf70")],
	"chibi_cap": [256, 256, "chibi", "cap", Color("ff5a5f"), Color("2a2a4a")],
	"chibi_cat": [256, 256, "chibi", "cat", Color("ff9ecb"), Color("fff0a8")],
	"motif_wave": [320, 256, "motif", "wave", Color("2f9bd6"), Color("ffd23f")],
	"motif_sun": [256, 256, "motif", "sun", Color("ffb62e"), Color("ff5a5f")],
	"motif_palm": [256, 320, "motif", "palm", Color("2aa876"), Color("ff7a45")],
	"motif_deck": [192, 320, "motif", "deck", Color("ff5a8a"), Color("ffd23f")],
	"motif_skull": [256, 256, "motif", "skull", Color("fff0dc"), Color("ff6fa8")],
	"motif_koi": [320, 192, "motif", "koi", Color("ff7a45"), Color("fff0dc")],
	"sticker_smile": [64, 64, "sticker", "smile", Color("ffd23f"), INK],
	"sticker_star": [64, 64, "sticker", "star", Color("ff5a8a"), WHITE],
	"sticker_sk8": [64, 64, "sticker", "sk8", Color("3fd0d4"), INK],
	"sticker_heart": [64, 64, "sticker", "heart", Color("b58cff"), WHITE],
}
static var _cache: Dictionary = {}
static var _half_cache: Dictionary = {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in SPECS:
		out.append(k)
	return out


## Pixel size [w, h] of the finished texture for an id.
static func size_of(id: String) -> Vector2i:
	var s: Array = SPECS[id]
	return Vector2i(int(s[0]), int(s[1]))


static func memory_bytes(id: String) -> int:
	var s: Vector2i = size_of(id)
	return int(float(s.x * s.y * 4) * 1.34)


static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id] as Texture2D
	var img: Image
	if DisplayServer.get_name() == "headless":
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 1.0, 1.0, 0.0))
	else:
		img = paint(id)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex


## Paints one id at full detail (always, even headless). Used by `texture` and by the unit test.
static func paint(id: String) -> Image:
	var s: Array = SPECS[id]
	var w: int = int(s[0])
	var h: int = int(s[1])
	var img: Image = Image.create(w * SS, h * SS, false, Image.FORMAT_RGBA8)
	img.fill(Color(INK.r, INK.g, INK.b, 0.0))
	var fill: Color = s[4]
	var accent: Color = s[5]
	match str(s[2]):
		"throw":
			_throw_up(img, str(s[3]), fill, accent)
		"tag":
			_tag(img, str(s[3]), fill, accent)
		"chibi":
			_chibi(img, str(s[3]), fill, accent)
		"motif":
			match str(s[3]):
				"wave":
					_wave(img, fill, accent)
				"sun":
					_sun(img, fill, accent)
				"palm":
					_palm(img, fill, accent)
				"deck":
					_deck(img, fill, accent)
				"skull":
					_skull(img, fill, accent)
				"koi":
					_koi(img, fill, accent)
		"sticker":
			_sticker(img, str(s[3]), fill, accent)
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return img


# ---------------------------------------------------------------------------------------------------------------- primitives

static func _half_widths(r: int) -> PackedInt32Array:
	if _half_cache.has(r):
		return _half_cache[r] as PackedInt32Array
	var out := PackedInt32Array()
	for dy: int in range(-r, r + 1):
		out.append(int(sqrt(maxf(0.0, float(r * r - dy * dy)))))
	_half_cache[r] = out
	return out


static func _disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var ri: int = maxi(1, int(round(r)))
	var hw: PackedInt32Array = _half_widths(ri)
	var x: int = int(round(cx))
	var y: int = int(round(cy))
	var w: int = img.get_width()
	var h: int = img.get_height()
	for i: int in hw.size():
		var yy: int = y - ri + i
		if yy < 0 or yy >= h:
			continue
		var x0: int = maxi(0, x - hw[i])
		var x1: int = mini(w, x + hw[i] + 1)
		if x1 > x0:
			img.fill_rect(Rect2i(x0, yy, x1 - x0, 1), col)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for yy: int in range(maxi(0, int(cy - ry)), mini(h, int(cy + ry) + 1)):
		var t: float = (float(yy) - cy) / ry
		var s: float = 1.0 - t * t
		if s < 0.0:
			continue
		var hw: float = rx * sqrt(s)
		var x0: int = maxi(0, int(cx - hw))
		var x1: int = mini(w, int(cx + hw) + 1)
		if x1 > x0:
			img.fill_rect(Rect2i(x0, yy, x1 - x0, 1), col)


static func _rect(img: Image, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	img.fill_rect(Rect2i(int(x0), int(y0), int(x1 - x0), int(y1 - y0)), col)


## A thick line: discs stamped along it. `r1` (optional, >= 0) tapers the radius toward the end.
static func _line(img: Image, a: Vector2, b: Vector2, r: float, col: Color, r1: float = -1.0) -> void:
	var len: float = a.distance_to(b)
	var end_r: float = r if r1 < 0.0 else r1
	var step: float = maxf(1.5, minf(r, end_r) * 0.55)
	var n: int = maxi(1, int(ceil(len / step)))
	for i: int in n + 1:
		var t: float = float(i) / float(n)
		var p: Vector2 = a.lerp(b, t)
		_disc(img, p.x, p.y, lerpf(r, end_r, t), col)


static func _path(img: Image, pts: PackedVector2Array, r: float, col: Color, r1: float = -1.0) -> void:
	var total: float = 0.0
	for i: int in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var end_r: float = r if r1 < 0.0 else r1
	var run: float = 0.0
	for i: int in range(1, pts.size()):
		var seg: float = pts[i - 1].distance_to(pts[i])
		var t0: float = run / maxf(total, 0.001)
		var t1: float = (run + seg) / maxf(total, 0.001)
		_line(img, pts[i - 1], pts[i], lerpf(r, end_r, t0), col, lerpf(r, end_r, t1))
		run += seg


## Even-odd scanline polygon fill.
static func _poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var y0: float = INF
	var y1: float = -INF
	for p: Vector2 in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var w: int = img.get_width()
	var h: int = img.get_height()
	for yy: int in range(maxi(0, int(y0)), mini(h, int(y1) + 1)):
		var fy: float = float(yy) + 0.5
		var xs: Array[float] = []
		for i: int in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if (a.y <= fy and b.y > fy) or (b.y <= fy and a.y > fy):
				xs.append(a.x + (fy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k: int in range(0, xs.size() - 1, 2):
			var x0: int = maxi(0, int(xs[k]))
			var x1: int = mini(w, int(xs[k + 1]) + 1)
			if x1 > x0:
				img.fill_rect(Rect2i(x0, yy, x1 - x0, 1), col)


## A polygon with a dark rim of `grow` pixels: pass grow > 0 with the ink colour for the outline pass.
static func _poly_grown(img: Image, pts: PackedVector2Array, col: Color, grow: float) -> void:
	_poly(img, pts, col)
	if grow > 0.0:
		for i: int in pts.size():
			_line(img, pts[i], pts[(i + 1) % pts.size()], grow, col)


static func _arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n: int = 10) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in n + 1:
		var a: float = deg_to_rad(lerpf(a0, a1, float(i) / float(n)))
		out.append(Vector2(cx + rx * cos(a), cy + ry * sin(a)))
	return out


static func _chaikin(pts: PackedVector2Array, iters: int) -> PackedVector2Array:
	var cur: PackedVector2Array = pts
	for _k: int in iters:
		if cur.size() < 3:
			return cur
		var nxt := PackedVector2Array()
		nxt.append(cur[0])
		for i: int in range(cur.size() - 1):
			nxt.append(cur[i].lerp(cur[i + 1], 0.25))
			nxt.append(cur[i].lerp(cur[i + 1], 0.75))
		nxt.append(cur[cur.size() - 1])
		cur = nxt
	return cur


static func _star(c: Vector2, r_out: float, r_in: float, points: int, rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in points * 2:
		var a: float = rot + PI * float(i) / float(points) - PI * 0.5
		var r: float = r_out if i % 2 == 0 else r_in
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


# ------------------------------------------------------------------------------------------------------------------- letters

static func _letter(ch: String) -> Array:
	## Stroke skeletons in a unit box (x right, y down). Round bits are sampled arcs.
	var v := func(x: float, y: float) -> Vector2: return Vector2(x, y)
	match ch:
		"A":
			return [[v.call(0, 1), v.call(0.5, 0), v.call(1, 1)], [v.call(0.2, 0.68), v.call(0.8, 0.68)]]
		"B":
			var top: Array[Vector2] = _arc(0.6, 0.25, 0.25, 0.25, -90, 90, 8)
			var bot: Array[Vector2] = _arc(0.62, 0.75, 0.28, 0.25, -90, 90, 8)
			var p: Array = [v.call(0, 1), v.call(0, 0), v.call(0.6, 0)]
			p.append_array(top)
			p.append_array([v.call(0, 0.5), v.call(0.62, 0.5)])
			p.append_array(bot)
			p.append(v.call(0, 1))
			return [p]
		"C":
			return [_arc(0.55, 0.5, 0.5, 0.5, -45, -315, 14)]
		"D":
			var p: Array = [v.call(0, 0), v.call(0, 1), v.call(0.35, 1)]
			p.append_array(_arc(0.35, 0.5, 0.6, 0.5, 90, -90, 10))
			p.append(v.call(0, 0))
			return [p]
		"E":
			return [[v.call(1, 0), v.call(0, 0), v.call(0, 1), v.call(1, 1)], [v.call(0, 0.5), v.call(0.7, 0.5)]]
		"F":
			return [[v.call(1, 0), v.call(0, 0), v.call(0, 1)], [v.call(0, 0.5), v.call(0.7, 0.5)]]
		"G":
			var p: Array = _arc(0.5, 0.5, 0.5, 0.5, -40, -300, 14)
			p.append_array([v.call(1, 0.56), v.call(0.55, 0.56)])
			return [p]
		"H":
			return [[v.call(0, 0), v.call(0, 1)], [v.call(1, 0), v.call(1, 1)], [v.call(0, 0.5), v.call(1, 0.5)]]
		"I":
			return [[v.call(0.5, 0), v.call(0.5, 1)]]
		"J":
			var p: Array = [v.call(0.85, 0), v.call(0.85, 0.65)]
			p.append_array(_arc(0.5, 0.65, 0.35, 0.35, 0, 180, 8))
			return [p]
		"K":
			return [[v.call(0, 0), v.call(0, 1)], [v.call(1, 0), v.call(0, 0.58), v.call(1, 1)]]
		"L":
			return [[v.call(0, 0), v.call(0, 1), v.call(0.9, 1)]]
		"M":
			return [[v.call(0, 1), v.call(0, 0), v.call(0.5, 0.62), v.call(1, 0), v.call(1, 1)]]
		"N":
			return [[v.call(0, 1), v.call(0, 0), v.call(1, 1), v.call(1, 0)]]
		"O":
			return [_arc(0.5, 0.5, 0.5, 0.5, 0, 360, 20)]
		"P":
			var p: Array = [v.call(0, 1), v.call(0, 0), v.call(0.6, 0)]
			p.append_array(_arc(0.6, 0.28, 0.4, 0.28, -90, 90, 8))
			p.append(v.call(0, 0.56))
			return [p]
		"Q":
			return [_arc(0.5, 0.5, 0.5, 0.5, 0, 360, 20), [v.call(0.6, 0.7), v.call(1.0, 1.05)]]
		"R":
			var p: Array = [v.call(0, 1), v.call(0, 0), v.call(0.6, 0)]
			p.append_array(_arc(0.6, 0.28, 0.4, 0.28, -90, 90, 8))
			p.append(v.call(0, 0.56))
			return [p, [v.call(0.45, 0.56), v.call(1, 1)]]
		"S":
			var p: Array = _arc(0.5, 0.27, 0.5, 0.27, -30, -270, 9)
			p.append_array(_arc(0.5, 0.77, 0.5, 0.27, -90, 150, 9))
			return [p]
		"T":
			return [[v.call(0, 0), v.call(1, 0)], [v.call(0.5, 0), v.call(0.5, 1)]]
		"U":
			var p: Array = [v.call(0, 0), v.call(0, 0.62)]
			p.append_array(_arc(0.5, 0.62, 0.5, 0.38, 180, 0, 10))
			p.append(v.call(1, 0))
			return [p]
		"V":
			return [[v.call(0, 0), v.call(0.5, 1), v.call(1, 0)]]
		"W":
			return [[v.call(0, 0), v.call(0.25, 1), v.call(0.5, 0.35), v.call(0.75, 1), v.call(1, 0)]]
		"X":
			return [[v.call(0, 0), v.call(1, 1)], [v.call(1, 0), v.call(0, 1)]]
		"Y":
			return [[v.call(0, 0), v.call(0.5, 0.5), v.call(1, 0)], [v.call(0.5, 0.5), v.call(0.5, 1)]]
		"Z":
			return [[v.call(0, 0), v.call(1, 0), v.call(0, 1), v.call(1, 1)]]
	return []


static func _advance(ch: String) -> float:
	match ch:
		"I":
			return 0.3
		"M", "W":
			return 1.05
	return 0.78


## Stroke polylines (pixel space, origin at the text's top-left) for a word, plus the total width.
static func _word_strokes(text: String, height: float, gap: float, slant: float, smooth: int) -> Dictionary:
	var strokes: Array[PackedVector2Array] = []
	var x: float = 0.0
	for i: int in text.length():
		var ch: String = text[i]
		var adv: float = _advance(ch) * height
		for st: Array in _letter(ch):
			var pts := PackedVector2Array()
			for p: Vector2 in st:
				var px: float = x + p.x * adv
				var py: float = p.y * height
				px += (height - py) * slant
				pts.append(Vector2(px, py))
			strokes.append(_chaikin(pts, smooth))
		x += adv + gap
	return {"strokes": strokes, "width": x - gap + height * slant}


# ---------------------------------------------------------------------------------------------------------------------- styles

static func _darker(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, 1.0)


static func _throw_up(img: Image, text: String, fill: Color, accent: Color) -> void:
	var w: float = float(img.get_width())
	var h: float = float(img.get_height())
	var letter_h: float = h * 0.58
	var r: float = letter_h * 0.15
	var gap: float = r * 1.5
	var wd: Dictionary = _word_strokes(text, letter_h, gap, 0.0, 2)
	var total: float = float(wd["width"])
	var strokes: Array[PackedVector2Array] = wd["strokes"]
	# fit the word to the canvas
	var fit: float = minf(1.0, (w - r * 5.0) / total)
	var origin := Vector2((w - total * fit) * 0.5, h * 0.2)
	var shadow_off := Vector2(r * 0.45, r * 0.55)
	for st: PackedVector2Array in strokes:
		_path(img, _xf(st, origin + shadow_off, fit), r + 9.0, _darker(accent, 0.55))
	for st: PackedVector2Array in strokes:
		_path(img, _xf(st, origin, fit), r + 9.0, INK)
	for st: PackedVector2Array in strokes:
		_path(img, _xf(st, origin, fit), r, fill)
	for st: PackedVector2Array in strokes:
		_path(img, _xf(st, origin + Vector2(r * 0.42, r * 0.42), fit), r * 0.2, _darker(fill, 0.8))
	for st: PackedVector2Array in strokes:
		_path(img, _xf(st, origin - Vector2(r * 0.36, r * 0.36), fit), r * 0.2, WHITE)
	# accent underline wave and sparkles
	var base_y: float = origin.y + letter_h + r * 1.7
	var wave := PackedVector2Array()
	for i: int in 21:
		var t: float = float(i) / 20.0
		wave.append(Vector2(lerpf(w * 0.12, w * 0.88, t), base_y + sin(t * TAU * 1.5) * r * 0.5))
	_path(img, wave, r * 0.55 + 6.0, INK)
	_path(img, wave, r * 0.55, accent)
	for sp: Vector2 in [Vector2(w * 0.07, h * 0.16), Vector2(w * 0.94, h * 0.12), Vector2(w * 0.9, h * 0.86)]:
		_poly_grown(img, _star(sp, r * 0.9, r * 0.28, 4), INK, 6.0)
		_poly(img, _star(sp, r * 0.9, r * 0.28, 4), WHITE)


static func _xf(pts: PackedVector2Array, off: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(off + p * s)
	return out


static func _tag(img: Image, text: String, fill: Color, accent: Color) -> void:
	var w: float = float(img.get_width())
	var h: float = float(img.get_height())
	var letter_h: float = h * 0.55
	var r: float = letter_h * 0.085
	var wd: Dictionary = _word_strokes(text, letter_h, r * 1.3, 0.32, 1)
	var total: float = float(wd["width"])
	var strokes: Array[PackedVector2Array] = wd["strokes"]
	var fit: float = minf(1.0, (w * 0.9) / total)
	var origin := Vector2((w - total * fit) * 0.5, h * 0.16)
	for st: PackedVector2Array in strokes:
		_path(img, _xf(st, origin, fit), r + 7.0, accent if accent != INK else WHITE)
	for st: PackedVector2Array in strokes:
		_path(img, _xf(st, origin, fit), r, fill, r * 0.8)
	# the swoosh: a long tapered underline that flicks up into an arrow, a crown above the first letter, dots
	var sw := PackedVector2Array()
	for i: int in 17:
		var t: float = float(i) / 16.0
		sw.append(Vector2(lerpf(w * 0.04, w * 0.9, t), origin.y + letter_h + r * 4.0 - sin(t * PI) * r * 3.0 - t * t * r * 7.0))
	_path(img, sw, r * 1.1 + 4.0, accent if accent != INK else WHITE, r * 0.3)
	_path(img, sw, r * 1.1, fill, r * 0.25)
	var tip: Vector2 = sw[sw.size() - 1]
	_poly(img, PackedVector2Array([tip + Vector2(r * 3.5, -r * 1.2), tip + Vector2(-r * 1.2, -r * 3.0), tip + Vector2(-r * 0.5, r * 2.4)]), fill)
	var cx: float = origin.x + r * 3.0
	var crown := PackedVector2Array([
		Vector2(cx, origin.y - r * 1.5), Vector2(cx + r * 1.2, origin.y - r * 4.2), Vector2(cx + r * 2.6, origin.y - r * 2.2),
		Vector2(cx + r * 4.0, origin.y - r * 4.2), Vector2(cx + r * 5.2, origin.y - r * 1.5)])
	_poly_grown(img, crown, accent if accent != INK else WHITE, 4.0)
	_poly(img, crown, fill)
	for i: int in 3:
		_disc(img, w * (0.82 + float(i) * 0.055), h * (0.2 + float(i % 2) * 0.1), r * 0.6, fill)


static func _chibi(img: Image, kind: String, hair: Color, accent: Color) -> void:
	var w: float = float(img.get_width())
	var c := Vector2(w * 0.5, w * 0.5)
	var skin := Color("ffe0c8")
	# die-cut sticker border
	_disc(img, c.x, c.y, w * 0.49, INK)
	_disc(img, c.x, c.y, w * 0.465, WHITE)
	var bg: Color = accent if kind != "cap" else Color("ffd23f")
	_disc(img, c.x, c.y, w * 0.43, bg)
	# hair behind the face
	_ellipse(img, c.x, c.y + w * 0.02, w * 0.36, w * 0.37, _darker(hair, 0.85))
	# face
	_ellipse(img, c.x, c.y + w * 0.07, w * 0.285, w * 0.26, skin)
	# side locks
	_poly(img, PackedVector2Array([Vector2(c.x - w * 0.3, c.y - w * 0.05), Vector2(c.x - w * 0.22, c.y + w * 0.3), Vector2(c.x - w * 0.15, c.y + w * 0.1)]), hair)
	_poly(img, PackedVector2Array([Vector2(c.x + w * 0.3, c.y - w * 0.05), Vector2(c.x + w * 0.22, c.y + w * 0.3), Vector2(c.x + w * 0.15, c.y + w * 0.1)]), hair)
	# fringe, a row of zigzag points over the forehead
	var fr := PackedVector2Array()
	fr.append(Vector2(c.x - w * 0.34, c.y - w * 0.02))
	fr.append(Vector2(c.x - w * 0.3, c.y - w * 0.3))
	fr.append(Vector2(c.x, c.y - w * 0.37))
	fr.append(Vector2(c.x + w * 0.3, c.y - w * 0.3))
	fr.append(Vector2(c.x + w * 0.34, c.y - w * 0.02))
	fr.append(Vector2(c.x + w * 0.22, c.y - w * 0.07))
	fr.append(Vector2(c.x + w * 0.16, c.y + w * 0.01))
	fr.append(Vector2(c.x + w * 0.07, c.y - w * 0.08))
	fr.append(Vector2(c.x - w * 0.02, c.y + w * 0.0))
	fr.append(Vector2(c.x - w * 0.1, c.y - w * 0.08))
	fr.append(Vector2(c.x - w * 0.17, c.y + w * 0.01))
	fr.append(Vector2(c.x - w * 0.24, c.y - w * 0.07))
	_poly(img, fr, hair)
	_path(img, PackedVector2Array([Vector2(c.x - w * 0.16, c.y - w * 0.27), Vector2(c.x - w * 0.02, c.y - w * 0.3), Vector2(c.x + w * 0.1, c.y - w * 0.24)]), w * 0.012, _lighter(hair))
	# ahoge, the one stray hair strand
	_path(img, PackedVector2Array(_arc(c.x + w * 0.02, c.y - w * 0.43, w * 0.1, w * 0.1, 90, -90, 8)), w * 0.014, hair)
	match kind:
		"cat":
			for sgn: float in [-1.0, 1.0]:
				var ear := PackedVector2Array([Vector2(c.x + sgn * w * 0.14, c.y - w * 0.33), Vector2(c.x + sgn * w * 0.3, c.y - w * 0.46), Vector2(c.x + sgn * w * 0.34, c.y - w * 0.22)])
				_poly_grown(img, ear, INK, 5.0)
				_poly(img, ear, hair)
				_poly(img, PackedVector2Array([ear[0].lerp(ear[1], 0.3) + Vector2(0, w * 0.02), ear[1].lerp(ear[0], 0.35), ear[2].lerp(ear[1], 0.4) + Vector2(sgn * -w * 0.02, w * 0.03)]), Color("ffb3c9"))
		"cap":
			_ellipse(img, c.x, c.y - w * 0.2, w * 0.31, w * 0.17, accent)
			_rect(img, c.x - w * 0.34, c.y - w * 0.2, c.x + w * 0.1, c.y - w * 0.16, accent)
			_ellipse(img, c.x + w * 0.2, c.y - w * 0.17, w * 0.2, w * 0.045, _darker(accent, 0.8))
			_disc(img, c.x - w * 0.02, c.y - w * 0.22, w * 0.045, WHITE)
	# eyes: big, shiny
	for sgn: float in [-1.0, 1.0]:
		var ec := Vector2(c.x + sgn * w * 0.115, c.y + w * 0.1)
		_ellipse(img, ec.x, ec.y, w * 0.075, w * 0.1, INK)
		_ellipse(img, ec.x, ec.y + w * 0.005, w * 0.062, w * 0.088, Color("4a7bd8") if kind == "blue" else (Color("b8402e") if kind == "cap" else Color("7a4ad8")))
		_ellipse(img, ec.x, ec.y + w * 0.03, w * 0.045, w * 0.05, _lighter(Color("4a7bd8") if kind == "blue" else Color("d86a5a")))
		_ellipse(img, ec.x, ec.y + w * 0.005, w * 0.026, w * 0.045, INK)
		_disc(img, ec.x - w * 0.022, ec.y - w * 0.035, w * 0.02, WHITE)
		_disc(img, ec.x + w * 0.02, ec.y + w * 0.045, w * 0.011, WHITE)
		_path(img, PackedVector2Array(_arc(ec.x, ec.y + w * 0.01, w * 0.085, w * 0.11, 200, 340, 6)), w * 0.014, INK)
		_ellipse(img, ec.x + sgn * w * 0.04, c.y + w * 0.2, w * 0.045, w * 0.022, Color("ff9ab0"))
	# mouth: a little cat smile
	var mouth := PackedVector2Array()
	mouth.append_array(_arc(c.x - w * 0.02, c.y + w * 0.185, w * 0.025, w * 0.02, 0, 180, 5))
	mouth.append_array(_arc(c.x + w * 0.03, c.y + w * 0.185, w * 0.025, w * 0.02, 0, 180, 5))
	_path(img, mouth, w * 0.007, INK)
	# a small blade of sticker shine
	_line(img, Vector2(c.x - w * 0.38, c.y - w * 0.15), Vector2(c.x - w * 0.28, c.y - w * 0.32), w * 0.012, WHITE)


static func _lighter(c: Color) -> Color:
	return c.lerp(Color.WHITE, 0.45)


static func _wave(img: Image, blue: Color, sun: Color) -> void:
	var w: float = float(img.get_width())
	var h: float = float(img.get_height())
	_disc(img, w * 0.72, h * 0.3, h * 0.27, INK)
	_disc(img, w * 0.72, h * 0.3, h * 0.24, sun)
	_disc(img, w * 0.72, h * 0.3, h * 0.16, _lighter(sun))
	for pass_i: int in 2:
		var grow: float = 10.0 if pass_i == 0 else 0.0
		var col: Color = INK if pass_i == 0 else blue
		# the curl: a crescent between two arcs
		var outer: Array[Vector2] = _arc(w * 0.44, h * 0.46, h * 0.4, h * 0.4, 180, 360 + 20, 16)
		var inner: Array[Vector2] = _arc(w * 0.5, h * 0.52, h * 0.24, h * 0.24, 380, 180, 14)
		var cres := PackedVector2Array()
		cres.append_array(PackedVector2Array(outer))
		cres.append_array(PackedVector2Array(inner))
		_poly_grown(img, cres, col, grow)
		var body := PackedVector2Array([Vector2(w * 0.03, h * 0.97), Vector2(w * 0.03, h * 0.58)])
		for i: int in 12:
			var t: float = float(i) / 11.0
			body.append(Vector2(lerpf(w * 0.03, w * 0.97, t), h * 0.78 + sin(t * TAU * 2.0) * h * 0.04))
		body.append(Vector2(w * 0.97, h * 0.97))
		_poly_grown(img, body, col, grow)
	# foam
	var tip: Vector2 = Vector2(w * 0.44 + cos(deg_to_rad(20.0)) * h * 0.4, h * 0.46 + sin(deg_to_rad(20.0)) * h * 0.4)
	for k: int in 5:
		_disc(img, tip.x - float(k) * h * 0.03, tip.y - h * 0.03 + float(k % 2) * h * 0.04, h * 0.045, WHITE)
	_path(img, PackedVector2Array(_arc(w * 0.5, h * 0.52, h * 0.255, h * 0.255, 360, 190, 12)), 5.0, WHITE)
	for i: int in 8:
		var t: float = float(i) / 7.0
		_disc(img, lerpf(w * 0.1, w * 0.92, t), h * 0.78 + sin(t * TAU * 2.0) * h * 0.04, 6.0, WHITE)
	_path(img, PackedVector2Array(_arc(w * 0.44, h * 0.46, h * 0.34, h * 0.34, 200, 300, 8)), 4.0, _lighter(blue))


static func _sun(img: Image, col: Color, accent: Color) -> void:
	var w: float = float(img.get_width())
	var c := Vector2(w * 0.5, w * 0.5)
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		var d := Vector2(cos(a), sin(a))
		var tri := PackedVector2Array([c + d * w * 0.34 + d.orthogonal() * w * 0.055, c + d * w * 0.49, c + d * w * 0.34 - d.orthogonal() * w * 0.055])
		_poly_grown(img, tri, INK, 6.0)
		_poly(img, tri, accent if i % 2 == 0 else col)
	_disc(img, c.x, c.y, w * 0.31, INK)
	_disc(img, c.x, c.y, w * 0.285, col)
	_disc(img, c.x - w * 0.07, c.y - w * 0.08, w * 0.15, _lighter(col))
	# shades
	for sgn: float in [-1.0, 1.0]:
		_ellipse(img, c.x + sgn * w * 0.115, c.y - w * 0.01, w * 0.1, w * 0.075, INK)
		_line(img, Vector2(c.x + sgn * w * 0.16, c.y - w * 0.04), Vector2(c.x + sgn * w * 0.08, c.y - w * 0.02), w * 0.012, Color("7b5cff"))
	_line(img, Vector2(c.x - w * 0.04, c.y - w * 0.02), Vector2(c.x + w * 0.04, c.y - w * 0.02), w * 0.018, INK)
	_path(img, PackedVector2Array(_arc(c.x, c.y + w * 0.06, w * 0.12, w * 0.09, 20, 160, 8)), w * 0.013, INK)


static func _palm(img: Image, green: Color, accent: Color) -> void:
	var w: float = float(img.get_width())
	var h: float = float(img.get_height())
	var sunc := Vector2(w * 0.55, h * 0.62)
	_disc(img, sunc.x, sunc.y, w * 0.42, INK)
	_disc(img, sunc.x, sunc.y, w * 0.4, accent)
	_disc(img, sunc.x, sunc.y, w * 0.31, Color("ff9a4d"))
	_disc(img, sunc.x, sunc.y, w * 0.21, Color("ffd23f"))
	_rect(img, 0, h * 0.86, w, h, Color(0, 0, 0, 0))
	# trunk, a leaning curve
	var trunk := PackedVector2Array()
	for i: int in 13:
		var t: float = float(i) / 12.0
		trunk.append(Vector2(w * 0.34 + sin(t * 2.2) * w * 0.1 + t * w * 0.1, h * 0.96 - t * h * 0.66))
	_path(img, trunk, 14.0 + 7.0, INK, 8.0 + 7.0)
	_path(img, trunk, 14.0, Color("8a5a3c"), 8.0)
	for i: int in range(1, 12, 2):
		_line(img, trunk[i] + Vector2(-14, 0), trunk[i] + Vector2(14, 5), 3.0, Color("5e3a26"))
	var top: Vector2 = trunk[trunk.size() - 1]
	var ang: Array[float] = [-170.0, -135.0, -100.0, -55.0, -15.0, 20.0, 150.0]
	for pass_i: int in 2:
		for a_deg: float in ang:
			var a: float = deg_to_rad(a_deg)
			var d := Vector2(cos(a), sin(a))
			var pts := PackedVector2Array()
			for i: int in 9:
				var t: float = float(i) / 8.0
				pts.append(top + d * t * w * 0.38 + Vector2(0, sin(t * PI * 0.5) * w * 0.14))
			if pass_i == 0:
				_path(img, pts, 17.0, INK, 5.0)
			else:
				_path(img, pts, 11.0, green, 2.0)
				for i: int in range(1, 8):
					var n: Vector2 = d.orthogonal()
					_line(img, pts[i], pts[i] + n * 9.0 + d * 8.0, 2.5, _darker(green, 0.7))
					_line(img, pts[i], pts[i] - n * 9.0 + d * 8.0, 2.5, _darker(green, 0.7))
	for k: int in 3:
		_disc(img, top.x - 8.0 + float(k) * 9.0, top.y + 10.0 + float(k % 2) * 6.0, 8.0, INK)
		_disc(img, top.x - 8.0 + float(k) * 9.0, top.y + 10.0 + float(k % 2) * 6.0, 5.5, Color("7a4a2a"))


static func _deck(img: Image, col: Color, accent: Color) -> void:
	var w: float = float(img.get_width())
	var h: float = float(img.get_height())
	var a := Vector2(w * 0.5, h * 0.17)
	var b := Vector2(w * 0.5, h * 0.83)
	for ty: float in [0.28, 0.72]:
		_rect(img, w * 0.22, h * ty - 7.0, w * 0.78, h * ty + 7.0, INK)
		_rect(img, w * 0.27, h * ty - 4.0, w * 0.73, h * ty + 4.0, Color("c9d3dd"))
		for sx: float in [0.2, 0.8]:
			_ellipse(img, w * sx, h * ty, 15.0 + 5.0, 26.0 + 5.0, INK)
			_ellipse(img, w * sx, h * ty, 15.0, 26.0, accent)
			_ellipse(img, w * sx, h * ty, 6.0, 11.0, WHITE)
	_line(img, a, b, w * 0.3 + 9.0, INK)
	_line(img, a, b, w * 0.3, col)
	_line(img, a + Vector2(0, h * 0.02), b - Vector2(0, h * 0.02), w * 0.3 - 20.0, _darker(col, 0.86))
	_line(img, a + Vector2(-w * 0.1, h * 0.03), b + Vector2(-w * 0.1, -h * 0.03), 4.0, WHITE)
	# graphic: a grinning star on the deck
	_poly_grown(img, _star(Vector2(w * 0.5, h * 0.5), w * 0.24, w * 0.11, 5), INK, 5.0)
	_poly(img, _star(Vector2(w * 0.5, h * 0.5), w * 0.24, w * 0.11, 5), accent)
	_disc(img, w * 0.46, h * 0.49, 6.0, INK)
	_disc(img, w * 0.54, h * 0.49, 6.0, INK)
	_path(img, PackedVector2Array(_arc(w * 0.5, h * 0.5, w * 0.06, w * 0.05, 20, 160, 6)), 3.5, INK)


static func _skull(img: Image, bone: Color, pink: Color) -> void:
	var w: float = float(img.get_width())
	for pass_i: int in 2:
		var g: float = 10.0 if pass_i == 0 else 0.0
		var col: Color = INK if pass_i == 0 else bone
		_ellipse(img, w * 0.5, w * 0.4, w * 0.34 + g, w * 0.3 + g, col)
		_rect(img, w * 0.33 - g, w * 0.58, w * 0.67 + g, w * 0.8 + g, col)
	# face holes
	for sgn: float in [-1.0, 1.0]:
		_ellipse(img, w * 0.5 + sgn * w * 0.14, w * 0.43, w * 0.1, w * 0.105, INK)
		_disc(img, w * 0.5 + sgn * w * 0.14 - sgn * 4.0, w * 0.4, 5.0, Color("ff5a8a"))
	_poly(img, PackedVector2Array([Vector2(w * 0.5, w * 0.52), Vector2(w * 0.46, w * 0.62), Vector2(w * 0.54, w * 0.62)]), INK)
	for k: int in 4:
		var x: float = w * (0.38 + float(k) * 0.08)
		_line(img, Vector2(x, w * 0.7), Vector2(x, w * 0.8), 2.5, INK)
	_line(img, Vector2(w * 0.34, w * 0.7), Vector2(w * 0.66, w * 0.7), 2.5, INK)
	_path(img, PackedVector2Array(_arc(w * 0.5, w * 0.4, w * 0.27, w * 0.23, 200, 250, 5)), 4.0, WHITE)
	# crossbones
	var y: float = w * 0.93
	_line(img, Vector2(w * 0.22, y), Vector2(w * 0.78, y), 15.0, INK)
	_line(img, Vector2(w * 0.22, y), Vector2(w * 0.78, y), 9.0, bone)
	for sx: float in [0.2, 0.8]:
		_disc(img, w * sx - 6.0, y - 8.0, 11.0 + 5.0, INK)
		_disc(img, w * sx + 6.0, y - 8.0, 11.0 + 5.0, INK)
		_disc(img, w * sx - 6.0, y - 8.0, 11.0, bone)
		_disc(img, w * sx + 6.0, y - 8.0, 11.0, bone)
	# the flower tucked over the left side of the skull
	var fc := Vector2(w * 0.25, w * 0.2)
	_line(img, fc, fc + Vector2(-w * 0.1, w * 0.13), 4.0 + 4.0, INK)
	_poly(img, PackedVector2Array([fc + Vector2(-w * 0.02, w * 0.06), fc + Vector2(-w * 0.15, w * 0.04), fc + Vector2(-w * 0.1, w * 0.14)]), Color("3ba982"))
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0 - PI * 0.5
		_disc(img, fc.x + cos(a) * w * 0.075, fc.y + sin(a) * w * 0.075, w * 0.068 + 5.0, INK)
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0 - PI * 0.5
		_disc(img, fc.x + cos(a) * w * 0.075, fc.y + sin(a) * w * 0.075, w * 0.068, pink)
	_disc(img, fc.x, fc.y, w * 0.05 + 4.0, INK)
	_disc(img, fc.x, fc.y, w * 0.05, Color("ffd23f"))


static func _koi(img: Image, orange: Color, cream: Color) -> void:
	var w: float = float(img.get_width())
	var h: float = float(img.get_height())
	var spine := PackedVector2Array()
	for i: int in 17:
		var t: float = float(i) / 16.0
		spine.append(Vector2(lerpf(w * 0.82, w * 0.18, t), h * 0.5 + sin(t * TAU * 0.9 + 0.6) * h * 0.16 * t))
	for pass_i: int in 2:
		var g: float = 9.0 if pass_i == 0 else 0.0
		var col: Color = INK if pass_i == 0 else cream
		_path(img, spine, h * 0.17 + g, col, h * 0.03 + g)
		var tail: Vector2 = spine[spine.size() - 1]
		_poly_grown(img, PackedVector2Array([tail, tail + Vector2(-w * 0.12, -h * 0.26), tail + Vector2(-w * 0.07, 0), tail + Vector2(-w * 0.12, h * 0.26)]), col if pass_i == 0 else orange, g)
		_poly_grown(img, PackedVector2Array([spine[6] + Vector2(0, -h * 0.1), spine[8] + Vector2(w * 0.04, -h * 0.34), spine[10] + Vector2(0, -h * 0.1)]), col if pass_i == 0 else orange, g)
	for i: int in [2, 5, 8, 11]:
		_disc(img, spine[i].x, spine[i].y - 3.0, h * 0.08, orange)
		_disc(img, spine[i].x - 3.0, spine[i].y + 3.0, h * 0.04, Color("ff5a5f"))
	var hd: Vector2 = spine[0]
	_disc(img, hd.x - w * 0.025, hd.y - h * 0.04, h * 0.045, WHITE)
	_disc(img, hd.x - w * 0.02, hd.y - h * 0.04, h * 0.022, INK)
	for i: int in 3:
		_path(img, PackedVector2Array(_arc(w * 0.3 + float(i) * w * 0.17, h * 0.9, w * 0.07, h * 0.05, 200, 340, 6)), 4.0, Color("5ad1e6"))


static func _sticker(img: Image, kind: String, col: Color, ink: Color) -> void:
	var w: float = float(img.get_width())
	var c := Vector2(w * 0.5, w * 0.5)
	_disc(img, c.x, c.y, w * 0.49, INK)
	_disc(img, c.x, c.y, w * 0.45, WHITE)
	_disc(img, c.x, c.y, w * 0.4, col)
	match kind:
		"smile":
			for sgn: float in [-1.0, 1.0]:
				_ellipse(img, c.x + sgn * w * 0.14, c.y - w * 0.08, w * 0.045, w * 0.075, ink)
			_path(img, PackedVector2Array(_arc(c.x, c.y + w * 0.02, w * 0.2, w * 0.2, 20, 160, 8)), w * 0.03, ink)
		"star":
			_poly(img, _star(c, w * 0.3, w * 0.13, 5), ink)
		"sk8":
			_line(img, c + Vector2(-w * 0.26, w * 0.08), c + Vector2(w * 0.26, w * 0.08), w * 0.06, ink)
			_disc(img, c.x - w * 0.17, c.y + w * 0.2, w * 0.06, ink)
			_disc(img, c.x + w * 0.17, c.y + w * 0.2, w * 0.06, ink)
			_path(img, PackedVector2Array(_arc(c.x, c.y - w * 0.05, w * 0.18, w * 0.15, 200, 340, 6)), w * 0.035, ink)
		"heart":
			_disc(img, c.x - w * 0.1, c.y - w * 0.06, w * 0.12, ink)
			_disc(img, c.x + w * 0.1, c.y - w * 0.06, w * 0.12, ink)
			_poly(img, PackedVector2Array([c + Vector2(-w * 0.21, -w * 0.02), c + Vector2(w * 0.21, -w * 0.02), c + Vector2(0, w * 0.28)]), ink)
