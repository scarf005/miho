extends TouchBase
## A finger does what the keys and the pointer do (Touch): taps, long presses,
## swipes and buttons on the game scene; the screen is shared by its size and
## pixel ratio, every target is at least 44 CSS pixels, and a mouse and keyboard
## game stays as it was.

# --- the screen -----------------------------------------------------------------


func test_a_touch_screen_has_no_status_rows_and_a_sidebar_only_in_landscape() -> void:
	var m := _main()
	get_tree().root.size = Vector2i(390, 844)
	m.fit()
	assert_eq(m.term.side, Vector2i.ZERO, "portrait lists the creatures in the HUD")
	get_tree().root.size = Vector2i(844, 390)
	m.fit()
	assert_eq(m.term.side, Term.MAP, "landscape lists them beside the map")
	get_tree().root.size = Vector2i(1280, 720)
	assert_eq(m.term.foot, 0)
	assert_eq(m.term.bar, m.touch.hud)
	assert_false(m.glass.visible, "the CRT curve would bend the edges")


func test_rotating_the_phone_lays_out_again_and_keeps_the_game() -> void:
	var m := _main()
	var world: World = m.world
	var rounds := world.round_no
	var rows: int = m.term.rows
	get_tree().root.size = Vector2i(390, 844)
	m.fit()
	assert_ne(m.term.rows, rows, "tall and wide are laid out differently")
	assert_false(m.touch.hud.wide)
	get_tree().root.size = Vector2i(844, 390)
	m.fit()
	assert_true(m.touch.hud.wide)
	assert_same(m.world, world)
	assert_eq(m.world.round_no, rounds)
	assert_eq(_me(m), Vector2i(4, 8))
	get_tree().root.size = Vector2i(1280, 720)


# --- a mouse and keyboard game --------------------------------------------------


func test_a_mouse_and_keyboard_game_keeps_the_sidebar_and_the_status_rows() -> void:
	var m := _main(false)
	assert_false(m.touch.enabled)
	assert_eq(m.term.side, Term.MAP)
	assert_eq(m.term.foot, 2)
	assert_eq(m.term.bar, StatusBar)
	assert_eq(PanelView.stride, 1)


func test_the_first_touch_on_a_screen_that_was_not_one_makes_it_a_touch_screen() -> void:
	var m := _main(false)
	_finger(m, _tile_at(m, Vector2i(4, 8)))
	assert_true(m.touch.enabled)
	assert_eq(m.term.bar, m.touch.hud)
	assert_eq(m.term.foot, 0)


func test_the_title_asks_for_a_touch_not_a_key() -> void:
	var m := _main()
	m.show_title()
	assert_eq(m.term.banner_lines[2], "화면을 눌러 시작")
	_finger(m, Vector2(300, 300))
	assert_eq(m.state, &"play", "a tap anywhere starts")
	var keys := _main(false)
	keys.show_title()
	assert_eq(keys.term.banner_lines[2], "아무 키나 눌러 시작")


# --- taps -----------------------------------------------------------------------


func test_a_tap_on_the_next_tile_steps_there_as_a_click_does() -> void:
	var m := _main()
	_finger(m, _tile_at(m, Vector2i(5, 9)))
	assert_eq(_me(m), Vector2i(5, 9))


func test_a_tap_on_a_far_known_tile_walks_there() -> void:
	var m := _main()
	_finger(m, _tile_at(m, Vector2i(9, 8)))
	assert_true(m.walking, "a walk is under way")
	for i in 400:
		if not m.walking:
			break
		await get_tree().process_frame
	assert_eq(_me(m), Vector2i(9, 8))


func test_a_tap_leaves_no_hover_frame_where_a_mouse_would_keep_one() -> void:
	var m := _main()
	_finger(m, _tile_at(m, Vector2i(5, 8)))
	assert_false(Grid.inside(m.look.hover))
	assert_eq(m.term.info, [])


func test_a_tap_outside_the_map_does_nothing() -> void:
	var m := _main()
	var rounds: int = m.world.round_no
	_finger(m, Vector2(-5, -5))
	assert_eq(m.world.round_no, rounds)


func test_a_tap_on_the_empty_queue_does_nothing() -> void:
	var m := _main()
	for n in [0, Spell.MAX_SLOTS - 1, -1]:
		_finger(m, _hud(m, &"queue", n))
		await _settle(m)
		assert_eq(m.world.round_no, 0, "slot %d" % n)


# --- long presses ---------------------------------------------------------------


