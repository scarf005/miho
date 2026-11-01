extends GutTest
## Power by tails spent, and how wisps and homing orbs pick and chase creatures.

const FOX := Cards.FOX
const ORB := Cards.ORB
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}


## An open hall walled at the edges, with no light, Miho at `at` and five tails.
func _world(at := Vector2i(4, 8)) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = at
	w.actors.append(me)
	w.depth = 13
	w.tails = 5
	w.cards.assign(Cards.ALL)
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature at its listed health (Bestiary hp), whatever the storey's rank.
func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	a.hp = Bestiary.info(kind).hp
	a.max_hp = a.hp
	return a


func test_one_talisman_is_power_one_and_every_copy_adds_one() -> void:
	assert_eq(Spell.make([FOX]).damage(0), 0, "a lone wisp: none")
	assert_eq(Spell.make([FOX, FOX]).damage(0), 1, "each of two wisps")
	assert_eq(Spell.make([FOX, FOX, FOX]).damage(0), 1, "each of three wisps")
	assert_eq(Spell.make([FOX, FOX, FOX]).shots(), 3)
	assert_eq(Spell.make([FOX, Cards.FIRE, Cards.FIRE]).damage(0), 2, "불 again: +1")
	assert_eq(Spell.make([ORB]).damage(0), 1)
	assert_eq(Spell.make([ORB, ORB, ORB]).damage(0), 3, "구 again: +1 each")
	assert_eq(Spell.make([ORB, ORB]).damage(Spell.MOMENTUM), 3, "and the run-up")
	assert_eq(Spell.make([FOX, ORB, ORB]).damage(0), 2, "a homing orb too")


func test_a_lone_wisp_does_no_harm_and_banks_30_degrees_a_tile() -> void:
	assert_eq(Spell.make([FOX]).damage(0), 0, "one tail: no harm")
	assert_eq(Spell.make([FOX]).turn(), 30)
	assert_eq(Spell.make([FOX, FOX]).damage(0), 1, "two tails: each wisp hits for 1")
	assert_eq(Spell.make([FOX, FOX]).turn(), 60, "30° more for every 여")
	assert_eq(Spell.make([FOX, FOX, FOX, FOX]).turn(), 120)
	var w := _world()
	var foe := _foe(w, &"jangseung", Vector2i(5, 8))
	w.act(_cast([FOX], E))
	assert_eq(foe.hp, foe.max_hp, "it strikes and does nothing")
	assert_eq(w.shots.map(func(s): return s.host), [foe.id], "it sticks to the creature")


func test_harmless_wisps_all_go_for_the_nearest() -> void:
	var w := _world()
	var a := _foe(w, &"imugi", Vector2i(6, 8))
	_foe(w, &"jangseung", Vector2i(4, 11))
	assert_eq(Homing.targets(w, w.player(), Spell.make([FOX])), [a.id] as Array[int])


func test_homing_orbs_turn_45_degrees_more_for_every_fox_and_freely_with_four() -> void:
	assert_eq(Spell.make([ORB]).turn(), 0)
	assert_eq(Spell.make([FOX, ORB]).turn(), 45)
	assert_eq(Spell.make([FOX, FOX, ORB]).turn(), 90)
	assert_eq(Spell.make([FOX, FOX, FOX, FOX, ORB]).turn(), 45 * Spell.TURN_FREE)
	assert_eq(Spell.make([FOX]).turn(), 30, "a wisp turns less")


func test_extra_copies_of_an_element_root_and_stun_a_round_longer() -> void:
	var cases := [
		[[FOX, Cards.WOOD], &"rooted", 2],
		[[FOX, Cards.WOOD, Cards.WOOD], &"rooted", 3],
		[[FOX, Cards.EARTH], &"stunned", 1],
		[[FOX, Cards.EARTH, Cards.EARTH], &"stunned", 2],
	]
	for c in cases:
		var w := _world()
		var foe := _foe(w, &"saja", Vector2i(6, 8))
		foe.hp = 20
		var events := w.act(_cast(c[0]))
		var e: Dictionary = events.filter(func(x): return x.t in [&"root", &"stun"])[0]
		assert_eq(e.rounds, c[2], str(c[0]))


