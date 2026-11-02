extends GutTest
## 3단, 4단 and 5단 compounds, and the join rule that makes them: every order
## of three, four and five different elements, each spell's effect, sprayed and
## carried, and its preview.

const FOX := Cards.FOX
const ORB := Cards.ORB
const FIRE := Cards.FIRE
const WATER := Cards.WATER
const WOOD := Cards.WOOD
const METAL := Cards.METAL
const EARTH := Cards.EARTH
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)
const SE := Vector2i(1, 1)
const ME := Vector2i(20, 12)
## The 4단 and 5단 spells.
const HIGH := [
	&"beacon",
	&"magpie",
	&"mist",
	&"sinkhole",
	&"newmoon",
	&"discord",
	&"thunder",
	&"stillness",
	Cards.SAMSARA,
	Cards.CONQUEST,
	Cards.DRAGON,
]
## The four 3단 spells that are no leap, and go on no one.
const NEW := [&"furnace", &"swamp", &"hypnosis", &"palisade"]


## An open hall walled at the edges, lit by lanterns two rows above Miho, who
## stands at ME with plenty of tails.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(2, Grid.W - 2, 3):
		w.tiles[Grid.index(Vector2i(x, ME.y - 2))] = World.LANTERN
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = 5
	w.tails = 9
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts, with health to spare.
func _post(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", at)
	a.cooldown = 99
	a.max_hp = 9
	a.hp = 9
	return a


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


func _harm(events: Array, id: int) -> int:
	var n := 0
	for e in _of(events, &"hurt"):
		if e.id == id:
			n += e.n
	return n


## The tiles a spell laid steam on, before it spread.
func _steam(events: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_of(events, &"gas").map(func(e): return e.at))
	return out


## The first harm `id` takes in the round: the spell's, before hot ground and gas.
func _first(events: Array, id: int) -> int:
	return _of(events, &"hurt").filter(func(e): return e.id == id)[0].n


func _made(c: StringName) -> Array:
	return Cards.recipe(c)


## What the cards join into, with no tier in the way.
func _fold(cards: Array) -> StringName:
	var slot: StringName = cards[0]
	for card: StringName in cards.slice(1):
		slot = Cards.join(slot, card, 5)
	return slot


func _orders(of: Array) -> Array:
	if of.size() <= 1:
		return [of]
	var out := []
	for i in of.size():
		var rest := of.duplicate()
		rest.remove_at(i)
		for tail: Array in _orders(rest):
			out.append([of[i]] + tail)
	return out


func _same_set(a: Array, b: Array) -> bool:
	return a.size() == b.size() and a.all(func(e): return b.has(e))


func test_an_order_of_three_different_elements_makes_the_3dan_of_that_set_if_it_has_one() -> void:
	var seen := {}
	for i in Cards.ELEMENTS.size():
		for j in range(i + 1, Cards.ELEMENTS.size()):
			for k in range(j + 1, Cards.ELEMENTS.size()):
				var picked := [Cards.ELEMENTS[i], Cards.ELEMENTS[j], Cards.ELEMENTS[k]]
				var named := Cards.TRIPLES.keys().filter(
					func(c): return _same_set(Cards.made_of(c), picked)
				)
				for order: Array in _orders(picked):
					var s := Spell.make(order)
					if named.is_empty():
						assert_gt(s.slots.size(), 1, "no spell of this set: %s" % [order])
						continue
					assert_eq(s.slots.size(), 1, str(order))
					assert_eq(s.slots[0], named[0], str(order))
					seen[s.slots[0]] = true
	assert_eq(seen.size(), Cards.TRIPLES.size(), "every 3단 is made")


func test_every_table_chain_runs_along_one_ring_and_has_a_name_and_a_glyph() -> void:
	var glyphs := {}
	for table: Dictionary in [Cards.TRIPLES, Cards.QUADS]:
		for c: StringName in table:
			var chain: Array = table[c]
			var ring: Dictionary = Cards.GROWS if Cards.GROWS[chain[0]] == chain[1] else Cards.BEATS
			for i in chain.size() - 1:
				assert_eq(ring[chain[i]], chain[i + 1], c)
			assert_true(Cards.NAME.has(c) and Cards.GLYPH.has(c), c)
	for c in Cards.NAME:
		assert_false(glyphs.has(Cards.GLYPH[c]), "one glyph each: " + Cards.GLYPH[c])
		glyphs[Cards.GLYPH[c]] = true
	assert_eq(Cards.TRIPLES.size(), 6)
	assert_eq(Cards.QUADS.size(), 8)
	assert_eq(Cards.FIVES.size(), 3)


func test_the_four_cards_of_a_copy_make_it_in_every_order_for_5_tails() -> void:
	var cards := [Cards.FOX, Cards.EARTH, Cards.FIRE, Cards.WOOD]
	var orders := _orders(cards)
	assert_eq(orders.size(), 24)
	for order: Array in orders:
		var s := Spell.make(order)
		assert_eq(s.slots, [Cards.BUNSIN] as Array[StringName], str(order))
		assert_eq(s.cost(), 5, str(order))
		assert_eq(Spell.from_key(s.key()).slots, s.slots, str(order))
	assert_true(_same_set(Cards.recipe(Cards.BUNSIN), cards))
	assert_eq(Spell.fill(Cards.recipe(Cards.BUNSIN)), [Cards.BUNSIN] as Array[StringName])


func test_other_cards_beside_the_four_of_a_copy_follow_the_usual_rules() -> void:
	var cards := [Cards.FOX, Cards.EARTH, Cards.FIRE, Cards.WOOD]
	assert_gt(Spell.make([EARTH, WATER, FIRE]).slots.size(), 1, "토 수 화 is no spell now")
	assert_gt(Spell.make([WOOD, FIRE, EARTH]).slots.size(), 1, "without 여 it is no spell")
	assert_false(Spell.make([Cards.FOX] + cards).has(Cards.BUNSIN), "a second 여")
	for e: StringName in Cards.ELEMENTS:
		assert_eq(Cards.join(Cards.BUNSIN, e, 5), &"", "it takes no element in")
		var beside := Spell.make(cards + [e])
		assert_eq(
			beside.slots, [Cards.BUNSIN, e] as Array[StringName], "a fifth card is its own slot"
		)
		assert_true(Guise.mixed(beside), "and a copy goes alone")
	assert_eq(Spell.make(Cards.recipe(&"beacon")).slots, [&"beacon"] as Array[StringName])
	assert_eq(Spell.make(Cards.recipe(&"mist")).slots, [&"mist"] as Array[StringName])


func test_a_3dan_and_a_missing_element_make_the_4dan_of_its_ring() -> void:
	assert_eq(Cards.join(&"furnace", WOOD, 5), &"beacon", "화토금 상생 + 목: 목화토금")
	assert_eq(Cards.join(Cards.VAULT, EARTH, 5), &"mist", "수목화 상생 + 토: 수목화토")
	assert_eq(Cards.join(&"swamp", FIRE, 5), &"sinkhole", "목토수 상극 + 화")
	assert_eq(Cards.join(&"swamp", METAL, 5), &"stillness", "목토수 상극 + 금: 금목토수")
	for t: StringName in Cards.TRIPLES:
		var grows: bool = Cards.GROWS[_made(t)[0]] == _made(t)[1]
		for e: StringName in Cards.ELEMENTS:
			var q := Cards.join(t, e, 5)
			if _made(t).has(e) or [t, e] == [&"furnace", WATER]:
				assert_eq(q, &"", "%s + %s has no spell" % [t, e])
				continue
			assert_true(Cards.QUADS.has(q), "%s + %s" % [t, e])
			assert_true(_same_set(Cards.QUADS[q], _made(t) + [e]), "%s + %s" % [t, e])
			var chain: Array = Cards.QUADS[q]
			assert_eq(Cards.GROWS[chain[0]] == chain[1], grows, "%s + %s" % [t, e])


func test_a_4dan_and_the_last_element_make_a_5dan() -> void:
	for q: StringName in Cards.QUADS:
		var chain: Array = Cards.QUADS[q]
		var last: StringName = Cards.ELEMENTS.filter(func(e): return not chain.has(e))[0]
		var grows: bool = Cards.GROWS[chain[0]] == chain[1]
		var want := Cards.SAMSARA if grows else Cards.CONQUEST
		assert_eq(Cards.join(q, last, 5), Cards.DRAGON if last == EARTH else want, q)
		assert_eq(Cards.join(q, chain[0], 5), &"", "a held element joins nothing")
	assert_eq(Cards.join(Cards.DRAGON, EARTH, 5), &"")


func test_every_compound_s_elements_join_back_into_it_in_some_order() -> void:
	for table: Dictionary in [Cards.PAIRS, Cards.TRIPLES, Cards.QUADS, Cards.FIVES]:
		for c: StringName in table:
			assert_true(_orders(Cards.made_of(c)).any(func(o): return _fold(o) == c), c)


func test_a_3dan_is_one_slot_worth_three_tails_that_holds_its_elements() -> void:
	for c: StringName in NEW:
		var s := Spell.make(_made(c))
		assert_eq(s.slots, [c] as Array[StringName])
		assert_eq(s.shape, Spell.SPRAY)
		assert_eq(s.cost(), 3, c)
		assert_eq(s.compounds(), [c] as Array[StringName])
		assert_eq(s.title(), Cards.NAME[c])
		for e: StringName in Cards.ELEMENTS:
			assert_eq(s.holds(e), _made(c).has(e), "%s holds %s" % [c, e])
			assert_false(s.has(e), "a compound is its own element")
	var leap := Spell.make(_made(Cards.VAULT))
	assert_true(leap.compounds().is_empty(), "도약 is a shape")
	assert_false(leap.holds(FIRE), "도약 carries nothing")


func test_a_doubled_3dan_grows_a_tile_and_costs_six_cards() -> void:
	var w := _world()
	var twice := Spell.make(_made(&"swamp") + _made(&"swamp"))
	assert_eq(twice.slots, [&"swamp", &"swamp"] as Array[StringName])
	assert_eq(twice.cost(), Spell.price(6))
	assert_eq(Spray.cover(w, w.player(), twice, E), Spray.square(w, ME + E * 3, 3, true))
	var fence := Spell.make(_made(&"palisade") + _made(&"palisade"))
	assert_eq(Spray.cover(w, w.player(), fence, E).size(), 4)
	var line := Spell.make(_made(&"hypnosis") + _made(&"hypnosis"))
	assert_eq(Spray.cover(w, w.player(), line, E).size(), 6)


func test_each_3dan_has_the_shape_of_the_plan() -> void:
	var w := _world()
	var cover := func(c: StringName, dir := E) -> Array[Vector2i]:
		return Spray.cover(w, w.player(), Spell.make(_made(c)), dir)
	assert_eq(cover.call(&"swamp"), Spray.square(w, ME + E * 3, 2, true))
	assert_eq(cover.call(&"furnace"), Spray.line(w, ME, E, 6, false))
	assert_eq(cover.call(&"hypnosis"), Spray.line(w, ME, E, 5, false))
	assert_eq(
		cover.call(&"palisade"),
		[ME + E * 2, ME + Vector2i(2, 1), ME + Vector2i(2, -1)] as Array[Vector2i]
	)


func test_a_burst_of_radius_two_does_not_pass_a_wall() -> void:
	var w := _world()
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(ME.x + 4, y), World.WALL)
	var behind := _post(w, ME + E * 5)
	var rain := Cards.PAIRS[&"rain"] + Cards.PAIRS[&"rain"]
	var tiles := Spray.cover(w, w.player(), Spell.make(rain), E)
	assert_false(tiles.has(behind.pos), "the wall shields it")
	assert_eq(tiles.size(), 15, "the three columns on Miho's side")
	w.act(_cast(rain))
	assert_eq(behind.rooted, 0)


