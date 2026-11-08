extends GutTest
## The language is a setting: every screen follows it at once, it is saved with
## the other settings, and the rules never read it.

const SEED := 114


func before_each() -> void:
	Lang.locked = false
	Lang.korean_symbols = false


func after_each() -> void:
	Lang.use(&"ko")
	Lang.locked = true
	Lang.korean_symbols = true
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
	assert_eq(Lang.active(), &"ja")
	assert_string_contains(_row_text(menu, &"language"), "日本語")
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
	assert_eq(runs[0], ["Flammable", Palette.FIRE_TAG, Palette.FLAMMABLE])
	assert_eq(runs[2], ["Combustible", Palette.FIRE_TAG, Palette.FIERCE_BACK])
	assert_eq(
		Keywords.runs("Flammables", Palette.TEXT),
		[["Flammables", Palette.TEXT]],
		"only whole words"
	)
	Lang.use(&"ko")
	assert_eq(Keywords.runs("Flammable", Palette.TEXT), [["Flammable", Palette.TEXT]])
	assert_eq(Keywords.runs("가연성", Palette.TEXT)[0][2], Palette.FLAMMABLE)


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


## The lines of `text` that still hold Korean.
func _korean(text: String) -> Array:
	var find := RegEx.create_from_string("[가-힣]")
	return Array(text.split("\n")).filter(func(line: String): return find.search(line) != null)


func test_every_codex_entry_reads_in_english() -> void:
	Lang.use(&"en")
	var left := []
	for tab in Codex.TABS.size():
		for e in Codex.entries(tab):
			for line in _korean(e.name + "\n" + Info.plain(Codex.detail(e))):
				left.append("%d %s: %s" % [tab, e.name, line])
	assert_eq(left, [], "Korean left in the English codex")


func test_every_codex_entry_reads_in_japanese() -> void:
	Lang.use(&"ja")
	var left := []
	for tab in Codex.TABS.size():
		for e in Codex.entries(tab):
			for line in _korean(e.name + "\n" + Info.plain(Codex.detail(e))):
				left.append("%d %s: %s" % [tab, e.name, line])
	assert_eq(left, [], "Korean left in the Japanese codex")


func test_every_menu_page_reads_in_english() -> void:
	Lang.use(&"en")
	var left := []
	for page: StringName in [&"main", &"options", &"keys", &"help", &"spells", &"log", &"cheat"]:
		var menu := Menu.new()
		menu.settings = Settings.new()
		menu.debug.world = World.create(7)
		menu.open(page)
		var shown := menu.panel()
		var rows: Array = shown.get("rows", []) + shown.get("detail", []) + shown.get("aside", [])
		var text := (
			Info.plain(rows) + "\n" + str(shown.get("title", "")) + str(shown.get("tabs", []))
		)
		for line in _korean(text.replace(Lang.NAMES[&"ko"], "")):
			left.append("%s: %s" % [page, line])
	assert_eq(left, [], "Korean left on an English menu page")


func test_a_long_log_of_every_spell_reads_in_english() -> void:
	Lang.use(&"en")
	var left := []
	var total := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for seed_value in [3, 7, 114, 21, 40, 51, 60, 77, 88]:
		var w := World.create(seed_value)
		var messages := Messages.new()
		for i in 160:
			var recipe: Array = SpellInfo.RECIPE.values()[rng.randi() % SpellInfo.RECIPE.size()]
			var cast := {t = &"cast", spells = [{cards = recipe, dir = Grid.DIRS[rng.randi() % 8]}]}
			var step := {t = &"move", dir = Grid.DIRS[rng.randi() % 8]}
			var action := cast if rng.randi() % 3 == 0 and w.can(cast) else step
			if not w.can(action):
				action = {t = &"wait"}
			var before := w.clone()
			messages.add_round(before, w, w.act(action))
		total += messages.lines.size()
		for line in messages.lines:
			left.append_array(_korean(Messages.plain(Messages.shown(line))))
	assert_gt(total, 100, "the log has lines to check")
	assert_eq(left, [], "Korean left in an English log")


func test_the_title_the_ending_the_step_question_and_a_refusal_read_in_english() -> void:
	Lang.use(&"en")
	var touch: Touch = autofree(Touch.new())
	var w := World.create(7)
	var left := []
	for lines in [Banner.title(null, false, touch), Banner.title(SaveGame.new(), true, touch)]:
		left.append_array(_korean("\n".join(lines)))
	w.outcome = &"lost"
	left.append_array(_korean("\n".join(Banner.over(w, 3, 5))))
	left.append_array(_korean(StepGuard.question(w, Vector2i(1, 0), false)))
	left.append_array(_korean(Guise.shown_only()))
	assert_eq(left, [], "Korean left on a banner or in the step question")


func test_a_count_of_one_reads_in_the_singular() -> void:
	Lang.use(&"en")
	assert_eq(Lang.singular("Around: 1 tiles, 11 tiles"), "Around: 1 tile, 11 tiles")
	assert_eq(Lang.singular("Fall: 1 floors, 1 more times"), "Fall: 1 floor, 1 more time")
	Lang.use(&"ko")
	assert_eq(Lang.singular("1 tiles"), "1 tiles")


