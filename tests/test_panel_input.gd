extends GutTest
## The full-screen pages over the game take the events a player sends: held
## keys, the wheel, the pointer and clicks, whichever list is open.


func before_each() -> void:
	Keys.reset()


func after_all() -> void:
	Keys.reset()


## The game with a screen `rows` cells high, 6 list rows at 10.
func _main(rows := 18) -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	m._new_run(3)
	m.state = &"play"
	m.glass.visible = false
	m.term.rows = rows
	return m


func _key(m: Node, key: String, echo := false) -> void:
	var e := Keys.event(key)
	e.pressed = true
	e.echo = echo
	m._unhandled_input(e)


## The screen point at the middle of cell (x, y).
func _at(m: Node, x: int, y: int) -> Vector2:
	return m.term.get_global_transform() * ((Vector2(x, y) + Vector2(0.5, 0.5)) * Term.CELL)


func _mouse(m: Node, button: int, x: int, y: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = _at(m, x, y)
	m._unhandled_input(e)


func _move(m: Node, x: int, y: int) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _at(m, x, y)
	m._unhandled_input(e)


func _codex(m: Node) -> void:
	m._open(&"codex")


func test_the_game_menu_opens_the_codex_and_esc_returns_to_it() -> void:
	var m := _main()
	_key(m, "Escape")
	assert_eq(m.term.panel.title, "설정")
	m.menu.selected = Menu.OPTIONS.find(&"codex")
	_key(m, "Enter")
	assert_eq(m.term.panel.title, "도감")
	_key(m, "Escape")
	assert_eq(m.overlay, &"options", "the game menu is still open")
	assert_eq(m.term.panel.title, "설정")
	assert_eq(m.term.panel.selected, Menu.OPTIONS.find(&"codex"))
	_key(m, "Escape")
	assert_eq(m.overlay, &"", "the second Esc closes the menu")


func test_a_clicked_codex_row_of_the_game_menu_opens_it() -> void:
	var m := _main()
	_key(m, "Escape")
	var row: int = Menu.OPTIONS.find(&"codex")
	assert_lt(row, 14, "the row is on screen")
	_mouse(m, MOUSE_BUTTON_LEFT, 5, 3 + row)
	assert_eq(m.term.panel.title, "도감")


func test_a_held_arrow_repeats_in_the_codex_the_game_menu_and_the_key_page() -> void:
	var m := _main()
	_codex(m)
	_key(m, "Down")
	_key(m, "Down", true)
	_key(m, "Down", true)
	assert_eq(m.term.panel.selected, 3)
	_key(m, "Escape")
	_key(m, "Escape")
	_key(m, "Down")
	_key(m, "Down", true)
	assert_eq(m.term.panel.selected, 2, "the game menu repeats")
	_key(m, "Enter", true)
	assert_eq(m.overlay, &"options", "a held Enter does not act again")
	m.menu.selected = Menu.OPTIONS.find(&"keys")
	_key(m, "Enter")
	_key(m, "Down")
	_key(m, "Down", true)
	assert_eq(m.term.panel.selected, 2, "the key page repeats")


func test_wrap_page_and_ends_work_on_the_game_menu() -> void:
	var m := _main(10)
	var last := Menu.OPTIONS.size() - 1
	var page := Term.list_fits(10, 1)  # under the seed line
	_key(m, "Escape")
	_key(m, "Up")
	assert_eq(m.term.panel.selected, last, "Up from the first row wraps")
	assert_eq(m.term.panel.top, last - page + 1, "and the row is in view")
	_key(m, "Down")
	assert_eq(m.term.panel.selected, 0, "Down from the last row wraps")
	assert_eq(m.term.panel.top, 0)
	_key(m, "End")
	assert_eq(m.term.panel.selected, last)
	_key(m, "Home")
	assert_eq(m.term.panel.selected, 0)
	_key(m, "PageDown")
	assert_eq(m.term.panel.selected, page, "a page is the rows shown")
	for i in last / page:
		_key(m, "PageDown", true)
	assert_eq(m.term.panel.selected, last, "a page past the end stops there")
	for i in last / page + 1:
		_key(m, "PageUp", true)
	assert_eq(m.term.panel.selected, 0)


func test_the_pointer_lights_a_row_and_a_click_selects_it_in_the_codex() -> void:
	var m := _main()
	_codex(m)
	_move(m, 5, 3 + 4)
	assert_eq(m.term.panel.hover, 4)
	assert_eq(m.term.panel.selected, 0)
	_mouse(m, MOUSE_BUTTON_LEFT, 5, 3 + 4)
	assert_eq(m.term.panel.selected, 4)
	_move(m, Codex.SIDE_X + 2, 3)
	assert_eq(m.term.panel.hover, -1, "over the detail no row lights")


func test_the_wheel_scrolls_the_list_or_the_detail_by_where_the_pointer_is() -> void:
	var m := _main(10)
	_codex(m)
	m.menu.codex.selected = Codex.foes().find(&"cheonnyeon")
	m.term.panel = m.menu.panel()
	_mouse(m, MOUSE_BUTTON_WHEEL_DOWN, 5, 8)
	assert_eq(m.term.panel.top, ListNav.WHEEL)
	assert_eq(m.term.panel.selected, Codex.foes().find(&"cheonnyeon"))
	assert_false(m.term.panel.aside_up)
	_mouse(m, MOUSE_BUTTON_WHEEL_DOWN, Codex.SIDE_X + 2, 8)
	assert_true(m.term.panel.aside_up, "over the detail it scrolls the detail")
	assert_eq(m.term.panel.top, ListNav.WHEEL)
	_mouse(m, MOUSE_BUTTON_WHEEL_UP, 5, 8)
	assert_eq(m.term.panel.top, 0)


func test_a_click_on_a_tab_of_the_codex_shows_it() -> void:
	var m := _main()
	_codex(m)
	var x := 6.0
	for k in 3:
		x += Term._cells(Codex.TABS[k]) + 1.0
	_mouse(m, MOUSE_BUTTON_LEFT, int(x), 1)
	assert_eq(m.term.panel.tab, 3)


func test_the_log_scrolls_and_esc_or_its_key_closes_it() -> void:
	var m := _main(10)
	for i in 40:
		m.messages.add([["쪽지 %d" % i, Palette.TEXT]], 0)
	_key(m, "P")
	assert_eq(m.overlay, &"log")
	assert_eq(m.term.panel.selected, m.term.panel.rows.size() - 1, "it opens on the newest")
	_key(m, "Home")
	assert_eq(m.term.panel.top, 0)
	_key(m, "Shift")
	assert_eq(m.overlay, &"log", "a modifier alone does not close it")
	_mouse(m, MOUSE_BUTTON_WHEEL_DOWN, 5, 8)
	assert_eq(m.term.panel.top, ListNav.WHEEL)
	_key(m, "Escape")
	assert_eq(m.overlay, &"")
	_key(m, "P")
	_key(m, "P")
	assert_eq(m.overlay, &"", "the log key closes it")


func test_the_help_page_scrolls_and_a_modifier_or_click_does_not_close_it() -> void:
	var m := _main()
	_key(m, "F1")
	_key(m, "Shift")
	_mouse(m, MOUSE_BUTTON_LEFT, 5, 5)
	assert_eq(m.overlay, &"help")
	assert_eq(m.term.panel.selected, 2, "the click selects the row")
	_key(m, "Escape")
	assert_eq(m.overlay, &"")
