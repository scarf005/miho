extends GutTest
## 도깨비불 장막: a line of fire splits a room; whoever stands next to it burns,
## and water or frost puts it out.

const FOX := Cards.FOX
const ORB := Cards.ORB
const WATER := Cards.WATER
const METAL := Cards.METAL
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(20, 12)
const LINE_X := 30
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


## An open hall walled at the edges with a veil down column LINE_X, Miho at ME
## with nine health and five tails.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for y in range(1, Grid.H - 1):
		w.tiles[Grid.index(Vector2i(LINE_X, y))] = World.VEIL
	w.rooms.assign([Rect2i(1, 1, Grid.W - 2, Grid.H - 2)])
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 9
	me.max_hp = 9
	me.pos = ME
	w.actors.append(me)
	w.depth = 5
	w.tails = 5
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


## A creature that stays where it stands: a 장승 (no element, 3 health).
func _post(w: World, at: Vector2i, kind := &"jangseung") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


# --- where it lies -----------------------------------------------------------


func _veils(w: World) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var i := w.tiles.find(World.VEIL)
	while i >= 0:
		out.append(Grid.at(i))
		i = w.tiles.find(World.VEIL, i + 1)
	return out


func test_some_storeys_split_a_room_with_a_veil_that_leaves_every_door_on_one_side() -> void:
	var found := 0
	for w in _storeys:
		var veil := _veils(w)
		if veil.is_empty():
			continue
		found += 1
		assert_true(w.seals.is_empty() and w.sites.is_empty(), "one event room: " + _label(w))
		var line := veil.map(func(p): return p.x if veil[0].x == veil[-1].x else p.y)
		assert_eq(line.min(), line.max(), "one straight line: " + _label(w))
		var room := FloorGen.room_at(w, veil[0])
		assert_false(room.has_area(), "the room left the list: " + _label(w))
		var whole := Masks.floor_of(w)
		var open := Masks.opened(w)
		var cut: PackedInt32Array = Grid.search(w.start, whole).dist
		var through: PackedInt32Array = Grid.search(w.start, open).dist
		var beyond := 0
		for p: Vector2i in w.peaches:
			if cut[Grid.index(p)] < 0 and through[Grid.index(p)] >= 0:
				beyond += 1
				assert_true(veil.all(func(v): return Grid.cheb(p, v) >= Veil.NEAR), "away from it")
		assert_eq(beyond, 1, "one peach beyond the fire: " + _label(w))
		assert_true(FloorGen.connected(w), _label(w))
	assert_gt(found, 0, "some storey has a veil")


func test_a_seed_builds_the_same_veil_every_time() -> void:
	for seed_value in 4:
		var a := World.create(seed_value)
		var b := World.create(seed_value)
		assert_eq(a.tiles, b.tiles)
		assert_eq(a.peaches, b.peaches)


func test_make_splits_a_room_with_one_door_and_refuses_one_it_cannot() -> void:
	var w := _world()
	w.tiles.fill(World.WALL)
	var room := Rect2i(10, 5, 10, 5)
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			_put(w, Vector2i(x, y), World.FLOOR)
	_put(w, Vector2i(9, 7), World.FLOOR)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	assert_true(Veil.make(w, room, rng))
	var veil := _veils(w)
	assert_eq(veil.size(), 5, "the room's height")
	assert_true(veil.all(func(p): return p.x == veil[0].x and p.x >= 11 + 1 and p.x <= 16))
	assert_eq(w.peaches.size(), 1)
	assert_gte(w.peaches[0].x, veil[0].x + Veil.NEAR)
	assert_false(Veil.scorches(w, Vector2i(10, 7)), "the tile inside the door is safe")
	var small := _world()
	small.tiles.fill(World.WALL)
	var tiny := Rect2i(10, 5, 5, 5)
	for y in range(tiny.position.y, tiny.end.y):
		for x in range(tiny.position.x, tiny.end.x):
			_put(small, Vector2i(x, y), World.FLOOR)
	_put(small, Vector2i(9, 7), World.FLOOR)
	_put(small, Vector2i(15, 7), World.FLOOR)
	assert_false(Veil.make(small, tiny, rng), "doors on both ends")
	assert_true(_veils(small).is_empty())
	assert_true(small.peaches.is_empty())


