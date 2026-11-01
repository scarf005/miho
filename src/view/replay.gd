class_name Replay
extends RefCounted
## The storey's best moment, zoomed in on Miho and slowed down, over the game
## `m` (main.gd); any key skips it.

const ZOOM := 1.5
const SPEED := 0.7


static func play(m: Node) -> void:
	var window: Dictionary = m.reel.best()
	if window.is_empty():
		return
	var clip: Dictionary = m.reel.clip(window)
	var w: World = clip.world
	m.state = &"replay"
	m.skip = false
	m.term.replay = true
	m.term.speed = SPEED * m.settings.speed
	m.term.fit(m.get_viewport().get_visible_rect().size, 0.0)
	m.term.show_world(w)
	_follow(m, w, 0.5)
	await m.get_tree().create_timer(0.5).timeout
	for action in clip.actions:
		if m.skip:
			break
		var before := w.clone()
		var events := w.act(action)
		_follow(m, w, 0.6)
		await m.term.play(events, before, w)
		if not m.skip:
			await m.get_tree().create_timer(0.3).timeout
	m.pan.kill()
	m.term.replay = false
	m.term.speed = m.settings.speed
	m.state = &"play"
	m._fit()
	m.term.show_world(m.world)


## Pans the zoomed, whole-map screen so Miho stays in the middle without
## showing past the map; a map narrower than the screen stays centred.
static func _follow(m: Node, w: World, time: float) -> void:
	var view: Vector2 = m.get_viewport().get_visible_rect().size
	var whole := Vector2(Term.MAP.x + Grid.W, Grid.H + 2) * Term.CELL
	var k := minf(view.x / whole.x, view.y / whole.y) * ZOOM
	var map: Rect2 = m.term.map_rect()
	var at: Vector2 = view / 2.0 - m.term.cell_centre(w.player().pos) * k
	for axis in 2:
		var lo := view[axis] - map.end[axis] * k
		var hi := -map.position[axis] * k
		at[axis] = clampf(at[axis], lo, hi) if lo <= hi else (lo + hi) / 2.0
	m.pan = m.create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	m.pan.tween_property(m.term, "scale", Vector2(k, k), time)
	m.pan.tween_property(m.term, "position", at.round(), time)
	m.sfx.listener.position = m.term.cell_centre(w.player().pos)
