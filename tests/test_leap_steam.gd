extends GutTest
## A leap vents steam to fly: Compounds.STEAM of it lies on the tiles she leaves,
## the one she starts on included. The landing and the tile before it stay clear,
## so that the spreading steam does not reach her as she lands.

const LEAP := [Cards.WATER, Cards.WOOD, Cards.FIRE]
const E := Vector2i(1, 0)
const ME := Vector2i(4, 8)
const DEEP := 5
const STEAM := Vector2i(Gas.STEAM, Compounds.STEAM)


## An open hall walled at the edges, Miho at ME, every tile known.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	w.rooms = [Rect2i(1, 1, Grid.W - 2, Grid.H - 2)]
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
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = DEEP
	w.tails = 5
	w.cards.append_array([Cards.EARTH, Cards.WATER, Cards.WOOD, Cards.FIRE])
	return w


func _cast(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = E}]}


func test_a_leap_lays_steam_behind_her_and_none_on_the_last_two_tiles() -> void:
	var w := _world()
	var spell := Spell.make(LEAP + [Cards.WOOD])
	Leap.cast(w, w.player(), spell, E)
	assert_eq(w.player().pos, ME + E * spell.leap())
	for i in spell.leap() - 1:
		assert_eq(w.gas.get(ME + E * i), STEAM, "tile %d" % i)
		var q := ME + E * i
		assert_eq(w.gas_heat[q], mini(Gas.MAX, Grid.cheb(q, w.player().pos) - 1), "heat %d" % i)
	assert_false(w.gas.has(w.player().pos), "she lands clear of it")
	assert_false(w.gas.has(w.player().pos - E), "and the tile before it")
	assert_eq(w.gas.size(), spell.leap() - 1, "and none beside the line")


func test_a_leap_stopped_short_vents_only_along_the_way_it_flew() -> void:
	var w := _world()
	w.set_tile(ME + E * 3, World.WALL)
	Leap.cast(w, w.player(), Spell.make(LEAP), E)
	assert_eq(w.player().pos, ME + E * 2)
	assert_eq(w.gas.size(), 1)
	assert_true(w.gas.has(ME))


func test_a_creatures_leap_vents_the_same_trail() -> void:
	var w := _world()
	var at := ME + E * 12
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	var spell := Spell.make(Bestiary.LEAP)
	Leap.cast(w, a, spell, -E)
	assert_eq(a.pos, at - E * spell.leap())
	for i in spell.leap() - 1:
		assert_eq(w.gas.get(at - E * i), STEAM, str(i))
	assert_false(w.gas.has(a.pos))
	assert_false(w.gas.has(a.pos + E))


func test_a_creature_the_leap_flew_over_is_scalded_by_the_trail() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"jangseung", ME + E * 2)
	foe.magic.cooldown = 99
	var hp := foe.hp
	w.act(_cast(LEAP + [Cards.WOOD]))
	assert_eq(foe.hp, hp - Gas.of(Gas.STEAM, "harm"))


func test_the_forecast_of_a_leap_equals_the_round() -> void:
	for wood in 3:
		var w := _world()
		var cards := LEAP.duplicate()
		for n in wood:
			cards.append(Cards.WOOD)
		var f := Forecast.of(w, _cast(cards))
		var hp := w.player().hp
		w.act(_cast(cards))
		assert_eq(f.after.gas, w.gas, "wood %d" % wood)
		assert_eq(f.after.player().pos, w.player().pos)
		assert_eq(f.harm.get(w.player().id, 0), hp - w.player().hp)
		assert_eq(f.after.rng.state, w.rng.state)


func test_she_lands_unscalded_however_the_steam_spreads() -> void:
	for s in 30:
		var w := _world()
		w.rng.seed = s
		var hp := w.player().hp
		w.act(_cast(LEAP + [Cards.WOOD]))
		assert_eq(w.player().hp, hp, "seed %d" % s)
