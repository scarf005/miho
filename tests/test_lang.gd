extends GutTest
## The language is a setting: every screen follows it at once, it is saved with
## the other settings, and the rules never read it.

const SEED := 114


func before_each() -> void:
	Lang.locked = false


func after_each() -> void:
	Lang.use(&"ko")
	Lang.locked = true
	TranslationServer.set_locale("ko")


func _row_text(menu: Menu, option: StringName) -> String:
	var row: Array = menu.panel().rows[Menu.OPTIONS.find(option)]
	return Info.plain([row.filter(func(run): return run is Array and run[0] is String)])


func test_switching_the_language_changes_a_hover_a_log_line_and_a_menu_row_at_once() -> void:
	var w := World.create(7)
	var lantern := Vector2i(-1, -1)
	for i in w.tiles.size():
		if w.tiles[i] == World.LANTERN:
			lantern = Grid.at(i)
			w.known[i] = 1
			break
	var menu := Menu.new()
	menu.settings = Settings.new()
	menu.settings.language = "ko"
	menu.open(&"options")
	var messages := Messages.new()
	messages.add_round(w, w, [{t = &"ascend", depth = 2}])
	Lang.use(&"ko")
	assert_true(Info.plain(Info.terrain(w, lantern)).begins_with("등불 ♥"))
	assert_eq(Messages.plain(Messages.shown(messages.lines[0])), "2층으로 올라갔다")
	assert_string_contains(_row_text(menu, &"language"), "한국어")
	Lang.use(&"en")
	menu.settings.language = "en"
	assert_true(Info.plain(Info.terrain(w, lantern)).begins_with("Lantern ♥"))
	assert_eq(Messages.plain(Messages.shown(messages.lines[0])), "Climbed to Floor 2")
	assert_string_contains(_row_text(menu, &"language"), "English")
	assert_string_contains(_row_text(menu, &"language"), "Language")


func test_choosing_the_language_in_the_options_shows_it_without_a_restart() -> void:
	var menu := Menu.new()
	menu.settings = Settings.new()
	menu.settings.language = "ko"
	menu.open(&"options")
	menu.selected = Menu.OPTIONS.find(&"language")
	assert_eq(menu._change(1), &"changed")
	assert_eq(menu.settings.language, "en")
	assert_eq(Lang.active(), &"en")
	assert_string_contains(_row_text(menu, &"language"), "English")
	menu._change(1)
	assert_eq(Lang.active(), &"ko")


func test_the_language_survives_a_settings_reload() -> void:
	var s := Settings.new()
	s.language = "en"
	var c := ConfigFile.new()
	assert_eq(c.parse(s.to_config().encode_to_text()), OK)
	var back := Settings.new()
	back.language = "ko"
	back.from_config(c)
	assert_eq(back.language, "en")
	c.set_value("settings", "language", "xx")
	back.language = "ko"
	back.from_config(c)
	assert_eq(back.language, "ko", "an unknown code keeps the current language")


## Plays `n` rounds of SEED with the log kept in the language `code`.
func _play(code: StringName, n: int) -> Dictionary:
	Lang.use(code)
	var w := World.create(SEED)
	var messages := Messages.new()
	for i in n:
		var action := {t = &"wait"}
		var cast := {t = &"cast", spells = [{cards = [Cards.FOX], dir = Grid.DIRS[i % 8]}]}
		var step := {t = &"move", dir = Grid.DIRS[i % 8]}
		if i % 5 == 4 and w.can(cast):
			action = cast
		elif w.can(step):
			action = step
		var before := w.clone()
		messages.add_round(before, w, w.act(action))
	return {world = w, messages = messages}


func test_a_world_played_with_the_same_actions_ends_the_same_in_both_languages() -> void:
	var ko := _play(&"ko", 40)
	var en := _play(&"en", 40)
	var a: World = ko.world
	var b: World = en.world
	assert_eq(a.round_no, b.round_no)
	assert_eq(a.tiles, b.tiles)
	assert_eq(a.known, b.known)
	assert_eq(a.player().pos, b.player().pos)
	assert_eq(a.player().hp, b.player().hp)
	assert_eq(a.tails, b.tails)
	assert_eq(a.rng.state, b.rng.state)
	assert_eq(
		ko.messages.lines.map(func(l): return l.text), en.messages.lines.map(func(l): return l.text)
	)
	assert_false(ko.messages.lines.is_empty())


func test_keywords_colour_the_english_word_and_the_log_keeps_both_languages() -> void:
	Lang.use(&"en")
	var runs := Keywords.runs("Flammable. Combustible.", Palette.TEXT)
	assert_eq(runs[0], ["Flammable", Palette.FLAMMABLE])
	assert_eq(runs[2], ["Combustible", Palette.FIERCE_TEXT, Palette.FIERCE_BACK])
	assert_eq(
		Keywords.runs("Flammables", Palette.TEXT),
		[["Flammables", Palette.TEXT]],
		"only whole words"
	)
	Lang.use(&"ko")
	assert_eq(Keywords.runs("Flammable", Palette.TEXT), [["Flammable", Palette.TEXT]])
	assert_eq(Keywords.runs("가연성", Palette.TEXT)[0][1], Palette.FLAMMABLE)


func test_korean_particles_do_not_reach_english_lines() -> void:
	Lang.use(&"en")
	var line := Messages.plain(
		Lang.runs(
			"{0}이/가 {1}을/를 먹고 커졌다", [["Dokkaebi", Color.WHITE], ["Peach", Color.WHITE]], Color.WHITE
		)
	)
	assert_eq(line, "Dokkaebi ate Peach and grew")
	Lang.use(&"ko")
	line = Messages.plain(
		Lang.runs("{0}이/가 {1}을/를 먹고 커졌다", [["도깨비", Color.WHITE], ["복숭아", Color.WHITE]], Color.WHITE)
	)
	assert_eq(line, "도깨비가 복숭아를 먹고 커졌다")
