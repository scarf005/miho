extends GutTest
## The 도감: every creature, spell, compound, item and tile, told as the hover tells it.

const FAR := Vector2i(20, 8)


func before_each() -> void:
	Keys.reset()


func after_all() -> void:
	Keys.reset()


func _press(key: String) -> InputEventKey:
	var e := Keys.event(key)
	e.pressed = true
	return e


func _names(tab: int) -> Array:
	return Codex.entries(tab).map(func(e): return e.name)


func _entry(tab: int, name: String) -> Dictionary:
	return Codex.entries(tab).filter(func(e): return e.name == name)[0]


func _text(lines: Array) -> String:
	return Info.plain(lines)


func _open() -> Menu:
	var menu := Menu.new()
	menu.open(&"codex")
	return menu


func test_the_foes_are_the_creatures_of_heaven() -> void:
	var names := _names(0)
	assert_eq(names.size(), Codex.foes().size())
	for kind in Bestiary.KINDS:
		var heaven: bool = Bestiary.info(kind).has("group")
		assert_eq(names.has(Bestiary.info(kind).name), heaven, kind)


## Every line of `facts` is a line of `hover`, in order.
func _assert_within(facts: Array, hover: Array, what: String) -> void:
	var at := 0
	for line in facts:
		var found := false
		while at < hover.size() and not found:
			found = _text([hover[at]]) == _text([line])
			at += 1
		assert_true(found, "%s: %s" % [what, _text([line])])


func test_a_foes_facts_are_its_hover_less_how_it_stands() -> void:
	for kind in Codex.foes():
		var w := Codex.stage()
		var hover := Info.creature(w, FloorGen.spawn(w, kind, FAR))
		var facts := Codex.detail(_entry(0, Bestiary.info(kind).name))
		_assert_within(facts, hover, kind)
		assert_false(_text(facts).contains("발톱"), "Miho's claws are told on her, not on each foe")
	var text := _text(Codex.detail(_entry(0, "불개")))
	assert_string_contains(text, "불개 ♥♥♥♥")
	assert_string_contains(text, "소지품: 불 부적")


func test_the_hover_of_a_creature_keeps_its_state_lines() -> void:
	var w := Codex.stage()
	var hover := _text(Info.creature(w, FloorGen.spawn(w, &"dokkaebi", FAR)))
	for part in ["순찰 중", "당신을 볼 수 없다", "기습 피해: 3"]:
		assert_string_contains(hover, part)


func test_no_entry_tells_how_it_stands_now() -> void:
	var now := ["당신을 볼 수 있다", "당신을 볼 수 없다", "둔갑한 당신을 알아볼 수 없다", "기습 피해", "남은 둘러보기"]
	var light := ["어두움", "대숲 속:", "안 보임"]
	for tab in Codex.TABS.size():
		for e in Codex.entries(tab):
			var text := _text(Codex.detail(e))
			for part in now:
				assert_false(text.contains(part), "%s: %s" % [e.name, part])
			for part in [] if tab == 6 else light:
				assert_false(text.contains(part), "%s: %s" % [e.name, part])
			assert_false(tab != 6 and text.split("\n").has("밝음."), e.name)
			for state in Info.STATE + ["자는 중", "순찰 중", "돌아가는 중"]:
				assert_false(text.split("\n").has(state), "%s: %s" % [e.name, state])


func test_the_spells_are_the_forms_the_elements_and_the_shapes() -> void:
	var names := _names(1)
	for c in Cards.FORMS + Cards.ELEMENTS:
		assert_true(names.has(Cards.NAME[c] + " 부적"), c)
	for shape in [Spell.SHAPE_NAME[Spell.WISP], Spell.SHAPE_NAME[Spell.ORB], SpellInfo.SPRAY_NAME]:
		assert_true(names.has(shape), shape)
	var fire := _text(Codex.detail(_entry(1, "불 부적")))
	assert_eq(fire, _text(SpellInfo.stacked(Cards.FIRE)))


