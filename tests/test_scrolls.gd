extends GutTest
## A fallen creature drops a scroll for its talisman; Miho gets the talisman by
## coming onto the scroll.

const E := Vector2i(1, 0)
const EDGE := 25
const ROW := 8
const FOE := Vector2i(12, ROW)


## An open hall whose east part is sky from x = EDGE, Miho at (10, 8).
func _world() -> World:
	var w := World.new()
	w.rng.seed = 11
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR if x < EDGE else World.SKY
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(10, ROW)
	w.actors.append(me)
	w.depth = 2
	w.tails = w.max_tails()
	w.sense()
	return w


func _foe(w: World, at := FOE, kind := &"bulgae") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.magic.cooldown = 99
	return a


func _kill(w: World, a: Actor) -> void:
	w.events = []
	Harm.hurt(w, a, a.hp)


func _scroll(w: World) -> Dictionary:
	return w.sites.filter(func(s): return s.kind == &"scroll").front()


func _step_onto(w: World, p: Vector2i) -> Array[Dictionary]:
	w.player().pos = p - E
	return w.act({t = &"move", dir = E})


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


func test_a_kill_leaves_a_scroll_and_no_talisman() -> void:
	var w := _world()
	var foe := _foe(w)
	assert_eq(foe.info().drop, Cards.FIRE)
	_kill(w, foe)
	assert_false(w.cards.has(Cards.FIRE))
	assert_true(_of(w.events, &"card").is_empty())
	assert_eq(_scroll(w), {kind = &"scroll", at = FOE, card = Cards.FIRE})
	assert_eq(_of(w.events, &"scroll"), [{t = &"scroll", card = Cards.FIRE, at = FOE}])


func test_stepping_onto_the_scroll_gives_the_talisman_once() -> void:
	var w := _world()
	_kill(w, _foe(w))
	var events := _step_onto(w, FOE)
	assert_has(w.cards, Cards.FIRE)
	assert_eq(_of(events, &"card"), [{t = &"card", card = Cards.FIRE, at = FOE}])
	assert_true(w.sites.is_empty())
	w.cards.erase(Cards.FIRE)
	w.player().pos = FOE - E
	w.act({t = &"move", dir = E})
	assert_false(w.cards.has(Cards.FIRE), "the scroll is gone")


func test_a_leap_onto_the_scroll_gives_it() -> void:
	var w := _world()
	w.cards.append_array([Cards.WATER, Cards.WOOD, Cards.FIRE])
	w.tails = 5
	var leap := [Cards.WATER, Cards.WOOD, Cards.FIRE]
	var to := Leap.landing(w, w.player().pos, E, Spell.make(leap).leap())
	w.sites.append({kind = &"scroll", at = to, card = Cards.EARTH})
	var events := w.act({t = &"cast", spells = [{cards = leap, dir = E}]})
	assert_eq(w.player().pos, to)
	assert_eq(_of(events, &"card"), [{t = &"card", card = Cards.EARTH, at = to}])
	assert_true(w.sites.is_empty())


func test_a_swap_onto_the_scroll_gives_it() -> void:
	var w := _world()
	var me := w.player()
	var to := me.pos + Vector2i(3, 0)
	w.sites.append({kind = &"scroll", at = to, card = Cards.EARTH})
	var shot := Shot.new()
	shot.caster = me.id
	shot.pos = to
	shot.spell = Spell.make([Cards.ORB, Cards.WATER, Cards.WOOD, Cards.FIRE])
	Leap.swap(w, shot, null)
	assert_eq(me.pos, to)
	assert_has(w.cards, Cards.EARTH)


func test_a_push_onto_the_scroll_gives_it() -> void:
	var w := _world()
	var me := w.player()
	w.sites.append({kind = &"scroll", at = me.pos + E * 2, card = Cards.EARTH})
	w.push(me, E, 2)
	assert_has(w.cards, Cards.EARTH)


