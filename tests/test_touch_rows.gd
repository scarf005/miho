extends TouchBase
## The status a touch screen shows besides the buttons: the noise bar, the
## creatures in sight (a strip in portrait, the sidebar in landscape) and the saved
## spells, which a finger picks in play and saves in the spellbook.

const SIZES := [Vector2i(390, 844), Vector2i(844, 390)]


func after_each() -> void:
	get_tree().root.size = Vector2i(1280, 720)


## Puts the phone to `size`, with creatures of the given kinds at x = 8, 9, ... on row 8.
func _phone(size: Vector2i, kinds := []) -> Node:
	var m := _main()
	for i in kinds.size():
		FloorGen.spawn(m.world, kinds[i], Vector2i(8 + i, 8))
	get_tree().root.size = size
	m.fit()
	m.world.seen.fill(1)
	m.term.show_world(m.world)
	m.forecast()
	return m


## Saves the spell of `cards` in the first slot of the game's saved spells.
func _save(m: Node, cards: Array) -> void:
	m.term.saved = {Keys.SLOTS[0]: Spell.make(cards).key()}
	m.settings.spells = m.term.saved


func test_the_noise_bar_has_room_beside_the_tails_in_both_orientations() -> void:
	for size in SIZES:
		var m := _phone(size)
		var stat: Rect2 = m.touch.hud._rect(m.term, &"stat")
		assert_gte(
			stat.size.x / Term.CELL.x,
			m.world.max_tails() + NoiseMeter.width(),
			"the tails and the bar share a row at %s" % size
		)


func test_a_tap_on_her_lists_her_buffs_and_a_tap_on_a_row_drops_that_one() -> void:
	var m := _main()
	m.world.cards.assign(Cards.ALL)
	m.world.tails = 9
	for kind: StringName in [Guise.TALON, Guise.CLOAK]:
		m.world.act({t = &"cast", spells = [{cards = Guise.RECIPE[kind], dir = Vector2i.ZERO}]})
	var round_no: int = m.world.round_no
	_finger(m, _tile_at(m, m.world.player().pos))
	assert_eq(m.overlay, &"dispel")
	assert_eq(m.world.round_no, round_no, "the list takes no round")
	_finger(m, _rows(m, 1))
	while m.busy:
		await get_tree().process_frame
	assert_eq(m.overlay, &"")
	assert_eq(Guise.worn(m.world, m.world.player()), [Guise.TALON])
	assert_eq(m.world.round_no, round_no + 1)


func test_a_tap_on_a_creature_of_the_strip_shows_its_info_in_portrait() -> void:
	var m := _phone(Vector2i(390, 844), [&"dokkaebi"])
	var card: Rect2 = m.touch.hud._creatures(m.term)[0].rect
	_finger(m, _screen(m, card.get_center()))
	assert_eq(m.look.hover, Vector2i(8, 8))
	assert_false(m.term.info.is_empty())
	assert_true(m.touch.frozen, "the next tap only closes it")
	assert_eq(m.world.round_no, 0, "no step was taken")


func test_a_tap_on_a_creature_of_the_sidebar_shows_its_info_in_landscape() -> void:
	var m := _phone(Vector2i(844, 390), [&"dokkaebi"])
	_finger(m, _screen(m, Vector2(0.5, 0.5) * Term.CELL))
	assert_eq(m.look.hover, Vector2i(8, 8))
	assert_false(m.term.info.is_empty())
	assert_eq(m.world.round_no, 0)


func test_the_strip_shows_two_creatures_and_a_drag_along_it_brings_on_the_next() -> void:
	var m := _phone(Vector2i(390, 844), [&"dokkaebi", &"dokkaebi", &"dokkaebi"])
	var hud: TouchHud = m.touch.hud
	var cards := hud._creatures(m.term)
	assert_eq(cards.size(), TouchHud.STRIP_CARDS)
	var third := Vector2i(10, 8)
	assert_ne(cards[1].actor.pos, third)
	var from: Vector2 = _screen(m, cards[1].rect.get_center())
	_finger(m, from, from - Vector2(cards[1].rect.size.x * m.term.scale.x, 0.0))
	assert_eq(hud._creatures(m.term)[1].actor.pos, third, "the strip moved on by one")
	assert_eq(m.world.round_no, 0, "a drag along the strip is no step")


func test_a_tap_on_a_saved_spell_picks_and_aims_it_and_a_hold_shows_it() -> void:
	var m := _phone(Vector2i(390, 844), [&"dokkaebi"])
	_save(m, [Cards.ORB])
	var chip: Rect2 = m.touch.hud._chips(m.term)[0].rect
	_hold(m, _screen(m, chip.get_center()))
	assert_false(m.term.info.is_empty(), "its info")
	_lift(m, _screen(m, chip.get_center()))
	_finger(m, _screen(m, chip.get_center()))
	_finger(m, _screen(m, chip.get_center()))
	assert_eq(m.casting.picked, [Cards.ORB])
	assert_eq(m.look.hover, Vector2i(8, 8), "aimed at the nearest creature, as a key aims it")


