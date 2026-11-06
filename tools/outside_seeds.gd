extends SceneTree
## Prints `<seed> <design> <x> <y> <key> <sx> <sy>` of the first runs: the tile beside the
## trail's exit on storey 1, the key that steps onto it, and the sister's tile in the house, to
## capture one with `just shot --keys=at:X:Y,<key>`.
## godot --headless --path . -s tools/outside_seeds.gd

const SEEDS := 41
const KEYS := {
	Vector2i.UP: "Up", Vector2i.DOWN: "Down", Vector2i.LEFT: "Left", Vector2i.RIGHT: "Right"
}


func _init() -> void:
	for seed_value in SEEDS:
		var w := World.create(seed_value)
		for d: Vector2i in KEYS:
			var beside := w.trail_end - d
			if w.tile(beside) == World.COURTYARD:
				Round.trail(w)
				var sister := Sister.of(w).pos
				print(
					(
						"%d %s %d %d %s %d %d"
						% [
							seed_value,
							RunPlan.outside(seed_value),
							beside.x,
							beside.y,
							KEYS[d],
							sister.x,
							sister.y
						]
					)
				)
				break
	quit()