func test_a_creature_stepping_onto_the_scroll_leaves_it_and_fire_and_water_spare_it() -> void:
	var w := _world()
	_kill(w, _foe(w))
	Walk.move(w, _foe(w, FOE + Vector2i(0, 2)), FOE)
	Terrain.ignite(w, FOE, true)
	w.set_tile(FOE, World.POND)
	assert_eq(_scroll(w).at, FOE)
	assert_false(w.cards.has(Cards.FIRE))


func test_a_second_kill_drops_nothing_once_the_talisman_is_held() -> void:
	var w := _world()
	w.cards.append(Cards.FIRE)
	_kill(w, _foe(w))
	assert_true(w.sites.is_empty())
	assert_true(_of(w.events, &"scroll").is_empty())
	assert_eq(w.cards.count(Cards.FIRE), 1)


func test_a_scroll_for_a_held_talisman_is_removed_silently() -> void:
	var w := _world()
	w.sites.append({kind = &"scroll", at = FOE, card = Cards.FIRE})
	w.cards.append(Cards.FIRE)
	var events := _step_onto(w, FOE)
	assert_true(w.sites.is_empty())
	assert_true(_of(events, &"card").is_empty())
	assert_eq(w.cards.count(Cards.FIRE), 1)


func test_a_creature_over_sky_drops_it_on_the_nearest_floor() -> void:
	var w := _world()
	var over := Vector2i(EDGE + 2, ROW)
	_kill(w, _foe(w, over))
	var at: Vector2i = _scroll(w).at
	assert_eq(w.tile(at), World.FLOOR)
	assert_eq(Grid.cheb(at, over), 3, "the nearest floor")
	assert_eq(_of(w.events, &"scroll")[0].at, at)


func test_a_creature_that_falls_into_the_sky_drops_it_where_it_stood() -> void:
	var w := _world()
	var edge := Vector2i(EDGE - 1, ROW)
	var foe := _foe(w, edge)
	w.events = []
	w.push(foe, E, 3)
	assert_false(foe.alive())
	assert_eq(_scroll(w).at, edge)
	assert_false(w.cards.has(Cards.FIRE))
	assert_eq(_of(w.events, &"scroll").size(), 1)


func test_a_tile_that_cannot_hold_it_sends_it_to_the_nearest_free_one() -> void:
	var w := _world()
	w.stairs = FOE
	w.peaches.append(FOE + Vector2i(0, -1))
	w.sites.append({kind = &"scroll", at = FOE + Vector2i(0, 1), card = Cards.WATER})
	w.traps[FOE + Vector2i(-1, 0)] = World.TRAP_ALARM
	_kill(w, _foe(w))
	var fire: Vector2i = w.sites.filter(func(s): return s.card == Cards.FIRE)[0].at
	assert_eq(Grid.cheb(fire, FOE), 1)
	for p: Vector2i in [FOE, FOE + Vector2i(0, -1), FOE + Vector2i(0, 1), FOE + Vector2i(-1, 0)]:
		assert_ne(fire, p)


func test_no_tile_to_hold_it_drops_nothing() -> void:
	var w := _world()
	w.tiles.fill(World.WALL)
	var me := w.player()
	w.tiles[Grid.index(me.pos)] = World.FLOOR
	w.tiles[Grid.index(FOE)] = World.FLOOR
	w.stairs = FOE
	_kill(w, _foe(w))
	assert_true(w.sites.is_empty())
	assert_true(_of(w.events, &"scroll").is_empty())


func test_the_scroll_stays_on_its_storey_when_miho_falls_and_returns() -> void:
	var w := _world()
	_kill(w, _foe(w))
	var kept := _scroll(w)
	assert_eq(_scroll(w.clone()), kept)
	assert_eq(_scroll(w.known_clone()), kept)
	Storeys.leave(w)
	Storeys.enter(w, 1)
	assert_true(Scrolls.spots(w).is_empty())
	Storeys.leave(w)
	Storeys.enter(w, 2)
	assert_eq(_scroll(w), kept)


