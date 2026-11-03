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
	m._open(&"codex")
	m.menu.codex.go(4)
	m.menu.codex.select(Codex.entries(4).find_custom(func(e): return e.name == "마루"))
	m.term.panel = m.menu.panel()
	var from: Array = [m.menu.codex.tab, m.menu.codex.selected]
	var at := _cell(m.term, "가연성")
	_click(m, _over(m, at.x, int(at.y)))
	var codex: Codex = m.menu.codex
	assert_eq(Vector2i(codex.tab, codex.selected), Keywords.locate("가연성"))
	assert_eq(Codex.entries(codex.tab)[codex.selected].name, "가연성")
	assert_eq(m.term.panel.rows[codex.selected][1][0], "가연성")
	var shown := PanelView.span(m.term)
	assert_true(codex.selected >= shown.x and codex.selected < shown.x + shown.y, "in view")
	_esc(m)
	assert_eq(m.overlay, &"codex", "back to the entry, not out")
	assert_eq([codex.tab, codex.selected], from)
	_esc(m)
	assert_eq(m.overlay, &"")


func test_a_word_inside_a_linked_entry_goes_on_and_esc_goes_back_one_entry_at_a_time() -> void:
	var m := _game()
	m._open(&"codex")
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
	assert_eq(m.overlay, &"codex")
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), Keywords.locate("진흙"))
	assert_eq(m.world.round_no, rounds)
	assert_eq(m.run.actions.size(), actions, "nothing is saved to replay")
	assert_eq(m.world.player().pos, me)
	_esc(m)
	assert_eq(m.overlay, &"", "Esc goes back to play")
	assert_false(m.busy)


func test_a_click_on_a_word_of_the_log_page_opens_it_and_esc_returns_to_the_page() -> void:
	var m := _game()
	m.messages.add_text("진흙이 깔렸다", 0)
	m._open(&"log")
	var at := _cell(m.term, "진흙")
	_click(m, _over(m, at.x, int(at.y)))
	assert_eq(m.menu.page, &"codex")
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), Keywords.locate("진흙"))
	_esc(m)
	assert_eq(m.menu.page, &"log")
	assert_eq(m.overlay, &"log")


func test_a_click_on_a_row_of_a_page_with_no_words_still_acts_on_the_row() -> void:
	var m := _game()
	m._open(&"options")
	_click(m, _over(m, 3.0, 4))
	assert_eq(m.menu.selected, 1)


func test_a_tap_on_a_word_of_the_log_links_as_a_click_does() -> void:
	var m := _main()
	m.term.banner_lines.clear()
	m.term.log_lines = [[[["진흙", Palette.TEXT]], 1.0]]
	var rounds: int = m.world.round_no
	_finger(m, _screen(m, Vector2(m.term.side.x + 0.5 + 1.0, 0.5) * Term.CELL))
	assert_eq(m.overlay, &"codex")
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), Keywords.locate("진흙"))
	assert_eq(m.world.round_no, rounds)


func test_a_tap_on_a_word_of_a_detail_links_as_a_click_does() -> void:
	var m := _main()
	m._open(&"codex")
	m.menu.codex.go(4)
	m.menu.codex.select(Codex.entries(4).find_custom(func(e): return e.name == "마루"))
	m.term.panel = m.menu.panel()
	var at := _cell(m.term, "가연성")
	_finger(m, _screen(m, (at + Vector2(0.5, 0.5)) * Term.CELL))
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), Keywords.locate("가연성"))


func test_the_entry_a_page_shows_is_not_a_word_of_its_own_title() -> void:
	var m := _game()
	m._open(&"codex")
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
	m._open(&"codex")
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
	assert_eq(m.overlay, &"codex")
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
	assert_eq(m.overlay, &"")
	m._open(&"codex")
	assert_true(m.menu.codex.ahead.is_empty())


func test_the_side_buttons_do_nothing_on_another_page() -> void:
	var m := _game()
	m._open(&"help")
	_click(m, Vector2.ZERO, MOUSE_BUTTON_XBUTTON1)
	assert_eq(m.overlay, &"help")
