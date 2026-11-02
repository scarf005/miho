extends SceneTree
## Splits the cost of a waiting round into its phases, over many rounds. A fog
## bank keeps being laid in the first room (`bank` tiles across), so the gas
## phase and the sight that gas blocks are timed with a cloud about.
## godot --headless --path . -s tools/bench_round.gd


func _init() -> void:
	var w := World.create(3)
	var bank := Rect2i(w.start - Vector2i(3, 2), Vector2i(7, 5))
	var cost := {shots = 0, heaven = 0, burn = 0, gas = 0, end = 0, sense = 0, light = 0}
	var tiles := 0
	for i in 100:
		w.events = []
		w.heard = []
		for y in range(bank.position.y, bank.end.y):
			for x in range(bank.position.x, bank.end.x):
				Gas.put(w, Vector2i(x, y), Gas.FOG, Gas.MAX)
		w._changed()
		var t := Time.get_ticks_usec()
		Flight.phase(w)
		cost.shots += Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		Mind.heaven_phase(w)
		cost.heaven += Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		Terrain.burn(w, w.burning.keys())
		cost.burn += Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		Gas.tick(w)
		cost.gas += Time.get_ticks_usec() - t
		tiles += w.gas.size()
		t = Time.get_ticks_usec()
		w._end_round()
		cost.end += Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		w.sense()
		cost.sense += Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		w._changed()
		w.light()
		cost.light += Time.get_ticks_usec() - t
	for k in cost:
		print("%-8s %6.2f ms/round" % [k, cost[k] / 100000.0])
	print("gas tiles %d on average" % (tiles / 100))
	quit()
