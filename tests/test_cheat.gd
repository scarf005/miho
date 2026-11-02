extends GutTest
## The debug commands (Cheat): what each does to the world, that none takes a
## round or draws attention, that a forecast on a clone matches the round, and
## that a save with them plays back to the same world.

const ME := Vector2i(4, 8)
const E := Vector2i(1, 0)
const PATH := "user://test_cheat.cfg"


func after_each() -> void:
	SaveGame.new(PATH).erase()


## An unlit hall walled at the edges, Miho at ME with 3 health on storey 2.
func _hall() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = 2
	w.tails = 1
	w.sense()
	return w


func _do(w: World, cmd: StringName, args := {}) -> Array:
	var action := {t = &"cheat", cmd = cmd}.merged(args)
	assert_true(w.can(action), str(action))
	return w.act(action)


## A creature of `kind` on the hall, asleep unless `alert`.
func _foe(w: World, at: Vector2i, kind := &"dokkaebi", alert := Actor.REST) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.alert = alert
	return a


func test_teleport_puts_miho_on_the_tile_with_no_round_and_no_one_alerted() -> void:
	var w := _hall()
	var sleeper := _foe(w, Vector2i(20, 8))
	var to := Vector2i(19, 8)
	var events := _do(w, &"teleport", {at = to})
	assert_eq(w.player().pos, to)
	assert_eq(w.round_no, 0)
	assert_eq(sleeper.alert, Actor.REST)
	assert_true(events.all(func(e): return e.t == &"cheat"), "no step, noise or round events")


func test_teleport_is_refused_onto_a_wall_a_creature_or_miho() -> void:
	var w := _hall()
	var foe := _foe(w, Vector2i(10, 8))
	for at in [Vector2i(0, 0), foe.pos, ME, Vector2i(-1, 3)]:
		assert_false(w.can({t = &"cheat", cmd = &"teleport", at = at}), str(at))


func test_god_takes_no_harm_and_off_it_does() -> void:
	var w := _hall()
	w.player().hp = 1
	_foe(w, ME + E, &"jangseung", Actor.HUNT)
	var control := w.clone()
	control.act({t = &"wait"})
	assert_eq(control.outcome, &"lost", "without it the blow kills her")
	_do(w, &"god")
	w.act({t = &"wait"})
	assert_eq(w.player().hp, 1)
	assert_eq(w.outcome, &"")
	_do(w, &"god")
	w.act({t = &"wait"})
	assert_eq(w.outcome, &"lost")


func test_kill_takes_the_creature_off_with_no_tail_and_no_scroll() -> void:
	var w := _hall()
	var near := _foe(w, ME + E * 3, &"bujigaengi")
	var far := _foe(w, Vector2i(30, 8))
	var events := _do(w, &"kill", {id = near.id})
	assert_null(w.actor(near.id))
	assert_not_null(w.actor(far.id))
	assert_eq(w.tails, 1, "no tail for it")
	assert_true(w.sites.is_empty(), "no scroll")
	assert_false(events.any(func(e): return e.t in [&"die", &"soul"]))


func test_kill_all_leaves_only_miho_and_is_refused_with_none() -> void:
	var w := _hall()
	assert_false(w.can({t = &"cheat", cmd = &"kill_all"}))
	for x in 3:
		_foe(w, Vector2i(10 + x, 5), &"dokkaebi", Actor.HUNT)
	_do(w, &"kill_all")
	assert_eq(w.actors.size(), 1)
	assert_eq(w.player().hp, 3)
	assert_false(w.can({t = &"cheat", cmd = &"kill_all"}))


func test_damage_goes_by_the_harm_path_so_a_death_gives_a_tail_and_a_scroll() -> void:
	var w := _hall()
	w.tails = 0
	var a := _foe(w, Vector2i(10, 8), &"dokkaebi")
	_do(w, &"damage", {id = a.id, n = 1})
	assert_eq(a.hp, Bestiary.hp(&"dokkaebi", a.rank) - 1)
	var events := _do(w, &"damage", {id = a.id, n = 50})
	assert_false(a.alive())
	assert_true(events.any(func(e): return e.t == &"die" and e.id == a.id))
	assert_true(events.any(func(e): return e.t == &"soul"))
	assert_eq(w.tails, 1)
	assert_null(w.actor(a.id), "gone from the storey")
	assert_false(w.can({t = &"cheat", cmd = &"damage", id = a.id, n = 1}))
	assert_false(w.can({t = &"cheat", cmd = &"damage", id = w.player().id, n = 1}))


