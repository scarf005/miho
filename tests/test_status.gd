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
	w.depth = 13
	w.tails = 5
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _put(w: World, p: Vector2i, t: int) -> void:
	w.tiles[Grid.index(p)] = t
	w._changed()


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that neither moves nor casts: a 장승 (no element, 3 health).
func _post(w: World, at: Vector2i, kind := &"jangseung") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
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
		assert_eq([b.wet, b.alight, b.hp], [a.wet, a.alight, a.hp], "%s %s" % [action, a.kind])
	assert_eq(f.after.burning, w.burning, str(action))


# --- 젖음 -------------------------------------------------------------------


func test_a_water_wisp_wets_whoever_stands_round_where_it_ends() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	var events := w.act(_cast([FOX, WATER]))
	assert_eq(foe.wet, Status.WET - 1, "wet, a round of it gone")
	assert_eq(w.player().wet, 0, "Miho stands outside the 3x3")
	assert_eq(_of(events, &"wet").size(), 1)
	assert_eq(Status.of(foe), &"wet")


func test_a_water_orb_bursting_next_to_miho_wets_her_too() -> void:
	var w := _world()
	_put(w, ME + E * 2, World.WALL)
	w.act(_cast([ORB, WATER]))
	assert_eq(w.player().wet, Status.WET - 1)


func test_a_jet_wets_the_creature_it_pushes() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	w.act(_cast([WATER]))
	assert_eq(foe.pos, ME + E * 3, "pushed")
	assert_eq(foe.wet, Status.WET - 1)


func test_steam_wets_whoever_stands_in_it() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	for p in Spray.square(w, foe.pos):
		Gas.put(w, p, Gas.STEAM, Gas.MAX)
	w.act(WAIT)
	assert_eq(foe.wet, Status.WET - 1)
	assert_eq(w.player().wet, 0, "no steam on her")


func test_a_wet_step_splashes_two_tiles_and_alarms_heaven() -> void:
	var w := _world()
	var near := _post(w, ME + W + Vector2i(0, -2), &"imugi")
	var far := _post(w, ME + W + Vector2i(0, -3), &"imugi")
	w.player().wet = Status.WET
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
	w.player().wet = Status.WET
	var events := w.act({t = &"move", dir = W})
	assert_true(_of(events, &"noise").is_empty())


func test_a_louder_tread_keeps_its_reach_but_splashes() -> void:
	var a := Actor.new()
	a.wet = 1
	assert_eq(Status.tread(a, [4, "삐걱"]), [4, Status.SPLASH_WORD])
	a.wet = 0
	assert_eq(Status.tread(a, [4, "삐걱"]), [4, "삐걱"])


func test_wet_lasts_its_rounds_then_dries() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	Status.soak(w, foe)
	var dried := []
	for i in Status.WET:
		dried.append(_of(w.act(WAIT), &"dry").size())
	assert_eq(foe.wet, 0)
	assert_eq(dried, [0, 0, 0, 1], "dry at the end of its last round")


func test_fire_that_strikes_a_wet_creature_dries_it_and_lights_nothing() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.soak(w, foe)
	var events := w.act(_cast([FOX, FIRE]))
	assert_eq(foe.wet, 0)
	assert_eq(_of(events, &"dry").size(), 1)
	assert_false(w.burning.has(foe.pos), "no fire under it")
	assert_eq(foe.hp, 3 - 1, "the wisp still hurts")


func test_a_burning_tile_dries_whoever_stands_in_it() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	Status.soak(w, foe)
	w.burning[foe.pos] = World.BURN_ROUNDS
	w.act(WAIT)
	assert_eq(foe.wet, 0)
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
	assert_string_contains(text, "젖음 %d초. 철벅 %d칸." % [Status.WET - 1, Status.SPLASH])
	var log := Messages.of(before, w, events).map(Messages.plain)
	assert_has(log, "장승이 젖었다")
	w.player().wet = 2
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
	assert_eq(foe.alight, 0)


