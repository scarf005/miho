class_name Panels
extends RefCounted
## The page open over the game `m` (main.gd), a Menu page: how it opens and closes,
## and what it does with the input it takes while it is open.

var m: Node
## The page open over the game (a full screen, or the debug box), or empty.
var overlay := &""


func _init(of: Node) -> void:
	m = of


## Shows a panel over the game: a Menu page.
func open(kind: StringName) -> void:
	m.menu.sync(m)
	overlay = kind
	if m.touch.enabled:
		m.fit()
	m.menu.open(kind, Vector2i(m.term.cols, m.term.rows))
	m.term.info = []
	m.term.example = {}
	m.term.panel = m.menu.panel()


## The Menu page takes keys; the wheel scrolls, a left click acts on the row or
## tab under the pointer, a right click goes back, and the mouse's side buttons go
## back and forward in the 도감.
func input(event: InputEvent) -> void:
	var menu: Menu = m.menu
	var term: Term = m.term
	if event is InputEventKey and event.keycode == KEY_SHIFT and not menu.waiting:
		return
	var command := &""
	var button: int = event.button_index if event is InputEventMouseButton else 0
	var local: Vector2 = m.to_term(event.position) if button != 0 else Vector2.ZERO
	if event is InputEventKey:
		command = menu.key(event)
	elif button == MOUSE_BUTTON_RIGHT:
		command = menu.back()
	elif button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		menu.wheel(1 if button == MOUSE_BUTTON_WHEEL_DOWN else -1, PanelView.aside_at(term, local))
	elif button in [MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		command = menu.history(button == MOUSE_BUTTON_XBUTTON2)
	elif button == MOUSE_BUTTON_LEFT:
		command = WordLink.click(m, local)
	match command:
		&"close":
			close()
			menu.debug.run(m)
			return
		&"changed":
			m.settings.save()
			m.apply()
		&"cast":
			close()
			m.casting.clear()
			m.casting.recall(menu.chosen.key())
			return
		&"restart":
			close()
			m.restart()
			return
		&"dispel":
			close()
			m.act({t = &"dispel", kind = menu.buffs[menu.selected]})
			return
		&"ask":
			m.sfx.play(&"warn")
		&"seed":
			m.copy_seed()
		&"quit":
			_quit()
			return
	term.panel = menu.panel()


## Takes the page down.
func close() -> void:
	overlay = &""
	m.term.panel = {}
	m.refresh()
	if m.touch.enabled:
		m.fit()


## Ends the game with the run kept; a web page cannot close itself, so it
## goes back to the title.
func _quit() -> void:
	if not OS.has_feature("web"):
		m.get_tree().quit()
		return
	close()
	m.new_run()
	m.show_title()
