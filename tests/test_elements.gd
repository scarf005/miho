extends GutTest
## Each element on a wisp and on an orb, stacked copies, the wooden wall, the
## hover lines and the forecast of every effect.

const FOX := Cards.FOX
const ORB := Cards.ORB
const FIRE := Cards.FIRE
const WATER := Cards.WATER
const WOOD := Cards.WOOD
const METAL := Cards.METAL
const EARTH := Cards.EARTH
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(20, 12)


## An open hall walled at the edges, with no light, Miho at ME and five tails.
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
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = 5
	w.tails = 5
	w.cards.assign(Cards.ALL)
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts: a 장승 (no element, 3 health).
func _post(w: World, at: Vector2i, kind := &"jangseung") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.magic.cooldown = 99
	return a


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


func _harm(events: Array) -> int:
	var n := 0
	for e in _of(events, &"hurt"):
		n += e.n
	return n


func test_a_one_talisman_spell_harms_for_at_most_one() -> void:
	for c in Cards.ALL:
		var w := _world()
		var foe := _post(w, ME + Vector2i(2, 0))
		foe.hp = 20
		var events := w.act(_cast([c]))
		events.append_array(w.act(WAIT))
		assert_lte(_harm(events), 1, str(c))


func test_power_grows_with_the_tails_spent() -> void:
	assert_eq(Spell.make([FOX, METAL]).damage(0), Elements.BULLET)
	assert_eq(Spell.make([FOX, METAL, METAL]).damage(0), Elements.BULLET + 1, "쇠 again: +1")
	assert_eq(Spell.make([ORB, METAL]).damage(0), 1 + Elements.CANNON)
	assert_eq(Spell.make([ORB, METAL, METAL]).damage(0), 2 + Elements.CANNON)
	assert_eq(Spell.make([ORB, METAL]).damage(Spell.MOMENTUM), 2 + Elements.CANNON, "run-up")
	assert_eq(Spell.make([FOX, FIRE, FIRE]).damage(0), 2, "불 again: +1")
	assert_eq(Spell.make([FOX, WOOD]).damage(0), 1, "the other elements add no harm")


# --- 화 ---------------------------------------------------------------------


func test_a_fire_wisp_sets_any_creature_it_strikes_alight() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	foe.hp = 9
	w.act(_cast([FOX, FIRE]))
	assert_gt(foe.ailments.alight, 0, "no wood, yet it burns")
	assert_eq(foe.hp, 9 - 1, "hit for 1; the flames it lit hurt from the next round")
	w.act(WAIT)
	assert_eq(foe.hp, 9 - 1 - World.FIRE_DAMAGE, "and each round after")


## A 부지깽이 도깨비 two tiles east has hurled its fire wisp at Miho, who has 5
## health; the round is not yet run.
func _wisp_at_miho() -> World:
	var w := _world()
	w.player().hp = 5
	w.player().max_hp = 5
	var foe := _post(w, ME + Vector2i(2, 0), &"bujigaengi")
	foe.ailments.rooted = 99
	Cast.cast(w, foe, Bestiary.spell(foe.kind, foe.info().casts[0]), -E)
	w.sense()
	return w


func test_a_wisp_hit_hurts_for_its_own_harm_and_leaves_her_on_a_burning_tile() -> void:
	var w := _wisp_at_miho()
	w.act(WAIT)
	assert_eq(w.player().hp, 5 - 1, "the wisp's 1, not the flames it lit")
	assert_true(w.burning.has(ME))


func test_staying_a_round_in_the_flames_costs_the_fire_damage() -> void:
	var w := _wisp_at_miho()
	w.act(WAIT)
	w.act(WAIT)
	assert_eq(w.player().hp, 5 - 1 - World.FIRE_DAMAGE)


func test_stepping_off_the_flames_costs_nothing() -> void:
	var w := _wisp_at_miho()
	w.act(WAIT)
	w.act({t = &"move", dir = Vector2i(0, 1)})
	assert_eq(w.player().hp, 5 - 1)


func test_stepping_into_flames_burning_since_before_the_round_hurts() -> void:
	var w := _world()
	w.burning[ME + E] = World.BURN_ROUNDS - 1
	w.act({t = &"move", dir = E})
	assert_eq(w.player().hp, 3 - World.FIRE_DAMAGE)


