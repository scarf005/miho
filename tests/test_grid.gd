extends GutTest
## Board geometry.


func test_nudge_moves_along_the_direction() -> void:
	assert_eq(Grid.nudge(Vector2i(10, 10), Vector2i(1, -1)), Vector2i(11, 9))
	assert_eq(Grid.nudge(Vector2i(10, 10), Vector2i(0, 1), 5), Vector2i(10, 15))


func test_nudge_stops_at_the_edge_of_the_board() -> void:
	assert_eq(Grid.nudge(Vector2i(0, 0), Vector2i(-1, -1)), Vector2i(0, 0))
	assert_eq(Grid.nudge(Vector2i(52, 3), Vector2i(1, -1), 5), Vector2i(Grid.W - 1, 0))
	assert_eq(Grid.nudge(Vector2i(2, 25), Vector2i(-1, 1), 5), Vector2i(0, Grid.H - 1))