func test_a_long_press_on_a_tile_shows_its_info_and_the_next_tap_only_closes_it() -> void:
	var m := _main()
	var at := _tile_at(m, Vector2i(6, 8))
	_hold(m, at)
	_lift(m, at)
	assert_false(m.term.info.is_empty(), "the info box is up")
	assert_eq(m.look.hover, Vector2i(6, 8))
	assert_eq(_me(m), Vector2i(4, 8), "lifting the finger does not walk")
	_finger(m, _tile_at(m, Vector2i(5, 8)))
	assert_eq(m.term.info, [], "closed")
	assert_eq(_me(m), Vector2i(4, 8), "that tap only closed it")
	_finger(m, _tile_at(m, Vector2i(5, 8)))
	assert_eq(_me(m), Vector2i(5, 8), "the next one acts")


func test_a_long_press_on_a_talisman_and_on_the_status_shows_their_info() -> void:
	var m := _main()
	var card := _hud(m, &"card", 1)
	_hold(m, card)
	_lift(m, card)
	assert_false(m.term.info.is_empty())
	assert_eq(m.look.hover_card, Cards.ORB)
	var stat := _hud(m, &"stat")
	_finger(m, stat)
	_hold(m, stat)
	_lift(m, stat)
	assert_true(m.look.hover_status)
	assert_false(m.term.info.is_empty())


func test_the_pointer_motion_a_browser_reports_for_a_dragging_finger_is_no_hover() -> void:
	var m := _main()
	var at := _tile_at(m, Vector2i(6, 8))
	m._unhandled_input(_touch_event(true, at))
	var motion := InputEventMouseMotion.new()
	motion.position = at + Vector2(40, 0)
	m._unhandled_input(motion)
	assert_false(Grid.inside(m.look.hover), "a finger is down")
	m._unhandled_input(_touch_event(false, at))
	m._unhandled_input(motion)
	assert_true(Grid.inside(m.look.hover), "a mouse moving with no finger down still points")


# --- swipes ---------------------------------------------------------------------


func test_a_swipe_takes_a_step_in_one_of_eight_directions() -> void:
	var m := _main()
	var from := _tile_at(m, Vector2i(10, 8))
	_finger(m, from, from + Vector2(80, -80))
	assert_eq(_me(m), Vector2i(5, 7), "north-east")
	_finger(m, from, from + Vector2(-80, 0))
	assert_eq(_me(m), Vector2i(4, 7), "west")
	_finger(m, from, from + Vector2(0, 80))
	assert_eq(_me(m), Vector2i(4, 8), "south")


func test_a_swipe_that_starts_on_the_hud_steps_nowhere() -> void:
	var m := _main()
	var from := _hud(m, &"stat")
	_finger(m, from, from + Vector2(80, 0))
	assert_eq(_me(m), Vector2i(4, 8))


func test_a_swipe_with_talismans_queued_hurls_that_way() -> void:
	var m := _main()
	_finger(m, _hud(m, &"card", 1))
	assert_eq(m.picked, [Cards.ORB])
	var from := _tile_at(m, Vector2i(10, 8))
	var rounds: int = m.world.round_no
	_finger(m, from, from + Vector2(80, 0))
	assert_eq(m.world.round_no, rounds + 1, "a round passed")
	assert_eq(_me(m), Vector2i(4, 8), "Miho did not walk")
	await _settle(m)
	assert_eq(m.picked, [])


# --- debug picks ----------------------------------------------------------------


func _ask(m: Node, cmd: StringName, needs: Array) -> void:
	m.menu.debug.ask = {cmd = cmd, needs = needs, args = {}}


func test_a_tap_answers_a_debug_pick_at_that_tile_without_a_round_or_a_walk() -> void:
	var m := _main()
	_ask(m, &"teleport", [&"tile"])
	_finger(m, _tile_at(m, Vector2i(9, 8)))
	await _settle(m)
	assert_false(m.menu.debug.asking())
	assert_eq(_me(m), Vector2i(9, 8), "teleported at once")
	assert_eq(m.world.round_no, 0)


func test_a_swipe_while_a_debug_pick_waits_does_nothing() -> void:
	var m := _main()
	_ask(m, &"teleport", [&"tile"])
	var from := _tile_at(m, Vector2i(10, 8))
	_finger(m, from, from + Vector2(80, 0))
	assert_true(m.menu.debug.asking())
	assert_eq(_me(m), Vector2i(4, 8))
	assert_eq(m.world.round_no, 0)


