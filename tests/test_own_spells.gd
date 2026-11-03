extends GutTest
## 쇠발톱 and 은신, cast on Miho (Guise): her claws harm more, and she wears the
## hat of 감투 도깨비 (Hat).

const E := Vector2i(1, 0)
const ME := Vector2i(4, 8)
const WAIT := {t = &"wait"}
const TALON := [Cards.FIRE, Cards.WOOD, Cards.METAL]
const CLOAK := [Cards.FOX, Cards.WOOD, Cards.EARTH]


## An open hall walled at the edges, every tile known and seen, Miho at ME with
## every talisman, nine tails and plenty of health.
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	w.rooms = [Rect2i(1, 1, Grid.W - 2, Grid.H - 2)]
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 99
	me.max_hp = 99
	me.pos = ME
	w.actors.append(me)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 5
	w.tails = 9
	w.cards.assign(Cards.ALL)
	return w


func _cast(cards: Array, dir := Vector2i.ZERO) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


## A creature that stands and fights, with health to spare.
func _foe(w: World, at: Vector2i, alert := Actor.SEARCH) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.magic.cooldown = 99
	a.brain.alert = alert
	a.brain.target = at
	a.hp = 99
	a.max_hp = 99
	return a


## A lantern lights Miho, so a creature in line sees her from afar.
func _lit(w: World) -> void:
	w.set_tile(ME + Vector2i(0, 3), World.LANTERN)


func _claws(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"claw").map(func(e): return e.n)


func _of(events: Array, kind: StringName) -> Array:
	return events.filter(func(e): return e.t == kind)


func test_the_claws_harm_more_until_the_talon_is_dropped() -> void:
	var w := _world()
	var foe := _foe(w, ME + E)
	w.act(_cast(TALON))
	for i in 3:
		assert_eq(_claws(w.act({t = &"move", dir = E})), [World.CLAW + Guise.TALON_HARM])
	w.act({t = &"dispel", kind = Guise.TALON})
	assert_eq(_claws(w.act({t = &"move", dir = E})), [World.CLAW])
	assert_eq(foe.max_hp - foe.hp, 3 * (World.CLAW + Guise.TALON_HARM) + World.CLAW)


func test_a_creature_that_absorbs_iron_takes_less_from_the_talon() -> void:
	var w := _world()
	var foe := FloorGen.spawn(w, &"bulgasari", ME + E)
	foe.hp = 99
	foe.brain.alert = Actor.HUNT
	w.act(_cast(TALON))
	var harm := World.CLAW + Guise.TALON_ABSORBED
	assert_eq(_claws(w.act({t = &"move", dir = E})), [harm])
	assert_eq(99 - foe.hp, harm)


func test_a_sneak_claw_gains_the_same_harm() -> void:
	var w := _world()
	w.act(_cast(TALON))
	var sleeper := FloorGen.spawn(w, &"imugi", ME + E)
	sleeper.hp = 99
	sleeper.max_hp = 99
	assert_true(sleeper.asleep())
	var sneak := World.CLAW * World.SNEAK + Guise.TALON_HARM
	assert_eq(_claws(w.act({t = &"move", dir = E})), [sneak])
	assert_eq(sleeper.max_hp - sleeper.hp, sneak)


func test_the_refusal_lists_every_spell_that_goes_on_her_and_each_can_be_cast() -> void:
	var w := _world()
	var refusal := Guise.only()
	assert_false(w.can(_cast([Cards.FIRE])))
	for kind in Guise.RECIPE:
		var spell := Spell.make(Guise.RECIPE[kind])
		assert_string_contains(refusal, Guise.NAME[kind])
		assert_eq(Guise.kind(spell), kind)
		assert_true(Guise.why(w.player(), spell) in ["", Guise.NO_PREY], "castable on herself")
	assert_true(w.can(_cast(TALON)))
	assert_true(w.can(_cast(CLOAK)))


func test_the_talon_goes_on_her_whatever_the_direction() -> void:
	var w := _world()
	assert_true(w.can(_cast(TALON, E)))
	w.act(_cast(TALON, E))
	assert_true(w.player().buffs.talon)
	assert_eq(w.shots.size(), 0, "nothing flies")


