extends GutTest
## 4단 and 5단 compounds: every order of four and five different elements, each
## spell's effect where it reaches, when a creature of heaven casts it, and
## carried on a projectile.

const FOX := Cards.FOX
const ORB := Cards.ORB
const FIRE := Cards.FIRE
const WATER := Cards.WATER
const WOOD := Cards.WOOD
const METAL := Cards.METAL
const EARTH := Cards.EARTH
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)
const ME := Vector2i(20, 12)


## An open hall walled at the edges, lit by lanterns two rows above Miho, who
## stands at ME with plenty of tails.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(2, Grid.W - 2, 3):
		w.tiles[Grid.index(Vector2i(x, ME.y - 2))] = World.LANTERN
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = 5
	w.tails = 9
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts, with health to spare.
func _post(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", at)
	a.cooldown = 99
	a.max_hp = 9
	a.hp = 9
	return a


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


## The first harm `id` takes in the round: the spell's, before hot ground and gas.
func _first(events: Array, id: int) -> int:
	return _of(events, &"hurt").filter(func(e): return e.id == id)[0].n


func _made(c: StringName) -> Array:
	return Cards.recipe(c)


func _orders(of: Array) -> Array:
	if of.size() <= 1:
		return [of]
	var out := []
	for i in of.size():
		var rest := of.duplicate()
		rest.remove_at(i)
		for tail: Array in _orders(rest):
			out.append([of[i]] + tail)
	return out


func _same_set(a: Array, b: Array) -> bool:
	return a.size() == b.size() and a.all(func(e): return b.has(e))


func test_an_order_of_four_different_elements_that_makes_one_slot_makes_a_4dan_of_that_set(
) -> void:
	var seen := {}
	for left in Cards.ELEMENTS:
		var picked: Array = Cards.ELEMENTS.filter(func(e): return e != left)
		for order: Array in _orders(picked):
			var s := Spell.make(order)
			if s.slots.size() > 1:
				continue
			assert_true(Cards.QUADS.has(s.slots[0]), str(order))
			assert_true(_same_set(Cards.made_of(s.slots[0]), picked), str(order))
			assert_eq(s.cost(), Spell.price(4), str(order))
			seen[s.slots[0]] = true
	assert_eq(seen.size(), Cards.QUADS.size(), "every 4단 is made")


func test_five_elements_that_make_one_slot_make_a_5dan_and_a_last_earth_the_dragon() -> void:
	var seen := {}
	for order: Array in _orders(Cards.ELEMENTS):
		var s := Spell.make(order)
		if s.slots.size() > 1:
			continue
		assert_true(Cards.FIVES.has(s.slots[0]), str(order))
		assert_eq(s.slots[0] == Cards.DRAGON, order.back() == EARTH, str(order))
		assert_eq(s.cost(), 7, str(order))
		seen[s.slots[0]] = true
	assert_eq(seen.size(), 3)


func test_a_fifth_card_of_a_held_element_stacks_beside_the_5dan() -> void:
	var s := Spell.make(Cards.recipe(Cards.SAMSARA) + [FIRE])
	assert_eq(s.slots, [Cards.SAMSARA, FIRE] as Array[StringName])
	assert_eq(s.cost(), Spell.price(6))


func test_a_5dan_costs_seven_tails_and_miho_has_them_on_the_seventh_storey() -> void:
	var w := _world()
	w.depth = 7
	assert_eq(w.max_tails(), 7)
	w.tails = 7
	var cards: Array = Cards.recipe(Cards.CONQUEST)
	assert_true(w.can(_cast(cards)))
	w.tails = 6
	assert_false(w.can(_cast(cards)))
	w.tails = 7
	w.act(_cast(cards))
	assert_eq(w.tails, 0)


# --- 4단 and 5단 --------------------------------------------------------------


## Casts `cards` from Miho's tile at once, with no round after it: nobody moves
## or looks again. Returns the events.
func _now(w: World, cards: Array, dir := E, by: Actor = null) -> Array:
	w.events = []
	w.cast(w.player() if by == null else by, Spell.make(cards), dir)
	return w.events


## A wall across the hall at column x.
func _wall_across(w: World, x: int) -> void:
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(x, y), World.WALL)


