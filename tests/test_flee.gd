extends GutTest
## A sharp or cunning creature at 1 health that hunts Miho runs from her, towards
## its own group. Brave kinds and creatures that cannot walk never flee, and one
## with nowhere to go fights.

const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)


## An open hall, every tile known and seen, Miho at ME; a lantern beside her
## lights it unless `lit` is false.
func _hall(lit := true) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 4
	w.tails = 4
	if lit:
		w.tiles[Grid.index(ME + Vector2i(0, -1))] = World.LANTERN
	return w


## A creature at `hp` that hunts Miho.
func _hunter(w: World, kind: StringName, at: Vector2i, hp := 1) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.hp = hp
	a.alert = Actor.HUNT
	a.target = ME
	a.cooldown = 99
	return a


func test_bravery_is_a_bestiary_field_of_the_haetae_and_the_reaper_only() -> void:
	var brave := Bestiary.KINDS.keys().filter(func(k): return Bestiary.info(k).get("brave", false))
	assert_eq(brave, [&"haetae", &"saja"])


func test_only_sharp_or_cunning_kinds_that_can_walk_flee() -> void:
	for kind in Bestiary.KINDS:
		if kind == &"miho":
			continue
		var spec := Bestiary.info(kind)
		var walks: bool = spec.get("move", &"static") != &"static"
		var should: bool = (
			Bestiary.wits(kind) >= Bestiary.SHARP and walks and not spec.get("brave", false)
		)
		assert_eq(Bestiary.flees(kind), should, kind)
	assert_true(Bestiary.flees(&"dokkaebi"))
	assert_true(Bestiary.flees(&"cheonnyeon"))
	assert_false(Bestiary.flees(&"jangseung"))
	assert_false(Bestiary.flees(&"haetae"))
	assert_false(Bestiary.flees(&"saja"))


func test_a_hunter_at_one_health_runs_from_miho() -> void:
	var w := _hall()
	var a := _hunter(w, &"dokkaebi", ME + Vector2i(3, 0))
	assert_true(a.fleeing())
	w.act(WAIT)
	assert_gt(Grid.cheb(a.pos, ME), 3)
	assert_eq(a.alert, Actor.HUNT, "it still hunts her")


func test_a_hunter_with_more_health_closes_in() -> void:
	var w := _hall()
	var a := _hunter(w, &"dokkaebi", ME + Vector2i(3, 0), 2)
	assert_false(a.fleeing())
	w.act(WAIT)
	assert_lt(Grid.cheb(a.pos, ME), 3)


func test_brave_kinds_never_flee() -> void:
	for kind in [&"haetae", &"saja"]:
		var w := _hall()
		var a := _hunter(w, kind, ME + Vector2i(3, 0))
		assert_false(a.fleeing(), kind)
		w.act(WAIT)
		assert_lte(Grid.cheb(a.pos, ME), 3, kind)


func test_a_creature_that_rests_or_searches_does_not_flee() -> void:
	var w := _hall()
	var a := _hunter(w, &"dokkaebi", ME + Vector2i(3, 0))
	for alert in [Actor.REST, Actor.SEARCH]:
		a.alert = alert
		assert_false(a.fleeing())


func test_it_runs_towards_its_own_group() -> void:
	for side in [-1, 1]:
		var w := _hall()
		var a := _hunter(w, &"dokkaebi", Vector2i(10, 8))
		var kin := FloorGen.spawn(w, &"oedari", Vector2i(14, 8 + 5 * side))
		kin.stunned = 5
		w.act(WAIT)
		assert_eq(a.pos, Vector2i(11, 8 + side), "kin at %d" % side)


func test_creatures_of_another_group_do_not_draw_it() -> void:
	var alone := _hall()
	var runner := _hunter(alone, &"dokkaebi", Vector2i(10, 8))
	alone.act(WAIT)
	for at in [Vector2i(14, 3), Vector2i(14, 13)]:
		var w := _hall()
		var a := _hunter(w, &"dokkaebi", Vector2i(10, 8))
		FloorGen.spawn(w, &"imugi", at).stunned = 5
		w.act(WAIT)
		assert_eq(a.pos, runner.pos, "an imugi at %s" % at)


func test_a_cornered_creature_fights() -> void:
	var w := _hall()
	w.player().pos = Vector2i(2, 2)
	var a := _hunter(w, &"dokkaebi", Vector2i(1, 1))
	a.target = w.player().pos
	var events := w.act(WAIT)
	assert_eq(a.pos, Vector2i(1, 1))
	assert_true(events.any(func(e): return e.t == &"melee" and e.id == a.id))


func test_one_that_loses_sight_of_her_stops_running_and_searches() -> void:
	var w := _hall(false)
	var a := _hunter(w, &"dokkaebi", ME + Vector2i(8, 0))
	w.act(WAIT)
	assert_false(w.sees(a, ME))
	assert_eq(a.alert, Actor.SEARCH)
	assert_false(a.fleeing())


func test_the_forecast_runs_the_same_flight() -> void:
	var w := _hall()
	var a := _hunter(w, &"dokkaebi", Vector2i(10, 8))
	var kin := FloorGen.spawn(w, &"oedari", Vector2i(14, 3))
	kin.stunned = 5
	var after := Forecast.of(w, WAIT).after
	w.act(WAIT)
	assert_eq(after.actor(a.id).pos, a.pos)
	assert_eq(a.pos, Vector2i(11, 7))


func test_the_hover_the_sidebar_and_the_map_call_it_fleeing() -> void:
	var w := _hall()
	var a := _hunter(w, &"dokkaebi", ME + Vector2i(3, 0))
	assert_eq(Info.state(a), "도망치는 중")
	assert_string_contains(Info.plain(Info.creature(w, a)), "도망치는 중")
	assert_eq(Perceived.mark_of(a), Palette.FLEE_MARK)
	a.hp = 2
	assert_eq(Info.state(a), Info.STATE[Actor.HUNT])
	assert_eq(Perceived.mark_of(a), Palette.ALERT_MARK[Actor.HUNT])


func test_the_log_tells_a_creature_in_sight_that_starts_to_flee() -> void:
	var w := _hall()
	var a := _hunter(w, &"dokkaebi", ME + Vector2i(3, 0), 2)
	var before := w.clone()
	a.hp = 1
	var events := w.act(WAIT)
	var lines := Messages.of(before, w, events).map(func(l): return Messages.plain(l))
	assert_true(lines.has("도깨비가 도망치고 있다"), str(lines))


func test_the_doc_and_the_hover_tell_who_flees_and_who_does_not() -> void:
	var sharp := Info.plain(Info.creature_facts(Codex.foe(&"dokkaebi"), []))
	assert_string_contains(sharp, "체력 1이면 도망친다")
	var brave := Info.plain(Info.creature_facts(Codex.foe(&"haetae"), []))
	assert_string_contains(brave, "용감해서 도망치지 않는다")
	var still := Info.plain(Info.creature_facts(Codex.foe(&"jangseung"), []))
	assert_false(still.contains("도망"))


func test_the_agent_is_told_a_creature_flees() -> void:
	var w := _hall()
	_hunter(w, &"dokkaebi", ME + Vector2i(3, 0))
	assert_string_contains(Observation.text(w), "hunting, fleeing")
