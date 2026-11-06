extends GutTest
## The death banner tells what felled Miho, and the log opens over it.

const ME := Vector2i(4, 8)


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
	me.hp = 1
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	return w


func _foe(w: World, at: Vector2i) -> Actor:
	var foe := Actor.new()
	foe.id = w.new_id()
	foe.kind = &"dokkaebi"
	foe.faction = Actor.HEAVEN
	foe.hp = 3
	foe.max_hp = 3
	foe.pos = at
	w.actors.append(foe)
	w.sense()
	return foe


func _head(w: World) -> String:
	return Banner.over(w, 0, 1)[0]


func test_a_blow_from_a_seen_creature_names_it() -> void:
	var w := _world()
	var foe := _foe(w, ME + Vector2i.RIGHT)
	foe.brain.alert = 2
	w.emit({t = &"melee", id = foe.id, target = w.player().id, at = ME, n = 1})
	Harm.hurt(w, w.player(), 1)
	assert_eq(_head(w), foe.info().name + "에게 쓰러졌다")


func test_the_sister_falling_heads_the_banner() -> void:
	var w := _world()
	var sister := FloorGen.spawn(w, &"sister", ME + Vector2i(9, 0))
	Harm.hurt(w, sister, 1)
	assert_eq(w.outcome, &"lost")
	assert_eq(_head(w), "여동생이 쓰러졌다")


func test_the_sister_saved_heads_the_banner() -> void:
	var w := _world()
	w.outcome = &"rescued"
	assert_eq(_head(w), "여동생을 구했다")


func test_a_blow_from_an_unseen_creature_names_nobody() -> void:
	var w := _world()
	var foe := _foe(w, ME + Vector2i.RIGHT)
	w.seen[Grid.index(foe.pos)] = 0
	w.emit({t = &"melee", id = foe.id, target = w.player().id, at = ME, n = 1})
	Harm.hurt(w, w.player(), 1)
	assert_eq(_head(w), "쓰러졌다")


func test_a_spell_names_its_caster_when_seen_and_itself_either_way() -> void:
	var w := _world()
	var foe := _foe(w, ME + Vector2i(2, 0))
	var hit := {t = &"hit", shot = 1, id = w.player().id, at = ME, by = foe.id, title = "불길"}
	w.emit(hit)
	Harm.hurt(w, w.player(), 1)
	assert_eq(_head(w), foe.info().name + "의 불길에 쓰러졌다")
	w.seen[Grid.index(foe.pos)] = 0
	assert_eq(_head(w), "불길에 쓰러졌다")


func test_her_own_spell_is_named_alone() -> void:
	var w := _world()
	w.emit({t = &"splash", at = ME, by = w.player().id, title = "여우불"})
	Harm.hurt(w, w.player(), 1)
	assert_eq(_head(w), "여우불에 쓰러졌다")


func test_an_earlier_wound_is_not_the_cause_of_a_later_one() -> void:
	var w := _world()
	w.player().hp = 2
	var foe := _foe(w, ME + Vector2i.RIGHT)
	w.emit({t = &"melee", id = foe.id, target = w.player().id, at = ME, n = 1})
	Harm.hurt(w, w.player(), 1)
	Harm.hurt(w, w.player(), 1)
	assert_eq(_head(w), "쓰러졌다")


func test_fire_and_a_fall_read_as_such() -> void:
	var w := _world()
	w.emit({t = &"burn", at = ME, id = w.player().id})
	Harm.hurt(w, w.player(), 1)
	assert_eq(_head(w), "불에 타 쓰러졌다")
	var fell := _world()
	fell.emit({t = &"fall", id = fell.player().id, from = ME, at = ME, depth = 1})
	Harm.hurt(fell, fell.player(), 1)
	assert_eq(_head(fell), "떨어져 쓰러졌다")


func test_the_log_opens_over_the_banner_and_closes_back_to_it() -> void:
	var m: Node = Built.main()
	add_child_autofree(m)
	Keys.reset()
	m.new_run(7)
	m.state = &"over"
	m.term.banner_lines = Banner.over(m.world, 0, m.run_seed)
	var open := Keys.event(Keys.keys_of(&"log")[0])
	open.pressed = true
	m._unhandled_input(open)
	assert_eq(m.panels.overlay, &"log")
	var shut := Keys.event("Escape")
	shut.pressed = true
	m._unhandled_input(shut)
	assert_eq(m.panels.overlay, &"")
	assert_eq(m.state, &"over")