func test_a_fire_orbs_splash_grows_with_every_fire_copy() -> void:
	var w := _world()
	var near := _foe(w, &"jangseung", Vector2i(9, 9))
	_put(w, Vector2i(10, 8), World.WALL)
	w.act(_cast([ORB, Cards.FIRE, Cards.FIRE]))
	w.act(WAIT)
	w.act(WAIT)
	assert_eq(near.max_hp - near.hp, World.FIRE_DAMAGE + 1, "1 more for the second 불")


func test_wisps_fill_the_nearest_creatures_up_to_their_health() -> void:
	var w := _world()
	var a := _foe(w, &"imugi", Vector2i(6, 8))
	var b := _foe(w, &"jangseung", Vector2i(4, 11))
	_put(w, Vector2i(6, 11), World.LANTERN)
	var me := w.player()
	var spell := Spell.make([FOX, FOX, FOX])
	assert_eq(Homing.targets(w, me, spell), [a.id, a.id, b.id] as Array[int], "a has 2 health")
	spell = Spell.make([FOX, FOX, FOX, FOX, FOX])
	assert_eq(Homing.targets(w, me, spell), [a.id, a.id, b.id, b.id, b.id] as Array[int])
	b.hp = 1
	assert_eq(
		Homing.targets(w, me, spell),
		[a.id, a.id, b.id, a.id, a.id] as Array[int],
		"the wisps left over go to the nearest"
	)
	spell = Spell.make([FOX, FOX, Cards.FIRE, Cards.FIRE])
	assert_eq(Homing.targets(w, me, spell), [a.id, b.id] as Array[int], "a wisp of 2 fills a")


func test_wisps_take_ties_by_id_and_only_creatures_the_caster_sees() -> void:
	var w := _world()
	var first := _foe(w, &"jangseung", Vector2i(6, 8))
	var second := _foe(w, &"jangseung", Vector2i(2, 8))
	var unseen := _foe(w, &"jangseung", Vector2i(30, 8))
	var targets := Homing.targets(w, w.player(), Spell.make([FOX, FOX, FOX, FOX, FOX]))
	assert_eq(targets.slice(0, 3), [first.id, first.id, first.id] as Array[int])
	assert_eq(targets.slice(3, 5), [second.id, second.id] as Array[int])
	assert_false(targets.has(unseen.id), "it is dark and far")


func test_heavens_wisps_go_for_miho_alone() -> void:
	var w := _world()
	var caster := _foe(w, &"dokkaebi", Vector2i(6, 8))
	_foe(w, &"jangseung", Vector2i(5, 8))
	_put(w, Vector2i(5, 10), World.LANTERN)
	assert_eq(
		Homing.targets(w, caster, Spell.make([FOX, FOX])),
		[w.player().id, w.player().id] as Array[int]
	)


func test_only_a_wisp_whose_creature_fell_takes_another() -> void:
	var w := _world()
	var a := _foe(w, &"jangseung", Vector2i(10, 8))
	var b := _foe(w, &"jangseung", Vector2i(10, 13))
	var c := _foe(w, &"jangseung", Vector2i(11, 8))
	_put(w, Vector2i(11, 11), World.LANTERN)
	for x in [a, b, c]:
		x.hp = 1
	w.act(_cast([FOX, FOX]))
	var shots := w.shots.duplicate()
	assert_eq(shots.map(func(s): return s.target), [a.id, b.id])
	a.hp = 0
	w.act(WAIT)
	assert_eq(c.hp, 0, "the first wisp took the nearest one left that it saw")
	assert_eq(b.hp, 0, "the second kept its own")


