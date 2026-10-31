extends GutTest
## How a list page moves: wrap, pages, ends, and keeping the selection in view.


func test_up_and_down_wrap_at_the_ends() -> void:
	assert_eq(ListNav.step(&"up", 0, 5, 3), 4)
	assert_eq(ListNav.step(&"down", 4, 5, 3), 0)
	assert_eq(ListNav.step(&"down", 1, 5, 3), 2)


func test_a_page_moves_the_rows_shown_and_stops_at_the_ends() -> void:
	assert_eq(ListNav.step(&"page_down", 1, 10, 3), 4)
	assert_eq(ListNav.step(&"page_down", 8, 10, 3), 9)
	assert_eq(ListNav.step(&"page_down", 9, 10, 3), 9, "no wrap")
	assert_eq(ListNav.step(&"page_up", 2, 10, 3), 0)
	assert_eq(ListNav.step(&"page_up", 0, 10, 3), 0, "no wrap")


func test_home_and_end_jump_to_the_ends() -> void:
	assert_eq(ListNav.step(&"home", 6, 10, 3), 0)
	assert_eq(ListNav.step(&"end", 6, 10, 3), 9)


func test_an_empty_list_and_other_navs_leave_the_selection() -> void:
	for nav in [&"up", &"down", &"page_up", &"page_down", &"home", &"end"]:
		assert_eq(ListNav.step(nav, 0, 0, 3), 0, nav)
	assert_eq(ListNav.step(&"enter", 4, 10, 3), 4)


func test_the_view_scrolls_the_least_that_shows_the_selection() -> void:
	assert_eq(ListNav.reveal(0, 2, 10, 3), 0, "already in view")
	assert_eq(ListNav.reveal(0, 3, 10, 3), 1, "one past the foot")
	assert_eq(ListNav.reveal(5, 2, 10, 3), 2, "above the head")
	assert_eq(ListNav.reveal(0, 9, 10, 3), 7, "the last row at the foot")
	assert_eq(ListNav.reveal(0, 0, 2, 3), 0, "a short list does not scroll")


func test_scrolling_stays_inside_the_list() -> void:
	assert_eq(ListNav.scrolled(0, -3, 10, 3), 0)
	assert_eq(ListNav.scrolled(5, 3, 10, 3), 7)
	assert_eq(ListNav.scrolled(0, 3, 2, 3), 0)
