extends GutTest
## 사령술 (Raise): five elements in the order of 윤회, cast on herself. The dead she sees
## rise as allies until she leaves the storey.

const ME := Vector2i(10, 8)
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const RAISE: Array = Guise.RECIPE[Guise.RAISE]
const SAVE := "user://test_raise.cfg"


func after_each() -> void:
	SaveGame.new(SAVE).erase()


## A lit open hall, every tile known, Miho at ME with every talisman and nine tails.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	w.rooms = [Rect2i(1, 1, Grid.W - 2, Grid.H - 2)]
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(2, Grid.W - 1, 4):
		w.tiles[Grid.index(Vector2i(x, ME.y - 3))] = World.LANTERN
		w.tiles[Grid.index(Vector2i(x, ME.y + 3))] = World.LANTERN
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
	w.start = ME
	w.depth = 5
	w.tail_bonus = 4
	w.tails = 9
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _cast() -> Dictionary:
	return {t = &"cast", spells = [{cards = RAISE, dir = Vector2i.ZERO}]}


## `w` with the spell on.
func _on() -> World:
	var w := _world()
	w.act(_cast())
	assert_true(w.player().raise)
	return w


## A resting creature of `kind` felled `dx` tiles east of Miho, in a round of no action.
func _fell(w: World, kind: StringName, dx: int) -> Vector2i:
	var at := ME + E * dx
	var foe := FloorGen.spawn(w, kind, at)
	w.hurt(foe, foe.hp)
	w._prune()
	w.sense()
	return at


func _risen(w: World) -> Array:
	return w.actors.filter(Raise.risen)


func test_it_costs_seven_tails_and_goes_on_her_in_the_order_of_samsara() -> void:
	var w := _world()
	assert_true(Spell.make(RAISE).holds(Cards.WOOD))
	assert_eq(Spell.make(RAISE).slots, [Cards.SAMSARA] as Array[StringName])
	w.act(_cast())
	assert_eq(w.tails, 9 - 7)
	assert_eq(Guise.worn(w, w.player()), [Guise.RAISE])


func test_seven_tails_are_needed() -> void:
	var w := _world()
	w.tails = 6
	assert_false(w.can(_cast()))


func test_hurled_it_stays_samsara() -> void:
	var w := _world()
	w.act({t = &"cast", spells = [{cards = RAISE, dir = E}]})
	assert_false(w.player().raise)


func test_the_other_five_element_spells_do_not_go_on_her() -> void:
	var w := _world()
	for slot: StringName in [Cards.CONQUEST, Cards.DRAGON]:
		var hers := {t = &"cast", spells = [{cards = Cards.recipe(slot), dir = Vector2i.ZERO}]}
		assert_false(w.can(hers), slot)


func test_a_foe_falling_in_sight_rises_as_a_fighting_ally() -> void:
	var w := _on()
	var at := _fell(w, &"dokkaebi", 3)
	var foe := FloorGen.spawn(w, &"dokkaebi", at + E * 2)
	foe.cooldown = 99
	var events := w.act(WAIT)
	var up: Array = _risen(w)
	assert_eq(up.size(), 1)
	assert_eq(up[0].pos, at)
	assert_eq(up[0].kind, Raise.WEAK)
	assert_eq(up[0].leader, w.player().id, "she leads it")
	assert_true(events.any(func(e): return e.t == &"ally" and e.id == up[0].id))
	assert_false(w.bodies.has(at), "the body is gone")
	var hp := foe.hp
	for i in 12:
		w.act(WAIT)
	assert_true(foe.hp < hp, "it fights")


func test_what_rises_goes_by_the_health_of_the_fallen() -> void:
	var w := _on()
	assert_eq(Raise.rises(w, Raise.WEAK), Raise.WEAK, "a 시귀 rises a 시귀")
	assert_eq(Raise.rises(w, Raise.STRONG), Raise.STRONG, "a 강시 rises a 강시")
	assert_eq(Raise.rises(w, &"dokkaebi"), Raise.WEAK, "frailer than a 강시")
	_fell(w, &"saja", 3)
	w.act(WAIT)
	assert_eq(_risen(w)[0].kind, Raise.STRONG, "as hale as a 강시")


