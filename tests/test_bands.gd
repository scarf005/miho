extends GutTest
## Creatures of one group come in bands: they stand together in a room and follow
## the strongest of them, their leader. When the leader falls the band scatters.

const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)
const SEEDS := [1, 2, 3, 5, 8]


## An unlit open hall, every tile known and seen, Miho at ME.
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
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 2
	w.tails = 4
	return w


func _band(w: World, leader: Actor, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.leader = leader.id
	a.cooldown = 99
	return a


func _storey(seed_value: int, depth: int) -> World:
	var w := World.create(seed_value)
	w.depth = depth
	FloorGen.build(w)
	return w


func _leaders(w: World) -> Array[Actor]:
	var out: Array[Actor] = []
	out.assign(w.actors.filter(func(a): return w.actors.any(func(b): return b.leader == a.id)))
	return out


func test_bands_split_the_mobile_creatures_of_a_group_evenly_under_the_cap() -> void:
	var sizes := func(kinds: Array) -> Array:
		return FloorGen.bands(kinds).map(func(b): return b.size())
	assert_eq(sizes.call([&"dokkaebi", &"dokkaebi", &"dokkaebi", &"dokkaebi"]), [2, 2])
	assert_eq(sizes.call([&"dokkaebi", &"dokkaebi", &"dokkaebi"]), [3])
	assert_eq(sizes.call([&"dokkaebi"]), [1])
	assert_eq(sizes.call(([&"imugi"] as Array).duplicate()), [1])
	var five := FloorGen.bands([&"oedari", &"dokkaebi", &"dokkaebi", &"dokkaebi", &"dokkaebi"])
	assert_eq(five.map(func(b): return b.size()), [3, 2])
	for band in five:
		assert_lte(band.size(), FloorGen.BAND)


func test_a_band_is_of_one_group_led_by_its_strongest() -> void:
	var mixed := FloorGen.bands([&"dokkaebi", &"imugi", &"oedari", &"imugi", &"dokkaebi"])
	assert_eq(mixed.size(), 2)
	for band in mixed:
		var groups: Array = band.map(func(k): return Bestiary.info(k).group)
		assert_eq(groups.filter(func(g): return g != groups[0]).size(), 0)
	var dokkaebi: Array = mixed.filter(func(b): return b.has(&"oedari"))[0]
	assert_eq(dokkaebi[0], &"oedari", "3 health against 2")


func test_standing_creatures_and_bosses_come_alone() -> void:
	assert_eq(FloorGen.bands([&"jangseung", &"jangseung", &"cheonnyeon"]), [])
	assert_false(Bestiary.bands(&"jangseung"))
	assert_false(Bestiary.bands(&"cheonnyeon"))
	assert_true(Bestiary.bands(&"dokkaebi"))


func test_each_follower_stands_beside_its_leader_in_one_room() -> void:
	var bands := 0
	for seed_value in SEEDS:
		for depth in [1, 2, 3, 5, 8]:
			var w := _storey(seed_value, depth)
			for lead in _leaders(w):
				bands += 1
				assert_eq(lead.leader, 0, "a leader follows nobody")
				var room := w.rooms.filter(func(r): return r.has_point(lead.pos))
				assert_eq(room.size(), 1)
				for f in w.actors.filter(func(a): return a.leader == lead.id):
					var ctx := "seed %d depth %d %s" % [seed_value, depth, f.kind]
					assert_true(Bestiary.allied(f.kind, lead.kind), ctx)
					assert_lte(Grid.cheb(f.pos, lead.pos), FloorGen.BAND_SPREAD, ctx)
					assert_true(room[0].has_point(f.pos), ctx)
					assert_lte(f.max_hp, lead.max_hp, ctx + " is no stronger than its leader")
	assert_gt(bands, 0, "bands appear")


func test_every_creature_of_the_plan_still_spawns_and_is_deterministic() -> void:
	for depth in [1, 2, 3, 5, 8]:
		var a := _storey(3, depth)
		var b := _storey(3, depth)
		var want: int = (
			FloorGen
			. PLAN[a.depth]
			. filter(func(k): return not Bestiary.info(k).get("boss", false))
			. size()
		)
		var guards := a.sites.filter(func(s): return s.kind in [&"yard", &"creak"]).size()
		assert_eq(a.actors.size() - 1, want + guards, "depth %d" % depth)
		assert_eq(
			a.actors.map(func(x): return [x.kind, x.pos, x.leader]),
			b.actors.map(func(x): return [x.kind, x.pos, x.leader])
		)


func test_a_resting_follower_keeps_up_with_a_walking_leader() -> void:
	var w := _hall()
	var lead := FloorGen.spawn(w, &"oedari", Vector2i(30, 8))
	lead.cooldown = 99
	var f := _band(w, lead, &"dokkaebi", Vector2i(30, 11))
	lead.post = Vector2i(50, 8)
	for i in 12:
		w.act(WAIT)
	assert_gt(lead.pos.x, 35, "the leader patrols")
	assert_lte(Grid.cheb(f.pos, lead.pos), FloorGen.BAND_SPREAD + 1)


func test_a_follower_beside_its_leader_stays_put() -> void:
	var w := _hall()
	var lead := FloorGen.spawn(w, &"oedari", Vector2i(30, 8))
	lead.cooldown = 99
	lead.post = lead.pos
	var f := _band(w, lead, &"dokkaebi", Vector2i(31, 9))
	var at := f.pos
	f.post = f.pos
	w.act(WAIT)
	assert_eq(f.pos, at)


func test_a_sleeping_band_stays_asleep_and_wakes_alone() -> void:
	var w := _hall()
	var lead := FloorGen.spawn(w, &"imugi", Vector2i(30, 8))
	var f := _band(w, lead, &"imugi", Vector2i(32, 8))
	lead.cooldown = 99
	assert_true(lead.asleep())
	assert_true(f.asleep())
	w.act(WAIT)
	assert_eq([lead.pos, f.pos], [Vector2i(30, 8), Vector2i(32, 8)])
	lead.alert = Actor.SEARCH
	lead.target = Vector2i(40, 8)
	w.act(WAIT)
	assert_true(f.asleep(), "the leader moving off does not wake it")
	assert_eq(f.pos, Vector2i(32, 8))


func test_a_follower_that_does_not_patrol_goes_home_to_sleep() -> void:
	var w := _hall()
	var lead := FloorGen.spawn(w, &"imugi", Vector2i(30, 8))
	var f := _band(w, lead, &"imugi", Vector2i(32, 8))
	lead.cooldown = 99
	f.pos = Vector2i(34, 8)
	w.act(WAIT)
	assert_eq(f.pos, Vector2i(33, 8))


func test_when_the_leader_falls_the_band_scatters() -> void:
	var w := _hall()
	var lead := FloorGen.spawn(w, &"oedari", Vector2i(30, 8))
	var f := _band(w, lead, &"dokkaebi", Vector2i(31, 8))
	var g := _band(w, lead, &"bitjaru", Vector2i(31, 9))
	var other := FloorGen.spawn(w, &"oedari", Vector2i(10, 4))
	var kin := _band(w, other, &"dokkaebi", Vector2i(11, 4))
	w.hurt(lead, 3)
	assert_false(lead.alive())
	assert_eq([f.leader, g.leader], [0, 0])
	assert_eq(kin.leader, other.id, "another band is left alone")
	assert_true(w.events.any(func(e): return e.t == &"scatter" and e.id == lead.id))
	assert_eq(w.events.filter(func(e): return e.t == &"scatter").size(), 1)


func test_a_leader_pushed_into_the_sky_scatters_the_band_too() -> void:
	var w := _hall()
	w.tiles[Grid.index(Vector2i(31, 8))] = World.SKY
	var lead := FloorGen.spawn(w, &"oedari", Vector2i(30, 8))
	var f := _band(w, lead, &"dokkaebi", Vector2i(29, 8))
	w.push(lead, Vector2i(1, 0), 1)
	assert_false(lead.alive())
	assert_eq(f.leader, 0)


func test_a_lone_creature_falling_scatters_nothing() -> void:
	var w := _hall()
	var lone := FloorGen.spawn(w, &"oedari", Vector2i(30, 8))
	w.hurt(lone, 3)
	assert_false(w.events.any(func(e): return e.t == &"scatter"))


func test_a_follower_reads_following() -> void:
	var w := _hall()
	var lead := FloorGen.spawn(w, &"oedari", Vector2i(30, 8))
	var f := _band(w, lead, &"dokkaebi", Vector2i(31, 8))
	assert_eq(Info.state(f), "따라가는 중")
	assert_string_contains(Info.plain(Info.creature(w, f)), "따라가는 중")


func test_a_sleeping_follower_reads_asleep() -> void:
	var w := _hall()
	var lead := FloorGen.spawn(w, &"imugi", Vector2i(30, 8))
	var f := _band(w, lead, &"imugi", Vector2i(32, 8))
	assert_eq(Info.state(f), "자는 중")


func test_no_hover_or_doc_tells_bands_or_groups() -> void:
	var w := _hall()
	var lead := FloorGen.spawn(w, &"oedari", Vector2i(30, 8))
	var f := _band(w, lead, &"dokkaebi", Vector2i(31, 8))
	w.seen.fill(1)
	for kind in [&"dokkaebi", &"jangseung", &"cheonnyeon"]:
		var text := Info.plain(Info.creature_facts(Codex.foe(kind), []))
		assert_false(text.contains("무리") or text.contains("우두머리"), str(kind))
	for a in [lead, f]:
		var text := Info.plain(Info.creature(w, a))
		assert_false(text.contains("무리") or text.contains("우두머리"), text)


func test_the_agent_tells_the_band_and_the_log_tells_no_scattering() -> void:
	var w := _hall()
	var lead := FloorGen.spawn(w, &"oedari", Vector2i(30, 8))
	var f := _band(w, lead, &"dokkaebi", Vector2i(31, 8))
	lead.hp = 1
	var before := w.clone()
	var events: Array[Dictionary] = []
	w.events = events
	w.hurt(lead, 1)
	var lines := Messages.of(before, w, events).map(func(l): return Messages.plain(l))
	assert_true(events.any(func(e): return e.t == &"scatter"), "the band scatters")
	assert_false(lines.any(func(l): return l.contains("무리")), str(lines))
	var again := _hall()
	var boss := FloorGen.spawn(again, &"oedari", Vector2i(30, 8))
	_band(again, boss, &"dokkaebi", Vector2i(31, 8))
	var text := Observation.text(again)
	assert_string_contains(text, "leads a band")
	assert_string_contains(text, "follows 외다리 도깨비")
	assert_eq(f.leader, 0)
