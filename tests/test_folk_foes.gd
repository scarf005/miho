extends GutTest
## The folk-tale foes: 저승사자's 오랏줄 roots Miho, and 강철이, 어둑시니 and 두억시니
## come to the upper storeys with the rules the bestiary gives them.

const WAIT := {t = &"wait"}
const ME := Vector2i(10, 8)
const E := Vector2i(1, 0)
const FIRST := {&"gangcheori": 5, &"eodeopsini": 6, &"dueoksini": 7}


## An open hall, Miho at ME by a lantern, on storey `depth`.
func _world(depth := 7) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	w.tiles[Grid.index(ME + Vector2i(0, -2))] = World.LANTERN
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 30
	me.max_hp = 30
	me.pos = ME
	w.actors.append(me)
	w.depth = depth
	w.sense()
	return w


func _hunter(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.alert = Actor.HUNT
	a.target = ME
	a.cooldown = 9 if Bestiary.mana(kind) == 0 else 0
	w.sense()
	return a


func test_the_reapers_rope_roots_miho_where_it_strikes() -> void:
	var w := _world()
	_hunter(w, &"saja", ME + E)
	var events := w.act(WAIT)
	var rope: Dictionary = Bestiary.info(&"saja").melee
	assert_eq(w.player().hp, 30 - rope.damage)
	assert_eq(w.player().rooted, rope.root - 1, "the round that struck has passed")
	assert_true(events.any(func(e): return e.t == &"root" and e.id == w.player().id))
	assert_false(w.can({t = &"move", dir = -E}), "she cannot step away")


func test_a_blow_without_a_rope_roots_nothing() -> void:
	for kind in [&"dokkaebi", &"oedari", &"eodeopsini", &"dueoksini"]:
		var w := _world()
		_hunter(w, kind, ME + E)
		w.act(WAIT)
		assert_lt(w.player().hp, 30, kind)
		assert_eq(w.player().rooted, 0, kind)


func test_a_blow_that_kills_does_not_root() -> void:
	var w := _world()
	w.player().hp = 1
	_hunter(w, &"saja", ME + E)
	var events := w.act(WAIT)
	assert_false(events.any(func(e): return e.t == &"root"))


func test_the_forecast_of_a_rope_equals_the_round() -> void:
	var w := _world()
	_hunter(w, &"saja", ME + E)
	var forecast := Forecast.of(w, WAIT)
	w.act(WAIT)
	var seen := forecast.after.player()
	assert_eq([seen.hp, seen.rooted], [w.player().hp, w.player().rooted])
	assert_eq(forecast.after.rng.state, w.rng.state)


func test_the_forecast_of_each_new_kind_equals_the_round() -> void:
	for kind in [&"saja"] + FIRST.keys():
		var w := _world(9)
		_hunter(w, kind, ME + E * 4).cooldown = 0
		_hunter(w, kind, ME + E)
		var forecast := Forecast.of(w, WAIT)
		w.act(WAIT)
		assert_eq(forecast.after.player().hp, w.player().hp, kind)
		assert_eq(forecast.after.player().pos, w.player().pos, kind)
		assert_eq(forecast.after.rng.state, w.rng.state, kind)


func test_it_casts_the_dearest_spell_it_can_pay_and_then_one_it_can_with_the_rest() -> void:
	var w := _world()
	var saja := _hunter(w, &"saja", ME + E * 4)
	var plans := Aim.at(w, saja, w.player())
	assert_eq(plans.size(), 2, "it can pay for two")
	assert_eq(plans[0].cards.size(), 5, "the dearest first")
	assert_eq(Spell.price(plans[0].cards.size()), 7)
	assert_lte(Spell.price(plans[1].cards.size()), 2, "then what the two mana left buy")


func test_a_charge_pays_its_mana_and_a_creature_with_none_left_casts_nothing() -> void:
	var w := _world()
	var saja := _hunter(w, &"saja", ME + E * 4)
	w.act(WAIT)
	var spent := 0
	for plan in saja.intent:
		spent += Spell.price(plan.cards.size())
	assert_gt(spent, 0)
	assert_eq(saja.mana, 9 - spent)
	saja.mana = 0
	assert_eq(Aim.at(w, saja, w.player()), [] as Array[Dictionary])


func test_its_mana_regrows_one_in_the_rounds_miho_regrows_a_tail() -> void:
	var w := _world()
	var saja := FloorGen.spawn(w, &"saja", Vector2i(30, 8))
	saja.mana = 0
	saja.stunned = 99
	for i in World.TAIL_REGROW * 4:
		w.act(WAIT)
	assert_eq(saja.mana, 4)
	saja.mana = 9
	w.act(WAIT)
	assert_eq(saja.mana, 9, "never past nine")
	saja.mana = 8
	for i in World.TAIL_REGROW - 1:
		w.act(WAIT)
		assert_eq(saja.mana, 8, "a full wait from the moment it is spent")
	w.act(WAIT)
	assert_eq(saja.mana, 9)


func test_a_spray_that_adds_nothing_is_not_bought() -> void:
	var w := _world()
	var saja := _hunter(w, &"saja", ME + E * 2)
	saja.mana = 1
	var fresh := Aim.at(w, saja, w.player())
	assert_eq(fresh[0].cards, [Cards.WOOD], "the rope-spray first")
	w.player().rooted = 3
	var held := Aim.at(w, saja, w.player())
	assert_false(held.is_empty())
	assert_ne(held[0].cards, [Cards.WOOD], "she is rooted already")
	w.player().wet = 3
	w.player().alight = 3
	var marked := Aim.at(w, saja, w.player())
	assert_true(marked.all(func(p): return p.cards.size() == 1))
	assert_false(marked.any(func(p): return [Cards.WOOD, Cards.WATER, Cards.FIRE].has(p.cards[0])))


func test_a_blow_costs_the_reaper_no_mana() -> void:
	var w := _world()
	var saja := _hunter(w, &"saja", ME + E)
	w.act(WAIT)
	assert_eq(saja.mana, 9, "a blow costs no mana")
	assert_gt(w.player().rooted, 0)


func test_each_new_kind_is_placed_from_its_storey_on_and_never_below() -> void:
	for kind in FIRST:
		for depth in range(1, World.FLOORS + 1):
			var found := 0
			for seed in 4:
				var w := Built.storey(seed, depth)
				found += w.actors.filter(func(a): return a.kind == kind).size()
			assert_eq(found > 0, depth >= FIRST[kind], "%s on storey %d" % [kind, depth])


func test_the_fist_throws_miho_three_tiles_and_the_dark_one_walks_silent() -> void:
	var w := _world()
	_hunter(w, &"dueoksini", ME + E)
	w.act(WAIT)
	assert_eq(w.player().pos, ME - E * Bestiary.info(&"dueoksini").melee.throw)
	var dark := _world()
	var walker := _hunter(dark, &"eodeopsini", ME + E * 6)
	var moves := dark.act(WAIT).filter(func(e): return e.t == &"move" and e.id == walker.id)
	assert_false(moves.is_empty(), "it walked")
	assert_true(moves.all(func(e): return e.loud == 0), "and made no sound")


func test_every_glyph_is_one_creatures_alone() -> void:
	var seen := {}
	for kind in Bestiary.KINDS:
		var glyph: String = Bestiary.info(kind).glyph
		assert_false(seen.has(glyph), "%s shares %s with %s" % [kind, glyph, seen.get(glyph)])
		seen[glyph] = kind


func test_no_element_is_the_reaper_s_weakness_and_it_does_not_burn() -> void:
	for c: StringName in Cards.ELEMENTS:
		assert_false(Bestiary.weak(&"saja", Spell.make([Cards.ORB, c])), c)
	assert_false(Bestiary.burns(&"saja"))
