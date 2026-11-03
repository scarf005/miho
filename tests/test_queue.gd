extends GutTest
## The talisman queue: two different elements merge into one compound slot,
## number keys fill it on the game scene, a saved spell replaces it, Esc clears
## it, and the lower status row shows its slots.

const FOX := Cards.FOX
const ORB := Cards.ORB


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
	w.cards.assign([FOX, ORB, Cards.FIRE, Cards.WATER])
	return w


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m.new_run(3)
	m.state = &"play"
	m.world = _hall()
	m.settings.spells = {}
	m.term.show_world(m.world)
	m.forecast()
	return m


func _press(m: Node, key: String) -> void:
	var e := Keys.event(key)
	e.pressed = true
	m._key(e)


func test_number_keys_queue_talismans_with_repeats_until_the_tails_run_out() -> void:
	var m := _main()
	for k in ["1", "1", "3", "4"]:
		_press(m, k)
	assert_eq(m.casting.picked, [FOX, FOX, Cards.FIRE, Cards.WATER] as Array[StringName])
	assert_eq(Spell.make(m.casting.picked).slots, [FOX, FOX, &"steam"] as Array[StringName])
	assert_eq(Spell.make(m.casting.picked).cost(), 5, "four cards, five tails")
	_press(m, "2")
	assert_eq(m.casting.picked.size(), 4, "a fifth card would cost seven")
	_press(m, "Escape")
	assert_true(m.casting.picked.is_empty(), "Esc clears the queue")


func test_three_tails_queue_three_cards_and_refuse_a_fourth_that_costs_five() -> void:
	var m := _main()
	m.world.tails = 3
	for i in 4:
		_press(m, "1")
	assert_eq(m.casting.picked.size(), 3)
	assert_true(m.casting.refused)


func test_five_tails_queue_a_fourth_card_but_refuse_a_fifth_that_costs_seven() -> void:
	var m := _main()
	for i in 3:
		_press(m, "1")
	assert_false(m.casting.refused)
	_press(m, "1")
	assert_eq(m.casting.picked.size(), 4, "the fourth costs five")
	assert_false(m.casting.refused)
	_press(m, "1")
	assert_eq(m.casting.picked.size(), 4, "the fifth costs seven")
	assert_true(m.casting.refused)


func test_the_status_bar_holds_the_cost_of_the_queue_and_of_every_spell_held_with_shift() -> void:
	var m := _main()
	var t: Term = m.term
	assert_eq(StatusBar._held(t), 0)
	for i in 3:
		_press(m, "1")
	assert_eq(StatusBar._held(t), 3, "three cards")
	m.casting.direction(Vector2i.RIGHT, true)
	assert_eq(m.casting.staged.size(), 1)
	assert_eq(StatusBar._held(t), 3, "held with Shift")
	for i in 2:
		_press(m, "1")
	assert_eq(StatusBar._held(t), 3 + 2, "plus two cards")
	m.casting.direction(Vector2i.UP, true)
	assert_eq(StatusBar._held(t), 5, "two spells add their costs")
	assert_false(m.casting.refused)
	_press(m, "1")
	assert_true(m.casting.picked.is_empty(), "no tail is left")
	assert_true(m.casting.refused)


func test_a_queue_dot_is_bright_only_while_one_more_card_is_paid() -> void:
	var m := _main()
	var t: Term = m.term
	for i in 2:
		_press(m, "1")
	assert_eq(StatusBar._held(t), 2)
	assert_true(StatusBar.fits(t, 1), "a third card costs three")
	assert_true(StatusBar.fits(t, 2), "a fourth costs five")
	assert_false(StatusBar.fits(t, 3), "a fifth costs seven")


func test_a_cast_spends_exactly_its_cost_and_its_forecast_says_the_same() -> void:
	var w := _hall()
	var action := {t = &"cast", spells = [{cards = [FOX, FOX, FOX, FOX], dir = Vector2i.RIGHT}]}
	var forecast := w.preview(action)
	assert_eq(forecast.tails, 0)
	w.act(action)
	assert_eq(w.tails, 0, "four cards, five tails of five")
	assert_eq(w.tails, forecast.tails)
	var w2 := _hall()
	w2.tails = 4
	assert_false(w2.can(action), "five tails are more than four")
	w2.tails = 6
	w2.act({t = &"cast", spells = [{cards = [FOX, FOX, FOX], dir = Vector2i.RIGHT}]})
	assert_eq(w2.tails, 3)


