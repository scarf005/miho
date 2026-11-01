extends GutTest
## Planks: 마루 with sky on two opposite sides burns away to the sky.

const ROW := 8
const AT := Vector2i(12, ROW)
const WAIT := {t = &"wait"}
const SEEDS := 200


## Two floors with a bridge of planks between them on ROW, x from 11 to 15, Miho on the
## west floor on storey `depth`; the storeys below are kept as all floor.
func _world(depth := 2) -> World:
	var w := World.new()
	w.rng.seed = 7
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.FLOOR)
	w.rooms.assign([Rect2i(1, 1, 8, 20)])
	for below in range(1, depth):
		w.depth = below
		Storeys.leave(w)
	w.tiles.fill(World.SKY)
	FloorGen._fill(w, Rect2i(1, 1, 10, 20), World.FLOOR)
	FloorGen._fill(w, Rect2i(16, 1, 10, 20), World.FLOOR)
	FloorGen._fill(w, Rect2i(11, ROW, 5, 1), World.BOARD)
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(3, 3)
	w.actors.append(me)
	w.depth = depth
	w.sense()
	return w


func _burn_out(w: World, p: Vector2i) -> void:
	w.ignite(p)
	for i in World.BURN_ROUNDS:
		Terrain.burn(w, [])


func test_a_plank_burns_away_to_the_sky_and_a_board_on_a_floor_to_ash() -> void:
	var w := _world()
	_burn_out(w, AT)
	assert_eq(w.tile(AT), World.SKY)
	var floor_board := Vector2i(5, 5)
	w.set_tile(floor_board, World.BOARD)
	_burn_out(w, floor_board)
	assert_eq(w.tile(floor_board), World.ASH)


func test_a_ledge_with_sky_on_one_side_only_burns_to_ash() -> void:
	var w := _world()
	var ledge := Vector2i(10, 3)
	w.set_tile(ledge, World.BOARD)
	assert_false(Terrain.plank(w, ledge))
	_burn_out(w, ledge)
	assert_eq(w.tile(ledge), World.ASH)


func test_a_plank_gives_way_with_a_crack_and_the_sound_of_a_fall() -> void:
	var w := _world()
	_burn_out(w, AT)
	var cracks := w.events.filter(func(e): return e.t == &"crumble" and e.at == AT)
	assert_eq(cracks.size(), 1)
	assert_eq(Sfx.sound_of(cracks[0]), &"fall")
	assert_false(w.events.any(func(e): return e.t == &"burnout" and e.at == AT), "no ash")


func test_wild_fire_turns_each_plank_it_reaches_to_sky_whatever_the_seed() -> void:
	var far_end_burnt := 0
	for seed_value in SEEDS:
		var w := _world()
		w.rng.seed = seed_value
		w.ignite(AT, false, true)
		for i in 60:
			Terrain.burn(w, [])
		for x in range(11, 14):
			assert_eq(w.tile(Vector2i(x, ROW)), World.SKY, "seed %d x %d" % [seed_value, x])
		for x in range(14, 16):
			assert_ne(w.tile(Vector2i(x, ROW)), World.ASH, "seed %d x %d" % [seed_value, x])
		far_end_burnt += 1 if w.tile(Vector2i(15, ROW)) == World.SKY else 0
	assert_gt(far_end_burnt, 0, "the fire runs on to the far end")


func test_the_hover_tells_what_a_plank_leaves_when_burnt_and_a_board_on_a_floor_says_nothing(
) -> void:
	var w := _world()
	var floor_board := Vector2i(5, 5)
	w.set_tile(floor_board, World.BOARD)
	w.seen.fill(1)
	var plank_says := Info.plain(Info.terrain_facts(w, AT))
	var board_says := Info.plain(Info.terrain_facts(w, floor_board))
	_burn_out(w, AT)
	assert_string_contains(plank_says, "탄 뒤: %s" % Tiles.of(w.tile(AT), "name"))
	assert_false(board_says.contains("탄 뒤"), board_says)


func test_a_creature_on_a_plank_falls_when_it_gives_way() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", AT)
	_burn_out(w, AT)
	assert_false(foe.alive())
	assert_true(w.events.any(func(e): return e.t == &"fall" and e.id == foe.id))


func test_miho_on_a_plank_falls_a_storey_after_the_creatures_on_the_others() -> void:
	var w := _world(3)
	var me := w.player()
	me.pos = AT
	var foe := FloorGen.spawn(w, &"dokkaebi", AT + Vector2i.RIGHT)
	w.ignite(AT)
	w.ignite(AT + Vector2i.RIGHT)
	for i in World.BURN_ROUNDS:
		Terrain.burn(w, [])
	assert_eq(w.depth, 2)
	assert_eq(me.pos, AT, "she lands where she fell")
	assert_eq(me.hp, 3 - Fall.DAMAGE)
	assert_false(foe.alive(), "the other plank's creature fell too, on its storey")
	assert_eq(w.storeys[3].tiles[Grid.index(AT)], World.SKY)
	assert_eq(w.storeys[3].tiles[Grid.index(AT + Vector2i.RIGHT)], World.SKY)


func test_a_burnt_plank_leaves_no_way_across() -> void:
	var w := _world()
	var from := Vector2i(5, ROW)
	var to := Grid.index(Vector2i(20, ROW))
	assert_gte(Grid.search(from, Masks.floor_of(w)).dist[to], 0)
	for x in range(11, 16):
		_burn_out(w, Vector2i(x, ROW))
	assert_lt(Grid.search(from, Masks.floor_of(w)).dist[to], 0)
