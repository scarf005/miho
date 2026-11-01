extends GutTest
## The storey below, dithered through the sky.


func _lit(image: Image) -> int:
	var n := 0
	for y in image.get_height():
		for x in image.get_width():
			n += 1 if image.get_pixel(x, y).a > 0.0 else 0
	return n


func test_what_blocks_the_way_below_is_denser_than_what_can_be_walked() -> void:
	var cell := int(Term.CELL.x * Term.CELL.y)
	assert_eq(_lit(Dither.image(Dither.OPEN)), cell / 4)
	assert_eq(_lit(Dither.image(Dither.SOLID)), cell / 2)
	assert_ne(Dither.of(World.FLOOR), Dither.of(World.WALL))


func test_the_pattern_repeats_across_cells_with_no_seam() -> void:
	assert_eq(int(Term.CELL.x) % (Dither.DOT.x * 4), 0)
	assert_eq(int(Term.CELL.y) % (Dither.DOT.y * 4), 0)