func test_a_saved_spell_needs_no_chip_when_none_is_saved() -> void:
	var m := _phone(Vector2i(390, 844))
	assert_true(m.touch.hud._chips(m.term).is_empty())


func test_every_saved_spell_has_a_chip_a_finger_can_hit_in_both_orientations() -> void:
	for size in SIZES:
		var m := _phone(size)
		m.term.saved = {}
		for slot in Keys.SLOTS:
			m.term.saved[slot] = Spell.make([Cards.FOX, Cards.ORB]).key()
		var hud: TouchHud = m.touch.hud
		for chip in hud._chips(m.term):
			assert_gte(chip.rect.size.x / hud.unit, TARGET, "%s wide at %s" % [chip.action, size])
			assert_gte(chip.rect.size.y / hud.unit, TARGET)
		assert_gte(hud._chips(m.term).size(), 3, "a few show at once at %s" % size)


func test_a_drag_along_the_saved_row_brings_on_the_next_spell() -> void:
	var m := _phone(Vector2i(390, 844))
	m.term.saved = {}
	for slot in Keys.SLOTS:
		m.term.saved[slot] = Spell.make([Cards.FOX, Cards.ORB, Cards.FIRE, Cards.WATER]).key()
	var hud: TouchHud = m.touch.hud
	var row: Rect2 = hud._rect(m.term, &"saved")
	var from: Vector2 = _screen(m, row.get_center())
	_finger(m, from, from - Vector2(TARGET * hud.unit * m.term.scale.x * 1.2, 0.0))
	assert_eq(hud.first[&"saved"], 1)
	assert_eq(hud._chips(m.term)[0].action, Keys.SLOTS[1])


# --- the spellbook --------------------------------------------------------------


func _spellbook(m: Node) -> void:
	_finger(m, _hud(m, &"card", 1))
	_finger(m, _hud(m, &"spellbook"))
	assert_eq(m.overlay, &"spells")


func test_a_slot_button_of_the_spellbook_saves_the_selected_spell_and_again_clears_it() -> void:
	var m := _main()
	_spellbook(m)
	var key: String = m.menu.spells()[0].key()
	_finger(m, _hud(m, Keys.SLOTS[2]))
	assert_eq(m.settings.spells.get(Keys.SLOTS[2]), key, "saved in the third slot")
	_finger(m, _hud(m, Keys.SLOTS[2]))
	assert_false(m.settings.spells.has(Keys.SLOTS[2]), "the same button again clears it")


func test_the_slot_buttons_are_at_least_44_css_pixels_and_named_by_their_keys() -> void:
	for wide in [false, true]:
		var area := Rect2(0, 0, 390 if not wide else 120, 844 if wide else 56)
		var items := TouchHud.layout(&"menu", area, 1.0, wide, 0, &"spells")
		var labels := items.map(func(i): return i.label)
		assert_eq(labels, ["던지기", "Q", "W", "E", "A", "S", "D", "뒤로"])
		for item in items:
			assert_gte(minf(item.rect.size.x, item.rect.size.y), TARGET, "%s" % item.label)
			assert_true(area.encloses(item.rect), "%s is on the HUD" % item.label)


func test_a_tap_on_a_row_of_the_spellbook_selects_it_and_throw_casts_the_selected_one() -> void:
	var m := _main()
	_save(m, [Cards.FIRE])
	_finger(m, _hud(m, &"card", 1))
	_finger(m, _hud(m, &"spellbook"))
	assert_eq(m.menu.spells().size(), 2, "the queued spell and the saved one")
	_finger(m, _rows(m, 1))
	assert_eq(m.overlay, &"spells", "a tap on a row only selects it")
	assert_eq(m.menu.selected, 1)
	_finger(m, _hud(m, &"enter"))
	assert_eq(m.overlay, &"", "the page is closed")
	assert_eq(m.casting.picked, [Cards.FIRE], "the selected spell is picked")


# --- the layout -----------------------------------------------------------------


func test_the_saved_row_takes_no_room_until_a_spell_is_saved() -> void:
	for css in [Vector2(390, 844), Vector2(844, 390)]:
		var with := Touch.plan(css, Vector4.ZERO, 3.0, false, true)
		var without := Touch.plan(css, Vector4.ZERO, 3.0, false, false)
		var gain: float = without.map.size.y - with.map.size.y
		assert_almost_eq(gain, 0.0 if with.wide else TARGET, 0.01, "map gain at %s" % css)
		var area := Rect2(Vector2.ZERO, without.hud.size)
		var kinds := TouchHud.layout(&"play", area, 1.0, without.wide, 2, &"", false).map(
			func(i): return i.kind
		)
		assert_false(kinds.has(&"saved"), "no saved row at %s" % css)


func test_saving_the_first_spell_lays_the_screen_out_again_with_the_row() -> void:
	var m := _phone(Vector2i(390, 844))
	var rows: int = m.term.rows
	_save(m, [Cards.ORB])
	m.touch._process(0.0)
	assert_lt(m.term.rows, rows, "the map gave the row its room")
	assert_eq(m.touch.hud._chips(m.term).size(), 1)


