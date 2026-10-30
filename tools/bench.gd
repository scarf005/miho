extends SceneTree
## Times the work behind loading and each round: storey generation, sensing,
## one round of play, a step forecast, and a replay of saved actions (Continue).
## godot --headless --path . -s tools/bench.gd


func _init() -> void:
	var t := Time.get_ticks_usec()
	var w := World.create(3)
	_say("World.create", t)
	t = Time.get_ticks_usec()
	for i in 10:
		FloorGen.build(World.create(i))
	_say("10 more storeys", t)
	t = Time.get_ticks_usec()
	for i in 20:
		w.sense()
	_say("20 x sense", t)
	t = Time.get_ticks_usec()
	for i in 20:
		w.known_clone()
	_say("20 x known_clone", t)
	t = Time.get_ticks_usec()
	for d in Grid.DIRS:
		Forecast.of(w, {t = &"move", dir = d})
	_say("8 step forecasts", t)
	t = Time.get_ticks_usec()
	for i in 50:
		w.act({t = &"wait"})
	_say("50 x act(wait)", t)
	# Random walks (their own dice, so the world plays as it will on replay)
	# until 300 rounds in all, over as many runs as it takes.
	var runs: Array[SaveGame] = []
	var rounds := 0
	while rounds < 300:
		var run := SaveGame.new("", 5 + runs.size())
		var play := World.create(run.seed_value)
		var dice := RandomNumberGenerator.new()
		dice.seed = run.seed_value
		while rounds + run.actions.size() < 300 and play.outcome == &"":
			var a := {t = &"move", dir = Grid.DIRS[dice.randi() % 8]}
			if not play.can(a):
				a = {t = &"wait"}
			play.act(a)
			run.actions.append(a)
		runs.append(run)
		rounds += run.actions.size()
	t = Time.get_ticks_usec()
	for run in runs:
		if not run.replay():
			push_error("replay of seed %d stopped at %d" % [run.seed_value, run.played])
	_say("replay %d rounds" % rounds, t)
	quit()


func _say(what: String, since: int) -> void:
	print("%-20s %8.1f ms" % [what, (Time.get_ticks_usec() - since) / 1000.0])
