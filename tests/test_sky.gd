extends GutTest
## Pavilions in open sky: skybridges, windows and the sky itself.

const ORB := Cards.ORB
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const SEEDS := 12

var _storeys_built: Array[Array] = []
var _pavilions_built: Array[Array] = []


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
			var w := Built.storey(seed_value, depth)
			w.sense()
			_storeys_built.append([w, "seed %d storey %d" % [seed_value, depth]])
			var kind := Built.storey(seed_value * World.FLOORS + depth, depth, Skeletons.PAVILIONS)
			_pavilions_built.append([kind, "seed %d storey %d" % [seed_value, depth]])


func _storeys(check: Callable) -> void:
	for built in _storeys_built:
		check.call(built[0], built[1])


func test_every_walkable_tile_the_exit_and_the_peaches_are_reachable_once_seals_open() -> void:
	_storeys(
		func(w: World, label: String):
			var open := Masks.opened(w)
			var dist: PackedInt32Array = Grid.search(w.start, open).dist
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
	var apart := Grid.mask(w.tiles, Grid.table(func(t): return t not in [World.SKY, World.BRIDGE]))
	var done := {}
	var n := 0
	for i in w.tiles.size():
		if apart[i] == 1 and not done.has(i):
			n += 1
			var dist: PackedInt32Array = Grid.search(Grid.at(i), apart).dist
			for j in dist.size():
				if dist[j] >= 0:
					done[j] = true
	return n


func test_pavilions_are_two_to_four_joined_by_bridges_across_gaps_of_three_to_six() -> void:
	var counts := {}
	for built in _pavilions_built:
		var w: World = built[0]
		var label: String = built[1]
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


func test_windows_sit_only_in_walls_between_a_room_and_the_sky() -> void:
	var seen := [0]
	_storeys(
		func(w: World, label: String):
			for i in w.tiles.size():
				if w.tiles[i] != World.WINDOW:
					continue
				seen[0] += 1
				var p := Grid.at(i)
				assert_between(p.x, 1, Grid.W - 2, "%s %s on the ring" % [label, p])
				assert_between(p.y, 1, Grid.H - 2, "%s %s on the ring" % [label, p])
				var faces := Grid.DIRS.filter(
					func(d): return d.x * d.y == 0 and w.tile(p + d) == World.SKY
				)
				assert_eq(faces.size(), 1, "%s %s faces the sky once" % [label, p])
				assert_false(
					Terrain.wall(w.tile(p - faces[0])) or w.tile(p - faces[0]) == World.SKY,
					"%s %s has a room behind" % [label, p]
				)
	)
	assert_gt(seen[0], 20, "windows are common enough to be seen")


func test_a_window_with_no_sky_beyond_it_is_walled_and_one_with_sky_stays() -> void:
	var w := _world()
	var bare := Vector2i(10, 8)
	var kept := Vector2i(10, 4)
	for p in [bare, kept]:
		_put(w, p, World.WINDOW)
		_put(w, p + E, World.SKY)
	_put(w, bare + E, World.BOARD)
	FloorGen._shut_windows(w)
	assert_eq(w.tile(bare), World.WALL, "a library floored the sky behind it")
	assert_eq(w.tile(kept), World.WINDOW)


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
	assert_eq(Tiles.burns[World.BRIDGE], 0)
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
	assert_true(w.can(_cast([Cards.FOX], E)), "a wisp is cast over sky")
	var events := w.act(_cast([Cards.FOX], E)) + w.act(WAIT)
	assert_true(
		events.any(func(e): return e.t == &"fly" and e.to.x > 7),
		"the wisp flew over the sky column"
	)


func test_a_window_blocks_walking_but_not_sight_or_light() -> void:
	var w := _world()
	_column(w, 7, World.WALL)
	_put(w, Vector2i(7, 8), World.WINDOW)
	_put(w, Vector2i(9, 8), World.LANTERN)
	assert_false(w.open_floor(Vector2i(7, 8)))
	assert_false(w.opaque(Vector2i(7, 8)))
	assert_eq(w.fov(w.player().pos)[Grid.index(Vector2i(11, 8))], 1, "seen through it")
	assert_true(w.lit(Vector2i(6, 8)), "the lantern's light comes through it")
	w.player().pos = Vector2i(6, 8)
	assert_false(w.opaque(Vector2i(7, 8)))


func test_walking_into_a_window_breaks_it_to_floor_with_a_clang_and_a_message() -> void:
	var w := _world()
	var at := Vector2i(5, 8)
	_put(w, at, World.WINDOW)
	var listener := FloorGen.spawn(w, &"imugi", Vector2i(8, 8))
	listener.cooldown = 99
	w.sense()
	assert_true(w.can({t = &"move", dir = E}), "a window can be knocked")
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.tile(at), World.FLOOR)
	assert_eq(w.player().pos, Vector2i(4, 8), "the knock takes her move")
	var clang: Dictionary = _noises(events)[0]
	assert_eq([clang.word, clang.loud, clang.at], ["쨍", World.KNOCK, at])
	assert_eq(listener.alert, Actor.SEARCH)
	var lines := Messages.of(w, w, events).map(Messages.plain)
	assert_eq(lines, ["창문이 깨졌다"])
	w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, at, "the broken window is walked through")


func test_an_orb_breaks_the_window_it_strikes_but_a_water_orb_and_a_wisp_do_not() -> void:
	for dist: int in [1, 4]:
		var w := _world()
		var at := w.player().pos + E * dist
		_put(w, at, World.WINDOW)
		var events := _throw(w)
		assert_eq(w.tile(at), World.FLOOR, "orb at %d tiles" % dist)
		assert_has(_noises(events).map(func(e): return e.word), "쨍")
	var w := _world()
	var at := Vector2i(6, 8)
	_put(w, at, World.WINDOW)
	for i in 2:
		_throw(w, [ORB, Cards.WATER])
	assert_eq(w.tile(at), World.WINDOW, "water does not break it")
	_throw(w, [Cards.FOX])
	assert_eq(w.tile(at), World.WINDOW, "a wisp does not break it")
	_put(w, Vector2i(5, 8), World.WINDOW)
	assert_false(w.can(_cast([Cards.FOX], E)), "a wisp cannot be cast at an adjacent window")
	assert_true(w.can(_cast([ORB], E)), "an orb can")


func test_a_wall_tile_facing_the_sky_on_two_sides_never_gets_a_window() -> void:
	var corner := Vector2i(10, 10)
	var flat := Vector2i(20, 10)
	var flat_windows := 0
	for seed_value in 60:
		var w := _world()
		w.rng.seed = seed_value
		for p in [corner, flat]:
			_put(w, p, World.WALL)
		for p in [corner + Vector2i.UP, corner + Vector2i.LEFT, flat + Vector2i.UP]:
			_put(w, p, World.SKY)
		FloorGen._windows(w)
		assert_eq(w.tile(corner), World.WALL, "seed %d" % seed_value)
		flat_windows += 1 if w.tile(flat) == World.WINDOW else 0
	assert_gt(flat_windows, 0, "a wall facing the sky once does get windows")
