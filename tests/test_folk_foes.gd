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
	a.cooldown = 9 if Bestiary.tails(kind) == 0 else 0
	w.sense()
	return a


func _text(kind: StringName) -> String:
	return Info.plain(Info.creature_facts(Codex.foe(kind), []))


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


func test_the_hover_tells_the_rope_and_the_fist() -> void:
	assert_string_contains(_text(&"saja"), "근접: 오랏줄\n  피해: 1\n  묶음: 2초")
	assert_string_contains(_text(&"dueoksini"), "근접: 주먹\n  피해: 2\n  던짐: 3칸")
	assert_false(_text(&"oedari").contains("묶음"))
	assert_false(_text(&"dueoksini").contains("묶음"))


func test_the_hover_tells_each_new_kind_by_its_rules() -> void:
	assert_string_contains(_text(&"gangcheori"), "면역: 불")
	assert_string_contains(_text(&"eodeopsini"), "냄새를 따라감")
	assert_false(_text(&"eodeopsini").contains("말할 수 있다"))
	assert_string_contains(_text(&"dueoksini"), "둔함")


func test_the_reaper_has_one_list_of_up_to_five_card_spells_at_every_rank() -> void:
	var list := Bestiary.casts(&"saja", 1)
	var sizes := list.map(func(c): return c.size())
	assert_eq(Bestiary.elements(&"saja"), Cards.ELEMENTS)
	assert_gt(sizes.count(4), 2)
	assert_gt(sizes.count(5), 2)
	assert_eq(sizes.max(), Spell.MAX_SLOTS)
	for r in range(2, Bestiary.RANKS + 1):
		assert_eq(Bestiary.casts(&"saja", r), list, "rank %d" % r)
	for cast: Array in list:
		assert_not_null(Spell.make(cast), str(cast))
		assert_eq(Spell.make(cast).cards.size(), cast.size(), str(cast))


func test_the_reaper_starts_with_nine_tails_and_shows_them() -> void:
	var w := _world()
	var saja := FloorGen.spawn(w, &"saja", ME + E * 4)
	assert_eq(saja.tails, 9)
	assert_string_contains(_text(&"saja"), "꼬리: 9/9")
	assert_false(_text(&"saja").contains("간격"))
	assert_false(_text(&"oedari").contains("꼬리"))


func test_it_casts_the_dearest_spell_it_can_pay_and_then_one_it_can_with_the_rest() -> void:
	var w := _world()
	var saja := _hunter(w, &"saja", ME + E * 4)
	var plans := Aim.at(w, saja, w.player())
	assert_eq(plans.size(), 2, "it can pay for two")
	assert_eq(plans[0].cards.size(), 5, "the dearest first")
	assert_eq(Spell.price(plans[0].cards.size()), 7)
	assert_lte(Spell.price(plans[1].cards.size()), 2, "then what the two tails left buy")


func test_a_charge_pays_its_tails_and_a_creature_with_none_left_casts_nothing() -> void:
	var w := _world()
	var saja := _hunter(w, &"saja", ME + E * 4)
	w.act(WAIT)
	var spent := 0
	for plan in saja.intent:
		spent += Spell.price(plan.cards.size())
	assert_gt(spent, 0)
	assert_eq(saja.tails, 9 - spent + (1 if saja.acted % World.TAIL_REGROW == 0 else 0))
	saja.tails = 0
	assert_eq(Aim.at(w, saja, w.player()), [] as Array[Dictionary])


func test_its_tails_regrow_one_in_the_rounds_miho_regrows_hers() -> void:
	var w := _world()
	var saja := FloorGen.spawn(w, &"saja", Vector2i(30, 8))
	saja.tails = 0
	saja.stunned = 99
	for i in World.TAIL_REGROW * 4:
		w.act(WAIT)
	assert_eq(saja.tails, 4)
	saja.tails = 9
	w.act(WAIT)
	assert_eq(saja.tails, 9, "never past nine")


func test_a_spray_that_adds_nothing_is_not_bought() -> void:
	var w := _world()
	var saja := _hunter(w, &"saja", ME + E * 2)
	saja.tails = 1
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


func test_it_strikes_with_the_rope_when_next_to_miho_and_casts_when_it_is_not() -> void:
	var w := _world()
	var saja := _hunter(w, &"saja", ME + E)
	w.act(WAIT)
	assert_eq(saja.tails, 9, "a blow costs no tails")
	assert_gt(w.player().rooted, 0)


func test_the_dark_one_is_weak_to_the_element_that_beats_water() -> void:
	assert_eq(Bestiary.weak_to(&"eodeopsini"), [Cards.EARTH] as Array[StringName])


func test_the_brute_casts_a_lone_earth_and_two_from_the_fourth_rank() -> void:
	assert_eq(Bestiary.casts(&"dueoksini", 3), [[Cards.EARTH]])
	assert_has(Bestiary.casts(&"dueoksini", 4), [Cards.EARTH, Cards.EARTH])
	assert_eq(Bestiary.wits(&"dueoksini"), Bestiary.DULL)


func test_the_drought_dragon_eats_fire_and_leaves_nothing() -> void:
	assert_true(Bestiary.absorbs(&"gangcheori", Spell.make([Cards.FOX, Cards.FIRE])))
	assert_false(Bestiary.info(&"gangcheori").has("drop"))


func test_each_new_kind_is_placed_from_its_storey_on_and_never_below() -> void:
	for kind in FIRST:
		for depth in range(1, World.FLOORS + 1):
			var found := 0
			for seed in 4:
				var w := World.create(seed)
				w.depth = depth
				FloorGen.build(w)
				found += w.actors.filter(func(a): return a.kind == kind).size()
			assert_eq(found > 0, depth >= FIRST[kind], "%s on storey %d" % [kind, depth])


func test_every_glyph_is_one_creatures_alone() -> void:
	var seen := {}
	for kind in Bestiary.KINDS:
		var glyph: String = Bestiary.info(kind).glyph
		assert_false(seen.has(glyph), "%s shares %s with %s" % [kind, glyph, seen.get(glyph)])
		seen[glyph] = kind
