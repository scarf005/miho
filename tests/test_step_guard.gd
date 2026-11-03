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
	m.forecast()


## Fire on the tile next to her, east unless told.
func _blaze(m: Node, d := E) -> void:
	m.world.burning[ME + d] = 5
	m.forecast()


## A creature under a lantern, so that Miho sees it from where she stands.
func _foe(m: Node, at: Vector2i, kind := &"dokkaebi") -> Actor:
	var a := FloorGen.spawn(m.world, kind, at)
	a.magic.cooldown = 99
	m.world.set_tile(at + Vector2i.UP, World.LANTERN)
	m.world.sense()
	m.forecast()
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
	assert_string_contains(_prompt(m), "불타는 칸")
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


func test_another_direction_only_cancels_the_prompt() -> void:
	var m := _keyboard()
	_blaze(m)
	var round_no: int = m.world.round_no
	_press(m, "Right")
	_press(m, "Down")
	await _settle(m)
	assert_eq(m.world.player().pos, ME)
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.guard.asking, Vector2i.ZERO)
	assert_false(_prompt(m).ends_with("Y/N"))


func test_another_action_only_cancels_the_prompt() -> void:
	var m := _keyboard()
	_blaze(m)
	var round_no: int = m.world.round_no
	_press(m, "Right")
	_press(m, "X")
	assert_false(m.looking, "the key that cancels does nothing else")
	assert_eq(m.guard.asking, Vector2i.ZERO)
	assert_false(_prompt(m).ends_with("Y/N"))
	_press(m, "Right")
	_press(m, "Enter")
	await _settle(m)
	assert_eq(m.world.round_no, round_no, "Enter passes no round")


func test_n_says_no_whichever_way_the_prompt_asks() -> void:
	for d: Vector2i in [E, Vector2i(1, 1)]:
		var m := _keyboard()
		_blaze(m, d)
		var round_no: int = m.world.round_no
		m.move(d)
		assert_eq(m.guard.asking, d)
		_press(m, "N")
		_press(m, "N", true)
		await _settle(m)
		assert_eq(m.world.player().pos, ME, "N at %s does not walk" % d)
		assert_eq(m.world.round_no, round_no)
		assert_eq(m.guard.asking, Vector2i.ZERO)


func test_a_held_y_steps_once_and_does_not_walk_on_north_west() -> void:
	var m := _keyboard()
	_blaze(m)
	_press(m, "Right")
	_press(m, "Y")
	await _settle(m)
	_press(m, "Y", true)
	await _settle(m)
	assert_eq(m.world.player().pos, ME + E)
	_press(m, "Y")
	await _settle(m)
	assert_eq(m.world.player().pos, ME + E + Vector2i(-1, -1), "a fresh Y is a move again")


func test_a_bare_shift_leaves_the_prompt_up() -> void:
	var m := _keyboard()
	_blaze(m)
	_press(m, "Right")
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	m._key(shift)
	assert_eq(m.guard.asking, E)


func test_a_creature_on_fire_or_a_plate_is_clawed_without_asking() -> void:
	var m := _keyboard()
	var foe := FloorGen.spawn(m.world, &"dokkaebi", ME + E)
	foe.magic.cooldown = 99
	var hp := foe.hp
	_blaze(m)
	_press(m, "Right")
	await _settle(m)
	assert_eq(m.guard.asking, Vector2i.ZERO)
	assert_lt(foe.hp, hp, "she clawed it")


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
		m.forecast()
		assert_eq(m.ahead[E].hurt_me(), 0, "the round of the step hurts nobody")
		_press(m, "Right")
		assert_eq(m.guard.asking, E)
		assert_eq(m.world.player().pos, ME)
		m._unask()


func test_a_plate_not_found_yet_is_stepped_on_without_asking() -> void:
	var m := _keyboard()
	m.world.traps[ME + E] = World.TRAP_ALARM
	m.forecast()
	_press(m, "Right")
	await _settle(m)
	assert_eq(m.world.player().pos, ME + E)


func test_harm_beside_a_creature_does_not_ask() -> void:
	var m := _keyboard()
	var foe := _foe(m, ME + Vector2i(3, 0))
	foe.magic.cooldown = 0
	foe.brain.alert = Actor.HUNT
	m.forecast()
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


## 둔갑 in her hand, with a 도깨비 felled before.
func _guise_in_hand(m: Node) -> void:
	m.world.player().buffs.prey = &"dokkaebi"
	m.world.tails = 5
	m.world.cards.assign(Cards.ALL)
	m.picked.assign([Cards.WOOD, Cards.EARTH, Cards.WOOD])


func test_casting_a_guise_before_a_sharp_creature_asks_and_takes_no_turn() -> void:
	var m := _keyboard()
	_foe(m, ME + E * 3)
	_guise_in_hand(m)
	var round_no: int = m.world.round_no
	_press(m, "Comma")
	assert_false(m.world.player().buffs.guise)
	assert_eq(m.world.round_no, round_no)
	assert_string_contains(_prompt(m), Lang.t(Bestiary.info(&"dokkaebi").name))
	assert_string_contains(_prompt(m), Guise.NAME[Guise.GUISE])
	assert_string_ends_with(_prompt(m), "Y/N")


func test_y_or_the_same_key_casts_the_guise_it_asked_about_and_the_creature_hunts() -> void:
	for key in ["Y", "Comma"]:
		var m := _keyboard()
		var foe := _foe(m, ME + E * 3)
		_guise_in_hand(m)
		_press(m, "Comma")
		_press(m, key)
		await _settle(m)
		assert_true(m.world.player().buffs.guise, key)
		assert_eq(foe.brain.alert, Actor.HUNT, key)
		assert_true(m.guard.casting.is_empty(), key)


func test_any_other_key_keeps_the_talismans_and_casts_nothing() -> void:
	var m := _keyboard()
	_foe(m, ME + E * 3)
	_guise_in_hand(m)
	var round_no: int = m.world.round_no
	_press(m, "Comma")
	_press(m, "N")
	await _settle(m)
	assert_false(m.world.player().buffs.guise)
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.picked.size(), 3)
	assert_false(_prompt(m).ends_with("Y/N"))


func test_a_dull_creature_that_sees_the_guise_is_not_asked_about() -> void:
	var m := _keyboard()
	var foe := _foe(m, ME + E * 3, &"jangseung")
	_guise_in_hand(m)
	assert_true(m.world.sees(foe, ME), "it sees her")
	_press(m, "Comma")
	await _settle(m)
	assert_true(m.world.player().buffs.guise)


func test_a_sharp_creature_she_does_not_know_of_is_not_named() -> void:
	var m := _keyboard()
	var at := ME + E * 3
	FloorGen.spawn(m.world, &"dokkaebi", at)
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x != 0 or y != 0:
				m.world.set_tile(at + Vector2i(x, y), World.WALL)
	m.world.sense()
	m.forecast()
	_guise_in_hand(m)
	_press(m, "Comma")
	await _settle(m)
	assert_true(m.world.player().buffs.guise)