func test_a_forecast_equals_the_real_pickup() -> void:
	var w := _world()
	_kill(w, _foe(w))
	w.player().pos = FOE - E
	var ahead := w.preview({t = &"move", dir = E})
	assert_has(ahead.cards, Cards.FIRE)
	assert_true(ahead.sites.is_empty())
	assert_eq(_scroll(w).at, FOE, "the real world is untouched")
	w.act({t = &"move", dir = E})
	assert_eq(w.cards, ahead.cards)
	assert_eq(w.sites, ahead.sites)


func test_a_forecast_of_a_kill_drops_what_the_real_kill_drops() -> void:
	var w := _world()
	var foe := _foe(w)
	var copy := w.clone()
	_kill(w, foe)
	_kill(copy, copy.actor(foe.id))
	assert_eq(copy.sites, w.sites)
	assert_eq(copy.events, w.events)


func test_the_log_tells_the_scroll_after_the_creature_falls() -> void:
	var w := _world()
	var foe := _foe(w)
	w.sense()
	var before := w.clone()
	_kill(w, foe)
	w.sense()
	var lines: Array[String] = []
	lines.assign(Messages.of(before, w, w.events).map(Messages.plain))
	assert_eq(lines.slice(-2), ["불개가 쓰러졌다", "불 주문서가 떨어졌다"] as Array[String])
	var far := w.clone()
	far.seen.fill(0)
	var told: Array[String] = []
	told.assign(Messages.of(far, far, w.events).map(Messages.plain))
	assert_false(told.has("불 주문서가 떨어졌다"), "not told out of sight")


func test_the_scroll_sounds_as_a_page_and_the_pickup_as_a_card() -> void:
	assert_eq(Sfx.sound_of({t = &"scroll", card = Cards.FIRE, at = FOE}), &"page")
	assert_eq(Sfx.sound_of({t = &"card", card = Cards.FIRE, at = FOE}), &"card")


func test_the_hover_names_the_scroll_and_nothing_more() -> void:
	var w := _world()
	w.sites.append({kind = &"scroll", at = FOE, card = Cards.WATER})
	assert_eq(Info.plain(Info.terrain_facts(w, FOE)), "물 주문서")


func test_exploring_fetches_a_known_scroll_before_the_stairs() -> void:
	var w := _world()
	w.known.fill(1)
	w.stairs = Vector2i(5, ROW)
	w.sites.append({kind = &"scroll", at = FOE, card = Cards.FIRE})
	assert_eq(Travel.explore_step(w, Travel.search(w)), E)
	w.sites.clear()
	assert_eq(Travel.explore_step(w, Travel.search(w)), -E, "otherwise it walks to the stairs")


func test_a_scroll_is_spotted_when_it_first_comes_into_sight() -> void:
	var w := _world()
	w.sites.append({kind = &"scroll", at = FOE, card = Cards.FIRE})
	var before := w.clone()
	before.known.fill(0)
	assert_eq(Perceived.spotted(before, w), [FOE] as Array[Vector2i])
	assert_eq(Perceived.spotted(w, w), [] as Array[Vector2i], "not again")


func test_the_observation_lists_a_scroll_where_it_lists_peaches() -> void:
	var w := _world()
	w.sites.append({kind = &"scroll", at = FOE, card = Cards.FIRE})
	w.known.fill(1)
	var rows: Array[String] = []
	rows.assign(Array(Observation.text(w).split("\n")))
	var row: String = rows.filter(func(r: String): return r.begins_with("%2d " % ROW))[0]
	assert_eq(row[3 + FOE.x], Palette.SCROLL)


# --- when the ground under it goes ---------------------------------------------


## A lone plank out in the sky, two tiles from the hall.
func _plank(w: World) -> Vector2i:
	var at := Vector2i(EDGE + 1, ROW)
	w.set_tile(at, World.BOARD)
	return at


