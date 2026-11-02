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
	w.depth = 2
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


## A creature resting one step from its home: awake, since one at its home sleeps.
func _lookout(w: World, kind: StringName, at: Vector2i, cooldown := 99) -> Actor:
	var a := _foe(w, kind, at, cooldown)
	a.home += E
	return a


func _types(events: Array) -> Array:
	return events.map(func(e): return e.t)


func test_the_queue_stacks_repeats_and_holds_five_slots_at_most() -> void:
	assert_null(Spell.make([]))
	assert_null(Spell.make([FOX, &"bomb"]))
	assert_eq(Spell.make([FOX, FOX, FOX]).slots, [FOX, FOX, FOX] as Array[StringName])
	assert_eq(Spell.make([FOX, FOX, FOX]).count(FOX), 3)
	assert_not_null(Spell.make([FOX, FOX, FOX, FOX, FOX]))
	assert_null(Spell.make([FOX, FOX, FOX, FOX, FOX, FOX]), "five slots at most")
	var six_cards := Spell.make([FOX, ORB, ORB, Cards.FIRE, Cards.WATER, Cards.FIRE])
	assert_eq(six_cards.slots.size(), 5, "a compound is one slot")
	assert_eq(six_cards.cost(), 9, "and nine tails: the sixth card is two more")


func test_spell_names_and_costs() -> void:
	assert_eq(Spell.make([FOX, Cards.FIRE]).title(), "불 여우불")
	assert_eq(Spell.make([FOX, FOX, FOX]).title(), "여우불 3발")
	assert_eq(Spell.make([ORB, FOX]).title(), "유도 구슬")
	assert_eq(Spell.make([ORB, Cards.WATER, Cards.WATER]).title(), "물×2 구슬")
	assert_eq(Spell.make([Cards.METAL, ORB, Cards.WATER]).title(), "서리 구슬")
	assert_eq(Spell.make([ORB, Cards.FIRE, Cards.EARTH, Cards.METAL]).title(), "용광로 구슬")
	assert_eq(Spell.make([ORB, Cards.WATER, Cards.FIRE, Cards.FIRE]).title(), "증기·불 구슬")
	assert_eq(Spell.make([ORB, Cards.FIRE, Cards.WATER, Cards.FIRE]).title(), "증기·불 구슬")
	assert_eq(Spell.make([FOX]).cost(), 1)
	assert_eq(Spell.make([ORB, Cards.FIRE, Cards.METAL]).cost(), 3)
	assert_eq(Spell.make([FOX, ORB, Cards.FIRE, Cards.METAL]).cost(), 5)


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
	var watcher := _lookout(w, &"jangseung", Vector2i(8, 8), 0)
	w.act(WAIT)
	assert_eq(watcher.alert, Actor.REST, "Miho stands in the dark")
	_put(w, Vector2i(5, 9), World.LANTERN)
	var events := w.act(WAIT)
	assert_eq(watcher.alert, Actor.HUNT)
	assert_has(_types(events), &"notice")
	var charged := Bestiary.casts(&"jangseung", watcher.rank)
	assert_eq(watcher.intent.map(func(p): return p.cards), charged, "it sees her and charges")
	var close := _world(Vector2i(7, 8))
	var other := _lookout(close, &"jangseung", Vector2i(8, 8))
	close.act(WAIT)
	assert_eq(other.alert, Actor.HUNT, "next to it even in the dark")


func test_preview_shows_only_what_miho_knows() -> void:
	var w := _world(Vector2i(5, 8))
	_put(w, Vector2i(5, 9), World.LANTERN)
	var hidden := _lookout(w, &"jangseung", Vector2i(16, 8), 0)
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
	foe.blind = 2
	w.sense()
	var text := Info.plain(Info.at(w.known_clone(), foe.pos))
	assert_string_contains(text, "도깨비")
	assert_string_contains(text, "순찰 중")
	assert_string_contains(text, "기습 피해: 3")
	assert_string_contains(text, "근접: 방망이 · 피해: 1")
	assert_string_contains(text, "주술: 도깨비불 · ")
	assert_string_contains(text, "2초 뒤")
	foe.alert = Actor.HUNT
	text = Info.plain(Info.at(w.known_clone(), foe.pos))
	assert_false(text.contains("기습"))


