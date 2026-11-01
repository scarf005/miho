extends GutTest
## 여우 홀림: a wisp of 여 alone that hovers with nothing to chase yelps "캥"
## every second round, an alarm heaven searches; a cunning creature searches
## where it was thrown from instead (Lure).

const FOX := Cards.FOX
const E := Vector2i(1, 0)
const ME := Vector2i(4, 8)
const HOVER := Vector2i(12, 8)
const WAIT := {t = &"wait"}


## An open hall walled at the edges with no light, Miho at ME with every
## talisman and five tails.
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
	me.hp = 3
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	w.depth = 13
	w.tails = 5
	w.cards.assign(Cards.ALL)
	w.sense()
	return w


func _cast(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func _yelps(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"yelp")


## A wisp of `cards` Miho threw from ME, hovering at HOVER with all its life left.
func _hovering(w: World, cards := [FOX]) -> Shot:
	var s := Shot.new()
	s.id = w.new_id()
	s.caster = w.player().id
	s.spell = Spell.make(cards)
	s.pos = HOVER
	s.origin = ME
	s.life = Spell.WISP_LIFE
	s.turn = s.spell.turn()
	w.shots.append(s)
	return s


## A creature asleep in bamboo at `at`, which no wisp makes out from afar.
func _sleeper(w: World, kind: StringName, at: Vector2i) -> Actor:
	w.set_tile(at, World.BAMBOO)
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


func test_a_lone_wisp_with_nothing_to_chase_yelps_every_second_round_it_hovers() -> void:
	var w := _world()
	var rounds := []
	var events := w.act(_cast([FOX]))
	for i in Spell.WISP_LIFE + 2:
		if not _yelps(events).is_empty():
			rounds.append(i)
			var noise: Array = events.filter(func(e): return e.t == &"noise")
			assert_eq(noise.map(func(e): return [e.word, e.loud]), [[Lure.WORD, Lure.LOUD]])
		events = w.act(WAIT)
	assert_eq(rounds, [1, 3, 5, 7], "from the round it comes to hover, four times")


func test_each_fox_past_the_first_is_heard_two_tiles_farther_and_one_tile_yelps_once() -> void:
	var w := _world()
	for d in Grid.DIRS:
		if d != E:
			w.set_tile(ME + d, World.WALL)
	w.act(_cast([FOX, FOX]))
	var yelps := _yelps(w.act(WAIT))
	assert_eq(yelps.size(), 1, "two wisps on one tile")
	assert_eq(yelps[0].loud, Lure.LOUD + Lure.PER_FOX)


func test_a_wisp_with_an_element_or_on_its_casters_tile_keeps_quiet() -> void:
	for cards in [[FOX, Cards.WATER], [FOX, Cards.FIRE], [FOX, Cards.WOOD]]:
		var w := _world()
		w.act(_cast(cards))
		var heard := []
		for i in Spell.WISP_LIFE:
			heard.append_array(_yelps(w.act(WAIT)))
		assert_eq(heard, [], str(cards))
	var w := _world()
	_hovering(w)
	w.player().pos = HOVER
	for i in Spell.WISP_LIFE:
		assert_eq(_yelps(w.act(WAIT)), [], "it hovers on her")


func test_heaven_searches_the_yelp_but_a_cunning_creature_where_it_was_thrown_from() -> void:
	var w := _world()
	var sharp := _sleeper(w, &"imugi", HOVER + Vector2i(0, 3))
	var cunning := _sleeper(w, &"cheonnyeon", HOVER + Vector2i(2, 2))
	var far := _sleeper(w, &"imugi", HOVER + Vector2i(9, 0))
	_hovering(w)
	w.act(WAIT)
	assert_eq([sharp.alert, sharp.target], [Actor.SEARCH, HOVER])
	assert_eq([cunning.alert, cunning.target], [Actor.SEARCH, ME])
	assert_eq(far.alert, Actor.REST, "out of earshot")


func test_the_forecast_hears_the_yelp_the_round_does() -> void:
	var w := _world()
	w.act(_cast([FOX, FOX, FOX]))
	var f := Forecast.of(w, WAIT)
	var told := _yelps(f.events).map(func(e): return [e.at, e.loud])
	assert_eq(told.size(), 3, "each wisp on its own tile")
	assert_eq(told, _yelps(w.act(WAIT)).map(func(e): return [e.at, e.loud]))


func test_the_log_tells_a_yelp_in_sight_and_a_yelp_heard_from_the_dark() -> void:
	var w := _world()
	w.act(_cast([FOX]))
	var before := w.clone()
	var lines := Messages.of(before, w, w.act(WAIT)).map(Messages.plain)
	assert_has(lines, "여우불이 캥 울었다")
	var blind := _world()
	blind.player().blind = 5
	blind.sense()
	var s := _hovering(blind)
	s.pos = ME + Vector2i(3, 0)
	before = blind.clone()
	lines = Messages.of(before, blind, blind.act(WAIT)).map(Messages.plain)
	assert_has(lines, "멀리서 캥 소리를 들었다 · 소리: 4칸")


func test_the_spell_info_tells_the_yelp_and_its_reach() -> void:
	var one := Info.plain(SpellInfo.spell(Spell.make([FOX])))
	var yelp := "떠 있을 때 소리: 2초마다 %d칸"
	assert_string_contains(one, yelp % Lure.LOUD)
	assert_false(one.contains(Lure.WORD), "no word in the hover")
	assert_string_contains(one, "교활한 적")
	assert_string_contains(Info.plain(SpellInfo.spell(Spell.make([FOX, FOX]))), yelp % 6)
	assert_false(Info.plain(SpellInfo.spell(Spell.make([FOX, Cards.WATER]))).contains("2초마다"))
	var w := _world()
	var s := _hovering(w)
	assert_string_contains(Info.plain(SpellInfo.shot(w, s)), yelp % Lure.LOUD)
