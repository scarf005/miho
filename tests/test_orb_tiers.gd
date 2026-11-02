extends GutTest
## 구 by copies: from three an orb gains speed each round and blasts the eight
## tiles round where it ends, four hurl two orbs that spread among the creatures
## in sight and blast half, five blast the full harm; 구 with 수 pushes; a
## creature's orb follows its storey.

const ORB := Cards.ORB
const FOX := Cards.FOX
const WATER := Cards.WATER
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(20, 12)


## An open moonlit courtyard walled at the edges, Miho at ME and seven tails.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.COURTYARD
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
	w.tails = 7
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts, with 20 health and no weakness.
func _post(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", at)
	a.cooldown = 99
	a.hp = 20
	a.max_hp = 20
	return a


func _copies(n: int, more := []) -> Array:
	var out := []
	for i in n:
		out.append(ORB)
	return out + more


## Tiles the first orb of the round flew.
func _flies(events: Array) -> int:
	var fly := events.filter(func(e): return e.t == &"fly")
	return fly.filter(func(e): return e.shot == fly[0].shot).size()


func test_an_orb_of_three_flies_faster_every_round() -> void:
	var w := _world()
	var cast := _flies(w.act(_cast(_copies(3))))
	var base := Spell.make(_copies(3)).speed()
	assert_eq(cast, 1 + base, "the cast tile and its first round at its base speed")
	assert_eq(_flies(w.act(WAIT)), base + 1)
	assert_eq(_flies(w.act(WAIT)), base + 2)
	var slow := _world()
	slow.act(_cast(_copies(2)))
	assert_eq(
		_flies(slow.act(WAIT)), Spell.make(_copies(2)).speed(), "two copies fly at a steady pace"
	)
	assert_eq(_flies(slow.act(WAIT)), Spell.make(_copies(2)).speed())


func test_the_acceleration_grows_with_the_copies() -> void:
	var gains := []
	for n in range(3, 6):
		var w := _world()
		w.act(_cast(_copies(n)))
		var first := _flies(w.act(WAIT))
		gains.append(_flies(w.act(WAIT)) - first)
	assert_eq(gains, [1, 2, 3])


func test_the_blast_of_three_hurts_the_eight_tiles_by_one() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	var side := _post(w, ME + Vector2i(2, 1))
	var far := _post(w, ME + Vector2i(2, 3))
	w.act(_cast(_copies(3)))
	assert_eq(20 - foe.hp, 3, "the creature struck takes the orb's harm")
	assert_eq(20 - side.hp, Spell.BLAST_HARM)
	assert_eq(20 - far.hp, 0, "past the eight tiles nothing is hurt")


func test_two_copies_blast_nothing() -> void:
	var w := _world()
	_post(w, ME + Vector2i(2, 0))
	var side := _post(w, ME + Vector2i(2, 1))
	w.act(_cast(_copies(2)))
	assert_eq(side.hp, 20)


func test_the_blast_of_four_is_half_the_centre_rounded_up() -> void:
	# The creature behind is a second target on the same line: both orbs strike
	# the first, and each blast hurts the one behind it by half.
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	var behind := _post(w, ME + Vector2i(3, 0))
	w.act(_cast(_copies(4)))
	assert_eq(20 - foe.hp, 2 * 4)
	assert_eq(20 - behind.hp, 2 * 2, "half of 4, for each orb")
	var run := _world()
	var hit := _post(run, ME + Vector2i(Spell.MOMENTUM, 0))
	var after := _post(run, ME + Vector2i(Spell.MOMENTUM + 1, 0))
	run.act(_cast(_copies(4)))
	assert_eq(20 - hit.hp, 2 * 5, "after the run-up")
	assert_eq(20 - after.hp, 2 * 3, "half of 5 rounds up")


func test_the_blast_of_five_is_the_whole_harm_of_the_centre() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	var side := _post(w, ME + Vector2i(2, 1))
	w.act(_cast(_copies(5)))
	assert_eq(20 - foe.hp, 5)
	assert_eq(20 - side.hp, 20 - foe.hp)


func test_the_blast_where_an_orb_stops_at_a_wall_hurts_and_leaves_the_wall_as_a_lone_orb_does(
) -> void:
	var w := _world()
	w.tiles[Grid.index(ME + Vector2i(3, 0))] = World.WALL
	var side := _post(w, ME + Vector2i(2, 1))
	w.act(_cast(_copies(5)))
	assert_eq(20 - side.hp, 5, "the full harm, from the tile where it stopped")
	var lone := _world()
	lone.tiles[Grid.index(ME + Vector2i(3, 0))] = World.WALL
	lone.act(_cast([ORB]))
	assert_eq(w.tile(ME + Vector2i(3, 0)), lone.tile(ME + Vector2i(3, 0)))
	assert_eq(w.tile(ME + Vector2i(3, 1)), World.COURTYARD, "the blast cracks nothing round it")


func test_a_blast_hurts_twice_over_what_is_weak_to_it() -> void:
	var w := _world()
	_post(w, ME + Vector2i(2, 0))
	var weak := FloorGen.spawn(w, &"bulgae", ME + Vector2i(2, 1))
	weak.cooldown = 99
	weak.hp = 20
	var spell := Spell.make(_copies(3, [Cards.WATER]))
	assert_true(Bestiary.weak(weak.kind, spell), "a fire beast is weak to water")
	w.act(_cast(_copies(3, [Cards.WATER])))
	assert_eq(20 - weak.hp, Spell.BLAST_HARM * Elements.WEAK)


func test_a_blast_does_not_hurt_what_eats_the_spell() -> void:
	var w := _world()
	_post(w, ME + Vector2i(2, 0))
	var eater := FloorGen.spawn(w, &"haetae", ME + Vector2i(2, 1))
	eater.cooldown = 99
	var spell := Spell.make(_copies(3, [Cards.FIRE]))
	assert_true(Bestiary.absorbs(eater.kind, spell))
	var hp := eater.hp
	w.act(_cast(_copies(3, [Cards.FIRE])))
	assert_eq(eater.hp, hp)


func test_a_fire_orb_of_three_blasts_the_fire_and_the_tier() -> void:
	var w := _world()
	_post(w, ME + Vector2i(2, 0))
	var side := _post(w, ME + Vector2i(2, 1))
	w.act(_cast(_copies(3, [Cards.FIRE])))
	assert_eq(20 - side.hp, World.FIRE_DAMAGE + Spell.BLAST_HARM)


func test_four_hurl_two_orbs_at_two_creatures() -> void:
	var w := _world()
	var a := _post(w, ME + Vector2i(3, 0))
	var b := _post(w, ME + Vector2i(3, -3))
	var events := w.act(_cast(_copies(4)))
	assert_eq(events.filter(func(e): return e.t == &"spawn").size(), 2)
	assert_eq(20 - a.hp, 4)
	assert_eq(20 - b.hp, 4)


func test_two_orbs_at_one_creature_follow_each_other_along_its_line() -> void:
	var w := _world()
	var a := _post(w, ME + Vector2i(5, 0))
	var events := w.act(_cast(_copies(4)))
	assert_eq(events.filter(func(e): return e.t == &"clash").size(), 0, "they do not collide")
	assert_eq(20 - a.hp, 2 * 5, "both strike it, after the run-up")


func test_two_orbs_with_no_creature_in_sight_fly_the_aimed_line() -> void:
	var w := _world()
	var events := w.act(_cast(_copies(4)))
	assert_eq(events.filter(func(e): return e.t == &"clash").size(), 0)
	assert_eq(w.shots.size(), 2)


func test_the_orbs_of_a_cast_spread_among_the_narrowest_arc_that_holds_them() -> void:
	var w := _world()
	var ahead := _post(w, ME + Vector2i(3, 0))
	var aslant := _post(w, ME + Vector2i(3, -3))
	var near := _post(w, ME + Vector2i(0, -1))
	var foes := [near, ahead, aslant]
	var spread := func(n: int, aim := E) -> Array[int]:
		var seen := foes.duplicate()
		seen.sort_custom(func(x, y): return Grid.cheb(ME, x.pos) < Grid.cheb(ME, y.pos))
		return Homing.spread(w.player(), seen, aim, n)
	assert_eq(
		spread.call(2),
		[ahead.id, aslant.id] as Array[int],
		"90° holds two; the near one is 90° off"
	)
	assert_eq(spread.call(1), [ahead.id] as Array[int], "30° holds one")
	assert_eq(spread.call(3), [near.id, ahead.id, aslant.id] as Array[int], "180° for three")
	assert_eq(spread.call(2, -E), [near.id, near.id] as Array[int], "behind: only the one beside")


func test_a_cast_with_no_creature_in_the_widest_arc_has_no_target() -> void:
	var w := _world()
	var behind := _post(w, ME + Vector2i(-3, 0))
	assert_eq(Homing.spread(w.player(), [behind], E, 2), [0, 0] as Array[int])


func test_a_creature_of_storey_one_hurls_two_orbs_of_tier_and_storey_four_three() -> void:
	for row in [[1, 2], [2, 2], [3, 3], [4, 3], [5, 4], [8, 5]]:
		var cast: Array = Bestiary.casts(&"imugi", Bestiary.rank(row[0]))[0]
		assert_eq(Spell.make(cast).count(ORB), row[1], "storey %d" % row[0])


func test_a_creatures_orb_tier_leaves_room_for_its_other_talismans() -> void:
	var cast := Bestiary.tiered([FOX, FOX, FOX, FOX, ORB], 5)
	assert_not_null(Spell.make(cast), "five slots at most")
	assert_eq(cast.count(ORB), 1)
	var mixed := Bestiary.tiered([FOX, ORB, WATER], 4)
	assert_eq(mixed, [FOX, ORB, ORB, ORB, WATER], "the rank's orbs, in the place of the one")
	assert_eq(Bestiary.tiered([Cards.FIRE], 4), [Cards.FIRE], "a spell without 구 stays")


func test_a_creature_casts_the_orb_of_its_storey_and_it_strikes_for_the_copies() -> void:
	for row in [[1, 2], [4, 3]]:
		var w := _world()
		w.depth = row[0]
		var foe := FloorGen.spawn(w, &"imugi", ME + Vector2i(3, 0))
		foe.cooldown = 99
		foe.intent.assign([{cards = foe.repertoire()[0], dir = -E}])
		var me := w.player()
		me.hp = 9
		me.max_hp = 9
		w.act(WAIT)
		w.act(WAIT)
		assert_eq(9 - me.hp, row[1], "storey %d" % row[0])


func test_an_orb_with_water_pushes_what_it_strikes() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	w.act(_cast([ORB, WATER]))
	assert_eq(foe.pos, ME + Vector2i(2 + Spray.PLAIN_PUSH, 0))
	assert_eq(20 - foe.hp, 1, "and hurts as an orb does")


func test_an_orb_with_water_pushes_a_tile_more_a_copy_and_stops_at_a_wall() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	w.act(_cast([ORB, WATER, WATER]))
	assert_eq(foe.pos, ME + Vector2i(2 + Spray.PLAIN_PUSH + 1, 0))
	var wall := _world()
	wall.tiles[Grid.index(ME + Vector2i(3, 0))] = World.WALL
	var held := _post(wall, ME + Vector2i(2, 0))
	var events := wall.act(_cast([ORB, WATER]))
	assert_eq(held.pos, ME + Vector2i(2, 0))
	assert_eq(events.filter(func(e): return e.t == &"push").size(), 0)


func test_an_orb_without_water_does_not_push() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	w.act(_cast([ORB]))
	assert_eq(foe.pos, ME + Vector2i(2, 0))


func test_the_push_and_the_blast_of_a_water_orb_are_heard() -> void:
	assert_ne(Sfx.sound_of({t = &"push", id = 1, at = ME}), &"")
	var w := _world()
	_post(w, ME + Vector2i(2, 0))
	var events := w.act(_cast(_copies(3, [WATER])))
	assert_true(events.any(func(e): return e.t == &"push"))
	for e: Dictionary in events.filter(func(e): return e.t in [&"push", &"hit"]):
		assert_ne(Sfx.sounds_of(e), [], str(e.t))
	var splash := {t = &"splash", cards = _copies(3)}
	assert_eq(Sfx.sound_of(splash), &"", "the strike's own sound covers a blast without fire")


func _agrees(cards: Array, setup: Callable) -> void:
	var w := _world()
	setup.call(w)
	var action := _cast(cards)
	var f := Forecast.of(w, action)
	var events := w.act(action)
	for id in f.paths:
		var flown := []
		for e: Dictionary in events.filter(func(e): return e.t == &"fly" and e.shot == id):
			flown.append(e.to)
		assert_eq(f.paths[id].tiles.slice(1), flown, "orb %d path" % id)
	var actual := {}
	for e: Dictionary in events.filter(func(e): return e.t == &"hurt"):
		actual[e.id] = actual.get(e.id, 0) + e.n
	assert_eq(f.harm, actual, "harm to each creature")
	assert_gt(actual.size(), 0, "something was hurt")


func test_the_forecast_equals_the_cast_for_each_tier() -> void:
	var setup := func(w: World):
		_post(w, ME + Vector2i(3, 0))
		_post(w, ME + Vector2i(3, 1))
		_post(w, ME + Vector2i(3, -3))
	for n in range(3, 6):
		_agrees(_copies(n), setup)


func test_the_forecast_of_a_flying_orb_draws_the_accelerated_round() -> void:
	var w := _world()
	w.act(_cast(_copies(3)))
	w.act(WAIT)
	var f := Forecast.of(w, WAIT)
	var next := w.shots[0].pace()
	assert_eq(next, Spell.make(_copies(3)).speed() + 2)
	assert_eq(f.paths[w.shots[0].id].tiles.size() - 1, next, "tiles drawn are the tiles flown")
	var events := w.act(WAIT)
	assert_eq(_flies(events), next)
	assert_eq(f.paths[w.shots[0].id].tiles.back(), w.shots[0].pos)


func test_a_blast_stays_on_the_storey_where_the_orb_struck() -> void:
	var w := _world()
	w.stairs = ME + E
	var caster := FloorGen.spawn(w, &"imugi", ME - E * 3)
	caster.cooldown = 99
	w.player().hp = 50
	Cast.cast(w, caster, Spell.make(_copies(3, [WATER])), E)
	var kinds := w.act({t = &"wait"}).map(func(e): return e.t)
	assert_true(kinds.has(&"ascend"), "the push took her up")
	assert_false(kinds.has(&"splash"), "the blast does not follow her")


func test_a_creatures_charged_twin_flies_the_line_it_drew() -> void:
	var w := _world()
	var caster := FloorGen.spawn(w, &"imugi", ME - E * 2)
	caster.cooldown = 99
	caster.alert = Actor.HUNT
	caster.intent.assign([{cards = _copies(4), dir = E}])
	w.player().hp = 50
	w.act({t = &"move", dir = Vector2i(0, -1)})
	assert_eq(w.shots.map(func(s): return s.dir), [E, E])


func test_an_orb_that_fades_blasts_where_it_ends() -> void:
	var w := _world()
	Cast.cast(w, w.player(), Spell.make(_copies(3, [Cards.FOX])), E)
	w.shots[0].life = 1
	var kinds := w.act({t = &"wait"}).map(func(e): return e.t)
	assert_true(kinds.has(&"fade"))
	assert_true(kinds.has(&"splash"))


func test_an_orb_that_fades_is_heard_as_a_blast() -> void:
	var w := _world()
	Cast.cast(w, w.player(), Spell.make(_copies(3, [Cards.FOX])), E)
	w.shots[0].life = 1
	var loud := w.act({t = &"wait"}).filter(func(e): return e.t == &"noise" and e.word == "쾅")
	assert_eq(loud.size(), 1)
