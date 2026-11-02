extends GutTest
## 물귀신: it moves only on water and waits there unseen. Its blow binds and drags. The
## hall has a pond east of a line of shallows, and floor west of that.

const KIND := &"mulgwisin"
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(6, 8)
## Column of shallows; the pond lies from here + 1 eastward to POND_END.
const SHORE := 8
const POND_END := 14
const PLANNED := [4, 5, 6, 7, 8, 9]
const SEEDS := 10
const PATH := "user://test_mulgwisin.cfg"


func after_each() -> void:
	SaveGame.new(PATH).erase()


func _hall() -> World:
	var w := World.new()
	w.rng.seed = 1
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = 3
	w.tails = 3
	w.sense()
	return w


## `_hall` with the shallows and the pond over rows 4 to 12.
func _shore() -> World:
	var w := _hall()
	for y in range(4, 13):
		w.set_tile(Vector2i(SHORE, y), World.SHALLOW)
		for x in range(SHORE + 1, POND_END + 1):
			w.set_tile(Vector2i(x, y), World.POND)
	w.set_tile(Vector2i(SHORE + 2, 3), World.LANTERN)
	w.sense()
	return w


func _ghost(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, KIND, at)
	w.sense()
	return a


func _water(w: World, p: Vector2i) -> bool:
	return w.tile(p) in [World.POND, World.SHALLOW]


func test_it_never_leaves_the_water_while_it_chases_her_round_the_room() -> void:
	var w := _shore()
	var a := _ghost(w, Vector2i(POND_END, 8))
	var dice := RandomNumberGenerator.new()
	dice.seed = 7
	w.player().max_hp = 1000
	w.player().hp = 1000
	var moved := {}
	for i in 300:
		var dirs := Grid.DIRS.filter(func(d): return w.can({t = &"move", dir = d}))
		var step: Vector2i = (
			dirs[dice.randi() % dirs.size()] if not dirs.is_empty() else Vector2i.ZERO
		)
		w.act({t = &"move", dir = step} if step != Vector2i.ZERO else WAIT)
		assert_true(_water(w, a.pos), "round %d at %s" % [i, a.pos])
		moved[a.pos] = true
	assert_gt(moved.size(), 3, "it does swim about")


func test_it_swims_up_to_her_when_she_stands_on_the_shore() -> void:
	var w := _shore()
	w.player().pos = Vector2i(SHORE - 1, 8)
	var a := _ghost(w, Vector2i(POND_END, 8))
	Mind.hunt_from(w, a, w.player().pos)
	w.sense()
	for i in 20:
		w.player().hp = w.player().max_hp
		w.act(WAIT)
		if Grid.cheb(a.pos, w.player().pos) == 1:
			break
	assert_eq(Grid.cheb(a.pos, w.player().pos), 1, "it reached her")


func test_she_is_safe_once_no_water_lies_next_to_her() -> void:
	var w := _shore()
	w.player().pos = Vector2i(SHORE - 2, 8)
	var a := _ghost(w, Vector2i(SHORE, 8))
	Mind.hunt_from(w, a, w.player().pos)
	w.sense()
	for i in 30:
		w.act(WAIT)
	assert_eq(w.player().hp, w.player().max_hp)
	assert_gte(Grid.cheb(a.pos, w.player().pos), 2)


func test_it_waits_awake_and_strikes_when_she_comes_next_to_it() -> void:
	var w := _shore()
	var a := _ghost(w, Vector2i(SHORE, 8))
	assert_false(a.asleep(), "resting, its eyes stay open")
	w.player().pos = Vector2i(SHORE - 2, 8)
	w.sense()
	w.act({t = &"move", dir = E})
	assert_lt(w.player().hp, w.player().max_hp, "she stepped next to it")


func test_it_is_unseen_on_the_map_and_hover_until_she_is_next_to_it() -> void:
	var w := _shore()
	var at := Vector2i(SHORE + 2, 8)
	var a := _ghost(w, at)
	assert_eq(w.seen[Grid.index(at)], 1, "she sees the water")
	assert_false(Hat.shown(w, a))
	assert_false(str(Info.at(w, at)).contains("물귀신"), "the hover tells the water")
	assert_false(w.known_clone().actors.any(func(b): return b.kind == KIND), "the forecast too")
	w.player().pos = at - E
	w.sense()
	assert_true(Hat.shown(w, a))
	assert_true(str(Info.at(w, at)).contains("물귀신"))
	assert_true(w.known_clone().actors.any(func(b): return b.kind == KIND))


