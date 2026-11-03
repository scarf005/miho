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
	m.new_run(3)
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
		creatures.append(
			[
				a.hp,
				a.ailments.wet,
				a.ailments.alight,
				a.ailments.frozen,
				a.ailments.rooted,
				a.ailments.stunned,
				a.brain.alert,
				a.ties.rival
			]
		)
	var me := [w.player().pos, w.player().buffs.guise, w.player().buffs.cloak]
	return str(
		[w.tiles, w.burning.keys(), w.hot.keys(), w.gas.keys(), w.shots.size(), creatures, me]
	)


## The result of the scene at its start and after each round, its casts left out if `idle`.
func _rounds(scene: Dictionary, idle := false) -> Array:
	var w := CodexScene.build(_uncharged(scene) if idle else scene)
	var out := [_result(w)]
	for action in CodexScene.actions(scene):
		if not w.can(action):
			break
		w.act(WAIT if idle and action.t == &"cast" else action)
		out.append(_result(w))
	return out


## The scene with its creature casting nothing.
func _uncharged(scene: Dictionary) -> Dictionary:
	var out := scene.duplicate()
	out.erase("charged")
	return out


func _assert_casts_matter(entries: Array) -> void:
	for e: Dictionary in entries:
		assert_false(e.scene.is_empty(), "%s has an example" % e.name)
		for scene in SpellScene.resolve(e.scene):
			var w := CodexScene.build(scene)
			for action in CodexScene.actions(scene):
				assert_true(
					scene.has("charged") or w.can(action), "%s: %s is legal" % [e.name, action]
				)
				if w.can(action):
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


func test_a_homing_shot_turns_after_miho_as_she_moves_in_the_scene() -> void:
	var homing: Array = Bestiary.casts(&"dokkaebi", 1)[0]
	assert_gt(Spell.make(homing).turn(), 0)
	var scene := CodexScene.charged(&"dokkaebi", homing)
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
		var w := CodexScene.build(CodexScene.foe(&"dokkaebi", rank).each[0], rank)
		assert_eq(w.actors[1].hp, Bestiary.hp(&"dokkaebi", rank))
		assert_eq(Bestiary.rank(w.depth), rank)


func test_a_creature_scene_follows_the_language_and_the_rank_it_is_asked_in() -> void:
	var korean: String = CodexScene.foe(&"dokkaebi", 1).each[0].label
	Lang.locked = false
	Lang.forced = &"en"
	var english: String = CodexScene.foe(&"dokkaebi", 1).each[0].label
	Lang.forced = &""
	Lang.locked = true
	assert_ne(english, korean)
	assert_eq(CodexScene.foe(&"dokkaebi", 1).each[0].label, korean)
	var low: int = CodexScene.foe(&"haetae", 1).each.size()
	assert_gt(CodexScene.foe(&"haetae", Bestiary.RANKS).each.size(), low)
	assert_eq(CodexScene.foe(&"haetae", 1).each.size(), low)


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
					var width: float = line.reduce(
						func(n, r): return n + Term.text_cells(r[0]), 0.0
					)
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
	m.panels.open(&"codex")
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
	m.panels.open(&"codex")
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
	m.panels.open(&"codex")
	_key(m, "7")
	assert_false(sim.visible)


## Opens the 도감, plays every kind of scene and closes it.
func _visit(m: Node) -> void:
	m.panels.open(&"codex")
	var sim := _sim(m)
	for tab in Codex.TABS.size():
		m.menu.codex.go(tab)
		m.term.panel = m.menu.panel()
		if sim.is_processing():
			for k in 6:
				sim._left = 0.0
				sim._process(0.0)
				sim.rush()
	m.panels.close()


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


## The health the creatures against Miho lose over the rounds of `scene`, which `w` plays.
func _foe_harm(w: World, scene: Dictionary) -> int:
	var harm := 0
	var foes := {}
	for action in CodexScene.actions(scene):
		if not w.can(action):
			break
		for a in w.actors:
			if a.faction != Actor.FOX:
				foes[a.id] = true
		for event in w.act(action):
			if event.t == &"hurt" and foes.has(event.id):
				harm += event.n
	return harm


## Whether the spell of `cards` harms a tough creature that stands still, 3 or 5 tiles from
## Miho in a bare hall, in the rounds a spell's example lasts, by either of two dice.
func _harms_a_creature_that_stands_still(cards: Array) -> bool:
	for dx in [3, 5]:
		for seed in [1, 2]:
			var scene := {
				key = &"cheonha",
				map = "  @" + " ".repeat(dx - 1) + "g",
				cards = cards,
				do = "c" + ".".repeat(SpellScene.WAITS),
			}
			var w := CodexScene.build(scene)
			w.rng.seed = seed
			if _foe_harm(w, scene) > 0:
				return true
	return false


