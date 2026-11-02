extends GutTest
## What lets out orbs of lava: the orb itself, which only an orb can carry, and the furnace
## that stands where it is set and hurls them at what it sees.

const ORB := Cards.ORB
const FIRE := Cards.FIRE
const EARTH := Cards.EARTH
const METAL := Cards.METAL
const LAVA := [ORB, FIRE, EARTH]
const FURNACE := [ORB, FIRE, EARTH, METAL]
const E := Vector2i(1, 0)
const ME := Vector2i(20, 12)
const WAIT := {t = &"wait"}


func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(2, Grid.W - 2, 3):
		w.tiles[Grid.index(Vector2i(x, ME.y - 4))] = World.LANTERN
		w.tiles[Grid.index(Vector2i(x, ME.y + 4))] = World.LANTERN
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


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func _post(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", at)
	a.cooldown = 99
	a.max_hp = 9
	a.hp = 9
	w.sense()
	return a


func _settle(w: World) -> void:
	while not w.shots.is_empty():
		w.act(WAIT)


func _furnace(w: World) -> Actor:
	for a: Actor in w.actors:
		if a.kind == Forge.FURNACE:
			return a
	return null


func test_a_lava_orb_flies_five_tiles_at_two_a_round_and_bursts_into_hot_iron() -> void:
	var w := _world()
	w.act(_cast(LAVA))
	assert_eq(w.shots.size(), 1)
	_settle(w)
	var end := ME + E * Forge.RANGE
	assert_eq(w.hot.size(), 9)
	for y in [-1, 0, 1]:
		for x in [-1, 0, 1]:
			assert_eq(w.hot[end + Vector2i(x, y)].x, Compounds.MOLTEN)


func test_a_lava_orb_bursts_on_the_first_creature_and_does_not_turn_for_one_off_its_line() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	w.act(_cast(LAVA))
	assert_lt(foe.hp, 9)
	assert_eq(w.hot[foe.pos].x, Compounds.MOLTEN)
	w = _world()
	_post(w, ME + Vector2i(3, 2))
	w.act(_cast(LAVA))
	assert_eq(w.shots[0].pos.y, ME.y)
	_settle(w)
	assert_true(w.hot.has(ME + E * Forge.RANGE))


func test_lava_and_a_furnace_are_no_spell_without_an_orb() -> void:
	for cards: Array in [
		[FIRE, EARTH],
		[FIRE, EARTH, METAL],
		[Cards.FOX, FIRE, EARTH],
		[Cards.FOX, FIRE, EARTH, METAL]
	]:
		var w := _world()
		assert_false(w.can(_cast(cards)), str(cards))
		assert_eq(Guise.why(w.player(), Spell.make(cards), E), Guise.NO_ORB, str(cards))
	for cards: Array in [LAVA, FURNACE]:
		var w := _world()
		assert_true(w.can(_cast(cards)), str(cards))
		assert_eq(Guise.why(w.player(), Spell.make(cards), E), "", str(cards))


func test_a_furnace_goes_on_a_free_tile_in_reach_that_the_seed_picks() -> void:
	var seen := {}
	for n in 8:
		var w := _world()
		w.rng.seed = n + 1
		w.act(_cast(FURNACE))
		var f := _furnace(w)
		assert_true(f.ally(), "on her side")
		assert_eq(w.seen[Grid.index(f.pos)], 1, "its own glow shows it in the dark")
		assert_lte(Grid.cheb(f.pos, ME), Forge.REACH)
		assert_ne(f.pos, ME)
		seen[f.pos] = true
	assert_gt(seen.size(), 1, "not one fixed tile")


func test_a_furnace_with_no_free_tile_is_not_set() -> void:
	var w := _world()
	for y in range(ME.y - 1, ME.y + 2):
		for x in range(ME.x - 1, ME.x + 2):
			if Vector2i(x, y) != ME:
				w.set_tile(Vector2i(x, y), World.WALL)
	w.sense()
	w.act(_cast(FURNACE))
	assert_null(_furnace(w))


func test_a_furnace_hurls_at_a_foe_it_sees_off_its_lines_every_two_rounds_and_stays_put() -> void:
	var w := _world()
	var f := FloorGen.spawn(w, Forge.FURNACE, ME + Vector2i(0, 3))
	var at := f.pos
	var foe := _post(w, f.pos + Vector2i(5, 2))
	foe.max_hp = 99
	foe.hp = 99
	var thrown := 0
	for i in 6:
		var had := w.shots.map(func(s): return s.id)
		w.act(WAIT)
		thrown += w.shots.filter(func(s): return not had.has(s.id) and Forge.lobbed(s.spell)).size()
	assert_eq(thrown, 6 / Forge.FIRE_ROUNDS)
	assert_eq(f.pos, at)


func test_a_furnace_holds_its_fire_when_its_side_stands_in_the_way() -> void:
	var w := _world()
	var f := FloorGen.spawn(w, Forge.FURNACE, ME - E * 2)
	_post(w, ME + E * 2)
	for i in 4:
		w.act(WAIT)
	assert_true(w.shots.is_empty(), "she stands on the line")
	assert_eq(w.player().hp, 3)
	assert_true(f.alive())


func test_a_furnace_stays_on_its_storey() -> void:
	var w := _world()
	var f := FloorGen.spawn(w, Forge.FURNACE, ME - E)
	var depth := w.depth
	w.stairs = ME + E
	w.act({t = &"move", dir = E})
	assert_eq(w.depth, depth + 1)
	assert_null(w.actor(f.id))
	assert_true(w.storeys[depth].actors.any(func(a): return a.id == f.id))


func test_a_leap_can_carry_a_lava_orb_to_where_it_lands() -> void:
	var w := _world()
	var cards: Array = Cards.recipe(Cards.VAULT) + LAVA
	assert_true(w.can(_cast(cards)))
	assert_eq(Guise.why(w.player(), Spell.make(cards), E), "")


func test_a_blasting_mortar_is_drawn_like_any_burst() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	foe.max_hp = 99
	foe.hp = 99
	var events := w.act(_cast([ORB, ORB, ORB, EARTH, METAL]))
	var splashes := events.filter(func(e): return e.t == &"splash")
	assert_false(splashes.is_empty())
	for e: Dictionary in splashes:
		assert_false(Impact.flashes(e).is_empty())


func test_a_furnace_hurls_at_every_rank_the_spell_it_lists() -> void:
	var w := _world()
	w.depth = World.FLOORS
	var f := FloorGen.spawn(w, Forge.FURNACE, ME + Vector2i(0, 3))
	var foe := _post(w, f.pos + E * 4)
	foe.max_hp = 99
	foe.hp = 99
	for i in 2:
		w.act(WAIT)
	var thrown := w.shots.filter(func(s): return s.caster == f.id)
	assert_false(thrown.is_empty())
	assert_eq(thrown[0].spell.cards, Bestiary.casts(Forge.FURNACE, f.rank)[0])


func test_a_furnace_never_shuts_her_off_from_the_way_up() -> void:
	for n in 8:
		var w := _world()
		w.rng.seed = n + 1
		for y in range(1, Grid.H - 1):
			for x in range(1, Grid.W - 1):
				if y != ME.y:
					w.tiles[Grid.index(Vector2i(x, y))] = World.WALL
		w.stairs = Vector2i(Grid.W - 2, ME.y)
		w.sense()
		w.act(_cast(FURNACE))
		var f := _furnace(w)
		assert_not_null(f)
		assert_lt(f.pos.x, ME.x, "behind her on the corridor")


func test_a_furnace_holds_its_fire_when_the_end_of_the_flight_would_catch_her() -> void:
	var w := _world()
	var f := FloorGen.spawn(w, Forge.FURNACE, ME - E * 5 + Vector2i(0, 1))
	_post(w, f.pos + Vector2i(4, 1))
	for i in 4:
		w.act(WAIT)
	assert_true(w.shots.is_empty(), "she stands by where it would burst")


func test_no_creature_lists_a_dead_spell_and_the_reaper_aims_its_beacon() -> void:
	var w := _world()
	var saja := FloorGen.spawn(w, &"saja", ME + E * 3)
	for kind: StringName in Bestiary.KINDS:
		for cast: Array in Bestiary.casts(kind, 5):
			assert_false(Forge.needs_orb(Spell.make(cast)), "%s %s" % [kind, cast])
	var beacons := Bestiary.casts(&"saja", 5).filter(func(c): return Spell.make(c).has(&"beacon"))
	assert_eq(beacons.size(), 1)
	assert_false(Aim._spray(w, saja, beacons[0], w.player()).is_empty())


func test_a_slot_in_a_queue_tells_its_own_talismans_and_price() -> void:
	var head := Info.plain(SpellInfo.slot(Spell.make(LAVA), 1)).get_slice("\n", 0)
	assert_string_contains(head, "꼬리: %d" % Spell.price(2))
	assert_false(head.contains("구슬"), head)


func test_a_flyer_takes_no_harm_from_hot_ground() -> void:
	var w := _world()
	var bat := FloorGen.spawn(w, &"bakjwi", ME + E * 3)
	bat.cooldown = 99
	bat.rooted = 9
	var hp := bat.hp
	Compounds.heat(w, [bat.pos], Compounds.MOLTEN)
	w.act(WAIT)
	assert_eq(bat.hp, hp)


func test_a_creature_that_leaps_into_a_wall_does_not_call_its_side() -> void:
	var w := _world()
	var y := ME.y + 6
	var sleeper := FloorGen.spawn(w, &"dokkaebi", Vector2i(Grid.W - 6, y))
	sleeper.cooldown = 99
	var leaper := FloorGen.spawn(w, &"dokkaebi", Vector2i(Grid.W - 3, y))
	Leap.cast(w, leaper, Spell.make(Cards.recipe(Cards.VAULT)), E)
	assert_eq(leaper.pos, Vector2i(Grid.W - 2, y))
	assert_eq(sleeper.alert, Actor.REST, "no search for its own crash")


func test_what_stands_round_her_is_cast_on_her_tile_too() -> void:
	for cards: Array in [FURNACE, Cards.recipe(&"beacon")]:
		var w := _world()
		assert_eq(Guise.why(w.player(), Spell.make(cards)), "", str(cards))
		assert_true(w.can(_cast(cards, Vector2i.ZERO)), str(cards))
		var tails := w.tails
		w.act(_cast(cards, Vector2i.ZERO))
		assert_lt(w.tails, tails, str(cards))
		assert_true(Guise.shadows(w, w.player()).is_empty(), "no dark wisp rides her")
	var w := _world()
	w.act(_cast(FURNACE, Vector2i.ZERO))
	assert_not_null(_furnace(w))


func test_a_furnace_stands_where_she_can_see_it() -> void:
	for n in 8:
		var w := _world()
		w.rng.seed = n + 1
		for y in range(ME.y - 3, ME.y + 4):
			if y != ME.y + 1:
				w.tiles[Grid.index(ME + Vector2i(1, y - ME.y))] = World.WALL
		w.sense()
		w.act(_cast(FURNACE))
		var f := _furnace(w)
		assert_not_null(f)
		assert_true(w.sees(w.player(), f.pos), str(f.pos))


func test_a_second_furnace_never_shuts_her_off_from_the_way_up() -> void:
	for n in 40:
		var w := _world()
		w.rng.seed = n + 1
		for y in range(1, Grid.H - 1):
			for x in range(1, Grid.W - 1):
				if y != ME.y and y != ME.y + 1:
					w.tiles[Grid.index(Vector2i(x, y))] = World.WALL
		for x in range(1, ME.x):
			w.tiles[Grid.index(Vector2i(x, ME.y))] = World.WALL
			w.tiles[Grid.index(Vector2i(x, ME.y + 1))] = World.WALL
		w.stairs = Vector2i(Grid.W - 2, ME.y)
		w.tails = 20
		w.sense()
		w.act(_cast(FURNACE))
		w.act(_cast(FURNACE))
		var furnaces := w.actors.filter(func(a): return a.kind == Forge.FURNACE)
		assert_eq(furnaces.size(), 2)
		assert_true(Compounds.linked(w, furnaces.map(func(a): return a.pos)), "seed %d" % (n + 1))


func test_a_creature_keeps_a_lava_orb_until_its_foe_is_in_range() -> void:
	var w := _world()
	var saja := FloorGen.spawn(w, &"saja", ME + E * (Forge.RANGE + 2))
	assert_true(Aim._reach(w, saja, LAVA, w.player()).is_empty())
	saja.pos = ME + E * Forge.RANGE
	assert_false(Aim._reach(w, saja, LAVA, w.player()).is_empty())
