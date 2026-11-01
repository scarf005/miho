extends GutTest
## The debug command list: how it opens and moves, and how a command that
## needs a tile or a creature waits for the cursor or a click.

## Named first so World loads before Menu does (a script that meets SpellInfo
## first leaves Masks half built).
const FLOORS := World.FLOORS


func before_each() -> void:
	Keys.reset()


func after_all() -> void:
	Keys.reset()


## The game in play, or at the title when a save path is given.
func _main(save_path := "") -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = save_path
	add_child_autofree(m)
	if save_path.is_empty():
		m._new_run(3)
		m.state = &"play"
	m.glass.visible = false
	return m


func _key(m: Node, key: String) -> void:
	var e := Keys.event(key)
	e.pressed = true
	m._unhandled_input(e)
	await wait_until(func(): return not m.busy, 5)


func _click_tile(m: Node, tile: Vector2i, button := MOUSE_BUTTON_LEFT) -> void:
	var at: Vector2 = m.term.get_global_transform() * m.term.cell_centre(tile)
	var move := InputEventMouseMotion.new()
	move.position = at
	m._unhandled_input(move)
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = at
	m._unhandled_input(e)
	await wait_until(func(): return not m.busy, 5)


func _row(m: Node, cmd: StringName) -> void:
	m.menu.debug.selected = DebugMenu.COMMANDS.find(cmd)


## A free tile next to Miho.
func _beside(m: Node) -> Vector2i:
	for d in Grid.DIRS:
		if m.world.vacant(m.world.player().pos + d):
			return m.world.player().pos + d
	return Vector2i(-1, -1)


## A creature of `kind` summoned `by` tiles from Miho, by the debug command.
func _foe(m: Node, kind: StringName, by: Vector2i) -> Actor:
	var at: Vector2i = m.world.player().pos + by
	m.world.act({t = &"cheat", cmd = &"summon", kind = kind, at = at})
	m._forecast()
	return m.world.actor_at(at)


func test_the_key_opens_the_commands_and_escape_closes_them() -> void:
	var m := _main()
	await _key(m, "F4")
	assert_eq(m.overlay, &"cheat")
	var names: Array = m.term.panel.rows.map(func(r): return r[0][0])
	assert_eq(names, DebugMenu.COMMANDS.map(func(c): return Cheat.NAME[c]))
	await _key(m, "Escape")
	assert_eq(m.overlay, &"")
	await _key(m, "F4")
	await _key(m, "F4")
	assert_eq(m.overlay, &"", "its key closes it too")


func test_the_game_menu_lists_it_and_escape_goes_back_there() -> void:
	var m := _main()
	await _key(m, "Escape")
	m.menu.selected = Menu.OPTIONS.find(&"cheat")
	await _key(m, "Enter")
	assert_eq(m.overlay, &"options")
	assert_eq(m.term.panel.rows.size(), DebugMenu.COMMANDS.size())
	await _key(m, "Escape")
	assert_eq(m.term.panel.rows.size(), Menu.OPTIONS.size())
	assert_eq(m.term.panel.selected, Menu.OPTIONS.find(&"cheat"))


func test_a_toggle_is_played_and_recorded_and_the_row_reads_it() -> void:
	var m := _main()
	await _key(m, "F4")
	_row(m, &"god")
	await _key(m, "Enter")
	assert_eq(m.overlay, &"")
	assert_true(Cheat.on(m.world, &"god"))
	assert_eq(m.run.actions.back(), {t = &"cheat", cmd = &"god"})
	await _key(m, "F4")
	assert_eq(m.term.panel.rows[DebugMenu.COMMANDS.find(&"god")][1][0], "켜짐")
	assert_eq(m.menu.debug.selected, DebugMenu.COMMANDS.find(&"god"), "it keeps its row")


func test_left_and_right_step_the_harm_and_a_list_of_its_own_goes_back_to_its_row() -> void:
	var m := _main()
	await _key(m, "F4")
	_row(m, &"damage")
	m.menu.debug.amount = 0
	await _key(m, "Right")
	assert_eq(m.menu.debug.amount, 1)
	await _key(m, "Left")
	await _key(m, "Left")
	assert_eq(m.menu.debug.amount, DebugMenu.AMOUNTS.size() - 1, "it wraps")
	_row(m, &"floor")
	await _key(m, "Enter")
	assert_eq(m.term.panel.rows.size(), FLOORS)
	assert_eq(m.term.panel.rows[0][1][0], "지금")
	await _key(m, "Escape")
	assert_eq(m.overlay, &"cheat")
	assert_eq(m.menu.debug.selected, DebugMenu.COMMANDS.find(&"floor"))


func test_a_storey_chosen_from_its_list_is_gone_to() -> void:
	var m := _main()
	await _key(m, "F4")
	_row(m, &"floor")
	await _key(m, "Enter")
	await _key(m, "Down")
	await _key(m, "Down")
	await _key(m, "Enter")
	assert_eq(m.world.depth, 3)
	assert_eq(m.overlay, &"")


func test_teleport_waits_for_a_tile_then_goes_on_enter_or_a_click() -> void:
	var m := _main()
	var start: Vector2i = m.world.player().pos
	await _key(m, "F4")
	await _key(m, "Enter")
	assert_eq(m.overlay, &"")
	assert_true(m.menu.debug.asking())
	assert_eq(m.hover, start, "the cursor starts on Miho")
	var at := _beside(m)
	await _key(m, Keys.keys_of(Keys.MOVES.find_key(at - start))[0])
	assert_eq(m.hover, at)
	await _key(m, "Enter")
	assert_false(m.menu.debug.asking())
	assert_eq(m.world.player().pos, at)
	assert_eq(m.world.round_no, 0)
	await _key(m, "F4")
	await _key(m, "Enter")
	await _click_tile(m, start)
	assert_eq(m.world.player().pos, start, "a click picks too")


