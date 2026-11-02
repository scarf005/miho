extends SceneTree
## Prints, per storey, how many of `seeds` builds place a creature of `kind`.
## godot --headless --path . -s tools/placed.gd -- mulgwisin 50


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := StringName(args[0])
	var seeds := int(args[1])
	for depth in range(1, World.FLOORS + 1):
		var got := 0
		for s in seeds:
			var w := World.create(s * World.FLOORS + depth)
			w.depth = depth
			FloorGen.build(w)
			got += 1 if w.actors.any(func(a): return a.kind == kind) else 0
		print("storey %d: %d placed, %d none" % [depth, got, seeds - got])
	quit()
