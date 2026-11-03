extends TouchBase
## The describe key: a hover box that tells of a 도감 entry ends in a small dim row
## with the key, and the key opens that entry, with no round and nothing saved.

const KIND := &"jangseung"


func after_each() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	Keys.reset()


## A game scene with a creature next to Miho and the pointer on it.
func _foe_hover(touch := false) -> Node:
	var m := _main(touch)
	m.glass.visible = false
	m.term.banner_lines.clear()
	var at := _me(m) + Vector2i(1, 0)
	FloorGen.spawn(m.world, KIND, at).magic.cooldown = 99
	m.world.sense()
	m.term.show_world(m.world)
	m.forecast()
	if touch:
		m.look.hover = at
		m.refresh()
	else:
		Preview.point(m, _tile_at(m, at))
	return m


func _press(m: Node, key: String, shift := false) -> void:
	var e := Keys.event(key)
	e.pressed = true
	e.shift_pressed = shift
	m._unhandled_input(e)


func _shift(m: Node, down: bool) -> void:
	var e := Keys.event("Shift")
	e.pressed = down
	m._unhandled_input(e)


func _text(m: Node) -> String:
	return Info.plain(m.term.info)


func _entry(m: Node) -> Vector2i:
	return Vector2i(m.menu.codex.tab, m.menu.codex.selected)


func _kind_entry() -> Vector2i:
	return Vector2i(0, Codex.foes().find(KIND))


func test_the_box_of_a_creature_ends_in_the_key_and_the_key_opens_its_kind_in_the_bestiary(
) -> void:
	var m := _foe_hover()
	assert_eq(m.term.info.back()[0][0], "M")
	assert_string_contains(m.term.info.back()[1][0], Lang.t("자세히"))
	var lines: Array = m.term.info.duplicate(true)
	var hover: Vector2i = m.look.hover
	var rounds: int = m.world.round_no
	var actions: int = m.run.actions.size()
	_press(m, "M")
	assert_eq(m.overlay, &"codex")
	assert_eq(_entry(m), _kind_entry(), "the creature's tab and place")
	assert_eq(m.world.round_no, rounds)
	assert_eq(m.run.actions.size(), actions, "nothing is saved to replay")
	_press(m, "Escape")
	assert_eq(m.overlay, &"")
	assert_eq(m.look.hover, hover)
	assert_eq(m.term.info, lines, "the same hover comes back")


func test_every_creature_kind_maps_to_an_entry_of_the_bestiary() -> void:
	var m := _main(false)
	for kind in Codex.foes():
		var a := FloorGen.spawn(m.world, kind, _me(m) + Vector2i(1, 0))
		m.world.sense()
		m.term.show_world(m.world)
		m.forecast()
		Preview.point(m, _tile_at(m, a.pos))
		assert_eq(Keywords.locate(m.term.subject).x, 0, "the entry of %s" % kind)
		m.world.actors.erase(a)


func test_the_box_of_a_tile_opens_the_entry_of_that_tile() -> void:
	var m := _main(false)
	var at := _me(m) + Vector2i(2, 0)
	m.world.set_tile(at, World.POND)
	m.world.sense()
	m.term.show_world(m.world)
	m.forecast()
	Preview.point(m, _tile_at(m, at))
	assert_eq(m.term.info.back()[0][0], "M")
	_press(m, "M")
	assert_eq(m.overlay, &"codex")
	assert_eq(_entry(m), Keywords.locate(Lang.t(Tiles.of(World.POND, "name"))))
	assert_eq(m.menu.codex.tab, 4, "the features of the floor")


func test_the_box_of_a_talisman_opens_its_entry() -> void:
	var m := _main(false)
	m.look.hover_card = Cards.ORB
	m.refresh()
	assert_eq(m.term.info.back()[0][0], "M")
	_press(m, "M")
	assert_eq(m.overlay, &"codex")
	assert_eq(_entry(m), Keywords.locate(Codex.talisman_name(Cards.ORB)))


func test_the_box_of_a_saved_spell_without_an_entry_of_its_own_opens_its_shape() -> void:
	var m := _main(false)
	var spell := Spell.make([Cards.FOX, Cards.FIRE])
	assert_lt(Keywords.locate(spell.shown()).x, 0, "a spell made of the talismans has no entry")
	m.look.hover_spell = spell.key()
	m.refresh()
	_press(m, "M")
	assert_eq(_entry(m), Keywords.locate(Lang.t(Spell.SHAPE_NAME[Spell.WISP])))


func test_the_box_of_a_queue_slot_opens_the_talisman_at_that_slot() -> void:
	var m := _main(false)
	m.picked.assign([Cards.ORB, Cards.FIRE])
	m.look.hover_slot = 1
	m.refresh()
	_press(m, "M")
	assert_eq(_entry(m), Keywords.locate(Codex.talisman_name(Cards.FIRE)))


