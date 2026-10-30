class_name Term
extends Control
## The screen as a Brogue-style terminal of COLS x ROWS cells in one pixel
## font. Columns 0-7 list the creatures Miho sees, the map fills the rest, and
## the two bottom rows hold her health, tails, storey, time and talismans.
## Every tile takes the colour of the light on it, lantern light flickers, and
## tiles out of sight are drawn from memory in dim blue. `play` animates a
## round's events one by one, carrying each projectile's light with it.

signal shown(e: Dictionary, at: Vector2)

const COLS := 40
const ROWS := 18
const CELL := Vector2(32, 40)
const MAP := Vector2i(8, 0)
const SIZE := 32
const BIG := 48
const SMALL := 16
const DELAY := {
	&"move": 0.05,
	&"spawn": 0.04,
	&"fly": 0.03,
	&"land": 0.05,
	&"hit": 0.1,
	&"burst": 0.1,
	&"clash": 0.1,
	&"claw": 0.16,
	&"club": 0.16,
	&"die": 0.14,
	&"flash": 0.16,
	&"charge": 0.08,
}

var world: World
var picked: Array[StringName] = []
var staged: Array[Dictionary] = []
## Set by the game: tile -> Color tints, and tile -> [text, Color] marks.
var tints := {}
var marks := {}
var replay := false
var speed := 1.0
var banner_lines: Array[String] = []

var _font: FontFile
var _vis := PackedByteArray()
var _actors := {}
var _shots := {}
var _animating := false
var _popups: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _lanterns: Array[Dictionary] = []
var _shot_light := {}
var _time := 0.0


func _ready() -> void:
	_font = Fonts.pixel()
	size = Vector2(COLS, ROWS) * CELL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	var now := _time
	_popups = _popups.filter(func(p): return now - p.born < p.life)
	_flashes = _flashes.filter(func(f): return now - f.born < 0.35)
	queue_redraw()


## Shows the world as it is now, with nothing in flight.
func show_world(w: World) -> void:
	world = w
	_vis = w.seen
	_actors.clear()
	_shots.clear()
	_animating = false
	_lanterns.clear()
	for i in w.tiles.size():
		if w.tiles[i] == World.LANTERN:
			var s := Light.spread(Grid.at(i), Light.LANTERN_RADIUS, w.opaque)
			var lit := PackedInt32Array()
			var amount := PackedFloat32Array()
			for j in s.size():
				if s[j] > 0.0:
					lit.append(j)
					amount.append(s[j])
			_lanterns.append({lit = lit, amount = amount, phase = float(i) * 1.7})


## Animates one round from `before` to `after`, then shows `after`.
func play(events: Array, before: World, after: World) -> void:
	world = after
	_vis = before.seen.duplicate()
	for i in after.seen.size():
		if after.seen[i] == 1:
			_vis[i] = 1
	_actors.clear()
	for a in before.actors:
		if a.alive():
			_actors[a.id] = a.clone()
	_shots.clear()
	for s in before.shots:
		_shots[s.id] = {pos = s.pos, spell = s.spell, faction = s.faction}
	_animating = true
	for e in events:
		var wait := _apply(e)
		if wait > 0.0:
			await get_tree().create_timer(wait / speed).timeout
	show_world(after)


func _visible(p: Vector2i) -> bool:
	return Grid.inside(p) and _vis[Grid.index(p)] == 1


## Applies one event to what is drawn; returns how long to hold it.
func _apply(e: Dictionary) -> float:
	var at: Vector2i = e.get("to", e.get("at", Vector2i(-1, -1)))
	if not Grid.inside(at) and _actors.has(e.get("id", -1)):
		at = _actors[e.id].pos
	var seen := (
		not Grid.inside(at) and not e.has("id")
		or _visible(at)
		or (e.has("from") and _visible(e.from))
	)
	match e.t:
		&"move":
			if _actors.has(e.id):
				_actors[e.id].pos = e.to
		&"spawn":
			_shots[e.shot] = {pos = e.at, spell = Spell.make(e.cards), faction = e.faction}
		&"fly":
			if _shots.has(e.shot):
				_shots[e.shot].pos = e.to
		&"burst", &"hit", &"fade", &"snuff":
			_shots.erase(e.shot)
			_flash(at, Color(1, 1, 1, 0.5))
		&"clash":
			_shots.erase(e.shot)
			_shots.erase(e.other)
			_flash(at, Color(1, 1, 1, 0.8))
		&"claw", &"club":
			_flash(at, Palette.HURT)
		&"hurt":
			_popup(at, str(e.n), Palette.HURT)
		&"die":
			_actors.erase(e.id)
		&"notice":
			_popup(at, "!", Palette.ALERT[2])
		&"flash":
			for d: Vector2i in Grid.DIRS + [Vector2i.ZERO]:
				_flash(at + d * 1, Color(1, 1, 1, 0.9))
		&"card":
			_popup(at, Cards.GLYPH[e.card], Palette.CARD[e.card], 1.6)
		&"heal":
			_popup(at, "+1", Palette.PEACH[1])
		&"noise":
			if e.heard and not _visible(e.at):
				_popup(e.at, e.word, Palette.SOUND, 1.4)
				shown.emit(e, cell_centre(e.at))
			return 0.0
	if not seen:
		return 0.0
	shown.emit(e, cell_centre(at))
	return DELAY.get(e.t, 0.0)


