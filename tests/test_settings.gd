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
	s.music = 30
	s.crt = 30
	s.zoom = 1.25
	s.speed = 4.0
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


func test_the_highlight_replay_is_off_whatever_an_old_file_says_and_has_no_option() -> void:
	var c := ConfigFile.new()
	c.set_value("settings", "replay", true)
	var s := Settings.new()
	s.from_config(c)
	assert_false(s.replay)
	assert_false(s.to_config().has_section_key("settings", "replay"))
	assert_false(Menu.OPTIONS.has(&"replay"))


func test_a_saved_spell_row_draws_its_key_slots_cost_and_name_apart() -> void:
	var menu := Menu.new()
	menu.settings.spells = {&"slot_1": "orb+orb+orb+orb+orb"}
	var row: Array = menu._spells(menu.spells())[0]
	var x := 2.0
	for run: Array in row:
		var at: float = run[2] if run.size() > 2 else x
		assert_gte(at, x, run[0])
		x = at + Term.text_cells(run[0])


func test_missing_or_wrong_values_fall_back_to_defaults() -> void:
	var c := ConfigFile.new()
	c.set_value("settings", "volume", 900)
	c.set_value("settings", "zoom", 3.0)
	c.set_value("settings", "speed", "fast")
	c.set_value("keys", "wait", "Period")
	var s := Settings.new()
	s.from_config(c)
	assert_eq(s.volume, 100)
	assert_eq(s.music, 60, "a file from before the music option keeps its default")
	assert_eq(s.zoom, 0.0)
	assert_eq(s.speed, 1.0)
	assert_eq(Keys.keys_of(&"wait"), Keys.ACTIONS[&"wait"][1] as Array[String])
	assert_eq(Keys.keys_of(&"move_n"), Keys.ACTIONS[&"move_n"][1] as Array[String])


func test_music_volume_stays_within_zero_and_one_hundred() -> void:
	for pair in [[-5, 0], [900, 100], [70, 70]]:
		var c := ConfigFile.new()
		c.set_value("settings", "music", pair[0])
		var s := Settings.new()
		s.from_config(c)
		assert_eq(s.music, pair[1], str(pair[0]))


func test_only_changed_keys_are_saved() -> void:
	Keys.bind(&"explore", ["Kp Add"])
	Keys.bind(&"rest", [])
	var c := Settings.new().to_config()
	assert_eq(c.get_section_keys("keys"), PackedStringArray(["explore", "rest"]))
	assert_eq(c.get_value("keys", "rest"), [])
	Keys.reset()
	assert_false(Settings.new().to_config().has_section("keys"), "defaults store no keys")


func test_defaults_changed_since_saving_reach_the_player() -> void:
	var c := ConfigFile.new()
	c.set_value("keys", "explore", ["Kp Add"])
	c.set_value("keys", "options", ["O"])
	c.set_value("keys", "gone", ["Q"])
	Settings.new().from_config(c)
	assert_eq(Keys.keys_of(&"explore"), ["Kp Add"] as Array[String])
	assert_eq(Keys.keys_of(&"cancel"), Keys.ACTIONS[&"cancel"][1] as Array[String])
	assert_false(InputMap.has_action(&"gone"))
	assert_false(InputMap.has_action(&"options"))


func test_old_default_keys_saved_before_the_key_change_give_way_to_new_ones() -> void:
	var c := ConfigFile.new()
	c.set_value("keys", "explore", ["X"])
	c.set_value("keys", "log", ["P"])
	c.set_value("keys", "restart", ["R"])
	c.set_value("keys", "move_ne", ["Kp 9", "U", "PageUp"])
	var s := Settings.new()
	s.from_config(c)
	assert_eq(Keys.keys_of(&"explore"), ["O"] as Array[String])
	assert_eq(Keys.keys_of(&"log"), ["Ctrl+P", "P"] as Array[String])
	assert_eq(Keys.keys_of(&"restart"), ["Ctrl+Q"] as Array[String])
	assert_eq(Keys.keys_of(&"move_ne"), ["Kp 9", "U", "PageUp"] as Array[String], "own keys stay")
	c.set_value("settings", "keys_version", Settings.KEYS_VERSION)
	s.from_config(c)
	assert_eq(Keys.keys_of(&"explore"), ["X"] as Array[String], "chosen after the change")


func test_saved_spells_round_trip_and_bad_ones_are_dropped() -> void:
	var s := Settings.new()
	s.spells = {&"slot_1": "fox+fire", &"slot_2": "fox+bomb", &"slot_3": "fox+fox+fox+fox+fox+fox"}
	var back := _reload(s)
	assert_eq(back.spells, {&"slot_1": "fox+fire"})


func test_sound_is_silent_only_at_volume_zero() -> void:
	var c := ConfigFile.new()
	c.set_value("settings", "muted", true)
	var s := Settings.new()
	s.path = ""
	s.from_config(c)
	s.apply_sound()
	assert_false(AudioServer.is_bus_mute(0), "a mute saved by an older version is dropped")
	s.volume = 0
	s.apply_sound()
	assert_true(AudioServer.is_bus_mute(0))
	s.volume = 100
	s.apply_sound()


func test_the_crt_is_at_half_strength_by_default() -> void:
	assert_eq(Settings.new().crt, 50)
	var s := Settings.new()
	s.from_config(ConfigFile.new())
	assert_eq(s.crt, 50)


func test_a_saved_crt_on_loads_as_half_strength_and_off_as_none() -> void:
	for saved in [[true, 50], [false, 0], [80, 80], [250, 100], [-3, 0], ["x", 50]]:
		var c := ConfigFile.new()
		c.set_value("settings", "crt", saved[0])
		var s := Settings.new()
		s.from_config(c)
		assert_eq(s.crt, saved[1], str(saved[0]))