func test_a_wound_with_its_own_cause_is_not_blamed_on_an_older_event() -> void:
	var w := _world()
	w.emit({t = &"splash", at = ME, by = w.player().id, title = "여우불"})
	w.emit({t = &"scald", id = w.player().id, at = ME, kind = Gas.STEAM})
	Harm.hurt(w, w.player(), 1)
	assert_eq(_head(w), Gas.of(Gas.STEAM, "name") + "에 쓰러졌다")


func test_an_unseen_blow_is_not_blamed_on_an_older_event() -> void:
	var w := _world()
	var foe := _foe(w, ME + Vector2i.RIGHT)
	w.seen[Grid.index(foe.pos)] = 0
	w.emit({t = &"burn", at = ME, id = w.player().id})
	w.emit({t = &"melee", id = foe.id, target = w.player().id, at = ME, n = 1})
	Harm.hurt(w, w.player(), 1)
	assert_eq(_head(w), "쓰러졌다")


func test_a_blast_far_from_her_is_not_the_cause() -> void:
	var w := _world()
	w.emit({t = &"splash", at = ME + Vector2i(5, 0), by = w.player().id, title = "여우불"})
	Harm.hurt(w, w.player(), 1)
	assert_eq(_head(w), "쓰러졌다")


func _lines() -> Array:
	var w := _world()
	var touch: Touch = autofree(Touch.new())
	var lost := Banner.over(w, 12, 123456789)
	w.outcome = &"won"
	return [
		Banner.title(null, false, touch),
		Banner.title(SaveGame.new(), false, touch),
		Banner.title(null, true, touch),
		lost,
		Banner.over(w, 12, 123456789),
	]


func test_a_banner_row_has_the_same_margin_on_both_sides() -> void:
	Lang.locked = false
	for lang in [&"ko", &"en"]:
		Lang.use(lang)
		for view in [Vector2(1280, 720), Vector2(390, 844)]:
			for zoom in [0.0, 1.0, 2.0]:
				for side in [Term.MAP.x, 0]:
					var t: Term = autofree(Term.new())
					t.side = Vector2i(side, 0)
					t.fit(view, zoom)
					for lines: Array in _lines():
						t.banner_lines.assign(lines)
						for row: Array in Banner.rows(t):
							var width := Term.text_cells(row[1])
							var where := (
								"%s %s zoom %s side %d: %s" % [lang, view, zoom, side, row[1]]
							)
							if width <= t.cols:
								var gap: float = row[2].x - (t.cols - row[2].x - width)
								assert_lte(absf(gap), 1.0, where)
							else:
								assert_eq(row[2].x, 0.0, where + " (wider than the screen)")
	Lang.use(&"ko")
	Lang.locked = true
	TranslationServer.set_locale("ko")


func test_a_wall_crash_reads_as_such() -> void:
	var w := _world()
	w.player().hp = 1
	w.set_tile(ME - Vector2i(1, 0), World.WALL)
	w.push(w.player(), -Vector2i(1, 0), 1)
	assert_eq(_head(w), "벽에 부딪혀 쓰러졌다")


func _spent(rounds: int) -> World:
	var w := _world()
	w.rounds = rounds
	w.round_no = 2
	return w


func test_a_run_under_a_minute_tells_seconds_only() -> void:
	assert_eq(Banner.over(_spent(59), 0, 1)[1], "1층 · 59초")


func test_a_run_of_a_minute_or_more_tells_minutes_and_seconds_of_the_whole_run() -> void:
	assert_eq(Banner.over(_spent(60), 0, 1)[1], "1층 · 1분 0초")
	assert_eq(Banner.over(_spent(185), 0, 1)[1], "1층 · 3분 5초")


func test_a_run_that_ends_in_the_house_names_the_house() -> void:
	var w := _spent(59)
	w.depth = World.HOUSE
	assert_eq(Banner.over(w, 0, 1)[1], "집 · 59초")
