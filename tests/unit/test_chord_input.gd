extends TestCase
## ChordInput: spin_left + spin_right within WINDOW_TICKS fire the ramp snap once, the spent buttons stop spinning
## until both are released, and lone or slow presses never fire.

const L: String = "spin_left"
const R: String = "spin_right"


func test_both_on_the_same_tick_fire_once() -> void:
	var c := ChordInput.new()
	assert_true(c.feed([L, R], [L, R]), "fires on the press")
	assert_true(c.suppressing(), "spins suppressed while held")
	for i: int in 10:
		assert_false(c.feed([], [L, R]), "holding does not fire again")
	assert_false(c.feed([], []), "release")
	assert_false(c.suppressing(), "released: spins work again")


func test_second_press_inside_the_window_fires() -> void:
	var c := ChordInput.new()
	assert_false(c.feed([L], [L]), "one button alone")
	for i: int in ChordInput.WINDOW_TICKS - 1:
		assert_false(c.feed([], [L]))
	assert_true(c.feed([R], [L, R]), "second press within 0.1 s")
	assert_eq(c.lead_ticks(), ChordInput.WINDOW_TICKS, "the first press led by the window")


func test_second_press_after_the_window_is_just_two_spins() -> void:
	var c := ChordInput.new()
	c.feed([L], [L])
	for i: int in ChordInput.WINDOW_TICKS + 2:
		c.feed([], [L])
	assert_false(c.feed([R], [L, R]), "too slow: no chord")
	assert_false(c.suppressing(), "no chord, spins still work")


func test_released_first_button_does_not_chord() -> void:
	var c := ChordInput.new()
	c.feed([L], [L])
	c.feed([], [])
	assert_false(c.feed([R], [R]), "first button already let go")


func test_held_without_just_pressed_counts_as_a_press() -> void:
	var c := ChordInput.new()
	assert_false(c.feed([], [L]))
	assert_true(c.feed([], [L, R]), "scripted holds make the chord too")


func test_new_chord_needs_both_released_first() -> void:
	var c := ChordInput.new()
	assert_true(c.feed([L, R], [L, R]))
	c.feed([], [L])  # R let go, L still down
	assert_false(c.feed([R], [L, R]), "re-pressing one button while the other is still spent does not fire")
	c.feed([], [])
	assert_true(c.feed([L, R], [L, R]), "fresh chord after a full release")


func test_direct_action_press_fires() -> void:
	var c := ChordInput.new()
	assert_true(c.feed(["ramp_snap"], []), "a bound or scripted ramp_snap press")
	assert_false(c.suppressing(), "no spin buttons involved")


func test_round_trips_through_a_dict() -> void:
	var a := ChordInput.new()
	a.feed([L], [L])
	var b := ChordInput.new()
	b.from_dict(a.to_dict())
	assert_true(b.feed([R], [L, R]), "restored mid-chord, the second press fires")
