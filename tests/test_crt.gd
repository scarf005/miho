extends GutTest
## The CRT strength sets the shader's uniforms, and the pointer finds what the
## curved screen shows under it.

const VIEW := Vector2(1280, 720)


func test_the_centre_stays_and_the_edges_bend_inward() -> void:
	assert_eq(Crt.flat(VIEW / 2.0, VIEW, 50), VIEW / 2.0)
	assert_gt(
		Crt.flat(Vector2(640, 683), VIEW, 50).y,
		683.0,
		"the bottom row shows above where it is drawn"
	)


func test_seen_inverts_flat() -> void:
	for p in [Vector2(215, 708), Vector2(5, 5), Vector2(1270, 400)]:
		assert_almost_eq(Crt.flat(Crt.seen(p, VIEW, 80), VIEW, 80), p, Vector2(0.01, 0.01))


func test_the_talisman_row_is_found_where_it_shows() -> void:
	# At 1280x720 the fitted term has 30 rows of 24 px; talismans are the last.
	assert_eq(floori(Crt.flat(Vector2(215, 700), VIEW, 50).y / 24.0), 29)


func test_the_pointer_bends_more_as_the_strength_rises_and_not_at_all_at_zero() -> void:
	var low := Crt.flat(Vector2(640, 683), VIEW, 0)
	assert_eq(low, Vector2(640, 683))
	assert_gt(Crt.flat(Vector2(640, 683), VIEW, 100).y, Crt.flat(Vector2(640, 683), VIEW, 50).y)
	assert_gt(Crt.flat(Vector2(640, 683), VIEW, 50).y, low.y)


func _main(strength: int) -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	m.settings.path = ""
	m.settings.crt = strength
	m.touch.enabled = false
	m._apply()
	return m


func _look(m: Node) -> Dictionary:
	var out := {}
	for k in Crt.NOW:
		out[k] = m.glass.material.get_shader_parameter(k)
	return out


func _assert_look(got: Dictionary, want: Dictionary, what: String) -> void:
	for k in want:
		assert_almost_eq(float(got[k]), float(want[k]), 1e-6, "%s %s" % [what, k])


func test_half_strength_draws_the_shader_as_it_is_written() -> void:
	var m := _main(50)
	var code: String = m.glass.material.shader.code
	var written := {}
	for k in Crt.NOW:
		var found := RegEx.create_from_string("uniform float %s = ([0-9.]+);" % k).search(code)
		written[k] = float(found.get_string(1))
	assert_true(m.glass.visible)
	_assert_look(_look(m), written, "50")


func test_full_strength_draws_the_crt_as_it_was_before_it_was_softened() -> void:
	var m := _main(100)
	var old := {
		&"curve": 0.06,
		&"fringe": 0.0012,
		&"glow": 0.55,
		&"scan": 0.28,
		&"grille": 0.12,
		&"rim": 0.35
	}
	assert_true(m.glass.visible)
	_assert_look(_look(m), old, "100")


func test_zero_strength_hides_the_glass_and_has_no_effect() -> void:
	var m := _main(0)
	assert_false(m.glass.visible)
	for k in Crt.params(0):
		assert_eq(Crt.params(0)[k], 0.0, k)


func test_each_uniform_is_straight_between_the_marks() -> void:
	for k in Crt.NOW:
		var at := func(s: int) -> float: return Crt.params(s)[k]
		assert_almost_eq(at.call(25), at.call(50) / 2.0, 1e-7, "%s 25" % k)
		assert_almost_eq(at.call(75), (at.call(50) + at.call(100)) / 2.0, 1e-7, "%s 75" % k)
