extends GutTest
## A 장승 stands still: it strikes what stands beside it and throws orbs that
## home from the storeys of rank 2 on.

const ME := Vector2i(4, 8)


func _hall(depth: int) -> World:
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
	me.hp = 9
	me.max_hp = 9
	me.pos = ME
	w.actors.append(me)
	w.depth = depth
	w.sense()
	return w


func test_it_strikes_miho_beside_it_and_stays_where_it_is() -> void:
	var w := _hall(1)
	var post := FloorGen.spawn(w, &"jangseung", ME + Vector2i.RIGHT)
	post.alert = Actor.HUNT
	post.magic.cooldown = 0
	var events := w.act({t = &"wait"})
	assert_eq(w.player().hp, 8)
	assert_eq(events.filter(func(e): return e.t == &"melee").size(), 1)
	assert_eq(post.pos, ME + Vector2i.RIGHT)


func test_it_charges_a_plain_orb_on_the_first_storeys_and_a_homing_one_above() -> void:
	for case in [[1, false], [2, false], [3, true], [5, true], [9, true]]:
		var w := _hall(case[0])
		var post := FloorGen.spawn(w, &"jangseung", ME + Vector2i.RIGHT * 4)
		post.magic.casts = 0
		var plans := Aim.at(w, post, w.player())
		assert_eq(Spell.make(plans[0].cards).homing(), case[1], "storey %d" % case[0])
