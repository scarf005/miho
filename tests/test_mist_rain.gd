extends GutTest
## 단비 lays fog, a water orb leaves shallow water, and fire turns fog to steam.

const ORB := Cards.ORB
const FIRE := Cards.FIRE
const WATER := Cards.WATER
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(20, 12)
const AHEAD := ME + Vector2i(3, 0)


## An open hall walled at the edges, Miho at ME with five tails.
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
	w.rng.seed = 5
	w.sense()
	return w


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func test_a_rain_spray_lays_fog_on_every_tile_it_reaches() -> void:
	var w := _world()
	var rain := Cards.recipe(&"rain")
	var tiles := Spray.cover(w, w.player(), Spell.make(rain), E)
	Cast.cast(w, w.player(), Spell.make(rain), E)
	assert_false(tiles.is_empty())
	for p in tiles:
		assert_eq(Gas.at(w, p).x, Gas.FOG, str(p))


func test_a_rain_orb_lays_fog_round_where_it_ends() -> void:
	var w := _world()
	w.set_tile(AHEAD + E, World.WALL)
	w.act(_cast([ORB] + Cards.recipe(&"rain")))
	w.act(WAIT)
	assert_eq(Gas.at(w, AHEAD).x, Gas.FOG)


func test_rain_puts_out_a_fire_and_the_fog_it_lays_stays_fog() -> void:
	var w := _world()
	var rain := Cards.recipe(&"rain")
	var tile: Vector2i = Spray.cover(w, w.player(), Spell.make(rain), E)[0]
	w.set_tile(tile, World.GRASS)
	Terrain.ignite(w, tile)
	Cast.cast(w, w.player(), Spell.make(rain), E)
	assert_false(w.burning.has(tile))
	assert_eq(Gas.at(w, tile).x, Gas.FOG)


func _splash(w: World, cards: Array) -> Array[Dictionary]:
	w.set_tile(AHEAD + E, World.WALL)
	var events := w.act(_cast(cards))
	events.append_array(w.act(WAIT))
	return events


func test_a_water_orb_leaves_shallow_water_on_the_floor_round_where_it_ends() -> void:
	var w := _world()
	var events := _splash(w, [ORB, WATER])
	for p in Terrain.near(AHEAD):
		assert_eq(w.tile(p), World.WALL if p == AHEAD + E else World.SHALLOW, str(p))
	assert_eq(w.tile(AHEAD + Vector2i(0, 2)), World.FLOOR, "not past the 3x3")
	assert_eq(events.filter(func(e): return e.t == &"become" and e.tile == World.SHALLOW).size(), 1)


func test_a_water_orb_leaves_a_hidden_plate_and_what_is_not_bare_floor_as_they_were() -> void:
	var w := _world()
	w.traps[AHEAD + Vector2i(0, 1)] = World.TRAP_ALARM
	w.set_tile(AHEAD + Vector2i(0, -1), World.GRASS)
	_splash(w, [ORB, WATER])
	assert_eq(w.tile(AHEAD + Vector2i(0, 1)), World.FLOOR)
	assert_eq(w.tile(AHEAD + Vector2i(0, -1)), World.GRASS)
	assert_eq(w.tile(AHEAD), World.SHALLOW)


func test_a_water_wisp_and_an_orb_without_water_leave_the_floor_alone() -> void:
	var w := _world()
	_splash(w, [Cards.FOX, WATER])
	assert_eq(w.tile(AHEAD), World.FLOOR)
	var v := _world()
	_splash(v, [ORB, Cards.EARTH])
	assert_eq(v.tile(AHEAD), World.FLOOR, "an orb without water")
