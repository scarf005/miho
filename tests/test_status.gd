extends GutTest
## The statuses water, fire and frost leave on creatures (Status): what causes
## each, what it does, what ends it, how Miho takes it, and that the preview
## shows each as the round plays it.

const FOX := Cards.FOX
const ORB := Cards.ORB
const FIRE := Cards.FIRE
const WATER := Cards.WATER
const METAL := Cards.METAL
const E := Vector2i(1, 0)
const W := Vector2i(-1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(20, 12)
const FROST := [METAL, WATER]


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
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts: a 장승 (no element, 3 health), at its
## listed health (Bestiary hp) whatever the storey's rank.
func _post(w: World, at: Vector2i, kind := &"jangseung") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.magic.cooldown = 99
	a.hp = Bestiary.hp(kind, 1)
	a.max_hp = a.hp
	w.sense()
	return a


func _of(events: Array, t: StringName) -> Array:
	return events.filter(func(e): return e.t == t)


## The preview of `action` and the round it plays agree on every creature's statuses.
func _forecast_is_the_round(w: World, action: Dictionary) -> void:
	var f := Forecast.of(w, action)
	w.act(action)
	for a in w.actors:
		var b := f.after.actor(a.id)
		assert_eq(
			[b.ailments.wet, b.ailments.alight, b.ailments.frozen, b.ailments.rooted, b.hp],
			[a.ailments.wet, a.ailments.alight, a.ailments.frozen, a.ailments.rooted, a.hp],
			"%s %s" % [action, a.kind]
		)
	assert_eq(f.after.burning, w.burning, str(action))


# --- 젖음 -------------------------------------------------------------------


func test_a_water_wisp_wets_whoever_stands_round_where_it_ends() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	var events := w.act(_cast([FOX, WATER]))
	assert_eq(foe.ailments.wet, Status.WET - 1, "wet, a round of it gone")
	assert_eq(w.player().ailments.wet, 0, "Miho stands outside the 3x3")
	assert_eq(_of(events, &"wet").size(), 1)
	assert_eq(Status.of(foe), &"wet")


func test_a_water_orb_bursting_next_to_miho_wets_her_too() -> void:
	var w := _world()
	_put(w, ME + E * 2, World.WALL)
	w.act(_cast([ORB, WATER]))
	assert_eq(w.player().ailments.wet, Status.WET - 1)


func test_a_jet_wets_the_creature_it_pushes() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	w.act(_cast([WATER]))
	assert_eq(foe.pos, ME + E * 3, "pushed")
	assert_eq(foe.ailments.wet, Status.WET - 1)


func test_steam_wets_whoever_stands_in_it() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	for p in Spray.square(w, foe.pos):
		Gas.put(w, p, Gas.STEAM, Gas.MAX)
	w.act(WAIT)
	assert_eq(foe.ailments.wet, Status.WET - 1)
	assert_eq(w.player().ailments.wet, 0, "no steam on her")


func test_a_wet_step_splashes_two_tiles_and_alarms_heaven() -> void:
	var w := _world()
	var near := _post(w, ME + W + Vector2i(0, -2), &"imugi")
	var far := _post(w, ME + W + Vector2i(0, -3), &"imugi")
	w.player().ailments.wet = Status.WET
	var events := w.act({t = &"move", dir = W})
	var noises := _of(events, &"noise").filter(func(e): return e.at == ME + W)
	assert_eq(noises.size(), 1)
	assert_eq([noises[0].word, noises[0].loud], [Status.SPLASH_WORD, Status.SPLASH])
	assert_eq(near.alert, Actor.SEARCH, "two tiles off, it heard her")
	assert_eq(far.alert, Actor.REST, "three tiles off, it did not")


func test_a_dry_step_on_floor_is_silent() -> void:
	var w := _world()
	var events := w.act({t = &"move", dir = W})
	assert_true(_of(events, &"noise").is_empty())


func test_a_wet_step_into_mud_is_still_silent() -> void:
	var w := _world()
	_put(w, ME + W, World.MUD)
	w.player().ailments.wet = Status.WET
	var events := w.act({t = &"move", dir = W})
	assert_true(_of(events, &"noise").is_empty())


func test_a_louder_tread_keeps_its_reach_but_splashes() -> void:
	var a := Actor.new()
	a.ailments.wet = 1
	assert_eq(Status.tread(a, [4, "삐걱"]), [4, Status.SPLASH_WORD])
	a.ailments.wet = 0
	assert_eq(Status.tread(a, [4, "삐걱"]), [4, "삐걱"])


func test_wet_lasts_its_rounds_then_dries() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	Status.soak(w, foe)
	var dried := []
	for i in Status.WET:
		dried.append(_of(w.act(WAIT), &"dry").size())
	assert_eq(foe.ailments.wet, 0)
	assert_eq(dried, [0, 0, 0, 1], "dry at the end of its last round")


func test_fire_that_strikes_a_wet_creature_dries_it_and_lights_nothing() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.soak(w, foe)
	var events := w.act(_cast([FOX, FIRE]))
	assert_eq(foe.ailments.wet, 0)
	assert_eq(_of(events, &"dry").size(), 1)
	assert_false(w.burning.has(foe.pos), "no fire under it")
	assert_eq(foe.hp, 3 - 1, "the wisp still hurts")


func test_a_burning_tile_dries_whoever_stands_in_it() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	Status.soak(w, foe)
	w.burning[foe.pos] = World.BURN_ROUNDS
	w.act(WAIT)
	assert_eq(foe.ailments.wet, 0)
	assert_eq(foe.hp, 3 - World.FIRE_DAMAGE, "and it burns as before")


func test_the_preview_shows_who_gets_wet() -> void:
	var w := _world()
	_post(w, ME + E * 2)
	_forecast_is_the_round(w, _cast([FOX, WATER]))
	w = _world()
	_post(w, ME + E * 2)
	_forecast_is_the_round(w, _cast([WATER]))


func test_the_hover_and_the_log_tell_of_wet() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	var before := w.clone()
	var events := w.act(_cast([FOX, WATER]))
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "젖음: %d초\n  소음: %d" % [Status.WET - 1, Status.SPLASH])
	assert_false(text.contains(Status.SPLASH_WORD), text)
	var log := Messages.of(before, w, events).map(Messages.plain)
	assert_has(log, "장승이 젖었다")
	w.player().ailments.wet = 2
	assert_string_contains(Info.plain(Info.creature(w, w.player())), Status.NAME[&"wet"])


