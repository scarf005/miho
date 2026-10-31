extends GutTest
## 멀리뛰기: the 도 talisman leads a spell that leaps Miho along a line over
## sky, ponds and creatures onto the farthest tile in reach she can stand on;
## the rest of the spell is cast where she lands (Leap).

const LEAP := Cards.LEAP
const E := Vector2i(1, 0)
const ME := Vector2i(4, 8)


## An open hall walled at the edges, every tile known and seen, Miho at ME.
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
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 13
	w.tails = 5
	w.cards.append(Cards.EARTH)
	return w


## Sky columns from x for `wide` tiles, floor to floor: a gap between pavilions.
func _gap(w: World, x: int, wide: int) -> void:
	for gx in range(x, x + wide):
		for y in range(1, Grid.H - 1):
			w.set_tile(Vector2i(gx, y), World.SKY)


func _leap(cards: Array, dir := E) -> Dictionary:
	return {t = &"cast", spells = [{cards = cards, dir = dir}]}


func _foe(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.cooldown = 99
	return a


func test_miho_starts_with_the_leap_talisman_third() -> void:
	assert_eq(World.new().cards, [Cards.FOX, Cards.ORB, LEAP] as Array[StringName])


func test_each_leap_talisman_reaches_one_tile_farther() -> void:
	var one := Spell.make([LEAP])
	assert_eq(one.shape, Spell.LEAP)
	assert_eq(one.leap(), 3)
	assert_eq(Spell.make([LEAP, LEAP]).leap(), 4)
	assert_eq(Spell.make([LEAP, LEAP]).cost(), 2)
	assert_eq(Spell.make([LEAP, LEAP]).title(), "멀리뛰기 4칸")


func test_a_leap_talisman_leads_a_spell_or_ends_one_projectile() -> void:
	assert_not_null(Spell.make([LEAP, LEAP, Cards.EARTH]))
	assert_null(Spell.make([LEAP, Cards.EARTH, LEAP]), "not in the middle")
	assert_null(Spell.make([Cards.EARTH, LEAP]), "not behind a spray")
	assert_null(Spell.make([Cards.ORB, LEAP, LEAP]), "one behind a projectile")
	assert_null(Spell.make([Cards.ORB, LEAP, Cards.EARTH]), "last behind a projectile")
	var swap := Spell.make([Cards.ORB, LEAP])
	assert_eq(swap.shape, Spell.ORB)
	assert_true(swap.swaps())
	assert_false(Spell.make([LEAP, Cards.ORB]).swaps(), "a leap that hurls an orb")
	assert_eq(swap.title(), "구슬 바꿔치기")
	assert_eq(swap.damage(0), Spell.make([Cards.ORB]).damage(0), "the orb is the same orb")
	assert_eq(Spell.make([Cards.FOX, Cards.FOX, LEAP]).shots(), 1, "one wisp to follow")
	assert_eq(Spell.make([Cards.FOX, LEAP]).damage(0), 0, "a lone 여 still hurts nothing")


func test_one_leap_crosses_two_tiles_of_sky() -> void:
	var w := _world()
	_gap(w, 5, 2)
	w.act(_leap([LEAP]))
	assert_eq(w.player().pos, Vector2i(7, 8))
	assert_eq(w.depth, 13, "no fall")
	assert_eq(w.tails, 4, "one tail")


func test_three_tiles_of_sky_take_two_leap_talismans() -> void:
	var w := _world()
	_gap(w, 5, 3)
	assert_false(w.can(_leap([LEAP])), "nowhere to land")
	assert_true(w.can(_leap([LEAP, LEAP])))
	w.act(_leap([LEAP, LEAP]))
	assert_eq(w.player().pos, Vector2i(8, 8))


func test_a_leap_lands_on_the_farthest_tile_in_reach() -> void:
	var w := _world()
	w.act(_leap([LEAP]))
	assert_eq(w.player().pos, ME + E * 3)


func test_a_wall_or_a_closed_door_stops_the_leap_short_of_it() -> void:
	for t in [World.WALL, World.DOOR, World.LANTERN]:
		var w := _world()
		w.set_tile(Vector2i(6, 8), t)
		w.act(_leap([LEAP]))
		assert_eq(w.player().pos, Vector2i(5, 8), "stops before tile %d" % t)
	var w := _world()
	w.set_tile(ME + E, World.WALL)
	assert_false(w.can(_leap([LEAP])), "no room at all")


func test_a_leap_clears_creatures_and_ponds_but_never_lands_on_them() -> void:
	var w := _world()
	var foe := _foe(w, Vector2i(5, 8))
	w.set_tile(Vector2i(7, 8), World.POND)
	w.act(_leap([LEAP]))
	assert_eq(w.player().pos, Vector2i(6, 8), "over the creature, short of the pond")
	assert_eq(foe.pos, Vector2i(5, 8))
	var v := _world()
	_foe(v, Vector2i(7, 8))
	v.act(_leap([LEAP]))
	assert_eq(v.player().pos, Vector2i(6, 8), "not onto the creature")


func test_a_rooted_or_stunned_miho_cannot_leap() -> void:
	var w := _world()
	w.player().rooted = 2
	assert_false(w.can(_leap([LEAP])))
	w.player().rooted = 0
	w.player().stunned = 1
	assert_false(w.can(_leap([LEAP])))


func test_the_landing_is_heard_but_not_on_mud() -> void:
	var w := _world()
	var words := (
		w
		. act(_leap([LEAP]))
		. filter(func(e): return e.t == &"noise")
		. map(func(e): return [e.word, e.at, e.loud])
	)
	assert_has(words, [Leap.WORD, Vector2i(7, 8), Leap.LOUD])
	var v := _world()
	v.set_tile(Vector2i(7, 8), World.MUD)
	var muddy := v.act(_leap([LEAP])).filter(func(e): return e.t == &"noise")
	assert_true(muddy.is_empty(), "mud swallows it")
	assert_eq(v.player().pos, Vector2i(7, 8))


func test_a_leap_lays_no_scent_on_the_tiles_it_clears() -> void:
	var w := _world()
	w.act(_leap([LEAP]))
	assert_gt(w.scent[Grid.index(Vector2i(7, 8))], 0, "where she lands")
	for x in [5, 6]:
		assert_eq(w.scent[Grid.index(Vector2i(x, 8))], 0, "none at x %d" % x)


func test_a_fire_plate_under_the_landing_flames_on_along_the_leap() -> void:
	var w := _world()
	w.traps[Vector2i(7, 8)] = World.TRAP_FIRE
	var lit := (
		w.act(_leap([LEAP])).filter(func(e): return e.t == &"ignite").map(func(e): return e.at)
	)
	assert_eq(lit.slice(0, 3), [Vector2i(8, 8), Vector2i(9, 8), Vector2i(10, 8)])


func test_the_rest_of_the_spell_is_cast_where_miho_lands() -> void:
	var w := _world()
	var far := _foe(w, Vector2i(8, 8))
	_foe(w, Vector2i(5, 9))
	var events := w.act(_leap([LEAP, Cards.EARTH]))
	assert_eq(w.player().pos, Vector2i(7, 8))
	var stunned := events.filter(func(e): return e.t == &"stun").map(func(e): return e.id)
	assert_eq(stunned, [far.id], "next to the landing, not to where she took off")
	assert_eq(w.tails, 3, "both talismans spent")


func test_landing_on_the_stairs_climbs_and_casts_nothing_more() -> void:
	var w := _world()
	w.stairs = Vector2i(7, 8)
	var events := w.act(_leap([LEAP, Cards.EARTH]))
	assert_eq(w.depth, 14)
	assert_false(events.any(func(e): return e.t == &"spray"), "no quake on the new storey")


func test_the_forecast_lands_where_the_leap_does() -> void:
	var w := _world()
	_gap(w, 5, 2)
	_foe(w, Vector2i(9, 8))
	var f := Forecast.of(w, _leap([LEAP, LEAP]))
	assert_eq(f.leaps, [[ME, Vector2i(8, 8)]])
	w.act(_leap([LEAP, LEAP]))
	assert_eq(w.player().pos, Vector2i(8, 8))


func test_the_log_tells_the_leap() -> void:
	var w := _world()
	var before := w.clone()
	var lines := Messages.of(before, w, w.act(_leap([LEAP]))).map(Messages.plain)
	assert_has(lines, "멀리 뛰었다")


func test_the_info_tells_the_reach_what_it_clears_and_its_sound() -> void:
	var text := " ".join(SpellInfo.spell(Spell.make([LEAP, Cards.EARTH])).map(Messages.plain))
	for part in ["멀리뛰기 3칸", "곧게 3칸", "하늘", "탁 %d칸" % Leap.LOUD, "내린 자리에서", "기절"]:
		assert_string_contains(text, part)


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(3)
	m.state = &"play"
	m.world = _world()
	_gap(m.world, 5, 2)
	m.settings.spells = {}
	m.term.show_world(m.world)
	m._forecast()
	return m


func _press(m: Node, key: String) -> void:
	var e := Keys.event(key)
	e.pressed = true
	m._key(e)


func test_the_aim_preview_shows_the_leap_and_miho_where_she_lands() -> void:
	var m := _main()
	_press(m, "3")
	assert_eq(m.picked, [LEAP] as Array[StringName])
	assert_true(m.reach.has(Vector2i(7, 8)), "the landing east is tinted")
	assert_false(m.reach.has(Vector2i(5, 8)), "not the sky it clears")
	m.hover = Vector2i(9, 8)
	m._refresh()
	assert_eq(m.term.marks.get(Vector2i(7, 8)), [Bestiary.info(&"miho").glyph, Palette.SIDE[0]])
	assert_true(m.term.tints.has(Vector2i(6, 8)), "the line it leaps along")
	_press(m, "Right")
	assert_eq(m.world.player().pos, Vector2i(7, 8), "the direction key leaps")
	while m.busy:
		await get_tree().process_frame


func test_a_leap_with_nowhere_to_land_says_so_and_keeps_the_turn() -> void:
	var m := _main()
	m.world.set_tile(ME + Vector2i.UP, World.WALL)
	_press(m, "3")
	var round_no: int = m.world.round_no
	_press(m, "Up")
	assert_eq(m.world.round_no, round_no)
	assert_eq(m.messages.lines.back().text, "내려설 곳이 없다")


func test_a_leap_talisman_behind_a_spray_is_refused() -> void:
	var m := _main()
	_press(m, "4")
	_press(m, "3")
	assert_eq(m.picked, [Cards.EARTH] as Array[StringName])
	assert_eq(m.messages.lines.back().text, "도약은 맨 앞이나 여, 구 뒤 끝에 한 장만 넣는다")
	_press(m, "Escape")
	_press(m, "2")
	_press(m, "3")
	assert_eq(m.picked, [Cards.ORB, LEAP] as Array[StringName], "behind an orb it swaps")


# --- 바꿔치기 -------------------------------------------------------------------


## Casts and waits until no projectile is left, up to `rounds` rounds.
func _until_still(w: World, cards: Array, rounds := 6) -> Array[Dictionary]:
	var events := w.act(_leap(cards))
	for i in rounds:
		if w.shots.all(func(s): return s.gone or s.dir == Vector2i.ZERO):
			break
		events.append_array(w.act({t = &"wait"}))
	return events


func test_an_orb_with_leap_trades_places_with_the_creature_it_strikes() -> void:
	var w := _world()
	var foe := _foe(w, Vector2i(7, 8))
	foe.stunned = 9
	var events := _until_still(w, [Cards.ORB, LEAP])
	assert_eq(w.player().pos, Vector2i(7, 8))
	assert_eq(foe.pos, ME)
	var heard := events.filter(func(e): return e.t == &"noise" and e.word == Leap.SWAP_WORD)
	assert_eq(heard.map(func(e): return e.at), [ME, Vector2i(7, 8)], "heard at both tiles")
	assert_eq(heard.map(func(e): return e.loud), [Leap.SWAP_LOUD, Leap.SWAP_LOUD])


func test_an_orb_with_leap_that_kills_takes_miho_where_the_creature_stood() -> void:
	var w := _world()
	var foe := _foe(w, Vector2i(8, 8))
	foe.stunned = 9
	_until_still(w, [Cards.ORB, LEAP])
	assert_false(foe.alive(), "a run-up hits for 2")
	assert_eq(w.player().pos, Vector2i(8, 8))


func test_an_orb_with_leap_that_bursts_on_a_wall_takes_miho_where_it_stopped() -> void:
	var w := _world()
	w.set_tile(Vector2i(10, 8), World.WALL)
	_until_still(w, [Cards.ORB, LEAP])
	assert_eq(w.player().pos, Vector2i(9, 8))


func test_a_hovering_wisp_takes_miho_once_and_flies_on_as_a_plain_wisp() -> void:
	var w := _world()
	_until_still(w, [Cards.FOX, LEAP])
	var to := ME + E * Spell.RANGE
	assert_eq(w.player().pos, to)
	assert_eq(w.shots.size(), 1)
	assert_eq(w.shots[0].pos, to, "it hovers on her, lighting her")
	assert_false(w.shots[0].spell.swaps(), "the 도 is spent")


func test_a_projectile_that_stops_over_the_sky_takes_miho_nowhere() -> void:
	var w := _world()
	_gap(w, 8, 6)
	_until_still(w, [Cards.FOX, LEAP])
	assert_eq(w.player().pos, ME)


func test_the_log_tells_the_swap() -> void:
	var w := _world()
	var foe := _foe(w, Vector2i(6, 8))
	foe.stunned = 9
	var before := w.clone()
	var lines := Messages.of(before, w, _until_still(w, [Cards.ORB, LEAP])).map(Messages.plain)
	assert_has(lines, "도깨비와 자리를 바꿨다")


func test_the_info_tells_the_swap_and_its_sound() -> void:
	var text := " ".join(SpellInfo.spell(Spell.make([Cards.ORB, LEAP])).map(Messages.plain))
	for part in ["구슬 바꿔치기", "자리를 바꾼다", "%s %d칸" % [Leap.SWAP_WORD, Leap.SWAP_LOUD]]:
		assert_string_contains(text, part)
	var leap := " ".join(SpellInfo.shape(Spell.LEAP).map(Messages.plain))
	assert_string_contains(leap, "바꿔치기", "the 도감 tells both uses")
