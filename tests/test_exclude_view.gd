extends GutTest
## Marking travel exclusions in look mode on the game scene, and what the
## walks do about them.

const SEED := 3


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m.new_run(SEED)
	m.state = &"play"
	return m


## An open hall walled at the edges, known except past column 12, with a wall
## down column 8 that has a gap at (8, 8); Miho at (4, 8).
func _hall() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.WALL if x == 8 and y != 8 else World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.dim.resize(w.tiles.size())
	for i in w.tiles.size():
		w.known[i] = 1 if Grid.at(i).x <= 12 else 0
	w.seen = w.known.duplicate()
	return w


## Look mode with the cursor on `tile`.
func _look(m: Node, tile: Vector2i) -> void:
	m.looking = true
	m._look_at(tile)


func test_the_mark_key_in_look_mode_marks_and_unmarks_the_cursor_tile() -> void:
	var m := _main()
	var tile: Vector2i = m.world.player().pos
	_look(m, tile)
	assert_true(m._look_key(&"exclude", false))
	assert_eq(m.excluded.zones, {tile: Exclusions.DEFAULT_RADIUS})
	assert_true(m.zone.has(tile))
	m._look_key(&"exclude", false)
	assert_eq(m.excluded.zones, {tile: 0})
	m._look_key(&"exclude", false)
	assert_true(m.excluded.is_empty())
	assert_true(m.zone.is_empty())


func test_a_digit_on_a_zone_centre_sets_its_radius() -> void:
	var m := _main()
	var tile: Vector2i = m.world.player().pos
	_look(m, tile)
	m._look_key(&"exclude", false)
	m._look_key(&"pick_2", false)
	assert_eq(m.excluded.zones[tile], 2)
	assert_eq(m.zone.size(), m.excluded.tiles(m.world).size())


func test_a_digit_elsewhere_still_picks_a_talisman() -> void:
	var m := _main()
	_look(m, m.world.player().pos)
	assert_false(m._look_key(&"pick_1", false), "left to the normal keys")
	assert_true(m.excluded.is_empty())


func test_unknown_tiles_cannot_be_marked() -> void:
	var m := _main()
	var far := Vector2i(Grid.W - 1, Grid.H - 1)
	assert_eq(m.world.known[Grid.index(far)], 0)
	_look(m, far)
	m._look_key(&"exclude", false)
	assert_true(m.excluded.is_empty())


func test_hovering_a_zone_says_so() -> void:
	var m := _main()
	var tile: Vector2i = m.world.player().pos
	_look(m, tile)
	m._look_key(&"exclude", false)
	_look(m, tile)
	var text := Info.plain(m.term.info)
	assert_string_contains(text, "위험구역 (반경 %d)" % Exclusions.DEFAULT_RADIUS)


func test_the_clear_key_removes_every_zone() -> void:
	var m := _main()
	_look(m, m.world.player().pos)
	m._look_key(&"exclude", false)
	m.looking = false
	m._key(_press("Shift+V"))
	assert_true(m.excluded.is_empty())
	assert_true(m.zone.is_empty())


func test_zones_are_kept_in_the_run_save() -> void:
	var m := _main()
	_look(m, m.world.player().pos)
	m._look_key(&"exclude", false)
	assert_eq(m.run.exclusions, m.excluded.zones)
	assert_false(m.run.exclusions.is_empty())


func test_continuing_a_run_restores_its_zones() -> void:
	var path := "user://test_exclude_view.cfg"
	var saved := SaveGame.new(path, SEED)
	saved.exclusions = {Vector2i(7, 7): 3}
	saved.write()
	var m := _main()
	m.pending = SaveGame.load_from(path)
	await m.resume()
	assert_eq(m.excluded.zones, {Vector2i(7, 7): 3})
	saved.erase()


func test_zones_are_cleared_when_miho_goes_up() -> void:
	var m := _main()
	m.world = World.create(SEED)
	var me: Actor = m.world.player()
	me.pos = m.world.stairs + Vector2i(1, 0)
	if not m.world.open_floor(me.pos):
		me.pos = m.world.stairs + Vector2i(-1, 0)
	m.excluded.cycle(me.pos)
	m.run.exclusions = m.excluded.zones.duplicate()
	var depth: int = m.world.depth
	await m.act({t = &"move", dir = m.world.stairs - me.pos})
	assert_eq(m.world.depth, depth + 1)
	assert_true(m.excluded.is_empty())
	assert_true(m.run.exclusions.is_empty())


func test_a_walk_shut_only_by_a_zone_says_so() -> void:
	var m := _main()
	m.world = _hall()
	m.excluded.zones[Vector2i(8, 8)] = 0
	m.forecast()
	var goal := Vector2i(12, 8)
	assert_eq(m._walled_in(goal, "x"), "위험구역 너머로는 갈 수 없다")
	assert_eq(m._walled_in(Vector2i(6, 8), "x"), "x", "reachable")
	assert_eq(m._walled_in(Vector2i(-1, -1), "x"), "x", "no goal")
	assert_true(m._path_to(goal).is_empty())


func test_walking_to_the_zone_tile_itself_is_allowed() -> void:
	var m := _main()
	m.world = _hall()
	m.excluded.zones[Vector2i(8, 8)] = 0
	m.forecast()
	var path: Array[Vector2i] = m._path_to(Vector2i(8, 8))
	assert_eq(path.back(), Vector2i(8, 8))


func test_exploring_that_only_a_zone_blocks_says_so() -> void:
	var m := _main()
	m.world = _hall()
	m.forecast()
	assert_ne(m._exploring(), {}, "open gap")
	m.excluded.zones[Vector2i(8, 8)] = 0
	m.forecast()
	assert_true(m._explore_walled())
	assert_eq(m._exploring(), {})
	assert_eq(m.messages.lines.back().text, "위험구역 너머는 탐험할 수 없다")


func test_exploring_with_nothing_left_is_not_blamed_on_a_zone() -> void:
	var m := _main()
	m.world = _hall()
	m.world.known.fill(1)
	m.excluded.zones[Vector2i(8, 8)] = 0
	m.forecast()
	assert_false(m._explore_walled())


func _press(key: String) -> InputEventKey:
	var e := Keys.event(key)
	e.pressed = true
	return e