## The orbs that burst within a tile of a creature against Miho over the rounds of `scene`.
func _bursts_on_a_creature(scene: Dictionary) -> int:
	var w := CodexScene.build(scene)
	var bursts := 0
	for action in CodexScene.actions(scene):
		var foes := (
			w.actors.filter(func(a): return a.faction != Actor.FOX).map(func(a): return a.pos)
		)
		for event in w.act(action):
			if event.t == &"burst" and foes.any(func(p): return Grid.cheb(p, event.at) <= 1):
				bursts += 1
	return bursts


func test_the_furnace_example_bursts_more_than_one_orb_on_its_creature() -> void:
	var name := Lang.t(Cards.NAME[Forge.FURNACE])
	var entry: Dictionary = Codex.entries(COMPOUNDS).filter(func(e): return e.name == name)[0]
	var made := Cards.made_of(Forge.FURNACE)
	var shown: Array[Dictionary] = [entry.scene]
	for cards: Array in [[Cards.ORB] + made, made + [Cards.ORB]]:
		shown.append(SpellScene.of(cards))
	for one in shown:
		var scene := SpellScene.resolve(one)[0]
		assert_gt(_bursts_on_a_creature(scene), 1, "an orb in the first rounds and another later")


func test_talismans_of_a_furnace_with_no_orb_are_not_shown_its_example() -> void:
	var scene := SpellScene.resolve(SpellScene.of(Cards.made_of(Forge.FURNACE)))[0]
	assert_ne(scene.get("key"), Forge.FURNACE)


func test_no_example_writes_over_the_walls_of_its_hall() -> void:
	var bare := CodexScene.hall()
	var ring := CodexScene.HALL.grow(1)
	for key: Variant in CodexScene.TABLE:
		var w := CodexScene.build(CodexScene.of(key))
		for y in range(ring.position.y, ring.end.y):
			for x in range(ring.position.x, ring.end.x):
				var p := Vector2i(x, y)
				if not CodexScene.HALL.has_point(p) and bare.tile(p) == World.WALL:
					assert_eq(w.tile(p), World.WALL, "%s at %s" % [key, p])


func test_a_lone_elements_spray_a_creature_casts_in_its_example_covers_miho() -> void:
	for rank in range(1, Bestiary.RANKS + 1):
		for e in Codex.entries(0, rank):
			for scene in SpellScene.resolve(e.scene):
				if not scene.has("charged") or Spray.called(Spell.make(scene.charged)) == "":
					continue
				var w := CodexScene.build(scene, rank)
				var me := w.player().pos
				var sprays := w.act(CodexScene.actions(scene)[0]).filter(
					func(ev): return ev.t == &"spray"
				)
				assert_true(
					sprays.any(func(ev): return ev.tiles.has(me)),
					"%s: %s reaches her at rank %d" % [e.name, scene.label, rank]
				)


func test_the_example_of_a_spell_that_harms_harms_the_creature_it_shows() -> void:
	var harmful := 0
	for tab in [SPELLS, COMPOUNDS]:
		for e in Codex.entries(tab):
			for scene in SpellScene.resolve(e.scene):
				var spell := Spell.make(scene.cards)
				if Guise.kind(spell) != &"":
					continue
				if _harms_a_creature_that_stands_still(scene.cards):
					var w := CodexScene.build(scene)
					assert_gt(_foe_harm(w, scene), 0, "%s harms in its example" % spell.shown())
					harmful += 1
	assert_gt(harmful, 0, "some of them harm")


func _compound(name: String) -> Dictionary:
	var list := Codex.entries(COMPOUNDS)
	return list[list.find_custom(func(e): return e.name == name)]


func test_the_lightning_of_a_creature_has_an_entry_whose_example_hits_miho_at_once() -> void:
	var scene: Dictionary = SpellScene.resolve(_compound(Spell.BOLT_NAME).scene)[0]
	var w := CodexScene.build(scene)
	var hp: int = w.player().hp
	w.act(WAIT)
	assert_lt(w.player().hp, hp, "it hits")
	assert_true(w.shots.is_empty(), "and stays nowhere")


func test_what_a_creature_alone_does_is_what_its_entry_tells() -> void:
	var text := Info.plain(Codex.detail(_compound(Spell.BOLT_NAME)))
	assert_true(Elements.bolt(Bestiary.spell(&"jiha", [Cards.FOX, Cards.METAL])))
	assert_false(text.contains("지속 시간"), "a bolt stays nowhere")
	assert_string_contains(text, "속도: 즉시")
	var wisp := Info.plain(Codex.detail(_compound("도깨비불")))
	assert_false(wisp.contains("대상:"), "it aims at Miho, no creature")
	assert_false(wisp.contains("정지 중 소음"), "the lure is Miho's")
