extends GutTest
## A push starts with the touch that makes it: the creature leaves at once, flashes and
## clashes as it does, slides fast and stops soft, and a slam into a wall shakes the map.

const E := Vector2i(1, 0)
const ME := Codex.ME
const JET := [Cards.WATER, Cards.WATER, Cards.WATER]


func _game(w: World) -> Node:
	var m: Node = Built.main()
	add_child_autofree(m)
	m.new_run(1)
	m.state = &"play"
	m.world = w
	return m


## Open floor, a foe two tiles east of Miho; a wall `wall` tiles east of her when set.
func _stage(wall := 0) -> Dictionary:
	var w := Codex.stage()
	w.depth = 5
	w.tails = 20
	w.cards.assign(Cards.ALL)
	for x in [2, 5]:
		w.tiles[Grid.index(ME + Vector2i(x, 3))] = World.LANTERN
	if wall > 0:
		w.tiles[Grid.index(ME + E * wall)] = World.WALL
	w._changed()
	w.sense()
	var foe := FloorGen.spawn(w, &"dokkaebi", ME + E * 2)
	foe.hp = 99
	return {w = w, foe = foe}


func _cast(w: World, cards: Array) -> Array:
	return w.act({t = &"cast", spells = [{cards = cards, dir = E}]})


## What Miho is told of `events`, by index, as Term.play tells it.
func _told(before: World, after: World, events: Array) -> Dictionary:
	var out := {}
	for f in Perceived.of(before, after, events).facts:
		if f.i >= 0:
			out[f.i] = f
	return out


func _first(events: Array, kind: StringName, id: int) -> int:
	for i in events.size():
		if events[i].t == kind and events[i].get("id", -1) == id:
			return i
	return -1


## The holds of `events` from index `from` up to `to`, `to` left out.
func _held(m: Node, events: Array, told: Dictionary, from: int, to: int) -> float:
	var waits: Array[float] = m.term.anim.holds(events, told)
	return waits.slice(from, to).reduce(func(a, b): return a + b, 0.0)


func test_a_three_tile_jet_holds_its_round_a_quarter_second_at_most() -> void:
	var s := _stage()
	var w: World = s.w
	var m := _game(w)
	var before := w.clone()
	var events := _cast(w, JET)
	var told := _told(before, w, events)
	assert_eq(RoundAnim.slides(events).size(), 3, "pushed 3 tiles")
	var move := _first(events, &"move", s.foe.id)
	assert_eq(_held(m, events, told, 0, move), 0.0, "the foe leaves at the cast")
	assert_lte(_held(m, events, told, 0, events.size()), 0.25)


func test_an_orb_that_pushes_holds_nothing_at_the_touch() -> void:
	var s := _stage()
	var w: World = s.w
	var m := _game(w)
	var before := w.clone()
	var events := _cast(w, [Cards.ORB, Cards.WATER])
	var hit := _first(events, &"hit", s.foe.id)
	var move := _first(events, &"move", s.foe.id)
	assert_gt(hit, -1)
	assert_gt(move, hit)
	assert_eq(_held(m, events, _told(before, w, events), hit, move), 0.0)


func test_a_slide_leaves_fast_and_stops_soft() -> void:
	var events: Array = [{t = &"push", id = 7, at = ME}]
	for k in 4:
		events.append({t = &"move", id = 7, from = ME + E * k, to = ME + E * (k + 1)})
	var slid := RoundAnim.slides(events)
	assert_eq(slid.size(), 4)
	for k in range(1, 4):
		assert_lt(slid[k], slid[k + 1])
	var sum: float = slid.values().reduce(func(a, b): return a + b, 0.0)
	assert_almost_eq(sum, RoundAnim.SLIDE * 4, 0.0001)


func test_the_push_clashes_and_flashes_in_the_frame_the_foe_leaves() -> void:
	var s := _stage()
	var w: World = s.w
	var m := _game(w)
	var before := w.clone()
	var events := _cast(w, JET)
	var push := _first(events, &"push", s.foe.id)
	var move := _first(events, &"move", s.foe.id)
	var waits: Array[float] = m.term.anim.holds(events, _told(before, w, events))
	assert_eq(waits.slice(push, move), waits.slice(push, move).map(func(_x): return 0.0))
	var flashed := {}
	m.term.shown.connect(
		func(e, _at):
			if e.t == &"push":
				flashed.push = m.term.anim.flashes.any(
					func(f): return f.at == e.at and f.born <= m.term.time
				)
	)
	m.term.play(events, before, w)
	m.term.rush()
	assert_eq(Sfx.sound_of(events[push]), &"clash")
	assert_eq(flashed, {push = true})


func test_a_spray_that_pushes_nothing_holds_before_a_throw() -> void:
	var s := _stage()
	var w: World = s.w
	s.foe.pos = Vector2i(30, 8)
	var thrower := FloorGen.spawn(w, &"oedari", ME - E)
	thrower.magic.cooldown = 99
	thrower.brain.alert = Actor.HUNT
	w.sense()
	var m := _game(w)
	var before := w.clone()
	var events := _cast(w, [Cards.FIRE])
	var spray := _first(events, &"spray", w.player().id)
	assert_gt(_first(events, &"push", w.player().id), spray, "the throw comes after the spray")
	var waits: Array[float] = m.term.anim.holds(events, _told(before, w, events))
	assert_eq(waits[spray], RoundAnim.DELAY[&"spray"])


func test_a_slam_into_a_wall_flashes_and_shakes_the_map() -> void:
	var s := _stage(4)
	var w: World = s.w
	var m := _game(w)
	var before := w.clone()
	var events := _cast(w, JET)
	var slam := {}
	m.term.shown.connect(
		func(e, _at):
			if e.t == &"crash":
				slam.shaking = m.term.shaking()
				slam.flashed = m.term.anim.flashes.any(func(f): return f.at == e.at)
	)
	m.term.play(events, before, w)
	m.term.rush()
	assert_eq(slam, {shaking = true, flashed = true})


func test_a_key_ends_a_push_round_at_once() -> void:
	var s := _stage()
	var w: World = s.w
	var m := _game(w)
	var before := w.clone()
	var events := _cast(w, JET)
	m.term.play(events, before, w)
	assert_true(m.term.anim.playing)
	m.term.rush()
	assert_false(m.term.anim.playing)
