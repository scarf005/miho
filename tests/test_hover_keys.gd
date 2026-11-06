extends TouchBase
## The hover box ends in a row with the key of every action that works on what it shows.

const KIND := &"jangseung"


func after_each() -> void:
	Keys.reset()


func _press(m: Node, key: String) -> void:
	var e := Keys.event(key)
	e.pressed = true
	m._unhandled_input(e)


## Look mode with the cursor on `tile`.
func _look(m: Node, tile: Vector2i) -> void:
	m.look.active = true
	m.look.at(tile)


func _row(m: Node) -> String:
	return Info.plain([m.term.info.back()]) if not m.term.info.is_empty() else ""


## Whether the last row of the box has the key of `action` and `label`.
func _lists(m: Node, action: StringName, label: String) -> bool:
	var want := Keys.label(Keys.keys_of(action)[0]) + " " + Lang.t(label)
	return _row(m).contains(want)


func _door(m: Node, state: int) -> Vector2i:
	var at: Vector2i = m.world.player().pos + Vector2i(1, 0)
	m.world.tiles[Grid.index(at)] = state
	m.refresh()
	return at


func test_an_open_door_next_to_miho_lists_close_and_the_key_shuts_it() -> void:
	var m := _main(false)
	var at := _door(m, World.DOOR_OPEN)
	_look(m, at)
	assert_true(_lists(m, &"close", "닫기"), _row(m))
	assert_true(_lists(m, &"exclude", "위험구역 표시"), _row(m))
	assert_true(_lists(m, &"confirm", "이동"), _row(m))
	_press(m, "C")
	assert_eq(m.world.tile(at), World.DOOR)


func test_a_door_something_stands_in_does_not_list_close() -> void:
	var m := _main(false)
	var at := _door(m, World.DOOR_OPEN)
	FloorGen.spawn(m.world, KIND, at).magic.cooldown = 99
	m.world.sense()
	_look(m, at)
	assert_false(_lists(m, &"close", "닫기"), _row(m))
	_press(m, "C")
	assert_eq(m.world.tile(at), World.DOOR_OPEN)


func test_the_close_key_shuts_the_door_under_the_cursor_not_another() -> void:
	var m := _main(false)
	var east := _door(m, World.DOOR_OPEN)
	var west: Vector2i = m.world.player().pos + Vector2i(-1, 0)
	m.world.tiles[Grid.index(west)] = World.DOOR_OPEN
	_look(m, west)
	_press(m, "C")
	assert_eq(m.world.tile(west), World.DOOR)
	assert_eq(m.world.tile(east), World.DOOR_OPEN)


func test_a_door_out_of_reach_does_not_list_close() -> void:
	var m := _main(false)
	var at: Vector2i = m.world.player().pos + Vector2i(3, 0)
	m.world.tiles[Grid.index(at)] = World.DOOR_OPEN
	_look(m, at)
	assert_false(_lists(m, &"close", "닫기"), _row(m))
	assert_true(_lists(m, &"confirm", "이동"), _row(m))


func test_the_exclude_key_listed_marks_then_the_row_offers_to_narrow_and_clear() -> void:
	var m := _main(false)
	var at: Vector2i = m.world.player().pos + Vector2i(3, 0)
	_look(m, at)
	assert_true(_lists(m, &"exclude", "위험구역 표시"), _row(m))
	_press(m, "V")
	assert_eq(m.journey.excluded.zones, {at: Exclusions.DEFAULT_RADIUS})
	assert_true(_lists(m, &"exclude", "위험구역 줄이기"), _row(m))
	assert_true(_row(m).contains(Lang.t("위험구역 반지름")), _row(m))
	_press(m, "V")
	assert_eq(m.journey.excluded.zones, {at: 0})
	assert_true(_lists(m, &"exclude", "위험구역 지우기"), _row(m))
	assert_false(_row(m).contains(Lang.t("위험구역 반지름")), _row(m))
	_press(m, "V")
	assert_true(m.journey.excluded.is_empty())


func test_a_creature_lists_detail_first_and_attack_when_next_to_miho() -> void:
	var m := _main(false)
	var at: Vector2i = m.world.player().pos + Vector2i(1, 0)
	FloorGen.spawn(m.world, KIND, at).magic.cooldown = 99
	m.world.sense()
	m.term.show_world(m.world)
	_look(m, at)
	var row := _row(m)
	assert_true(row.begins_with("M " + Lang.t("자세히")), row)
	assert_true(_lists(m, &"confirm", "공격"), row)
	assert_false(_lists(m, &"close", "닫기"), row)


func test_miho_own_tile_lists_no_walk() -> void:
	var m := _main(false)
	_look(m, m.world.player().pos)
	assert_false(_row(m).contains(Lang.t("이동")), _row(m))
	assert_true(_lists(m, &"exclude", "위험구역 표시"), _row(m))


func test_a_tile_not_known_lists_no_exclude_and_no_walk() -> void:
	var m := _main(false)
	var at: Vector2i = m.world.player().pos + Vector2i(5, 0)
	m.world.known[Grid.index(at)] = 0
	_look(m, at)
	assert_false(_row(m).contains(Lang.t("위험구역 표시")), _row(m))


func test_the_pointer_alone_lists_only_what_the_keys_do_without_look_mode() -> void:
	var m := _main(false)
	var at := _door(m, World.DOOR_OPEN)
	m.look.hover = at
	m.refresh()
	assert_true(_lists(m, &"close", "닫기"), _row(m))
	assert_false(_row(m).contains(Lang.t("위험구역 표시")), _row(m))
	assert_false(_row(m).contains(Lang.t("이동")), _row(m))
	_press(m, "C")
	assert_eq(m.world.tile(at), World.DOOR)


func test_the_row_follows_a_rebind() -> void:
	var m := _main(false)
	var at := _door(m, World.DOOR_OPEN)
	Keys.bind(&"close", ["B"])
	_look(m, at)
	assert_true(_lists(m, &"close", "닫기"), _row(m))
	assert_true(_row(m).begins_with("B "), _row(m))


func test_a_touch_screen_shows_no_row() -> void:
	var m := _main(true)
	var at := _door(m, World.DOOR_OPEN)
	_look(m, at)
	assert_false(_row(m).contains(Lang.t("닫기")))
