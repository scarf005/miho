extends GutTest
## Menu pages over the game.


func before_each() -> void:
	Keys.reset()


func after_all() -> void:
	Keys.reset()


func _press(key: String) -> InputEventKey:
	var e := Keys.event(key)
	e.pressed = true
	return e


func _text(panel: Dictionary) -> String:
	return Info.plain(panel.rows.map(func(r): return r.map(func(run): return [run[0] + " "])))


func test_help_lists_every_action_with_its_current_keys() -> void:
	Keys.bind(&"explore", ["Shift+X"])
	var menu := Menu.new()
	menu.open(&"help")
	var text := _text(menu.panel())
	for action in Keys.ACTIONS:
		if not action.begins_with("pick_"):
			assert_string_contains(text, Keys.ACTIONS[action][0])
	assert_string_contains(text, "자동 탐험 Shift+X")
	assert_string_contains(text, "계단으로 가기 >")
	assert_string_contains(text, "부적 고르기 1 2 3 4 5 6 7")
	assert_false(text.contains("1 2 3 4 5 6 7 8"), "one key per talisman Miho can hold")
	assert_string_contains(text, "살펴보기 X")
	assert_string_contains(text, "기록 Ctrl+P, P")
	assert_string_contains(text, "살피는 중")


func test_help_scrolls_and_esc_closes_it() -> void:
	var menu := Menu.new()
	menu.open(&"help")
	assert_eq(menu.key(_press("Down")), &"")
	assert_eq(menu.key(_press("J")), &"")
	assert_eq(menu.top, 2)
	assert_eq(menu.key(_press("Escape")), &"close")


func _log(lines: int) -> Menu:
	var menu := Menu.new()
	for i in lines:
		menu.log_rows.append([["줄 %d" % i, Palette.TEXT]])
	menu.open(&"log")
	return menu


func test_a_page_that_is_only_read_lights_no_row_and_its_keys_scroll_it() -> void:
	var menu := _log(40)
	var fits := menu._fits()
	var last := 40 - fits
	assert_eq(menu.top, last, "it opens on the newest")
	menu.point(last + 1)
	for k in 40:
		assert_false(PanelView.acts(menu.panel(), k), "no bar on row %d" % k)
	menu.key(_press("Up"))
	assert_eq(menu.top, last - 1, "Up scrolls a row")
	menu.key(_press("Down"))
	menu.key(_press("Down"))
	assert_eq(menu.top, 0, "Down from the end wraps to the start")
	menu.key(_press("Up"))
	assert_eq(menu.top, last, "Up from the start wraps to the end")
	menu.key(_press("Home"))
	menu.key(_press("PageDown"))
	assert_eq(menu.top, fits)
	menu.key(_press("End"))
	assert_eq(menu.top, last)
	assert_eq(menu.click(last + 1, -1), &"", "a click acts on nothing")
	assert_eq(menu.top, last)


func test_a_page_that_is_only_read_scrolls_from_its_end_after_the_screen_grows() -> void:
	var menu := _log(40)
	menu.room = Vector2i(40, 30)
	var last := 40 - menu._fits()
	assert_lt(last, menu.top, "the end is nearer now")
	menu.key(_press("Up"))
	assert_eq(menu.top, last - 1, "Up goes a row up from the end shown")


func test_the_bar_lights_a_spell_but_not_the_line_of_an_empty_spellbook() -> void:
	var menu := Menu.new()
	menu.open(&"spells")
	assert_false(PanelView.acts(menu.panel(), 0))
	menu.queued = Spell.make([Cards.FOX])
	menu.open(&"spells")
	assert_true(PanelView.acts(menu.panel(), 0))


func _options() -> Menu:
	var menu := Menu.new()
	menu.open(&"options")
	return menu


func _select(menu: Menu, row: StringName) -> void:
	menu.selected = (
		Menu.OPTIONS.find(row) if menu.page == &"options" else Keys.ACTIONS.keys().find(row)
	)


