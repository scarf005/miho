extends TouchBase
## Shift keeps the hover box that is open where it is, and a word in it works as a
## word anywhere: the pointer over it shows its entry and a click opens it.


func after_each() -> void:
	get_tree().root.size = Vector2i(1280, 720)


## A game scene with a creature three tiles east of Miho and the pointer on it.
func _foe_hover(touch := false) -> Node:
	var m := _main(touch)
	m.glass.visible = false
	m.term.banner_lines.clear()
	var at := _me(m) + Vector2i(3, 0)
	FloorGen.spawn(m.world, &"jangseung", at).magic.cooldown = 99
	m.world.sense()
	m.term.show_world(m.world)
	m._forecast()
	if not touch:
		m._point(_tile_at(m, at))
	return m


func _shift(m: Node, down: bool) -> void:
	var e := Keys.event("Shift")
	e.pressed = down
	m._unhandled_input(e)


## The screen point over the first word of the kept box that has an entry.
func _word(m: Node) -> Vector2:
	for y in m.term.rows:
		for x in m.term.cols:
			var local := (Vector2(x, y) + Vector2(0.5, 0.5)) * Term.CELL
			if WordHover.word_at(m.term, local) != "":
				return _screen(m, local)
	fail_test("no word in the box")
	return Vector2.ZERO