func test_a_shape_tells_its_talismans_and_its_numbers() -> void:
	var homing := _text(Codex.detail(_entry(2, "유도 구슬")))
	assert_string_contains(homing, "만드는 법: 여+구")
	assert_string_contains(homing, "가장 가까운 적")
	assert_string_contains(homing, "회전: 칸당 45°")
	assert_string_contains(_text(Codex.detail(_entry(1, "뿌리기"))), "모양: 투사체 없이")


func test_every_compound_is_listed_with_its_parts() -> void:
	var names := _names(2)
	assert_true(names.has(Spell.MORTAR_NAME), "a named combination lists there too")
	assert_true(names.has(Spell.SHAPE_NAME[Spell.HOMING]))
	for c in Cards.compounds():
		var text := _text(Codex.detail(_entry(2, Cards.NAME[c])))
		var parts: Array = Cards.spell_of(c).map(func(e): return Cards.part(e, Lang.t))
		assert_string_contains(text, " · %s\n" % "+".join(parts))
		assert_eq(text, _text(SpellInfo.combo(c)), c)
		var tails := "꼬리: %d" % Spell.price(parts.size())
		assert_eq(text.count(tails), 1, "one head line: " + text)
		var second: Array = ["자신에게:", "지속"] if Guise.ANYWHERE.has(c) else ["오행:", "모양:", "대상:"]
		assert_true(
			text.get_slice("\n", 1).split(" ")[0] in second,
			"the head line is followed by the shape, the target or the one it goes on"
		)


func test_the_leap_compound_is_listed_with_its_three_parts() -> void:
	var text := _text(Codex.detail(_entry(2, "도약")))
	assert_eq(text, _text(SpellInfo.combo(Cards.VAULT)))
	assert_string_contains(text.get_slice("\n", 0), "도약 · 꼬리: 3 · 물+나무+불")
	assert_eq(text.get_slice("\n", 1).split(" ")[0], "모양:")
	assert_string_contains(text, "모양: 곧게 3칸")


func test_the_items_are_the_elixir_the_peach_and_the_element_talismans() -> void:
	var names := _names(3)
	assert_true(names.has("영약") and names.has("복숭아"))
	for c in Cards.ELEMENTS:
		assert_true(names.has(Cards.NAME[c] + " 부적"), c)
	var w := Codex.stage()
	w.elixir = Codex.AT
	w.sense()
	assert_eq(_text(Codex.detail(_entry(3, "영약"))), _text(Info.terrain_facts(w, Codex.AT)))
	assert_string_contains(_text(Codex.detail(_entry(3, "복숭아"))), "최대 체력: +")


func test_the_hover_of_a_tile_is_its_facts_then_its_light() -> void:
	var w := Codex.stage()
	w.sense()
	var facts := Info.terrain_facts(w, Codex.AT)
	var hover := Info.terrain(w, Codex.AT)
	assert_eq(hover.slice(0, facts.size()), facts)
	assert_eq(hover.size(), facts.size() + 1)
	assert_string_contains(_text(hover.slice(facts.size())), "어두움")
	w.set_tile(Codex.AT, World.WALL)
	assert_eq(
		Info.terrain(w, Codex.AT), Info.terrain_facts(w, Codex.AT), "a wall has no light line"
	)


func test_every_named_tile_is_its_hover_facts() -> void:
	var names := _names(4)
	for t in Tiles.ROWS:
		var name: String = Tiles.of(t, "name")
		if name == "":
			continue
		assert_true(names.has(name), name)
		var w := Codex.stage()
		w.set_tile(Codex.AT, t)
		w.sense()
		var facts := _text(Info.terrain_facts(w, Codex.AT))
		var told := facts + ("\n" + _text(Info.jar_facts()) if t == World.JAR else "")
		assert_eq(_text(Codex.detail(_entry(4, name))), told, name)
		var hover := _text(Info.terrain(w, Codex.AT))
		assert_true(hover.begins_with(facts), name)


