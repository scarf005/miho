extends GutTest
## The creatures of a storey: those of PLAN's row that come in no band stand as listed, and
## those that band are drawn from the world's rng within a health budget.

const SEEDS := [1, 2, 3, 5, 8]
const DRAWS := 40


## The health the banding kinds of PLAN's row for `w`'s storey have, half of it beside a maze.
func _budget(w: World) -> int:
	var r := Bestiary.rank(w.depth)
	var out := 0
	for kind: StringName in FloorGen.PLAN[w.depth]:
		if Bestiary.bands(kind):
			out += Bestiary.hp(kind, r)
	return out / 2 if not Labyrinth.site(w).is_empty() else out


## The storeys whose PLAN row holds `kind`.
func _storeys(kind: StringName) -> Array:
	return FloorGen.PLAN.keys().filter(func(d): return FloorGen.PLAN[d].has(kind))


## The kinds `w` holds that the storey did not put there for an event room.
func _placed(w: World) -> Array:
	var guards := w.sites.filter(func(s): return s.kind == &"creak").map(func(s): return s.id)
	return (
		w
		. actors
		. slice(1)
		. filter(func(a): return not a.brain.guard and not guards.has(a.id))
		. map(func(a): return a.kind)
	)


func test_the_creatures_that_walk_alone_stand_as_plan_lists_them() -> void:
	for seed_value: int in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := Built.storey(seed_value, depth)
			if not Labyrinth.site(w).is_empty():
				continue
			var stands := func(k): return not Bestiary.bands(k) and not Bestiary.swims(k)
			var got := _placed(w).filter(stands)
			var want: Array = FloorGen.PLAN[depth].filter(stands)
			if depth < World.FLOORS:
				want = want.filter(func(k): return not Bestiary.info(k).get("boss", false))
			got.sort()
			want.sort()
			assert_eq(got, want, "seed %d storey %d" % [seed_value, depth])


func test_the_drawn_health_reaches_the_budget_and_passes_it_by_less_than_one_kind() -> void:
	for depth in range(1, World.FLOORS + 1):
		var w := Built.storey(1, depth)
		var r := Bestiary.rank(depth)
		for k in DRAWS:
			w.rng.seed = k
			var drawn := Roster.drawn(w, Cards.ELEMENTS[k % Cards.ELEMENTS.size()])
			var health: Array = drawn.map(func(kind): return Bestiary.hp(kind, r))
			var total: int = health.reduce(func(a, b): return a + b, 0)
			var label := "storey %d draw %d" % [depth, k]
			assert_gte(total, _budget(w), label)
			assert_lt(total - _budget(w), health.max(), label)


func test_a_maze_halves_the_budget() -> void:
	var w := Built.storey(2, 5)
	w.sites = w.sites.filter(func(s): return s.kind != &"labyrinth")
	var whole := _budget(w)
	w.sites.append({kind = &"labyrinth"})
	w.rng.seed = 4
	var r := Bestiary.rank(5)
	var drawn := Roster.drawn(w, Cards.WOOD)
	var total: int = drawn.map(func(k): return Bestiary.hp(k, r)).reduce(func(a, b): return a + b)
	assert_gte(total, whole / 2)
	assert_lt(total, whole)


func test_only_kinds_within_their_storeys_and_at_most_three_groups_come() -> void:
	for depth in range(1, World.FLOORS + 1):
		var w := Built.storey(3, depth)
		for k in DRAWS:
			w.rng.seed = k
			var groups := {}
			for kind: StringName in Roster.drawn(w, Cards.ELEMENTS[k % Cards.ELEMENTS.size()]):
				var on := _storeys(kind)
				var label := "storey %d draw %d %s" % [depth, k, kind]
				assert_true(Bestiary.bands(kind), label)
				assert_true(on.min() <= depth and depth <= on.max(), label)
				groups[Bestiary.info(kind).group] = true
			assert_between(groups.size(), 1, 3, "storey %d draw %d" % [depth, k])


func test_a_kind_comes_more_often_on_a_storey_of_its_element_than_one_that_beats_it() -> void:
	var cases := []
	for depth: int in FloorGen.PLAN:
		for kind: StringName in FloorGen.PLAN[depth].filter(Bestiary.bands):
			var own := Bestiary.elements(kind)
			for storey: StringName in Cards.ELEMENTS:
				var beats: bool = own.has(Cards.BEATS[storey])
				if beats and not own.has(storey) and not own.has(Cards.GROWS[storey]):
					cases.append([depth, kind, own[0], storey])
	assert_gt(cases.size(), 0, "some kind is of an element some storey beats")
	var case: Array = cases[0]
	var w := Built.storey(1, case[0])
	var counts := []
	for element: StringName in case.slice(2):
		var count := 0
		for k in DRAWS * 5:
			w.rng.seed = k
			count += Roster.drawn(w, element).count(case[1])
		counts.append(count)
	assert_gt(counts[0], counts[1], "%s" % [case])


func test_one_seed_builds_the_same_creatures_and_seeds_differ() -> void:
	var lists := {}
	for seed_value: int in SEEDS:
		var a := World.create(seed_value)
		var b := World.create(seed_value)
		var kinds := a.actors.map(func(x): return [x.kind, x.pos])
		assert_eq(kinds, b.actors.map(func(x): return [x.kind, x.pos]), "seed %d" % seed_value)
		lists[str(a.actors.map(func(x): return x.kind))] = true
	assert_gt(lists.size(), 1, "the creatures differ from seed to seed")