func test_furnace_leaves_hot_iron_and_fells_the_wall_at_its_end() -> void:
	var w := _world()
	_put(w, ME + E * 4, World.WALL)
	_put(w, ME + E * 5, World.WALL)
	w.act(_cast(_made(&"furnace")))
	assert_eq(w.hot.get(ME + E * 3).x, Compounds.MOLTEN)
	assert_eq(w.tile(ME + E * 4), World.RUBBLE, "the wall it ran into")
	assert_eq(w.tile(ME + E * 5), World.WALL, "one wall only")
	w = _world()
	_put(w, ME + E, World.WALL)
	w.act(_cast(_made(&"furnace")))
	assert_eq(w.tile(ME + E), World.RUBBLE, "right next to Miho")
	w = _world()
	_put(w, ME + E * 7, World.WALL)
	w.act(_cast(_made(&"furnace")))
	assert_eq(w.tile(ME + E * 7), World.WALL, "past the end of the line")
	w = _world()
	var foe := _post(w, ME + E * 2)
	_put(w, ME + E * 3, World.WALL)
	w.act(_cast(_made(&"furnace")))
	assert_eq(w.tile(ME + E * 3), World.WALL, "the creature stopped the line")
	assert_true(w.hot.has(foe.pos))
	w = _world()
	w.tiles[Grid.index(Vector2i(0, ME.y))] = World.WALL
	w.player().pos = Vector2i(1, ME.y)
	w.sense()
	w.act(_cast(_made(&"furnace"), W))
	assert_eq(w.tile(Vector2i(0, ME.y)), World.WALL, "the map's edge stands")