func test_a_body_out_of_sight_rises_when_she_comes_to_see_it() -> void:
	var w := _world()
	for y in range(1, Grid.H - 1):
		w.tiles[Grid.index(Vector2i(ME.x + 2, y))] = World.WALL
	var door := Vector2i(ME.x + 2, ME.y)
	w.sense()
	var at := _fell(w, &"dokkaebi", 4)
	assert_true(w.bodies.has(at))
	assert_eq(w.seen[Grid.index(at)], 0, "behind the wall")
	w.act(_cast())
	for i in 3:
		w.act(WAIT)
	assert_true(_risen(w).is_empty(), "unseen it lies")
	assert_true(w.bodies.has(at))
	w.set_tile(door, World.FLOOR)
	w.act(WAIT)
	assert_eq(_risen(w).size(), 1, "seen, it rises at the end of that round")


func test_a_body_lying_in_sight_rises_when_the_spell_is_cast() -> void:
	var w := _world()
	var at := _fell(w, &"dokkaebi", 3)
	w.act(WAIT)
	assert_true(_risen(w).is_empty(), "no spell, no rising")
	w.act(_cast())
	assert_eq(_risen(w).size(), 1)
	assert_eq(_risen(w)[0].pos, at)


func test_a_body_rises_once() -> void:
	var w := _on()
	_fell(w, &"dokkaebi", 3)
	w.act(WAIT)
	for i in 3:
		w.act(WAIT)
	assert_eq(_risen(w).size(), 1)


func test_a_body_with_a_creature_on_it_rises_next_to_it() -> void:
	var w := _on()
	var at := _fell(w, &"dokkaebi", 3)
	FloorGen.spawn(w, &"jangseung", at).cooldown = 99
	w.act(WAIT)
	assert_eq(Grid.cheb(_risen(w)[0].pos, at), 1)


func test_a_body_with_no_room_stays_a_body_until_there_is() -> void:
	var w := _on()
	var at := _fell(w, &"dokkaebi", 3)
	var round_it: Array[Actor] = []
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		if at + d != w.player().pos:
			round_it.append(FloorGen.spawn(w, &"jangseung", at + d))
	w.cheats[&"halt"] = true
	w.act(WAIT)
	assert_true(_risen(w).is_empty())
	assert_true(w.bodies.has(at))
	w.actors.erase(round_it[0])
	w.act(WAIT)
	assert_eq(_risen(w).size(), 1)
	assert_false(w.bodies.has(at))


func test_a_fallen_risen_ally_gives_nothing_and_does_not_rise() -> void:
	var w := _on()
	_fell(w, &"dokkaebi", 3)
	w.act(WAIT)
	var up: Actor = _risen(w)[0]
	w.tails = 1
	var prey := w.player().prey
	w.hurt(up, up.hp)
	assert_eq(w.tails, 1, "no tail")
	assert_eq(w.player().prey, prey, "no form")
	assert_true(w.bodies.is_empty(), "no body")
	for i in 2:
		w.act(WAIT)
	assert_true(_risen(w).is_empty())


func test_a_creature_lost_to_the_sky_leaves_nothing_to_raise() -> void:
	var w := _on()
	var foe := FloorGen.spawn(w, &"dokkaebi", ME + E * 3)
	Fall.drop(w, foe, foe.pos + E)
	w.act(WAIT)
	assert_true(_risen(w).is_empty())


func test_dropping_stops_the_rising_and_keeps_what_rose() -> void:
	var w := _on()
	_fell(w, &"dokkaebi", 3)
	w.act(WAIT)
	w.act({t = &"dispel", kind = Guise.RAISE})
	assert_false(w.player().raise)
	assert_eq(_risen(w).size(), 1, "what rose stays up")
	var at := _fell(w, &"dokkaebi", 6)
	w.act(WAIT)
	assert_eq(_risen(w).size(), 1)
	assert_true(w.bodies.has(at))


## Stairs just east of Miho, and a risen ally beside her.
func _at_stairs(w: World) -> void:
	w.stairs = ME + E
	_fell(w, &"dokkaebi", 3)
	w.act(WAIT)
	_risen(w)[0].pos = ME - E


func test_climbing_ends_it_and_what_rose_stays_on_the_storey() -> void:
	var w := _on()
	_at_stairs(w)
	var copy := FloorGen.spawn(w, Cards.BUNSIN, ME + Vector2i(0, 1))
	var top := w.depth
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.depth, top + 1)
	assert_false(w.player().raise)
	assert_true(events.any(func(e): return e.t == &"unraise"))
	assert_true(_risen(w).is_empty(), "the risen stay below")
	assert_true(w.actors.any(func(a): return a.id == copy.id), "a copy comes along")
	assert_eq(w.storeys[top].actors.filter(Raise.risen).size(), 1)


