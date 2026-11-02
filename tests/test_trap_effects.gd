extends GutTest
## Plates going off: each kind for Miho, a creature and a projectile, and who walks round them.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const PLATE := Vector2i(7, 8)


## An open hall walled at the edges with no light, Miho at (4, 8) on storey 2.
func _world(depth := 2) -> World:
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
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.depth = depth
	w.tails = 1
	w.sense()
	return w


func _foe(w: World, at: Vector2i, kind := &"dokkaebi") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.magic.cooldown = 99
	return a


## A plate of `kind` at `at`, still hidden.
func _plate(w: World, at: Vector2i, kind: int) -> void:
	w.traps[at] = kind


func _types(events: Array) -> Array:
	return events.map(func(e): return e.t)


# --- going off ---------------------------------------------------------------


func test_the_alarm_plate_sends_every_resting_creature_to_search_it() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_ALARM)
	var far := _foe(w, Vector2i(50, 24))
	var near := _foe(w, Vector2i(10, 20))
	var hunter := _foe(w, Vector2i(30, 4))
	hunter.alert = Actor.HUNT
	hunter.target = Vector2i(2, 2)
	var deaf := _foe(w, Vector2i(40, 20), &"jangseung")
	var events := w.act({t = &"move", dir = E})
	var gong := events.filter(func(e): return e.t == &"noise" and e.word == Traps.GONG)
	assert_eq(gong.size(), 1)
	assert_eq(gong[0].loud, Drums.LOUD, "the whole storey")
	for a in [far, near]:
		assert_eq(a.alert, Actor.SEARCH)
		assert_eq(a.target, PLATE)
	assert_eq(hunter.alert, Actor.HUNT, "a hunter keeps hunting")
	assert_eq(hunter.target, Vector2i(2, 2))
	assert_eq(deaf.alert, Actor.REST, "a deaf creature does not hear")


func test_the_alarm_plate_goes_off_again_for_every_step() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_ALARM)
	var gongs := 0
	for dir in [E, -E, E]:
		gongs += w.act({t = &"move", dir = dir}).filter(func(e): return e.t == &"trap").size()
	assert_eq(gongs, 2, "stepping on twice, off once")


func test_a_creature_pushed_onto_the_alarm_plate_rings_it_for_the_others() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_ALARM)
	var pushed := _foe(w, PLATE - E)
	var other := _foe(w, Vector2i(40, 20))
	w.push(pushed, E, 1)
	assert_eq(pushed.pos, PLATE)
	assert_eq(other.alert, Actor.SEARCH)
	assert_eq(other.target, PLATE)
	assert_ne(pushed.alert, Actor.SEARCH, "not the one that rang it")


## Keeps the hall as the storey below, as if Miho had climbed from it.
func _keep_below(w: World) -> void:
	w.depth -= 1
	Storeys.leave(w)
	w.depth += 1


func test_miho_stepping_on_a_collapsing_floor_goes_one_storey_down() -> void:
	var w := _world()
	_keep_below(w)
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.depth, 1)
	var fall := events.filter(func(e): return e.t == &"fall")
	assert_eq(fall.size(), 1)
	assert_eq(fall[0].depth, 1)
	assert_eq(w.player().pos, PLATE, "she lands under the plate")
	assert_eq(w.scent.count(0), w.scent.size(), "no trail of hers on the storey below")
	assert_eq(w.player().hp, 2)


func test_a_creature_on_a_collapsing_floor_falls_out_of_the_game() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	var foe := _foe(w, PLATE - E)
	w.push(foe, E, 1)
	assert_false(foe.alive())
	assert_eq(w.depth, 2, "Miho stays")
	assert_eq(w.tails, 2, "a kill gives a tail back")
	var types := _types(w.events)
	assert_has(types, &"trap")
	assert_has(types, &"fall")
	assert_eq(w.tile(PLATE), World.FLOOR, "it was never found")


func test_a_collapsing_floor_on_the_first_storey_drops_nobody_but_heaven() -> void:
	var w := _world(1)
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	w.act({t = &"move", dir = E})
	assert_eq(w.depth, 1)
	assert_eq(w.player().pos, PLATE)
	w.player().pos = Vector2i(2, 20)
	var foe := _foe(w, PLATE + E)
	w.push(foe, -E, 1)
	assert_false(foe.alive())


