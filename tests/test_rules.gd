extends GutTest

const FOX := Cards.FOX
const ORB := Cards.ORB
const UP := Vector2i(0, -1)


func _world(at := Vector2i(4, 8)) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = at
	w.actors.append(me)
	w.depth = 4
	w.tails = 4
	return w


## A cast action of one or more spells; each spell is [cards] or [cards, dir].
func _cast(cards: Array, dir := Vector2i.ZERO) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func _casts(spells: Array) -> Dictionary:
	return {
		t = &"cast",
		spells =
		spells.map(func(s): return {cards = s[0], dir = s[1] if s.size() > 1 else Vector2i.ZERO})
	}


func _foe(w: World, kind: StringName, at: Vector2i, cooldown := 99) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = cooldown
	return a


func _types(events: Array) -> Array:
	return events.map(func(e): return e.t)


func test_spell_needs_a_form_and_distinct_cards() -> void:
	assert_null(Spell.make([]))
	assert_null(Spell.make([Cards.FIRE]))
	assert_null(Spell.make([FOX, FOX]))
	assert_not_null(Spell.make([Cards.FIRE, FOX]))
	assert_not_null(Spell.make([FOX, ORB, Cards.FIRE, Cards.WATER]))
	assert_null(
		Spell.make([ORB, Cards.FIRE, Cards.WATER, Cards.WOOD, Cards.METAL]), "four cards at most"
	)


func test_spell_names_and_costs() -> void:
	assert_eq(Spell.make([FOX, Cards.FIRE]).title(), "화염구")
	assert_eq(Spell.make([ORB, FOX]).title(), "여우구슬")
	assert_eq(Spell.make([ORB, Cards.WATER]).title(), "물구슬")
	assert_eq(Spell.make([Cards.METAL, ORB, Cards.FIRE]).title(), "불·쇠 구슬")
	assert_eq(Spell.make([FOX]).cost(), 1)
	assert_eq(Spell.make([ORB]).cost(), 1)
	assert_eq(Spell.make([ORB, Cards.FIRE, Cards.METAL]).cost(), 3)
	assert_eq(Spell.make([FOX, ORB, Cards.FIRE, Cards.METAL]).cost(), 4)


func test_foxfire_pair_seeks_the_nearest_foe() -> void:
	var w := _world()
	var near := _foe(w, &"jangseung", Vector2i(4, 4))
	var far := _foe(w, &"jangseung", Vector2i(0, 0))
	w.act(_cast([FOX]))
	assert_eq(near.hp, 1, "both wisps reach the nearer foe in one round")
	assert_eq(far.hp, 3)
	assert_eq(w.shots.size(), 0)


func test_foxfire_intercepts_hostile_foxfire() -> void:
	var w := _world()
	var dok := _foe(w, &"dokkaebi", Vector2i(4, 2))
	w._spawn(dok, Spell.make([FOX]), Vector2i(4, 6), Vector2i.ZERO)
	w._spawn(dok, Spell.make([FOX]), Vector2i(3, 6), Vector2i.ZERO)
	var events := w.act(_cast([FOX]))
	assert_eq(_types(events).count(&"clash"), 2)
	assert_eq(w.player().hp, 3)


func test_hostile_foxfire_burns_miho_after_her_next_action() -> void:
	var w := _world()
	var dok := _foe(w, &"dokkaebi", Vector2i(4, 2))
	w._spawn(dok, Spell.make([FOX]), Vector2i(4, 5), Vector2i.ZERO)
	w.act({t = &"wait"})
	assert_eq(w.player().hp, 2)


func test_orb_hits_harder_after_four_tiles() -> void:
	var w := _world()
	var far := _foe(w, &"jangseung", Vector2i(4, 3))
	w.act(_cast([ORB], UP))
	w.act({t = &"wait"})
	assert_eq(far.hp, 1, "five tiles out: 2 damage")
	var v := _world()
	var near := _foe(v, &"jangseung", Vector2i(4, 6))
	v.act(_cast([ORB], UP))
	assert_eq(near.hp, 2, "two tiles out: 1 damage")


func test_orb_snuffs_foxfire_and_flies_on() -> void:
	var w := _world()
	var wisp := w._spawn(w.player(), Spell.make([FOX]), Vector2i(4, 5), Vector2i.ZERO)
	var events := w.act(_cast([ORB], UP))
	assert_true(_types(events).has(&"snuff"))
	assert_true(wisp.gone)
	assert_eq(w.shots.filter(func(s): return s.spell.line).size(), 1)


func test_orbs_collide() -> void:
	var w := _world()
	var j := _foe(w, &"jangseung", Vector2i(4, 0))
	w._spawn(j, Spell.make([ORB]), Vector2i(4, 5), Vector2i(0, 1))
	var events := w.act(_cast([ORB], UP))
	assert_true(_types(events).has(&"clash"))
	assert_eq(w.shots.size(), 0)
	assert_eq(w.player().hp, 3)