func test_a_fire_orb_splash_hurts_at_once_and_only_once() -> void:
	var w := _world()
	_post(w, ME + Vector2i(2, 0))
	var side := _post(w, ME + Vector2i(2, 1))
	side.hp = 9
	w.act(_cast([ORB, FIRE]))
	assert_eq(9 - side.hp, World.FIRE_DAMAGE, "the burst, the same round")
	w.act(WAIT)
	assert_eq(9 - side.hp, World.FIRE_DAMAGE, "bare floor keeps no flames to hurt it again")


func test_the_forecast_of_a_wisp_hit_counts_its_harm_but_not_the_flames_it_lights() -> void:
	var w := _wisp_at_miho()
	assert_eq(Forecast.of(w, WAIT).hurt_me(), 1)
	w.act(WAIT)
	assert_eq(Forecast.of(w, WAIT).hurt_me(), World.FIRE_DAMAGE, "staying costs the burn")
	assert_eq(
		Forecast.of(w, {t = &"move", dir = Vector2i(0, 1)}).hurt_me(), 0, "a step off is free"
	)


func test_a_fire_orb_sets_only_a_wood_creature_alight_and_bursts_round_it() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	var side := _post(w, ME + Vector2i(2, 1))
	side.hp = 9
	_put(w, ME + Vector2i(1, 1), World.BOARD)
	w.act(_cast([ORB, FIRE, FIRE]))
	assert_false(w.burning.has(foe.pos))
	assert_eq(9 - side.hp, World.FIRE_DAMAGE + 1, "the burst, 1 more a copy")
	assert_true(w.burning.has(ME + Vector2i(1, 1)), "what burns round it catches")


# --- 수 ---------------------------------------------------------------------


func test_a_water_wisp_is_silent_and_douses_the_fire_on_the_creature_it_strikes() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	Terrain.ignite(w, foe.pos, true)
	var events := w.act(_cast([FOX, WATER]))
	assert_true(_of(events, &"noise").all(func(e): return e.word != "휙"), "no cast sound")
	assert_eq(Spell.make([FOX, WATER]).cast_noise(), 0)
	assert_false(w.burning.has(foe.pos))
	assert_eq(_of(events, &"douse").size(), 1)


func test_a_water_orb_douses_the_3x3_round_where_it_bursts_and_no_farther() -> void:
	var w := _world()
	_put(w, ME + Vector2i(4, 0), World.WALL)
	for p: Vector2i in [ME + Vector2i(2, 1), ME + Vector2i(1, -1)]:
		_put(w, p, World.BOARD)
		Terrain.ignite(w, p)
	_put(w, ME + Vector2i(3, -1), World.LANTERN)
	w.act(_cast([ORB, WATER]))
	w.act(WAIT)
	assert_false(w.burning.has(ME + Vector2i(2, 1)), "next to where it burst")
	assert_eq(w.tile(ME + Vector2i(3, -1)), World.LANTERN_OUT)
	assert_true(w.burning.has(ME + Vector2i(1, -1)), "two tiles off it still burns")


# --- 금 ---------------------------------------------------------------------


func test_a_metal_wisp_is_a_fast_dark_loud_bullet() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(5, 0))
	foe.hp = 9
	var events := w.act(_cast([FOX, METAL]))
	assert_eq(foe.hp, 9 - Elements.BULLET, "it reaches 5 tiles in the round it is cast")
	var bang: Dictionary = _of(events, &"noise")[0]
	assert_eq([bang.word, bang.loud], ["탕", Spray.GUN_LOUD])
	assert_eq(Spell.make([FOX, METAL]).speed(), Spell.BULLET_SPEED)
	assert_eq(Spell.make([FOX, METAL]).light(Actor.FOX), {})
	assert_eq(Spell.make([ORB]).speed(), Spell.ORB_SPEED)
	assert_eq(Spell.make([ORB, ORB]).speed(), Spell.ORB_SPEED + 1)
	assert_eq(Spell.make([FOX, ORB, ORB, ORB]).speed(), Spell.ORB_SPEED + 2, "homing too")
	assert_eq(Spell.make([ORB, ORB, ORB, ORB, ORB]).speed(), Spell.BULLET_SPEED, "never past it")
	var lone := _world()
	lone.act(_cast([ORB]))
	var three := _world()
	three.act(_cast([ORB, ORB, ORB]))
	assert_eq(three.shots[0].pos.x - lone.shots[0].pos.x, 2, "it flies that much farther")
	var far := _world()
	far.act(_cast([FOX, METAL]))
	var plain := _world()
	plain.act(_cast([FOX]))
	assert_eq(
		far.shots[0].pos.x - plain.shots[0].pos.x,
		Spell.BULLET_SPEED - Spell.WISP_SPEED,
		"farther in a round than a wisp"
	)


