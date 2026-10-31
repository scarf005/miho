extends GutTest
## Plates in the floor: found on a lit tile or right next to Miho, hidden from
## every view until then, and told in the hover, the log and the popups.

const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}
const PLATE := Vector2i(7, 8)
const KINDS := [World.TRAP_ALARM, World.TRAP_COLLAPSE, World.TRAP_FIRE, World.TRAP_VINE]


## An open hall walled at the edges with no light, Miho at (4, 8) on storey 4.
func _world(depth := 4) -> World:
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
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	w.depth = depth
	w.tails = 1
	w.sense()
	return w


func _foe(w: World, at: Vector2i, kind := &"dokkaebi") -> Actor:
	var a := FloorGen.spawn(w, kind, at)
	a.cooldown = 99
	return a


## A plate of `kind` at `at`, still hidden.
func _plate(w: World, at: Vector2i, kind: int) -> void:
	w.traps[at] = kind


func _lantern(w: World, at: Vector2i) -> void:
	w.tiles[Grid.index(at)] = World.LANTERN
	w._changed()
	w.sense()


func _types(events: Array) -> Array:
	return events.map(func(e): return e.t)


func _lines(before: World, after: World, events: Array) -> Array:
	return Messages.of(before, after, events).map(Messages.plain)


## The map row y of the observation, one character per tile.
func _row(w: World, y: int) -> String:
	var rows := Array(Observation.text(w).split("\n"))
	return rows.filter(func(r: String): return r.begins_with("%2d " % y))[0].substr(3)


# --- finding -----------------------------------------------------------------


func test_a_plate_in_the_dark_is_found_only_right_next_to_miho() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_ALARM)
	for x in [4, 5]:
		w.player().pos = Vector2i(x, 8)
		w.sense()
		assert_eq(w.tile(PLATE), World.FLOOR, "from %d tiles away it is floor" % (PLATE.x - x))
	w.player().pos = Vector2i(6, 8)
	w.sense()
	assert_eq(w.tile(PLATE), World.TRAP_ALARM)
	assert_eq(Traps.REACH, 1)


func test_miho_finds_a_plate_diagonally_next_to_her() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_FIRE)
	w.player().pos = PLATE + Vector2i(-1, -1)
	w.sense()
	assert_eq(w.tile(PLATE), World.TRAP_FIRE)


func test_a_plate_on_a_lit_tile_in_sight_is_found_from_afar() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	_lantern(w, PLATE + Vector2i(0, 1))
	assert_true(w.lit(PLATE))
	assert_gt(Grid.cheb(PLATE, w.player().pos), Traps.REACH)
	w.sense()
	assert_eq(w.tile(PLATE), World.TRAP_COLLAPSE)
	assert_has(_types(w.events), &"find")


func test_a_lit_plate_out_of_sight_stays_hidden() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	for y in range(1, Grid.H - 1):
		w.tiles[Grid.index(Vector2i(6, y))] = World.WALL
	_lantern(w, PLATE + Vector2i(0, 1))
	assert_true(w.lit(PLATE))
	assert_eq(w.seen[Grid.index(PLATE)], 0)
	assert_eq(w.tile(PLATE), World.FLOOR)


func test_a_found_plate_stays_on_the_map_when_miho_leaves() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_VINE)
	w.player().pos = Vector2i(6, 8)
	w.sense()
	w.player().pos = Vector2i(2, 20)
	w.sense()
	assert_eq(w.seen[Grid.index(PLATE)], 0)
	assert_eq(w.tile(PLATE), World.TRAP_VINE)
	assert_eq(w.known_clone().traps, {PLATE: World.TRAP_VINE})


func test_finding_a_plate_is_one_event_with_its_kind() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_FIRE)
	var found := w.act({t = &"move", dir = E}).filter(func(e): return e.t == &"find")
	assert_eq(found, [] as Array[Dictionary], "two tiles away")
	found = w.act({t = &"move", dir = E}).filter(func(e): return e.t == &"find")
	assert_eq(found, [{t = &"find", at = PLATE, kind = World.TRAP_FIRE}] as Array[Dictionary])
	found = w.act(WAIT).filter(func(e): return e.t == &"find")
	assert_eq(found, [] as Array[Dictionary], "found once")


# --- hidden from every view --------------------------------------------------


func test_a_hidden_plate_is_not_on_the_map_the_observation_or_the_hover() -> void:
	var w := _world()
	for kind in KINDS:
		_plate(w, PLATE, kind)
		w.player().pos = Vector2i(5, 8)
		w.tiles[Grid.index(PLATE)] = World.FLOOR
		w.sense()
		var glyph: String = Palette.TILES[kind][0]
		assert_false(_row(w, 8).contains(glyph), "%s in the observation" % glyph)
		assert_eq(_row(w, 8)[PLATE.x], "·", "drawn as floor")
		var lines := Info.plain(Info.at(w.known_clone(), PLATE))
		assert_false(lines.contains("발판"), lines)
		assert_false(lines.contains(Tiles.of(kind, "name")), lines)
		assert_eq(Info.plain(Info.at(w.known_clone(), PLATE)).split("\n")[0], "바닥")


