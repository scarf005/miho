extends GutTest
## A world written down as plain data plays on as if it had never stopped, and a saved run
## whose actions no longer fit the rules goes on from the last state it wrote.

const PATH := "user://test_snapshot.cfg"
const SEED := 114


func after_each() -> void:
	SaveGame.new(PATH).erase()


func _through_bytes(w: World) -> World:
	return Snapshot.world(bytes_to_var(var_to_bytes(Snapshot.of(w))))


func _action(w: World, i: int) -> Dictionary:
	var cast := {t = &"cast", spells = [{cards = [Cards.FOX], dir = Grid.DIRS[i % 8]}]}
	var step := {t = &"move", dir = Grid.DIRS[i % 8]}
	if i % 5 == 4 and w.can(cast):
		return cast
	return step if w.can(step) else {t = &"wait"}


## Plays `n` rounds, saving each with the world and its log.
func _play(n: int) -> SaveGame:
	var run := SaveGame.new(PATH, SEED)
	var w := World.create(SEED)
	var log := Messages.new()
	for i in n:
		var action := _action(w, i)
		var before := w.clone()
		var events := w.act(action)
		run.record(action, i, w.outcome != &"")
		log.add_round(before, w, events)
		run.keep(w, log)
	run.flush()
	return run


func _version(version: int) -> void:
	var c := ConfigFile.new()
	assert_eq(c.load(PATH), OK)
	c.set_value("run", "version", version)
	c.save(PATH)


func test_a_world_written_down_plays_on_the_same_as_the_one_it_was() -> void:
	for path in ["res://tools/oracle/05.cfg"]:
		var save := SaveGame.load_from(path)
		assert_not_null(save, path)
		var kept := World.create(save.seed_value)
		var read := World.create(save.seed_value)
		for i in save.actions.size():
			if i % 25 == 0:
				read = _through_bytes(read)
			assert_eq(
				str(read.act(save.actions[i])), str(kept.act(save.actions[i])), "%s %d" % [path, i]
			)
			assert_eq(read.rng.state, kept.rng.state)
		assert_eq(read.tiles, kept.tiles)
		assert_eq(read.storeys.size(), kept.storeys.size())


func test_a_creature_the_rules_no_longer_know_is_gone_from_the_world() -> void:
	var w := World.create(SEED)
	var data := Snapshot.of(w)
	var count: int = data.actors.size()
	assert_gt(count, 1)
	data.actors[1].kind = &"no_such_creature"
	assert_eq(Snapshot.world(data).actors.size(), count - 1)


func test_a_field_the_rules_no_longer_know_is_left_out() -> void:
	var w := World.create(SEED)
	var data := Snapshot.of(w)
	data.no_such_field = 3
	data.actors[0].no_such_field = 3
	assert_eq(Snapshot.world(data).player().hp, w.player().hp)


func test_a_run_of_old_rules_goes_on_from_its_last_state() -> void:
	var run := _play(SaveGame.STATE_EVERY + 4)
	_version(SaveGame.VERSION - 1)
	var back := SaveGame.load_from(PATH)
	assert_not_null(back)
	back.begin()
	assert_true(back.actions.is_empty())
	assert_eq(back.world.round_no, _world_after(SaveGame.STATE_EVERY).round_no)
	assert_eq(back.world.tiles, _world_after(SaveGame.STATE_EVERY).tiles)
	assert_eq(back.kills, SaveGame.STATE_EVERY - 1)
	assert_eq(run.seed_value, back.seed_value)
	assert_string_contains(back.messages.lines[-1].text, SaveGame.ROLLED_BACK)


func _world_after(n: int) -> World:
	var w := World.create(SEED)
	for i in n:
		w.act(_action(w, i))
	return w


func test_a_run_that_went_on_from_a_state_comes_back_the_same() -> void:
	_play(SaveGame.STATE_EVERY + 4)
	_version(SaveGame.VERSION - 1)
	var run := SaveGame.load_from(PATH)
	run.begin()
	var w := run.world
	for i in SaveGame.STATE_EVERY * 2 + 7:
		var action := _action(w, i)
		var before := w.clone()
		var events := w.act(action)
		run.record(action, i, false)
		run.messages.add_round(before, w, events)
		run.keep(w, run.messages)
	run.flush()
	var back := SaveGame.load_from(PATH)
	assert_true(back.replay())
	assert_eq(back.world.round_no, w.round_no)
	assert_eq(back.world.tiles, w.tiles)
	assert_eq(back.world.rng.state, w.rng.state)


func test_an_action_the_rules_refuse_goes_back_to_the_last_state() -> void:
	var run := _play(SaveGame.STATE_EVERY + 4)
	run.actions[-1] = {t = &"move", dir = Vector2i(9, 9)}
	run.write()
	var back := SaveGame.load_from(PATH)
	assert_true(back.replay())
	assert_eq(back.world.round_no, _world_after(SaveGame.STATE_EVERY).round_no)
	assert_true(back.actions.is_empty())


func test_a_run_with_no_state_is_still_dropped() -> void:
	var run := SaveGame.new(PATH, SEED)
	run.record({t = &"wait"}, 0, false)
	run.flush()
	_version(SaveGame.VERSION - 1)
	assert_null(SaveGame.load_from(PATH))


