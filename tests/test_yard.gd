extends GutTest
## 장승 마당: a guard that never sleeps, a lit yard with bamboo and pillars to
## hide behind, and the talisman on the stand.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ROOM := Rect2i(10, 5, 11, 5)
const DOOR := Vector2i(9, 7)
const GUARD := Vector2i(20, 7)
const STAND := Vector2i(19, 7)
const SEEDS := 24
const DEPTHS := [1, 7, 13, 25]

var _storeys: Array[World] = []


func before_all() -> void:
	for seed_value in SEEDS:
		for depth in DEPTHS:
			var w := World.create(seed_value)
			w.depth = depth
			FloorGen.build(w)
			_storeys.append(w)


func _label(w: World) -> String:
	return "seed %d storey %d" % [w.rng.seed, w.depth]


## ROOM cut into a wall with a door at DOOR, Miho outside it at (6, 7) with no
## talisman but fox and orb. The yard is not laid yet.
func _hall() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(ROOM.position.y, ROOM.end.y):
		for x in range(ROOM.position.x, ROOM.end.x):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for x in range(4, 10):
		w.tiles[Grid.index(Vector2i(x, 7))] = World.FLOOR
	w.rooms.assign([ROOM])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(6, 7)
	w.actors.append(me)
	w.depth = 4
	w.tails = 3
	return w


func _yard(card := Cards.WATER) -> World:
	var w := _hall()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_true(Yard.make(w, ROOM, rng))
	w.sites[0].card = card
	w.sense()
	return w


func _guard(w: World) -> Actor:
	return w.actor_at(GUARD)


func _step_onto(w: World, p: Vector2i) -> Array[Dictionary]:
	w.player().pos = p - E
	return w.act({t = &"move", dir = E})


# --- where it lies -----------------------------------------------------------


func test_some_storeys_have_a_yard_with_a_guard_and_a_stand_in_a_room_of_their_own() -> void:
	var found := 0
	for w in _storeys:
		for site: Dictionary in w.sites:
			if site.kind != &"yard":
				continue
			found += 1
			assert_eq(w.sites.size() + w.seals.size(), 1, "one event room: " + _label(w))
			assert_eq(w.tile(site.at), World.TALISMAN)
			var guards := w.actors.filter(func(a): return a.guard)
			assert_eq(guards.size(), 1, _label(w))
			assert_eq(guards[0].kind, &"jangseung")
			assert_eq(Grid.cheb(guards[0].pos, site.at), 1, "by the stand")
			assert_true(w.rooms.all(func(r): return not r.has_point(site.at)), "off the room list")
			assert_true(FloorGen.connected(w), _label(w))
			assert_false(guards[0].asleep(), "awake")
			assert_true(w.tiles.has(World.LAMP), "lamps")
			for a in w.actors.slice(1):
				if a != guards[0]:
					assert_gt(Grid.cheb(a.pos, site.at), 1, "no other creature by the stand")
	assert_gt(found, 0, "some storey has a yard")


func test_a_seed_builds_the_same_yard_every_time() -> void:
	for seed_value in 4:
		var a := World.create(seed_value)
		var b := World.create(seed_value)
		assert_eq(a.sites, b.sites)
		assert_eq(a.tiles, b.tiles)


func test_make_lays_the_guard_the_stand_the_pillars_and_the_grove_far_from_the_door() -> void:
	var w := _yard()
	assert_eq(w.sites, [{kind = &"yard", at = STAND, card = Cards.WATER}])
	assert_eq(_guard(w).kind, &"jangseung")
	assert_true(_guard(w).guard)
	assert_eq(w.tile(STAND), World.TALISMAN)
	for dy in [-1, 1]:
		assert_eq(w.tile(GUARD + Vector2i(-Yard.PILLARS, dy)), World.PILLAR)
	for k in range(ROOM.size.x - Yard.GROVE - 1, ROOM.size.x - 1):
		for dy in range(-1, 2):
			assert_eq(w.tile(GUARD + Vector2i(-k, dy)), World.BAMBOO, "grove %d %d" % [k, dy])
	assert_eq(w.tiles.count(World.LAMP), 6)
	assert_true(FloorGen.connected(w))


func test_a_room_too_small_or_with_ways_in_by_both_ends_is_refused() -> void:
	var w := _hall()
	var rng := RandomNumberGenerator.new()
	assert_false(Yard.make(w, Rect2i(10, 5, 8, 5), rng), "too narrow")
	assert_false(Yard.make(w, Rect2i(10, 5, 11, 4), rng), "too low")
	w.set_tile(Vector2i(21, 7), World.FLOOR)
	assert_false(Yard.make(w, ROOM, rng), "a way in at each end")
	assert_true(w.sites.is_empty())
	assert_true(w.actors.size() == 1 and w.tiles.count(World.LAMP) == 0, "nothing was laid")


# --- the guard ---------------------------------------------------------------


