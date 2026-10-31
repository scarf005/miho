extends GutTest
## 상극: a spell holding an element that beats one of a creature's elements hits
## it twice as hard. Wood creatures catch fire when a fire spell hits them.

const ORB := Cards.ORB
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const FOE := Vector2i(7, 8)


## An open hall, Miho at (4, 8) holding every element.
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
	w.depth = 4
	w.tails = 4
	w.cards.assign(Cards.ALL)
	return w


func _foe(w: World, kind: StringName, at := FOE) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


func _cast(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = E}]}


func _hurts(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"hurt")


## Each beating pair: [victim, the element that beats it, spell cards].
## Fire is added where the victim only takes fire (불가사리) or eats it (해태, 불개).
func test_each_sangkeuk_pair_doubles_an_orb_hit() -> void:
	for pair in [
		[&"bulgasari", Cards.WOOD, [ORB, Cards.WOOD, Cards.FIRE]],
		[&"haetae", Cards.EARTH, [ORB, Cards.EARTH]],
		[&"bulgae", Cards.WATER, [ORB, Cards.WATER]],
		[&"jiha", Cards.FIRE, [ORB, Cards.FIRE]],
		[&"cheonha", Cards.METAL, [ORB, Cards.METAL]],
	]:
		var w := _world()
		var foe := _foe(w, pair[0])
		assert_has(Bestiary.weak_to(pair[0]), pair[1], pair[0])
		foe.hp = 9
		var hurts := _hurts(w.act(_cast(pair[2])))
		var n := 2 * Spell.make(pair[2]).damage(0)
		assert_eq(hurts.size(), 1, pair[0])
		assert_eq(hurts[0].n, n, "%s takes double from %s" % [pair[0], pair[1]])
		assert_true(hurts[0].weak, pair[0])
		assert_eq(foe.hp, 9 - n, pair[0])


func test_elements_that_do_not_beat_it_deal_the_plain_harm() -> void:
	var w := _world()
	var foe := _foe(w, &"cheonha")
	var hurts := _hurts(w.act(_cast([ORB, Cards.WATER])))
	assert_eq(hurts[0].n, 1)
	assert_false(hurts[0].weak)
	assert_eq(foe.hp, 3)
	var other := _world()
	var jiha := _foe(other, &"jiha")
	jiha.hp = 9
	var cannon := Spell.make([ORB, Cards.METAL]).damage(0)
	assert_eq(
		_hurts(other.act(_cast([ORB, Cards.METAL])))[0].n, cannon, "metal does not beat metal"
	)
	assert_eq(jiha.hp, 9 - cannon)


func test_weakness_follows_the_beats_table_both_ways() -> void:
	assert_eq(Bestiary.weak_to(&"cheonha"), [Cards.METAL] as Array[StringName])
	assert_eq(Bestiary.weak_to(&"haetae"), [Cards.EARTH] as Array[StringName])
	assert_eq(Bestiary.weak_to(&"dokkaebi"), [] as Array[StringName])
	assert_eq(Bestiary.weak_to(&"miho"), [] as Array[StringName])
	assert_eq(
		Bestiary.weak_to(&"cheonnyeon"),
		[Cards.FIRE, Cards.WATER, Cards.EARTH] as Array[StringName],
		"one weakness per element it holds"
	)


func test_a_bullet_beats_wood_for_twice_its_harm() -> void:
	var w := _world()
	var foe := _foe(w, &"cheonha")
	foe.hp = 9
	var hurts := _hurts(w.act(_cast([Cards.FOX, Cards.METAL])))
	assert_eq(hurts.map(func(e): return e.n), [2 * Elements.BULLET])
	assert_eq(foe.hp, 9 - 2 * Elements.BULLET)


func test_a_fire_wisp_beats_metal_for_two() -> void:
	var w := _world()
	var foe := _foe(w, &"jiha")
	foe.hp = 9
	assert_eq(_hurts(w.act(_cast([Cards.FOX, Cards.FIRE])))[0].n, 2)
	assert_eq(foe.hp, 9 - 2 - World.FIRE_DAMAGE, "and it burns, unweakened")


func test_immunity_comes_first_and_the_weakness_does_not_break_it() -> void:
	var w := _world()
	var foe := _foe(w, &"haetae")
	var types := w.act(_cast([ORB, Cards.EARTH, Cards.FIRE])).map(func(e): return e.t)
	assert_has(types, &"absorb")
	assert_does_not_have(types, &"hurt")
	assert_eq(foe.hp, 4)
	var starfish := _world()
	var s := _foe(starfish, &"bulgasari")
	var plain := starfish.act(_cast([ORB, Cards.WOOD])).map(func(e): return e.t)
	assert_has(plain, &"absorb")
	assert_eq(s.hp, 3, "불로만 피해 still eats a spell without fire")


func test_a_fire_orb_splash_doubles_on_a_weak_neighbour() -> void:
	var w := _world()
	var front := _foe(w, &"dokkaebi")
	var side := _foe(w, &"jiha", FOE + Vector2i(0, 1))
	side.hp = 12
	_hurts(w.act(_cast([ORB, Cards.FIRE])))
	assert_eq(front.hp, 1)
	assert_eq(side.hp, 12 - 2 * World.FIRE_DAMAGE, "splash doubled")


