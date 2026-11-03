extends GutTest
## 불여우 (Guise.FLAME): Miho counts as a fire creature, as the rules creatures obey
## say, and her spells that hold 불 harm one more.

const ME := Vector2i(4, 8)
const AWAY := Vector2i(4, 12)
const WAIT := {t = &"wait"}
const SAVE := "user://test_flame.cfg"
const FIRE_WISP := [Cards.FOX, Cards.FIRE]
const FIRE_ORB := [Cards.ORB, Cards.FIRE]
const WATER_WISP := [Cards.FOX, Cards.WATER]
const WATER_ORB := [Cards.ORB, Cards.WATER]
const EARTH_WISP := [Cards.FOX, Cards.EARTH]
const FIRE_SPRAY := [Cards.FIRE, Cards.FIRE, Cards.FIRE]
const WEST := Vector2i(-1, 0)
## Tiles away she sees in the dark hall, where a forecast keeps a creature.
const GAP := 2
const EAST := Vector2i(1, 0)


func before_each() -> void:
	Keys.reset()


func after_each() -> void:
	SaveGame.new(SAVE).erase()


## An open hall walled at the edges, every tile known and seen, Miho at ME with
## every talisman and nine tails.
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
	w.depth = 5
	w.tails = 9
	w.cards.assign(Cards.ALL)
	return w


func _self(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = Vector2i.ZERO}]}


func _throw(cards: Array, dir: Vector2i) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func _wear(w: World) -> void:
	w.act(_self(Guise.RECIPE[Guise.FLAME]))
	w.tails = 9


