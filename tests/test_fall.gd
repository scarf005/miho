extends GutTest
## World.push: a creature slides until something blocks it, or falls into the sky.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const EDGE := 25
const ROW := 8


## An open hall whose east part is sky from x = EDGE, Miho at (10, 8) on storey
## `depth`; the storeys below are kept as the whole hall, with no sky.
func _world(depth := 2) -> World:
	var w := World.new()
	w.rng.seed = 11
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, EDGE - 2, Grid.H - 2)])
	for below in range(1, depth):
		w.depth = below
		Storeys.leave(w)
	for y in range(1, Grid.H - 1):
		for x in range(EDGE, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.SKY
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(10, ROW)
	w.actors.append(me)
	w.depth = depth
	w.tails = w.max_tails()
	w.sense()
	return w


func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.magic.cooldown = 99
	return a


func test_a_push_slides_the_creature_up_to_n_tiles() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
	w.push(foe, E, 3)
	assert_eq(foe.pos, Vector2i(15, ROW))
	w.push(foe, Vector2i(0, -1), 2)
	assert_eq(foe.pos, Vector2i(15, ROW - 2))
	w.push(foe, E, 0)
	assert_eq(foe.pos, Vector2i(15, ROW - 2))


func test_a_push_stops_at_a_wall() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(4, ROW))
	foe.hp = 99
	w.push(foe, -E, 9)
	assert_eq(foe.pos, Vector2i(1, ROW), "the wall ring is at x = 0")
	assert_true(foe.alive())


func test_a_push_stops_at_whatever_blocks_walking() -> void:
	for blocker in [World.LANTERN, World.POND, World.WINDOW, World.WALL_CRACKED]:
		var w := _world()
		var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
		w.set_tile(Vector2i(15, ROW), blocker)
		w.push(foe, E, 9)
		assert_eq(foe.pos, Vector2i(14, ROW), str(blocker))


func test_a_push_stops_at_a_creature() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
	var other := _foe(w, &"dokkaebi", Vector2i(15, ROW))
	w.push(foe, E, 9)
	assert_eq(foe.pos, Vector2i(14, ROW))
	assert_eq(other.pos, Vector2i(15, ROW))
	w.push(w.player(), E, 9)
	assert_eq(w.player().pos, Vector2i(13, ROW), "Miho is stopped by a creature too")


func test_a_direction_that_is_no_unit_step_does_nothing() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
	w.push(foe, Vector2i(2, 0), 3)
	assert_eq(foe.pos, Vector2i(12, ROW))


func test_a_creature_pushed_into_the_sky_falls_and_counts_as_a_kill() -> void:
	var w := _world()
	var foe := _foe(w, &"cheonha", Vector2i(EDGE - 2, ROW))
	w.tails = 1
	var had := w.cards.duplicate()
	w.events = []
	w.push(foe, E, 5)
	assert_false(foe.alive())
	assert_eq(foe.pos, Vector2i(EDGE - 1, ROW), "it falls from the last floor tile")
	var types := w.events.map(func(e): return e.t)
	assert_has(types, &"fall")
	assert_has(types, &"die")
	assert_does_not_have(types, &"card")
	assert_eq(w.cards, had, "no talisman")
	assert_eq(w.tails, 2 if w.max_tails() >= 2 else 1)
	w.act(WAIT)
	assert_null(w.actor(foe.id), "it is gone from the storey")


func test_a_fallen_creature_leaves_no_body_and_no_change() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(EDGE - 1, ROW))
	w.push(foe, E, 1)
	assert_true(w.bodies.is_empty())
	assert_true(w.changes.is_empty())


func test_the_log_tells_who_fell() -> void:
	var w := _world()
	w.set_tile(Vector2i(11, ROW), World.LANTERN)
	var foe := _foe(w, &"dokkaebi", Vector2i(EDGE - 1, ROW))
	w.player().pos = Vector2i(EDGE - 3, ROW)
	w.sense()
	var before := w.clone()
	w.events = []
	w.push(foe, E, 1)
	var lines := Messages.of(before, w, w.events).map(Messages.plain)
	assert_eq(lines, ["도깨비가 하늘로 떨어졌다"])


