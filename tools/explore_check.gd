extends SceneTree
## Replays a save (all but the last `back` actions), then explores as the o key
## does, round after round, and prints each step. It stops when there is
## nowhere left to go or Miho steps back and forth between two tiles (a loop).
## godot --headless --path . -s tools/explore_check.gd -- <save.cfg> [rounds] [back]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var run := SaveGame.load_from(args[0])
	if run == null:
		print("no save at %s" % args[0])
		quit(1)
		return
	run.begin()
	var upto := run.actions.size() - (int(args[2]) if args.size() > 2 else 0)
	while run.played < upto:
		if not run.step():
			print("the save does not replay at action %d" % run.played)
			quit(1)
			return
	var w := run.world
	var trail: Array[Vector2i] = []
	var memory := Sightings.new()
	for i in int(args[1]) if args.size() > 1 else 400:
		memory.update(w)
		var found := Travel.search(w, memory.at)
		var d := Travel.explore_step(w, found)
		var me := w.player().pos
		print("%d층 r%d at %s step %s" % [w.depth, w.round_no, me, d])
		if d == Vector2i.ZERO:
			print("stop: nowhere to go")
			break
		if w.tails >= w.max_tails():
			trail.append(me)
		if trail.size() >= 4 and trail[-1] == trail[-3] and trail[-2] == trail[-4]:
			print("loop between %s and %s" % [trail[-1], trail[-2]])
			quit(1)
			return
		w.act({t = &"move", dir = d} if w.tails >= w.max_tails() else {t = &"wait"})
	quit()
