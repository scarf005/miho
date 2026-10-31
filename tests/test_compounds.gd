extends GutTest
## Each compound's own effect: sprayed, and carried on a wisp or an orb to the
## 3x3 where it ends; the ground it leaves (hot ground, ice, thorns, mud) and
## the rules of that ground, the hover text and the log.

const FOX := Cards.FOX
const ORB := Cards.ORB
const FIRE := Cards.FIRE
const WATER := Cards.WATER
const WOOD := Cards.WOOD
const METAL := Cards.METAL
const EARTH := Cards.EARTH
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(20, 12)


## A lit open hall walled at the edges, Miho at ME with five tails.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(2, Grid.W - 2, 3):
		w.tiles[Grid.index(Vector2i(x, ME.y - 4))] = World.LANTERN
		w.tiles[Grid.index(Vector2i(x, ME.y + 4))] = World.LANTERN
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 9
	me.max_hp = 9
	me.pos = ME
	w.actors.append(me)
	w.depth = 13
	w.tails = 5
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts: a 장승 (no element, 3 health).
func _post(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", at)
	a.cooldown = 99
	w.sense()
	return a


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


func _harm(events: Array, id: int) -> int:
	var n := 0
	for e in _of(events, &"hurt"):
		n += e.n if e.id == id else 0
	return n


func _lines(before: World, w: World, events: Array) -> Array:
	return Messages.of(before, w, events).map(Messages.plain)


func test_wildfire_sets_the_fan_and_its_creatures_alight_and_always_spreads() -> void:
	var w := _world()
	_put(w, ME + Vector2i(2, 1), World.GRASS)
	var foe := _post(w, ME + Vector2i(2, 0))
	w.act(_cast([WOOD, FIRE]))
	assert_true(w.burning.has(ME + Vector2i(2, 1)), "grass in the fan burns")
	assert_true(w.wild.has(ME + Vector2i(2, 1)), "and always spreads")
	assert_gt(foe.alight, 0, "the creature in it is alight")
	assert_false(w.burning.has(ME + Vector2i(1, 1)), "bare floor does not burn")


func test_lava_leaves_hot_ground_that_sears_whoever_stands_on_it_and_cools() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(3, 0))
	foe.max_hp = 9
	foe.hp = 9
	var events := w.act(_cast([FIRE, EARTH]))
	for k in range(1, 4):
		assert_eq(w.hot.get(ME + E * k), Vector2i(Compounds.LAVA, Compounds.HOT_ROUNDS - 1), str(k))
	assert_false(w.hot.has(ME + E * 4), "the line stops at the creature")
	var harm: int = Compounds.HOT[Compounds.LAVA].harm
	assert_eq(_harm(events, foe.id), harm, "seared as the round ends")
	assert_eq(_of(events, &"sear").size(), 1)
	var cooled := []
	for i in Compounds.HOT_ROUNDS - 1:
		cooled.append_array(_of(w.act(WAIT), &"cool"))
	assert_eq(foe.hp, 9 - harm * Compounds.HOT_ROUNDS, "a round of harm a second")
	assert_true(w.hot.is_empty(), "cooled after %d rounds" % Compounds.HOT_ROUNDS)
	assert_eq(cooled.size(), 1, "one line for the cooling")
	assert_eq(cooled[0].tiles.size(), 3)


func test_hot_ground_lies_only_on_dry_walkable_ground() -> void:
	var w := _world()
	_put(w, ME + E * 2, World.POND)
	_put(w, ME + E * 3, World.SHALLOW)
	w.act(_cast([FIRE, METAL]))
	assert_eq(w.hot.keys(), [ME + E, ME + E * 4])
	assert_eq(w.hot[ME + E].x, Compounds.MOLTEN)


func test_molten_iron_sears_harder_than_lava_and_a_fire_eater_takes_none() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	var events := w.act(_cast([FIRE, METAL]))
	assert_eq(_harm(events, foe.id), Compounds.HOT[Compounds.MOLTEN].harm)
	assert_gt(Compounds.HOT[Compounds.MOLTEN].harm, Compounds.HOT[Compounds.LAVA].harm)
	w = _world()
	var dog := FloorGen.spawn(w, &"haetae", ME + Vector2i(2, 0))
	dog.cooldown = 99
	dog.rooted = 9
	w.sense()
	events = w.act(_cast([FIRE, METAL]))
	assert_eq(_harm(events, dog.id), 0, "해태 eats fire")
	assert_false(_of(events, &"absorb").is_empty())


