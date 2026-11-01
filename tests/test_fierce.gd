extends GutTest
## 인화성 tiles: fire on them runs two steps a round and burns for more than
## ordinary fire (Terrain.burn).

const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)
const FROM := Vector2i(10, 8)


## An open hall walled at the edges, Miho at ME with plenty of health.
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
	me.hp = 9
	me.max_hp = 9
	me.pos = ME
	w.actors.append(me)
	w.depth = 2
	w.tails = 4
	w.sense()
	return w


## Tiles of `kind` along the row from FROM, `gaps` listing the offsets left as floor,
## with fire on the first (always spreading when `wild`).
func _row(kind: int, length: int, gaps := [], wild := false) -> World:
	var w := _world()
	for i in length:
		w.tiles[Grid.index(FROM + Vector2i(i, 0))] = World.FLOOR if gaps.has(i) else kind
	w._changed()
	w.burning[FROM] = World.BURN_ROUNDS
	if wild:
		w.wild[FROM] = true
	return w


func _alight(w: World, length: int) -> Array:
	return range(length).filter(func(i): return w.burning.has(FROM + Vector2i(i, 0)))


func test_fire_crosses_two_fierce_tiles_in_one_round() -> void:
	for kind in [World.STRAW, World.LEAVES, World.REEDS, World.REEDS_FLAT, World.SHELF]:
		var w := _row(kind, 5)
		w.act(WAIT)
		assert_eq(_alight(w, 5), [0, 1, 2], str(kind))


func test_fierce_fire_stops_at_a_gap() -> void:
	var w := _row(World.STRAW, 5, [2])
	w.act(WAIT)
	assert_eq(_alight(w, 5), [0, 1], "the floor in between holds it")
	w = _row(World.STRAW, 5, [1])
	w.act(WAIT)
	assert_eq(_alight(w, 5), [0], "a gap right next to the fire holds it a round")


func test_ordinary_fire_takes_one_step_a_round() -> void:
	var w := _row(World.BOARD, 5, [], true)
	w.act(WAIT)
	assert_eq(_alight(w, 5), [0, 1])
	w.wild[FROM + Vector2i(1, 0)] = true
	w.act(WAIT)
	assert_eq(_alight(w, 5), [0, 1, 2], "one more tile the next round")


func test_a_fierce_tile_ordinary_fire_catches_spreads_on_in_the_same_round() -> void:
	var w := _row(World.BOARD, 4, [], true)
	w.tiles[Grid.index(FROM + Vector2i(1, 0))] = World.STRAW
	w.tiles[Grid.index(FROM + Vector2i(2, 0))] = World.STRAW
	w._changed()
	w.act(WAIT)
	assert_eq(_alight(w, 4), [0, 1, 2], "it is the fierce tile that runs on")


func _stand_in_fire(kind: int) -> int:
	var w := _row(kind, 2)
	w.burning.erase(FROM)
	w.burning[ME] = World.BURN_ROUNDS
	w.tiles[Grid.index(ME)] = kind
	w._changed()
	w.act(WAIT)
	return 9 - w.player().hp


func test_standing_in_fierce_fire_costs_three_and_in_ordinary_fire_two() -> void:
	assert_eq(_stand_in_fire(World.STRAW), World.FIERCE_DAMAGE)
	assert_eq(_stand_in_fire(World.BOARD), World.FIRE_DAMAGE)
	assert_gt(World.FIERCE_DAMAGE, World.FIRE_DAMAGE)


func test_a_creature_alight_burns_for_two_even_on_fierce_ground() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"jangseung", ME + Vector2i(6, 0))
	foe.cooldown = 99
	foe.hp = 9
	foe.max_hp = 9
	w.tiles[Grid.index(foe.pos)] = World.STRAW
	w.sense()
	foe.alight = 3
	w.act(WAIT)
	assert_eq(foe.hp, 9 - World.FIRE_DAMAGE)


func test_the_preview_of_fierce_fire_is_the_round() -> void:
	var w := _row(World.REEDS, 6)
	w.rng.seed = 3
	var f := w.preview(WAIT)
	w.act(WAIT)
	assert_eq(f.burning, w.burning)
	assert_eq(f.tiles, w.tiles)
	assert_eq(f.rng.state, w.rng.state)


func test_burning_reeds_open_the_view_and_leave_ash() -> void:
	var w := _row(World.REEDS, 3)
	w.act(WAIT)
	assert_false(w.opaque(FROM + Vector2i(1, 0)), "burning reeds hide nothing")
	for i in World.BURN_ROUNDS:
		w.act(WAIT)
	assert_eq(w.tile(FROM + Vector2i(1, 0)), World.ASH)


func test_the_burn_event_tells_fierce_fire() -> void:
	var w := _row(World.STRAW, 2)
	w.burning.erase(FROM)
	w.burning[ME] = World.BURN_ROUNDS
	w.tiles[Grid.index(ME)] = World.STRAW
	w._changed()
	var burn := w.act(WAIT).filter(func(e): return e.t == &"burn")
	assert_true(burn[0].fierce)


func test_the_hover_of_fierce_fire_says_so_and_its_harm() -> void:
	var w := _world()
	var at := ME + Vector2i(1, 0)
	w.tiles[Grid.index(at)] = World.STRAW
	w.burning[at] = 2
	w.sense()
	var text := Info.plain(Info.terrain(w, at))
	assert_string_contains(text, "맹렬한 불: 2초 남음")
	assert_string_contains(text, "초당 피해: %d" % World.FIERCE_DAMAGE)
	w.tiles[Grid.index(at)] = World.BOARD
	text = Info.plain(Info.terrain(w, at))
	assert_false(text.contains("맹렬한 불"), "board burns as ordinary fire")
	assert_string_contains(text, "초당 피해: %d" % World.FIRE_DAMAGE)


func test_a_creature_in_fierce_fire_is_told_the_harm_of_it() -> void:
	var w := _world()
	var at := ME + Vector2i(1, 0)
	w.tiles[Grid.index(at)] = World.STRAW
	w.burning[at] = 2
	var foe := FloorGen.spawn(w, &"dokkaebi", at)
	w.sense()
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "맹렬한 불 위: 2초\n  초당 피해: %d" % World.FIERCE_DAMAGE)


func test_the_log_names_fierce_fire_where_it_catches_and_burns() -> void:
	var w := _world()
	var at := ME + Vector2i(1, 0)
	w.tiles[Grid.index(at)] = World.STRAW
	w.sense()
	var caught := Messages.of(w, w, [{t = &"ignite", at = at}]).map(Messages.plain)
	assert_eq(caught, ["마른 짚에 맹렬한 불이 붙었다"])
	var foe := FloorGen.spawn(w, &"dokkaebi", at)
	w.sense()
	var events := [
		{t = &"burn", at = at, id = foe.id, fierce = true}, {t = &"hurt", id = foe.id, n = 3}
	]
	var burnt := Messages.of(w, w, events).map(Messages.plain)
	assert_eq(burnt, ["도깨비가 맹렬한 불에 타 피해를 3 입었다"])
