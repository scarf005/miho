extends GutTest
## Elements alone spray: each lone element's gimmick at every level, with its
## shape, harm, sound and light.

const FIRE := Cards.FIRE
const WATER := Cards.WATER
const WOOD := Cards.WOOD
const METAL := Cards.METAL
const EARTH := Cards.EARTH
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(20, 12)


## An open hall walled at the edges, with no light, Miho at ME and five tails.
func _world() -> World:
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
	w.depth = 5
	w.tails = 5
	w.cards.assign(Cards.ALL)
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts: a 장승 (no element, 3 health).
func _post(w: World, at: Vector2i, kind := &"jangseung") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


func _cover(w: World, cards: Array, dir := E) -> Array[Vector2i]:
	return Spray.cover(w, w.player(), Spell.make(cards), dir)


## `k` copies of talisman c.
func _n(c: StringName, k: int) -> Array:
	var out := []
	for i in k:
		out.append(c)
	return out


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


func _offsets(tiles: Array[Vector2i]) -> Array:
	return tiles.map(func(p): return p - ME)


func test_elements_alone_spray_one_level_a_copy_up_to_three() -> void:
	var one := Spell.make([FIRE])
	assert_eq(one.shape, Spell.SPRAY)
	assert_eq(one.level(), 1)
	assert_eq(Spell.make([FIRE, FIRE]).level(), 2)
	assert_eq(Spell.make([FIRE, FIRE, FIRE, FIRE]).level(), 3, "no level past 3")
	assert_eq(Spell.make([FIRE, FIRE, FIRE, FIRE]).cost(), 4)
	assert_eq(Spell.make([WATER, FIRE]).level(), 0, "a compound has its own shape")
	assert_eq(one.title(), "불 불길")
	assert_eq(Spell.make([METAL, METAL]).title(), "쇠×2 산탄")
	assert_eq(Spell.make([WATER, WATER, WATER]).title(), "물×3 물줄기")
	assert_eq(Spell.make([WATER, FIRE]).title(), "증기")
	assert_eq(Spell.make([WATER, FIRE, FIRE]).title(), "증기·불")


func test_a_fire_fan_is_symmetric_about_its_line_in_every_direction() -> void:
	var w := _world()
	for level in [1, 2, 3]:
		var r: int = Spray.FAN[level - 1]
		for d in Grid.DIRS:
			var offsets := _offsets(_cover(w, _n(FIRE, level), d))
			assert_eq(offsets.size(), r * (r + 2), "%s level %d" % [d, level])
			var axis := Vector2(d).normalized()
			for v: Vector2i in offsets:
				assert_true(Grid.cheb(v, Vector2i.ZERO) <= r)
				var mirror := Vector2i((2 * Vector2(v).dot(axis) * axis - Vector2(v)).round())
				assert_has(offsets, mirror, "%s mirrors %s" % [v, d])


func test_a_fire_fan_stops_at_a_wall() -> void:
	var w := _world()
	for y in range(ME.y - 3, ME.y + 4):
		_put(w, ME + Vector2i(2, y - ME.y), World.WALL)
	var tiles := _cover(w, [FIRE, FIRE, FIRE])
	assert_eq(_offsets(tiles), [Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)])


func test_one_fire_lights_only_what_burns_and_harms_no_one() -> void:
	var w := _world()
	_put(w, ME + Vector2i(1, 1), World.BAMBOO)
	var foe := _post(w, ME + Vector2i(1, 0))
	var events := w.act(_cast([FIRE]))
	assert_eq(_of(events, &"spray").size(), 1)
	assert_true(w.burning.has(ME + Vector2i(1, 1)), "bamboo burns")
	assert_false(w.burning.has(foe.pos), "the floor under the creature does not")
	assert_eq(foe.hp, foe.max_hp)
	assert_true(_of(events, &"hit").is_empty())


func test_three_fires_set_the_creatures_in_the_fan_alight() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(3, 1))
	w.act(_cast([FIRE, FIRE, FIRE]))
	assert_gt(foe.alight, 0, "radius 4 reaches it")
	assert_eq(foe.hp, foe.max_hp, "and it burns from the next round")
	w.act(WAIT)
	assert_eq(foe.hp, foe.max_hp - World.FIRE_DAMAGE)


