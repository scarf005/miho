extends GutTest

const FOX := Cards.FOX
const ORB := Cards.ORB
const N := Vector2i(0, -1)
const E := Vector2i(1, 0)
const S := Vector2i(0, 1)
const WEST := Vector2i(-1, 0)
const WAIT := {t = &"wait"}


## An open hall walled at the edges, with no light, Miho at `at`.
func _world(at := Vector2i(4, 8)) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	var hall := Rect2i(1, 1, Grid.W - 2, Grid.H - 2)
	for y in range(hall.position.y, hall.end.y):
		for x in range(hall.position.x, hall.end.x):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([hall])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = at
	w.actors.append(me)
	w.depth = 4
	w.tails = 4
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t


func _cast(cards: Array, dir: Vector2i) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A cast of several spells, each [cards, dir].
func _casts(spells: Array) -> Dictionary:
	return {t = &"cast", spells = spells.map(func(s): return {cards = s[0], dir = s[1]})}


func _foe(w: World, kind: StringName, at: Vector2i, cooldown := 99) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = cooldown
	return a


func _types(events: Array) -> Array:
	return events.map(func(e): return e.t)


func test_spell_needs_a_form_and_distinct_cards() -> void:
	assert_null(Spell.make([]))
	assert_null(Spell.make([Cards.FIRE]))
	assert_null(Spell.make([FOX, FOX]))
	assert_not_null(Spell.make([Cards.FIRE, FOX]))
	assert_not_null(Spell.make([FOX, ORB, Cards.FIRE, Cards.WATER]))
	assert_null(
		Spell.make([ORB, Cards.FIRE, Cards.WATER, Cards.WOOD, Cards.METAL]), "four cards at most"
	)


func test_spell_names_and_costs() -> void:
	assert_eq(Spell.make([FOX, Cards.FIRE]).title(), "화염구")
	assert_eq(Spell.make([ORB, FOX]).title(), "여우구슬")
	assert_eq(Spell.make([ORB, Cards.WATER]).title(), "먹구슬")
	assert_eq(Spell.make([FOX, Cards.METAL]).title(), "섬광")
	assert_eq(Spell.make([Cards.METAL, ORB, Cards.FIRE]).title(), "불·쇠 구슬")
	assert_eq(Spell.make([FOX]).cost(), 1)
	assert_eq(Spell.make([ORB, Cards.FIRE, Cards.METAL]).cost(), 3)
	assert_eq(Spell.make([FOX, ORB, Cards.FIRE, Cards.METAL]).cost(), 4)


func test_sight_is_symmetric_between_floor_tiles() -> void:
	var w := _world()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		_put(
			w, Vector2i(rng.randi_range(1, Grid.W - 2), rng.randi_range(1, Grid.H - 2)), World.WALL
		)
	var floors: Array[Vector2i] = []
	for i in w.tiles.size():
		if w.tiles[i] == World.FLOOR:
			floors.append(Grid.at(i))
	for i in 300:
		var a := floors[rng.randi_range(0, floors.size() - 1)]
		var b := floors[rng.randi_range(0, floors.size() - 1)]
		assert_eq(w.fov(a)[Grid.index(b)], w.fov(b)[Grid.index(a)], "%s %s" % [a, b])


func test_a_lantern_lights_tiles_in_reach_and_walls_cast_shadows() -> void:
	var w := _world()
	_put(w, Vector2i(10, 8), World.LANTERN)
	_put(w, Vector2i(12, 8), World.WALL)
	assert_true(w.lit(Vector2i(11, 8)))
	assert_true(w.lit(Vector2i(10, 4)))
	assert_false(w.lit(Vector2i(13, 8)), "in the wall's shadow")
	assert_false(w.lit(Vector2i(17, 4)), "out of reach")


func test_miho_sees_lit_tiles_far_away_and_dark_tiles_only_close() -> void:
	var w := _world()
	_put(w, Vector2i(20, 8), World.LANTERN)
	w.sense()
	assert_eq(w.seen[Grid.index(Vector2i(6, 8))], 1, "fox eyes reach two tiles")
	assert_eq(w.seen[Grid.index(Vector2i(7, 8))], 0, "dark and three tiles away")
	assert_eq(w.dim[Grid.index(Vector2i(7, 8))], 1, "its shape shows in the dark")
	assert_eq(w.dim[Grid.index(Vector2i(12, 8))], 0, "too far to make out")
	assert_eq(w.seen[Grid.index(Vector2i(19, 8))], 1, "lit, across the hall")
	assert_eq(w.known[Grid.index(Vector2i(19, 8))], 1)


