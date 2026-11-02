extends GutTest
## Set rooms: layouts of terrain that one room of a storey is made into. Each is
## built on a plan of three rooms in a row, the first the start room and the
## last the goal room, and then on the generated storeys of many seeds.

const HOME := Rect2i(2, 2, 6, 8)
const MID := Rect2i(10, 2, 12, 9)
const GOAL := Rect2i(24, 2, 6, 8)
const HALL := Rect2i(10, 4, 12, 3)
const SEEDS := 8
## The tiles each kind leaves in its room: those it must hold, and the others it may.
const MADE_OF := {
	&"garden": [[World.REEDS, World.SHALLOW], []],
	&"granary": [[World.STRAW, World.CENSER], []],
	&"mist": [[World.POND], [World.FLOOR]],
	&"corridor": [[], [World.FLOOR]],
	&"statues": [[World.STATUE], [World.FLOOR]],
	&"rotten": [[World.BOARD_ROTTEN], [World.FLOOR]],
	&"swamp": [[World.MUD], [World.FLOOR]],
}

var _built: Array[Dictionary] = []


func before_all() -> void:
	_built = _storeys()


## Three rooms in a row, walled, with a doorway between each pair, on storey `depth`.
func _plan(depth := 1, mid := MID) -> World:
	var w := World.new()
	w.depth = depth
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	var rooms: Array[Rect2i] = [HOME, mid, GOAL]
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(HOME.end.x, mid.position.x) + range(mid.end.x, GOAL.position.x):
		w.tiles[Grid.index(Vector2i(x, 5))] = World.FLOOR
	w.rooms.assign(rooms)
	w.start = HOME.position + HOME.size / 2
	w.stairs = GOAL.position + GOAL.size / 2
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = w.start
	w.actors.append(me)
	w.rng.seed = 9
	w.sense()
	return w


func _count(w: World, r: Rect2i, t: int) -> int:
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			n += 1 if w.tile(Vector2i(x, y)) == t else 0
	return n


## The tiles of room `r`, by kind.
func _kinds(w: World, r: Rect2i) -> Dictionary:
	var out := {}
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out[w.tile(Vector2i(x, y))] = out.get(w.tile(Vector2i(x, y)), 0) + 1
	return out


# --- the choice --------------------------------------------------------------------


func test_a_set_room_is_never_the_start_room_or_the_goal_room() -> void:
	for seed_value in 20:
		var w := _plan()
		w.rng.seed = seed_value
		var before := w.tiles.duplicate()
		var built := SetRooms.build(w, HOME, GOAL)
		assert_eq(built.room, MID)
		for r in [HOME, GOAL]:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var i := Grid.index(Vector2i(x, y))
					assert_eq(w.tiles[i], before[i], "seed %d" % seed_value)


func test_a_room_too_small_for_any_kind_is_left_alone() -> void:
	var w := _plan(1, Rect2i(10, 2, 3, 3))
	var before := w.tiles.duplicate()
	assert_eq(SetRooms.build(w, HOME, GOAL), {})
	assert_eq(w.tiles, before)


func test_the_choice_leaves_the_worlds_draws_as_they_were_and_the_same_seed_picks_the_same(
) -> void:
	var a := _plan()
	var b := _plan()
	var state := a.rng.state
	var built := SetRooms.build(a, HOME, GOAL)
	assert_eq(a.rng.state, state, "no draw of the world's")
	assert_eq(SetRooms.build(b, HOME, GOAL), built)
	assert_eq(a.tiles, b.tiles)


func test_the_room_is_cleared_of_patches_plates_and_vents_but_keeps_its_lantern() -> void:
	var w := _plan()
	var lantern := MID.position
	w.tiles[Grid.index(lantern)] = World.LANTERN
	for p in [Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4)]:
		w.tiles[Grid.index(p)] = World.POND
	w.tiles[Grid.index(Vector2i(15, 6))] = World.BAMBOO
	w.traps[Vector2i(16, 6)] = World.TRAP_ALARM
	w.vents[Vector2i(12, 4)] = Gas.FOG
	Gas.put(w, Vector2i(12, 4), Gas.FOG, Gas.MAX)
	SetRooms.build(w, HOME, GOAL)
	assert_eq(w.tile(lantern), World.LANTERN)
	assert_false(w.traps.has(Vector2i(16, 6)))
	assert_false(w.vents.has(Vector2i(12, 4)))
	assert_false(w.gas.has(Vector2i(12, 4)))
	assert_eq(_count(w, MID, World.POND) + _count(w, MID, World.BAMBOO), 0)


# --- 갈대 정원 -----------------------------------------------------------------------


