extends GutTest
## Guns that grow with the elements added: a shotgun a tile wider for every 쇠,
## the armour-piercing wisp (여 with two 쇠), the 비격진 (구 with 유탄), and a
## 상생 pair a tile bigger for every lone element that feeds it.

const FOX := Cards.FOX
const ORB := Cards.ORB
const FIRE := Cards.FIRE
const WOOD := Cards.WOOD
const METAL := Cards.METAL
const EARTH := Cards.EARTH
const E := Vector2i(1, 0)
const ME := Vector2i(20, 12)
const HEALTH := 30


## An open hall walled at the edges, lit by lanterns two rows above Miho, who
## stands at ME with tails to spare.
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
	me.hp = HEALTH
	me.max_hp = HEALTH
	me.pos = ME
	w.actors.append(me)
	w.depth = 5
	w.tails = 20
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _put(w: World, x: int, y: int, t: int) -> void:
	w.tiles[Grid.index(ME + Vector2i(x, y))] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts, `x` east and `y` south of Miho.
func _post(w: World, x: int, y := 0) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", ME + Vector2i(x, y))
	a.magic.cooldown = 99
	a.hp = HEALTH
	a.max_hp = HEALTH
	w.sense()
	return a


## `k` copies of talisman c.
func _n(c: StringName, k: int) -> Array:
	var out := []
	for i in k:
		out.append(c)
	return out


func _hurts(events: Array, a: Actor) -> Array:
	return events.filter(func(e): return e.t == &"hurt" and e.id == a.id).map(func(e): return e.n)


func test_a_shotgun_reaches_one_tile_farther_for_every_more_metal() -> void:
	for copies in range(2, 6):
		var w := _world()
		var in_reach := _post(w, copies + 1, 0)
		var past := _post(w, copies + 2, 0)
		w.act(_cast(_n(METAL, copies)))
		assert_eq(in_reach.hp, HEALTH - 1, "%d copies hit radius %d" % [copies, copies + 1])
		assert_eq(past.hp, HEALTH, "%d copies stop at radius %d" % [copies, copies + 1])


func test_a_shotgun_hits_harder_next_to_the_caster_however_much_metal() -> void:
	var w := _world()
	var close := _post(w, 1, 1)
	var far := _post(w, 4, 0)
	w.act(_cast(_n(METAL, 4)))
	assert_eq(close.hp, HEALTH - 2)
	assert_eq(far.hp, HEALTH - 1)


func test_a_piercing_wisp_hurts_each_creature_in_its_line_once_and_goes_through_one_wall() -> void:
	var w := _world()
	var a := _post(w, 2)
	var b := _post(w, 3)
	_put(w, 4, 0, World.WALL)
	var c := _post(w, 5)
	_put(w, 6, 0, World.WALL)
	var d := _post(w, 7)
	var events := w.act(_cast([FOX, METAL, METAL]))
	var harm := Elements.BULLET + 1
	for x in [a, b, c]:
		assert_eq(_hurts(events, x), [harm], "hurt once for the bullet and one more 쇠")
	assert_eq(d.hp, HEALTH, "the second wall stops it")
	assert_eq(w.tile(ME + Vector2i(4, 0)), World.WALL, "it goes through, it does not break")
	assert_eq(w.tile(ME + Vector2i(6, 0)), World.WALL)


func test_a_piercing_wisp_hurts_one_more_for_every_more_metal() -> void:
	var w := _world()
	var a := _post(w, 2)
	var b := _post(w, 3)
	var events := w.act(_cast([FOX, METAL, METAL, METAL]))
	assert_eq(_hurts(events, a), [Elements.BULLET + 2])
	assert_eq(_hurts(events, b), [Elements.BULLET + 2])


func test_a_bullet_stops_at_the_first_creature_and_a_wall() -> void:
	var w := _world()
	var a := _post(w, 2)
	var b := _post(w, 3)
	w.act(_cast([FOX, METAL]))
	assert_lt(a.hp, HEALTH)
	assert_eq(b.hp, HEALTH)
	var walled := _world()
	_put(walled, 2, 0, World.WALL)
	var behind := _post(walled, 3)
	walled.act(_cast([FOX, METAL]))
	assert_eq(behind.hp, HEALTH)


