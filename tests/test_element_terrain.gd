extends GutTest
## The elements change the ground they reach by the cycles of 오행: 쇠 cuts what
## grows, 나무 cracks walls, 흙 fills water, 물 makes ash green, 불 bakes mud.

const FOX := Cards.FOX
const ORB := Cards.ORB
const FIRE := Cards.FIRE
const WATER := Cards.WATER
const WOOD := Cards.WOOD
const METAL := Cards.METAL
const EARTH := Cards.EARTH
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(20, 12)
## Where a creature stands that the projectile of a cast east ends on.
const FOE := ME + Vector2i(3, 0)
const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)


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


## A world with a creature that neither moves nor casts at `at`.
func _hall(at := FOE) -> World:
	var w := _world()
	var foe := FloorGen.spawn(w, &"jangseung", at)
	foe.cooldown = 99
	foe.hp = 40
	foe.max_hp = 40
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## Casts and lets the projectile fly.
func _fire(w: World, cards: Array) -> Array[Dictionary]:
	var events := w.act(_cast(cards))
	events.append_array(w.act(WAIT))
	return events


func test_a_bullet_cuts_what_grows_round_where_it_strikes() -> void:
	for t: int in [
		World.BAMBOO,
		World.GRASS,
		World.THORNS,
		World.REEDS,
		World.REEDS_FLAT,
		World.WOOD_WALL,
	]:
		var w := _hall()
		_put(w, FOE + UP, t)
		_put(w, FOE + E + DOWN, t)
		_put(w, FOE + E * 2, t)
		_fire(w, [FOX, METAL])
		assert_eq(w.tile(FOE + UP), World.FLOOR, str(t))
		assert_eq(w.tile(FOE + E + DOWN), World.FLOOR, "the corner of the 3x3 %d" % t)
		assert_eq(w.tile(FOE + E * 2), t, "two tiles off stays %d" % t)


func test_a_cut_is_told_and_heard() -> void:
	var w := _hall()
	_put(w, FOE + UP, World.BAMBOO)
	var cut := _fire(w, [FOX, METAL]).filter(func(e): return e.t == &"become")
	assert_eq(cut.size(), 1)
	assert_ne(Sfx.sound_of(cut[0]), &"")
	assert_eq(cut[0].tiles, [FOE + UP])


func test_other_elements_leave_what_grows_alone() -> void:
	for cards: Array in [[FOX, WATER], [FOX, WOOD], [FOX, EARTH]]:
		var w := _hall()
		_put(w, FOE + UP, World.BAMBOO)
		_put(w, FOE + DOWN, World.THORNS)
		_fire(w, cards)
		assert_eq(w.tile(FOE + UP), World.BAMBOO, str(cards))
		assert_eq(w.tile(FOE + DOWN), World.THORNS, str(cards))


func test_a_cannonball_cuts_what_grows_and_breaks_the_wooden_wall_it_strikes_once() -> void:
	var w := _world()
	_put(w, ME + E * 2 + UP, World.GRASS)
	_put(w, ME + E * 3, World.WOOD_WALL)
	var events := w.act(_cast([ORB, METAL]))
	assert_eq(w.tile(ME + E * 2 + UP), World.FLOOR)
	assert_eq(w.tile(ME + E * 3), World.FLOOR)
	var smashed := events.filter(func(e): return e.t == &"smash" and e.at == ME + E * 3)
	assert_eq(smashed.size(), 1)


func test_roots_crack_the_walls_round_a_wood_orb_and_cracked_ones_fall() -> void:
	var w := _hall()
	_put(w, FOE + E + UP, World.WALL)
	_put(w, FOE + E + DOWN, World.WALL_CRACKED)
	_fire(w, [ORB, WOOD])
	assert_eq(w.tile(FOE + E + UP), World.WALL_CRACKED)
	assert_eq(w.tile(FOE + E + DOWN), World.RUBBLE)


func test_roots_do_not_break_the_outermost_ring() -> void:
	var edge := Vector2i(Grid.W - 2, ME.y)
	var w := _world()
	w.player().pos = edge - Vector2i(3, 0)
	var foe := FloorGen.spawn(w, &"jangseung", edge)
	foe.cooldown = 99
	foe.hp = 40
	w.sense()
	_put(w, edge + UP, World.WALL)
	_fire(w, [ORB, WOOD])
	assert_eq(w.tile(edge + E), World.WALL)
	assert_eq(w.tile(edge + E + UP), World.WALL)
	assert_eq(w.tile(edge + UP), World.WALL_CRACKED, "an inner wall beside it does crack")


func test_a_wood_orb_cracks_the_wall_it_strikes_once() -> void:
	var w := _world()
	_put(w, ME + E * 3, World.WALL)
	w.act(_cast([ORB, WOOD]))
	assert_eq(w.tile(ME + E * 3), World.WALL_CRACKED)


func test_earth_fills_water_with_mud() -> void:
	var w := _hall()
	_put(w, FOE + UP, World.POND)
	_put(w, FOE + DOWN, World.SHALLOW)
	_put(w, FOE + E * 2, World.POND)
	_fire(w, [FOX, EARTH])
	assert_eq(w.tile(FOE + UP), World.MUD)
	assert_eq(w.tile(FOE + DOWN), World.MUD)
	assert_eq(w.tile(FOE + E * 2), World.POND, "out of the 3x3")


