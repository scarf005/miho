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


func _play(w: World, cards: Array) -> Dictionary:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	m.new_run(1)
	m.state = &"play"
	m.world = w
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