func test_the_sidebar_comes_when_the_title_gives_way_to_play() -> void:
	var m := _phone(Vector2i(844, 390))
	m.state = &"title"
	m.touch._process(0.0)
	assert_eq(m.term.side, Vector2i.ZERO)
	m.state = &"play"
	m.touch._process(0.0)
	assert_eq(m.term.side, Term.MAP)


func test_every_button_label_fits_inside_its_button_in_both_orientations() -> void:
	for css in [Vector2(390, 844), Vector2(844, 390), Vector2(360, 640), Vector2(640, 360)]:
		var p := Touch.plan(css, Vector4.ZERO, 3.0, false)
		var unit: float = Term.CELL.x / p.cw
		var area := Rect2(Vector2.ZERO, p.hud.size * unit)
		for item in TouchHud.layout(&"play", area, unit, p.wide, 8):
			if item.kind != &"button":
				continue
			var need: float = Term.text_cells(item.label) * p.cw + 4.0
			assert_gte(item.rect.size.x / unit, need, "%s fits at %s" % [item.label, css])


func test_the_spellbook_with_nothing_to_act_on_has_only_the_back_button() -> void:
	var m := _main()
	_finger(m, _hud(m, &"spellbook"))
	assert_eq(m.overlay, &"spells")
	var labels: Array = m.touch.hud._items(m.term).map(func(i): return i.label)
	assert_eq(labels, ["뒤로"])


# --- the camera -----------------------------------------------------------------


func test_the_camera_keeps_miho_in_the_middle_as_far_as_the_map_allows() -> void:
	var m := _phone(Vector2i(390, 844))
	var view: Vector2i = m.term.map_view()
	m.world.player().pos = Vector2i(30, 14)
	m.term.show_world(m.world)
	assert_eq(m.term.cam, Vector2i(30, 14) - view / 2, "in the middle")
	m.world.player().pos = Vector2i(2, 14)
	m.term.show_world(m.world)
	assert_eq(m.term.cam.x, 0, "against the map's left edge")


func test_a_mouse_game_keeps_the_camera_off_the_edges_only() -> void:
	var m := _main(false)
	assert_false(m.term.centred)


## A finger down at `from` at `t0`, dragged to `to` at `t1`, up at `t2`.
func _drag(m: Node, from: Vector2, to: Vector2, times: Vector3) -> void:
	m.touch.input(_touch_event(true, from), times.x)
	var d := InputEventScreenDrag.new()
	d.position = to
	d.relative = to - from
	m.touch.input(d, times.y)
	m.touch.input(_touch_event(false, to), times.z)


func test_a_slow_drag_over_the_map_pans_it_and_takes_no_step() -> void:
	var m := _phone(Vector2i(390, 844))
	m.world.player().pos = Vector2i(30, 14)
	m.term.show_world(m.world)
	var before: Vector2i = m.term.cam
	var tile: Vector2 = Term.CELL * m.term.scale.x
	var from := _tile_at(m, Vector2i(30, 14))
	_drag(m, from, from + Vector2(-3.2 * tile.x, 2.2 * tile.y), Vector3(0.0, 0.6, 0.7))
	assert_eq(m.term.cam, before + Vector2i(3, -2), "the map follows the finger")
	assert_eq(_me(m), Vector2i(30, 14))
	assert_eq(m.world.round_no, 0)


func test_a_quick_flick_over_the_map_is_a_step_and_pans_nothing() -> void:
	var m := _phone(Vector2i(390, 844))
	m.world.player().pos = Vector2i(30, 14)
	m.term.show_world(m.world)
	var tile: float = Term.CELL.x * m.term.scale.x
	var from := _tile_at(m, Vector2i(30, 14))
	_drag(m, from, from + Vector2(-2.0 * tile, 0.0), Vector3(0.0, 0.1, 0.15))
	assert_eq(_me(m), Vector2i(29, 14), "a step west")


func test_a_pan_stops_at_the_map_edge() -> void:
	var m := _phone(Vector2i(390, 844))
	m.world.player().pos = Vector2i(4, 14)
	m.term.show_world(m.world)
	var tile: float = Term.CELL.x * m.term.scale.x
	var from := _tile_at(m, Vector2i(4, 14))
	_drag(m, from, from + Vector2(6.0 * tile, 0.0), Vector3(0.0, 0.6, 0.7))
	assert_eq(m.term.cam.x, 0, "there is no map left of it")


func test_the_spellbook_entered_from_the_esc_menu_has_its_buttons() -> void:
	var m := _main()
	_finger(m, _hud(m, &"card", 1))
	_finger(m, _hud(m, &"spellbook"))
	_finger(m, _hud(m, &"back"))
	m._open(&"options")
	m.menu.selected = m.menu._listed().find(&"spells")
	m._panel_input(m.touch._key(KEY_ENTER))
	m.touch._process(0.0)
	assert_eq(m.menu.page, &"spells")
	assert_ne(_hud(m, &"enter"), Vector2.ZERO)
