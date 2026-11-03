extends GutTest
## The burst of an orb is drawn as the orb touches, whatever it hurts or kills first.

const E := Vector2i(1, 0)
const ME := Codex.ME


func _game(w: World) -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	m.new_run(1)
	m.state = &"play"
	m.world = w
	return m


func _stage() -> World:
	var w := Codex.stage()
	w.depth = 5
	w.tails = 20
	w.cards.assign(Cards.ALL)
	w.tiles[Grid.index(ME + Vector2i(2, 3))] = World.LANTERN
	w._changed()
	w.sense()
	return w


## The flashes drawn when `kind` of event from a round of hurling `cards` starts it.
func _flashed_at_the_touch(w: World, cards: Array, kind: StringName) -> Dictionary:
	var m := _game(w)
	var before := w.clone()
	var events := w.act({t = &"cast", spells = [{cards = cards, dir = E}]})
	var touch: int = events.map(func(e): return e.t).find(kind)
	assert_gt(touch, -1)
	var at: Vector2i = events[touch].at
	m.term.play(events.slice(touch), before, w)
	var drawn: Array = m.term.anim.flashes.map(func(f): return f.at)
	m.term.rush()
	return {at = at, drawn = drawn}


func _ring_is_drawn(seen: Dictionary) -> void:
	for d in Grid.DIRS:
		assert_has(seen.drawn, seen.at + d)


func test_a_blast_is_drawn_as_the_orb_touches_a_creature() -> void:
	var w := _stage()
	var foe := FloorGen.spawn(w, &"jangseung", ME + E * 2)
	foe.hp = 99
	_ring_is_drawn(
		_flashed_at_the_touch(w, [Cards.ORB, Cards.ORB, Cards.ORB, Cards.ORB, Cards.ORB], &"hit")
	)


func test_a_blast_is_drawn_as_the_orb_touches_a_wall() -> void:
	var w := _stage()
	w.tiles[Grid.index(ME + E * 3)] = World.WALL
	w._changed()
	_ring_is_drawn(
		_flashed_at_the_touch(w, [Cards.ORB, Cards.ORB, Cards.ORB, Cards.ORB, Cards.ORB], &"burst")
	)