func test_a_wall_hides_it_even_from_the_next_tile() -> void:
	var w := _shore()
	var at := Vector2i(SHORE, 8)
	var a := _ghost(w, at)
	w.set_tile(at - E, World.WALL)
	w.player().pos = at - E * 2
	w.set_tile(at - E * 2, World.FLOOR)
	w.sense()
	assert_false(Hat.shown(w, a), "not seen through a wall")
	w.act(WAIT)
	assert_eq(w.player().hp, w.player().max_hp, "nor does it strike through one")


func test_the_log_tells_nothing_of_it_while_it_is_unseen() -> void:
	var w := _shore()
	var at := Vector2i(SHORE + 2, 8)
	var a := _ghost(w, at)
	assert_eq(w.seen[Grid.index(at)], 1, "she sees the water")
	Mind.hunt_from(w, a, w.player().pos)
	w.player().pos = Vector2i(SHORE - 1, 8)
	a.pos = at + E
	w.sense()
	var before := w.clone()
	var events := w.act(WAIT)
	assert_true(events.any(func(e): return e.t == &"move" and e.id == a.id), "it did swim")
	assert_eq(w.seen[Grid.index(a.pos)], 1)
	var told := Perceived.of(before, w, events).facts
	assert_false(told.any(func(f): return f.get("id", -1) == a.id), str(told))


func test_a_blow_binds_her_and_drags_her_onto_the_shallows_beside_it() -> void:
	var w := _shore()
	w.player().pos = Vector2i(SHORE - 1, 8)
	var a := _ghost(w, Vector2i(SHORE, 8))
	w.act(WAIT)
	var me := w.player()
	assert_eq(me.hp, me.max_hp - Bestiary.info(KIND).melee.damage)
	assert_gt(me.ailments.rooted, 0, "she is bound")
	assert_true(_water(w, me.pos), "on water: %s" % me.pos)
	assert_eq(Grid.cheb(me.pos, a.pos), 1, "beside it")
	assert_false(w.can({t = &"move", dir = W}), "she cannot walk off")


func test_with_only_the_pond_beside_her_she_is_bound_where_she_stands() -> void:
	var w := _hall()
	for y in range(1, Grid.H - 1):
		for x in range(SHORE, Grid.W - 1):
			w.set_tile(Vector2i(x, y), World.POND)
	var me := w.player()
	me.pos = Vector2i(SHORE - 1, 8)
	var a := _ghost(w, Vector2i(SHORE, 8))
	w.sense()
	var from := me.pos
	w.act(WAIT)
	assert_gt(me.ailments.rooted, 0)
	assert_eq(me.pos, from, "the pond cannot hold her")


func test_on_the_water_already_she_is_not_dragged() -> void:
	var w := _shore()
	var me := w.player()
	me.pos = Vector2i(SHORE, 8)
	var a := _ghost(w, Vector2i(SHORE + 1, 9))
	w.sense()
	w.act(WAIT)
	assert_gt(me.ailments.rooted, 0)
	assert_eq(me.pos, Vector2i(SHORE, 8))
	assert_eq(a.pos, Vector2i(SHORE + 1, 9))


func test_she_comes_free_while_it_holds_her_and_can_walk_away() -> void:
	var w := _shore()
	var me := w.player()
	me.pos = Vector2i(SHORE - 1, 8)
	var a := _ghost(w, Vector2i(SHORE, 8))
	me.max_hp = 50
	me.hp = 50
	w.sense()
	w.act(WAIT)
	var bound_for := 0
	while me.ailments.rooted > 0 and bound_for < 10:
		bound_for += 1
		w.act(WAIT)
	assert_lt(bound_for, 10, "a blow on one bound does not bind her longer")
	var away := Vector2i(-1, -1) if a.pos.y > me.pos.y else Vector2i(-1, 1)
	assert_true(w.can({t = &"move", dir = away}), "she can step off")
	var hp := me.hp
	for d: Vector2i in [away, W, W]:
		w.act({t = &"move", dir = d})
	assert_eq(me.hp, hp, "walking straight off, it never gets a blow in")
	assert_gte(Grid.cheb(me.pos, a.pos), 2, "and it stays in the water")
	for i in 5:
		w.act(WAIT)
	assert_eq(me.hp, hp)


