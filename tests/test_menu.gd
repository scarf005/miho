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
	assert_string_contains(text, "탐험 Shift+X")
	assert_string_contains(text, "계단으로 Shift+.")
	assert_string_contains(text, "부적 고르기 1 2 3 4 5 6 7")


func test_help_scrolls_and_esc_closes_it() -> void:
	var menu := Menu.new()
	menu.open(&"help")
	assert_eq(menu.key(_press("Down")), &"")
	assert_eq(menu.key(_press("J")), &"")
	assert_eq(menu.selected, 2)
	assert_eq(menu.key(_press("Escape")), &"close")


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
	_select(menu, &"zoom")
	var seen := []
	for i in Settings.ZOOMS.size():
		assert_eq(menu.use(), &"changed")
		seen.append(menu.settings.zoom)
	assert_eq(seen, [1.0, 1.25, 1.5, 0.0])
	_select(menu, &"crt")
	menu.key(_press("Right"))
	assert_false(menu.settings.crt)
	_select(menu, &"restart")
	assert_eq(menu.use(), &"restart")
	_select(menu, &"close")
	assert_eq(menu.use(), &"close")
	assert_eq(menu.key(_press("Escape")), &"close")


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
	assert_eq(Keys.keys_of(&"explore"), ["X", "Shift+K"] as Array[String])
	menu.key(_press("Enter"))
	assert_eq(menu.key(_press("K")), &"changed")
	assert_eq(Keys.keys_of(&"move_n"), ["Up", "Kp 8"] as Array[String], "K left moving up")
	assert_eq(Keys.action_of(_press("K")), &"explore")


func test_keys_clear_cancel_and_reset() -> void:
	var menu := Menu.new()
	menu.open(&"keys")
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