func test_the_terrain_also_lists_the_stairs_fire_hot_ground_gas_and_the_fallen() -> void:
	var names := _names(4)
	for name in ["계단", "불", "시체"]:
		assert_true(names.has(name), name)
	for spec in Compounds.HOT:
		assert_true(names.has(spec.name), spec.name)
	for kind in Gas.ROWS:
		assert_true(names.has(Gas.of(kind, "name")), str(kind))
	assert_string_contains(_text(Codex.detail(_entry(4, "불"))), "초당 피해:")
	assert_string_contains(_text(Codex.detail(_entry(4, "증기"))), "시야 막음")
	assert_string_contains(_text(Codex.detail(_entry(4, "시체"))), Info.TRACE)
	assert_string_contains(_text(Codex.detail(_entry(4, "뜨거운 땅"))), "초 남음")
	assert_string_contains(_text(Codex.detail(_entry(4, "계단"))), "꼬리: 모두 회복")


func test_a_gas_entry_tells_what_the_gas_is_not_how_much_of_it_lies_there() -> void:
	for kind in Gas.ROWS:
		var name: String = Gas.of(kind, "name")
		var text := _text(Codex.detail(_entry(4, name)))
		assert_false(text.contains("/%d" % Gas.MAX), name + " has no amount")
		if Gas.of(kind, "blocks"):
			assert_string_contains(text, "시야 막음: %d 이상" % Gas.OPAQUE)
		assert_string_contains(text, "감소")
		assert_false(text.contains("\n시야 막음."), name + " does not say it blocks sight now")


func test_a_mark_reads_as_the_hover_without_the_floors_name() -> void:
	for name in ["불", "증기", "시체", "뜨거운 쇠"]:
		var text := _text(Codex.detail(_entry(4, name)))
		assert_false(text.begins_with("바닥"), name)
		assert_false(text.is_empty(), name)
	assert_true(_text(Codex.detail(_entry(4, "증기"))).begins_with("증기\n"))
	var body := _text(Codex.detail(_entry(4, "시체")))
	assert_eq(body, "시체\n" + Info.TRACE)
	for kind in Codex.foes():
		assert_false(body.contains(Bestiary.info(kind).name), "a body names no creature")


func test_the_glossary_tells_each_shared_rule_once_by_its_tag() -> void:
	var tab := Codex.TABS.find("용어")
	var terms := Glossary.rows()
	assert_eq(_names(tab), terms.keys())
	for term: String in terms:
		assert_eq(_text(Codex.detail(_entry(tab, term))), term + ".\n" + "\n".join(terms[term]))
	var w := Codex.stage()
	w.set_tile(Codex.AT, World.BOARD)
	assert_true(_text(Info.terrain_facts(w, Codex.AT)).split("\n").has("가연성."))
	assert_false(
		_text(Info.terrain_facts(w, Codex.AT)).contains("재"), "the burn rule is not repeated"
	)
	w.set_tile(Codex.AT, World.TRAP_FIRE)
	assert_true(_text(Info.terrain_facts(w, Codex.AT)).split("\n").has("함정."))


func test_the_codex_key_is_slash_and_help_keeps_shift_slash() -> void:
	assert_eq(Keys.action_of(_press("Slash")), &"codex")
	assert_eq(Keys.action_of(_press("Shift+Slash")), &"help")
	assert_eq(Keys.ACTIONS[&"codex"][0], "도감")
	var help := Menu.new()
	help.open(&"help")
	var rows: Array = help.panel().rows
	assert_true(rows.any(func(r): return r[0][0] == "도감" and r[1][0] == "/"))


func test_esc_and_the_codex_key_close_it() -> void:
	var menu := _open()
	assert_eq(menu.key(_press("Escape")), &"close")
	assert_eq(menu.key(_press("Slash")), &"close")
	assert_eq(menu.key(_press("Enter")), &"", "Enter does nothing here")
	assert_eq(menu.use(), &"")
	assert_eq(menu.back(), &"close")


func test_left_and_right_change_the_tab_and_wrap() -> void:
	var menu := _open()
	menu.key(_press("Down"))
	assert_eq(menu.panel().tab, 0)
	assert_eq(menu.key(_press("Right")), &"")
	assert_eq(menu.panel().tab, 1)
	assert_eq(menu.panel().selected, 0, "a new tab starts at its first entry")
	menu.key(_press("Left"))
	menu.key(_press("Left"))
	assert_eq(menu.panel().tab, Codex.TABS.size() - 1, "Left from the first tab wraps")
	menu.key(_press("Right"))
	assert_eq(menu.panel().tab, 0)
	menu.key(_press("3"))
	assert_eq(menu.panel().tab, 2)
	menu.key(_press("7"))
	assert_eq(menu.panel().tab, Codex.TABS.size() - 1, "the last tab has a number key")


