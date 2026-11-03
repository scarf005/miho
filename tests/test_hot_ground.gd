extends GutTest
## A creature keeps off hot iron however it picks its way (Mind._walkable), but for one that
## flies or absorbs fire, which it does not harm (Compounds.spared).

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


func test_a_flyer_and_a_fire_absorber_count_a_way_across_hot_iron() -> void:
	for kind: StringName in [&"bakjwi", &"samjogo", &"bulgae"]:
		var w := _world()
		var a := FloorGen.spawn(w, kind, FROM)
		_hot_column(w)
		var open := Masks.walk(w, a, Mind._walkable(w, a))
		assert_gt(Grid.search(a.pos, open).dist[Grid.index(FROM + Vector2i(2, 0))], 0, kind)


func test_a_flyer_and_a_fire_absorber_on_hot_iron_take_no_harm_and_no_word_of_it() -> void:
	for kind: StringName in [&"bakjwi", &"bulgae"]:
		var w := _world()
		var a := FloorGen.spawn(w, kind, ME + Vector2i(8, 0))
		a.magic.cooldown = 99
		a.ailments.rooted = 9
		a.hp = 9
		a.max_hp = 9
		w.hot[a.pos] = Vector2i(Compounds.MOLTEN, 3)
		assert_false(Info.plain(Info.creature(w, a)).contains("초당 피해"), kind)
		var events := w.act({t = &"wait"})
		assert_eq(a.hp, 9, kind)
		assert_false(events.any(func(e): return e.t in [&"sear", &"absorb"] and e.id == a.id), kind)


func test_a_walker_on_hot_iron_is_seared_and_told_so() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"jangseung", ME + Vector2i(8, 0))
	a.magic.cooldown = 99
	a.hp = 9
	a.max_hp = 9
	w.hot[a.pos] = Vector2i(Compounds.MOLTEN, 3)
	assert_string_contains(Info.plain(Info.creature(w, a)), "초당 피해")
	w.act({t = &"wait"})
	assert_eq(a.hp, 9 - Compounds.HOT[Compounds.MOLTEN].harm)


func test_a_deep_fire_absorber_leaps_onto_hot_iron_and_a_deep_dokkaebi_does_not() -> void:
	for kind: StringName in [&"bujigaengi", &"dokkaebi"]:
		var w := _world()
		var a := FloorGen.spawn(w, kind, ME - Vector2i(9, 0))
		var spell := Bestiary.spell(kind, Bestiary.LEAP)
		var to := Leap.landing(w, a.pos, Vector2i(1, 0), spell.leap())
		w.hot[to] = Vector2i(Compounds.MOLTEN, 3)
		assert_eq(Aim._leap(w, a, spell, w.player()).is_empty(), kind == &"dokkaebi", kind)