## Casts by a creature of heaven standing at `at`, which has a good look at Miho.
func _caster(w: World, at: Vector2i) -> Actor:
	var a := _post(w, at)
	a.hp = 1
	return a


func test_beacon_sets_a_wildfire_is_heard_at_its_end_and_lights_the_lanterns_in_sight() -> void:
	var w := _world()
	var centre := ME + E * 6
	_put(w, centre, World.GRASS)
	_put(w, centre + Vector2i(1, 1), World.GRASS)
	_wall_across(w, ME.x + 12)
	_put(w, ME + Vector2i(3, -2), World.LANTERN_OUT)
	_put(w, Vector2i(ME.x + 15, ME.y - 2), World.LANTERN_OUT)
	var foe := _post(w, centre + E)
	w.sense()
	var events := w.act(_cast(_made(&"beacon")))
	assert_true(w.wild.has(centre) and w.wild.has(centre + Vector2i(1, 1)), "a fire that spreads")
	assert_gt(foe.alight, 0)
	assert_eq(w.tile(ME + Vector2i(3, -2)), World.LANTERN, "the dark lantern in sight")
	assert_eq(w.tile(Vector2i(ME.x + 15, ME.y - 2)), World.LANTERN_OUT, "behind the wall")
	var calls := _of(events, &"noise").filter(func(e): return e.word == Compounds.BEACON_WORD)
	assert_eq(calls.size(), 1)
	assert_eq([calls[0].at, calls[0].loud], [centre, Compounds.BOOM])
	var at_me := _of(events, &"noise").filter(func(e): return e.at == ME and e.loud > 0)
	assert_true(at_me.is_empty(), "nothing is heard where it was cast")


func test_a_beacon_wakes_the_creature_that_hears_it_to_search_the_end() -> void:
	var w := _world()
	var centre := ME + E * 6
	var sleeper := FloorGen.spawn(w, &"dokkaebi", ME + Vector2i(-2, 3))
	sleeper.cooldown = 99
	w.sense()
	_now(w, _made(&"beacon"))
	assert_eq(sleeper.alert, Actor.SEARCH)
	assert_eq(sleeper.target, centre)


func test_magpie_bridges_the_sky_on_the_seven_by_seven_round_her_and_nothing_else() -> void:
	var w := _world()
	var inside := [ME + E * 2, ME + E * 3, ME + Vector2i(-3, 3), ME + Vector2i(3, -3)]
	for p: Vector2i in inside:
		_put(w, p, World.SKY)
	_put(w, ME + Vector2i(1, 1), World.WALL)
	_put(w, ME + Vector2i(2, 2), World.SKY)
	_put(w, ME + E * 4, World.SKY)
	_put(w, ME + Vector2i(0, 2), World.POND)
	var events := w.act(_cast(_made(&"magpie")))
	for p: Vector2i in inside + [ME + Vector2i(2, 2)]:
		assert_eq(w.tile(p), World.BRIDGE, str(p))
		assert_true(w.open_floor(p), "it can be walked")
	assert_eq(w.tile(ME + E * 4), World.SKY, "past three tiles")
	assert_eq(w.tile(ME + Vector2i(0, 2)), World.POND, "a pond stays")
	assert_eq(_of(events, &"become").size(), 1)


func test_mist_lays_fog_round_miho_and_washes_the_scent_without_striking_anyone() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Scent.lay(w, ME + E * 3)
	var events := _now(w, _made(&"mist"))
	assert_eq(Gas.at(w, ME + E * 4).x, Gas.FOG)
	assert_eq(Gas.at(w, ME + E * 4).y, Gas.MAX)
	assert_false(w.gas.has(ME + E * 5), "four tiles")
	assert_eq(w.scent[Grid.index(ME + E * 3)], 0)
	assert_eq(foe.alert, Actor.REST, "no one is struck")
	assert_true(_of(events, &"noise").is_empty(), "silent")