func test_unlimited_tails_let_a_costly_spell_go_and_spend_nothing() -> void:
	var w := _hall()
	w.cards.assign(Cards.ALL)
	var spell := {t = &"cast", spells = [{cards = [Cards.FIRE, Cards.WATER], dir = E}]}
	assert_false(w.can(spell), "one tail does not pay two cards")
	_do(w, &"tails")
	assert_true(w.can(spell))
	w.act(spell)
	assert_eq(w.tails, 1, "nothing spent")
	assert_eq(Cheat.tails(w), Cheat.UNLIMITED)
	_do(w, &"tails")
	assert_false(w.can(spell))


func test_moving_a_creature_is_refused_onto_a_wall_or_another_creature() -> void:
	var w := _hall()
	var a := _foe(w, Vector2i(10, 8))
	var b := _foe(w, Vector2i(12, 8))
	for at in [Vector2i(0, 0), b.pos, ME]:
		assert_false(w.can({t = &"cheat", cmd = &"move_foe", id = a.id, at = at}), str(at))
	_do(w, &"move_foe", {id = a.id, at = Vector2i(11, 12)})
	assert_eq(a.pos, Vector2i(11, 12))
	assert_eq(w.round_no, 0)
	assert_false(w.can({t = &"cheat", cmd = &"move_foe", id = w.player().id, at = Vector2i(9, 9)}))


func test_floor_goes_up_or_down_by_the_storeys_that_keep_what_was_left() -> void:
	var w := World.create(5)
	w.set_tile(Vector2i(w.start.x, w.start.y), World.ASH)
	var marked := w.tiles.duplicate()
	_do(w, &"floor", {depth = 4})
	assert_eq(w.depth, 4)
	assert_eq(w.tails, w.max_tails())
	assert_true(w.storeys.has(1))
	_do(w, &"floor", {depth = 1})
	assert_eq(w.depth, 1)
	assert_eq(w.tiles, marked, "storey 1 as it was left")
	assert_false(w.can({t = &"cheat", cmd = &"floor", depth = 1}), "not the storey she is on")
	assert_false(w.can({t = &"cheat", cmd = &"floor", depth = World.FLOORS + 1}))
	assert_false(w.can({t = &"cheat", cmd = &"floor", depth = 0}))


func test_one_talisman_or_all_of_them_are_granted_once() -> void:
	var w := _hall()
	var events := _do(w, &"card", {card = Cards.FIRE})
	assert_true(w.cards.has(Cards.FIRE))
	assert_eq(events.filter(func(e): return e.t == &"card").size(), 1)
	assert_false(w.can({t = &"cheat", cmd = &"card", card = Cards.FIRE}), "she has it")
	assert_false(w.can({t = &"cheat", cmd = &"card", card = &"nothing"}))
	_do(w, &"cards")
	assert_eq(w.cards.size(), Cards.ALL.size())
	for c in Cards.ALL:
		assert_true(w.cards.has(c), c)
	assert_false(w.can({t = &"cheat", cmd = &"cards"}))


func test_summon_stands_a_creature_of_that_kind_on_the_tile() -> void:
	var w := _hall()
	for kind in Codex.foes():
		var at := Vector2i(10, 8)
		_do(w, &"summon", {kind = kind, at = at})
		assert_eq(w.actor_at(at).kind, kind)
		assert_false(w.can({t = &"cheat", cmd = &"summon", kind = kind, at = at}), "occupied")
		w.actors.erase(w.actor_at(at))
	assert_false(w.can({t = &"cheat", cmd = &"summon", kind = &"miho", at = Vector2i(10, 8)}))
	assert_false(w.can({t = &"cheat", cmd = &"summon", kind = &"dokkaebi", at = Vector2i(0, 0)}))


func test_reveal_makes_every_tile_known_and_seen_and_keeps_them_so() -> void:
	var w := World.create(5)
	assert_lt(w.known.count(1), w.known.size())
	_do(w, &"reveal")
	assert_eq(w.seen.count(1), w.seen.size())
	assert_eq(w.known.count(1), w.known.size())
	w.act({t = &"wait"})
	assert_eq(w.seen.count(1), w.seen.size(), "still, after a round")
	_do(w, &"floor", {depth = 2})
	assert_eq(w.seen.count(1), w.seen.size(), "and on another storey")
	_do(w, &"reveal")
	assert_lt(w.seen.count(1), w.seen.size(), "off, she sees what she sees")


