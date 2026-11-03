class_name TouchBase
extends GutTest
## What the tests of touch play share: a hall with Miho in it as a game scene, and
## fingers put on its screen.

const TARGET := TouchHud.TARGET


func before_each() -> void:
	Keys.reset()
	PanelView.stride = 1


func after_all() -> void:
	Keys.reset()
	PanelView.stride = 1


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
	w.depth = 5
	w.tails = 5
	w.cards.assign([Cards.FOX, Cards.ORB, Cards.FIRE, Cards.WATER])
	return w


func _main(touch := true) -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	m.new_run(3)
	m.state = &"play"
	m.term.speed = 1000.0
	m.world = _hall()
	m.settings.spells = {}
	m.settings.path = ""
	m.touch.probing = false
	m.touch.dpr = 1.0
	m.touch.enabled = touch
	m.touch._dress()
	m.apply()
	m.term.show_world(m.world)
	m.forecast()
	return m


func _screen(m: Node, local: Vector2) -> Vector2:
	return m.term.get_global_transform() * local


func _tile_at(m: Node, tile: Vector2i) -> Vector2:
	return _screen(m, m.term.cell_centre(tile))


## The centre of a HUD target, by its id (and place).
func _hud(m: Node, id: StringName, n := -2) -> Vector2:
	for item in m.touch.hud._items(m.term):
		if item.id == id and (n == -2 or item.n == n):
			return _screen(m, item.rect.get_center())
	fail_test("no HUD target %s" % id)
	return Vector2.ZERO


func _touch_event(down: bool, at: Vector2, id := 0) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = id
	e.pressed = down
	e.position = at
	return e


## A finger down at `from`, moved to `to`, up.
func _finger(m: Node, from: Vector2, to := Vector2.INF) -> void:
	to = from if to == Vector2.INF else to
	m._unhandled_input(_touch_event(true, from))
	if to != from:
		var d := InputEventScreenDrag.new()
		d.position = to
		d.relative = to - from
		m._unhandled_input(d)
	m._unhandled_input(_touch_event(false, to))


## A finger put down at `at` and held for `seconds`, then lifted.
func _hold(m: Node, at: Vector2, seconds := 1.0) -> void:
	m.touch.input(_touch_event(true, at), 0.0)
	m.touch.tick(seconds)


func _lift(m: Node, at: Vector2) -> void:
	m._unhandled_input(_touch_event(false, at))


## Lets the round in progress finish.
func _settle(m: Node) -> void:
	for i in 200:
		if not m.busy:
			return
		await get_tree().process_frame


func _me(m: Node) -> Vector2i:
	return m.world.player().pos


func _rows(m: Node, row: int) -> Vector2:
	var y := (3.0 + row * PanelView.stride + PanelView.stride / 2.0) * Term.CELL.y
	return _screen(m, Vector2(4.0 * Term.CELL.x, y))