func _popup(at: Vector2i, text: String, color: Color, life := 0.9) -> void:
	_popups.append({at = at, text = text, color = color, born = _time, life = life})


func _flash(at: Vector2i, color: Color) -> void:
	if _visible(at):
		_flashes.append({at = at, color = color, born = _time})


## Screen position of the centre of map tile p, in this node's space.
func cell_centre(p: Vector2i) -> Vector2:
	return (Vector2(MAP + p) + Vector2(0.5, 0.5)) * CELL


## The map tile under a point in this node's space, or (-1, -1).
func tile_at(local: Vector2) -> Vector2i:
	var c := Vector2i((local / CELL).floor()) - MAP
	return c if Grid.inside(c) else Vector2i(-1, -1)


## The talisman under a point in this node's space, or empty.
func card_at(local: Vector2) -> StringName:
	var c := Vector2i((local / CELL).floor())
	if c.y != ROWS - 1 or world == null:
		return &""
	var i := (c.x - MAP.x) / 3
	if c.x < MAP.x or i >= world.cards.size():
		return &""
	return world.cards[i]


# --- light -------------------------------------------------------------------


func _field() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(Grid.W * Grid.H)
	for l in _lanterns:
		var k: float = 0.9 + 0.07 * sin(_time * 6.1 + l.phase) + 0.04 * sin(_time * 15.7 + l.phase)
		var c := Light.LANTERN * k
		var lit: PackedInt32Array = l.lit
		var amount: PackedFloat32Array = l.amount
		for j in lit.size():
			out[lit[j]] += c * amount[j]
	var shots := _shots if _animating else _world_shots()
	for id in shots:
		var s: Dictionary = shots[id]
		var l: Dictionary = s.spell.light(s.faction)
		if l.is_empty():
			continue
		var key := "%d@%s" % [id, s.pos]
		if not _shot_light.has(key):
			_shot_light[key] = Light.spread(s.pos, l.radius, world.opaque)
		var spread: PackedFloat32Array = _shot_light[key]
		var c: Vector3 = l.color * (0.92 + 0.08 * sin(_time * 11.0 + id))
		for i in spread.size():
			if spread[i] > 0.0:
				out[i] += c * spread[i]
	if _shot_light.size() > 256:
		_shot_light.clear()
	return out


func _world_shots() -> Dictionary:
	var out := {}
	for s in world.shots:
		out[s.id] = {pos = s.pos, spell = s.spell, faction = s.faction}
	return out


func _world_actors() -> Dictionary:
	var out := {}
	for a in world.actors:
		if a.alive():
			out[a.id] = a
	return out


# --- drawing -----------------------------------------------------------------


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.VOID)
	if world == null:
		return
	var light := _field()
	var actors := _actors if _animating else _world_actors()
	var me := world.player()
	var me_pos: Vector2i = actors[me.id].pos if actors.has(me.id) else me.pos
	_draw_map(light, me_pos)
	_draw_telegraphs(actors)
	_draw_things(light, actors)
	for f in _flashes:
		var k: float = 1.0 - (_time - f.born) / 0.35
		var c: Color = f.color
		draw_rect(Rect2(Vector2(MAP + f.at) * CELL, CELL), Color(c, c.a * k))
	for p in _popups:
		var k: float = (_time - p.born) / p.life
		var c: Color = p.color
		var at := Vector2(MAP + p.at) + Vector2(0, -0.6 * k)
		if p.text.length() == 1:
			_glyph(at, p.text, Color(c, 1.0 - k * k))
		else:
			_text(at, p.text, Color(c, 1.0 - k * k))
	if not replay:
		_draw_side(actors, me_pos)
		_draw_bottom()
	if not banner_lines.is_empty():
		draw_rect(Rect2(Vector2(MAP) * CELL, Vector2(Grid.W, Grid.H) * CELL), Color(0, 0, 0, 0.8))
	for i in banner_lines.size():
		var line := banner_lines[i]
		var color: Color = Palette.KIND[&"miho"] if i == 0 else Palette.TEXT
		_text(Vector2(MAP.x + (Grid.W - _cells(line)) / 2.0, 5 + i * 2), line, color)


