extends GutTest
## 도약 cast on Miho herself (Guise.VAULT): the next fall harms nothing and ends it, and
## steam rings the landing.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const EDGE := 25
const ROW := 8
const VAULT := [Cards.WATER, Cards.WOOD, Cards.FIRE]


## An open hall whose east part is sky from x = EDGE, Miho at (10, 8) on storey `depth`; the
## storeys below are kept as the whole hall, with no sky.
func _world(depth := 3) -> World:
	var w := World.new()
	w.rng.seed = 11
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, EDGE - 2, Grid.H - 2)])
	for below in range(1, depth):
		w.depth = below
		Storeys.leave(w)
	for y in range(1, Grid.H - 1):
		for x in range(EDGE, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.SKY
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(10, ROW)
	w.actors.append(me)
	w.depth = depth
	w.tails = w.max_tails()
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _self(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = Vector2i.ZERO}]}


## Miho wears 도약 and stands on the last floor tile before the sky.
func _at_the_edge(depth := 3) -> World:
	var w := _world(depth)
	w.player().buffs.vault = true
	w.player().pos = Vector2i(EDGE - 1, ROW)
	w.sense()
	return w


func _foe(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", at)
	a.ailments.stunned = 99
	a.hp = 99
	return a


func _steam_near(w: World, at: Vector2i, reach: int) -> bool:
	return w.gas.keys().any(func(p): return w.gas[p].x == Gas.STEAM and Grid.cheb(p, at) <= reach)


func test_vault_alone_goes_on_her_for_three_cards_and_she_stays() -> void:
	var w := _world()
	var at := w.player().pos
	var tails := w.tails
	w.act(_self(VAULT))
	assert_true(w.player().buffs.vault)
	assert_eq(w.player().pos, at)
	assert_eq(w.tails, tails - Spell.price(3))
	assert_eq(Guise.worn(w, w.player()), [Guise.VAULT])


func test_a_second_cast_is_refused_while_it_is_on() -> void:
	var w := _world()
	w.player().buffs.vault = true
	assert_eq(Guise.why(w.player(), Spell.make(VAULT)), Guise.WORN)
	assert_false(w.can(_self(VAULT)))
	w.player().buffs.vault = false
	assert_true(w.can(_self(VAULT)))


func test_vault_with_another_element_or_a_direction_still_leaps() -> void:
	var w := _world()
	w.act({t = &"cast", spells = [{cards = VAULT, dir = E}]})
	assert_false(w.player().buffs.vault)
	assert_ne(w.player().pos, Vector2i(10, ROW), "she leapt")
	assert_eq(Guise.kind(Spell.make(VAULT + [Cards.EARTH])), &"")
	assert_false(_world().can(_self(VAULT + [Cards.EARTH])), "an element behind it is thrown")


func test_pushed_into_the_sky_she_keeps_her_health_and_loses_the_buff() -> void:
	var w := _at_the_edge()
	var hp := w.player().hp
	w.events = []
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 2)
	assert_eq(w.player().hp, hp)
	assert_false(w.player().buffs.vault)
	assert_true(w.events.any(func(e): return e.t == &"fall" and e.soft))
	assert_true(w.events.any(func(e): return e.t == &"unvault" and e.fall))


func test_after_the_landing_she_waits_ten_rounds_unscalded_and_a_foe_on_the_ring_is() -> void:
	var w := _at_the_edge()
	var hp := w.player().hp
	w.push(w.player(), E, 1)
	var me := w.player().pos
	var ring := _foe(w, me + Vector2i(-Leap.RING, 0))
	var near := _foe(w, me + Vector2i(0, 1))
	assert_true(_steam_near(w, me, Leap.RING))
	assert_false(_steam_near(w, me, 1), "none inside the ring")
	for i in 10:
		w.act(WAIT)
		assert_false(_steam_near(w, me, 1), "round %d" % i)
	assert_eq(w.player().hp, hp)
	assert_eq(near.hp, 99)
	assert_lt(ring.hp, 99, "a foe on the ring is scalded")


func test_the_ring_is_the_sixteen_tiles_round_the_inner_three_by_three() -> void:
	var w := _world()
	Leap.vent(w, Vector2i(10, ROW))
	assert_eq(w.gas.size(), 16)
	for p: Vector2i in w.gas:
		assert_eq(Grid.cheb(p, Vector2i(10, ROW)), Leap.RING)


func test_the_second_fall_hurts_as_before() -> void:
	var w := _at_the_edge(4)
	w.push(w.player(), E, 1)
	var hp := w.player().hp
	w.player().pos = Vector2i(EDGE - 1, ROW)
	for y in range(1, Grid.H - 1):
		w.set_tile(Vector2i(EDGE, y), World.SKY)
	w.push(w.player(), E, 1)
	assert_eq(w.player().hp, hp - Fall.DAMAGE)


func test_a_collapsing_floor_over_two_storeys_costs_nothing() -> void:
	var w := _world(4)
	w.player().buffs.vault = true
	# Storey 3 is sky where she lands, so she drops on to storey 2.
	w.depth = 3
	for y in range(1, Grid.H - 1):
		w.set_tile(Vector2i(11, y), World.SKY)
	Storeys.leave(w)
	w.depth = 4
	w.set_tile(Vector2i(11, ROW), World.TRAP_COLLAPSE)
	w.traps[Vector2i(11, ROW)] = World.TRAP_COLLAPSE
	var hp := w.player().hp
	w.act({t = &"move", dir = E})
	assert_eq(w.depth, 2, "two storeys down")
	assert_eq(w.player().hp, hp)
	assert_false(w.player().buffs.vault)


func test_on_the_first_storey_the_buff_stays() -> void:
	var w := _at_the_edge(1)
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 1)
	assert_true(w.player().buffs.vault)
	assert_true(w.gas.is_empty())


func test_the_soft_fall_is_told_and_heard() -> void:
	var w := _at_the_edge()
	var before := w.clone()
	w.events = []
	w.push(w.player(), E, 1)
	var lines := Messages.of(before, w, w.events).map(Messages.plain)
	assert_eq(lines.slice(0, 1), ["2층으로 내려왔다"])
	for e: Dictionary in w.events:
		if e.t == &"fall":
			assert_eq(Sfx.sound_of(e), &"")
		if e.t == &"unvault":
			assert_eq(Sfx.sound_of(e), &"hiss")
	assert_eq(Sfx.sound_of({t = &"unvault", id = 1, at = Vector2i.ZERO}), &"tick")
	assert_eq(Sfx.sound_of({t = &"vault", id = 1, at = Vector2i.ZERO}), &"hiss")


func test_the_cast_is_told_and_dropping_it_is_told() -> void:
	var w := _world()
	var before := w.clone()
	w.events = []
	w.act(_self(VAULT))
	var lines := Messages.of(before, w, w.events).map(Messages.plain)
	assert_true(lines.has("도약을 걸었다"), str(lines))
	before = w.clone()
	w.events = []
	w.act({t = &"dispel", kind = Guise.VAULT})
	assert_false(w.player().buffs.vault)
	lines = Messages.of(before, w, w.events).map(Messages.plain)
	assert_true(lines.has("도약이 풀렸다"), str(lines))


func test_the_buff_survives_a_clone() -> void:
	var w := _world()
	w.player().buffs.vault = true
	assert_true(w.clone().player().buffs.vault)