func test_the_detail_follows_the_selected_entry_and_the_status_tab_tells_each_status() -> void:
	var menu := _open()
	var first: Array = menu.panel().aside
	menu.key(_press("Down"))
	assert_eq(menu.panel().selected, 1)
	assert_ne(menu.panel().aside, first)

	var tab := Codex.TABS.find("상태이상")
	assert_eq(Codex.TABS[tab + 1], "용어")
	menu = _open()
	for i in tab:
		menu.key(_press("Right"))
	var panel := menu.panel()
	assert_eq(panel.tab, tab)
	var names: Array = panel.rows.map(func(r): return r[1][0])
	for key in Status.NAME:
		assert_has(names, Status.NAME[key])
		var text := _text(Codex.detail(_entry(tab, Status.NAME[key])))
		for does in SpellInfo.status_does(key):
			assert_string_contains(text, does)
	for word in ["묶임", "기절", "둔갑"]:
		assert_has(names, word)
	assert_string_contains(_text(Codex.detail(_entry(tab, "둔갑"))), Info._text(Info.NOT_FOOLED))
	assert_eq(panel.aside[0][0][0], names[0], "the detail opens on the first status")
	menu.key(_press("Down"))
	assert_eq(menu.panel().aside[0][0][0], names[1], "Down moves to the next status")
	menu.key(_press("Right"))
	assert_eq(menu.panel().tab, tab + 1)


func test_the_rows_show_a_glyph_and_a_name_and_the_detail_sits_to_the_right() -> void:
	var panel := _open().panel()
	assert_eq(panel.title, "도감")
	assert_eq(panel.rows.size(), Codex.foes().size())
	assert_eq(panel.rows[0][0][0], "도")
	assert_eq(panel.rows[0][0][1], Palette.KIND[&"dokkaebi"])
	assert_eq(panel.rows[0][1][0], "도깨비")
	assert_eq(panel.aside_x, Codex.SIDE_X)
	assert_string_contains(_text(panel.aside), "도깨비")


func test_the_page_is_opaque_and_draws_no_dim_text() -> void:
	var menu := _open()
	menu.codex.selected = Codex.foes().find(&"bulgae")
	var panel := menu.panel()
	assert_true(panel.opaque)
	for line in panel.aside:
		for run in line:
			assert_ne(run[1], Palette.DIM, run[0])


func test_the_detail_wraps_to_the_room_and_scrolls() -> void:
	var menu := Menu.new()
	menu.open(&"codex", Vector2i(30, 10))
	menu.codex.selected = Codex.foes().find(&"cheonnyeon")
	var width := 30 - Codex.SIDE_X - 1.0
	var panel := menu.panel()
	assert_eq(panel.aside.size(), 6, "the rows left under the title")
	assert_true(panel.aside_down)
	assert_false(panel.aside_up)
	for line in panel.aside:
		assert_lte(Term.text_cells(Info.plain([line]).replace("\n", "")), width)
	menu.key(_press("PageDown"))
	assert_true(menu.panel().aside_up)
	menu.key(_press("PageUp"))
	assert_false(menu.panel().aside_up)
	while menu.panel().aside_down:
		menu.key(_press("PageDown"))
	assert_eq(menu.panel().aside.size(), 6, "the scroll stops at the last line")
	assert_eq(menu.codex.selected, Codex.foes().find(&"cheonnyeon"), "and the entry stays")


func test_flow_breaks_after_a_space_and_inside_a_long_word() -> void:
	var c := Palette.TEXT
	var rows := Codex.flow([[["가나 다라 마바", c]]], 3.0)
	assert_eq(rows.map(func(r): return Info.plain([r])), ["가나", "다라", "마바"])
	rows = Codex.flow([[["가나다라마바사", c]]], 3.0)
	assert_eq(rows.map(func(r): return Info.plain([r])), ["가나다", "라마바", "사"])
	rows = Codex.flow([[["  가나", c], ["다", Palette.HURT]]], 3.0)
	assert_eq(rows.size(), 2)
	assert_eq(rows[0][0][0], "  가나", "an indent stays")
	assert_eq(Codex.flow([[]], 5.0), [[]], "an empty line stays a blank row")