func test_swamp_fells_walls_quietly_and_lays_mud() -> void:
	var w := _world()
	for x in [ME.x + 3, ME.x + 4, ME.x + 5]:
		for y in range(1, Grid.H - 1):
			_put(w, Vector2i(x, y), World.WALL)
	var foe := _post(w, ME + E)
	foe.pos = ME + Vector2i(1, 2)
	w._changed()
	w.sense()
	var events := w.act(_cast(_made(&"swamp")))
	var at := ME + E * 2
	assert_eq(w.tile(at + E), World.MUD, "the first wall")
	assert_eq(w.tile(at + E * 2), World.MUD, "the second wall")
	assert_eq(w.tile(at + E * 3), World.WALL, "past the radius")
	assert_eq(w.tile(at), World.MUD)
	assert_eq(foe.rooted, Compounds.SWAMP - 1)
	assert_true(_of(events, &"noise").is_empty(), "silent")


func test_palisade_grows_a_wooden_wall_across_the_line_on_open_ground() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 1))
	_put(w, ME + Vector2i(2, -1), World.POND)
	var events := w.act(_cast(_made(&"palisade")))
	assert_eq(w.tile(ME + E * 2), World.WOOD_WALL)
	assert_eq(w.tile(foe.pos), World.FLOOR, "not under a creature")
	assert_eq(w.tile(ME + Vector2i(2, -1)), World.POND, "not on water")
	assert_true(_of(events, &"hit").is_empty(), "a wall strikes no one")
	assert_eq(_of(events, &"sprout").size(), 1)
	w = _world()
	w.act(_cast(_made(&"palisade"), SE))
	var at := ME + SE * 2
	for p in Elements.across(at, SE, Elements.WALL):
		assert_eq(w.tile(p), World.WOOD_WALL, str(p))
	w = _world()
	w.stairs = ME + E * 2
	w.act(_cast(_made(&"palisade")))
	assert_eq(w.tile(ME + E * 2), World.FLOOR, "not on the stairs")