func test_a_hole_in_the_room_keeps_its_sky_and_holds_no_peach() -> void:
	for seed_value in 8:
		var w := _world()
		w.tiles.fill(World.WALL)
		var room := Rect2i(10, 5, 10, 5)
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				_put(w, Vector2i(x, y), World.SKY if y == 5 else World.FLOOR)
		_put(w, Vector2i(9, 7), World.FLOOR)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		assert_true(Veil.make(w, room, rng))
		assert_eq(_veils(w).size(), 4, "the rows that have a floor")
		assert_true(w.open_floor(w.peaches[0]), "%s" % w.peaches[0])
		for x in range(room.position.x, room.end.x):
			assert_eq(w.tile(Vector2i(x, 5)), World.SKY)


# --- the fire ----------------------------------------------------------------


func test_who_stands_beside_the_veil_burns_for_the_fire_damage_each_round() -> void:
	var w := _world()
	var me := w.player()
	me.pos = Vector2i(LINE_X - 1, 12)
	var events := w.act(WAIT)
	assert_eq(me.hp, 9 - World.FIRE_DAMAGE)
	assert_eq(_of(events, &"burn").size(), 1)
	w.act(WAIT)
	assert_eq(me.hp, 9 - 2 * World.FIRE_DAMAGE, "every round")


func test_the_veil_burns_from_its_corner_and_not_two_tiles_off() -> void:
	var w := _world()
	for y in range(1, Grid.H - 1):
		if y != 12:
			_put(w, Vector2i(LINE_X, y), World.FLOOR)
	var me := w.player()
	me.pos = Vector2i(LINE_X + 1, 11)
	w.act(WAIT)
	assert_eq(me.hp, 9 - World.FIRE_DAMAGE, "diagonal")
	me.hp = 9
	me.pos = Vector2i(LINE_X - 2, 12)
	w.act(WAIT)
	assert_eq(me.hp, 9, "two tiles off")


func test_a_creature_beside_the_veil_burns_and_one_that_eats_fire_does_not() -> void:
	var w := _world()
	var plain := _post(w, Vector2i(LINE_X + 1, 5))
	var eater := _post(w, Vector2i(LINE_X + 1, 8), &"haetae")
	var plain_hp := plain.hp
	var eater_hp := eater.hp
	var events := w.act(WAIT)
	assert_eq(plain.hp, plain_hp - World.FIRE_DAMAGE)
	assert_eq(eater.hp, eater_hp)
	assert_eq(_of(events, &"absorb").size(), 1)


func test_the_veil_blocks_walking_and_lets_sight_through() -> void:
	var w := _world()
	var me := w.player()
	me.pos = Vector2i(LINE_X - 1, 12)
	w.sense()
	assert_false(w.open_floor(Vector2i(LINE_X, 12)))
	assert_false(w.opaque(Vector2i(LINE_X, 12)))
	w.act({t = &"move", dir = E})
	assert_eq(me.pos, Vector2i(LINE_X - 1, 12), "no step through")
	assert_true(w.lit(Vector2i(LINE_X + 2, 12)), "it lights the room")


func test_a_clone_keeps_the_veil_burning() -> void:
	var w := _world()
	w.player().pos = Vector2i(LINE_X - 1, 12)
	var c := w.known_clone()
	c.act(WAIT)
	assert_eq(c.player().hp, 9 - World.FIRE_DAMAGE)
	assert_eq(w.player().hp, 9, "the preview leaves the world as it was")


# --- putting it out ----------------------------------------------------------


