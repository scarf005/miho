extends GutTest
## What the map marks, the log tells: both read Perceived's facts.

const SEEN := Vector2i(6, 8)
const HIDDEN := Vector2i(20, 8)
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const ROUNDS := 120
const POPUP_LINE := {
	&"notice": "들켰다",
	&"heed": "살피러 갔다",
	&"drum": "북을 쳤",
	&"hurt": "피해",
	&"card": "부적",
	&"heal": "회복",
	&"noise": "소리를 들었다",
	&"shout": "소리쳤다",
	&"find": "찾았다",
	&"trap": "밟았다",
}

## The log of the same rounds with the debug view off and on, and whether each showed it.
var _logs := []
var _shown := []


## An open hall, Miho at (4, 8), seeing only the tiles near her.
func _world() -> World:
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
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.sense()
	return w


func _lines(before: World, after: World, events: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(Messages.of(before, after, events).map(Messages.plain))
	return out


## The round where a creature at `from` becomes `alert` and walks to `to`.
func _round(from: Vector2i, to: Vector2i, alert: int, events: Array) -> Array:
	var before := _world()
	var foe := FloorGen.spawn(before, &"dokkaebi", from)
	before.sense()
	var after := before.clone()
	var moved := after.actor(foe.id)
	moved.pos = to
	moved.brain.alert = alert
	after.sense()
	return [before, after, foe.id, events]


func test_a_creature_that_noticed_miho_in_the_dark_is_told_once_when_it_comes_into_view() -> void:
	var r := _round(HIDDEN, SEEN, Actor.HUNT, [])
	var events := [
		{t = &"notice", id = r[2], at = HIDDEN},
		{t = &"move", id = r[2], from = HIDDEN, to = SEEN},
	]
	assert_eq(_lines(r[0], r[1], events), ["도깨비가 추격을 시작했다"] as Array[String])
	assert_eq(_lines(r[1], r[1], []), [] as Array[String], "still in view and still hunting")


func test_a_seen_notice_is_told_once() -> void:
	var r := _round(SEEN, SEEN, Actor.HUNT, [])
	var events := [{t = &"notice", id = r[2], at = SEEN}]
	assert_eq(_lines(r[0], r[1], events), ["도깨비에게 들켰다"] as Array[String])
	assert_eq(_lines(r[1], r[1], []), [] as Array[String])


func test_a_seen_heed_is_told_once() -> void:
	var r := _round(SEEN, SEEN, Actor.SEARCH, [])
	var events := [{t = &"heed", id = r[2], kind = &"ash", at = SEEN}]
	assert_eq(_lines(r[0], r[1], events), ["도깨비가 재를 보고 살피러 갔다"] as Array[String])


func test_a_creature_coming_into_view_searching_or_blind_is_told() -> void:
	var r := _round(HIDDEN, SEEN, Actor.SEARCH, [])
	assert_eq(_lines(r[0], r[1], []), ["도깨비가 수색을 시작했다"] as Array[String])
	r[1].actor(r[2]).ailments.blind = 2
	assert_eq(_lines(r[0], r[1], []), ["도깨비가 눈이 멀었다"] as Array[String])
	var seen := _round(SEEN, SEEN, Actor.SEARCH, [])
	seen[1].actor(seen[2]).ailments.blind = 2
	var blinded := [{t = &"blind", id = seen[2]}]
	assert_eq(_lines(seen[0], seen[1], blinded), ["도깨비의 눈이 멀었다"] as Array[String])


func test_a_mark_changing_in_sight_is_told() -> void:
	var r := _round(SEEN, SEEN, Actor.SEARCH, [])
	assert_eq(_lines(r[0], r[1], []), ["도깨비가 수색을 시작했다"] as Array[String])
	assert_eq(_lines(r[1], r[1], []), [] as Array[String])
	r[0].actor(r[2]).brain.alert = Actor.SEARCH
	r[1].actor(r[2]).brain.alert = Actor.HUNT
	assert_eq(_lines(r[0], r[1], []), ["도깨비가 추격을 시작했다"] as Array[String])


func test_a_hidden_notice_gives_no_popup() -> void:
	var r := _round(HIDDEN, HIDDEN, Actor.HUNT, [])
	var events := [{t = &"notice", id = r[2], at = HIDDEN}]
	assert_eq(Perceived.of(r[0], r[1], events).facts, [] as Array[Dictionary])
	var seen := _round(SEEN, SEEN, Actor.HUNT, [])
	var facts := Perceived.of(seen[0], seen[1], [{t = &"notice", id = seen[2], at = SEEN}]).facts
	assert_eq(facts.map(Perceived.popup_of).map(func(p): return p.text), ["!"])


## A scripted round: step towards the nearest creature most of the time.
func _action(w: World, rng: RandomNumberGenerator) -> Dictionary:
	var me := w.player()
	var foes := w.actors.filter(func(a): return a.alive() and a.faction != Actor.FOX)
	var dirs := Grid.DIRS.filter(func(d): return w.can({t = &"move", dir = d}))
	if dirs.is_empty() or rng.randf() < 0.1:
		return {t = &"wait"}
	if not foes.is_empty() and rng.randf() < 0.6:
		foes.sort_custom(func(a, b): return Grid.cheb(a.pos, me.pos) < Grid.cheb(b.pos, me.pos))
		dirs.sort_custom(
			func(a, b):
				return Grid.cheb(me.pos + a, foes[0].pos) < Grid.cheb(me.pos + b, foes[0].pos)
		)
		return {t = &"move", dir = dirs[0]}
	return {t = &"move", dir = dirs[rng.randi_range(0, dirs.size() - 1)]}


func _in_sight(w: World, a: Actor) -> bool:
	return a.alive() and Perceived.sees(w.seen, a.pos)


func test_every_mark_on_the_map_was_told_and_every_popup_has_a_line() -> void:
	var told_marks := 0
	var popups := 0
	for seed_value in SEEDS:
		var w := Built.world(seed_value)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		## id -> the mark Miho was last told since the creature came into sight.
		var told := {}
		for round_no in ROUNDS:
			if w.outcome != &"":
				break
			var before := w.clone()
			var events := w.act(_action(w, rng))
			var facts := Perceived.of(before, w, events).facts
			var lines := _lines(before, w, events)
			var ctx := "seed %d round %d" % [seed_value, round_no]
			for a in w.actors:
				var was := before.actor(a.id)
				if was == null or not _in_sight(before, was) or not _in_sight(w, a):
					told.erase(a.id)
			for f in facts:
				match f.t:
					&"notice":
						told[f.id] = "!"
					&"heed":
						told[f.id] = "?"
					&"blind":
						told[f.id] = "x"
					&"state":
						told[f.id] = f.mark
						told_marks += 1
						assert_true(
							lines.any(func(l): return l.contains(Messages.STATE[f.mark])), ctx
						)
				var text: String = POPUP_LINE.get(f.t, "")
				if not Perceived.popup_of(f).is_empty():
					popups += 1
					assert_true(lines.any(func(l): return l.contains(text)), "%s %s" % [ctx, f.t])
			for a in w.actors:
				var mark := Perceived.mark_of(a)
				if a.faction != Actor.FOX and mark != "" and _in_sight(w, a):
					assert_eq(told.get(a.id, ""), mark, "%s creature %d" % [ctx, a.id])
	assert_gt(told_marks, 0, "the scripted rounds meet creatures in a state the map marks")
	assert_gt(popups, 0, "the scripted rounds show popups")


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(2)
	m.state = &"play"
	m.term.speed = 1000.0
	return m


func before_all() -> void:
	for debugging in [false, true]:
		var m := _main()
		m.debugging = debugging
		m._refresh()
		_shown.append(not m.term.debug.is_empty())
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for round_no in 40:
			await m._act(_action(m.world, rng))
		_logs.append(m.messages.lines.map(func(l): return l.text))
		m.queue_free()


func test_the_debug_view_does_not_change_the_log() -> void:
	assert_eq(_shown, [false, true])
	assert_gt(_logs[0].size(), 0, "the rounds tell something")
	assert_eq(_logs[0], _logs[1])


func test_a_noise_on_a_seen_tile_is_no_fact() -> void:
	var w := _world()
	var noise := {t = &"noise", at = SEEN, word = "삐걱", loud = 3, heard = false}
	var p := Perceived.of(w, w, [noise])
	assert_eq(p.facts, [] as Array[Dictionary], "the log and the sound tell nothing twice")


func test_a_noise_out_of_sight_pops_its_bare_word() -> void:
	var w := _world()
	var noise := {t = &"noise", at = HIDDEN, word = "쾅", loud = 9, heard = true}
	var p := Perceived.of(w, w, [noise])
	assert_eq(p.facts.map(Perceived.popup_of).map(func(q): return q.text), ["쾅"])
	var quiet := noise.merged({heard = false}, true)
	assert_eq(Perceived.of(w, w, [quiet]).facts, [] as Array[Dictionary], "out of earshot")


func test_a_shout_pops_its_bare_word_once() -> void:
	var w := _world()
	var shout := {t = &"shout", id = w.player().id, at = SEEN, word = "낄낄", loud = 6}
	var noise := {t = &"noise", at = SEEN, word = "낄낄", loud = 6, heard = true}
	var p := Perceived.of(w, w, [shout, noise])
	assert_eq(p.facts.map(Perceived.popup_of).map(func(q): return q.text), ["낄낄"])


func test_the_reapers_omen_is_told_wherever_she_stands() -> void:
	var w := _world()
	w.start = HIDDEN
	w.round_no = World.REAPER_OMEN - 1
	var before := w.clone()
	var events := w.act({t = &"wait"})
	assert_true(Perceived.of(before, w, events).facts.any(func(f): return f.t == &"omen"))
