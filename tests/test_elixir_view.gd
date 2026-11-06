extends TouchBase
## The question the elixir asks (Elixir): Y and N answer it on a keyboard, two buttons on a
## touch screen, and nothing else takes a turn until it is answered.

const ME := Vector2i(4, 8)
const E := Vector2i(1, 0)


func _key(m: Node, code: String) -> void:
	var e := Keys.event(code)
	e.pressed = true
	m._unhandled_input(e)


## A hall with the elixir east of Miho, and Miho on it.
func _asked(touch := false) -> Node:
	get_tree().root.size = Vector2i(1280, 720)
	var m := _main(touch)
	m.world.elixir = ME + E
	m.act({t = &"move", dir = E})
	await _settle(m)
	await get_tree().process_frame
	return m


func _prompt(m: Node) -> String:
	return Messages.plain(m.term.log_lines.back()[0])


func test_the_question_shows_over_the_map_with_the_keys_that_answer_it() -> void:
	var m: Node = await _asked()
	assert_true(m.world.elixir_asked)
	assert_eq(_prompt(m), Lang.t(Elixir.ASK) + " Y/N")


func test_y_drinks_it_and_the_run_ends() -> void:
	var m: Node = await _asked()
	_key(m, "Y")
	await _settle(m)
	assert_eq(m.world.outcome, &"won")
	assert_eq(m.state, &"over")


func test_n_keeps_it_and_the_game_goes_on() -> void:
	var m: Node = await _asked()
	var round_no: int = m.world.round_no
	_key(m, "N")
	await _settle(m)
	assert_true(m.world.elixir_held)
	assert_eq(m.state, &"play")
	assert_eq(m.world.round_no, round_no)
	assert_ne(m.term.log_lines.size(), 0)
	assert_false(_prompt(m).ends_with("Y/N"), "the question is taken down")


func test_other_keys_neither_answer_nor_pass_a_round() -> void:
	var m: Node = await _asked()
	var round_no: int = m.world.round_no
	for code in ["Right", "Space", "X", "Enter"]:
		_key(m, code)
		await _settle(m)
	assert_true(m.world.elixir_asked)
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.world.player().pos, ME + E)


func test_the_menu_stays_reachable_while_it_waits() -> void:
	var m: Node = await _asked()
	_key(m, "Escape")
	assert_ne(m.panels.overlay, &"")
	assert_true(m.world.elixir_asked)


func test_a_touch_screen_has_a_yes_and_a_no_button_and_no_keys_in_the_question() -> void:
	var m: Node = await _asked(true)
	assert_eq(m.touch.hud.mode, &"elixir")
	assert_eq(
		m.touch.hud._items(m.term).map(func(i): return i.id),
		TouchHud.ALONE[&"elixir"].map(func(b): return b[0])
	)
	assert_eq(_prompt(m), Lang.t(Elixir.ASK))


func test_tapping_yes_drinks_it_and_no_keeps_it() -> void:
	var m: Node = await _asked(true)
	_finger(m, _hud(m, &"yes"))
	await _settle(m)
	assert_eq(m.world.outcome, &"won")
	m = await _asked(true)
	_finger(m, _hud(m, &"no"))
	await _settle(m)
	await get_tree().process_frame
	assert_true(m.world.elixir_held)
	assert_eq(m.touch.hud.mode, &"play")


func test_a_tap_on_the_map_while_it_waits_takes_no_turn() -> void:
	var m: Node = await _asked(true)
	var round_no: int = m.world.round_no
	_finger(m, _tile_at(m, ME + Vector2i(2, 0)))
	await _settle(m)
	assert_true(m.world.elixir_asked)
	assert_eq(m.world.round_no, round_no)