func test_three_fires_always_spread() -> void:
	var w := _world()
	for x in range(5, 35):
		_put(w, Vector2i(x, ME.y + 4), World.BOARD)
	w.act(_cast([FIRE, FIRE, FIRE], Vector2i(0, 1)))
	for x in range(-4, 5):
		assert_true(w.wild.has(ME + Vector2i(x, 4)), "the fan's own fires are wild")
	for x in [-5, 5]:
		assert_true(w.burning.has(ME + Vector2i(x, 4)), "and took the boards beside them")
		assert_false(w.wild.has(ME + Vector2i(x, 4)), "with fire that spreads as usual")


func test_a_water_jet_stops_at_the_first_creature_and_pushes_it_one_or_two() -> void:
	for level in [1, 2]:
		var w := _world()
		var near := _post(w, ME + Vector2i(3, 0))
		var far := _post(w, ME + Vector2i(4, 0))
		var tiles := _cover(w, _n(WATER, level))
		assert_eq(tiles.back(), near.pos, "stops at the first creature")
		w.act(_cast(_n(WATER, level)))
		assert_eq(far.pos, ME + Vector2i(4, 0), "level %d leaves the one behind" % level)
		assert_eq(near.pos, ME + Vector2i(3, 0), "it has nowhere to slide")
	var w := _world()
	var foe := _post(w, ME + Vector2i(3, 0))
	w.act(_cast([WATER, WATER]))
	assert_eq(foe.pos, ME + Vector2i(5, 0), "2 tiles")
	assert_eq(_cover(w, [WATER]).size(), 4, "4 tiles of jet on open floor")
	assert_eq(_cover(w, [WATER, WATER]).size(), 5, "up to the creature at 5")


func test_three_waters_go_through_and_push_every_creature_three() -> void:
	var w := _world()
	var near := _post(w, ME + Vector2i(2, 0))
	var far := _post(w, ME + Vector2i(3, 0))
	assert_eq(_cover(w, [WATER, WATER, WATER]).size(), 8)
	w.act(_cast([WATER, WATER, WATER]))
	assert_eq(far.pos, ME + Vector2i(6, 0))
	assert_eq(near.pos, ME + Vector2i(5, 0))


func test_a_water_jet_douses_fire_and_the_lantern_it_runs_into() -> void:
	var w := _world()
	_put(w, ME + Vector2i(2, 0), World.BOARD)
	w.ignite(ME + Vector2i(2, 0))
	_put(w, ME + Vector2i(4, 0), World.LANTERN)
	w.act(_cast([WATER]))
	assert_false(w.burning.has(ME + Vector2i(2, 0)))
	assert_eq(w.tile(ME + Vector2i(4, 0)), World.LANTERN_OUT)


func test_a_jet_pushes_heaven_into_the_sky_and_miho_onto_a_peach() -> void:
	var w := _world()
	_put(w, ME + Vector2i(3, 0), World.SKY)
	var foe := _post(w, ME + Vector2i(2, 0))
	var events := w.act(_cast([WATER]))
	assert_false(foe.alive(), "falls out")
	assert_eq(_of(events, &"fall").size(), 1)
	w = _world()
	var me := w.player()
	me.hp = 2
	w.peaches.append(me.pos + E)
	w.push(me, E, 2)
	assert_eq(me.hp, 3, "a push onto a peach eats it")
	assert_false(w.peaches.has(ME + E))
	w.elixir = me.pos + E
	w.push(me, E, 3)
	assert_eq(w.outcome, &"won", "and onto the elixir drinks it")
	assert_eq(me.pos, w.elixir, "she stops there")


func test_a_pushed_miho_takes_the_stairs() -> void:
	var w := _world()
	w.stairs = ME + E
	w.push(w.player(), E, 2)
	assert_eq(w.depth, 6)


