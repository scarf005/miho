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
