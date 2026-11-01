extends GutTest
## A log line too wide for the screen wraps at a space instead of running off it.

const HEARD := [
	["멀리서 ", Palette.TEXT],
	["탁", Palette.SOUND],
	[" 소리를 들었다", Palette.TEXT],
	[" · ", Palette.DIM],
	["소리: 4칸", Palette.SOUND],
]


func _text(row: Array) -> String:
	return "".join(row.map(func(r): return r[0]))


func test_a_line_that_fits_stays_one_row() -> void:
	assert_eq(Term.rows_of(HEARD, 40.0), [HEARD])


func test_a_wide_line_wraps_at_spaces_keeping_text_and_colours() -> void:
	var rows := Term.rows_of(HEARD, 10.0)
	assert_eq(rows.map(_text), ["멀리서 탁 소리를", "들었다 · 소리: 4칸"])
	for row: Array in rows:
		assert_lte(row.reduce(func(n, r): return n + Term._cells(r[0]), 0.0), 10.0)
	assert_eq(rows[0].slice(1), [["탁", Palette.SOUND], [" 소리를", Palette.TEXT]])
	assert_eq(rows[1].slice(1), [[" · ", Palette.DIM], ["소리: 4칸", Palette.SOUND]])


func test_a_word_wider_than_the_screen_takes_a_row_of_its_own() -> void:
	assert_eq(Term.rows_of([["가나다라마 바", Palette.TEXT]], 3.0).map(_text), ["가나다라마", "바"])