func test_options_step_and_wrap() -> void:
	var menu := _options()
	_select(menu, &"volume")
	assert_eq(menu.key(_press("Left")), &"changed")
	assert_eq(menu.settings.volume, 90)
	for i in 12:
		menu.key(_press("Left"))
	assert_eq(menu.settings.volume, 0, "stops at 0")
	var volume: Array = menu.panel().rows[Menu.OPTIONS.find(&"volume")]
	assert_eq(volume[1][0], "꺼짐", "silence is shown where the volume is set")
	_select(menu, &"music")
	assert_eq(menu.settings.music, 60, "music starts below the effects")
	menu.key(_press("Right"))
	assert_eq(menu.settings.music, 70)
	assert_eq(menu.settings.volume, 0, "the music row leaves the master volume alone")
	for i in 12:
		menu.key(_press("Right"))
	assert_eq(menu.settings.music, 100, "stops at 100")
	for i in 12:
		menu.key(_press("Left"))
	assert_eq(menu.settings.music, 0, "stops at 0")
	var music: Array = menu.panel().rows[Menu.OPTIONS.find(&"music")]
	assert_eq(music[0][0], "음악 크기")
	assert_eq(music[1][0], "꺼짐", "silence is shown where the music is set")
	_select(menu, &"zoom")
	var seen := []
	for i in Settings.ZOOMS.size():
		assert_eq(menu.use(), &"changed")
		seen.append(menu.settings.zoom)
	assert_eq(seen, [1.0, 1.25, 1.5, 0.0])
	_select(menu, &"crt")
	assert_eq(menu.settings.crt, 50)
	menu.key(_press("Right"))
	assert_eq(menu.settings.crt, 60)
	for i in 12:
		menu.key(_press("Left"))
	assert_eq(menu.settings.crt, 0, "stops at 0")
	var crt: Array = menu.panel().rows[Menu.OPTIONS.find(&"crt")]
	assert_eq(crt[1][0], "꺼짐", "no effect is shown where the strength is set")
	menu.key(_press("Right"))
	assert_eq(menu.panel().rows[Menu.OPTIONS.find(&"crt")][1][0], "10")
	_select(menu, &"restart")
	menu.use()
	assert_eq(menu.use(), &"restart")
	_select(menu, &"close")
	assert_eq(menu.use(), &"close")
	assert_eq(menu.key(_press("Escape")), &"close")


func _restart_label(menu: Menu) -> String:
	return menu.panel().rows[Menu.OPTIONS.find(&"restart")][0][0]


func test_the_first_use_of_the_restart_row_asks_and_the_second_acts() -> void:
	var menu := Menu.new()
	menu.open(&"options")
	_select(menu, &"restart")
	var name := _restart_label(menu)
	assert_eq(menu.key(_press("Enter")), &"ask")
	assert_ne(_restart_label(menu), name, "the row asks")
	assert_eq(menu.key(_press("Enter")), &"restart")


func test_moving_off_the_restart_row_or_esc_takes_the_question_back() -> void:
	var menu := Menu.new()
	menu.open(&"options")
	_select(menu, &"restart")
	var name := _restart_label(menu)
	menu.use()
	menu.key(_press("Down"))
	assert_eq(_restart_label(menu), name)
	menu.key(_press("Up"))
	assert_eq(_restart_label(menu), name, "coming back does not bring the question back")
	assert_eq(menu.use(), &"ask")
	assert_eq(menu.key(_press("Escape")), &"", "Esc takes it back and leaves the page open")
	assert_eq(_restart_label(menu), name)
	assert_eq(menu.use(), &"ask", "and the next use asks again")


func test_a_click_on_another_row_takes_the_restart_question_back() -> void:
	var menu := Menu.new()
	menu.open(&"options")
	_select(menu, &"restart")
	var name := _restart_label(menu)
	var row := Menu.OPTIONS.find(&"restart")
	assert_eq(menu.click(row, -1), &"ask")
	assert_eq(menu.click(Menu.OPTIONS.find(&"crt"), -1), &"changed", "another row is used")
	assert_eq(_restart_label(menu), name)
	assert_eq(menu.click(row, -1), &"ask")


func test_the_seed_is_a_row_of_the_options_that_enter_asks_to_copy() -> void:
	var menu := Menu.new()
	menu.seed_value = 2715675124
	menu.open(&"options")
	_select(menu, &"seed")
	var row: Array = menu.panel().rows[menu.selected]
	assert_string_contains(Messages.plain(row), "2715675124")
	assert_eq(menu.key(_press("Enter")), &"seed")
	assert_string_contains(Messages.plain(menu.panel().rows[menu.selected]), "2715675124")


func test_options_can_save_and_quit() -> void:
	var menu := _options()
	assert_string_contains(_text(menu.panel()), "저장하고 끝내기")
	_select(menu, &"quit")
	assert_eq(menu.use(), &"quit")
	assert_eq(menu.key(_press("Enter")), &"quit")


func test_a_new_key_leaves_the_action_that_had_it() -> void:
	var menu := _options()
	_select(menu, &"keys")
	menu.use()
	assert_eq(menu.page, &"keys")
	_select(menu, &"explore")
	menu.key(_press("Enter"))
	assert_true(menu.waiting)
	assert_eq(menu.key(_press("Shift")), &"", "a modifier alone waits on")
	assert_eq(menu.key(_press("Shift+K")), &"changed")
	assert_eq(Keys.keys_of(&"explore"), ["O", "Shift+K"] as Array[String])
	menu.key(_press("Enter"))
	assert_eq(menu.key(_press("K")), &"changed")
	assert_eq(Keys.keys_of(&"move_n"), ["Up", "Kp 8"] as Array[String], "K left moving up")
	assert_eq(Keys.action_of(_press("K")), &"explore")


