extends GutTest
## Arena draws a world from rows: where the rows land, where Miho stands, what lies outside.


func test_rows_land_at_the_offset_and_the_rest_is_wall() -> void:
	var w := Arena.from(["..", ".@"], Vector2i(10, 5))
	assert_eq(w.player().pos, Vector2i(11, 6))
	assert_eq(w.tile(Vector2i(10, 5)), World.FLOOR)
	assert_eq(w.tile(Vector2i(9, 5)), World.WALL)
	assert_eq(w.tile(Vector2i(12, 5)), World.WALL)
	assert_eq(w.rooms, [Rect2i(10, 5, 2, 2)] as Array[Rect2i])


func test_hall_is_the_open_map_with_miho_at_the_given_tile() -> void:
	var w := Arena.hall(Vector2i(4, 8))
	assert_eq(w.player().pos, Vector2i(4, 8))
	assert_eq(w.tile(Vector2i(Grid.W - 2, Grid.H - 2)), World.FLOOR)
	assert_eq(w.tile(Vector2i(0, 0)), World.WALL)
	assert_eq(w.actors.size(), 1)
