extends GutTest
## The MCP tools: protocol replies, and a game played on what Miho knows.


func _request(method: String, params: Dictionary = {}, id: Variant = 1) -> Dictionary:
	return {jsonrpc = "2.0", id = id, method = method, params = params}


## The text of a tools/call reply, and whether it is an error.
func _call(tools: GameTools, name: String, args: Dictionary = {}) -> Dictionary:
	var reply: Dictionary = tools.handle(_request("tools/call", {name = name, arguments = args}))
	return {
		text = reply.result.content[0].text,
		error = reply.result.isError,
	}


func _game(seed_value := 7) -> GameTools:
	var tools := GameTools.new()
	_call(tools, "new_game", {seed = seed_value})
	return tools


func test_initialize_names_the_server_and_offers_tools() -> void:
	var reply: Dictionary = GameTools.new().handle(_request("initialize"))
	assert_eq(reply.id, 1)
	assert_eq(reply.result.protocolVersion, "2025-06-18")
	assert_eq(reply.result.serverInfo.name, "miho")
	assert_true(reply.result.capabilities.has("tools"))
	assert_not_null(JSON.parse_string(JSON.stringify(reply)), "the reply is JSON")


func test_a_notification_gets_no_reply() -> void:
	var note := {jsonrpc = "2.0", method = "notifications/initialized"}
	assert_null(GameTools.new().handle(note))


func test_ping_answers_empty() -> void:
	assert_eq(GameTools.new().handle(_request("ping")).result, {})


func test_an_unknown_method_is_a_jsonrpc_error() -> void:
	var reply: Dictionary = GameTools.new().handle(_request("tools/nope", {}, 9))
	assert_eq(reply.error.code, -32601)
	assert_eq(reply.id, 9)


func test_a_whole_float_id_reads_back_as_an_integer() -> void:
	var reply: Dictionary = GameTools.new().handle(_request("ping", {}, 3.0))
	assert_eq(JSON.stringify(reply.id), "3")


func test_tools_list_names_every_tool_with_a_schema() -> void:
	var tools: Array = GameTools.new().handle(_request("tools/list")).result.tools
	assert_eq(tools.map(func(t): return t.name), ["new_game", "observe", "act", "look", "forecast"])
	for t in tools:
		assert_eq(t.inputSchema.type, "object")


func test_an_unknown_tool_is_a_jsonrpc_error() -> void:
	var reply: Dictionary = GameTools.new().handle(_request("tools/call", {name = "cheat"}))
	assert_eq(reply.error.code, -32602)


func test_a_tool_before_new_game_is_an_error_result() -> void:
	var r := _call(GameTools.new(), "observe")
	assert_true(r.error)
	assert_string_contains(r.text, "new_game")


func test_new_game_with_a_seed_is_deterministic() -> void:
	var a := _call(GameTools.new(), "new_game", {seed = 7})
	var b := _call(GameTools.new(), "new_game", {seed = 7})
	var c := _call(GameTools.new(), "new_game", {seed = 8})
	assert_false(a.error)
	assert_eq(a.text, b.text)
	assert_ne(a.text, c.text)


func test_the_observation_tells_the_state_and_the_map() -> void:
	var text: String = (
		_game().handle(_request("tools/call", {name = "observe"})).result.content[0].text
	)
	for part in ["storey 1/9", "hp 3/3", "tails 1/1", "1 fox (여우불)", "@", "moves:"]:
		assert_string_contains(text, part)


func test_a_bad_seed_is_refused() -> void:
	assert_true(_call(GameTools.new(), "new_game", {seed = "x"}).error)
	assert_true(_call(GameTools.new(), "new_game", {seed = 1.5}).error)


func test_an_illegal_act_changes_nothing_and_says_so() -> void:
	var tools := _game()
	var before: String = _call(tools, "observe").text
	var round_before := tools.world.round_no
	for args in [
		{action = "move"},
		{action = "move", dir = "up"},
		{action = "dance"},
		{action = "cast", spells = []},
		{action = "cast", spells = [{cards = ["fox", "orb", "fire"], dir = "e"}]},
		{action = "cast", spells = [{cards = ["fire"], dir = "e"}]},
		{action = "cast", spells = [{cards = ["fox"], dir = "x"}]},
		{action = "cast", spells = [{cards = ["fox", "bomb"], dir = "e"}]},
		{action = "travel", x = 1},
		{action = "travel", x = 99, y = 99},
		{action = "stairs"},
	]:
		var r := _call(tools, "act", args)
		assert_true(r.error, "%s is refused" % [args])
	assert_eq(tools.world.round_no, round_before)
	assert_eq(_call(tools, "observe").text, before)


