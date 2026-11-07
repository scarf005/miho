extends GutTest
## 최면 sprays a line and puts the first creature it reaches to sleep, with the
## sleep every creature has (Actor.asleep): noise or a wound wakes it. A patrol
## sleeps where it is hit, and a creature that never sleeps is left as it was,
## the log telling it.

const E := Vector2i(1, 0)
const ME := Vector2i(4, 8)
const WAIT := {t = &"wait"}
const HYPNOSIS := [Cards.WATER, Cards.FIRE, Cards.METAL]


## An open hall walled at the edges, every tile known and seen, Miho at ME with
## every talisman and nine tails.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	w.rooms = [Rect2i(1, 1, Grid.W - 2, Grid.H - 2)]
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 99
	me.max_hp = 99
	me.pos = ME
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 5
	w.tails = 9
	w.cards.assign(Cards.ALL)
	return w


func _cast() -> Dictionary:
	return {t = &"cast", spells = [{cards = HYPNOSIS, dir = E}]}


## A creature that hunts Miho from where it stands, home elsewhere.
func _hunter(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.brain.alert = Actor.HUNT
	a.brain.target = ME
	a.brain.home = at + Vector2i(0, 3)
	a.magic.cooldown = 99
	a.hp = 9
	a.max_hp = 9
	return a


func test_the_first_creature_in_the_line_falls_asleep_unhurt_and_the_next_does_not() -> void:
	var w := _world()
	var first := _hunter(w, &"imugi", ME + E * 2)
	var second := _hunter(w, &"imugi", ME + E * 4)
	first.magic.intent.assign([{cards = [Cards.FOX], dir = Vector2i(-1, 0)}])
	var events := w.act(_cast())
	assert_true(first.asleep())
	assert_eq(first.brain.alert, Actor.REST)
	assert_eq(first.hp, first.max_hp)
	assert_true(first.magic.intent.is_empty(), "the spell it charged is dropped")
	assert_eq(events.filter(func(e): return e.t == &"sleep").map(func(e): return e.id), [first.id])
	assert_false(second.asleep())
	assert_eq(second.brain.alert, Actor.HUNT)


func test_it_sleeps_on_and_does_not_hunt_her() -> void:
	var w := _world()
	var foe := _hunter(w, &"imugi", ME + E * 2)
	w.act(_cast())
	for i in 4:
		w.act(WAIT)
	assert_true(foe.asleep())
	assert_eq(foe.brain.alert, Actor.REST)
	assert_false(w.sees(foe, ME), "its eyes are shut")


func test_noise_wakes_it_and_it_goes_to_search_the_spot() -> void:
	var w := _world()
	var foe := _hunter(w, &"imugi", ME + E * 2)
	w.act(_cast())
	Hearing.noise(w, ME + Vector2i(3, 3), Compounds.BOOM, "쾅", true, 0)
	assert_false(foe.asleep())
	assert_eq(foe.brain.alert, Actor.SEARCH)


func test_a_wound_wakes_it() -> void:
	var w := _world()
	var foe := _hunter(w, &"imugi", ME + E)
	w.act(_cast())
	assert_true(foe.asleep())
	w.act({t = &"move", dir = E})
	assert_false(foe.asleep())
	assert_eq(foe.brain.alert, Actor.HUNT)


func test_a_creature_that_never_sleeps_stays_awake_and_still_stops_the_line() -> void:
	for kind in [&"mulgwisin", &"cheonha", &"saja"]:
		var w := _world()
		w.tiles[Grid.index(ME + E)] = World.SHALLOW
		var first := _hunter(w, kind, ME + E)
		var second := _hunter(w, &"imugi", ME + E * 4)
		var before := w.clone()
		var events := w.act(_cast())
		assert_false(first.asleep(), kind)
		assert_eq(first.hp, first.max_hp, kind)
		assert_eq(events.filter(func(e): return e.t == &"sleep").size(), 0, kind)
		assert_false(second.asleep(), "%s stops the line" % kind)
		var told := events.filter(func(e): return e.t == &"sleepless")
		assert_eq(told.map(func(e): return e.id), [first.id], kind)
		assert_ne(Sfx.sound_of(told[0]), &"", kind)
		var lines := Messages.of(before, w, events).map(func(l): return Messages.plain(l))
		var name: String = Bestiary.info(kind).name
		assert_has(lines, "%s%s 잠들지 않았다" % [name, "는" if kind == &"saja" else "은"], kind)


func test_a_patrol_falls_asleep_where_it_is_hit_and_stays_there() -> void:
	for kind in [&"bitjaru", &"dokkaebi", &"bakjwi"]:
		var w := _world()
		var foe := _hunter(w, kind, ME + E * 3)
		var events := w.act(_cast())
		assert_eq(events.filter(func(e): return e.t == &"sleep").size(), 1, kind)
		var at := foe.pos
		for i in 6:
			w.act(WAIT)
			assert_true(foe.asleep(), kind)
			assert_eq(foe.pos, at, "%s does not patrol or track" % kind)
		assert_false(w.sees(foe, ME), kind)
		assert_eq(Info.state(foe), "자는 중", kind)


func test_a_follower_put_to_sleep_does_not_follow_its_leader() -> void:
	var w := _world()
	var lead := FloorGen.spawn(w, &"dokkaebi", Vector2i(Grid.W - 4, Grid.H - 3))
	lead.brain.post = Vector2i(Grid.W - 4, 2)
	var foe := _hunter(w, &"dokkaebi", ME + E * 3)
	foe.ties.leader = lead.id
	w.act(_cast())
	var at := foe.pos
	for i in 6:
		w.act(WAIT)
	assert_ne(lead.pos, Vector2i(Grid.W - 4, Grid.H - 3), "the leader walks on")
	assert_eq(foe.pos, at)
	assert_true(foe.asleep())


func test_a_woken_patrol_is_awake_when_it_rests_again() -> void:
	var w := _world()
	var foe := _hunter(w, &"dokkaebi", ME + E * 3)
	w.act(_cast())
	Hearing.noise(w, ME + Vector2i(3, 3), Compounds.BOOM, "쾅", true, 0)
	assert_false(foe.asleep())
	assert_eq(foe.brain.alert, Actor.SEARCH)
	foe.brain.alert = Actor.REST
	assert_false(foe.asleep(), "it patrols again")


func test_the_log_tells_who_fell_asleep() -> void:
	var w := _world()
	_hunter(w, &"imugi", ME + E * 2)
	var before := w.clone()
	var events := w.act(_cast())
	var lines := Messages.of(before, w, events).map(func(l): return Messages.plain(l))
	assert_has(lines, "이무기가 잠들었다")


func test_a_forecast_equals_the_round() -> void:
	var w := _world()
	_hunter(w, &"imugi", ME + E * 2)
	_hunter(w, &"dokkaebi", ME + E * 4)
	var forecast := Forecast.of(w, _cast())
	var played := w.act(_cast())
	assert_eq(forecast.events, played)
	for a in w.actors:
		var seen := forecast.after.actor(a.id)
		assert_eq([seen.brain.alert, seen.brain.home, seen.hp], [a.brain.alert, a.brain.home, a.hp])
