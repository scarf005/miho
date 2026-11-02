extends GutTest
## A spell meets a creature by its elements (Spell.nature): all of them
## absorbed stops it whole; some of them halve its harm and keep its effects;
## an element beating the creature's doubles the harm, never more than twice.
## 전기 (벼락) follows the creature's elements and wetness instead.

const ORB := Cards.ORB
const FIRE := Cards.FIRE
const E := Vector2i(1, 0)
const FOE := Vector2i(7, 8)
const LAVA := [ORB, FIRE, Cards.EARTH]
const LAVA_TWICE := [ORB, ORB, FIRE, Cards.EARTH]
## A creature of fire: it absorbs fire. A creature of water: it also absorbs fire,
## and is weak to earth.
const FIRE_EATER := &"bulgae"
const WATER_EATER := &"haetae"


## An open hall, Miho at (4, 8) with tails to spare.
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
	w.depth = 2
	w.tails = 20
	w.cards.assign(Cards.ALL)
	return w


## A creature that neither moves nor casts, with health to spare.
func _foe(w: World, kind: StringName, at := FOE) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	a.max_hp = 20
	a.hp = 20
	return a


func _cast(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = E}]}


func _of(events: Array, t: StringName, id := -1) -> Array:
	return events.filter(func(e): return e.t == t and (id < 0 or e.get("id", -1) == id))


## The harm of the round's first `hurt` of creature `id`, before hot ground and gas.
func _first(events: Array, id: int) -> int:
	return _of(events, &"hurt", id)[0].n


func test_lava_on_a_fire_absorber_is_halved_and_still_leaves_hot_ground() -> void:
	var w := _world()
	var foe := _foe(w, FIRE_EATER)
	assert_eq(Spell.make(LAVA_TWICE).damage(3), 2, "the harm before it is halved")
	var events := w.act(_cast(LAVA_TWICE))
	assert_eq(_first(events, foe.id), 1)
	assert_false(_of(events, &"resist", foe.id).is_empty(), "the log tells it was held back")
	assert_false(w.hot.is_empty(), "the hot ground is laid")


func test_a_lone_fire_on_a_fire_absorber_is_stopped_with_no_effect() -> void:
	var beside := FOE + Vector2i(0, 1)
	var control := _world()
	control.tiles[Grid.index(beside)] = World.GRASS
	_foe(control, &"dokkaebi")
	control.act(_cast([ORB, FIRE]))
	assert_false(control.burning.is_empty(), "the same fire's blast sets the grass alight")
	var w := _world()
	w.tiles[Grid.index(beside)] = World.GRASS
	var foe := _foe(w, FIRE_EATER)
	var events := w.act(_cast([ORB, FIRE]))
	assert_false(_of(events, &"absorb", foe.id).is_empty())
	assert_true(_of(events, &"hurt", foe.id).is_empty())
	assert_true(_of(events, &"resist").is_empty())
	assert_true(w.burning.is_empty())


func test_a_harm_of_one_partly_absorbed_is_nothing_and_the_effect_applies() -> void:
	var w := _world()
	var foe := _foe(w, FIRE_EATER)
	assert_eq(Spell.make(LAVA).damage(3), 1)
	var events := w.act(_cast(LAVA))
	assert_true(_of(events, &"hurt", foe.id).is_empty())
	assert_false(_of(events, &"resist", foe.id).is_empty())
	assert_false(w.hot.is_empty())


func test_a_weak_element_doubles_the_harm_though_the_spell_has_another() -> void:
	var w := _world()
	var foe := _foe(w, WATER_EATER)
	var mud := [ORB, Cards.EARTH, Cards.WATER]
	assert_true(Spell.make(mud).nature().has(Cards.WATER), "water does not beat water")
	assert_eq(_first(w.act(_cast(mud)), foe.id), Elements.WEAK)


func test_weak_and_partly_absorbed_deals_the_harm_as_it_is() -> void:
	var w := _world()
	var foe := _foe(w, WATER_EATER)
	assert_eq(_first(w.act(_cast([ORB, ORB, Cards.EARTH])), foe.id), 2 * Elements.WEAK)
	var lava := _world()
	var guard := _foe(lava, WATER_EATER)
	var events := lava.act(_cast(LAVA_TWICE))
	assert_eq(_first(events, guard.id), 2, "doubled, then halved")
	assert_false(_of(events, &"resist", guard.id).is_empty())


func test_two_weak_elements_still_deal_twice_the_harm() -> void:
	var w := _world()
	var foe := _foe(w, &"cheonnyeon")
	var steam := Spell.make([ORB, Cards.WATER, FIRE])
	assert_eq(Bestiary.weak_to(foe.kind).filter(func(e): return steam.nature().has(e)).size(), 2)
	assert_eq(_first(w.act(_cast([ORB, Cards.WATER, FIRE])), foe.id), Elements.WEAK)


