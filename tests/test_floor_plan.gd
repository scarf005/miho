extends GutTest
## The floor plan: the rooms of a pavilion share walls one tile thick, joined
## by doorways, and some walls between rooms are hidden doors that Miho finds
## like plates.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const SEEDS := 6
## What a feature laid after the exit was picked may add to a route, breaking a tie.
const DECOR := 1
## The hidden door in the wall column of `_world`.
const SECRET := Vector2i(7, 8)

var _storeys: Array[World] = []
var _pavilions: Array[World] = []


## Every storey of several seeds, built once: as the seed falls and on pavilions.
func before_all() -> void:
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value * World.FLOORS + depth)
			w.depth = depth
			FloorGen.build(w)
			_storeys.append(w)
			var p := World.create(seed_value)
			p.depth = depth
			FloorGen.build(p, Skeletons.PAVILIONS)
			_pavilions.append(p)


func _label(w: World) -> String:
	return "seed %d storey %d" % [w.rng.seed, w.depth]


func _room_of(w: World, p: Vector2i) -> int:
	for k in w.rooms.size():
		if w.rooms[k].has_point(p):
			return k
	return -1


## The floor plan as a walk mask: every tile but walls, windows and sky, so
## that what lies in the rooms does not count.
func _plan(w: World) -> PackedByteArray:
	var out := PackedByteArray()
	for t in w.tiles:
		out.append(0 if Terrain.wall(t) or t in [World.WINDOW, World.SKY] else 1)
	return out


## The axis across a hidden door at p: the side whose two ends are rooms.
func _across(w: World, p: Vector2i) -> Vector2i:
	for d in [Vector2i.RIGHT, Vector2i.DOWN]:
		var a := _room_of(w, p - d)
		var b := _room_of(w, p + d)
		if a >= 0 and b >= 0 and a != b:
			return d
	return Vector2i.ZERO


# --- the floor plan ----------------------------------------------------------


func test_every_wall_has_a_tile_that_is_neither_wall_nor_sky_within_one_step() -> void:
	for w in _storeys:
		for i in w.tiles.size():
			var p := Grid.at(i)
			if not Terrain.wall(w.tiles[i]):
				continue
			var open := Grid.DIRS.any(
				func(d):
					var q: Vector2i = p + d
					return Grid.inside(q) and not Terrain.wall(w.tile(q)) and w.tile(q) != World.SKY
			)
			assert_true(open, "%s wall %s is thick" % [_label(w), p])


func test_rooms_are_at_least_three_wide_and_a_wall_apart() -> void:
	for w in _storeys:
		assert_gte(w.rooms.size(), FloorGen.MIN_ROOMS, _label(w))
		for a in w.rooms:
			assert_gte(mini(a.size.x, a.size.y), FloorGen.ROOM_LEAST, "%s %s" % [_label(w), a])
			for b in w.rooms:
				if a != b:
					assert_false(a.grow(1).intersects(b), "%s %s and %s" % [_label(w), a, b])


func test_on_pavilions_miho_starts_in_the_westmost_room_and_the_exit_is_in_the_farthest() -> void:
	for w in _pavilions:
		var home := w.rooms[0]
		assert_eq(w.start, home.position + home.size / 2, _label(w))
		for r in w.rooms:
			assert_lte(home.get_center().x, r.get_center().x, _label(w))
		var dist: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
		var exit := w.elixir if w.depth >= World.FLOORS else w.stairs
		for r in w.rooms:
			var centre := r.position + r.size / 2
			assert_lte(dist[Grid.index(centre)], dist[Grid.index(exit)] + DECOR, _label(w))


func test_the_storey_is_whole_with_hidden_doors_and_plates_counted_as_walls() -> void:
	for w in _storeys:
		assert_true(FloorGen.connected(w, w.traps.keys()), _label(w))


# --- ledges ------------------------------------------------------------------


## The widths of sky between two ledges on one row of a storey.
func _leaps(w: World) -> Array[int]:
	var out: Array[int] = []
	for y in Grid.H:
		var from := -1
		for x in Grid.W:
			var t := w.tile(Vector2i(x, y))
			if t == World.BOARD:
				if from >= 0 and x - from > 1:
					out.append(x - from - 1)
				from = x
			elif t != World.SKY:
				from = -1
	return out


func test_pavilions_have_facing_ledges_with_two_or_three_tiles_of_sky_between() -> void:
	for w in _pavilions:
		var leaps := _leaps(w)
		assert_gt(leaps.size(), 0, _label(w))
		for n in leaps:
			assert_between(n, FloorGen.LEAP.x, FloorGen.LEAP.y, _label(w))


func test_a_ledge_hangs_between_an_outer_wall_or_doorway_and_the_sky() -> void:
	for w in _pavilions:
		var doorways := 0
		for i in w.tiles.size():
			var p := Grid.at(i)
			var sides := [w.tile(p + Vector2i.LEFT), w.tile(p + Vector2i.RIGHT)]
			if w.tiles[i] != World.BOARD or not sides.has(World.SKY):
				continue
			var label := "%s %s" % [_label(w), p]
			var inner: int = sides[0] if sides[1] == World.SKY else sides[1]
			assert_true(
				inner in [World.WALL, World.WINDOW, World.FLOOR, World.DOOR, World.DOOR_OPEN], label
			)
			doorways += 0 if inner in [World.WALL, World.WINDOW] else 1
		assert_gte(doorways, 2, "%s: a doorway onto each ledge" % _label(w))


