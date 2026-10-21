extends TestCase


func test_arithmetic() -> void:
	assert_eq(1 + 1, 2)
	assert_near(0.1 + 0.2, 0.3)
