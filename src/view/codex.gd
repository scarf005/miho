class_name Codex
extends RefCounted
## The 도감: every creature, spell, compound, item and terrain feature, whether
## or not Miho has met it. The list is on the left; on the right the selected
## entry reads as its hover does, from the same Info and SpellInfo functions,
## less the lines about how it stands now (state, sight, light): a creature
## from `foe`, a feature of the floor on the tile AT of a stand-in world
## (`stage`, an unlit hall with Miho at ME). The entries come from the data
## tables, so a new kind appears with no change here.
## `key` returns &"close" or nothing.

const TABS := ["적", "주문", "조합", "아이템", "지형지물"]
## The cell where the detail starts.
const SIDE_X := 13.0
const ME := Vector2i(4, 8)
const AT := Vector2i(5, 8)

static var _words := RegEx.create_from_string(" *[^ ]+| +")

var tab := 0
var selected := 0
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
## returning the hover lines.
static func entries(tab_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match tab_index:
		0:
			for kind in foes():
				var spec := Bestiary.info(kind)
				var lines := func(): return Info.creature_facts(foe(kind), [])
				out.append(_entry(spec.glyph, Palette.KIND[kind], spec.name, lines))
		1:
			for c in Cards.FORMS + Cards.ELEMENTS:
				out.append(_talisman(c))
			for kind in SpellInfo.RECIPE:
				var s := Spell.make(SpellInfo.RECIPE[kind])
				var color := Palette.shot_color(s, Actor.FOX)
				out.append(
					_entry(Palette.shot_glyph(s), color, Spell.SHAPE_NAME[kind], _shape(kind))
				)
			out.append(_entry(":", Palette.TEXT, SpellInfo.SPRAY_NAME, _shape(Spell.SPRAY)))
		2:
			for c in Cards.PAIRS:
				var lines := func(): return SpellInfo.combo(c)
				out.append(_entry(Cards.GLYPH[c], Palette.card(c), Cards.NAME[c], lines))
		3:
			out.append(_feature(Palette.ELIXIR[0], Palette.ELIXIR[1], "영약", _elixir))
			out.append(_feature(Palette.PEACH[0], Palette.PEACH[1], "복숭아", _peach))
			for c in Cards.ELEMENTS:
				out.append(_talisman(c))
		4:
			for t in Tiles.ROWS:
				if Tiles.of(t, "name") != "":
					var tile := func(w: World): w.set_tile(AT, t)
					var glyph: Array = Palette.TILES[t]
					out.append(_feature(glyph[0], glyph[1], Tiles.of(t, "name"), tile))
			out.append_array(_extras())
	return out


## The creatures, as the bestiary lists them, Miho left out.
static func foes() -> Array:
	return Bestiary.KINDS.keys().filter(func(k): return k != &"miho")


## A creature of `kind` at full health, unaware.
static func foe(kind: StringName) -> Actor:
	var a := Actor.new()
	a.kind = kind
	a.hp = Bestiary.info(kind).hp
	a.max_hp = a.hp
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
					out.append(row + [[word.left(cut), run[1]]])
					row = []
					word = word.substr(cut)
				row.append([word, run[1]])
				x += Term._cells(word)
		out.append(row)
	return out


## What the page shows, as a Term.panel.
func panel() -> Dictionary:
	var list := entries(tab)
	var rows := []
	for e in list:
		rows.append([[e.glyph, e.color, 2.0], [e.name, Palette.TEXT, 4.0]])
	var lines := flow(detail(list[selected]), room.x - SIDE_X - 1.0)
	var fits := room.y - 4
	scroll = clampi(scroll, 0, maxi(0, lines.size() - fits))
	var shown := lines.slice(scroll, scroll + fits).map(_legible)
	return {
		title = "도감",
		tabs = TABS,
		tab = tab,
		rows = rows,
		selected = selected,
		aside = shown,
		aside_x = SIDE_X,
		opaque = true,
		aside_up = scroll > 0,
		aside_down = scroll + fits < lines.size(),
	}


## A line with the dim runs in plain text colour, so a whole page reads.
static func _legible(line: Array) -> Array:
	return line.map(func(run): return [run[0], Palette.TEXT if run[1] == Palette.DIM else run[1]])


## Handles a key press that menu movement `nav` names: Left and Right (or 1 to
## 5) change the tab, Up and Down the entry, Page Up and Down scroll the detail.
func key(e: InputEventKey, nav: StringName) -> StringName:
	var action := Keys.action_of(e)
	if nav == &"back" or action == &"codex":
		return &"close"
	var last := entries(tab).size() - 1
	if action.begins_with("pick_") and int(action.trim_prefix("pick_")) <= TABS.size():
		_go(int(action.trim_prefix("pick_")) - 1)
	elif nav in [&"left", &"right"]:
		_go(posmod(tab + (1 if nav == &"right" else -1), TABS.size()))
	elif nav in [&"up", &"down"]:
		point(clampi(selected + (1 if nav == &"down" else -1), 0, last))
	elif e.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		scroll = maxi(0, scroll + (1 if e.keycode == KEY_PAGEDOWN else -1) * (room.y - 5))
	return &""


## The pointer is over row k, or the selection moves to it.
func point(k: int) -> void:
	if k != selected:
		selected = k
		scroll = 0


func _go(t: int) -> void:
	tab = t
	selected = 0
	scroll = 0


static func _entry(glyph: String, color: Color, name: String, lines: Callable) -> Dictionary:
	return {glyph = glyph, color = color, name = name, lines = lines}


static func _talisman(c: StringName) -> Dictionary:
	var lines := func(): return SpellInfo.card(c, null)
	return _entry(Cards.GLYPH[c], Palette.CARD[c], Cards.NAME[c] + " 부적", lines)


static func _shape(kind: StringName) -> Callable:
	return func(): return SpellInfo.shape(kind)


## A feature of the floor: the hover over tile AT after `change` has set it up.
static func _feature(glyph: String, color: Color, name: String, change: Callable) -> Dictionary:
	return _entry(glyph, color, name, func(): return _ground(change))


static func _ground(change: Callable) -> Array:
	var w := stage()
	change.call(w)
	w.sense()
	return Info.terrain_facts(w, AT)


## Like `_feature`, for what lies on a plain floor tile (fire, hot ground, gas):
## the hover's floor name line is left out, as the mark's own lines say what it is.
static func _mark(glyph: String, color: Color, name: String, change: Callable) -> Dictionary:
	return _entry(glyph, color, name, func(): return _ground(change).slice(1))


## The stairs, then what lies on a plain floor tile.
static func _extras() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_feature(Palette.STAIRS[0], Palette.STAIRS[1], "계단", _stairs))
	var fire := func(w: World): w.burning[AT] = World.BURN_ROUNDS
	out.append(_mark(Palette.BURNING[0], Palette.BURNING[1], "불타는 칸", fire))
	for kind in Compounds.HOT.size():
		var heat := func(w: World): w.hot[AT] = Vector2i(kind, Compounds.HOT_ROUNDS)
		out.append(_mark(Palette.HOT[0], Palette.HOT[1], Compounds.HOT[kind].name, heat))
	for kind in Gas.ROWS:
		var gas := func(w: World): Gas.put(w, AT, kind, Gas.MAX)
		out.append(_mark(Palette.GAS[kind][0], Palette.GAS[kind][1], Gas.of(kind, "name"), gas))
	var label: String = Notice.LABEL[&"body"]
	var body := func(): return [[[label, Palette.BODY[1]]], [[Info.BODY_RULE, Palette.DIM]]]
	out.append(_entry(Palette.BODY[0], Palette.BODY[1], label, body))
	return out


static func _stairs(w: World) -> void:
	w.stairs = AT


static func _elixir(w: World) -> void:
	w.elixir = AT


static func _peach(w: World) -> void:
	w.peaches.append(AT)