func test_hover_never_shows_a_creature_miho_cannot_see() -> void:
	var w := _world(Vector2i(5, 8))
	var foe := _foe(w, &"dokkaebi", Vector2i(9, 8))
	w.sense()
	assert_eq(w.dim[Grid.index(foe.pos)], 1)
	var text := Info.plain(Info.at(w.known_clone(), foe.pos))
	assert_false(text.contains("도깨비"))
	assert_string_contains(text, "가림: 어둠")
	assert_eq(Info.at(w.known_clone(), Vector2i(30, 2)), [], "never seen")


func test_a_wisp_with_no_creature_in_sight_flies_three_a_round_then_hovers_and_lights() -> void:
	var w := _world()
	w.act(_cast([FOX], E))
	var wisp: Shot = w.shots[0]
	assert_eq(wisp.pos, Vector2i(8, 8))
	assert_eq(wisp.target, 0)
	w.act(WAIT)
	assert_eq(wisp.pos, Vector2i(11, 8), "stops at its range")
	assert_eq(wisp.dir, Vector2i.ZERO)
	assert_eq(wisp.life, Spell.WISP_LIFE - 1, "hovers WISP_LIFE rounds from where it stopped")
	assert_true(w.lit(Vector2i(13, 8)))
	assert_true(w.vacant(wisp.pos), "creatures may share a hovering wisp's tile")


func test_a_resting_sharp_creature_that_sees_a_wisp_goes_to_search_where_it_came_from() -> void:
	var w := _world()
	var foe := _lookout(w, &"imugi", Vector2i(12, 4))
	w.act(_cast([FOX], E))
	assert_eq(foe.alert, Actor.SEARCH)
	assert_eq(foe.target, Vector2i(4, 8))
	assert_eq(foe.pos, Vector2i(11, 5), "one step towards it")


func test_claws_strike_thrice_at_an_unaware_creature_and_kill_silently() -> void:
	var w := _world()
	var prey := _foe(w, &"dokkaebi", Vector2i(5, 8))
	prey.blind = 2
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
	foe.hp = 3
	var other := _foe(w, &"imugi", Vector2i(9, 8))
	w.act({t = &"move", dir = E})
	assert_eq(foe.hp, 2, "at 1 health it would run instead of striking back")
	assert_eq(other.alert, Actor.SEARCH)
	assert_eq(other.target, Vector2i(5, 8))
	assert_eq(w.player().hp, 2, "the hunter strikes back")


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
	assert_eq(foe.intent[0].dir, WEST)
	w.act(WAIT)
	assert_eq(w.shots.size(), 1, "the searchlight is out")


func test_a_hunter_telegraphs_its_orb_and_a_side_step_dodges_it() -> void:
	for stay in [true, false]:
		var w := _world(Vector2i(5, 8))
		_put(w, Vector2i(5, 9), World.LANTERN)
		_lookout(w, &"jangseung", Vector2i(10, 8), 0)
		var events := w.act(WAIT)
		assert_has(_types(events), &"charge")
		w.act(WAIT if stay else {t = &"move", dir = N})
		w.act(WAIT)
		w.act(WAIT)
		var orb := Spell.make(Bestiary.casts(&"jangseung", 1)[0])
		var left := maxi(0, 3 - orb.damage(5))
		assert_eq(w.player().hp, left if stay else 3, "an orb from five tiles hits for its tier")


func test_a_blind_hunter_cannot_strike_back_and_takes_a_plain_claw() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(5, 8))
	foe.hp = 3
	foe.alert = Actor.HUNT
	foe.blind = 2
	w.act(WAIT)
	assert_eq(w.player().hp, 3, "blind, it cannot strike")
	w.act({t = &"move", dir = E})
	assert_eq(foe.hp, 2, "it is on guard")


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


func test_bamboo_hides_who_stands_in_it_from_all_but_the_next_tile() -> void:
	var w := _world(Vector2i(4, 8))
	_put(w, Vector2i(6, 10), World.LANTERN)
	_put(w, Vector2i(7, 8), World.BAMBOO)
	var hidden := _lookout(w, &"jangseung", Vector2i(7, 8))
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


