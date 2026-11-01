extends TouchBase
## Accidents the game asks about or refuses: a step onto a found plate, fire or a
## drop, a held key that walks on when a creature comes into sight, resting with
## an awake enemy in sight.

const ME := Vector2i(4, 8)
const E := Vector2i(1, 0)


func _press(m: Node, key: String, echo := false) -> void:
	var e := Keys.event(key)
	e.pressed = true
	e.echo = echo
	m._key(e)


func _settle(m: Node) -> void:
	while m.busy or m.walking:
		await get_tree().process_frame


func _keyboard() -> Node:
	return _main(false)


## A touch screen on the window the touch tests lay out for.
func _phone() -> Node:
	get_tree().root.size = Vector2i(1280, 720)
	return _main(true)


## A collapsing floor Miho has found, east of her.
func _plate(m: Node) -> void:
	m.world.traps[ME + E] = World.TRAP_COLLAPSE
	m.world.set_tile(ME + E, World.TRAP_COLLAPSE)
	m._forecast()


## Fire on the tile next to her, east unless told.
func _blaze(m: Node, d := E) -> void:
	m.world.burning[ME + d] = 5
	m._forecast()


## A creature under a lantern, so that Miho sees it from where she stands.
func _foe(m: Node, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(m.world, &"dokkaebi", at)
	a.cooldown = 99
	m.world.set_tile(at + Vector2i.UP, World.LANTERN)
	m.world.sense()
	m._forecast()
	assert_true(Travel.in_sight(m.world).has(a.id), "Miho sees it")
	return a


func _prompt(m: Node) -> String:
	return Messages.plain(m.term.log_lines.back()[0]) if not m.term.log_lines.is_empty() else ""


func test_a_fresh_press_into_a_found_plate_asks_and_takes_no_turn() -> void:
	var m := _keyboard()
	_plate(m)
	var round_no: int = m.world.round_no
	var saved: int = m.run.actions.size()
	_press(m, "Right")
	assert_eq(m.world.player().pos, ME)
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.run.actions.size(), saved, "a prompt is not in the save")
	assert_eq(m.guard.asking, E)
	assert_string_contains(_prompt(m), Tiles.of(World.TRAP_COLLAPSE, "name"))
	assert_string_ends_with(_prompt(m), "Y/N")


func test_the_same_direction_again_steps_onto_the_fire() -> void:
	var m := _keyboard()
	_blaze(m)
	_press(m, "Right")
	assert_eq(m.world.player().pos, ME)
	_press(m, "Right")
	await _settle(m)
	assert_eq(m.world.player().pos, ME + E)
	assert_eq(m.guard.asking, Vector2i.ZERO)


func test_y_steps_onto_the_found_plate_and_drops_her_a_storey() -> void:
	var m := _keyboard()
	_plate(m)
	var depth: int = m.world.depth
	_press(m, "Right")
	_press(m, "Y")
	await _settle(m)
	assert_lt(m.world.depth, depth)


func test_another_direction_cancels_the_prompt_and_walks() -> void:
	var m := _keyboard()
	_blaze(m)
	_press(m, "Right")
	_press(m, "Down")
	await _settle(m)
	assert_eq(m.world.player().pos, ME + Vector2i.DOWN)
	assert_eq(m.guard.asking, Vector2i.ZERO)
	assert_ne(_prompt(m), "")
	assert_false(_prompt(m).ends_with("Y/N"))


func test_another_action_cancels_the_prompt_and_is_handled_normally() -> void:
	var m := _keyboard()
	_blaze(m)
	var round_no: int = m.world.round_no
	_press(m, "Right")
	_press(m, "X")
	assert_true(m.looking, "the look key still looks")
	assert_eq(m.guard.asking, Vector2i.ZERO)
	assert_false(_prompt(m).ends_with("Y/N"))
	assert_eq(m.world.round_no, round_no)


func test_after_a_cancel_the_next_press_asks_again() -> void:
	var m := _keyboard()
	_blaze(m)
	_press(m, "Right")
	_press(m, "Period")
	await _settle(m)
	_press(m, "Right")
	assert_eq(m.world.player().pos, ME)
	assert_eq(m.guard.asking, E)


func test_a_held_key_never_steps_onto_danger_or_confirms() -> void:
	var m := _keyboard()
	_blaze(m)
	_press(m, "Right", true)
	assert_eq(m.world.player().pos, ME)
	assert_eq(m.guard.asking, Vector2i.ZERO, "a repeat does not ask")
	_press(m, "Right")
	_press(m, "Right", true)
	assert_eq(m.world.player().pos, ME, "a repeat does not confirm")
	assert_eq(m.guard.asking, E)


