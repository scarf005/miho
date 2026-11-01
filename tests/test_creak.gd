extends GutTest
## 삐걱 마루: a room of boards with a sleeping 해태 at its far end; when the
## 해태 falls every tail returns.

const E := Vector2i(1, 0)
const ROOM := Rect2i(10, 5, 11, 5)
const BEAST := Vector2i(20, 5)
const SEEDS := 24
const DEPTHS := [7, 13, 25]

var _storeys: Array[World] = []


func before_all() -> void:
	for seed_value in SEEDS:
		for depth in DEPTHS:
			var w := World.create(seed_value)
			w.depth = depth
			FloorGen.build(w)
			_storeys.append(w)


func _label(w: World) -> String:
	return "seed %d storey %d" % [w.rng.seed, w.depth]


## ROOM cut into a wall with a way in at (9, 7), Miho in the passage outside it
## with one tail on storey 7 (three allowed).
func _hall() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(ROOM.position.y, ROOM.end.y):
		for x in range(ROOM.position.x, ROOM.end.x):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(4, 10):
		w.tiles[Grid.index(Vector2i(x, 7))] = World.FLOOR
	w.rooms.assign([ROOM])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(6, 7)
	w.actors.append(me)
	w.depth = 7
	w.tails = 1
	return w


func _floor() -> World:
	var w := _hall()
	assert_true(Creak.make(w, ROOM))
	w.sense()
	return w


func _beast(w: World) -> Actor:
	return w.actor(w.sites[0].id)


## The 해태 falls in a round of its own.
func _fall(w: World) -> void:
	w.events = []
	w.hurt(_beast(w), 99)
	EventRooms.tick(w)


# --- where it lies -----------------------------------------------------------


func test_some_storeys_have_a_creaking_floor_with_a_sleeping_beast_in_a_room_of_its_own() -> void:
	var found := 0
	for w in _storeys:
		for site: Dictionary in w.sites:
			if site.kind != &"creak":
				continue
			found += 1
			assert_eq(w.sites.size() + w.seals.size(), 1, "one event room: " + _label(w))
			var beast := w.actor(site.id)
			assert_eq(beast.kind, &"haetae", _label(w))
			assert_eq(beast.pos, site.at)
			assert_true(beast.asleep(), "asleep: " + _label(w))
			assert_eq(w.tile(site.at), World.BOARD)
			for d in Grid.DIRS:
				assert_ne(w.tile(site.at + d), World.FLOOR, "boards round it: " + _label(w))
			assert_true(w.rooms.all(func(r): return not r.has_point(site.at)), "off the room list")
			assert_true(FloorGen.connected(w), _label(w))
	assert_gt(found, 0, "some storey has a creaking floor")


func test_a_seed_builds_the_same_floor_every_time() -> void:
	for seed_value in 4:
		var a := World.create(seed_value)
		var b := World.create(seed_value)
		assert_eq(a.sites, b.sites)
		assert_eq(a.tiles, b.tiles)


func test_make_boards_the_room_and_lays_the_beast_far_from_the_way_in() -> void:
	var w := _floor()
	for y in range(ROOM.position.y, ROOM.end.y):
		for x in range(ROOM.position.x, ROOM.end.x):
			assert_eq(w.tile(Vector2i(x, y)), World.BOARD)
	assert_eq(w.tile(Vector2i(9, 7)), World.FLOOR, "the passage stays")
	assert_eq(w.sites, [{kind = &"creak", at = BEAST, id = _beast(w).id}])
	assert_eq(_beast(w).kind, &"haetae")
	assert_true(_beast(w).asleep())


func test_a_small_room_or_one_with_no_tile_far_from_its_ways_in_is_refused() -> void:
	var w := _hall()
	assert_false(Creak.make(w, Rect2i(10, 5, 4, 5)), "too narrow")
	assert_false(Creak.make(w, Rect2i(10, 5, 11, 2)), "too low")
	var small := Rect2i(10, 5, 5, 3)
	for p: Vector2i in [Vector2i(12, 4), Vector2i(12, 8), Vector2i(9, 6), Vector2i(15, 6)]:
		w.set_tile(p, World.FLOOR)
	assert_false(Creak.make(w, small), "ways in on every side")
	var shut := _hall()
	shut.set_tile(Vector2i(9, 7), World.WALL)
	assert_false(Creak.make(shut, ROOM), "no way in")
	for x in range(ROOM.position.x, ROOM.end.x):
		assert_eq(shut.tile(Vector2i(x, 6)), World.FLOOR, "nothing was boarded")
	assert_true(shut.sites.is_empty() and shut.actors.size() == 1)


# --- the creak ---------------------------------------------------------------


func test_a_step_on_the_boards_wakes_the_beast_three_tiles_off_and_not_five() -> void:
	var near := _floor()
	near.player().pos = BEAST + Vector2i(-3, 0)
	near.act({t = &"move", dir = E})
	assert_false(_beast(near).asleep(), "heard at 2 tiles")
	var far := _floor()
	far.player().pos = BEAST + Vector2i(-6, 0)
	far.act({t = &"move", dir = E})
	assert_true(_beast(far).asleep(), "5 tiles off, out of earshot")


# --- the tails ---------------------------------------------------------------


func test_the_beast_falling_returns_every_tail_once() -> void:
	var w := _floor()
	var before := w.clone()
	_fall(w)
	assert_eq(w.max_tails(), 3)
	assert_eq(w.tails, 3, "every tail, though the fall gave one")
	assert_true(w.sites.is_empty())
	assert_has(w.events.map(func(e): return e.t), &"creak")
	var lines := Messages.of(before, w, w.events).map(Messages.plain)
	assert_has(lines, "꼬리가 모두 돌아왔다")
	assert_false(lines.any(func(l): return l.contains("꼬리") and l.contains("쓰러졌다")), str(lines))
	w.tails = 0
	EventRooms.tick(w)
	assert_eq(w.tails, 0, "once")


func test_another_creature_falling_in_the_room_returns_nothing() -> void:
	var w := _floor()
	var other := FloorGen.spawn(w, &"dokkaebi", Vector2i(14, 7))
	w.events = []
	w.hurt(other, 99)
	EventRooms.tick(w)
	assert_eq(w.tails, 2, "only the soul it gave, not all three")
	assert_eq(w.sites.size(), 1)


func test_the_beast_pushed_into_the_sky_returns_every_tail_too() -> void:
	var w := _floor()
	w.set_tile(BEAST + E, World.SKY)
	w.events = []
	Fall.push(w, _beast(w), E, 1)
	EventRooms.tick(w)
	assert_eq(w.tails, 3)


func test_a_clone_keeps_the_site() -> void:
	var w := _floor()
	var c := w.clone()
	assert_eq(c.sites, w.sites)
	c.sites[0].id = -1
	assert_ne(w.sites[0].id, -1, "a copy of its own")


# --- what the hover says -----------------------------------------------------


func test_hovering_the_beast_keeps_what_its_fall_brings_a_secret() -> void:
	var w := _floor()
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	assert_false(Info.plain(Info.creature(w, _beast(w))).contains("꼬리 모두"))
	assert_string_contains(Info.plain(Info.terrain(w, Vector2i(14, 7))), "발소리: 3칸")