func test_wisps_of_four_foxes_fly_round_a_wall_to_their_creature() -> void:
	var w := _world()
	for y in range(1, 11):
		_put(w, Vector2i(8, y), World.WINDOW)
	_put(w, Vector2i(12, 8), World.LANTERN)
	var foe := _foe(w, &"jangseung", Vector2i(11, 8))
	var events := w.act(_cast([FOX, FOX, FOX, FOX])) + w.act(WAIT) + w.act(WAIT) + w.act(WAIT)
	var tiles := events.filter(func(e): return e.t == &"fly").map(func(e): return e.to)
	assert_lt(foe.hp, foe.max_hp, "they got there")
	assert_true(tiles.has(Vector2i(8, 11)), "under the windows")
	assert_false(tiles.any(func(p): return w.tile(p) == World.WINDOW))


## A winding way that turns back on itself: a corridor east along y 8, up
## x 10, over (11, 4) and down x 12 to the creature at (12, 7). Every other
## tile is a window, so Miho sees all of it but nothing flies through.
func _hairpin() -> World:
	var w := _world()
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			_put(w, Vector2i(x, y), World.WINDOW)
	for x in range(3, 11):
		_put(w, Vector2i(x, 8), World.FLOOR)
	for p in [Vector2i(10, 7), Vector2i(10, 6), Vector2i(10, 5), Vector2i(11, 4)]:
		_put(w, p, World.FLOOR)
	for p in [Vector2i(12, 5), Vector2i(12, 6), Vector2i(12, 7)]:
		_put(w, p, World.FLOOR)
	_put(w, Vector2i(13, 6), World.LANTERN)
	return w


func test_a_homing_orb_with_one_fox_loses_its_creature_round_a_sharp_corner() -> void:
	var w := _hairpin()
	var foe := _foe(w, &"jangseung", Vector2i(12, 7))
	var events := []
	events += w.act(_cast([FOX, ORB]))
	for i in 5:
		events += w.act(WAIT)
	assert_eq(foe.hp, 3, "it could not turn 90° at (11, 4)")
	assert_true(events.any(func(e): return e.t == &"burst"))


func test_a_homing_orb_with_four_foxes_follows_the_corner() -> void:
	var w := _hairpin()
	w.tails = 7
	var foe := _foe(w, &"jangseung", Vector2i(12, 7))
	var events := []
	events += w.act(_cast([FOX, FOX, FOX, FOX, ORB]))
	for i in 5:
		events += w.act(WAIT)
	assert_lt(foe.hp, 3)
	var tiles := events.filter(func(e): return e.t == &"fly").map(func(e): return e.to)
	assert_true(tiles.has(Vector2i(11, 4)) and tiles.has(Vector2i(12, 6)))


func test_the_forecast_of_a_cast_of_wisps_is_what_the_round_does() -> void:
	var w := _world()
	var a := _foe(w, &"imugi", Vector2i(7, 9))
	var b := _foe(w, &"jangseung", Vector2i(5, 12))
	_put(w, Vector2i(6, 11), World.LANTERN)
	w.sense()
	var action := _cast([FOX, FOX, FOX, Cards.FIRE])
	var f := Forecast.of(w, action)
	var after := w.preview(action)
	w.act(action)
	assert_eq(f.harm.get(a.id, 0), a.max_hp - a.hp)
	assert_eq(f.harm.get(b.id, 0), b.max_hp - b.hp)
	assert_eq(after.shots.map(func(s): return s.pos), w.shots.map(func(s): return s.pos))
	assert_true(f.paths.values().all(func(p): return p.target != 0), "each wisp chases someone")


func test_two_wisps_strike_the_creature_they_chase_for_one_each() -> void:
	var w := _world()
	var foe := _foe(w, &"jangseung", Vector2i(7, 8))
	w.act(_cast([FOX, FOX], E))
	assert_eq(foe.hp, foe.max_hp - 2)
	assert_eq(w.shots.size(), 2, "both stick and strike no more")


## The first tile each projectile flies to in `events`, in the order they were cast.
func _starts(events: Array) -> Array:
	var out := {}
	for e in events:
		if e.t == &"fly" and not out.has(e.shot):
			out[e.shot] = e.to
	return out.values()


