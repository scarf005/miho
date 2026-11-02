extends GutTest
## A torn 제웅 (Jars) puts one curse on Miho (Curse): the reaper comes sooner, creatures see
## farther in the dark, or a body in the jar rises one second later as an enemy.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const BUMP := {t = &"move", dir = E}
const ME := Vector2i(4, 8)
const AT := Vector2i(5, 8)
const FAR_JAR := Vector2i(40, 8)
const SEEDS := 60
const LEAD := World.REAPER_ARRIVES - World.REAPER_OMEN
const ALL := [Curse.REAPER, Curse.SIGHT, Curse.BODY]
## Rounds a doll is bumped in, around every moment of the reaper's clock.
const ROUNDS := [0, 199, 219, 220, 221, 250, 298, 299, 300, 301, 310, 318]


## An open hall walled at the edges, with no light, Miho at ME beside a doll jar at AT.
func _world(seed_value := 5, depth := 2, round_no := 0) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = depth
	w.round_no = round_no
	w.start = ME
	w.rng.seed = seed_value
	w.set_tile(AT, World.JAR)
	w.jars[AT] = &"effigy"
	w.sense()
	return w


## What the round's events put on her, or nothing.
func _picked(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"curse").map(func(e): return e.what)


## A world whose doll, bumped next, puts `what` on her.
func _doomed(what: StringName, depth := 2, round_no := 0) -> World:
	for s in SEEDS:
		var w := _world(s, depth, round_no)
		if _picked(w.preview(BUMP).events) == [what]:
			return w
	fail_test("no seed picks %s" % what)
	return _world()


## A creature that never walks or sleeps, in the hall, `reach` tiles south of Miho.
func _watcher(w: World, reach: int) -> Actor:
	var a := FloorGen.spawn(w, &"jangseung", ME + Vector2i(0, reach))
	a.magic.cooldown = 99
	w.sense()
	return a


## Waits until the reaper arrives or `last` is passed: the rounds its omen and its arrival
## were told in.
func _clock(w: World, events: Array, last := World.REAPER_ARRIVES) -> Dictionary:
	var out := {omens = [], arrivals = []}
	var told := events
	while true:
		for e: Dictionary in told:
			if e.t == &"omen":
				out.omens.append(w.round_no)
			if e.t == &"arrive":
				out.arrivals.append(w.round_no)
		if w.round_no > last or w.outcome != &"":
			return out
		told = w.act(WAIT)
		w.player().hp = w.player().max_hp
	return out


func test_a_doll_jar_puts_one_curse_on_her_and_each_comes_up_over_the_seeds() -> void:
	var seen := {}
	for s in SEEDS:
		var picked := _picked(_world(s).act(BUMP))
		assert_eq(picked.size(), 1)
		seen[picked[0]] = true
	for what: StringName in ALL:
		assert_true(seen.has(what), str(what))


func test_a_doll_jar_harms_no_creature_any_more() -> void:
	for s in SEEDS:
		var w := _world(s)
		var foe := _watcher(w, 1)
		var hp := foe.hp
		w.act(BUMP)
		assert_eq(foe.hp, hp)


func test_the_reaper_curse_brings_the_omen_and_the_reaper_sooner() -> void:
	var w := _doomed(Curse.REAPER)
	var at := World.REAPER_ARRIVES - Curse.SOONER
	var told := w.act(BUMP)
	w.round_no = at - LEAD - 2
	var clock := _clock(w, told, at)
	assert_eq(clock.omens, [at - LEAD])
	assert_eq(clock.arrivals, [at])
	assert_eq(w.actors.filter(func(a): return a.kind == &"saja").size(), 1)


func test_the_reaper_comes_once_and_never_later_whenever_the_curse_falls() -> void:
	for r: int in ROUNDS:
		var w := _doomed(Curse.REAPER, 2, r)
		var clock := _clock(w, w.act(BUMP))
		assert_eq(clock.arrivals.size(), 1, "bumped in round %d" % r)
		assert_lte(clock.omens.size(), 1, "bumped in round %d" % r)
		assert_lt(clock.arrivals[0], World.REAPER_ARRIVES, "bumped in round %d" % r)


func test_with_the_omen_passed_the_reaper_comes_at_the_end_of_that_round() -> void:
	for r in range(World.REAPER_OMEN, World.REAPER_ARRIVES - 1):
		var w := _doomed(Curse.REAPER, 2, r)
		var told := w.act(BUMP)
		assert_true(told.any(func(e): return e.t == &"arrive"), "bumped in round %d" % r)
		assert_false(told.any(func(e): return e.t == &"omen"), "told already, round %d" % r)
		assert_eq(_clock(w, []).arrivals, [], "not again, round %d" % r)


