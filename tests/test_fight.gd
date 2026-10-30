extends GutTest
## Tab: auto-fight like DCSS's Autofight, on the world and on the game scene.

const E := Vector2i(1, 0)
const S := Vector2i(0, 1)


## An open hall walled at the edges, every tile known and seen, Miho at (4, 8).
func _hall() -> World:
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
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	return w


func _foe(w: World, at: Vector2i, alert := Actor.REST) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.alert = alert
	return a


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(3)
	m.state = &"play"
	m.world = _hall()
	m.term.show_world(m.world)
	m._forecast()
	return m


func test_it_claws_the_creature_next_to_miho() -> void:
	var w := _hall()
	_foe(w, Vector2i(5, 8))
	assert_eq(Fight.step(w), {t = &"move", dir = E})
	_foe(w, Vector2i(9, 8))
	assert_eq(Fight.step(w), {t = &"move", dir = E}, "the far one does not matter")


func test_it_prefers_an_unaware_one_among_those_next_to_her() -> void:
	var w := _hall()
	_foe(w, Vector2i(5, 8), Actor.HUNT)
	_foe(w, Vector2i(4, 9))
	assert_eq(Fight.step(w), {t = &"move", dir = S}, "the sneak attack")
	w.actor_at(Vector2i(4, 9)).alert = Actor.HUNT
	assert_eq(Fight.step(w), {t = &"move", dir = E}, "both aware: the older one")
	w.actor_at(Vector2i(4, 9)).blind = 2
	assert_eq(Fight.step(w), {t = &"move", dir = S}, "a blind one is unaware")


func test_it_steps_towards_the_nearest_when_none_is_next_to_her() -> void:
	var w := _hall()
	_foe(w, Vector2i(10, 8))
	_foe(w, Vector2i(4, 11))
	assert_eq(Fight.step(w), {t = &"move", dir = S})
	w.actor_at(Vector2i(4, 11)).hp = 0
	assert_eq(Fight.step(w), {t = &"move", dir = E}, "a fallen one is not a target")


func test_it_walks_round_a_wall_on_the_shortest_path() -> void:
	var w := _hall()
	_foe(w, Vector2i(7, 8))
	w.tiles[Grid.index(Vector2i(5, 8))] = World.WALL
	var step: Dictionary = Fight.step(w)
	assert_eq(step.dir.x, 1)
	assert_ne(step.dir.y, 0, "it does not walk into the wall")


func test_it_does_nothing_when_no_creature_is_in_sight() -> void:
	var w := _hall()
	assert_eq(Fight.step(w), {}, "none on the storey")
	var foe := _foe(w, Vector2i(9, 8))
	w.seen[Grid.index(foe.pos)] = 0
	assert_eq(Fight.step(w), {}, "one she cannot see")
	w.seen[Grid.index(foe.pos)] = 1
	for d in Grid.DIRS:
		w.tiles[Grid.index(foe.pos + d)] = World.WALL
	assert_eq(Fight.step(w), {}, "one she cannot reach")


func test_it_refuses_at_half_health_or_less() -> void:
	var w := _hall()
	var me := w.player()
	me.max_hp = 4
	for hp in [4, 3, 2, 1]:
		me.hp = hp
		assert_eq(Fight.too_hurt(w), hp <= 2, "%d of 4" % hp)


func test_tab_is_the_fight_key_and_is_listed_in_help() -> void:
	Keys.reset()
	assert_eq(Keys.keys_of(&"fight"), ["Tab"] as Array[String])
	var e := Keys.event("Tab")
	e.pressed = true
	assert_eq(Keys.action_of(e), &"fight")
	var menu := Menu.new()
	menu.open(&"help")
	var text := "\n".join(
		menu.panel().rows.map(func(r): return " ".join(r.map(func(run): return run[0])))
	)
	assert_string_contains(text, "자동 공격 Tab")


func test_tab_plays_the_claw_move_and_saves_it_like_any_move() -> void:
	var m := _main()
	var foe := _foe(m.world, Vector2i(5, 8))
	m._forecast()
	var e := Keys.event("Tab")
	e.pressed = true
	m._key(e)
	while m.busy:
		await get_tree().process_frame
	assert_eq(m.run.actions.size(), 1)
	assert_eq(m.run.actions[0], {t = &"move", dir = E})
	assert_lt(foe.hp, foe.max_hp, "the claw landed")
	assert_eq(m.world.round_no, 1)


func test_tab_with_nothing_in_view_says_so_and_takes_no_turn() -> void:
	var m := _main()
	await m._fight()
	assert_true(m.run.actions.is_empty())
	assert_eq(m.world.round_no, 0)
	assert_eq(m.messages.lines.back().text, "보이는 적이 없다")


func test_tab_when_badly_hurt_refuses_even_with_a_creature_next_to_her() -> void:
	var m := _main()
	_foe(m.world, Vector2i(5, 8))
	m.world.player().hp = 1
	await m._fight()
	assert_true(m.run.actions.is_empty())
	assert_eq(m.messages.lines.back().text, "너무 다쳐서 싸울 수 없다")
