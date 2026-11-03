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


func test_exploring_eats_a_known_peach_before_the_unexplored_edge() -> void:
	var w := _world()
	_forget(w, Vector2i(0, 0), Vector2i(1, 12))
	w.peaches = [Vector2i(9, 8), Vector2i(4, 12)]
	w.known[Grid.index(Vector2i(4, 12))] = 0
	assert_eq(
		Travel.explore_step(w, Travel.search(w)), Vector2i(1, 0), "the known one, not the edge"
	)
	w.peaches = [Vector2i(4, 12)]
	assert_eq(
		Travel.explore_step(w, Travel.search(w)), Vector2i(-1, 0), "an unknown one is no goal"
	)
	w.stairs = Vector2i(5, 8)
	_forget(w, Vector2i(0, 0), Vector2i(0, 0))
	w.known.fill(1)
	w.peaches = [Vector2i(9, 8)]
	assert_eq(Travel.explore_step(w, Travel.search(w)), Vector2i(1, 0), "before the stairs too")


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
	w.known[Grid.index(Vector2i(14, 8))] = 0
	assert_true(Travel.interrupted(w, after, [], {}))


func test_exploring_waits_while_an_awake_creature_is_in_sight() -> void:
	var w := _world()
	assert_false(Travel.watched(w))
	var foe := FloorGen.spawn(w, &"imugi", Vector2i(12, 8))
	foe.brain.home = foe.pos
	assert_true(foe.asleep())
	assert_false(Travel.watched(w), "one asleep")
	foe.pos += Vector2i(1, 0)
	assert_true(Travel.watched(w))
	w.seen[Grid.index(foe.pos)] = 0
	assert_false(Travel.watched(w), "one out of sight")


func test_exploring_takes_no_step_while_an_awake_creature_is_in_sight() -> void:
	var w := _world()
	_forget(w, Vector2i(0, 0), Vector2i(1, 12))
	var foe := FloorGen.spawn(w, &"dokkaebi", Vector2i(12, 8))
	assert_false(foe.asleep())
	assert_eq(Travel.explore_step(w, Travel.search(w)), Vector2i.ZERO)
	w.seen[Grid.index(foe.pos)] = 0
	assert_eq(Travel.explore_step(w, Travel.search(w)), Vector2i(-1, 0), "one out of sight")
	w.seen[Grid.index(foe.pos)] = 1
	foe.hp = 0
	assert_eq(Travel.explore_step(w, Travel.search(w)), Vector2i(-1, 0), "a fallen one")


## The storey's creatures walk in and out of sight, so the ground they block
## changes every round; on these seeds Miho used to step back and forth between
## two tiles.
func test_exploring_a_storey_with_creatures_never_steps_back_and_forth() -> void:
	for seed_value in [2, 6, 7, 12]:
		var w := Built.world(seed_value)
		var memory := Sightings.new()
		var trail: Array[Vector2i] = []
		for r in 400:
			memory.update(w)
			var d := Travel.explore_step(w, Travel.search(w, memory.at))
			if d == Vector2i.ZERO or w.depth != 1:
				break
			var action := {t = &"move", dir = d} if w.tails >= w.max_tails() else {t = &"wait"}
			assert_true(w.can(action), "seed %d round %d" % [seed_value, w.round_no])
			if action.t == &"move":
				trail.append(w.player().pos)
			var back := trail.size() >= 4 and trail[-1] == trail[-3] and trail[-2] == trail[-4]
			assert_false(back, "seed %d round %d: %s" % [seed_value, w.round_no, trail.slice(-4)])
			w.act(action)


func test_a_statue_in_sight_blocks_exploring_only_while_it_hunts() -> void:
	var w := _world()
	var post := FloorGen.spawn(w, &"jangseung", Vector2i(12, 8))
	assert_false(post.asleep(), "a 장승 never sleeps")
	assert_true(Travel.in_sight(w).has(post.id))
	assert_false(Travel.watched(w), "it has not noticed her and cannot walk into her way")
	post.brain.alert = Actor.SEARCH
	assert_false(Travel.watched(w))
	post.brain.alert = Actor.HUNT
	assert_true(Travel.watched(w))
	var other := FloorGen.spawn(w, &"dokkaebi", Vector2i(13, 8))
	post.brain.alert = Actor.REST
	other.brain.home = other.pos + Vector2i(1, 0)
	assert_true(Travel.watched(w), "one that walks still counts")


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


func test_a_step_stops_a_walk_beside_fire_or_into_a_wall_but_not_away_from_them() -> void:
	var w := _world()
	w.burning[Vector2i(6, 8)] = 2
	var near := {t = &"move", dir = Vector2i.RIGHT}
	var away := {t = &"move", dir = Vector2i.LEFT}
	assert_eq(Travel.hazard(w, near, Forecast.of(w, near)), &"fire")
	assert_eq(Travel.hazard(w, away, Forecast.of(w, away)), &"")
	w.player().pos = Vector2i(1, 8)
	assert_eq(Travel.hazard(w, away, Forecast.of(w, away)), &"blocked")


func test_exploring_does_not_climb_stairs_at_the_unexplored_edge() -> void:
	var w := _world()
	w.stairs = Vector2i(5, 8)
	_forget(w, Vector2i(6, 0), Vector2i(Grid.W - 1, Grid.H - 1))
	var step := Travel.explore_step(w, Travel.search(w))
	assert_ne(step, Vector2i.ZERO, "the edge beside the stairs is still there to explore")
	assert_ne(w.player().pos + step, w.stairs)


func test_exploring_does_not_take_the_elixir_at_the_unexplored_edge() -> void:
	var w := _world()
	w.elixir = Vector2i(5, 8)
	_forget(w, Vector2i(6, 0), Vector2i(Grid.W - 1, Grid.H - 1))
	assert_ne(w.player().pos + Travel.explore_step(w, Travel.search(w)), w.elixir)


func test_a_walk_ends_on_the_stairs_and_never_goes_through_them() -> void:
	var w := _world()
	for y in Grid.H:
		w.tiles[Grid.index(Vector2i(6, y))] = World.WALL
	w.stairs = Vector2i(6, 8)
	w.tiles[Grid.index(w.stairs)] = World.FLOOR
	var found := Travel.search(w)
	assert_eq(Travel.route(found, w.stairs).back(), w.stairs, "told to go there, she can")
	assert_eq(Travel.route(found, Vector2i(9, 8)), [] as Array[Vector2i], "the far side is shut")


func test_a_hunted_stairs_tile_is_no_way_out() -> void:
	var w := _world()
	w.stairs = Vector2i(6, 8)
	var found := Travel.search(w, {w.stairs: true})
	assert_eq(Travel.route(found, w.stairs), [] as Array[Vector2i], "an exclusion holds")


func test_exploring_goes_round_stairs_straight_on_its_way_to_the_edge() -> void:
	var w := _world()
	w.stairs = Vector2i(5, 8)
	_forget(w, Vector2i(8, 0), Vector2i(Grid.W - 1, Grid.H - 1))
	var found := Travel.search(w)
	assert_false(Travel.route(found, Vector2i(7, 8)).has(w.stairs))
	assert_ne(w.player().pos + Travel.explore_step(w, found), w.stairs)


func test_a_walk_past_the_elixir_goes_round_it() -> void:
	var w := _world()
	w.elixir = Vector2i(6, 8)
	assert_false(Travel.route(Travel.search(w), Vector2i(9, 8)).has(w.elixir))