func test_earth_that_fills_its_tile_ends_it_and_leaves_no_body() -> void:
	var w := _shore()
	var me := w.player()
	me.pos = Vector2i(SHORE, 8)
	w.cards.assign(Cards.ALL)
	w.tails = 3
	var at := me.pos + E
	var a := _ghost(w, at)
	a.cooldown = 99
	w.tails = 1
	var fill := {t = &"cast", spells = [{cards = [Cards.EARTH], dir = E}]}
	assert_true(w.can(fill))
	var events := w.act(fill)
	assert_eq(w.tile(at), World.MUD, "earth fills water")
	assert_false(a.alive(), "the tile is no water now")
	assert_false(w.bodies.has(at), "no body")
	assert_false(w.actors.has(a))
	assert_true(events.any(func(e): return e.t == &"soul"), "it gives a tail as any fall")


func test_a_flame_on_its_tile_finds_no_fuel_and_a_fire_wisp_sets_it_alight() -> void:
	var w := _shore()
	var me := w.player()
	me.pos = Vector2i(SHORE, 8)
	w.cards.assign(Cards.ALL)
	var at := me.pos + E
	var a := _ghost(w, at)
	a.cooldown = 99
	var hp := a.hp
	w.tails = 3
	w.act({t = &"cast", spells = [{cards = [Cards.FIRE], dir = E}]})
	assert_eq(w.tile(at), World.POND)
	assert_false(w.burning.has(at))
	assert_eq([a.hp, a.ailments.alight], [hp, 0])
	w.act({t = &"cast", spells = [{cards = [Cards.FOX, Cards.FIRE], dir = E}]})
	assert_eq(w.tile(at), World.POND)
	assert_false(w.burning.has(at))
	assert_lt(a.hp, hp)
	assert_gt(a.ailments.alight, 0)


func test_any_change_of_its_tile_from_water_ends_it() -> void:
	for ground in [World.MUD, World.ICE, World.BRIDGE, World.FLOOR]:
		var w := _shore()
		var at := Vector2i(SHORE + 3, 8)
		var a := _ghost(w, at)
		w.set_tile(at, ground)
		w.act(WAIT)
		assert_false(a.alive(), "on %d" % ground)
		assert_false(w.bodies.has(at))


func test_pushed_ashore_it_ends_as_on_a_filled_tile() -> void:
	var w := _shore()
	var a := _ghost(w, Vector2i(SHORE, 8))
	w.push(a, W, 1)
	assert_eq(a.pos, Vector2i(SHORE - 1, 8))
	w.act(WAIT)
	assert_false(a.alive())


func test_what_is_clawed_dead_leaves_a_body_that_rises_on_land() -> void:
	var w := _shore()
	var me := w.player()
	me.pos = Vector2i(SHORE - 1, 8)
	var a := _ghost(w, Vector2i(SHORE + 1, 8))
	Harm.hurt(w, a, a.hp)
	assert_true(w.bodies.has(a.pos), "a body on the water")
	me.raise = true
	w.sense()
	Raise.tick(w)
	var risen := w.actors.filter(func(b): return b.ally())
	assert_eq(risen.size(), 1)
	assert_eq(risen[0].kind, Raise.rises(w, KIND))
	assert_eq(risen[0].pos.x, SHORE, "a walker: on the shallows next to the pond tile")


func test_it_is_fooled_by_a_guise_like_any_dull_creature() -> void:
	var w := _shore()
	var me := w.player()
	me.pos = Vector2i(SHORE - 1, 8)
	me.guise = true
	me.form = &"dokkaebi"
	var a := _ghost(w, Vector2i(SHORE, 8))
	w.sense()
	w.act(WAIT)
	assert_eq(me.hp, me.max_hp, "it does not know her")
	assert_ne(a.alert, Actor.HUNT)


func test_a_forecast_of_a_seen_one_agrees_with_the_round() -> void:
	var w := _shore()
	w.player().pos = Vector2i(SHORE - 1, 8)
	_ghost(w, Vector2i(SHORE, 8))
	var f := Forecast.of(w, WAIT)
	var me := w.player()
	w.act(WAIT)
	assert_eq(f.hurt_me(), Bestiary.info(KIND).melee.damage)
	assert_eq(f.after.player().hp, me.hp)
	assert_eq(f.after.player().pos, me.pos)
	assert_eq(f.after.player().ailments.rooted, me.ailments.rooted)