func test_enemy_charges_a_round_before_casting_along_a_locked_line() -> void:
	var w := _world()
	var j := _foe(w, &"jangseung", Vector2i(4, 2), 0)
	var events := w.act({t = &"wait"})
	assert_true(_types(events).has(&"charge"))
	assert_eq(j.aim, Vector2i(0, 1))
	w.act({t = &"move", dir = Vector2i(-1, 0)})
	assert_eq(w.shots.size(), 1, "orb launched down the locked line")
	for i in 4:
		w.act({t = &"wait"})
	assert_eq(w.player().hp, 3, "stepping off the line dodges it")


func test_orbs_strike_creatures_of_either_side() -> void:
	var w := _world()
	_foe(w, &"jangseung", Vector2i(4, 1), 0)
	var shield := _foe(w, &"jangseung", Vector2i(4, 4))
	for i in 3:
		w.act({t = &"wait"})
	assert_eq(shield.hp, 2)
	assert_eq(w.player().hp, 3)


func test_haetae_eats_fire() -> void:
	var w := _world()
	w.cards.append(Cards.FIRE)
	var h := _foe(w, &"haetae", Vector2i(4, 5))
	var events := w.act(_cast([FOX, Cards.FIRE]))
	assert_true(_types(events).has(&"absorb"))
	assert_eq(h.hp, 4)


func test_bulgasari_dies_only_in_fire() -> void:
	var w := _world()
	w.cards.append(Cards.FIRE)
	var b := _foe(w, &"bulgasari", Vector2i(4, 6))
	w.act(_cast([FOX]))
	assert_eq(b.hp, 3)
	w.act(_cast([FOX, Cards.FIRE]))
	assert_lt(b.hp, 3)


func test_water_pushes_and_slams_into_pillars() -> void:
	var w := _world()
	w.cards.append(Cards.WATER)
	var j := _foe(w, &"jangseung", Vector2i(4, 6))
	w.act(_cast([ORB, Cards.WATER], UP))
	assert_eq(j.pos, Vector2i(4, 5))
	var v := _world()
	v.cards.append(Cards.WATER)
	v.tiles[Grid.index(Vector2i(4, 5))] = World.PILLAR
	var k := _foe(v, &"jangseung", Vector2i(4, 6))
	v.act(_cast([ORB, Cards.WATER], UP))
	assert_eq(k.pos, Vector2i(4, 6))
	assert_eq(k.hp, 1, "1 hit + 1 slam")


func test_wood_roots_and_earth_cancels_a_charge() -> void:
	var w := _world()
	w.cards.append_array([Cards.WOOD, Cards.EARTH])
	var d := _foe(w, &"imugi", Vector2i(4, 6))
	w.act(_cast([ORB, Cards.WOOD], UP))
	w.act({t = &"wait"})
	assert_eq(d.pos, Vector2i(4, 6), "rooted foe stays put for two rounds")
	w.act({t = &"wait"})
	assert_ne(d.pos, Vector2i(4, 6), "then walks again")
	var v := _world()
	v.cards.append(Cards.EARTH)
	var j := _foe(v, &"jangseung", Vector2i(4, 4), 0)
	v.act({t = &"wait"})
	assert_false(j.intent.is_empty())
	var events := v.act(_cast([FOX, Cards.EARTH]))
	assert_true(_types(events).has(&"stun"))
	assert_false(
		(
			_types(events).has(&"cast")
			and events.filter(func(e): return e.t == &"cast" and e.id == j.id).size() > 0
		)
	)
	assert_true(j.intent.is_empty())


func test_metal_orb_pierces_a_line_of_foes() -> void:
	var w := _world()
	w.cards.append(Cards.METAL)
	var a := _foe(w, &"jangseung", Vector2i(4, 6))
	var b := _foe(w, &"jangseung", Vector2i(4, 5))
	w.act(_cast([ORB, Cards.METAL], UP))
	assert_eq(a.hp, 2)
	assert_eq(b.hp, 2)


func test_fire_splash_burns_neighbours_and_the_caster() -> void:
	var w := _world()
	w.cards.append(Cards.FIRE)
	var a := _foe(w, &"jangseung", Vector2i(4, 6))
	var b := _foe(w, &"jangseung", Vector2i(5, 6))
	w.act(_cast([ORB, Cards.FIRE], Vector2i(0, -1)))
	assert_eq(a.hp, 2)
	assert_eq(b.hp, 2)
	var v := _world()
	v.cards.append(Cards.FIRE)
	_foe(v, &"jangseung", Vector2i(4, 7))
	v.act(_cast([ORB, Cards.FIRE], UP))
	assert_eq(v.player().hp, 2, "point-blank fire splashes back")


func test_strong_foe_gives_its_element_and_a_kill_gives_back_a_tail() -> void:
	var w := _world()
	var dog := _foe(w, &"bulgae", Vector2i(4, 6))
	dog.hp = 1
	w.tails = 1
	w.act(_cast([ORB], UP))
	assert_true(w.cards.has(Cards.FIRE))
	assert_eq(w.tails, 1 - 1 + 1 + 1, "one back for the kill, one regrown")