func test_a_gun_lights_the_casters_tile_for_the_round_it_fires() -> void:
	for cards: Array in [[FOX, METAL], [ORB, METAL]]:
		var w := _world()
		assert_false(w.lit(ME))
		Cast.cast(w, w.player(), Spell.make(cards), E)
		assert_true(w.lit(ME), "the muzzle flash of %s" % [cards])
		w.act(WAIT)
		assert_false(w.lit(ME), "for that round only")
	var watcher := _world()
	var foe := _post(watcher, ME + Vector2i(-6, 0))
	foe.brain.home += E  # awake: one at its home sleeps
	watcher.act(_cast([FOX, METAL]))
	assert_eq(foe.brain.alert, Actor.HUNT, "a creature that sees the flash sees Miho")
	var quiet := _world()
	var other := _post(quiet, ME + Vector2i(-6, 0))
	other.brain.home += E  # awake: one at its home sleeps
	quiet.act(_cast([FOX]))
	assert_ne(other.brain.alert, Actor.HUNT, "a wisp gives her no light")


func test_a_cannonball_hits_harder_pushes_two_and_booms() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	foe.hp = 9
	var events := w.act(_cast([ORB, METAL]))
	assert_eq(foe.hp, 9 - 1 - Elements.CANNON)
	assert_eq(foe.pos, ME + Vector2i(2 + Elements.CANNON_PUSH, 0))
	assert_eq(_of(events, &"push").size(), 1)
	var boom: Dictionary = _of(events, &"noise")[0]
	assert_eq([boom.word, boom.loud], ["쾅", Elements.CANNON_LOUD])
	var stacked := _world()
	var other := _post(stacked, ME + Vector2i(2, 0))
	other.hp = 9
	stacked.act(_cast([ORB, METAL, METAL]))
	assert_eq(other.hp, 9 - 2 - Elements.CANNON, "1 more a copy")


func test_a_cannonball_pushes_a_creature_into_the_sky() -> void:
	var w := _world()
	_put(w, ME + Vector2i(4, 0), World.SKY)
	var foe := _post(w, ME + Vector2i(2, 0))
	foe.hp = 9
	var events := w.act(_cast([ORB, METAL]))
	assert_false(foe.alive())
	assert_eq(_of(events, &"fall").size(), 1)


## A heaven projectile at `at` flying along `dir`, cast by `caster`.
func _heaven_shot(w: World, caster: Actor, cards: Array, at: Vector2i, dir: Vector2i) -> Shot:
	var s := Shot.new()
	s.id = w.new_id()
	s.faction = Actor.HEAVEN
	s.caster = caster.id
	s.spell = Spell.make(cards)
	s.origin = caster.pos
	s.pos = at
	s.dir = dir
	w.shots.append(s)
	return s


func test_a_cannonball_that_pushes_miho_upstairs_leaves_the_other_projectiles_behind() -> void:
	var w := _world()
	w.player().hp = 9
	w.stairs = ME + Vector2i(-1, 0)
	var caster := _post(w, ME + Vector2i(6, 0), &"imugi")
	_heaven_shot(w, caster, [ORB, METAL], ME + Vector2i(2, 0), Vector2i(-1, 0))
	_heaven_shot(w, caster, [FOX], ME + Vector2i(0, 6), Vector2i(0, -1))
	var events := w.act(WAIT)
	assert_eq(w.depth, 6, "pushed onto the stairs")
	var up := events.find(events.filter(func(e): return e.t == &"ascend")[0])
	var later := events.slice(up).filter(func(e): return e.has("shot"))
	assert_eq(later, [], "nothing of the storey below flies on")
	assert_eq(w.shots, [] as Array[Shot])