func test_without_the_curse_the_reaper_keeps_its_time() -> void:
	var w := _world(5, 2, World.REAPER_OMEN - 1)
	var clock := _clock(w, [])
	assert_eq(clock.omens, [World.REAPER_OMEN])
	assert_eq(clock.arrivals, [World.REAPER_ARRIVES])


func test_no_doll_brings_a_reaper_that_cannot_come_sooner() -> void:
	for s in SEEDS:
		assert_false(_picked(_world(s, 2, World.REAPER_ARRIVES).act(BUMP)).has(Curse.REAPER))
		assert_false(_picked(_world(s, World.FLOORS).act(BUMP)).has(Curse.REAPER))


func test_a_second_doll_does_not_pick_the_sight_she_already_has() -> void:
	for s in SEEDS:
		var w := _world(s)
		w.curses[Curse.SIGHT] = true
		assert_false(_picked(w.act(BUMP)).has(Curse.SIGHT))


func test_a_second_reaper_curse_brings_it_sooner_again() -> void:
	var w := _doomed(Curse.REAPER)
	w.act(BUMP)
	w.set_tile(AT, World.JAR)
	w.jars[AT] = &"effigy"
	for s in SEEDS:
		w.rng.seed = s
		if _picked(w.preview(BUMP).events) == [Curse.REAPER]:
			break
	var told := w.act(BUMP)
	w.round_no = World.REAPER_ARRIVES - 2 * Curse.SOONER - 1
	assert_eq(_clock(w, told, World.REAPER_ARRIVES - 2 * Curse.SOONER).arrivals.size(), 1)


func test_under_the_sight_curse_a_creature_sees_her_farther_in_the_dark_and_no_farther() -> void:
	var reach: int = World.NIGHT[Actor.HEAVEN] + Curse.MORE_SIGHT
	var w := _doomed(Curse.SIGHT)
	var near := _watcher(w, reach)
	var far := _watcher(w, reach + 1)
	var me := w.player()
	assert_false(w.sees(near, me.pos), "not before the curse")
	w.act(BUMP)
	assert_true(w.sees(near, me.pos), "at the longer range")
	assert_false(w.sees(far, me.pos), "one tile past it")


func test_under_the_sight_curse_a_creature_notices_her_where_it_would_not_have() -> void:
	var reach: int = World.NIGHT[Actor.HEAVEN] + Curse.MORE_SIGHT
	var cursed := _doomed(Curse.SIGHT)
	var plain := cursed.clone()
	plain.jars[AT] = &"empty"
	var foes := [_watcher(cursed, reach), _watcher(plain, reach)]
	cursed.act(BUMP)
	plain.act(BUMP)
	assert_eq(foes[0].alert, Actor.HUNT)
	assert_ne(foes[1].alert, Actor.HUNT)


func test_rust_and_gdscript_sight_agree_under_the_sight_curse() -> void:
	var w := _doomed(Curse.SIGHT)
	var foe := _watcher(w, 4)
	var before := w.view_of(foe)
	assert_eq(Sight.sensed(w, foe)[0], before, "no curse")
	w.act(BUMP)
	assert_eq(Sight.sensed(w, foe)[0], w.view_of(foe), "cursed")
	assert_ne(w.view_of(foe), before, "and it did change")


func test_the_sight_curse_does_not_change_what_she_sees() -> void:
	var w := _doomed(Curse.SIGHT)
	var reach := Sight.reach(w, w.player())
	w.act(BUMP)
	assert_eq(Sight.reach(w, w.player()), reach)


func test_the_sight_curse_stays_on_its_storey() -> void:
	var w := _doomed(Curse.SIGHT)
	w.act(BUMP)
	var reach: int = World.NIGHT[Actor.HEAVEN] + Curse.MORE_SIGHT
	var cursed := w.depth
	w.stairs = ME + E
	w.act(BUMP)
	assert_eq(w.depth, cursed + 1)
	assert_true(w.curses.is_empty(), "the next storey is free of it")
	var foe := FloorGen.spawn(w, &"jangseung", w.player().pos + Vector2i(0, reach))
	assert_lt(Sight.reach(w, foe), reach)
	Storeys.leave(w)
	Storeys.enter(w, cursed)
	assert_eq(Sight.reach(w, foe), reach, "back where it fell, it holds")


func test_the_reaper_curse_stays_on_its_storey() -> void:
	var w := _doomed(Curse.REAPER)
	var at := World.REAPER_ARRIVES - Curse.SOONER
	w.act(BUMP)
	var cursed := w.depth
	w.stairs = ME + E
	w.act(BUMP)
	w.round_no = at - 2
	assert_eq(_clock(w, [], at).arrivals, [], "the next storey keeps its own clock")
	w.round_no = World.REAPER_ARRIVES - 2
	assert_eq(_clock(w, []).arrivals, [World.REAPER_ARRIVES])
	Storeys.leave(w)
	Storeys.enter(w, cursed)
	w.round_no = at - 2
	assert_eq(_clock(w, [], at).arrivals, [at], "back where it fell, sooner")
	w.round_no = World.REAPER_ARRIVES - 2
	assert_eq(_clock(w, []).arrivals, [], "and once")


