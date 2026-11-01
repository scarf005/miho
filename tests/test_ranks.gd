extends GutTest
## Ranks of storeys (Bestiary.rank): two storeys each. A creature of a deeper rank
## has more health and more spells, picks the one that suits from the third rank
## and charges two at once from the fourth; the first rank keeps every creature
## as it was.

const FOX := Cards.FOX
const ORB := Cards.ORB
const WAIT := {t = &"wait"}
const ME := Vector2i(10, 8)
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)
## The first storey of each rank.
const FIRST := [1, 3, 5, 7, 9]


## An open hall, Miho at ME by a lantern, on storey `depth`.
func _world(depth: int) -> World:
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


## A creature of `kind` at `at` hunting Miho, ready to cast, its next spell `next`.
func _hunter(w: World, kind: StringName, at: Vector2i, next := 0) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.alert = Actor.HUNT
	a.target = ME
	a.casts = next
	w.sense()
	return a


func _of(events: Array, t: StringName, id: int) -> Array:
	return events.filter(func(e): return e.t == t and e.id == id)


## The elements the spells hold, in 오행 order.
func _elements(casts: Array) -> Array:
	return Cards.ELEMENTS.filter(func(c): return casts.any(func(cast): return cast.has(c)))


func test_a_rank_spans_two_storeys() -> void:
	var by_depth := {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4, 8: 4, 9: 5}
	for depth in by_depth:
		assert_eq(Bestiary.rank(depth), by_depth[depth], "storey %d" % depth)


func test_the_first_rank_keeps_every_kind_as_it_was() -> void:
	for kind in Codex.foes():
		var a := FloorGen.spawn(_world(2), kind, Vector2i(20, 8))
		var spec := Bestiary.info(kind)
		assert_eq(a.rank, 1, kind)
		assert_eq([a.hp, a.max_hp], [spec.hp, spec.hp], kind)
		assert_eq(a.repertoire(), spec.get("casts", []), kind)


func test_health_grows_with_the_rank() -> void:
	var hp := []
	for depth in FIRST:
		hp.append(FloorGen.spawn(_world(depth), &"dokkaebi", Vector2i(20, 8)).max_hp)
	assert_eq(hp, [2, 3, 5, 7, 8])
	assert_eq(FloorGen.spawn(_world(9), &"cheonnyeon", Vector2i(20, 8)).hp, 14)
	assert_eq(FloorGen.spawn(_world(9), &"saja", Vector2i(20, 8)).hp, 18)


func test_no_rank_gives_a_kind_another_element() -> void:
	for kind in Codex.foes():
		var first := _elements(Bestiary.casts(kind, 1))
		for r in range(2, Bestiary.RANKS + 1):
			assert_eq(_elements(Bestiary.casts(kind, r)), first, "%s rank %d" % [kind, r])
	assert_eq(Bestiary.elements(&"dokkaebi"), [] as Array[StringName], "잡몹 stays plain")


func test_a_caster_has_more_spells_deeper() -> void:
	for kind in Codex.foes():
		var last := 0
		for r in range(1, Bestiary.RANKS + 1):
			var casts := Bestiary.casts(kind, r)
			assert_true(casts.size() >= last, "%s rank %d" % [kind, r])
			last = casts.size()
			for cast: Array in casts:
				var s := Spell.make(cast)
				assert_not_null(s, "%s %s" % [kind, cast])
	for kind in [&"dokkaebi", &"jangseung", &"imugi", &"haetae", &"bujigaengi"]:
		assert_gt(Bestiary.casts(kind, Bestiary.RANKS).size(), Bestiary.casts(kind, 1).size())


func test_below_the_third_rank_it_tries_only_its_next_spell() -> void:
	var off_line := ME + Vector2i(4, 2)
	var low := _world(3)
	var guard := _hunter(low, &"haetae", off_line)
	assert_eq(Aim.at(low, guard, low.player()), [] as Array[Dictionary], "no line for its orb")
	var deep := _world(5)
	var picker := _hunter(deep, &"haetae", off_line)
	var plans := Aim.at(deep, picker, deep.player())
	assert_eq(plans.size(), 1)
	assert_true(Spell.make(plans[0].cards).homing(), "its homing orb goes round")


