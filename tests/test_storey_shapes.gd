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
		Skeletons.SCATTERED,
		Skeletons.GARDEN,
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


# --- the scattered pavilions ----------------------------------------------------


func test_the_scattered_storey_has_eight_to_twelve_pavilions_joined_by_bridges() -> void:
	for seed_value in 30:
		var w := World.create(seed_value)
		w.depth = 4
		FloorGen._carve(w, Skeletons.SCATTERED)
		if FloorGen.connected(w):
			assert_between(_blocks(w), PAVILIONS.x, PAVILIONS.y, _label(w))
			assert_gt(w.tiles.count(World.BRIDGE), 0, _label(w))


func test_every_storey_of_bridges_has_planks_and_the_exit_stays_in_reach_once_they_burn() -> void:
	for kind: StringName in [Skeletons.SCATTERED]:
		for w: World in _built[kind]:
			var planks := Skeletons.planks(w)
			assert_false(planks.is_empty(), _label(w))
			var v := w.clone()
			for p: Vector2i in planks:
				v.ignite(p)
			for i in World.BURN_ROUNDS:
				Terrain.burn(v, [])
			if v.depth != w.depth:
				continue
			for p: Vector2i in planks:
				assert_eq(v.tile(p), World.SKY, "%s %s" % [_label(w), p])
			var open := Masks.floor_of(v, v.traps.keys(), func(_p): return false)
			assert_gte(Grid.search(v.start, open).dist[Grid.index(_exit(v))], 0, _label(w))


func test_two_ways_counts_planks_but_the_route_left_by_fire_does_not() -> void:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.SKY)
	var home := Rect2i(2, 2, 6, 20)
	var goal := Rect2i(30, 2, 6, 20)
	FloorGen._fill(w, home, World.FLOOR)
	FloorGen._fill(w, goal, World.FLOOR)
	FloorGen._fill(w, Rect2i(8, 5, 22, 1), World.BOARD)
	FloorGen._fill(w, Rect2i(8, 15, 22, 1), World.BOARD)
	w.rooms.assign([home, goal])
	assert_true(Skeletons.two_ways(w, home, goal))
	assert_false(Skeletons.routes_hold(w, Skeletons.SCATTERED, home, goal), "both planks")
	FloorGen._fill(w, Rect2i(8, 15, 22, 1), World.BRIDGE)
	assert_true(Skeletons.routes_hold(w, Skeletons.SCATTERED, home, goal), "one of stone")


# --- the garden -----------------------------------------------------------------


func test_the_garden_has_hardly_a_wall_and_ponds_bamboo_and_reeds_in_clumps() -> void:
	for w: World in _built[Skeletons.GARDEN]:
		var walls := w.tiles.count(World.WALL)
		var ground := 0
		for t in w.tiles:
			ground += 1 if t != World.WALL and t != World.SKY and t != World.WINDOW else 0
		assert_gt(ground, walls * 3, _label(w))
		for t in [World.POND, World.BAMBOO, World.REEDS]:
			assert_gte(w.tiles.count(t), 8, "%s tile %d" % [_label(w), t])


func test_the_garden_has_walled_houses_for_what_needs_doors() -> void:
	var vaults := 0
	for w: World in _built[Skeletons.GARDEN]:
		vaults += 1 if not w.seals.is_empty() else 0
		var walled := w.rooms.filter(func(r): return EventRooms.doorways(w, r).size() <= 3)
		assert_gt(walled.size() + w.sites.size() + w.seals.size(), 0, _label(w))
	assert_gt(vaults, 0, "treasure rooms in the garden")
