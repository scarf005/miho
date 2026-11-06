extends GutTest
## 지도 생성 (Cheat generate): the storey Miho is on built again in place on a chosen
## storey, shape, 미궁 and seed, each left empty for the one the seed draws as a run does.

const DEPTHS: Array[int] = [1, 5, 9]
const SEED := 21


func _gen(w: World, depth: int, shape := &"", concept := &"", seed_value := SEED) -> Array:
	var action := {
		t = &"cheat",
		cmd = &"generate",
		depth = depth,
		shape = shape,
		concept = concept,
		seed_value = seed_value,
	}
	assert_true(w.can(action), str(action))
	return w.act(action)


## Storey `depth` of a run on `seed_value` built on `shape`, as a run builds a storey.
func _built(seed_value: int, depth: int, shape: StringName) -> World:
	var w := Built.world(1)
	w.depth = depth
	w.rng.seed = seed_value
	FloorGen.storey(w, shape)
	return w


## The first seed whose run draws a maze of `concept`.
func _seed_of(concept: StringName) -> int:
	var s := 0
	while RunPlan.labyrinth(s).concept != concept:
		s += 1
	return s


func test_each_shape_is_built_on_the_first_middle_and_last_storey_with_miho_at_its_start() -> void:
	for depth in DEPTHS:
		var maps := {}
		for shape in Skeletons.ALL:
			var w := Built.world(SEED)
			_gen(w, depth, shape)
			var label := "%s on %d" % [shape, depth]
			assert_eq(w.tiles, _built(SEED, depth, shape).tiles, label)
			assert_eq(w.depth, depth, label)
			assert_eq(w.player().pos, w.start, label)
			maps[w.tiles] = true
		assert_eq(maps.size(), Skeletons.ALL.size(), "every shape differs on %d" % depth)


func test_each_maze_concept_is_built_and_the_run_s_own_matches_the_seed_s_draw() -> void:
	for concept in Labyrinth.CONCEPTS:
		var s := _seed_of(concept)
		var drawn := Built.world(1)
		_gen(drawn, 5, Skeletons.LABYRINTH, &"", s)
		for other in Labyrinth.CONCEPTS:
			var w := Built.world(1)
			_gen(w, 5, Skeletons.LABYRINTH, other, s)
			var label := "%s on the seed of %s" % [other, concept]
			assert_eq(w.tiles == drawn.tiles, other == concept, label)
			assert_eq(Labyrinth.site(w).island.has_area(), other == Labyrinth.ISLAND, label)


func test_the_same_seed_and_picks_build_the_same_storey_twice() -> void:
	var w := Built.world(SEED)
	_gen(w, 4, Skeletons.RING)
	var first := w.clone()
	w.act({t = &"wait"})
	_gen(w, 4, Skeletons.RING)
	assert_eq(w.tiles, first.tiles)
	assert_eq(w.start, first.start)
	var kinds := func(x: World): return x.actors.map(func(a): return [a.kind, a.pos])
	assert_eq(kinds.call(w), kinds.call(first))
	_gen(w, 4, Skeletons.RING, &"", SEED + 1)
	assert_ne(w.tiles, first.tiles, "the next seed builds another")


func test_a_storey_with_nothing_picked_is_the_one_a_run_on_the_seed_builds() -> void:
	var run := World.create(SEED)
	var w := Built.world(SEED + 5)
	_gen(w, 1)
	assert_eq(w.tiles, run.tiles)
	assert_eq(w.player().pos, run.player().pos)


func test_a_build_shows_the_whole_storey_lit_and_seen_and_keeps_creatures_still() -> void:
	var w := Built.world(SEED)
	for i in 2:
		_gen(w, 3)
		assert_true(Cheat.on(w, &"reveal"), "build %d" % i)
		assert_true(Cheat.on(w, &"halt"), "build %d" % i)
		assert_false(w.seen.has(0), "every tile seen")
	var foes := w.actors.slice(1).map(func(a): return a.pos)
	assert_false(foes.is_empty())
	for i in 3:
		w.act({t = &"wait"})
	assert_eq(w.actors.slice(1).map(func(a): return a.pos), foes)


func test_the_log_line_names_the_seed_storey_shape_element_light_and_set_room() -> void:
	var w := Built.world(SEED)
	var before := w.clone()
	var told := Messages.of(before, w, _gen(w, 6, &"", &"", SEED))
	assert_eq(told.size(), 1)
	var line := Messages.plain(told[0])
	var shape: StringName = RunPlan.shapes(SEED)[5]
	assert_string_contains(line, str(SEED))
	assert_string_contains(line, Lang.t("%d층") % 6)
	assert_string_contains(line, Skeletons.NAME[shape])
	assert_string_contains(line, Cards.NAME[RunPlan.element(SEED, 6, shape)])
	var light := RunPlan.LIGHTS.find(RunPlan.light(SEED, 6))
	assert_string_contains(line, RunPlan.LIGHT_NAME[light])
	var ref := Built.world(1)
	ref.depth = 6
	ref.rng.seed = SEED
	var made := FloorGen.storey(ref, shape)
	assert_false(made.is_empty(), "a storey with a set room")
	assert_string_contains(line, SetRooms.NAME[made.kind])


func test_a_maze_names_its_concept_in_the_log_line() -> void:
	var w := Built.world(SEED)
	var before := w.clone()
	var told := Messages.of(before, w, _gen(w, 5, Skeletons.LABYRINTH, Labyrinth.CELLS))
	assert_string_contains(Messages.plain(told[0]), Labyrinth.NAME[Labyrinth.CELLS])


func test_a_storey_shape_or_concept_the_tables_do_not_have_is_refused() -> void:
	var w := Built.world(SEED)
	var good := {
		t = &"cheat", cmd = &"generate", depth = 2, shape = &"", concept = &"", seed_value = 1
	}
	assert_true(w.can(good))
	for bad in [
		{depth = 0},
		{depth = World.FLOORS + 1},
		{shape = &"nowhere"},
		{concept = &"nowhere"},
		{seed_value = "1"},
	]:
		assert_false(w.can(good.merged(bad, true)), str(bad))
