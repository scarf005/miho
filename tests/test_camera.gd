extends GutTest
## The screen's camera over maps larger and smaller than the window.


func _term(view: Vector2, zoom: float) -> Term:
	var t: Term = autofree(Term.new())
	t.fit(view, zoom)
	return t


func test_fitting_shows_the_whole_map_with_sidebar_and_status_rows() -> void:
	for view in [Vector2(1280, 720), Vector2(1558, 720), Vector2(720, 1280)]:
		var t := _term(view, 0.0)
		assert_gte(t.map_view().x, Grid.W)
		assert_gte(t.map_view().y, Grid.H)
		assert_lte(t.size.x * t.scale.x, view.x + 0.01)
		assert_lte(t.size.y * t.scale.y, view.y + 0.01)
		t.follow(Vector2i(0, 0))
		assert_true(t.map_rect().has_point(t.cell_centre(Vector2i(0, 0))))
		assert_true(t.map_rect().has_point(t.cell_centre(Vector2i(Grid.W - 1, Grid.H - 1))))


func test_a_zoomed_camera_keeps_miho_in_view_and_stays_on_the_map() -> void:
	var t := _term(Vector2(400, 240), 1.0)
	var v := t.map_view()
	assert_lt(v.x, Grid.W)
	assert_lt(v.y, Grid.H)
	for p in [Vector2i(0, 0), Vector2i(Grid.W - 1, Grid.H - 1), Vector2i(Grid.W / 2, 3)]:
		t.follow(p)
		assert_eq(t.tile_at(t.cell_centre(p)), p, "Miho at %s is on screen" % p)
		assert_between(t.cam.x, 0, Grid.W - v.x)
		assert_between(t.cam.y, 0, Grid.H - v.y)


func test_the_camera_moves_only_near_the_edge() -> void:
	var t := _term(Vector2(800, 480), 1.0)
	t.follow(Vector2i(Grid.W / 2, Grid.H / 2))
	var cam := t.cam
	t.follow(Vector2i(Grid.W / 2 - 1, Grid.H / 2))
	assert_eq(t.cam, cam, "a step away from the edge keeps the camera")
	t.follow(Vector2i(Grid.W / 2 + 1, Grid.H / 2))
	assert_eq(t.cam, cam + Vector2i(1, 0), "a step into the margin scrolls one tile")


func test_a_small_map_sits_centred() -> void:
	var t := _term(Vector2(4000, 3000), 1.0)
	t.follow(Vector2i(1, 1))
	var v := t.map_view()
	assert_eq(t.cam, -(v - Vector2i(Grid.W, Grid.H)) / 2)
	assert_eq(t.tile_at(Vector2(Term.MAP) * Term.CELL), Vector2i(-1, -1), "margin is not map")
