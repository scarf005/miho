extends GutTest
## Changes heaven creatures notice: what is recorded, who reacts, and the body marks.

const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)
const SPOT := Vector2i(20, 8)
const NEXT := Vector2i(21, 8)


## An open hall walled at the edges, with no light, Miho at ME.
func _world() -> World:
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
	me.pos = ME
	w.actors.append(me)
	w.depth = 2
	w.tails = 4
	w.sense()
	return w


## A creature next to SPOT, too far from Miho to see her.
func _watcher(w: World, kind := &"dokkaebi") -> Actor:
	var a := FloorGen.spawn(w, kind, NEXT)
	a.cooldown = 99
	# One step from its home, it is awake: a creature at its home sleeps.
	a.home += Vector2i.RIGHT
	return a


func _searching(a: Actor, at: Vector2i) -> void:
	assert_eq(a.alert, Actor.SEARCH)
	assert_eq(a.target, at)


func test_a_lantern_that_went_out_is_searched() -> void:
	var w := _world()
	w.set_tile(SPOT, World.LANTERN)
	var a := _watcher(w)
	Terrain.hit(w, SPOT)
	assert_eq(w.changes.size(), 1)
	assert_eq(w.changes[0].kind, &"lantern_out")
	assert_eq(w.changes[0].at, SPOT)
	assert_eq(w.changes[0].round, w.round_no)
	w.act(WAIT)
	assert_eq(a.alert, Actor.SEARCH)
	assert_eq(Grid.cheb(a.target, SPOT), 1, "a lantern cannot be stood on")


func test_a_lantern_that_broke_is_searched() -> void:
	var w := _world()
	w.set_tile(SPOT, World.LANTERN_OUT)
	var a := _watcher(w)
	Terrain.hit(w, SPOT)
	assert_eq(w.changes[0].kind, &"lantern_broken")
	w.act(WAIT)
	_searching(a, SPOT)


func test_water_putting_out_a_lantern_is_a_change() -> void:
	var w := _world()
	w.set_tile(SPOT, World.LANTERN)
	var s := Shot.new()
	s.spell = Spell.make([Cards.ORB, Cards.WATER])
	Terrain.touch(w, s, SPOT, Vector2i(-1, -1))
	assert_eq(w.changes[0].kind, &"lantern_out")


func test_a_broken_door_is_searched() -> void:
	var w := _world()
	w.set_tile(SPOT, World.DOOR)
	var a := _watcher(w)
	Terrain.hit(w, SPOT)
	assert_eq(w.changes[0].kind, &"door")
	w.act(WAIT)
	_searching(a, SPOT)


func test_a_cracked_wall_is_searched_from_the_floor_beside_it() -> void:
	var w := _world()
	w.set_tile(SPOT, World.WALL)
	var a := _watcher(w)
	Terrain.hit(w, SPOT)
	assert_eq(w.changes[0].kind, &"wall")
	w.act(WAIT)
	assert_eq(a.alert, Actor.SEARCH)
	assert_true(w.open_floor(a.target), "a wall cannot be stood on")
	assert_eq(Grid.cheb(a.target, SPOT), 1)


func test_a_wall_that_fell_is_a_change_too() -> void:
	var w := _world()
	w.set_tile(SPOT, World.WALL_CRACKED)
	Terrain.hit(w, SPOT)
	assert_eq(w.changes[0].kind, &"wall")
	assert_eq(w.tile(SPOT), World.RUBBLE)


func test_a_tile_burnt_to_ash_is_searched() -> void:
	var w := _world()
	w.set_tile(SPOT, World.BOARD)
	var a := _watcher(w, &"jangseung")
	w.burning[SPOT] = 1
	w.act(WAIT)
	assert_eq(w.tile(SPOT), World.ASH)
	assert_eq(w.changes[0].kind, &"ash")
	assert_eq(a.alert, Actor.REST, "it burnt down after the creature looked")
	w.act(WAIT)
	_searching(a, SPOT)


func test_a_fallen_creature_is_searched() -> void:
	var w := _world()
	var a := _watcher(w)
	var other := FloorGen.spawn(w, &"dokkaebi", SPOT)
	other.cooldown = 99
	Harm.hurt(w, other, 99)
	assert_eq(w.changes[0].kind, &"body")
	assert_eq(w.changes[0].at, SPOT)
	w.act(WAIT)
	_searching(a, SPOT)


func test_every_wits_searches_and_none_hunts() -> void:
	for kind in [&"jangseung", &"imugi", &"cheonnyeon"]:
		var w := _world()
		w.set_tile(SPOT, World.DOOR)
		var a := _watcher(w, kind)
		Terrain.hit(w, SPOT)
		w.act(WAIT)
		assert_eq(a.alert, Actor.SEARCH, str(kind))
		assert_eq(a.target, SPOT, str(kind))