func test_sinkhole_drops_the_open_ground_and_what_stands_on_it() -> void:
	var w := _world()
	var centre := _post(w, ME + E * 3)
	var side := _post(w, ME + Vector2i(4, 1))
	var events := w.act(_cast(_made(&"sinkhole")))
	for p: Vector2i in Spray.square(w, ME + E * 3, 1):
		assert_eq(w.tile(p), World.SKY, str(p))
	assert_false(centre.alive() or side.alive())
	assert_eq(_of(events, &"fall").size(), 2)
	assert_eq(w.tile(ME), World.FLOOR)


func test_sinkhole_moves_a_scroll_off_the_ground_it_takes() -> void:
	var w := _world()
	var on := ME + E * 3
	w.sites.append({kind = &"scroll", at = on, card = FIRE})
	w.act(_cast(_made(&"sinkhole")))
	assert_eq(w.tile(on), World.SKY)
	var at: Vector2i = w.sites[0].at
	assert_true(w.vacant(at), str(at))
	assert_eq(Grid.cheb(at, on), 2, "the nearest floor past the sinkhole")


func test_sinkhole_never_takes_miho_s_tile_nor_the_stairs_the_elixir_or_a_peach() -> void:
	var w := _world()
	_put(w, ME + E, World.WALL)
	w.stairs = ME + Vector2i(-1, 0)
	w.peaches.append(ME + Vector2i(0, -1))
	w.elixir = ME + Vector2i(0, 1)
	w.act(_cast(_made(&"sinkhole")))
	assert_eq(w.tile(ME), World.FLOOR, "centred on her")
	for p in [w.stairs, w.elixir, ME + Vector2i(0, -1)]:
		assert_eq(w.tile(p), World.FLOOR, str(p))
	assert_eq(w.tile(ME + Vector2i(1, 1)), World.SKY)
	assert_eq(w.depth, 5, "she stays")


## A corridor of `lanes` rows from Miho to the stairs 25 tiles east.
func _corridor(lanes: int) -> World:
	var w := _world()
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			_put(w, Vector2i(x, y), World.WALL)
	for y in range(ME.y, ME.y + lanes):
		for x in range(ME.x, ME.x + 26):
			_put(w, Vector2i(x, y), World.FLOOR)
	w.stairs = ME + E * 25
	w.sense()
	return w


func _linked(w: World) -> bool:
	return Grid.search(w.stairs, Masks.floor_of(w)).dist[Grid.index(w.player().pos)] >= 0


func test_sinkhole_keeps_every_tile_whose_loss_would_cut_miho_from_the_stairs() -> void:
	var w := _corridor(1)
	w.act(_cast(_made(&"sinkhole")))
	assert_true(_linked(w))
	assert_eq(w.tiles.count(World.SKY), 0, "a single lane stays whole")
	w = _corridor(2)
	w.act(_cast(_made(&"sinkhole")))
	assert_true(_linked(w))
	assert_eq(w.tiles.count(World.SKY), 3, "one lane of the burst goes, the other stays")


func test_discord_sets_the_nearest_pairs_of_seen_foes_on_each_other_whatever_their_group() -> void:
	var w := _world()
	var a := _post(w, ME + E * 3)
	var b := _post(w, ME + E * 4)
	var c := _post(w, ME + Vector2i(10, -1))
	var d := _post(w, ME + Vector2i(11, -1))
	var lone := _post(w, ME + Vector2i(-8, 2))
	var events := _now(w, _made(&"discord"))
	assert_eq([a.rival, b.rival], [b.id, a.id])
	assert_eq([c.rival, d.rival], [d.id, c.id])
	assert_eq([a.grudge, c.grudge], [Mind.GRUDGE_ROUNDS, Mind.GRUDGE_ROUNDS])
	assert_eq(lone.rival, 0, "an odd one out")
	assert_eq(_of(events, &"feud").size(), 4)
	assert_eq(a.alert, Actor.REST, "no one is struck")


