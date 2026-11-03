extends GutTest
## 낙뢰 is lightning: it strikes in the round it is cast with nothing in flight, and every
## tile it covers flickers as a creature's 번개 does (TermMarks.bolt).

const E := Vector2i(1, 0)
const ME := Codex.ME


func _stage() -> World:
	var w := Codex.stage()
	w.depth = 5
	w.tails = 20
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _main(w: World) -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	m.new_run(1)
	m.state = &"play"
	m.world = w
	return m


func _play(w: World, cards: Array) -> Dictionary:
	var m := _main(w)
	var before := w.clone()
	var events := w.act({t = &"cast", spells = [{cards = cards, dir = E}]})
	m.term.play(events, before, w)
	var out := {
		events = events,
		flashes = m.term.anim.flashes.duplicate(),
		shots = w.shots.size(),
		seen = func(p: Vector2i) -> bool: return m.term.sees(p),
	}
	m.term.rush()
	return out


func test_thunder_strikes_in_its_round_with_nothing_left_in_flight() -> void:
	var w := _stage()
	var foe := FloorGen.spawn(w, &"jangseung", ME + E * 3)
	foe.hp = 99
	foe.max_hp = 99
	var seen := _play(w, Cards.recipe(&"thunder"))
	assert_lt(foe.hp, 99)
	assert_eq(seen.shots, 0)
	assert_true(seen.events.filter(func(e): return e.t in [&"spawn", &"fly"]).is_empty())


func test_thunder_flickers_on_every_tile_it_covers() -> void:
	var w := _stage()
	var seen := _play(w, Cards.recipe(&"thunder"))
	var tiles: Array = seen.events.filter(func(e): return e.t == &"spray")[0].tiles
	tiles = tiles.filter(seen.seen)
	assert_false(tiles.is_empty())
	for p: Vector2i in tiles:
		assert_true(seen.flashes.any(func(f): return f.at == p and f.zap), str(p))


func test_a_creature_s_bolt_flickers_on_its_whole_line_the_moment_the_round_plays() -> void:
	var w := _stage()
	var general := FloorGen.spawn(w, &"jiha", ME + Vector2i(-3, 2))
	general.magic.cooldown = 99
	var m := _main(w)
	var before := w.clone()
	w.events = []
	Cast.cast(w, general, Bestiary.spell(&"jiha", [Cards.FOX, Cards.METAL]), E)
	var flown: Array = w.events.filter(func(e): return e.t == &"fly")
	m.term.play(w.events, before, w)
	var path: Array = flown.map(func(e): return e.to).filter(func(p): return m.term.sees(p))
	assert_gt(path.size(), 1)
	for p: Vector2i in path:
		assert_true(m.term.anim.flashes.any(func(f): return f.at == p and f.zap), str(p))
	m.term.rush()


## Seconds from the cast until nothing of the round is drawn but popups, with `n` foes in a
## row, each one tile on from the last, and the most popups shown at once.
func _length(n: int) -> Array:
	var w := _stage()
	for i in n:
		var foe := FloorGen.spawn(w, &"jangseung", ME + E * (2 + i))
		foe.hp = 99
		foe.max_hp = 99
	var m := _main(w)
	var before := w.clone()
	var events := w.act({t = &"cast", spells = [{cards = Cards.recipe(&"thunder"), dir = E}]})
	await wait_process_frames(10)
	var start: float = m.term.time
	var popups := 0
	m.term.play(events, before, w)
	await wait_process_frames(1)
	while m.term.anim.playing or not m.term.anim.flashes.is_empty():
		popups = maxi(popups, m.term.anim.popups.size())
		await wait_process_frames(1)
	return [m.term.time - start, popups]


func test_thunder_chain_takes_one_strike_plus_a_stagger_not_a_strike_per_arc() -> void:
	var one := await _length(1)
	var four := await _length(4)
	gut.p("1 foe %.2f s, 4 foes %.2f s" % [one[0], four[0]])
	assert_lt(four[0], one[0] + 0.3)


func test_thunder_chain_still_pops_up_a_hit_on_every_foe() -> void:
	var four := await _length(4)
	assert_gte(four[1], 4)
