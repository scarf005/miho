extends GutTest
## The skeletons a storey is built on (Skeletons): each stays whole, gives two routes
## to the exit, cuts links only across long walks, and differs from seed to seed.

const SEEDS := 10
## The most rooms of a storey with one way in and nothing hidden behind it, the start
## and the exit left out.
const DEAD_ENDS := {pavilions = 10, ring = 5, avenue = 5, towers = 5}
## How many tiles two seeds' outlines differ by at least, on one storey.
const OUTLINES_APART := 60

## Every storey of each skeleton: [{w, made}], built once.
var _built := {}


func before_all() -> void:
	for kind in Skeletons.ALL:
		_built[kind] = []
		for seed_value in SEEDS:
			for depth in range(1, World.FLOORS + 1):
				var w := World.create(seed_value * World.FLOORS + depth)
				w.depth = depth
				_built[kind].append({w = w, made = FloorGen.build(w, kind)})


func _label(w: World, kind: StringName) -> String:
	return "%s seed %d storey %d" % [kind, w.rng.seed, w.depth]


func _exit(w: World) -> Vector2i:
	return w.elixir if w.depth >= World.FLOORS else w.stairs


## The tiles open to walk on, plates shut as Heaven's walks treat them.
func _walk(w: World) -> PackedByteArray:
	return Masks.floor_of(w, w.traps.keys(), func(_p): return false)


## The first tile whose 3 by 3 block cuts `from` off from `to`, tiles within 3 of the
## rooms `ends` left out; (-1, -1) when none does.
func _choke(open: PackedByteArray, from: Vector2i, to: Vector2i, ends: Array) -> Vector2i:
	for i in open.size():
		var mid := Grid.at(i)
		if open[i] == 0 or ends.any(func(r: Rect2i): return r.grow(3).has_point(mid)):
			continue
		var shut := open.duplicate()
		for d in Grid.DIRS + [Vector2i.ZERO]:
			if Grid.inside(mid + d):
				shut[Grid.index(mid + d)] = 0
		if Grid.search(from, shut).dist[Grid.index(to)] < 0:
			return mid
	return Vector2i(-1, -1)


# --- every skeleton ----------------------------------------------------------


func test_every_storey_is_whole_and_its_exit_can_be_walked_to() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			assert_true(FloorGen.connected(w, w.traps.keys()), _label(w, kind))
			var dist: PackedInt32Array = Grid.search(w.start, _walk(w)).dist
			assert_gt(dist[Grid.index(_exit(w))], 0, _label(w, kind))


## A yard beside the start room once lit the start and left the exit dark.
func test_the_start_stays_dark_and_the_exit_lit() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			assert_false(w.lit(w.start), _label(w, kind))
			assert_true(w.lit(_exit(w)), _label(w, kind))


func test_every_storey_has_rooms_a_wall_apart_and_the_start_in_the_first() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			assert_true(w.rooms[0].has_point(w.start), _label(w, kind))
			assert_gte(w.rooms.size() + w.sites.size(), FloorGen.MIN_ROOMS - 1, _label(w, kind))
			for a in w.rooms:
				assert_gte(mini(a.size.x, a.size.y), FloorGen.ROOM_LEAST, _label(w, kind))
				for b in w.rooms:
					if a != b:
						assert_false(a.grow(1).intersects(b), "%s %s %s" % [_label(w, kind), a, b])


func test_a_storey_has_all_its_hidden_doors_on_every_skeleton() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			assert_eq(w.secrets.size(), FloorGen.hidden_doors(w.depth), _label(w, kind))


func test_dead_ends_stay_under_the_limit() -> void:
	for kind: StringName in _built:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			var goal := FloorGen.room_at(w, _exit(w))
			var dead := w.rooms.filter(
				func(r: Rect2i):
					var ways := EventRooms.doorways(w, r)
					return (
						r != w.rooms[0]
						and r != goal
						and ways.size() == 1
						and not w.secrets.has(ways[0])
					)
			)
			assert_lte(dead.size(), DEAD_ENDS[kind], _label(w, kind))


func test_a_seed_builds_the_same_storey_on_every_skeleton() -> void:
	for kind in Skeletons.ALL:
		var a := World.create(5)
		FloorGen.build(a, kind)
		var b := World.create(5)
		FloorGen.build(b, kind)
		assert_eq(a.tiles, b.tiles, kind)
		assert_eq(a.rooms, b.rooms, kind)


