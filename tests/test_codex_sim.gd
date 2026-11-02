extends GutTest
## The 도감's examples (CodexSim): each entry's scene (CodexScene) plays real rounds of
## a World of its own, and does what its entry says where the window shows it.

const SPELLS := 1
const COMPOUNDS := 2
const STATUSES := 5
const WAIT := {t = &"wait"}


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


func _sim(m: Node) -> CodexSim:
	for child in m.term.get_children():
		if child is CodexSim:
			return child
	return null


func _key(m: Node, key: String) -> void:
	var e := Keys.event(key)
	e.pressed = true
	m._unhandled_input(e)


## What a player sees of `w`, but where a creature walked, which it does whether Miho
## casts or not. Miho's own place counts.
func _result(w: World) -> String:
	var creatures := []
	for a in w.actors:
		creatures.append([a.hp, a.wet, a.alight, a.frozen, a.rooted, a.stunned, a.alert, a.rival])
	var me := [w.player().pos, w.player().guise, w.player().cloak]
	return str(
		[w.tiles, w.burning.keys(), w.hot.keys(), w.gas.keys(), w.shots.size(), creatures, me]
	)


## The result of the scene at its start and after each round, its casts left out if `idle`.
func _rounds(scene: Dictionary, idle := false) -> Array:
	var w := CodexScene.build(scene)
	var out := [_result(w)]
	for action in CodexScene.actions(scene):
		w.act(WAIT if idle and action.t == &"cast" else action)
		out.append(_result(w))
	return out


func _assert_casts_matter(entries: Array) -> void:
	for e: Dictionary in entries:
		assert_false(e.scene.is_empty(), "%s has an example" % e.name)
		for scene in SpellScene.resolve(e.scene):
			var w := CodexScene.build(scene)
			for action in CodexScene.actions(scene):
				assert_true(w.can(action), "%s: %s is legal" % [e.name, action])
				w.act(action)
			assert_true(_rounds(scene) != _rounds(scene, true), "%s does something" % e.name)


func test_every_spell_entry_casts_and_does_what_waiting_would_not() -> void:
	_assert_casts_matter(Codex.entries(SPELLS))


func test_every_compound_entry_casts_and_does_what_waiting_would_not() -> void:
	_assert_casts_matter(Codex.entries(COMPOUNDS))


func test_every_status_entry_shows_its_status_on_a_creature() -> void:
	for key in Status.NAME:
		var scene := CodexScene.of(key)
		var w := CodexScene.build(scene)
		var told := []
		for action in CodexScene.actions(scene):
			told.append_array(w.act(action).map(func(e): return e.t))
			if w.actors.slice(1).any(func(a): return Status.of(a) == key):
				told.append(key)
		assert_has(told, key, "%s is caused" % key)


func test_every_condition_entry_casts_and_does_what_waiting_would_not() -> void:
	var conditions := Codex.entries(STATUSES).filter(func(e): return Info.CONDITIONS.has(e.name))
	assert_eq(conditions.size(), Info.CONDITIONS.size())
	_assert_casts_matter(conditions)


## Everything a round of the scene does happens inside the window. A spell's example reaches
## as far as the spell does, which a wide spray carries past the walls of the hall: it keeps
## Miho in the window.
func test_what_every_scene_does_stays_in_the_window() -> void:
	var window := Rect2i(CodexScene.CORNER, CodexScene.VIEW)
	for tab in Codex.TABS.size():
		for e in Codex.entries(tab):
			var of_a_spell: bool = e.scene.has("spell") or e.scene.has("each")
			for scene in SpellScene.resolve(e.scene):
				var w := CodexScene.build(scene)
				for action in CodexScene.actions(scene):
					if not w.can(action):
						break
					for event in w.act(action):
						var at: Vector2i = event.get("to", event.get("at", window.position))
						if event.t != &"noise" and Grid.inside(at) and not of_a_spell:
							assert_true(window.has_point(at), "%s: %s" % [e.name, event])
				assert_true(window.has_point(w.player().pos), "%s: Miho stays" % e.name)


func test_every_creature_entry_does_something_as_miho_waits() -> void:
	for kind in Codex.foes():
		var scene := CodexScene.of(kind)
		var w := CodexScene.build(scene)
		var events := []
		for action in CodexScene.actions(scene):
			events.append_array(w.act(action))
		var acted := events.filter(func(e): return e.get("id", -1) != w.player().id)
		assert_false(acted.is_empty(), "%s acts" % kind)


func test_a_homing_shot_turns_after_miho_as_she_moves_in_the_scene() -> void:
	var scene := CodexScene.of(&"dokkaebi")
	var w := CodexScene.build(scene)
	var rows := {}
	for action in CodexScene.actions(scene):
		w.act(action)
		for s in w.shots:
			rows[s.pos.y] = true
	assert_gt(rows.size(), 1, "the shot leaves its first row")


func test_every_tile_scene_plays_its_actions_and_changes_the_hall() -> void:
	for e in Codex.entries(4):
		if e.scene.is_empty():
			continue
		var w := CodexScene.build(e.scene)
		for action in CodexScene.actions(e.scene):
			assert_true(w.can(action), "%s: %s is legal" % [e.name, action])
			w.act(action)
		var rounds := _rounds(e.scene)
		assert_true(rounds.any(func(r): return r != rounds[0]), "%s changes the hall" % e.name)


func test_a_scene_plays_the_same_every_time() -> void:
	var scene := SpellScene.ready(SpellScene.of(Cards.made_of(Cards.compounds()[0])))
	var runs := []
	for k in 2:
		var w := CodexScene.build(scene)
		var told := []
		for action in CodexScene.actions(scene):
			told.append(w.act(action))
		runs.append(str(told) + str(w.rng.state))
	assert_eq(runs[0], runs[1])