func test_keys_clear_cancel_and_reset() -> void:
	var menu := _options()
	_select(menu, &"keys")
	menu.use()
	_select(menu, &"rest")
	assert_eq(menu.key(_press("Delete")), &"changed")
	assert_true(Keys.keys_of(&"rest").is_empty())
	menu.key(_press("Enter"))
	assert_eq(menu.key(_press("Escape")), &"", "Esc stops waiting")
	assert_false(menu.waiting)
	assert_true(Keys.keys_of(&"rest").is_empty())
	menu.selected = Keys.ACTIONS.size()
	assert_eq(menu.use(), &"changed")
	assert_eq(Keys.keys_of(&"rest"), ["Z"] as Array[String])
	assert_eq(menu.key(_press("Escape")), &"")
	assert_eq(menu.page, &"options")


func test_the_spellbook_lists_the_queue_then_the_saved_spells_and_a_slot_key_saves_one() -> void:
	var menu := Menu.new()
	menu.settings.spells = {&"slot_2": "orb+fire"}
	menu.queued = Spell.make([Cards.FOX, Cards.FOX, Cards.FIRE])
	menu.open(&"spells")
	var text := _text(menu.panel())
	assert_eq(menu.panel().rows.size(), 2, "the queue, then the saved spell")
	assert_string_contains(text, "불 여우불 2발")
	assert_string_contains(text, "불 구슬")
	assert_false(menu.panel().detail.is_empty(), "the selected spell's effect")
	assert_eq(menu.key(_press("Q")), &"changed")
	assert_eq(menu.settings.spells, {&"slot_1": "fox+fox+fire", &"slot_2": "orb+fire"})
	assert_eq(menu.key(_press("Q")), &"changed")
	assert_eq(menu.settings.spells, {&"slot_2": "orb+fire"}, "the same key again clears it")
	assert_eq(menu.use(), &"cast")
	assert_eq(menu.chosen.key(), "fox+fox+fire")


func test_an_empty_spellbook_says_so_and_enter_closes_it() -> void:
	var menu := Menu.new()
	menu.open(&"spells")
	assert_string_contains(_text(menu.panel()), "저장한 주문도 없다")
	assert_eq(menu.use(), &"close")


func test_the_one_row_of_an_empty_spellbook_stays_selected_whatever_the_key() -> void:
	var menu := Menu.new()
	menu.open(&"spells")
	for key in ["Up", "Down", "PageUp", "PageDown", "Home", "End"]:
		menu.key(_press(key))
		assert_eq(menu.selected, 0, key)


func test_the_keys_page_wraps_and_a_click_selects_a_row_without_binding() -> void:
	var menu := _options()
	_select(menu, &"keys")
	menu.use()
	menu.key(_press("Up"))
	assert_eq(menu.selected, Keys.ACTIONS.size(), "up from the first row reaches the reset row")
	assert_eq(menu.click(2, -1), &"", "the click on an action starts the wait")
	assert_eq(menu.selected, 2)
	assert_true(menu.waiting)
	assert_eq(menu.click(4, -1), &"", "a click while a key is awaited does nothing")
	assert_eq(menu.selected, 2)


func test_a_click_lowers_a_full_slider_to_nothing() -> void:
	var menu := _options()
	for option: StringName in [&"volume", &"music", &"crt"]:
		menu.settings.set(option, 90)
		var row := Menu.OPTIONS.find(option)
		assert_eq(menu.click(row, -1), &"changed", option)
		assert_eq(menu.settings.get(option), 100, option)
		menu.click(row, -1)
		assert_eq(menu.settings.get(option), 0, "%s goes round" % option)
		menu.click(row, -1)
		assert_eq(menu.settings.get(option), 10, option)
	_select(menu, &"crt")
	menu.settings.crt = 100
	menu.key(_press("Right"))
	assert_eq(menu.settings.crt, 100, "the Right key stops at the top")


func test_a_detail_too_tall_for_the_screen_stays_under_the_list_and_scrolls_to_its_end() -> void:
	var menu := Menu.new()
	var spell := Spell.make(Guise.RECIPE[Guise.CLOAK])
	var all := SpellInfo.spell(spell)
	menu.queued = spell
	menu.open(&"spells", Vector2i(40, 12))
	assert_gt(all.size(), 12 - 5, "the spell's detail is taller than the screen")
	var shown: Dictionary = menu.panel()
	assert_eq(shown.detail.size(), 12 - 5)
	assert_eq(shown.detail[0], all[0])
	assert_true(shown.aside_down)
	menu.scroll_by(99, true)
	shown = menu.panel()
	assert_eq(shown.detail.back(), all.back())
	assert_false(shown.aside_down)
	assert_true(shown.aside_up)
	menu.scroll_by(-99, true)
	assert_eq(menu.panel().detail[0], all[0])


func test_clearing_the_slot_of_the_last_spell_keeps_the_selection_on_the_list() -> void:
	var menu := Menu.new()
	menu.settings.spells = {&"slot_1": "orb+fire", &"slot_2": "fox+fire"}
	menu.open(&"spells", Vector2i(60, 24))
	menu.selected = 1
	menu.save(&"slot_2")
	assert_eq(menu.selected, 0)
	assert_eq(menu.panel().rows.size(), 1)
