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
