extends GutTest
## The placement table: how many patches a tier gets, how a patch grows, and
## where the storeys put them.

const SEEDS := 4
const KINDS := [World.GRASS, World.LEAVES, World.STRAW, World.REEDS, World.SHALLOW, World.PILLAR]

var _storeys_built: Array[World] = []


## Every storey of several seeds, built once.
func before_all() -> void:
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value)
			w.depth = depth
			FloorGen.build(w)
			_storeys_built.append(w)


func _row(what: int) -> Dictionary:
	return Placement.ROWS.filter(func(r): return r.get("what") == what)[0]


## A walled board with one floor room of `room`, rooms[0] being it.
func _hall(room: Rect2i) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([room])
	w.rng.seed = 11
	return w


func _tiles_of(w: World, t: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in w.tiles.size():
		if w.tiles[i] == t:
			out.append(Grid.at(i))
	return out


func test_the_count_is_intercept_plus_tier_times_slope_in_hundredths_up_to_the_most() -> void:
	var row := {count = [150, 50, 3]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 20:
		assert_eq(Placement.count(row, 1, rng), 2, "200 hundredths is always 2")
		assert_eq(Placement.count(row, 5, rng), 3, "400 hundredths is capped at 3")
	var three := 0
	for i in 400:
		var n := Placement.count(row, 2, rng)
		assert_between(n, 2, 3, "250 hundredths is 2 or 3")
		three += 1 if n == 3 else 0
	assert_between(three, 150, 250, "half the storeys get the extra patch")


func test_a_negative_count_is_none() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(Placement.count({count = [-100, 20, 5]}, 2, rng), 0)


func test_a_patch_with_no_growth_is_one_tile() -> void:
	var w := _hall(Rect2i(10, 5, 12, 8))
	var laid := Placement.lay(w, _row(World.PILLAR), Vector2i(15, 8))
	assert_eq(laid, [Vector2i(15, 8)] as Array[Vector2i])
	assert_eq(_tiles_of(w, World.PILLAR).size(), 1)


func test_a_patch_grows_over_neighbours_in_its_room_and_replaces_only_its_floor() -> void:
	var room := Rect2i(10, 5, 12, 8)
	var row := {what = World.GRASS, on = World.FLOOR, grow = [100, 20]}
	var w := _hall(room)
	w.tiles[Grid.index(Vector2i(15, 8))] = World.BOARD
	var laid := Placement.lay(w, row, Vector2i(14, 8))
	assert_gt(laid.size(), 5, "a certain start spreads far")
	assert_eq(w.tile(Vector2i(15, 8)), World.BOARD, "other kinds stay")
	for p in laid:
		assert_true(room.has_point(p), "%s is in the room" % p)
		assert_eq(w.tile(p), World.GRASS)
	assert_eq(_tiles_of(w, World.GRASS).size(), laid.size())
	for p in laid.slice(1):
		assert_true(
			laid.any(func(q): return absi(q.x - p.x) + absi(q.y - p.y) == 1),
			"%s touches the patch" % p
		)


func test_a_patch_stays_inside_a_small_room_whatever_its_start() -> void:
	var room := Rect2i(10, 5, 3, 2)
	var row := {what = World.GRASS, on = World.FLOOR, grow = [100, 5]}
	var w := _hall(room)
	var laid := Placement.lay(w, row, Vector2i(10, 5))
	assert_eq(laid.size(), room.get_area())
	assert_eq(_tiles_of(w, World.GRASS).size(), room.get_area())


func test_a_higher_start_chance_makes_a_larger_patch() -> void:
	var sizes := []
	for start in [30, 60, 90]:
		var total := 0
		for seed_value in 30:
			var w := _hall(Rect2i(10, 5, 12, 8))
			w.rng.seed = seed_value
			var row := {what = World.GRASS, on = World.FLOOR, grow = [start, 10]}
			total += Placement.lay(w, row, Vector2i(15, 8)).size()
		sizes.append(total)
	assert_lt(sizes[0], sizes[1])
	assert_lt(sizes[1], sizes[2])


func test_a_pillar_that_would_cut_the_storey_apart_is_taken_out_again() -> void:
	var w := _hall(Rect2i(2, 2, 5, 1))
	assert_eq(Placement.lay(w, _row(World.PILLAR), Vector2i(3, 2)), [] as Array[Vector2i])
	assert_eq(w.tile(Vector2i(3, 2)), World.FLOOR, "the corridor stays open")
	assert_eq(Placement.lay(w, _row(World.PILLAR), Vector2i(6, 2)).size(), 1, "the end is no cut")
	assert_eq(w.tile(Vector2i(6, 2)), World.PILLAR)


## The tiles a row has laid: its tile kind, or the gas of its kind.
func _laid(w: World, row: Dictionary) -> Array[Vector2i]:
	if row.has("gas"):
		var out: Array[Vector2i] = []
		out.assign(w.gas.keys().filter(func(p): return w.gas[p].x == row.gas))
		return out
	return _tiles_of(w, row.what)


func test_no_tile_of_a_row_appears_before_its_first_tier_or_after_its_last() -> void:
	for w in _storeys_built:
		for row: Dictionary in Placement.ROWS:
			if w.tier() < row.tiers[0] or w.tier() > row.tiers[1]:
				assert_eq(_laid(w, row), [], "tier %d has no %s" % [w.tier(), row.keys()])


func test_each_row_turns_up_on_the_tiers_it_asks_for() -> void:
	for row: Dictionary in Placement.ROWS:
		var found := {}
		for w in _storeys_built:
			if not _laid(w, row).is_empty():
				found[w.tier()] = true
		for tier in range(row.tiers[0], row.tiers[1] + 1):
			assert_true(
				found.has(tier), "row %s on tier %d" % [row.get("what", row.get("gas")), tier]
			)


func test_fog_is_laid_over_ponds_outside_the_goal_room_at_full_amount() -> void:
	var row: Dictionary = Placement.ROWS.filter(func(r): return r.get("gas") == Gas.FOG)[0]
	var found := 0
	for w in _storeys_built:
		var goal: Vector2i = w.elixir if w.elixir.x >= 0 else w.stairs
		for p in _laid(w, row):
			found += 1
			assert_eq(w.tile(p), World.POND, "%s is over a pond" % p)
			assert_eq(w.gas[p].y, row.amount)
			assert_false(w.rooms.any(func(r: Rect2i): return r.has_point(p) and r.has_point(goal)))
	assert_gt(found, 20, "storeys of tier 2 and up have fog")


func test_a_gas_patch_grows_like_a_tile_patch_and_leaves_the_tiles_alone() -> void:
	var w := _hall(Rect2i(10, 5, 12, 8))
	for p in [Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8), Vector2i(15, 9)]:
		w.tiles[Grid.index(p)] = World.POND
	var row := {gas = Gas.STEAM, amount = 4, on = World.POND, grow = [100, 50]}
	var laid := Placement.lay(w, row, Vector2i(15, 8))
	assert_eq(laid.size(), 4, "all four pond tiles touch")
	assert_eq(w.gas.size(), 4, "only the pond is covered")
	for p in laid:
		assert_eq(w.gas[p], Vector2i(Gas.STEAM, 4))
		assert_eq(w.tile(p), World.POND)
	assert_eq(w.events, [] as Array[Dictionary], "laid in silence")


func test_patches_lie_in_rooms_other_than_the_goal_room() -> void:
	for w in _storeys_built:
		var goal: Vector2i = w.elixir if w.elixir.x >= 0 else w.stairs
		for kind: int in KINDS:
			for p in _tiles_of(w, kind):
				assert_true(
					w.rooms.any(func(r: Rect2i): return r.has_point(p)), "%s is in a room" % p
				)
				assert_false(
					w.rooms.any(func(r: Rect2i): return r.has_point(p) and r.has_point(goal)),
					"%s is outside the goal room" % p
				)


func test_a_storey_with_patches_stays_connected_with_its_start_and_stairs_free() -> void:
	for w in _storeys_built:
		var dist: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
		for i in w.tiles.size():
			if w.open_floor(Grid.at(i)):
				assert_gt(dist[i], -1, "tile %s of depth %d" % [Grid.at(i), w.depth])
		assert_eq(w.tile(w.start), World.FLOOR)
		assert_true(w.lit(w.elixir if w.depth >= World.FLOORS else w.stairs), "depth %d" % w.depth)
		assert_false(w.lit(w.start), "depth %d" % w.depth)


func test_a_seed_and_depth_lay_the_same_patches_every_time() -> void:
	for seed_value in [1, 5]:
		for depth in [1, 7, 20]:
			var tiles := []
			for i in 2:
				var w := World.create(seed_value)
				w.depth = depth
				FloorGen.build(w)
				tiles.append(w.tiles)
			assert_eq(tiles[0], tiles[1], "seed %d depth %d" % [seed_value, depth])
