extends GutTest
## Which action a key press means.


func before_each() -> void:
	Keys.reset()


func _press(key: String) -> InputEventKey:
	var e := Keys.event(key)
	e.pressed = true
	return e


func test_every_action_has_a_default_key() -> void:
	for action in Keys.ACTIONS:
		assert_false(Keys.keys_of(action).is_empty(), action)


func test_a_modifier_picks_the_action_bound_with_it() -> void:
	assert_eq(Keys.action_of(_press("Period")), &"wait")
	assert_eq(Keys.action_of(_press("Shift+Period")), &"stairs")
	assert_eq(Keys.action_of(_press("Shift+Slash")), &"help")


func test_shift_with_a_direction_still_moves() -> void:
	assert_eq(Keys.action_of(_press("Shift+Up")), &"move_n")
	assert_eq(Keys.action_of(_press("Shift+Kp 3")), &"move_se")


func test_the_left_ctrl_key_alone_takes_back_one_spell() -> void:
	for held in [false, true]:
		var e := InputEventKey.new()
		e.keycode = KEY_CTRL
		e.location = KEY_LOCATION_LEFT
		e.ctrl_pressed = held
		e.pressed = true
		assert_eq(Keys.action_of(e), &"unpick", "ctrl_pressed %s" % held)
	assert_eq(Keys.action_of(_press("Ctrl+P")), &"log")


func test_an_unbound_key_means_nothing() -> void:
	assert_eq(Keys.action_of(_press("F12")), &"")
	assert_eq(Keys.action_of(_press("Shift+X")), &"")


func test_keys_read_back_as_they_were_bound() -> void:
	Keys.bind(&"explore", ["Shift+X", "Kp Add"])
	assert_eq(Keys.keys_of(&"explore"), ["Shift+X", "Kp Add"] as Array[String])
	assert_eq(Keys.action_of(_press("Shift+X")), &"explore")


func test_labels_show_printable_keys_as_characters() -> void:
	assert_eq(Keys.label("Shift+Period"), ">")
	assert_eq(Keys.label("K"), "K")
	assert_eq(Keys.label("Kp 8"), "키패드 8")
	assert_eq(Keys.label("Kp Period"), "키패드 .")
	assert_eq(Keys.label("Shift+V"), "Shift+V")
	assert_eq(Keys.label("Escape"), "Esc")


func test_default_keys_follow_roguelike_conventions() -> void:
	assert_eq(Keys.action_of(_press("O")), &"explore")
	assert_eq(Keys.action_of(_press("Escape")), &"cancel")
	assert_eq(Keys.action_of(_press("Ctrl+P")), &"log")
	assert_eq(Keys.action_of(_press("P")), &"log")
	assert_false(Keys.ACTIONS.has(&"options"), "Esc is the one key for cancel and options")


func test_x_looks_around_and_the_look_key_is_not_exploring() -> void:
	assert_eq(Keys.action_of(_press("X")), &"look")
	assert_ne(Keys.action_of(_press("X")), &"explore")


## A press of the keypad key `pad` as Num Lock makes it read: `key` is what it sends.
func _pad(pad: Key, key: String) -> InputEventKey:
	var e := _press(key)
	e.physical_keycode = pad
	return e


func test_the_keypad_moves_whatever_num_lock_says() -> void:
	for row in [
		[KEY_KP_7, "Home", "7", &"move_nw"],
		[KEY_KP_8, "Up", "8", &"move_n"],
		[KEY_KP_9, "PageUp", "9", &"move_ne"],
		[KEY_KP_4, "Left", "4", &"move_w"],
		[KEY_KP_5, "Clear", "5", &"wait"],
		[KEY_KP_6, "Right", "6", &"move_e"],
		[KEY_KP_1, "End", "1", &"move_sw"],
		[KEY_KP_2, "Down", "2", &"move_s"],
		[KEY_KP_3, "PageDown", "3", &"move_se"],
		[KEY_KP_PERIOD, "Delete", "Period", &"wait"],
	]:
		assert_eq(Keys.action_of(_pad(row[0], row[1])), row[3], "off: %s" % row[1])
		assert_eq(Keys.action_of(_pad(row[0], row[2])), row[3], "on: %s" % row[2])


func test_the_keys_above_the_arrows_and_the_digit_row_keep_their_meaning() -> void:
	assert_eq(Keys.action_of(_pad(KEY_HOME, "Home")), &"")
	assert_eq(Keys.action_of(_pad(KEY_PAGEUP, "PageUp")), &"")
	assert_eq(Keys.action_of(_pad(KEY_7, "7")), &"pick_7")


func test_a_list_reads_the_keypad_with_num_lock_off_as_list_keys() -> void:
	assert_eq(Menu._nav(_pad(KEY_KP_7, "Home")), &"home")
	assert_eq(Menu._nav(_pad(KEY_KP_1, "End")), &"end")
	assert_eq(Menu._nav(_pad(KEY_KP_9, "PageUp")), &"page_up")
	assert_eq(Menu._nav(_pad(KEY_KP_3, "PageDown")), &"page_down")


func test_a_key_bound_from_the_keypad_is_the_keypad_key() -> void:
	var menu := Menu.new()
	menu.page = &"keys"
	menu.selected = menu._actions().find(&"dispel")
	menu._bind(_pad(KEY_KP_9, "PageUp"))
	assert_has(Keys.keys_of(&"dispel"), "Kp 9")