# --- 토 and the walls a heavy orb fells -------------------------------------


func test_an_earth_or_metal_orb_fells_a_wall_in_one_blow_a_plain_orb_cracks_it() -> void:
	for c in [[ORB, EARTH, World.RUBBLE], [ORB, METAL, World.RUBBLE], [ORB, World.WALL_CRACKED]]:
		var w := _world()
		var at := ME + Vector2i(3, 0)
		_put(w, at, World.WALL)
		var events := w.act(_cast(c.slice(0, -1)))
		events.append_array(w.act(WAIT))
		assert_eq(w.tile(at), c.back(), str(c))
		var thuds := _of(events, &"noise").filter(func(e): return e.word == "쿵")
		assert_true(thuds.all(func(e): return e.loud == World.THUD), "쿵 %d" % World.THUD)
		assert_false(thuds.is_empty())


func test_an_earth_wisp_stuns_a_round_more_a_copy_and_an_earth_orb_does_not_stun() -> void:
	for c in [
		[[FOX, EARTH], Elements.STUN], [[FOX, EARTH, EARTH], Elements.STUN + 1], [[ORB, EARTH], 0]
	]:
		var w := _world()
		var foe := _post(w, ME + Vector2i(2, 0))
		foe.hp = 9
		var events := w.act(_cast(c[0]))
		var stuns := _of(events, &"stun")
		assert_eq(stuns[0].rounds if not stuns.is_empty() else 0, c[1], str(c[0]))


# --- 목 ---------------------------------------------------------------------


func test_a_wood_wisp_roots_a_round_more_a_copy_and_a_wood_orb_does_not_root() -> void:
	for c in [
		[[FOX, WOOD], Elements.ROOT], [[FOX, WOOD, WOOD], Elements.ROOT + 1], [[ORB, WOOD], 0]
	]:
		var w := _world()
		var foe := _post(w, ME + Vector2i(2, 0))
		foe.hp = 9
		var events := w.act(_cast(c[0]))
		var roots := _of(events, &"root")
		assert_eq(roots[0].rounds if not roots.is_empty() else 0, c[1], str(c[0]))


func test_a_wood_orb_grows_a_wall_across_its_line_where_it_bursts() -> void:
	var w := _world()
	_put(w, ME + Vector2i(3, 0), World.WALL)
	var events := w.act(_cast([ORB, WOOD]))
	var at := ME + Vector2i(2, 0)
	for dy in [-1, 0, 1]:
		assert_eq(w.tile(at + Vector2i(0, dy)), World.WOOD_WALL, "dy %d" % dy)
	for dy in [-2, 2]:
		assert_eq(w.tile(at + Vector2i(0, dy)), World.FLOOR, "%d tiles only" % Elements.WALL)
	assert_eq(_of(events, &"sprout").size(), 1)
	var stacked := _world()
	_put(stacked, ME + Vector2i(3, 0), World.WALL)
	stacked.act(_cast([ORB, WOOD, WOOD]))
	var grown := range(-2, 3).filter(
		func(dy): return stacked.tile(at + Vector2i(0, dy)) == World.WOOD_WALL
	)
	assert_eq(grown.size(), Elements.WALL + 1, "a tile more a copy")


func test_a_diagonal_wood_orb_grows_a_wall_with_no_gap_to_slip_through() -> void:
	for dir: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		for cards in [[ORB, WOOD], [ORB, WOOD, WOOD, WOOD]]:
			var tiles := Elements.wall_tiles(Spell.make(cards), ME, dir)
			assert_eq(tiles.size(), Elements.WALL + cards.count(WOOD) - 1)
			assert_eq(tiles[0], ME, "centred where it ends")
			for p in tiles:
				var touching := tiles.filter(func(q): return absi(q.x - p.x) + absi(q.y - p.y) == 1)
				assert_false(touching.is_empty(), "%s: %s shares an edge with the wall" % [dir, p])
			var across := Vector2i(-dir.y, dir.x)
			for k in [1, -1]:
				var side := func(q):
					return (q - ME).x * across.x * k > 0 or (q - ME).y * across.y * k > 0
				assert_true(tiles.any(side), "%s: it reaches both sides" % dir)


