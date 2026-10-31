extends GutTest
## A foxfire wisp that strikes a creature sticks to it and keeps lighting it.

const FOX := Cards.FOX
const E := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const WAIT := {t = &"wait"}


## An open hall walled at the edges, with no light, Miho at `at` and five tails.
func _world(at := Vector2i(4, 8)) -> World:
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
	me.hp = 3
	me.max_hp = 3
	me.pos = at
	w.actors.append(me)
	w.depth = 13
	w.tails = 5
	w.cards.assign(Cards.ALL)
	return w


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func _foe(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


## A world where a lone wisp has struck a static creature three tiles east.
func _stuck() -> Array:
	var w := _world()
	var foe := _foe(w, &"jangseung", Vector2i(7, 8))
	w.act(_cast([FOX]))
	return [w, foe]


func test_a_wisp_that_strikes_a_creature_sticks_to_it_and_lights_its_tile() -> void:
	var s := _stuck()
	var w: World = s[0]
	var foe: Actor = s[1]
	assert_eq(w.shots.size(), 1, "it does not vanish on the creature")
	var wisp: Shot = w.shots[0]
	assert_eq(wisp.pos, foe.pos)
	assert_eq(wisp.dir, Vector2i.ZERO)
	assert_eq(wisp.life, Spell.WISP_LIFE - 1, "burns WISP_LIFE rounds from the hit")
	assert_true(w.lit(foe.pos + Vector2i(2, 0)))
	assert_false(w.lit(foe.pos + Vector2i(6, 0)))
	assert_eq(foe.hp, foe.max_hp, "a lone wisp harms nothing, stuck or not")


func test_a_stuck_wisp_rides_the_creature_and_its_light_follows() -> void:
	var s := _stuck()
	var w: World = s[0]
	var foe: Actor = s[1]
	var wisp: Shot = w.shots[0]
	var to := Vector2i(7, 12)
	w.move(foe, to)
	assert_eq(wisp.pos, to, "on the creature's new tile")
	assert_true(w.lit(to + Vector2i(2, 0)))
	assert_false(w.lit(Vector2i(7, 8)), "the old tile is dark again")
	w.act(WAIT)
	assert_eq(wisp.pos, foe.pos)
	assert_eq(foe.hp, foe.max_hp, "it strikes no more")
	assert_eq(w.shots.size(), 1)


func test_the_wisp_goes_out_after_wisp_life_rounds_from_the_hit() -> void:
	var s := _stuck()
	var w: World = s[0]
	var foe: Actor = s[1]
	for i in Spell.WISP_LIFE - 2:
		w.act(WAIT)
	assert_eq(w.shots.size(), 1, "still burning the round before")
	assert_true(w.lit(foe.pos))
	w.act(WAIT)
	assert_true(w.shots.is_empty())
	assert_false(w.lit(foe.pos))


func test_several_wisps_stick_to_one_creature() -> void:
	var w := _world()
	var foe := _foe(w, &"bulgae", Vector2i(7, 8))
	foe.hp = 9
	foe.max_hp = 9
	w.act(_cast([FOX, FOX]))
	assert_eq(w.shots.size(), 2)
	assert_true(w.shots.all(func(s): return s.pos == foe.pos and s.dir == Vector2i.ZERO))


func test_the_wisp_hovers_where_its_creature_died_for_the_rest_of_its_life() -> void:
	var s := _stuck()
	var w: World = s[0]
	var foe: Actor = s[1]
	var wisp: Shot = w.shots[0]
	var at := foe.pos
	w.hurt(foe, foe.hp)
	w.act(WAIT)
	assert_false(foe.alive())
	assert_eq(w.shots.size(), 1)
	assert_eq(wisp.pos, at, "it stays where it was")
	assert_true(w.lit(at))
	assert_true(w.vacant(at), "creatures may share it as any hovering wisp")
	assert_eq(wisp.life, Spell.WISP_LIFE - 2)


func test_a_bullet_does_not_stick() -> void:
	var w := _world()
	var foe := _foe(w, &"jangseung", Vector2i(7, 8))
	w.act(_cast([FOX, Cards.METAL]))
	assert_true(w.shots.is_empty())
	assert_lt(foe.hp, foe.max_hp)
	assert_false(w.lit(foe.pos))


func test_a_creature_that_eats_the_spell_gets_no_wisp() -> void:
	var w := _world()
	var foe := _foe(w, &"bulgasari", Vector2i(7, 8))
	w.act(_cast([FOX]))
	assert_true(w.shots.is_empty(), "absorbed")
	assert_false(w.lit(foe.pos))


func test_a_heaven_wisp_sticks_to_miho_and_lights_her() -> void:
	var w := _world(Vector2i(8, 8))
	var foe := _foe(w, &"bulgae", Vector2i(4, 8))
	w.cast(foe, Spell.make([FOX]), E)
	w.act(WAIT)
	assert_eq(w.shots.size(), 1)
	var wisp: Shot = w.shots[0]
	assert_eq(wisp.pos, w.player().pos)
	assert_true(w.lit(w.player().pos))
	w.move(w.player(), Vector2i(9, 8))
	assert_eq(wisp.pos, Vector2i(9, 8), "it rides her")
	assert_true(w.sees(foe, Vector2i(9, 8)), "heaven sees her in the light")


func test_a_stuck_wisp_does_not_block_a_projectile_or_a_step() -> void:
	var s := _stuck()
	var w: World = s[0]
	var foe: Actor = s[1]
	w.act(_cast([Cards.ORB]))
	assert_lt(foe.hp, foe.max_hp, "the orb strikes the creature, not the wisp")
	assert_eq(w.shots.size(), 1, "the wisp is not snuffed")
	assert_true(w.can({t = &"move", dir = E}))


func test_a_clone_and_the_forecast_agree_on_a_stuck_wisp() -> void:
	var s := _stuck()
	var w: World = s[0]
	var foe: Actor = s[1]
	w.move(foe, Vector2i(7, 9))
	var copy := w.clone()
	var wisp: Shot = copy.shots[0]
	assert_eq(wisp.host, foe.id)
	assert_eq(wisp.pos, Vector2i(7, 9))
	var forecast := Forecast.of(w, WAIT)
	w.act(WAIT)
	var real: Shot = w.shots[0]
	var seen: Shot = forecast.after.shots[0]
	assert_eq([seen.pos, seen.life, seen.host], [real.pos, real.life, real.host])
	assert_eq(forecast.after.rng.state, w.rng.state)


func test_the_forecast_keeps_the_creature_a_wisp_struck_as_its_target() -> void:
	var w := _world()
	var foe := _foe(w, &"dokkaebi", Vector2i(6, 8))
	w.sense()
	var f := Forecast.of(w, _cast([FOX, FOX]))
	assert_eq(f.paths.values().map(func(p): return p.target), [foe.id, foe.id])
	assert_true(f.paths.values().all(func(p): return p.live))


func test_a_wisp_tells_it_sticks_and_a_bullet_does_not() -> void:
	var wisp := Info.plain(SpellInfo.spell(Spell.make([FOX])))
	assert_string_contains(wisp, "붙어서 %d초 빛난다" % Spell.WISP_LIFE)
	var bullet := Info.plain(SpellInfo.spell(Spell.make([FOX, Cards.METAL])))
	assert_false(bullet.contains("붙어서"))
