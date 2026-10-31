extends GutTest
## Sliding doors: closed or open, opened by walking into them, shut by the
## close action; a closed door blocks sight but not light.

const E := Vector2i(1, 0)
const N := Vector2i(0, -1)
const WAIT := {t = &"wait"}
const DOOR_AT := Vector2i(10, 8)


## A hall walled at the edges with a wall down column 10 and a closed door in
## it at (10, 8); no light; Miho at (9, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.WALL if x == 10 else World.FLOOR
	_put(w, DOOR_AT, World.DOOR)
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(9, 8)
	w.actors.append(me)
	w.depth = 4
	w.tails = 4
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t


func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


func _slides(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"noise" and e.word == "드르륵")


func test_walking_into_a_closed_door_slides_it_open_and_costs_the_move() -> void:
	var w := _world()
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.tile(DOOR_AT), World.DOOR_OPEN)
	assert_eq(w.player().pos, Vector2i(9, 8), "Miho stays put")
	assert_eq(w.round_no, 1, "the round passed")
	assert_eq(events.filter(func(e): return e.t == &"open").size(), 1)
	var noise: Dictionary = _slides(events)[0]
	assert_eq([noise.loud, noise.at], [Terrain.SLIDE, DOOR_AT])
	w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, DOOR_AT, "the next step goes through")


func test_a_closed_door_blocks_sight_but_light_passes() -> void:
	var w := _world()
	_put(w, Vector2i(13, 8), World.LANTERN)
	var far := _foe(w, &"jangseung", Vector2i(12, 8))
	w.sense()
	assert_true(w.opaque(DOOR_AT))
	assert_false(w.blocks_light(DOOR_AT))
	assert_eq(w.opaque_mask()[Grid.index(DOOR_AT)], 1)
	assert_eq(w.light_mask()[Grid.index(DOOR_AT)], 0)
	assert_true(w.lit(DOOR_AT), "the paper glows")
	assert_true(w.lit(w.player().pos), "its light reaches Miho's side")
	assert_eq(w.seen[Grid.index(far.pos)], 0, "she does not see the room")
	assert_false(w.sees(far, w.player().pos), "nor does it see her")
	_put(w, DOOR_AT, World.DOOR_OPEN)
	w.sense()
	assert_eq(w.seen[Grid.index(far.pos)], 1, "open, she sees it")
	assert_true(w.sees(far, w.player().pos))


func test_a_wall_still_casts_a_shadow() -> void:
	var w := _world()
	_put(w, Vector2i(13, 8), World.LANTERN)
	_put(w, DOOR_AT, World.WALL)
	assert_false(w.lit(w.player().pos))


func test_the_close_action_shuts_an_open_door_with_a_sound() -> void:
	var w := _world()
	_put(w, DOOR_AT, World.DOOR_OPEN)
	var action := {t = &"close", dir = E}
	assert_true(w.can(action))
	var events := w.act(action)
	assert_eq(w.tile(DOOR_AT), World.DOOR)
	assert_true(w.opaque(DOOR_AT))
	assert_eq(events.filter(func(e): return e.t == &"close").size(), 1)
	assert_eq(_slides(events).size(), 1)


func test_the_close_action_refuses_whatever_is_not_a_free_open_door_next_to_miho() -> void:
	var w := _world()
	assert_false(w.can({t = &"close", dir = E}), "already closed")
	assert_false(w.can({t = &"close", dir = N}), "floor")
	_put(w, DOOR_AT, World.DOOR_OPEN)
	assert_false(w.can({t = &"close", dir = Vector2i.ZERO}))
	assert_false(w.can({t = &"close", dir = Vector2i(2, 0)}))
	w.burning[DOOR_AT] = 2
	assert_false(w.can({t = &"close", dir = E}), "burning")
	w.burning.clear()
	var foe := _foe(w, &"jangseung", DOOR_AT)
	assert_false(w.can({t = &"close", dir = E}), "a creature stands in it")
	foe.hp = 0
	assert_true(w.can({t = &"close", dir = E}))
	var wisp := Shot.new()
	wisp.id = w.new_id()
	wisp.spell = Spell.make([Cards.FOX])
	wisp.pos = DOOR_AT
	w.shots.append(wisp)
	assert_false(w.can({t = &"close", dir = E}), "a wisp hovers in it")