func test_heaven_sees_miho_only_in_light_or_next_to_it() -> void:
	var w := _world(Vector2i(5, 8))
	var watcher := _foe(w, &"jangseung", Vector2i(8, 8), 0)
	w.act(WAIT)
	assert_eq(watcher.alert, Actor.REST, "Miho stands in the dark")
	_put(w, Vector2i(5, 9), World.LANTERN)
	var events := w.act(WAIT)
	assert_eq(watcher.alert, Actor.HUNT)
	assert_has(_types(events), &"notice")
	assert_eq(watcher.intent, [ORB] as Array[StringName], "it sees her and charges")
	var close := _world(Vector2i(7, 8))
	var other := _foe(close, &"jangseung", Vector2i(8, 8))
	close.act(WAIT)
	assert_eq(other.alert, Actor.HUNT, "next to it even in the dark")


func test_preview_shows_only_what_miho_knows() -> void:
	var w := _world(Vector2i(5, 8))
	_put(w, Vector2i(5, 9), World.LANTERN)
	var hidden := _foe(w, &"jangseung", Vector2i(16, 8), 0)
	w.sense()
	assert_eq(w.seen[Grid.index(hidden.pos)], 0)
	var real := w.preview(WAIT)
	assert_eq(real.actor(hidden.id).alert, Actor.HUNT, "it really sees her")
	var f := Forecast.of(w, WAIT)
	assert_null(f.after.actor(hidden.id))
	assert_false(_types(f.events).has(&"charge"))
	assert_eq(hidden.alert, Actor.REST, "previews leave the world unchanged")


func test_a_creature_view_is_every_tile_it_sees() -> void:
	var w := _world(Vector2i(5, 8))
	_put(w, Vector2i(14, 5), World.LANTERN)
	_put(w, Vector2i(12, 8), World.WALL)
	var foe := _foe(w, &"dokkaebi", Vector2i(10, 8))
	for blind in [0, 2]:
		foe.blind = blind
		var view := w.view_of(foe)
		var lit := 0
		for i in view.size():
			assert_eq(view[i] == 1, w.sees(foe, Grid.at(i)), "tile %s" % Grid.at(i))
			lit += view[i]
		assert_true(lit > 9 if blind == 0 else lit == 0, "blind %d sees %d" % [blind, lit])


func test_hover_tells_a_seen_creature_state_and_claw_damage() -> void:
	var w := _world(Vector2i(5, 8))
	_put(w, Vector2i(8, 9), World.LANTERN)
	var foe := _foe(w, &"dokkaebi", Vector2i(8, 8), 2)
	w.sense()
	var text := Info.plain(Info.at(w.known_clone(), foe.pos))
	assert_string_contains(text, "도깨비")
	assert_string_contains(text, "쉰다")
	assert_string_contains(text, "발톱 3 (기습)")
	assert_string_contains(text, "2초 뒤")
	foe.alert = Actor.HUNT
	text = Info.plain(Info.at(w.known_clone(), foe.pos))
	assert_string_contains(text, "발톱 1")
	assert_false(text.contains("기습"))


func test_hover_never_shows_a_creature_miho_cannot_see() -> void:
	var w := _world(Vector2i(5, 8))
	var foe := _foe(w, &"dokkaebi", Vector2i(9, 8))
	w.sense()
	assert_eq(w.dim[Grid.index(foe.pos)], 1)
	var text := Info.plain(Info.at(w.known_clone(), foe.pos))
	assert_false(text.contains("도깨비"))
	assert_string_contains(text, "누가 있는지 모른다")
	assert_eq(Info.at(w.known_clone(), Vector2i(30, 2)), [], "never seen")