func test_the_guard_never_sleeps_and_sees_whoever_walks_into_the_lit_yard() -> void:
	var w := _yard()
	var guard := _guard(w)
	assert_false(guard.asleep())
	assert_true(w.lit(Vector2i(14, 7)), "the lamps light the yard")
	assert_true(w.lit(Vector2i(12, 5)))
	var plain := FloorGen.spawn(w, &"jangseung", Vector2i(5, 7))
	assert_true(plain.asleep(), "a post elsewhere sleeps")
	var me := w.player()
	me.pos = Vector2i(13, 8)
	w.sense()
	assert_eq(w.view_of(guard)[Grid.index(me.pos)], 1, "in the open")
	w.act(WAIT)
	assert_eq(guard.alert, Actor.HUNT)


func test_bamboo_and_the_shade_of_a_pillar_hide_miho_from_the_guard() -> void:
	var w := _yard()
	var view := w.view_of(_guard(w))
	for p: Vector2i in [GUARD + Vector2i(-8, 0), GUARD + Vector2i(-9, 1), GUARD + Vector2i(-8, -1)]:
		assert_eq(w.tile(p), World.BAMBOO)
		assert_eq(view[Grid.index(p)], 0, "in the grove %s" % p)
	var behind := GUARD + Vector2i(-4, -1)
	assert_eq(w.tile(behind), World.FLOOR)
	assert_eq(view[Grid.index(behind)], 0, "behind a pillar")
	assert_eq(view[Grid.index(GUARD + Vector2i(-4, 0))], 1, "in the lane")


func test_a_clone_keeps_the_guard_awake() -> void:
	var w := _yard()
	var c := w.clone()
	assert_true(c.actor(_guard(w).id).guard)
	assert_false(c.actor(_guard(w).id).asleep())


# --- the talisman ------------------------------------------------------------


func test_stepping_onto_the_stand_gives_the_rolled_talisman_once() -> void:
	var w := _yard(Cards.WATER)
	var events := _step_onto(w, STAND)
	assert_has(w.cards, Cards.WATER)
	assert_eq(
		events.filter(func(e): return e.t == &"card").map(func(e): return e.card), [Cards.WATER]
	)
	assert_true(w.sites.is_empty())
	assert_eq(w.tile(STAND), World.FLOOR)
	w.cards.erase(Cards.WATER)
	w.player().pos = STAND - E
	w.act({t = &"move", dir = E})
	assert_false(w.cards.has(Cards.WATER), "the stand is gone")


func test_a_talisman_already_held_gives_the_first_one_missing() -> void:
	var w := _yard(Cards.FIRE)
	w.cards.append(Cards.FIRE)
	assert_eq(Yard.prize(w, w.sites[0]), Cards.WATER)
	_step_onto(w, STAND)
	assert_has(w.cards, Cards.WATER)
	assert_eq(w.cards.count(Cards.FIRE), 1)


func test_with_every_talisman_held_the_stand_gives_nothing() -> void:
	var w := _yard()
	w.cards.assign(Cards.ALL)
	var events := _step_onto(w, STAND)
	assert_eq(w.cards.size(), Cards.ALL.size())
	assert_true(events.all(func(e): return e.t != &"card"))
	assert_eq(Yard.prize(_yard(), {card = Cards.WATER}), Cards.WATER)


func test_the_preview_of_the_step_equals_the_round() -> void:
	var w := _yard()
	w.player().pos = STAND - E * 2
	w.sense()
	var f := Forecast.of(w, {t = &"move", dir = E})
	w.act({t = &"move", dir = E})
	assert_eq(f.after.cards, w.cards)
	assert_eq(f.after.sites, w.sites)


func test_a_push_onto_the_stand_gives_it_too() -> void:
	var w := _yard()
	var me := w.player()
	me.pos = STAND - E
	w.push(me, E, 1)
	assert_has(w.cards, Cards.WATER)


# --- what the hover says -----------------------------------------------------


func test_hovering_the_stand_names_the_talisman_it_gives() -> void:
	var w := _yard(Cards.FIRE)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	var text := Info.plain(Info.terrain(w, STAND))
	assert_string_contains(text, "부적 단")
	assert_string_contains(text, "밟으면 아직 없는 원소 부적 하나를 얻는다")
	assert_string_contains(text, "얻는 부적: 불")
	w.cards.assign(Cards.ALL)
	assert_string_contains(Info.plain(Info.terrain(w, STAND)), "얻는 부적: 없음")


func test_hovering_the_guard_says_it_does_not_sleep() -> void:
	var w := _yard()
	var text := Info.plain(Info.creature(w, _guard(w)))
	assert_string_contains(text, "잠들지 않음")
	assert_string_contains(text, "지키는 중")


func test_the_codex_lists_the_lamp_and_the_stand_by_what_they_are() -> void:
	for name in ["석등", "부적 단"]:
		var entry := Codex.entries(4).filter(func(e): return e.name == name)
		assert_eq(entry.size(), 1, name)
		assert_false(Info.plain(Codex.detail(entry[0])).contains("얻는 부적"), name)
	var lamp: Dictionary = Codex.entries(4).filter(func(e): return e.name == "석등")[0]
	assert_string_contains(Info.plain(Codex.detail(lamp)), "꺼지지 않는다")
