extends StoreyShapes
## The broken building and the scattered pavilions, and the ruin that mixes them.


func before_all() -> void:
	for kind: StringName in [Skeletons.BROKEN, Skeletons.RUIN, Skeletons.SCATTERED]:
		_storeys(kind)


# --- the broken building --------------------------------------------------------


func test_the_broken_building_has_holes_in_its_floor_but_none_in_a_rooms_middle() -> void:
	for kind: StringName in [Skeletons.BROKEN, Skeletons.RUIN]:
		for w: World in _storeys(kind):
			assert_gte(_sky_by_floor(w), 20, _label(w))
			for r: Rect2i in w.rooms:
				assert_ne(w.tile(FloorGen._centre(r)), World.SKY, "%s %s" % [_label(w), r])


# --- the scattered pavilions ----------------------------------------------------


func test_the_scattered_storey_has_eight_to_twelve_pavilions_joined_by_bridges() -> void:
	for seed_value in 30:
		var w := Built.world(seed_value)
		w.depth = 4
		FloorGen._carve(w, Skeletons.SCATTERED)
		if FloorGen.connected(w):
			assert_between(_blocks(w), PAVILIONS.x, PAVILIONS.y, _label(w))
			assert_gt(w.tiles.count(World.BRIDGE), 0, _label(w))


func test_every_storey_of_bridges_has_planks_and_the_exit_stays_in_reach_once_they_burn() -> void:
	for kind: StringName in [Skeletons.SCATTERED, Skeletons.RUIN]:
		for w: World in _storeys(kind):
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
