extends GutTest
## The house (World.HOUSE) at the end of the trail from storey 1: the trail leads there and
## back, each map kept as she left it; it is a hut in a clearing with the sister in it; the rules
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


func test_the_house_keeps_storey_one_tails_as_they_change() -> void:
	var w := World.create(3)
	_take_trail(w)
	_take_trail(w)
	w.tail_bonus += 1
	var tails := w.max_tails()
	_take_trail(w)
	assert_eq(w.max_tails(), tails)


## The house of seed `s`, Miho at the trail's end.
func _house(s := 3) -> World:
	var w := World.create(s)
	_take_trail(w)
	return w


func _sister(w: World) -> Actor:
	for a in w.actors:
		if a.kind == &"sister":
			return a
	return null


func test_the_house_is_a_hut_in_a_clearing_with_the_sister_inside() -> void:
	for s in 6:
		var w := World.create(s)
		_take_trail(w)
		var sister := _sister(w)
		assert_eq(w.actors.size(), 2, "seed %d: Miho and her sister" % s)
		assert_true(sister.ally(), "seed %d" % s)
		assert_false(w.events.any(func(e): return e.t == &"ally"), "seed %d: not told" % s)
		assert_false(World.SKY in w.tiles, "seed %d" % s)
		var board := w.tiles.find(World.BOARD)
		assert_gt(board, -1, "seed %d: a floor of boards" % s)
		var door := w.tiles.find(World.DOOR)
		var shut := Grid.search(w.start, Masks.floor_of(w, [Grid.at(door)], func(_p): return false))
		var open := Grid.search(w.start, Masks.floor_of(w))
		assert_lt(shut.dist[board], 0, "seed %d: the hut's walls shut it" % s)
		assert_gt(open.dist[board], 0, "seed %d: its door lets her in" % s)
		assert_lt(shut.dist[Grid.index(sister.pos)], 0, "seed %d: the sister is inside" % s)
		for d in Placement.SIDES:
			assert_ne(sister.pos, Grid.at(door) + d, "seed %d: the doorway is free" % s)
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


func test_the_log_tells_where_the_trail_took_her() -> void:
	var w := World.create(3)
	w.known.fill(1)
	var lines := []
	for i in 2:
		var before := w.clone()
		w.events = []
		_take_trail(w)
		lines.append_array(Messages.of(before, w, w.events).map(Messages.plain))
	assert_eq(lines, ["집으로 갔다", "1층으로 갔다"])


func test_the_hover_names_the_trail_exit_alone() -> void:
	var w := World.create(3)
	assert_eq(Info.plain(Info.terrain_facts(w, w.trail_end)), "오솔길")


func test_the_agent_is_told_the_house_and_the_trail_exit() -> void:
	var w := World.create(3)
	w.known.fill(1)
	var exit := "trail exit at (%d,%d): storey 1 <-> house" % [w.trail_end.x, w.trail_end.y]
	assert_has(Observation.text(w).split("\n"), exit)
	_take_trail(w)
	w.known.fill(1)
	var head := Observation.text(w).split("\n")[0]
	assert_true(head.begins_with("house, round 0,"), head)


## A free tile beside the sister.
func _by_sister(w: World) -> Vector2i:
	return FloorGen.nearest_free(w, _sister(w).pos)


func test_the_sister_stays_behind() -> void:
	var w := _house()
	var sister := _sister(w)
	var at := sister.pos
	w.player().pos = _by_sister(w)
	assert_does_not_have(Storeys.followers(w.clone()).map(func(a): return a.id), sister.id)
	_take_trail(w)
	assert_eq(w.depth, 1)
	assert_null(_sister(w))
	_take_trail(w)
	assert_eq(_sister(w).pos, at)


## The rounds the sister coughed in, whether Miho heard each, and the log, over `n` waits.
func _coughs(w: World, n: int) -> Dictionary:
	var out := {rounds = [], heard = [], lines = []}
	for i in n:
		var before := w.clone()
		var events := w.act(WAIT)
		for e in events:
			if e.t == &"cough":
				out.rounds.append(w.round_no)
				out.heard.append(e.heard)
		out.lines.append_array(Messages.of(before, w, events).map(Messages.plain))
	return out


func test_the_sister_coughs_now_and_then() -> void:
	var w := _house()
	w.player().pos = _by_sister(w)
	w.sense()
	var told := _coughs(w, 80)
	assert_gt(told.rounds.size(), 4)
	for k in range(1, told.rounds.size()):
		assert_between(told.rounds[k] - told.rounds[k - 1], 5, 15)
	assert_false(told.heard.has(false))
	assert_eq(told.lines.count("여동생이 기침했다"), told.rounds.size())