func test_falling_ends_it() -> void:
	var w := _world()
	Storeys.leave(w)
	w.depth += 1
	w.act(_cast())
	w.set_tile(ME + E, World.SKY)
	Fall.drop(w, w.player(), ME + E)
	assert_eq(w.depth, 5)
	assert_false(w.player().raise)


func test_the_floor_cheat_ends_it() -> void:
	var w := _on()
	w.act({t = &"cheat", cmd = &"floor", depth = 2})
	assert_eq(w.depth, 2)
	assert_false(w.player().raise)


func test_back_on_a_storey_the_risen_still_stand_and_the_spell_is_off() -> void:
	var w := _on()
	_at_stairs(w)
	var top := w.depth
	w.act({t = &"move", dir = E})
	Storeys.leave(w)
	Storeys.enter(w, top)
	assert_false(w.player().raise)
	assert_eq(_risen(w).size(), 1)


func test_a_forecast_equals_the_round() -> void:
	var w := _on()
	var at := _fell(w, &"dokkaebi", 3)
	var f := Forecast.of(w, WAIT)
	var events := w.act(WAIT)
	assert_eq(f.events, events)
	assert_eq(f.allies, [at] as Array[Vector2i], "the tile a risen ally stands on")
	assert_eq(f.after.actors.filter(Raise.risen).size(), _risen(w).size())


func test_a_forecast_does_not_give_away_a_body_she_never_saw() -> void:
	var w := _on()
	for y in range(1, Grid.H - 1):
		w.tiles[Grid.index(Vector2i(ME.x + 2, y))] = World.WALL
	w.sense()
	var at := _fell(w, &"dokkaebi", 4)
	assert_false(w.known_clone().bodies.has(at))


func test_a_clone_keeps_the_spell_and_a_change_to_it_stays_its_own() -> void:
	var w := _on()
	var c := w.clone()
	assert_true(c.player().raise)
	c.player().raise = false
	assert_true(w.player().raise)


func test_a_save_replays_a_rising() -> void:
	var run := SaveGame.new(SAVE, 11)
	var w := World.create(11)
	var foe: Actor = w.actors.filter(func(a): return a.faction == Actor.HEAVEN)[0]
	var actions := [
		{t = &"cheat", cmd = &"cards"},
		{t = &"cheat", cmd = &"tails"},
		{t = &"cheat", cmd = &"reveal"},
		{t = &"cheat", cmd = &"damage", id = foe.id, n = foe.hp},
		_cast(),
		WAIT,
		{t = &"dispel", kind = Guise.RAISE},
		WAIT,
	]
	for action in actions:
		assert_true(w.can(action), str(action))
		w.act(action)
		run.record(action, 0, false)
	assert_eq(_risen(w).size(), 1)
	var back := SaveGame.load_from(SAVE)
	assert_not_null(back)
	assert_true(back.replay())
	var look := func(a: Actor) -> Array: return [a.id, a.pos, a.kind, a.hp]
	assert_eq(_risen(back.world).map(look), _risen(w).map(look))
	assert_false(back.world.player().raise)
	assert_eq(back.world.round_no, w.round_no)
	assert_eq(back.world.rng.state, w.rng.state)


func test_each_event_of_it_is_told_with_a_sound() -> void:
	var w := _world()
	var before := w.clone()
	var cast := w.act(_cast())
	assert_false(Messages.of(before, w, cast).is_empty())
	assert_true(cast.any(func(e): return e.t == &"raise" and Sfx.sound_of(e) != &""))
	_fell(w, &"dokkaebi", 3)
	before = w.clone()
	var rise := w.act(WAIT)
	assert_false(Messages.of(before, w, rise).is_empty())
	assert_true(rise.any(func(e): return e.t == &"ally" and Sfx.sound_of(e) != &""))
	before = w.clone()
	var drop := w.act({t = &"dispel", kind = Guise.RAISE})
	assert_false(Messages.of(before, w, drop).is_empty())
	assert_true(drop.any(func(e): return e.t == &"unraise" and Sfx.sound_of(e) != &""))