func test_it_passes_over_what_its_rival_absorbs_and_takes_what_it_is_weak_to() -> void:
	var w := _world(9)
	var boss := _hunter(w, &"cheonnyeon", Vector2i(20, 8), 1)
	var dog := FloorGen.spawn(w, &"bulgae", Vector2i(16, 8))
	w.sense()
	var plans := Aim.at(w, boss, dog)
	assert_eq(plans.size(), 2)
	for plan in plans:
		var s := Spell.make(plan.cards)
		assert_false(s.holds(Cards.FIRE), s.title())
	assert_true(Bestiary.weak(&"bulgae", Spell.make(plans[0].cards)))


func test_from_the_fourth_rank_it_charges_two_spells_and_casts_both() -> void:
	var w := _world(7)
	var post := _hunter(w, &"jangseung", ME + E * 4)
	var events := w.act(WAIT)
	assert_eq(_of(events, &"charge", post.id).size(), 2)
	assert_eq(post.intent.size(), 2)
	events = w.act(WAIT)
	assert_eq(_of(events, &"cast", post.id).size(), 2)
	assert_eq(post.intent, [] as Array[Dictionary])
	var third := _world(5)
	var one := _hunter(third, &"jangseung", ME + E * 4)
	assert_eq(_of(third.act(WAIT), &"charge", one.id).size(), 1)


func test_the_forecast_shows_both_spells_of_a_double_charge() -> void:
	var w := _world(7)
	var post := _hunter(w, &"jangseung", ME + E * 2)
	w.act(WAIT)
	var cast := Forecast.of(w, WAIT)
	assert_eq(_of(cast.events, &"cast", post.id).size(), 2)
	var cast_round := w.act(WAIT)
	assert_false(cast_round.any(func(e): return e.t in [&"clash", &"snuff"]), "they leave apart")
	var f := Forecast.of(w, WAIT)
	var harm := 0
	for e in w.act(WAIT):
		if e.t == &"hurt" and e.id == w.player().id:
			harm += e.n
	assert_gt(harm, 0)
	assert_eq(f.harm.get(w.player().id, 0), harm)


func test_a_water_jet_from_heaven_pushes_miho_back() -> void:
	var w := _world(3)
	var guard := _hunter(w, &"haetae", ME + E * 3, 1)
	w.act(WAIT)
	assert_eq(guard.intent.size(), 1)
	assert_eq(Spell.make(guard.intent[0].cards).shape, Spell.SPRAY)
	w.act(WAIT)
	assert_eq(w.player().pos, ME + W)


func test_roots_from_heaven_hold_miho() -> void:
	var w := _world(4)
	_hunter(w, &"cheonha", ME + E * 3, 1)
	w.act(WAIT)
	w.act(WAIT)
	assert_gt(w.player().rooted, 0)


func test_the_great_serpent_freezes_miho() -> void:
	var w := _world(9)
	var boss := _hunter(w, &"cheonnyeon", ME + E * 3, 2)
	var events := w.act(WAIT)
	for i in 2:
		events += w.act(WAIT)
	assert_true(events.any(func(e): return e.t == &"freeze" and e.id == w.player().id))
	assert_eq(_of(events, &"cast", boss.id).size(), 2, "with a second spell")


func test_hover_and_codex_tell_the_spells_and_health_of_its_rank() -> void:
	var w := _world(7)
	var guard := _hunter(w, &"haetae", ME + E * 3)
	w.act(WAIT)
	var text := Info.plain(Info.creature(w, guard))
	assert_string_contains(text, "물줄기")
	assert_string_contains(text, "동시 주술: 2개")
	assert_eq(text.count("모으는 중."), 2)
	var shallow := _world(1)
	var low := Info.plain(Info.creature(shallow, _hunter(shallow, &"haetae", ME + E * 3)))
	assert_false(low.contains("물줄기"))
	assert_false(low.contains("동시 주술"))
	var entry := Codex.foe(&"haetae", 4)
	assert_eq(entry.max_hp, 9)
	assert_string_contains(Info.plain(Info.creature_facts(entry, [])), "물줄기")
	assert_false(Info.plain(Info.creature_facts(Codex.foe(&"haetae"), [])).contains("물줄기"))


func test_hover_tells_its_homing_orbs_apart_by_their_turn() -> void:
	var text := Info.plain(Info.creature_facts(Codex.foe(&"jangseung", 3), []))
	assert_string_contains(text, "꺾임: 한 칸에 45°")
	assert_string_contains(text, "꺾임: 한 칸에 90°")
	var plain := Info.plain(Info.creature_facts(Codex.foe(&"jangseung"), []))
	assert_false(plain.contains("꺾임"), "a straight orb does not turn")
