extends GutTest
## Afterimage: a fading copy on each tile a creature passed in one move of
## several tiles, read from the round's events alone.

const LEAP := [Cards.WATER, Cards.WOOD, Cards.FIRE]
const E := Vector2i(1, 0)
const ME := Vector2i(4, 8)


func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	w.rooms = [Rect2i(1, 1, Grid.W - 2, Grid.H - 2)]
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
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
	w.cards.append_array([Cards.EARTH, Cards.WATER, Cards.WOOD, Cards.FIRE])
	w.sense()
	return w


## Every tile the plan leaves a copy on, for one creature.
func _tiles(plan: Dictionary, id: int) -> Array:
	var out := []
	for i in plan:
		for p: Dictionary in plan[i]:
			if p.id == id:
				out.append(p.at)
	return out


func test_a_leap_leaves_copies_on_the_tiles_before_the_landing() -> void:
	var w := _world()
	var events := w.act({t = &"cast", spells = [{cards = LEAP, dir = E}]})
	var landing := w.player().pos
	assert_gt(landing.x - ME.x, 1, "the leap went more than one tile")
	var expected := []
	for x in range(ME.x, landing.x):
		expected.append(Vector2i(x, ME.y))
	assert_eq(_tiles(Afterimage.plan(events), w.player().id), expected)


func test_a_step_leaves_nothing() -> void:
	var w := _world()
	var events := w.act({t = &"move", dir = E})
	assert_eq(_tiles(Afterimage.plan(events), w.player().id), [])


func test_a_push_of_several_tiles_leaves_copies_and_a_push_of_one_does_not() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", ME + E * 3)
	w.events = []
	w.push(foe, E, 3)
	var start := ME + E * 3
	assert_eq(_tiles(Afterimage.plan(w.events), foe.id), [start, start + E, start + E * 2])
	w.events = []
	w.push(foe, E, 1)
	assert_eq(_tiles(Afterimage.plan(w.events), foe.id), [])


func test_a_creature_that_walks_after_a_push_of_one_tile_leaves_no_copies() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"dokkaebi", ME + E * 3)
	w.events = []
	w.push(foe, E, 1)
	w.emit({t = &"charge", id = foe.id, cards = [Cards.FOX], dir = E})
	Walk.move(w, foe, foe.pos + E)
	assert_eq(_tiles(Afterimage.plan(w.events), foe.id), [])


func test_a_copy_has_the_glyph_of_the_mover_and_a_missing_mover_leaves_none() -> void:
	var w := _world()
	var copies := Afterimage.copies(
		[{id = w.player().id, at = ME}], {w.player().id: w.player()}, 2.0
	)
	assert_eq(copies.size(), 1)
	assert_eq(copies[0].glyph, Bestiary.info(&"miho").glyph)
	assert_eq(copies[0].born, 2.0)
	assert_eq(Afterimage.copies([{id = 99, at = ME}], {}, 0.0), [])


func test_a_creature_she_cannot_see_leaves_no_copy() -> void:
	var w := _world()
	var id := w.player().id
	var passes := [{id = id, at = ME}]
	assert_eq(Afterimage.copies(passes, {id: w.player()}, 2.0, {id: true}).size(), 0)