func _burn_out(w: World, at: Vector2i) -> void:
	Terrain.ignite(w, at)
	for i in World.BURN_ROUNDS:
		Terrain.burn(w, [])


func test_a_scroll_on_a_plank_that_burns_moves_off_the_sky_and_can_be_taken() -> void:
	var w := _world()
	var plank := _plank(w)
	w.sites.append({kind = &"scroll", at = plank, card = Cards.FIRE})
	_burn_out(w, plank)
	assert_eq(w.tile(plank), World.SKY)
	var at: Vector2i = _scroll(w).at
	assert_true(w.vacant(at), "she can stand on it")
	assert_eq(Grid.cheb(at, plank), 2, "the nearest floor")
	_step_onto(w, at)
	assert_has(w.cards, Cards.FIRE)


func test_a_peach_on_a_plank_that_burns_moves_off_the_sky_and_can_be_eaten() -> void:
	var w := _world()
	var plank := _plank(w)
	w.peaches.append(plank)
	_burn_out(w, plank)
	assert_eq(w.peaches.size(), 1)
	var at := w.peaches[0]
	assert_true(w.vacant(at), "she can stand on it")
	assert_eq(Grid.cheb(at, plank), 2, "the nearest floor")
	w.player().hp = 1
	_step_onto(w, at)
	assert_true(w.peaches.is_empty())
	assert_gt(w.player().hp, 1)


func test_two_things_on_a_burnt_plank_do_not_land_on_one_tile() -> void:
	var w := _world()
	var plank := _plank(w)
	w.sites.append({kind = &"scroll", at = plank, card = Cards.FIRE})
	w.sites.append({kind = &"scroll", at = plank, card = Cards.WATER})
	w.peaches.append(plank)
	_burn_out(w, plank)
	var spots := Scrolls.spots(w) + w.peaches
	assert_eq(spots.size(), 3)
	for at: Vector2i in spots:
		assert_true(w.vacant(at), str(at))
		assert_eq(spots.count(at), 1, str(at))


func test_with_no_tile_to_hold_it_a_scroll_and_a_peach_on_a_burnt_plank_are_lost() -> void:
	var w := _world()
	w.tiles.fill(World.SKY)
	w.set_tile(w.player().pos, World.FLOOR)
	var plank := _plank(w)
	w.sites.append({kind = &"scroll", at = plank, card = Cards.FIRE})
	w.peaches.append(plank)
	_burn_out(w, plank)
	assert_true(w.sites.is_empty())
	assert_true(w.peaches.is_empty())


func test_a_forecast_of_the_plank_burning_moves_the_scroll_as_the_round_does() -> void:
	var w := _world()
	var plank := _plank(w)
	w.sites.append({kind = &"scroll", at = plank, card = Cards.FIRE})
	Terrain.ignite(w, plank)
	for i in World.BURN_ROUNDS - 1:
		w.act({t = &"wait"})
	var f := Forecast.of(w, {t = &"wait"})
	assert_eq(_scroll(w).at, plank, "the forecast leaves it where it is")
	w.act({t = &"wait"})
	assert_eq(w.tile(plank), World.SKY)
	assert_eq(f.after.sites, w.sites)
	assert_ne(_scroll(w).at, plank)


func test_a_scroll_and_a_peach_on_a_rotten_board_move_when_it_gives_way() -> void:
	var w := _world()
	var at := FOE + Vector2i(2, 0)
	w.set_tile(at, World.BOARD_ROTTEN)
	w.sites.append({kind = &"scroll", at = at, card = Cards.FIRE})
	w.peaches.append(at)
	var foe := _foe(w, at + E)
	Terrain.crumble(w, foe, at)
	assert_eq(w.tile(at), World.SKY)
	for spot: Vector2i in [_scroll(w).at, w.peaches[0]]:
		assert_true(w.vacant(spot), str(spot))