func test_the_queue_holds_five_slots_even_with_tails_to_spare() -> void:
	var m := _main()
	m.world.tails = 9
	m.world.depth = 9
	for i in 6:
		_press(m, "1")
	assert_eq(m.casting.picked.size(), 5)


func test_a_saved_spell_fills_the_queue() -> void:
	var m := _main()
	m.settings.spells = {&"slot_1": "fox+fox+fire"}
	_press(m, "2")
	_press(m, "Q")
	assert_eq(
		m.casting.picked, [FOX, FOX, Cards.FIRE] as Array[StringName], "it replaces the queue"
	)
	m.world.tails = 2
	m.settings.spells = {&"slot_2": "fox+fox+fox"}
	m.casting.picked.clear()
	_press(m, "W")
	assert_true(m.casting.picked.is_empty(), "not with too few tails")


func test_the_status_row_shows_and_points_at_each_queue_slot() -> void:
	var m := _main()
	for k in ["1", "3", "4"]:
		_press(m, k)
	var t: Term = m.term
	var row := (t.rows - 1 + 0.5) * Term.CELL.y
	var first := (StatusBar.queue_x(t) + 0.5) * Term.CELL.x
	assert_eq(StatusBar.queue_at(t, Vector2(first, row)), 0)
	assert_eq(StatusBar.queue_at(t, Vector2(first + Term.CELL.x, row)), 1, "the steam slot")
	assert_eq(StatusBar.queue_at(t, Vector2(first + 2 * Term.CELL.x, row)), -1, "an empty slot")
	assert_eq(StatusBar.hand_at(t, Vector2(first, row)), "fox+fire+water")


func test_two_different_elements_merge_into_the_first_ones_compound() -> void:
	var pairs := {
		&"wildfire": [Cards.WOOD, Cards.FIRE],
		&"lava": [Cards.FIRE, Cards.EARTH],
		&"shrapnel": [Cards.EARTH, Cards.METAL],
		&"frost": [Cards.METAL, Cards.WATER],
		&"rain": [Cards.WATER, Cards.WOOD],
		&"steam": [Cards.WATER, Cards.FIRE],
		&"thorn": [Cards.METAL, Cards.WOOD],
		&"rift": [Cards.WOOD, Cards.EARTH],
		&"mud": [Cards.EARTH, Cards.WATER],
	}
	for c in pairs:
		for order in [pairs[c], [pairs[c][1], pairs[c][0]]]:
			assert_eq(Spell.make([FOX] + order).slots, [FOX, c] as Array[StringName], str(order))
	var queue := Spell.make([ORB, Cards.FIRE, Cards.FIRE, Cards.WATER])
	assert_eq(queue.slots, [ORB, &"steam", Cards.FIRE] as Array[StringName])
	assert_eq(queue.count(Cards.FIRE), 1, "a compound is its own element")
	assert_true(queue.holds(Cards.FIRE))
	queue = Spell.make([ORB, Cards.WATER, Cards.FIRE, Cards.METAL, Cards.EARTH])
	assert_eq(queue.slots, [ORB, &"newmoon"] as Array[StringName], "all four join")
	assert_true(queue.holds(Cards.WATER))
	assert_false(queue.has(Cards.WATER))


func test_every_compound_can_be_made_through_the_queue_from_single_talismans() -> void:
	var made := {}
	var queues: Array = [[] as Array[StringName]]
	for card in Cards.TIER:
		var next: Array = []
		for slots: Array[StringName] in queues:
			for element in Cards.ELEMENTS + [Cards.FOX]:
				var out := Spell.queue(slots, element)
				for slot in out:
					made[slot] = true
				next.append(out)
		queues = next
	for c in Cards.compounds():
		assert_true(made.has(c), "%s can be queued" % c)