func test_a_creature_scene_reads_at_the_rank_of_its_entry() -> void:
	for rank in [1, Bestiary.RANKS]:
		var w := CodexScene.build(CodexScene.of(&"dokkaebi"), rank)
		assert_eq(w.actors[1].hp, Bestiary.hp(&"dokkaebi", rank))
		assert_eq(Bestiary.rank(w.depth), rank)


func test_the_detail_never_runs_under_the_example() -> void:
	for room: Vector2i in [Vector2i(40, 18), Vector2i(66, 30), Vector2i(53, 24)]:
		var codex := Codex.new()
		codex.room = room
		for tab in [0, SPELLS, COMPOUNDS, STATUSES]:
			codex.go(tab)
			for k in Codex.entries(tab).size():
				codex.select(k)
				var shown := codex.panel()
				assert_false(shown.example.is_empty(), "%s has room" % room)
				var edge: float = room.x - CodexSim.beside(shown.example.scale)
				for line: Array in shown.aside:
					var width: float = line.reduce(func(n, r): return n + Term._cells(r[0]), 0.0)
					assert_true(Codex.SIDE_X + width <= edge, "%s at %s" % [line, room])


func test_a_screen_with_no_room_shows_no_example_and_keeps_the_text_wide() -> void:
	var codex := Codex.new()
	codex.room = Vector2i(26, 12)
	codex.go(COMPOUNDS)
	var narrow := Codex.new()
	narrow.room = Vector2i(40, 18)
	narrow.go(COMPOUNDS)
	assert_true(codex.panel().example.is_empty())
	assert_false(narrow.panel().example.is_empty())
	assert_eq(codex._lines(), Codex.flow(Codex.detail(Codex.entries(COMPOUNDS)[0]), 12.0))


func test_a_phone_upright_has_no_room_on_its_pages_and_one_on_its_side_has() -> void:
	var cells := func(size: Vector2) -> Vector2i:
		var plan := Touch.plan(size, Vector4.ZERO, 3.0, true, false)
		var k: float = plan.cw / Term.CELL.x
		return Vector2i(plan.map.size / (Term.CELL * k))
	assert_eq(CodexSim.scale_for(cells.call(Vector2(390, 844))), 0.0)
	assert_gt(CodexSim.scale_for(cells.call(Vector2(844, 390))), 0.0)


func test_the_box_of_a_word_over_the_example_hides_it() -> void:
	var m := _main()
	var sim := _sim(m)
	m._open(&"codex")
	m.term.hint_at = Vector2(0, m.term.rows - 1)
	m.term.hint = [[["가연성", Palette.TEXT]]]
	sim._process(0.0)
	assert_true(sim.visible, "a box on the far side leaves it be")
	m.term.hint_at = Vector2(sim.position.x / Term.CELL.x, CodexSim.TOP - 1.0)
	sim._process(0.0)
	assert_false(sim.visible, "a box under the word, from the example's column")
	m.term.hint = []
	sim._process(0.0)
	assert_true(sim.visible)


func test_an_entry_with_no_row_has_no_example() -> void:
	var codex := Codex.new()
	codex.room = Vector2i(66, 30)
	codex.go(6)
	assert_true(codex.panel().example.is_empty(), "the glossary shows only words")


func test_the_selection_starts_the_example_and_closing_stops_it() -> void:
	var m := _main()
	var sim := _sim(m)
	assert_false(sim.visible)
	m._open(&"codex")
	assert_true(sim.visible, "the first entry plays at once")
	assert_not_null(sim.world)
	var first := sim.world
	_key(m, "Down")
	assert_ne(sim.world, first, "the next entry starts over")
	var second := sim.world
	m.term.panel = m.menu.panel()
	assert_eq(sim.world, second, "the panel drawn again does not restart it")
	_key(m, "Escape")
	assert_false(sim.visible)
	assert_false(sim.is_processing())


func test_a_tab_with_no_example_hides_it() -> void:
	var m := _main()
	var sim := _sim(m)
	m._open(&"codex")
	_key(m, "7")
	assert_false(sim.visible)


## Opens the 도감, plays every kind of scene and closes it.
func _visit(m: Node) -> void:
	m._open(&"codex")
	var sim := _sim(m)
	for tab in Codex.TABS.size():
		m.menu.codex.go(tab)
		m.term.panel = m.menu.panel()
		if sim.is_processing():
			for k in 6:
				sim._left = 0.0
				sim._process(0.0)
				sim.rush()
	m._close()


func test_the_run_is_untouched_by_the_codex() -> void:
	var seen := _main()
	var plain := _main()
	var lines: int = seen.messages.lines.size()
	var actions: Array = seen.run.actions.duplicate()
	_visit(seen)
	assert_eq(seen.world.rng.state, plain.world.rng.state)
	assert_eq(seen.world.tiles, plain.world.tiles)
	assert_eq(seen.world.next_id, plain.world.next_id)
	assert_eq(seen.messages.lines.size(), lines)
	assert_eq(seen.run.actions, actions)
	var step := {t = &"wait"}
	assert_eq(
		str(seen.world.clone().act(step)),
		str(plain.world.clone().act(step)),
		"the run's next round is what it would have been"
	)


func test_the_example_has_no_way_to_the_sound_or_the_log() -> void:
	var m := _main()
	var sim := _sim(m)
	assert_true(sim.shown.get_connections().is_empty())
	assert_true(sim.settled.get_connections().is_empty())
	var calls := []
	m.term.shown.connect(func(e, _at): calls.append(e))
	_visit(m)
	assert_eq(calls, [], "the game's own term told the sound nothing")