func test_two_seeds_give_a_skeleton_different_outlines() -> void:
	for kind: StringName in _built:
		var rows: Array = _built[kind]
		for i in rows.size():
			for j in range(i + 1, rows.size()):
				var a: World = rows[i].w
				var b: World = rows[j].w
				if a.depth != b.depth:
					continue
				var differ := 0
				for k in a.tiles.size():
					differ += 1 if (a.tiles[k] == World.SKY) != (b.tiles[k] == World.SKY) else 0
				assert_gte(differ, OUTLINES_APART, "%s and seed %d" % [_label(a, kind), b.rng.seed])


func test_set_rooms_and_treasure_rooms_come_up_on_every_skeleton() -> void:
	for kind: StringName in _built:
		var rows: Array = _built[kind]
		var sets := rows.filter(func(row): return not row.made.is_empty()).size()
		var vaults := rows.filter(func(row): return not row.w.seals.is_empty()).size()
		assert_gte(float(sets) / rows.size(), 0.9, "%s set rooms" % kind)
		assert_between(float(vaults) / rows.size(), 0.2, 0.65, "%s vaults" % kind)


func test_pick_draws_every_skeleton_from_the_worlds_generator() -> void:
	var seen := {}
	for seed_value in 40:
		var w := World.new()
		w.rng.seed = seed_value
		var picked := Skeletons.pick(w)
		seen[picked] = true
		w.rng.seed = seed_value
		assert_eq(Skeletons.pick(w), picked, "seed %d" % seed_value)
	assert_eq(seen.size(), Skeletons.ALL.size())


# --- two routes --------------------------------------------------------------


func test_ring_avenue_and_towers_have_two_routes_from_start_to_exit() -> void:
	for kind in [Skeletons.RING, Skeletons.AVENUE, Skeletons.TOWERS]:
		for row: Dictionary in _built[kind]:
			var w: World = row.w
			var ends := [w.rooms[0], FloorGen.room_at(w, _exit(w))]
			var cut := _choke(_walk(w), w.start, _exit(w), ends)
			assert_eq(cut, Vector2i(-1, -1), _label(w, kind))


## Two rooms at the ends of a walled board, joined by the rows in `rows`.
func _rooms_joined_by(rows: Array) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	FloorGen._fill(w, Rect2i(2, 2, 4, 20), World.FLOOR)
	FloorGen._fill(w, Rect2i(40, 2, 4, 20), World.FLOOR)
	for y: int in rows:
		FloorGen._fill(w, Rect2i(6, y, 34, 1), World.FLOOR)
	return w


func test_two_ways_refuses_one_hall_and_takes_two_far_apart() -> void:
	var home := Rect2i(2, 2, 4, 20)
	var goal := Rect2i(40, 2, 4, 20)
	assert_false(Skeletons.two_ways(_rooms_joined_by([5]), home, goal), "one hall")
	assert_false(Skeletons.two_ways(_rooms_joined_by([5, 6]), home, goal), "side by side")
	assert_false(Skeletons.two_ways(_rooms_joined_by([]), home, goal), "no way at all")
	assert_true(Skeletons.two_ways(_rooms_joined_by([5, 15]), home, goal), "two halls")


# --- far links ---------------------------------------------------------------


func test_every_link_a_storey_cut_joined_two_places_far_apart() -> void:
	for kind in Skeletons.ALL:
		var cut := 0
		for seed_value in SEEDS:
			for depth in range(1, World.FLOORS + 1):
				var w := World.create(seed_value * World.FLOORS + depth)
				w.depth = depth
				var links: Array = FloorGen._carve(w, kind).links
				cut += links.size()
				var doors := links.filter(func(l): return l.a + (l.b - l.a) / 2 == l.at)
				assert_lte(doors.size(), FloorGen.LOOPS, _label(w, kind))
				var open := Masks.floor_of(w)
				for k in range(links.size() - 1, -1, -1):
					open[Grid.index(links[k].at)] = 0
					var dist: int = Grid.search(links[k].a, open).dist[Grid.index(links[k].b)]
					assert_gte(dist, FloorGen.APART, "%s %s" % [_label(w, kind), links[k]])
		assert_gt(cut, SEEDS * World.FLOORS, "%s cuts more than one a storey" % kind)


## Two rooms with a wall between them at x = 5, joined only by a long way round.
func _far_rooms() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for r in [
		Rect2i(2, 2, 3, 5),
		Rect2i(6, 2, 3, 5),
		Rect2i(3, 7, 1, 6),
		Rect2i(3, 12, 38, 1),
		Rect2i(40, 10, 1, 3),
		Rect2i(7, 10, 34, 1),
		Rect2i(7, 7, 1, 4),
	]:
		FloorGen._fill(w, r, World.FLOOR)
	return w