func test_bamboo_rustles_and_floorboards_creak_and_draw_a_resting_creature() -> void:
	for tread in [[World.BAMBOO, ["사각", 2]], [World.BOARD, ["삐걱", 3]], [World.FLOOR, null]]:
		var w := _world()
		_put(w, Vector2i(5, 8), tread[0])
		var listener := _foe(w, &"imugi", Vector2i(7, 8))
		var noises := _noises(w.act({t = &"move", dir = E}))
		if tread[1] == null:
			assert_eq(noises, [], "plain floor is silent")
			assert_eq(listener.alert, Actor.REST)
			continue
		assert_eq([noises[0].word, noises[0].loud], tread[1])
		assert_eq(listener.alert, Actor.SEARCH)
		assert_eq(listener.target, Vector2i(5, 8))


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


func test_a_fire_wisp_sets_bamboo_alight_which_lights_burns_and_leaves_ash() -> void:
	var w := _world()
	w.cards.append(Cards.FIRE)
	for x in range(6, 13):
		_put(w, Vector2i(x, 8), World.BAMBOO)
	var foe := _foe(w, &"jangseung", Vector2i(8, 8))
	foe.hp = 8
	assert_false(w.lit(Vector2i(8, 6)))
	var events := w.act(_cast([FOX, Cards.FIRE], E))
	assert_true(w.burning.has(Vector2i(6, 8)), "caught where the wisp flew")
	assert_true(w.lit(Vector2i(8, 6)), "fire lights its surroundings")
	assert_eq(foe.hp, 8 - 1, "struck for 1; the flames it lit burn it from the next second")
	assert_true(events.filter(func(e): return e.t == &"burn").is_empty())
	assert_has(w.heard.map(func(h): return h.word), "타닥")
	assert_eq(w.seen[Grid.index(foe.pos)], 1, "burning bamboo hides nothing")
	events = w.act(WAIT)
	assert_eq(events.filter(func(e): return e.t == &"burn")[0].id, foe.id)
	assert_eq(foe.hp, 8 - 1 - World.FIRE_DAMAGE, "burnt the next second")
	events = w.act(WAIT)
	assert_eq(w.tile(Vector2i(6, 8)), World.ASH)
	assert_false(w.burning.has(Vector2i(6, 8)))
	assert_has(_types(events), &"burnout")
	assert_true(w.open_floor(Vector2i(6, 8)))


func test_a_burning_tile_burns_whoever_stands_in_it_for_fire_damage() -> void:
	assert_eq(World.FIRE_DAMAGE, 2)
	var w := _world()
	_put(w, Vector2i(5, 8), World.BOARD)
	w.burning[Vector2i(5, 8)] = World.BURN_ROUNDS
	var foe := _foe(w, &"jangseung", Vector2i(5, 8))
	w.act(WAIT)
	assert_eq(foe.hp, 3 - World.FIRE_DAMAGE)
	var quiet := _world()
	var me := quiet.player()
	_put(quiet, me.pos, World.BOARD)
	quiet.burning[me.pos] = World.BURN_ROUNDS
	quiet.act(WAIT)
	assert_eq(me.hp, 3 - World.FIRE_DAMAGE, "Miho burns for as much")


func test_a_fire_orbs_splash_hurts_for_fire_damage_and_twice_that_to_the_weak() -> void:
	var w := _world()
	w.cards.append(Cards.FIRE)
	var mid := _foe(w, &"jangseung", Vector2i(7, 8))
	var near := _foe(w, &"imugi", Vector2i(7, 9))
	var weak := _foe(w, &"jiha", Vector2i(8, 7))
	for a in [mid, near, weak]:
		a.hp = 12
	w.act(_cast([ORB, Cards.FIRE], E))
	assert_eq(mid.hp, 12 - 1, "the struck creature takes the orb's own harm")
	assert_eq(near.hp, 12 - World.FIRE_DAMAGE)
	assert_eq(weak.hp, 12 - 2 * World.FIRE_DAMAGE, "weak to fire")


