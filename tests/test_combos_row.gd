extends GutTest
## The compounds Miho can make now, after the queue on the lower status row.


func _main() -> Node:
	var m: Node = Built.main()
	add_child_autofree(m)
	Keys.reset()
	m.new_run(7)
	m.state = &"play"
	m.term.speed = 1000.0
	return m


func _hold(m: Node, cards: Array, depth: int) -> void:
	m.world.cards.assign(cards)
	m.world.depth = depth
	m.world.tail_bonus = 0


func _made(m: Node) -> Array:
	return StatusBar.combos(m.term).map(func(k): return k.c)


func test_nothing_shows_without_a_pair_of_elements() -> void:
	var m := _main()
	m.term.fit(Vector2(1920, 1080), 0.0)
	for held in [
		[Cards.FOX, Cards.ORB], [Cards.FOX, Cards.ORB, Cards.FIRE], [Cards.FIRE, Cards.FIRE]
	]:
		_hold(m, held, 9)
		assert_eq(_made(m), [], str(held))


func test_two_elements_make_their_pair_and_no_other() -> void:
	var m := _main()
	m.term.fit(Vector2(1920, 1080), 0.0)
	_hold(m, [Cards.FIRE, Cards.WATER], 9)
	assert_eq(_made(m), [Cards.pair(Cards.FIRE, Cards.WATER)])


func test_a_compound_shows_only_when_her_most_tails_pay_for_it() -> void:
	var m := _main()
	m.term.fit(Vector2(1920, 1080), 0.0)
	for depth in range(1, 8):
		_hold(m, Cards.ELEMENTS + [Cards.FOX, Cards.ORB], depth)
		var shown := StatusBar.makeable(m.world)
		for c in Cards.compounds():
			var price := Spell.price(Cards.spell_of(c).size())
			assert_eq(shown.has(c), price <= depth, "%s at depth %d" % [c, depth])


func test_a_compound_needs_every_one_of_its_elements() -> void:
	var m := _main()
	m.term.fit(Vector2(1920, 1080), 0.0)
	_hold(m, [Cards.FIRE, Cards.WATER, Cards.WOOD], 9)
	for c in _made(m):
		assert_true(Cards.made_of(c).all(func(e): return m.world.cards.has(e)), str(c))
	assert_false(_made(m).is_empty())


func test_they_come_in_tier_order() -> void:
	var m := _main()
	m.term.fit(Vector2(1920, 1080), 0.0)
	_hold(m, Cards.ELEMENTS, 9)
	var sizes := StatusBar.makeable(m.world).map(func(c): return Cards.made_of(c).size())
	var sorted := sizes.duplicate()
	sorted.sort()
	assert_eq(sizes, sorted)


func test_the_row_fits_before_the_name_and_the_bar_at_every_zoom_of_a_1280x720_window() -> void:
	var m := _main()
	var t: Term = m.term
	_hold(m, Cards.ALL, 9)
	m.casting.picked.assign([Cards.FIRE, Cards.WOOD, Cards.EARTH])
	m.casting.staged.assign([{cards = [Cards.FIRE]}, {cards = [Cards.WATER]}])
	var name := StatusBar._name(t, Spell.make(m.casting.picked))
	for zoom in Settings.ZOOMS:
		t.fit(Vector2(1280, 720), zoom)
		var from := StatusBar.queue_x(t) + Spell.MAX_SLOTS
		var title := StatusBar.title_at(t, name)
		var bar := NoiseMeter.at(t)
		for k in StatusBar.combos(t):
			var ctx := "%s at zoom %s" % [k.c, zoom]
			assert_gte(k.x, from, "after the queue: " + ctx)
			assert_lte(k.x + 1.0, float(t.cols), "on screen: " + ctx)
			if title.y == t.rows - 1:
				assert_gte(k.x, title.x + t.text_cells(name), "after the name: " + ctx)
			if bar.y == t.rows - 1:
				assert_lte(k.x + 1.0, bar.x, "clear of the bar: " + ctx)