func test_fire_never_sets_miho_alight_only_her_tile_which_she_steps_off() -> void:
	var w := _world()
	var dog := _post(w, ME + E * 2, &"dokkaebi")
	dog.rooted = 99
	w.cast(dog, Bestiary.spell(dog.kind, dog.info().casts[0]), W)
	w.sense()
	w.act(WAIT)
	assert_eq(w.player().alight, 0)
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


func test_a_hunter_alight_flees_if_it_would_flee_at_one_health() -> void:
	var dog := Actor.new()
	dog.kind = &"dokkaebi"
	dog.hp = 2
	dog.alert = Actor.HUNT
	assert_false(dog.fleeing())
	dog.alight = 1
	assert_true(dog.fleeing())
	assert_eq(Info.state(dog), "도망치는 중")
	dog.alert = Actor.SEARCH
	assert_false(dog.fleeing(), "only a hunter runs")
	var post := Actor.new()
	post.kind = &"jangseung"
	post.alert = Actor.HUNT
	post.alight = 1
	assert_false(post.fleeing(), "one that cannot walk stands")
	assert_string_contains(Info.plain(Info.creature_facts(dog, [])), "불붙음: 도망.")
	assert_false(Info.plain(Info.creature_facts(post, [])).contains("불붙음"))


func test_a_fleeing_creature_alight_steps_away_from_miho() -> void:
	var w := _world()
	_put(w, ME + Vector2i(0, -3), World.LANTERN)
	var dog := _post(w, ME + E * 2, &"dokkaebi")
	dog.alert = Actor.HUNT
	Status.ignite(w, dog)
	w.sense()
	w.act(WAIT)
	assert_gt(Grid.cheb(dog.pos, ME), 2, "it ran")


func test_water_puts_a_creature_alight_out_and_wets_it() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2)
	Status.ignite(w, foe)
	var events := w.act(_cast([FOX, WATER]))
	assert_eq(_of(events, &"quench").size(), 1)
	assert_eq([foe.alight, foe.wet], [0, Status.WET - 1])
	assert_eq(foe.hp, 3 - 1, "the wisp's 1; put out before it burned")


func test_a_burning_tile_adds_nothing_to_a_creature_alight() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 4)
	foe.hp = 9
	foe.alight = Status.ALIGHT
	w.burning[foe.pos] = World.BURN_ROUNDS
	w.act(WAIT)
	assert_eq(foe.hp, 9 - World.FIRE_DAMAGE)


func test_fire_that_does_not_harm_wood_still_sets_it_alight() -> void:
	var w := _world()
	var wood := _post(w, ME + E * 2, &"cheonha")
	wood.hp = 9
	w.act(_cast([ORB, FIRE]))
	assert_gt(wood.alight, 0)
	var metal := _post(w, ME + Vector2i(2, 3), &"jiha")
	w.act(_cast([ORB, FIRE], Vector2i(2, 3).sign()))
	assert_eq(metal.alight, 0, "an orb lights only wood")


func test_the_preview_shows_who_catches_alight() -> void:
	for q in [[FOX, FIRE], [FIRE, FIRE], [Cards.WOOD, FIRE], [ORB, FIRE]]:
		var w := _world()
		_post(w, ME + E * 2, &"cheonha")
		_post(w, ME + Vector2i(2, 1))
		_forecast_is_the_round(w, _cast(q))
		_forecast_is_the_round(w, WAIT)


func test_the_hover_and_the_log_tell_of_fire_on_a_creature() -> void:
	var w := _world()
	var foe := _post(w, ME + E * 2, &"dokkaebi")
	foe.cooldown = 99
	var before := w.clone()
	var events := w.act(_cast([FOX, FIRE]))
	var log := Messages.of(before, w, events).map(Messages.plain)
	assert_has(log, "도깨비에게 불이 붙었다")
	var text := Info.plain(Info.creature(w, foe))
	var tags := "불붙음 %d초. 매 초 피해 %d. 빛 %d칸."
	assert_string_contains(text, tags % [Status.ALIGHT - 1, World.FIRE_DAMAGE, Light.FIRE_RADIUS])
	before = w.clone()
	events = w.act(WAIT)
	log = Messages.of(before, w, events).map(Messages.plain)
	assert_has(log, "도깨비가 불에 타 피해를 %d 입었다" % World.FIRE_DAMAGE)
