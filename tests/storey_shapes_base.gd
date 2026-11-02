class_name StoreyShapes
extends GutTest
## What the scripts about the storeys of a run share (test_storey_shapes*): the storeys of each
## skeleton, built when a test asks for them, and ways to measure a storey.

const SEEDS := 6
## How many pavilions a map of them has (least, most), and the hall of a broken building.
const PAVILIONS := Vector2i(8, 12)

## Every storey of each skeleton asked for: [World].
var _built := {}


func _storeys(kind: StringName) -> Array:
	if not _built.has(kind):
		_built[kind] = []
		for seed_value in SEEDS:
			for depth in range(1, World.FLOORS + 1):
				_built[kind].append(Built.storey(seed_value * World.FLOORS + depth, depth, kind))
	return _built[kind]


func _label(w: World) -> String:
	return "seed %d storey %d" % [w.rng.seed, w.depth]


func _exit(w: World) -> Vector2i:
	return w.elixir if w.depth >= World.FLOORS else w.stairs


## The sky a walk round the map's edge across sky does not reach: holes and courts.
func _enclosed_sky(w: World) -> int:
	var sky := Grid.mask(w.tiles, Grid.table(func(t): return t == World.SKY))
	var outside: PackedInt32Array = Grid.search(Vector2i.ZERO, sky).dist
	var count := 0
	for i in sky.size():
		count += 1 if sky[i] == 1 and outside[i] < 0 else 0
	return count


## The tiles of sky with ground beside them: an outer wall keeps the sky outside from any.
func _sky_by_floor(w: World) -> int:
	var count := 0
	for i in w.tiles.size():
		if w.tiles[i] == World.SKY:
			var by_floor := func(d):
				return (
					w.open_floor(Grid.at(i) + d)
					and w.tile(Grid.at(i) + d) not in [World.BRIDGE, World.BOARD]
				)
			count += 1 if Placement.SIDES.any(by_floor) else 0
	return count


## The parts of the storey that stand apart with its bridges and planks taken away.
func _blocks(w: World) -> int:
	var solid := Grid.mask(
		w.tiles, Grid.table(func(t): return not t in [World.SKY, World.BRIDGE] and t != World.BOARD)
	)
	var seen := {}
	var count := 0
	for i in solid.size():
		if solid[i] == 0 or seen.has(i):
			continue
		count += 1
		var dist: PackedInt32Array = Grid.search(Grid.at(i), solid).dist
		for j in dist.size():
			if dist[j] >= 0:
				seen[j] = true
	return count
