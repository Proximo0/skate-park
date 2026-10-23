extends TestCase


## Feeds a list of yaw angles (degrees) into a fresh tracker that starts at the first value.
func _track_deg(yaws_deg: Array[float]) -> SpinTracker:
	var t: SpinTracker = SpinTracker.new()
	t.start(deg_to_rad(yaws_deg[0]))
	for i: int in range(1, yaws_deg.size()):
		t.update(deg_to_rad(yaws_deg[i]))
	return t


func _sweep_deg(from: float, to: float, step: float) -> Array[float]:
	var out: Array[float] = []
	var v: float = from
	while (step > 0.0 and v <= to + 0.0001) or (step < 0.0 and v >= to - 0.0001):
		out.append(v)
		v += step
	return out


## Yaw path (degrees) that ends exactly at total, in steps of at most 5 degrees.
func _spin_yaws(total: float) -> Array[float]:
	var step: float = 5.0 if total >= 0.0 else -5.0
	var out: Array[float] = _sweep_deg(0.0, total, step)
	if absf(out[out.size() - 1] - total) > 0.0001:
		out.append(total)
	return out


func test_no_movement_is_zero_and_no_label() -> void:
	var t: SpinTracker = SpinTracker.new()
	t.start(1.2)
	t.update(1.2)
	assert_near(t.degrees(), 0.0)
	assert_eq(t.spins180(), 0)
	assert_eq(t.label(), "")


func test_under_150_degrees_is_no_spin() -> void:
	assert_eq(_track_deg(_spin_yaws(149.0)).label(), "", "149")
	assert_eq(_track_deg(_spin_yaws(90.0)).spins180(), 0, "90")
	assert_eq(_track_deg(_spin_yaws(-149.0)).label(), "", "-149")


func test_150_degrees_counts_as_180() -> void:
	var t: SpinTracker = _track_deg(_spin_yaws(150.0))
	assert_eq(t.spins180(), 1, "150")
	assert_eq(t.label(), "180")


func test_180_exact() -> void:
	var t: SpinTracker = _track_deg(_spin_yaws(180.0))
	assert_near(t.degrees(), 180.0, 0.001)
	assert_eq(t.spins180(), 1)
	assert_eq(t.label(), "180")


func test_329_is_still_180() -> void:
	assert_eq(_track_deg(_spin_yaws(329.0)).label(), "180", "329")


func test_330_is_360() -> void:
	assert_eq(_track_deg(_spin_yaws(330.0)).label(), "360", "330")


func test_360_exact_label() -> void:
	var t: SpinTracker = _track_deg(_spin_yaws(360.0))
	assert_near(t.degrees(), 360.0, 0.001)
	assert_eq(t.label(), "360")


func test_540_and_720_labels() -> void:
	assert_eq(_track_deg(_sweep_deg(0.0, 540.0, 45.0)).label(), "540", "540")
	assert_eq(_track_deg(_sweep_deg(0.0, 720.0, 45.0)).label(), "720", "720")


func test_negative_spin_is_unsigned_in_label() -> void:
	var t: SpinTracker = _track_deg(_spin_yaws(-180.0))
	assert_near(t.degrees(), -180.0, 0.001)
	assert_eq(t.spins180(), 1)
	assert_eq(t.label(), "180")


func test_negative_360() -> void:
	var t: SpinTracker = _track_deg(_sweep_deg(0.0, -360.0, -30.0))
	assert_near(t.degrees(), -360.0, 0.001)
	assert_eq(t.label(), "360")


func test_spin_sign_is_kept_in_degrees() -> void:
	assert_true(_track_deg(_spin_yaws(90.0)).degrees() > 0.0, "ccw positive")
	assert_true(_track_deg(_spin_yaws(-90.0)).degrees() < 0.0, "cw negative")


func test_wraparound_forward_across_pi() -> void:
	# 170 to -170 is a 20 degree step forward, not a 340 degree step back.
	var t: SpinTracker = _track_deg([170.0, -170.0])
	assert_near(t.degrees(), 20.0, 0.001, "170 to -170")
	assert_eq(t.spins180(), 0)


func test_wraparound_backward_across_pi() -> void:
	# -170 to 170 is a 20 degree step backward.
	var t: SpinTracker = _track_deg([-170.0, 170.0])
	assert_near(t.degrees(), -20.0, 0.001, "-170 to 170")


func test_wraparound_accumulates_over_many_turns() -> void:
	# Three full turns in 30 degree steps, each step wraps through +/-180.
	var yaws: Array[float] = _sweep_deg(0.0, 1080.0, 30.0)
	var t: SpinTracker = _track_deg(yaws)
	assert_near(t.degrees(), 1080.0, 0.01, "three turns")
	assert_eq(t.label(), "1080", "label for 1080")


func test_wraparound_with_raw_yaw_values_outside_pi() -> void:
	# Yaw values larger than PI (raw engine yaw) still give the right shortest step.
	var t: SpinTracker = SpinTracker.new()
	t.start(6.0)
	t.update(0.5)
	# Step from 6.0 to 0.5 is -5.5, which wraps to about +0.7832 rad.
	assert_near(t.degrees(), rad_to_deg(TAU - 5.5), 0.001, "raw wrap")
	t.update(2.5)
	assert_near(t.degrees(), rad_to_deg(TAU - 5.5 + 2.0), 0.001, "raw wrap then step")
	assert_eq(t.label(), "180", "about 159 degrees rounds to 180")


func test_switch_landing_backward_spin_label() -> void:
	# Rolling switch: spin runs backward through the wrap, roughly 200 degrees.
	var t: SpinTracker = _track_deg([10.0, -10.0, -100.0, -190.0])
	assert_near(t.degrees(), -200.0, 0.001, "switch backward 200")
	assert_eq(t.label(), "180", "200 rounds to 180")


func test_start_resets_accumulated_spin() -> void:
	var t: SpinTracker = _track_deg(_sweep_deg(0.0, 720.0, 45.0))
	assert_eq(t.label(), "720")
	t.start(0.0)
	assert_near(t.degrees(), 0.0)
	assert_eq(t.label(), "")


func test_start_sets_reference_yaw() -> void:
	var t: SpinTracker = SpinTracker.new()
	t.start(deg_to_rad(90.0))
	t.update(deg_to_rad(100.0))
	assert_near(t.degrees(), 10.0, 0.001, "step from start yaw")


func test_thresholds_are_consistent_with_formula() -> void:
	# A single update can only carry a step under 180 degrees, so feed a sweep in 10 degree steps.
	for deg: int in range(0, 1000, 10):
		var t: SpinTracker = _track_deg(_sweep_deg(0.0, float(deg), 10.0))
		var expected: int = int(floor((float(deg) + 30.0) / 180.0))
		assert_eq(t.spins180(), expected, "spins180 at %d" % deg)
