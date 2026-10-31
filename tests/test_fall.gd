extends GutTest
## World.push: a creature slides until something blocks it, or falls into the sky.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const EDGE := 25
const ROW := 8


## An open hall whose east part is sky from x = EDGE, Miho at (10, 8) on storey `depth`.
func _world(depth := 2) -> World:
	var w := World.new()
	w.rng.seed = 11
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.SKY if x >= EDGE else World.FLOOR
	w.rooms.assign([Rect2i(1, 1, EDGE - 2, Grid.H - 2)])
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
	w.sense()
	return w


func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


func test_a_push_slides_the_creature_up_to_n_tiles() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
	w.push(foe, E, 3)
	assert_eq(foe.pos, Vector2i(15, ROW))
	w.push(foe, Vector2i(0, -1), 2)
	assert_eq(foe.pos, Vector2i(15, ROW - 2))
	w.push(foe, E, 0)
	assert_eq(foe.pos, Vector2i(15, ROW - 2))


func test_a_push_stops_at_a_wall() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(4, ROW))
	w.push(foe, -E, 9)
	assert_eq(foe.pos, Vector2i(1, ROW), "the wall ring is at x = 0")
	assert_true(foe.alive())


func test_a_push_stops_at_whatever_blocks_walking() -> void:
	for blocker in [World.LANTERN, World.POND, World.WINDOW, World.WALL_CRACKED]:
		var w := _world()
		var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
		w.set_tile(Vector2i(15, ROW), blocker)
		w.push(foe, E, 9)
		assert_eq(foe.pos, Vector2i(14, ROW), str(blocker))


func test_a_push_stops_at_a_creature() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
	var other := _foe(w, &"dokkaebi", Vector2i(15, ROW))
	w.push(foe, E, 9)
	assert_eq(foe.pos, Vector2i(14, ROW))
	assert_eq(other.pos, Vector2i(15, ROW))
	w.push(w.player(), E, 9)
	assert_eq(w.player().pos, Vector2i(13, ROW), "Miho is stopped by a creature too")


func test_a_direction_that_is_no_unit_step_does_nothing() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
	w.push(foe, Vector2i(2, 0), 3)
	assert_eq(foe.pos, Vector2i(12, ROW))


func test_a_creature_pushed_into_the_sky_falls_and_counts_as_a_kill() -> void:
	var w := _world()
	var foe := _foe(w, &"cheonha", Vector2i(EDGE - 2, ROW))
	w.tails = 1
	var had := w.cards.duplicate()
	w.events = []
	w.push(foe, E, 5)
	assert_false(foe.alive())
	assert_eq(foe.pos, Vector2i(EDGE - 1, ROW), "it falls from the last floor tile")
	var types := w.events.map(func(e): return e.t)
	assert_has(types, &"fall")
	assert_has(types, &"die")
	assert_does_not_have(types, &"card")
	assert_eq(w.cards, had, "no talisman")
	assert_eq(w.tails, 2 if w.max_tails() >= 2 else 1)
	w.act(WAIT)
	assert_null(w.actor(foe.id), "it is gone from the storey")


func test_a_fallen_creature_leaves_no_body_and_no_change() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(EDGE - 1, ROW))
	w.push(foe, E, 1)
	assert_true(w.bodies.is_empty())
	assert_true(w.changes.is_empty())


func test_the_log_tells_who_fell() -> void:
	var w := _world()
	w.set_tile(Vector2i(11, ROW), World.LANTERN)
	var foe := _foe(w, &"dokkaebi", Vector2i(EDGE - 1, ROW))
	w.player().pos = Vector2i(EDGE - 3, ROW)
	w.sense()
	var before := w.clone()
	w.events = []
	w.push(foe, E, 1)
	var lines := Messages.of(before, w, w.events).map(Messages.plain)
	assert_eq(lines, ["도깨비가 하늘로 떨어졌다"])