func test_discord_does_nothing_when_a_creature_of_heaven_casts_it() -> void:
	var w := _world()
	var caster := _caster(w, ME + E * 3)
	var a := _post(w, ME + E * 5)
	var b := _post(w, ME + E * 6)
	var events := _now(w, _made(&"discord"), W, caster)
	assert_eq([a.rival, b.rival, caster.rival], [0, 0, 0])
	assert_true(_of(events, &"feud").is_empty())
	assert_eq(w.player().hp, w.player().max_hp)


## The creatures harmed in `events`, by id, in order.
func _struck(events: Array) -> Array:
	return _of(events, &"hurt").map(func(e): return e.id)


## A post that outlasts every arc.
func _tough(w: World, at: Vector2i) -> Actor:
	var a := _post(w, at)
	a.max_hp = 99
	a.hp = 99
	return a


func test_thunder_strikes_the_first_creature_on_its_line_and_is_heard_and_seen() -> void:
	var w := _world()
	var first := _post(w, ME + E * 2)
	var far := _post(w, ME + E * 2 + E * (Compounds.ARC_REACH + 1))
	var events := w.act(_cast(_made(&"thunder")))
	assert_eq(_first(events, first.id), Compounds.THUNDER)
	assert_eq(first.stunned, Compounds.THUNDER_STUN - 1)
	assert_eq(far.hp, far.max_hp, "out of reach of the arc")
	var booms := _of(events, &"noise").filter(func(e): return e.loud == Compounds.BOOM)
	assert_false(booms.is_empty())
	w = _world()
	_now(w, _made(&"thunder"))
	assert_true(w.flares.has(ME), "a flash on her tile")


func test_thunder_arcs_to_a_foe_within_reach_and_not_through_a_wall() -> void:
	var w := _world()
	var first := _post(w, ME + E * 2)
	var next := _tough(w, first.pos + Vector2i(-1, Compounds.ARC_REACH))
	var walled := _post(w, first.pos + E * Compounds.ARC_REACH)
	_put(w, first.pos + E, World.WALL)
	var events := w.act(_cast(_made(&"thunder")))
	assert_eq(_first(events, next.id), Compounds.THUNDER)
	assert_eq(next.stunned, Compounds.THUNDER_STUN - 1)
	assert_eq(walled.hp, walled.max_hp, "the wall stops the arc")
	assert_eq(next.alert, Actor.HUNT, "it is struck like the first")


func test_thunder_goes_back_and_forth_between_two_foes_for_all_its_arcs() -> void:
	var w := _world()
	var a := _tough(w, ME + E * 2)
	var b := _tough(w, ME + E * 4)
	var struck := _struck(w.act(_cast(_made(&"thunder"))))
	assert_eq(struck.size(), Compounds.ARCS + 1)
	for i in struck.size():
		assert_eq(struck[i], a.id if i % 2 == 0 else b.id, "arc %d" % i)


func test_thunder_arcs_to_the_foe_it_struck_least_then_the_nearest() -> void:
	var w := _world()
	var a := _tough(w, ME + E * 2)
	var far := _tough(w, a.pos + E * Compounds.ARC_REACH)
	var near := _tough(w, a.pos + Vector2i(1, 1))
	var struck := _struck(w.act(_cast(_made(&"thunder"))))
	assert_eq(struck.slice(0, 3), [a.id, near.id, far.id])


func test_thunder_never_arcs_to_its_caster_or_her_allies() -> void:
	var w := _world()
	var first := _post(w, ME + E * 2)
	var ally := _post(w, ME + Vector2i(1, 1))
	ally.faction = Actor.FOX
	ally.stunned = 9
	var struck := _struck(w.act(_cast(_made(&"thunder"))))
	assert_eq(struck, [first.id])


func test_a_foes_thunder_arcs_to_miho() -> void:
	var w := _world()
	var caster := _post(w, ME + E * 4)
	var first := _post(w, ME + E * 2)
	first.faction = Actor.FOX
	var s := Spell.make(_made(&"thunder"))
	Spray.cast(w, caster, s, -E)
	assert_lt(w.player().hp, w.player().max_hp)
	assert_eq(caster.hp, caster.max_hp)


