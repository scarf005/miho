extends TouchBase
## A name that has an entry in the 도감 gives it in a box under the pointer and,
## on a click or a tap, opens it in its own tab.


func after_each() -> void:
	get_tree().root.size = Vector2i(1280, 720)


func _game() -> Node:
	var m := _main(false)
	m.glass.visible = false
	m.term.banner_lines.clear()
	return m


## The screen point over character `at` of the text drawn from cell `x`, `y`.
func _over(m: Node, x: float, y: int) -> Vector2:
	return _screen(m, Vector2(x + 0.5, y + 0.5) * Term.CELL)


## The cell where the term draws `word`, found by pointing at each cell.
func _cell(t: Term, word: String) -> Vector2:
	for y in t.rows:
		for x in t.cols:
			if WordHover.word_at(t, (Vector2(x, y) + Vector2(0.5, 0.5)) * Term.CELL) == word:
				return Vector2(x, y)
	fail_test("%s is not on the screen" % word)
	return Vector2.ZERO


func _click(m: Node, at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = at
	m._unhandled_input(e)


func _esc(m: Node) -> void:
	var e := Keys.event("Escape")
	e.pressed = true
	m._unhandled_input(e)


func test_a_click_on_a_word_of_the_detail_opens_its_entry_and_esc_goes_back() -> void:
	var m := _game()
	m.panels.open(&"codex")
	m.menu.codex.go(4)
	m.menu.codex.select(Codex.entries(4).find_custom(func(e): return e.name == "마루"))
	m.term.panel = m.menu.panel()
	var from: Array = [m.menu.codex.tab, m.menu.codex.selected]
	var at := _cell(m.term, "가연성")
	_click(m, _over(m, at.x, int(at.y)))
	var codex: Codex = m.menu.codex
	assert_eq(Vector2i(codex.tab, codex.selected), Keywords.locate("가연성"))
	assert_eq(Codex.entries(codex.tab)[codex.selected].name, "가연성")
	assert_eq(m.term.panel.rows[codex.selected].back()[0], "가연성")
	var shown := PanelView.span(m.term)
	assert_true(codex.selected >= shown.x and codex.selected < shown.x + shown.y, "in view")
	_esc(m)
	assert_eq(m.panels.overlay, &"codex", "back to the entry, not out")
	assert_eq([codex.tab, codex.selected], from)
	_esc(m)
	assert_eq(m.panels.overlay, &"")


func test_a_word_inside_a_linked_entry_goes_on_and_esc_goes_back_one_entry_at_a_time() -> void:
	var m := _game()
	m.panels.open(&"codex")
	m.menu.codex.go(4)
	m.menu.codex.select(Codex.entries(4).find_custom(func(e): return e.name == "마루"))
	m.term.panel = m.menu.panel()
	var first := Vector2i(4, m.menu.codex.selected)
	var at := _cell(m.term, "가연성")
	_click(m, _over(m, at.x, int(at.y)))
	var second := Vector2i(m.menu.codex.tab, m.menu.codex.selected)
	var found := _cell_any(m.term)
	assert_ne(found, Vector2(-1, -1), "the entry names another")
	_click(m, _over(m, found.x, int(found.y)))
	assert_ne(Vector2i(m.menu.codex.tab, m.menu.codex.selected), second)
	_esc(m)
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), second)
	_esc(m)
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), first)


## A cell on a word of the screen, or (-1, -1).
func _cell_any(t: Term) -> Vector2:
	for y in t.rows:
		for x in t.cols:
			if WordHover.word_at(t, (Vector2(x, y) + Vector2(0.5, 0.5)) * Term.CELL) != "":
				return Vector2(x, y)
	return Vector2(-1, -1)


func test_a_click_on_a_word_of_the_log_over_the_map_opens_it_and_plays_no_round() -> void:
	var m := _game()
	m.term.log_lines = [[[["바닥이 ", Palette.TEXT], ["진흙", Palette.TEXT], ["이다", Palette.TEXT]], 1.0]]
	var rounds: int = m.world.round_no
	var actions: int = m.run.actions.size()
	var me: Vector2i = m.world.player().pos
	var col := Term.MAP.x + 0.5 + Term.text_cells("바닥이 ") + 0.5
	_click(m, _over(m, col, 0))
	assert_eq(m.panels.overlay, &"codex")
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), Keywords.locate("진흙"))
	assert_eq(m.world.round_no, rounds)
	assert_eq(m.run.actions.size(), actions, "nothing is saved to replay")
	assert_eq(m.world.player().pos, me)
	_esc(m)
	assert_eq(m.panels.overlay, &"", "Esc goes back to play")
	assert_false(m.busy)