func test_the_spell_name_never_covers_the_queue() -> void:
	var m := _main()
	m.world.cards.assign(Cards.ALL)
	for k in ["1", "1", "1", "1", "1"]:
		_press(m, k)
	var t: Term = m.term
	t.cols = 30
	var at := StatusBar.title_at(t, Spell.make(m.casting.picked).title())
	assert_true(at.y < t.rows - 1 or at.x >= StatusBar.queue_x(t) + Spell.MAX_SLOTS)


func test_the_longest_spell_name_fits_the_screen_at_every_zoom_of_a_1280x720_window() -> void:
	var m := _main()
	var t: Term = m.term
	var longest := ""
	# Spell.make folds Spell.queue over its cards and its title reads the slots alone: of the
	# card orders that fill the same slots one is enough.
	var queues := [{slots = [] as Array[StringName], cards = []}]
	var seen := {}
	for n in Spell.MAX_SLOTS:
		var next := []
		for q: Dictionary in queues:
			for c in Cards.ALL:
				var slots := Spell.queue(q.slots, c)
				if seen.has(slots):
					continue
				seen[slots] = true
				var cards: Array = q.cards + [c]
				next.append({slots = slots, cards = cards})
				var spell := Spell.make(cards)
				if spell != null and Term.text_cells(spell.title()) > Term.text_cells(longest):
					longest = spell.title()
		queues = next
	var name := "+9 " + longest
	for zoom in Settings.ZOOMS:
		t.fit(Vector2(1280, 720), zoom)
		for count in range(Cards.FORMS.size(), Cards.ALL.size() + 1):
			m.world.cards.assign(Cards.ALL.slice(0, count))
			var at := StatusBar.title_at(t, name)
			var ctx := "%s at zoom %s with %d talismans" % [name, zoom, count]
			assert_true(at.x >= 0.0 and at.x + Term.text_cells(name) <= t.cols, "on screen: " + ctx)
			assert_true(
				at.y < t.rows - 1 or at.x >= StatusBar.queue_x(t) + Spell.MAX_SLOTS,
				"clear of the queue: " + ctx
			)


func test_the_aim_preview_marks_the_creature_it_kills_and_a_line_per_wisp() -> void:
	var m := _main()
	var foe := FloorGen.spawn(m.world, &"dokkaebi", Vector2i(6, 8))
	foe.magic.cooldown = 99
	foe.hp = 2
	foe.max_hp = 2
	m.forecast()
	for k in ["1", "1"]:
		_press(m, k)
	m.look.hover = Vector2i(7, 8)
	m.refresh()
	assert_eq(m.term.marks.get(foe.pos), [str(foe.hp), Palette.HURT], "dies, still marked")
	var gaps: Array = m.term.lines.map(func(l): return l[3])
	assert_eq(gaps, [0, 1], "two wisps, two lines side by side")


func test_each_wisps_aim_line_starts_on_the_tile_it_leaves_on() -> void:
	var m := _main()
	FloorGen.spawn(m.world, &"dokkaebi", Vector2i(6, 8)).magic.cooldown = 99
	m.forecast()
	for k in ["1", "1"]:
		_press(m, k)
	m.look.hover = Vector2i(7, 8)
	m.refresh()
	var froms: Array = m.term.lines.map(func(l): return l[0])
	assert_eq(froms, [Vector2i(5, 8), Vector2i(5, 7)], "beside Miho, each on its own")


func test_a_refused_talisman_makes_the_next_direction_key_do_nothing() -> void:
	var m := _main()
	m.world.tails = 0
	var start: Vector2i = m.world.player().pos
	_press(m, "1")
	assert_true(m.casting.picked.is_empty(), "no tail is left for the talisman")
	_press(m, "Right")
	assert_eq(m.world.player().pos, start, "the key meant to aim does not walk")
	m.busy = false
	_press(m, "Right")
	assert_eq(m.world.player().pos, start + Vector2i.RIGHT, "the next one walks")


func test_a_refused_saved_spell_makes_the_next_tile_click_do_nothing() -> void:
	var m := _main()
	m.world.tails = 0
	m.settings.spells = {&"slot_1": "fox"}
	var start: Vector2i = m.world.player().pos
	_press(m, "Q")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	m.look.hover = start + Vector2i.RIGHT
	m.click(click)
	assert_eq(m.world.player().pos, start, "the click meant to aim does not walk")
	m.look.hover = start + Vector2i.RIGHT
	m.click(click)
	assert_eq(m.world.player().pos, start + Vector2i.RIGHT, "the next one walks")


