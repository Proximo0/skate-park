extends TestCase
## GoalsPanel formatting: timer text, goal count line, next unfinished goals, progress rows.


func test_format_time_rounds_up_and_pads() -> void:
	assert_eq(GoalsPanel.format_time(120.0), "2:00")
	assert_eq(GoalsPanel.format_time(59.2), "1:00")
	assert_eq(GoalsPanel.format_time(9.0), "0:09")
	assert_eq(GoalsPanel.format_time(-3.0), "0:00")


func test_count_line() -> void:
	assert_eq(GoalsPanel.count_line(3, 12), "Goals 3/12")


func test_next_goals_skips_done_and_limits() -> void:
	var all: Array[Dictionary] = [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]
	var out: Array[Dictionary] = GoalsPanel.next_goals(all, PackedStringArray(["b"]), 2)
	assert_eq(out.size(), 2)
	assert_eq(str(out[0]["id"]), "a")
	assert_eq(str(out[1]["id"]), "c")


func test_row_text_shows_partial_progress_only() -> void:
	assert_eq(GoalsPanel.row_text("Pizza", 0.0), "Pizza")
	assert_eq(GoalsPanel.row_text("Pizza", 0.4), "Pizza  40%")
	assert_eq(GoalsPanel.row_text("Pizza", 1.0), "Pizza")