## --- list conventions, by sending the events a player would ---


func _tap(key: String, echo := false) -> InputEventKey:
	var e := _press(key)
	e.echo = echo
	return e


## The page on a screen 30 cells wide and 10 high: 6 rows and 6 detail lines.
func _small() -> Menu:
	var menu := Menu.new()
	menu.open(&"codex", Vector2i(30, 10))
	return menu


func test_a_held_up_or_down_repeats() -> void:
	var menu := _open()
	for i in 3:
		menu.key(_tap("Down", i > 0))
	assert_eq(menu.panel().selected, 3, "echo events move like presses")
	menu.key(_tap("Up", true))
	assert_eq(menu.panel().selected, 2)


func test_echo_of_keys_that_must_not_repeat_does_nothing() -> void:
	var menu := _open()
	assert_eq(menu.key(_tap("Escape", true)), &"", "a held Esc does not close")
	assert_eq(menu.key(_tap("Slash", true)), &"")
	menu.key(_tap("3", true))
	assert_eq(menu.panel().tab, 0)
	menu.key(_tap("End", true))
	assert_eq(menu.panel().selected, 0)


func test_up_on_the_first_entry_goes_to_the_last_and_down_on_the_last_to_the_first() -> void:
	var menu := _small()
	var last := Codex.foes().size() - 1
	menu.key(_tap("Up"))
	assert_eq(menu.panel().selected, last)
	assert_eq(menu.panel().top, last - 5, "and the last entry is in view")
	menu.key(_tap("Down"))
	assert_eq(menu.panel().selected, 0)
	assert_eq(menu.panel().top, 0)


func test_page_down_and_page_up_move_a_page_stop_at_the_ends_and_repeat() -> void:
	var menu := Menu.new()
	menu.open(&"codex", Vector2i(80, 12))
	menu.key(_tap("5"))
	var fits := 8
	var last := Codex.entries(4).size() - 1
	assert_gt(last, 3 * fits, "a long list")
	assert_lte(menu.panel().aside.size(), fits)
	assert_false(menu.panel().aside_down, "the detail fits, so the page keys move the entry")
	menu.key(_tap("PageDown"))
	assert_eq(menu.panel().selected, fits)
	assert_eq(menu.panel().top, 1, "the page ends at the foot of the view")
	menu.key(_tap("PageUp", true))
	assert_eq(menu.panel().selected, 0)
	for i in 4 * last:
		menu.key(_tap("PageDown", true))
	assert_eq(menu.panel().selected, last, "stops at the last entry")
	for i in 4 * last:
		menu.key(_tap("PageUp", true))
	assert_eq(menu.panel().selected, 0, "stops at the first entry")


func test_home_and_end_go_to_the_first_and_last_entry() -> void:
	var menu := _small()
	var last := Codex.foes().size() - 1
	menu.key(_tap("End"))
	assert_eq(menu.panel().selected, last)
	assert_eq(menu.panel().top, last - 5)
	menu.key(_tap("Home"))
	assert_eq(menu.panel().selected, 0)
	assert_eq(menu.panel().top, 0)


func test_the_wheel_scrolls_the_list_without_moving_the_selection() -> void:
	var menu := _small()
	menu.wheel(1, false)
	assert_eq(menu.panel().top, ListNav.WHEEL)
	assert_eq(menu.panel().selected, 0, "the selection stays where it was")
	menu.wheel(-1, false)
	menu.wheel(-1, false)
	assert_eq(menu.panel().top, 0, "stops at the top")
	for i in Codex.foes().size():
		menu.wheel(1, false)
	assert_eq(menu.panel().top, Codex.foes().size() - 6, "stops with the last entry at the foot")