func test_a_found_plate_is_on_the_map_the_observation_and_the_hover() -> void:
	var w := _world()
	for kind in KINDS:
		w.tiles[Grid.index(PLATE)] = World.FLOOR
		_plate(w, PLATE, kind)
		w.player().pos = Vector2i(6, 8)
		w.sense()
		assert_eq(_row(w, 8)[PLATE.x], Palette.TILES[kind][0])
		var lines := Info.plain(Info.at(w.known_clone(), PLATE))
		assert_eq(lines.split("\n")[0], Tiles.of(kind, "name"))


func test_no_view_of_the_world_gives_a_hidden_plate_away() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	w.sense()
	assert_eq(w.known_clone().traps, {})
	assert_eq(w.known_clone().tile(PLATE), World.FLOOR)
	assert_eq(w.traps.size(), 1, "the world itself still has it")
	assert_eq(w.clone().traps, w.traps, "a copy keeps it")


func test_a_forecast_of_stepping_onto_a_hidden_plate_shows_nothing() -> void:
	for kind in KINDS:
		var w := _world()
		w.player().pos = PLATE - E
		_plate(w, PLATE, kind)
		var f := Forecast.of(w, {t = &"move", dir = E})
		assert_false(_types(f.events).has(&"trap"), "kind %d" % kind)
		assert_false(f.drops_me())
		assert_eq(f.after.depth, w.depth)
		assert_eq(f.hurt_me(), 0)


func test_a_forecast_of_stepping_onto_a_found_collapsing_floor_shows_the_fall() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	w.sense()
	assert_eq(w.tile(PLATE), World.TRAP_COLLAPSE)
	var f := Forecast.of(w, {t = &"move", dir = E})
	assert_true(f.drops_me())
	assert_eq(f.after.depth, 3)
	assert_eq(w.depth, 4, "the preview does not move the world")


func test_a_walk_goes_round_a_found_plate_and_over_a_hidden_one() -> void:
	var w := _world()
	w.player().pos = Vector2i(5, 8)
	_plate(w, Vector2i(6, 8), World.TRAP_FIRE)
	_plate(w, Vector2i(6, 9), World.TRAP_FIRE)
	w.sense()
	w.known.fill(1)
	w.tiles[Grid.index(Vector2i(6, 9))] = World.FLOOR
	assert_eq(w.tile(Vector2i(6, 8)), World.TRAP_FIRE)
	assert_false(Travel.walkable(w, Vector2i(6, 8)), "a found plate")
	assert_true(Travel.walkable(w, Vector2i(6, 9)), "a hidden plate is only floor")
	var found := Travel.search(w)
	var route := Travel.route(found, Vector2i(8, 8))
	assert_false(route.is_empty())
	assert_does_not_have(route, Vector2i(6, 8))


func test_a_walk_stops_when_a_plate_is_found_or_goes_off() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_ALARM)
	w.player().pos = Vector2i(5, 8)
	var before := w.clone()
	w.act({t = &"move", dir = E})
	assert_true(Travel.interrupted(before, w, w.events, {}))
	var again := _world()
	_plate(again, PLATE, World.TRAP_ALARM)
	again.player().pos = PLATE - E
	again.sense()
	var b2 := again.clone()
	again.act({t = &"move", dir = E})
	assert_true(Travel.interrupted(b2, again, again.events, {}), "it went off")
	assert_true(Travel.interrupted(b2, again, [{t = &"trap", at = PLATE, id = 1}], {}))
	var quiet := _world()
	assert_false(Travel.interrupted(quiet, quiet, [], {}))


# --- what the player is told -------------------------------------------------


func test_hovering_a_plate_tells_its_rule_from_the_constants() -> void:
	var w := _world()
	var text := {}
	for kind in KINDS:
		text[kind] = Info.plain(_hover(w, kind))
	assert_string_contains(text[World.TRAP_ALARM], "층 전체에 징 소리가 퍼진다")
	assert_string_contains(text[World.TRAP_COLLAPSE], "한 층 아래로 간다")
	assert_string_contains(text[World.TRAP_FIRE], "앞 %d칸에 불을" % Traps.FLAME_REACH)
	assert_string_contains(text[World.TRAP_FIRE], "피해 %d" % World.FIRE_DAMAGE)
	assert_string_contains(text[World.TRAP_VINE], "주위 3×3의 모두를 %d초" % Traps.ROOT_ROUNDS)
	for kind in KINDS:
		assert_string_contains(text[kind], "밝은 칸이나 %d칸 안에서만 보인다" % Traps.REACH)
		assert_string_contains(text[kind], "적은 알고 피해 다닌다")


