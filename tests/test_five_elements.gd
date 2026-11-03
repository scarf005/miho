extends GutTest
## A creature's immunity follows its five elements: each of its elements is immune to the
## one it beats and weak to the one that beats it (Cards.BEATS), immune winning. Every case
## goes through the real strike, spray and round.

const ORB := Cards.ORB
const FOX := Cards.FOX
const FIRE := Cards.FIRE
const WATER := Cards.WATER
const EARTH := Cards.EARTH
const METAL := Cards.METAL
const WOOD := Cards.WOOD
const E := Vector2i(1, 0)
const ME := Vector2i(4, 8)
const FOE := Vector2i(7, 8)
## Far enough from Miho that a round's fire cannot reach her.
const AWAY := Vector2i(30, 8)
const FIRE_KINDS := [&"bulgae", &"bujigaengi", &"samjogo", &"gangcheori"]


## An open hall, Miho at ME with tails to spare.
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
	w.depth = 2
	w.tails = 20
	w.cards.assign(Cards.ALL)
	return w


## A creature that neither moves nor casts, with health to spare.
func _foe(w: World, kind: StringName, at := FOE) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.magic.cooldown = 99
	a.ailments.rooted = 99
	a.max_hp = 40
	a.hp = 40
	return a


func _cast(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = E}]}


func _of(events: Array, t: StringName, id: int) -> Array:
	return events.filter(func(e): return e.t == t and e.get("id", -1) == id)


## What `cards`, hurled at one creature of `kind`, do to it: the harm of its first
## `hurt`, whether it stopped them whole and whether it told it took part of them.
func _struck(kind: StringName, cards: Array) -> Dictionary:
	var w := _world()
	var foe := _foe(w, kind)
	var events := w.act(_cast(cards))
	var hurts := _of(events, &"hurt", foe.id)
	return {
		harm = 0 if hurts.is_empty() else hurts[0].n,
		stopped = not _of(events, &"absorb", foe.id).is_empty(),
		resisted = not _of(events, &"resist", foe.id).is_empty(),
	}


## Harm of the same cards on a creature with no element, for the numbers to compare with.
func _plain(cards: Array) -> int:
	return _struck(&"dokkaebi", cards).harm


func _assert_stopped(kind: StringName, cards: Array) -> void:
	var got := _struck(kind, cards)
	assert_true(got.stopped, "%s stops %s" % [kind, cards])
	assert_eq(got.harm, 0, "%s takes nothing from %s" % [kind, cards])


func test_a_water_creature_stops_fire_and_is_weak_to_earth() -> void:
	_assert_stopped(&"haetae", [ORB, FIRE])
	_assert_stopped(&"haetae", [FOX, FIRE])
	var earth := _struck(&"haetae", [ORB, ORB, EARTH])
	assert_false(earth.stopped)
	assert_eq(earth.harm, _plain([ORB, ORB, EARTH]) * Elements.WEAK)


func test_an_earth_creature_stops_water_and_is_weak_to_wood() -> void:
	_assert_stopped(&"dueoksini", [ORB, WATER])
	_assert_stopped(&"dueoksini", [FOX, WATER])
	var wood := _struck(&"dueoksini", [ORB, ORB, WOOD])
	assert_eq(wood.harm, _plain([ORB, ORB, WOOD]) * Elements.WEAK)


func test_a_stopped_water_orb_does_not_push_an_earth_creature() -> void:
	var pushed := {}
	for kind in [&"dokkaebi", &"dueoksini"]:
		var w := _world()
		var foe := _foe(w, kind)
		foe.ailments.rooted = 0
		foe.ailments.stunned = 99
		w.act(_cast([ORB, WATER]))
		pushed[kind] = foe.pos != FOE
	assert_true(pushed[&"dokkaebi"], "the same orb pushes a creature of no element")
	assert_false(pushed[&"dueoksini"])


func test_a_water_spray_reaches_but_does_nothing_to_an_earth_creature() -> void:
	var w := _world()
	var foe := _foe(w, &"dueoksini", ME + E * 2)
	foe.ailments.rooted = 0
	foe.ailments.stunned = 99
	var events := w.act(_cast([WATER]))
	assert_false(_of(events, &"absorb", foe.id).is_empty())
	assert_eq(foe.pos, ME + E * 2, "not pushed")


