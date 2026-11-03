extends GutTest
## The skeletons a storey is built on (Skeletons): the plans that need no storey built, and the
## shape of the ring, the avenue and the towers. What every skeleton shares is SkeletonsBase.

const SEEDS := 6


func before_all() -> void:
	for kind: StringName in [Skeletons.RING, Skeletons.AVENUE, Skeletons.TOWERS]:
		_rows(kind)


## Every storey of one skeleton: [{w, made}].
func _rows(kind: StringName) -> Array:
	var rows := []
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			rows.append(Built.made(seed_value * World.FLOORS + depth, depth, kind))
	return rows


func _label(w: World, kind: StringName) -> String:
	return "%s seed %d storey %d" % [kind, w.rng.seed, w.depth]


func _exit(w: World) -> Vector2i:
	return w.elixir if w.depth >= World.FLOORS else w.stairs


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
	for row: Dictionary in _rows(Skeletons.RING):
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
	for row: Dictionary in _rows(Skeletons.AVENUE):
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
	for row: Dictionary in _rows(Skeletons.TOWERS):
		var w: World = row.w
		var label := _label(w, Skeletons.TOWERS)
		assert_ne(w.start.x < Grid.W / 2, _exit(w).x < Grid.W / 2, label)
		assert_gte(absi(w.start.y - _exit(w).y), Skeletons.TOWER_ENDS, label)
		var rows := {}
		for i in w.tiles.size():
			if w.tiles[i] == World.BRIDGE:
				rows[Grid.at(i).y] = true
		assert_gte(rows.size(), 2, label)


## A skeleton that is added to Skeletons.ALL is tried by one of the scripts of SkeletonsBase.
func test_every_skeleton_is_tried_by_a_script_of_the_base() -> void:
	var tried: Array[StringName] = []
	for part in ["scattered", "ruin", "garden", "broken", "halls", "reused", "drawn"]:
		var script: SkeletonsBase = load("res://tests/test_skeletons_%s.gd" % part).new()
		tried.append_array(script.kinds)
		script.free()
	tried.sort()
	var all := Skeletons.ALL.duplicate()
	all.sort()
	assert_eq(tried, all)
