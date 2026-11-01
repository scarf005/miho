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
		Skeletons.KEEP,
		Skeletons.RUIN,
		Skeletons.CITADEL,
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


# --- the run ------------------------------------------------------------------


func test_a_run_walks_nine_different_places_and_a_seed_varies_only_their_shape() -> void:
	var w := World.new()
	var places := {}
	for depth in range(1, World.FLOORS + 1):
		w.depth = depth
		var state := w.rng.state
		var place := Skeletons.pick(w)
		assert_eq(w.rng.state, state, "the storey decides, not the draw")
		assert_false(places.has(place), str(depth))
		places[place] = true


func test_the_old_pavilions_are_no_storey_of_a_run_and_every_other_skeleton_is() -> void:
	var w := World.new()
	var used := {}
	for depth in range(1, World.FLOORS + 1):
		w.depth = depth
		used[Skeletons.pick(w)] = true
	for kind in Skeletons.ALL:
		assert_eq(used.has(kind), kind != Skeletons.PAVILIONS, kind)


# --- the broken building --------------------------------------------------------


func test_the_broken_building_has_holes_in_its_floor_but_none_in_a_rooms_middle() -> void:
	for kind: StringName in [Skeletons.BROKEN, Skeletons.RUIN]:
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
	for kind: StringName in [Skeletons.SCATTERED, Skeletons.RUIN]:
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


# --- the keep -------------------------------------------------------------------


## The doorways on the walk from `from` to `to` without which there is no walk, in order
## from `from`.
func _gates(w: World, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var open := Masks.floor_of(w, [], func(_p): return false)
	var found: Dictionary = Grid.search(from, open)
	var at := Grid.index(to)
	var out: Array[Vector2i] = []
	while at >= 0:
		var p := Grid.at(at)
		if not FloorGen.room_at(w, p).has_area() and p != to and p != from:
			var shut := open.duplicate()
			shut[at] = 0
			if Grid.search(from, shut).dist[Grid.index(to)] < 0:
				out.push_front(p)
		at = found.parent[at]
	return out


## Draws `kind`, with nothing laid on it yet; returns the plan's goal.
func _drawn(kind: StringName, w: World) -> Rect2i:
	w.depth = 7
	return FloorGen._carve(w, kind).goal


func test_each_wall_of_the_keep_has_one_way_in_on_the_side_opposite_the_next() -> void:
	for seed_value in 30:
		var w := World.create(seed_value)
		var core := _drawn(Skeletons.KEEP, w)
		var mid := FloorGen._centre(core)
		var gates := _gates(w, FloorGen._centre(w.rooms[0]), mid)
		var label := "seed %d %s" % [seed_value, gates]
		assert_eq(gates.size(), 2, label)
		var a: Vector2i = gates[0] - mid
		var b: Vector2i = gates[1] - mid
		assert_true(a.x * b.x < 0 or a.y * b.y < 0, label)


func test_the_hidden_doors_of_the_keep_skip_a_wall() -> void:
	var skips := 0
	for w: World in _built[Skeletons.KEEP]:
		var plain: int = Grid.search(w.start, Masks.floor_of(w)).dist[Grid.index(_exit(w))]
		var v := w.clone()
		for p: Vector2i in w.secrets:
			v.set_tile(p, World.DOOR)
		var found: int = Grid.search(v.start, Masks.floor_of(v)).dist[Grid.index(_exit(v))]
		skips += 1 if found < plain else 0
	assert_gt(skips, _built[Skeletons.KEEP].size() / 2, "a shorter way once they are found")


func test_the_citadel_holds_its_exit_in_a_keep_on_an_island_of_sky_with_one_bridge() -> void:
	for seed_value in 30:
		var w := World.create(seed_value)
		var core := _drawn(Skeletons.CITADEL, w)
		var label := "seed %d" % seed_value
		assert_gte(_enclosed_sky(w), 40, label)
		var bridges: Array[int] = []
		for i in w.tiles.size():
			if w.tiles[i] == World.BRIDGE:
				bridges.append(i)
		assert_gt(bridges.size(), 0, label)
		var mid := Grid.index(FloorGen._centre(core))
		var from := FloorGen._centre(w.rooms[0])
		var open := Masks.floor_of(w)
		assert_gte(Grid.search(from, open).dist[mid], 0, label)
		for i in bridges:
			open[i] = 0
		assert_lt(Grid.search(from, open).dist[mid], 0, "%s: the only way over" % label)


## Seeds whose first wings all came up sky, and left the ring no room to start in.
func test_the_citadel_starts_in_a_room_by_its_ring_when_its_first_wings_come_up_empty() -> void:
	for seed_value in [480, 829, 841]:
		var w := World.create(seed_value)
		var core := _drawn(Skeletons.CITADEL, w)
		var from := FloorGen._centre(w.rooms[0])
		assert_ne(w.rooms[0], core, str(seed_value))
		assert_gt(Grid.search(from, Masks.floor_of(w)).dist[Grid.index(FloorGen._centre(core))], 0)


func test_the_boss_of_the_citadel_stands_with_the_elixir() -> void:
	for w: World in _built[Skeletons.CITADEL]:
		if w.depth != World.FLOORS:
			continue
		var boss: Array = w.actors.filter(func(a): return a.kind == &"cheonnyeon")
		assert_eq(boss.size(), 1, _label(w))
		var keep := FloorGen.room_at(w, w.elixir)
		assert_true(keep.has_point(boss[0].pos), _label(w))


# --- falling through the sky ------------------------------------------------------


## A run on `seed_value` built by the table up to `depth`, each storey left behind.
func _run(seed_value: int, depth: int) -> World:
	var w := World.create(seed_value)
	for d in range(1, depth):
		Storeys.leave(w)
		Storeys.enter(w, d + 1)
	return w


func test_a_fall_through_a_hole_chains_through_sky_below_and_lands_on_something_to_stand_on(
) -> void:
	var chained := 0
	for seed_value in 4:
		var top := _run(seed_value, 5)
		for i in top.tiles.size():
			if top.tiles[i] != World.SKY or i % 7 != 0:
				continue
			var w := top.clone()
			var me := w.player()
			me.hp = 100
			me.max_hp = 100
			Fall.drop(w, me, Grid.at(i))
			var fell := 5 - w.depth
			assert_gt(fell, 0, str(Grid.at(i)))
			assert_eq(me.hp, 100 - fell * Fall.DAMAGE)
			assert_true(w.open_floor(me.pos), "%d %s" % [w.depth, me.pos])
			for between in range(w.depth + 1, 5):
				assert_eq(w.storeys[between].tiles[i], World.SKY, "sky all the way down")
			chained += 1 if fell > 1 else 0
	assert_gt(chained, 0, "some falls go through more than one storey")


func test_the_court_of_the_ring_on_the_second_storey_drops_to_the_first() -> void:
	for seed_value in 4:
		var top := _run(seed_value, 3)
		var ring: PackedByteArray = top.storeys[2].tiles
		var w := top.clone()
		var me := w.player()
		me.hp = 100
		me.max_hp = 100
		var into := Vector2i(-1, -1)
		for i in ring.size():
			if ring[i] == World.SKY and top.tiles[i] == World.SKY and Grid.at(i).x > 10:
				into = Grid.at(i)
		Fall.drop(w, me, into)
		assert_eq(w.depth, 1, str(into))
		assert_eq(me.hp, 100 - 2 * Fall.DAMAGE)
		assert_true(w.open_floor(me.pos))
