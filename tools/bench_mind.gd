extends SceneTree
## The cost of the creatures' turns (Mind.heaven_phase) a round, by storey, for creatures as
## they lie and for all of them hunting Miho, with how often they look and find a way.
## godot --headless --path . -s tools/bench_mind.gd

const SEEDS := [11, 12, 13, 14, 15, 16]
const ROUNDS := 40


func _init() -> void:
	for hunting in [false, true]:
		for depth in [1, 3, 5, 7, 9]:
			_storey(depth, hunting)
	quit()


func _storey(depth: int, hunting: bool) -> void:
	var cost := 0
	var rounds := 0
	var foes := 0
	for s: int in SEEDS:
		var w := World.create(s)
		if depth > 1:
			Storeys.enter(w, depth)
		for a in w.actors:
			if hunting and not a.is_miho():
				a.brain.alert = Actor.HUNT
				a.brain.target = w.player().pos
		for r in ROUNDS:
			if w.outcome != &"":
				break
			var x := w.clone()
			var t := Time.get_ticks_usec()
			Mind.heaven_phase(x)
			cost += Time.get_ticks_usec() - t
			rounds += 1
			foes += w.actors.size() - 1
			w.act({t = &"wait"})
	print(
		(
			"%s storey %d: %.1f creatures, %d us a round"
			% ["hunting" if hunting else "as they lie", depth, float(foes) / rounds, cost / rounds]
		)
	)
