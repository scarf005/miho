extends GutTest
## The nine storeys: their creatures, peaches and exits.

const SEEDS := 4


func _built(seed_value: int, depth: int) -> World:
	var w := Built.storey(seed_value, depth)
	return w


func _bosses(w: World) -> int:
	return w.actors.filter(func(a): return Bestiary.info(a.kind).get("boss", false)).size()


func test_the_tower_has_nine_storeys() -> void:
	assert_eq(World.FLOORS, 9)


func test_each_storey_has_its_own_creatures_and_one_tail_more() -> void:
	var w := Built.world(1)
	for depth in range(1, World.FLOORS + 1):
		w.depth = depth
		assert_true(FloorGen.PLAN.has(depth), "storey %d" % depth)
		assert_eq(w.max_tails(), depth, "storey %d" % depth)


func test_the_boss_waits_only_on_the_last_storey() -> void:
	for seed_value in SEEDS:
		for depth in [6, 7, 8, 9]:
			var w := _built(seed_value, depth)
			var label := "seed %d storey %d" % [seed_value, depth]
			assert_eq(_bosses(w), 1 if depth == 9 else 0, label)
		var eighth := _built(seed_value, 8)
		var guards := eighth.sites.filter(func(s): return s.kind == &"yard").size()
		var alone := func(k): return not Bestiary.swims(k) and not Bestiary.bands(k)
		var walkers := eighth.actors.filter(func(a): return alone.call(a.kind)).size() - 1
		var want := Roster.fixed(eighth).filter(alone).size() + guards
		assert_eq(walkers, want, "seed %d" % seed_value)


func test_peaches_grow_on_odd_storeys_from_the_third() -> void:
	for depth in range(1, World.FLOORS + 1):
		var w := _built(1, depth)
		var grows := depth >= 3 and depth % 2 == 1
		var loose := w.peaches.filter(func(p): return w.rooms.any(func(r): return r.has_point(p)))
		assert_eq(loose.size(), 1 if grows else 0, "storey %d" % depth)


func test_the_elixir_is_on_storey_9_and_the_stairs_below() -> void:
	for seed_value in SEEDS:
		var last := _built(seed_value, 9)
		assert_true(last.elixir.x >= 0 and last.stairs.x < 0, "seed %d storey 9" % seed_value)
		var below := _built(seed_value, 8)
		assert_true(below.stairs.x >= 0 and below.elixir.x < 0, "seed %d storey 8" % seed_value)


func test_the_status_row_fits_nine_tails_and_the_saved_spells() -> void:
	var t: Term = autofree(Term.new())
	t.world = _built(1, 9)
	t.saved = {&"slot_1": "fox+fire", &"slot_2": "orb+water+wood"}
	t.fit(Vector2(1280, 720), 0.0)
	var slots := StatusBar.saved_slots(t)
	assert_eq(t.world.max_tails(), 9)
	assert_eq(slots.size(), 2)
	assert_gt(slots[0].x, Term.MAP.x + 9.0, "saved spells start after the ninth tail")
	var right := "%d층 %d초" % [World.FLOORS, 999]
	var last: Dictionary = slots[-1]
	assert_lt(last.x + last.width, t.cols - t.text_cells(right) - t.text_cells("디버그") - 1)


func test_a_longer_saved_spell_key_pushes_the_next_spell_along() -> void:
	var t: Term = autofree(Term.new())
	t.world = _built(1, 1)
	t.saved = {&"slot_1": "fox+fire", &"slot_2": "orb+water"}
	t.fit(Vector2(1280, 720), 0.0)
	var short: float = StatusBar.saved_slots(t)[1].x
	var keys := Keys.keys_of(&"slot_1")
	Keys.bind(&"slot_1", ["Ctrl+Shift+Q"])
	var slots := StatusBar.saved_slots(t)
	assert_gt(slots[1].x, short)
	var hit := StatusBar.slot_at(t, Vector2(slots[1].x + 0.1, t.rows - 2) * Term.CELL)
	Keys.bind(&"slot_1", keys)
	assert_eq(hit, "orb+water")


func test_a_new_storey_starts_with_none_of_the_last_one_wet_or_wild() -> void:
	var w := World.create(3)
	w.wet[w.start] = 3
	w.wild[w.start] = true
	Round.ascend(w)
	assert_eq(w.depth, 2)
	assert_eq(w.wet, {})
	assert_eq(w.wild, {})
