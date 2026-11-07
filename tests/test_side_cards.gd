extends GutTest
## The sidebar shows creatures that look the same on one card, and counts those that do not fit.


func _term() -> Term:
	var w := Codex.stage()
	w.seen.resize(w.tiles.size())
	w.seen.fill(1)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	var t: Term = autofree(Term.new())
	t.world = w
	t.vis = w.seen
	t.fit(Vector2(1280, 720), 0.0)
	return t


func _spawn(t: Term, kind: StringName, d: Vector2i) -> Actor:
	var a := FloorGen.spawn(t.world, kind, t.world.player().pos + d)
	a.magic.cooldown = 99
	return a


func _cards(t: Term) -> Dictionary:
	return t.side_groups(t.world_actors(), t.world.player().pos)


func test_creatures_that_look_the_same_share_one_card_and_its_hover() -> void:
	var t := _term()
	var four := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)].map(
		func(d): return _spawn(t, &"dokkaebi", d)
	)
	var cards: Array = _cards(t).cards
	assert_eq(cards.size(), 1)
	assert_eq(cards[0].size(), 4)
	var on := Vector2(1, 0.5) * Term.CELL
	assert_true(four.any(func(a): return a.pos == t.side_at(on)), "the card points at one of them")
	assert_eq(t.side_cards().size(), 1)


func test_a_creature_that_differs_in_health_or_kind_has_its_own_card() -> void:
	var t := _term()
	_spawn(t, &"dokkaebi", Vector2i(1, 0))
	_spawn(t, &"dokkaebi", Vector2i(-1, 0))
	var hurt := _spawn(t, &"dokkaebi", Vector2i(0, 1))
	hurt.hp -= 1
	_spawn(t, &"haetae", Vector2i(0, -1))
	var sizes: Array = _cards(t).cards.map(func(c): return c.size())
	sizes.sort()
	assert_eq(sizes, [1, 1, 2])
	assert_eq(_cards(t).hidden, 0)


func test_the_last_row_counts_the_creatures_the_cards_leave_out() -> void:
	var t := _term()
	var room := t.rows - t.foot
	var whole := room / Term.SIDE_ROWS
	for k in whole:
		_spawn(t, &"dokkaebi", Vector2i(k + 1, 2)).hp = k + 1
	assert_eq(_cards(t).cards.size(), whole, "as many as fit show whole")
	assert_eq(_cards(t).hidden, 0)
	_spawn(t, &"dokkaebi", Vector2i(whole + 1, 2)).hp = whole + 1
	_spawn(t, &"dokkaebi", Vector2i(whole + 2, 2)).hp = whole + 1
	var cards: Array = _cards(t).cards
	assert_lte(cards.size() * Term.SIDE_ROWS, room - 1, "a row is left for the count")
	var shown: int = cards.reduce(func(n, c): return n + c.size(), 0)
	assert_eq(_cards(t).hidden, whole + 2 - shown)
	assert_gt(_cards(t).hidden, 0)


func test_an_ally_and_a_foe_of_one_kind_have_cards_of_their_own() -> void:
	var t := _term()
	_spawn(t, &"dokkaebi", Vector2i(1, 0)).faction = Actor.FOX
	_spawn(t, &"dokkaebi", Vector2i(-1, 0))
	for a: Actor in t.world.actors:
		a.ailments.blind = 3
	assert_eq(_cards(t).cards.size(), 2, "both blind, so they do the same")


func test_the_count_of_a_card_stays_inside_the_sidebar_for_every_kind() -> void:
	var t := _term()
	for kind: StringName in Codex.foes():
		var a := _spawn(t, kind, Vector2i(1, 0))
		for n in [2, 12]:
			var all := []
			all.resize(n)
			all.fill(a)
			var head := CreatureCard.title(t, all, Term.MAP.x)
			var where := "%s x%d: %s" % [kind, n, head]
			assert_lte(
				1.5 + t.text_cells(head.name), head.x - 0.5, "the name ends before it " + where
			)
			assert_lte(head.x + t.text_cells(head.count), float(Term.MAP.x), where)
			assert_false(head.name.is_empty(), where)
		t.world.actors.erase(a)
