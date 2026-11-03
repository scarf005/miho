extends GutTest
## Where the example of a spell is shown: in the box of a hover over a spell, in the spellbook
## and in the 도감's talisman entry. Each plays a World of its own and leaves the run alone.


func before_each() -> void:
	Keys.reset()


func after_all() -> void:
	Keys.reset()


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	m.new_run(3)
	m.state = &"play"
	m.glass.visible = false
	return m


func _sim(m: Node) -> CodexSim:
	for child in m.term.get_children():
		if child is CodexSim:
			return child
	return null


## Plays `rounds` rounds of the example `sim` shows, as fast as it can.
func _play(sim: ExampleSim, rounds: int) -> void:
	for k in rounds:
		sim._left = 0.0
		sim._process(0.0)
		sim.rush()


func test_a_hovered_spell_plays_in_its_box_and_closing_the_box_frees_its_world() -> void:
	var m := _main()
	assert_null(m.term.sim)
	m.look.hover_card = Cards.FIRE
	m.refresh()
	assert_eq(m.term.example.spell, [Cards.FIRE])
	var sim: ExampleSim = m.term.sim
	assert_not_null(sim.world, "its world is made as the box opens")
	m.refresh()
	assert_eq(m.term.sim, sim, "the same box goes on playing")
	m.look.hover_card = &""
	m.refresh()
	assert_true(m.term.example.is_empty())
	assert_null(m.term.sim)
	assert_true(sim.is_queued_for_deletion())


func test_every_box_about_one_spell_shows_it_and_a_box_about_a_tile_does_not() -> void:
	var m := _main()
	m.casting.picked.assign([Cards.FIRE, Cards.FIRE])
	m.look.hover_slot = 0
	m.refresh()
	assert_eq(m.term.example.spell, [Cards.FIRE, Cards.FIRE], "a slot of the queue")
	m.look.hover_slot = -1
	m.look.hover_spell = "orb+fire"
	m.refresh()
	assert_eq(m.term.example.spell, [Cards.ORB, Cards.FIRE], "a saved spell")
	m.look.hover_spell = ""
	m.look.hover_card = Cards.compounds()[0]
	m.refresh()
	assert_eq(m.term.example.spell, Cards.spell_of(m.look.hover_card), "a compound")
	m.look.hover_card = &""
	m.look.hover = m.world.player().pos
	m.refresh()
	assert_true(m.term.example.is_empty(), "a tile")


func test_a_flying_shot_on_the_map_shows_its_spell() -> void:
	var m := _main()
	var me: Vector2i = m.world.player().pos
	m.world.cards.assign(Cards.ALL)
	m.world.tails = m.world.max_tails()
	Cast.cast(m.world, m.world.player(), Spell.make([Cards.FOX]), Vector2i(1, 0))
	m.world.sense()
	m.known = m.world.known_clone()
	var shot: Shot = m.world.shots[0]
	m.look.hover = shot.pos
	m.refresh()
	assert_eq(m.term.example.spell, [Cards.FOX], "from %s" % me)


func test_a_shot_of_a_caster_she_does_not_see_does_not_tell_its_kind() -> void:
	var m := _main()
	var me: Vector2i = m.world.player().pos
	var hidden: Actor = FloorGen.spawn(m.world, &"gamtu", me + Vector2i(1, 0) * (Hat.REACH + 1))
	var shot := Shot.new()
	shot.spell = Spell.make([Cards.FOX])
	shot.faction = Actor.HEAVEN
	shot.caster = hidden.id
	shot.pos = me + Vector2i(0, 1)
	shot.life = 4
	m.world.shots.append(shot)
	m.world.seen[Grid.index(shot.pos)] = 1
	m.world.seen[Grid.index(hidden.pos)] = 1
	m.known = m.world.known_clone()
	m.look.hover = shot.pos
	m.refresh()
	assert_ne(m.term.example.key, hidden.kind)


