extends GutTest
## A 해태 strikes hard beside Miho. A creature that lines up to shoot holds its
## tile in the dark, where stepping back would lose sight of her.

const ME := Vector2i(10, 8)


func _dark_hall(depth: int) -> World:
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
	me.hp = 99
	me.max_hp = 99
	me.pos = ME
	w.actors.append(me)
	w.depth = depth
	w.sense()
	return w


func _hunter(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.alert = Actor.HUNT
	a.target = ME
	a.home = Vector2i(40, 8)
	return a


func test_a_haetae_beside_miho_in_the_dark_stays_and_strikes_for_three() -> void:
	var w := _dark_hall(3)
	var h := _hunter(w, &"haetae", ME + Vector2i.RIGHT)
	for i in 4:
		w.act({t = &"wait"})
	assert_eq(w.player().hp, 99 - 4 * 3)
	assert_eq(h.pos, ME + Vector2i.RIGHT)


func test_a_creature_lining_up_holds_its_tile_beside_miho_in_the_dark() -> void:
	var w := _dark_hall(3)
	var a := _hunter(w, &"imugi", ME + Vector2i.RIGHT)
	a.magic.cooldown = 99
	for i in 4:
		w.act({t = &"wait"})
		assert_eq(a.pos, ME + Vector2i.RIGHT, "round %d" % i)


func test_a_creature_lining_up_in_the_light_still_steps_back_to_shoot() -> void:
	var w := _dark_hall(3)
	w.tiles[Grid.index(ME + Vector2i.UP)] = World.LANTERN
	w.sense()
	var a := _hunter(w, &"imugi", ME + Vector2i.RIGHT)
	a.magic.cooldown = 99
	w.act({t = &"wait"})
	assert_gt(Grid.cheb(a.pos, ME), 1)