func test_the_body_lies_for_a_second_then_rises_as_an_enemy() -> void:
	var w := _doomed(Curse.BODY)
	var round_no := w.round_no
	w.act(BUMP)
	assert_true(w.bodies.has(AT), "a body where the jar stood")
	assert_true(w.bodies[AT].met, "and she sees it")
	assert_null(w.actor_at(AT))
	var told := w.act(WAIT)
	assert_eq(w.round_no, round_no + 2)
	assert_true(told.any(func(e): return e.t == &"rise" and e.at == AT))
	assert_false(w.bodies.has(AT), "the body is gone")
	var risen := w.actor_at(AT)
	assert_eq(risen.faction, Actor.HEAVEN)
	assert_false(Raise.risen(risen))
	for i in 4:
		w.act(WAIT)
	assert_lt(w.player().hp, w.player().max_hp, "it attacks her")


func test_what_rises_goes_by_the_storey() -> void:
	var low := _doomed(Curse.BODY, Curse.STRONG_FROM - 1)
	low.act(BUMP)
	low.act(WAIT)
	assert_eq(low.actor_at(AT).kind, Raise.WEAK)
	var high := _doomed(Curse.BODY, Curse.STRONG_FROM)
	high.act(BUMP)
	high.act(WAIT)
	assert_eq(high.actor_at(AT).kind, Raise.STRONG)


func test_raising_the_dead_does_not_take_the_body_in_the_jar() -> void:
	var w := _doomed(Curse.BODY)
	w.player().buffs.raise = true
	w.act(BUMP)
	assert_true(w.bodies.has(AT), "it lies its second")
	w.act(WAIT)
	assert_eq(w.actor_at(AT).faction, Actor.HEAVEN)


func test_a_body_whose_tile_is_taken_rises_beside_it() -> void:
	var w := _doomed(Curse.BODY)
	w.act(BUMP)
	var stander := _watcher(w, 1)
	stander.pos = AT
	w.act(WAIT)
	assert_false(w.bodies.has(AT))
	assert_eq(w.actor_at(AT), stander)
	var risen := w.actors.filter(func(a): return Raise.undead(a.kind))
	assert_eq(risen.size(), 1)
	assert_eq(Grid.cheb(risen[0].pos, AT), 1)


func test_a_body_with_no_room_stays_a_body_until_there_is_room() -> void:
	var w := _doomed(Curse.BODY)
	w.act(BUMP)
	var stander := _watcher(w, 1)
	stander.pos = AT
	for d: Vector2i in Grid.DIRS:
		if AT + d != ME:
			w.set_tile(AT + d, World.WALL)
	w.act(WAIT)
	assert_true(w.bodies.has(AT), "nowhere to rise")
	assert_false(w.actors.any(func(a): return Raise.undead(a.kind)))
	w.set_tile(AT + E, World.FLOOR)
	w.act(WAIT)
	assert_false(w.bodies.has(AT))
	assert_true(w.actor_at(AT + E) != null and Raise.undead(w.actor_at(AT + E).kind))


func test_a_preview_equals_the_act_for_every_curse() -> void:
	for what: StringName in ALL:
		var w := _doomed(what)
		for action: Dictionary in [BUMP, WAIT]:
			var ahead := w.preview(action)
			w.act(action)
			assert_eq(ahead.curses, w.curses, str(what))
			assert_eq(ahead.bodies, w.bodies, str(what))
			assert_eq(ahead.rng.state, w.rng.state, str(what))
			assert_eq(ahead.events, w.events, str(what))
			assert_eq(ahead.actors.size(), w.actors.size(), str(what))


func test_a_forecast_tells_no_curse_before_the_jar_breaks() -> void:
	for what: StringName in ALL:
		var w := _doomed(what)
		var f := Forecast.of(w, BUMP)
		assert_eq(_picked(f.events), [], str(what))
		assert_true(f.after.curses.is_empty(), str(what))
		assert_eq(f.after.rng.state, w.rng.state, str(what))


func test_a_forecast_of_the_second_after_shows_the_body_rising() -> void:
	var w := _doomed(Curse.BODY)
	w.act(BUMP)
	var f := Forecast.of(w, WAIT)
	w.act(WAIT)
	assert_eq(f.after.actor_at(AT).kind, w.actor_at(AT).kind)


## The state of a run a replay must give back.
func _state(w: World) -> Array:
	return [
		w.curses,
		w.bodies,
		w.round_no,
		w.rng.state,
		w.tiles,
		w.actors.map(func(a): return [a.id, a.kind, a.pos, a.hp, a.alert, a.faction]),
	]