func test_what_does_not_fit_is_cut_short_with_a_count() -> void:
	var m := _main()
	var t: Term = m.term
	_hold(m, Cards.ALL, 9)
	var all := StatusBar.makeable(m.world)
	var cut := 0
	for zoom in Settings.ZOOMS:
		t.fit(Vector2(1280, 720), zoom)
		var row := StatusBar.combos(t)
		if row.size() == all.size():
			continue
		cut += 1
		if row.is_empty():
			continue
		assert_eq(row.back().c, &"", "ends with the count at zoom %s" % zoom)
		assert_eq(row.slice(0, -1).map(func(k): return k.c), all.slice(0, row.size() - 1))
	assert_gt(cut, 0, "some zoom is too tight for them all")


func test_the_name_wins_when_the_row_is_tight() -> void:
	var m := _main()
	var t: Term = m.term
	_hold(m, Cards.ALL, 9)
	t.fit(Vector2(1280, 720), 0.0)
	var free := StatusBar.combos(t).size()
	m.casting.picked.assign([Cards.FIRE, Cards.WOOD, Cards.EARTH])
	var name := StatusBar._name(t, Spell.make(m.casting.picked))
	var title := StatusBar.title_at(t, name)
	assert_eq(title.y, float(t.rows - 1), "the name stays on the row")
	assert_lt(title.x, StatusBar.queue_x(t) + Spell.MAX_SLOTS + 1.0, "right after the queue")
	assert_lte(StatusBar.combos(t).size(), free)


func test_a_glyph_points_at_its_compound_and_is_not_a_talisman_to_click() -> void:
	var m := _main()
	var t: Term = m.term
	t.fit(Vector2(1920, 1080), 0.0)
	_hold(m, [Cards.FIRE, Cards.WATER], 9)
	var c := Cards.pair(Cards.FIRE, Cards.WATER)
	var on := Vector2(StatusBar.combos(t)[0].x + 0.5, t.rows - 0.5) * Term.CELL
	assert_eq(StatusBar.talisman_at(t, on), c)
	assert_eq(StatusBar.card_at(t, on), &"", "a click picks nothing")
	assert_eq(StatusBar.combo_at(t, on + Vector2(Term.CELL.x * 3, 0)), &"")
	var picked: Array[StringName] = [Cards.FIRE]
	assert_eq(SpellInfo.hovered(c, picked), SpellInfo.combo(c))


func _left_click(m: Node, cell: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	m.glass.visible = false
	click.position = m.term.get_global_transform() * (cell * Term.CELL)
	m.click(click)


func test_a_click_on_a_compound_fills_the_queue_with_its_talismans() -> void:
	var m := _main()
	var t: Term = m.term
	t.fit(Vector2(1920, 1080), 0.0)
	_hold(m, [Cards.FIRE, Cards.WATER], 9)
	m.world.tails = m.world.max_tails()
	m.casting.picked.assign([Cards.FIRE, Cards.FIRE])
	var c := Cards.pair(Cards.FIRE, Cards.WATER)
	_left_click(m, Vector2(StatusBar.combos(t)[0].x + 0.5, t.rows - 0.5))
	assert_eq(
		Spell.make(m.casting.picked).slots, [c] as Array[StringName], "the queue is that spell"
	)


func test_a_click_on_a_compound_she_cannot_pay_for_now_is_refused() -> void:
	var m := _main()
	var t: Term = m.term
	t.fit(Vector2(1920, 1080), 0.0)
	_hold(m, [Cards.FIRE, Cards.WATER], 9)
	m.world.tails = 0
	_left_click(m, Vector2(StatusBar.combos(t)[0].x + 0.5, t.rows - 0.5))
	assert_eq(m.casting.picked, [] as Array[StringName])
	assert_true(m.casting.refused)


func test_a_click_on_a_saved_spell_fills_the_queue_with_it() -> void:
	var m := _main()
	var t: Term = m.term
	t.fit(Vector2(1920, 1080), 0.0)
	_hold(m, [Cards.FOX], 9)
	m.world.tails = m.world.max_tails()
	m.settings.spells = {&"slot_1": "fox"}
	t.saved = m.settings.spells
	var slot: Dictionary = StatusBar.saved_slots(t)[0]
	_left_click(m, Vector2(slot.x + 0.1, t.rows - 1.5))
	assert_eq(m.casting.picked, [Cards.FOX] as Array[StringName])
