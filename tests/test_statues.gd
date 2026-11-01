extends GutTest
## Statues: stone 장승 that wake when Miho comes within Statues.REACH. What stays
## still outside it, what stands there after, and what the hover, log and sound say.

const AT := Vector2i(12, 8)
const WAIT := {t = &"wait"}


## An open hall walled at the edges, Miho at (4, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.depth = 2
	w.rng.seed = 5
	w.set_tile(AT, World.STATUE)
	w.sense()
	return w


func _wakes(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"wake")


func test_a_statue_cannot_be_walked_through_or_knocked_down() -> void:
	var w := _world()
	w.player().pos = AT + Vector2i.LEFT
	w.sense()
	assert_false(w.vacant(AT))
	assert_false(Terrain.knockable(World.STATUE))
	assert_eq(Tiles.of(World.STATUE, "breaks_to"), -1)


func test_a_statue_stays_while_miho_is_farther_than_its_reach_and_wakes_when_she_comes() -> void:
	var w := _world()
	w.player().pos = AT + Vector2i(Statues.REACH + 1, 0)
	w.sense()
	assert_eq(_wakes(w.act(WAIT)), [])
	assert_eq(w.tile(AT), World.STATUE)
	w.player().pos = AT + Vector2i(Statues.REACH, Statues.REACH)
	w.sense()
	var woke := _wakes(w.act(WAIT))
	assert_eq(woke.size(), 1, "on the corner of its reach")
	assert_eq(w.tile(AT), World.FLOOR)


func test_the_woken_statue_is_a_jangseung_hunting_miho_from_where_it_stood() -> void:
	var w := _world()
	w.player().pos = AT + Vector2i.LEFT * Statues.REACH
	w.sense()
	var woke := _wakes(w.act(WAIT))
	var a := w.actor_at(AT)
	assert_not_null(a)
	assert_eq(a.kind, &"jangseung")
	assert_eq(a.faction, Actor.HEAVEN)
	assert_eq(a.alert, Actor.HUNT)
	assert_eq(a.hp, a.max_hp)
	assert_eq(woke[0].id, a.id)
	assert_eq(woke[0].at, AT)


func test_each_statue_wakes_by_its_own_distance() -> void:
	var w := _world()
	var far := AT + Vector2i(0, 6)
	w.set_tile(far, World.STATUE)
	w.player().pos = AT + Vector2i.LEFT
	w.sense()
	assert_eq(_wakes(w.act(WAIT)).size(), 1)
	assert_eq(w.tile(far), World.STATUE)


func test_waking_draws_nothing_from_the_worlds_generator() -> void:
	var w := _world()
	w.player().pos = AT + Vector2i.LEFT
	w.sense()
	var state := w.rng.state
	w.act(WAIT)
	assert_eq(w.rng.state, state)


func test_the_hover_the_log_and_the_sound_of_a_statue() -> void:
	var w := _world()
	var text := Info.plain(Info.terrain(w, AT))
	assert_string_contains(text, "석상")
	assert_string_contains(text, "막음: 길")
	assert_false(text.contains("장승"), "a statue looks like a statue until it wakes")
	w.player().pos = AT + Vector2i.LEFT
	w.sense()
	var events := w.act(WAIT)
	var lines: Array[String] = []
	lines.assign(Messages.of(w, w, _wakes(events)).map(Messages.plain))
	assert_eq(lines, ["석상이 깨어났다"] as Array[String])
	assert_eq(Sfx.sound_of(_wakes(events)[0]), &"stone")