func test_a_piercing_wisp_stops_at_a_wall_with_a_wall_behind_it() -> void:
	var w := _world()
	_put(w, 2, 0, World.WALL)
	_put(w, 3, 0, World.WALL)
	var behind := _post(w, 4)
	w.act(_cast([FOX, METAL, METAL]))
	assert_eq(behind.hp, HEALTH)
	assert_false(w.shots.any(func(s): return s.pos.x > ME.x + 1), "it hovers short of the walls")


func test_a_piercing_wisp_fired_at_a_wall_beside_miho_goes_through_it() -> void:
	for dir: Vector2i in [E, Vector2i(1, -1)]:
		var w := _world()
		_put(w, dir.x, dir.y, World.WALL)
		var behind := _post(w, dir.x * 2, dir.y * 2)
		var cast := _cast([FOX, METAL, METAL], dir)
		assert_true(w.can(cast), str(dir))
		var events := w.act(cast)
		assert_eq(_hurts(events, behind), [Elements.BULLET + 1], str(dir))
		assert_eq(w.tile(ME + dir), World.WALL, "it goes through, it does not break")


func test_only_a_piercing_wisp_with_open_air_behind_the_wall_is_fired_at_a_wall_beside_miho(
) -> void:
	var w := _world()
	_put(w, 1, 0, World.WALL)
	assert_false(w.can(_cast([FOX])), "a wisp")
	assert_false(w.can(_cast([FOX, METAL])), "a bullet")
	_put(w, 2, 0, World.WALL)
	assert_false(w.can(_cast([FOX, METAL, METAL])), "a wall behind it")
	var edge := _world()
	edge.player().pos = Vector2i(ME.x, 1)
	assert_false(edge.can(_cast([FOX, METAL, METAL], Vector2i(0, -1))), "the map's edge behind it")


func test_the_preview_of_a_piercing_wisp_through_a_wall_beside_miho_equals_the_round() -> void:
	var w := _world()
	_put(w, 1, 0, World.WALL)
	_post(w, 2)
	w.sense()
	w.seen[Grid.index(ME + E * 2)] = 1
	var f := Forecast.of(w, _cast([FOX, METAL, METAL]))
	var events := w.act(_cast([FOX, METAL, METAL]))
	var harm := {}
	for e in events.filter(func(e): return e.t == &"hurt"):
		harm[e.id] = harm.get(e.id, 0) + e.n
	assert_eq(harm.size(), 1)
	assert_eq(f.harm, harm)
	assert_eq(f.after.shots.map(func(s): return s.pos), w.shots.map(func(s): return s.pos))


func test_a_piercing_wisp_stays_pierced_in_a_clone() -> void:
	var w := _world()
	_put(w, 3, 0, World.WALL)
	w.act(_cast([FOX, METAL, METAL]))
	assert_true(w.shots[0].pierced)
	assert_true(w.clone().shots[0].pierced)


func test_a_piercing_wisp_preview_equals_the_round() -> void:
	var w := _world()
	_post(w, 2)
	_post(w, 3, 0)
	_put(w, 4, 0, World.WALL)
	var f := Forecast.of(w, _cast([FOX, METAL, METAL]))
	var events := w.act(_cast([FOX, METAL, METAL]))
	var harm := {}
	for e in events.filter(func(e): return e.t == &"hurt"):
		harm[e.id] = harm.get(e.id, 0) + e.n
	assert_eq(f.harm, harm)
	assert_eq(harm.size(), 2)
	assert_eq(f.after.shots.map(func(s): return s.pos), w.shots.map(func(s): return s.pos))