func test_a_wood_wall_grows_round_a_struck_creature_and_never_on_doors_or_stairs() -> void:
	var w := _world()
	var foe := _post(w, ME + Vector2i(2, 0))
	foe.hp = 9
	_put(w, foe.pos + Vector2i(0, -1), World.DOOR)
	w.stairs = foe.pos + Vector2i(0, 1)
	var events := w.act(_cast([ORB, WOOD]))
	assert_true(foe.alive())
	assert_eq(w.tile(foe.pos), World.FLOOR, "not under the creature")
	assert_eq(w.tile(foe.pos + Vector2i(0, -1)), World.DOOR)
	assert_eq(w.tile(foe.pos + Vector2i(0, 1)), World.FLOOR, "not on the stairs")
	assert_true(_of(events, &"sprout").is_empty(), "nothing grew")


# --- the wooden wall --------------------------------------------------------


func test_a_wooden_wall_blocks_walking_sight_and_light() -> void:
	var w := _world()
	var at := ME + E
	_put(w, at, World.WOOD_WALL)
	assert_false(w.open_floor(at))
	assert_false(w.open_air(at))
	assert_true(w.opaque(at))
	assert_true(w.blocks_light(at))
	assert_false(w.can({t = &"move", dir = E}))


func test_a_wooden_wall_burns_to_ash() -> void:
	var w := _world()
	var at := ME + Vector2i(3, 0)
	_put(w, at, World.WOOD_WALL)
	Terrain.ignite(w, at)
	assert_true(w.burning.has(at))
	assert_false(w.opaque(at), "nothing burning blocks sight")
	for i in World.BURN_ROUNDS:
		w.act(WAIT)
	assert_eq(w.tile(at), World.ASH)


func test_one_orb_breaks_a_wooden_wall_to_floor() -> void:
	var w := _world()
	var at := ME + Vector2i(3, 0)
	_put(w, at, World.WOOD_WALL)
	_put(w, ME + Vector2i(2, 2), World.LANTERN)
	assert_eq(Tiles.of(World.WOOD_WALL, "health"), 1)
	w.sense()
	var before := w.clone()
	var events := w.act(_cast([ORB]))
	assert_eq(w.tile(at), World.FLOOR)
	assert_has(Messages.of(before, w, events).map(Messages.plain), "나무벽이 부서졌다")


func test_hovering_a_wooden_wall_tells_its_rules() -> void:
	var w := _world()
	var at := ME + E
	_put(w, at, World.WOOD_WALL)
	w.sense()
	var text := Info.plain(Info.terrain(w, at))
	assert_true(text.begins_with("%s %s" % [Tiles.of(World.WOOD_WALL, "name"), Info.hearts(1, 1)]))
	assert_string_contains(text, "막음: 길, 시야, 빛")
	assert_string_contains(text, "\n가연성.")


# --- the hover lines --------------------------------------------------------


func test_a_spell_tells_every_element_number_by_its_form() -> void:
	var cases := [
		[[FOX, FIRE], ["불타는 칸: 지나간 가연성·인화성 칸", "불붙음: %d초" % Status.ALIGHT]],
		[[ORB, FIRE, FIRE], ["폭발: 주위 8칸, 피해 %d" % (World.FIRE_DAMAGE + 1)]],
		[[ORB, WATER], ["꺼짐: 멈춘 곳 3×3의 불, 등불", "소음: 없음"]],
		[
			[FOX, METAL, METAL],
			[
				"발당 피해: %d" % (Elements.BULLET + 1),
				"초당 %d칸" % Spell.BULLET_SPEED,
				"빛: 없음\n발사 빛: 쏜 칸",
				"소음: %d" % Spray.GUN_LOUD,
			]
		],
		[
			[ORB, METAL],
			[
				"밀침: %d칸" % Elements.CANNON_PUSH,
				"소음: %d" % Elements.CANNON_LOUD,
				"발사 빛: 쏜 칸",
			]
		],
		[[FOX, EARTH, EARTH], ["기절: %d초" % (Elements.STUN + 1), "멈춘 곳 소음: %d" % World.THUD]],
		[[ORB, EARTH], ["벽: 한 번에 부술 수 있다", "멈춘 곳 소음: %d" % World.THUD]],
		[[FOX, WOOD], ["묶임: %d초" % Elements.ROOT]],
		[[ORB, WOOD, WOOD], ["나무벽: 멈춘 곳에 직각으로 %d칸" % (Elements.WALL + 1), "나무벽 체력: 1"]],
	]
	for c in cases:
		var text := Info.plain(SpellInfo.spell(Spell.make(c[0])))
		for part: String in c[1]:
			assert_string_contains(text, part)
	var orb := Info.plain(SpellInfo.spell(Spell.make([ORB, EARTH])))
	assert_false(orb.contains("기절"), "an earth orb does not stun")


