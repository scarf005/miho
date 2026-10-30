extends GutTest
## The pointer finds what the curved CRT screen shows under it.

const VIEW := Vector2(1280, 720)


func test_the_centre_stays_and_the_edges_bend_inward() -> void:
	assert_eq(Crt.flat(VIEW / 2.0, VIEW), VIEW / 2.0)
	assert_gt(
		Crt.flat(Vector2(640, 683), VIEW).y, 683.0, "the bottom row shows above where it is drawn"
	)


func test_seen_inverts_flat() -> void:
	for p in [Vector2(215, 708), Vector2(5, 5), Vector2(1270, 400)]:
		assert_almost_eq(Crt.flat(Crt.seen(p, VIEW), VIEW), p, Vector2(0.01, 0.01))


func test_the_talisman_row_is_found_where_it_shows() -> void:
	# At 1280x720 the fitted term has 30 rows of 24 px; talismans are the last.
	assert_eq(floori(Crt.flat(Vector2(215, 683), VIEW).y / 24.0), 29)