func test_a_cough_heard_through_the_wall_is_told_once() -> void:
	var w := _house()
	var sister := _sister(w)
	var dist: PackedInt32Array = Grid.search(sister.pos, Masks.heard(w), 5).dist
	var floor_tiles := Masks.floor_of(w)
	for i in dist.size():
		if dist[i] >= 3 and floor_tiles[i] == 1 and w.vacant(Grid.at(i)):
			w.player().pos = Grid.at(i)
			w.sense()
			if not w.sees(w.player(), sister.pos):
				break
	assert_false(w.sees(w.player(), sister.pos), "she stands out of sight")
	var told := _coughs(w, 20)
	assert_gt(told.rounds.size(), 0)
	assert_false(told.heard.has(false))
	assert_eq(told.lines.count("여동생이 기침했다"), told.rounds.size())
	assert_false(told.lines.any(func(l): return l.contains("소리를 들었다")), str(told.lines))


func test_a_cough_out_of_earshot_is_not_heard() -> void:
	var w := _house()
	var dist: PackedInt32Array = Grid.search(_sister(w).pos, Masks.heard(w), 5).dist
	assert_lt(dist[Grid.index(w.player().pos)], 0, "the trail's end is out of earshot")
	var told := _coughs(w, 20)
	assert_gt(told.rounds.size(), 0)
	assert_false(told.heard.has(true))
	assert_eq(told.lines.count("여동생이 기침했다"), 0)


func test_the_run_ends_when_the_sister_falls() -> void:
	var w := _house()
	var before := w.clone()
	w.events = []
	Harm.hurt(w, _sister(w), 1)
	assert_eq(w.outcome, &"lost")
	assert_has(w.events.map(func(e): return e.t), &"lost")
	var lines := Messages.of(before, w, w.events).map(Messages.plain)
	assert_has(lines, "여동생이 쓰러졌다", "told out of sight too")


func test_the_run_ends_when_miho_strikes_her_sister() -> void:
	var w := _house()
	var sister := _sister(w)
	w.player().pos = _by_sister(w)
	w.cards.assign(Cards.ALL)
	w.tails = 3
	w.sense()
	var dir := sister.pos - w.player().pos
	w.act({t = &"cast", spells = [{cards = [Cards.ORB], dir = dir}]})
	assert_false(sister.alive())
	assert_eq(w.outcome, &"lost")


func test_the_reaper_goes_for_the_sister_only() -> void:
	var w := _house()
	var sister := _sister(w)
	var me := w.player()
	var saja := FloorGen.spawn(w, &"saja", FloorGen.nearest_free(w, me.pos))
	w.sense()
	for i in 40:
		if w.outcome != &"":
			break
		w.act(WAIT)
		assert_true(not sister.alive() or saja.ties.rival == sister.id)
	assert_eq(w.outcome, &"lost")
	assert_false(sister.alive())
	assert_eq(me.hp, me.max_hp, "it never struck her")


func test_the_returning_reaper_is_counted_from_the_sister() -> void:
	var w := _house()
	var sister := _sister(w)
	assert_eq(Curse.target(w), sister.pos)
	w.reaper_step = 3
	w.reaper_due = w.round_no
	var told := w.act(WAIT).filter(func(e): return e.t == &"arrive")
	assert_eq(told.size(), 1)
	assert_eq(Grid.cheb(told[0].at, sister.pos), Curse.distance(3))


## Puts Miho two tiles from the sister and gives the step that brings her beside her.
func _come_to_sister(w: World) -> Dictionary:
	var at := _sister(w).pos
	var walk := Masks.floor_of(w)
	var free := func(p): return w.vacant(p) and walk[Grid.index(p)] == 1 and w.tile(p) != World.DOOR
	for d in Grid.DIRS:
		for e in Grid.DIRS:
			var from: Vector2i = at + d + e
			if Grid.cheb(from, at) == 2 and free.call(at + d) and free.call(from):
				w.player().pos = from
				w.sense()
				return {t = &"move", dir = -e}
	return {}


func test_the_elixir_brought_to_the_sister_saves_her() -> void:
	var w := _house()
	w.elixir_held = true
	var step := _come_to_sister(w)
	var before := w.clone()
	var events := w.act(step)
	assert_eq(w.outcome, &"rescued")
	assert_has(events.map(func(e): return e.t), &"rescued")
	assert_has(Messages.of(before, w, events).map(Messages.plain), "여동생을 구했다")
	assert_has(Observation.text(w).split("\n"), "game over: rescued, Miho saved her sister")


func test_beside_the_sister_without_the_elixir_the_run_goes_on() -> void:
	var w := _house()
	w.act(_come_to_sister(w))
	assert_eq(Grid.cheb(w.player().pos, _sister(w).pos), 1)
	w.act(WAIT)
	assert_eq(w.outcome, &"")


func test_a_death_in_the_round_she_comes_beside_her_comes_first() -> void:
	var w := _house()
	w.elixir_held = true
	var step := _come_to_sister(w)
	w.player().hp = 1
	w.burning[w.player().pos + step.dir] = World.BURN_ROUNDS
	w.act(step)
	assert_false(w.player().alive())
	assert_eq(w.outcome, &"lost")
