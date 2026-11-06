extends GutTest
## While Miho carries the elixir her storey collapses every round and 저승사자 keeps coming
## (Collapse).

const WAIT := {t = &"wait"}
const ME := Vector2i(10, 10)
const START := Vector2i(4, 4)
const STAIRS := Vector2i(Grid.W - 3, Grid.H - 3)
const PILLARS: Array[Vector2i] = [Vector2i(20, 10), Vector2i(30, 12), Vector2i(25, 20)]
const ROUNDS := 100
const SKIES := [World.SKY]
const ROTTEN := [World.BOARD_ROTTEN, World.RUBBLE, World.SKY]


## An open hall on storey `depth` with pillars, Miho at ME carrying the elixir.
func _world(depth := 2, held := true) -> World:
	var w := Arena.hall(ME)
	w.depth = depth
	w.start = START
	w.stairs = STAIRS
	w.elixir_held = held
	w.rng.seed = 7
	for p in PILLARS:
		w.set_tile(p, World.PILLAR)
	w.sense()
	return w


func _count(w: World, kinds: Array) -> int:
	return Array(w.tiles).filter(func(t): return t in kinds).size()


## The world after `n` rounds of waiting, with every creature but Miho removed each round.
func _waited(w: World, n: int) -> World:
	for i in n:
		w.act(WAIT)
		w.actors.assign(w.actors.filter(func(a): return a.is_miho()))
	return w


func _arrivals(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"arrive")


func test_a_round_rots_sinks_and_heats_by_the_scaled_counts() -> void:
	var w := _world()
	var rotten := _count(w, ROTTEN)
	var sky := _count(w, SKIES)
	w.act(WAIT)
	assert_eq(_count(w, ROTTEN) - rotten, Collapse.count(Collapse.ROT))
	assert_eq(_count(w, SKIES) - sky, Collapse.count(Collapse.FALL))
	assert_eq(w.hot.size(), Collapse.count(Collapse.HOT))


func test_without_the_elixir_nothing_changes_and_no_reaper_comes() -> void:
	var w := _world(2, false)
	var tiles := w.tiles.duplicate()
	var state := w.rng.state
	var events := []
	for i in ROUNDS:
		events.append_array(w.act(WAIT))
	assert_eq(w.tiles, tiles)
	assert_eq(w.rng.state, state)
	assert_eq(_arrivals(events), [])
	assert_true(w.hot.is_empty())


func test_on_the_first_storey_only_hot_ground_forms() -> void:
	var w := _world(1)
	var tiles := w.tiles.duplicate()
	w.act(WAIT)
	assert_eq(w.tiles, tiles)
	assert_eq(w.hot.size(), Collapse.count(Collapse.HOT))
	_waited(w, ROUNDS)
	assert_eq(w.tiles, tiles)
	assert_false(w.hot.has(w.player().pos))


func test_miho_and_the_stairs_keep_their_tiles_and_their_path() -> void:
	var w := Arena.from(["@" + ".".repeat(Grid.W - 4)])
	w.depth = 2
	w.start = w.player().pos
	w.stairs = w.start + Vector2i(Grid.W - 5, 0)
	w.elixir_held = true
	w.rng.seed = 3
	w.sense()
	var keep: Array = Collapse.goals(w) + [w.player().pos]
	for i in ROUNDS:
		_waited(w, 1)
		for p: Vector2i in keep:
			assert_ne(w.tile(p), World.SKY, "round %d" % i)
			assert_false(w.hot.has(p), "round %d" % i)
	assert_gt(_count(w, [World.BOARD_ROTTEN]), 0)
	assert_true(Compounds.linked(w, [], Collapse.goals(w)))


func test_a_creature_on_a_sunk_board_falls() -> void:
	var w := _world()
	var boards: Array[Vector2i] = []
	for y in range(2, 8):
		for x in range(20, 30):
			var p := Vector2i(x, y)
			w.set_tile(p, World.BOARD_ROTTEN)
			boards.append(p)
			FloorGen.spawn(w, &"dokkaebi", p)
	var before := w.events.size()
	Collapse.tick(w)
	var sunk := boards.filter(func(p): return w.tile(p) == World.SKY)
	assert_gt(sunk.size(), 0)
	for p: Vector2i in sunk:
		assert_eq(w.actors.filter(func(a): return a.alive() and a.pos == p), [])
		var died := w.events.slice(before).filter(func(e): return e.t == &"die" and e.at == p)
		assert_eq(died.size(), 1)


