extends GutTest
## The seed: a click on the game-over banner and Enter on the options row copy it.

var _copies: Array[String] = []
var _clipboard: Callable


func before_each() -> void:
	_copies = []
	_clipboard = Banner.clipboard
	Banner.clipboard = func(text: String) -> void: _copies.append(text)


func after_each() -> void:
	Banner.clipboard = _clipboard


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m.new_run(7)
	m.state = &"play"
	m.term.speed = 1000.0
	return m


func test_a_click_on_the_seed_line_of_the_banner_copies_the_seed() -> void:
	var m := _main()
	m.term.banner_lines = Banner.over(m.world, 0, m.run_seed)
	m.state = &"over"
	var click := func(line: int) -> void:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		var r: Rect2 = Banner.rect(m.term, line)
		e.position = m.term.get_global_transform() * ((r.position + r.size / 2.0) * Term.CELL)
		m._unhandled_input(e)
	click.call(0)
	assert_eq(_copies, [])
	assert_eq(m.state, &"over")
	click.call(Banner.SEED)
	assert_eq(_copies, [str(m.run_seed)])
	assert_eq(m.state, &"over")


func test_enter_on_the_seed_row_of_the_options_copies_it() -> void:
	var m := _main()
	m.menu.seed_value = m.run_seed
	m.menu.open(&"options")
	m.panels.overlay = &"options"
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	var presses := 0
	while Menu.OPTIONS[m.menu.selected] != &"seed" and presses < Menu.OPTIONS.size():
		m.menu.key(down)
		presses += 1
	assert_eq(Menu.OPTIONS[m.menu.selected], &"seed", "reached with the arrow keys")
	m.panels.input(enter)
	assert_eq(_copies, [str(m.run_seed)])
