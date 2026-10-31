extends GutTest
## Rotten boards: a creature that steps off one leaves a hole in the sky.

const AT := Vector2i(5, 8)
const E := Vector2i(1, 0)


## An open hall walled at the edges, Miho at (4, 8), a rotten board at AT.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.depth = 6
	w.rng.seed = 5
	w.set_tile(AT, World.BOARD_ROTTEN)
	w.sense()
	return w


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


func test_a_rotten_board_holds_while_a_creature_stands_on_it_and_gives_way_when_it_steps_off(
) -> void:
	var w := _world()
	w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, AT)
	assert_eq(w.tile(AT), World.BOARD_ROTTEN, "she stands on it")
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.tile(AT), World.SKY)
	assert_eq(_of(events, &"crumble").size(), 1)
	assert_eq(_of(events, &"crumble")[0].at, AT)
	assert_false(w.vacant(AT), "no way back over the hole")


func test_a_board_that_gives_way_cracks_loud_enough_to_alarm_only_when_miho_made_it() -> void:
	var w := _world()
	w.act({t = &"move", dir = E})
	var cracks := _of(w.act({t = &"move", dir = E}), &"noise").filter(
		func(e): return e.word == "우지끈"
	)
	assert_eq(cracks.size(), 1)
	assert_eq(cracks[0].loud, Terrain.CRACK)
	var foe := FloorGen.spawn(w, &"dokkaebi", Vector2i(20, 8))
	w.set_tile(foe.pos, World.BOARD_ROTTEN)
	w.set_tile(foe.pos + E, World.FLOOR)
	Terrain.crumble(w, foe, foe.pos)
	assert_eq(w.tile(foe.pos), World.SKY, "heaven's steps break it too")
	assert_eq(foe.alert, Actor.REST, "a crack of heaven's own is no alarm")


func test_other_boards_and_other_floors_stay_when_stepped_off() -> void:
	var w := _world()
	w.set_tile(AT, World.BOARD)
	w.act({t = &"move", dir = E})
	w.act({t = &"move", dir = E})
	assert_eq(w.tile(AT), World.BOARD)
	assert_eq(w.tile(AT - E), World.FLOOR)


func test_a_creature_pushed_off_a_board_leaves_a_hole_too() -> void:
	var w := _world()
	w.player().pos = AT
	w.sense()
	w.push(w.player(), E, 2)
	assert_eq(w.tile(AT), World.SKY)


func test_the_hover_and_the_log_of_a_rotten_board() -> void:
	var w := _world()
	var text := Info.plain(Info.terrain(w, AT))
	assert_string_contains(text, "낡은 마루")
	assert_string_contains(text, "벗어난 뒤: 하늘")
	assert_string_contains(text, "소리: %d칸" % Terrain.CRACK)
	assert_string_contains(text, "삐걱 소리 3칸")
	w.act({t = &"move", dir = E})
	var events := _of(w.act({t = &"move", dir = E}), &"crumble")
	var lines: Array[String] = []
	lines.assign(Messages.of(w, w, events).map(Messages.plain))
	assert_eq(lines, ["낡은 마루가 꺼졌다"] as Array[String])
