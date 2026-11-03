extends GutTest
## What a run's seed decides of its storeys (RunPlan), and that whole runs built by it keep
## the rules every storey keeps.

const MAPS := preload("res://tools/maps.gd")
const SEEDS := 200
const CLIMBED := 12


func test_no_run_stands_on_one_shape_twice() -> void:
	for seed_value in SEEDS:
		var shapes := RunPlan.shapes(seed_value)
		var seen := {}
		for shape in shapes:
			seen[shape] = true
		assert_eq(seen.size(), World.FLOORS, "seed %d %s" % [seed_value, shapes])


func test_two_storeys_in_a_row_are_never_of_one_kind_of_place() -> void:
	for seed_value in SEEDS:
		var shapes := RunPlan.shapes(seed_value)
		for i in range(1, shapes.size()):
			var kinds := [RunPlan.FAMILY[shapes[i - 1]], RunPlan.FAMILY[shapes[i]]]
			assert_ne(kinds[0], kinds[1], "seed %d %s" % [seed_value, shapes])


func test_a_maze_comes_in_about_two_runs_in_five_on_one_storey_from_the_third_to_the_seventh(
) -> void:
	var runs := 2000
	var with_one := 0
	var concepts := {}
	for seed_value in runs:
		var plan := RunPlan.labyrinth(seed_value)
		var mazes := RunPlan.shapes(seed_value).count(Skeletons.LABYRINTH)
		concepts[plan.concept] = true
		if plan.depth > 0:
			with_one += 1
			assert_eq(RunPlan.shapes(seed_value)[plan.depth - 1], Skeletons.LABYRINTH)
			assert_between(plan.depth, RunPlan.MAZE_DEPTH.x, RunPlan.MAZE_DEPTH.y)
		assert_eq(mazes, 1 if plan.depth > 0 else 0, "seed %d" % seed_value)
	assert_almost_eq(float(with_one) / runs, RunPlan.MAZE_RUNS, 0.04)
	assert_eq(concepts.size(), Labyrinth.CONCEPTS.size())


func test_storeys_of_one_depth_differ_across_runs_and_storeys_of_one_run_differ_in_make_up(
) -> void:
	var layouts := []
	for seed_value in CLIMBED * 2:
		var w := World.create(seed_value)
		var layout := [MAPS._layout(w)]
		for depth in range(2, World.FLOORS + 1):
			Storeys.leave(w)
			Storeys.enter(w, depth)
			layout.append(MAPS._layout(w))
		layouts.append(layout)
	assert_lt(MAPS._overlap(layouts), 0.441)
	assert_lt(MAPS._make_up(layouts), 0.9)


func test_reading_the_plan_draws_nothing_and_reads_the_same_on_a_clone() -> void:
	var w := Built.world(11)
	for depth in range(1, World.FLOORS + 1):
		w.depth = depth
		var state := w.rng.state
		var shape := Skeletons.pick(w)
		assert_eq(w.rng.state, state, "storey %d" % depth)
		var copy := w.clone()
		assert_eq(Skeletons.pick(copy), shape, "storey %d" % depth)


func test_every_shape_comes_up_and_the_order_changes_from_seed_to_seed() -> void:
	var used := {}
	var last := {}
	var orders := {}
	for seed_value in SEEDS:
		var shapes := RunPlan.shapes(seed_value)
		orders[str(shapes)] = true
		last[shapes[World.FLOORS - 1]] = true
		for shape in shapes:
			used[shape] = true
	for kind in Skeletons.ALL:
		assert_true(used.has(kind), kind)
	assert_gt(orders.size(), SEEDS * 9 / 10, "orders")
	assert_gt(last.size(), 3, "the shapes of the ninth storey: %s" % [last.keys()])


func test_no_three_storeys_in_a_row_share_a_light() -> void:
	for seed_value in SEEDS:
		for depth in range(3, World.FLOORS + 1):
			var row := range(depth - 2, depth + 1).map(func(d): return RunPlan.light(seed_value, d))
			assert_false(row[0] == row[1] and row[1] == row[2], "seed %d %s" % [seed_value, row])


func _lanterns(light: float) -> float:
	var seeds := range(SEEDS).filter(func(s): return RunPlan.light(s, 5) == light).slice(0, 12)
	var count := 0
	for seed_value: int in seeds:
		count += Built.storey(seed_value, 5, Skeletons.TOWERS).tiles.count(World.LANTERN)
	return float(count) / seeds.size()


func test_a_bright_storey_holds_more_lanterns_than_a_dark_one() -> void:
	assert_gt(_lanterns(RunPlan.LIGHTS[2]), _lanterns(RunPlan.LIGHTS[0]) + 2.0)


func _tiles_on(element: StringName, kind: int) -> int:
	var seeds := range(SEEDS).filter(
		func(s): return RunPlan.element(s, 5, Skeletons.TOWERS) == element
	)
	var count := 0
	for seed_value: int in seeds.slice(0, 12):
		count += Built.storey(seed_value, 5, Skeletons.TOWERS).tiles.count(kind)
	return count


func test_a_storey_of_metal_grows_no_grass_where_one_of_wood_grows_plenty() -> void:
	assert_eq(_tiles_on(Cards.METAL, World.GRASS), 0)
	assert_gt(_tiles_on(Cards.WOOD, World.GRASS), 12 * 4)


func test_a_storey_of_fire_lays_far_more_straw_than_one_of_water() -> void:
	assert_gt(_tiles_on(Cards.FIRE, World.STRAW), _tiles_on(Cards.WATER, World.STRAW) * 2)


func test_the_elements_of_a_run_follow_one_another_by_what_each_grows_into() -> void:
	for seed_value in 20:
		for depth in range(2, World.FLOORS + 1):
			assert_eq(
				RunPlan.element(seed_value, depth, Skeletons.RING),
				Cards.GROWS[RunPlan.element(seed_value, depth - 1, Skeletons.RING)]
			)


func test_a_whole_run_keeps_the_rules_on_every_storey_it_climbs() -> void:
	for seed_value in CLIMBED:
		var w := World.create(seed_value)
		for depth in range(2, World.FLOORS + 1):
			Storeys.leave(w)
			Storeys.enter(w, depth)
			assert_eq(
				MAPS.faults(w), [] as Array[String], "seed %d storey %d" % [seed_value, depth]
			)
		assert_true(Grid.inside(w.elixir), "seed %d holds the elixir" % seed_value)
		assert_true(
			w.actors.any(func(a): return Bestiary.info(a.kind).get("boss", false)),
			"seed %d holds the boss" % seed_value
		)