func _click(m: Node, at: Vector2, shift := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	e.shift_pressed = shift
	m._unhandled_input(e)


func test_the_box_stays_as_it_was_while_the_pointer_crosses_other_things() -> void:
	var m := _foe_hover()
	var lines: Array = m.term.info.duplicate(true)
	assert_false(lines.is_empty(), "the creature shows a box")
	_shift(m, true)
	assert_eq(m.term.pin.lines, lines)
	for tile: Vector2i in [_me(m), _me(m) + Vector2i(0, 2), Vector2i(-1, -1)]:
		m._point(_tile_at(m, tile) if Grid.inside(tile) else Vector2(-1.0e5, -1.0e5))
		assert_eq(m.term.pin.lines, lines)
		assert_eq(m.term.info, lines, "no box for the thing crossed")
	assert_eq(m.hover, Vector2i(-1, -1), "what is under the pointer is still followed")


func test_letting_go_of_shift_drops_the_box_and_shows_what_is_under_the_pointer() -> void:
	var m := _foe_hover()
	var foe := _me(m) + Vector2i(3, 0)
	_shift(m, true)
	m._point(_tile_at(m, _me(m)))
	_shift(m, false)
	assert_true(m.term.pin.is_empty())
	m._point(_tile_at(m, foe))
	assert_false(m.term.info.is_empty(), "the box of the tile under the pointer")
	assert_eq(m.term.cursor, foe)


func test_a_word_in_the_kept_box_shows_its_entry_and_a_click_opens_it_without_a_round() -> void:
	var m := _foe_hover()
	_shift(m, true)
	var at := _word(m)
	var word: String = WordHover.word_at(m.term, m._local(at))
	m._point(at)
	assert_eq(m.term.hint, Keywords.entry(word), "a second box beside the word")
	assert_false(m.term.pin.is_empty(), "the kept box stays")
	var rounds: int = m.world.round_no
	var actions: int = m.run.actions.size()
	var me := _me(m)
	_click(m, at, true)
	assert_eq(m.overlay, &"codex")
	assert_eq(Vector2i(m.menu.codex.tab, m.menu.codex.selected), Keywords.locate(word))
	assert_eq(m.world.round_no, rounds)
	assert_eq(m.run.actions.size(), actions, "nothing is saved to replay")
	assert_eq(_me(m), me)
	var esc := Keys.event("Escape")
	esc.pressed = true
	m._unhandled_input(esc)
	assert_eq(m.overlay, &"", "Esc comes back to the map")


func test_a_click_inside_the_kept_box_on_no_word_does_not_walk_to_the_tile_under_it() -> void:
	var m := _foe_hover()
	_shift(m, true)
	var fit: Dictionary = m.term.pin.fit
	var corner := _screen(m, (fit.at + Vector2(0.1, 0.1)) * Term.CELL)
	assert_eq(WordHover.word_at(m.term, m._local(corner)), "")
	var rounds: int = m.world.round_no
	_click(m, corner, true)
	assert_eq(m.world.round_no, rounds)
	assert_false(m.term.pin.is_empty())


func test_a_shift_click_off_the_box_still_acts_on_the_tile_under_the_pointer() -> void:
	var m := _foe_hover()
	_shift(m, true)
	var fit: Dictionary = m.term.pin.fit
	var box := Rect2(fit.at, fit.cells * fit.scale)
	var tile := Vector2i(-1, -1)
	for y in Grid.H:
		for x in Grid.W:
			var cell: Vector2 = m.term.cell_centre(Vector2i(x, y)) / Term.CELL
			var far := Grid.inside(tile) and tile.x < x
			if Grid.cheb(Vector2i(x, y), _me(m)) == 1 and not box.has_point(cell) and not far:
				tile = Vector2i(x, y)
	assert_true(Grid.inside(tile), "a tile beside Miho clear of the box")
	var from := _me(m)
	m._point(_tile_at(m, tile))
	_click(m, _tile_at(m, tile), true)
	await _settle(m)
	assert_eq(_me(m), tile, "walked, as a click does")
	assert_ne(_me(m), from)
	assert_true(m.term.pin.is_empty())


func test_shift_with_a_direction_still_plays_its_round_and_ends_the_kept_box() -> void:
	var m := _foe_hover()
	_shift(m, true)
	var rounds: int = m.world.round_no
	var key := Keys.event("Shift+Left")
	key.pressed = true
	m._unhandled_input(key)
	await _settle(m)
	assert_eq(m.world.round_no, rounds + 1)
	assert_true(m.term.pin.is_empty())


func test_holding_shift_over_nothing_keeps_nothing_and_plays_no_round() -> void:
	var m := _main(false)
	var rounds: int = m.world.round_no
	_shift(m, true)
	assert_true(m.term.pin.is_empty())
	_shift(m, false)
	assert_eq(m.world.round_no, rounds)


func test_a_tap_on_a_word_in_the_box_a_hold_keeps_opens_that_entry() -> void:
	var m := _foe_hover(true)
	_hold(m, _tile_at(m, _me(m) + Vector2i(3, 0)))
	assert_true(m.touch.frozen)
	assert_false(m.term.pin.is_empty(), "the box a hold opens stays")
	var word := _word(m)
	var rounds: int = m.world.round_no
	_finger(m, word)
	assert_eq(m.overlay, &"codex")
	assert_eq(m.world.round_no, rounds)
	assert_false(m.touch.frozen)


func test_a_tap_off_the_box_a_hold_keeps_only_closes_it() -> void:
	var m := _foe_hover(true)
	_hold(m, _tile_at(m, _me(m) + Vector2i(3, 0)))
	var fit: Dictionary = m.term.pin.fit
	var below := Vector2(fit.at.x + 1.0, fit.at.y + fit.cells.y * fit.scale + 2.0) * Term.CELL
	var rounds: int = m.world.round_no
	_finger(m, _screen(m, below))
	assert_true(m.term.pin.is_empty())
	assert_false(m.touch.frozen)
	assert_eq(m.world.round_no, rounds)


func test_the_box_of_a_word_on_a_page_is_kept_too_and_its_words_link() -> void:
	var m := _main(false)
	m.glass.visible = false
	m._open(&"codex")
	m.menu.codex.go(4)
	m.menu.codex.select(Codex.entries(4).find_custom(func(e): return e.name == "마루"))
	m.term.panel = m.menu.panel()
	var on_page := _word(m)
	m._point(on_page)
	var entry: Array = m.term.hint.duplicate(true)
	assert_false(entry.is_empty(), "the word's box")
	_shift(m, true)
	assert_eq(m.term.pin.lines, entry)
	assert_true(m.term.hint.is_empty())
	var inner := _word(m)
	m._point(inner)
	assert_false(m.term.hint.is_empty(), "a word of the kept box shows its own box")
	var tab: int = m.menu.codex.tab
	var selected: int = m.menu.codex.selected
	_click(m, inner)
	assert_ne([m.menu.codex.tab, m.menu.codex.selected], [tab, selected], "its entry is open")


func test_a_page_covers_the_box_and_the_example_and_shift_keeps_nothing_there() -> void:
	var m := _foe_hover()
	assert_false(m.term.info.is_empty(), "the creature shows a box")
	m._open(&"options")
	assert_true(m.term.info.is_empty())
	_shift(m, true)
	assert_true(m.term.pin.is_empty())
	_shift(m, false)
	m._close()
	assert_false(m.term.info.is_empty(), "the box is back with the page gone")


func test_a_talisman_under_the_pointer_plays_no_example_over_a_page() -> void:
	var m := _foe_hover()
	m.hover_card = Cards.FOX
	m._refresh()
	assert_false(m.term.example.is_empty(), "the talisman plays its example on the map")
	m._open(&"spells")
	assert_true(m.term.example.is_empty(), "opening the page stops it")
	m._refresh()
	assert_true(m.term.example.is_empty(), "the pointer on the talisman row does not start it")
