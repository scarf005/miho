class_name Codex
extends RefCounted
## The 도감: every creature, spell, compound, item and terrain feature, whether
## or not Miho has met it, and the rules many of them share (Info.glossary),
## by the tag their hovers show. The list is on the left; on the right the selected
## entry reads as its hover does, from the same Info and SpellInfo functions,
## less the lines about how it stands now (state, sight, light): a creature
## from `foe`, a feature of the floor on the tile AT of a stand-in world
## (`stage`, an unlit hall with Miho at ME). The entries come from the data
## tables, so a new kind appears with no change here. Beside the detail, an entry with
## a scene (CodexScene) plays it (CodexSim) where the screen has room.
## `key` returns &"close" or nothing.

const TABS := ["적", "주문", "조합", "아이템", "지형지물", "상태이상", "용어"]
## The cell where the detail starts.
const SIDE_X := 13.0
const ME := Vector2i(4, 8)
const AT := Vector2i(5, 8)

static var _words := RegEx.create_from_string(" *[^ ]+| +")

var tab := 0
## The rank of the storey Miho is on (Bestiary.rank): the creatures read as there.
var rank := 1
var selected := 0
## The first entry shown, and the entry the pointer is over (-1 for none).
var top := 0
var hover := -1
## Lines the detail is scrolled down.
var scroll := 0
## The screen in cells: columns, rows.
var room := Vector2i(40, 18)


## An unlit hall walled all round, Miho at ME, full health.
static func stage() -> World:
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
	me.hp = Bestiary.info(&"miho").hp
	me.max_hp = me.hp
	me.pos = ME
	w.actors.append(me)
	w.sense()
	return w