func test_fire_spreads_through_bamboo_the_same_way_for_a_seed() -> void:
	var runs := []
	for run in 2:
		var w := _world()
		w.rng.seed = 11
		w.cards.append(Cards.FIRE)
		for y in range(4, 13):
			for x in range(8, 17):
				_put(w, Vector2i(x, y), World.BAMBOO)
		w.act(_cast([FOX, Cards.FIRE], E))
		for i in 5:
			w.act(WAIT)
		runs.append(w)
	assert_eq(runs[0].tiles, runs[1].tiles)
	assert_eq(runs[0].burning, runs[1].burning)
	var reached := 0
	for i in runs[0].tiles.size():
		var p := Grid.at(i)
		if p.y != 8 and (runs[0].tiles[i] == World.ASH or runs[0].burning.has(p)):
			reached += 1
	assert_gt(reached, 0, "it spread off the wisp's line")


func test_fire_burns_a_door_to_ash_and_spares_a_creature_that_eats_fire() -> void:
	var w := _world()
	w.cards.append(Cards.FIRE)
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(10, y), World.WALL)
	_put(w, Vector2i(10, 8), World.DOOR)
	_put(w, Vector2i(12, 4), World.BOARD)
	w.burning[Vector2i(12, 4)] = World.BURN_ROUNDS
	var eater := _foe(w, &"haetae", Vector2i(12, 4))
	assert_has(_types(w.act(_cast([FOX, Cards.FIRE], E))), &"absorb")
	assert_eq(eater.hp, 4)
	w.act(WAIT)
	assert_true(w.burning.has(Vector2i(10, 8)))
	assert_false(w.opaque(Vector2i(10, 8)), "a burning door hides nothing")
	w.act(WAIT)
	w.act(WAIT)
	assert_eq(w.tile(Vector2i(10, 8)), World.ASH)


func test_water_puts_a_fire_out() -> void:
	var w := _world()
	w.cards.append(Cards.WATER)
	_put(w, Vector2i(11, 8), World.BAMBOO)
	w.burning[Vector2i(11, 8)] = World.BURN_ROUNDS
	w.act(_cast([FOX, Cards.WATER], E))
	var events := w.act(WAIT)
	assert_has(_types(events), &"douse")
	assert_eq(w.burning, {})
	assert_eq(w.tile(Vector2i(11, 8)), World.BAMBOO)


func test_heaven_walks_around_fire() -> void:
	var w := _world()
	_put(w, Vector2i(9, 8), World.BOARD)
	w.burning[Vector2i(9, 8)] = World.BURN_ROUNDS
	var foe := _foe(w, &"dokkaebi", Vector2i(8, 8))
	foe.alert = Actor.SEARCH
	foe.target = Vector2i(12, 8)
	w.act(WAIT)
	assert_has([Vector2i(9, 7), Vector2i(9, 9)], foe.pos)


func test_strong_foe_drops_its_element_and_a_kill_gives_back_a_tail() -> void:
	var w := _world()
	w.tails = 1
	var foe := _foe(w, &"bulgae", Vector2i(6, 8))
	foe.hp = 1
	w.act(_cast([ORB], E))
	assert_false(foe.alive())
	assert_false(w.cards.has(Cards.FIRE), "the kill gives only the scroll")
	assert_eq(Scrolls.card_at(w, Vector2i(6, 8)), Cards.FIRE)
	assert_eq(w.tails, 1)
	w.player().pos = Vector2i(5, 8)
	w.act({t = &"move", dir = E})
	assert_has(w.cards, Cards.FIRE)


