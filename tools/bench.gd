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
	var run := SaveGame.new("", 5)
	var play := World.create(5)
	while run.actions.size() < 300 and play.outcome == &"":
		var a := {t = &"move", dir = Grid.DIRS[play.rng.randi() % 8]}
		if not play.can(a):
			a = {t = &"wait"}
		play.act(a)
		run.actions.append(a)
	t = Time.get_ticks_usec()
	run.replay()
	_say("replay %d rounds" % run.actions.size(), t)
	quit()


func _say(what: String, since: int) -> void:
	print("%-20s %8.1f ms" % [what, (Time.get_ticks_usec() - since) / 1000.0])