func test_a_creature_that_cannot_see_the_tile_does_not_react() -> void:
	var w := _world()
	w.set_tile(SPOT, World.DOOR)
	var a := _watcher(w)
	a.pos = Vector2i(30, 20)
	Terrain.hit(w, SPOT)
	w.act(WAIT)
	assert_eq(a.alert, Actor.REST)
	assert_true(a.marked.is_empty())


func test_a_creature_reacts_to_a_change_once() -> void:
	var w := _world()
	w.set_tile(SPOT, World.DOOR)
	var a := _watcher(w)
	Terrain.hit(w, SPOT)
	w.act(WAIT)
	assert_eq(a.marked, [0] as Array[int])
	a.alert = Actor.REST
	var events := w.act(WAIT)
	assert_eq(a.alert, Actor.REST, "the same change does not draw it again")
	assert_false(events.any(func(e): return e.t == &"heed"))


func test_a_new_change_draws_it_again() -> void:
	var w := _world()
	var far := SPOT + Vector2i.LEFT
	w.set_tile(SPOT, World.DOOR)
	w.set_tile(far, World.DOOR)
	var a := _watcher(w)
	Terrain.hit(w, SPOT)
	w.act(WAIT)
	a.alert = Actor.REST
	Terrain.hit(w, far)
	w.act(WAIT)
	assert_eq(a.alert, Actor.SEARCH)
	assert_eq(a.marked.size(), 2)


func test_each_creature_reacts_on_its_own() -> void:
	var w := _world()
	w.set_tile(SPOT, World.DOOR)
	var a := _watcher(w)
	var b := FloorGen.spawn(w, &"dokkaebi", SPOT + Vector2i(0, 1))
	b.cooldown = 99
	Terrain.hit(w, SPOT)
	w.act(WAIT)
	assert_eq(a.alert, Actor.SEARCH)
	assert_eq(b.alert, Actor.SEARCH)


func test_a_hunter_ignores_a_change() -> void:
	var w := _world()
	w.set_tile(SPOT, World.DOOR)
	var a := _watcher(w)
	a.alert = Actor.HUNT
	a.target = Vector2i(10, 10)
	Terrain.hit(w, SPOT)
	w.act(WAIT)
	assert_eq(a.alert, Actor.HUNT)
	assert_ne(a.target, SPOT)


func test_a_blind_creature_does_not_see_a_change() -> void:
	var w := _world()
	w.set_tile(SPOT, World.DOOR)
	var a := _watcher(w)
	a.blind = 5
	Terrain.hit(w, SPOT)
	w.act(WAIT)
	assert_eq(a.alert, Actor.REST)


func test_a_body_mark_stays_once_seen_and_is_cloned() -> void:
	var w := _world()
	var at := ME + Vector2i.RIGHT
	var other := FloorGen.spawn(w, &"dokkaebi", at)
	other.cooldown = 99
	Harm.hurt(w, other, 99)
	w.act(WAIT)
	assert_eq(w.bodies[at].kind, &"dokkaebi")
	assert_true(w.bodies[at].met, "Miho saw it")
	for i in 40:
		w.act(WAIT)
	assert_true(w.bodies.has(at), "it stays")
	var c := w.clone()
	assert_eq(c.bodies, w.bodies)
	assert_eq(c.changes, w.changes)
	c.bodies[at].met = false
	assert_true(w.bodies[at].met, "the copy is deep")


func test_a_body_out_of_sight_is_not_known_until_seen() -> void:
	var w := _world()
	var other := FloorGen.spawn(w, &"dokkaebi", SPOT)
	other.cooldown = 99
	Harm.hurt(w, other, 99)
	w.sense()
	assert_false(w.bodies[SPOT].met)


func test_the_noted_changes_are_cloned_with_the_creature() -> void:
	var w := _world()
	var a := _watcher(w)
	a.marked.append(3)
	var c := w.clone()
	assert_eq(c.actor(a.id).marked, [3] as Array[int])
	c.actor(a.id).marked.append(4)
	assert_eq(a.marked, [3] as Array[int])


func test_a_new_storey_forgets_the_changes() -> void:
	var w := World.create(5)
	w.changes.append({id = 0, kind = &"door", at = Vector2i(3, 3), round = 0})
	w.bodies[Vector2i(3, 3)] = {kind = &"dokkaebi", round = 0, met = true}
	Round.ascend(w)
	assert_true(w.changes.is_empty())
	assert_true(w.bodies.is_empty())


func test_the_preview_matches_the_round() -> void:
	var w := _world()
	w.set_tile(SPOT, World.DOOR)
	var a := _watcher(w)
	Terrain.hit(w, SPOT)
	var p := w.preview(WAIT)
	w.act(WAIT)
	assert_eq(p.actor(a.id).alert, w.actor(a.id).alert)
	assert_eq(p.actor(a.id).target, w.actor(a.id).target)
	assert_eq(p.actor(a.id).marked, w.actor(a.id).marked)