func test_a_water_jet_that_reaches_the_veil_turns_it_to_ash() -> void:
	var w := _world()
	var me := w.player()
	me.pos = Vector2i(LINE_X - 2, 12)
	var events := w.act(_cast([WATER]))
	assert_eq(w.tile(Vector2i(LINE_X, 12)), World.ASH)
	assert_eq(w.tile(Vector2i(LINE_X, 11)), World.VEIL, "only the tile it reached")
	assert_eq(_of(events, &"douse").size(), 1)
	assert_true(w.open_floor(Vector2i(LINE_X, 12)))


func test_a_water_wisp_or_orb_that_ends_beside_the_veil_puts_out_the_tiles_by_it() -> void:
	for cards in [[FOX, WATER], [ORB, WATER]]:
		var w := _world()
		w.player().pos = Vector2i(LINE_X - 4, 12)
		w.act(_cast(cards))
		w.act(WAIT)
		assert_eq(w.tile(Vector2i(LINE_X, 12)), World.ASH, str(cards))
		assert_eq(w.tile(Vector2i(LINE_X, 8)), World.VEIL, "far along the line it stays")


func test_frost_turns_the_veil_to_ice_that_can_be_walked() -> void:
	var w := _world()
	w.player().pos = Vector2i(LINE_X - 2, 12)
	w.act(_cast([METAL, WATER]))
	assert_eq(w.tile(Vector2i(LINE_X, 12)), World.ICE)
	assert_true(w.open_floor(Vector2i(LINE_X, 12)))
	w.player().hp = 9
	w.player().pos = Vector2i(LINE_X - 1, 12)
	w.act(WAIT)
	assert_eq(w.player().hp, 9 - World.FIRE_DAMAGE, "the rest of the line still burns")


func test_a_fire_spell_leaves_the_veil_as_it_is() -> void:
	var w := _world()
	w.player().pos = Vector2i(LINE_X - 2, 12)
	w.act(_cast([Cards.FIRE]))
	assert_eq(w.tile(Vector2i(LINE_X, 12)), World.VEIL)


func test_the_preview_of_a_water_jet_equals_the_round() -> void:
	var w := _world()
	w.player().pos = Vector2i(LINE_X - 2, 12)
	var f := Forecast.of(w, _cast([WATER]))
	w.act(_cast([WATER]))
	assert_eq(f.after.tiles, w.tiles)


# --- what the hover says -----------------------------------------------------


func test_hovering_the_veil_tells_the_harm_but_not_how_to_put_it_out() -> void:
	var w := _world()
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	var text := Info.plain(Info.terrain(w, Vector2i(LINE_X, 12)))
	assert_string_contains(text, "도깨비불 장막")
	assert_string_contains(text, "옆 칸 초당 피해: %d" % World.FIRE_DAMAGE)
	assert_false(text.contains("재가 됨") or text.contains("얼음이 됨"), text)
	assert_string_contains(text, "빛: %d칸" % Light.LANTERN_RADIUS)


func test_a_creature_beside_the_veil_says_so_on_hover() -> void:
	var w := _world()
	var foe := _post(w, Vector2i(LINE_X + 1, 5))
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	assert_string_contains(
		Info.plain(Info.creature(w, foe)), "도깨비불 장막 옆 칸 초당 피해: %d" % World.FIRE_DAMAGE
	)


func test_the_codex_lists_the_veil_by_what_it_is() -> void:
	var entry := Codex.entries(4).filter(func(e): return e.name == "도깨비불 장막")
	assert_eq(entry.size(), 1)
	assert_string_contains(Info.plain(Codex.detail(entry[0])), "옆 칸 초당 피해: %d" % World.FIRE_DAMAGE)


func test_travel_will_not_walk_beside_the_veil() -> void:
	var w := _world()
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	assert_false(Travel.walkable(w, Vector2i(LINE_X - 1, 12)))
	assert_true(Travel.walkable(w, Vector2i(LINE_X - 2, 12)))