# --- 불붙음 -----------------------------------------------------------------


func test_a_fire_wisp_sets_a_creature_alight_and_it_burns_from_the_next_round() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	foe.hp = 9
	var events := w.act(_cast([FOX, FIRE]))
	assert_eq(_of(events, &"alight").size(), 1)
	assert_false(w.burning.has(foe.pos), "the bare floor under it does not burn")
	var hp := [foe.hp]
	var quenched := []
	for i in Status.ALIGHT:
		quenched.append(_of(w.act(WAIT), &"quench").size())
		hp.append(foe.hp)
	assert_eq(hp, [9 - 1, 9 - 3, 9 - 5, 9 - 5], "the wisp's 1, then 2 a round for two rounds")
	assert_eq(quenched, [0, 1, 0], "out at the end of its third round")
	assert_eq(foe.ailments.alight, 0)


func test_fire_never_sets_miho_alight_only_her_tile_which_she_steps_off() -> void:
	var w := _world()
	var dog := _post(w, ME + E * 2, &"bujigaengi")
	dog.ailments.rooted = 99
	Cast.cast(w, dog, Bestiary.spell(dog.kind, dog.info().casts[0]), W)
	w.sense()
	w.act(WAIT)
	assert_eq(w.player().ailments.alight, 0)
	assert_true(w.burning.has(ME), "her tile burns instead")
	assert_eq(w.player().hp, 3 - 1)
	w.act({t = &"move", dir = W})
	assert_eq(w.player().hp, 3 - 1, "off the fire before it burns her")


func test_a_creature_alight_shines_like_fire() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 6)
	assert_false(w.lit(foe.pos + E * 2))
	Status.ignite(w, foe)
	assert_true(w.lit(foe.pos + E * 2), "within the fire's reach")
	assert_false(w.lit(foe.pos + E * (Light.FIRE_RADIUS + 1)), "and no farther")


func test_a_hunter_at_one_health_and_one_alight_still_come_at_miho() -> void:
	var w := _world()
	_put(w, ME + Vector2i(0, -3), World.LANTERN)
	var weak := _post(w, ME + E * 4, &"dokkaebi")
	weak.hp = 1
	weak.alert = Actor.HUNT
	var burning := _post(w, ME + W * 4, &"dokkaebi")
	burning.hp = 9
	burning.alert = Actor.HUNT
	Status.ignite(w, burning)
	w.sense()
	w.act(WAIT)
	assert_eq(Grid.cheb(weak.pos, ME), 3, "at 1 health it closed in")
	assert_eq(Grid.cheb(burning.pos, ME), 3, "alight it closed in")
	assert_eq(Info.state(weak), Info.STATE[Actor.HUNT])
	assert_eq(Info.state(burning), Info.STATE[Actor.HUNT])


