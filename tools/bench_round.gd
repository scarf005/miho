extends SceneTree
## Splits the cost of a waiting round into its phases, over many rounds.
## godot --headless --path . -s tools/bench_round.gd


func _init() -> void:
	var w := World.create(3)
	var cost := {shots = 0, heaven = 0, burn = 0, end = 0, sense = 0, light = 0}
	for i in 100:
		w.events = []
		w.heard = []
		w._changed()
		var t := Time.get_ticks_usec()
		w._shots_phase()
		cost.shots += Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		Mind.heaven_phase(w)
		cost.heaven += Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		w._burn()
		cost.burn += Time.get_ticks_usec() - t
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
	quit()
