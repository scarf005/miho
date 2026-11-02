extends GutTest
## The bubbles over a 물귀신 she does not see.

const ME := Vector2i(5, 5)
const POND := Vector2i(10, 5)


## Miho at ME in a hall she sees all of, with a pond round POND.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.FLOOR)
	w.seen.resize(Grid.W * Grid.H)
	w.seen.fill(1)
	for x in range(-1, 2):
		for y in range(-1, 2):
			w.tiles[Grid.index(POND + Vector2i(x, y))] = World.POND
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.pos = ME
	w.actors.append(me)
	return w


func _ghost(w: World, at := POND) -> Actor:
	var a := Actor.new()
	a.id = w.new_id()
	a.kind = &"mulgwisin"
	a.faction = Actor.HEAVEN
	a.pos = at
	a.hp = 3
	w.actors.append(a)
	return a


func test_a_hidden_ghost_makes_bubbles_on_the_water_round_it() -> void:
	var w := _world()
	_ghost(w)
	var spots := Bubbles.spots(w)
	assert_has(spots, POND)
	assert_has(spots, POND + Vector2i(1, 1))
	assert_does_not_have(spots, POND + Vector2i(2, 0), "the bank is not water")


func test_a_pond_with_no_ghost_is_still() -> void:
	assert_eq(Bubbles.spots(_world()), [] as Array[Vector2i])


func test_no_bubbles_on_water_out_of_sight() -> void:
	var w := _world()
	_ghost(w)
	w.seen[Grid.index(POND)] = 0
	assert_does_not_have(Bubbles.spots(w), POND)


func test_no_bubbles_once_it_is_seen_or_gone() -> void:
	var w := _world()
	var ghost := _ghost(w, POND + Vector2i(1, 0))
	w.player().pos = POND + Vector2i(2, 0)
	assert_eq(Bubbles.spots(w), [] as Array[Vector2i], "beside her it shows itself")
	w.player().pos = ME
	ghost.hp = 0
	assert_eq(Bubbles.spots(w), [] as Array[Vector2i], "gone")


func test_a_bubble_rises_at_each_interval() -> void:
	var w := _world()
	_ghost(w)
	var bubbles := Bubbles.new()
	assert_eq(bubbles.rise(w, Bubbles.EVERY / 2.0, 3.0), [], "not yet")
	var risen := bubbles.rise(w, Bubbles.EVERY, 4.0)
	assert_eq(risen.size(), 1)
	assert_has(Bubbles.spots(w), risen[0].at)
	assert_eq(risen[0].born, 4.0)