func test_wisps_of_one_cast_leave_on_their_own_tiles_fanned_round_the_aim() -> void:
	var w := _world()
	var me := w.player().pos
	var ne := Vector2i(1, -1)
	var se := Vector2i(1, 1)
	var events := w.act(_cast([FOX, FOX, FOX]))
	assert_eq(_starts(events), [me + E, me + ne, me + se])
	assert_eq(w.shots.map(func(s): return s.dir), [E, ne, se], "no creature: each flies on")
	assert_eq(
		w.shots.map(func(s): return s.pos),
		w.shots.map(func(s): return me + s.dir * s.flown),
		"straight along its own heading"
	)


func test_a_wisp_passes_over_a_wall_beside_miho_for_the_next_open_tile() -> void:
	var w := _world()
	var me := w.player().pos
	_put(w, me + Vector2i(1, -1), World.WALL)
	var events := w.act(_cast([FOX, FOX, FOX]))
	assert_eq(_starts(events), [me + E, me + Vector2i(1, 1), me + Vector2i(0, -1)])


func test_wisps_with_no_open_tile_of_their_own_follow_the_aimed_one() -> void:
	var w := _world()
	var me := w.player().pos
	for d in Grid.DIRS:
		if d != E:
			_put(w, me + d, World.WALL)
	var events := w.act(_cast([FOX, FOX, FOX]))
	assert_eq(_starts(events), [me + E, me + E, me + E])


func test_the_forecast_shows_the_tile_each_wisp_of_a_cast_leaves_on() -> void:
	var w := _world()
	_foe(w, &"imugi", Vector2i(8, 5))
	_put(w, Vector2i(8, 3), World.LANTERN)
	w.sense()
	var action := _cast([FOX, FOX, FOX, FOX])
	var f := Forecast.of(w, action)
	var events := w.act(action)
	var me := w.player().pos
	var starts := _starts(events)
	assert_eq(starts, [me + E, me + Vector2i(1, -1), me + Vector2i(1, 1), me + Vector2i(0, -1)])
	assert_eq(f.paths.values().map(func(p): return p.tiles[1]), starts)


func test_a_wisp_off_the_aimed_line_turns_on_its_tile_to_a_creature_close_by() -> void:
	var w := _world()
	var foe := _foe(w, &"jangseung", Vector2i(6, 8))
	var events := w.act(_cast([FOX, FOX]))
	assert_eq(_starts(events)[1], w.player().pos + Vector2i(1, -1))
	assert_eq(foe.hp, foe.max_hp - 2, "both strike in the round of the cast")


func test_a_wisp_off_the_aimed_line_never_turns_back_at_miho() -> void:
	var w := _world()
	var me := w.player()
	for x in [-1, 0, 1]:
		_put(w, me.pos + Vector2i(x, -1), World.WALL)
		_put(w, me.pos + Vector2i(x, 1), World.WALL)
	_foe(w, &"jangseung", Vector2i(9, 8))
	_put(w, Vector2i(9, 10), World.LANTERN)
	var events := w.act(_cast([FOX, FOX]))
	for i in 3:
		events += w.act(WAIT)
	assert_eq(_starts(events), [me.pos + E, me.pos - E])
	assert_false(events.any(func(e): return e.t == &"hit" and e.id == me.id))
	assert_eq(me.hp, me.max_hp)


func test_one_to_five_cards_cost_1_2_3_5_7_tails_and_each_card_past_five_two_more() -> void:
	var costs: Array[int] = []
	for n in range(1, 6):
		var cards: Array[StringName] = []
		cards.resize(n)
		cards.fill(FOX)
		costs.append(Spell.make(cards).cost())
	assert_eq(costs, [1, 2, 3, 5, 7] as Array[int])
	assert_eq(Spell.price(0), 0)
	assert_eq([Spell.price(6), Spell.price(7), Spell.price(11)], [9, 11, 19])
