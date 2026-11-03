extends GutTest
## The debug view: what it shows from the world, and that it changes nothing.

const SETTINGS := "user://test_debug_settings.cfg"


## A hall walled at the edges with a wall down column 8, Miho at (4, 8) knowing
## and seeing nothing past her own tile.
func _hall() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.WALL if x == 8 else World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.seen = w.known.duplicate()
	w.dim = w.known.duplicate()
	w.round_no = 20
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


## Everything of the world a round could change.
func _sig(w: World) -> Array:
	var actors := w.actors.map(
		func(a):
			return [
				a.id,
				a.pos,
				a.hp,
				a.brain.alert,
				a.brain.target,
				a.brain.lost,
				a.magic.cooldown,
				a.magic.intent,
				a.brain.sees_me
			]
	)
	return [w.round_no, w.rng.state, actors, w.seen, w.known, w.scent, w.heard, w.events.size()]


func test_goals_are_listed_for_creatures_that_search_or_hunt_only() -> void:
	var w := _hall()
	var hunter := FloorGen.spawn(w, &"dokkaebi", Vector2i(12, 8))
	hunter.brain.alert = Actor.HUNT
	hunter.brain.target = Vector2i(10, 3)
	var searcher := FloorGen.spawn(w, &"dokkaebi", Vector2i(14, 9))
	searcher.brain.alert = Actor.SEARCH
	searcher.brain.target = Vector2i(2, 2)
	FloorGen.spawn(w, &"dokkaebi", Vector2i(16, 9))
	var goals: Array = DebugView.view(w).goals
	assert_eq(goals.size(), 2, "the sleeper has none")
	assert_eq(goals[0], {from = hunter.pos, to = Vector2i(10, 3), alert = Actor.HUNT})
	assert_eq(goals[1].alert, Actor.SEARCH)


func test_scent_is_brighter_the_fresher_and_stops_where_hunters_stop_following() -> void:
	var w := _hall()
	w.scent.resize(w.tiles.size())
	var fresh := Vector2i(3, 8)
	var older := Vector2i(2, 8)
	var cold := Vector2i(1, 8)
	w.scent[Grid.index(fresh)] = w.round_no + 1
	w.scent[Grid.index(older)] = w.round_no + 1 - 6
	w.scent[Grid.index(cold)] = w.round_no + 1 - Scent.TRAIL_AGE - 1
	var scent: Dictionary = DebugView.view(w).scent
	assert_eq(scent.size(), 2)
	assert_gt(scent[fresh], scent[older])
	assert_false(scent.has(cold))
	assert_false(scent.has(Vector2i(5, 8)), "never trodden")


func test_a_sound_reaches_only_as_far_as_it_travels_round_walls() -> void:
	var w := _hall()
	Hearing.noise(w, Vector2i(6, 8), 3, "쿵", false, 0)
	var sounds: Array = DebugView.view(w).sounds
	assert_eq(sounds.size(), 1)
	assert_eq(sounds[0].word, "쿵")
	assert_eq(sounds[0].loud, 3)
	var reach: Dictionary = sounds[0].reach
	assert_eq(reach[Vector2i(6, 8)], 0)
	assert_eq(reach[Vector2i(3, 8)], 3, "the edge")
	assert_false(reach.has(Vector2i(2, 8)), "past the edge")
	assert_false(reach.has(Vector2i(9, 8)), "the wall stops it")
	assert_false(reach.has(Vector2i(8, 8)), "not into the wall")


func test_a_creature_out_of_sight_tells_its_hidden_state_on_hover() -> void:
	var w := _hall()
	var a := FloorGen.spawn(w, &"dokkaebi", Vector2i(14, 8))
	a.brain.alert = Actor.SEARCH
	a.brain.target = Vector2i(12, 3)
	a.brain.lost = 4
	a.magic.cooldown = 2
	a.brain.sees_me = false
	assert_eq(w.seen[Grid.index(a.pos)], 0)
	var text := Info.plain(DebugView.at(w, a.pos))
	assert_string_contains(text, "도깨비")
	assert_string_contains(text, "목표 (12, 3) 5칸")
	assert_string_contains(text, "놓친 지 4/%d초" % World.SEARCH_ROUNDS)