# --- hidden doors: where they lie --------------------------------------------


func test_a_storey_has_one_hidden_door_more_every_third_storey() -> void:
	for w in _storeys:
		assert_eq(w.secrets.size(), FloorGen.hidden_doors(w.depth), _label(w))
	assert_eq(range(1, World.FLOORS + 1).map(FloorGen.hidden_doors), [2, 2, 2, 3, 3, 3, 4, 4, 4])


func test_a_hidden_door_is_a_wall_between_two_rooms_far_apart_without_it() -> void:
	for w in _storeys:
		for p: Vector2i in w.secrets:
			var label := "%s %s" % [_label(w), p]
			assert_eq(w.tile(p), World.WALL, label)
			var d := _across(w, p)
			assert_ne(d, Vector2i.ZERO, label + " lies between two rooms")
			assert_false(w.rooms[0].grow(1).has_point(p), label + " is not the start room's")
			var side := Vector2i(d.y, d.x)
			assert_true(Terrain.wall(w.tile(p + side)), label)
			assert_true(Terrain.wall(w.tile(p - side)), label)
			var dist: PackedInt32Array = Grid.search(p - d, _plan(w)).dist
			assert_gte(dist[Grid.index(p + d)], FloorGen.SHORTCUT, label)


# --- hidden doors: finding them ----------------------------------------------


## An open hall walled at the edges, cut by a wall column at x = 7 with a
## doorway at the bottom and a hidden door at SECRET; no light, Miho at (4, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR if x != SECRET.x else World.WALL
	w.tiles[Grid.index(Vector2i(SECRET.x, Grid.H - 2))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, 6, Grid.H - 2), Rect2i(8, 1, Grid.W - 9, Grid.H - 2)])
	w.secrets[SECRET] = true
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
	w.sense()
	return w


func test_a_hidden_door_in_the_dark_is_found_only_right_next_to_miho() -> void:
	var w := _world()
	w.player().pos = Vector2i(5, 8)
	w.sense()
	assert_eq(w.tile(SECRET), World.WALL, "two tiles away in the dark it is a wall")
	assert_true(w.secrets.has(SECRET))
	w.player().pos = Vector2i(6, 9)
	w.sense()
	assert_eq(w.tile(SECRET), World.DOOR, "diagonally next to her it is a door")
	assert_false(w.secrets.has(SECRET))


func test_a_hidden_door_on_a_lit_wall_in_sight_is_found_from_afar() -> void:
	var w := _world()
	w.tiles[Grid.index(SECRET + Vector2i(-1, 2))] = World.LANTERN
	w._changed()
	assert_true(w.lit(SECRET))
	w.player().pos = Vector2i(2, 8)
	w.sense()
	assert_eq(w.tile(SECRET), World.DOOR)


func test_finding_a_hidden_door_is_one_find_event_and_one_log_line() -> void:
	var w := _world()
	var before := w.clone()
	var events := w.act({t = &"move", dir = E})
	var found := events.filter(func(e): return e.t == &"find")
	assert_eq(found, [] as Array[Dictionary], "two tiles away")
	before = w.clone()
	events = w.act({t = &"move", dir = E})
	found = events.filter(func(e): return e.t == &"find")
	assert_eq(found, [{t = &"find", at = SECRET, kind = World.DOOR}] as Array[Dictionary])
	assert_has(Messages.of(before, w, events).map(Messages.plain), "문을 찾았다")
	found = w.act(WAIT).filter(func(e): return e.t == &"find")
	assert_eq(found, [] as Array[Dictionary], "found once")


func test_a_planned_walk_goes_round_a_hidden_door_until_it_is_found() -> void:
	var w := _world()
	w.known.fill(1)
	var beyond := SECRET + E
	var round_walk := Travel.route(Travel.search(w), beyond)
	assert_gt(round_walk.size(), 10, "round by the doorway at the bottom")
	assert_does_not_have(round_walk, SECRET)
	w.player().pos = SECRET - E
	w.sense()
	w.player().pos = Vector2i(4, 8)
	w.sense()
	assert_has(Travel.route(Travel.search(w), beyond), SECRET, "through the door once found")


func test_heaven_walks_round_a_hidden_door_until_miho_finds_it() -> void:
	var w := _world()
	assert_false(w.open_floor(SECRET))
	assert_eq(Masks.floor_of(w)[Grid.index(SECRET)], 0)


func test_a_preview_does_not_give_a_hidden_door_away_but_a_clone_keeps_it() -> void:
	var w := _world()
	assert_eq(w.known_clone().secrets, {})
	assert_eq(w.clone().secrets, {SECRET: true})


func test_a_hit_that_cracks_a_hidden_door_leaves_a_cracked_wall_and_no_door() -> void:
	var w := _world()
	Terrain.hit(w, SECRET)
	w.sense()
	assert_eq(w.tile(SECRET), World.WALL_CRACKED)
	assert_false(w.secrets.has(SECRET))
	w.player().pos = SECRET - E
	w.sense()
	assert_eq(w.tile(SECRET), World.WALL_CRACKED, "nothing left to find")


func test_hovering_a_wall_gives_no_hidden_door_away() -> void:
	var w := _world()
	var plain := Vector2i(SECRET.x, 4)
	var told := Info.plain(Info.terrain(w, SECRET))
	assert_eq(told, Info.plain(Info.terrain(w, plain)))
