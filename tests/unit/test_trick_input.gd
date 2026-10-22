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


func test_pressed_within_buffers_any_button_and_consume_forgets_it() -> void:
	var f: TrickInput = TrickInput.new()
	assert_false(f.pressed_within("ollie", 6), "never pressed")
	f.feed(Vector2.ZERO, ["ollie"], ["ollie"])  # tick 1
	assert_true(f.pressed_within("ollie", 0), "pressed this tick")
	_trick_input_idle(f, TrickInput.OLLIE_LAND_BUFFER_TICKS)
	assert_true(f.pressed_within("ollie", TrickInput.OLLIE_LAND_BUFFER_TICKS), "still buffered at the window's edge")
	f.feed(Vector2.ZERO, [], [])
	assert_false(f.pressed_within("ollie", TrickInput.OLLIE_LAND_BUFFER_TICKS), "expired one tick later")
	f.feed(Vector2.ZERO, ["ollie"], ["ollie"])
	f.consume("ollie")
	assert_false(f.pressed_within("ollie", 6), "consumed press is gone")
	var r: Array = f.feed(Vector2.ZERO, ["revert", "flip"], [])
	assert_eq(r.size(), 1, "only flip/grab/grind make trick requests")
	assert_true(f.pressed_within("revert", 0) and f.pressed_within("flip", 0), "every button is stamped")


func test_ollie_variant_from_up_taps() -> void:
	var up: Vector2 = Vector2(0, -1)
	var f: TrickInput = TrickInput.new()
	f.feed(Vector2.ZERO, ["ollie"], ["ollie"])
	assert_eq(f.ollie_variant(), "", "no stick: a plain ollie")
	f.clear()
	f.feed(up, ["ollie"], ["ollie"])
	assert_eq(f.ollie_variant(), "no_comply", "up + ollie together")
	f.clear()
	f.feed(up, [], [])
	f.feed(up, [], [])
	_trick_input_idle(f, 3)
	f.feed(up, ["ollie"], ["ollie"])
	assert_eq(f.ollie_variant(), "boneless", "up, up + ollie")
	f.clear()
	f.feed(Vector2.ZERO, ["ollie"], ["ollie"])
	f.feed(up, [], ["ollie"])
	assert_eq(f.ollie_variant(), "no_comply", "up a tick after the press still counts")
	f.clear()
	for i: int in 30:
		f.feed(up, [], [])  # holding up to push
	f.feed(up, ["ollie"], ["ollie"])
	assert_eq(f.ollie_variant(), "", "a push held long before the press is not a tap")
	f.clear()
	f.feed(up, [], [])
	_trick_input_idle(f, TrickInput.NO_COMPLY_TICKS + 2)
	f.feed(Vector2.ZERO, ["ollie"], ["ollie"])
	assert_eq(f.ollie_variant(), "", "one old up tap is too early for a no-comply")
	f.clear()
	f.feed(up, [], [])
	_trick_input_idle(f, TrickInput.BONELESS_TICKS + 2)
	f.feed(up, ["ollie"], ["ollie"])
	assert_eq(f.ollie_variant(), "no_comply", "the first of two taps out of the boneless window")
	f.clear()
	f.feed(up, [], [])
	f.feed(up, [], [])
	_trick_input_idle(f, 3)
	f.feed(Vector2.ZERO, ["ollie"], ["ollie"])
	assert_eq(f.ollie_variant(), "", "up, up then a plain ollie press: the second up must come with the press")


func test_ollie_variant_ignores_pushes_and_jitter() -> void:
	var up: Vector2 = Vector2(0, -1)
	var f: TrickInput = TrickInput.new()
	f.feed(up, ["ollie"], ["ollie"])
	for i: int in TrickInput.FLICK_TICKS + 2:
		f.feed(up, [], ["ollie"])  # up held on through a long crouch: a push
	assert_eq(f.ollie_variant(), "", "up held past a flick is a push")
	f.clear()
	for i: int in 3:
		f.feed(up, [], [])
		f.feed(Vector2.ZERO, [], [])
	f.feed(up, ["ollie"], ["ollie"])
	assert_eq(f.ollie_variant(), "", "four quick taps: a jittery push, not a boneless")
	f.clear()
	f.feed(up, ["ollie"], ["ollie"])
	_trick_input_idle(f, 6)
	f.feed(up, [], ["ollie"])
	f.feed(Vector2.ZERO, [], ["ollie"])
	assert_eq(f.ollie_variant(), "", "up tapped again mid-crouch: pushing")
	f.clear()
	f.feed(up, [], [])  # a one-tick blip of push...
	_trick_input_idle(f, 3)
	f.feed(Vector2.ZERO, ["ollie"], ["ollie"])  # ...then the press with the stick neutral
	assert_eq(f.ollie_variant(), "", "up must be held with the press")


func test_push_with_up_pulses_then_ollie_is_a_plain_ollie() -> void:
	var up: Vector2 = Vector2(0, -1)
	var f: TrickInput = TrickInput.new()
	for i: int in 30:
		f.feed(up if i % 3 == 0 else Vector2.ZERO, [], [])  # the bot's push: up pulsed every 3 ticks
	f.feed(up, ["ollie"], ["ollie"])
	for i: int in 6:
		f.feed(up if i % 3 == 2 else Vector2.ZERO, [], ["ollie"])
	assert_eq(f.ollie_variant(), "", "pulsed pushing into an ollie never makes a boneless or no-comply")
	f.clear()
	for i: int in 12:
		f.feed(up if i % 3 == 0 else Vector2.ZERO, [], [])
	f.feed(up, ["ollie"], ["ollie"])
	assert_eq(f.ollie_variant(), "", "pulses right up to an up + ollie press: still a push")