func test_a_mortar_hurts_what_stands_next_to_where_it_ends_and_the_creature_it_struck_once(
) -> void:
	var w := _world()
	var struck := _post(w, 3)
	var beside := _post(w, 3, 1)
	var behind := _post(w, 4)
	var two_off := _post(w, 3, 2)
	var away := _post(w, 3, 3)
	var events := w.act(_cast([ORB, EARTH, METAL]))
	assert_eq(_hurts(events, beside), [Compounds.MORTAR])
	assert_eq(_hurts(events, behind), [Compounds.MORTAR])
	assert_eq(_hurts(events, two_off), [Compounds.MORTAR])
	assert_eq(_hurts(events, struck).count(Compounds.MORTAR), 1, "the burst hurts it once")
	assert_eq(away.hp, HEALTH, "three tiles from the burst")


func test_a_mortar_into_a_wall_bursts_in_front_of_it_and_hits_the_walls_round_it() -> void:
	var w := _world()
	for y in range(-3, 4):
		_put(w, 3, y, World.WALL)
	_put(w, 5, 0, World.WALL)
	var beside := _post(w, 2, 1)
	var far := _post(w, 2, 3)
	var events := w.act(_cast([ORB, EARTH, METAL]))
	assert_eq(_hurts(events, beside), [Compounds.MORTAR])
	assert_eq(far.hp, HEALTH)
	for y in range(-2, 3):
		assert_eq(w.tile(ME + Vector2i(3, y)), World.WALL_CRACKED, "walls in reach take a hit")
	assert_eq(w.tile(ME + Vector2i(3, 3)), World.WALL, "out of reach")
	assert_eq(w.tile(ME + Vector2i(5, 0)), World.WALL)


func test_a_mortar_bursts_one_tile_wider_for_every_more_earth() -> void:
	for more in [0, 1, 2]:
		var w := _world()
		_post(w, 3)
		var in_reach := _post(w, 3, 2 + more)
		var past := _post(w, 3, 3 + more)
		w.act(_cast([ORB, EARTH, METAL] + _n(EARTH, more)))
		assert_lt(in_reach.hp, HEALTH, "%d more 토 reach radius %d" % [more, 2 + more])
		assert_eq(past.hp, HEALTH, "%d more 토 stop at radius %d" % [more, 2 + more])


func test_a_blast_of_plain_orbs_stays_one_tile_round_and_leaves_the_walls_near_it() -> void:
	var w := _world()
	_post(w, 3)
	var beside := _post(w, 3, 1)
	var two_off := _post(w, 3, 2)
	_put(w, 3, 3, World.WALL)
	_put(w, 4, 2, World.WALL)
	w.act(_cast([ORB, ORB, ORB]))
	assert_lt(beside.hp, HEALTH)
	assert_eq(two_off.hp, HEALTH)
	assert_eq(w.tile(ME + Vector2i(4, 2)), World.WALL)


func test_a_mortar_hurts_one_more_for_every_more_metal() -> void:
	var w := _world()
	_post(w, 3)
	var beside := _post(w, 3, 1)
	var events := w.act(_cast([ORB, EARTH, METAL, METAL]))
	assert_eq(_hurts(events, beside), [Compounds.MORTAR + 1])


func test_a_mortar_with_a_lone_metal_bursts_on_the_creature_it_strikes_and_leaves_it_there(
) -> void:
	var w := _world()
	var struck := _post(w, 1)
	var events := w.act(_cast([ORB, EARTH, METAL, METAL]))
	assert_eq(struck.pos, ME + E, "no push")
	assert_eq(_hurts(events, struck).size(), 2, "the strike and the burst")


func test_the_hover_tells_a_push_only_for_a_spell_that_pushes() -> void:
	for cards: Array in [[ORB, METAL], [ORB, EARTH, METAL, METAL]]:
		var w := _world()
		var struck := _post(w, 3)
		w.act(_cast(cards))
		var pushed := struck.pos != ME + E * 3
		var hover := Info.plain(SpellInfo.spell(Spell.make(cards)))
		assert_eq(hover.contains("밀침"), pushed, str(cards))