## A creature of `kind` that does nothing but stand, with health to spare.
func _dummy(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.hp = 30
	a.max_hp = 30
	a.magic.cooldown = 99
	a.ailments.stunned = 99
	return a


## A standing 장승 GAP tiles east of `at`, which throws `cards` west at it; the
## events of the rounds that follow.
func _shoot(w: World, at: Vector2i, cards: Array) -> Array[Dictionary]:
	var shooter := _dummy(w, &"jangseung", at + Vector2i(GAP, 0))
	Cast.cast(w, shooter, Spell.make(cards), WEST)
	var events: Array[Dictionary] = []
	for i in 6:
		events.append_array(w.act(WAIT))
	return events


## The health `victim` loses to `cards` thrown at it by a creature, with 불여우 on
## Miho when `worn`. The victim is Miho, or a creature of `kind` away from her.
func _loss(cards: Array, worn: bool, kind := &"miho") -> int:
	var w := _world()
	if worn:
		_wear(w)
	var victim := w.player() if kind == &"miho" else _dummy(w, kind, AWAY)
	var before := victim.hp
	_shoot(w, victim.pos, cards)
	return before - victim.hp


## The harm of the first blow of the cast `cards` of Miho on a creature, worn or not.
func _dealt(cards: Array, worn: bool) -> int:
	var w := _world()
	if worn:
		_wear(w)
	var foe := _dummy(w, &"imugi", ME + Vector2i(GAP, 0))
	var events := w.act(_throw(cards, EAST))
	for i in 6:
		events.append_array(w.act(WAIT))
	return events.filter(func(e): return e.t == &"hurt" and e.id == foe.id)[0].n


func test_the_recipe_goes_on_her_and_thrown_it_is_a_spell_as_before() -> void:
	var w := _world()
	w.act(_throw(Guise.RECIPE[Guise.FLAME], EAST))
	assert_false(w.player().buffs.flame, "thrown, it goes on no one")
	_wear(w)
	assert_true(w.player().buffs.flame)
	assert_eq(Guise.worn(w, w.player()), [Guise.FLAME])
	assert_eq(w.player().nature_kind(), Guise.FLAME_KIND)


func test_it_costs_what_its_cards_cost_and_recasting_keeps_one() -> void:
	var w := _world()
	w.act(_self(Guise.RECIPE[Guise.FLAME]))
	assert_eq(w.tails, 9 - Spell.price(Guise.RECIPE[Guise.FLAME].size()))
	w.act(_self(Guise.RECIPE[Guise.FLAME]))
	assert_eq(Guise.worn(w, w.player()), [Guise.FLAME])


func test_a_fire_spell_does_no_harm_worn_and_harms_without() -> void:
	for cards: Array in [FIRE_WISP, FIRE_ORB, FIRE_SPRAY]:
		assert_gt(_loss(cards, false), 0, "unworn %s" % [cards])
		assert_eq(_loss(cards, true), 0, "worn %s" % [cards])


func test_she_meets_every_spell_as_a_fire_creature_does() -> void:
	for cards: Array in [FIRE_WISP, FIRE_ORB, FIRE_SPRAY, WATER_WISP, WATER_ORB, EARTH_WISP]:
		assert_eq(_loss(cards, true), _loss(cards, false, &"bulgae"), "%s" % [cards])


func test_water_hurts_her_twice_over_as_it_hurts_a_fire_creature() -> void:
	for cards: Array in [WATER_WISP, WATER_ORB]:
		var plain := _loss(cards, false)
		assert_gt(plain, 0, "%s" % [cards])
		assert_eq(_loss(cards, true), plain * Elements.WEAK, "%s" % [cards])
		assert_eq(_loss(cards, false, &"bulgae"), plain * Elements.WEAK, "%s" % [cards])


func test_a_burning_tile_does_no_harm_and_she_catches_no_fire() -> void:
	for worn in [false, true]:
		var w := _world()
		if worn:
			_wear(w)
		w.set_tile(ME, World.GRASS)
		w.burning[ME] = World.BURN_ROUNDS
		w.act(WAIT)
		assert_eq(w.player().hp, 9 if worn else 9 - World.FIRE_DAMAGE, "worn: %s" % worn)
		assert_eq(Status.of(w.player()), &"", "worn: %s" % worn)


func test_her_spells_that_hold_fire_harm_one_more_and_the_rest_do_not() -> void:
	for cards: Array in [FIRE_WISP, FIRE_ORB]:
		assert_eq(_dealt(cards, true), _dealt(cards, false) + Guise.FLAME_HARM, "%s" % [cards])
	for cards: Array in [EARTH_WISP, WATER_WISP]:
		assert_eq(_dealt(cards, true), _dealt(cards, false), "%s" % [cards])


func test_a_blast_harms_the_creatures_round_it_one_more() -> void:
	var by := []
	for worn in [false, true]:
		var w := _world()
		if worn:
			_wear(w)
		var near := _dummy(w, &"imugi", ME + Vector2i(GAP + 2, 0))
		var side := _dummy(w, &"imugi", ME + Vector2i(GAP + 2, 1))
		w.act(_throw(FIRE_ORB, EAST))
		for i in 6:
			w.act(WAIT)
		by.append(60 - near.hp - side.hp)
	assert_gt(by[0], 0)
	assert_eq(by[1], by[0] + 2 * Guise.FLAME_HARM)


func test_a_forecast_of_the_cast_and_of_the_round_equals_what_happens() -> void:
	var w := _world()
	var cast := _self(Guise.RECIPE[Guise.FLAME])
	var f := Forecast.of(w, cast)
	assert_eq(f.events, w.act(cast))
	assert_true(f.after.player().buffs.flame)
	w.tails = 9
	_dummy(w, &"imugi", ME + Vector2i(GAP, 0))
	var fire := _throw(FIRE_WISP, EAST)
	f = Forecast.of(w, fire)
	var events := w.act(fire)
	assert_eq(f.events, events)
	assert_eq(f.after.actors.map(func(a): return a.hp), w.actors.map(func(a): return a.hp))


func test_a_forecast_of_a_fire_shot_at_her_equals_the_round() -> void:
	var w := _world()
	_wear(w)
	var shooter := _dummy(w, &"jangseung", ME + Vector2i(GAP, 0))
	Cast.cast(w, shooter, Spell.make(FIRE_WISP), WEST)
	w.sense()
	var f := Forecast.of(w, WAIT)
	var events := w.act(WAIT)
	assert_eq(f.events, events)
	assert_eq(f.after.player().hp, w.player().hp)
	assert_eq(w.player().hp, 9)


func test_the_form_stays_up_a_storey_and_down_again() -> void:
	var w := World.create(5)
	w.cards.assign(Cards.ALL)
	w.tails = 9
	_wear(w)
	var down := w.clone()
	for at_storey in [w.depth + 1, w.depth]:
		Storeys.leave(w)
		Storeys.enter(w, at_storey)
		w.sense()
		w.act(WAIT)
		assert_true(w.player().buffs.flame, "on storey %d" % at_storey)
		assert_eq(w.player().nature_kind(), Guise.FLAME_KIND)
	assert_true(down.player().buffs.flame, "a clone keeps it")
	assert_eq(down.player().nature_kind(), Guise.FLAME_KIND)


func test_it_does_not_end_by_time() -> void:
	var w := _world()
	_wear(w)
	for i in 200:
		w.act(WAIT)
	assert_true(w.player().buffs.flame)


func test_dropping_it_takes_everything_back() -> void:
	var w := _world()
	_wear(w)
	var events := w.act({t = &"dispel", kind = Guise.FLAME})
	assert_false(w.player().buffs.flame)
	assert_eq(w.player().nature_kind(), &"miho")
	assert_eq(Guise.worn(w, w.player()), [])
	assert_true(events.any(func(e): return e.t == &"unflame"))
	assert_gt(_loss(FIRE_WISP, false), 0, "fire harms her again")
	assert_eq(_dealt(FIRE_WISP, false), 1, "and her fire is plain")


func test_the_log_tells_the_form_and_its_end_and_each_is_heard() -> void:
	var w := _world()
	var before := w.clone()
	var events := w.act(_self(Guise.RECIPE[Guise.FLAME]))
	assert_has(Messages.of(before, w, events).map(Messages.plain), "불여우로 변했다")
	assert_true(events.any(func(e): return e.t == &"flame" and Sfx.sound_of(e) == &"flame"))
	w.tails = 9
	before = w.clone()
	events = w.act({t = &"dispel", kind = Guise.FLAME})
	assert_has(Messages.of(before, w, events).map(Messages.plain), "불여우 변신이 풀렸다")
	assert_true(events.any(func(e): return Sfx.sound_of(e) == &"hiss"))


func test_the_hover_on_her_tells_the_element_and_the_immunity_only_worn() -> void:
	var w := _world()
	var plain := Info.plain(Info.creature(w, w.player()))
	_wear(w)
	var worn := Info.plain(Info.creature(w, w.player()))
	for label in ["오행:", "약점:", "면역:"]:
		assert_false(plain.contains(label), label)
		assert_true(worn.contains(label), label)


func test_creatures_do_not_throw_fire_at_her_while_she_is_a_fire_creature() -> void:
	var w := _world()
	var caster := FloorGen.spawn(w, &"bulgae", ME + Vector2i(GAP, 0))
	caster.rank = Bestiary.PICKS
	assert_false(Aim.at(w, caster, w.player()).is_empty(), "it casts at a plain Miho")
	_wear(w)
	assert_true(Aim.at(w, caster, w.player()).is_empty())


func test_a_save_replays_to_the_same_world() -> void:
	var run := SaveGame.new(SAVE, 11)
	var w := World.create(11)
	var actions := [
		{t = &"cheat", cmd = &"cards"},
		{t = &"cheat", cmd = &"tails"},
		_self(Guise.RECIPE[Guise.FLAME]),
		_throw(FIRE_WISP, EAST),
		WAIT,
		WAIT,
	]
	for i in actions.size():
		assert_true(w.can(actions[i]), str(actions[i]))
		w.act(actions[i])
		run.record(actions[i], 0, false)
	run.flush()
	var back := SaveGame.load_from(SAVE)
	assert_not_null(back)
	assert_true(back.replay())
	assert_true(back.world.player().buffs.flame)
	assert_eq(back.world.player().hp, w.player().hp)
	assert_eq(back.world.round_no, w.round_no)
	assert_eq(back.world.rng.state, w.rng.state)


func test_the_hover_on_her_tells_no_harm_from_hot_ground_only_worn() -> void:
	var w := _world()
	w.hot[ME] = Vector2i(0, Compounds.HOT_ROUNDS)
	assert_true(Info.plain(Info.creature(w, w.player())).contains("초당 피해"))
	_wear(w)
	w.hot[ME] = Vector2i(0, Compounds.HOT_ROUNDS)
	assert_false(Info.plain(Info.creature(w, w.player())).contains("초당 피해"))


func test_the_hover_on_her_flying_shot_tells_the_harm_it_will_do() -> void:
	var w := _world()
	_wear(w)
	w.act(_throw(FIRE_ORB, EAST))
	var shot: Shot = w.shots.back()
	var harm: int = shot.spell.damage(shot.distance()) + Guise.FLAME_HARM
	assert_true(Info.plain(SpellInfo.shot(w, shot)).contains("피해: %d" % harm))


func test_a_spell_of_lightning_is_no_fire_spell() -> void:
	var cards := [Cards.FOX] + Cards.made_of(&"thunder")
	assert_eq(_dealt(cards, true), _dealt(cards, false))