func test_one_turn_splits_the_tails_across_several_spells() -> void:
	var w := _world()
	w.depth = 2
	w.tails = 5
	for c in Cards.ELEMENTS:
		w.cards.append(c)
	var one_three := _casts([[[FOX], N], [[ORB, Cards.FIRE, Cards.WOOD], E]])
	var one_four := _casts([[[FOX], N], [[ORB, Cards.FIRE, Cards.WOOD, Cards.METAL], E]])
	var ones := _casts([[[FOX], N], [[FOX], E], [[ORB], S], [[ORB], WEST]])
	assert_true(w.can(one_three))
	assert_false(w.can(one_four), "one and five tails are six")
	assert_true(w.can(ones))
	assert_false(w.can(_casts([[[FOX, Cards.FIRE], N], [[ORB, Cards.WOOD, Cards.METAL, FOX], E]])))
	assert_false(w.can(_casts([[[FOX], E], [[ORB], E]])), "one spell per line")
	var events := w.act(ones)
	assert_eq(_types(events).count(&"cast"), 4)
	assert_eq(w.tails, 1)


func test_spent_tails_regrow_one_every_three_rounds_up_to_the_most_the_storey_allows() -> void:
	var w := _world()
	w.depth = 2
	w.tails = 0
	for i in 3:
		w.act(WAIT)
	assert_eq(w.tails, 1)
	for i in 9:
		w.act(WAIT)
	assert_eq(w.tails, 2)


func test_a_tail_grows_on_every_storey() -> void:
	var w := World.create(5)
	for case in [[1, 1], [2, 2], [3, 3], [5, 5], [8, 8], [9, 9]]:
		w.depth = case[0]
		assert_eq(w.max_tails(), case[1], "storey %d" % case[0])


func test_climbing_refills_the_tails_to_what_the_new_storey_allows() -> void:
	for depth in [1, 4]:
		var w := World.create(5)
		w.depth = depth
		FloorGen.build(w)
		w.tails = 0
		w.actors[0].pos = w.stairs + WEST
		if not w.vacant(w.stairs + WEST):
			w.actors[0].pos = w.stairs + E
		w.act({t = &"move", dir = w.stairs - w.actors[0].pos})
		assert_eq(w.depth, depth + 1)
		assert_eq(w.tails, depth + 1, "arriving on storey %d" % w.depth)


func test_storeys_are_connected_with_dark_starts_and_lit_stairs() -> void:
	var features := {World.BAMBOO: 0, World.POND: 0, World.BOARD: 0}
	for seed_value in 20:
		var w := World.create(seed_value)
		for t in w.tiles:
			if features.has(t):
				features[t] += 1
		assert_eq(w.tile(w.start), World.FLOOR)
		assert_eq(w.tile(w.stairs), World.FLOOR)
		var open := Masks.opened(w)
		var dist: PackedInt32Array = Grid.search(w.start, open).dist
		for i in w.tiles.size():
			if w.open_floor(Grid.at(i)):
				assert_gt(dist[i], -1, "seed %d tile %s" % [seed_value, Grid.at(i)])
		assert_true(w.lit(w.stairs), "seed %d" % seed_value)
		assert_false(w.lit(w.start), "seed %d" % seed_value)
		var guards := w.sites.filter(func(s): return s.kind in [&"yard", &"creak"]).size()
		assert_eq(w.actors.size() - 1, FloorGen.PLAN[1].size() + guards)
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


func test_climbing_the_stairs_heals_one_up_to_full() -> void:
	var w := World.create(5)
	var me := w.player()
	for hp in [1, me.max_hp]:
		me = w.player()
		me.hp = hp
		w.stairs = me.pos + E
		w.tiles[Grid.index(w.stairs)] = World.FLOOR
		var events := w.act({t = &"move", dir = E})
		assert_eq(w.player().hp, mini(hp + 1, me.max_hp))
		var healed := events.filter(func(e): return e.t == &"heal")
		assert_eq(healed.size(), 1 if hp < me.max_hp else 0, "hp %d" % hp)


func test_a_peach_heals_one_or_raises_full_health_by_one() -> void:
	var w := _world(Vector2i(5, 8))
	var me := w.player()
	me.hp = 1
	w.peaches.append(me.pos + E)
	w.act({t = &"move", dir = E})
	assert_eq([me.hp, me.max_hp], [2, 3])
	w.peaches.append(me.pos + E)
	me.hp = me.max_hp
	var grew := w.act({t = &"move", dir = E}).filter(func(e): return e.t == &"heal")
	assert_eq([me.hp, me.max_hp], [4, 4])
	assert_true(grew[0].grew)
