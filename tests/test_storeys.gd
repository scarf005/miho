extends GutTest
## The 27 storeys: their creatures, peaches and exits.

const SEEDS := 4


func _built(seed_value: int, depth: int) -> World:
	var w := World.create(seed_value)
	w.depth = depth
	FloorGen.build(w)
	return w


func _bosses(w: World) -> int:
	return w.actors.filter(func(a): return Bestiary.info(a.kind).get("boss", false)).size()


func test_the_tower_has_twenty_seven_storeys() -> void:
	assert_eq(World.FLOORS, 27)


func test_difficulty_steps_up_every_third_storey() -> void:
	var w := World.create(1)
	for case in [[1, 1], [3, 1], [4, 2], [25, 9], [27, 9]]:
		w.depth = case[0]
		assert_eq(w.tier(), case[1], "storey %d" % case[0])


func test_the_boss_waits_only_on_the_last_storey() -> void:
	for seed_value in SEEDS:
		for depth in [24, 25, 26, 27]:
			var w := _built(seed_value, depth)
			var label := "seed %d storey %d" % [seed_value, depth]
			assert_eq(_bosses(w), 1 if depth == 27 else 0, label)
		assert_eq(_built(seed_value, 26).actors.size() - 1, FloorGen.PLAN[9].size() - 1)


func test_peaches_grow_on_odd_storeys_from_the_third() -> void:
	for depth in range(1, World.FLOORS + 1):
		var w := _built(1, depth)
		var grows := depth >= 3 and depth % 2 == 1
		assert_eq(w.peaches.size(), 1 if grows else 0, "storey %d" % depth)


func test_the_elixir_is_on_storey_27_and_the_stairs_below() -> void:
	for seed_value in SEEDS:
		var last := _built(seed_value, 27)
		assert_true(last.elixir.x >= 0 and last.stairs.x < 0, "seed %d storey 27" % seed_value)
		var below := _built(seed_value, 26)
		assert_true(below.stairs.x >= 0 and below.elixir.x < 0, "seed %d storey 26" % seed_value)


func test_the_status_row_fits_nine_tails_and_the_saved_spells() -> void:
	var t: Term = autofree(Term.new())
	t.world = _built(1, 25)
	t.saved = {&"slot_1": "fox+fire", &"slot_2": "orb+water+wood"}
	t.fit(Vector2(1280, 720), 0.0)
	var slots := t._slots()
	assert_eq(t.world.max_tails(), 9)
	assert_eq(slots.size(), 2)
	assert_gt(slots[0].x, Term.MAP.x + 9.0, "saved spells start after the ninth tail")
	var right := "%d층 %d초" % [27, 999]
	var last: Dictionary = slots[-1]
	assert_lt(last.x + last.width, t.cols - t._cells(right) - t._cells("디버그") - 1)