func test_a_pistol_hits_the_first_creature_for_one_loudly_and_lights_miho() -> void:
	var w := _world()
	var near := _post(w, ME + Vector2i(3, 0))
	var far := _post(w, ME + Vector2i(5, 0))
	var events := w.act(_cast([METAL]))
	assert_eq(near.hp, near.max_hp - 1)
	assert_eq(far.hp, far.max_hp)
	var bang: Dictionary = _of(events, &"noise")[0]
	assert_eq([bang.word, bang.loud], ["탕", Spray.GUN_LOUD])
	assert_eq(_cover(_world(), [METAL]).size(), Spray.PISTOL)
	var dark := _world()
	assert_false(dark.lit(ME))
	Spray.cast(dark, dark.player(), Spell.make([METAL]), E)
	assert_true(dark.lit(ME), "the muzzle flash")
	dark.act(WAIT)
	assert_false(dark.lit(ME), "for that round only")


func test_a_pistol_hits_a_creature_weak_to_metal_for_two() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(3, 0), &"cheonha")
	w.act(_cast([METAL]))
	assert_eq(foe.hp, foe.max_hp - 2)


func test_a_shotgun_fans_out_and_hits_harder_up_close() -> void:
	var w := _world()
	var close := _post(w, ME + Vector2i(1, 1))
	var far := _post(w, ME + Vector2i(3, -2))
	var out := _post(w, ME + Vector2i(4, 0))
	var events := w.act(_cast([METAL, METAL]))
	assert_eq(close.hp, close.max_hp - 2)
	assert_eq(far.hp, far.max_hp - 1)
	assert_eq(out.hp, out.max_hp, "radius 3")
	assert_eq(_of(events, &"noise")[0].word, "쾅")


func test_armour_piercing_goes_through_every_creature_and_one_wall() -> void:
	var w := _world()
	var a := _post(w, ME + Vector2i(2, 0))
	var b := _post(w, ME + Vector2i(4, 0))
	_put(w, ME + Vector2i(5, 0), World.WALL)
	var c := _post(w, ME + Vector2i(6, 0))
	_put(w, ME + Vector2i(7, 0), World.WALL)
	var d := _post(w, ME + Vector2i(8, 0))
	assert_eq(_cover(w, [METAL, METAL, METAL]).size(), 6, "the second wall stops it")
	w.act(_cast([METAL, METAL, METAL]))
	for x in [a, b, c]:
		assert_eq(x.hp, x.max_hp - Spray.PIERCE_HARM)
	assert_eq(d.hp, d.max_hp)
	assert_eq(w.tile(ME + Vector2i(5, 0)), World.WALL, "it pierces, it does not break")


## The rounds each creature was stunned or rooted for this round, by id.
func _held(events: Array, t: StringName) -> Dictionary:
	var out := {}
	for e in _of(events, t):
		out[e.id] = e.rounds
	return out


func test_a_quake_stuns_a_ring_whatever_the_direction() -> void:
	var w := _world()
	assert_eq(_cover(w, [EARTH], E), _cover(w, [EARTH], Vector2i(-1, -1)))
	assert_eq(_cover(w, [EARTH]).size(), 8)
	assert_eq(_cover(w, [EARTH, EARTH]).size(), 24)
	assert_eq(_cover(w, [EARTH, EARTH, EARTH]).size(), 48)
	var near := _post(w, ME + Vector2i(-1, 1))
	_post(w, ME + Vector2i(2, 0))
	var events := w.act(_cast([EARTH]))
	assert_eq(_held(events, &"stun"), {near.id: Spray.QUAKE_STUN[0]})
	var thud: Dictionary = _of(events, &"noise")[0]
	assert_eq([thud.word, thud.loud], ["쿵", World.THUD])


func test_a_bigger_quake_cracks_walls_and_fells_cracked_ones() -> void:
	var w := _world()
	var wall := ME + Vector2i(2, 0)
	var cracked := ME + Vector2i(-2, 0)
	_put(w, wall, World.WALL)
	_put(w, cracked, World.WALL_CRACKED)
	w.act(_cast([EARTH]))
	assert_eq(w.tile(wall), World.WALL, "radius 1 shakes no wall")
	w.tails = 5
	w.act(_cast([EARTH, EARTH]))
	assert_eq(w.tile(wall), World.WALL_CRACKED)
	assert_eq(w.tile(cracked), World.WALL_CRACKED, "level 2 fells nothing")
	var foe := _post(w, ME + Vector2i(0, 3))
	w.tails = 5
	var events := w.act(_cast([EARTH, EARTH, EARTH]))
	assert_eq(w.tile(wall), World.RUBBLE)
	assert_eq(w.tile(cracked), World.RUBBLE)
	assert_eq(_held(events, &"stun"), {foe.id: Spray.QUAKE_STUN[2]})