func test_the_cloak_goes_on_her_only_with_no_direction() -> void:
	var w := _world()
	w.act(_cast(CLOAK, E))
	assert_false(w.player().buffs.cloak, "hurled, it is a wisp")
	w.act(_cast(CLOAK))
	assert_true(w.player().buffs.cloak)


func test_they_hurt_nobody() -> void:
	for cards in [TALON, CLOAK]:
		var w := _world()
		var foe := FloorGen.spawn(w, &"imugi", ME + Vector2i(3, 0))
		var health := foe.hp
		w.act(_cast(cards))
		assert_eq(foe.hp, health)


func test_the_four_that_change_how_she_is_seen_are_heard_three_tiles_and_wake_what_hears() -> void:
	for kind: StringName in [Guise.GUISE, Guise.TALON, Guise.CLOAK, Guise.FLAME]:
		var w := _world()
		w.player().buffs.prey = &"dokkaebi"
		var near := _foe(w, ME + Vector2i(3, 0), Actor.REST)
		var far := _foe(w, ME + Vector2i(4, 0), Actor.REST)
		var events := w.act(_cast(Guise.RECIPE[kind]))
		var noises := _of(events, &"noise")
		assert_eq(noises[0].loud, 3, kind)
		assert_eq(near.brain.alert, Actor.SEARCH, "%s: 3 tiles away hears" % kind)
		assert_eq(near.brain.target, ME, kind)
		assert_eq(far.brain.alert, Actor.REST, "%s: 4 tiles away does not" % kind)


func test_the_shadow_and_the_raising_stay_silent() -> void:
	for kind: StringName in [Guise.SHADOW, Guise.RAISE]:
		var w := _world()
		var events := w.act(_cast(Guise.RECIPE[kind]))
		assert_eq(_of(events, &"noise").size(), 0, kind)


func _claw_noise(w: World, sleeper: bool) -> Array:
	var foe := FloorGen.spawn(w, &"imugi", ME + E)
	foe.hp = 99
	foe.max_hp = 99
	if not sleeper:
		foe.brain.alert = Actor.HUNT
	var blows := _of(w.act({t = &"move", dir = E}), &"noise").filter(func(e): return e.word == "퍽")
	return blows.slice(0, 1).map(func(e): return e.loud)


func test_a_claw_is_heard_three_tiles_with_the_talon_even_on_a_sneak_attack() -> void:
	var w := _world()
	assert_eq(_claw_noise(w, true), [1], "a sneak claw is quiet without it")
	w = _world()
	assert_eq(_claw_noise(w, false), [3])
	w = _world()
	w.act(_cast(TALON))
	assert_eq(_claw_noise(w, true), [3])
	assert_eq(_claw_noise(w, true), [3])


func test_with_the_cloak_a_creature_that_is_not_hunting_does_not_know_her() -> void:
	var w := _world()
	_lit(w)
	var searcher := _foe(w, ME + Vector2i(4, 0))
	w.act(_cast(CLOAK))
	assert_true(w.sees(searcher, ME), "it sees her tile")
	assert_true(Hat.hidden(w, w.player(), searcher.pos))
	assert_false(Guise.knows(w, searcher))
	w.act(WAIT)
	assert_ne(searcher.brain.alert, Actor.HUNT, "it goes on searching")


func test_without_the_cloak_the_same_creature_hunts_her() -> void:
	var w := _world()
	_lit(w)
	var searcher := _foe(w, ME + Vector2i(4, 0))
	w.act(WAIT)
	assert_eq(searcher.brain.alert, Actor.HUNT)


func test_the_cloak_fools_a_hunter_too_but_not_one_next_to_her() -> void:
	var w := _world()
	_lit(w)
	var far := _foe(w, ME + Vector2i(4, 0), Actor.HUNT)
	var near := _foe(w, ME + Vector2i(0, -1), Actor.HUNT)
	w.act(_cast(CLOAK))
	assert_false(far.brain.sees_me, "a hunter beyond the next tile loses sight of her")
	assert_true(near.brain.sees_me, "beside her it still sees her")


