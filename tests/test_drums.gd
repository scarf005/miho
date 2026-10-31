extends GutTest
## War drums: a sharp creature runs to one when it starts hunting and beats it,
## and the boom sends the whole storey to search where Miho was last seen.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const DRUM_AT := Vector2i(20, 8)


## An open hall walled at the edges with no light, a drum at DRUM_AT, Miho at (4, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	_put(w, DRUM_AT, World.DRUM)
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.depth = 4
	w.tails = 4
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t


func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


## A creature that has just noticed Miho, `at` tiles from the drum along its row.
func _drummer(w: World, at := Vector2i(16, 8), kind := &"dokkaebi") -> Actor:
	var a := _foe(w, kind, at)
	w.hunt_from(a, w.player().pos)
	return a


## Waits until a creature strikes the drum (at most `limit` rounds); the events of all rounds.
func _until_struck(w: World, limit := 10) -> Array:
	var all := []
	for i in limit:
		var events := w.act(WAIT)
		all.append_array(events)
		if events.any(func(e): return e.t == &"drum"):
			break
	return all


func _booms(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"noise" and e.word == "둥")


func test_a_sharp_creature_that_starts_hunting_near_a_drum_plans_to_strike_it() -> void:
	var w := _world()
	var a := _drummer(w)
	assert_eq(a.drum, DRUM_AT)
	assert_true(a.drumming())


func test_a_dull_creature_ignores_the_drum() -> void:
	var w := _world()
	var a := _drummer(w, Vector2i(16, 8), &"jangseung")
	assert_eq(Bestiary.wits(&"jangseung"), Bestiary.DULL)
	assert_eq(a.drum, Drums.NONE)
	var b := _drummer(w, Vector2i(16, 10), &"cheonha")
	assert_eq(b.drum, Drums.NONE)
	var c := _drummer(w, Vector2i(17, 8), &"dokkaebi")
	assert_eq(c.drum, DRUM_AT, "a sharp one does not")


func test_a_drum_beyond_walking_reach_is_ignored_however_near_it_looks() -> void:
	var w := _world()
	var far := _drummer(w, DRUM_AT + Vector2i(Drums.REACH + 2, 0))
	assert_eq(far.drum, Drums.NONE, "too far")
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(22, y), World.WALL)
	var behind := _drummer(w, Vector2i(23, 8))
	assert_eq(behind.drum, Drums.NONE, "a wall between: the way round is long")
	_put(w, Vector2i(22, 8), World.DOOR_OPEN)
	var through := _drummer(w, Vector2i(23, 9))
	assert_eq(through.drum, DRUM_AT, "through the open door it is near")


func test_the_creature_runs_to_the_drum_and_strikes_it_instead_of_attacking() -> void:
	var w := _world()
	w.player().pos = Vector2i(15, 8)
	var a := _drummer(w, Vector2i(16, 9))
	assert_eq(Grid.cheb(a.pos, w.player().pos), 1, "next to Miho, melee in reach")
	var hp := w.player().hp
	var events: Array = w.act(WAIT)
	assert_eq(w.player().hp, hp, "it did not strike her")
	assert_eq(events.filter(func(e): return e.t == &"melee").size(), 0)
	assert_gt(a.pos.x, 16, "it ran")
	events = _until_struck(w)
	assert_eq(events.filter(func(e): return e.t == &"drum" and e.id == a.id).size(), 1)
	assert_eq(a.drum, Drums.NONE, "done, it hunts as usual")
	assert_eq(a.alert, Actor.HUNT)


func test_the_boom_reaches_every_heaven_creature_and_sends_it_to_the_spot_of_sight() -> void:
	var w := _world()
	for y in range(1, Grid.H - 1):
		_put(w, Vector2i(30, y), World.WALL)
	var a := _drummer(w)
	a.target = Vector2i(7, 9)
	var sealed := _foe(w, &"imugi", Vector2i(45, 20))
	var resting := _foe(w, &"dokkaebi", Vector2i(26, 3))
	var hunting := _foe(w, &"imugi", Vector2i(40, 5))
	hunting.alert = Actor.HUNT
	hunting.target = Vector2i(50, 24)
	var statue := _foe(w, &"jangseung", Vector2i(35, 8))
	var events := _until_struck(w)
	assert_eq(_booms(events).size(), 1)
	assert_eq(_booms(events)[0].loud, Drums.LOUD)
	for b: Actor in [sealed, resting]:
		assert_eq(b.alert, Actor.SEARCH, b.kind)
		assert_eq(b.target, a.target, "where the drummer last saw Miho")
	assert_eq(hunting.alert, Actor.HUNT)
	assert_eq(hunting.target, Vector2i(50, 24), "already hunting, it keeps its prey")
	assert_eq(statue.alert, Actor.REST, "deaf")


