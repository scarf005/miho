extends GutTest
## Once the storey's first 저승사자 has fallen, more come after half the rounds and at half the
## tiles each time (Curse.fell, Curse.gap, Curse.distance).

const WAIT := {t = &"wait"}
const ME := Vector2i(20, 13)
const LEAD := World.REAPER_ARRIVES - World.REAPER_OMEN
## Rounds after the fall each comes, and tiles from Miho.
const ROUNDS := [160, 240, 280, 300, 310, 315, 317, 318, 319, 320]
const TILES := [16, 8, 4, 2, 1, 1, 1, 1, 1, 1]


## An open hall on storey 3, Miho at ME, a reaper of the clock standing apart.
func _world(depth := 3) -> World:
	var w := Arena.hall(ME)
	w.depth = depth
	w.start = ME
	w.rng.seed = 11
	return w


func _first(w: World) -> Actor:
	var saja := FloorGen.spawn(w, &"saja", Vector2i(45, 3))
	w.first_reaper = saja.id
	w.curses[Curse.REAPER] = 0  # its own arrival is past
	return saja


func _slay(w: World, a: Actor) -> void:
	Harm.hurt(w, a, a.hp)
	w.actors.assign(w.actors.filter(func(b): return b.is_miho()))


## Waits `n` rounds, Miho kept whole: what came, as {round, tiles, hunting}, and the rounds an
## omen was told. With `slay` the arrivals are removed each round.
func _wait(w: World, n: int, slay := true) -> Dictionary:
	var out := {came = [], omens = []}
	var start := w.round_no
	for i in n:
		w.player().hp = w.player().max_hp
		for e: Dictionary in w.act(WAIT):
			if e.t == &"omen":
				out.omens.append(w.round_no - start)
			if e.t == &"arrive":
				var a := w.actor(e.id)
				(
					out
					. came
					. append(
						{
							round = w.round_no - start,
							tiles = Grid.cheb(e.at, w.player().pos),
							hunting = a.brain.alert == Actor.HUNT,
						}
					)
				)
		if slay:
			w.actors.assign(w.actors.filter(func(b): return b.is_miho()))
	return out


func test_after_the_first_falls_each_comes_after_half_the_rounds_and_at_half_the_tiles() -> void:
	var w := _world()
	_slay(w, _first(w))
	var out := _wait(w, 320)
	assert_eq(out.came.map(func(c): return c.round), ROUNDS)
	assert_eq(out.came.map(func(c): return c.tiles), TILES)
	assert_true(out.came.all(func(c): return c.hunting))


func test_the_omen_comes_only_before_a_wait_longer_than_the_lead() -> void:
	var w := _world()
	_slay(w, _first(w))
	var out := _wait(w, 320)
	var told := []
	for i in ROUNDS.size():
		var gap: int = ROUNDS[i] - (ROUNDS[i - 1] if i > 0 else 0)
		if gap > LEAD:
			told.append(ROUNDS[i] - LEAD)
	assert_eq(told, [140, 220, 260])
	assert_eq(out.omens, told)


func test_with_no_free_tile_that_far_the_nearest_free_tile_is_taken() -> void:
	var w := Arena.from(["@..", "..."])
	w.depth = 3
	w.start = w.player().pos
	w.rng.seed = 3
	_slay(w, _first(w))
	var out := _wait(w, Curse.gap(0))
	assert_eq(out.came.size(), 1)
	assert_eq(out.came[0].tiles, 1)


func test_nothing_slain_brings_no_second_reaper() -> void:
	var w := _world()
	var out := _wait(w, World.REAPER_ARRIVES + 400, false)
	assert_eq(out.came.size(), 1, "the clock's own, and no more")
	assert_eq(w.reaper_due, -1)


func test_the_clock_reaper_slain_after_it_came_starts_the_clock_and_only_it() -> void:
	var w := _world()
	w.round_no = World.REAPER_ARRIVES - 1
	_wait(w, 1, false)
	var clock := w.actors.filter(func(a): return a.kind == &"saja")
	assert_eq(clock.size(), 1)
	var other := FloorGen.spawn(w, &"saja", Vector2i(45, 3))
	_slay(w, other)
	assert_eq(w.reaper_due, -1, "one the elixir brought starts nothing")
	_slay(w, clock[0])
	assert_eq(w.reaper_due, w.round_no + Curse.gap(0))


func test_a_reaper_still_living_does_not_stop_the_next_from_coming() -> void:
	var w := _world()
	_slay(w, _first(w))
	var out := _wait(w, ROUNDS[1], false)
	assert_eq(out.came.size(), 2)


func test_the_clock_goes_on_after_leaving_the_storey_and_coming_back() -> void:
	var w := _world(2)
	w.stairs = Vector2i(30, 5)
	_slay(w, _first(w))
	_wait(w, 100)
	var due := w.reaper_due
	var step := w.reaper_step
	var round_no := w.round_no
	Storeys.leave(w)
	Storeys.enter(w, 3)
	Storeys.leave(w)
	Storeys.enter(w, 2)
	assert_eq([w.reaper_due, w.reaper_step, w.round_no], [due, step, round_no])
	var clone := w.clone()
	assert_eq([clone.reaper_due, clone.reaper_step], [due, step])
	var out := _wait(w, due - w.round_no)
	assert_eq(out.came.size(), 1)


func test_the_top_storey_has_no_clock() -> void:
	var w := _world(World.FLOORS)
	_slay(w, _first(w))
	assert_eq(_wait(w, 200).came.size(), 0)


func test_the_gap_and_the_distance_stay_at_one_for_any_large_step() -> void:
	for step in [10, 63, 64, 65, 128, 1000]:
		assert_eq(Curse.gap(step), 1, "gap %d" % step)
		assert_eq(Curse.distance(step), 1, "distance %d" % step)


func test_only_the_reaper_whose_fall_starts_the_clock_tells_when_the_next_comes() -> void:
	var w := _world()
	var first := _first(w)
	var other := FloorGen.spawn(w, &"saja", Vector2i(45, 4))
	var told := "재등장: %d초 뒤" % World.REAPER_AGAIN
	assert_string_contains(Info.plain(Info.creature(w, first)), told)
	assert_false(Info.plain(Info.creature(w, other)).contains("재등장"))
	w.depth = World.FLOORS
	assert_false(Info.plain(Info.creature(w, first)).contains("재등장"))
