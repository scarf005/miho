extends GutTest
## A creature keeps off hot iron however it picks its way (Mind._walkable).

const ME := Vector2i(30, 12)
const FROM := Vector2i(20, 3)


func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
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
	Status.ignite(w, me)
	w.sense()
	return w


## Hot iron down the whole column beside FROM, on the way to any tile that lines up on Miho.
func _hot_column(w: World) -> void:
	for y in range(1, Grid.H - 1):
		w.hot[Vector2i(FROM.x + 1, y)] = Vector2i(0, 3)


func test_a_creature_lining_up_does_not_step_onto_hot_iron() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"jiha", FROM)
	_hot_column(w)
	assert_true(w.lit(ME), "it has something to line up on")
	Mind._align(w, a, w.player())
	assert_false(w.hot.has(a.pos), "stands on %s" % a.pos)


func test_a_creature_counts_no_way_across_hot_iron() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"jiha", FROM)
	_hot_column(w)
	var open := Masks.walk(w, a, Mind._walkable(w, a))
	assert_lt(Grid.search(a.pos, open).dist[Grid.index(FROM + Vector2i(2, 0))], 0)