func test_miho_pushed_into_the_sky_lands_one_storey_down() -> void:
	var w := _world(5)
	var me := w.player()
	me.pos = Vector2i(EDGE - 2, ROW)
	me.hp = 2
	w.tails = 2
	w.cards.append(Cards.FIRE)
	var cards := w.cards.duplicate()
	w.events = []
	w.push(me, E, 4)
	assert_eq(w.depth, 4)
	assert_eq(me.hp, 2, "her health is kept")
	assert_eq(w.tails, 2, "and her tails")
	assert_eq(w.cards, cards)
	assert_eq(me.pos, w.start, "she lands at the start of a fresh storey")
	assert_eq(w.round_no, 0)
	assert_true(w.changes.is_empty())
	assert_eq(w.actors[0], me)
	var fall: Dictionary = w.events.filter(func(e): return e.t == &"fall")[0]
	assert_eq(fall.depth, 4)
	assert_eq(w.outcome, &"")


func test_her_tails_are_kept_up_to_what_the_lower_storey_allows() -> void:
	var w := _world(4)
	assert_eq(w.tails, 2)
	w.player().pos = Vector2i(EDGE - 1, ROW)
	w.push(w.player(), E, 1)
	assert_eq(w.depth, 3)
	assert_eq(w.tails, 1)


func test_the_log_tells_that_miho_fell() -> void:
	var w := _world(3)
	w.player().pos = Vector2i(EDGE - 1, ROW)
	w.sense()
	var before := w.clone()
	w.events = []
	w.push(w.player(), E, 1)
	var lines := Messages.of(before, w, w.events).map(Messages.plain)
	assert_eq(lines, ["하늘로 떨어져 2층으로 내려왔다"])


func test_miho_on_the_first_storey_stops_at_the_edge() -> void:
	var w := _world(1)
	var me := w.player()
	me.pos = Vector2i(EDGE - 3, ROW)
	w.events = []
	w.push(me, E, 9)
	assert_eq(me.pos, Vector2i(EDGE - 1, ROW))
	assert_eq(w.depth, 1)
	assert_eq(me.hp, 3)
	assert_false(w.events.any(func(e): return e.t == &"fall"))


func test_a_fall_in_the_middle_of_a_round_leaves_the_old_storey_behind() -> void:
	var w := _world(3)
	var foe := _foe(w, &"dokkaebi", Vector2i(12, ROW))
	w.player().pos = Vector2i(EDGE - 1, ROW)
	w.push(w.player(), E, 1)
	assert_false(w.actors.has(foe))
	w.act(WAIT)
	assert_eq(w.depth, 2)
	assert_eq(w.outcome, &"")


func test_the_preview_of_a_fall_equals_the_fall() -> void:
	var w := _world(3)
	w.player().pos = Vector2i(EDGE - 1, ROW)
	var copy := w.clone()
	w.push(w.player(), E, 1)
	copy.push(copy.player(), E, 1)
	assert_eq(copy.depth, w.depth)
	assert_eq(copy.tiles, w.tiles)
	assert_eq(copy.start, w.start)
	assert_eq(copy.actors.size(), w.actors.size())
	assert_eq(copy.rng.state, w.rng.state)


func test_the_forecast_shows_a_fall() -> void:
	var w := _world(3)
	var foe := _foe(w, &"dokkaebi", Vector2i(EDGE - 1, ROW))
	w.player().pos = Vector2i(EDGE - 3, ROW)
	w.sense()
	var f := Forecast.new()
	f.after = w.known_clone()
	f.after.events = []
	f.after.push(f.after.actor(foe.id), E, 1)
	f.after.push(f.after.player(), Vector2i(1, 0), 9)
	f.read(f.after.events)
	assert_true(f.falls.has(foe.id))
	assert_true(f.deaths.has(foe.id))
	assert_true(f.drops_me())
	assert_eq(f.after.depth, 2)