func test_heaven_walks_round_hot_ground() -> void:
	var w := _world()
	w.hot[ME + Vector2i(2, 0)] = Vector2i(Compounds.LAVA, 9)
	var a := FloorGen.spawn(w, &"dokkaebi", ME + Vector2i(3, 0))
	a.cooldown = 99
	w.sense()
	a.alert = Actor.HUNT
	a.target = ME
	var before := a.pos
	w.act(WAIT)
	assert_ne(a.pos, ME + Vector2i(2, 0))
	assert_ne(a.pos, before, "it still comes")


func test_shrapnel_hurts_every_creature_in_the_3x3_three_ahead() -> void:
	var w := _world()
	var near := _post(w, ME + Vector2i(3, 1))
	var mid := _post(w, ME + Vector2i(4, -1))
	var far := _post(w, ME + Vector2i(5, 0))
	var events := w.act(_cast([EARTH, METAL]))
	assert_eq(_harm(events, near.id), Compounds.SHRAPNEL)
	assert_eq(_harm(events, mid.id), Compounds.SHRAPNEL)
	assert_eq(_harm(events, far.id), 0, "outside the square")
	assert_eq(_of(events, &"noise")[0].loud, Spray.GUN_LOUD)


func test_frost_freezes_the_first_creature_and_the_ponds_on_its_line() -> void:
	var w := _world()
	_put(w, ME + E, World.POND)
	_put(w, ME + E * 2, World.POND)
	var foe := _post(w, ME + E * 3)
	var behind := _post(w, ME + E * 4)
	var events := w.act(_cast([METAL, WATER]))
	assert_eq([w.tile(ME + E), w.tile(ME + E * 2)], [World.ICE, World.ICE])
	assert_true(w.open_floor(ME + E), "ice is walked")
	assert_eq(foe.rooted, Compounds.FROST - 1, "frozen, a round of it gone")
	assert_eq(behind.rooted, 0, "the line stops at the first")
	assert_eq(_of(events, &"freeze").size(), 1)
	assert_true(_of(events, &"noise").is_empty(), "silent")
	w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, ME + E, "Miho walks onto the ice")


func test_rain_roots_the_3x3_and_douses_it() -> void:
	var w := _world()
	_put(w, ME + Vector2i(3, 1), World.BOARD)
	w.ignite(ME + Vector2i(3, 1))
	var foe := _post(w, ME + Vector2i(4, -1))
	var events := w.act(_cast([WATER, WOOD]))
	assert_false(w.burning.has(ME + Vector2i(3, 1)), "doused")
	assert_eq(_of(events, &"root")[0].rounds, Compounds.RAIN)
	assert_eq(foe.rooted, Compounds.RAIN - 1)


func test_steam_clouds_the_3x3_three_ahead_and_scalds_who_is_inside() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(4, 1))
	foe.max_hp = 9
	foe.hp = 9
	var events := w.act(_cast([WATER, FIRE]))
	assert_false(_of(events, &"gas").is_empty())
	assert_eq(Gas.at(w, ME + E * 3).x, Gas.STEAM)
	assert_eq(_harm(events, foe.id), Gas.of(Gas.STEAM, "harm"), "scalded as the round ends")
	assert_eq(w.player().hp, 9, "Miho stands clear of it")
	assert_true(w.opaque(ME + E * 3), "the cloud blocks sight")
	w.act(WAIT)
	assert_true(w.opaque(ME + E * 3), "the next round too")


func test_thorns_grow_prick_and_hurt_whoever_steps_onto_them() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	var events := w.act(_cast([METAL, WOOD]))
	assert_eq(_harm(events, foe.id), Compounds.THORN)
	assert_eq(w.tile(ME + E), World.THORNS)
	assert_eq(w.tile(foe.pos), World.THORNS, "under the creature too")
	assert_eq(w.opaque(ME + E), false, "sight goes through")
	var me := w.player()
	var hp := me.hp
	var before := w.clone()
	events = w.act({t = &"move", dir = E})
	assert_eq(me.hp, hp - Compounds.THORN, "a step onto thorns pricks")
	assert_has(_lines(before, w, events), "가시에 찔려 피해를 %d 입었다" % Compounds.THORN)
	assert_false(Travel.walkable(w, ME + Vector2i(1, 1)), "a walk goes round thorns")