func test_the_box_keeps_its_text_clear_of_the_example_and_drops_it_when_there_is_no_room() -> void:
	var lines := [[["하나", Palette.TEXT]], [["둘 둘 둘", Palette.TEXT]], [["셋", Palette.TEXT]]]
	var extra := Vector2(CodexScene.VIEW)
	var fit := InfoBox.layout(lines, Vector2(60, 24), InfoBox.READABLE, extra)
	var text_end := 0.0
	for column: Array in fit.columns:
		for line: Array in column[1]:
			text_end = maxf(text_end, column[0] + InfoBox._width(line))
	assert_true(fit.example.x >= text_end, "the example starts after the last column")
	assert_true(fit.example.x + extra.x <= fit.cells.x, "and ends inside the box")
	assert_true(fit.example.y + extra.y <= fit.cells.y, "and does not run past its foot")
	assert_false(InfoBox.layout(lines, Vector2(60, 24)).has("example"), "no example unless asked")
	var t: Term = autofree(Term.new())
	t.cols = 12
	t.rows = 6
	assert_false(t.fit_far_from(null, lines, extra).has("example"), "a screen too small drops it")


func test_the_spellbook_puts_the_example_where_no_text_is_and_none_where_none_fits() -> void:
	var shown_once := false
	for room in [Vector2i(66, 30), Vector2i(53, 24), Vector2i(40, 18), Vector2i(20, 9)]:
		var menu := Menu.new()
		menu.settings.spells = {&"slot_1": "orb+fire"}
		menu.queued = Spell.make([Cards.FOX, Cards.FOX, Cards.FIRE])
		menu.room = room
		menu.open(&"spells")
		var page := menu.panel()
		if page.example.is_empty():
			continue
		shown_once = true
		var box := Rect2(page.example.at, Vector2(CodexScene.VIEW) * page.example.scale)
		for k in page.rows.size():
			var row := Rect2(2, 3 + k, PanelView.end(page.rows[k]) - 2, 1)
			assert_false(row.intersects(box), "row %d at %s" % [k, room])
		for k in page.detail.size():
			var at: int = room.y - page.detail.size() + k
			var line := Rect2(2, at, PanelView.end(page.detail[k]) - 2, 1)
			assert_false(line.intersects(box), "line %d at %s" % [k, room])
		assert_true(Rect2(0, 0, room.x, room.y).encloses(box), "on the screen at %s" % room)
	assert_true(shown_once, "a big enough screen has it")
	var tiny := Menu.new()
	tiny.queued = Spell.make([Cards.FOX])
	tiny.room = Vector2i(20, 9)
	tiny.open(&"spells")
	assert_true(tiny.panel().example.is_empty())


func test_the_runs_world_and_dice_are_untouched_by_a_hovered_spell() -> void:
	var seen := _main()
	var plain := _main()
	seen.look.hover_card = Cards.FIRE
	seen.refresh()
	var sim: ExampleSim = seen.term.sim
	_play(sim, 30)
	seen.look.hover_card = &""
	seen.refresh()
	assert_eq(seen.world.rng.state, plain.world.rng.state)
	assert_eq(seen.world.tiles, plain.world.tiles)
	assert_eq(seen.world.next_id, plain.world.next_id)
	assert_eq(seen.run.actions, plain.run.actions)
	assert_true(sim.shown.get_connections().is_empty(), "no way to the sound")
	assert_true(sim.settled.get_connections().is_empty())


func test_a_slot_the_queue_no_longer_has_is_no_longer_under_the_pointer() -> void:
	var m := _main()
	m.world.cards.assign(Cards.ALL)
	m.casting.picked.assign([Cards.FOX, Cards.FIRE])
	m.forecast()
	m.look.hover_slot = 1
	m.refresh()
	assert_false(m.term.info.is_empty(), "the slot shows a box")
	m.casting.unpick()
	assert_eq(m.look.hover_slot, -1, "the slot went with the talisman")
	m.look.hover_slot = 0
	m.casting.unpick()
	assert_eq(m.look.hover_slot, -1, "the queue is empty")