func test_each_3dan_carried_on_a_projectile_acts_on_the_3x3_where_it_ends() -> void:
	for form in [FOX, ORB]:
		for c: StringName in NEW:
			var w := _world()
			var foe := _post(w, ME + E * 3)
			var side := _post(w, ME + Vector2i(4, 1))
			var at := foe.pos
			var q: Array = [form] + _made(c)
			var events := w.act(_cast(q))
			var label := str(q)
			match c:
				&"furnace":
					assert_eq(w.hot.get(at + Vector2i(1, -1)).x, Compounds.MOLTEN, label)
				&"swamp":
					assert_eq(w.tile(side.pos), World.MUD, label)
					assert_eq(side.rooted, Compounds.SWAMP - 1, label)
				&"palisade":
					assert_eq(w.tile(at + Vector2i(-1, -1)), World.WOOD_WALL, label)
					assert_eq(w.tile(at), World.FLOOR, "the struck creature's tile")
					assert_eq(w.tile(side.pos), World.FLOOR, label)


func test_a_wisp_that_stops_at_a_wall_still_knows_its_line() -> void:
	for cards: Array in [_made(&"furnace"), [WOOD, EARTH]]:
		var w := _world()
		_put(w, ME + E * 2, World.WALL)
		w.act(_cast([FOX] + cards))
		assert_eq(w.tile(ME + E * 2), World.RUBBLE, "the wall ahead of it: %s" % [cards])
		assert_eq(w.shots[0].dir, Vector2i.ZERO, "it hovers")


func test_a_compound_preview_equals_the_round() -> void:
	_preview_equals_round([], NEW)


func test_a_high_compound_preview_equals_the_round() -> void:
	_preview_equals_round([], HIGH)


func test_a_fox_compound_preview_equals_the_round() -> void:
	_preview_equals_round([FOX], NEW)


func test_a_high_fox_compound_preview_equals_the_round() -> void:
	_preview_equals_round([FOX], HIGH)


func test_an_orb_compound_preview_equals_the_round() -> void:
	_preview_equals_round([ORB], NEW)


func test_a_high_orb_compound_preview_equals_the_round() -> void:
	_preview_equals_round([ORB], HIGH)


