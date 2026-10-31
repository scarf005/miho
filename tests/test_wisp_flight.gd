extends GutTest
## How far and how sharply a wisp flies: it banks 30° of turn for every 여
## each tile and spends 45° on each step of turn, flies at most
## Spell.RANGE tiles, and once it stops at a wall or the end of its range it
## hovers there WISP_LIFE rounds and never flies again.

const FOX := Cards.FOX
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ROUNDS := 16


## An open hall walled at the edges, with no light, Miho at `at`.
func _world(at: Vector2i) -> World:
	var w := World.new()
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
	me.hp = 30
	me.max_hp = 30
	me.pos = at
	w.actors.append(me)
	w.depth = 4
	w.tails = 5
	w.cards.assign(Cards.ALL)
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t


## Lanterns two tiles above and below `p`.
func _light(w: World, p: Vector2i) -> void:
	_put(w, p + Vector2i(0, 2), World.LANTERN)
	_put(w, p - Vector2i(0, 2), World.LANTERN)


## A dokkaebi at `at` that casts its 도깨비불 east in the next round.
func _caster(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.intent.assign(a.info().casts[0])
	a.aim = E
	w.sense()
	return a


## Windows from (10, 5) to (10, 11) between a dokkaebi at (4, 8) and Miho at
## (13, 8), both lit: the way to her goes round the windows.
func _windows() -> World:
	var w := _world(Vector2i(13, 8))
	for y in range(5, 12):
		_put(w, Vector2i(10, y), World.WINDOW)
	_light(w, Vector2i(13, 8))
	_light(w, Vector2i(4, 8))
	_caster(w, Vector2i(4, 8))
	return w


## Every round's events while Miho waits, until no projectile is left or
## ROUNDS have passed. Heaven stands still once it has cast.
func _rounds(w: World) -> Array:
	var out := []
	for i in ROUNDS:
		out.append(w.act(WAIT))
		for a in w.actors.slice(1):
			a.stunned = 99
		if w.shots.is_empty():
			break
	return out


func _tiles(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"fly").map(func(e): return e.to)


## The round in which an event of type `t` first happens, -1 for none.
func _round_of(rounds: Array, t: StringName) -> int:
	for i in rounds.size():
		if rounds[i].any(func(e): return e.t == t):
			return i
	return -1


func test_a_wisp_banks_30_degrees_a_tile_and_a_homing_orb_45_for_every_fox() -> void:
	assert_eq(Spell.make([FOX]).turn(), 30)
	assert_eq(Spell.make([FOX, FOX]).turn(), 60)
	assert_eq(Spell.make([FOX, Cards.FIRE]).turn(), 30)
	assert_eq(Spell.make([FOX, Cards.ORB]).turn(), 45)
	assert_eq(Spell.make([FOX, FOX, FOX, FOX, Cards.ORB]).turn(), 180)
	assert_eq(Spell.make([Cards.ORB]).turn(), 0)


func test_a_lone_wisp_turns_one_step_at_most_every_second_tile() -> void:
	var w := _world(Vector2i(4, 12))
	var foe := FloorGen.spawn(w, &"jangseung", Vector2i(12, 3))
	foe.cooldown = 99
	_put(w, Vector2i(13, 3), World.LANTERN)
	w.sense()
	var events := w.act({t = &"cast", spells = [{cards = [FOX], dir = E}]})
	events += w.act(WAIT) + w.act(WAIT)
	var tiles := [Vector2i(4, 12)] + _tiles(events)
	var dirs := []
	for k in range(1, tiles.size()):
		dirs.append(tiles[k] - tiles[k - 1])
	assert_eq(dirs[0], E, "no turn on the first tile")
	assert_true(dirs.has(Vector2i(1, -1)), "it does turn towards the creature")
	var turned_before := false
	for k in range(1, dirs.size()):
		var steps := absi(Grid.DIRS.find(dirs[k]) - Grid.DIRS.find(dirs[k - 1]))
		steps = mini(steps, 8 - steps)
		assert_lte(steps, 1, "one 45° step at a time, tile %d" % k)
		assert_false(steps == 1 and turned_before, "never two tiles running, tile %d" % k)
		turned_before = steps == 1


func test_a_wisp_that_overshoots_to_a_wall_hovers_there_and_never_turns_back() -> void:
	var w := _windows()
	var rounds := _rounds(w)
	var landed := _round_of(rounds, &"land")
	assert_gt(landed, -1, "it stops at a wall")
	var at: Vector2i = rounds[landed].filter(func(e): return e.t == &"land")[0].at
	assert_eq(_tiles(rounds.slice(landed + 1).reduce(func(a, b): return a + b, [])), [])
	assert_eq(w.shots.size(), 0, "and goes out")
	var fade: Array = rounds.back().filter(func(e): return e.t == &"fade")
	assert_eq(fade.map(func(e): return e.at), [at], "where it stopped")
	assert_eq(w.player().hp, 30)


func test_a_chasing_wisp_flies_range_tiles_then_hovers_wisp_life_rounds() -> void:
	var w := _world(Vector2i(20, 8))
	_light(w, Vector2i(20, 8))
	_light(w, Vector2i(4, 8))
	_caster(w, Vector2i(4, 8))
	var rounds := _rounds(w)
	var flown := _tiles(rounds.reduce(func(a, b): return a + b, []))
	assert_eq(flown.size(), Spell.RANGE)
	assert_eq(flown.back(), Vector2i(4 + Spell.RANGE, 8))
	var landed := _round_of(rounds, &"land")
	assert_eq(
		_round_of(rounds, &"fade") - landed, Spell.WISP_LIFE - 1, "the round it stops and 7 more"
	)
	assert_eq(w.player().hp, 30)


func test_a_hovering_wisp_stays_when_a_creature_comes_into_sight() -> void:
	var w := _world(Vector2i(4, 8))
	w.act({t = &"cast", spells = [{cards = [FOX], dir = E}]})
	w.act(WAIT)
	var wisp: Shot = w.shots[0]
	var at := wisp.pos
	var foe := FloorGen.spawn(w, &"jangseung", at + Vector2i(2, 1))
	foe.cooldown = 99
	var events := w.act(WAIT) + w.act(WAIT)
	assert_eq(_tiles(events), [])
	assert_eq(wisp.pos, at)
	assert_eq(wisp.host, 0)


func test_a_wisp_whose_creature_dies_stays_where_it_was_with_another_in_sight() -> void:
	var w := _world(Vector2i(4, 8))
	var foe := FloorGen.spawn(w, &"jangseung", Vector2i(7, 8))
	foe.cooldown = 99
	var other := FloorGen.spawn(w, &"jangseung", Vector2i(9, 10))
	other.cooldown = 99
	_put(w, Vector2i(8, 9), World.LANTERN)
	w.sense()
	w.act({t = &"cast", spells = [{cards = [FOX], dir = E}]})
	var wisp: Shot = w.shots[0]
	assert_eq(wisp.host, foe.id)
	w.hurt(foe, foe.hp)
	var events := w.act(WAIT) + w.act(WAIT)
	assert_eq(_tiles(events), [])
	assert_eq(wisp.pos, Vector2i(7, 8))
	assert_eq(other.hp, other.max_hp)


func test_the_forecast_of_each_round_flies_the_wisp_where_the_round_does() -> void:
	var w := _windows()
	for i in ROUNDS:
		var f := Forecast.of(w, WAIT)
		var events := w.act(WAIT)
		for a in w.actors.slice(1):
			a.stunned = 99
		assert_false(f.paths.is_empty(), "round %d" % i)
		for id in f.paths:
			var real := events.filter(func(e): return e.t == &"fly" and e.shot == id)
			var told: Array = f.paths[id].tiles.slice(1)
			assert_eq(told, real.map(func(e): return e.to), "round %d" % i)
		assert_eq(f.after.shots.map(func(s): return s.pos), w.shots.map(func(s): return s.pos))
		if w.shots.is_empty():
			break
