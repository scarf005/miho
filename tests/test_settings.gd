extends GutTest
## Settings and key bindings survive a save and a load.


func after_each() -> void:
	Keys.reset()


func _events(action: StringName) -> Array:
	return InputMap.action_get_events(action).map(
		func(e): return [e.keycode, e.shift_pressed, e.ctrl_pressed, e.alt_pressed]
	)


func _reload(s: Settings) -> Settings:
	var text := s.to_config().encode_to_text()
	Keys.reset()
	var c := ConfigFile.new()
	assert_eq(c.parse(text), OK)
	var back := Settings.new()
	back.from_config(c)
	return back


func test_options_and_bindings_round_trip() -> void:
	var s := Settings.new()
	s.volume = 40
	s.crt = false
	s.zoom = 1.25
	s.speed = 4.0
	s.replay = false
	s.muted = true
	Keys.bind(&"explore", ["Shift+X", "Kp Add"])
	Keys.bind(&"rest", [])
	var saved := {}
	for action in Keys.ACTIONS:
		saved[action] = _events(action)
	var back := _reload(s)
	for n in Settings.NAMES:
		assert_eq(back.get(n), s.get(n), n)
	for action in Keys.ACTIONS:
		assert_eq(_events(action), saved[action], action)
	assert_true(Keys.event("Shift+X").is_match(InputMap.action_get_events(&"explore")[0]))


func test_missing_or_wrong_values_fall_back_to_defaults() -> void:
	var c := ConfigFile.new()
	c.set_value("settings", "volume", 900)
	c.set_value("settings", "zoom", 3.0)
	c.set_value("settings", "speed", "fast")
	c.set_value("keys", "wait", "Period")
	var s := Settings.new()
	s.from_config(c)
	assert_eq(s.volume, 100)
	assert_eq(s.zoom, 0.0)
	assert_eq(s.speed, 1.0)
	assert_eq(Keys.keys_of(&"wait"), Keys.ACTIONS[&"wait"][1] as Array[String])
	assert_eq(Keys.keys_of(&"move_n"), Keys.ACTIONS[&"move_n"][1] as Array[String])
