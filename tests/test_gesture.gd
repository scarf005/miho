extends GutTest
## One finger is a tap, a hold, a swipe in one of 8 directions or a drag along
## one axis, whatever its path; a second finger cancels all of it.

const AT := Vector2(200, 300)


func _g(scale := 1.0) -> Gesture:
	var g := Gesture.new()
	g.scale = scale
	return g


## The events of a finger put down at AT and lifted at `to` after `after` seconds.
func _stroke(g: Gesture, to: Vector2, after := 0.1) -> Array:
	g.down(0, AT, 0.0)
	var out := g.move(0, to, after / 2.0)
	out.append_array(g.up(0, to, after))
	return out


func test_a_touch_that_stays_put_is_a_tap_where_it_began() -> void:
	var g := _g()
	assert_eq(_stroke(g, AT + Vector2(5, -4)), [{t = &"tap", pos = AT}])


func test_a_finger_resting_long_enough_holds_once_and_lifting_it_is_no_tap() -> void:
	var g := _g()
	g.down(0, AT, 0.0)
	assert_eq(g.tick(Gesture.HOLD - 0.01), [])
	assert_eq(g.tick(Gesture.HOLD), [{t = &"hold", pos = AT}])
	assert_eq(g.tick(Gesture.HOLD + 1.0), [], "a hold fires once")
	assert_eq(g.up(0, AT, 2.0), [], "lifting after a hold does not tap")


func test_a_finger_that_wandered_off_does_not_hold() -> void:
	var g := _g()
	g.down(0, AT, 0.0)
	g.move(0, AT + Vector2(40, 0), 0.1)
	assert_eq(g.tick(5.0), [])


func test_swipes_in_all_eight_directions() -> void:
	var cases := {
		Vector2i(1, 0): Vector2(60, 0),
		Vector2i(1, 1): Vector2(50, 50),
		Vector2i(0, 1): Vector2(0, 60),
		Vector2i(-1, 1): Vector2(-50, 50),
		Vector2i(-1, 0): Vector2(-60, 0),
		Vector2i(-1, -1): Vector2(-50, -50),
		Vector2i(0, -1): Vector2(0, -60),
		Vector2i(1, -1): Vector2(50, -50),
	}
	for dir in cases:
		var events := _stroke(_g(), AT + cases[dir])
		assert_eq(events.back(), {t = &"swipe", dir = dir, from = AT}, str(dir))


func test_a_swipe_leaning_less_than_22_degrees_off_east_is_east() -> void:
	assert_eq(Gesture.dir_of(Vector2(100, 40)), Vector2i(1, 0))
	assert_eq(Gesture.dir_of(Vector2(100, 42)), Vector2i(1, 1))
	assert_eq(Gesture.dir_of(Vector2(-100, -40)), Vector2i(-1, 0))
	assert_eq(Gesture.dir_of(Vector2(-100, 42)), Vector2i(-1, 1))


func test_a_drag_reports_the_travel_along_its_axis_only() -> void:
	var g := _g()
	g.down(0, AT, 0.0)
	var first := g.move(0, AT + Vector2(3, 30), 0.1)
	assert_eq(first, [{t = &"drag", delta = Vector2(0, 30), from = AT}], "locks to the longer axis")
	var next := g.move(0, AT + Vector2(40, 50), 0.2)
	assert_eq(
		next, [{t = &"drag", delta = Vector2(0, 20), from = AT}], "sideways travel is dropped"
	)


func test_a_drag_that_stops_short_of_a_swipe_ends_with_nothing() -> void:
	var g := _g()
	g.down(0, AT, 0.0)
	g.move(0, AT + Vector2(0, 14), 0.1)
	assert_eq(g.up(0, AT + Vector2(0, 14), 0.2), [], "past the slop, short of a swipe: no tap")


func test_distances_scale_with_the_screen_units_per_css_pixel() -> void:
	var g := _g(3.0)
	assert_eq(_stroke(g, AT + Vector2(30, 0)), [{t = &"tap", pos = AT}], "30 px is 10 css px")
	var swipe := _stroke(_g(3.0), AT + Vector2(0, 90))
	assert_eq(swipe.back().dir, Vector2i(0, 1), "90 px is 30 css px")


func test_a_second_finger_cancels_until_every_finger_is_up() -> void:
	var g := _g()
	g.down(0, AT, 0.0)
	g.down(1, AT + Vector2(80, 0), 0.05)
	assert_eq(g.tick(1.0), [], "no hold with two fingers")
	assert_eq(g.up(1, AT + Vector2(80, 0), 0.1), [])
	assert_eq(g.up(0, AT, 0.2), [], "the first finger's lift is no tap")
	assert_eq(_stroke(g, AT), [{t = &"tap", pos = AT}], "a fresh touch works again")


func test_a_new_touch_after_a_swipe_starts_clean() -> void:
	var g := _g()
	_stroke(g, AT + Vector2(80, 0))
	assert_eq(_stroke(g, AT), [{t = &"tap", pos = AT}])
