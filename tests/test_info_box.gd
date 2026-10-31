extends GutTest
## The hover box shows every line whole on screen, at every zoom and window.

const AT := Vector2i(8, 8)
## The windows the game runs in: the desktop and a phone held upright.
const VIEWS := [Vector2(1280, 720), Vector2(720, 1280)]
## Settings.ZOOMS: 0 fits the whole map.
const ZOOMS := [0.0, 1.0, 1.25, 1.5]


## An open hall with Miho at ME, all of it seen.
func _world() -> World:
	var w := Codex.stage()
	w.seen.resize(w.tiles.size())
	w.seen.fill(1)
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	return w


## A `kind` at AT held by every condition and showing every situational line.
## `led` is led by a creature (else it leads one); `hunting` is on its way to a drum
## (else it searches).
func _busy(w: World, kind: StringName, led: bool, hunting: bool) -> Actor:
	var a := FloorGen.spawn(w, kind, AT)
	var other := FloorGen.spawn(w, &"dokkaebi", AT + Vector2i(2, 0))
	if led:
		a.leader = other.id
	else:
		other.leader = a.id
	a.rival = other.id
	a.grudge = 5
	a.blind = 3
	a.rooted = 3
	a.stunned = 3
	a.wary = 3
	a.cooldown = 4
	a.lost = 1
	if hunting:
		a.alert = Actor.HUNT
		a.drum = Vector2i(1, 1)
	else:
		a.alert = Actor.SEARCH
	w.burning[AT] = 4
	w.hot[AT] = Vector2i(Compounds.LAVA, 3)
	w.gas[AT] = Vector2i(Gas.STEAM, 5)
	var wisp := Shot.new()
	wisp.host = a.id
	wisp.spell = Spell.make([Cards.FOX])
	wisp.life = 5
	wisp.pos = AT
	w.shots.append(wisp)
	return a


## Every hover a creature can give, as lines.
func _hovers() -> Dictionary:
	var out := {}
	for kind in Codex.foes():
		for led in [false, true]:
			for hunting in [false, true]:
				var w := _world()
				var a := _busy(w, kind, led, hunting)
				out["%s led=%s hunting=%s" % [kind, led, hunting]] = Info.creature(w, a)
	var w := _world()
	w.player().wary = 3
	w.player().blind = 3
	out["miho"] = Info.creature(w, w.player())
	return out


## The screen of a window at a zoom, showing `lines`, and the map tiles to point at:
## its corners and middle.
func _screen(view: Vector2, zoom: float, lines: Array) -> Array:
	var t: Term = autofree(Term.new())
	t.fit(view, zoom)
	t.info = lines
	var v := t.map_view()
	return [t, [Vector2i.ZERO, Vector2i(v.x - 1, 0), Vector2i(0, v.y - 1), v - Vector2i.ONE, v / 2]]


func test_every_creature_hover_is_inside_the_screen_at_every_zoom_and_window() -> void:
	var hovers := _hovers()
	for view: Vector2 in VIEWS:
		for zoom: float in ZOOMS:
			for name: String in hovers:
				var screen := _screen(view, zoom, hovers[name])
				var t: Term = screen[0]
				for p in screen[1] + [null]:
					var fit := t._info_fit(p)
					var box := Rect2(fit.at, fit.cells * fit.scale)
					var where := "%s %s zoom %s cursor %s: %s" % [name, view, zoom, p, box]
					assert_true(Rect2(0, 0, t.cols, t.rows - 2).grow(0.001).encloses(box), where)
					assert_gte(
						fit.scale * t.scale.x, minf(InfoBox.READABLE, t.scale.x) - 0.001, where
					)


func test_the_hover_box_loses_no_line_and_keeps_them_in_order() -> void:
	var hovers := _hovers()
	for view: Vector2 in VIEWS:
		for zoom: float in ZOOMS:
			for name: String in hovers:
				var screen := _screen(view, zoom, hovers[name])
				var drawn := ""
				for column: Array in screen[0]._info_fit().columns:
					for line: Array in column[1]:
						drawn += "".join(line.map(func(run): return run[0])) + "\n"
				var said := ""
				for line: Array in hovers[name]:
					said += "".join(line.map(func(run): return run[0])) + "\n"
				assert_eq(
					drawn.replace(" ", "").replace("\n", ""),
					said.replace(" ", "").replace("\n", ""),
					"%s %s %s" % [name, view, zoom]
				)


func test_the_hover_box_sits_on_the_far_side_of_the_map_from_the_cursor() -> void:
	var screen := _screen(Vector2(1280, 720), 1.0, [[["abc", Color.WHITE]]])
	var t: Term = screen[0]
	var v := t.map_view()
	assert_eq(t._info_fit(Vector2i(0, 0)).at, Vector2(Term.MAP.x + v.x - 2.5, v.y - 1.0))
	assert_eq(t._info_fit(Vector2i(v.x - 1, v.y - 1)).at, Vector2(Term.MAP.x, 0))


func test_a_hover_that_fits_stays_one_column_at_full_size() -> void:
	var lines := [[["abc", Color.WHITE]], [["def", Color.WHITE]]]
	var fit := InfoBox.layout(lines, Vector2(30, 10))
	assert_eq(fit.scale, 1.0)
	assert_eq(fit.columns.size(), 1)
	assert_eq(fit.cells, Vector2(1.5 + 1.0, 2))


func test_a_hover_taller_than_the_room_flows_into_a_second_column() -> void:
	var lines := []
	for k in 6:
		lines.append([["가나다", Color.WHITE]])
	var fit := InfoBox.layout(lines, Vector2(20, 3))
	assert_eq(fit.scale, 1.0)
	assert_eq(fit.columns.size(), 2)
	assert_eq(
		fit.columns[1][0], 0.5 + 3.0 + InfoBox.GAP, "the second column starts after the first"
	)
	assert_eq(fit.cells, Vector2(0.5 + 3.0 + 1.0 + 3.0 + 0.5, 3))


func test_a_column_never_starts_with_the_indented_lines_of_the_one_before() -> void:
	var lines := []
	for text in ["가나", "다라", "마바", "  사", "  아", "자차"]:
		lines.append([[text, Color.WHITE]])
	var fit := InfoBox.layout(lines, Vector2(20, 3))
	assert_eq(fit.scale, 1.0)
	var heads: Array = fit.columns.map(func(c): return c[1][0][0][0])
	assert_eq(heads, ["가나", "마바", "자차"], "마바 moves over with the lines under it")
	assert_eq(fit.cells.y, 3.0)


func test_a_hover_too_big_for_any_columns_shrinks() -> void:
	var lines := []
	for k in 4:
		lines.append([["가나다라마바", Color.WHITE]])
	var fit := InfoBox.layout(lines, Vector2(7, 2))
	assert_lt(fit.scale, 1.0)
	assert_lte(fit.cells.x * fit.scale, 7.0)
	assert_lte(fit.cells.y * fit.scale, 2.0)