func test_a_pick_that_does_not_fit_asks_again_and_escape_opens_the_list() -> void:
	var m := _main()
	await _key(m, "F4")
	await _key(m, "Enter")
	var acts: int = m.run.actions.size()
	await _key(m, "Enter")
	assert_true(m.menu.debug.asking(), "Miho's own tile is not a place to go")
	assert_eq(m.run.actions.size(), acts)
	await _key(m, "Escape")
	assert_false(m.menu.debug.asking())
	assert_eq(m.overlay, &"cheat")
	await _key(m, "Enter")
	await _click_tile(m, m.world.player().pos, MOUSE_BUTTON_RIGHT)
	assert_eq(m.overlay, &"cheat", "a right click gives up too")


func test_damage_picks_a_creature_with_tab_and_hurts_it_by_the_amount() -> void:
	var m := _main()
	var near := _foe(m, &"dokkaebi", Vector2i(1, 0))
	var far := _foe(m, &"bujigaengi", Vector2i(0, -4))
	var hp := far.hp
	await _key(m, "F4")
	_row(m, &"damage")
	m.menu.debug.amount = 0
	await _key(m, "Enter")
	assert_eq(m.hover, near.pos, "the cursor starts on the nearest creature")
	await _key(m, "Tab")
	assert_eq(m.hover, far.pos, "Tab moves it to the next")
	await _key(m, "Enter")
	assert_eq(far.hp, hp - 1)
	assert_false(m.menu.debug.asking())


func test_a_creature_pick_refuses_an_empty_tile_and_miho() -> void:
	var m := _main()
	_foe(m, &"dokkaebi", Vector2i(1, 0))
	await _key(m, "F4")
	_row(m, &"kill")
	await _key(m, "Enter")
	await _key(m, "Enter")
	assert_true(m.menu.debug.asking())
	m._look_at(m.world.player().pos)
	await _key(m, "Enter")
	assert_true(m.menu.debug.asking(), "Miho is not a creature to pick")
	assert_eq(m.menu.debug.head()[0][0][0], "적 제거: 적")


func test_moving_a_creature_picks_it_then_a_tile() -> void:
	var m := _main()
	var foe := _foe(m, &"dokkaebi", Vector2i(0, -3))
	var to := _beside(m)
	await _key(m, "F4")
	_row(m, &"move_foe")
	await _key(m, "Enter")
	await _key(m, "Enter")
	assert_true(m.menu.debug.asking())
	assert_eq(m.menu.debug.head()[0][0][0], "적 이동: 칸")
	await _click_tile(m, to)
	assert_eq(foe.pos, to)
	assert_false(m.menu.debug.asking())


func test_a_summoned_kind_stands_where_the_tile_is_picked() -> void:
	var m := _main()
	var to := _beside(m)
	await _key(m, "F4")
	_row(m, &"summon")
	await _key(m, "Enter")
	await _key(m, "Down")
	await _key(m, "Enter")
	await _click_tile(m, to)
	assert_eq(m.world.actor_at(to).kind, Codex.foes()[1])


func test_the_title_does_not_offer_the_commands_and_the_saved_run_stays() -> void:
	var path := "user://debug_title_save.cfg"
	var saved := SaveGame.new(path, 7)
	for i in 3:
		saved.record({t = &"wait"}, 0, false)
	var m := _main(path)
	assert_eq(m.state, &"title")
	await _key(m, "Escape")
	assert_eq(m.overlay, &"options")
	var names: Array = m.term.panel.rows.map(func(r): return r[0][0])
	assert_false(names.has(Menu.OPTION_NAMES[&"cheat"]), "no run is being played")
	var disk := SaveGame.load_from(path)
	assert_eq([disk.seed_value, disk.actions.size()], [7, 3], "the saved run is as it was")
	DirAccess.remove_absolute(path)


func test_a_right_click_in_a_list_of_its_own_goes_back_to_its_row_as_escape_does() -> void:
	var m := _main()
	await _key(m, "F4")
	_row(m, &"floor")
	await _key(m, "Enter")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	m._unhandled_input(click)
	assert_eq(m.overlay, &"cheat", "the page stays")
	assert_eq(m.menu.debug.page, &"", "on the commands")
	assert_eq(m.menu.debug.selected, DebugMenu.COMMANDS.find(&"floor"))
	m._unhandled_input(click)
	assert_eq(m.overlay, &"", "a second one closes it")


func test_a_held_key_never_answers_a_pick() -> void:
	var m := _main()
	_foe(m, &"dokkaebi", Vector2i(2, 0))
	await _key(m, "F4")
	_row(m, &"kill")
	await _key(m, "Enter")
	await _key(m, "Enter")
	assert_true(m.menu.debug.asking())
	var acts: int = m.run.actions.size()
	var held := Keys.event("Enter")
	held.pressed = true
	held.echo = true
	m._unhandled_input(held)
	await wait_until(func(): return not m.busy, 5)
	assert_true(m.menu.debug.asking(), "the repeat of the key that chose the row")
	assert_eq(m.run.actions.size(), acts)