func test_a_wisp_flies_three_a_round_then_hovers_and_lights_without_harm() -> void:
	var w := _world()
	w.act(_cast([FOX], E))
	var wisp: Shot = w.shots[0]
	assert_eq(wisp.pos, Vector2i(8, 8))
	w.act(WAIT)
	assert_eq(wisp.pos, Vector2i(11, 8), "stops at its range")
	assert_eq(wisp.dir, Vector2i.ZERO)
	assert_true(w.lit(Vector2i(13, 8)))
	var near := _world()
	var foe := _foe(near, &"jangseung", Vector2i(7, 8))
	near.act(_cast([FOX], E))
	assert_eq(near.shots[0].pos, Vector2i(6, 8), "stops short of a creature")
	assert_eq(foe.hp, 3)
	assert_eq(near.seen[Grid.index(foe.pos)], 1, "and shows it")


func test_a_resting_creature_that_sees_a_wisp_goes_to_search_it() -> void:
	var w := _world()
	var foe := _foe(w, &"imugi", Vector2i(12, 4))
	w.act(_cast([FOX], E))
	assert_eq(foe.alert, Actor.SEARCH)
	assert_eq(foe.target, Vector2i(8, 8))
	assert_eq(foe.pos, Vector2i(11, 5), "one step towards it")


func test_claws_strike_thrice_at_an_unaware_creature_and_kill_silently() -> void:
	var w := _world()
	var prey := _foe(w, &"dokkaebi", Vector2i(5, 8))
	var other := _foe(w, &"imugi", Vector2i(8, 8))
	var events := w.act({t = &"move", dir = E})
	assert_false(prey.alive())
	var claw: Dictionary = events.filter(func(e): return e.t == &"claw")[0]
	assert_eq(claw.n, 3)
	assert_true(claw.sneak)
	assert_eq(other.alert, Actor.REST, "nobody heard it")
	assert_eq(w.player().pos, Vector2i(4, 8), "claws do not move her")


func test_claws_on_a_hunter_strike_once_and_its_cry_alerts_others() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(5, 8))
	foe.alert = Actor.HUNT
	var other := _foe(w, &"imugi", Vector2i(9, 8))
	w.act({t = &"move", dir = E})
	assert_eq(foe.hp, 1)
	assert_eq(other.alert, Actor.SEARCH)
	assert_eq(other.target, Vector2i(5, 8))
	assert_eq(w.player().hp, 2, "the hunter clubs back")


func test_miho_hears_footsteps_in_the_dark_within_range_around_walls() -> void:
	var w := _world()
	var walker := _foe(w, &"dokkaebi", Vector2i(8, 8))
	walker.post = Vector2i(6, 8)
	w.act(WAIT)
	assert_eq(walker.pos, Vector2i(7, 8))
	assert_eq(w.heard, [{at = Vector2i(7, 8), word = "탁"}])
	assert_eq(w.seen[Grid.index(walker.pos)], 0, "heard, not seen")
	var walled := _world()
	for y in range(2, Grid.H - 1):
		_put(walled, Vector2i(6, y), World.WALL)
	var behind := _foe(walled, &"dokkaebi", Vector2i(8, 8))
	behind.post = Vector2i(6, 1)
	walled.act(WAIT)
	assert_eq(walled.heard, [], "the way round is too long")


func test_a_searcher_throws_a_wisp_into_the_dark_before_going_in() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(20, 8), 0)
	foe.alert = Actor.SEARCH
	foe.target = Vector2i(14, 8)
	var events := w.act(WAIT)
	assert_has(_types(events), &"charge")
	assert_eq(foe.aim, WEST)
	w.act(WAIT)
	assert_eq(w.shots.size(), 1, "the searchlight is out")


func test_a_hunter_telegraphs_its_orb_and_a_side_step_dodges_it() -> void:
	for stay in [true, false]:
		var w := _world(Vector2i(5, 8))
		_put(w, Vector2i(5, 9), World.LANTERN)
		_foe(w, &"jangseung", Vector2i(10, 8), 0)
		var events := w.act(WAIT)
		assert_has(_types(events), &"charge")
		w.act(WAIT if stay else {t = &"move", dir = N})
		w.act(WAIT)
		w.act(WAIT)
		assert_eq(w.player().hp, 1 if stay else 3, "an orb from five tiles hits for 2")