func test_a_wood_creature_stops_earth_and_a_metal_one_stops_wood() -> void:
	_assert_stopped(&"cheonha", [ORB, EARTH])
	_assert_stopped(&"jiha", [ORB, WOOD])


func test_a_fire_creature_stops_metal_and_is_weak_to_water() -> void:
	for kind in FIRE_KINDS:
		_assert_stopped(kind, [FOX, METAL])
		var water := _struck(kind, [ORB, ORB, WATER])
		assert_eq(water.harm, _plain([ORB, ORB, WATER]) * Elements.WEAK, kind)


func test_a_fire_spell_hits_a_fire_creature() -> void:
	for kind in [&"bulgae", &"bujigaengi", &"samjogo"]:
		var got := _struck(kind, [ORB, ORB, FIRE])
		assert_false(got.stopped, kind)
		assert_false(got.resisted, kind)
		assert_eq(got.harm, _plain([ORB, ORB, FIRE]), kind)


## Rounds of `kind` standing on a tile that burns, away from Miho: the harm it took.
func _burnt(kind: StringName) -> int:
	var w := _world()
	var foe := _foe(w, kind, AWAY)
	w.tiles[Grid.index(AWAY)] = World.GRASS
	Terrain.ignite(w, AWAY)
	var start := foe.hp
	for i in 2:
		w.act({t = &"wait"})
	return start - foe.hp


func test_what_is_immune_to_fire_or_is_of_fire_takes_no_harm_from_a_burning_tile() -> void:
	for kind in FIRE_KINDS + [&"haetae", &"cheonnyeon", Forge.FURNACE]:
		assert_eq(_burnt(kind), 0, kind)


func test_other_creatures_burn_on_a_burning_tile() -> void:
	for kind in [&"dokkaebi", &"dueoksini", &"jiha", &"bulgasari"]:
		assert_gt(_burnt(kind), 0, kind)


func test_a_fire_creature_is_not_set_alight_and_does_not_burn() -> void:
	var w := _world()
	var foe := _foe(w, &"bulgae")
	w.act(_cast([FOX, FIRE]))
	assert_eq(foe.ailments.alight, 0)
	var after := _of(w.act({t = &"wait"}), &"burn", foe.id)
	assert_true(after.is_empty(), "nothing burns it the round after")


func test_a_mixed_fire_spell_does_not_set_a_water_creature_alight() -> void:
	var w := _world()
	var foe := _foe(w, &"haetae")
	w.act(_cast([FOX, FIRE, METAL]))
	assert_eq(foe.ailments.alight, 0)


func test_fire_still_dries_a_wet_fire_creature() -> void:
	var w := _world()
	var foe := _foe(w, &"bulgae")
	foe.ailments.wet = Status.WET
	Status.ignite(w, foe)
	assert_eq(foe.ailments.wet, 0)


func test_a_plain_creature_is_still_set_alight() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi")
	w.act(_cast([FOX, FIRE]))
	assert_gt(foe.ailments.alight, 0)


func test_a_fire_creature_crosses_hot_iron_unharmed_and_an_earth_one_does_not() -> void:
	var w := _world()
	var dog := _foe(w, &"bulgae", AWAY)
	var earth := _foe(w, &"dueoksini", AWAY + Vector2i(0, 2))
	w.hot[dog.pos] = Vector2i(Compounds.MOLTEN, 3)
	w.hot[earth.pos] = Vector2i(Compounds.MOLTEN, 3)
	var dog_hp := dog.hp
	var earth_hp := earth.hp
	w.act({t = &"wait"})
	assert_eq(dog.hp, dog_hp)
	assert_lt(earth.hp, earth_hp)


func test_the_great_serpent_is_immune_where_weak_and_immune_overlap() -> void:
	var boss := &"cheonnyeon"
	_assert_stopped(boss, [ORB, FIRE])
	_assert_stopped(boss, [FOX, METAL])
	_assert_stopped(boss, [ORB, WOOD])
	_assert_stopped(boss, [ORB, FIRE, METAL])
	for c in [WATER, EARTH]:
		var got := _struck(boss, [ORB, ORB, c])
		assert_eq(got.harm, _plain([ORB, ORB, c]) * Elements.WEAK, c)
		assert_false(got.resisted, c)


