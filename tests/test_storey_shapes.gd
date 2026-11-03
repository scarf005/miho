extends StoreyShapes
## The places of a run, the doorways of the broken building, and falling through the sky.

var _tops: Array[World] = []


func before_all() -> void:
	_storeys(Skeletons.BROKEN)
	for seed_value in 4:
		_tops.append(_run(seed_value, 5))


# --- the run ------------------------------------------------------------------


func test_no_hole_opens_beside_a_doorway() -> void:
	for w: World in _storeys(Skeletons.BROKEN):
		for i in w.tiles.size():
			var p := Grid.at(i)
			if w.tiles[i] != World.DOOR and w.tiles[i] != World.DOOR_OPEN:
				continue
			for d in Grid.DIRS:
				assert_ne(w.tile(p + d), World.SKY, "%s %s" % [_label(w), p])


# --- falling through the sky ------------------------------------------------------


## A run on `seed_value` built by the table up to `depth`, each storey left behind.
func _run(seed_value: int, depth: int) -> World:
	var w := Built.world(seed_value)
	for d in range(1, depth):
		Storeys.leave(w)
		Storeys.enter(w, d + 1)
	return w


func test_a_fall_through_a_hole_chains_through_sky_below_and_lands_on_something_to_stand_on(
) -> void:
	_falls_chain_and_land(0)


func test_a_fall_through_a_second_set_of_holes_chains_through_sky_below_and_lands_too() -> void:
	_falls_chain_and_land(7)


## The falls through every hole whose tile index is `rest` modulo 14.
func _falls_chain_and_land(rest: int) -> void:
	var chained := 0
	for seed_value in 4:
		var top := _tops[seed_value]
		for i in top.tiles.size():
			if top.tiles[i] != World.SKY or i % 14 != rest:
				continue
			var w := top.clone()
			var me := w.player()
			me.hp = 100
			me.max_hp = 100
			Fall.drop(w, me, Grid.at(i))
			var fell := 5 - w.depth
			assert_gt(fell, 0, str(Grid.at(i)))
			assert_eq(me.hp, 100 - fell * Fall.DAMAGE)
			assert_true(w.open_floor(me.pos), "%d %s" % [w.depth, me.pos])
			for between in range(w.depth + 1, 5):
				assert_eq(w.storeys[between].tiles[i], World.SKY, "sky all the way down")
			chained += 1 if fell > 1 else 0
	assert_gt(chained, 0, "some falls go through more than one storey")


func test_the_court_of_the_ring_on_the_second_storey_drops_to_the_first() -> void:
	for seed_value in 4:
		var top := _run(seed_value, 3)
		var ring: PackedByteArray = top.storeys[2].tiles
		var w := top.clone()
		var me := w.player()
		me.hp = 100
		me.max_hp = 100
		var into := Vector2i(-1, -1)
		for i in ring.size():
			if ring[i] == World.SKY and top.tiles[i] == World.SKY and Grid.at(i).x > 10:
				into = Grid.at(i)
		Fall.drop(w, me, into)
		assert_eq(w.depth, 1, str(into))
		assert_eq(me.hp, 100 - 2 * Fall.DAMAGE)
		assert_true(w.open_floor(me.pos))