func test_a_flash_blinds_so_claws_strike_thrice_even_at_a_hunter() -> void:
	var w := _world()
	w.cards.append(Cards.METAL)
	var foe := _foe(w, &"dokkaebi", Vector2i(5, 8))
	foe.hp = 3
	foe.alert = Actor.HUNT
	w.act(_cast([FOX, Cards.METAL], E))
	assert_eq(foe.blind, 1, "the wisp stops before it and flashes")
	assert_eq(w.player().hp, 3, "blind, it cannot club")
	w.act({t = &"move", dir = E})
	assert_false(foe.alive())


func test_a_dark_wisp_puts_out_lantern_light() -> void:
	var w := _world()
	w.cards.append(Cards.WATER)
	_put(w, Vector2i(10, 8), World.LANTERN)
	assert_true(w.lit(Vector2i(8, 8)))
	w.act(_cast([FOX, Cards.WATER], E))
	w.act(WAIT)
	assert_eq(w.shots[0].pos, Vector2i(9, 8))
	assert_false(w.lit(Vector2i(8, 8)))


func test_a_thud_draws_creatures_through_a_closed_door() -> void:
	var w := _world()
	w.cards.append(Cards.EARTH)
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(14, y), World.WALL)
	_put(w, Vector2i(14, 8), World.DOOR)
	var near := _foe(w, &"imugi", Vector2i(18, 8))
	var far := _foe(w, &"imugi", Vector2i(26, 3))
	w.act(_cast([FOX, Cards.EARTH], E))
	w.act(WAIT)
	assert_eq(near.alert, Actor.SEARCH)
	assert_eq(near.target, Vector2i(11, 8))
	assert_eq(far.alert, Actor.REST)


func _noises(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"noise")


func test_walking_into_a_lantern_knocks_it_out_with_a_clang() -> void:
	var w := _world()
	_put(w, Vector2i(5, 8), World.LANTERN)
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(7, y), World.WALL)
	_put(w, Vector2i(7, 8), World.DOOR)
	var listener := _foe(w, &"imugi", Vector2i(9, 8))
	assert_true(w.lit(Vector2i(6, 8)))
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.tile(Vector2i(5, 8)), World.LANTERN_OUT)
	assert_eq(w.player().pos, Vector2i(4, 8), "the knock takes her move")
	assert_false(w.lit(Vector2i(6, 8)))
	assert_has(_types(events), &"smash")
	var clang: Dictionary = _noises(events)[0]
	assert_eq([clang.word, clang.loud], ["쨍", World.KNOCK])
	assert_eq(listener.alert, Actor.SEARCH, "heard through the door")
	assert_eq(listener.target, Vector2i(5, 8))
	assert_false(w.can({t = &"move", dir = E}), "a dark lantern still blocks")


func test_a_noise_reaches_exactly_as_far_as_it_is_loud() -> void:
	var w := _world()
	_put(w, Vector2i(5, 8), World.LANTERN)
	var near := _foe(w, &"imugi", Vector2i(9, 8))
	var far := _foe(w, &"imugi", Vector2i(10, 4))
	w.act({t = &"move", dir = E})
	assert_eq(near.alert, Actor.SEARCH, "four steps away")
	assert_eq(far.alert, Actor.REST, "five steps away")


func test_water_douses_a_lantern_silently_and_a_searcher_relights_it() -> void:
	var w := _world()
	w.cards.append(Cards.WATER)
	_put(w, Vector2i(10, 8), World.LANTERN)
	var events := w.act(_cast([FOX, Cards.WATER], E))
	events.append_array(w.act(WAIT))
	assert_eq(w.tile(Vector2i(10, 8)), World.LANTERN_OUT)
	assert_has(_types(events), &"douse")
	assert_eq(_noises(events), [], "silent")
	var searcher := _foe(w, &"dokkaebi", Vector2i(11, 9))
	searcher.alert = Actor.SEARCH
	searcher.target = Vector2i(14, 9)
	events = w.act(WAIT)
	assert_eq(w.tile(Vector2i(10, 8)), World.LANTERN)
	var relight: Dictionary = events.filter(func(e): return e.t == &"relight")[0]
	assert_eq(relight.id, searcher.id)
	assert_eq(searcher.pos, Vector2i(11, 9), "relighting takes its turn")