func test_a_step_into_a_wall_is_refused() -> void:
	var tools := _game()
	tools.world.player().pos = Vector2i(1, 24)
	tools.world.sense()
	var r := _call(tools, "act", {action = "move", dir = "w"})
	assert_true(r.error)
	assert_eq(tools.world.player().pos, Vector2i(1, 24))
	assert_eq(tools.world.round_no, 0)


func test_move_and_wait_play_one_round() -> void:
	var tools := _game()
	var r := _call(tools, "act", {action = "wait"})
	assert_false(r.error)
	assert_eq(tools.world.round_no, 1)
	var open := Grid.DIRS.filter(func(d): return tools.world.can({t = &"move", dir = d}))
	r = _call(tools, "act", {action = "move", dir = Observation.NAMES[open[0]]})
	assert_false(r.error)
	assert_eq(tools.world.round_no, 2)


func test_a_cast_spends_tails_and_a_cast_the_tails_cannot_pay_is_refused() -> void:
	var tools := _game()
	var open := Grid.DIRS.filter(func(d): return tools.world.open_air(tools.world.player().pos + d))
	var dir: String = Observation.NAMES[open[0]]
	var r := _call(tools, "act", {action = "cast", spells = [{cards = ["fox"], dir = dir}]})
	assert_false(r.error)
	assert_eq(tools.world.tails, 0)
	r = _call(tools, "act", {action = "cast", spells = [{cards = ["여우불"], dir = dir}]})
	assert_true(r.error, "no tail is left")


func test_a_cast_on_self_lays_the_shadow_and_a_thrown_spell_is_refused_there() -> void:
	var tools := _game()
	tools.world.tails = 3
	tools.world.cards.append_array([Cards.WATER, Cards.WOOD])
	var r := _call(tools, "act", {action = "cast", spells = [{cards = ["fox"], dir = "self"}]})
	assert_true(r.error, "a lone wisp does not go on Miho")
	r = _call(
		tools, "act", {action = "cast", spells = [{cards = ["fox", "water", "wood"], dir = "self"}]}
	)
	assert_false(r.error)
	assert_true(tools.world.shots.any(func(s): return s.host == tools.world.player().id))


func test_dispel_drops_the_buff_named_and_refuses_one_she_does_not_wear() -> void:
	var tools := _game()
	tools.world.tails = 3
	tools.world.cards.append_array([Cards.WOOD, Cards.EARTH])
	var cards := ["fox", "wood", "earth"]
	_call(tools, "act", {action = "cast", spells = [{cards = cards, dir = "self"}]})
	assert_true(tools.world.player().cloak)
	assert_true(_call(tools, "act", {action = "dispel", kind = "talon"}).error)
	assert_false(_call(tools, "act", {action = "dispel", kind = "cloak"}).error)
	assert_false(tools.world.player().cloak)


func test_explore_walks_many_rounds_and_stops_with_a_reason() -> void:
	var tools := _game(3)
	var r := _call(tools, "act", {action = "explore"})
	assert_false(r.error)
	assert_gt(tools.world.round_no, 1)
	assert_lte(tools.world.round_no, GameTools.MAX_ROUNDS)
	assert_string_contains(r.text, "rounds walked: %d, stopped:" % tools.world.round_no)


func test_rest_waits_until_the_tails_regrow() -> void:
	var tools := _game()
	tools.world.tails = 0
	var r := _call(tools, "act", {action = "rest"})
	assert_false(r.error)
	assert_eq(tools.world.round_no, World.TAIL_REGROW)
	assert_eq(tools.world.tails, tools.world.max_tails())
	assert_true(_call(tools, "act", {action = "rest"}).error, "nothing to rest for")


func test_travel_walks_to_a_known_tile() -> void:
	var tools := _game(2)
	var dist: PackedInt32Array = Travel.search(tools.world).dist
	var goal := Grid.at(dist.find(2))
	assert_true(Travel.walkable(tools.world, goal))
	var r := _call(tools, "act", {action = "travel", x = goal.x, y = goal.y})
	assert_false(r.error)
	assert_eq(tools.world.player().pos, goal)
	assert_true(_call(tools, "act", {action = "travel", x = goal.x, y = goal.y}).error)


