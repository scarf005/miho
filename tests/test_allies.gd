extends GutTest
## Allies: a creature of Miho's side other than her fights on its own, draws fire,
## trades places with her and goes by the stairs only from beside her. 분신 is the
## ally her spell makes: a copy with tails of its own and a spell she threw.

const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)
const S := Vector2i(0, 1)
const WAIT := {t = &"wait"}
const ME := Vector2i(10, 8)
const BUNSIN := [Cards.FOX, Cards.EARTH, Cards.FIRE, Cards.WOOD]
## A spell a copy can pay for, and one it cannot.
const CHEAP := [Cards.ORB, Cards.FIRE]
const DEAR := [Cards.ORB, Cards.ORB, Cards.ORB, Cards.ORB]
const PATH := "user://test_allies.cfg"


func after_each() -> void:
	SaveGame.new(PATH).erase()


## A lit open hall, Miho at ME with tails to spare and every talisman.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
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
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = 2
	w.tails = 9
	w.tail_bonus = 9
	w.cards.assign(Cards.ALL)
	w.rng.seed = 7
	w._changed()
	return w


## A copy on `at`, its spell `spell` (none when empty).
func _copy(w: World, at: Vector2i, spell := []) -> Actor:
	var a := FloorGen.spawn(w, Cards.BUNSIN, at)
	a.magic.imprint.assign(spell)
	return a