func test_the_log_page_follows_a_language_chosen_in_the_same_menu() -> void:
	var m: Node = Built.main()
	add_child_autofree(m)
	m.settings.path = ""
	m.settings.language = "ko"
	m.apply()
	m.messages.add_round(World.create(7), World.create(7), [{t = &"ascend", depth = 2}])
	m.panels.open(&"options")
	m.menu.selected = Menu.OPTIONS.find(&"language")
	var right := Keys.event("Right")
	right.pressed = true
	m.panels.input(right)
	assert_eq(m.settings.language, "en")
	m.menu.page = &"log"
	assert_string_ends_with(Messages.plain(m.menu.panel().rows[0]), "Climbed to Floor 2")


func test_the_log_and_the_hover_call_the_player_you() -> void:
	var w := World.create(7)
	var me := w.player()
	var quench := func() -> String:
		var lines := Messages.new()
		lines.add_round(w, w, [{t = &"quench", id = me.id}])
		return Messages.plain(Messages.shown(lines.lines[0]))
	Lang.use(&"ko")
	assert_eq(quench.call(), "당신의 불이 꺼졌다")
	assert_true(Info.plain(Info.creature(w, me)).begins_with("당신 "))
	Lang.use(&"en")
	assert_eq(quench.call(), "Your fire went out")
	assert_true(Info.plain(Info.creature(w, me)).begins_with("You "))


func test_euro_follows_a_final_consonant_but_not_rieul() -> void:
	var with := func(word: String):
		return Info.plain([Lang.runs("{0}으로/로", [[word, Palette.TEXT]], Palette.TEXT)])
	assert_eq(with.call("흙"), "흙으로")
	assert_eq(with.call("물"), "물로")
	assert_eq(with.call("재"), "재로")
	assert_eq(Info.plain([Lang.runs("{0}을/를", [["물", Palette.TEXT]], Palette.TEXT)]), "물을")


func test_the_symbols_stay_hangul_in_other_languages_until_the_option_is_off() -> void:
	var glyph: String = Bestiary.info(&"dokkaebi").glyph
	var talisman: String = Cards.GLYPH[Cards.FOX]
	for code: StringName in [&"en", &"ja"]:
		Lang.use(code)
		Lang.korean_symbols = true
		assert_eq(Lang.t(glyph, "creature"), glyph, "%s creature" % code)
		assert_eq(Lang.t(talisman, "talisman"), talisman, "%s talisman" % code)
		assert_ne(Lang.t("도깨비"), "도깨비", "%s name is still translated" % code)
		Lang.korean_symbols = false
		assert_ne(Lang.t(glyph, "creature"), glyph, "%s creature off" % code)
		assert_ne(Lang.t(talisman, "talisman"), talisman, "%s talisman off" % code)
	Lang.use(&"en")
	assert_eq(Lang.t(glyph, "creature"), "D")


func test_the_option_defaults_to_on_and_survives_a_settings_reload() -> void:
	var s := Settings.new()
	assert_true(s.korean_symbols)
	s.korean_symbols = false
	var c := ConfigFile.new()
	assert_eq(c.parse(s.to_config().encode_to_text()), OK)
	var back := Settings.new()
	back.from_config(c)
	assert_false(back.korean_symbols)
	c.set_value("settings", "korean_symbols", "no")
	back.korean_symbols = true
	back.from_config(c)
	assert_true(back.korean_symbols, "a wrong value keeps the current one")


func test_toggling_the_option_in_the_menu_changes_the_symbols_at_once() -> void:
	var menu := Menu.new()
	menu.settings = Settings.new()
	menu.settings.language = "en"
	menu.settings.apply_language()
	menu.open(&"options")
	menu.selected = Menu.OPTIONS.find(&"korean_symbols")
	var glyph: String = Bestiary.info(&"dokkaebi").glyph
	assert_eq(Lang.t(glyph, "creature"), glyph)
	assert_eq(menu._change(1), &"changed")
	assert_false(menu.settings.korean_symbols)
	assert_eq(Lang.t(glyph, "creature"), "D")
	assert_string_contains(_row_text(menu, &"korean_symbols"), "Off")


func test_japanese_is_listed_and_a_japanese_system_starts_in_it() -> void:
	assert_true(Lang.NAMES.has(&"ja"))
	assert_eq(Lang.detect("ja"), &"ja")
	assert_eq(Lang.detect("ko"), &"ko")
	assert_eq(Lang.detect("fr"), &"en")


func test_a_japanese_line_gets_no_korean_particle_and_no_english_fix() -> void:
	Lang.use(&"ja")
	var line := Messages.plain(
		Lang.runs("{0}이/가 {1}을/를 먹고 커졌다", [["도깨비", Color.WHITE], ["복숭아", Color.WHITE]], Color.WHITE)
	)
	assert_false(line.contains("/"))
	assert_false(line.contains("이"))
	assert_true(line.contains("トッケビ"))