func test_miho_hears_the_boom_wherever_she_is_on_the_storey() -> void:
	var w := _world()
	w.player().pos = Vector2i(2, 26)
	_drummer(w)
	var heard := []
	for i in 10:
		w.act(WAIT)
		heard.append_array(w.heard)
		if heard.any(func(h): return h.word == "둥"):
			break
	assert_true(heard.any(func(h): return h.word == "둥" and h.at == DRUM_AT))


func test_a_wet_drum_makes_no_sound_and_dries_after_its_time() -> void:
	var w := _world()
	w.wet[DRUM_AT] = 8
	var a := _drummer(w)
	var bystander := _foe(w, &"imugi", Vector2i(40, 20))
	var events := _until_struck(w)
	var drum: Dictionary = events.filter(func(e): return e.t == &"drum")[0]
	assert_true(drum.wet)
	assert_eq(_booms(events).size(), 0, "silent")
	assert_eq(bystander.alert, Actor.REST)
	assert_eq(a.drum, Drums.NONE)
	assert_true(w.wet.has(DRUM_AT), "still wet")
	for i in 8:
		w.act(WAIT)
	assert_false(w.wet.has(DRUM_AT), "dry again")
	var b := _drummer(w, Vector2i(16, 8))
	events = _until_struck(w)
	assert_eq(_booms(events).size(), 1, "dry, it sounds")
	assert_eq(b.drum, Drums.NONE)


func test_a_water_spell_beside_a_drum_wets_it_and_puts_out_its_fire() -> void:
	for cards: Array in [[Cards.FOX, Cards.WATER], [Cards.ORB, Cards.WATER]]:
		var w := _world()
		w.cards.append(Cards.WATER)
		w.player().pos = Vector2i(15, 8)
		w.burning[DRUM_AT] = 3
		w.act({t = &"cast", spells = [{cards = cards, dir = E}]})
		for i in 5:
			w.act(WAIT)
		assert_true(w.wet.has(DRUM_AT), str(cards))
		assert_between(w.wet[DRUM_AT], Drums.WET_ROUNDS - 6, Drums.WET_ROUNDS)
		assert_false(w.burning.has(DRUM_AT), "doused")
		assert_eq(w.tile(DRUM_AT), World.DRUM, "water does not tear it")


func test_an_orb_tears_a_drum_and_a_fox_wisp_does_not() -> void:
	var w := _world()
	w.player().pos = Vector2i(15, 8)
	w.act({t = &"cast", spells = [{cards = [Cards.FOX], dir = E}]})
	assert_eq(w.tile(DRUM_AT), World.DRUM)
	var orb := _world()
	orb.player().pos = Vector2i(15, 8)
	orb.wet[DRUM_AT] = 9
	var events := orb.act({t = &"cast", spells = [{cards = [Cards.ORB], dir = E}]})
	events.append_array(orb.act(WAIT))
	assert_eq(orb.tile(DRUM_AT), World.DRUM_TORN)
	assert_false(orb.wet.has(DRUM_AT))
	assert_true(events.any(func(e): return e.t == &"smash" and e.was == World.DRUM))


func test_miho_walking_into_a_drum_tears_it_with_a_noise_heaven_investigates() -> void:
	var w := _world()
	w.player().pos = Vector2i(19, 8)
	var foe := _foe(w, &"imugi", Vector2i(24, 8))
	var action := {t = &"move", dir = E}
	assert_true(w.can(action))
	var events := w.act(action)
	assert_eq(w.tile(DRUM_AT), World.DRUM_TORN)
	assert_eq(w.player().pos, Vector2i(19, 8), "she stays put")
	var noise: Dictionary = events.filter(func(e): return e.t == &"noise")[0]
	assert_eq([noise.word, noise.loud], ["찌익", World.KNOCK])
	assert_eq(foe.alert, Actor.SEARCH, "it heard the tear, not a drum")
	assert_eq(foe.target, DRUM_AT)
	w.act(action)
	assert_eq(w.player().pos, DRUM_AT, "a torn drum can be walked over")


func test_a_torn_drum_is_not_struck_and_a_creature_running_to_it_gives_up() -> void:
	var w := _world()
	var a := _drummer(w)
	w.act(WAIT)
	assert_true(a.drumming())
	_put(w, DRUM_AT, World.DRUM_TORN)
	var events := _until_struck(w, 5)
	assert_eq(events.filter(func(e): return e.t == &"drum").size(), 0)
	assert_eq(a.drum, Drums.NONE)
	var later := _drummer(w, Vector2i(17, 8))
	assert_eq(later.drum, Drums.NONE, "no whole drum within reach")