func test_mud_slows_every_step_and_silences_it() -> void:
	var w := _world()
	w.act(_cast([EARTH, WATER]))
	for d in Grid.DIRS + [Vector2i.ZERO]:
		assert_eq(w.tile(ME + E * 2 + d), World.MUD, str(d))
	var heavy := FloorGen.spawn(w, &"bulgasari", ME + E * 4)
	assert_gt(heavy.info().step, 0)
	w.events = []
	w.move(heavy, ME + E * 3)
	assert_true(_of(w.events, &"noise").is_empty(), "no footstep on mud")
	w.events = []
	w.move(heavy, ME + E * 4)
	assert_false(_of(w.events, &"noise").is_empty(), "but off it")
	heavy.hp = 0
	w.player().pos = ME + E
	w.act({t = &"move", dir = E})
	assert_eq(w.player().pos, ME + E * 2)
	assert_false(w.can({t = &"move", dir = E}), "stuck for the next round")
	w.act(WAIT)
	assert_true(w.can({t = &"move", dir = E}), "free after %d rounds" % Compounds.MUD)


func test_split_on_an_orb_fells_the_wall_it_strikes_and_its_neighbours() -> void:
	var w := _world()
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(ME.x + 3, y), World.WALL)
	w.act(_cast([ORB, WOOD, EARTH]))
	for y in [-1, 0, 1]:
		assert_eq(w.tile(ME + Vector2i(3, y)), World.RUBBLE, str(y))
	assert_eq(w.tile(ME + Vector2i(3, 2)), World.WALL)


func test_every_compound_carried_on_an_orb_acts_on_the_3x3_where_it_strikes() -> void:
	for c: StringName in Cards.PAIRS:
		if c == &"split":
			continue
		var w := _world()
		var foe := _post(w, ME + E * 3)
		foe.max_hp = 9
		foe.hp = 9
		var side := _post(w, ME + Vector2i(4, 1))
		var events := w.act(_cast([ORB] + Cards.PAIRS[c]))
		var at := foe.pos
		match c:
			&"wildfire":
				assert_eq([foe.alight, side.alight], [Status.ALIGHT - 1, Status.ALIGHT - 1], c)
			&"lava", &"molten":
				assert_true(w.hot.has(at) and w.hot.has(at + Vector2i(1, -1)), c)
			&"shrapnel":
				assert_eq(_harm(events, side.id), Compounds.SHRAPNEL, c)
				assert_eq(_harm(events, foe.id), 1 + Compounds.SHRAPNEL, "orb and shrapnel")
			&"frost":
				assert_eq([foe.rooted, side.rooted], [Compounds.FROST - 1, Compounds.FROST - 1])
			&"rain":
				assert_eq([foe.rooted, side.rooted], [Compounds.RAIN - 1, Compounds.RAIN - 1])
			&"steam":
				assert_eq(Gas.at(w, at).x, Gas.STEAM, c)
			&"thorn":
				assert_eq([w.tile(at), w.tile(side.pos)], [World.THORNS, World.THORNS])
				assert_eq(_harm(events, side.id), Compounds.THORN)
			&"mud":
				assert_eq([w.tile(at), w.tile(at + Vector2i(-1, 1))], [World.MUD, World.MUD])


func test_a_wisp_carries_steam_and_more_copies_reach_farther() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	w.act(_cast([FOX, WATER, FIRE]))
	assert_eq(Gas.at(w, foe.pos).x, Gas.STEAM, "where the wisp struck")
	assert_eq(Spray.cover(w, w.player(), Spell.make([WATER, FIRE, WATER, FIRE]), E).size(), 25)
	for copies in [1, 2]:
		w = _world()
		var struck := _post(w, ME + E * 3)
		var corner := _post(w, ME + Vector2i(5, 2))
		w.act(_cast([ORB] + [METAL, WATER, METAL, WATER].slice(0, 2 * copies)))
		assert_eq(struck.rooted, Compounds.FROST - 1)
		assert_eq(corner.rooted, Compounds.FROST - 1 if copies == 2 else 0, "5x5 for two")


