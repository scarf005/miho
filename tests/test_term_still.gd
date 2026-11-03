extends GutTest
## A still term keeps its flames as they are, while its other clocks go on.

var _t: Term


func before_each() -> void:
	_t = Term.new()
	add_child_autofree(_t)
	_t.set_process(false)


func test_a_flame_wavers_until_the_term_is_still() -> void:
	var from := _t.layer.flicker(0.0, true)
	_t._process(0.1)
	assert_ne(_t.layer.flicker(0.0, true), from)
	_t.still = true
	from = _t.layer.flicker(0.0, true)
	_t._process(0.1)
	assert_eq(_t.layer.flicker(0.0, true), from)


func test_a_still_term_keeps_the_time_of_what_fades() -> void:
	_t.still = true
	_t._process(0.1)
	assert_almost_eq(_t.time, 0.1, 0.0001)
