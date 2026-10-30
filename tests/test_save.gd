extends GutTest
## A run is kept as its seed and actions, and plays back to the same world.

const PATH := "user://test_save.cfg"
const SEED := 1


func after_each() -> void:
	SaveGame.new(PATH).erase()


## Plays `n` rounds on a new run of SEED, saving each: a spell every fifth round,
## else a step round the compass, else a wait.
func _play(n: int) -> SaveGame:
	var run := SaveGame.new(PATH, SEED)
	var w := World.create(SEED)
	for i in n:
		var action := {t = &"wait"}
		var cast := {t = &"cast", spells = [{cards = [Cards.FOX], dir = Grid.DIRS[i % 8]}]}
		var step := {t = &"move", dir = Grid.DIRS[i % 8]}
		if i % 5 == 4 and w.can(cast):
			action = cast
		elif w.can(step):
			action = step
		w.act(action)
		run.record(action, i, w.outcome != &"")
	return run


func _write(run: Dictionary, version := SaveGame.VERSION) -> void:
	var c := ConfigFile.new()
	c.set_value("run", "version", version)
	for k in run:
		c.set_value("run", k, run[k])
	c.save(PATH)


func test_a_saved_run_loads_to_the_same_world() -> void:
	var run := _play(40)
	var back := SaveGame.load_from(PATH)
	assert_true(back.replay())
	var live := World.create(SEED)
	for action in run.actions:
		live.act(action)
	assert_true(run.actions.any(func(a): return a.t == &"cast"), "the run includes a spell")
	var w := back.world
	assert_eq(w.round_no, 40)
	assert_eq(w.round_no, live.round_no)
	assert_eq(w.player().pos, live.player().pos)
	assert_eq(w.player().hp, live.player().hp)
	assert_eq(w.depth, live.depth)
	assert_eq(w.tails, live.tails)
	assert_eq(w.tiles, live.tiles)
	assert_eq(w.known, live.known)
	assert_eq(
		w.actors.map(func(a): return [a.id, a.pos]), live.actors.map(func(a): return [a.id, a.pos])
	)
	assert_eq(w.rng.state, live.rng.state)
	assert_eq(back.actions, run.actions)
	assert_eq(back.kills, 39)


func test_loading_rebuilds_the_message_log() -> void:
	_play(40)
	var back := SaveGame.load_from(PATH)
	assert_true(back.replay())
	var live := Messages.new()
	var w := World.create(SEED)
	for action in back.actions:
		var before := w.clone()
		for line in Messages.of(before, w, w.act(action)):
			live.add(line, w.round_no)
	assert_false(live.lines.is_empty())
	assert_eq(back.messages.lines, live.lines)


func test_each_round_is_on_disk_as_it_is_played() -> void:
	var run := SaveGame.new(PATH, SEED)
	assert_null(SaveGame.load_from(PATH), "nothing before the first round")
	run.record({t = &"wait"}, 0, false)
	assert_eq(SaveGame.load_from(PATH).actions.size(), 1)
	run.record({t = &"wait"}, 0, false)
	assert_eq(SaveGame.load_from(PATH).actions.size(), 2)


func test_a_finished_run_leaves_no_save() -> void:
	var run := _play(3)
	assert_true(FileAccess.file_exists(PATH))
	run.record({t = &"wait"}, 3, true)
	assert_false(FileAccess.file_exists(PATH))
	assert_null(SaveGame.load_from(PATH))
	run.erase()
	assert_false(FileAccess.file_exists(PATH), "erasing nothing is harmless")


func test_a_run_with_no_path_touches_no_file() -> void:
	var run := SaveGame.new("", SEED)
	run.record({t = &"wait"}, 0, false)
	assert_null(SaveGame.load_from(""))
	assert_eq(run.actions.size(), 1)


func test_a_file_that_is_not_a_run_is_ignored() -> void:
	assert_null(SaveGame.load_from(PATH), "missing")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("garbage = [[[\n{ not a config")
	f.close()
	assert_null(SaveGame.load_from(PATH), "garbage")
	assert_engine_error("ConfigFile parse error")
	_write({seed = SEED, kills = 0, actions = []}, SaveGame.VERSION + 1)
	assert_null(SaveGame.load_from(PATH), "other format")
	_write({seed = SEED, kills = 0, actions = []}, 0)
	assert_null(SaveGame.load_from(PATH), "no format")
	var c := ConfigFile.new()
	c.set_value("other", "seed", SEED)
	c.save(PATH)
	assert_null(SaveGame.load_from(PATH), "no run")


func test_a_run_with_wrong_parts_is_ignored() -> void:
	_write({seed = "x", kills = 0, actions = []})
	assert_null(SaveGame.load_from(PATH), "seed")
	_write({seed = SEED, kills = "x", actions = []})
	assert_null(SaveGame.load_from(PATH), "kills")
	_write({seed = SEED, kills = 0, actions = 5})
	assert_null(SaveGame.load_from(PATH), "actions")
	for bad: Variant in [
		5,
		{t = &"fly"},
		{t = &"move"},
		{t = &"move", dir = "up"},
		{t = &"cast", spells = 1},
		{t = &"cast", spells = [{cards = [Cards.FOX]}]},
		{t = &"cast", spells = [{cards = ["fox"], dir = Vector2i.UP}]},
	]:
		_write({seed = SEED, kills = 0, actions = [{t = &"wait"}, bad]})
		assert_null(SaveGame.load_from(PATH), "action %s" % [bad])


func test_a_replay_stops_at_an_action_the_rules_refuse() -> void:
	var jump := {t = &"move", dir = Vector2i(2, 0)}
	_write({seed = SEED, kills = 0, actions = [{t = &"wait"}, jump]})
	var refused := SaveGame.load_from(PATH)
	assert_false(refused.replay())
	assert_eq(refused.played, 1, "stops at the action the rules refuse")
	_write({seed = SEED, kills = 0, actions = [{t = &"wait"}]})
	assert_true(SaveGame.load_from(PATH).replay())
