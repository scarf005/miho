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


func test_the_foes_are_every_bestiary_kind_but_miho() -> void:
	var names := _names(0)
	assert_eq(names.size(), Bestiary.KINDS.size() - 1)
	for kind in Bestiary.KINDS:
		assert_eq(names.has(Bestiary.info(kind).name), kind != &"miho", kind)


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
		var rest := facts.filter(func(l): return _text([l]).begins_with("발톱"))
		_assert_within(facts.filter(func(l): return not rest.has(l)), hover, kind)
		assert_eq(rest.size(), 1, "the claw harm is told as a fact")
	var text := _text(Codex.detail(_entry(0, "불개")))
	assert_string_contains(text, "불개 ♥♥♥♥")
	assert_string_contains(text, "발톱: 피해 1, 기습 시 3")
	assert_string_contains(text, "처치 시 불 부적")


func test_the_hover_of_a_creature_keeps_its_state_lines() -> void:
	var w := Codex.stage()
	var hover := _text(Info.creature(w, FloorGen.spawn(w, &"dokkaebi", FAR)))
	for part in ["순찰 중", "당신을 볼 수 없다", "기습 시 피해 3"]:
		assert_string_contains(hover, part)


func test_no_entry_tells_how_it_stands_now() -> void:
	var now := ["당신을 볼", "당신을 보고", "기습 시 피해", "초 뒤 쉰다"]
	var light := ["어둡다", "밝다. 멀리", "대숲 속. 바로", "누가 있는지", "지금은 보이지 않는다"]
	for tab in Codex.TABS.size():
		for e in Codex.entries(tab):
			var text := _text(Codex.detail(e))
			for part in now + light:
				assert_false(text.contains(part), "%s: %s" % [e.name, part])
			for state in Info.STATE + ["자는 중", "순찰 중", "돌아가는 중", "도망치는 중"]:
				assert_false(text.split("\n").has(state), "%s: %s" % [e.name, state])


func test_the_spells_are_the_forms_the_elements_and_the_shapes() -> void:
	var names := _names(1)
	for c in Cards.FORMS + Cards.ELEMENTS:
		assert_true(names.has(Cards.NAME[c] + " 부적"), c)
	for shape in Spell.SHAPE_NAME.values() + [SpellInfo.SPRAY_NAME]:
		assert_true(names.has(shape), shape)
	var fire := _text(Codex.detail(_entry(1, "불 부적")))
	assert_eq(fire, _text(SpellInfo.card(Cards.FIRE, null)))


func test_a_shape_tells_its_talismans_and_its_numbers() -> void:
	var homing := _text(Codex.detail(_entry(1, "유도 구슬")))
	assert_string_contains(homing, "만드는 법 여 구")
	assert_string_contains(homing, "가장 가까운 적")
	assert_string_contains(homing, "꺾임 한 칸에 45°")
	assert_string_contains(_text(Codex.detail(_entry(1, "뿌리기"))), "투사체 없이")


func test_every_compound_is_listed_with_its_two_parts() -> void:
	var names := _names(2)
	assert_eq(names.size(), Cards.PAIRS.size() + Cards.TRIPLES.size())
	for c in Cards.PAIRS:
		var text := _text(Codex.detail(_entry(2, Cards.NAME[c])))
		var parts: Array = Cards.PAIRS[c]
		assert_string_contains(text, "(%s+%s)" % [Cards.NAME[parts[0]], Cards.NAME[parts[1]]])
		assert_eq(text, _text(SpellInfo.combo(c)), c)
		assert_eq(text.count("꼬리 2개"), 1, "one head line: " + text)
		assert_eq(
			text.get_slice("\n", 1).split(" ")[0], "모양", "the head line is followed by the shape"
		)


func test_the_leap_compound_is_listed_with_its_three_parts() -> void:
	var text := _text(Codex.detail(_entry(2, "도약")))
	assert_eq(text, _text(SpellInfo.combo(Cards.VAULT)))
	assert_string_contains(text.get_slice("\n", 0), "도약 꼬리 3개 (물+나무+불)")
	assert_eq(text.get_slice("\n", 1).split(" ")[0], "모양")
	assert_string_contains(text, "곧게 3칸.")


func test_the_items_are_the_elixir_the_peach_and_the_element_talismans() -> void:
	var names := _names(3)
	assert_true(names.has("영약") and names.has("복숭아"))
	for c in Cards.ELEMENTS:
		assert_true(names.has(Cards.NAME[c] + " 부적"), c)
	var w := Codex.stage()
	w.elixir = Codex.AT
	w.sense()
	assert_eq(_text(Codex.detail(_entry(3, "영약"))), _text(Info.terrain_facts(w, Codex.AT)))
	assert_string_contains(_text(Codex.detail(_entry(3, "복숭아"))), "최대 체력 +")


