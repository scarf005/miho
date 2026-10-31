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
		assert_eq([b.wet, b.hp], [a.wet, a.hp], "%s %s" % [action, a.kind])


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
	assert_string_contains(text, "%s (%d초)" % [Status.NAME[&"wet"], Status.WET - 1])
	assert_string_contains(text, SpellInfo.WET_DOES)
	var log := Messages.of(before, w, events).map(Messages.plain)
	assert_has(log, "장승이 물에 젖었다")
	w.player().wet = 2
	assert_string_contains(Info.plain(Info.creature(w, w.player())), Status.NAME[&"wet"])