func test_another_key_after_a_refused_talisman_lets_the_direction_walk() -> void:
	var m := _main()
	m.world.tails = 0
	var start: Vector2i = m.world.player().pos
	_press(m, "1")
	_press(m, "Escape")
	m._close()
	_press(m, "Right")
	assert_eq(m.world.player().pos, start + Vector2i.RIGHT)


func test_a_picked_talisman_aims_at_the_nearest_creature_and_space_hurls_it() -> void:
	var m := _main()
	var foe := FloorGen.spawn(m.world, &"dokkaebi", Vector2i(8, 8))
	foe.magic.cooldown = 99
	m.forecast()
	_press(m, "2")
	assert_eq(m.look.hover, foe.pos, "the cursor goes to the nearest creature in sight")
	var round_no: int = m.world.round_no
	_press(m, "Space")
	assert_eq(m.world.round_no, round_no + 1, "the round is played")
	assert_eq(m.world.shots.map(func(s): return s.dir), [Vector2i.RIGHT], "hurled at it")
	while m.busy:
		await get_tree().process_frame
	assert_true(m.casting.picked.is_empty())


func test_tab_moves_the_aim_to_the_next_creature_in_sight() -> void:
	var m := _main()
	var near := FloorGen.spawn(m.world, &"dokkaebi", Vector2i(6, 8))
	var far := FloorGen.spawn(m.world, &"dokkaebi", Vector2i(4, 5))
	m.forecast()
	_press(m, "2")
	assert_eq(m.look.hover, near.pos)
	_press(m, "Tab")
	assert_eq(m.look.hover, far.pos)
	_press(m, "Tab")
	assert_eq(m.look.hover, m.world.player().pos, "then on her")
	_press(m, "Tab")
	assert_eq(m.look.hover, near.pos, "and round again")
	assert_eq(m.casting.picked, [ORB] as Array[StringName], "Tab does not fight while aiming")


func test_space_with_talismans_and_nothing_to_aim_at_keeps_the_turn() -> void:
	var m := _main()
	_press(m, "2")
	var round_no: int = m.world.round_no
	_press(m, "Space")
	assert_eq(m.world.round_no, round_no, "no wasted wait")
	assert_eq(m.casting.picked, [ORB] as Array[StringName])


func test_f_picks_the_last_hurled_spell_again() -> void:
	var m := _main()
	for k in ["1", "1", "Right"]:
		_press(m, k)
	while m.busy:
		await get_tree().process_frame
	assert_true(m.casting.picked.is_empty())
	_press(m, "F")
	assert_eq(m.casting.picked, [FOX, FOX] as Array[StringName])


func test_period_with_talismans_picked_hurls_at_the_cursor_too() -> void:
	var m := _main()
	var foe := FloorGen.spawn(m.world, &"dokkaebi", Vector2i(8, 8))
	foe.magic.cooldown = 99
	m.forecast()
	_press(m, "2")
	_press(m, "Period")
	assert_eq(m.world.shots.map(func(s): return s.dir), [Vector2i.RIGHT])


func test_a_cursor_already_on_a_creature_stays_when_picking() -> void:
	var m := _main()
	FloorGen.spawn(m.world, &"dokkaebi", Vector2i(6, 8))
	var far := FloorGen.spawn(m.world, &"dokkaebi", Vector2i(4, 5))
	m.look.at(far.pos)
	_press(m, "2")
	assert_eq(m.look.hover, far.pos)


func test_a_direction_after_a_refused_confirm_still_hurls() -> void:
	var m := _main()
	_press(m, "2")
	_press(m, "Space")
	_press(m, "Right")
	assert_eq(m.world.shots.map(func(s): return s.dir), [Vector2i.RIGHT])


func test_f_with_nothing_hurled_yet_refuses_and_picks_nothing() -> void:
	var m := _main()
	var round_no: int = m.world.round_no
	_press(m, "F")
	assert_true(m.casting.picked.is_empty())
	assert_eq(m.world.round_no, round_no)
	assert_true(m.casting.refused)


