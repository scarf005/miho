extends TouchBase
## Erasing the run asks first: the title's N (a button on a touch screen) when a
## run is saved, and the options row 처음부터.

const SAVE := "user://test_new_run_confirm.cfg"


func after_each() -> void:
	SaveGame.new(SAVE).erase()


func _keyboard() -> Node:
	return _main(false)


## A touch screen on the window the touch tests lay out for.
func _phone() -> Node:
	get_tree().root.size = Vector2i(1280, 720)
	return _main(true)


func _title(m: Node, saved: bool) -> void:
	m.save_path = SAVE if saved else ""
	m.new_run(3)
	if saved:
		m.run.write()
	m.show_title()
	m.fit()


func _key_event(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func test_n_on_the_title_with_a_save_asks_and_y_erases_it() -> void:
	var m := _keyboard()
	_title(m, true)
	var plain: Array = m.term.banner_lines.duplicate()
	m._unhandled_input(_key_event(KEY_N))
	assert_eq(m.state, &"title")
	assert_true(FileAccess.file_exists(SAVE))
	assert_ne(m.term.banner_lines, plain)
	assert_string_ends_with(m.term.banner_lines.back(), "Y/N")
	m._unhandled_input(_key_event(KEY_Y))
	assert_eq(m.state, &"play")
	assert_false(FileAccess.file_exists(SAVE))


func test_any_other_key_cancels_the_new_run_question() -> void:
	var m := _keyboard()
	_title(m, true)
	var plain: Array = m.term.banner_lines.duplicate()
	m._unhandled_input(_key_event(KEY_N))
	m._unhandled_input(_key_event(KEY_ENTER))
	assert_eq(m.state, &"title", "Enter does not continue either")
	assert_eq(m.term.banner_lines, plain)
	assert_true(FileAccess.file_exists(SAVE))
	m._unhandled_input(_key_event(KEY_N))
	m._unhandled_input(_key_event(KEY_N))
	assert_eq(m.state, &"title", "N again is not Y")
	assert_true(FileAccess.file_exists(SAVE))


func test_n_on_the_title_without_a_save_starts_at_once() -> void:
	var m := _keyboard()
	_title(m, false)
	m._unhandled_input(_key_event(KEY_N))
	assert_eq(m.state, &"play")


func test_the_new_run_button_of_the_touch_title_asks_before_it_erases() -> void:
	var m := _phone()
	_title(m, true)
	_finger(m, _hud(m, &"new"))
	assert_eq(m.state, &"title")
	assert_true(FileAccess.file_exists(SAVE))
	assert_ne(m.term.banner_lines.back(), "")
	assert_false("Y/N" in m.term.banner_lines.back())
	_finger(m, _hud(m, &"new"))
	assert_eq(m.state, &"play")
	assert_false(FileAccess.file_exists(SAVE))


func test_a_tap_elsewhere_takes_back_the_touch_title_question() -> void:
	var m := _phone()
	_title(m, true)
	_finger(m, _hud(m, &"new"))
	assert_true(m.erasing)
	_finger(m, Vector2(300, 300))
	assert_false(m.erasing)
	_finger(m, _hud(m, &"new"))
	assert_eq(m.state, &"title", "the next new run asks again")
	assert_true(FileAccess.file_exists(SAVE))


func test_the_options_row_erases_the_run_on_its_second_enter_only() -> void:
	var m := _keyboard()
	var seed_was: int = m.run_seed
	m._open(&"options")
	m.menu.selected = Menu.OPTIONS.find(&"restart")
	m._panel_input(_key_event(KEY_ENTER))
	assert_eq(m.overlay, &"options", "the first Enter only asks")
	assert_eq(m.run_seed, seed_was)
	m._panel_input(_key_event(KEY_ENTER))
	assert_eq(m.overlay, &"")
	assert_ne(m.run_seed, seed_was)


func test_a_map_tap_in_play_after_the_touch_erase_stays_in_play() -> void:
	var m := _phone()
	_title(m, true)
	_finger(m, _hud(m, &"new"))
	_finger(m, _hud(m, &"new"))
	assert_eq(m.state, &"play")
	assert_false(m.erasing)
	_finger(m, Vector2(300, 300))
	assert_eq(m.state, &"play")


func _ctrl_q() -> InputEventKey:
	var e := _key_event(KEY_Q)
	e.ctrl_pressed = true
	return e


func test_ctrl_q_in_play_asks_and_only_y_starts_a_new_run() -> void:
	var m := _keyboard()
	m.save_path = SAVE
	m.new_run(3)
	m.run.write()
	var round_was: int = m.world.round_no
	m._unhandled_input(_ctrl_q())
	assert_eq(m.run_seed, 3, "the first press only asks")
	assert_eq(m.world.round_no, round_was, "asking takes no round")
	assert_string_ends_with(m.term.log_lines.back()[0][0][0], "Y/N")
	m._unhandled_input(_key_event(KEY_N))
	assert_eq(m.run_seed, 3, "N keeps the run")
	assert_false(m.erasing)
	assert_true(FileAccess.file_exists(SAVE))
	m._unhandled_input(_ctrl_q())
	m._unhandled_input(_key_event(KEY_Y))
	assert_ne(m.world, null)
	assert_false(m.erasing)
	assert_eq(m.state, &"play")
	assert_eq(m.world.round_no, 0)


func test_r_no_longer_restarts() -> void:
	var m := _keyboard()
	m.new_run(3)
	m._unhandled_input(_key_event(KEY_R))
	assert_false(m.erasing)
	assert_eq(m.run_seed, 3)


func test_a_held_ctrl_q_does_not_answer_its_own_question() -> void:
	var m := _keyboard()
	m.new_run(3)
	m._unhandled_input(_ctrl_q())
	var echo := _ctrl_q()
	echo.echo = true
	m._unhandled_input(echo)
	assert_true(m.erasing)


func _ending(m: Node) -> void:
	m.new_run(3)
	m.state = &"over"
	Banner.show(m)


func test_r_on_the_ending_starts_a_new_run_at_once() -> void:
	var m := _keyboard()
	_ending(m)
	m._unhandled_input(_key_event(KEY_R))
	assert_eq(m.state, &"play")
	assert_false(m.erasing)


func test_ctrl_q_on_the_ending_starts_a_new_run_at_once() -> void:
	var m := _keyboard()
	_ending(m)
	m._unhandled_input(_ctrl_q())
	assert_eq(m.state, &"play")
	assert_false(m.erasing)


func test_the_ending_tells_the_key_that_starts_again() -> void:
	var m := _keyboard()
	_ending(m)
	assert_true(m.term.banner_lines.any(func(l): return l.begins_with("R키")))


func test_the_restart_button_of_the_touch_ending_starts_at_once() -> void:
	var m := _phone()
	_ending(m)
	m.fit()
	_finger(m, _hud(m, &"new"))
	assert_eq(m.state, &"play")


func test_ctrl_r_on_the_ending_does_not_start_a_new_run() -> void:
	var m := _keyboard()
	_ending(m)
	var e := _key_event(KEY_R)
	e.ctrl_pressed = true
	m._unhandled_input(e)
	assert_eq(m.state, &"over")