func test_a_loop_opens_where_the_walk_round_is_long_and_not_beside_it_afterwards() -> void:
	var w := _far_rooms()
	var far := [Vector2i(5, 2), Vector2i.RIGHT, 0, 1]
	var near := [Vector2i(5, 6), Vector2i.RIGHT, 0, 1]
	var links := []
	var left := FloorGen._loops(w, [far, near], links)
	assert_ne(w.tile(far[0]), World.WALL, "a long walk round")
	assert_eq(w.tile(near[0]), World.WALL, "the first loop made this walk short")
	assert_eq(left, [near])
	assert_eq(links.size(), 1)
	assert_eq(links[0].at, far[0])


func test_a_loop_never_opens_between_places_no_walk_joins() -> void:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	FloorGen._fill(w, Rect2i(1, 1, 1, Grid.H - 2), World.FLOOR)
	FloorGen._fill(w, Rect2i(3, 1, 1, Grid.H - 2), World.FLOOR)
	var spots := [[Vector2i(2, 5), Vector2i.RIGHT, 0, 1]]
	var links := []
	assert_eq(FloorGen._loops(w, spots, links), spots)
	assert_eq(links, [])


func test_a_second_bridge_is_cut_only_across_a_long_walk() -> void:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.SKY)
	var west := Rect2i(1, 2, 8, 22)
	var east := Rect2i(15, 2, 8, 22)
	for r in [west, east]:
		FloorGen._fill(w, r, World.WALL)
		FloorGen._fill(w, r.grow(-1), World.FLOOR)
	var links := []
	assert_true(FloorGen.link_far(w, west, east, 4, links), "the first joins them")
	assert_eq(links, [], "the first is no loop")
	assert_false(FloorGen.link_far(w, west, east, 6, links), "a short walk round")
	assert_eq(w.tile(Vector2i(10, 6)), World.SKY)
	assert_true(FloorGen.link_far(w, west, east, 22, links), "a long walk round")
	assert_eq(links.size(), 1)
	assert_eq(w.tile(Vector2i(10, 22)), World.BRIDGE)


# --- each skeleton's shape ---------------------------------------------------


func test_the_ring_holds_a_court_of_sky_with_a_bridge_over_it() -> void:
	for row: Dictionary in _built[Skeletons.RING]:
		var w: World = row.w
		var sky := Grid.mask(w.tiles, Grid.table(func(t): return t == World.SKY))
		var outside: PackedInt32Array = Grid.search(Vector2i.ZERO, sky).dist
		var court := 0
		for i in sky.size():
			court += 1 if sky[i] == 1 and outside[i] < 0 else 0
		assert_gte(court, 20, _label(w, Skeletons.RING))
		assert_gt(w.tiles.count(World.BRIDGE), 0, _label(w, Skeletons.RING))


func test_the_avenue_runs_straight_from_the_start_to_the_exit() -> void:
	var from_east := 0
	for row: Dictionary in _built[Skeletons.AVENUE]:
		var w: World = row.w
		from_east += 1 if w.start.x > _exit(w).x else 0
		assert_gte(absi(w.start.x - _exit(w).x), 30, _label(w, Skeletons.AVENUE))
		var longest := 0
		for y in Grid.H:
			var run := 0
			for x in Grid.W:
				run = run + 1 if w.open_floor(Vector2i(x, y)) else 0
				longest = maxi(longest, run)
		assert_gte(longest, 25, _label(w, Skeletons.AVENUE))
		assert_gt(w.tiles.count(World.LANTERN), 0, _label(w, Skeletons.AVENUE))
	assert_between(from_east, 1, SEEDS * World.FLOORS - 1, "from either end")


func test_the_towers_put_the_start_and_the_exit_at_opposite_ends() -> void:
	for row: Dictionary in _built[Skeletons.TOWERS]:
		var w: World = row.w
		var label := _label(w, Skeletons.TOWERS)
		assert_ne(w.start.x < Grid.W / 2, _exit(w).x < Grid.W / 2, label)
		assert_gte(absi(w.start.y - _exit(w).y), Skeletons.TOWER_ENDS, label)
		var rows := {}
		for i in w.tiles.size():
			if w.tiles[i] == World.BRIDGE:
				rows[Grid.at(i).y] = true
		assert_gte(rows.size(), 2, label)