func test_a_garden_is_reeds_round_a_pool_of_shallow_water_in_the_middle() -> void:
	var w := _plan()
	assert_eq(SetRooms.build(w, HOME, GOAL).kind, &"garden")
	var pool := (mini(MID.size.x, MID.size.y) - 1) / 3
	var centre := MID.position + MID.size / 2
	for y in range(MID.position.y, MID.end.y):
		for x in range(MID.position.x, MID.end.x):
			var p := Vector2i(x, y)
			var water := Grid.cheb(p, centre) <= pool
			assert_eq(w.tile(p), World.SHALLOW if water else World.REEDS, str(p))
	assert_eq(_count(w, MID, World.SHALLOW), (2 * pool + 1) ** 2)


func test_a_garden_leaves_the_storey_whole_and_reeds_hide_what_stands_behind_them() -> void:
	var w := _plan()
	SetRooms.build(w, HOME, GOAL)
	assert_true(FloorGen.connected(w))
	assert_true(w.opaque(MID.position + Vector2i(1, 1)))


# --- 불타기 쉬운 곳간 -------------------------------------------------------------------


func _granary(w: World, r := MID) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	assert_true(SetRooms.make(w, &"granary", r, rng))


func _censers(w: World, r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if w.tile(Vector2i(x, y)) == World.CENSER:
				out.append(Vector2i(x, y))
	return out


func test_a_granary_is_straw_all_over_with_a_censer_that_breathes_incense() -> void:
	var w := _plan(2)
	_granary(w)
	var kinds := _kinds(w, MID)
	assert_eq(kinds.keys().size(), 2)
	assert_eq(kinds[World.CENSER], 2, "two in a room of %d tiles" % MID.get_area())
	assert_eq(kinds[World.STRAW] + kinds[World.CENSER], MID.get_area())
	for p in _censers(w, MID):
		assert_eq(w.vents[p], Gas.INCENSE)
		assert_eq(w.gas[p].x, Gas.INCENSE)
	assert_true(FloorGen.connected(w))


func test_a_small_granary_holds_one_censer() -> void:
	var w := _plan(2, Rect2i(10, 2, 5, 5))
	_granary(w, Rect2i(10, 2, 5, 5))
	assert_eq(_censers(w, Rect2i(10, 2, 5, 5)).size(), 1)


func test_a_censer_never_goes_where_it_would_cut_the_storey_apart() -> void:
	var lane := Rect2i(10, 5, 1, 12)
	var w := _plan(2, lane)
	_granary(w, lane)
	assert_eq(_censers(w, lane), [Vector2i(10, 16)] as Array[Vector2i], "only the dead end")
	assert_true(FloorGen.connected(w))


func test_a_spark_spreads_over_the_straw_of_a_granary() -> void:
	var w := _plan(2)
	_granary(w)
	w.ignite(Vector2i(16, 6))
	for i in 8:
		w.act({t = &"wait"})
	var burnt := _count(w, MID, World.ASH) + w.burning.size()
	assert_gt(burnt, MID.get_area() / 2, "most of the room is alight or ash")


func test_knocking_a_censer_over_lights_the_straw_beside_it() -> void:
	var w := _plan(2)
	_granary(w)
	var censer := _censers(w, MID)[0]
	w.player().pos = censer + Vector2i.LEFT
	w.sense()
	w.act({t = &"move", dir = Vector2i.RIGHT})
	assert_eq(w.tile(censer), World.FLOOR)
	assert_true(w.burning.size() > 0, "the straw beside it burns")
	assert_true(w.hot.has(censer))


# --- 안개 연못 -------------------------------------------------------------------------


func _ponds(w: World, r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if w.tile(Vector2i(x, y)) == World.POND:
				out.append(Vector2i(x, y))
	return out


func test_a_mist_room_is_a_pond_from_the_middle_breathing_fog_from_every_tile() -> void:
	var w := _plan(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	assert_true(SetRooms.make(w, &"mist", MID, rng))
	var pond := _ponds(w, MID)
	assert_gte(pond.size(), SetRooms.POND_LEAST)
	assert_true(pond.has(MID.position + MID.size / 2), "it grows from the middle")
	for p in pond:
		assert_eq(w.vents.get(p), Gas.FOG, str(p))
	assert_eq(w.vents.size(), pond.size(), "no vent but on the pond")
	assert_true(FloorGen.connected(w))
	for i in 6:
		w.act({t = &"wait"})
	assert_true(pond.any(func(p): return w.opaque(p)), "the fog blocks sight")


func test_a_pond_that_would_cut_the_storey_apart_leaves_the_room_as_it_was() -> void:
	var lane := Rect2i(10, 5, 12, 1)
	var w := _plan(3, lane)
	var before := w.tiles.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	assert_false(SetRooms.make(w, &"mist", lane, rng))
	assert_eq(w.tiles, before)
	assert_true(w.vents.is_empty() and w.gas.is_empty())


# --- 경보 복도 -------------------------------------------------------------------------


func _corridor(w: World, r := HALL) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	return SetRooms.make(w, &"corridor", r, rng)


func test_a_corridor_hides_alarm_plates_on_the_floor_of_a_narrow_dark_room() -> void:
	var w := _plan(4, HALL)
	assert_true(_corridor(w))
	assert_between(w.traps.size(), SetRooms.PLATES.x, SetRooms.PLATES.y)
	for p in w.traps:
		assert_eq(w.traps[p], World.TRAP_ALARM)
		assert_true(HALL.has_point(p), str(p))
	assert_true(FloorGen.connected(w, w.traps.keys()), "round the plates, home meets goal")


func test_a_plate_that_would_wall_off_the_storey_is_not_laid() -> void:
	var lane := Rect2i(10, 5, 12, 1)
	var w := _plan(4, lane)
	assert_false(_corridor(w, lane), "every plate of the only way through cuts it")
	assert_true(w.traps.is_empty())


func test_a_wide_or_short_or_lit_room_is_no_corridor() -> void:
	for r in [MID, Rect2i(10, 4, 6, 3)]:
		var w := _plan(4, r)
		assert_false(_corridor(w, r), str(r))
		assert_true(w.traps.is_empty())
	var lit := _plan(4, HALL)
	lit.tiles[Grid.index(HALL.position)] = World.LANTERN
	assert_false(_corridor(lit), "a lantern lights it")
	assert_true(lit.traps.is_empty())


# --- 깨어나는 석상 ----------------------------------------------------------------------


func _statues(w: World, r := MID) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	return SetRooms.make(w, &"statues", r, rng)


func test_a_hall_of_statues_stands_three_in_a_large_room_clear_of_the_edge() -> void:
	var w := _plan(5)
	assert_true(_statues(w))
	var at: Array[Vector2i] = []
	for y in range(MID.position.y, MID.end.y):
		for x in range(MID.position.x, MID.end.x):
			if w.tile(Vector2i(x, y)) == World.STATUE:
				at.append(Vector2i(x, y))
	assert_eq(at.size(), 3, "a room of %d tiles" % MID.get_area())
	for p in at:
		assert_true(MID.grow(-1).has_point(p), str(p))
	assert_true(FloorGen.connected(w))


func test_a_small_hall_of_statues_stands_two() -> void:
	var small := Rect2i(10, 3, 6, 6)
	var w := _plan(5, small)
	assert_true(_statues(w, small))
	assert_eq(_count(w, small, World.STATUE), 2)


func test_a_room_with_no_inner_floor_for_the_statues_is_left_as_it_was() -> void:
	var thin := Rect2i(10, 4, 12, 2)
	var w := _plan(5, thin)
	var before := w.tiles.duplicate()
	assert_false(_statues(w, thin))
	assert_eq(w.tiles, before)


func test_a_statue_hall_wakes_its_statues_as_miho_crosses_it() -> void:
	var w := _plan(5)
	_statues(w)
	var woke := 0
	for x in range(w.player().pos.x, GOAL.position.x):
		w.player().pos = Vector2i(x, 5)
		w.sense()
		woke += w.act({t = &"wait"}).filter(func(e): return e.t == &"wake").size()
	assert_gt(woke, 0, "crossing the room along its middle row")
	assert_eq(_count(w, MID, World.STATUE) + woke, 3)


# --- 무너지는 마루 ----------------------------------------------------------------------


func _rotten(w: World, r := MID) -> bool:
	var rng := RandomNumberGenerator.new()
	return SetRooms.make(w, &"rotten", r, rng)


func test_a_rotten_floor_is_boards_on_every_other_tile_off_the_edge_of_the_room() -> void:
	var w := _plan(6)
	assert_true(_rotten(w))
	for y in range(MID.position.y, MID.end.y):
		for x in range(MID.position.x, MID.end.x):
			var p := Vector2i(x, y)
			var rotten := MID.grow(-1).has_point(p) and (x + y) % 2 == 1
			assert_eq(w.tile(p), World.BOARD_ROTTEN if rotten else World.FLOOR, str(p))
	assert_true(FloorGen.connected(w))


func test_with_the_boards_gone_to_holes_every_plain_tile_still_meets_the_rest() -> void:
	var w := _plan(6)
	_rotten(w)
	for y in range(MID.position.y, MID.end.y):
		for x in range(MID.position.x, MID.end.x):
			if w.tile(Vector2i(x, y)) == World.BOARD_ROTTEN:
				w.tiles[Grid.index(Vector2i(x, y))] = World.SKY
	assert_true(FloorGen.connected(w))


func test_a_room_too_small_for_six_boards_is_left_as_it_was() -> void:
	var small := Rect2i(10, 3, 5, 5)
	var w := _plan(6, small)
	var before := w.tiles.duplicate()
	assert_false(_rotten(w, small))
	assert_eq(w.tiles, before)


# --- 늪지 -------------------------------------------------------------------------------


func _swamp(w: World, r := MID) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	return SetRooms.make(w, &"swamp", r, rng)


func test_a_swamp_is_mud_from_the_middle_with_marsh_gas_rising_from_three_tiles_of_it() -> void:
	var w := _plan(7)
	assert_true(_swamp(w))
	var mud := _count(w, MID, World.MUD)
	assert_gte(mud, SetRooms.MUD_LEAST)
	assert_eq(w.tile(MID.position + MID.size / 2), World.MUD, "it grows from the middle")
	assert_eq(w.vents.size(), SetRooms.MARSH_VENTS + 1, "a room of %d tiles" % MID.get_area())
	for p in w.vents:
		assert_eq(w.tile(p), World.MUD, str(p))
		assert_eq(w.vents[p], Gas.MARSH)
		assert_eq(w.gas[p].x, Gas.MARSH)
	assert_true(FloorGen.connected(w))


func test_a_small_swamp_has_two_vents() -> void:
	var small := Rect2i(10, 3, 7, 5)
	var w := _plan(7, small)
	assert_true(_swamp(w, small))
	assert_eq(w.vents.size(), SetRooms.MARSH_VENTS)


func test_mud_that_stays_under_six_tiles_leaves_the_room_as_it_was() -> void:
	var small := Rect2i(10, 4, 2, 2)
	var w := _plan(7, small)
	var before := w.tiles.duplicate()
	assert_false(_swamp(w, small))
	assert_eq(w.tiles, before)
	assert_true(w.vents.is_empty() and w.gas.is_empty())


func test_a_spark_in_a_swamp_sets_off_its_marsh_gas() -> void:
	var w := _plan(7)
	_swamp(w)
	var vent: Vector2i = w.vents.keys()[0]
	w.ignite(vent)
	assert_eq(w.events.filter(func(e): return e.t == &"blast").size(), 1)
	assert_false(w.gas.has(vent))


# --- the storeys ---------------------------------------------------------------------


## Every storey of several seeds: {w, set}, the world and the set room it was given.
func _storeys() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var row := Built.made(seed_value * World.FLOORS + depth, depth)
			out.append({w = row.w, set = row.made})
	return out


func _is_built(w: World, kind: StringName, r: Rect2i) -> bool:
	var kinds := _kinds(w, r)
	for t in (
		[World.LANTERN, World.LANTERN_OUT, World.DRUM, World.SKY]
		+ MADE_OF[kind][0]
		+ MADE_OF[kind][1]
	):
		kinds.erase(t)
	return kinds.is_empty() and MADE_OF[kind][0].all(func(t): return _count(w, r, t) > 0)


func test_storeys_hold_each_set_room_from_its_tier_and_stay_whole() -> void:
	var storeys := {}
	for s in _built:
		var w: World = s.w
		var label := "seed %d storey %d" % [w.rng.seed, w.depth]
		assert_true(FloorGen.connected(w, w.traps.keys()), label)
		if s.set.is_empty():
			continue
		storeys[s.set.kind] = storeys.get(s.set.kind, 0) + 1
		assert_true(w.rooms.has(s.set.room), label)
		assert_ne(s.set.room, w.rooms[0], label)
		assert_false(s.set.room.has_point(w.stairs), label)
		assert_false(s.set.room.has_point(w.elixir), label)
		assert_true(_is_built(w, s.set.kind, s.set.room), "%s %s" % [label, s.set.kind])
		if s.set.kind == &"corridor":
			var plates: Array = w.traps.keys().filter(func(p): return s.set.room.has_point(p))
			assert_gte(plates.size(), SetRooms.PLATES.x, label)
		var first: int = SetRooms.ROWS.filter(func(row): return row.kind == s.set.kind)[0].tier
		assert_gte(w.depth, first, label)
	for row: Dictionary in SetRooms.ROWS:
		assert_gt(storeys.get(row.kind, 0), 0, str(row.kind))