func test_esc_sends_the_cursor_back_to_the_pointer() -> void:
	var m := _main()
	var foe := FloorGen.spawn(m.world, &"dokkaebi", Vector2i(8, 8))
	_press(m, "2")
	assert_eq(m.look.hover, foe.pos)
	_press(m, "Escape")
	assert_ne(m.look.hover, foe.pos)


func test_a_tail_spent_from_full_comes_back_three_rounds_later_at_any_moment() -> void:
	for waited in World.TAIL_REGROW * 2:
		var w := World.create(5)
		w.actors = w.actors.filter(func(a): return a.faction == Actor.FOX)
		for i in waited:
			w.act({t = &"wait"})
		var dir := Vector2i.ZERO
		for d in Grid.DIRS:
			if w.can({t = &"cast", spells = [{cards = [Cards.FOX], dir = d}]}):
				dir = d
				break
		w.act({t = &"cast", spells = [{cards = [Cards.FOX], dir = dir}]})
		assert_eq(w.tails, 0, "spent at round %d" % waited)
		for i in World.TAIL_REGROW - 1:
			w.act({t = &"wait"})
			assert_eq(w.tails, 0, "round %d after a cast at %d" % [i + 1, waited])
		w.act({t = &"wait"})
		assert_eq(w.tails, 1, "the third round after a cast at %d" % waited)


## Miho holds what a 그림자 takes and the tails for it, the talismans picked, the pointer off the map.
func _guise_ready() -> Node:
	var m := _main()
	var recipe: Array = Guise.RECIPE[Guise.SHADOW]
	m.world.cards.assign(recipe)
	m.world.tails = m.world.max_tails()
	m.look.hover = Vector2i(-1, -1)
	for c in recipe:
		m.casting.add(c)
	return m


func _foe_in_sight(m: Node) -> void:
	var at: Vector2i = m.world.player().pos + Vector2i(2, 0)
	m.world.set_tile(at, World.FLOOR)
	FloorGen.spawn(m.world, &"jangseung", at)
	m.world.sense()


func _wears_guise(m: Node) -> bool:
	return Guise.worn(m.world, m.world.player()).has(Guise.SHADOW)


func test_the_self_key_casts_the_picked_spell_on_her() -> void:
	var m := _guise_ready()
	_press(m, "Comma")
	assert_true(_wears_guise(m))


func test_with_no_foe_a_keyboard_pick_puts_the_cursor_on_her_and_enter_casts_there() -> void:
	var m := _guise_ready()
	m.casting.aim()
	assert_eq(m.look.hover, m.world.player().pos)
	_press(m, "Enter")
	assert_true(_wears_guise(m))


func test_with_no_foe_a_pick_leaves_the_cursor_where_the_pointer_is_on_the_map() -> void:
	var m := _guise_ready()
	var at: Vector2i = m.world.player().pos + Vector2i(3, 0)
	m.look.hover = at
	m.casting.aim()
	assert_eq(m.look.hover, at)


func test_tab_goes_through_the_foes_then_to_her() -> void:
	var m := _guise_ready()
	_foe_in_sight(m)
	m.casting.aim()
	var foes: Array = Fight.targets(m.world)
	assert_eq(foes.size(), 1)
	assert_eq(m.look.hover, foes[0].pos)
	m.casting.aim_next()
	assert_eq(m.look.hover, m.world.player().pos)
	m.casting.aim_next()
	assert_eq(m.look.hover, foes[0].pos)
	m.casting.aim_next()
	_press(m, "Enter")
	assert_true(_wears_guise(m), "Enter casts on the tile Tab reached")


func test_enter_in_look_mode_on_her_own_tile_casts_the_picked_spell_on_her() -> void:
	var m := _guise_ready()
	_press(m, "X")
	assert_eq(m.look.hover, m.world.player().pos)
	_press(m, "Enter")
	assert_true(_wears_guise(m))


func test_enter_on_her_own_tile_refuses_a_spell_that_cannot_go_on_her() -> void:
	var m := _main()
	m.world.cards.assign([Cards.FOX])
	m.world.tails = m.world.max_tails()
	m.casting.add(Cards.FOX)
	m.look.hover = m.world.player().pos
	_press(m, "Enter")
	assert_eq(m.world.round_no, 0)
	assert_true(m.casting.refused)
