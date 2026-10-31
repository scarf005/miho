extends GutTest
## Set rooms: layouts of terrain that one room of a storey is made into. Each is
## built on a plan of three rooms in a row, the first the start room and the
## last the goal room, and then on the generated storeys of many seeds.

const HOME := Rect2i(2, 2, 6, 8)
const MID := Rect2i(10, 2, 12, 9)
const GOAL := Rect2i(24, 2, 6, 8)
const SEEDS := 8


## Three rooms in a row, walled, with a doorway between each pair, tier `depth`'s.
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


# --- the storeys ---------------------------------------------------------------------


func _storeys() -> Array[World]:
	var out: Array[World] = []
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value)
			w.depth = depth
			FloorGen.build(w)
			out.append(w)
	return out


## The rooms that are reeds and shallow water and nothing else but lanterns and drums.
func _gardens(w: World) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for r in w.rooms:
		var kinds := _kinds(w, r)
		for t in [World.LANTERN, World.DRUM, World.REEDS, World.SHALLOW]:
			kinds.erase(t)
		if kinds.is_empty() and _count(w, r, World.SHALLOW) > 0 and _count(w, r, World.REEDS) > 0:
			out.append(r)
	return out


func test_storeys_hold_gardens_and_stay_whole() -> void:
	var gardens := 0
	for w in _storeys():
		var label := "seed %d storey %d" % [w.rng.seed, w.depth]
		assert_true(FloorGen.connected(w, w.traps.keys()), label)
		for r in _gardens(w):
			assert_ne(r, w.rooms[0], label)
			assert_false(r.has_point(w.stairs), label)
		gardens += 1 if not _gardens(w).is_empty() else 0
	assert_gt(gardens, SEEDS * World.FLOORS / 10)