func test_a_wisp_clinging_to_her_shows_her() -> void:
	var w := _world()
	_lit(w)
	var searcher := _foe(w, ME + Vector2i(4, 0))
	w.act(_cast(CLOAK))
	assert_false(Guise.knows(w, searcher))
	var wisp := Shot.new()
	wisp.id = w.new_id()
	wisp.spell = Spell.make([Cards.FOX, Cards.FIRE])
	wisp.caster = searcher.id
	w.shots.append(wisp)
	Elements.stick(w, wisp, w.player())
	assert_true(Guise.knows(w, searcher))


func test_her_own_shadow_does_not_show_her_under_the_cloak() -> void:
	var w := _world()
	_lit(w)
	var searcher := _foe(w, ME + Vector2i(4, 0))
	w.act(_cast(CLOAK))
	w.act(_cast([Cards.FOX, Cards.WATER, Cards.WOOD]))
	assert_eq(Guise.worn(w, w.player()), [Guise.SHADOW, Guise.CLOAK])
	assert_true(Hat.hidden(w, w.player(), searcher.pos))


func test_a_forecast_of_each_equals_the_round() -> void:
	for cards in [TALON, CLOAK]:
		var w := _world()
		_foe(w, ME + E)
		var forecast := Forecast.of(w, _cast(cards))
		var played := w.act(_cast(cards))
		assert_eq(forecast.events, played)
		assert_eq(forecast.after.player().buffs.talon, w.player().buffs.talon)
		assert_eq(forecast.after.player().buffs.cloak, w.player().buffs.cloak)


func test_no_creature_casts_them() -> void:
	for kind: StringName in Bestiary.KINDS:
		var spec := Bestiary.info(kind)
		var casts: Array = spec.get("casts", []).duplicate()
		for rank: int in spec.get("ranks", {}):
			casts.append_array(spec.ranks[rank])
		for cards: Array in casts:
			assert_false(
				Guise.ANYWHERE.has(Guise.kind(Spell.make(cards))), "%s: %s" % [kind, cards]
			)


func test_a_card_more_on_a_spell_for_herself_cannot_be_cast() -> void:
	var w := _world()
	w.cards.assign(Cards.ALL)
	w.tails = 9
	var talon: Array = Guise.RECIPE[Guise.TALON]
	assert_true(w.can({t = &"cast", spells = [{cards = talon, dir = Vector2i.ZERO}]}))
	var more := {t = &"cast", spells = [{cards = talon + [Cards.WOOD], dir = Vector2i(1, 0)}]}
	assert_false(w.can(more))


func test_the_hovers_tell_the_noise_of_the_cast_and_of_a_claw_under_the_talon() -> void:
	for kind: StringName in [Guise.GUISE, Guise.TALON, Guise.CLOAK, Guise.FLAME]:
		var text := Info.plain(SpellInfo.ward(Spell.make(Guise.RECIPE[kind])))
		assert_string_contains(text, "소음: 3")
		assert_eq(text.contains("근접 소음: 3"), kind == Guise.TALON, kind)
		assert_false(text.contains("소음: 없음"), kind)
	var w := _world()
	w.act(_cast(TALON))
	assert_string_contains(Info.plain(Info.creature(w, w.player())), "근접 소음: 3")


func test_a_buff_hover_tells_the_noise_of_its_cast_under_its_name_and_no_bare_noise_of_it() -> void:
	for kind: StringName in [Guise.GUISE, Guise.TALON, Guise.CLOAK, Guise.FLAME]:
		var text := Info.plain(SpellInfo.spell(Spell.make(Guise.RECIPE[kind])))
		var lines := Array(text.split("\n")).map(func(l: String): return l.strip_edges())
		assert_has(lines, "%s 소음: %d" % [Lang.t(Guise.NAME[kind]), Guise.CAST_LOUD])
		assert_does_not_have(lines, "소음: %d" % Guise.CAST_LOUD, kind)