func test_a_mortar_is_a_gun_that_flashes_and_booms() -> void:
	var w := _world()
	var events := w.act(_cast([ORB, EARTH, METAL]))
	var bang: Dictionary = events.filter(func(e): return e.t == &"noise")[0]
	assert_eq([bang.word, bang.loud], ["쾅", Elements.CANNON_LOUD])
	var flash := _world()
	Cast.cast(flash, flash.player(), Spell.make([ORB, EARTH, METAL]), E)
	assert_has(flash.flares, ME)


func test_a_homing_mortar_that_fades_bursts_where_it_stops() -> void:
	var w := _world()
	var events: Array = w.act(_cast([FOX, ORB, EARTH, METAL]))
	for i in 12:
		events = w.act({t = &"wait"})
		if events.any(func(e): return e.t == &"fade"):
			break
	var kinds := events.map(func(e): return e.t)
	assert_has(kinds, &"fade")
	assert_has(kinds, &"splash")


func test_a_homing_mortar_that_fades_is_heard_as_loud_as_one_that_strikes() -> void:
	var w := _world()
	var cards := [FOX, ORB, EARTH, METAL]
	var events: Array = w.act(_cast(cards))
	for i in 12:
		events = w.act({t = &"wait"})
		if events.any(func(e): return e.t == &"fade"):
			break
	var at: Vector2i = events.filter(func(e): return e.t == &"fade")[0].at
	var bangs := events.filter(func(e): return e.t == &"noise" and e.at == at)
	assert_eq(bangs.map(func(e): return e.loud), [Spell.make(cards).burst_noise()])


func test_a_mortar_preview_equals_the_round() -> void:
	var w := _world()
	_post(w, 3)
	_post(w, 3, 1)
	_post(w, 4, -1)
	_put(w, 4, 2, World.WALL)
	var cards := [ORB, EARTH, METAL, EARTH]
	var f := Forecast.of(w, _cast(cards))
	var events := w.act(_cast(cards))
	var harm := {}
	for e in events.filter(func(e): return e.t == &"hurt"):
		harm[e.id] = harm.get(e.id, 0) + e.n
	assert_eq(f.harm, harm)
	assert_eq(f.after.tiles, w.tiles)


func test_shrapnel_sprays_one_tile_wider_for_every_earth() -> void:
	var w := _world()
	var plain := _post(w, 5)
	w.act(_cast([EARTH, METAL]))
	assert_eq(plain.hp, HEALTH, "radius 1 round the third tile")
	var fed := _world()
	var near := _post(fed, 5)
	var past := _post(fed, 6)
	fed.act(_cast([EARTH, METAL, EARTH]))
	assert_eq(near.hp, HEALTH - Compounds.SHRAPNEL, "radius 2")
	assert_eq(past.hp, HEALTH)


func test_a_pair_that_beats_gains_nothing_from_a_lone_element() -> void:
	var w := _world()
	var with_metal := Spray.cover(w, w.player(), Spell.make([METAL, WOOD, METAL]), E)
	var plain := Spray.cover(w, w.player(), Spell.make([METAL, WOOD]), E)
	assert_eq(with_metal.size(), plain.size(), "가시 is a 상극 pair")


func test_wildfire_fans_one_tile_wider_for_every_wood() -> void:
	var w := _world()
	var wide := Spray.cover(w, w.player(), Spell.make([WOOD, FIRE, WOOD]), E)
	var plain := Spray.cover(w, w.player(), Spell.make([WOOD, FIRE]), E)
	assert_has(wide, ME + Vector2i(4, 0))
	assert_does_not_have(plain, ME + Vector2i(4, 0))
	assert_does_not_have(wide, ME + Vector2i(5, 0))


func test_five_fires_cover_a_fan_of_radius_six() -> void:
	var w := _world()
	var reached := _post(w, 6)
	var past := _post(w, 7)
	w.act(_cast(_n(FIRE, 5)))
	assert_gt(reached.ailments.alight, 0)
	assert_eq(past.ailments.alight, 0)