func test_a_held_key_still_walks_where_it_is_safe() -> void:
	var m := _keyboard()
	_blaze(m)
	_press(m, "Down", true)
	await _settle(m)
	assert_eq(m.world.player().pos, ME + Vector2i.DOWN)


func test_every_kind_of_found_plate_asks_though_the_forecast_shows_no_harm() -> void:
	var m := _keyboard()
	for kind in [World.TRAP_ALARM, World.TRAP_FIRE, World.TRAP_VINE]:
		m.world.traps[ME + E] = kind
		m.world.set_tile(ME + E, kind)
		m._forecast()
		assert_eq(m.ahead[E].hurt_me(), 0, "the round of the step hurts nobody")
		_press(m, "Right")
		assert_eq(m.guard.asking, E)
		assert_eq(m.world.player().pos, ME)
		m._unask()


func test_a_plate_not_found_yet_is_stepped_on_without_asking() -> void:
	var m := _keyboard()
	m.world.traps[ME + E] = World.TRAP_ALARM
	m._forecast()
	_press(m, "Right")
	await _settle(m)
	assert_eq(m.world.player().pos, ME + E)


func test_harm_beside_a_creature_does_not_ask() -> void:
	var m := _keyboard()
	var foe := _foe(m, ME + Vector2i(3, 0))
	foe.cooldown = 0
	foe.alert = Actor.HUNT
	m._forecast()
	_press(m, "Right")
	await _settle(m)
	assert_eq(m.world.player().pos, ME + E)
	assert_eq(m.guard.asking, Vector2i.ZERO)


func test_the_prompt_on_a_touch_screen_has_no_keys_in_it_and_a_second_swipe_steps() -> void:
	var m := _phone()
	_blaze(m)
	var from := _tile_at(m, Vector2i(10, 8))
	_finger(m, from, from + Vector2(80, 0))
	assert_eq(m.world.player().pos, ME)
	assert_eq(m.guard.asking, E)
	assert_ne(_prompt(m), "")
	assert_false("Y/N" in _prompt(m))
	_finger(m, from, from + Vector2(80, 0))
	await _settle(m)
	assert_eq(m.world.player().pos, ME + E)


func test_a_second_tap_on_the_tile_steps() -> void:
	var m := _phone()
	_blaze(m, Vector2i(1, 1))
	_finger(m, _tile_at(m, ME + Vector2i(1, 1)))
	assert_eq(m.guard.asking, Vector2i(1, 1))
	assert_eq(m.world.player().pos, ME)
	_finger(m, _tile_at(m, ME + Vector2i(1, 1)))
	await _settle(m)
	assert_eq(m.world.player().pos, ME + Vector2i(1, 1))


func test_a_tap_elsewhere_cancels_the_prompt_and_acts() -> void:
	var m := _phone()
	_blaze(m, Vector2i(1, 1))
	_finger(m, _tile_at(m, ME + Vector2i(1, 1)))
	_finger(m, _tile_at(m, ME + Vector2i(1, -1)))
	await _settle(m)
	assert_eq(m.guard.asking, Vector2i.ZERO)
	assert_eq(m.world.player().pos, ME + Vector2i(1, -1))


func test_a_held_key_stops_when_a_creature_comes_into_sight() -> void:
	var m := _keyboard()
	_press(m, "Left")
	await _settle(m)
	_foe(m, ME + Vector2i(5, 0))
	var at: Vector2i = m.world.player().pos
	_press(m, "Left", true)
	await _settle(m)
	assert_eq(m.world.player().pos, at, "the repeat is ignored")
	_press(m, "Left")
	await _settle(m)
	assert_eq(m.world.player().pos, at + Vector2i.LEFT, "a fresh press always works")


func test_a_held_key_walks_on_past_a_creature_already_in_sight() -> void:
	var m := _keyboard()
	_foe(m, ME + Vector2i(5, 0))
	_press(m, "Left")
	await _settle(m)
	_press(m, "Left", true)
	await _settle(m)
	assert_eq(m.world.player().pos, ME + Vector2i(-2, 0))


func test_rest_refuses_with_an_awake_enemy_in_sight_and_takes_no_turn() -> void:
	var m := _keyboard()
	_foe(m, ME + Vector2i(5, 0))
	m.world.tails = 1
	assert_true(Travel.watched(m.world))
	var round_no: int = m.world.round_no
	_press(m, "Z")
	await _settle(m)
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.messages.lines.back().text, m.WATCHED[&"rest"])


func test_rest_works_with_no_enemy_in_sight() -> void:
	var m := _keyboard()
	m.world.tails = 1
	var round_no: int = m.world.round_no
	_press(m, "Z")
	await _settle(m)
	assert_gt(m.world.round_no, round_no)
	assert_eq(m.world.tails, m.world.max_tails())