func test_miho_pushed_into_the_sky_lands_one_storey_down() -> void:
	var w := _world(5)
	var me := w.player()
	me.pos = Vector2i(EDGE - 2, ROW)
	me.hp = 2
	w.tails = 2
	w.cards.append(Cards.FIRE)
	var cards := w.cards.duplicate()
	w.events = []
	w.push(me, E, 4)
	assert_eq(w.depth, 4)
	assert_eq(me.hp, 1, "a fall of one storey hurts 1")
	assert_eq(w.tails, 2, "her tails are kept")
	assert_eq(w.cards, cards)
	assert_eq(me.pos, Vector2i(EDGE, ROW), "she lands where she fell")
	assert_eq(w.round_no, 0)
	assert_true(w.changes.is_empty())
	assert_eq(w.actors[0], me)
	var fall: Dictionary = w.events.filter(func(e): return e.t == &"fall")[0]
	assert_eq(fall.depth, 4)
	assert_eq(w.outcome, &"")


func test_her_tails_are_kept_up_to_what_the_lower_storey_allows() -> void:
	var w := _world(2)
	assert_eq(w.tails, 2)
	w.player().pos = Vector2i(EDGE - 1, ROW)
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 1)
	assert_eq(w.tails, 1)


func test_the_log_tells_that_miho_fell() -> void:
	var w := _world(3)
	w.player().pos = Vector2i(EDGE - 1, ROW)
	w.sense()
	var before := w.clone()
	w.events = []
	w.push(w.player(), E, 1)
	var lines := Messages.of(before, w, w.events).map(Messages.plain)
	assert_eq(lines, ["2층으로 추락했다", "피해를 1 입었다"])


func test_miho_on_the_first_storey_stops_at_the_edge() -> void:
	var w := _world(1)
	var me := w.player()
	me.pos = Vector2i(EDGE - 3, ROW)
	w.events = []
	w.push(me, E, 9)
	assert_eq(me.pos, Vector2i(EDGE - 1, ROW))
	assert_eq(w.depth, 1)
	assert_eq(me.hp, 3)
	assert_false(w.events.any(func(e): return e.t == &"fall"))


func test_a_fall_in_the_middle_of_a_round_leaves_the_old_storey_behind() -> void:
	var w := _world(3)
	var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
	w.player().pos = Vector2i(EDGE - 1, ROW)
	w.push(w.player(), E, 1)
	assert_false(w.actors.has(foe))
	w.act(WAIT)
	assert_eq(w.depth, 2)
	assert_eq(w.outcome, &"")


func test_the_preview_of_a_fall_equals_the_fall() -> void:
	var w := _world(3)
	w.player().pos = Vector2i(EDGE - 1, ROW)
	var copy := w.clone()
	w.push(w.player(), E, 1)
	copy.push(copy.player(), E, 1)
	assert_eq(copy.depth, w.depth)
	assert_eq(copy.tiles, w.tiles)
	assert_eq(copy.start, w.start)
	assert_eq(copy.actors.size(), w.actors.size())
	assert_eq(copy.rng.state, w.rng.state)


## Miho takes the stairs up.
func _climb(w: World) -> void:
	w.player().pos = w.stairs
	Walk.arrive(w, w.player())


## A free floor tile with no plate, away from the start and the stairs.
func _spot(w: World) -> Vector2i:
	for i in w.tiles.size():
		var p := Grid.at(i)
		var free := w.vacant(p) and w.vacant(p + E) and not w.traps.has(p)
		if free and Grid.cheb(p, w.start) >= 3 and p != w.stairs and not w.peaches.has(p):
			return p
	return Vector2i(-1, -1)


## Makes `p` sky with Miho on a bare floor tile west of it, one push from falling.
func _edge(w: World, p: Vector2i) -> void:
	var from := p - E
	var other := w.actor_at(from)
	if other != null and other != w.player():
		w.actors.erase(other)
	w.set_tile(p, World.SKY)
	w.set_tile(from, World.FLOOR)
	w.traps.erase(from)
	w.player().pos = from