func test_a_spell_stacks_at_most_four_cards_at_a_tail_each() -> void:
	var w := _world()
	assert_false(w.can(_cast([FOX, Cards.FIRE])), "card not owned yet")
	w.cards.append_array([Cards.FIRE, Cards.WATER, Cards.METAL])
	var big := _cast([ORB, Cards.FIRE, Cards.WATER, Cards.METAL], UP)
	w.tails = 3
	assert_false(w.can(big), "four cards need four tails")
	w.tails = 4
	assert_true(w.can(big))
	w.act(big)
	assert_eq(w.tails, 1, "four spent, one regrown")
	assert_false(w.can(_cast([FOX, Cards.FIRE])))
	assert_true(w.can(_cast([FOX])))


func test_one_turn_splits_the_tails_across_several_spells() -> void:
	var w := _world()
	w.depth = 5
	w.tails = 5
	w.cards.append_array([Cards.FIRE, Cards.WATER, Cards.METAL])
	var one_four := _casts([[[FOX]], [[ORB, Cards.FIRE, Cards.WATER, Cards.METAL], UP]])
	assert_true(w.can(one_four), "1+4")
	assert_true(w.can(_casts([[[FOX]], [[FOX]], [[ORB], UP], [[ORB], Vector2i(1, -1)]])), "1+1+1+1")
	var six := [
		[[FOX]],
		[[FOX]],
		[[ORB], UP],
		[[ORB], Vector2i(1, -1)],
		[[ORB], Vector2i(1, 0)],
		[[ORB], Vector2i(-1, 0)]
	]
	assert_false(w.can(_casts(six)), "six cards, five tails")
	assert_false(w.can(_casts([[[ORB], UP], [[ORB], UP]])), "two orbs down one line")
	var events := w.act(one_four)
	assert_eq(events.filter(func(e): return e.t == &"cast" and e.id == w.player().id).size(), 2)
	assert_eq(w.tails, 1)


func test_spent_tails_regrow_one_a_round_up_to_the_storey() -> void:
	var w := _world()
	w.tails = 0
	w.act({t = &"wait"})
	assert_eq(w.tails, 1)
	for i in 5:
		w.act({t = &"wait"})
	assert_eq(w.tails, 4, "a fox on the fourth storey has four tails")


func test_preview_leaves_the_world_unchanged() -> void:
	var w := World.create(7)
	var before := var_to_str([w.player().pos, w.tails, w.actors.size(), w.round_no])
	var after := w.preview(_cast([FOX]))
	assert_eq(var_to_str([w.player().pos, w.tails, w.actors.size(), w.round_no]), before)
	assert_eq(after.round_no, w.round_no + 1)


func test_each_storey_grows_one_more_tail() -> void:
	var w := World.create(3)
	assert_eq(w.tails, 1)
	assert_eq(w.max_tails(), 1)
	w.tails = 0
	w.actors.assign([w.player()])
	w.player().pos = w.stairs + Vector2i(0, 1)
	w.act({t = &"move", dir = UP})
	assert_eq(w.depth, 2)
	assert_eq(w.tails, 2)
	assert_eq(w.player().pos, FloorGen.START)
	assert_true(w.actors.any(func(a): return a.kind == &"bulgae"))


func test_top_floor_holds_the_elixir() -> void:
	var w := World.create(5)
	w.depth = World.FLOORS
	FloorGen.build(w)
	assert_eq(w.stairs, Vector2i(-1, -1))
	w.actors.assign([w.player()])
	w.player().pos = w.elixir + Vector2i(0, 1)
	w.act({t = &"move", dir = UP})
	assert_eq(w.outcome, &"won")


func test_every_floor_is_connected_and_starts_clear() -> void:
	for seed_value in 40:
		var w := World.create(seed_value)
		for depth in range(1, World.FLOORS + 1):
			w.depth = depth
			FloorGen.build(w)
			var dist: PackedInt32Array = Grid.search(w.start, w.open_floor).dist
			for i in w.tiles.size():
				if w.tiles[i] == World.FLOOR:
					assert_true(
						dist[i] >= 0, "seed %d depth %d tile %d reachable" % [seed_value, depth, i]
					)
			assert_eq(w.actors.size(), FloorGen.PLAN[depth].size() + 1)
			for a in w.actors.slice(1):
				assert_gte(Grid.cheb(a.pos, w.start), 4)


func test_reaper_comes_for_a_lingering_fox() -> void:
	var w := _world()
	w.depth = 2
	w.start = Vector2i(0, 8)
	w.round_no = World.REAPER_ARRIVES - 1
	var events := w.act({t = &"wait"})
	assert_true(_types(events).has(&"arrive"))
	assert_true(w.actors.any(func(a): return a.kind == &"saja"))