func test_miho_sliding_a_door_wakes_heaven_within_its_reach_only() -> void:
	var w := _world()
	var near := _foe(w, &"imugi", DOOR_AT + Vector2i(2, 0))
	var far := _foe(w, &"imugi", DOOR_AT + Vector2i(Terrain.SLIDE + 2, 0))
	w.act({t = &"move", dir = E})
	assert_eq(near.alert, Actor.SEARCH)
	assert_eq(near.target, DOOR_AT)
	assert_eq(far.alert, Actor.REST)


func test_a_hunting_creature_opens_a_door_on_its_path_and_leaves_it_open() -> void:
	var w := _world()
	w.player().pos = Vector2i(5, 8)
	var foe := _foe(w, &"dokkaebi", Vector2i(11, 8))
	foe.alert = Actor.HUNT
	foe.target = w.player().pos
	var events := w.act(WAIT)
	assert_eq(w.tile(DOOR_AT), World.DOOR_OPEN)
	assert_eq(foe.pos, Vector2i(11, 8), "opening spent its move")
	var noise: Dictionary = _slides(events)[0]
	assert_eq([noise.at, noise.loud], [DOOR_AT, Terrain.SLIDE])
	assert_eq(events.filter(func(e): return e.t == &"open" and e.id == foe.id).size(), 1)
	w.act(WAIT)
	assert_eq(foe.pos, DOOR_AT)
	w.act(WAIT)
	assert_eq(w.tile(DOOR_AT), World.DOOR_OPEN, "left open behind it")


func test_a_creatures_door_does_not_wake_other_heaven() -> void:
	var w := _world()
	w.player().pos = Vector2i(2, 8)
	var foe := _foe(w, &"dokkaebi", Vector2i(11, 8))
	foe.alert = Actor.HUNT
	foe.target = w.player().pos
	var sleeper := _foe(w, &"imugi", Vector2i(12, 9))
	w.act(WAIT)
	assert_eq(w.tile(DOOR_AT), World.DOOR_OPEN)
	assert_eq(sleeper.alert, Actor.REST)


func test_a_door_burns_open_or_shut() -> void:
	for open in [false, true]:
		var w := _world()
		_put(w, DOOR_AT, World.DOOR_OPEN if open else World.DOOR)
		w.cards.append(Cards.FIRE)
		w.act({t = &"cast", spells = [{cards = [Cards.FOX, Cards.FIRE], dir = E}]})
		for i in 5:
			w.act(WAIT)
		assert_eq(w.tile(DOOR_AT), World.ASH, "open %s" % open)


func test_an_orb_smashes_a_shut_door_and_flies_through_an_open_one() -> void:
	for open in [false, true]:
		var w := _world()
		_put(w, DOOR_AT, World.DOOR_OPEN if open else World.DOOR)
		w.act({t = &"cast", spells = [{cards = [Cards.ORB], dir = E}]})
		for i in 3:
			w.act(WAIT)
		assert_eq(w.tile(DOOR_AT), World.DOOR_OPEN if open else World.FLOOR, "open %s" % open)


func test_a_preview_of_opening_or_closing_a_door_equals_the_real_round() -> void:
	for action in [{t = &"move", dir = E}, {t = &"close", dir = E}]:
		var w := _world()
		_put(w, DOOR_AT, World.DOOR if action.t == &"move" else World.DOOR_OPEN)
		_foe(w, &"imugi", Vector2i(12, 8)).alert = Actor.SEARCH
		var ahead := w.preview(action)
		w.act(action)
		assert_eq(ahead.tiles, w.tiles, str(action))
		assert_eq(ahead.actors.map(func(a): return a.pos), w.actors.map(func(a): return a.pos))
		assert_eq(ahead.heard, w.heard)


func test_generated_storeys_start_some_doors_open_and_stay_connected() -> void:
	var kinds := {World.DOOR: 0, World.DOOR_OPEN: 0}
	for s in 12:
		var w := World.create(s)
		for t: int in w.tiles:
			if kinds.has(t):
				kinds[t] += 1
		var dist: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
		assert_gte(dist[Grid.index(w.stairs if w.stairs.x >= 0 else w.elixir)], 0)
	assert_gt(kinds[World.DOOR_OPEN], 0, "some start open")
	assert_gt(kinds[World.DOOR], kinds[World.DOOR_OPEN], "most start closed")


func test_the_light_mask_agrees_with_blocks_light_on_every_tile() -> void:
	for s in 6:
		var w := World.create(s)
		var mask := w.light_mask()
		for i in mask.size():
			assert_eq(mask[i] == 1, w.blocks_light(Grid.at(i)), "seed %d %s" % [s, Grid.at(i)])


