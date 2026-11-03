extends GutTest
## A creature's step leaves sight as it is, so sight and light are only worked out again when
## a light has come, gone or moved, and always then.

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


## What is lit as the world has it now and as it would be worked out afresh are the same.
func _assert_light_is_current(w: World, when: String) -> void:
	var fresh := Native.lit(Light.field(Light.sources(w), Masks.shade(w)), Light.LIT)
	assert_eq(w._lit_mask(), fresh, when)


func test_a_step_with_no_light_keeps_what_was_worked_out() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"jiha", FROM)
	var view := w.fov(FROM)
	w._lit_mask()
	Walk.move(w, a, a.pos + E)
	assert_eq(w._fov.get(FROM), view)
	assert_false(w._light_dirty)


func test_a_creature_alight_takes_its_light_along() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"jiha", FROM)
	Status.ignite(w, a)
	_assert_light_is_current(w, "alight")
	for i in 8:
		Walk.move(w, a, a.pos + E)
		_assert_light_is_current(w, "step %d" % i)
	assert_true(w.lit(a.pos))


func test_a_gun_lights_its_muzzle_at_once() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"jiha", FROM)
	assert_false(w.lit(FROM))
	Cast.cast(w, a, Bestiary.spell(&"jiha", [Cards.FOX, Cards.METAL]), E)
	_assert_light_is_current(w, "after the shot")
	assert_true(w.lit(FROM))


func test_a_wisp_takes_its_light_along_and_out_when_it_strikes() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"bujigaengi", FROM)
	var foe := FloorGen.spawn(w, &"jiha", FROM + E * 8)
	Cast.cast(w, a, Bestiary.spell(a.kind, a.info().casts[0]), E)
	var wisp: Shot = w.shots[0]
	for i in 3:
		Flight.step(w, wisp)
		_assert_light_is_current(w, "step %d" % i)
	wisp.gone = true
	Flight.strike(w, wisp, foe)
	_assert_light_is_current(w, "struck")


func test_a_glowing_wisp_on_a_creature_goes_along_with_it() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"bujigaengi", FROM)
	var foe := FloorGen.spawn(w, &"jiha", FROM + E * 2)
	Cast.cast(w, a, Bestiary.spell(a.kind, a.info().casts[0]), E)
	var wisp: Shot = w.shots[0]
	assert_true(Light.glows(wisp))
	Elements.stick(w, wisp, foe)
	_assert_light_is_current(w, "stuck")
	for i in 4:
		Walk.move(w, foe, foe.pos + E)
		_assert_light_is_current(w, "step %d" % i)


func test_a_wisp_an_orb_snuffs_stops_lighting() -> void:
	var w := _world()
	var a := FloorGen.spawn(w, &"bujigaengi", FROM)
	Cast.cast(w, a, Bestiary.spell(a.kind, a.info().casts[0]), E)
	var wisp: Shot = w.shots[0]
	wisp.dir = Vector2i.ZERO
	wisp.pos = FROM + E * 3
	w._changed()
	var orb := Flight.spawn(w, a, Spell.make([Cards.ORB]), E, 0)
	orb.pos = FROM + E * 2
	w._lit_mask()
	Flight.step(w, orb)
	assert_true(wisp.gone)
	_assert_light_is_current(w, "snuffed")


func test_a_walk_mask_says_what_the_test_says_at_every_tile_that_can_differ() -> void:
	for s in 12:
		var w := World.create(s)
		Storeys.enter(w, 1 + s % World.FLOORS)
		var foes := w.actors.filter(func(a): return not a.is_miho())
		foes[-1].hp = 0
		w.burning[w.player().pos + E] = 3
		Cast.cast(w, foes[0], Spell.make([Cards.FOX]), E)
		for a: Actor in foes:
			if a.alive():
				var test := Mind._walkable(w, a)
				var ground := Bestiary.ground(a.kind)
				var every := Grid.mask(w.tiles, ground, Masks.odd(w) + [a.pos], test)
				assert_eq(Masks.walk(w, a, test), every, "%s on seed %d" % [a.kind, s])
