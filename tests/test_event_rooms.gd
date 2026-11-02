extends GutTest
## How often the event rooms appear and whether the rules can open each one
## (tools/event_rooms.gd).

const EventRooms := preload("res://tools/event_rooms.gd")
const SEEDS := 40
const VAULT := "세 등불 보물방"

var _rows := {}


func before_all() -> void:
	_rows = EventRooms.measure(SEEDS, Built.storey)


func test_every_event_room_can_be_opened_from_the_start() -> void:
	for name: String in _rows:
		assert_gt(_rows[name].present, 0, name)
		assert_eq(_rows[name].stuck, [], name)


func test_a_vault_comes_up_in_about_two_storeys_in_five() -> void:
	var row: Dictionary = _rows[VAULT]
	assert_eq(row.storeys, SEEDS * World.FLOORS)
	assert_between(float(row.present) / row.storeys, 0.3, 0.5, "share of storeys")


func test_the_table_has_a_row_per_room_with_its_shares() -> void:
	var table := EventRooms.table({VAULT: {storeys = 8, present = 2, solvable = 2, stuck = []}})
	assert_string_contains(table, "| %s | 8 | 2 | 25.0%% | 2 | 100.0%% |" % VAULT)