func test_a_click_on_a_word_of_the_log_page_opens_it_and_esc_returns_to_the_page() -> void:
	var m := _game()
	m.messages.add_text("진흙이 깔렸다", 0)
	m.panels.open(&"log")
	var at := _cell(m.term, "진흙")
	_click(m, _over(m, at.x, int(at.y)))
	assert_eq(m.menu.page, &"codex")
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), Keywords.locate("진흙"))
	_esc(m)
	assert_eq(m.menu.page, &"log")
	assert_eq(m.panels.overlay, &"log")


func test_a_click_on_a_row_of_a_page_with_no_words_still_acts_on_the_row() -> void:
	var m := _game()
	m.panels.open(&"options")
	_click(m, _over(m, 3.0, 4))
	assert_eq(m.menu.selected, 1)


func test_a_tap_on_a_word_of_the_log_links_as_a_click_does() -> void:
	var m := _main()
	m.term.banner_lines.clear()
	m.term.log_lines = [[[["진흙", Palette.TEXT]], 1.0]]
	var rounds: int = m.world.round_no
	_finger(m, _screen(m, Vector2(m.term.side.x + 0.5 + 1.0, 0.5) * Term.CELL))
	assert_eq(m.panels.overlay, &"codex")
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), Keywords.locate("진흙"))
	assert_eq(m.world.round_no, rounds)


func test_a_tap_on_a_word_of_a_detail_links_as_a_click_does() -> void:
	var m := _main()
	m.panels.open(&"codex")
	m.menu.codex.go(4)
	m.menu.codex.select(Codex.entries(4).find_custom(func(e): return e.name == "마루"))
	m.term.panel = m.menu.panel()
	var at := _cell(m.term, "가연성")
	_finger(m, _screen(m, (at + Vector2(0.5, 0.5)) * Term.CELL))
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), Keywords.locate("가연성"))


func test_the_entry_a_page_shows_is_not_a_word_of_its_own_title() -> void:
	var m := _game()
	m.panels.open(&"codex")
	m.menu.codex.go(6)
	m.menu.codex.select(Codex.entries(6).find_custom(func(e): return e.name == "소음"))
	m.term.panel = m.menu.panel()
	var own := Keywords.locate("소음")
	for y in m.term.rows:
		for x in m.term.cols:
			var word := WordHover.word_at(m.term, (Vector2(x, y) + Vector2(0.5, 0.5)) * Term.CELL)
			if word != "":
				assert_ne(Keywords.locate(word), own, word)


func _linked(m: Node) -> Array:
	m.panels.open(&"codex")
	m.menu.codex.go(4)
	m.menu.codex.select(Codex.entries(4).find_custom(func(e): return e.name == "마루"))
	m.term.panel = m.menu.panel()
	var from: Array = [m.menu.codex.tab, m.menu.codex.selected]
	var at := _cell(m.term, "가연성")
	_click(m, _over(m, at.x, int(at.y)))
	return from


func _press(m: Node, keys: String) -> void:
	var e := Keys.event(keys)
	e.pressed = true
	m._unhandled_input(e)


func _place(m: Node) -> Array:
	return [m.menu.codex.tab, m.menu.codex.selected]


func test_alt_and_the_arrows_go_back_and_forward_along_the_links_and_change_no_tab() -> void:
	var m := _game()
	var from := _linked(m)
	var there := _place(m)
	_press(m, "Alt+Left")
	assert_eq(_place(m), from)
	assert_eq(m.panels.overlay, &"codex")
	_press(m, "Alt+Right")
	assert_eq(_place(m), there)
	_press(m, "Alt+Right")
	assert_eq(_place(m), there, "nothing further on")