func test_a_push_ends_when_the_creature_falls_through_a_plate_on_the_way() -> void:
	var w := _world()
	_keep_below(w)
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	w.push(w.player(), E, 4)
	assert_eq(w.depth, 1, "dropped once, not pushed on")
	assert_eq(w.player().pos, PLATE)


func test_the_fire_plate_breathes_fire_the_way_the_creature_stepped() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_FIRE)
	w.act({t = &"move", dir = E})
	var flames := []
	for i in range(1, Traps.FLAME_REACH + 1):
		flames.append(PLATE + E * i)
	assert_eq(w.burning.keys().size(), Traps.FLAME_REACH + 0)
	for p in flames:
		assert_true(w.burning.has(p), "burning at %s" % p)
	assert_false(w.burning.has(PLATE), "not under her")
	assert_eq(w.player().hp, 3)


func test_the_fire_plate_breathes_along_a_diagonal_step() -> void:
	var w := _world()
	var d := Vector2i(1, 1)
	w.player().pos = PLATE - d
	_plate(w, PLATE, World.TRAP_FIRE)
	w.act({t = &"move", dir = d})
	for i in range(1, Traps.FLAME_REACH + 1):
		assert_true(w.burning.has(PLATE + d * i))
	assert_false(w.burning.has(PLATE + E))


func test_the_fire_stops_at_a_wall() -> void:
	var w := _world()
	var plate := Vector2i(Grid.W - 3, 8)
	w.player().pos = plate - E
	_plate(w, plate, World.TRAP_FIRE)
	w.act({t = &"move", dir = E})
	assert_eq(w.burning.keys(), [Vector2i(Grid.W - 2, 8)])


func test_the_fire_burns_a_creature_in_its_way() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_FIRE)
	var foe := _foe(w, PLATE + E * 2, &"jangseung")
	w.act({t = &"move", dir = E})
	assert_eq(foe.hp, Bestiary.hp(&"jangseung", 1), "it burns from the next round")
	w.act(WAIT)
	assert_eq(foe.hp, Bestiary.hp(&"jangseung", 1) - World.FIRE_DAMAGE)


func test_the_fire_leaves_a_plate_in_its_path_alone() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_FIRE)
	_plate(w, PLATE + E, World.TRAP_VINE)
	w.act({t = &"move", dir = E})
	assert_false(w.burning.has(PLATE + E))
	assert_true(w.burning.has(PLATE + E * 2))
	assert_eq(w.traps[PLATE + E], World.TRAP_VINE)


func test_a_creature_pushed_onto_the_fire_plate_breathes_it_along_the_push() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_FIRE)
	var foe := _foe(w, PLATE - Vector2i(0, 1))
	w.push(foe, Vector2i(0, 1), 1)
	assert_true(w.burning.has(PLATE + Vector2i(0, 1)))
	assert_false(w.burning.has(PLATE + E))


func test_the_vine_plate_roots_everyone_in_the_three_by_three_for_the_set_rounds() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_VINE)
	w.player().hp = 9
	w.player().max_hp = 9
	var beside := _foe(w, PLATE + Vector2i(1, 1))
	var apart := _foe(w, PLATE + Vector2i(2, 0), &"jangseung")
	var events := w.act({t = &"move", dir = E})
	assert_eq(w.player().ailments.rooted, Traps.ROOT_ROUNDS - 1, "one round of it has passed")
	assert_eq(beside.ailments.rooted, Traps.ROOT_ROUNDS - 1)
	assert_eq(apart.ailments.rooted, 0, "two tiles from the plate")
	assert_eq(events.filter(func(e): return e.t == &"root").size(), 2)
	assert_false(w.can({t = &"move", dir = E}), "she cannot step")
	var rounds := 0
	while not w.can({t = &"move", dir = E}) and rounds < 10:
		w.act(WAIT)
		rounds += 1
	assert_eq(rounds, Traps.ROOT_ROUNDS - 1)