func test_miho_pushed_into_a_sunk_tile_lands_below_hurt() -> void:
	var w: World = Built.made(5, 2).w
	w.elixir_held = true
	w.rng.seed = 5
	var me := w.player()
	var before := w.tiles.duplicate()
	w.act(WAIT)
	var sunk := []
	for i in before.size():
		if w.tiles[i] == World.SKY and before[i] != World.SKY:
			sunk.append(Grid.at(i))
	assert_gt(sunk.size(), 0)
	var hp := me.hp
	var from: Vector2i = sunk[0]
	me.pos = from - Vector2i.RIGHT
	w.push(me, Vector2i.RIGHT, 1)
	assert_eq(w.depth, 1)
	assert_eq(me.hp, hp - Fall.DAMAGE)


func test_reapers_come_unseen_within_reach_and_hunt() -> void:
	for depth in [2, 9]:
		var w := _world(depth)
		w.seen.fill(0)
		var arrived := 0
		for i in 300:
			var before := w.seen.duplicate()
			var events := w.act(WAIT)
			for e in _arrivals(events):
				arrived += 1
				var saja := w.actor(e.id)
				assert_lte(Grid.cheb(e.at, w.player().pos), World.REAPER_NEAR)
				assert_eq(before[Grid.index(e.at)], 0)
				assert_eq(saja.brain.alert, Actor.HUNT)
			w.actors.assign(w.actors.filter(func(a): return a.is_miho()))
		assert_gt(arrived, 0, "depth %d" % depth)


func test_the_reaper_clock_still_comes_with_the_elixir() -> void:
	var w := _world()
	w.round_no = World.REAPER_ARRIVES - 1
	var events := w.act(WAIT)
	var clock := _arrivals(events).filter(func(e): return not e.has("anywhere"))
	assert_eq(clock.size(), 1)
	assert_lte(Grid.cheb(clock[0].at, w.start), 2)


func test_a_preview_equals_the_act_while_collapsing() -> void:
	var w := _world()
	var seen := w.preview(WAIT)
	w.act(WAIT)
	assert_eq(seen.tiles, w.tiles)
	assert_eq(seen.hot, w.hot)
	assert_eq(seen.rng.state, w.rng.state)


func test_a_saved_run_replays_the_same_collapse() -> void:
	var w := World.create(4)
	var run := SaveGame.new("", 4)
	run.actions.assign([{t = &"cheat", cmd = &"elixir"}, WAIT, WAIT, WAIT, WAIT, WAIT])
	for action: Dictionary in run.actions:
		w.act(action)
	assert_true(w.elixir_held)
	assert_true(run.replay())
	assert_eq(run.world.tiles, w.tiles)
	assert_eq(run.world.hot, w.hot)
	assert_eq(run.world.rng.state, w.rng.state)


func test_the_log_tells_one_collapse_line_and_the_unseen_reaper() -> void:
	var w := _world()
	w.seen.fill(0)
	var line := Lang.t("바닥이 무너졌다")
	var told := 0
	for i in 300:
		var before := w.clone()
		var events := w.act(WAIT)
		var lines := Messages.of(before, w, events).map(Messages.plain)
		assert_eq(lines.count(line), 1, "round %d" % i)
		if not _arrivals(events).is_empty():
			assert_true(lines.any(func(l): return l.begins_with("저승사자")), "round %d" % i)
			told += 1
		w.actors.assign(w.actors.filter(func(a): return a.is_miho()))
	assert_gt(told, 0)


func test_a_quake_comes_only_in_a_round_where_floor_became_sky() -> void:
	for depth in [1, 2]:
		var w := _world(depth)
		for i in 60:
			var sky := _count(w, SKIES)
			var quakes := w.act(WAIT).filter(func(e): return e.t == &"quake")
			assert_eq(not quakes.is_empty(), _count(w, SKIES) > sky, "depth %d round %d" % [depth, i])
			w.actors.assign(w.actors.filter(func(a): return a.is_miho()))
