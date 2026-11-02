extends GutTest
## A creature's 번개: it crosses its whole range the moment it is loosed and stays nowhere,
## where a wisp flies by the round and hovers at its end.

const E := Vector2i(1, 0)
const ME := Vector2i(30, 12)
const FROM := Vector2i(10, 8)


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
	w.sense()
	return w


func _general(w: World) -> Actor:
	var a := FloorGen.spawn(w, &"jiha", FROM)
	a.magic.cooldown = 99
	return a


func _bolt() -> Spell:
	return Bestiary.spell(&"jiha", [Cards.FOX, Cards.METAL])


func test_a_bolt_crosses_its_whole_range_at_once_and_stays_nowhere() -> void:
	var w := _world()
	w.events = []
	Cast.cast(w, _general(w), _bolt(), E)
	var flown := w.events.filter(func(e): return e.t == &"fly")
	assert_eq(flown.size(), Spell.RANGE)
	assert_eq(flown.back().to, FROM + E * Spell.RANGE)
	assert_true(w.shots.all(func(s): return s.gone), "nothing hangs in the air")
	assert_true(w.events.filter(func(e): return e.t == &"land").is_empty())


func test_a_bolt_strikes_the_first_creature_on_its_line_the_moment_it_is_loosed() -> void:
	var w := _world()
	var a := _general(w)
	w.player().pos = FROM + E * 5
	w.sense()
	w.events = []
	Cast.cast(w, a, _bolt(), E)
	assert_lt(w.player().hp, 3)
	assert_true(w.shots.all(func(s): return s.gone))


func test_a_bolt_ends_at_a_wall_and_stays_nowhere() -> void:
	var w := _world()
	w.set_tile(FROM + E * 3, World.WALL)
	Cast.cast(w, _general(w), _bolt(), E)
	assert_true(w.shots.all(func(s): return s.gone))
	assert_eq(w.tile(FROM + E * 3), World.WALL)


func test_her_bullet_still_flies_by_the_round_and_hovers_at_its_end() -> void:
	var w := _world()
	var bullet := Spell.make([Cards.FOX, Cards.METAL])
	Cast.cast(w, w.player(), bullet, E)
	assert_eq(w.shots.size(), 1)
	assert_false(w.shots[0].gone)
	assert_lt(w.shots[0].flown, Spell.RANGE)
	for i in 3:
		w.act({t = &"wait"})
	assert_eq(w.shots[0].dir, Vector2i.ZERO, "it hovers")


func test_a_bolt_thunders_when_it_is_loosed() -> void:
	var w := _world()
	w.events = []
	Cast.cast(w, _general(w), _bolt(), E)
	var cast: Dictionary = w.events.filter(func(e): return e.t == &"cast")[0]
	assert_has(Sfx.sounds_of(cast), &"thunder")


func test_a_bolt_heard_out_of_sight_thunders() -> void:
	assert_eq(Sfx.sound_of({t = &"noise", word = _bolt().cast_word()}), &"thunder")