func test_a_creature_pushed_onto_the_vine_plate_roots_itself_and_its_neighbours() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_VINE)
	var foe := _foe(w, PLATE - E)
	var next_to := _foe(w, PLATE + Vector2i(0, -1))
	w.push(foe, E, 1)
	assert_eq(foe.ailments.rooted, Traps.ROOT_ROUNDS)
	assert_eq(next_to.ailments.rooted, Traps.ROOT_ROUNDS)
	assert_eq(w.player().ailments.rooted, 0)


# --- who walks onto them ------------------------------------------------------


func _walled_column(w: World, x: int, gap: int) -> void:
	for y in range(1, Grid.H - 1):
		if y != gap:
			w.tiles[Grid.index(Vector2i(x, y))] = World.WALL
	w._changed()


func test_a_hunter_crosses_a_plate_that_is_the_only_way_and_sets_it_off() -> void:
	var w := _world()
	_walled_column(w, 9, 8)
	_plate(w, Vector2i(9, 8), World.TRAP_ALARM)
	var foe := _foe(w, Vector2i(14, 8))
	Mind.hunt_from(w, foe, w.player().pos)
	var gongs := 0
	for i in 8:
		gongs += w.act(WAIT).filter(func(e): return e.t == &"trap" and e.id == foe.id).size()
	assert_lt(foe.pos.x, 9, "it came through")
	assert_eq(gongs, 1)


func test_a_hunter_does_not_step_aside_for_a_plate_on_its_straight_line() -> void:
	var w := _world()
	for y in range(6, 11):
		_plate(w, Vector2i(8, y), World.TRAP_VINE)
	var foe := _foe(w, Vector2i(10, 8))
	Mind.hunt_from(w, foe, w.player().pos)
	w.act(WAIT)
	w.act(WAIT)
	assert_true(w.traps.has(foe.pos), "at %s" % foe.pos)
	assert_gt(foe.ailments.rooted, 0, "its own vines hold it")


func test_a_hunter_lured_over_a_collapsing_floor_falls_and_counts_as_a_kill() -> void:
	var w := _world()
	_walled_column(w, 9, 8)
	_plate(w, Vector2i(9, 8), World.TRAP_COLLAPSE)
	var foe := _foe(w, Vector2i(11, 8))
	Mind.hunt_from(w, foe, w.player().pos)
	for i in 4:
		w.act(WAIT)
	assert_false(foe.alive())
	assert_eq(w.player().buffs.prey, foe.kind, "a fall gives what a kill does")


func test_a_searcher_goes_to_the_alarm_plate_but_not_onto_it() -> void:
	var w := _world()
	w.player().pos = Vector2i(2, 20)
	_plate(w, PLATE, World.TRAP_ALARM)
	var foe := _foe(w, Vector2i(14, 8))
	foe.alert = Actor.SEARCH
	foe.target = PLATE
	var nearest := 99
	for i in 12:
		w.act(WAIT)
		assert_ne(foe.pos, PLATE, "round %d" % i)
		nearest = mini(nearest, Grid.cheb(foe.pos, PLATE))
	assert_eq(nearest, 1, "it stands beside it")


func test_the_searchers_an_alarm_plate_calls_do_not_ring_it_again() -> void:
	var w := _world()
	w.player().pos = Vector2i(2, 20)
	_plate(w, PLATE, World.TRAP_ALARM)
	var foes := [_foe(w, PLATE + Vector2i(6, 0)), _foe(w, PLATE + Vector2i(0, 6))]
	Hearing.noise(w, PLATE, Drums.LOUD, Traps.GONG, true, 0)
	for i in 20:
		assert_false(w.act(WAIT).any(func(e): return e.t == &"trap"), "round %d" % i)
	assert_eq(foes.filter(func(a): return Grid.cheb(a.pos, PLATE) <= 2).size(), 2, "they came")


func test_an_ally_on_the_hunt_walks_round_a_plate() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_FIRE)
	var friend := _foe(w, PLATE - E)
	friend.faction = Actor.FOX
	friend.alert = Actor.HUNT
	assert_true(Traps.bars(w, friend, PLATE))
	friend.faction = Actor.HEAVEN
	assert_false(Traps.bars(w, friend, PLATE))


