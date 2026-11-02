extends GutTest
## A creature that flies crosses sky and deep water and touches nothing on the ground.
## 박쥐 flits; 삼족오 throws fire.

const ME := Vector2i(10, 12)
const E := Vector2i(1, 0)


func _world() -> World:
	var w := World.new()
	w.rng.seed = 5
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
	me.hp = 30
	me.max_hp = 30
	me.pos = ME
	w.actors.append(me)
	w.depth = 2
	w.sense()
	return w


func _flyer(w: World, at: Vector2i, kind := &"samjogo") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.hp = 9
	a.magic.cooldown = 99
	a.brain.alert = Actor.HUNT
	a.brain.target = ME
	return a


## A wall from top to bottom at `x`, broken only by `gap` tiles of `tile` at the row of Miho.
func _moat(w: World, x: int, tile: int) -> void:
	for y in range(1, Grid.H - 1):
		w.set_tile(Vector2i(x, y), tile)


func test_a_flyer_crosses_sky_and_deep_water_a_walker_cannot() -> void:
	for tile in [World.SKY, World.POND]:
		var w := _world()
		_moat(w, ME.x + 2, tile)
		var a := _flyer(w, ME + E * 3)
		var post := _flyer(w, ME + E * 3 + Vector2i(0, 2), &"dokkaebi")
		for i in 4:
			w.sense()
			w.act({t = &"wait"})
		assert_eq(Grid.cheb(a.pos, ME), 1, "it came across %d" % tile)
		assert_gt(post.pos.x, ME.x + 2, "a walker stays on its side")


func test_a_flyer_can_end_a_step_over_the_sky_and_does_not_fall() -> void:
	var w := _world()
	w.set_tile(ME + E * 2, World.SKY)
	var a := _flyer(w, ME + E * 3)
	Walk.move(w, a, ME + E * 2)
	assert_eq(a.pos, ME + E * 2)
	assert_true(a.alive())
	assert_true(w.actors.has(a))


func test_a_flyer_touches_nothing_on_the_ground() -> void:
	var w := _world()
	var a := _flyer(w, ME + E * 2)
	var to := ME + E * 3
	w.traps[to] = World.TRAP_COLLAPSE
	w.set_tile(to, World.THORNS)
	var from := w.events.size()
	Walk.move(w, a, to)
	assert_true(a.alive())
	assert_eq(a.hp, 9, "thorns do not prick it")
	assert_false(w.events.slice(from).any(func(e): return e.t == &"trap"), "no plate goes off")
	var mud := to + E
	w.set_tile(mud, World.MUD)
	Walk.move(w, a, mud)
	assert_eq(a.ailments.rooted, 0, "mud does not hold it")


func test_a_flyer_on_a_rotten_board_or_a_noisy_one_leaves_it_as_it_is() -> void:
	var w := _world()
	var a := _flyer(w, ME + E * 2)
	var rotten := ME + E * 3
	w.set_tile(rotten, World.BOARD_ROTTEN)
	var from := w.events.size()
	Walk.move(w, a, rotten)
	Walk.move(w, a, rotten + E)
	assert_eq(w.tile(rotten), World.BOARD_ROTTEN)
	var moves := w.events.slice(from).filter(func(e): return e.t == &"move")
	assert_true(moves.all(func(e): return e.loud == 0), "no step is heard")


func test_a_push_carries_a_flyer_over_the_sky_and_water_and_it_stays_up() -> void:
	var w := _world()
	var a := _flyer(w, ME + E * 2)
	w.set_tile(ME + E * 3, World.SKY)
	w.set_tile(ME + E * 4, World.POND)
	w.push(a, E, 2)
	assert_eq(a.pos, ME + E * 4)
	assert_true(w.actors.has(a))


func test_a_push_still_slams_a_flyer_into_a_wall() -> void:
	var w := _world()
	var a := _flyer(w, ME + E * 2)
	w.set_tile(ME + E * 3, World.WALL)
	w.push(a, E, 2)
	assert_eq(a.hp, 7)


func test_a_floor_that_falls_away_under_a_flyer_leaves_it_in_the_air() -> void:
	var w := _world()
	var a := _flyer(w, ME + E * 2)
	w.set_tile(a.pos, World.SKY)
	Fall.drop(w, a, a.pos)
	assert_true(a.alive())
	assert_true(w.actors.has(a))
	assert_eq(a.pos, ME + E * 2)


func test_a_flyer_felled_over_the_sky_leaves_no_body_there() -> void:
	var w := _world()
	var a := _flyer(w, ME + E * 2)
	w.set_tile(a.pos, World.SKY)
	Harm.hurt(w, a, a.hp)
	assert_false(w.bodies.has(a.pos))


func test_a_flyer_felled_over_floor_leaves_a_body() -> void:
	var w := _world()
	var a := _flyer(w, ME + E * 2)
	var at := a.pos
	Harm.hurt(w, a, a.hp)
	assert_true(w.bodies.has(at))


func test_a_bat_flits_about_one_move_in_three() -> void:
	var w := _world()
	var a := _flyer(w, ME + E * 12, &"bakjwi")
	var away := 0
	var rounds := 300
	for i in rounds:
		a.pos = ME + E * 12
		a.brain.alert = Actor.HUNT
		a.brain.sees_me = true
		a.brain.target = ME
		Mind.heaven_phase(w)
		away += 1 if a.pos.x >= ME.x + 12 else 0
	assert_between(away, 40, 110, "of %d moves it did not close in on %d" % [rounds, away])


func test_a_bat_next_to_miho_sometimes_flits_instead_of_biting() -> void:
	var w := _world()
	var a := _flyer(w, ME + E, &"bakjwi")
	var bites := 0
	var rounds := 300
	for i in rounds:
		a.pos = ME + E
		a.brain.alert = Actor.HUNT
		a.brain.sees_me = true
		var from := w.events.size()
		Mind.heaven_phase(w)
		if w.events.slice(from).any(func(e): return e.t == &"melee"):
			bites += 1
		w.player().hp = 30
	assert_between(bites, 150, 260, "bit %d of %d" % [bites, rounds])


func test_the_three_legged_crow_stops_a_spell_of_only_fire() -> void:
	var w := _world()
	var a := _flyer(w, ME + E * 2)
	var hp := a.hp
	w.tails = 9
	w.cards.assign(Cards.ALL)
	var events := w.act({t = &"cast", spells = [{cards = [Cards.ORB, Cards.FIRE], dir = E}]})
	for i in 4:
		if a.hp != hp or events.any(func(e): return e.t == &"absorb"):
			break
		events = w.act({t = &"wait"})
	assert_eq(a.hp, hp)