func test_weak_and_immune_in_one_spell_harm_as_they_are() -> void:
	var got := _struck(&"cheonnyeon", [ORB, ORB, WATER, FIRE])
	assert_true(got.resisted)
	assert_eq(got.harm, _plain([ORB, ORB, WATER, FIRE]))


func test_a_spell_with_an_immune_element_and_another_is_halved() -> void:
	var mixed := [ORB, ORB, WATER, METAL]
	var got := _struck(&"dueoksini", mixed)
	assert_true(got.resisted)
	assert_false(got.stopped)
	assert_gt(_plain(mixed), 1)
	assert_eq(got.harm, _plain(mixed) / Elements.HALF)


func test_an_orb_blast_is_stopped_by_a_neighbour_immune_to_all_of_it() -> void:
	var w := _world()
	_foe(w, &"dokkaebi")
	var side := _foe(w, &"haetae", FOE + Vector2i(0, 1))
	var events := w.act(_cast([ORB, ORB, FIRE]))
	assert_true(_of(events, &"hurt", side.id).is_empty())
	assert_false(_of(events, &"absorb", side.id).is_empty())


func test_the_starfish_keeps_its_rule_and_halves_water_mixed_with_fire() -> void:
	var kind := &"bulgasari"
	_assert_stopped(kind, [ORB, METAL])
	_assert_stopped(kind, [ORB, WATER])
	_assert_stopped(kind, [ORB, ORB])
	var fire := _struck(kind, [ORB, ORB, FIRE])
	assert_eq(fire.harm, _plain([ORB, ORB, FIRE]))
	var steam := _struck(kind, [ORB, ORB, ORB, FIRE, WATER])
	assert_true(steam.resisted)
	assert_eq(steam.harm, _plain([ORB, ORB, ORB, FIRE, WATER]) / Elements.HALF)
	var wood := _struck(kind, [ORB, ORB, FIRE, WOOD])
	assert_eq(wood.harm, _plain([ORB, ORB, FIRE, WOOD]) * Elements.WEAK)


func test_the_starfish_still_grows_on_metal_and_nothing_else_does() -> void:
	var w := _world()
	var foe := _foe(w, &"bulgasari")
	var hp := foe.max_hp
	w.act(_cast([ORB, METAL]))
	assert_eq(foe.max_hp, hp + Bestiary.GROWTH)
	var x := _world()
	var dog := _foe(x, &"bulgae")
	hp = dog.max_hp
	x.act(_cast([FOX, METAL]))
	assert_eq(dog.max_hp, hp)


func _flame(w: World) -> void:
	w.player().buffs.flame = true


func test_her_fire_gets_through_every_creature_immune_to_fire_for_one_at_most() -> void:
	for kind in [&"haetae", &"cheonnyeon", &"eodeopsini"]:
		var w := _world()
		_flame(w)
		var foe := _foe(w, kind)
		var events := w.act(_cast([ORB, ORB, ORB, FIRE, FIRE]))
		assert_true(_of(events, &"absorb", foe.id).is_empty(), kind)
		assert_eq(_of(events, &"hurt", foe.id)[0].n, Guise.FLAME_THROUGH, kind)
		assert_eq(foe.ailments.alight, 0, kind)


func test_her_fire_hits_a_fire_creature_as_it_is() -> void:
	var w := _world()
	_flame(w)
	var foe := _foe(w, &"bulgae")
	var cards := [ORB, ORB, ORB, FIRE, FIRE]
	assert_eq(_of(w.act(_cast(cards)), &"hurt", foe.id)[0].n, _plain(cards))


## What a shot of `cards` from a creature, striking Miho as 불여우 for 2, harms her.
func _thrown_at_her(cards: Array) -> int:
	var w := _world()
	_flame(w)
	var foe := _foe(w, &"dokkaebi")
	var hp := w.player().hp
	Elements.strike(w, Flight.spawn(w, foe, Spell.make(cards), -E, -1), w.player(), 2)
	return hp - w.player().hp


func test_as_a_flame_fox_she_keeps_her_fire_immunity_and_follows_the_fire_rule() -> void:
	assert_eq(_thrown_at_her([FOX, FIRE]), 0, "fire")
	assert_eq(_thrown_at_her([FOX, METAL]), 0, "the metal a fire creature is immune to")
	assert_eq(_thrown_at_her([FOX, WATER]), 2 * Elements.WEAK, "water")
	assert_eq(_thrown_at_her([FOX, EARTH]), 2, "earth")


