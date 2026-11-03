extends GutTest
## Travel exclusions: what a zone covers, how walks and exploring go around
## it, and that a run keeps its zones.

const PATH := "user://test_exclusions.cfg"


func after_each() -> void:
	SaveGame.new(PATH).erase()


## An open hall walled at the edges, every tile known, Miho at (4, 8).
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


## A wall down column x with a gap at (x, 8).
func _wall_with_gap(w: World, x: int) -> void:
	for y in range(1, Grid.H - 1):
		if y != 8:
			w.tiles[Grid.index(Vector2i(x, y))] = World.WALL


func _zone(at: Vector2i, radius: int) -> Exclusions:
	var ex := Exclusions.new()
	ex.zones[at] = radius
	return ex


func _press(key: String) -> InputEventKey:
	var e := Keys.event(key)
	e.pressed = true
	return e


func test_a_zone_covers_the_square_around_its_centre() -> void:
	var covered := _zone(Vector2i(20, 10), 2).tiles(_world())
	assert_eq(covered.size(), 25)
	assert_true(covered.has(Vector2i(22, 12)))
	assert_false(covered.has(Vector2i(23, 10)))


func test_a_radius_of_zero_covers_the_tile_alone() -> void:
	assert_eq(_zone(Vector2i(20, 10), 0).tiles(_world()).keys(), [Vector2i(20, 10)])


func test_a_zone_does_not_reach_past_a_wall() -> void:
	var w := _world()
	_wall_with_gap(w, 21)
	var covered := _zone(Vector2i(20, 3), 4).tiles(w)
	assert_true(covered.has(Vector2i(20, 6)))
	assert_false(covered.has(Vector2i(23, 3)), "the wall hides what is behind it")


func test_a_zone_covers_known_tiles_only() -> void:
	var w := _world()
	w.known[Grid.index(Vector2i(21, 10))] = 0
	assert_false(_zone(Vector2i(20, 10), 2).tiles(w).has(Vector2i(21, 10)))


func test_the_mark_key_cycles_default_radius_then_one_tile_then_off() -> void:
	var ex := Exclusions.new()
	var at := Vector2i(7, 7)
	ex.cycle(at)
	assert_eq(ex.zones, {at: Exclusions.DEFAULT_RADIUS})
	ex.cycle(at)
	assert_eq(ex.zones, {at: 0})
	ex.cycle(at)
	assert_true(ex.is_empty())


func test_a_radius_is_kept_between_one_and_the_most() -> void:
	var ex := Exclusions.new()
	ex.set_radius(Vector2i(7, 7), 3)
	assert_eq(ex.zones[Vector2i(7, 7)], 3)
	ex.set_radius(Vector2i(7, 7), 0)
	assert_eq(ex.zones[Vector2i(7, 7)], 1)
	ex.set_radius(Vector2i(7, 7), 99)
	assert_eq(ex.zones[Vector2i(7, 7)], Exclusions.MAX_RADIUS)


func test_clearing_removes_every_zone() -> void:
	var ex := _zone(Vector2i(7, 7), 2)
	ex.cycle(Vector2i(9, 9))
	ex.clear()
	assert_true(ex.is_empty())


func test_a_zone_around_miho_is_left_out_so_she_can_walk_out() -> void:
	var w := _world()
	var ex := _zone(Vector2i(6, 8), 3)
	assert_true(ex.tiles(w, Vector2i(4, 8)).is_empty())
	assert_false(ex.tiles(w, Vector2i(20, 8)).is_empty())


func test_walks_go_around_a_zone() -> void:
	var w := _world()
	var avoid := _zone(Vector2i(10, 8), 2).tiles(w)
	var path := Travel.route(Travel.search(w, avoid), Vector2i(16, 8))
	assert_false(path.is_empty())
	assert_true(path.all(func(p): return not avoid.has(p)))
	assert_eq(path.size(), 12, "the detour costs no more than the straight 12 steps")


func test_a_walk_that_must_cross_a_zone_has_no_route() -> void:
	var w := _world()
	_wall_with_gap(w, 10)
	var goal := Vector2i(16, 8)
	var avoid := _zone(Vector2i(10, 8), 0).tiles(w)
	assert_true(Travel.route(Travel.search(w, avoid), goal).is_empty())
	assert_false(Travel.route(Travel.search(w), goal).is_empty(), "open without the zone")


func test_exploring_stops_when_only_the_zone_leads_to_unexplored_ground() -> void:
	var w := _world()
	_wall_with_gap(w, 8)
	for y in Grid.H:
		for x in range(13, Grid.W):
			w.known[Grid.index(Vector2i(x, y))] = 0
			w.seen[Grid.index(Vector2i(x, y))] = 0
	var avoid := _zone(Vector2i(8, 8), 0).tiles(w)
	assert_ne(Travel.explore_step(w, Travel.search(w)), Vector2i.ZERO, "the gap leads on")
	assert_eq(Travel.explore_step(w, Travel.search(w, avoid)), Vector2i.ZERO)


func test_a_run_saves_and_loads_its_zones() -> void:
	var run := SaveGame.new(PATH, 2)
	run.exclusions = {Vector2i(7, 7): 5, Vector2i(9, 3): 0}
	run.record({t = &"wait"}, 0, false)
	run.flush()
	var back := SaveGame.load_from(PATH)
	assert_eq(back.exclusions, run.exclusions)
	assert_true(back.replay(), "zones do not touch the replay")
	var live := World.create(2)
	live.act({t = &"wait"})
	assert_eq(back.world.rng.state, live.rng.state)


func test_a_save_with_malformed_zones_still_loads_without_them() -> void:
	var c := ConfigFile.new()
	c.set_value("run", "version", SaveGame.VERSION)
	c.set_value("run", "seed", 2)
	c.set_value("run", "kills", 0)
	c.set_value("run", "actions", [])
	c.set_value("run", "exclusions", {"here": "big"})
	c.save(PATH)
	var back := SaveGame.load_from(PATH)
	assert_not_null(back)
	assert_true(back.exclusions.is_empty())


func test_a_save_from_before_zones_loads_with_none() -> void:
	var c := ConfigFile.new()
	c.set_value("run", "version", SaveGame.VERSION)
	c.set_value("run", "seed", 2)
	c.set_value("run", "kills", 0)
	c.set_value("run", "actions", [])
	c.save(PATH)
	assert_true(SaveGame.load_from(PATH).exclusions.is_empty())


func test_the_keys_are_bound_and_listed_in_help() -> void:
	Keys.reset()
	assert_eq(Keys.action_of(_press("V")), &"exclude")
	assert_eq(Keys.action_of(_press("Shift+V")), &"exclude_clear")
	var menu := Menu.new()
	menu.open(&"help")
	var rows: Array = menu.panel().rows
	var text := Info.plain(rows.map(func(r): return r.map(func(run): return [run[0] + " "])))
	assert_string_contains(text, "위험구역 표시 V")
	assert_string_contains(text, "위험구역 모두 지우기 Shift+V")