func test_a_saved_run_replays_to_the_same_curse() -> void:
	var picked := {}
	for s in 200:
		var w := World.create(s)
		var jars := w.jars.keys().filter(func(at): return w.jars[at] == &"effigy")
		if jars.is_empty():
			continue
		var sides := Placement.SIDES.filter(func(d): return w.vacant(jars[0] + d))
		if sides.is_empty():
			continue
		var run := SaveGame.new("", s)
		(
			run
			. actions
			. assign(
				[
					{t = &"cheat", cmd = &"halt"},
					{t = &"cheat", cmd = &"teleport", at = jars[0] + sides[0]},
					{t = &"move", dir = -sides[0]},
				]
			)
		)
		var told := []
		for action: Dictionary in run.actions:
			told.append_array(w.act(action))
		picked.merge({_picked(told)[0]: true})
		assert_true(run.replay(), "seed %d" % s)
		assert_eq(_state(run.world), _state(w), "seed %d" % s)
		if picked.size() >= 2:
			return
	fail_test("too few seeds hold a doll beside free floor")


func test_a_curse_reads_on_her_hover_with_the_longer_reach() -> void:
	var w := _doomed(Curse.SIGHT)
	var name := Lang.t(Curse.NAME[Curse.SIGHT])
	var me := w.player()
	assert_false(Info.plain(Info.creature(w, me)).contains(name))
	var dark := Lang.t("어두움: %d칸 안에서만 보임")
	assert_true(Info.plain(Info.creature(w, me)).contains(dark % World.NIGHT[Actor.HEAVEN]))
	w.act(BUMP)
	assert_true(Info.plain(Info.creature(w, me)).contains(name))
	var reach: int = World.NIGHT[Actor.HEAVEN] + Curse.MORE_SIGHT
	assert_true(Info.plain(Info.creature(w, me)).contains(dark % reach))


func test_a_lasting_curse_is_told_out_of_sight_and_a_body_only_in_sight() -> void:
	var seen := {}
	for s in SEEDS:
		var w := _world(s)
		w.set_tile(FAR_JAR, World.JAR)
		w.jars[FAR_JAR] = &"effigy"
		w.sense()
		assert_eq(w.seen[Grid.index(FAR_JAR)], 0)
		var before := w.clone()
		Terrain.hit(w, FAR_JAR)
		var what: StringName = _picked(w.events)[0]
		seen[what] = true
		var told: bool = _picked(Perceived.of(before, w, w.events).facts).has(what)
		assert_eq(told, what != Curse.BODY, str(what))
	assert_eq(seen.size(), ALL.size())


## What the 도감's example of a curse leaves at its end, the doll's jar holding `what`.
func _example(curse: StringName, what := &"effigy") -> World:
	var scene := CodexScene.of(Curse.NAME[curse])
	var w := CodexScene.build(scene)
	for at: Vector2i in w.jars:
		w.jars[at] = what
	for action in CodexScene.actions(scene):
		w.act(action)
	return w


func test_the_examples_in_the_codex_show_what_each_curse_does() -> void:
	var saja := func(a): return a.kind == &"saja"
	var watcher := func(a): return a.kind == &"jangseung"
	assert_true(_example(Curse.REAPER).actors.any(saja), "the reaper comes at once")
	assert_false(_example(Curse.REAPER, &"empty").actors.any(saja), "only by the doll")
	assert_eq(_example(Curse.SIGHT).actors.filter(watcher)[0].alert, Actor.HUNT, "seen in the dark")
	assert_ne(_example(Curse.SIGHT, &"empty").actors.filter(watcher)[0].alert, Actor.HUNT)


func test_the_rising_is_told_as_a_line_when_she_sees_it() -> void:
	var w := _doomed(Curse.BODY)
	w.act(BUMP)
	var before := w.clone()
	var told := w.act(WAIT)
	assert_true(Perceived.of(before, w, told).facts.any(func(f): return f.t == &"rise"))
	assert_eq(Messages.of(before, w, told).size(), 1, "one line, its search mark told by it")


func test_a_reaper_due_this_round_anyway_is_no_curse_to_pick() -> void:
	for seed_value in SEEDS:
		var w := _world(seed_value, 2, World.REAPER_ARRIVES - 1)
		assert_ne(Curse.pick(w), Curse.REAPER)


func test_a_creature_dying_on_a_rising_body_does_not_stop_it() -> void:
	var w := _world()
	var body := Notice.lay(w, Raise.WEAK, FAR_JAR)
	body.rises = w.round_no + Curse.RISE_ROUNDS
	Notice.lay(w, &"dokkaebi", FAR_JAR)
	w.act(WAIT)
	w.act(WAIT)
	var risen := w.actor_at(FAR_JAR)
	assert_not_null(risen)
	assert_eq(risen.kind, Raise.WEAK)