func test_hovering_a_door_shows_its_state_sound_and_light() -> void:
	var w := _world()
	w.sense()
	var shut := Info.plain(Info.terrain(w, DOOR_AT))
	assert_string_contains(shut, "닫혀 있다")
	assert_string_contains(shut, "빛은 지나간다")
	assert_string_contains(shut, "드르륵 소리 %d칸" % Terrain.SLIDE)
	assert_string_contains(shut, "♥")
	_put(w, DOOR_AT, World.DOOR_OPEN)
	var open := Info.plain(Info.terrain(w, DOOR_AT))
	assert_string_contains(open, "열린 문")
	assert_string_contains(open, "드르륵 소리 %d칸" % Terrain.SLIDE)


func test_the_log_tells_who_slid_a_door() -> void:
	var w := _world()
	_put(w, DOOR_AT, World.DOOR_OPEN)
	w.sense()
	var foe := _foe(w, &"dokkaebi", Vector2i(9, 9))
	var me := w.player().id
	var lines := Messages.of(
		w, w, [{t = &"open", at = DOOR_AT, id = me}, {t = &"close", at = DOOR_AT, id = me}]
	)
	assert_eq(lines.map(Messages.plain), ["문을 열었다", "문을 닫았다"])
	lines = Messages.of(w, w, [{t = &"open", at = DOOR_AT, id = foe.id}])
	assert_eq(lines.map(Messages.plain), ["도깨비가 문을 열었다"])


func test_the_agent_sees_doors_in_the_legend_and_moves_and_can_close_one() -> void:
	var tools := GameTools.new()
	tools.world = _world()
	tools.world.sense()
	assert_string_contains(Observation.LEGEND, "+closed-door 'open-door")
	var text := Observation.text(tools.world)
	assert_string_contains(text, "e(open door)")
	var r := _mcp(tools, "act", {action = "move", dir = "e"})
	assert_eq(tools.world.tile(DOOR_AT), World.DOOR_OPEN)
	assert_string_contains(r.text, "문을 열었다")
	assert_string_contains(r.text, "close: e")
	r = _mcp(tools, "forecast", {action = "close", dir = "e"})
	assert_false(r.error)
	assert_eq(tools.world.tile(DOOR_AT), World.DOOR_OPEN, "a forecast changes nothing")
	r = _mcp(tools, "act", {action = "close", dir = "e"})
	assert_eq(tools.world.tile(DOOR_AT), World.DOOR)
	r = _mcp(tools, "act", {action = "close", dir = "e"})
	assert_true(r.error, "nothing left to close")
	assert_true(_mcp(tools, "act", {action = "close"}).error, "close needs a direction")


func _mcp(tools: GameTools, name: String, args: Dictionary) -> Dictionary:
	var reply: Dictionary = tools.handle(
		{jsonrpc = "2.0", id = 1, method = "tools/call", params = {name = name, arguments = args}}
	)
	return {text = reply.result.content[0].text, error = reply.result.isError}


# --- the close key on the game scene -----------------------------------------


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(3)
	m.state = &"play"
	m.world = _world()
	m.world.sense()
	m._forecast()
	return m


func test_the_close_key_shuts_the_only_open_door_beside_miho() -> void:
	var m := _main()
	_put(m.world, DOOR_AT, World.DOOR_OPEN)
	m._shut()
	assert_eq(m.world.tile(DOOR_AT), World.DOOR)
	assert_false(m.shutting)


func test_the_close_key_asks_for_a_direction_when_two_doors_are_open() -> void:
	var m := _main()
	_put(m.world, DOOR_AT, World.DOOR_OPEN)
	_put(m.world, Vector2i(10, 9), World.DOOR_OPEN)
	m._shut()
	assert_true(m.shutting)
	assert_eq(m.world.tile(DOOR_AT), World.DOOR_OPEN, "nothing is shut yet")
	var down := Keys.event("Kp 3")
	down.pressed = true
	m._key(down)
	assert_false(m.shutting)
	assert_eq(m.world.tile(Vector2i(10, 9)), World.DOOR)
	assert_eq(m.world.tile(DOOR_AT), World.DOOR_OPEN)


func test_the_close_key_with_no_open_door_says_so_and_takes_no_round() -> void:
	var m := _main()
	m._shut()
	assert_false(m.shutting)
	assert_eq(m.world.round_no, 0)
	assert_eq(m.messages.lines.back().text, "닫을 문이 없다")


func test_the_close_key_is_c() -> void:
	var e := Keys.event("C")
	e.pressed = true
	assert_eq(Keys.action_of(e), &"close")
