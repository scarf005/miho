extends GutTest
## 감투 도깨비 wears an invisibility hat: Miho sees it only from the next tile, or
## while a wisp clings to it. Her map, hover, log, sidebar list, travel, fight
## and the agent's observation all go by the same per-creature sight.

const FOX := Cards.FOX
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)
const FAR := Vector2i(9, 8)


## An open hall walled at the edges, lit by a lantern in the middle, Miho at ME
## with every talisman.
func _hall() -> World:
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
	w.known.resize(w.tiles.size())
	w.dim.resize(w.tiles.size())
	w.depth = 5
	w.tails = 5
	w.cards.assign(Cards.ALL)
	w.tiles[Grid.index(Vector2i(7, 6))] = World.LANTERN
	w.sense()
	return w


func _hatted(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"gamtu", at)
	a.magic.cooldown = 99
	a.ailments.rooted = 99
	a.home = at
	a.post = at
	w.sense()
	return a


func _cast(cards: Array) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = E}]}


func test_the_hat_dokkaebi_is_a_dokkaebi_that_comes_from_tier_five() -> void:
	assert_true(Bestiary.info(&"gamtu").get("hat", false))
	assert_true(Bestiary.allied(&"gamtu", &"dokkaebi"))
	assert_true(Bestiary.bands(&"gamtu"))
	var first := 0
	for tier in range(1, 10):
		if FloorGen.PLAN[tier].has(&"gamtu"):
			first = tier if first == 0 else first
	assert_eq(first, 5)


func test_a_hat_wearer_in_a_lit_seen_tile_is_not_seen_unless_next_to_miho() -> void:
	var w := _hall()
	var a := _hatted(w, FAR)
	assert_eq(w.seen[Grid.index(FAR)], 1, "she sees the tile")
	assert_false(Hat.shown(w, a))
	a.pos = ME + E
	w.sense()
	assert_true(Hat.shown(w, a))
	var plain := FloorGen.spawn(w, &"dokkaebi", FAR)
	w.sense()
	assert_true(Hat.shown(w, plain), "one without a hat is seen by sight alone")


func test_a_wisp_on_it_shows_it_and_the_hat_hides_it_again_when_the_wisp_fades() -> void:
	var w := _hall()
	var a := _hatted(w, FAR)
	for i in 3:
		w.act(_cast([FOX]) if i == 0 else WAIT)
	assert_eq(w.shots.size(), 1)
	assert_eq(w.shots[0].host, a.id, "the wisp clings to it")
	assert_true(Hat.shown(w, a))
	assert_string_contains(Info.plain(Info.at(w, FAR)), "감투 도깨비")
	for i in Spell.WISP_LIFE + 1:
		w.act(WAIT)
	assert_true(w.shots.is_empty())
	assert_false(Hat.shown(w, a))


func test_the_hover_the_clone_the_agent_and_travel_do_not_know_of_it() -> void:
	var w := _hall()
	var a := _hatted(w, FAR)
	assert_false(Info.plain(Info.at(w, FAR)).contains("감투"), "the tile reads as a tile")
	assert_false(w.known_clone().actors.any(func(x): return x.id == a.id))
	assert_false(Observation.text(w).contains("감투 도깨비"))
	assert_false(Travel.in_sight(w).has(a.id))
	assert_true(Fight.targets(w).is_empty())
	a.pos = ME + E
	w.sense()
	assert_string_contains(Info.plain(Info.at(w, ME + E)), "감투 도깨비")
	assert_true(w.known_clone().actors.any(func(x): return x.id == a.id))
	assert_string_contains(Observation.text(w), "감투 도깨비")
	assert_true(Travel.in_sight(w).has(a.id))
	assert_eq(Fight.targets(w), [a] as Array[Actor])


func test_the_log_tells_nothing_of_a_creature_she_does_not_see() -> void:
	var w := _hall()
	var a := _hatted(w, FAR)
	var before := w.clone()
	w.events = []
	Harm.hurt(w, a, 1)
	assert_true(Messages.of(before, w, w.events).is_empty())
	assert_true(Perceived.of(before, w, w.events).facts.is_empty())


func test_the_log_tells_what_happens_to_one_beside_her() -> void:
	var w := _hall()
	var a := _hatted(w, ME + E)
	var before := w.clone()
	w.events = []
	Harm.hurt(w, a, 1)
	var lines := Messages.of(before, w, w.events).map(func(l): return Messages.plain(l))
	assert_string_contains(lines[0], "감투 도깨비가 피해를 1 입었다")


func test_a_homing_wisp_of_miho_goes_for_the_visible_only() -> void:
	var w := _hall()
	var a := _hatted(w, FAR)
	var homing := Spell.make([FOX, Cards.ORB])
	var unseen := Homing.targets(w, w.player(), homing)
	assert_false(unseen.has(a.id))
	a.pos = ME + E
	w.sense()
	assert_true(Homing.targets(w, w.player(), homing).has(a.id))


func test_heaven_does_not_see_a_hat_wearer_from_afar_either() -> void:
	var w := _hall()
	var a := _hatted(w, FAR)
	var seer := FloorGen.spawn(w, &"imugi", Vector2i(12, 8))
	assert_false(Hat.sees(w, seer, a))
	seer.pos = FAR + E
	assert_true(Hat.sees(w, seer, a))


func test_the_doc_tells_the_hat() -> void:
	var text := Info.plain(Info.creature_facts(Codex.foe(&"gamtu"), []))
	assert_string_contains(text, "은신.")
	assert_false(Info.plain(Info.creature_facts(Codex.foe(&"dokkaebi"), [])).contains("감투"))


func test_the_round_a_wisp_clings_to_it_the_log_names_it() -> void:
	var w := _hall()
	_hatted(w, FAR)
	var told: Array = []
	for i in 3:
		var before := w.clone()
		var events := w.act(_cast([FOX]) if i == 0 else WAIT)
		told.append_array(Messages.of(before, w, events).map(func(l): return Messages.plain(l)))
	assert_true(told.any(func(l): return l.contains("감투 도깨비에게 붙었다")), str(told))
