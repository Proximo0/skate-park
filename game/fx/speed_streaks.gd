class_name SpeedStreaks
extends CanvasLayer
## Camera-attached speed lines: thin radial streaks that rush outward at the screen edges, fading in above
## FADE_LO m/s. Drawn by one canvas shader on a full-screen rect, below the HUD. Subtle, no shake.

const FADE_LO: float = 12.0
const FADE_HI: float = 24.0
const MAX_ALPHA: float = 0.55

const SHADER_CODE: String = """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform float aspect = 1.78;
uniform float scroll = 0.0;
float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p) / (0.5 * sqrt(aspect * aspect + 1.0));
	float ang = atan(p.y, p.x);
	float cells = 90.0;
	float f = (ang / 6.2831853 + 0.5) * cells;
	float id = floor(f);
	float d = abs(fract(f) - 0.5);
	float h = hash(id);
	float width = 0.05 + 0.08 * hash(id + 7.0);
	float line = smoothstep(width, 0.0, d);
	float phase = fract(scroll * (0.8 + h) + h * 5.0);
	float s = fract(r * 1.3 - phase);
	float seg = smoothstep(0.0, 0.08, s) * (1.0 - smoothstep(0.08, 0.3, s));
	float edge = smoothstep(0.42, 0.85, r);
	float on = step(0.45, hash(id + 3.0));
	COLOR = vec4(1.0, 1.0, 1.0, line * seg * edge * on * intensity);
}
"""

var skater: Skater

var _rect: ColorRect
var _mat: ShaderMaterial
var _scroll: float = 0.0
var _level: float = 0.0


## 0 below FADE_LO, 1 at FADE_HI and above; smooth in between.
static func level_for_speed(speed: float) -> float:
	return smoothstep(FADE_LO, FADE_HI, speed)


func _init() -> void:
	layer = 5


func _ready() -> void:
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func _process(delta: float) -> void:
	if _rect == null:
		return
	var goal: float = 0.0
	if skater != null and is_instance_valid(skater):
		var st: SkateState.State = skater.state.state
		if st != SkateState.State.WALK and st != SkateState.State.BAIL:
			goal = level_for_speed(skater.speed)
	_level = SkateCamera.damp(_level, goal, 4.0, delta)
	_rect.visible = _level > 0.01
	if not _rect.visible:
		return
	_scroll += delta * (1.0 + _level * 1.5)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("intensity", _level * MAX_ALPHA)
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_mat.set_shader_parameter("scroll", _scroll)
