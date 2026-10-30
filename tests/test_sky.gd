extends GutTest
## Pavilions in open sky: skybridges and the sky itself.

const ORB := Cards.ORB
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const SEEDS := 12

var _storeys_built: Array[Array] = []


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
	w.depth = 4
	w.tails = 4
	w.cards.append(Cards.WATER)
	w.cards.append(Cards.FIRE)
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t


## A column of `t` at x, floor to floor.
func _column(w: World, x: int, t: int) -> void:
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(x, y), t)


func _cast(cards: Array, dir: Vector2i) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func _throw(w: World, cards := [ORB]) -> Array[Dictionary]:
	var events := w.act(_cast(cards, E))
	events.append_array(w.act(WAIT))
	events.append_array(w.act(WAIT))
	w.tails = 4
	return events


func _noises(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"noise")


## Every storey of many seeds, built once: [world, label].
func before_all() -> void:
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value)
			w.depth = depth
			FloorGen.build(w)
			w.sense()
			_storeys_built.append([w, "seed %d storey %d" % [seed_value, depth]])


func _storeys(check: Callable) -> void:
	for built in _storeys_built:
		check.call(built[0], built[1])


func test_every_walkable_tile_the_exit_and_the_peaches_are_reachable_from_the_start() -> void:
	_storeys(
		func(w: World, label: String):
			var dist: PackedInt32Array = Grid.search(w.start, w.open_floor).dist
			for i in w.tiles.size():
				if w.open_floor(Grid.at(i)):
					assert_gt(dist[i], -1, "%s tile %s" % [label, Grid.at(i)])
			var exit := w.elixir if w.depth >= World.FLOORS else w.stairs
			assert_gt(dist[Grid.index(exit)], -1, "%s exit" % label)
			for p in w.peaches:
				assert_gt(dist[Grid.index(p)], -1, "%s peach" % label)
			for a in w.actors:
				assert_gt(dist[Grid.index(a.pos)], -1, "%s creature" % label)
	)


## The pavilions: separate blocks of everything that is not sky or bridge.
func _pavilions(w: World) -> int:
	var apart := func(p: Vector2i): return w.tile(p) not in [World.SKY, World.BRIDGE]
	var done := {}
	var n := 0
	for i in w.tiles.size():
		if apart.call(Grid.at(i)) and not done.has(i):
			n += 1
			var dist: PackedInt32Array = Grid.search(Grid.at(i), apart).dist
			for j in dist.size():
				if dist[j] >= 0:
					done[j] = true
	return n


func test_a_storey_is_two_to_four_pavilions_joined_by_bridges_across_gaps_of_three_to_six() -> void:
	var counts := {}
	_storeys(
		func(w: World, label: String):
			var n := _pavilions(w)
			counts[n] = true
			assert_between(n, 2, 4, label)
			var bridges := 0
			for y in Grid.H:
				var run := 0
				for x in Grid.W + 1:
					if w.tile(Vector2i(x, y)) == World.BRIDGE:
						run += 1
						bridges += 1
					elif run > 0:
						assert_between(run, FloorGen.SKY_GAP.x, FloorGen.SKY_GAP.y, label)
						run = 0
			assert_gte(bridges, FloorGen.SKY_GAP.x * (n - 1), "%s joins every pavilion" % label)
	)
	assert_eq(counts.keys().size(), 3, "2, 3 and 4 pavilions all turn up")


func test_the_grid_edge_cannot_be_walked_and_outside_it_is_wall() -> void:
	_storeys(
		func(w: World, label: String):
			for x in Grid.W:
				for y in [0, Grid.H - 1]:
					assert_false(w.open_floor(Vector2i(x, y)), label)
			for y in Grid.H:
				for x in [0, Grid.W - 1]:
					assert_false(w.open_floor(Vector2i(x, y)), label)
	)
	var w := _world()
	for p in [Vector2i(-1, 3), Vector2i(Grid.W, 3), Vector2i(3, -1), Vector2i(3, Grid.H)]:
		assert_eq(w.tile(p), World.WALL, str(p))
	w.player().pos = Vector2i(1, 8)
	_put(w, Vector2i(0, 8), World.SKY)
	assert_false(w.can({t = &"move", dir = Vector2i(-1, 0)}))


func test_bridges_are_lit_by_the_moon_and_a_start_in_the_dark_stays_dark() -> void:
	_storeys(
		func(w: World, label: String):
			for i in w.tiles.size():
				if w.tiles[i] == World.BRIDGE:
					assert_true(w.lit(Grid.at(i)), "%s %s" % [label, Grid.at(i)])
			assert_false(w.lit(w.start), label)
			assert_true(w.lit(w.elixir if w.depth >= World.FLOORS else w.stairs), label)
	)


func test_a_bridge_can_be_walked_creaks_three_tiles_and_never_burns() -> void:
	var w := _world()
	_column(w, 6, World.SKY)
	for x in range(5, 9):
		_put(w, Vector2i(x, 8), World.BRIDGE)
	var events := w.act({t = &"move", dir = E})
	var creak: Dictionary = _noises(events)[0]
	assert_eq([creak.word, creak.loud], ["삐걱", 3])
	assert_false(World.FLAMMABLE.has(World.BRIDGE))
	w.cards.append(Cards.FIRE)
	w.act(_cast([Cards.FOX, Cards.FIRE], E))
	w.act(WAIT)
	w.act(WAIT)
	assert_eq(w.burning, {}, "a bridge catches no fire")
	assert_eq(w.tile(Vector2i(7, 8)), World.BRIDGE)


func test_miho_on_a_bridge_is_seen_from_afar_but_not_on_the_floor() -> void:
	var w := _world()
	_put(w, Vector2i(30, 8), World.BRIDGE)
	var foe := FloorGen.spawn(w, &"dokkaebi", Vector2i(10, 8))
	foe.cooldown = 99
	w.player().pos = Vector2i(30, 9)
	assert_false(w.sees(foe, w.player().pos), "dark floor: unseen")
	w.player().pos = Vector2i(30, 8)
	w._changed()
	assert_true(w.sees(foe, w.player().pos), "the moon shows the bridge")


func test_sky_blocks_walking_but_not_sight_light_sound_or_spells() -> void:
	var w := _world()
	_put(w, Vector2i(5, 8), World.SKY)
	assert_false(w.can({t = &"move", dir = E}), "sky cannot be walked")
	assert_false(w.open_floor(Vector2i(5, 8)))
	assert_true(w.open_air(Vector2i(5, 8)))
	assert_false(w.opaque(Vector2i(5, 8)))
	_column(w, 7, World.SKY)
	_put(w, Vector2i(9, 8), World.LANTERN)
	assert_eq(w.fov(w.player().pos)[Grid.index(Vector2i(12, 8))], 1, "seen across the gap")
	assert_true(w.lit(Vector2i(8, 8)), "light crosses it too")
	var listener := FloorGen.spawn(w, &"imugi", Vector2i(10, 8))
	listener.cooldown = 99
	w.noise(Vector2i(5, 8), World.THUD, "쿵", true, w.player().id)
	assert_eq(listener.alert, Actor.SEARCH, "sound crosses it")
	var shot := w.act(_cast([Cards.FOX], E))
	assert_true(w.can(_cast([Cards.FOX], E)), "a wisp is cast over sky")
	assert_gt(shot.filter(func(e): return e.t == &"fly").size(), 0)
	w.act(WAIT)
	assert_gt(w.shots[0].pos.x, 7, "the wisp flew over the sky column")