func test_fire_relights_a_lantern_that_went_out() -> void:
	var w := _world()
	w.cards.append(Cards.FIRE)
	_put(w, Vector2i(10, 8), World.LANTERN_OUT)
	assert_false(w.lit(Vector2i(12, 8)))
	w.act(_cast([FOX, Cards.FIRE], E))
	var events := w.act(WAIT)
	assert_has(_types(events), &"relight")
	assert_eq(w.tile(Vector2i(10, 8)), World.LANTERN)
	assert_true(w.lit(Vector2i(12, 8)))


func test_an_orb_smashes_the_lantern_or_closed_door_it_strikes() -> void:
	for t in [World.LANTERN, World.DOOR]:
		var w := _world()
		if t == World.DOOR:
			for y in range(1, Grid.H - 1):
				_put(w, Vector2i(10, y), World.WALL)
		_put(w, Vector2i(10, 8), t)
		var events := w.act(_cast([ORB], E))
		events.append_array(w.act(WAIT))
		events.append_array(w.act(WAIT))
		assert_eq(w.tile(Vector2i(10, 8)), World.LANTERN_OUT if t == World.LANTERN else World.FLOOR)
		assert_has(_types(events), &"smash")
		assert_has(_noises(events).map(func(e): return e.word), "쾅", "it bursts loudly")
		assert_eq(w.shots, [] as Array[Shot])


func test_bamboo_hides_who_stands_in_it_from_all_but_the_next_tile() -> void:
	var w := _world(Vector2i(4, 8))
	_put(w, Vector2i(6, 10), World.LANTERN)
	_put(w, Vector2i(7, 8), World.BAMBOO)
	var hidden := _foe(w, &"jangseung", Vector2i(7, 8))
	w.sense()
	assert_true(w.lit(hidden.pos))
	assert_eq(w.seen[Grid.index(hidden.pos)], 0, "lit, yet hidden")
	assert_eq(w.dim[Grid.index(hidden.pos)], 1, "the bamboo itself shows")
	assert_null(w.known_clone().actor(hidden.id))
	assert_string_contains(Info.plain(Info.at(w.known_clone(), hidden.pos)), "대숲")
	assert_true(w.sees(hidden, w.player().pos), "it watches from inside")
	w.player().pos = Vector2i(6, 8)
	w.sense()
	assert_eq(w.seen[Grid.index(hidden.pos)], 1, "right next to it")


func test_stepping_into_bamboo_rustles() -> void:
	var w := _world()
	_put(w, Vector2i(5, 8), World.BAMBOO)
	var listener := _foe(w, &"imugi", Vector2i(7, 8))
	var rustle: Dictionary = _noises(w.act({t = &"move", dir = E}))[0]
	assert_eq([rustle.word, rustle.loud], ["사각", 2])
	assert_eq(listener.alert, Actor.SEARCH)


func test_floorboards_creak_and_draw_a_resting_creature_that_hears_it() -> void:
	for board in [true, false]:
		var w := _world()
		if board:
			_put(w, Vector2i(5, 8), World.BOARD)
		var listener := _foe(w, &"imugi", Vector2i(8, 8))
		var events := w.act({t = &"move", dir = E})
		assert_eq(listener.alert, Actor.SEARCH if board else Actor.REST)
		if board:
			assert_eq(listener.target, Vector2i(5, 8))
			assert_eq(_noises(events)[0].word, "삐걱")
		else:
			assert_eq(_noises(events), [], "plain floor is silent")


func test_miho_hears_heaven_creak_over_floorboards() -> void:
	var w := _world()
	_put(w, Vector2i(7, 8), World.BOARD)
	var walker := _foe(w, &"dokkaebi", Vector2i(8, 8))
	walker.post = Vector2i(6, 8)
	var other := _foe(w, &"imugi", Vector2i(9, 9))
	w.act(WAIT)
	assert_eq(w.heard, [{at = Vector2i(7, 8), word = "삐걱"}])
	assert_eq(other.alert, Actor.REST, "heaven ignores its own")