func test_a_foe_an_arc_felled_takes_no_more_of_a_carried_thunder() -> void:
	var w := _world()
	var foes := [_post(w, ME + E * 2), _post(w, ME + E * 3), _post(w, ME + E * 2 + Vector2i(0, 1))]
	for foe in foes:
		foe.hp = 1
	var events := w.act(_cast([ORB] + _made(&"thunder")))
	for foe in foes:
		var fell := events.find_custom(func(e): return e.t == &"die" and e.id == foe.id)
		assert_gte(fell, 0)
		var after := events.slice(fell)
		assert_false(after.any(func(e): return e.t == &"hit" and e.id == foe.id))


func test_the_arcs_of_thunder_show_on_the_aim() -> void:
	var w := _world()
	var a := _post(w, ME + E * 2)
	var b := _post(w, a.pos + Vector2i(2, 2))
	var f := Forecast.of(w, _cast(_made(&"thunder")))
	var tiles := []
	for e in f.sprays:
		tiles += e.tiles
	assert_true(tiles.has(b.pos))
	assert_true(tiles.has(a.pos + Vector2i(1, 1)), "the path between them")


func test_thunder_hurts_a_wet_creature_and_a_water_creature_twice_but_not_four_times() -> void:
	var spell := Spell.make(_made(&"thunder"))
	var waters := Bestiary.KINDS.keys().filter(
		func(k): return Bestiary.elements(k).has(WATER) and not Bestiary.absorbs(k, spell)
	)
	var water: StringName = waters[0]
	var w := _world()
	var dry := _post(w, ME + E * 2)
	var wet := _post(w, ME + E * 3)
	wet.wet = Status.WET
	var of_water := _post(w, ME + E * 4)
	of_water.kind = water
	var both := _post(w, ME + E * 5)
	both.kind = water
	both.wet = Status.WET
	var events := w.act(_cast(_made(&"thunder")))
	assert_eq(_first(events, dry.id), Compounds.THUNDER)
	for foe in [wet, of_water, both]:
		assert_eq(_first(events, foe.id), Compounds.THUNDER * Elements.WEAK)


func test_stillness_sends_the_hunters_in_reach_to_search_where_they_stand() -> void:
	var w := _world()
	var near := _post(w, ME + E * 4)
	var far := _post(w, ME + E * 10)
	var asleep := _post(w, ME + Vector2i(-3, 2))
	for foe in [near, far]:
		foe.alert = Actor.HUNT
		foe.target = ME
	Scent.lay(w, ME + E * 2)
	var events := _now(w, _made(&"stillness"))
	assert_eq([near.alert, near.target], [Actor.SEARCH, near.pos])
	assert_eq(far.alert, Actor.HUNT, "past six tiles")
	assert_eq(asleep.alert, Actor.REST)
	assert_eq(w.scent[Grid.index(ME + E * 2)], 0)
	assert_true(_of(events, &"noise").is_empty(), "silent")


func test_stillness_cast_by_a_creature_of_heaven_leaves_miho_as_she_was() -> void:
	var w := _world()
	var caster := _caster(w, ME + E * 3)
	var events := _now(w, _made(&"stillness"), W, caster)
	assert_eq(w.player().alert, Actor.REST)
	assert_eq(w.player().hp, w.player().max_hp)
	assert_true(_of(events, &"hurt").is_empty())


func test_samsara_heals_the_caster_a_point_and_stuns_every_foe_in_sight() -> void:
	var w := _world()
	w.player().hp = 1
	var near := _post(w, ME + E * 3)
	var far := _post(w, ME + Vector2i(-9, 2))
	_wall_across(w, ME.x + 6)
	var hidden := _post(w, ME + Vector2i(9, 0))
	var events := _now(w, _made(Cards.SAMSARA))
	assert_eq(w.player().hp, 2)
	assert_eq(_of(events, &"heal").size(), 1)
	assert_eq([near.stunned, far.stunned, hidden.stunned], [2, 2, 0])
	events = _now(w, _made(Cards.SAMSARA))
	assert_eq(w.player().hp, 3)
	events = _now(w, _made(Cards.SAMSARA))
	assert_eq(w.player().hp, 3, "never past her health")
	assert_true(_of(events, &"heal").is_empty())