func test_water_puts_a_creature_alight_out_and_wets_it() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.ignite(w, foe)
	var events := w.act(_cast([FOX, WATER]))
	assert_eq(_of(events, &"quench").size(), 1)
	assert_eq([foe.ailments.alight, foe.ailments.wet], [0, Status.WET - 1])
	assert_eq(foe.hp, 3 - 1, "the wisp's 1; put out before it burned")


func test_a_burning_tile_adds_nothing_to_a_creature_alight() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	foe.hp = 9
	foe.ailments.alight = Status.ALIGHT
	w.burning[foe.pos] = World.BURN_ROUNDS
	w.act(WAIT)
	assert_eq(foe.hp, 9 - World.FIRE_DAMAGE)


func test_fire_that_does_not_harm_wood_still_sets_it_alight() -> void:
	var w := _world()
	var wood := _post(w, ME + E * 2, &"cheonha")
	wood.hp = 9
	w.act(_cast([ORB, FIRE]))
	assert_gt(wood.ailments.alight, 0)
	var metal := _post(w, ME + Vector2i(2, 3), &"jiha")
	w.act(_cast([ORB, FIRE], Vector2i(2, 3).sign()))
	assert_eq(metal.ailments.alight, 0, "an orb lights only wood")


func test_the_preview_shows_who_catches_alight() -> void:
	for q in [[FOX, FIRE], [FIRE, FIRE, FIRE], [Cards.WOOD, FIRE], [ORB, FIRE]]:
		var w := _world()
		_post(w, ME + E * 2, &"cheonha")
		_post(w, ME + Vector2i(2, 1))
		_forecast_is_the_round(w, _cast(q))
		_forecast_is_the_round(w, WAIT)


func test_the_hover_and_the_log_tell_of_fire_on_a_creature() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2, &"dokkaebi")
	foe.magic.cooldown = 99
	var before := w.clone()
	var events := w.act(_cast([FOX, FIRE]))
	var log := Messages.of(before, w, events).map(Messages.plain)
	assert_has(log, "도깨비에게 불이 붙었다")
	var text := Info.plain(Info.creature(w, foe))
	var tags := "불붙음: %d초\n  초당 피해: %d\n  빛: %d칸"
	assert_string_contains(text, tags % [Status.ALIGHT - 1, World.FIRE_DAMAGE, Light.FIRE_RADIUS])
	before = w.clone()
	events = w.act(WAIT)
	log = Messages.of(before, w, events).map(Messages.plain)
	assert_has(log, "도깨비가 불에 타 피해를 %d 입었다" % World.FIRE_DAMAGE)


# --- 얼어붙음 ---------------------------------------------------------------


func test_frost_freezes_a_creature_so_it_cannot_move() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	var events := w.act(_cast(FROST))
	assert_eq(
		[foe.ailments.frozen, foe.ailments.rooted], [Compounds.FROST - 1, Compounds.FROST - 1]
	)
	assert_eq(Status.of(foe), &"frozen")
	assert_eq(_of(events, &"freeze")[0].rounds, Compounds.FROST)


func test_frost_on_a_wet_creature_freezes_it_twice_as_long() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.soak(w, foe)
	w.act(_cast(FROST))
	assert_eq(
		[foe.ailments.frozen, foe.ailments.rooted],
		[2 * Compounds.FROST - 1, 2 * Compounds.FROST - 1]
	)
	assert_eq(foe.ailments.wet, 0, "the water is ice now")


func test_the_next_harm_to_a_frozen_creature_is_doubled_and_frees_it() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	foe.hp = 9
	Status.freeze(w, foe, Compounds.FROST)
	var events := w.act(_cast([ORB]))
	var hurts := _of(events, &"hurt")
	assert_eq([hurts[0].n, hurts[0].shatter], [2, true], "the orb's 1, doubled")
	assert_eq([foe.ailments.frozen, foe.ailments.rooted], [0, 0], "the ice broke")
	events = w.act(_cast([ORB]))
	assert_eq(_of(events, &"hurt")[0].n, 1, "once only")


func test_fire_thaws_a_frozen_creature_instead_of_setting_it_alight() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.freeze(w, foe, Compounds.FROST)
	var events := w.act(_cast([FIRE, FIRE, FIRE]))
	assert_eq(_of(events, &"thaw").size(), 1)
	assert_eq([foe.ailments.frozen, foe.ailments.rooted, foe.ailments.alight], [0, 0, 0])


func test_frost_puts_fire_out_and_water_does_not_wet_ice() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.ignite(w, foe)
	w.act(_cast(FROST))
	assert_eq(foe.ailments.alight, 0)
	assert_gt(foe.ailments.frozen, 0)
	Status.soak(w, foe)
	assert_eq(foe.ailments.wet, 0)


