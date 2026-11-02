extends GutTest
## 혼불 제단: three creatures of heaven fall around the altar and all of Miho's
## tails return, with one more tail for the storey.

const WAIT := {t = &"wait"}
const E := Vector2i(1, 0)
const ALTAR := Vector2i(20, 8)
const SEEDS := 16
const DEPTHS := [1, 3, 5, 9]

var _storeys: Array[World] = []


func before_all() -> void:
	for seed_value in SEEDS:
		for depth in DEPTHS:
			var w := Built.storey(seed_value * World.FLOORS + depth, depth)
			_storeys.append(w)


func _label(w: World) -> String:
	return "seed %d storey %d" % [w.rng.seed, w.depth]


## An open hall walled at the edges with an altar at ALTAR, Miho at (4, 8) with
## one tail on storey 4 (three tails allowed).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	w.tiles[Grid.index(ALTAR)] = World.ALTAR
	w.sites.append({kind = &"altar", at = ALTAR, fallen = 0})
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.depth = 2
	w.tails = 1
	w.sense()
	return w


## A creature of heaven with one health, awake and unaware.
func _foe(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.hp = 1
	a.max_hp = 1
	a.cooldown = 99
	a.home += E
	return a


## `a` falls near the altar in a round of its own.
func _fall(w: World, a: Actor) -> void:
	w.events = []
	Harm.hurt(w, a, 1)
	EventRooms.tick(w)


# --- where it lies -----------------------------------------------------------


func test_some_storeys_have_an_altar_in_a_room_of_its_own() -> void:
	var tiers := {}
	for w in _storeys:
		var altars := []
		for i in w.tiles.size():
			if w.tiles[i] == World.ALTAR:
				altars.append(Grid.at(i))
		assert_lte(altars.size(), 1, _label(w))
		assert_lte(w.seals.size() + w.sites.size(), 1, "one event room at most: " + _label(w))
		for at: Vector2i in altars:
			tiers[w.depth] = true
			assert_eq(w.sites, [{kind = &"altar", at = at, fallen = 0}], _label(w))
			assert_true(w.rooms.all(func(r): return not r.has_point(at)), "off the room list")
			assert_false(w.open_floor(at) or w.opaque(at), "it blocks walking only")
			assert_true(FloorGen.connected(w), _label(w))
			for a in w.actors.slice(1):
				assert_gt(Grid.cheb(a.pos, at), 1, "no creature is put by the altar")
	assert_gt(tiers.size(), 0, "some storey has an altar")


func test_a_seed_builds_the_same_altar_every_time() -> void:
	for seed_value in 3:
		var a := World.create(seed_value)
		var b := World.create(seed_value)
		assert_eq(a.sites, b.sites)
		assert_eq(a.tiles, b.tiles)


func test_a_room_too_small_for_an_altar_is_refused() -> void:
	var w := _world()
	w.sites.clear()
	w.set_tile(ALTAR, World.FLOOR)
	assert_false(Altar.make(w, Rect2i(10, 4, 4, 6)), "too narrow")
	assert_false(Altar.make(w, Rect2i(10, 4, 8, 3)), "too low")
	assert_eq(w.tile(Vector2i(14, 7)), World.FLOOR)
	assert_true(w.sites.is_empty())
	var wide := Rect2i(10, 4, 5, 4)
	assert_true(Altar.make(w, wide))
	assert_eq(w.tile(Vector2i(12, 6)), World.ALTAR, "in the middle")


# --- lighting it -------------------------------------------------------------


func test_creatures_that_fall_near_the_altar_are_counted_and_the_third_lights_it() -> void:
	var w := _world()
	w.sense()
	var foes := [ALTAR + Vector2i(1, 1), ALTAR + Vector2i(-3, 0), ALTAR + Vector2i(0, Altar.REACH)]
	for k in 2:
		_fall(w, _foe(w, foes[k]))
		assert_eq(w.sites[0].fallen, k + 1)
		assert_eq(w.tile(ALTAR), World.ALTAR)
	w.tails = 0
	var before := w.clone()
	_fall(w, _foe(w, foes[2]))
	assert_eq(w.tile(ALTAR), World.ALTAR_LIT)
	assert_true(w.sites.is_empty())
	assert_eq(w.tail_bonus, 1)
	assert_eq(w.max_tails(), 3, "one more than storey 4 allows")
	assert_eq(w.tails, 3, "every tail returned, though the third fall gave one")
	assert_has(w.events.map(func(e): return e.t), &"altar")
	assert_has(
		Messages.of(before, w, w.events).map(Messages.plain), "혼불 제단이 타올랐다. 꼬리가 모두 돌아오고 하나 더 돋았다"
	)


func test_a_fall_beyond_reach_or_of_miho_is_not_counted() -> void:
	var w := _world()
	_fall(w, _foe(w, ALTAR + Vector2i(Altar.REACH + 1, 0)))
	assert_eq(w.sites[0].fallen, 0, "one tile too far")
	_fall(w, _foe(w, ALTAR + Vector2i(0, -Altar.REACH)))
	assert_eq(w.sites[0].fallen, 1, "exactly in reach")
	var me := w.player()
	me.pos = ALTAR + Vector2i(1, 0)
	w.events = []
	Harm.hurt(w, me, 3)
	EventRooms.tick(w)
	assert_eq(w.sites[0].fallen, 1)


func test_claws_count_in_a_real_round() -> void:
	var w := _world()
	w.player().pos = ALTAR + Vector2i(-2, 0)
	var foe := _foe(w, ALTAR + Vector2i(-1, 0))
	w.sense()
	w.act({t = &"move", dir = E})
	assert_false(foe.alive())
	assert_eq(w.sites[0].fallen, 1)


func test_a_creature_pushed_into_the_sky_near_the_altar_counts() -> void:
	var w := _world()
	var edge := ALTAR + Vector2i(2, 0)
	w.set_tile(edge + E, World.SKY)
	var foe := _foe(w, edge)
	w.events = []
	Fall.push(w, foe, E, 1)
	assert_false(foe.alive())
	EventRooms.tick(w)
	assert_eq(w.sites[0].fallen, 1)


func test_the_extra_tail_ends_with_the_storey() -> void:
	var w := _world()
	for k in Altar.NEED:
		_fall(w, _foe(w, ALTAR + Vector2i(k, 1)))
	assert_eq(w.max_tails(), 3)
	w.stairs = w.player().pos + E
	w.tails = 3
	w.act({t = &"move", dir = E})
	assert_eq(w.depth, 3)
	assert_eq(w.tail_bonus, 0)
	assert_eq(w.max_tails(), 3)
	assert_eq(w.tails, 3, "the new storey's own count")


func test_a_clone_keeps_the_altars_count_and_the_bonus() -> void:
	var w := _world()
	_fall(w, _foe(w, ALTAR + Vector2i(1, 1)))
	w.tail_bonus = 1
	var c := w.clone()
	assert_eq(c.sites, w.sites)
	assert_eq(c.tail_bonus, 1)
	c.sites[0].fallen = 2
	assert_eq(w.sites[0].fallen, 1, "a copy of its own")
	assert_eq(w.known_clone().sites, w.sites)


func test_a_lit_altar_shines() -> void:
	var w := _world()
	assert_false(w.lit(ALTAR + E))
	w.set_tile(ALTAR, World.ALTAR_LIT)
	assert_true(w.lit(ALTAR + E))
	assert_true(w.lit(ALTAR + Vector2i(Light.SOUL_RADIUS - 1, 0)))
	assert_false(w.lit(ALTAR + Vector2i(Light.SOUL_RADIUS + 3, 0)))


# --- what the hover says -----------------------------------------------------


func test_hovering_the_altar_keeps_how_it_burns_and_its_gift_a_secret() -> void:
	var w := _world()
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	_fall(w, _foe(w, ALTAR + Vector2i(1, 1)))
	var text := Info.plain(Info.terrain(w, ALTAR))
	assert_string_contains(text, "혼불 제단")
	for told in ["타오", "쓰러", "꼬리", "/%d" % Altar.NEED]:
		assert_false(text.contains(told), told)


func test_the_codex_lists_both_altars_by_what_they_are_not_how_far_they_got() -> void:
	for name in ["혼불 제단", "타오르는 제단"]:
		var entry := Codex.entries(4).filter(func(e): return e.name == name)
		assert_eq(entry.size(), 1, name)
		var text := Info.plain(Codex.detail(entry[0]))
		assert_string_contains(text, "막음: 길, 주문")
		assert_false(text.contains("0/") or text.contains("쓰러짐"), name)
