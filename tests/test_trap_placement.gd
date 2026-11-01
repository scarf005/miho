extends GutTest
## Where plates are laid: by tier, on bare floor, leaving the storey whole.

const WAIT := {t = &"wait"}
const SEEDS := 3
const KINDS := [World.TRAP_ALARM, World.TRAP_COLLAPSE, World.TRAP_FIRE, World.TRAP_VINE]

var _storeys: Array[World] = []


func before_all() -> void:
	for seed_value in SEEDS:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value)
			w.depth = depth
			FloorGen.build(w)
			_storeys.append(w)


# --- laying them -------------------------------------------------------------


func _rows() -> Array:
	return Placement.ROWS.filter(func(r): return r.get("hidden", false))


func test_each_plate_has_a_hidden_placement_row_with_its_tiers() -> void:
	var by_kind := {}
	for row in _rows():
		by_kind[row.what] = row.tiers
	assert_eq(by_kind.keys().size(), 4)
	assert_eq(by_kind[World.TRAP_ALARM], [1, 9])
	assert_eq(by_kind[World.TRAP_COLLAPSE], [2, 9])
	assert_eq(by_kind[World.TRAP_FIRE], [3, 9])
	assert_eq(by_kind[World.TRAP_VINE], [2, 9])


func test_a_storey_has_only_the_plates_its_tier_allows() -> void:
	var seen := {}
	for w in _storeys:
		for p: Vector2i in w.traps:
			var kind: int = w.traps[p]
			seen[kind] = true
			var row: Dictionary = _rows().filter(func(r): return r.what == kind)[0]
			assert_between(w.depth, row.tiers[0], row.tiers[1], "depth %d %s" % [w.depth, p])
	for kind in KINDS:
		assert_true(seen.has(kind), "kind %d is laid somewhere" % kind)


func test_no_storey_has_more_plates_of_a_kind_than_its_row_allows() -> void:
	for w in _storeys:
		for row in _rows():
			var n := w.traps.values().count(row.what)
			var corridor := SetRooms.PLATES.y if row.what == World.TRAP_ALARM else 0
			assert_lte(n, row.count[2] + corridor, "depth %d kind %d" % [w.depth, row.what])


func test_the_first_storey_has_only_alarm_plates() -> void:
	var alarms := 0
	for w in _storeys.filter(func(w): return w.depth == 1):
		for kind in w.traps.values():
			assert_eq(kind, World.TRAP_ALARM)
			alarms += 1
	assert_gt(alarms, 0)


func test_plates_lie_on_bare_floor_in_rooms_away_from_the_stairs_creatures_and_peaches() -> void:
	for w in _storeys:
		for p: Vector2i in w.traps:
			var ctx := "depth %d %s" % [w.depth, p]
			assert_true(w.rooms.any(func(r: Rect2i): return r.has_point(p)), ctx)
			assert_true(w.tile(p) in [World.FLOOR, w.traps[p]], ctx)
			assert_ne(p, w.start, ctx)
			assert_ne(p, w.stairs, ctx)
			assert_ne(p, w.elixir, ctx)
			assert_false(w.peaches.has(p), ctx)
			assert_null(w.actor_at(p), ctx)


func test_the_storey_stays_whole_with_every_plate_counted_as_a_wall() -> void:
	for w in _storeys:
		assert_true(FloorGen.connected(w, w.traps.keys()), "depth %d" % w.depth)


func test_a_plate_that_would_cut_a_one_wide_room_in_two_is_taken_out_again() -> void:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for x in range(2, 12):
		w.tiles[Grid.index(Vector2i(x, 5))] = World.FLOOR
	w.rooms.assign([Rect2i(2, 5, 10, 1)])
	w.rng.seed = 1
	var row: Dictionary = _rows()[0]
	assert_eq(Placement.lay(w, row, Vector2i(6, 5)), [] as Array[Vector2i])
	assert_eq(w.traps, {})
	w.rooms.assign([Rect2i(2, 5, 10, 1), Rect2i(2, 6, 10, 1)])
	for x in range(2, 12):
		w.tiles[Grid.index(Vector2i(x, 6))] = World.FLOOR
	assert_eq(Placement.lay(w, row, Vector2i(6, 5)), [Vector2i(6, 5)] as Array[Vector2i])
	assert_eq(w.traps, {Vector2i(6, 5): row.what})


func test_the_same_seed_lays_the_same_plates_and_finds_them_the_same_way() -> void:
	var runs := []
	for run in 2:
		var w := World.create(5)
		w.depth = 3
		FloorGen.build(w)
		w.sense()
		var events := []
		for i in 30:
			var dir: Vector2i = Grid.DIRS[(i * 3) % 8]
			events.append_array(
				w.act({t = &"move", dir = dir} if w.can({t = &"move", dir = dir}) else WAIT)
			)
		runs.append([w.traps, w.tiles, events, w.player().pos, w.depth])
	assert_gt(runs[0][0].size(), 0, "there are plates to compare")
	assert_eq(runs[0], runs[1])