func _preview_equals_round(form: Array, compounds: Array) -> void:
	for c: StringName in compounds:
		for dir: Vector2i in [E, W, SE]:
			var w := _world()
			for x in range(2, Grid.W - 2, 3):
				_put(w, Vector2i(x, ME.y + 3), World.LANTERN)
			_post(w, ME + dir * 2)
			var wet := _post(w, ME + dir * 2 + Vector2i(-dir.y, dir.x))
			wet.wet = Status.WET
			w.player().hp = 1
			_put(w, ME + dir * 2 + Vector2i(0, -1), World.POND)
			_put(w, ME + dir * 4, World.WALL)
			w.sense()
			var q: Array = form + _made(c)
			var f := Forecast.of(w, _cast(q, dir))
			var events := w.act(_cast(q, dir))
			var label := "%s %s" % [q, dir]
			var harm := {}
			for e in _of(events, &"hurt"):
				harm[e.id] = harm.get(e.id, 0) + e.n
			assert_eq(f.harm, harm, label)
			assert_eq(f.after.tiles, w.tiles, label)
			assert_eq([f.after.hot, f.after.gas, f.after.burning], [w.hot, w.gas, w.burning], label)
			for a in w.actors:
				var other := f.after.actor(a.id)
				assert_eq(
					[other.pos, other.rooted, other.frozen, other.alight, other.wet],
					[a.pos, a.rooted, a.frozen, a.alight, a.wet],
					label
				)
				assert_eq(
					[other.hp, other.stunned, other.alert, other.rival, other.grudge],
					[a.hp, a.stunned, a.alert, a.rival, a.grudge],
					label
				)


func test_each_3dan_tells_its_numbers_in_name_value_lines() -> void:
	var rows := {
		&"furnace": ["용광로 · 꼬리: 3", "모양: 곧게 6칸", "뜨거운 쇠: %d초" % Compounds.HOT_ROUNDS, "무너짐: 끝 벽"],
		&"swamp":
		[
			"늪 · 꼬리: 3",
			"모양: 3칸 앞 5×5",
			"무너짐: 벽",
			"땅: 진흙",
			"묶임: %d초" % Compounds.SWAMP,
			"소음: 없음",
		],
		&"hypnosis": ["최면 · 꼬리: 3", "모양: 곧게 5칸"],
		&"palisade":
		["목책 · 꼬리: 3", "모양: 2칸 앞에서 직각으로 3칸", "나무벽 체력: %d" % Tiles.of(World.WOOD_WALL, "health")],
	}
	assert_eq(rows.size(), NEW.size())
	for c: StringName in rows:
		var text := Info.plain(SpellInfo.combo(c))
		for part: String in rows[c]:
			assert_string_contains(text, part)
		for line in text.split("\n").slice(1):
			assert_string_contains(line, ": ", "name and value: " + line)
			assert_false(line.ends_with("다"), "no sentences: " + line)
	var carried := Info.plain(SpellInfo.spell(Spell.make([ORB] + _made(&"swamp"))))
	assert_string_contains(carried, "늪: 멈춘 곳 3×3")
	assert_string_contains(carried, "묶임: %d초" % Compounds.SWAMP)


func test_a_self_cast_goes_only_to_the_spells_that_change_her() -> void:
	assert_eq(Guise.kind(Spell.make([WOOD, EARTH])), &"", "two cards are no buff")
	assert_eq(Guise.kind(Spell.make([WOOD, EARTH, WOOD])), Guise.GUISE)
	assert_eq(Guise.kind(Spell.make([FOX, WATER, WOOD])), Guise.SHADOW)
	assert_eq(Guise.kind(Spell.make(_made(Guise.TALON))), Guise.TALON)
	assert_eq(Guise.kind(Spell.make([FOX, WOOD, EARTH])), Guise.CLOAK)
	assert_eq(
		Guise.kind(Spell.make([FOX] + _made(Guise.TALON))), &"", "carried, it is no self-cast"
	)
	for c: StringName in NEW:
		assert_eq(Guise.kind(Spell.make(_made(c))), &"", c)


func test_no_creature_but_the_reaper_casts_a_3dan_besides_the_leap() -> void:
	for kind: StringName in Bestiary.KINDS:
		var spec := Bestiary.info(kind)
		if spec.has("mana"):
			continue
		var casts: Array = spec.get("casts", []).duplicate()
		for rank: int in spec.get("ranks", {}):
			casts.append_array(spec.ranks[rank])
		for cards: Array in casts.filter(func(c): return c != Bestiary.LEAP):
			for slot in Spell.make(cards).slots:
				assert_lt(Cards.made_of(slot).size(), 3, "%s casts %s" % [kind, cards])