func test_a_forecast_does_not_name_one_gone_in_the_same_round_as_having_noticed_her() -> void:
	var w := _hall()
	var a := _ghost(w, ME + Vector2i(1, 0))
	var f := Forecast.of(w, {t = &"move", dir = Vector2i(1, 0)})
	assert_true(f.deaths.has(a.id), "struck, then gone with no water under it")
	assert_false(f.noticed.has(a.id))
	assert_eq(Info.ahead(w, {Vector2i(1, 0): f}, a.pos), [])


func test_a_preview_on_a_clone_equals_the_round_itself() -> void:
	var w := _shore()
	w.player().pos = Vector2i(SHORE - 1, 8)
	var a := _ghost(w, Vector2i(SHORE + 1, 8))
	for i in 6:
		var ahead := w.preview(WAIT)
		w.act(WAIT)
		var mine := w.player()
		var clone := ahead.player()
		assert_eq(
			[clone.pos, clone.hp, clone.ailments.rooted],
			[mine.pos, mine.hp, mine.ailments.rooted],
			"me %d" % i
		)
		var b := ahead.actor(a.id)
		assert_eq([b.pos, b.hp, b.alert], [a.pos, a.hp, a.alert], "it %d" % i)


func test_a_saved_run_with_a_seize_plays_back_the_same() -> void:
	for s in range(1, 40):
		var w := World.create(s)
		var spot := _shore_spot(w)
		if spot.is_empty():
			continue
		var run := SaveGame.new(PATH, s)
		var actions: Array[Dictionary] = [
			{t = &"cheat", cmd = &"teleport", at = spot.land},
			{t = &"cheat", cmd = &"summon", kind = KIND, at = spot.water},
			WAIT,
			WAIT,
		]
		for action in actions:
			assert_true(w.can(action), str(action))
			w.act(action)
			run.record(action, 0, false)
		assert_gt(
			w.player().ailments.rooted + (w.player().max_hp - w.player().hp), 0, "she was seized"
		)
		var back := SaveGame.load_from(PATH)
		assert_true(back.replay())
		var me := back.world.player()
		var was := w.player()
		assert_eq([me.pos, me.hp, me.ailments.rooted], [was.pos, was.hp, was.ailments.rooted])
		assert_eq(back.world.rng.state, w.rng.state)
		return
	fail_test("no seed has a shallow tile by the floor")


## A shallow tile of a new run with a floor tile next to it, and no creature at either.
func _shore_spot(w: World) -> Dictionary:
	for i in w.tiles.size():
		var p := Grid.at(i)
		if w.tile(p) != World.SHALLOW or not w.vacant(p):
			continue
		for d in Grid.DIRS:
			if w.vacant(p + d) and w.tile(p + d) == World.FLOOR and p + d != w.player().pos:
				return {water = p, land = p + d}
	return {}


func test_it_stands_on_water_alone_on_every_storey_it_is_planned_for() -> void:
	var placed := 0
	for depth: int in PLANNED:
		assert_true(FloorGen.PLAN[depth].has(KIND), "storey %d" % depth)
		for s in SEEDS:
			var w := World.create(s * World.FLOORS + depth)
			w.depth = depth
			FloorGen.build(w)
			for a in w.actors.filter(func(b): return b.kind == KIND):
				placed += 1
				assert_true(_water(w, a.pos), "seed %d at %s" % [s, a.pos])
				assert_eq(a.leader, 0, "no band leads it")
				assert_false(w.actors.any(func(b): return b.leader == a.id), "it leads none")
	assert_gt(placed, 0)


func test_a_storey_with_no_water_places_none() -> void:
	var w := _hall()
	w.rng.seed = 11
	var state := w.rng.state
	var count := w.actors.size()
	assert_null(FloorGen._place(w, KIND))
	assert_eq(w.actors.size(), count)
	assert_eq(w.rng.state, state, "and draws no dice for it")


func test_the_debug_summon_puts_it_only_on_water() -> void:
	var w := _shore()
	var cheat := {t = &"cheat", cmd = &"summon", kind = KIND}
	assert_false(w.can(cheat.merged({at = Vector2i(SHORE - 2, 8)})), "not on land")
	assert_true(w.can(cheat.merged({at = Vector2i(SHORE, 8)})))
	assert_true(w.can(cheat.merged({at = Vector2i(SHORE + 2, 8)})))
