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
		m.new_run(3)
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
	m.forecast()
	return m.world.actor_at(at)


## The screen point at the middle of cell `c`.
func _at(m: Node, c: Vector2) -> Vector2:
	return m.term.get_global_transform() * ((c + Vector2(0.5, 0.5)) * Term.CELL)


func _mouse(m: Node, c: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _at(m, c)
	m._unhandled_input(move)
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = move.position
	m._unhandled_input(e)
	await wait_until(func(): return not m.busy, 5)


## The cell of list row `k` of the open box, as the pointer finds it.
func _row_cell(m: Node, k: int) -> Vector2:
	var span := PanelView.span(m.term)
	var box := PanelView.frame(m.term)
	return box.position + Vector2(3, 3 + (k - span.x) * PanelView.stride)


func test_the_key_opens_the_commands_in_a_box_and_escape_closes_them() -> void:
	var m := _main()
	await _key(m, "F4")
	assert_eq(m.overlay, &"cheat")
	var names: Array = m.term.panel.rows.map(func(r): return r[0][0])
	assert_eq(names, DebugMenu.COMMANDS.map(func(c): return Cheat.NAME[c]))
	var box := PanelView.frame(m.term)
	assert_false(m.term.panel.get("opaque", false), "the game is still drawn")
	assert_true(box.size.x < m.term.cols, "map beside the box")
	assert_true(box.end.y <= m.term.rows - 2, "the status rows under the box")
	await _key(m, "Escape")
	assert_eq(m.overlay, &"")
	assert_true(m.term.panel.is_empty())
	await _key(m, "F4")
	await _key(m, "F4")
	assert_eq(m.overlay, &"", "its key closes it too")


func test_the_game_menu_row_opens_the_box_and_escape_closes_to_the_game() -> void:
	var m := _main()
	await _key(m, "Escape")
	m.menu.selected = Menu.OPTIONS.find(&"cheat")
	await _key(m, "Enter")
	assert_eq(m.term.panel.rows.size(), DebugMenu.COMMANDS.size())
	assert_true(m.term.panel.has("box"), "not the settings page")
	await _key(m, "Escape")
	assert_true(m.term.panel.is_empty(), "no settings page behind it")
	assert_eq(m.overlay, &"")
	assert_eq(m.state, &"play")


func test_a_right_click_on_the_box_from_the_game_menu_closes_it_to_the_game() -> void:
	var m := _main()
	await _key(m, "Escape")
	m.menu.selected = Menu.OPTIONS.find(&"cheat")
	await _key(m, "Enter")
	await _mouse(m, Vector2(2, 2), MOUSE_BUTTON_RIGHT)
	assert_eq(m.overlay, &"")
	assert_true(m.term.panel.is_empty())


func test_a_toggle_is_played_and_recorded_and_the_list_is_back_on_its_row() -> void:
	var m := _main()
	await _key(m, "F4")
	_row(m, &"god")
	await _key(m, "Enter")
	assert_true(Cheat.on(m.world, &"god"))
	assert_eq(m.run.actions.back(), {t = &"cheat", cmd = &"god"})
	assert_eq(m.overlay, &"cheat", "the list is back")
	assert_eq(m.term.panel.rows[DebugMenu.COMMANDS.find(&"god")][1][0], "켜짐")
	assert_eq(m.menu.debug.selected, DebugMenu.COMMANDS.find(&"god"), "it keeps its row")
	await _key(m, "Enter")
	assert_false(Cheat.on(m.world, &"god"), "a second command without opening it again")
	assert_eq(m.overlay, &"cheat")


func test_a_command_hides_the_box_while_it_plays() -> void:
	var m := _main()
	await _key(m, "F4")
	_row(m, &"god")
	var during := []
	m.term.shown.connect(func(_e, _at): during.append(m.overlay))
	await _key(m, "Enter")
	assert_false(during.is_empty(), "the command showed an event")
	assert_true(during.all(func(o): return o == &""), "the game shows the command")
	assert_eq(m.overlay, &"cheat")


func test_a_command_that_ends_the_run_does_not_open_the_list_again() -> void:
	var m := _main()
	await _key(m, "F4")
	_row(m, &"god")
	m.term.shown.connect(func(_e, _at): m.world.outcome = &"lost")
	await _key(m, "Enter")
	assert_eq(m.state, &"over")
	assert_eq(m.overlay, &"", "the ending shows as usual")
	assert_true(m.term.panel.is_empty())


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


func test_a_storey_chosen_from_its_list_is_gone_to_and_the_list_stays_on_its_row() -> void:
	var m := _main()
	await _key(m, "F4")
	_row(m, &"floor")
	await _key(m, "Enter")
	await _key(m, "Down")
	await _key(m, "Down")
	await _key(m, "Enter")
	assert_eq(m.world.depth, 3)
	assert_eq(m.overlay, &"cheat", "another storey keeps the list open")
	assert_eq(m.menu.debug.page, &"floor")
	assert_eq(m.menu.debug.selected, 2)
	assert_eq(m.term.panel.rows[2][1][0], "지금")
	await _key(m, "Escape")
	assert_eq(m.menu.debug.selected, DebugMenu.COMMANDS.find(&"floor"))
	await _key(m, "Escape")
	assert_eq(m.overlay, &"")


func test_teleport_waits_for_a_tile_then_goes_on_enter_or_a_click() -> void:
	var m := _main()
	var start: Vector2i = m.world.player().pos
	await _key(m, "F4")
	await _key(m, "Enter")
	assert_eq(m.overlay, &"", "the box is hidden for the pick")
	assert_true(m.term.panel.is_empty())
	assert_true(m.menu.debug.asking())
	assert_eq(m.look.hover, start, "the cursor starts on Miho")
	var at := _beside(m)
	await _key(m, Keys.keys_of(Keys.MOVES.find_key(at - start))[0])
	assert_eq(m.look.hover, at)
	await _key(m, "Enter")
	assert_false(m.menu.debug.asking())
	assert_eq(m.world.player().pos, at)
	assert_eq(m.world.round_no, 0)
	assert_eq(m.overlay, &"cheat", "the list is back after the pick")
	assert_eq(m.menu.debug.selected, DebugMenu.COMMANDS.find(&"teleport"))
	await _key(m, "Enter")
	await _click_tile(m, start)
	assert_eq(m.world.player().pos, start, "a click picks too")
	assert_eq(m.overlay, &"cheat")


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
	await _key(m, "Escape")
	assert_eq(m.overlay, &"", "and Esc on the list closes it to the game")


func test_damage_picks_a_creature_with_tab_and_hurts_it_by_the_amount() -> void:
	var m := _main()
	var near := _foe(m, &"dokkaebi", Vector2i(1, 0))
	var far := _foe(m, &"bujigaengi", Vector2i(0, -4))
	var hp := far.hp
	await _key(m, "F4")
	_row(m, &"damage")
	m.menu.debug.amount = 0
	await _key(m, "Enter")
	assert_eq(m.look.hover, near.pos, "the cursor starts on the nearest creature")
	await _key(m, "Tab")
	assert_eq(m.look.hover, far.pos, "Tab moves it to the next")
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
	m.look.at(m.world.player().pos)
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
	saved.flush()
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


func test_a_creature_picked_for_damage_brings_the_list_back_on_that_row() -> void:
	var m := _main()
	_foe(m, &"dokkaebi", Vector2i(1, 0))
	await _key(m, "F4")
	_row(m, &"damage")
	await _key(m, "Enter")
	await _key(m, "Enter")
	assert_eq(m.overlay, &"cheat")
	assert_eq(m.menu.debug.selected, DebugMenu.COMMANDS.find(&"damage"))


func test_a_row_is_found_where_the_box_draws_it_and_a_click_on_it_plays_it() -> void:
	var m := _main()
	await _key(m, "F4")
	var god := DebugMenu.COMMANDS.find(&"god")
	for k in DebugMenu.COMMANDS.size():
		var local: Vector2 = (_row_cell(m, k) + Vector2(0.5, 0.5)) * Term.CELL
		assert_eq(PanelView.row_at(m.term, local), k, "row %d" % k)
	var box := PanelView.frame(m.term)
	var left := (box.position - Vector2(1, -4)) * Term.CELL
	assert_eq(PanelView.row_at(m.term, left), -1, "beside the box is no row")
	var below := (box.position + Vector2(3, box.size.y + 1)) * Term.CELL
	assert_eq(PanelView.row_at(m.term, below), -1, "under the box is no row")
	await _mouse(m, _row_cell(m, god))
	assert_true(Cheat.on(m.world, &"god"))
	assert_eq(m.overlay, &"cheat")
	assert_eq(m.menu.debug.selected, god)


func test_the_pointer_lights_the_row_it_is_over_and_a_click_beside_the_box_does_nothing() -> void:
	var m := _main()
	await _key(m, "F4")
	var move := InputEventMouseMotion.new()
	move.position = _at(m, _row_cell(m, 3))
	m._unhandled_input(move)
	assert_eq(m.term.panel.hover, 3)
	var acts: int = m.run.actions.size()
	await _mouse(m, Vector2(2, 6))
	assert_eq(m.run.actions.size(), acts, "not a step on the map under it")
	assert_eq(m.overlay, &"cheat")


func test_the_wheel_scrolls_a_list_that_does_not_fit_and_keeps_the_selection_in_view() -> void:
	var m := _main()
	m.term.rows = 9
	await _key(m, "F4")
	var count: int = DebugMenu.COMMANDS.size()
	assert_true(PanelView.span(m.term).y < count, "a box that scrolls")
	await _key(m, "End")
	var shown := PanelView.span(m.term)
	assert_eq(m.term.panel.selected, count - 1)
	assert_true(count - 1 >= shown.x and count - 1 < shown.x + shown.y)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	m._unhandled_input(wheel)
	assert_true(PanelView.span(m.term).x < shown.x, "the wheel scrolled up")


func test_the_box_fits_every_screen_and_zoom_with_the_status_rows_left() -> void:
	var m := _main()
	for zoom in Settings.ZOOMS:
		for view in [Vector2(1280, 720), Vector2(390, 844), Vector2(844, 390)]:
			m.term.fit(view, zoom)
			m.menu.room = Vector2i(m.term.cols, m.term.rows)
			m.menu.debug.selected = 0
			m._open(&"cheat")
			var box := PanelView.frame(m.term)
			var where := "%s at %s" % [view, zoom]
			assert_true(box.position.x >= 0 and box.end.x <= m.term.cols, where)
			assert_true(box.position.y >= 0 and box.end.y <= maxf(5, m.term.rows - 2), where)
			var shown := PanelView.span(m.term)
			assert_true(shown.y >= 1 and shown.y * PanelView.stride + 4 <= box.size.y, where)
			await _key(m, "End")
			shown = PanelView.span(m.term)
			var last: int = DebugMenu.COMMANDS.size() - 1
			assert_true(last >= shown.x and last < shown.x + shown.y, "End in view " + where)
			m._close()


func test_the_box_keeps_off_miho_and_beside_the_creature_list() -> void:
	var m := _main()
	m._open(&"cheat")
	var corner: Rect2 = m.term.panel.box
	var me: Actor = m.world.player()
	me.pos = Vector2i(corner.get_center().x, corner.end.y - 1) - m.term.side + m.term.cam
	assert_true(Grid.inside(me.pos), "a tile under the corner")
	var box := PanelView.frame(m.term)
	assert_false(box.has_point(m.term.cell_of(me.pos)), "Miho stays in view")
	assert_eq(box.position.x, float(m.term.side.x))
	assert_eq(PanelView.row_at(m.term, (box.position + Vector2(3, 3.5)) * Term.CELL), 0)


func test_a_touch_screen_spaces_the_rows_by_its_stride_and_finds_them_there() -> void:
	var m := _main()
	PanelView.stride = 2
	await _key(m, "F4")
	for k in mini(PanelView.span(m.term).y, DebugMenu.COMMANDS.size()):
		var local: Vector2 = (_row_cell(m, k) + Vector2(0.5, 0.5)) * Term.CELL
		assert_eq(PanelView.row_at(m.term, local), k, "row %d" % k)
	var box := PanelView.frame(m.term)
	assert_true(PanelView.span(m.term).y * 2 + 4 <= box.size.y)
	PanelView.stride = 1


func test_the_debug_label_opens_the_box_when_clicked_and_does_nothing_when_the_view_is_off(
) -> void:
	var m := _main()
	await wait_process_frames(2)
	await _mouse(m, StatusBar.debug_label(m.term).position)
	assert_eq(m.overlay, &"", "no label while the debug view is off")
	await _key(m, "F3")
	assert_true(m.debugging)
	await _mouse(m, StatusBar.debug_label(m.term).position)
	assert_eq(m.overlay, &"cheat")
	assert_true(m.term.panel.has("box"))
	await _key(m, "Escape")
	assert_eq(m.overlay, &"", "Esc closes it to the game")
	assert_true(m.term.panel.is_empty())