func test_a_fall_lands_on_the_storey_below_as_miho_left_it() -> void:
	var w := World.create(3)
	for i in 3:
		w.act(WAIT)
	var p := _spot(w)
	assert_gt(w.actors.size(), 1, "storey 1 holds creatures")
	var foe: Actor = w.actors[1]
	var foe_at := foe.pos
	var tiles := w.tiles.duplicate()
	var known := w.known.duplicate()
	var rounds := w.round_no
	_climb(w)
	assert_eq(w.depth, 2)
	_edge(w, p)
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 1)
	assert_eq(w.tiles, tiles, "the storey she left")
	var forgot := 0
	for i in known.size():
		forgot += 1 if known[i] == 1 and w.known[i] == 0 else 0
	assert_eq(forgot, 0, "what she knew of it")
	var still := w.actor(foe.id)
	assert_eq(still.pos if still != null else null, foe_at, "its creatures")
	assert_eq(w.round_no, rounds)
	assert_eq(w.player().pos, p, "she lands where she fell")
	assert_eq(w.player().hp, 2, "a fall of one storey hurts 1")


func test_the_stairs_lead_back_up_to_the_storey_she_fell_from() -> void:
	var w := World.create(3)
	var p := _spot(w)
	_climb(w)
	_edge(w, p)
	var tiles := w.tiles.duplicate()
	var ids := w.actors.map(func(a): return a.id)
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 1)
	_climb(w)
	assert_eq(w.depth, 2)
	assert_eq(w.tiles, tiles)
	assert_eq(w.actors.map(func(a): return a.id), ids)
	assert_eq(w.player().pos, w.start)


func test_a_fall_through_sky_on_the_storey_below_goes_on_down_and_hurts_more() -> void:
	var w := World.create(3)
	var p := _spot(w)
	_climb(w)
	w.set_tile(p, World.SKY)
	_climb(w)
	assert_eq(w.depth, 3)
	_edge(w, p)
	w.events = []
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 1, "two storeys down")
	assert_eq(w.player().pos, p)
	assert_eq(w.player().hp, 1, "a fall of two storeys hurts 2")
	var fall: Dictionary = w.events.filter(func(e): return e.t == &"fall")[0]
	assert_eq(fall.depth, 1)


func test_a_fall_onto_a_wall_lands_on_the_nearest_free_tile() -> void:
	var w := World.create(3)
	var p := _spot(w)
	w.set_tile(p, World.WALL)
	_climb(w)
	_edge(w, p)
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 1)
	assert_eq(Grid.cheb(w.player().pos, p), 1)
	assert_true(w.open_floor(w.player().pos))


func test_a_fall_onto_sky_on_the_first_storey_lands_on_the_nearest_free_tile() -> void:
	var w := World.create(3)
	var p := _spot(w)
	w.set_tile(p, World.SKY)
	_climb(w)
	_edge(w, p)
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 1)
	assert_eq(Grid.cheb(w.player().pos, p), 1)
	assert_eq(w.player().hp, 2)


func test_a_fall_can_kill_miho() -> void:
	var w := _world(3)
	w.player().hp = 1
	w.player().pos = Vector2i(EDGE - 1, ROW)
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 2)
	assert_false(w.player().alive())
	assert_eq(w.outcome, &"lost")


func test_a_copy_keeps_the_storeys_left_below() -> void:
	var w := World.create(3)
	var p := _spot(w)
	_climb(w)
	_edge(w, p)
	w.sense()
	var known := w.known_clone()
	var copy := w.clone()
	copy.push(copy.player(), E, 1)
	known.push(known.player(), E, 1)
	w.push(w.player(), E, 1)
	for c in [copy, known]:
		assert_eq(c.depth, 1)
		assert_eq(c.tiles, w.tiles)
		assert_eq(c.player().pos, p)
		assert_eq(c.actors.map(func(a): return a.pos), w.actors.map(func(a): return a.pos))


func test_the_same_seed_and_moves_keep_the_same_storeys() -> void:
	var runs: Array[World] = []
	for n in 2:
		var w := World.create(5)
		var p := _spot(w)
		w.act(WAIT)
		_climb(w)
		w.act(WAIT)
		_edge(w, p)
		w.push(w.player(), E, 1)
		w.act(WAIT)
		_climb(w)
		w.act(WAIT)
		runs.append(w)
	assert_eq(runs[0].depth, runs[1].depth)
	assert_eq(runs[0].tiles, runs[1].tiles)
	assert_eq(runs[0].round_no, runs[1].round_no)
	assert_eq(runs[0].rng.state, runs[1].rng.state)
	assert_eq(runs[0].actors.map(func(a): return a.pos), runs[1].actors.map(func(a): return a.pos))