func _trail(w: World) -> Actor:
	_plate(w, PLATE + E, World.TRAP_FIRE)
	w.scent.resize(w.tiles.size())
	w.scent[Grid.index(PLATE + E)] = 5
	w.scent[Grid.index(PLATE)] = 2
	w.round_no = 5
	return _foe(w, PLATE)


func test_a_trail_of_scent_leads_a_hunter_onto_a_plate() -> void:
	var w := _world()
	var foe := _trail(w)
	foe.alert = Actor.HUNT
	assert_eq(Scent.next(w, foe), PLATE + E)


func test_a_trail_of_scent_does_not_lead_a_searcher_onto_a_plate() -> void:
	var w := _world()
	var foe := _trail(w)
	foe.alert = Actor.SEARCH
	assert_eq(Scent.next(w, foe), PLATE, "the trail goes over the plate, so it stays")


# --- projectiles set them off -------------------------------------------------


## What Miho hurled from (4, 8) east, an orb unless `cards` says otherwise.
func _shot(w: World, cards := [Cards.ORB]) -> Shot:
	return Flight.spawn(w, w.player(), Spell.make(cards), E, 0)


func _fly_on(w: World, s: Shot, tiles: int) -> Array:
	var from := w.events.size()
	for i in tiles:
		if not s.gone:
			Flight.step(w, s)
	return w.events.slice(from)


func test_an_orb_over_an_alarm_plate_calls_the_storey() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_ALARM)
	var far := _foe(w, Vector2i(50, 24))
	var events := _fly_on(w, _shot(w), 3)
	assert_eq(_types(events).count(&"trap"), 1)
	assert_eq(far.alert, Actor.SEARCH)
	assert_eq(far.target, PLATE)
	assert_true(events.any(func(e): return e.t == &"noise" and e.word == Traps.GONG and e.heard))


func test_a_shot_of_heaven_sets_a_plate_off_too() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_VINE)
	var foe := _foe(w, PLATE - E - E)
	var next_to := _foe(w, PLATE + Vector2i(0, 1))
	var s := Flight.spawn(w, foe, Spell.make([Cards.ORB]), E, 0)
	_fly_on(w, s, 2)
	assert_eq(next_to.ailments.rooted, Traps.ROOT_ROUNDS)
	assert_false(s.gone, "it flies on")


func test_a_fire_plate_flames_on_along_the_flight_of_the_shot() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_FIRE)
	_fly_on(w, _shot(w), 3)
	for i in range(1, Traps.FLAME_REACH + 1):
		assert_true(w.burning.has(PLATE + E * i), "tile %d" % i)


func test_a_shot_falls_through_a_collapsing_floor_and_does_not_burst() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	var s := _shot(w)
	var events := _fly_on(w, s, 5)
	assert_true(s.gone)
	assert_eq(s.pos, PLATE)
	assert_false(_types(events).has(&"burst"))
	assert_eq(_types(events).count(&"fade"), 1)
	assert_true(w.traps.has(PLATE), "the plate stays")


func test_a_wisp_at_the_end_of_its_range_does_not_land_after_falling() -> void:
	var w := _world()
	var spell := Spell.make([Cards.FOX])
	var s := Flight.spawn(w, w.player(), spell, E, 0)
	s.flown = Spell.RANGE - 1
	_plate(w, s.pos + E, World.TRAP_COLLAPSE)
	assert_false(_types(_fly_on(w, s, 1)).has(&"land"))


func test_a_shot_that_strikes_a_creature_on_a_plate_does_not_press_it() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_ALARM)
	_foe(w, PLATE)
	assert_false(_types(_fly_on(w, _shot(w), 3)).has(&"trap"))


func test_a_spray_does_not_set_a_plate_off() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_ALARM)
	w.tails = 9
	w.cards.assign(Cards.ALL)
	var events := w.act({t = &"cast", spells = [{cards = [Cards.WATER], dir = E}]})
	assert_true(_types(events).has(&"spray"))
	assert_false(_types(events).has(&"trap"))
