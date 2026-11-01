extends GutTest
## 서고: a dark room behind closed doors whose scroll shelves show the map of
## the storey, and which burns easily.

const E := Vector2i(1, 0)
const ROOM := Rect2i(10, 5, 11, 5)
const DOOR := Vector2i(9, 7)
const SHELVES := [11, 13, 15, 17, 19]
const SEEDS := 24
const DEPTHS := [2, 5, 9]

var _storeys: Array[World] = []


func before_all() -> void:
	for seed_value in SEEDS:
		for depth in DEPTHS:
			var w := World.create(seed_value * World.FLOORS + depth)
			w.depth = depth
			FloorGen.build(w)
			_storeys.append(w)


func _label(w: World) -> String:
	return "seed %d storey %d" % [w.rng.seed, w.depth]


## ROOM cut into a wall with a way in at DOOR, Miho in the passage outside it.
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
	w.depth = 2
	w.tails = 1
	return w


func _library() -> World:
	var w := _hall()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	assert_true(Library.make(w, ROOM, rng))
	w.sense()
	return w


func _read(w: World) -> Array[Dictionary]:
	w.player().pos = Vector2i(SHELVES[0], ROOM.position.y + 1)
	return w.act({t = &"move", dir = Vector2i.UP})


# --- where it lies -----------------------------------------------------------


func test_some_storeys_have_a_library_in_a_room_of_their_own() -> void:
	var found := 0
	for w in _storeys:
		for site: Dictionary in w.sites:
			if site.kind != &"library":
				continue
			found += 1
			assert_eq(w.sites.size() + w.seals.size(), 1, "one event room: " + _label(w))
			assert_eq(w.tile(site.at), World.SHELF)
			assert_gte(w.tiles.count(World.SHELF), 2, _label(w))
			assert_true(w.rooms.all(func(r): return not r.has_point(site.at)), "off the room list")
			assert_true(FloorGen.connected(w), _label(w))
	assert_gt(found, 0, "some storey has a library")


func test_a_seed_builds_the_same_library_every_time() -> void:
	for seed_value in 4:
		var a := World.create(seed_value)
		var b := World.create(seed_value)
		assert_eq(a.sites, b.sites)
		assert_eq(a.tiles, b.tiles)


func test_make_shuts_the_door_floors_the_room_and_lines_the_top_wall_with_shelves() -> void:
	var w := _library()
	assert_eq(w.tile(DOOR), World.DOOR)
	assert_true(w.opaque(DOOR), "a closed door hides the room")
	var straw := 0
	for y in range(ROOM.position.y, ROOM.end.y):
		for x in range(ROOM.position.x, ROOM.end.x):
			var t := w.tile(Vector2i(x, y))
			assert_true(t in [World.BOARD, World.STRAW, World.SHELF], "%s %d" % [Vector2i(x, y), t])
			straw += 1 if t == World.STRAW else 0
	assert_gt(straw, 0)
	for x in SHELVES:
		assert_eq(w.tile(Vector2i(x, ROOM.position.y)), World.SHELF)
	assert_eq(w.tiles.count(World.SHELF), SHELVES.size())
	assert_false(w.lit(Vector2i(15, 7)), "dark inside")
	assert_eq(w.sites, [{kind = &"library", at = Vector2i(SHELVES[0], ROOM.position.y)}])


func test_a_room_too_small_with_no_way_in_or_room_for_two_shelves_is_refused() -> void:
	var rng := RandomNumberGenerator.new()
	var w := _hall()
	assert_false(Library.make(w, Rect2i(10, 5, 4, 5), rng), "too narrow")
	assert_false(Library.make(w, Rect2i(10, 5, 11, 2), rng), "too low")
	var shut := _hall()
	shut.set_tile(DOOR, World.WALL)
	assert_false(Library.make(shut, ROOM, rng), "no way in")
	var small := _hall()
	small.set_tile(Vector2i(11, 4), World.FLOOR)
	assert_false(Library.make(small, Rect2i(10, 5, 5, 3), rng), "one shelf only")
	for p in [w, shut, small]:
		assert_true(p.sites.is_empty() and p.tiles.count(World.SHELF) == 0, "nothing was laid")
	assert_eq(w.tile(DOOR), World.FLOOR)