func test_the_forecast_shows_a_fall() -> void:
	var w := _world(3)
	var foe := _foe(w, &"dokkaebi", Vector2i(EDGE - 1, ROW))
	w.player().pos = Vector2i(EDGE - 3, ROW)
	w.sense()
	var f := Forecast.new()
	f.after = w.known_clone()
	f.after.events = []
	f.after.push(f.after.actor(foe.id), E, 1)
	f.after.push(f.after.player(), Vector2i(1, 0), 9)
	f.read(f.after.events)
	assert_true(f.falls.has(foe.id))
	assert_true(f.deaths.has(foe.id))
	assert_true(f.drops_me())
	assert_eq(f.after.depth, 2)


func test_a_push_into_a_wall_harms_both_by_the_tiles_left() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(16, ROW))
	foe.hp = 9
	w.set_tile(Vector2i(14, ROW), World.WALL)
	w.push(foe, -E, 2)
	assert_eq(foe.pos, Vector2i(15, ROW), "one tile flown, one left")
	assert_eq(foe.hp, 8)
	assert_eq(w.tile(Vector2i(14, ROW)), World.WALL_CRACKED)


func test_a_push_from_beside_a_wall_harms_both_by_the_whole_push() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(15, ROW))
	foe.hp = 9
	w.set_tile(Vector2i(14, ROW), World.WALL)
	w.push(foe, -E, 2)
	assert_eq(foe.pos, Vector2i(15, ROW))
	assert_eq(foe.hp, 7)
	assert_eq(w.tile(Vector2i(14, ROW)), World.RUBBLE)


func test_miho_pushed_into_a_wall_is_harmed_like_a_creature() -> void:
	var w := _world()
	var me := w.player()
	me.hp = 9
	w.set_tile(me.pos - E * 2, World.WALL)
	var from := me.pos
	w.push(me, -E, 2)
	assert_eq(me.pos, from - E)
	assert_eq(me.hp, 8)
	assert_eq(w.tile(from - E * 2), World.WALL_CRACKED)


func test_a_push_that_ends_beside_a_wall_harms_nothing() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(16, ROW))
	foe.hp = 9
	w.set_tile(Vector2i(14, ROW), World.WALL)
	w.push(foe, -E, 1)
	assert_eq(foe.hp, 9)
	assert_eq(w.tile(Vector2i(14, ROW)), World.WALL)


func test_the_outermost_wall_harms_the_creature_and_stands() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(1, ROW))
	foe.hp = 9
	w.push(foe, -E, 2)
	assert_eq(foe.hp, 7)
	assert_eq(w.tile(Vector2i(0, ROW)), World.WALL)


func test_a_wall_broken_early_still_harms_the_creature_by_the_whole_rest() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(15, ROW))
	foe.hp = 9
	w.set_tile(Vector2i(14, ROW), World.WALL_CRACKED)
	w.push(foe, -E, 3)
	assert_eq(foe.hp, 6)
	assert_eq(w.tile(Vector2i(14, ROW)), World.RUBBLE)


func test_a_push_into_anything_but_a_wall_harms_nothing() -> void:
	for blocker in [World.LANTERN, World.POND, World.WINDOW]:
		var w := _world()
		var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
		foe.hp = 9
		w.set_tile(Vector2i(13, ROW), blocker)
		w.push(foe, E, 3)
		assert_eq(foe.hp, 9, str(blocker))
		assert_eq(w.tile(Vector2i(13, ROW)), blocker, str(blocker))


func test_a_wall_crash_can_fell_the_creature() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(15, ROW))
	foe.hp = 1
	w.set_tile(Vector2i(14, ROW), World.WALL)
	w.push(foe, -E, 2)
	assert_false(foe.alive())


func test_a_wooden_wall_breaks_and_harms_like_a_wall() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(15, ROW))
	foe.hp = 9
	w.set_tile(Vector2i(14, ROW), World.WOOD_WALL)
	w.push(foe, -E, 2)
	assert_eq(foe.hp, 7)
	assert_eq(w.tile(Vector2i(14, ROW)), World.FLOOR)


func test_the_log_tells_who_hit_the_wall() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(11, ROW))
	foe.hp = 9
	w.set_tile(Vector2i(11, ROW - 1), World.WALL)
	w.sense()
	var before := w.clone()
	var from := w.events.size()
	w.push(foe, Vector2i(0, -1), 1)
	var lines := Messages.of(before, w, w.events.slice(from)).map(Messages.plain)
	assert_true(lines.has("도깨비가 벽에 부딪혀 피해를 1 입었다"), str(lines))