func test_the_ice_melts_after_its_rounds() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	Status.freeze(w, foe, Compounds.FROST)
	var thawed := []
	for i in Compounds.FROST:
		thawed.append(_of(w.act(WAIT), &"thaw").size())
	assert_eq(thawed, [0, 1])
	assert_eq([foe.ailments.frozen, foe.ailments.rooted], [0, 0])


func test_frozen_miho_cannot_step_and_takes_double_harm() -> void:
	var w := _world()
	Status.freeze(w, w.player(), Compounds.FROST)
	assert_false(w.can({t = &"move", dir = W}))
	Harm.hurt(w, w.player(), 1)
	assert_eq(w.player().hp, 3 - 2)
	assert_true(w.can({t = &"move", dir = W}), "the ice broke")


func test_the_preview_shows_the_ice_and_its_doubled_harm() -> void:
	var w := _world()
	_post(w, ME + E * 2)
	_forecast_is_the_round(w, _cast(FROST))
	_forecast_is_the_round(w, _cast([ORB]))
	w = _world()
	Status.soak(w, _post(w, ME + E * 2))
	_forecast_is_the_round(w, _cast(FROST))
	_forecast_is_the_round(w, _cast([FIRE, FIRE, FIRE]))


func test_the_hover_and_the_log_tell_of_ice() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	var before := w.clone()
	var events := w.act(_cast(FROST))
	assert_has(Messages.of(before, w, events).map(Messages.plain), "장승이 얼어붙었다")
	var text := Info.plain(Info.creature(w, foe))
	assert_string_contains(text, "얼어붙음: %d초\n  다음 피해: ×2" % (Compounds.FROST - 1))
	before = w.clone()
	events = w.act(_cast([ORB]))
	assert_has(Messages.of(before, w, events).map(Messages.plain), "장승에게 피해를 2 주었다")


## What Miho's log says of the round from `before` to `w`.
func _told(before: World, w: World, events: Array) -> Array:
	return Messages.of(before, w, events).map(Messages.plain)


func test_the_log_tells_when_each_hold_on_a_creature_lets_go() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	foe.ailments.rooted = 1
	foe.ailments.stunned = 1
	foe.ailments.blind = 1
	var before := w.clone()
	var events := w.act(WAIT)
	assert_eq(_told(before, w, events), ["장승이 정신을 차렸다", "장승이 풀려났다", "장승이 다시 볼 수 있게 되었다"])
	assert_eq(_of(w.act(WAIT), &"unroot").size(), 0, "told once")


func test_miho_is_told_by_name_when_she_is_free_again() -> void:
	var w := _world()
	w.player().ailments.stunned = 1
	w.player().ailments.rooted = 2
	var before := w.clone()
	assert_eq(_told(before, w, w.act(WAIT)), ["정신을 차렸다"])
	before = w.clone()
	assert_eq(_told(before, w, w.act(WAIT)), ["풀려났다"])


func test_mud_roots_for_its_rounds_and_the_log_tells_both_ends() -> void:
	var w := _world()
	_put(w, ME + E, World.MUD)
	var before := w.clone()
	assert_eq(_told(before, w, w.act({t = &"move", dir = E})), ["묶였다"])
	var lines := []
	for i in Compounds.MUD:
		before = w.clone()
		lines.append_array(_told(before, w, w.act(WAIT)))
	assert_eq(lines, ["풀려났다"])


func test_ice_that_melts_with_its_hold_tells_one_line() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.freeze(w, foe, Compounds.FROST)
	var lines := []
	for i in Compounds.FROST:
		var before := w.clone()
		lines.append_array(_told(before, w, w.act(WAIT)))
	assert_eq(lines, ["장승이 녹았다"])


func test_a_blow_that_breaks_the_ice_tells_that_it_melted() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.freeze(w, foe, Compounds.FROST)
	var before := w.clone()
	w.events = []
	Harm.hurt(w, foe, 1)
	assert_eq(_of(w.events, &"thaw").size(), 1)
	assert_eq(_told(before, w, w.events).slice(0, 2), ["장승이 피해를 2 입었다", "장승이 녹았다"])


func test_frost_on_a_wet_creature_tells_that_it_dried() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.soak(w, foe)
	var before := w.clone()
	var events := w.act(_cast(FROST))
	assert_eq(_told(before, w, events).slice(0, 2), ["장승이 말랐다", "장승이 얼어붙었다"])


func test_a_new_storey_frees_miho_and_says_so() -> void:
	var w := World.create(1)
	var me := w.player()
	me.ailments.rooted = 2
	me.ailments.stunned = 2
	me.pos = w.stairs
	Walk.arrive(w, me)
	assert_eq(w.depth, 2)
	assert_eq([me.ailments.rooted, me.ailments.stunned], [0, 0])
	assert_eq(_of(w.events, &"unroot").size(), 1)
	assert_eq(_of(w.events, &"unstun").size(), 1)
