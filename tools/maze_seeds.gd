extends SceneTree
## Prints `<seed> <depth> <concept>` of the first runs that draw a 미궁, to capture one with `just shot`.
## godot --headless --path . -s tools/maze_seeds.gd

const SEEDS := 40


func _init() -> void:
	for seed_value in SEEDS:
		var maze := RunPlan.labyrinth(seed_value)
		if maze.depth > 0:
			print("%d %d %s" % [seed_value, maze.depth, maze.concept])
	quit()
