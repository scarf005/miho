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
	m._fit()
	m.world.seen.fill(1)
	m.term.show_world(m.world)
	m._forecast()
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
			m.world.max_tails() + NoiseMeter.WIDTH,
			"the tails and the bar share a row at %s" % size
		)


func test_a_tap_on_a_creature_of_the_strip_shows_its_info_in_portrait() -> void:
	var m := _phone(Vector2i(390, 844), [&"dokkaebi"])
	var card: Rect2 = m.touch.hud._creatures(m.term)[0].rect
	_finger(m, _screen(m, card.get_center()))
	assert_eq(m.hover, Vector2i(8, 8))
	assert_false(m.term.info.is_empty())
	assert_true(m.touch.frozen, "the next tap only closes it")
	assert_eq(m.world.round_no, 0, "no step was taken")


func test_a_tap_on_a_creature_of_the_sidebar_shows_its_info_in_landscape() -> void:
	var m := _phone(Vector2i(844, 390), [&"dokkaebi"])
	_finger(m, _screen(m, Vector2(0.5, 0.5) * Term.CELL))
	assert_eq(m.hover, Vector2i(8, 8))
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
	assert_eq(m.picked, [Cards.ORB])
	assert_eq(m.hover, Vector2i(8, 8), "aimed at the nearest creature, as a key aims it")


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
	assert_eq(m.picked, [Cards.FIRE], "the selected spell is picked")