func test_erasing_a_run_takes_its_states_too() -> void:
	var run := _play(SaveGame.STATE_EVERY)
	assert_true(FileAccess.file_exists(PATH + SaveGame.STATES))
	run.erase()
	assert_false(FileAccess.file_exists(PATH + SaveGame.STATES))
	assert_false(FileAccess.file_exists(PATH))


func test_the_title_leaves_a_run_of_old_rules_as_it_is_until_it_goes_on() -> void:
	_play(SaveGame.STATE_EVERY + 4)
	_version(SaveGame.VERSION - 1)
	var back := SaveGame.load_from(PATH)
	assert_not_null(back)
	var c := ConfigFile.new()
	c.load(PATH)
	assert_eq(c.get_value("run", "version"), SaveGame.VERSION - 1)
	assert_eq(c.get_value("run", "actions").size(), SaveGame.STATE_EVERY + 4)
	back.begin()
	c.load(PATH)
	assert_eq(c.get_value("run", "version"), SaveGame.VERSION)
	assert_true(c.get_value("run", "actions").is_empty())


func test_a_run_of_old_rules_keeps_the_marks_of_its_storey() -> void:
	var run := _play(SaveGame.STATE_EVERY + 4)
	run.exclusions = {Vector2i(3, 4): 2}
	run.write()
	_version(SaveGame.VERSION - 1)
	var back := SaveGame.load_from(PATH)
	back.begin()
	assert_eq(back.exclusions, {Vector2i(3, 4): 2})
	assert_eq(SaveGame.load_from(PATH).exclusions, {Vector2i(3, 4): 2})


func test_the_state_of_another_run_is_not_taken() -> void:
	_play(SaveGame.STATE_EVERY)
	var c := ConfigFile.new()
	c.load(PATH)
	c.set_value("run", "seed", SEED + 1)
	c.set_value("run", "version", SaveGame.VERSION - 1)
	c.save(PATH)
	assert_null(SaveGame.load_from(PATH))


func test_a_run_that_lost_the_state_its_actions_start_from_is_not_played_from_the_seed() -> void:
	_play(SaveGame.STATE_EVERY + 4)
	_version(SaveGame.VERSION - 1)
	var run := SaveGame.load_from(PATH)
	run.begin()
	var w := run.world
	var action := _action(w, 0)
	w.act(action)
	run.record(action, 0, false)
	run.flush()
	DirAccess.remove_absolute(PATH + SaveGame.STATES)
	assert_null(SaveGame.load_from(PATH))


func test_the_last_state_holds_the_lines_of_the_round_it_was_cut_on() -> void:
	var run := SaveGame.new(PATH, SEED)
	var w := World.create(SEED)
	var log := Messages.new()
	var before := w.clone()
	var events := w.act({t = &"wait"})
	run.record({t = &"wait"}, 0, false)
	log.add_text("마지막 저장 지점으로 돌아왔다", w.round_no)
	log.add_round(before, w, events)
	run.keep(w, log)
	assert_eq(run.states.last.log.size(), log.lines.size())
	assert_false(run.states.last.log.is_empty())


func test_a_world_written_down_does_not_change_with_the_one_it_was() -> void:
	var w := World.create(SEED)
	var data := Snapshot.of(w)
	var from_data := Snapshot.world(data)
	var at := w.player().pos
	var was: int = w.tile(at)
	w.set_tile(at, World.WALL if was != World.WALL else World.FLOOR)
	from_data.set_tile(at, World.WALL if was != World.WALL else World.FLOOR)
	assert_eq(Snapshot.world(data).tile(at), was)


func test_a_state_reaches_the_disk_at_the_flush() -> void:
	var run := SaveGame.new(PATH, SEED)
	var w := World.create(SEED)
	w.act({t = &"wait"})
	run.record({t = &"wait"}, 0, false)
	run.keep(w, Messages.new())
	assert_false(FileAccess.file_exists(PATH + SaveGame.STATES), "it waits in memory")
	run.flush()
	assert_true(SaveGame.load_from(PATH).states.has("last"))


func test_a_run_taken_up_again_plays_only_what_came_after_its_last_state() -> void:
	var rounds := SaveGame.STATE_EVERY * 2 + 7
	_play(rounds)
	var back := SaveGame.load_from(PATH)
	back.begin()
	assert_eq(back.played, SaveGame.STATE_EVERY * 2)
	assert_true(back.replay())
	var whole := SaveGame.new("", SEED)
	whole.actions.assign(back.actions)
	assert_true(whole.replay())
	assert_eq(whole.played, rounds)
	assert_eq(var_to_str(Snapshot.of(back.world)), var_to_str(Snapshot.of(whole.world)))
	assert_eq(back.messages.saved(), whole.messages.saved())


func test_a_state_ahead_of_the_actions_on_disk_is_not_started_from() -> void:
	_play(SaveGame.STATE_EVERY + 4)
	var back := SaveGame.load_from(PATH)
	back.actions.resize(SaveGame.STATE_EVERY - 1)
	back.begin()
	assert_eq(back.played, 0)
	assert_eq(back.world.round_no, 0)
	assert_false(back.states.has("last"), "the actions after it would not be its own")