func test_samsara_cast_by_a_creature_of_heaven_heals_it_and_stuns_miho() -> void:
	var w := _world()
	var caster := _caster(w, ME + E * 3)
	var events := _now(w, _made(Cards.SAMSARA), W, caster)
	assert_eq(caster.hp, 2)
	assert_eq(w.player().stunned, 2)
	assert_true(_of(events, &"heal").is_empty(), "the log tells only Miho's")


func test_conquest_hurts_every_foe_in_sight_and_doubles_it_for_one_with_a_weakness() -> void:
	var w := _world()
	var plain := _post(w, ME + E * 3)
	var weak := FloorGen.spawn(w, &"cheonnyeon", ME + E * 5)
	weak.cooldown = 99
	weak.max_hp = 20
	weak.hp = 20
	_wall_across(w, ME.x + 8)
	var hidden := _post(w, ME + Vector2i(10, 0))
	w.sense()
	var events := w.act(_cast(_made(Cards.CONQUEST)))
	assert_eq(_first(events, plain.id), Compounds.CONQUEST_HARM)
	assert_eq(_first(events, weak.id), 2 * Compounds.CONQUEST_HARM)
	assert_eq(hidden.hp, hidden.max_hp)
	assert_false(_of(events, &"noise").filter(func(e): return e.loud == Compounds.BOOM).is_empty())


func test_dragon_fells_the_walls_and_pushes_the_foes_out_farthest_first_and_stuns_them() -> void:
	var w := _world()
	for y in range(ME.y - 2, ME.y + 3):
		_put(w, ME + Vector2i(3, y - ME.y), World.WALL)
	_put(w, ME + Vector2i(5, -4), World.WALL)
	var inner := _post(w, ME + E * 2)
	var outer := _post(w, ME + E * 4)
	var west := _post(w, ME + Vector2i(-3, 0))
	var events := w.act(_cast(_made(Cards.DRAGON)))
	assert_eq(w.tile(ME + E * 3), World.RUBBLE, "the walls in reach")
	assert_eq(w.tile(ME + Vector2i(5, -4)), World.WALL, "past four tiles")
	assert_eq(outer.pos, ME + E * 7)
	assert_eq(inner.pos, ME + E * 5, "room was made for it")
	assert_eq(west.pos, ME + Vector2i(-6, 0))
	for foe in [inner, outer, west]:
		assert_eq(foe.stunned, Compounds.DRAGON_STUN - 1)
	assert_eq([w.player().pos, w.player().hp], [ME, 3])
	assert_false(_of(events, &"noise").filter(func(e): return e.loud == Compounds.BOOM).is_empty())


func test_a_4dan_or_5dan_carried_on_a_projectile_acts_on_the_3x3_where_it_ends() -> void:
	for form in [FOX, ORB]:
		var w := _world()
		var hit := _post(w, ME + E * 2)
		var side := _post(w, ME + Vector2i(2, 1))
		w.act(_cast([form] + _made(&"sinkhole")))
		assert_false(hit.alive() or side.alive(), "both fall: %s" % form)
		w = _world()
		w.player().hp = 1
		hit = _post(w, ME + E * 2)
		side = _post(w, ME + Vector2i(2, 1))
		w.act(_cast([form] + _made(Cards.SAMSARA)))
		assert_eq(w.player().hp, 2, str(form))
		assert_gt(side.stunned, 0, str(form))
		w = _world()
		hit = _post(w, ME + E * 2)
		side = _post(w, ME + Vector2i(2, 1))
		var events := w.act(_cast([form] + _made(Cards.CONQUEST)))
		assert_eq(_first(events, side.id), Compounds.CONQUEST_HARM, str(form))


func test_a_cloud_of_fog_is_one_line_in_the_log() -> void:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.FLOOR)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	var fog := []
	for x in range(3, 8):
		fog.append({t = &"gas", at = Vector2i(x, 5), kind = Gas.FOG})
	assert_eq(Messages.of(w, w, fog).map(Messages.plain), ["안개가 피어올랐다"])
