extends GutTest
## The example of one spell (SpellScene, ExampleSim): made from the spell alone, it tints
## before each cast the tiles the aim preview tints, and those are the tiles the cast touches.


func before_each() -> void:
	Keys.reset()


func after_all() -> void:
	Keys.reset()


## Every talisman held 1 to Spell.MAX_SLOTS times over, and every compound.
func _spells() -> Array:
	var out := []
	for c in Cards.ALL:
		for n in range(1, Spell.MAX_SLOTS + 1):
			var cards := []
			cards.resize(n)
			cards.fill(c)
			out.append(cards)
	for c in Cards.compounds():
		out.append(Cards.made_of(c))
	return out


## The tiles the round of `action` touches in `w`, read from its events alone.
func _touched(w: World, action: Dictionary) -> Dictionary:
	var out := {}
	for e in w.clone().act(action):
		match e.t:
			&"spawn":
				out[e.at] = true
			&"fly":
				out[e.to] = true
			&"spray", &"sprout", &"become", &"heat":
				for p: Vector2i in e.tiles:
					out[p] = true
			&"leap":
				if e.id == w.player().id:
					for i in range(1, Grid.cheb(e.from, e.to) + 1):
						out[e.from + Grid.line_dir(e.from, e.to) * i] = true
	return out


func test_the_tiles_tinted_before_a_cast_are_the_tiles_the_cast_touches() -> void:
	for cards in _spells():
		var scene := SpellScene.ready(SpellScene.of(cards))
		var w := CodexScene.build(scene)
		var cast := CodexScene.actions(scene)[0]
		var tinted: Dictionary = SpellScene.reach(w, cast).tints
		var touched := _touched(w, cast)
		for p: Vector2i in touched:
			assert_true(tinted.has(p), "%s: %s is touched and tinted" % [cards, p])
		for p: Vector2i in tinted:
			assert_true(touched.has(p), "%s: %s is tinted and touched" % [cards, p])


func test_one_fire_tints_its_fan_and_a_spell_on_herself_is_cast_on_her() -> void:
	var fan := SpellScene.ready(SpellScene.of([Cards.FIRE]))
	var cast := CodexScene.actions(fan)[0]
	var tinted: Dictionary = SpellScene.reach(CodexScene.build(fan), cast).tints
	assert_gt(tinted.size(), 1, "one 불 covers a fan")
	for kind in Guise.ANYWHERE:
		var scene := SpellScene.ready(SpellScene.of(Cards.made_of(kind)))
		assert_eq(CodexScene.actions(scene)[0].spells[0].dir, Vector2i.ZERO, "%s: on her" % kind)


func test_every_example_does_something_a_wait_would_not() -> void:
	for cards in _spells():
		var scene := SpellScene.ready(SpellScene.of(cards))
		var w := CodexScene.build(scene)
		for action in CodexScene.actions(scene):
			assert_true(w.can(action), "%s: %s is legal" % [cards, action])
			w.act(action)
		assert_true(SpellScene.alters(scene), "%s changes something" % [cards])


func test_a_creature_the_spell_needs_stands_by_her_row_inside_the_hall() -> void:
	for cards in _spells():
		var scene := SpellScene.ready(SpellScene.of(cards))
		var w := CodexScene.build(scene)
		for foe: Actor in w.actors.slice(1):
			assert_true(absi(foe.pos.y - w.player().pos.y) <= 1, "%s: by her row" % [cards])
			assert_true(CodexScene.HALL.has_point(foe.pos), "%s: in the hall" % [cards])


func test_a_queue_that_changes_later_does_not_change_the_example_made_from_it() -> void:
	var queue := [Cards.FIRE, Cards.WATER]
	SpellScene.ready(SpellScene.of(queue))
	queue.clear()
	var plan := SpellScene.ready(SpellScene.of([Cards.FIRE, Cards.WATER]))
	assert_eq(plan.cards, [Cards.FIRE, Cards.WATER])
