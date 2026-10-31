extends GutTest
## Heaven's projectiles, splashes and fire hurt other heaven creatures by the
## same rules as Miho's spells: weakness, immunity, wood that burns.

const W := Vector2i(-1, 0)
const WAIT := {t = &"wait"}
const ME := Vector2i(4, 8)
const SHOOTER := Vector2i(12, 8)
const VICTIM := Vector2i(9, 8)


## An open hall, Miho at ME holding every element.
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
	w.depth = 4
	w.tails = 4
	w.cards.assign(Cards.ALL)
	return w


func _creature(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


## `caster` hurls the spell west and the round plays until it is spent.
func _hurl(w: World, caster: Actor, cards: Array) -> Array:
	var events: Array = []
	w.cast(caster, Spell.make(cards), W)
	for i in 6:
		events.append_array(w.act(WAIT))
	return events


## Hp the victim loses to a spell of `cards` hurled by heaven, and by Miho's
## own cast from the same tile.
func _loss(kind: StringName, cards: Array) -> Array:
	var out := []
	for caster_kind in [&"imugi", &"miho"]:
		var w := _world()
		var victim := _creature(w, kind, VICTIM)
		var caster := w.player() if caster_kind == &"miho" else _creature(w, caster_kind, SHOOTER)
		if caster_kind == &"miho":
			w.player().pos = SHOOTER
		var before := victim.hp
		_hurl(w, caster, cards)
		out.append(before - victim.hp)
	return out


func test_a_heaven_orb_hurts_another_heaven_creature_like_miho_s_does() -> void:
	var loss := _loss(&"dokkaebi", [Cards.ORB])
	assert_eq(loss[0], 1, "3 tiles flown")
	assert_eq(loss[0], loss[1])


func test_the_orb_hits_harder_after_a_run_up_both_ways() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", Vector2i(16, 8))
	var victim := _creature(w, &"haetae", VICTIM)
	victim.hp = 9
	_hurl(w, shooter, [Cards.ORB])
	assert_eq(victim.hp, 7, "7 tiles flown")


func test_weakness_doubles_the_harm_both_ways() -> void:
	var loss := _loss(&"cheonha", [Cards.ORB, Cards.METAL])
	assert_eq(loss[0], 2 * (1 + Elements.CANNON))
	assert_eq(loss[0], loss[1])


func test_a_creature_that_eats_fire_takes_none_from_heaven_either() -> void:
	var loss := _loss(&"haetae", [Cards.ORB, Cards.FIRE])
	assert_eq(loss, [0, 0])


func test_a_creature_that_takes_only_fire_takes_none_without_it() -> void:
	var loss := _loss(&"bulgasari", [Cards.ORB])
	assert_eq(loss, [0, 0])
	assert_eq(_loss(&"bulgasari", [Cards.ORB, Cards.FIRE])[0], 1)


func test_heaven_fire_sets_a_wood_creature_alight() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", SHOOTER)
	var victim := _creature(w, &"cheonha", VICTIM)
	var events := _hurl(w, shooter, [Cards.ORB, Cards.FIRE])
	assert_true(events.any(func(e): return e.t == &"alight" and e.id == victim.id))


func test_heaven_fire_leaves_other_creatures_tiles_alone() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", SHOOTER)
	_creature(w, &"jiha", VICTIM)
	_hurl(w, shooter, [Cards.ORB, Cards.FIRE])
	assert_false(w.burning.has(VICTIM))


func test_a_heaven_fire_orb_splashes_the_neighbours_of_its_target() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", SHOOTER)
	var front := _creature(w, &"dokkaebi", VICTIM)
	var side := _creature(w, &"dokkaebi", VICTIM + Vector2i(0, 1))
	var weak := _creature(w, &"jiha", VICTIM + Vector2i(0, -1))
	_hurl(w, shooter, [Cards.ORB, Cards.FIRE])
	assert_eq(front.hp, 1)
	assert_false(side.alive(), "splash 2 fells a 2-heart creature")
	assert_false(weak.alive(), "fire beats metal: splash 2 doubled")


func test_a_creature_hurt_by_another_becomes_wary_and_looks_around_only() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", SHOOTER)
	var victim := _creature(w, &"imugi", VICTIM)
	victim.hp = 5
	w.cast(shooter, Spell.make([Cards.ORB]), W)
	for i in 3:
		w.act(WAIT)
	assert_lt(victim.hp, 5)
	assert_gt(victim.wary, 0)
	assert_eq(victim.alert, Actor.SEARCH)
	assert_ne(victim.target, SHOOTER, "a sharp creature does not trace an ally's shot")
	assert_eq(victim.target, VICTIM)


func test_a_cunning_creature_hit_by_an_ally_does_not_hunt() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", SHOOTER)
	var victim := _creature(w, &"cheonnyeon", VICTIM)
	_hurl(w, shooter, [Cards.ORB])
	assert_lt(victim.hp, 8)
	assert_ne(victim.alert, Actor.HUNT)


func test_the_forecast_shows_the_harm_heaven_does_to_itself() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", SHOOTER)
	var victim := _creature(w, &"dokkaebi", VICTIM)
	w.cast(shooter, Spell.make([Cards.ORB]), W)
	w.act(WAIT)
	var p := w.preview(WAIT)
	w.act(WAIT)
	assert_eq(p.actor(victim.id).hp, victim.hp)


func test_the_log_names_both_creatures() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", Vector2i(9, 8))
	var victim := _creature(w, &"dokkaebi", Vector2i(6, 8))
	victim.hp = 5
	w.sense()
	w.cast(shooter, Spell.make([Cards.ORB]), W)
	var lines := []
	for i in 4:
		var before := w.clone()
		lines.append_array(Messages.of(before, w, w.act(WAIT)).map(Messages.plain))
	assert_has(lines, "이무기의 구슬에 도깨비가 피해를 1 입었다")


func test_the_log_marks_the_weakness_of_an_ally_hit() -> void:
	var w := _world()
	var shooter := _creature(w, &"imugi", Vector2i(9, 8))
	_creature(w, &"cheonha", Vector2i(6, 8))
	w.sense()
	w.cast(shooter, Spell.make([Cards.ORB, Cards.METAL]), W)
	var lines := []
	for i in 4:
		var before := w.clone()
		lines.append_array(Messages.of(before, w, w.act(WAIT)).map(Messages.plain))
	var n := 2 * (1 + Elements.CANNON)
	assert_has(lines, "약점! 이무기의 쇠 구슬에 천하대장군이 피해를 %d 입었다" % n)


func test_a_heaven_projectile_tells_it_hits_other_creatures() -> void:
	var s := Shot.new()
	s.faction = Actor.HEAVEN
	s.spell = Spell.make([Cards.ORB])
	assert_string_contains(Info.plain(SpellInfo.shot(_world(), s)), "다른 적도 맞힌다")
	s.faction = Actor.FOX
	assert_false(Info.plain(SpellInfo.shot(_world(), s)).contains("다른 적도 맞힌다"))
