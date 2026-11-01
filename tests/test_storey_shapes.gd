extends GutTest
## What each storey of a run is like: the broken building, the scattered pavilions, the
## pond garden, the keep and what comes of mixing them, and falling through their sky.

const SEEDS := 6
## How many pavilions a map of them has (least, most), and the hall of a broken building.
const PAVILIONS := Vector2i(8, 12)

## Every storey of each skeleton: [World], built once.
var _built := {}


func before_all() -> void:
	for kind: StringName in [
		Skeletons.BROKEN,
	]:
		_built[kind] = []
		for seed_value in SEEDS:
			for depth in range(1, World.FLOORS + 1):
				var w := World.create(seed_value * World.FLOORS + depth)
				w.depth = depth
				FloorGen.build(w, kind)
				_built[kind].append(w)


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


# --- the broken building --------------------------------------------------------


func test_the_broken_building_has_holes_in_its_floor_but_none_in_a_rooms_middle() -> void:
	for kind: StringName in [Skeletons.BROKEN]:
		for w: World in _built[kind]:
			assert_gte(_sky_by_floor(w), 20, _label(w))
			for r: Rect2i in w.rooms:
				assert_ne(w.tile(FloorGen._centre(r)), World.SKY, "%s %s" % [_label(w), r])


func test_no_hole_opens_beside_a_doorway() -> void:
	for w: World in _built[Skeletons.BROKEN]:
		for i in w.tiles.size():
			var p := Grid.at(i)
			if w.tiles[i] != World.DOOR and w.tiles[i] != World.DOOR_OPEN:
				continue
			for d in Grid.DIRS:
				assert_ne(w.tile(p + d), World.SKY, "%s %s" % [_label(w), p])