func test_a_quake_fills_the_ponds_in_its_ring_only() -> void:
	var w := _world()
	_put(w, ME + E, World.POND)
	_put(w, ME + E * 3, World.POND)
	w.act(_cast([EARTH]))
	assert_eq(w.tile(ME + E), World.MUD)
	assert_eq(w.tile(ME + E * 3), World.POND)


func test_water_makes_ash_green_and_still_puts_fire_out() -> void:
	var w := _hall()
	_put(w, FOE + UP, World.ASH)
	_put(w, FOE + DOWN, World.GRASS)
	w.ignite(FOE + DOWN)
	_fire(w, [FOX, WATER])
	assert_eq(w.tile(FOE + UP), World.GRASS)
	assert_false(w.burning.has(FOE + DOWN))


func test_a_dokkaebi_fire_veil_doused_by_water_stays_ash() -> void:
	var w := _hall()
	_put(w, FOE + UP, World.VEIL)
	_fire(w, [FOX, WATER])
	assert_eq(w.tile(FOE + UP), World.ASH, "the ash the veil left is not watered the same cast")


func test_a_water_jet_greens_the_ash_along_its_line_only() -> void:
	var w := _world()
	_put(w, ME + E * 2, World.ASH)
	_put(w, ME + E * 2 + UP, World.ASH)
	_put(w, ME + E * (Spray.JET[0] + 2), World.ASH)
	w.act(_cast([WATER]))
	assert_eq(w.tile(ME + E * 2), World.GRASS)
	assert_eq(w.tile(ME + E * 2 + UP), World.ASH, "beside the jet")
	assert_eq(w.tile(ME + E * (Spray.JET[0] + 2)), World.ASH, "past the jet")


func test_fire_bakes_mud_to_floor_and_does_not_burn_it() -> void:
	var w := _hall()
	_put(w, FOE + UP, World.MUD)
	_fire(w, [FOX, FIRE])
	assert_eq(w.tile(FOE + UP), World.FLOOR)
	assert_false(w.burning.has(FOE + UP))


func test_steam_does_not_bake_mud() -> void:
	var w := _hall()
	_put(w, FOE + UP, World.MUD)
	_fire(w, [FOX, FIRE, WATER])
	assert_eq(w.tile(FOE + UP), World.MUD)


func test_a_burning_tile_that_is_cut_stops_burning() -> void:
	var w := _hall()
	_put(w, FOE + UP, World.GRASS)
	w.ignite(FOE + UP)
	_fire(w, [FOX, METAL])
	assert_eq(w.tile(FOE + UP), World.FLOOR)
	assert_false(w.burning.has(FOE + UP))


func test_a_shotgun_cuts_the_growth_in_its_fan() -> void:
	var w := _world()
	_put(w, ME + E * 2, World.BAMBOO)
	_put(w, ME - E * 2, World.GRASS)
	w.act(_cast([METAL, METAL]))
	assert_eq(w.tile(ME + E * 2), World.FLOOR)
	assert_eq(w.tile(ME - E * 2), World.GRASS, "behind the caster")


func test_the_forecast_of_an_orb_matches_the_round() -> void:
	var w := _world()
	_put(w, ME + E * 3, World.WALL)
	_put(w, ME + E * 2 + UP, World.ASH)
	w.sense()
	var f := Forecast.of(w, _cast([ORB, WATER]))
	w.act(_cast([ORB, WATER]))
	assert_eq(f.after.tiles, w.tiles)
	assert_eq(f.grounds.get(ME + E * 2 + UP), World.GRASS, "the aim shows the ash turning")


func test_the_forecast_of_a_spray_matches_the_round() -> void:
	var w := _world()
	_put(w, ME + E * 2, World.ASH)
	_put(w, ME + E * 3, World.ASH)
	w.sense()
	var f := Forecast.of(w, _cast([WATER]))
	w.act(_cast([WATER]))
	assert_eq(f.after.tiles, w.tiles)
	assert_eq(f.grounds.size(), 2)


func test_a_spray_hover_leaves_out_what_its_shape_cannot_reach() -> void:
	var read := func(picked: Array) -> String:
		return Info.plain(SpellInfo.spell(Spell.make(picked)))
	assert_false(read.call([WOOD, FIRE, WOOD]).contains("금 간 벽이 됨"), "a fan leaves walls out")


## An element's hover names a tile only if its spray's real cover can hold that tile.
func test_a_spray_hover_names_only_the_tiles_it_reaches() -> void:
	var talons := Cards.recipe(&"talon") + Cards.recipe(&"talon")
	var spells := [[FIRE], [WATER], [METAL], [METAL, METAL], [EARTH], [WOOD, FIRE, WOOD], talons]
	for c: StringName in Cards.TRIPLES.keys() + Cards.PAIRS.keys():
		spells.append(Cards.recipe(c))
	var kinds := [World.WALL, World.WALL_CRACKED, World.WOOD_WALL, World.POND, World.GRASS]
	var placed := [Spray.SIGHT, Spray.ROOTS, Spray.ACROSS, Spray.CLEAVE]
	for picked: Array in spells:
		var s := Spell.make(picked)
		if s.shape != Spell.SPRAY or Spray.form(s) in placed:
			continue
		for t: int in kinds:
			var w := _world()
			for i in w.tiles.size():
				if w.tiles[i] == World.FLOOR and (Grid.index(ME) != i or Tiles.walk[t] == 1):
					w.tiles[i] = t
			var cover := Spray.cover(w, w.player(), s, E)
			var held := cover.any(func(p): return w.tile(p) == t)
			assert_eq(Spray.holds(s, t), held, "%s %s" % [s.title(), Tiles.of(t, "name")])