func test_heal_fills_her_health_and_is_refused_when_full() -> void:
	var w := _hall()
	assert_false(w.can({t = &"cheat", cmd = &"heal"}))
	w.player().hp = 1
	_do(w, &"heal")
	assert_eq(w.player().hp, w.player().max_hp)


func test_halt_stops_creatures_taking_turns() -> void:
	var w := _hall()
	var hunter := _foe(w, Vector2i(30, 8), &"dokkaebi", Actor.HUNT)
	hunter.target = ME
	var still := w.clone()
	_do(w, &"halt")
	for i in 4:
		w.act({t = &"wait"})
		still.act({t = &"wait"})
	assert_eq(hunter.pos, Vector2i(30, 8), "it stayed")
	assert_ne(still.actor(hunter.id).pos, Vector2i(30, 8), "else it comes")


func test_a_command_takes_no_round_and_wakes_no_one() -> void:
	var w := _hall()
	var sleeper := _foe(w, Vector2i(6, 8))
	w.player().hp = 1
	for cmd in [&"god", &"tails", &"reveal", &"halt", &"heal", &"cards"]:
		_do(w, cmd)
	_do(w, &"teleport", {at = Vector2i(7, 8)})
	assert_eq(w.round_no, 0)
	assert_eq(sleeper.alert, Actor.REST)


func test_a_toggle_and_a_summon_leave_a_log_line_that_says_which_way_it_went() -> void:
	var w := _hall()
	var lines := []
	for action in [
		{t = &"cheat", cmd = &"god"},
		{t = &"cheat", cmd = &"god"},
		{t = &"cheat", cmd = &"summon", kind = &"dokkaebi", at = Vector2i(5, 8)},
	]:
		var before := w.clone()
		var told := Messages.of(before, w, w.act(action))
		assert_eq(told.size(), 1, str(action))
		lines.append(Messages.plain(told[0]))
	assert_string_contains(lines[0], Cheat.NAME[&"god"])
	assert_string_contains(lines[1], Cheat.NAME[&"god"])
	assert_ne(lines[0], lines[1], "on and off read differently")
	assert_string_contains(lines[2], Bestiary.info(&"dokkaebi").name)


func test_a_cheat_the_world_does_not_know_or_that_lacks_its_parts_is_refused() -> void:
	var w := _hall()
	assert_false(w.can({t = &"cheat", cmd = &"nothing"}))
	assert_false(w.can({t = &"cheat"}))
	assert_false(w.can({t = &"cheat", cmd = &"teleport"}))
	assert_false(w.can({t = &"cheat", cmd = &"teleport", at = "10,8"}))
	assert_false(w.can({t = &"cheat", cmd = &"floor", depth = 2.0}))


func test_a_clone_forecasts_a_round_as_it_is_played_with_the_toggles_on() -> void:
	var w := World.create(11)
	for cmd in Cheat.TOGGLES:
		_do(w, cmd)
	_do(w, &"cards")
	var foe := _foe(w, w.player().pos + E * 2, &"dokkaebi", Actor.HUNT)
	foe.hp = 1
	w.player().hp = 1
	var spell := {t = &"cast", spells = [{cards = [Cards.ORB, Cards.FIRE], dir = E}]}
	assert_true(w.can(spell))
	var forecast := w.preview(spell)
	assert_eq(forecast.cheats, w.cheats)
	w.act(spell)
	assert_eq(forecast.tails, w.tails)
	assert_eq(forecast.player().hp, w.player().hp)
	assert_eq(forecast.rng.state, w.rng.state)
	assert_eq(forecast.known, w.known)
	assert_eq(
		forecast.actors.map(func(a): return [a.id, a.pos, a.hp]),
		w.actors.map(func(a): return [a.id, a.pos, a.hp])
	)
	assert_null(w.actor(foe.id), "the spell struck it")
	assert_null(forecast.actor(foe.id))


