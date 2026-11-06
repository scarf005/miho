extends GutTest
## Whether the rules can open the treasure room of a storey (tools/event_rooms.gd): a pond, a
## broken lantern and a lantern out of reach.

const EventRooms := preload("res://tools/event_rooms.gd")
const SEEDS := 25


func before_all() -> void:
	for seed_value in 200:
		Built.storey(seed_value, 1)


## Ponds once grew round a lantern of the vault on storey 1 of some seeds. The 200 seeds
## come in four parts, so that each part stays a short test.
func _vault_lanterns_open(seeds: Array) -> void:
	for seed_value: int in seeds:
		var w := Built.storey(seed_value, 1)
		for seal: Vector2i in w.seals:
			assert_true(EventRooms._vault_opens(w, seal), "seed %d" % seed_value)


func test_a_pond_never_cuts_a_vault_lantern_off_seeds_0_to_49() -> void:
	_vault_lanterns_open(range(0, 50))


func test_a_pond_never_cuts_a_vault_lantern_off_seeds_50_to_99() -> void:
	_vault_lanterns_open(range(50, 100))


func test_a_pond_never_cuts_a_vault_lantern_off_seeds_100_to_149() -> void:
	_vault_lanterns_open(range(100, 150))


func test_a_pond_never_cuts_a_vault_lantern_off_seeds_150_to_199() -> void:
	_vault_lanterns_open(range(150, 200))


func test_storey_1_of_200_seeds_holds_vaults() -> void:
	var vaults := 0
	for seed_value in 200:
		vaults += Built.storey(seed_value, 1).seals.size()
	assert_gt(vaults, 40, "storey 1 of 200 seeds holds vaults")


func test_a_vault_with_a_broken_lantern_is_not_opened_by_its_lanterns() -> void:
	for seed_value in SEEDS:
		var w := Built.storey(seed_value, 1)
		for seal: Vector2i in w.seals:
			assert_true(EventRooms._vault_opens(w, seal), "seed %d" % seed_value)
			w.tiles[Grid.index(w.seals[seal][0])] = World.LANTERN_BROKEN
			assert_false(EventRooms._vault_opens(w, seal), "seed %d broken" % seed_value)
			return
	fail_test("no vault on storey 1 in %d seeds" % SEEDS)


func test_a_vault_with_a_lantern_beyond_reach_is_not_opened() -> void:
	for seed_value in SEEDS:
		var w := Built.storey(seed_value, 1)
		for seal: Vector2i in w.seals:
			var lantern: Vector2i = w.seals[seal][0]
			for d in Grid.DIRS:
				if w.open_floor(lantern + d):
					w.tiles[Grid.index(lantern + d)] = World.WALL
			assert_false(EventRooms._vault_opens(w, seal), "seed %d walled in" % seed_value)
			return
	fail_test("no vault on storey 1 in %d seeds" % SEEDS)
