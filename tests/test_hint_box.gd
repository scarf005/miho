extends GutTest
## The box of a word opens under the pointer, never over the word.


func test_the_box_opens_under_the_pointers_row_from_its_column() -> void:
	var t: Term = autofree(Term.new())
	t.cols = 60
	t.rows = 24
	t.hint = Keywords.entry("가연성")
	t.hint_at = Vector2(14.5, 5.5)
	var fit := t.hint_fit()
	assert_eq(fit.at, Vector2(14, 6))
	t.hint_at = Vector2(t.cols - 1.5, 5.5)
	fit = t.hint_fit()
	assert_eq(fit.at.y, 6.0)
	assert_eq(fit.at.x + fit.cells.x * fit.scale, float(t.cols), "moved left to stay on screen")


func test_the_box_goes_above_the_row_when_there_is_no_room_below_and_never_covers_it() -> void:
	var t: Term = autofree(Term.new())
	t.cols = 60
	t.rows = 24
	t.hint = Keywords.entry("가연성")
	for row in [0, 5, 12, t.rows - 1]:
		t.hint_at = Vector2(10.5, row + 0.5)
		var fit := t.hint_fit()
		var box := Rect2(fit.at, fit.cells * fit.scale)
		assert_false(box.intersects(Rect2(0, row, t.cols, 1)), "row %d" % row)
		assert_true(Rect2(0, 0, t.cols, t.rows).encloses(box), "on screen at row %d" % row)
	t.hint_at = Vector2(10.5, t.rows - 0.5)
	assert_eq(t.hint_fit().at.y + t.hint_fit().cells.y * t.hint_fit().scale, float(t.rows - 1))