func test_the_hover_of_a_tile_is_its_facts_then_its_light() -> void:
	var w := Codex.stage()
	w.sense()
	var facts := Info.terrain_facts(w, Codex.AT)
	var hover := Info.terrain(w, Codex.AT)
	assert_eq(hover.slice(0, facts.size()), facts)
	assert_eq(hover.size(), facts.size() + 1)
	assert_string_contains(_text(hover.slice(facts.size())), "어둡다")
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
		assert_eq(_text(Codex.detail(_entry(4, name))), facts, name)
		var hover := _text(Info.terrain(w, Codex.AT))
		assert_true(hover.begins_with(facts), name)


func test_the_terrain_also_lists_the_stairs_fire_hot_ground_gas_and_the_fallen() -> void:
	var names := _names(4)
	for name in ["계단", "불타는 칸", "쓰러진 몸"]:
		assert_true(names.has(name), name)
	for spec in Compounds.HOT:
		assert_true(names.has(spec.name), spec.name)
	for kind in Gas.ROWS:
		assert_true(names.has(Gas.of(kind, "name")), str(kind))
	assert_string_contains(_text(Codex.detail(_entry(4, "불타는 칸"))), "서 있으면 매 초 피해")
	assert_string_contains(_text(Codex.detail(_entry(4, "증기"))), "시야를 막는다")
	assert_string_contains(_text(Codex.detail(_entry(4, "쓰러진 몸"))), "이 층에 남는다")
	assert_string_contains(_text(Codex.detail(_entry(4, "뜨거운 땅"))), "초 뒤 식는다")
	assert_string_contains(_text(Codex.detail(_entry(4, "계단"))), "위층으로 올라간다")


func test_a_gas_entry_tells_what_the_gas_is_not_how_much_of_it_lies_there() -> void:
	for kind in Gas.ROWS:
		var name: String = Gas.of(kind, "name")
		var text := _text(Codex.detail(_entry(4, name)))
		assert_false(text.contains("/%d" % Gas.MAX), name + " has no amount")
		assert_string_contains(text, "%d 이상 모이면 시야를 막는다" % Gas.OPAQUE)
		assert_string_contains(text, "줄어든다")
		assert_false(text.contains("\n시야를 막는다"), name + " does not say it blocks sight now")


func test_a_mark_reads_as_the_hover_without_the_floors_name() -> void:
	for name in ["불타는 칸", "증기", "쓰러진 몸", "뜨거운 쇠"]:
		var text := _text(Codex.detail(_entry(4, name)))
		assert_false(text.begins_with("바닥"), name)
		assert_false(text.is_empty(), name)
	assert_true(_text(Codex.detail(_entry(4, "증기"))).begins_with("증기\n"))
	var body := _text(Codex.detail(_entry(4, "쓰러진 몸")))
	assert_eq(body, "쓰러진 몸\n" + Info.BODY_RULE)
	for kind in Codex.foes():
		assert_false(body.contains(Bestiary.info(kind).name), "a body names no creature")


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
	assert_eq(menu.panel().tab, 2, "a number past the last tab does nothing")


func test_up_and_down_stop_at_the_ends_and_the_detail_follows() -> void:
	var menu := _open()
	menu.key(_press("Up"))
	assert_eq(menu.panel().selected, 0)
	var first: Array = menu.panel().aside
	menu.key(_press("Down"))
	assert_eq(menu.panel().selected, 1)
	assert_ne(menu.panel().aside, first)
	for i in 30:
		menu.key(_press("Down"))
	assert_eq(menu.panel().selected, Codex.foes().size() - 1)
	menu.point(2)
	assert_eq(menu.panel().selected, 2, "the pointer picks a row")


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
		assert_lte(Term._cells(Info.plain([line]).replace("\n", "")), width)
	menu.key(_press("PageDown"))
	assert_true(menu.panel().aside_up)
	menu.key(_press("PageUp"))
	assert_false(menu.panel().aside_up)
	for i in 20:
		menu.key(_press("PageDown"))
	assert_false(menu.panel().aside_down, "the scroll stops at the last line")
	assert_eq(menu.panel().aside.size(), 6)


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


func test_a_new_page_opens_at_the_first_tab() -> void:
	var menu := _open()
	menu.key(_press("Right"))
	menu.open(&"codex")
	assert_eq(menu.panel().tab, 0)
	assert_eq(menu.panel().selected, 0)