func test_the_wheel_over_the_detail_scrolls_the_detail() -> void:
	var menu := _small()
	menu.codex.selected = Codex.foes().find(&"cheonnyeon")
	menu.wheel(1, true)
	assert_true(menu.panel().aside_up)
	assert_eq(menu.panel().top, 0, "the list stays")
	menu.wheel(-1, true)
	assert_false(menu.panel().aside_up)
	for i in 40:
		menu.wheel(1, true)
	assert_false(menu.panel().aside_down, "stops at the last line")


func test_hovering_an_entry_lights_it_and_a_click_selects_it() -> void:
	var menu := _open()
	menu.point(4)
	assert_eq(menu.panel().hover, 4)
	assert_eq(menu.panel().selected, 0, "hovering does not select")
	assert_eq(menu.click(4, -1), &"", "a click on an entry only selects")
	assert_eq(menu.panel().selected, 4)
	menu.point(-1)
	assert_eq(menu.panel().hover, -1, "the light leaves with the pointer")


func test_tab_and_shift_tab_switch_the_tab_and_wrap() -> void:
	var menu := _open()
	menu.key(_tap("Tab"))
	assert_eq(menu.panel().tab, 1)
	menu.key(_tap("Shift+Tab"))
	menu.key(_tap("Shift+Tab"))
	assert_eq(menu.panel().tab, Codex.TABS.size() - 1)
	menu.key(_tap("Tab", true))
	assert_eq(menu.panel().tab, 0, "a held Tab repeats")


func test_a_click_on_a_tab_selects_it() -> void:
	var menu := _open()
	menu.key(_tap("Down"))
	menu.click(-1, 3)
	assert_eq(menu.panel().tab, 3)
	assert_eq(menu.panel().selected, 0)


func test_the_selected_entry_stays_in_view_as_it_moves_both_ways() -> void:
	var menu := _small()
	for nav in ["Down", "Up"]:
		for i in 20:
			menu.key(_tap(nav))
			var panel := menu.panel()
			assert_true(panel.selected >= panel.top and panel.selected < panel.top + 6, nav)


func test_the_selected_entry_is_in_view_after_the_wheel_moved_the_list_away() -> void:
	var menu := _small()
	for i in 3:
		menu.wheel(1, false)
	menu.key(_tap("Down"))
	assert_eq(menu.panel().selected, 1)
	assert_eq(menu.panel().top, 1, "the list scrolls back just enough")


func test_reopening_keeps_the_tab_and_the_entry() -> void:
	var menu := _open()
	menu.key(_tap("Right"))
	menu.key(_tap("Down"))
	menu.key(_tap("Down"))
	assert_eq(menu.key(_tap("Escape")), &"close")
	menu.open(&"codex")
	assert_eq(menu.panel().tab, 1)
	assert_eq(menu.panel().selected, 2)


func test_the_codex_opened_from_the_options_goes_back_to_them() -> void:
	var menu := Menu.new()
	menu.open(&"options")
	menu.selected = Menu.OPTIONS.find(&"codex")
	assert_eq(menu.use(), &"")
	assert_eq(menu.page, &"codex")
	assert_eq(menu.key(_tap("Escape")), &"", "Esc does not close the game menu")
	assert_eq(menu.page, &"options")
	assert_eq(menu.selected, Menu.OPTIONS.find(&"codex"))
	menu.use()
	assert_eq(menu.key(_tap("Slash")), &"")
	assert_eq(menu.page, &"options", "the codex key goes back too")
	menu.use()
	assert_eq(menu.back(), &"")
	assert_eq(menu.page, &"options")


func test_the_options_list_the_codex_between_the_language_and_the_keys() -> void:
	var at := Menu.OPTIONS.find(&"codex")
	assert_eq(Menu.OPTIONS[at - 1], &"language")
	assert_eq(Menu.OPTIONS[at + 1], &"keys")
	var menu := Menu.new()
	menu.open(&"options")
	assert_eq(menu.panel().rows[at][0][0], "도감")


func test_the_word_resistance_in_a_hover_opens_its_entry_that_tells_half_harm() -> void:
	assert_gte(Keywords.locate("내성").x, 0)
	assert_string_contains(_text(Codex.detail(_entry(6, "내성"))), "해당 주문에 피해를 절반만 입음")