func test_a_burning_drum_is_not_struck_and_burns_to_ash() -> void:
	var w := _world()
	w.burning[DRUM_AT] = World.BURN_ROUNDS
	assert_eq(_drummer(w).drum, Drums.NONE)
	for i in 4:
		w.act(WAIT)
	assert_eq(w.tile(DRUM_AT), World.ASH)


func test_the_view_marks_a_creature_on_its_way_to_the_drum() -> void:
	var w := _world()
	w.player().pos = Vector2i(18, 8)
	var a := _drummer(w)
	w.sense()
	var hover := Info.plain(Info.creature(w, a))
	assert_string_contains(hover, "북 치러 가는 중.")
	assert_string_contains(Observation.text(w), "running to the drum at (20,8)")
	_until_struck(w)
	assert_false(Info.plain(Info.creature(w, a)).contains("북 치러 가는 중."))


func test_hovering_a_drum_shows_every_value() -> void:
	var w := _world()
	w.sense()
	var dry := Info.plain(Info.terrain(w, DRUM_AT))
	assert_string_contains(dry, "북 ♥")
	assert_string_contains(dry, "소리: 칠 때 층 전체")
	assert_false(dry.contains("둥"), dry)
	assert_string_contains(dry, "걸어서 %d칸" % Drums.REACH)
	assert_string_contains(dry, "영리한 적")
	assert_string_contains(dry, "찢어짐: 구슬")
	assert_string_contains(dry, "물: %d초 소리 없음" % Drums.WET_ROUNDS)
	w.wet[DRUM_AT] = 7
	assert_string_contains(Info.plain(Info.terrain(w, DRUM_AT)), "젖음: 7초. 소리 없음")
	_put(w, DRUM_AT, World.DRUM_TORN)
	assert_string_contains(Info.plain(Info.terrain(w, DRUM_AT)), "찢어진 북")


func test_the_log_tells_the_blow() -> void:
	var w := _world()
	w.sense()
	var a := _foe(w, &"dokkaebi", Vector2i(5, 8))
	var loud := Messages.of(w, w, [{t = &"drum", at = Vector2i(5, 9), id = a.id, wet = false}])
	assert_eq(loud.map(Messages.plain), ["도깨비가 북을 쳤다"])
	var soaked := Messages.of(w, w, [{t = &"drum", at = Vector2i(5, 9), id = a.id, wet = true}])
	assert_eq(soaked.map(Messages.plain), ["도깨비가 젖은 북을 쳤지만 소리가 나지 않았다"])
	assert_eq(
		Messages.of(w, w, [{t = &"soak", at = Vector2i(5, 9)}]).map(Messages.plain), ["북이 젖었다"]
	)


func test_a_preview_of_a_round_with_a_drummer_equals_the_real_round() -> void:
	var w := _world()
	w.player().pos = Vector2i(15, 8)
	_drummer(w, Vector2i(19, 9))
	var other := _foe(w, &"imugi", Vector2i(40, 20))
	for i in 3:
		var ahead := w.preview(WAIT)
		w.act(WAIT)
		assert_eq(ahead.heard, w.heard, "round %d" % i)
		assert_eq(
			ahead.actors.map(func(x): return [x.pos, x.alert, x.target, x.drum]),
			w.actors.map(func(x): return [x.pos, x.alert, x.target, x.drum])
		)
	assert_eq(other.alert, Actor.SEARCH)


func test_drums_stand_in_lit_rooms_from_tier_two_and_never_cut_the_storey() -> void:
	var drums := 0
	for s in 30:
		for depth in [1, 4]:
			var w := World.new()
			w.rng.seed = s
			w.depth = depth
			var me := Actor.new()
			me.id = w.new_id()
			me.kind = &"miho"
			me.faction = Actor.FOX
			me.hp = 3
			w.actors.append(me)
			FloorGen.build(w)
			var at := w.tiles.find(World.DRUM)
			assert_true(at < 0 or depth >= 4, "no drum on tier 1")
			if at < 0:
				continue
			drums += 1
			var p := Grid.at(at)
			assert_true(w.rooms.any(func(r): return r.has_point(p)), "in a room")
			assert_true(w.lit(p), "in a lit room")
			assert_eq(w.tiles.count(World.DRUM), 1, "one a storey")
			var dist: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
			assert_gte(dist[Grid.index(w.stairs)], 0)
	assert_gt(drums, 3, "some storeys of tier 2 have one")
	assert_lt(drums, 30, "not all")


func test_the_agent_reads_the_drum_on_the_map_and_among_its_moves() -> void:
	var w := _world()
	w.player().pos = Vector2i(19, 8)
	w.sense()
	var text := Observation.text(w)
	assert_string_contains(text, "◎drum ◌torn-drum")
	assert_string_contains(text, "e(tear drum)")
	assert_string_contains(Observation.text(w), "◎")
