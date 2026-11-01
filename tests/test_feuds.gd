extends GutTest
## Groups and infighting: a creature of heaven struck by another group's spell
## or blow fights the one that struck it for Mind.GRUDGE_ROUNDS, in place of
## Miho; one of its own group only makes it wary.

const W := Vector2i(-1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)


## An unlit open hall, Miho at ME.
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
	w.depth = 2
	w.tails = 4
	return w


func _creature(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


## `a` is struck by `by` as a blow of another group strikes it: hurt, then provoked.
func _provoke(w: World, a: Actor, by: Actor) -> void:
	Mind.hurt(a)
	Mind.provoke(w, a, by)


## `caster` hurls an orb west; rounds pass until `victim` is hurt (at most 4).
func _orb_at(w: World, caster: Actor, victim: Actor) -> Array:
	var events: Array = []
	var before := victim.hp
	w.cast(caster, Spell.make([Cards.ORB]), W)
	for i in 4:
		events.append_array(w.act(WAIT))
		if victim.hp < before:
			break
	return events


func test_every_creature_of_heaven_has_a_group() -> void:
	for kind in Bestiary.KINDS:
		if kind != &"miho":
			assert_true(Bestiary.GROUPS.has(Bestiary.info(kind).get("group", &"")), kind)
	assert_true(Bestiary.allied(&"dokkaebi", &"dokkaebi"))
	assert_true(Bestiary.allied(&"cheonha", &"jangseung"))
	assert_false(Bestiary.allied(&"dokkaebi", &"imugi"))


func test_a_creature_struck_by_another_group_fights_the_caster() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", Vector2i(12, 8))
	var victim := _creature(w, &"dokkaebi", Vector2i(9, 8))
	victim.hp = 5
	var events := _orb_at(w, shooter, victim)
	assert_lt(victim.hp, 5)
	assert_eq(victim.rival, shooter.id)
	assert_true(victim.fighting())
	assert_true(events.any(func(e): return e.t == &"feud" and e.rival == shooter.id))


func test_one_of_its_own_group_hurts_it_but_starts_no_fight() -> void:
	for kinds in [[&"imugi", &"imugi"], [&"imugi", &"cheonnyeon"]]:
		var w := _world()
		var shooter := _creature(w, kinds[0], Vector2i(12, 8))
		var victim := _creature(w, kinds[1], Vector2i(9, 8))
		victim.hp = 5
		var events := _orb_at(w, shooter, victim)
		assert_lt(victim.hp, 5, "friendly fire still hurts")
		assert_eq(victim.rival, 0)
		assert_false(events.any(func(e): return e.t == &"feud"))


func test_a_fighter_strikes_its_rival_before_miho_beside_it() -> void:
	var w := _world()
	var fighter := _creature(w, &"dokkaebi", ME + Vector2i(1, 0))
	var rival := _creature(w, &"jangseung", ME + Vector2i(2, 0))
	_provoke(w, fighter, rival)
	var events := w.act(WAIT)
	assert_eq(w.player().hp, 3)
	assert_eq(rival.hp, 2)
	assert_true(events.any(func(e): return e.t == &"melee" and e.target == rival.id))
	assert_eq(fighter.alert, Actor.HUNT, "it saw Miho all the same")


func test_a_fighter_s_homing_spell_goes_for_its_rival() -> void:
	var w := _world()
	var fighter := _creature(w, &"dokkaebi", ME + Vector2i(1, 0))
	var rival := _creature(w, &"jangseung", ME + Vector2i(2, 0))
	var spell := Bestiary.spell(&"dokkaebi", [Cards.FOX, Cards.FIRE])
	assert_eq(Homing.targets(w, fighter, spell), [w.player().id] as Array[int])
	_provoke(w, fighter, rival)
	assert_eq(Homing.targets(w, fighter, spell), [rival.id] as Array[int])


func test_a_fighter_walks_to_where_it_last_saw_its_rival() -> void:
	var w := _world()
	var fighter := _creature(w, &"dokkaebi", Vector2i(20, 8))
	var rival := _creature(w, &"jangseung", Vector2i(26, 8))
	_provoke(w, fighter, rival)
	w.act(WAIT)
	assert_eq(fighter.pos, Vector2i(21, 8))
	assert_true(fighter.fighting())


func test_the_fight_ends_when_the_rival_falls() -> void:
	var w := _world()
	var fighter := _creature(w, &"dokkaebi", Vector2i(20, 8))
	var rival := _creature(w, &"jangseung", Vector2i(21, 8))
	_provoke(w, fighter, rival)
	w.hurt(rival, 9)
	assert_eq(fighter.rival, 0)


func test_the_fight_ends_after_the_grudge_runs_out() -> void:
	var w := _world()
	var fighter := _creature(w, &"jangseung", Vector2i(20, 8))
	var rival := _creature(w, &"imugi", Vector2i(21, 8))
	_provoke(w, fighter, rival)
	assert_true(fighter.fighting())
	var events: Array = []
	for i in Mind.GRUDGE_ROUNDS:
		events.append_array(w.act(WAIT))
	assert_false(fighter.fighting())
	events.append_array(w.act(WAIT))
	assert_eq(fighter.rival, 0)
	assert_true(events.any(func(e): return e.t == &"truce" and e.id == fighter.id))


func test_a_rival_striking_again_renews_the_grudge() -> void:
	var w := _world()
	var fighter := _creature(w, &"dokkaebi", Vector2i(20, 8))
	var rival := _creature(w, &"jangseung", Vector2i(26, 8))
	_provoke(w, fighter, rival)
	fighter.grudge = 2
	_provoke(w, fighter, rival)
	assert_eq(fighter.grudge, Mind.GRUDGE_ROUNDS)


func test_harm_from_miho_ends_the_fight() -> void:
	var w := _world()
	var fighter := _creature(w, &"dokkaebi", ME + Vector2i(1, 0))
	var rival := _creature(w, &"jangseung", Vector2i(26, 8))
	_provoke(w, fighter, rival)
	fighter.hp = 9
	w.act({t = &"move", dir = Vector2i(1, 0)})
	assert_eq(fighter.rival, 0)
	assert_eq(fighter.alert, Actor.HUNT)


func test_a_fighter_that_loses_its_rival_searches_where_it_saw_it_last() -> void:
	var w := _world()
	var fighter := _creature(w, &"jangseung", Vector2i(20, 8))
	var rival := _creature(w, &"imugi", Vector2i(26, 8))
	_provoke(w, fighter, rival)
	var events := w.act(WAIT)
	assert_eq(fighter.rival, 0)
	assert_eq(fighter.alert, Actor.SEARCH)
	assert_eq(fighter.target, Vector2i(26, 8))
	assert_true(events.any(func(e): return e.t == &"truce"))


func test_the_forecast_plays_the_fight_as_the_round_does() -> void:
	var w := _world()
	var fighter := _creature(w, &"dokkaebi", ME + Vector2i(1, 0))
	var rival := _creature(w, &"jangseung", ME + Vector2i(2, 0))
	_provoke(w, fighter, rival)
	w.sense()
	var f := Forecast.of(w, WAIT)
	w.act(WAIT)
	assert_eq(f.after.actor(rival.id).hp, rival.hp)
	assert_eq(f.after.player().hp, w.player().hp)


func test_the_hover_tells_whom_it_fights() -> void:
	var w := _world()
	var fighter := _creature(w, &"dokkaebi", ME + Vector2i(1, 0))
	var rival := _creature(w, &"jangseung", ME + Vector2i(2, 0))
	_provoke(w, fighter, rival)
	w.sense()
	var text := Info.plain(Info.creature(w, fighter))
	assert_string_contains(text, "싸우는 중: 장승\n  남은 시간: %d초" % Mind.GRUDGE_ROUNDS)
	assert_false(text.contains("무리"), text)
	rival.pos = Vector2i(26, 8)
	w.sense()
	assert_string_contains(Info.plain(Info.creature(w, fighter)), "싸우는 중: 무언가")


func test_the_doc_tells_no_group() -> void:
	var text := Info.plain(Info.creature_facts(Codex.foe(&"bulgae"), []))
	assert_false(text.contains("무리"), text)


func test_the_log_tells_the_fight() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", ME + Vector2i(5, 0))
	var victim := _creature(w, &"dokkaebi", ME + Vector2i(2, 0))
	victim.hp = 5
	w.set_tile(ME + Vector2i(5, 1), World.LANTERN)
	w.sense()
	w.cast(shooter, Spell.make([Cards.ORB]), W)
	var lines := []
	for i in 3:
		var before := w.clone()
		lines.append_array(Messages.of(before, w, w.act(WAIT)).map(Messages.plain))
	assert_has(lines, "도깨비가 이무기에게 덤벼들었다")


func test_the_log_names_the_creature_a_blow_strikes() -> void:
	var w := _world()
	var fighter := _creature(w, &"dokkaebi", ME + Vector2i(1, 0))
	var rival := _creature(w, &"jangseung", ME + Vector2i(2, 0))
	_provoke(w, fighter, rival)
	w.sense()
	var before := w.clone()
	var lines := Messages.of(before, w, w.act(WAIT)).map(Messages.plain)
	assert_has(lines, "도깨비의 방망이에 장승이 맞아 피해를 1 입었다")
	var me := _world()
	var foe := _creature(me, &"dokkaebi", ME + Vector2i(1, 0))
	foe.alert = Actor.HUNT
	me.sense()
	before = me.clone()
	assert_has(Messages.of(before, me, me.act(WAIT)).map(Messages.plain), "도깨비의 방망이에 맞아 피해를 1 입었다")