func test_look_describes_known_tiles_only() -> void:
	var tools := _game()
	var me := tools.world.player().pos
	var here := _call(tools, "look", {x = me.x, y = me.y})
	assert_false(here.error)
	assert_string_contains(here.text, "당신")
	var far := _call(tools, "look", {x = 55, y = 0})
	assert_false(far.error)
	assert_string_contains(far.text, "unknown")
	assert_true(_call(tools, "look", {x = 56, y = 0}).error)
	assert_true(_call(tools, "look", {x = 1}).error)


func test_forecast_reports_harm_without_changing_the_world() -> void:
	var tools := _game()
	var before: String = _call(tools, "observe").text
	var r := _call(tools, "forecast", {action = "wait"})
	assert_false(r.error)
	assert_string_contains(r.text, "harm to Miho: 0")
	assert_string_contains(r.text, "noticed by: nobody")
	assert_eq(_call(tools, "observe").text, before)
	assert_true(_call(tools, "forecast", {action = "explore"}).error)
	assert_true(_call(tools, "forecast", {action = "move"}).error)


func test_forecast_names_who_would_be_hurt() -> void:
	var tools := _game()
	var w := tools.world
	var foe := FloorGen.spawn(w, &"dokkaebi", w.player().pos + Vector2i(1, 0))
	foe.ailments.blind = 2
	w.sense()
	var r := _call(tools, "forecast", {action = "move", dir = "e"})
	assert_string_contains(r.text, "harm dealt: 도깨비 (%d,%d) -3" % [foe.pos.x, foe.pos.y])
	assert_string_contains(_call(tools, "observe").text, "moves: ")
	assert_string_contains(_call(tools, "observe").text, "e(claw 도깨비)")


func test_forecast_lists_where_a_wooden_wall_grows() -> void:
	var tools := _game()
	var w := tools.world
	var me := w.player().pos
	for dy in [-1, 0, 1]:
		w.set_tile(me + Vector2i(1, dy), World.FLOOR)
	w.set_tile(me + Vector2i(2, 0), World.WALL)
	w.cards.append(Cards.WOOD)
	w.tails = 2
	w.sense()
	var spells := [{cards = ["orb", "wood"], dir = "e"}]
	var r := _call(tools, "forecast", {action = "cast", spells = spells})
	var at := me + Vector2i(1, 0)
	assert_string_contains(r.text, "wooden wall grows at: (%d,%d)" % [at.x, at.y])


func test_no_creature_out_of_sight_is_in_the_observation() -> void:
	var hidden := 0
	for seed_value in range(1, 9):
		var tools := _game(seed_value)
		for step in 12:
			var text: String = _call(tools, "observe").text
			var map := text.split("\n").slice(5, 5 + Grid.H)
			for a in tools.world.actors:
				if a.faction == Actor.FOX or tools.world.seen[Grid.index(a.pos)] == 1:
					continue
				hidden += 1
				assert_false(text.contains("%s (%d,%d)" % [a.info().name, a.pos.x, a.pos.y]))
				var row: String = map[a.pos.y]
				assert_ne(row.substr(3 + a.pos.x, 1), a.info().glyph, "%s is not drawn" % a.kind)
			if tools.world.outcome != &"":
				break
			_call(tools, "act", {action = "explore"})
	assert_gt(hidden, 0, "some creature was out of sight")


func test_a_finished_game_refuses_more_actions() -> void:
	var tools := _game()
	tools.world.outcome = &"lost"
	var r := _call(tools, "act", {action = "wait"})
	assert_true(r.error)
	assert_string_contains(r.text, "over")
	assert_string_contains(_call(tools, "observe").text, "game over: lost")


func test_observation_tells_what_a_creature_is_weak_to() -> void:
	var tools := _game()
	var w := tools.world
	FloorGen.spawn(w, &"cheonha", w.player().pos + Vector2i(1, 0))
	FloorGen.spawn(w, &"jangseung", w.player().pos + Vector2i(0, 1))
	w.sense()
	var lines: Array = _call(tools, "observe").text.split("\n")
	var wood: Array = lines.filter(func(l): return l.contains("천하대장군"))
	assert_string_contains(wood[0], ", weak to metal")
	var plain: Array = lines.filter(func(l): return l.contains("장승 ("))
	assert_false(plain[0].contains("weak to"))