func test_the_forecast_shows_the_halved_harm() -> void:
	var w := _world()
	var foe := _foe(w, FIRE_EATER)
	w.tiles[Grid.index(FOE + Vector2i(0, 2))] = World.LANTERN
	w.sense()
	assert_eq(Forecast.of(w, _cast(LAVA_TWICE)).harm.get(foe.id), 1)
	assert_eq(_first(w.act(_cast(LAVA_TWICE)), foe.id), 1)


func test_an_orb_blast_halves_what_a_neighbour_absorbs_in_part() -> void:
	var w := _world()
	var centre := _foe(w, &"dokkaebi")
	var side := _foe(w, FIRE_EATER, FOE + Vector2i(0, 1))
	var cards := [ORB, FIRE, FIRE, FIRE, Cards.METAL]
	var spell := Spell.make(cards)
	var blast := spell.blast(spell.damage(3))
	assert_gt(blast, 1)
	var events := w.act(_cast(cards))
	assert_false(_of(events, &"hurt", centre.id).is_empty())
	assert_eq(_first(events, side.id), blast / 2)
	assert_false(_of(events, &"resist", side.id).is_empty())


func test_a_blast_is_stopped_whole_by_a_neighbour_that_absorbs_all_of_it() -> void:
	var w := _world()
	_foe(w, &"dokkaebi")
	var side := _foe(w, FIRE_EATER, FOE + Vector2i(0, 1))
	var events := w.act(_cast([ORB, FIRE]))
	assert_true(_of(events, &"hurt", side.id).is_empty())
	assert_false(_of(events, &"absorb", side.id).is_empty())


func test_a_spell_with_no_element_is_not_weak_hit_and_a_starfish_stops_it() -> void:
	var w := _world()
	var foe := _foe(w, &"bulgasari")
	var sleep := Spell.make(Cards.recipe(&"hypnosis"))
	assert_true(sleep.nature().is_empty())
	assert_false(Bestiary.weak(foe.kind, sleep))
	assert_true(Bestiary.absorbs(foe.kind, sleep))
	assert_false(Bestiary.absorbs(FIRE_EATER, sleep))
	assert_false(Bestiary.absorbs(foe.kind, Spell.make([Cards.FOX, FIRE, Cards.METAL])))


## The events of 벼락 cast at one creature of `kind`, wet or not.
func _zap(kind: StringName, wet := false) -> Dictionary:
	var w := _world()
	var foe := _foe(w, kind)
	foe.wet = Status.WET if wet else 0
	var events := w.act(_cast(Cards.recipe(&"thunder")))
	var hurts := _of(events, &"hurt", foe.id)
	return {
		harm = 0 if hurts.is_empty() else hurts[0].n,
		stunned = not _of(events, &"stun", foe.id).is_empty(),
		stopped = not _of(events, &"absorb", foe.id).is_empty(),
	}


func test_electricity_hurts_a_creature_without_elements_as_it_is_and_stuns_it() -> void:
	var got := _zap(&"dokkaebi")
	assert_eq(got.harm, Compounds.THUNDER)
	assert_true(got.stunned)


func test_electricity_hurts_a_creature_of_metal_or_water_twice() -> void:
	for kind in [&"jiha", &"haetae", &"gangcheori"]:
		var got := _zap(kind)
		assert_eq(got.harm, Compounds.THUNDER * Elements.WEAK, kind)
		assert_true(got.stunned, kind)


func test_electricity_does_nothing_to_a_dry_creature_of_wood_earth_or_fire() -> void:
	for kind in [&"cheonha", &"dueoksini", &"bujigaengi"]:
		var got := _zap(kind)
		assert_eq(got.harm, 0, kind)
		assert_false(got.stunned, kind)


func test_electricity_is_never_absorbed() -> void:
	for kind in [FIRE_EATER, WATER_EATER, &"bulgasari"]:
		assert_false(_zap(kind).stopped, kind)
	assert_true(_zap(&"bulgasari", true).stunned, "a wet starfish is shocked, not stopped")


func test_electricity_hurts_a_wet_creature_twice_also_when_it_would_be_immune() -> void:
	for kind in [&"dokkaebi", &"cheonha", &"bulgae", &"dueoksini", &"jiha"]:
		var got := _zap(kind, true)
		assert_eq(got.harm, Compounds.THUNDER * Elements.WEAK, kind)
		assert_true(got.stunned, kind)