func test_as_a_flame_fox_she_does_not_burn_on_a_burning_tile() -> void:
	var w := _world()
	_flame(w)
	w.tiles[Grid.index(ME)] = World.GRASS
	Terrain.ignite(w, ME)
	var hp := w.player().hp
	w.act({t = &"wait"})
	w.act({t = &"wait"})
	assert_eq(w.player().hp, hp)


func test_a_creature_passes_over_what_its_rival_stops_whole() -> void:
	var w := _world()
	var caster := _foe(w, &"cheonha", ME + E * 3)
	caster.rank = Bestiary.PICKS
	var rival := _foe(w, &"jiha", ME + E * 5)
	assert_true(Aim.at(w, caster, rival).is_empty(), "wood at a creature of metal")
	rival.pos = AWAY
	var plain := _foe(w, &"dokkaebi", ME + E * 5)
	assert_false(Aim.at(w, caster, plain).is_empty(), "wood at a creature of no element")


func test_the_talon_counts_a_fire_creature_as_immune_to_metal() -> void:
	var w := _world()
	w.player().buffs.talon = true
	var dog := _foe(w, &"bulgae", ME + E)
	var plain := _foe(w, &"dokkaebi", ME - E)
	assert_eq(Guise.talon_harm(w.player(), dog), Guise.TALON_ABSORBED)
	assert_eq(Guise.talon_harm(w.player(), plain), Guise.TALON_HARM)


func test_electricity_keeps_its_own_rule() -> void:
	var w := _world()
	var water := _foe(w, &"haetae")
	var events := w.act(_cast(Cards.recipe(&"thunder")))
	assert_eq(_of(events, &"hurt", water.id)[0].n, Compounds.THUNDER * Elements.WEAK)


## The lines of the hover of a creature of `kind`.
func _hover(kind: StringName) -> PackedStringArray:
	var w := World.create(7)
	return Info.plain(Info.creature(w, FloorGen.spawn(w, kind, w.player().pos + E))).split("\n")


func _told(kind: StringName, word: String) -> Array:
	return Array(_hover(kind)).filter(func(l): return l.begins_with(word))


func test_the_hover_tells_each_creature_s_immunity_by_its_elements() -> void:
	assert_eq(_told(&"haetae", "면역"), ["면역: 불"])
	assert_eq(_told(&"haetae", "내성"), ["내성: 불이 섞인 주문"])
	assert_eq(_told(&"dueoksini", "면역"), ["면역: 물, 전기"])
	assert_eq(_told(&"dueoksini", "내성"), ["내성: 물이 섞인 주문"])
	assert_eq(_told(&"bulgae", "면역"), ["면역: 쇠"])
	assert_eq(_told(&"bulgae", "내성"), ["내성: 쇠가 섞인 주문"])
	assert_eq(_told(&"cheonnyeon", "면역"), ["면역: 불, 나무, 쇠"])
	assert_eq(_told(&"cheonnyeon", "내성"), ["내성: 불, 나무, 쇠가 섞인 주문"])
	assert_eq(_told(&"cheonnyeon", "약점"), ["약점: 물, 흙, 전기"])


func test_the_starfish_tells_its_own_immunity_and_what_it_halves() -> void:
	assert_eq(_told(&"bulgasari", "면역"), ["면역: 불 없는 주문"])
	assert_eq(_told(&"bulgasari", "내성"), ["내성: 물이 섞인 주문"])


func test_only_a_fire_creature_tells_it_does_not_burn() -> void:
	var tag := "불에 타지 않음"
	assert_true("\n".join(_hover(&"bulgae")).contains(tag))
	assert_false("\n".join(_hover(&"haetae")).contains(tag), "면역: 불 says it")
	assert_false("\n".join(_hover(&"cheonnyeon")).contains(tag), "면역: 불 says it")
	assert_false("\n".join(_hover(&"dokkaebi")).contains(tag))


func test_a_creature_with_no_element_tells_no_immunity_of_one() -> void:
	assert_eq(_told(&"dokkaebi", "면역"), [])
	assert_eq(_told(&"dokkaebi", "내성"), [])