## A creature that stands fixed and takes many blows, to be fought.
func _post(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", at)
	a.hp = 40
	a.magic.cooldown = 99
	return a


func _hunter(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.alert = Actor.HUNT
	return a


func _cast(w: World, cards: Array, dir := E) -> Array[Dictionary]:
	return w.act({t = &"cast", spells = [{cards = cards, dir = dir}]})


func _can_cast(w: World, cards: Array, dir: Vector2i) -> bool:
	return w.can({t = &"cast", spells = [{cards = cards, dir = dir}]})


func _rounds(w: World, n: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in n:
		events.append_array(w.act(WAIT))
	return events


## The copies of Miho that stand, oldest first.
func _copies(w: World) -> Array:
	var out := w.actors.filter(func(a): return a.ally() and a.kind == Cards.BUNSIN)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


## The first of the eight lines a copy can be cast along, with the tails for it.
func _free(w: World) -> Vector2i:
	w.tails = w.max_tails()
	return Grid.DIRS.filter(func(d): return _can_cast(w, BUNSIN, d))[0]


func _stand(w: World) -> void:
	_cast(w, BUNSIN, _free(w))


func _hurt(events: Array[Dictionary], a: Actor) -> bool:
	return events.any(func(e): return e.t == &"hurt" and e.id == a.id)


func test_miho_pays_the_table_price_and_the_copy_stands_on_the_aimed_tile() -> void:
	var w := _world()
	var before := w.tails
	var events := _cast(w, BUNSIN, E)
	assert_eq(before - w.tails, Spell.price(BUNSIN.size()))
	var copy := w.actor_at(ME + E)
	assert_not_null(copy)
	assert_true(copy.ally())
	assert_eq(copy.magic.mana, Bunsin.TAILS, "its tails are its own")
	assert_true(events.any(func(e): return e.t == &"ally" and e.id == copy.id))


func test_earth_water_and_fire_make_no_copy() -> void:
	var w := _world()
	var action := {
		t = &"cast", spells = [{cards = [Cards.EARTH, Cards.WATER, Cards.FIRE], dir = E}]
	}
	if w.can(action):
		w.act(action)
	assert_true(_copies(w).is_empty())


func test_a_third_copy_stands_on_the_aimed_tile_and_the_oldest_goes() -> void:
	var w := _world()
	_stand(w)
	_stand(w)
	var kept := _copies(w)
	assert_eq(kept.size(), 2)
	var dir := _free(w)
	var events := _cast(w, BUNSIN, dir)
	var now := _copies(w)
	assert_eq(now.size(), Bunsin.MOST)
	assert_eq(now[0].id, kept[1].id, "the second is the oldest now")
	assert_false(w.actors.has(kept[0]), "the first is gone")
	assert_eq(w.actor_at(ME + dir), now[1], "the new one stands where it was aimed")
	var gone := events.filter(func(e): return e.t == &"die" and e.id == kept[0].id)
	assert_eq(gone.size(), 1)
	assert_true(gone[0].gone)
	assert_false(gone[0].foe)
	assert_eq(w.tails, w.max_tails() - Spell.price(BUNSIN.size()), "a vanished copy gives no tail")


func test_a_copy_that_came_upstairs_counts_and_the_lowest_id_goes_first() -> void:
	var w := _world()
	var old := _copy(w, ME + E)
	var mid := _copy(w, ME + W)
	w.actors.erase(old)
	w.actors.append(old)
	_stand(w)
	assert_false(w.actors.has(old), "the first to come is the first to go, wherever it is listed")
	assert_true(w.actors.has(mid))
	assert_eq(_copies(w).size(), Bunsin.MOST)


func test_the_forecast_of_a_third_copy_is_the_cast() -> void:
	var w := _world()
	_stand(w)
	_stand(w)
	var oldest: Actor = _copies(w)[0]
	var dir := _free(w)
	var action := {t = &"cast", spells = [{cards = BUNSIN, dir = dir}]}
	var f := Forecast.of(w, action)
	assert_true(f.deaths.has(oldest.id))
	assert_eq(f.allies, [ME + dir] as Array[Vector2i])
	assert_eq(str(w.clone().act(action)), str(w.act(action)))


func test_the_log_and_the_hover_tell_a_copy_leaving_and_how_many_stand() -> void:
	var w := _world()
	w.sense()
	_stand(w)
	_stand(w)
	var before := w.clone()
	var dir := _free(w)
	var lines := Messages.of(before, w, _cast(w, BUNSIN, dir)).map(Messages.plain)
	assert_has(lines, "분신이 사라졌다")
	assert_string_contains(str(SpellInfo.combo(Cards.BUNSIN)), "최대 수")


func test_the_copy_needs_a_free_tile_along_a_line() -> void:
	var w := _world()
	_hunter(w, ME + E)
	w.set_tile(ME + S, World.WALL)
	assert_false(_can_cast(w, BUNSIN, E), "taken")
	assert_false(_can_cast(w, BUNSIN, S), "a wall")
	assert_false(_can_cast(w, BUNSIN, Vector2i.ZERO), "on herself")
	assert_true(_can_cast(w, BUNSIN, W))


func test_the_copy_takes_the_last_spell_she_threw_that_its_tails_pay_for() -> void:
	var w := _world()
	_cast(w, BUNSIN, E)
	assert_true(w.actor_at(ME + E).magic.imprint.is_empty(), "none thrown yet")
	_cast(w, CHEAP, W)
	_cast(w, DEAR, W)
	assert_gt(Spell.make(DEAR).cost(), Bunsin.TAILS)
	assert_false(Bunsin.imprints(Spell.make(BUNSIN), E), "it never takes its own spell")
	w.tails = w.max_tails()
	_cast(w, BUNSIN, Vector2i(0, -1))
	assert_eq(w.actor_at(ME + Vector2i(0, -1)).magic.imprint, Spell.make(CHEAP).cards)


func test_a_copy_with_no_spell_walks_to_a_foe_and_claws_it() -> void:
	var w := _world()
	var copy := _copy(w, ME + E)
	var foe := _post(w, ME + Vector2i(5, 0))
	var events := _rounds(w, 5)
	assert_eq(Grid.cheb(copy.pos, foe.pos), 1, "it walked up")
	assert_true(_hurt(events, foe), "and clawed")


func test_a_foe_takes_on_an_ally_nearer_than_miho_and_goes_back_to_her() -> void:
	var w := _world()
	var foe := _hunter(w, ME + Vector2i(6, 0))
	var copy := _copy(w, ME + Vector2i(4, 0))
	w.act(WAIT)
	assert_eq(foe.ties.rival, copy.id, "the nearer draws it")
	copy.pos = Vector2i(2, 2)
	foe.pos = ME + Vector2i(2, 0)
	w._changed()
	w.act(WAIT)
	assert_eq(foe.ties.rival, 0, "she is nearer now")
	assert_eq(foe.alert, Actor.HUNT)


func test_an_ally_takes_the_blows_of_a_foe_in_her_place() -> void:
	var w := _world()
	var copy := _copy(w, ME + Vector2i(6, 0))
	copy.hp = 99
	var foe := FloorGen.spawn(w, &"oedari", ME + Vector2i(7, 0))
	foe.alert = Actor.HUNT
	var hp := w.player().hp
	_rounds(w, 5)
	assert_lt(copy.hp, 99, "the foe struck it")
	assert_eq(w.player().hp, hp, "and not her")


func test_a_homing_spell_of_a_foe_chases_an_ally() -> void:
	var w := _world()
	var copy := _copy(w, ME + Vector2i(6, 0))
	var caster := _hunter(w, ME + Vector2i(9, 0))
	Cast.cast(w, caster, Spell.make([Cards.FOX]), W)
	assert_eq(w.shots.back().target, copy.id)


func test_a_copy_casts_its_spell_and_spends_its_own_tails() -> void:
	var w := _world()
	var copy := _copy(w, ME + E, CHEAP)
	var foe := _post(w, ME + Vector2i(6, 0))
	var tails := w.tails
	w.act(WAIT)
	assert_false(copy.magic.intent.is_empty(), "it charges")
	assert_eq(copy.magic.mana, Bunsin.TAILS - Spell.price(CHEAP.size()))
	var events := w.act(WAIT)
	var thrown := events.filter(func(e): return e.t == &"spawn" and e.faction == Actor.FOX)
	assert_eq(thrown.size(), 1)
	assert_eq(w.tails, tails, "she pays nothing")
	assert_true(_hurt(events + _rounds(w, 6), foe), "it lands")


func test_at_no_tails_a_copy_claws_and_its_tails_grow_back() -> void:
	var w := _world()
	var copy := _copy(w, ME + E, CHEAP)
	copy.magic.mana = 0
	var foe := _post(w, copy.pos + E)
	var events := w.act(WAIT)
	assert_true(copy.magic.intent.is_empty(), "nothing to pay with")
	assert_true(_hurt(events, foe), "so it claws")
	_rounds(w, World.TAIL_REGROW)
	assert_gt(copy.magic.mana + copy.magic.regrow, 0, "they grow back")


func test_a_spell_too_dear_for_the_tails_left_is_not_cast() -> void:
	var w := _world()
	var copy := _copy(w, ME + E, CHEAP)
	copy.magic.mana = Spell.price(CHEAP.size()) - 1
	copy.magic.regrow = 0
	_post(w, ME + Vector2i(6, 0))
	w.act(WAIT)
	assert_true(copy.magic.intent.is_empty())


func test_a_copy_with_tails_stands_off_and_one_without_walks_in() -> void:
	var w := _world()
	var copy := _copy(w, ME + E, CHEAP)
	var foe := _post(w, copy.pos + Vector2i(2, 1))
	w.act(WAIT)
	assert_gt(Grid.cheb(copy.pos, foe.pos), 1, "it does not walk up to claw")
	for i in 4:
		copy.magic.mana = 0
		copy.magic.intent.clear()
		w.act(WAIT)
	assert_eq(Grid.cheb(copy.pos, foe.pos), 1, "with none left it walks up")


func test_an_ally_holds_back_a_spell_that_would_catch_her() -> void:
	var w := _world()
	var copy := _copy(w, ME + W, CHEAP)
	_post(w, ME + Vector2i(3, 0))
	w.act(WAIT)
	assert_true(copy.magic.intent.is_empty(), "she stands on the line")
	assert_eq(copy.magic.mana, Bunsin.TAILS)


func test_a_shot_of_an_ally_turns_a_foe_on_the_ally_and_not_on_miho() -> void:
	var w := _world()
	var copy := _copy(w, ME + Vector2i(5, 0), CHEAP)
	var foe := FloorGen.spawn(w, &"dokkaebi", copy.pos + Vector2i(3, 0))
	var s := Shot.new()
	s.caster = copy.id
	s.faction = Actor.FOX
	s.origin = copy.pos
	Mind.struck(w, foe, s)
	assert_eq(foe.ties.rival, copy.id)
	assert_ne(foe.alert, Actor.HUNT)


func test_the_forecast_of_a_round_with_an_ally_is_the_round() -> void:
	var w := _world()
	_copy(w, ME + Vector2i(2, 0), CHEAP)
	_hunter(w, ME + Vector2i(8, 0))
	for i in 6:
		var told := w.clone().act(WAIT)
		assert_eq(str(told), str(w.act(WAIT)), "round %d" % i)


func test_the_forecast_marks_where_the_copy_steps_out() -> void:
	var f := Forecast.of(_world(), {t = &"cast", spells = [{cards = BUNSIN, dir = E}]})
	assert_eq(f.allies, [ME + E] as Array[Vector2i])


func test_a_saved_run_with_a_copy_replays_to_the_same_world() -> void:
	var run := SaveGame.new(PATH, 114)
	var w := World.create(114)
	var plan: Array[Dictionary] = [
		{t = &"cheat", cmd = &"cards"},
		{t = &"cheat", cmd = &"tails"},
		{t = &"cheat", cmd = &"god"},
	]
	plan.append({t = &"cast", spells = [{cards = CHEAP, dir = Grid.DIRS[0]}]})
	for d in Grid.DIRS:
		plan.append({t = &"cast", spells = [{cards = BUNSIN, dir = d}]})
	plan.append_array([WAIT, WAIT, WAIT, WAIT])
	var gone := 0
	for action in plan:
		if w.can(action):
			gone += (
				w.act(action).filter(func(e): return e.t == &"die" and e.get("gone", false)).size()
			)
			run.record(action, w.round_no, w.outcome != &"")
			assert_lte(_copies(w).size(), Bunsin.MOST)
	assert_gt(gone, 0, "a third pushed one out")
	var back := SaveGame.load_from(PATH)
	assert_true(back.replay())
	var state := func(a: Actor) -> Array: return [a.id, a.pos, a.hp, a.magic.mana, a.magic.imprint]
	assert_eq(str(back.world.actors.map(state)), str(w.actors.map(state)))
	assert_eq(back.world.rng.state, w.rng.state)


func test_she_trades_places_with_an_ally_she_walks_into() -> void:
	var w := _world()
	var copy := _copy(w, ME + E)
	var hp := copy.hp
	assert_true(w.can({t = &"move", dir = E}))
	w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, ME + E)
	assert_eq(copy.hp, hp, "no claw")
	assert_eq(Grid.cheb(copy.pos, w.player().pos), 1, "it stays by her")


func test_an_ally_held_fast_does_not_trade_places() -> void:
	var w := _world()
	var copy := _copy(w, ME + E)
	copy.ailments.rooted = 3
	assert_false(w.can({t = &"move", dir = E}))
	copy.ailments.rooted = 0
	copy.ailments.stunned = 3
	assert_false(w.can({t = &"move", dir = E}))


func test_an_ally_right_behind_her_comes_up_the_stairs_and_a_far_one_stays_on_its_storey() -> void:
	var w := _world()
	var near := _copy(w, ME - S)
	var far := _copy(w, ME - S * (Storeys.FOLLOW + 1))
	w.stairs = ME + S
	var depth := w.depth
	w.act({t = &"move", dir = S})
	assert_eq(w.depth, depth + 1)
	var came := w.actor(near.id)
	assert_not_null(came, "it came along")
	assert_eq(Grid.cheb(came.pos, w.player().pos), 1)
	assert_null(w.actor(far.id), "too far")
	assert_true(w.storeys[depth].actors.any(func(a): return a.id == far.id), "it stays")


func test_an_ally_keeps_up_with_her_so_that_it_is_by_her_at_the_stairs() -> void:
	var w := _world()
	var copy := _copy(w, ME + W)
	for i in 5:
		w.act({t = &"move", dir = E})
		assert_eq(Grid.cheb(copy.pos, w.player().pos), 1)


func test_an_ally_does_not_stop_a_walk() -> void:
	var w := _world()
	_copy(w, ME + Vector2i(2, 0))
	assert_true(Travel.in_sight(w).is_empty(), "no creature of heaven in sight")
	var before := w.clone()
	var events := w.act(WAIT)
	assert_false(Travel.interrupted(before, w, events, {}))


func test_a_walk_goes_through_an_ally_that_can_trade_places() -> void:
	var w := _world()
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen.resize(w.tiles.size())
	w.seen.fill(1)
	var copy := _copy(w, ME + E)
	assert_true(Travel.walkable(w, copy.pos))
	copy.ailments.rooted = 2
	assert_false(Travel.walkable(w, copy.pos))


func test_an_ally_opens_a_door_and_she_cannot_shut_it_on_the_ally() -> void:
	var w := _world()
	for y in range(1, Grid.H - 1):
		w.set_tile(Vector2i(ME.x + 2, y), World.WALL)
	var door := ME + Vector2i(2, 0)
	w.set_tile(door, World.DOOR)
	var copy := _copy(w, ME + E)
	var foe := _post(w, ME + Vector2i(4, 0))
	copy.ties.rival = foe.id
	copy.ties.grudge = 9
	copy.ties.rival_at = foe.pos
	_rounds(w, 2)
	assert_eq(w.tile(door), World.DOOR_OPEN)
	assert_eq(copy.pos, door)
	assert_false(w.can({t = &"close", dir = door - w.player().pos}))


func test_a_kill_by_an_ally_gives_a_tail_and_a_form_as_any_fall() -> void:
	var w := _world()
	var copy := _copy(w, ME + E)
	var foe := FloorGen.spawn(w, &"dokkaebi", copy.pos + E)
	foe.hp = 1
	w.tails = 1
	var events := w.act(WAIT)
	assert_true(events.any(func(e): return e.t == &"die" and e.id == foe.id and e.foe))
	assert_eq(w.tails, 2)
	assert_eq(w.player().prey, &"dokkaebi")


func test_a_fallen_ally_gives_nothing_and_the_run_goes_on() -> void:
	var w := _world()
	var copy := _copy(w, ME + E)
	w.tails = 1
	Harm.hurt(w, copy, copy.hp)
	assert_eq(w.tails, 1)
	assert_eq(w.player().prey, &"")
	assert_eq(w.outcome, &"")
	assert_false(w.bodies.has(ME + E))
	w.act(WAIT)
	assert_null(w.actor(copy.id))


func test_an_ally_pushed_into_the_sky_is_gone_and_she_stays_on_the_storey() -> void:
	var w := _world()
	var copy := _copy(w, ME + E)
	var depth := w.depth
	w.set_tile(copy.pos + E, World.SKY)
	w.tails = 1
	w.push(copy, E, 1)
	assert_false(copy.alive())
	assert_eq(w.depth, depth)
	assert_eq(w.tails, 1)


func test_the_log_tells_the_copy_appearing_and_its_spell_as_its_own() -> void:
	var w := _world()
	w.sense()
	var before := w.clone()
	var lines := Messages.of(before, w, _cast(w, BUNSIN, E)).map(Messages.plain)
	assert_has(lines, "분신이 나타났다")
	var copy := w.actor_at(ME + E)
	copy.magic.imprint.assign(CHEAP)
	var foe := _post(w, ME + Vector2i(4, 0))
	var told := []
	for i in 6:
		before = w.clone()
		told.append_array(Messages.of(before, w, w.act(WAIT)).map(Messages.plain))
	assert_lt(foe.hp, 40, "it landed")
	assert_true(
		told.any(func(l): return l.begins_with("분신의 ") and l.contains("장승이 피해를")), str(told)
	)


func test_the_hover_of_a_copy_counts_the_tails_it_has_left() -> void:
	var w := _world()
	var copy := _copy(w, ME + E, CHEAP)
	copy.magic.mana = 2
	var text := str(Info.creature(w, copy))
	assert_string_contains(text, "꼬리: 2/%d" % Bunsin.TAILS)
	assert_false(text.contains("당신을"), "what it sees of her changes nothing")


func test_copies_that_come_upstairs_to_copies_left_there_are_cut_to_the_most() -> void:
	var w := _world()
	_copy(w, ME + E)
	_copy(w, ME + W)
	var party: Array[Actor] = [_copy(w, ME + E * 2), _copy(w, ME + W * 2)]
	w.actors.assign(w.actors.filter(func(a): return not party.has(a)))
	Storeys.bring(w, party)
	var left := _copies(w).filter(func(a): return a.alive())
	assert_eq(left, party, "the oldest, left upstairs, go")


func test_trading_places_on_a_rotten_board_drops_her_through_it() -> void:
	var w := _world()
	var ally := _copy(w, ME + E)
	w.set_tile(ME + E, World.BOARD_ROTTEN)
	var depth := w.depth
	w.act({t = &"move", dir = E})
	assert_eq(ally.pos, ME)
	assert_eq(w.depth, depth - 1, "the board that gave way under her let her fall")


func test_trading_places_off_a_rotten_board_drops_the_ally_through_it() -> void:
	var w := _world()
	var ally := _copy(w, ME + E)
	w.set_tile(ME, World.BOARD_ROTTEN)
	w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, ME + E)
	assert_false(ally.alive(), "the board gave way under the ally")


func test_after_a_fall_a_trade_does_not_read_the_old_tile_on_the_new_storey() -> void:
	var w := _world()
	var ally := _copy(w, ME + E)
	w.set_tile(ally.pos, World.SKY)
	Fall.traded(w, ally, w.player(), w.depth + 1)
	assert_true(ally.alive())


func test_a_creature_a_trap_killed_in_the_trade_does_not_fall_as_well() -> void:
	var w := _world()
	var foe := _hunter(w, ME + E)
	foe.hp = 0
	w.set_tile(foe.pos, World.SKY)
	w.tails = 0
	Fall.traded(w, foe, w.player(), w.depth)
	assert_eq(w.tails, 0, "no tail for a fall that did not happen")
