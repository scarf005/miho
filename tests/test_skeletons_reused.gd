extends SkeletonsBase


func _init() -> void:
	kinds = [Skeletons.GROVE, Skeletons.FLOODED, Skeletons.TIMBER, Skeletons.HOLLOW]


func test_a_grove_is_thick_with_bamboo_and_holds_no_pond_of_its_garden() -> void:
	for row: Dictionary in _built[Skeletons.GROVE]:
		var w: World = row.w
		assert_gt(w.tiles.count(World.BAMBOO), 60, _label(w, Skeletons.GROVE))


func test_a_flooded_storey_has_pools_ringed_by_shallows_and_the_exit_is_walked_to_dry_of_them(
) -> void:
	for row: Dictionary in _built[Skeletons.FLOODED]:
		var w: World = row.w
		assert_gt(w.tiles.count(World.POND), 25, _label(w, Skeletons.FLOODED))
		assert_gt(w.tiles.count(World.SHALLOW), 25, _label(w, Skeletons.FLOODED))


func test_the_inner_walls_of_a_timber_storey_are_mostly_wood_and_a_hidden_door_stands_in_stone(
) -> void:
	for row: Dictionary in _built[Skeletons.TIMBER]:
		var w: World = row.w
		assert_gt(w.tiles.count(World.WOOD_WALL), 100, _label(w, Skeletons.TIMBER))
		for p: Vector2i in w.secrets:
			for d in Grid.DIRS:
				assert_ne(w.tile(p + d), World.WOOD_WALL, _label(w, Skeletons.TIMBER))


func test_a_noise_passes_a_wooden_wall_and_a_wall_of_stone_stops_it() -> void:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WOOD_WALL)
	assert_eq(Masks.heard(w)[0], 1, "wood")
	w.tiles.fill(World.WALL)
	assert_eq(Masks.heard(w)[0], 0, "stone")


func test_the_hollow_has_sky_beside_its_hall_and_moonlit_stretches() -> void:
	for row: Dictionary in _built[Skeletons.HOLLOW]:
		var w: World = row.w
		var by_sky := 0
		for i in w.tiles.size():
			if w.tiles[i] == World.FLOOR or w.tiles[i] == World.COURTYARD:
				by_sky += (
					1 if Grid.DIRS.any(func(d): return w.tile(Grid.at(i) + d) == World.SKY) else 0
				)
		assert_gt(by_sky, 40, _label(w, Skeletons.HOLLOW))
		assert_gt(w.tiles.count(World.COURTYARD), 5, _label(w, Skeletons.HOLLOW))
