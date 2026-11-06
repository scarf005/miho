extends GutTest
## The house (World.HOUSE) at the end of the trail from storey 1: the trail leads there and
## back, each map kept as she left it; it is a hut in a clearing with nobody in it; the rules
## that count storeys take storey 1's; the same seed builds the same house whenever she comes.

const WAIT := {t = &"wait"}


## The trail's tile beside its exit.
func _beside(w: World) -> Vector2i:
	for d in Placement.SIDES:
		if w.tile(w.trail_end + d) == World.COURTYARD:
			return w.trail_end + d
	return Vector2i(-1, -1)


## Miho steps from the trail's tile beside its exit onto the exit.
func _walk_trail(w: World) -> void:
	var beside := _beside(w)
	w.player().pos = beside
	w.sense()
	w.act({t = &"move", dir = w.trail_end - beside})


## Miho comes onto the trail's exit.
func _take_trail(w: World) -> void:
	w.player().pos = w.trail_end
	Walk.arrive(w, w.player())


func test_the_trail_leads_to_the_house_and_back_as_left() -> void:
	var w := World.create(3)
	var end := w.trail_end
	var tiles := w.tiles.duplicate()
	var ids := w.actors.map(func(a): return [a.id, a.pos])
	_walk_trail(w)
	assert_eq(w.depth, World.HOUSE)
	assert_eq(w.player().pos, _beside(w), "she stands on the trail by its exit")
	var house := w.tiles.duplicate()
	w.act(WAIT)
	assert_eq(w.depth, World.HOUSE, "standing beside the exit does not take her back")
	_walk_trail(w)
	assert_eq(w.depth, 1)
	assert_eq(w.tiles, tiles)
	assert_eq(w.actors.slice(1).map(func(a): return [a.id, a.pos]), ids.slice(1))
	assert_eq(w.player().pos, _beside(w), "she comes back beside storey 1's exit")
	assert_eq(w.trail_end, end)
	_walk_trail(w)
	assert_eq(w.depth, World.HOUSE)
	assert_eq(w.tiles, house)


func test_health_and_tails_go_along_the_trail_unchanged() -> void:
	var w := World.create(3)
	w.player().hp = 1
	w.tails = 0
	_take_trail(w)
	assert_eq(w.player().hp, 1)
	assert_eq(w.tails, 0)
	_take_trail(w)
	assert_eq(w.player().hp, 1)
	assert_eq(w.tails, 0)


func test_the_house_takes_storey_one_values() -> void:
	var w := World.create(3)
	w.tail_bonus = 1
	var tails := w.max_tails()
	_take_trail(w)
	assert_eq(w.max_tails(), tails)
	var a := FloorGen.spawn(w, &"dokkaebi", FloorGen.nearest_free(w, w.start + Vector2i.LEFT))
	assert_eq(a.rank, Bestiary.rank(1))
	assert_eq(Raise.rises(w, &"dokkaebi"), Raise.rises(Built.world(3), &"dokkaebi"))


func test_the_house_is_a_hut_in_a_clearing_with_nobody_in_it() -> void:
	for s in 6:
		var w := World.create(s)
		_take_trail(w)
		assert_eq(w.actors.size(), 1, "seed %d: only Miho" % s)
		assert_false(World.SKY in w.tiles, "seed %d" % s)
		var board := w.tiles.find(World.BOARD)
		assert_gt(board, -1, "seed %d: a floor of boards" % s)
		var door := w.tiles.find(World.DOOR)
		var shut := Grid.search(w.start, Masks.floor_of(w, [Grid.at(door)], func(_p): return false))
		var open := Grid.search(w.start, Masks.floor_of(w))
		assert_lt(shut.dist[board], 0, "seed %d: the hut's walls shut it" % s)
		assert_gt(open.dist[board], 0, "seed %d: its door lets her in" % s)
		assert_true(Outside._edge(w.trail_end), "seed %d: the exit is on the edge" % s)


func test_the_house_is_the_same_whenever_she_comes() -> void:
	var a := World.create(5)
	_take_trail(a)
	var b := World.create(5)
	for i in 20:
		b.act(WAIT)
	_take_trail(b)
	assert_eq(b.depth, World.HOUSE)
	assert_eq(b.tiles, a.tiles)
	assert_eq(b.trail_end, a.trail_end)


func test_a_walk_ends_on_the_trail_exit_and_never_crosses_it() -> void:
	var w := World.create(3)
	w.known.fill(1)
	var beside := _beside(w)
	w.player().pos = beside
	w.sense()
	var found := Travel.search(w)
	assert_eq(Travel.route(found, w.trail_end), [w.trail_end] as Array[Vector2i])
	for d in Grid.DIRS:
		var q := w.trail_end + d
		if q != beside and Travel.walkable(w, q):
			assert_does_not_have(Travel.route(found, q), w.trail_end)
	assert_ne(w.player().pos + Travel.explore_step(w, found), w.trail_end)


func test_no_spell_turns_or_grows_over_the_trail_exit() -> void:
	var w := World.create(3)
	w.player().pos = _beside(w)
	assert_false(Compounds.open(w, w.trail_end))
	assert_eq(Elements.growable(w, [w.trail_end] as Array[Vector2i]), [] as Array[Vector2i])


func test_nothing_crumbles_in_the_house_while_she_holds_the_elixir() -> void:
	var w := World.create(3)
	_take_trail(w)
	w.elixir_held = true
	var tiles := w.tiles.duplicate()
	for i in 5:
		w.act(WAIT)
	assert_eq(w.tiles, tiles)
	assert_true(w.hot.is_empty())


func test_the_reaper_comes_to_the_house_on_its_clock() -> void:
	var w := World.create(3)
	_take_trail(w)
	w.round_no = World.REAPER_ARRIVES - 1
	var told := w.act(WAIT).filter(func(e): return e.t == &"arrive")
	assert_eq(told.size(), 1)
	assert_lt(Grid.cheb(told[0].at, w.start), 3)
