extends GutTest
## The map shakes when the ground gives way, once a round, and nowhere else.

const E := Vector2i(1, 0)
const ME := Codex.ME
const QUAKE := {t = &"quake", at = ME, tiles = []}
const SINK := {t = &"become", at = ME, tiles = [], tile = World.SKY}
const WAIT := {t = &"drum", at = ME, wet = false}


func _game(w: World) -> Node:
	var m: Node = Built.main()
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
	w._changed()
	w.sense()
	return w


func test_a_sinkhole_cast_shakes_the_map() -> void:
	var w := _stage()
	var m := _game(w)
	var before := w.clone()
	var events := w.act({t = &"cast", spells = [{cards = Cards.recipe(&"sinkhole"), dir = E}]})
	assert_true(events.any(Shake.by))
	m.term.play(events, before, w)
	m.term.rush()
	assert_true(m.term.shaking())
	assert_ne(Shake.offset(m.term.time - m.term.shook), Vector2.ZERO)


func test_other_tiles_made_do_not_shake() -> void:
	for tile in [World.BRIDGE, World.MUD, World.SHALLOW]:
		assert_false(Shake.by({t = &"become", at = ME, tiles = [], tile = tile}))


func test_the_shake_fades_to_none() -> void:
	assert_eq(Shake.offset(Shake.LIFE), Vector2.ZERO)
	assert_eq(Shake.offset(Shake.LIFE * 10.0), Vector2.ZERO)
	assert_eq(Shake.offset(-1.0), Vector2.ZERO)


func test_two_triggers_in_a_round_shake_once() -> void:
	var w := _stage()
	var m := _game(w)
	m.term.play([QUAKE, WAIT, SINK], w.clone(), w)
	var began: float = m.term.shook
	assert_true(m.term.shaking())
	m.term.time += 10.0
	assert_false(m.term.shaking())
	m.term.rush()
	assert_eq(m.term.shook, began, "the second trigger did not start another")
	assert_false(m.term.shaking())


func test_the_next_round_shakes_again() -> void:
	var w := _stage()
	var m := _game(w)
	m.term.play([QUAKE], w.clone(), w)
	m.term.time += 10.0
	assert_false(m.term.shaking())
	m.term.play([SINK], w.clone(), w)
	assert_true(m.term.shaking())


func test_a_round_without_a_trigger_does_not_shake() -> void:
	var w := _stage()
	var m := _game(w)
	m.term.play([WAIT], w.clone(), w)
	assert_false(m.term.shaking())
	m.term.rush()


func test_a_still_picture_does_not_shake() -> void:
	var w := _stage()
	var m := _game(w)
	m.term.still = true
	m.term.play([QUAKE, SINK], w.clone(), w)
	assert_false(m.term.shaking())
	assert_eq(Shake.offset(m.term.time - m.term.shook), Vector2.ZERO)