func test_a_cheat_forecast_on_a_clone_is_the_cheat_played() -> void:
	var w := World.create(11)
	var foe := _foe(w, w.player().pos + E * 3)
	for action in [
		{t = &"cheat", cmd = &"god"},
		{t = &"cheat", cmd = &"damage", id = foe.id, n = 1},
		{t = &"cheat", cmd = &"teleport", at = w.player().pos + E},
		{t = &"cheat", cmd = &"floor", depth = 3},
	]:
		var forecast := w.preview(action)
		w.act(action)
		assert_eq(forecast.cheats, w.cheats)
		assert_eq(forecast.depth, w.depth)
		assert_eq(forecast.player().pos, w.player().pos)
		assert_eq(forecast.seen, w.seen)
		assert_eq(forecast.rng.state, w.rng.state, str(action))


func test_a_saved_run_with_debug_actions_plays_back_to_the_same_world() -> void:
	var seed_of := 21
	var run := SaveGame.new(PATH, seed_of)
	var w := World.create(seed_of)
	var script := []
	for i in 6:
		script.append({t = &"move", dir = Grid.DIRS[i % 8]})
	var foe_at := Vector2i(-1, -1)
	for action in script:
		if w.can(action):
			w.act(action)
			run.record(action, 0, false)
	for action in [
		{t = &"cheat", cmd = &"god"},
		{t = &"cheat", cmd = &"cards"},
		{t = &"cheat", cmd = &"tails"},
		{t = &"cheat", cmd = &"reveal"},
		{t = &"cheat", cmd = &"floor", depth = 3},
		{t = &"cheat", cmd = &"summon", kind = &"dokkaebi", at = Vector2i(-1, -1)},
	]:
		if action.cmd == &"summon":
			foe_at = FloorGen.nearest_free(w, w.player().pos + E * 2)
			action.at = foe_at
		assert_true(w.can(action), str(action))
		w.act(action)
		run.record(action, 0, false)
	var foe := w.actor_at(foe_at)
	for action in [
		{t = &"cheat", cmd = &"damage", id = foe.id, n = 1},
		{t = &"cheat", cmd = &"move_foe", id = foe.id, at = w.player().pos - E},
		{t = &"wait"},
		{t = &"cheat", cmd = &"kill", id = foe.id},
		{t = &"cheat", cmd = &"floor", depth = 1},
		{t = &"cheat", cmd = &"teleport", at = FloorGen.nearest_free(w, w.player().pos + E * 3)},
	]:
		assert_true(w.can(action), str(action))
		w.act(action)
		run.record(action, 0, false)
	var back := SaveGame.load_from(PATH)
	assert_not_null(back, "a save with debug actions loads")
	assert_true(back.replay())
	var r := back.world
	assert_eq(r.depth, w.depth)
	assert_eq(r.cheats, w.cheats)
	assert_eq(r.player().pos, w.player().pos)
	assert_eq(r.cards, w.cards)
	assert_eq(r.round_no, w.round_no)
	assert_eq(r.tails, w.tails)
	assert_eq(r.tiles, w.tiles)
	assert_eq(r.known, w.known)
	assert_eq(r.rng.state, w.rng.state)
	assert_eq(
		r.actors.map(func(a): return [a.id, a.pos]), w.actors.map(func(a): return [a.id, a.pos])
	)


func test_a_save_whose_cheat_lacks_its_parts_is_not_loaded() -> void:
	for bad in [
		{t = &"cheat", cmd = &"teleport"}, {t = &"cheat"}, {t = &"cheat", cmd = &"nothing"}
	]:
		var c := ConfigFile.new()
		c.set_value("run", "version", SaveGame.VERSION)
		c.set_value("run", "seed", 1)
		c.set_value("run", "kills", 0)
		c.set_value("run", "actions", [bad])
		c.save(PATH)
		assert_null(SaveGame.load_from(PATH), str(bad))


func test_a_creature_moved_takes_the_wisp_riding_it_along() -> void:
	var w := _hall()
	var a := _foe(w, Vector2i(10, 8))
	var wisp := Shot.new()
	wisp.id = w.new_id()
	wisp.host = a.id
	wisp.spell = Spell.make([Cards.FOX])
	wisp.life = 5
	wisp.pos = a.pos
	w.shots.append(wisp)
	_do(w, &"move_foe", {id = a.id, at = Vector2i(11, 12)})
	assert_eq(wisp.pos, a.pos)
