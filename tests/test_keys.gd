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