func _hover(w: World, kind: int) -> Array:
	w.tiles[Grid.index(PLATE)] = kind
	w.known[Grid.index(PLATE)] = 1
	return Info.terrain(w, PLATE)


func test_plates_share_a_glyph_no_other_tile_uses_and_differ_by_colour() -> void:
	var others := [Palette.BURNING[0], Palette.HOT[0]]
	others.append_array(Palette.GAS.values().map(func(v): return v[0]))
	for t in Palette.TILES:
		if not KINDS.has(t):
			others.append(Palette.TILES[t][0])
	var colours := {}
	for kind in KINDS:
		var glyph: String = Palette.TILES[kind][0]
		assert_string_contains(Observation.LEGEND, glyph)
		assert_does_not_have(others, glyph)
		assert_eq(glyph, Palette.TILES[KINDS[0]][0], "one glyph for every plate")
		colours[Palette.TILES[kind][1]] = true
	assert_eq(colours.size(), KINDS.size(), "told apart by colour")


func test_miho_stepping_on_the_alarm_plate_is_told_in_the_log() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_ALARM)
	var before := w.clone()
	w.act({t = &"move", dir = E})
	assert_has(_lines(before, w, w.events), "경보 발판을 밟았다. 징 소리가 층 전체에 울렸다")
	assert_false(_lines(before, w, w.events).any(func(l): return l.contains("찾았다")))


func test_a_creature_stepping_on_a_plate_in_sight_is_told_in_the_log() -> void:
	var w := _world()
	_lantern(w, PLATE + Vector2i(0, 2))
	_plate(w, PLATE, World.TRAP_VINE)
	var foe := _foe(w, PLATE - E)
	w.sense()
	var before := w.clone()
	w.push(foe, E, 1)
	w.sense()
	var lines := _lines(before, w, w.events)
	assert_has(lines, "도깨비가 덩굴 발판을 밟았다")
	assert_has(lines, "도깨비가 덩굴에 묶였다")
	assert_eq(w.tile(PLATE), World.TRAP_VINE, "seen going off, it is found")


func test_a_creature_falling_through_a_plate_is_told_in_the_log() -> void:
	var w := _world()
	_lantern(w, PLATE + Vector2i(0, 2))
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	var foe := _foe(w, PLATE - E)
	w.sense()
	var before := w.clone()
	w.push(foe, E, 1)
	var lines := _lines(before, w, w.events)
	assert_eq(lines.slice(-2), ["도깨비가 꺼지는 마루를 밟았다", "도깨비가 하늘로 떨어졌다"])


func test_miho_falling_through_a_plate_is_told_in_the_log() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_COLLAPSE)
	w.sense()
	var before := w.clone()
	w.act({t = &"move", dir = E})
	var lines := _lines(before, w, w.events)
	assert_eq(lines[0], "꺼지는 마루를 밟았다")
	assert_eq(lines[1], "하늘로 떨어져 3층으로 내려왔다")


func test_the_fire_plate_is_told_with_the_fire_it_lights() -> void:
	var w := _world()
	w.player().pos = PLATE - E
	_plate(w, PLATE, World.TRAP_FIRE)
	var before := w.clone()
	w.act({t = &"move", dir = E})
	var lines := _lines(before, w, w.events)
	assert_eq(lines[0], "불 발판을 밟았다")
	assert_eq(lines.filter(func(l): return l.ends_with("불이 붙었다")).size(), Traps.FLAME_REACH)


func test_finding_a_plate_is_told_in_the_log_and_shown_as_a_popup() -> void:
	var w := _world()
	_plate(w, PLATE, World.TRAP_FIRE)
	var before := w.clone()
	w.player().pos = PLATE - E
	w.sense()
	var facts := Perceived.of(before, w, w.events).facts
	assert_eq(_lines(before, w, w.events), ["불 발판을 찾았다"])
	var popups := facts.map(Term.popup_of).filter(func(p): return not p.is_empty())
	assert_eq(popups.map(func(p): return p.text), [Palette.TILES[World.TRAP_FIRE][0]])


func test_a_plate_going_off_shows_a_popup_with_its_click() -> void:
	var fact := {t = &"trap", id = 1, at = PLATE, kind = World.TRAP_ALARM, where = PLATE}
	assert_eq(Term.popup_of(fact).text, Traps.CLICK)


func test_arriving_on_a_new_storey_tells_the_plates_found_there_after_the_climb() -> void:
	var w := World.create(2)
	w.depth = 3
	FloorGen.build(w)
	w.player().hp = 1
	var before := w.clone()
	w.player().pos = w.stairs
	w.arrive(w.player())
	var types := _types(w.events)
	assert_eq(types.slice(0, 2), [&"ascend", &"heal"])
	for i in range(2, types.size()):
		assert_eq(types[i], &"find")
	assert_not_null(before)