## The entries of a tab: {glyph, color, name, lines}, `lines` a Callable
## returning the hover lines; a creature as it comes at rank `at_rank`.
static func entries(tab_index: int, at_rank := 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match tab_index:
		0:
			for kind in foes():
				var spec := Bestiary.info(kind)
				var lines := func(): return Info.creature_facts(foe(kind, at_rank), [])
				out.append(_entry(spec.glyph, Palette.KIND[kind], spec.name, lines, kind))
		1:
			for c in Cards.FORMS + Cards.ELEMENTS:
				out.append(_talisman(c))
			for kind in SpellInfo.RECIPE:
				var s := Spell.make(SpellInfo.RECIPE[kind])
				var color := Palette.shot_color(s, Actor.FOX)
				out.append(
					_entry(
						Palette.shot_glyph(s),
						color,
						Spell.SHAPE_NAME[kind],
						_shape(kind),
						kind,
						s.cards
					)
				)
			out.append(
				_entry(
					":",
					Palette.TEXT,
					SpellInfo.SPRAY_NAME,
					_shape(Spell.SPRAY),
					Spell.SPRAY,
					[Cards.FIRE]
				)
			)
			for cards in SpellInfo.GUNS:
				var s := Spell.make(cards)
				var lines := func(): return SpellInfo.spell(s)
				out.append(
					_entry(
						Palette.shot_glyph(s),
						Palette.shot_color(s, Actor.FOX),
						s.title(),
						lines,
						StringName(s.key()),
						s.cards
					)
				)
			for kind in Guise.RECIPE:
				var s := Spell.make(Guise.RECIPE[kind])
				var lines := func(): return SpellInfo.own(kind)
				var color := Palette.card(s.slots.back())
				out.append(_entry(",", color, Guise.NAME[kind], lines, kind, s.cards))
		2:
			for c in Cards.compounds():
				var lines := func(): return SpellInfo.combo(c)
				var cards := Cards.made_of(c)
				out.append(_entry(Cards.GLYPH[c], Palette.card(c), Cards.NAME[c], lines, c, cards))
		3:
			out.append(_feature(Palette.ELIXIR[0], Palette.ELIXIR[1], "영약", _elixir, &"elixir"))
			out.append(_feature(Palette.PEACH[0], Palette.PEACH[1], "복숭아", _peach, &"peach"))
			var kimchi := Jars.name_of(Jars.KIMCHI)
			out.append(_feature(Palette.KIMCHI[0], Palette.KIMCHI[1], kimchi, _kimchi, Jars.KIMCHI))
			out.append(
				_feature(Palette.SCROLL, Palette.CARD[Cards.FIRE], "주문서", _scroll, &"scroll")
			)
			for c in Cards.ELEMENTS:
				out.append(_talisman(c))
		4:
			for t in Tiles.ROWS:
				if Tiles.of(t, "name") != "":
					var tile := func(w: World): w.set_tile(AT, t)
					var glyph: Array = Palette.TILES[t]
					out.append(_feature(glyph[0], glyph[1], Tiles.of(t, "name"), tile, t))
					if t == World.JAR:
						out.back().lines = func(): return _ground(tile) + Info.jar_facts()
			out.append_array(_extras())
		5:
			for key in Status.NAME:
				var glyph: Array = Palette.STATUS[key]
				var lines := Info.status_facts.bind(key)
				out.append(_entry(glyph[0], glyph[1], Status.NAME[key], lines, key))
			for name: String in Info.CONDITIONS:
				out.append(_entry("·", Palette.TEXT, name, Info.condition_facts.bind(name), name))
		6:
			for term: String in Info.glossary():
				out.append(_entry("·", Palette.TEXT, term, Info.term_facts.bind(term)))
	return out


## The creatures, as the bestiary lists them, Miho left out.
static func foes() -> Array:
	return Bestiary.KINDS.keys().filter(func(k): return k != &"miho")


## A creature of `kind` of rank `at_rank` at full health, unaware.
static func foe(kind: StringName, at_rank := 1) -> Actor:
	var a := Actor.new()
	a.kind = kind
	a.rank = at_rank
	a.hp = Bestiary.hp(kind, at_rank)
	a.max_hp = a.hp
	a.mana = Bestiary.mana(kind)
	return a


## The lines of an entry: what the hover tells of it, less how it stands now.
static func detail(entry: Dictionary) -> Array:
	return entry.lines.call()


## `lines` cut to rows `width` cells wide, breaking after a space, or inside a
## word wider than the row.
static func flow(lines: Array, width: float) -> Array:
	var out := []
	for line: Array in lines:
		var row := []
		var x := 0.0
		for run: Array in line:
			for m in _words.search_all(run[0]):
				var word := m.get_string()
				if x > 0.0 and x + Term._cells(word) > width:
					out.append(row)
					row = []
					x = 0.0
					word = word.lstrip(" ")
				while Term._cells(word) > width:
					var cut := 1
					while Term._cells(word.left(cut + 1)) <= width:
						cut += 1
					out.append(row + [Keywords.piece(run, word.left(cut))])
					row = []
					word = word.substr(cut)
				row.append(Keywords.piece(run, word))
				x += Term._cells(word)
		out.append(row)
	return out


## What the page shows, as a Term.panel.
func panel() -> Dictionary:
	var list := entries(tab, rank)
	var rows := []
	for e in list:
		rows.append([[e.glyph, e.color, 2.0], [e.name, Palette.TEXT, 4.0]])
	var lines := _lines()
	var fits := _lines_fit()
	scroll = clampi(scroll, 0, maxi(0, lines.size() - fits))
	var shown := lines.slice(scroll, scroll + fits).map(_legible)
	return {
		title = "도감",
		tabs = TABS,
		tab = tab,
		rows = rows,
		selected = selected,
		top = top,
		hover = hover,
		aside = shown,
		aside_x = SIDE_X,
		opaque = true,
		aside_up = scroll > 0,
		aside_down = scroll + fits < lines.size(),
		example = _example(list[selected]),
	}


## The example beside `entry`, the selected one (CodexSim): empty when it has none or
## the screen has no room for one. A creature's reads as its entry does, at `rank`.
func _example(entry: Dictionary) -> Dictionary:
	var k := CodexSim.scale_for(room)
	if entry.scene.is_empty() or k == 0.0:
		return {}
	return {entry = [tab, selected], scene = entry.scene, rank = rank if tab == 0 else 0, scale = k}


## A line with the dim runs in plain text colour, so a whole page reads.
static func _legible(line: Array) -> Array:
	return line.map(
		func(run):
			return Keywords.piece(run, run[0], Palette.TEXT if run[1] == Palette.DIM else null)
	)


## Handles a key press that menu movement `nav` names: Left and Right, Tab and
## Shift+Tab (or 1 to 7) change the tab; Up, Down, Home and End the entry, which
## wrap at the ends; Page Up and Down scroll the detail while it overflows, else
## move the entry a page.
func key(e: InputEventKey, nav: StringName) -> StringName:
	var action := Keys.action_of(e)
	if nav == &"back" or action == &"codex":
		return &"close"
	var pick := int(action.trim_prefix("pick_")) if action.begins_with("pick_") else 0
	if pick > 0 and pick <= TABS.size():
		go(pick - 1)
	elif nav in [&"left", &"right", &"tab_prev", &"tab_next"]:
		go(posmod(tab + (1 if nav in [&"right", &"tab_next"] else -1), TABS.size()))
	elif nav == &"page_down" and scroll < _lines().size() - _lines_fit():
		scroll = ListNav.scrolled(scroll, maxi(1, _lines_fit() - 1), _lines().size(), _lines_fit())
	elif nav == &"page_up" and scroll > 0:
		scroll = ListNav.scrolled(scroll, -maxi(1, _lines_fit() - 1), _lines().size(), _lines_fit())
	else:
		select(ListNav.step(nav, selected, entries(tab).size(), _fits()))
	return &""


## The selection moves to entry k, kept in view.
func select(k: int) -> void:
	if k != selected:
		selected = k
		scroll = 0
	top = ListNav.reveal(top, selected, entries(tab).size(), _fits())


## Scrolls `dir` notches of the wheel: the detail when the pointer is over it,
## else the list.
func wheel(dir: int, aside: bool) -> void:
	scroll_by(dir * ListNav.WHEEL, aside)


## Scrolls `lines` lines of the detail, or rows of the list.
func scroll_by(lines: int, aside: bool) -> void:
	if aside:
		scroll = ListNav.scrolled(scroll, lines, _lines().size(), _lines_fit())
	else:
		top = ListNav.scrolled(top, lines, entries(tab).size(), _fits())


func go(t: int) -> void:
	tab = t
	selected = 0
	top = 0
	scroll = 0


## The detail of the selected entry, cut to the room.
func _lines() -> Array:
	var entry: Dictionary = entries(tab, rank)[selected]
	var example := _example(entry)
	var taken: float = 0.0 if example.is_empty() else CodexSim.beside(example.scale)
	return flow(detail(entry), room.x - SIDE_X - 1.0 - taken)


## Rows of the list that fit.
func _fits() -> int:
	return PanelView.fits(room.y, 0)


## Lines of the detail that fit.
func _lines_fit() -> int:
	return PanelView.lines_fit(room.y, 0)


## An entry, its example the row `key` of CodexScene.
static func _entry(
	glyph: String, color: Color, name: String, lines: Callable, key: Variant = null, cards := []
) -> Dictionary:
	var scene := CodexScene.of(key, cards)
	return {glyph = glyph, color = color, name = name, lines = lines, scene = scene}


static func _talisman(c: StringName) -> Dictionary:
	var lines := func(): return SpellInfo.card(c, null)
	return _entry(Cards.GLYPH[c], Palette.CARD[c], Cards.NAME[c] + " 부적", lines, c, [c])


static func _shape(kind: StringName) -> Callable:
	return func(): return SpellInfo.shape(kind)


## A feature of the floor: the hover over tile AT after `change` has set it up.
static func _feature(
	glyph: String, color: Color, name: String, change: Callable, key: Variant = null
) -> Dictionary:
	return _entry(glyph, color, name, func(): return _ground(change), key)


static func _ground(change: Callable) -> Array:
	var w := stage()
	change.call(w)
	w.sense()
	return Info.terrain_facts(w, AT)


## Like `_feature`, for what lies on a plain floor tile (fire, hot ground, gas):
## the hover's floor name line is left out, as the mark's own lines say what it is.
static func _mark(
	glyph: String, color: Color, name: String, change: Callable, key: StringName
) -> Dictionary:
	return _entry(glyph, color, name, func(): return _ground(change).slice(1), key)


## The stairs, then what lies on a plain floor tile.
static func _extras() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_feature(Palette.STAIRS[0], Palette.STAIRS[1], "계단", _stairs))
	var fire := func(w: World): w.burning[AT] = World.BURN_ROUNDS
	out.append(_mark(Palette.BURNING[0], Palette.BURNING[1], "불타는 칸", fire, &"burning"))
	var fierce := func(w: World):
		w.set_tile(AT, World.STRAW)
		w.burning[AT] = World.BURN_ROUNDS
	var flame: Array = Palette.FIERCE_BURNING
	out.append(_mark(flame[0], flame[1], "맹렬한 불", fierce, &"fierce"))
	for kind in Compounds.HOT.size():
		var heat := func(w: World): w.hot[AT] = Vector2i(kind, Compounds.HOT_ROUNDS)
		var row := StringName("hot%d" % kind)
		out.append(_mark(Palette.HOT[0], Palette.HOT[1], Compounds.HOT[kind].name, heat, row))
	for kind in Gas.ROWS:
		var gas := func(w: World): Gas.put(w, AT, kind, Gas.MAX)
		var look: Array = Palette.GAS[kind]
		var row := StringName("gas%d" % kind)
		out.append(_mark(look[0], look[1], Gas.of(kind, "name"), gas, row))
	var label: String = Notice.LABEL[&"body"]
	var body := func(): return [[[label, Palette.BODY[1]]], [[Info.TRACE, Palette.DIM]]]
	out.append(_entry(Palette.BODY[0], Palette.BODY[1], label, body, &"body"))
	return out


static func _stairs(w: World) -> void:
	w.stairs = AT


static func _elixir(w: World) -> void:
	w.elixir = AT


static func _peach(w: World) -> void:
	w.peaches.append(AT)


static func _kimchi(w: World) -> void:
	w.sites.append({kind = Jars.KIMCHI, at = AT})


static func _scroll(w: World) -> void:
	w.sites.append({kind = &"scroll", at = AT, card = Cards.FIRE})