func test_a_projectile_tells_what_it_is_wherever_it_flies() -> void:
	var w := _hall()
	var s := Shot.new()
	s.spell = Spell.make([Cards.ORB])
	s.pos = Vector2i(14, 8)
	s.origin = Vector2i(13, 8)
	s.dir = Vector2i(1, 0)
	s.life = 4
	w.shots.append(s)
	assert_eq(w.seen[Grid.index(s.pos)], 0)
	assert_eq(Info.plain(DebugView.at(w, s.pos)), Info.plain(SpellInfo.shot(w, s)))


func test_a_creature_on_a_projectile_tile_is_what_the_view_tells_of() -> void:
	var w := _hall()
	var a := FloorGen.spawn(w, &"dokkaebi", Vector2i(14, 8))
	var s := Shot.new()
	s.spell = Spell.make([Cards.ORB])
	s.pos = a.pos
	w.shots.append(s)
	assert_null(DebugView.shot_at(w, a.pos))
	assert_string_contains(Info.plain(DebugView.at(w, a.pos)), "도깨비")


func test_a_sleeper_tells_where_it_rests_and_an_empty_tile_tells_its_scent() -> void:
	var w := _hall()
	var a := FloorGen.spawn(w, &"dokkaebi", Vector2i(14, 8))
	var text := Info.plain(DebugView.at(w, a.pos))
	assert_string_contains(text, "쉬는 곳 (14, 8)")
	assert_false(text.contains("놓친 지"))
	w.scent.resize(w.tiles.size())
	w.scent[Grid.index(Vector2i(3, 8))] = w.round_no + 1 - 2
	text = Info.plain(DebugView.at(w, Vector2i(3, 8)))
	assert_string_contains(text, "바닥")
	assert_string_contains(text, "냄새 2초 전")
	assert_eq(DebugView.at(w, Vector2i(-1, -1)), [])


func test_the_debug_key_is_f3_and_is_listed_in_help() -> void:
	Keys.reset()
	assert_eq(Keys.keys_of(&"debug"), ["F3"] as Array[String])
	assert_eq(Keys.action_of(_press("F3")), &"debug")
	var menu := Menu.new()
	menu.open(&"help")
	var text := "\n".join(
		menu.panel().rows.map(func(r): return " ".join(r.map(func(run): return run[0])))
	)
	assert_string_contains(text, "디버그 보기 F3")


func test_toggling_the_view_shows_everything_and_changes_nothing() -> void:
	var m := _main()
	m.settings.path = SETTINGS
	var before := _sig(m.world)
	var saved: int = m.run.actions.size()
	assert_true(m.term.debug.is_empty(), "off by default")
	m._key(_press("F3"))
	assert_true(m.debugging)
	assert_false(m.term.debug.is_empty())
	assert_eq(_sig(m.world), before)
	m._key(_press("F3"))
	assert_false(m.debugging)
	assert_true(m.term.debug.is_empty())
	assert_eq(_sig(m.world), before)
	assert_eq(m.run.actions.size(), saved, "no action is recorded")
	assert_false(FileAccess.file_exists(SETTINGS), "the view is not a setting")


func test_with_the_view_on_hover_shows_a_creature_the_game_hides() -> void:
	var m := _main()
	var unseen := func(a: Actor):
		return a.faction != Actor.FOX and m.world.seen[Grid.index(a.pos)] == 0
	var hidden: Actor = m.world.actors.filter(unseen)[0]
	m._look_at(hidden.pos)
	assert_eq(Info.plain(m.term.info), "", "the game knows nothing of it")
	m._key(_press("F3"))
	m._look_at(hidden.pos)
	assert_string_contains(Info.plain(m.term.info), "디버그")
	assert_string_contains(Info.plain(m.term.info), hidden.info().name)
