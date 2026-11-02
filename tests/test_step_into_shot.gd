extends GutTest
## A step the player asks for is taken even onto the tile of a flying shot.

const ME := Vector2i(4, 8)
const FOE := Vector2i(9, 8)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)


## An open hall, Miho at ME.
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
	w.depth = 2
	w.sense()
	return w


## The wisp of `kind`, in flight towards Miho on the tile next to her.
func _wisp(w: World, kind: StringName) -> Shot:
	var foe := FloorGen.spawn(w, kind, FOE)
	foe.cooldown = 99
	Cast.cast(w, foe, Bestiary.spell(kind, foe.info().casts[0]), WEST)
	var s: Shot = w.shots.back()
	s.pos = ME + EAST
	w.sense()
	return s


func test_miho_steps_onto_the_tile_of_a_flying_wisp() -> void:
	for kind in [&"dokkaebi", &"bujigaengi"]:
		var w := _world()
		var wisp := _wisp(w, kind)
		assert_ne(wisp.dir, Vector2i.ZERO, "still flying")
		assert_true(w.can({t = &"move", dir = EAST}), str(kind))
		w.act({t = &"move", dir = EAST})
		assert_eq(w.player().pos, ME + EAST, str(kind))


func test_the_forecast_of_that_step_is_drawn() -> void:
	var w := _world()
	_wisp(w, &"bujigaengi")
	var f := Forecast.of(w, {t = &"move", dir = EAST})
	assert_eq(f.after.player().pos, ME + EAST)


func test_a_rooted_miho_still_cannot_step_onto_it() -> void:
	var w := _world()
	_wisp(w, &"dokkaebi")
	w.player().ailments.rooted = 2
	assert_false(w.can({t = &"move", dir = EAST}))