func test_the_menu_button_gives_up_a_debug_pick_as_a_right_click_does() -> void:
	var m := _main()
	_ask(m, &"teleport", [&"tile"])
	_finger(m, _hud(m, &"cancel"))
	await _settle(m)
	assert_false(m.menu.debug.asking())
	assert_eq(m.overlay, &"cheat", "the list opens again")
	assert_eq(_me(m), Vector2i(4, 8))


func test_the_debug_list_fits_the_screen_after_the_phone_is_turned() -> void:
	var m := _main()
	get_tree().root.size = Vector2i(390, 844)
	m.fit()
	m._open(&"cheat")
	m.menu.debug.selected = DebugMenu.COMMANDS.size() - 1
	get_tree().root.size = Vector2i(844, 390)
	m.fit()
	var e := Keys.event("Up")
	e.pressed = true
	m._unhandled_input(e)
	var shown := PanelView.span(m.term)
	var row: int = m.term.panel.selected
	assert_true(row >= shown.x and row < shown.x + shown.y, "row %d in %s" % [row, shown])
	get_tree().root.size = Vector2i(1280, 720)


# --- aiming ---------------------------------------------------------------------


func test_a_talisman_tapped_is_queued_and_a_tap_on_it_again_is_not_a_second_pick() -> void:
	var m := _main()
	_finger(m, _hud(m, &"card", 0))
	assert_eq(m.picked, [Cards.FOX])
	assert_eq(m.world.round_no, 0, "no round passed")


func test_aiming_taps_the_target_then_taps_it_again_to_hurl() -> void:
	var m := _main()
	_finger(m, _hud(m, &"card", 1))
	var target := _tile_at(m, Vector2i(9, 8))
	_finger(m, target)
	assert_eq(m.look.hover, Vector2i(9, 8), "the first tap aims")
	assert_eq(m.picked, [Cards.ORB])
	assert_eq(m.world.round_no, 0)
	_finger(m, target)
	assert_eq(m.world.round_no, 1, "the second tap hurls")
	await _settle(m)
	assert_eq(m.picked, [])


func test_aiming_at_another_tile_moves_the_aim_instead_of_hurling() -> void:
	var m := _main()
	_finger(m, _hud(m, &"card", 1))
	_finger(m, _tile_at(m, Vector2i(9, 8)))
	_finger(m, _tile_at(m, Vector2i(9, 4)))
	assert_eq(m.look.hover, Vector2i(9, 4))
	assert_eq(m.world.round_no, 0)


func test_a_tap_on_the_queue_hurls_at_the_aim() -> void:
	var m := _main()
	_finger(m, _hud(m, &"card", 1))
	_finger(m, _tile_at(m, Vector2i(9, 8)))
	_finger(m, _hud(m, &"queue", -1))
	assert_eq(m.world.round_no, 1)
	await _settle(m)
	assert_eq(m.picked, [])


func test_a_tap_on_the_queue_with_no_aim_says_there_is_nothing_to_aim_at() -> void:
	var m := _main()
	_finger(m, _hud(m, &"card", 1))
	_finger(m, _hud(m, &"queue", -1))
	assert_eq(m.world.round_no, 0)
	assert_eq(m.messages.lines.back().text, "겨눌 곳이 없다")


func test_a_tap_on_a_talisman_aims_at_the_nearest_creature_in_sight() -> void:
	var m := _main()
	FloorGen.spawn(m.world, &"dokkaebi", Vector2i(8, 8))
	m.world.seen.fill(1)
	m.forecast()
	_finger(m, _hud(m, &"card", 1))
	assert_eq(m.look.hover, Vector2i(8, 8), "the aim is on it, so one tap on it hurls")


# --- buttons --------------------------------------------------------------------


func test_wait_passes_a_round() -> void:
	var m := _main()
	_finger(m, _hud(m, &"wait"))
	assert_eq(m.world.round_no, 1)


func test_unpick_takes_back_the_last_talisman() -> void:
	var m := _main()
	_finger(m, _hud(m, &"card", 0))
	_finger(m, _hud(m, &"card", 1))
	_finger(m, _hud(m, &"unpick"))
	assert_eq(m.picked, [Cards.FOX])


func test_explore_and_stairs_do_what_their_keys_do() -> void:
	var m := _main()
	_finger(m, _hud(m, &"explore"))
	assert_eq(m.messages.lines.back().text, "더 탐험할 곳이 없다")
	_finger(m, _hud(m, &"stairs"))
	assert_eq(m.messages.lines.back().text, "아직 계단을 찾지 못했다")