# --- messages ---------------------------------------------------------------


func test_the_log_tells_a_push_and_a_wall_that_grew() -> void:
	var w := _world()
	_put(w, ME + Vector2i(8, -2), World.LANTERN)
	_put(w, ME + Vector2i(8, 2), World.LANTERN)
	var foe := _post(w, ME + Vector2i(2, 0))
	foe.hp = 9
	w.sense()
	var before := w.clone()
	var events := w.act(_cast([ORB, METAL]))
	var lines := Messages.of(before, w, events).map(Messages.plain)
	assert_has(lines, "장승이 밀려났다")
	var grow := _world()
	_put(grow, ME + Vector2i(2, 0), World.WALL)
	grow.sense()
	var start := grow.clone()
	lines = Messages.of(start, grow, grow.act(_cast([ORB, WOOD]))).map(Messages.plain)
	assert_has(lines, "나무벽이 자랐다")


# --- forecast ---------------------------------------------------------------


## The forecast of `cards` cast east equals the round itself: every tile,
## fire, creature and harm.
func _assert_forecast_is_exact(w: World, cards: Array) -> void:
	w.sense()
	var f := Forecast.of(w, _cast(cards))
	var events := w.act(_cast(cards))
	assert_eq(f.after.tiles, w.tiles, "tiles of %s" % [cards])
	assert_eq(f.after.burning, w.burning, "fire of %s" % [cards])
	for a in w.actors:
		var b := f.after.actor(a.id)
		assert_eq(
			[b.pos, b.hp, b.ailments.rooted, b.ailments.stunned],
			[a.pos, a.hp, a.ailments.rooted, a.ailments.stunned],
			str(cards)
		)
	var grown: Array[Vector2i] = []
	for e in _of(events, &"sprout"):
		grown.append_array(e.tiles)
	assert_eq(f.sprouts, grown, "walls of %s" % [cards])


func test_the_forecast_of_every_element_effect_is_exact() -> void:
	for cards: Array in [
		[FOX, FIRE],
		[ORB, FIRE],
		[FOX, WATER],
		[ORB, WATER],
		[FOX, METAL],
		[ORB, METAL],
		[FOX, EARTH],
		[ORB, EARTH],
		[FOX, WOOD],
		[ORB, WOOD],
		[ORB, WOOD, WOOD],
	]:
		var w := _world()
		_put(w, ME + Vector2i(1, -3), World.LANTERN)
		_put(w, ME + Vector2i(1, 3), World.LANTERN)
		var foe := _post(w, ME + Vector2i(2, 0))
		foe.hp = 9
		_put(w, ME + Vector2i(5, 0), World.WALL)
		_assert_forecast_is_exact(w, cards)
		var walled := _world()
		_put(walled, ME + Vector2i(1, -3), World.LANTERN)
		_put(walled, ME + Vector2i(3, 0), World.WALL)
		_assert_forecast_is_exact(walled, cards)


func test_the_forecast_shows_where_a_wooden_wall_grows() -> void:
	var w := _world()
	_put(w, ME + Vector2i(3, 0), World.WALL)
	w.sense()
	var f := Forecast.of(w, _cast([ORB, WOOD]))
	assert_eq(f.sprouts.size(), Elements.WALL)
	assert_true(f.sprouts.has(ME + Vector2i(2, 0)))
	assert_eq(w.tile(ME + Vector2i(2, 0)), World.FLOOR, "the real world is untouched")
