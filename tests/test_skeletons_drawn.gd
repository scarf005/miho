extends SkeletonsBase
## The skeletons with drawing of their own: the askew hall, the mirrored hall, the cave and
## the winding hall.


func _init() -> void:
	kinds = [
		Skeletons.CAVE, Skeletons.ASKEW, Skeletons.MIRROR, Skeletons.WINDING, Skeletons.LABYRINTH
	]


func test_the_cave_is_mostly_narrow_tunnels_with_side_ways_a_hit_can_open() -> void:
	for row: Dictionary in _built[Skeletons.CAVE]:
		var w: World = row.w
		assert_gt(w.tiles.count(World.WALL_CRACKED), 20, _label(w, Skeletons.CAVE))
		var open := 0
		var wide := 0
		for i in w.tiles.size():
			var p := Grid.at(i)
			if w.open_floor(p):
				open += 1
				wide += 1 if Grid.DIRS.all(func(d): return w.open_floor(p + d)) else 0
		assert_lt(float(wide) / open, 0.3, _label(w, Skeletons.CAVE))


func test_a_mirrored_hall_has_the_same_walls_on_both_sides_but_its_hidden_doors() -> void:
	for seed_value in 12:
		var w := World.create(seed_value)
		w.depth = 5
		FloorGen._carve(w, Skeletons.MIRROR)
		for p: Vector2i in w.secrets:
			assert_gt(p.x, Grid.W / 2, "seed %d only the east hides doors" % seed_value)
			var west := Vector2i(Grid.W - 1 - p.x, p.y)
			assert_false(Terrain.wall(w.tile(west)), "seed %d a door faces it" % seed_value)
		for y in Grid.H:
			for x in Grid.W / 2:
				var a := Vector2i(x, y)
				var b := Vector2i(Grid.W - 1 - x, y)
				if w.tile(a) == World.WINDOW or w.tile(b) == World.WINDOW or w.secrets.has(b):
					continue
				assert_eq(
					Terrain.wall(w.tile(a)), Terrain.wall(w.tile(b)), "seed %d %s" % [seed_value, a]
				)


func test_the_winding_hall_turns_many_times_and_joins_the_start_to_the_exit() -> void:
	for row: Dictionary in _built[Skeletons.WINDING]:
		var w: World = row.w
		var open := Masks.floor_of(w, w.secrets.keys(), func(_p): return false)
		var way: int = Grid.distance(w.start, open, _exit(w))
		assert_gt(way, Grid.cheb(w.start, _exit(w)) + 8, _label(w, Skeletons.WINDING))


func test_the_winding_hall_is_three_tiles_wide_along_its_way() -> void:
	for seed_value in 12:
		var path := Winding._longest_way(_dice(seed_value))
		assert_gte(path.size(), Winding.LEAST_HALL)
		var turns := 0
		for i in range(2, path.size()):
			turns += 1 if path[i] - path[i - 1] != path[i - 1] - path[i - 2] else 0
		assert_gt(turns, path.size() / 3, "seed %d" % seed_value)
		var origin := Vector2i.ZERO
		assert_eq(Winding._cell(path[0], origin).size, Vector2i(3, 3))


func test_the_askew_hall_has_rooms_of_more_than_one_shape() -> void:
	for seed_value in 12:
		var rng := _dice(seed_value)
		var counts := {}
		for i in 40:
			counts[Askew._shape(rng).rects.size()] = true
		assert_gt(counts.size(), 3, "seed %d" % seed_value)


func _dice(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
