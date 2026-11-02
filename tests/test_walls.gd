extends GutTest
## Walls: orbs crack them and bring them down; the outer edge never breaks.

const ORB := Cards.ORB
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const WALL_AT := Vector2i(10, 8)


## An open hall walled at the edges, with no light, Miho at (4, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.depth = 2
	w.tails = 4
	w.cards.append(Cards.WATER)
	w.cards.append(Cards.FIRE)
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t


func _cast(cards: Array, dir: Vector2i) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## Hurls an orb east and lets it land.
func _throw(w: World, cards := [ORB]) -> Array[Dictionary]:
	var events := w.act(_cast(cards, E))
	events.append_array(w.act(WAIT))
	events.append_array(w.act(WAIT))
	w.tails = 4
	return events


func _thuds(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"noise" and e.word == "쿵")


func test_an_orb_cracks_a_wall_and_then_brings_it_down_with_a_thud_each_time() -> void:
	var w := _world()
	_put(w, WALL_AT, World.WALL)
	var first := _throw(w)
	assert_eq(w.tile(WALL_AT), World.WALL_CRACKED)
	var second := _throw(w)
	assert_eq(w.tile(WALL_AT), World.RUBBLE)
	for events in [first, second]:
		var thuds := _thuds(events)
		assert_eq(thuds.size(), 1)
		assert_eq([thuds[0].at, thuds[0].loud], [WALL_AT, World.THUD])
	var smashed := (first + second).filter(func(e): return e.t == &"smash")
	assert_eq(smashed.map(func(e): return e.was), [World.WALL, World.WALL_CRACKED])


func test_an_orb_flies_on_over_rubble() -> void:
	var w := _world()
	_put(w, WALL_AT, World.RUBBLE)
	w.act(_cast([ORB], E))
	w.act(WAIT)
	w.act(WAIT)
	assert_eq(w.shots[0].pos, Vector2i(11, 8))
	assert_eq(w.tile(WALL_AT), World.RUBBLE)


func test_the_outer_edge_never_breaks() -> void:
	var w := _world()
	var edge := [
		Vector2i(0, 0), Vector2i(Grid.W - 1, Grid.H - 1), Vector2i(5, 0), Vector2i(Grid.W - 1, 8)
	]
	for p: Vector2i in edge + [Vector2i(-1, 8), Vector2i(5, Grid.H)]:
		assert_false(Terrain.breakable(w, p), str(p))
	_put(w, Vector2i(1, 1), World.WALL)
	assert_true(Terrain.breakable(w, Vector2i(1, 1)), "one tile in is an ordinary wall")
	w.player().pos = Vector2i(Grid.W - 3, 8)
	for i in 3:
		var events := _throw(w)
		assert_eq(w.tile(Vector2i(Grid.W - 1, 8)), World.WALL)
		assert_eq(_thuds(events), [], "a wall that holds does not thud")
		assert_does_not_have(events.map(func(e): return e.t), &"smash")


func test_an_orb_cannot_be_hurled_at_an_edge_wall_next_to_her() -> void:
	var w := _world()
	w.player().pos = Vector2i(5, 1)
	assert_false(w.can(_cast([ORB], Vector2i(0, -1))))
	assert_true(w.can(_cast([ORB], Vector2i(0, 1))), "an open tile is fine")
	w.player().pos = Vector2i(5, 2)
	_put(w, Vector2i(5, 1), World.WALL)
	assert_true(w.can(_cast([ORB], Vector2i(0, -1))), "an inner wall is fine")


func test_an_adjacent_wall_can_be_targeted_by_an_orb_but_not_a_wisp() -> void:
	var w := _world()
	var next := w.player().pos + E
	_put(w, next, World.WALL)
	assert_true(w.can(_cast([ORB], E)))
	assert_false(w.can(_cast([Cards.FOX], E)))
	_put(w, next, World.WALL_CRACKED)
	assert_true(w.can(_cast([ORB], E)))
	_throw(w)
	assert_eq([w.tile(next), w.player().pos], [World.RUBBLE, Vector2i(4, 8)])


func test_a_cracked_wall_blocks_walking_sight_and_light_like_a_wall() -> void:
	var w := _world()
	var beside := w.player().pos + E
	_put(w, beside, World.WALL_CRACKED)
	assert_false(w.open_floor(beside))
	assert_false(w.open_air(beside))
	assert_true(w.opaque(beside))
	assert_false(w.can({t = &"move", dir = E}))
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(7, y), World.WALL_CRACKED)
	assert_eq(w.fov(w.player().pos)[Grid.index(Vector2i(9, 8))], 0, "no sight through it")


func test_rubble_can_be_walked_over_and_seen_through() -> void:
	var w := _world()
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(7, y), World.WALL_CRACKED)
	_put(w, Vector2i(7, 8), World.RUBBLE)
	assert_true(w.open_floor(Vector2i(7, 8)))
	assert_false(w.opaque(Vector2i(7, 8)))
	assert_eq(w.fov(w.player().pos)[Grid.index(Vector2i(9, 8))], 1, "seen through the gap")
	for i in 3:
		w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, Vector2i(7, 8))


func test_a_noise_is_stopped_by_a_cracked_wall_but_not_by_rubble() -> void:
	for t in [World.WALL_CRACKED, World.RUBBLE]:
		var w := _world()
		for y in range(1, Grid.H - 1):
			_put(w, Vector2i(7, y), t)
		var listener := FloorGen.spawn(w, &"imugi", Vector2i(9, 8))
		listener.magic.cooldown = 99
		Hearing.noise(w, Vector2i(5, 8), World.THUD, "쿵", true, w.player().id)
		assert_eq(listener.alert == Actor.SEARCH, t == World.RUBBLE, "noise over %d" % t)


func test_a_water_orb_does_not_break_a_wall() -> void:
	var w := _world()
	_put(w, WALL_AT, World.WALL)
	for i in 3:
		var events := _throw(w, [ORB, Cards.WATER])
		assert_eq(w.tile(WALL_AT), World.WALL)
		assert_eq(_thuds(events), [])


func test_a_fire_orb_breaks_only_the_wall_it_strikes() -> void:
	var w := _world()
	var neighbours := [
		Vector2i(10, 7), Vector2i(10, 9), Vector2i(9, 7), Vector2i(9, 9), Vector2i(11, 8)
	]
	for p in [WALL_AT] + neighbours:
		_put(w, p, World.WALL)
	for i in 2:
		_throw(w, [ORB, Cards.FIRE])
	assert_eq(w.tile(WALL_AT), World.RUBBLE)
	for p: Vector2i in neighbours:
		assert_eq(w.tile(p), World.WALL, str(p))