func test_no_shelf_stands_by_a_way_in() -> void:
	var w := _hall()
	w.set_tile(Vector2i(13, 4), World.FLOOR)
	var rng := RandomNumberGenerator.new()
	assert_true(Library.make(w, ROOM, rng))
	assert_true(w.tile(Vector2i(13, 5)) in [World.BOARD, World.STRAW], "kept clear of the way in")
	assert_eq(w.tile(Vector2i(13, 4)), World.DOOR)
	assert_eq(w.tiles.count(World.SHELF), SHELVES.size() - 1)


# --- the scrolls -------------------------------------------------------------


func test_stepping_onto_a_shelf_shows_the_whole_map_once_and_reads_every_shelf() -> void:
	var w := _library()
	assert_eq(w.known.count(1) < w.tiles.size(), true, "not known yet")
	var events := _read(w)
	assert_eq(w.known.count(1), w.tiles.size())
	assert_eq(events.filter(func(e): return e.t == &"read").size(), 1)
	assert_true(w.sites.is_empty())
	assert_eq(w.tiles.count(World.SHELF), 0)
	assert_eq(w.tiles.count(World.SHELF_READ), SHELVES.size())
	var again := w.act({t = &"move", dir = E})
	assert_true(again.all(func(e): return e.t != &"read"))


func test_the_log_tells_the_map_was_shown() -> void:
	var w := _library()
	var before := w.clone()
	var events := _read(w)
	assert_has(Messages.of(before, w, events).map(Messages.plain), "두루마리를 읽었다. 이 층의 지도가 드러났다")


func test_a_shelf_that_burned_gives_nothing() -> void:
	var w := _library()
	w.set_tile(Vector2i(SHELVES[0], ROOM.position.y), World.ASH)
	w.player().pos = Vector2i(SHELVES[0], ROOM.position.y + 1)
	w.act({t = &"move", dir = Vector2i.UP})
	assert_lt(w.known.count(1), w.tiles.size(), "an ash heap shows nothing")
	assert_eq(w.sites.size(), 1)


func test_the_preview_of_the_reading_equals_the_round() -> void:
	var w := _library()
	w.player().pos = Vector2i(SHELVES[0], ROOM.position.y + 1)
	w.sense()
	var f := Forecast.of(w, {t = &"move", dir = Vector2i.UP})
	w.act({t = &"move", dir = Vector2i.UP})
	assert_eq(f.after.tiles, w.tiles)
	assert_eq(f.after.known.count(1), w.known.count(1))


# --- the fire ----------------------------------------------------------------


func test_boards_straw_and_shelves_burn_and_catch_fire_more_readily_than_grass() -> void:
	for t in [World.BOARD, World.STRAW, World.SHELF, World.SHELF_READ]:
		assert_eq(Tiles.burns[t], 1, str(t))
	for t in [World.BOARD, World.STRAW, World.SHELF]:
		assert_gt(Tiles.of(t, "spread"), Tiles.of(World.GRASS, "spread"), str(t))
	var w := _library()
	var rng_state := w.rng.state
	w.ignite(Vector2i(SHELVES[0], ROOM.position.y + 1))
	for i in 8:
		Terrain.burn(w, w.burning.keys())
	assert_eq(
		w.tile(Vector2i(SHELVES[0], ROOM.position.y)), World.ASH, "the shelf beside it burned"
	)
	assert_ne(w.rng.state, rng_state)


# --- what the hover says -----------------------------------------------------


func test_hovering_a_shelf_keeps_what_reading_it_does_a_secret() -> void:
	var w := _library()
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	var text := Info.plain(Info.terrain(w, Vector2i(SHELVES[0], ROOM.position.y)))
	assert_string_contains(text, "두루마리 서가")
	assert_false(text.contains("밟으면") or text.contains("지도"), text)


func test_the_codex_lists_both_shelves_by_what_they_are() -> void:
	for name in ["두루마리 서가", "읽은 서가"]:
		var entry := Codex.entries(4).filter(func(e): return e.name == name)
		assert_eq(entry.size(), 1, name)
