extends GutTest
## The scent view: the trail Miho left, on the tiles she has seen, and that it changes nothing.

const E := Vector2i(1, 0)
const SETTINGS := "user://test_scent_view_settings.cfg"


## A corridor y = 8 from x = 2 to 16, Miho at (4, 8), everything seen.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for x in range(2, 17):
		w.tiles[Grid.index(Vector2i(x, 8))] = World.FLOOR
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
	w.dim = w.known.duplicate()
	return w


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m.new_run(3)
	m.state = &"play"
	return m


func _press(key: String) -> InputEventKey:
	var e := Keys.event(key)
	e.pressed = true
	return e


func test_a_tile_miho_walked_is_fresher_the_later_she_left_it() -> void:
	var w := _world()
	for i in 3:
		w.act({t = &"move", dir = E})
	var trail := Scent.fresh(w, true)
	assert_true(trail.has(Vector2i(5, 8)))
	assert_true(trail.has(Vector2i(6, 8)))
	assert_gt(trail[Vector2i(6, 8)], trail[Vector2i(5, 8)], "the later step is stronger")
	assert_lte(trail[Vector2i(6, 8)], 1.0)
	assert_gt(trail[Vector2i(5, 8)], 0.0)
	assert_false(trail.has(Vector2i(12, 8)), "she never went there")


func test_a_trail_older_than_a_hunter_would_follow_is_not_shown() -> void:
	var w := _world()
	w.round_no = 100
	w.scent.resize(w.tiles.size())
	w.scent[Grid.index(Vector2i(9, 8))] = w.round_no + 1 - Scent.TRAIL_AGE
	w.scent[Grid.index(Vector2i(10, 8))] = w.round_no + 1 - Scent.TRAIL_AGE - 1
	var trail := Scent.fresh(w, true)
	assert_true(trail.has(Vector2i(9, 8)))
	assert_false(trail.has(Vector2i(10, 8)))


func test_a_tile_she_has_not_seen_shows_no_scent_to_her_but_the_debug_view_shows_it() -> void:
	var w := _world()
	w.act({t = &"move", dir = E})
	w.known[Grid.index(Vector2i(5, 8))] = 0
	assert_false(Scent.fresh(w, true).has(Vector2i(5, 8)))
	assert_true(Scent.fresh(w, false).has(Vector2i(5, 8)))


func test_a_scentless_tile_shows_none() -> void:
	var w := _world()
	w.tiles[Grid.index(Vector2i(5, 8))] = World.BAMBOO
	w.act({t = &"move", dir = E})
	assert_false(Scent.fresh(w, true).has(Vector2i(5, 8)))


func test_the_scent_key_is_bound_and_listed_in_help() -> void:
	Keys.reset()
	var keys := Keys.keys_of(&"scent")
	assert_eq(keys.size(), 1)
	assert_eq(Keys.action_of(_press(keys[0])), &"scent")
	var menu := Menu.new()
	menu.open(&"help")
	var text := "\n".join(
		menu.panel().rows.map(func(r): return " ".join(r.map(func(run): return run[0])))
	)
	assert_string_contains(text, "냄새 보기 " + keys[0])


func _plain_at(w: World, p: Vector2i) -> String:
	return Info.plain(Info.at(w.known_clone(), p, Scent.fresh(w, true)))


func test_the_scent_is_on_by_default_and_a_saved_off_stays_off() -> void:
	assert_true(Settings.new().scent)
	var s := Settings.new()
	s.scent = false
	var c := ConfigFile.new()
	assert_eq(c.parse(s.to_config().encode_to_text()), OK)
	var back := Settings.new()
	back.from_config(c)
	assert_false(back.scent)
	var fresh := Settings.new()
	fresh.from_config(ConfigFile.new())
	assert_true(fresh.scent, "a file without the option keeps the default")


func test_the_settings_page_has_a_scent_row_that_flips_the_setting() -> void:
	var menu := Menu.new()
	menu.open(&"options")
	var row := Menu.OPTIONS.find(&"scent")
	assert_gt(row, -1)
	menu.selected = row
	assert_eq(menu.panel().rows[row][0][0], "냄새 보기")
	assert_eq(menu.panel().rows[row][1][0], "켜짐")
	assert_eq(menu.key(_press("Right")), &"changed")
	assert_false(menu.settings.scent)
	assert_eq(menu.panel().rows[row][1][0], "꺼짐")


func test_the_scent_is_tinted_from_the_start_and_the_key_flips_the_saved_setting() -> void:
	var m := _main()
	m.settings = Settings.new()
	m.settings.path = SETTINGS
	m._key(_press("Right"))
	var before: World = m.world.clone()
	var saved: int = m.run.actions.size()
	assert_false(m.term.scent.is_empty(), "on by default")
	m._key(_press(Keys.keys_of(&"scent")[0]))
	assert_false(m.settings.scent)
	assert_true(m.term.scent.is_empty())
	assert_false(Settings.load_from(SETTINGS).scent, "the choice is kept")
	m._key(_press(Keys.keys_of(&"scent")[0]))
	assert_true(m.settings.scent)
	assert_false(m.term.scent.is_empty())
	assert_eq(m.world.scent, before.scent)
	assert_eq(m.world.round_no, before.round_no)
	assert_eq(m.run.actions.size(), saved, "no action is recorded")
	DirAccess.remove_absolute(SETTINGS)


func test_the_trail_is_current_while_a_step_plays() -> void:
	var m := _main()
	m.settings = Settings.new()
	m.settings.path = ""
	m.act({t = &"move", dir = E})
	assert_true(m.busy, "the step is still playing")
	assert_eq(m.term.scent, Scent.fresh(m.world, true), "the trail of the round being shown")
	assert_true(m.term.scent.has(m.world.player().pos))
	await wait_until(func(): return not m.busy, 5.0)
	assert_eq(m.term.scent, Scent.fresh(m.world, true), "and the same when it ends")


func test_hovering_a_scented_tile_shows_a_meter_of_its_freshness() -> void:
	var w := _world()
	w.round_no = 100
	w.scent.resize(w.tiles.size())
	w.scent[Grid.index(Vector2i(9, 8))] = w.round_no + 1
	w.scent[Grid.index(Vector2i(10, 8))] = w.round_no + 1 - Scent.TRAIL_AGE
	assert_string_contains(_plain_at(w, Vector2i(9, 8)), "냄새 ■■■■■")
	assert_string_contains(_plain_at(w, Vector2i(10, 8)), "냄새 ■□□□□")


func test_hovering_a_tile_with_no_scent_or_not_seen_shows_no_meter() -> void:
	var w := _world()
	w.round_no = 100
	w.scent.resize(w.tiles.size())
	w.scent[Grid.index(Vector2i(9, 8))] = w.round_no + 1
	w.scent[Grid.index(Vector2i(11, 8))] = w.round_no + 1
	w.known[Grid.index(Vector2i(11, 8))] = 0
	assert_false(_plain_at(w, Vector2i(12, 8)).contains("냄새"), "no scent")
	assert_eq(_plain_at(w, Vector2i(11, 8)), "", "not seen")
	assert_false(Info.plain(Info.at(w.known_clone(), Vector2i(9, 8))).contains("냄새"), "view off")
