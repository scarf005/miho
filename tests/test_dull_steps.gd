extends GutTest
## A dull creature does not read what flies at it: it walks on into a foe's projectile.
## A sharp one steps round it.

const ME := Vector2i(20, 12)
const E := Vector2i(1, 0)


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
	me.hp = 30
	me.max_hp = 30
	me.pos = ME
	w.actors.append(me)
	w.depth = 1
	w.tails = 9
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _hunter(w: World, kind: StringName, dist: int) -> Actor:
	var a := FloorGen.spawn(w, kind, ME + E * dist)
	a.max_hp = 50
	a.hp = 50
	a.magic.cooldown = 99
	a.brain.alert = Actor.HUNT
	a.brain.target = ME
	return a


## Whether `cards` thrown at a creature of `kind` hunting from `dist` tiles strikes it.
func _struck(kind: StringName, cards: Array, dist: int) -> bool:
	var w := _world()
	var a := _hunter(w, kind, dist)
	var events := w.act({t = &"cast", spells = [{cards = cards, dir = E}]})
	for i in 6:
		if events.any(func(e): return e.t == &"hit" and e.get("id") == a.id):
			return true
		if w.shots.is_empty():
			return false
		events = w.act({t = &"wait"})
	return false


func test_a_dull_creature_is_struck_from_every_distance() -> void:
	for kind in [&"gaekgwi", &"dalgyal"]:
		for cards in [[Cards.ORB], [Cards.FOX]]:
			for dist in range(2, 9):
				assert_true(_struck(kind, cards, dist), "%s %s %d" % [kind, cards, dist])


func test_a_sharp_creature_steps_round_a_projectile_on_its_way() -> void:
	assert_false(_struck(&"dokkaebi", [Cards.ORB], 4))


func test_a_dull_creature_never_walks_onto_a_shot_of_its_own_side() -> void:
	var w := _world()
	var a := _hunter(w, &"gaekgwi", 4)
	var s := Shot.new()
	s.spell = Spell.make([Cards.ORB])
	s.faction = a.faction
	s.pos = a.pos - E
	s.dir = Vector2i(0, 1)
	s.life = 4
	w.shots.append(s)
	assert_false(Mind._walkable(w, a).call(s.pos))


func test_a_creature_felled_by_the_step_does_not_stop_the_projectile() -> void:
	var w := _world()
	var a := _hunter(w, &"gaekgwi", 9)
	a.hp = 1
	w.act({t = &"cast", spells = [{cards = [Cards.ORB], dir = E}]})
	var s: Shot = w.shots[0]
	w.set_tile(s.pos, World.THORNS)
	a.pos = s.pos + E
	var from := w.events.size()
	Mind._walk(w, a, s.pos)
	assert_false(a.alive(), "the thorns fell it")
	assert_false(s.gone)
	assert_false(w.events.slice(from).any(func(e): return e.t == &"hit"))
