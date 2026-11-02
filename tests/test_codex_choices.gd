extends GutTest
## An example of several parts plays the one the player picks, over and over: a talisman by
## how many copies, a creature by its strike and each of its spells, which the creature
## itself does. A shot of a creature's in a hover box is cast by that creature.

const RANKS := [1, 2, 3, 4, 5]
const TALISMANS := 1
const FOES := 0


func before_each() -> void:
	Keys.reset()


func after_all() -> void:
	Keys.reset()


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	m._new_run(3)
	m.state = &"play"
	m.glass.visible = false
	return m


func _codex(m: Node, tab: int) -> CodexSim:
	m._open(&"codex")
	m.menu.codex.go(tab)
	m.term.panel = m.menu.panel()
	for child in m.term.get_children():
		if child is CodexSim:
			return child
	return null


func _press(m: Node, code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	m._unhandled_input(e)


func _play(sim: ExampleSim, rounds: int) -> void:
	for k in rounds:
		sim._left = 0.0
		sim._process(0.0)
		sim.rush()


func test_the_bracket_keys_pick_the_copies_of_a_talisman_and_the_example_stays_on_them() -> void:
	var m := _main()
	var sim := _codex(m, TALISMANS)
	assert_eq(sim._scene.spell.size(), 1)
	_press(m, KEY_BRACKETRIGHT)
	assert_eq(m.term.panel.choices.at, 1)
	assert_eq(sim._scene.spell.size(), 2)
	_play(sim, 300)
	assert_eq(sim._scene.spell.size(), 2, "it does not go on to the next by itself")
	_press(m, KEY_BRACKETLEFT)
	_press(m, KEY_BRACKETLEFT)
	assert_eq(m.term.panel.choices.at, Spell.MAX_SLOTS - 1, "wraps at the ends")


func test_another_entry_starts_on_its_first_choice() -> void:
	var m := _main()
	_codex(m, TALISMANS)
	_press(m, KEY_BRACKETRIGHT)
	m.menu.codex.select(1)
	m.term.panel = m.menu.panel()
	assert_eq(m.term.panel.choices.at, 0)


func test_a_click_picks_a_choice_and_the_pointer_lights_it() -> void:
	var m := _main()
	var sim := _codex(m, TALISMANS)
	var row: Vector2 = m.term.panel.choices.from + Vector2(1, 2)
	var local: Vector2 = (row + Vector2(0.1, 0.5)) * Term.CELL
	assert_eq(PanelView.choice_at(m.term, local), 2)
	assert_eq(PanelView.choice_at(m.term, Vector2.ZERO), -1)
	m.menu.point(PanelView.row_at(m.term, local))
	m.menu.codex.lit = PanelView.choice_at(m.term, local)
	m.term.panel = m.menu.panel()
	assert_eq(m.term.panel.choices.lit, 2)
	WordLink.click(m, local)
	m.term.panel = m.menu.panel()
	assert_eq(sim._scene.spell.size(), 3)


func test_opening_the_codex_again_lights_no_choice() -> void:
	var m := _main()
	_codex(m, TALISMANS)
	m.menu.codex.lit = 2
	m.menu.open(&"codex")
	assert_eq(m.menu.codex.lit, -1)


func test_a_click_on_a_kept_box_over_a_choice_does_not_pick_it() -> void:
	var m := _main()
	_codex(m, TALISMANS)
	var row: Vector2 = m.term.panel.choices.from + Vector2(1, 2)
	var local: Vector2 = (row + Vector2(0.1, 0.5)) * Term.CELL
	var fit := InfoBox.layout([[["하나", Palette.TEXT]]], Vector2(60, 24), InfoBox.READABLE)
	fit.at = row - Vector2.ONE
	fit.cells = Vector2(4, 4)
	fit.scale = 1.0
	m.term.pin = {fit = fit, lines = []}
	WordLink.click(m, local)
	assert_eq(m.menu.codex.part, 0)


func test_a_creature_strikes_and_casts_each_spell_itself_in_its_examples() -> void:
	for rank in RANKS:
		var list := Codex.entries(FOES, rank)
		var kinds := Codex.foes()
		for k in kinds.size():
			var kind: StringName = kinds[k]
			var parts := SpellScene.parts(list[k].scene)
			var casts := Bestiary.casts(kind, rank)
			var melee := Bestiary.info(kind).has("melee")
			var want: int = casts.size() + (1 if melee else 0)
			assert_eq(parts.filter(func(p): return p.has("charged")).size(), casts.size(), kind)
			assert_gte(parts.size(), want, kind)
			assert_false(parts.is_empty(), kind)
			for part: Dictionary in parts:
				var what := "%s %d %s" % [kind, rank, part.label]
				var w := CodexScene.build(part, rank)
				var told := []
				for action in CodexScene.actions(part):
					assert_ne(action.t, &"cast", what)
					if not w.can(action):
						break
					told.append_array(w.act(action).map(func(e): return e.t))
				if part.has("charged"):
					assert_has(told, &"cast", what)
				elif melee:
					assert_has(told, &"melee", what)


func test_every_part_of_a_creature_is_named() -> void:
	var list := Codex.entries(FOES, 5)
	for e: Dictionary in list:
		for part: Dictionary in SpellScene.parts(e.scene):
			assert_ne(part.get("label", ""), "", e.name)


func test_a_creatures_shot_in_a_hover_box_is_cast_by_that_creature() -> void:
	var m := _main()
	var w: World = m.world
	var me: Vector2i = w.player().pos
	var foe := FloorGen.spawn(w, &"imugi", me + Vector2i(0, -2))
	foe.magic.cooldown = 99
	var spell := Bestiary.spell(&"imugi", [Cards.ORB])
	var shot: Shot = Flight.spawn(w, foe, spell, Vector2i(0, 1), 0)
	shot.pos = me + Vector2i(0, -1)
	w.sense()
	m.term.show_world(w)
	m._forecast()
	m.hover = shot.pos
	m._refresh()
	assert_eq(m.term.example.get("key"), &"imugi")
	assert_eq(m.term.example.get("charged"), spell.cards)


func test_miho_casts_her_own_shot_in_a_hover_box() -> void:
	var m := _main()
	var w: World = m.world
	var shot: Shot = Flight.spawn(w, w.player(), Spell.make([Cards.ORB]), Vector2i(0, -1), 0)
	shot.pos = w.player().pos + Vector2i(0, -1)
	w.sense()
	m.term.show_world(w)
	m._forecast()
	m.hover = shot.pos
	m._refresh()
	assert_eq(m.term.example.get("spell"), [Cards.ORB])


func test_a_long_list_of_choices_keeps_the_picked_one_in_view() -> void:
	var m := _main()
	_codex(m, FOES)
	m.menu.codex.select(Codex.foes().find(&"saja"))
	m.menu.codex.room = Vector2i(66, 18)
	m.term.panel = m.menu.panel()
	_press(m, KEY_BRACKETLEFT)
	var choices: Dictionary = m.term.panel.choices
	assert_eq(choices.at, choices.names.size() - 1)
	assert_gt(choices.top, 0)
	assert_lt(choices.at, choices.top + choices.fit)
	var row: Vector2 = choices.from + Vector2(1, choices.at - choices.top)
	assert_eq(PanelView.choice_at(m.term, (row + Vector2(0.1, 0.5)) * Term.CELL), choices.at)