## Lanterns two rows above Miho light the hall so she sees far along her row.
func _lit_world() -> World:
	var w := _world()
	for x in range(2, Grid.W - 2, 3):
		_put(w, Vector2i(x, ME.y - 2), World.LANTERN)
	return w


func test_roots_seize_the_nearest_seen_creatures_silently() -> void:
	for level in [1, 2, 3]:
		var w := _lit_world()
		var foes: Array[Actor] = []
		for x in [3, -5, 7, 9]:
			foes.append(_post(w, ME + Vector2i(x, 0)))
		var events := w.act(_cast(_n(WOOD, level)))
		var want := {}
		for i in [[0], [0, 1], [0, 1, 2]][level - 1]:
			want[foes[i].id] = Spray.ROOT_ROUNDS[level - 1]
		assert_eq(_held(events, &"root"), want, "level %d" % level)
		assert_true(_of(events, &"noise").filter(func(e): return e.at == ME).is_empty())


func test_roots_pass_under_creatures_but_not_under_a_pond() -> void:
	var w := _lit_world()
	_post(w, ME + Vector2i(-1, 0))
	var far := _post(w, ME + Vector2i(-2, 0))
	for y in range(1, Grid.H - 1):
		_put(w, ME + Vector2i(2, y - ME.y), World.POND)
	_post(w, ME + Vector2i(3, 0))
	var events := w.act(_cast([WOOD, WOOD, WOOD]))
	assert_eq(_held(events, &"root").size(), 2, "the two on Miho's side")
	assert_true(_held(events, &"root").has(far.id), "through the one in front")


func test_a_spray_goes_any_way_even_into_a_wall() -> void:
	var w := _world()
	_put(w, ME + E, World.WALL)
	assert_true(w.can(_cast([EARTH])))
	assert_true(w.can(_cast([FIRE])))
	assert_false(w.can(_cast([Cards.FOX])), "a wisp still needs open air")


func test_a_lone_fire_fan_covers_three_tiles_and_two_cover_what_one_did() -> void:
	var w := _world()
	assert_eq(_offsets(_cover(w, [FIRE])).size(), 3)
	assert_eq(_offsets(_cover(w, [FIRE, FIRE])).size(), 8)
	var foe := _post(w, ME + Vector2i(2, 0))
	w.act(_cast([FIRE, FIRE]))
	assert_eq(foe.alight, 0, "two fires light what burns, not creatures")
	var three := _world()
	var burnt := _post(three, ME + Vector2i(2, 0))
	three.act(_cast([FIRE, FIRE, FIRE]))
	assert_gt(burnt.alight, 0, "three do")


func test_every_fire_spell_relights_a_dark_lantern_it_reaches() -> void:
	var lamp := ME + Vector2i(2, 0)
	for cards in [[FIRE], [FIRE, FIRE], [Cards.ORB, FIRE], [Cards.FOX, FIRE], [FIRE, Cards.EARTH]]:
		var w := _world()
		_put(w, lamp, World.LANTERN_OUT)
		var events := w.act(_cast(cards))
		for i in 4:
			if w.tile(lamp) == World.LANTERN_OUT:
				events = w.act(WAIT)
		assert_eq(w.tile(lamp), World.LANTERN, str(cards))
	var steam := _world()
	_put(steam, lamp, World.LANTERN_OUT)
	steam.act(_cast([FIRE, Cards.WATER]))
	assert_eq(steam.tile(lamp), World.LANTERN_OUT, "steam does not")
	var cold := _world()
	_put(cold, lamp, World.LANTERN_OUT)
	cold.act(_cast([Cards.ORB]))
	assert_eq(cold.tile(lamp), World.LANTERN_BROKEN, "a plain orb breaks it")