func test_look_mode_opens_the_entry_of_the_tile_under_the_cursor_and_stays_in_look_mode() -> void:
	var m := _foe_hover()
	var foe := _me(m) + Vector2i(1, 0)
	Preview.point(m, Vector2(-1.0e5, -1.0e5))
	_press(m, "X")
	assert_true(m.look.active)
	m.look.at(foe)
	assert_eq(m.term.info.back()[0][0], "M")
	var rounds: int = m.world.round_no
	_press(m, "M")
	assert_eq(m.overlay, &"codex")
	assert_eq(_entry(m), _kind_entry())
	_press(m, "Escape")
	assert_eq(m.overlay, &"")
	assert_true(m.look.active, "the look cursor is where it was")
	assert_eq(m.look.hover, foe)
	assert_eq(m.world.round_no, rounds)


func test_a_kept_box_opens_its_own_entry_when_the_pointer_is_over_something_else() -> void:
	var m := _foe_hover()
	_shift(m, true)
	assert_false(m.term.pin.is_empty())
	var floor_tile := _me(m) + Vector2i(0, 2)
	Preview.point(m, _tile_at(m, floor_tile))
	assert_eq(m.look.hover, floor_tile, "the pointer moved to a floor tile")
	var rounds: int = m.world.round_no
	_press(m, "M", true)
	assert_eq(m.overlay, &"codex")
	assert_eq(_entry(m), _kind_entry(), "the creature, not the floor")
	assert_eq(m.world.round_no, rounds)


func test_a_box_with_no_entry_shows_no_row_and_the_key_leaves_the_screen_as_it_is() -> void:
	var m := _main(false)
	Preview.point(m, _tile_at(m, _me(m)))
	assert_false(m.term.info.is_empty(), "Miho's own box")
	assert_eq(m.term.subject, "")
	assert_false(_text(m).contains(Lang.t("자세히")))
	var lines: Array = m.term.info.duplicate(true)
	var rounds: int = m.world.round_no
	var log: int = m.messages.lines.size()
	_press(m, "M")
	assert_eq(m.overlay, &"")
	assert_eq(m.term.info, lines)
	assert_eq(m.world.round_no, rounds)
	assert_eq(m.messages.lines.size(), log, "no refusal in the log")
	assert_eq(m.run.actions.size(), 0)


func test_the_status_row_has_no_entry_either() -> void:
	var m := _main(false)
	m.look.hover_status = true
	m.refresh()
	assert_false(m.term.info.is_empty())
	assert_eq(m.term.subject, "")
	_press(m, "M")
	assert_eq(m.overlay, &"")


func test_the_row_follows_a_rebind() -> void:
	var m := _foe_hover()
	Keys.bind(&"describe", ["T"])
	m.refresh()
	assert_eq(m.term.info.back()[0][0], "T")
	_press(m, "T")
	assert_eq(m.overlay, &"codex")


func test_a_touch_screen_shows_no_row() -> void:
	var m := _foe_hover(true)
	assert_false(m.term.info.is_empty())
	assert_false(_text(m).contains(Lang.t("자세히")))


func test_the_row_is_inside_the_box_at_the_smallest_window() -> void:
	get_tree().root.size = Vector2i(640, 360)
	var m := _foe_hover()
	var fit: Dictionary = m.term.info_fit()
	var shown: Array = fit.columns.back()[1]
	assert_eq(shown.back()[0][0], "M", "the row is laid out with the lines")
	var wide: Vector2 = fit.cells * fit.scale
	assert_true(fit.at.y >= 0.0 and fit.at.y + wide.y <= m.term.rows)
	assert_true(fit.at.x >= 0.0 and fit.at.x + wide.x <= m.term.cols)


func test_the_row_is_no_word() -> void:
	var m := _foe_hover()
	_shift(m, true)
	var fit: Dictionary = m.term.pin.fit
	var column: Array = fit.columns.back()
	var y: float = fit.at.y + (column[1].size() - 0.5) * fit.scale
	var x: float = fit.at.x
	while x < fit.at.x + fit.cells.x * fit.scale:
		assert_eq(WordHover.word_at(m.term, Vector2(x, y) * Term.CELL), "", "at %f" % x)
		x += 0.25


func test_the_describe_key_works_in_the_debug_view_on_what_miho_does_not_see() -> void:
	var m := _foe_hover()
	var far := Vector2i(1, 1)
	var hidden := FloorGen.spawn(m.world, &"dokkaebi", far)
	hidden.magic.cooldown = 99
	m.debugging = true
	m.look.hover = hidden.pos
	m.refresh()
	assert_eq(m.term.subject, Lang.t(hidden.info().name))
	_press(m, "M")
	assert_eq(m.overlay, &"codex")
