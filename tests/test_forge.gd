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
	a.magic.cooldown = 99
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
