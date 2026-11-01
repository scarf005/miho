extends GutTest
## The skeletons a storey is built on (Skeletons): links are cut only across long
## walks, and a storey can be told to have two routes to its exit.

const SEEDS := 10


func _label(w: World, kind: StringName) -> String:
	return "%s seed %d storey %d" % [kind, w.rng.seed, w.depth]


# --- two routes --------------------------------------------------------------


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


# --- far links ---------------------------------------------------------------


func test_every_link_a_storey_cut_joined_two_places_far_apart() -> void:
	for kind in Skeletons.ALL:
		var cut := 0
		for seed_value in SEEDS:
			for depth in range(1, World.FLOORS + 1):
				var w := World.create(seed_value * World.FLOORS + depth)
				w.depth = depth
				var links: Array = FloorGen._carve(w, kind).links
				cut += links.size()
				var doors := links.filter(func(l): return l.a + (l.b - l.a) / 2 == l.at)
				assert_lte(doors.size(), FloorGen.LOOPS, _label(w, kind))
				var open := Masks.floor_of(w)
				for k in range(links.size() - 1, -1, -1):
					open[Grid.index(links[k].at)] = 0
					var dist: int = Grid.search(links[k].a, open).dist[Grid.index(links[k].b)]
					assert_gte(dist, FloorGen.APART, "%s %s" % [_label(w, kind), links[k]])
		assert_gt(cut, SEEDS * World.FLOORS, "%s cuts more than one a storey" % kind)


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