func _draw_map(light: PackedVector3Array, me_pos: Vector2i) -> void:
	for i in world.tiles.size():
		var p := Grid.at(i)
		if world.known[i] == 0 and _vis[i] == 0:
			continue
		var t := world.tiles[i]
		var spec: Array = Palette.TILES[t]
		var glyph: String = spec[0]
		var fg: Color = spec[1]
		var bg: Color = spec[2]
		if t == World.DOOR and not world.opaque(p):
			glyph = Palette.OPEN_DOOR
		for item in [[world.stairs, Palette.STAIRS], [world.elixir, Palette.ELIXIR]]:
			if p == item[0]:
				glyph = item[1][0]
				fg = item[1][1]
		if world.peaches.has(p):
			glyph = Palette.PEACH[0]
			fg = Palette.PEACH[1]
		if _vis[i] == 1:
			var l := light[i]
			var d := Grid.cheb(p, me_pos)
			if d <= World.NIGHT[0]:
				l += Palette.NIGHT * (1.0 - d / 3.0)
			if t != World.LANTERN:
				fg = _lit(fg, l, 0.18)
				bg = _lit(bg, l, 0.0) + Color(l.x, l.y, l.z) * 0.06
		elif world.dim[i] == 1:
			fg = fg * 0.3 + Palette.STARLIGHT
			bg = bg * 0.22 + Palette.STARLIGHT * 0.4
		else:
			var v := fg.get_luminance()
			fg = Palette.MEMORY_FG * (0.6 + v * 0.6)
			bg = Palette.MEMORY_BG
		var grain := 0.92 + 0.16 * fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		fg *= grain
		bg *= grain
		var tint: Color = tints.get(p, Color(0, 0, 0, 0))
		bg = bg.lerp(Color(tint, 1.0), tint.a)
		var cell := Vector2(MAP + p)
		draw_rect(Rect2(cell * CELL, CELL), bg)
		_glyph(cell, glyph, fg)


static func _lit(c: Color, l: Vector3, floor_level: float) -> Color:
	return Color(
		c.r * clampf(floor_level + l.x, 0.0, 1.6),
		c.g * clampf(floor_level + l.y, 0.0, 1.6),
		c.b * clampf(floor_level + l.z, 0.0, 1.6)
	)


## A charging creature's line, so every incoming spell is seen a round early.
func _draw_telegraphs(actors: Dictionary) -> void:
	for id in actors:
		var a: Actor = actors[id]
		if a.faction == Actor.FOX or a.intent.is_empty() or not _visible(a.pos):
			continue
		var spell := Spell.make(a.intent)
		var ray := Forecast.ray(world, a.pos, a.aim)
		if not spell.orb:
			ray = ray.slice(0, Spell.RANGE)
		for k in ray.size():
			var pulse := 0.5 + 0.5 * sin(_time * 8.0 - k * 0.6)
			var c := Color(Palette.SIDE[1], 0.16 + 0.14 * pulse)
			draw_rect(Rect2(Vector2(MAP + ray[k]) * CELL, CELL), c)
			if k == 0:
				_glyph(Vector2(MAP + ray[k]), Palette.BOLT[a.aim], Palette.SIDE[1])


func _draw_things(light: PackedVector3Array, actors: Dictionary) -> void:
	var shots := _shots if _animating else _world_shots()
	for id in shots:
		var s: Dictionary = shots[id]
		if _visible(s.pos):
			_glyph(
				Vector2(MAP + s.pos),
				Palette.shot_glyph(s.spell),
				Palette.shot_color(s.spell, s.faction)
			)
	for id in actors:
		var a: Actor = actors[id]
		if a.faction != Actor.FOX and not _visible(a.pos):
			continue
		var cell := Vector2(MAP + a.pos)
		var l := light[Grid.index(a.pos)]
		var c: Color = Palette.KIND[a.kind]
		if a.faction != Actor.FOX:
			c = c * clampf(0.55 + Light.level(l), 0.55, 1.2)
			c.a = 1.0
		elif Light.level(l) < Light.LIT:
			c = c.darkened(0.45)
		draw_rect(Rect2(cell * CELL, CELL), Color(0, 0, 0, 0.55))
		_glyph(cell, a.info().glyph, c)
		if a.faction != Actor.FOX:
			var mark: String = Palette.ALERT_MARK[a.alert]
			if a.blind > 0:
				mark = "x"
			if mark != "":
				_small(cell + Vector2(0.62, -0.05), mark, Palette.ALERT[maxi(a.alert, 1)])
	for p in marks:
		var m: Array = marks[p]
		_small(Vector2(MAP + p) + Vector2(0.62, 0.55), m[0], m[1])