func test_the_side_buttons_of_a_mouse_go_back_and_forward_along_the_links() -> void:
	var m := _game()
	var from := _linked(m)
	var there := _place(m)
	_click(m, Vector2.ZERO, MOUSE_BUTTON_XBUTTON1)
	assert_eq(_place(m), from)
	_click(m, Vector2.ZERO, MOUSE_BUTTON_XBUTTON2)
	assert_eq(_place(m), there)


func test_esc_goes_back_so_that_forward_can_return() -> void:
	var m := _game()
	_linked(m)
	var there := _place(m)
	_esc(m)
	_press(m, "Alt+Right")
	assert_eq(_place(m), there)


func test_following_a_new_link_forgets_what_lay_ahead() -> void:
	var m := _game()
	var from := _linked(m)
	_press(m, "Alt+Left")
	var at := _cell(m.term, "가연성")
	_click(m, _over(m, at.x, int(at.y)))
	var there := _place(m)
	_press(m, "Alt+Left")
	assert_eq(_place(m), from)
	assert_eq(m.menu.codex.ahead.size(), 1, "only the last entry")
	_press(m, "Alt+Right")
	assert_eq(_place(m), there)


func test_back_with_no_link_left_closes_the_codex_as_esc_does_and_opening_forgets_forward() -> void:
	var m := _game()
	_linked(m)
	_press(m, "Alt+Left")
	_press(m, "Alt+Left")
	assert_eq(m.panels.overlay, &"")
	m.panels.open(&"codex")
	assert_true(m.menu.codex.ahead.is_empty())


func test_the_side_buttons_do_nothing_on_another_page() -> void:
	var m := _game()
	m.panels.open(&"help")
	_click(m, Vector2.ZERO, MOUSE_BUTTON_XBUTTON1)
	assert_eq(m.panels.overlay, &"help")


func _foe_detail(m: Node, kind: StringName, rank: int) -> void:
	m.panels.open(&"codex")
	m.menu.codex.go(0)
	m.menu.codex.rank = rank
	m.menu.codex.select(Codex.foes().find(kind))
	m.term.panel = m.menu.panel()


func test_a_spell_of_a_creature_shows_its_recipe_and_a_click_opens_it_at_that_recipe() -> void:
	var m := _game()
	var cards := [Cards.ORB, Cards.ORB, Cards.ORB, Cards.ORB, Cards.WATER]
	_foe_detail(m, &"haetae", Bestiary.RANKS)
	var recipe := SpellInfo.recipe_text(cards)
	var at := _cell(m.term, SpellInfo.spell_word(cards))
	var local := (at + Vector2(0.5, 0.5)) * Term.CELL
	assert_string_contains(Info.plain(WordHover.at(m.term, local)), recipe)
	_click(m, _over(m, at.x, int(at.y)))
	var codex: Codex = m.menu.codex
	var entry: Dictionary = Codex.entries(codex.tab)[codex.selected]
	assert_eq(entry.name, Bestiary.spell(&"haetae", cards).shot_shown())
	assert_string_contains(Info.plain(Codex.detail(entry, codex.part)), recipe)
	_esc(m)
	assert_eq(codex.tab, 0, "Esc goes back to the creature")


func test_a_spell_named_as_a_gas_still_shows_its_recipe() -> void:
	var m := _game()
	var cards := [Cards.WATER, Cards.FIRE]
	_foe_detail(m, &"cheonnyeon", Bestiary.RANKS)
	var at := _cell(m.term, SpellInfo.spell_word(cards))
	var local := (at + Vector2(0.5, 0.5)) * Term.CELL
	assert_string_contains(Info.plain(WordHover.at(m.term, local)), SpellInfo.recipe_text(cards))
	_click(m, _over(m, at.x, int(at.y)))
	var codex: Codex = m.menu.codex
	assert_eq(codex.tab, 2, "the spell, not the gas of its name")
	assert_eq(Codex.entries(2)[codex.selected].name, Bestiary.spell(&"cheonnyeon", cards).shown())