func test_a_carried_compound_preview_equals_the_round() -> void:
	for c: StringName in Cards.PAIRS:
		for form in [FOX, ORB]:
			var w := _world()
			_post(w, ME + E * 3)
			_post(w, ME + Vector2i(4, 1))
			_put(w, ME + Vector2i(2, -1), World.POND)
			_put(w, ME + Vector2i(4, 0), World.WALL)
			w.sense()
			var q: Array = [form] + Cards.PAIRS[c]
			var f := Forecast.of(w, _cast(q))
			var events := w.act(_cast(q))
			var harm := {}
			for e in _of(events, &"hurt"):
				harm[e.id] = harm.get(e.id, 0) + e.n
			assert_eq(f.harm, harm, str(q))
			assert_eq(f.after.tiles, w.tiles, str(q))
			assert_eq(
				[f.after.hot, f.after.gas, f.after.burning], [w.hot, w.gas, w.burning], str(q)
			)
			for a in w.actors:
				assert_eq(f.after.actor(a.id).rooted, a.rooted, str(q))


func test_the_forecast_shows_the_ground_a_compound_changes() -> void:
	var w := _world()
	var f := Forecast.of(w, _cast([EARTH, WATER]))
	assert_eq(f.grounds.size(), 9)
	assert_eq(f.grounds[ME + E * 2], World.MUD)
	f = Forecast.of(w, _cast([FIRE, EARTH]))
	assert_eq(f.heated, [ME + E, ME + E * 2, ME + E * 3, ME + E * 4] as Array[Vector2i])


func test_the_log_tells_what_each_compound_leaves() -> void:
	var rows := {
		[METAL, WATER]: "%s 얼어붙었다",
		[EARTH, WATER]: "진흙이 생겼다",
		[METAL, WOOD]: "가시덤불이 생겼다",
		[FIRE, EARTH]: "%s이 남았다" % Compounds.HOT[Compounds.LAVA].name,
		[FIRE, METAL]: "%s가 남았다" % Compounds.HOT[Compounds.MOLTEN].name,
	}
	for q: Array in rows:
		var w := _world()
		var foe := _post(w, ME + E * 2)
		var before := w.clone()
		var events := w.act(_cast(q))
		var line: String = rows[q]
		if line.contains("%s"):
			line = line % (foe.info().name + "이")
		assert_has(_lines(before, w, events), line, str(q))
	var w := _world()
	_put(w, ME + E, World.POND)
	var before := w.clone()
	var events := w.act(_cast([METAL, WATER]))
	assert_has(_lines(before, w, events), "얼음이 생겼다")
	w = _world()
	var foe := _post(w, ME + E * 2)
	foe.max_hp = 9
	foe.hp = 9
	w.act(_cast([FIRE, EARTH]))
	before = w.clone()
	events = w.act(WAIT)
	var hot: String = Compounds.HOT[Compounds.LAVA].name
	assert_has(_lines(before, w, events), "%s이 %s에 데어 피해를 1 입었다" % [foe.info().name, hot])
	before = w.clone()
	assert_has(_lines(before, w, w.act(WAIT)), "%s이 식었다" % hot)


func test_hover_tells_the_new_ground_from_the_rules() -> void:
	var w := _world()
	_put(w, ME + E, World.THORNS)
	_put(w, ME + E * 2, World.MUD)
	w.hot[ME + Vector2i(0, 1)] = Vector2i(Compounds.MOLTEN, 2)
	w.sense()
	assert_string_contains(Info.plain(Info.at(w, ME + E)), "피해: 지날 때 %d" % Compounds.THORN)
	assert_string_contains(Info.plain(Info.at(w, ME + E)), "\n가연성.")
	assert_string_contains(Info.plain(Info.at(w, ME + E * 2)), "걸음: %d초" % Compounds.MUD)
	var hot := Info.plain(Info.at(w, ME + Vector2i(0, 1)))
	var spec: Dictionary = Compounds.HOT[Compounds.MOLTEN]
	assert_string_contains(hot, "%s: 2초 남음" % spec.name)
	assert_string_contains(hot, "피해: 매 초 %d" % spec.harm)
	w.player().pos = ME + Vector2i(0, 1)
	var me := Info.plain(Info.creature(w, w.player()))
	assert_string_contains(me, "%s 위: 2초. 피해: 매 초 %d" % [spec.name, spec.harm])


func test_the_map_text_draws_hot_ground() -> void:
	var w := _world()
	w.hot[ME + E] = Vector2i(Compounds.LAVA, 2)
	assert_string_contains(Observation.text(w), Palette.HOT[0])
