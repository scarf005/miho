extends GutTest
## Walks planned from what Miho knows, and when they stop.


## An open hall walled at the edges, every tile known and seen, Miho at (4, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	return w


func _forget(w: World, from: Vector2i, to: Vector2i) -> void:
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			w.known[Grid.index(Vector2i(x, y))] = 0
			w.seen[Grid.index(Vector2i(x, y))] = 0


func _steps_are_single(w: World, path: Array[Vector2i]) -> bool:
	var at := w.player().pos
	for p in path:
		if Grid.cheb(p, at) != 1:
			return false
		at = p
	return true


func test_a_route_is_shortest_in_eight_directions() -> void:
	var w := _world()
	var path := Travel.route(Travel.search(w), Vector2i(10, 5))
	assert_eq(path.size(), 6)
	assert_eq(path.back(), Vector2i(10, 5))
	assert_true(_steps_are_single(w, path))


func test_a_route_goes_around_unknown_tiles() -> void:
	var w := _world()
	_forget(w, Vector2i(10, 1), Vector2i(10, Grid.H - 3))
	var path := Travel.route(Travel.search(w), Vector2i(16, 8))
	assert_false(path.is_empty())
	assert_true(path.has(Vector2i(10, Grid.H - 2)), "through the one known gap")
	for p in path:
		assert_eq(w.known[Grid.index(p)], 1, "%s is known" % p)
	assert_true(_steps_are_single(w, path))


func test_a_route_steps_around_creatures_in_sight_only() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"jangseung", Vector2i(6, 8))
	var path := Travel.route(Travel.search(w), Vector2i(8, 8))
	assert_eq(path.size(), 4)
	assert_false(path.has(foe.pos))
	w.seen[Grid.index(foe.pos)] = 0
	var unseen := Travel.route(Travel.search(w), Vector2i(8, 8))
	foe.hp = 0
	assert_eq(unseen, Travel.route(Travel.search(w), Vector2i(8, 8)), "hidden ones change nothing")


func test_unreachable_or_unknown_goals_have_no_route() -> void:
	var w := _world()
	_forget(w, Vector2i(20, 1), Vector2i(20, Grid.H - 2))
	var found := Travel.search(w)
	assert_true(Travel.route(found, Vector2i(25, 8)).is_empty(), "behind the unknown")
	assert_true(Travel.route(found, Vector2i(20, 8)).is_empty(), "unknown itself")
	assert_true(Travel.route(found, Vector2i(0, 0)).is_empty(), "a wall")
	assert_true(Travel.route(found, w.player().pos).is_empty(), "where she stands")


func test_exploring_heads_for_the_nearest_unexplored_edge() -> void:
	var w := _world()
	_forget(w, Vector2i(12, 0), Vector2i(Grid.W - 1, Grid.H - 1))
	_forget(w, Vector2i(0, 0), Vector2i(1, 12))
	var found := Travel.search(w)
	assert_eq(Travel.frontier(w, found), Vector2i(2, 8))
	assert_eq(Travel.explore_step(w, found), Vector2i(-1, 0))
	_forget(w, Vector2i(0, 0), Vector2i(Grid.W - 1, Grid.H - 1))
	w.known[Grid.index(w.player().pos)] = 1
	assert_eq(Travel.explore_step(w, Travel.search(w)), Vector2i.ZERO, "nowhere known to go")


func test_explored_storeys_lead_beside_the_known_stairs() -> void:
	var w := _world()
	w.stairs = Vector2i(9, 8)
	var found := Travel.search(w)
	assert_eq(Travel.frontier(w, found), Vector2i(-1, -1))
	assert_eq(Travel.exit(w), w.stairs)
	assert_eq(Travel.explore_step(w, found), Vector2i(1, 0))
	w.player().pos = Vector2i(8, 8)
	assert_eq(Travel.explore_step(w, Travel.search(w)), Vector2i.ZERO, "stops beside them")
	w.known[Grid.index(w.stairs)] = 0
	assert_eq(Travel.exit(w), Vector2i(-1, -1), "unseen stairs are not a goal")


func test_a_walk_stops_when_a_new_creature_comes_into_sight() -> void:
	var w := _world()
	var old := FloorGen.spawn(w, &"jangseung", Vector2i(12, 8))
	var sighted := Travel.in_sight(w)
	var after := w.clone()
	assert_false(Travel.interrupted(w, after, [], sighted), "one already in sight")
	var foe := FloorGen.spawn(after, &"dokkaebi", Vector2i(14, 3))
	after.seen[Grid.index(foe.pos)] = 0
	assert_false(Travel.interrupted(w, after, [], sighted), "one out of sight")
	after.seen[Grid.index(foe.pos)] = 1
	assert_true(Travel.interrupted(w, after, [], sighted))
	assert_true(sighted.has(old.id))


func test_a_walk_stops_on_harm_noise_notice_and_talismans() -> void:
	var w := _world()
	var after := w.clone()
	var me := w.player().id
	assert_true(
		Travel.interrupted(
			w, after, [{t = &"hurt", id = me, n = 1, hp = 2, at = Vector2i(4, 8)}], {}
		)
	)
	assert_false(
		Travel.interrupted(
			w, after, [{t = &"hurt", id = 99, n = 1, hp = 0, at = Vector2i(5, 8)}], {}
		)
	)
	assert_true(
		Travel.interrupted(w, after, [{t = &"card", card = Cards.FIRE, at = Vector2i(5, 8)}], {})
	)
	var notice := {t = &"notice", id = 99, at = Vector2i(12, 8)}
	assert_true(Travel.interrupted(w, after, [notice], {}))
	w.seen[Grid.index(notice.at)] = 0
	after.seen[Grid.index(notice.at)] = 0
	assert_false(Travel.interrupted(w, after, [notice], {}), "a notice out of sight stays hidden")
	after.heard.append({at = Vector2i(20, 3), word = "탁"})
	assert_true(Travel.interrupted(w, after, [], {}))


func test_a_walk_stops_when_the_stairs_or_a_peach_first_come_into_sight() -> void:
	var w := _world()
	w.stairs = Vector2i(12, 8)
	w.known[Grid.index(w.stairs)] = 0
	var after := w.clone()
	after.seen[Grid.index(w.stairs)] = 0
	assert_false(Travel.interrupted(w, after, [], {}), "stairs out of sight")
	after.seen[Grid.index(w.stairs)] = 1
	assert_true(Travel.interrupted(w, after, [], {}))
	w.known[Grid.index(w.stairs)] = 1
	assert_false(Travel.interrupted(w, after, [], {}), "stairs seen before")
	after.peaches.append(Vector2i(14, 8))
	assert_true(Travel.interrupted(w, after, [], {}))


func test_a_walk_stops_when_the_storey_changes() -> void:
	var w := _world()
	var after := w.clone()
	after.depth += 1
	assert_true(Travel.interrupted(w, after, [], {}))


func test_a_route_steps_around_fire_in_sight() -> void:
	var w := _world()
	w.burning[Vector2i(6, 8)] = 2
	var path := Travel.route(Travel.search(w), Vector2i(8, 8))
	assert_eq(path.size(), 4)
	assert_false(path.has(Vector2i(6, 8)))
	assert_true(Travel.near_fire(w, Vector2i(5, 8)))
	assert_true(Travel.near_fire(w, Vector2i(6, 8)))
	assert_false(Travel.near_fire(w, Vector2i(4, 8)))
	w.seen[Grid.index(Vector2i(6, 8))] = 0
	assert_false(Travel.near_fire(w, Vector2i(5, 8)), "fire out of sight is not known")