## Creatures in sight, nearest first: glyph and health, then state and the spell it charges.
func _draw_side(actors: Dictionary, me_pos: Vector2i) -> void:
	var list: Array = actors.values().filter(
		func(a): return a.faction != Actor.FOX and _visible(a.pos)
	)
	list.sort_custom(func(a, b): return Grid.cheb(a.pos, me_pos) < Grid.cheb(b.pos, me_pos))
	for k in mini(list.size(), (ROWS - 2) / 2):
		var a: Actor = list[k]
		var row := k * 2
		_glyph(Vector2(0, row), a.info().glyph, Palette.KIND[a.kind])
		_pips(Vector2(1.5, row), a.hp, a.max_hp, Palette.HURT)
		var mark: String = Palette.ALERT_MARK[a.alert]
		if a.blind > 0:
			mark = "x"
		_glyph(Vector2(0, row + 1), mark, Palette.ALERT[maxi(a.alert, 1)])
		for j in a.intent.size():
			_glyph(Vector2(1 + j, row + 1), Cards.GLYPH[a.intent[j]], Palette.CARD[a.intent[j]])
		if not a.intent.is_empty():
			_glyph(Vector2(1 + a.intent.size(), row + 1), Palette.BOLT[a.aim], Palette.SIDE[1])


func _draw_bottom() -> void:
	var me := world.player()
	var row := ROWS - 2
	_glyph(Vector2(0, row), "@", Palette.KIND[&"miho"])
	_pips(Vector2(1.5, row), me.hp, me.max_hp, Palette.HURT)
	var held: int = staged.reduce(func(n, s): return n + s.cards.size(), 0) + picked.size()
	for i in world.max_tails():
		var c: Color = Palette.SIDE[0]
		if i >= world.tails:
			c = Palette.DIM
		elif i >= world.tails - held:
			c = Palette.CARD[Cards.EARTH]
		_glyph(Vector2(MAP.x + i, row), "~", c)
	var right := "%d층 %d초" % [world.depth, world.round_no]
	_text(Vector2(COLS - _cells(right), row), right, Palette.TEXT)
	row += 1
	for i in world.cards.size():
		var card := world.cards[i]
		var x := MAP.x + i * 3
		if picked.has(card):
			draw_rect(
				Rect2(Vector2(x, row) * CELL, Vector2(2, 1) * CELL), Palette.CARD[card] * 0.45
			)
		_small(Vector2(x, row + 0.05), str(i + 1), Palette.DIM)
		_glyph(Vector2(x + 1, row), Cards.GLYPH[card], Palette.CARD[card])
	var spell := Spell.make(picked)
	var name := spell.title() if spell != null else ""
	if not staged.is_empty():
		name = "+%d %s" % [staged.size(), name]
	_text(Vector2(COLS - _cells(name), row), name, Palette.TEXT)


func _pips(at: Vector2, n: int, of: int, color: Color) -> void:
	for i in mini(of, 6):
		_glyph(at + Vector2(i, 0), "■" if i < n else "□", color if i < n else Palette.DIM)
	if of > 6:
		_small(at + Vector2(6, 0.3), str(n), color)


## Cells a string takes: Hangul is two halves wide, ASCII one half.
func _cells(s: String) -> float:
	var n := 0.0
	for c in s:
		n += 1.0 if c.unicode_at(0) > 0x7E else 0.5
	return n


## A line of text at the font's doubled grid, Hangul a cell wide and ASCII half.
func _text(at: Vector2, s: String, color: Color) -> void:
	var y := at.y * CELL.y + (CELL.y - SIZE) / 2.0 + SIZE * 0.75
	draw_string(
		_font, Vector2(at.x * CELL.x, y).round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, color
	)


## One glyph centred in the cell at `cell` (in cells, may be fractional).
## Half-width glyphs are drawn at three times the font's pixel grid and
## Hangul at twice, so both fill a cell and keep square pixels.
func _glyph(cell: Vector2, c: String, color: Color) -> void:
	if c == "":
		return
	var px := BIG if c.unicode_at(0) < 0x1100 else SIZE
	var w := _font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := cell * CELL + Vector2((CELL.x - w) / 2.0, (CELL.y - px) / 2.0 + px * 0.75)
	draw_string(_font, at.round(), c, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


func _small(cell: Vector2, s: String, color: Color) -> void:
	var at := cell * CELL + Vector2(0, SMALL * 0.75)
	draw_string(_font, at.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, color)
