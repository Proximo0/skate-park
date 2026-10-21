extends TestCase


func _trick_input_idle(f: TrickInput, ticks: int) -> void:
	for i: int in ticks:
		f.feed(Vector2.ZERO, [], [])


func test_quantize_all_eight_dirs() -> void:
	assert_eq(TrickInput.quantize(Vector2(1, 0)), "E")
	assert_eq(TrickInput.quantize(Vector2(1, -1)), "NE")
	assert_eq(TrickInput.quantize(Vector2(0, -1)), "N")
	assert_eq(TrickInput.quantize(Vector2(-1, -1)), "NW")
	assert_eq(TrickInput.quantize(Vector2(-1, 0)), "W")
	assert_eq(TrickInput.quantize(Vector2(-1, 1)), "SW")
	assert_eq(TrickInput.quantize(Vector2(0, 1)), "S")
	assert_eq(TrickInput.quantize(Vector2(1, 1)), "SE")


func test_quantize_deadzone() -> void:
	assert_eq(TrickInput.quantize(Vector2(0.3, 0)), "", "inside default deadzone")
	assert_eq(TrickInput.quantize(Vector2(0.5, 0)), "E", "outside default deadzone")
	assert_eq(TrickInput.quantize(Vector2(0.3, 0), 0.2), "E", "custom deadzone")
	assert_eq(TrickInput.quantize(Vector2.ZERO, 0.0), "", "zero stick is neutral")


func test_buffer_holds_dir_six_ticks_after_release() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2(0, -1), [], [])  # tick 1: N
	_trick_input_idle(f, 5)  # ticks 2-6
	var r: Array = f.feed(Vector2.ZERO, ["flip"], [])  # tick 7: 6 ticks after release
	assert_eq(r.size(), 1)
	assert_eq(r[0]["dir"], "N", "buffered dir at 6 ticks")
	assert_eq(r[0]["button"], "flip")
	f.feed(Vector2.ZERO, [], [])  # tick 8
	r = f.feed(Vector2.ZERO, ["grab"], [])  # tick 9: 8 ticks after release
	assert_eq(r[0]["dir"], "", "buffer expired after 6 ticks")


func test_current_dir_beats_buffer() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2(0, -1), [], [])
	var r: Array = f.feed(Vector2(1, 0), ["flip"], [])
	assert_eq(r[0]["dir"], "E")


func test_non_button_presses_yield_nothing() -> void:
	var f: TrickInput = TrickInput.new()
	var r: Array = f.feed(Vector2(1, 0), ["ollie", "spin_left", "revert", "nollie"], [])
	assert_eq(r.size(), 0)
	r = f.feed(Vector2(1, 0), [], ["flip", "grab"])
	assert_eq(r.size(), 0, "held buttons do not request")


func test_double_tap_within_15_ticks() -> void:
	var f: TrickInput = TrickInput.new()
	var r: Array = f.feed(Vector2.ZERO, ["flip"], [])  # tick 1
	assert_false(r[0]["double_tap"], "first press is not a double tap")
	_trick_input_idle(f, 14)  # ticks 2-15
	r = f.feed(Vector2.ZERO, ["flip"], [])  # tick 16: 15 ticks after
	assert_eq(r.size(), 1)
	assert_true(r[0]["double_tap"], "15 ticks apart counts")


func test_double_tap_expires_at_16_ticks() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2.ZERO, ["flip"], [])  # tick 1
	_trick_input_idle(f, 15)  # ticks 2-16
	var r: Array = f.feed(Vector2.ZERO, ["flip"], [])  # tick 17: 16 ticks after
	assert_false(r[0]["double_tap"], "16 ticks apart does not count")


func test_double_tap_is_per_button() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2.ZERO, ["flip"], [])
	var r: Array = f.feed(Vector2.ZERO, ["grab"], [])
	assert_false(r[0]["double_tap"], "different button is not a double tap")


func test_sequence_two_distinct_dirs() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2(0, -1), [], [])  # N
	f.feed(Vector2(0, 1), [], [])  # S
	var r: Array = f.feed(Vector2.ZERO, ["flip"], [])
	assert_eq(r[0]["sequence"], ["N", "S"])


func test_sequence_ignores_repeats_and_neutral() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2(0, -1), [], [])
	f.feed(Vector2(0, -1), [], [])
	f.feed(Vector2.ZERO, [], [])
	f.feed(Vector2(0, 1), [], [])
	assert_eq(f.manual_sequence(), ["N", "S"])


func test_sequence_keeps_last_two() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2(0, -1), [], [])  # N
	f.feed(Vector2(0, 1), [], [])  # S
	f.feed(Vector2(0, -1), [], [])  # N
	var r: Array = f.feed(Vector2.ZERO, ["grab"], [])
	assert_eq(r[0]["sequence"], ["S", "N"])


func test_sequence_empty_with_one_dir() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2(0, -1), [], [])
	assert_eq(f.manual_sequence(), [])


func test_sequence_expires_after_20_ticks() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2(0, -1), [], [])  # tick 1: N
	_trick_input_idle(f, 19)  # ticks 2-20
	f.feed(Vector2(0, 1), [], [])  # tick 21: S, 20 ticks after N
	assert_eq(f.manual_sequence(), ["N", "S"], "N still within 20 ticks")

	var g: TrickInput = TrickInput.new()
	g.feed(Vector2(0, -1), [], [])  # tick 1: N
	_trick_input_idle(g, 21)  # ticks 2-22
	var r: Array = g.feed(Vector2(0, 1), ["flip"], [])  # tick 23: N is 22 ticks old
	assert_eq(r[0]["sequence"], [], "N expired, only one dir left")


func test_sequence_attached_to_requests_and_empty_when_idle() -> void:
	var f: TrickInput = TrickInput.new()
	var r: Array = f.feed(Vector2.ZERO, ["grind"], [])
	assert_eq(r[0]["sequence"], [])
	assert_eq(r[0]["button"], "grind")


func test_clear_resets_state() -> void:
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2(0, -1), [], [])
	f.feed(Vector2(0, 1), ["flip"], [])
	f.clear()
	assert_eq(f.manual_sequence(), [])
	var r: Array = f.feed(Vector2.ZERO, ["flip"], [])
	assert_eq(r[0]["dir"], "", "buffer cleared")
	assert_false(r[0]["double_tap"], "double tap cleared")
	assert_eq(r[0]["sequence"], [])