func test_a_weak_creature_hit_by_another_creatures_spell_takes_double() -> void:
	var w := _world()
	var caster := _foe(w, &"imugi", Vector2i(12, 8))
	var victim := _foe(w, &"cheonha", Vector2i(9, 8))
	victim.hp = 9
	var shot := Shot.new()
	shot.id = w.new_id()
	shot.faction = Actor.HEAVEN
	shot.caster = caster.id
	shot.spell = Spell.make([ORB, Cards.METAL])
	shot.origin = Vector2i(12, 8)
	shot.pos = Vector2i(10, 8)
	shot.dir = Vector2i(-1, 0)
	w.shots.append(shot)
	var hurts := _hurts(w.act(WAIT))
	assert_eq(hurts.size(), 1)
	assert_eq(hurts[0].n, 2 * (1 + Elements.CANNON))
	assert_eq(victim.hp, 9 - 2 * (1 + Elements.CANNON))


func test_a_fire_spell_sets_a_wood_creatures_tile_burning_and_does_not_double() -> void:
	var w := _world()
	var foe := _foe(w, &"cheonha")
	foe.hp = 12
	assert_false(w.burning.has(FOE))
	var events := w.act(_cast([ORB, Cards.FIRE]))
	assert_eq(_hurts(events)[0].n, 1, "fire does not beat wood")
	assert_true(w.burning.has(FOE), "the tile it stands on burns")
	assert_has(events.map(func(e): return e.t), &"ignite")
	assert_eq(w.tile(FOE), World.FLOOR)
	var before := foe.hp
	w.act(WAIT)
	assert_eq(foe.hp, before - World.FIRE_DAMAGE, "standing in the flames hurts it")


func test_a_fire_wisp_also_lights_a_wood_creature() -> void:
	var w := _world()
	_foe(w, &"cheonha")
	w.act(_cast([Cards.FOX, Cards.FIRE]))
	assert_true(w.burning.has(FOE))


func test_fire_splash_lights_a_wood_creature_next_to_the_blast() -> void:
	var w := _world()
	_foe(w, &"dokkaebi")
	var wood := _foe(w, &"cheonha", FOE + Vector2i(0, 1))
	w.act(_cast([ORB, Cards.FIRE]))
	assert_true(w.burning.has(wood.pos))


func test_fire_leaves_other_creatures_tiles_alone() -> void:
	var w := _world()
	_foe(w, &"jiha")
	w.act(_cast([ORB, Cards.FIRE]))
	assert_false(w.burning.has(FOE), "metal creatures do not burn")
	var wet := _world()
	_foe(wet, &"cheonha")
	wet.act(_cast([ORB, Cards.WATER]))
	assert_false(wet.burning.has(FOE), "no fire, no flames")


func test_a_creature_that_eats_fire_and_is_no_wood_does_not_burn() -> void:
	var w := _world()
	var foe := _foe(w, &"haetae")
	w.act(_cast([ORB, Cards.FIRE]))
	assert_false(w.burning.has(foe.pos), "water creatures are no wood")


func test_the_forecast_includes_the_doubled_harm() -> void:
	var w := _world()
	var foe := _foe(w, &"cheonha")
	w.tiles[Grid.index(FOE + Vector2i(0, 2))] = World.LANTERN
	w.sense()
	assert_eq(w.seen[Grid.index(FOE)], 1)
	var f := Forecast.of(w, _cast([ORB, Cards.METAL]))
	assert_eq(f.harm.get(foe.id), 2 * (1 + Elements.CANNON))
	var plain := Forecast.of(w, _cast([ORB, Cards.WATER]))
	assert_eq(plain.harm.get(foe.id), 1)


func test_the_starfish_eats_a_spell_with_metal_and_grows() -> void:
	var w := _world()
	var foe := _foe(w, &"bulgasari")
	var types := w.act(_cast([ORB, Cards.METAL])).map(func(e): return e.t)
	assert_has(types, &"absorb")
	assert_has(types, &"grow")
	assert_does_not_have(types, &"hurt")
	assert_eq([foe.hp, foe.max_hp], [3 + Bestiary.GROWTH, 3 + Bestiary.GROWTH])
	assert_does_not_have(types, &"push", "an eaten spell has no other effect")


func test_the_starfish_does_not_grow_on_a_spell_without_metal_or_with_fire() -> void:
	var w := _world()
	var foe := _foe(w, &"bulgasari")
	foe.rooted = 9
	var types := w.act(_cast([ORB, Cards.WOOD])).map(func(e): return e.t)
	assert_has(types, &"absorb")
	assert_does_not_have(types, &"grow")
	assert_eq([foe.hp, foe.max_hp], [3, 3])
	w.tails = 4
	var hurts := _hurts(w.act(_cast([ORB, Cards.METAL, Cards.FIRE])))
	assert_eq(hurts.size(), 2, "the orb, then the hot iron under it: fire hurts it")
	assert_eq(foe.max_hp, 3)


func test_the_forecast_shows_the_starfish_grown_and_unhurt() -> void:
	var w := _world()
	var foe := _foe(w, &"bulgasari", Vector2i(6, 8))
	w.sense()
	var f := Forecast.of(w, _cast([ORB, Cards.METAL]))
	assert_eq(f.harm, {})
	var after := f.after.actor(foe.id)
	assert_eq([after.hp, after.max_hp], [3 + Bestiary.GROWTH, 3 + Bestiary.GROWTH])
	assert_eq([foe.hp, foe.max_hp], [3, 3], "the real creature is untouched")
	w.act(_cast([ORB, Cards.METAL]))
	assert_eq(foe.hp, after.hp, "the forecast was exact")