func test_a_box_shift_keeps_gives_the_recipe_of_the_spell_in_it() -> void:
	var m := _game()
	var w: World = m.world
	var foe := FloorGen.spawn(w, &"jiha", w.player().pos + Vector2i(1, 0))
	foe.rank = 1
	w.sense()
	m.term.show_world(w)
	m.forecast()
	m.look.hover = foe.pos
	m.refresh()
	WordHover.hold(m, true)
	assert_false(m.term.pin.is_empty())
	var cards: Array = Bestiary.casts(&"jiha", 1)[0]
	var recipe := SpellInfo.recipe_text(cards)
	var at := _cell(m.term, SpellInfo.spell_word(cards))
	var word := WordHover.at(m.term, (at + Vector2(0.5, 0.5)) * Term.CELL)
	assert_string_contains(Info.plain(word), recipe)


func test_the_spell_a_creature_charges_in_the_sidebar_is_a_word() -> void:
	var m := _game()
	var w: World = m.world
	var cards := [Cards.FOX, Cards.METAL]
	var foe := FloorGen.spawn(w, &"jiha", w.player().pos + Vector2i(1, 0))
	foe.magic.intent.assign([{cards = cards, dir = Vector2i.LEFT}])
	w.sense()
	m.term.show_world(w)
	m.forecast()
	var recipe := SpellInfo.recipe_text(cards)
	var at := _cell(m.term, SpellInfo.spell_word(cards))
	assert_true(at.x < m.term.side.x, "in the sidebar")
	assert_string_contains(
		Info.plain(WordHover.at(m.term, (at + Vector2(0.5, 0.5)) * Term.CELL)), recipe
	)
	var rounds: int = w.round_no
	_click(m, _over(m, at.x, int(at.y)))
	assert_eq(m.panels.overlay, &"codex")
	assert_eq(w.round_no, rounds)


func test_every_spell_of_every_creature_has_an_entry_that_tells_its_recipe() -> void:
	for kind: StringName in Codex.foes():
		for rank in Bestiary.RANKS:
			for cards: Array in Bestiary.casts(kind, rank + 1):
				var word := SpellInfo.spell_word(cards)
				var what := "%s %s" % [kind, word]
				assert_ne(Keywords.locate(word).x, -1, what)
				var head := Info.plain(Keywords.entry(word)).split("\n")[0]
				for c: StringName in cards:
					assert_string_contains(head, Cards.part(c, Lang.t), what)


func test_a_title_with_a_count_is_a_word_for_that_recipe() -> void:
	var cards := [Cards.ORB, Cards.ORB, Cards.ORB, Cards.ORB, Cards.WATER]
	var title := Bestiary.spell(&"haetae", cards).shown()
	var text := Keywords.word_at([["해태가 %s을 던졌다" % title, Palette.TEXT]], 0.0, 5.0)
	assert_eq(text, title)
	assert_string_contains(Info.plain(Keywords.entry(title)), SpellInfo.recipe_text(cards))


func test_a_talisman_in_a_recipe_or_a_line_is_a_word_for_its_entry() -> void:
	for c: StringName in Cards.FORMS + Cards.ELEMENTS:
		var part := Cards.part(c, Lang.t)
		assert_eq(Keywords.locate(part), Keywords.locate(Codex.talisman_name(c)), part)
		assert_string_contains(Info.plain(Keywords.entry(part)), Codex.talisman_name(c))
	assert_eq(Keywords.word_at([["구+불", Palette.TEXT]], 0.0, 0.2), Cards.part(Cards.ORB, Lang.t))
	assert_eq(Keywords.word_at([["구+불", Palette.TEXT]], 0.0, 1.8), Cards.part(Cards.FIRE, Lang.t))


func test_a_click_on_a_word_of_a_creature_card_aims_while_talismans_are_picked() -> void:
	var m := _game()
	var w: World = m.world
	var cards := [Cards.FOX, Cards.METAL]
	var foe := FloorGen.spawn(w, &"jiha", w.player().pos + Vector2i(1, 0))
	foe.magic.intent.assign([{cards = cards, dir = Vector2i.LEFT}])
	w.sense()
	m.term.show_world(w)
	m.forecast()
	m.casting.add(Cards.FOX)
	var at := _cell(m.term, SpellInfo.spell_word(cards))
	_click(m, _over(m, at.x, int(at.y)))
	assert_eq(m.panels.overlay, &"", "no 도감 over the aim")