func test_the_menu_button_clears_the_queue_first_then_opens_the_options() -> void:
	var m := _main()
	_finger(m, _hud(m, &"card", 0))
	_finger(m, _hud(m, &"cancel"))
	assert_eq(m.picked, [])
	assert_eq(m.overlay, &"")
	_finger(m, _hud(m, &"cancel"))
	assert_eq(m.overlay, &"options")


func test_the_log_and_the_codex_open_and_the_back_button_closes_them() -> void:
	var m := _main()
	_finger(m, _hud(m, &"log"))
	assert_eq(m.overlay, &"log")
	assert_eq(m.touch.hud.mode, &"menu")
	_finger(m, _hud(m, &"back"))
	assert_eq(m.overlay, &"")
	_finger(m, _hud(m, &"codex"))
	assert_eq(m.overlay, &"codex")
	_finger(m, _hud(m, &"back"))
	assert_eq(m.overlay, &"")
	assert_eq(m.term.panel, {})


func test_the_spellbook_opens_from_its_button() -> void:
	var m := _main()
	_finger(m, _hud(m, &"spellbook"))
	assert_eq(m.overlay, &"spells")


func test_the_back_button_on_a_page_opened_from_a_page_goes_back_one() -> void:
	var m := _main()
	_finger(m, _hud(m, &"cancel"))
	_finger(m, _rows(m, Menu.OPTIONS.find(&"codex")))
	assert_eq(m.menu.page, &"codex")
	_finger(m, _hud(m, &"back"))
	assert_eq(m.overlay, &"options")
	assert_eq(m.menu.page, &"options")


# --- pages ----------------------------------------------------------------------


func test_a_tap_on_a_row_of_the_options_acts_on_it_and_a_row_is_at_least_44_css_px() -> void:
	var m := _main()
	m._open(&"options")
	var apart: float = PanelView.stride * Term.CELL.y * m.term.scale.y / m.touch.dpr
	assert_gte(apart, TARGET)
	var before: int = m.settings.crt
	m.menu.selected = 0
	_finger(m, _rows(m, Menu.OPTIONS.find(&"crt")))
	assert_ne(m.settings.crt, before)
	assert_false(m.glass.visible, "the touch screen has no CRT glass whatever the option")


func test_a_drag_scrolls_a_page_by_its_rows() -> void:
	var m := _main()
	for i in 60:
		m.messages.add([["줄 %d" % i, Palette.TEXT]], 0)
	m._open(&"log")
	m.menu.top = 0
	var from := _rows(m, 2)
	var row: float = PanelView.stride * Term.CELL.y * m.term.scale.y
	_finger(m, from, from - Vector2(0, row * 3.2))
	assert_eq(m.menu.top, 3, "three rows up, three rows on")
	_finger(m, from, from + Vector2(0, row * 2.2))
	assert_eq(m.menu.top, 1, "and back two")


func test_a_tap_on_a_codex_tab_and_a_swipe_sideways_change_the_tab() -> void:
	var m := _main()
	m._open(&"codex")
	var tab_two := Vector2(PanelView._tabs_at(m.term) + 2.5, 1.5) * Term.CELL
	_finger(m, _screen(m, tab_two))
	assert_eq(m.menu.codex.tab, 1, "a tap on the second tab shows it")
	var from := _rows(m, 3)
	_finger(m, from, from + Vector2(-120, 0))
	assert_eq(m.menu.codex.tab, 2, "a swipe left turns to the next tab")
	_finger(m, from, from + Vector2(120, 0))
	assert_eq(m.menu.codex.tab, 1)


func test_a_swipe_sideways_on_the_options_steps_the_value() -> void:
	var m := _main()
	m._open(&"options")
	m.menu.selected = Menu.OPTIONS.find(&"volume")
	var before: int = m.settings.volume
	var from := _rows(m, 5)
	_finger(m, from, from + Vector2(-120, 0))
	assert_eq(m.settings.volume, maxi(0, before - 10))


func test_a_page_laid_out_for_a_phone_keeps_its_selection_in_view() -> void:
	var m := _main()
	for i in 60:
		m.messages.add([["줄 %d" % i, Palette.TEXT]], 0)
	m._open(&"log")
	var shown: Vector2i = PanelView.span(m.term)
	assert_lte(m.menu.selected, shown.x + shown.y - 1)
	assert_gte(m.menu.selected, shown.x)