func test_a_pond_blocks_walking_but_an_orb_flies_over_it() -> void:
	var w := _world()
	_put(w, Vector2i(5, 8), World.POND)
	_put(w, Vector2i(6, 8), World.POND)
	var foe := _foe(w, &"jangseung", Vector2i(9, 8))
	assert_false(w.can({t = &"move", dir = E}))
	assert_eq(
		Forecast.ray(w, w.player().pos, E).slice(0, 5),
		[5, 6, 7, 8, 9].map(func(x): return Vector2i(x, 8))
	)
	w.act(_cast([ORB], E))
	w.act(WAIT)
	assert_eq(foe.hp, 1, "struck after a five-tile run")


func test_strong_foe_gives_its_element_and_a_kill_gives_back_a_tail() -> void:
	var w := _world()
	w.tails = 1
	var foe := _foe(w, &"bulgae", Vector2i(6, 8))
	foe.hp = 1
	w.act(_cast([ORB], E))
	assert_false(foe.alive())
	assert_has(w.cards, Cards.FIRE)
	assert_eq(w.tails, 1)


func test_one_turn_splits_the_tails_across_several_spells() -> void:
	var w := _world()
	w.depth = 5
	w.tails = 5
	for c in Cards.ELEMENTS:
		w.cards.append(c)
	var one_four := _casts([[[FOX], N], [[ORB, Cards.FIRE, Cards.WOOD, Cards.METAL], E]])
	var ones := _casts([[[FOX], N], [[FOX], E], [[ORB], S], [[ORB], WEST]])
	assert_true(w.can(one_four))
	assert_true(w.can(ones))
	assert_false(w.can(_casts([[[FOX, Cards.FIRE], N], [[ORB, Cards.WOOD, Cards.METAL, FOX], E]])))
	assert_false(w.can(_casts([[[FOX], E], [[ORB], E]])), "one spell per line")
	var events := w.act(ones)
	assert_eq(_types(events).count(&"cast"), 4)
	assert_eq(w.tails, 1)


func test_spent_tails_regrow_one_every_three_rounds_up_to_the_storey() -> void:
	var w := _world()
	w.depth = 2
	w.tails = 0
	for i in 3:
		w.act(WAIT)
	assert_eq(w.tails, 1)
	for i in 9:
		w.act(WAIT)
	assert_eq(w.tails, 2)


func test_each_storey_grows_one_more_tail() -> void:
	var w := World.create(5)
	assert_eq(w.tails, 1)
	assert_eq(w.max_tails(), 1)
	w.actors[0].pos = w.stairs + WEST
	if not w.vacant(w.stairs + WEST):
		w.actors[0].pos = w.stairs + E
	w.act({t = &"move", dir = w.stairs - w.actors[0].pos})
	assert_eq(w.depth, 2)
	assert_eq(w.tails, 2)


func test_storeys_are_connected_with_dark_starts_and_lit_stairs() -> void:
	var features := {World.BAMBOO: 0, World.POND: 0, World.BOARD: 0}
	for seed_value in 20:
		var w := World.create(seed_value)
		for t in w.tiles:
			if features.has(t):
				features[t] += 1
		assert_eq(w.tile(w.start), World.FLOOR)
		assert_eq(w.tile(w.stairs), World.FLOOR)
		var dist: PackedInt32Array = Grid.search(w.start, w.open_floor).dist
		for i in w.tiles.size():
			if w.open_floor(Grid.at(i)):
				assert_gt(dist[i], -1, "seed %d tile %s" % [seed_value, Grid.at(i)])
		assert_true(w.lit(w.stairs), "seed %d" % seed_value)
		assert_false(w.lit(w.start), "seed %d" % seed_value)
		assert_eq(w.actors.size() - 1, FloorGen.PLAN[1].size())
		for a in w.actors.slice(1):
			assert_gt(Grid.cheb(a.pos, w.start), 3, "seed %d" % seed_value)
	for t in features:
		assert_gt(features[t], 0, "some rooms have tile %d" % t)


func test_a_seed_builds_the_same_storey_every_time() -> void:
	for seed_value in 5:
		var a := World.create(seed_value)
		var b := World.create(seed_value)
		assert_eq(a.tiles, b.tiles, "seed %d tiles" % seed_value)
		assert_eq(
			a.actors.map(func(x): return x.pos),
			b.actors.map(func(x): return x.pos),
			"seed %d creatures" % seed_value
		)
