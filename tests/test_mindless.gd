extends GutTest
## 객귀 and 달걀귀신, the mindless dead (wits 0, no spells): they stand on the early
## storeys, strike in melee and fall for a guise.

const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)
const E := Vector2i(1, 0)
const SEEDS := [1, 2, 3, 4, 5, 6]


## An open hall, every tile known and seen, Miho at ME.
func _hall() -> World:
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
	me.hp = 9
	me.max_hp = 9
	me.pos = ME
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 2
	w.tails = 4
	w.set_tile(ME + Vector2i(0, 3), World.LANTERN)
	w.sense()
	return w


func _hunter(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.brain.alert = Actor.HUNT
	a.brain.target = ME
	return a


func _count(kind: StringName, depth: int) -> int:
	return (
		SEEDS
		. filter(func(s): return Built.storey(s, depth).actors.any(func(a): return a.kind == kind))
		. size()
	)


func test_a_storey_builds_with_the_mindless_dead_in_it() -> void:
	assert_eq(_count(&"gaekgwi", 1), SEEDS.size(), "storey 1 holds a 객귀")
	assert_eq(_count(&"dalgyal", 2), SEEDS.size(), "storey 2 holds a 달걀귀신")
	assert_eq(_count(&"gaekgwi", 3), SEEDS.size(), "storey 3 holds a 객귀")


func test_the_undead_of_a_storey_stand_in_one_band_led_by_the_dalgyal() -> void:
	for s in SEEDS:
		var w := Built.storey(s, 2)
		var lead: Actor = w.actors.filter(func(a): return a.kind == &"dalgyal")[0]
		var gaekgwi: Actor = w.actors.filter(func(a): return a.kind == &"gaekgwi")[0]
		assert_eq(gaekgwi.ties.leader, lead.id, "seed %d" % s)


func test_a_gaekgwi_walks_at_her_and_strikes() -> void:
	var w := _hall()
	var a := _hunter(w, &"gaekgwi", ME + E * 3)
	var struck := 0
	for i in 6:
		struck += w.act(WAIT).filter(func(e): return e.t == &"melee" and e.id == a.id).size()
	assert_eq(Grid.cheb(a.pos, ME), 1, "it came to her")
	assert_gt(struck, 0)
	assert_eq(w.player().hp, w.player().max_hp - struck * Bestiary.info(&"gaekgwi").melee.damage)


func test_a_dalgyal_hops_every_other_round_and_hits_harder() -> void:
	var w := _hall()
	var a := _hunter(w, &"dalgyal", ME + E * 5)
	var hops := 0
	for i in 4:
		var before := a.pos
		w.act(WAIT)
		hops += 1 if a.pos != before else 0
	assert_eq(hops, 2, "it moves every other round")
	assert_gt(Bestiary.info(&"dalgyal").melee.damage, Bestiary.info(&"gaekgwi").melee.damage)


func test_a_dalgyal_does_not_hear_noise() -> void:
	var w := _hall()
	var dead := FloorGen.spawn(w, &"dalgyal", ME + E * 6)
	var living := FloorGen.spawn(w, &"dokkaebi", ME + Vector2i(0, -4))
	Hearing.noise(w, ME, 12, "쾅", true, w.player().id)
	assert_eq(living.brain.alert, Actor.SEARCH, "a 도깨비 goes to look")
	assert_eq(dead.brain.alert, Actor.REST, "a 달걀귀신 does not")


func test_the_forecast_of_a_round_with_the_dead_equals_the_round() -> void:
	var w := _hall()
	_hunter(w, &"dalgyal", ME + E)
	_hunter(w, &"gaekgwi", ME + Vector2i(0, -1))
	var f := Forecast.of(w, WAIT)
	var hurt := 0
	for e in w.act(WAIT):
		if e.t == &"hurt" and e.id == w.player().id:
			hurt += e.n
	assert_gt(hurt, 0)
	assert_eq(f.harm.get(w.player().id, 0), hurt)
	assert_eq(f.after.player().hp, w.player().hp)


func test_a_whole_storey_with_the_dead_runs_rounds_alike_twice() -> void:
	var runs := []
	for k in 2:
		var w := Built.storey(3, 2)
		for a in w.actors:
			if a.kind in [&"gaekgwi", &"dalgyal"]:
				a.brain.alert = Actor.HUNT
				a.brain.target = w.player().pos
		for i in 12:
			w.act(WAIT)
		runs.append(w.actors.map(func(a): return [a.kind, a.pos, a.hp]))
	assert_eq(runs[0], runs[1])
