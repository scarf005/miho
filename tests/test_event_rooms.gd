extends GutTest
## How often the event rooms appear and whether the rules can open each one
## (tools/event_rooms.gd).

const EventRooms := preload("res://tools/event_rooms.gd")
const SEEDS := 25
const VAULT := "세 등불 보물방"

var _rows := {}


func before_all() -> void:
	_rows = EventRooms.measure(SEEDS)


func test_every_event_room_can_be_opened_from_the_start() -> void:
	for name: String in _rows:
		assert_gt(_rows[name].present, 0, name)
		assert_eq(_rows[name].stuck, [], name)


func test_a_vault_comes_up_in_about_two_storeys_in_five() -> void:
	var row: Dictionary = _rows[VAULT]
	assert_eq(row.storeys, SEEDS * World.FLOORS)
	assert_between(float(row.present) / row.storeys, 0.3, 0.5, "share of storeys")


func test_a_vault_with_a_broken_lantern_is_not_opened() -> void:
	for seed_value in SEEDS:
		var w := World.create(seed_value)
		w.depth = 1
		FloorGen.build(w)
		for seal: Vector2i in w.seals:
			assert_true(EventRooms._vault_opens(w, seal), "seed %d" % seed_value)
			w.tiles[Grid.index(w.seals[seal][0])] = World.LANTERN_BROKEN
			assert_false(EventRooms._vault_opens(w, seal), "seed %d broken" % seed_value)
			return
	fail_test("no vault on storey 1 in %d seeds" % SEEDS)


func test_a_vault_with_a_lantern_beyond_reach_is_not_opened() -> void:
	for seed_value in SEEDS:
		var w := World.create(seed_value)
		w.depth = 1
		FloorGen.build(w)
		for seal: Vector2i in w.seals:
			var lantern: Vector2i = w.seals[seal][0]
			for d in Grid.DIRS:
				if w.open_floor(lantern + d):
					w.tiles[Grid.index(lantern + d)] = World.WALL
			assert_false(EventRooms._vault_opens(w, seal), "seed %d walled in" % seed_value)
			return
	fail_test("no vault on storey 1 in %d seeds" % SEEDS)


func test_the_table_has_a_row_per_room_with_its_shares() -> void:
	var table := EventRooms.table({VAULT: {storeys = 8, present = 2, solvable = 2, stuck = []}})
	assert_string_contains(table, "| %s | 8 | 2 | 25.0%% | 2 | 100.0%% |" % VAULT)
