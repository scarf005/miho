class_name Term
extends Control
## The screen as a Brogue-style terminal of `cols` x `rows` cells in one pixel
## font, as many as fit the window at the chosen zoom. Columns 0-7 list the
## creatures Miho sees, the map fills the rest, and the two bottom rows hold
## her health, tails, storey, time and talismans. When the map is larger than
## its area, a camera shows the part around Miho. Every tile takes the colour
## of the light on it, lantern light flickers, and tiles out of sight are
## drawn from memory in dim blue. `play` animates a round's events one by one,
## carrying each projectile's light with it.

signal shown(e: Dictionary, at: Vector2)

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
## The tile under the pointer and what it shows there, as Info lines.
var cursor := Vector2i(-1, -1)
var info: Array = []
var speed := 1.0
var banner_lines: Array[String] = []
## Recent message lines over the top map rows, oldest first: [text, alpha].
var log_lines: Array = []
## A full-screen list over everything, or empty: {title, rows, selected}, each
## row a list of [text, Color] runs, a run optionally starting at a given
## column ([text, Color, x]); the selected row (-1 for none) is kept in view,
## and with none the last rows are.
var panel := {}
var cols := 40
var rows := 18
## The map tile drawn at the map area's top-left; negative centres a small map.
var cam := Vector2i.ZERO

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
	size = Vector2(cols, rows) * CELL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fills `view` (in the parent's space) with cells at `zoom` times their size,
## or, at zoom 0, at the size that shows the whole map with sidebar and status rows.
func fit(view: Vector2, zoom: float) -> void:
	var k := zoom
	if k <= 0.0:
		var whole := Vector2(MAP.x + Grid.W, Grid.H + 2) * CELL
		k = minf(view.x / whole.x, view.y / whole.y)
	cols = maxi(MAP.x + 1, floori(view.x / (CELL.x * k)))
	rows = maxi(4, floori(view.y / (CELL.y * k)))
	size = Vector2(cols, rows) * CELL
	scale = Vector2(k, k)
	position = ((view - size * k) / 2.0).round()
	if world != null:
		follow(world.player().pos)


## Map tiles the map area holds across and down.
func map_view() -> Vector2i:
	return Vector2i(cols - MAP.x, rows - 2)


## Moves the camera only as far as needed to keep p a few tiles from the map
## area's edges, never past the map; a map smaller than its area sits centred.
func follow(p: Vector2i) -> void:
	var v := map_view()
	var grid := Vector2i(Grid.W, Grid.H)
	for axis in 2:
		if grid[axis] <= v[axis]:
			cam[axis] = -(v[axis] - grid[axis]) / 2
			continue
		var margin := mini(6, v[axis] / 4)
		cam[axis] = clampi(cam[axis], p[axis] - v[axis] + 1 + margin, p[axis] - margin)
		cam[axis] = clampi(cam[axis], 0, grid[axis] - v[axis])


## The part of this node's space where map tiles are drawn.
func map_rect() -> Rect2:
	var from := Vector2(MAP) + Vector2(maxi(0, -cam.x), maxi(0, -cam.y))
	var v := map_view()
	var to := Vector2(MAP) + Vector2(mini(v.x, Grid.W - cam.x), mini(v.y, Grid.H - cam.y))
	return Rect2(from * CELL, (to - from) * CELL)


## The screen cell of map tile p, and whether it is inside the map area.
func _cell(p: Vector2i) -> Vector2:
	return Vector2(MAP + p - cam)


func _shown(p: Vector2i) -> bool:
	var c := p - cam
	var v := map_view()
	return c.x >= 0 and c.y >= 0 and c.x < v.x and c.y < v.y


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
	follow(w.player().pos)
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
	return (_cell(p) + Vector2(0.5, 0.5)) * CELL


## The map tile under a point in this node's space, or (-1, -1).
func tile_at(local: Vector2) -> Vector2i:
	var c := Vector2i((local / CELL).floor()) - MAP + cam
	return c if Grid.inside(c) and _shown(c) else Vector2i(-1, -1)


## Where the creature listed in the sidebar under a point stands, or (-1, -1).
func side_at(local: Vector2) -> Vector2i:
	var c := Vector2i((local / CELL).floor())
	if world == null or c.x < 0 or c.x >= MAP.x or c.y < 0 or c.y >= rows - 2:
		return Vector2i(-1, -1)
	var list := _side_list(_world_actors(), world.player().pos)
	return list[c.y / 2].pos if c.y / 2 < list.size() else Vector2i(-1, -1)


## Whether a point in this node's space is on Miho's health and tails row.
func status_at(local: Vector2) -> bool:
	return floori(local.y / CELL.y) == rows - 2


## The talisman under a point in this node's space, or empty.
func card_at(local: Vector2) -> StringName:
	var c := Vector2i((local / CELL).floor())
	if c.y != rows - 1 or world == null:
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
		if not _shown(f.at):
			continue
		var k: float = 1.0 - (_time - f.born) / 0.35
		var c: Color = f.color
		draw_rect(Rect2(_cell(f.at) * CELL, CELL), Color(c, c.a * k))
	for p in _popups:
		if not _shown(p.at):
			continue
		var k: float = (_time - p.born) / p.life
		var c: Color = p.color
		var at := _cell(p.at) + Vector2(0, -0.6 * k)
		if p.text.length() == 1:
			_glyph(at, p.text, Color(c, 1.0 - k * k))
		else:
			_text(at, p.text, Color(c, 1.0 - k * k))
	if not replay:
		_draw_side(actors, me_pos)
		_draw_bottom()
		_draw_log()
		_draw_info()
	var v := map_view()
	if not banner_lines.is_empty():
		draw_rect(Rect2(Vector2.ZERO, Vector2(cols, v.y) * CELL), Color(0, 0, 0, 0.8))
	var top := maxi(0, (v.y - banner_lines.size() * 2) / 2)
	for i in banner_lines.size():
		var line := banner_lines[i]
		var color: Color = Palette.KIND[&"miho"] if i == 0 else Palette.TEXT
		var w := _cells(line)
		var x := clampf(MAP.x + (v.x - w) / 2.0, 0.0, maxf(0.0, cols - w))
		_text(Vector2(x, top + i * 2), line, color)
	if not panel.is_empty():
		_draw_panel()


func _draw_map(light: PackedVector3Array, me_pos: Vector2i) -> void:
	for i in world.tiles.size():
		var p := Grid.at(i)
		if world.known[i] == 0 and _vis[i] == 0 or not _shown(p):
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
		var cell := _cell(p)
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
			if not _shown(ray[k]):
				continue
			var pulse := 0.5 + 0.5 * sin(_time * 8.0 - k * 0.6)
			var c := Color(Palette.SIDE[1], 0.16 + 0.14 * pulse)
			draw_rect(Rect2(_cell(ray[k]) * CELL, CELL), c)
			if k == 0:
				_glyph(_cell(ray[k]), Palette.BOLT[a.aim], Palette.SIDE[1])


func _draw_things(light: PackedVector3Array, actors: Dictionary) -> void:
	var shots := _shots if _animating else _world_shots()
	for id in shots:
		var s: Dictionary = shots[id]
		if _visible(s.pos) and _shown(s.pos):
			_glyph(
				_cell(s.pos), Palette.shot_glyph(s.spell), Palette.shot_color(s.spell, s.faction)
			)
	for id in actors:
		var a: Actor = actors[id]
		if a.faction != Actor.FOX and not _visible(a.pos) or not _shown(a.pos):
			continue
		var cell := _cell(a.pos)
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
		if _shown(p):
			_small(_cell(p) + Vector2(0.62, 0.55), m[0], m[1])


func _side_list(actors: Dictionary, me_pos: Vector2i) -> Array:
	var list: Array = actors.values().filter(
		func(a): return a.faction != Actor.FOX and _visible(a.pos)
	)
	list.sort_custom(func(a, b): return Grid.cheb(a.pos, me_pos) < Grid.cheb(b.pos, me_pos))
	return list.slice(0, (rows - 2) / 2)


## Creatures in sight, nearest first: glyph and health, then state and the spell it charges.
func _draw_side(actors: Dictionary, me_pos: Vector2i) -> void:
	var list := _side_list(actors, me_pos)
	for k in list.size():
		var a: Actor = list[k]
		var row := k * 2
		if a.pos == cursor:
			draw_rect(
				Rect2(Vector2(0, row) * CELL, Vector2(MAP.x, 2) * CELL), Color(Palette.TEXT, 0.12)
			)
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
	var row := rows - 2
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
	_text(Vector2(cols - _cells(right), row), right, Palette.TEXT)
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
	_text(Vector2(cols - _cells(name), row), name, Palette.TEXT)


## A frame on the tile under the pointer, and what is there in a box on the
## far side of the map from it.
func _draw_info() -> void:
	var shown := Grid.inside(cursor) and _shown(cursor)
	if shown:
		var r := Rect2(_cell(cursor) * CELL, CELL)
		draw_rect(r.grow(-1), Color(Palette.TEXT, 0.7), false, 2.0)
	if info.is_empty():
		return
	var width := 0.0
	for line: Array in info:
		width = maxf(width, line.reduce(func(n, run): return n + _cells(run[0]), 0.0))
	width = ceilf(width) + 1.0
	var height := info.size()
	var v := map_view()
	var from := Vector2(MAP.x, rows - 2 - height)
	if shown:
		var at := cursor - cam
		from.x = MAP.x + v.x - width if at.x < v.x / 2 else MAP.x
		from.y = v.y - height if at.y < v.y / 2 else 0
	var box := Rect2(from * CELL, Vector2(width, height) * CELL)
	draw_rect(box, Color(Palette.VOID, 0.92))
	draw_rect(box.grow(-1), Palette.DIM, false, 2.0)
	for k in info.size():
		var x := from.x + 0.5
		for run: Array in info[k]:
			_text(Vector2(x, from.y + k), run[0], run[1])
			x += _cells(run[0])


func _draw_log() -> void:
	for k in log_lines.size():
		var text: String = log_lines[k][0]
		var alpha: float = log_lines[k][1]
		var box := Rect2(Vector2(MAP.x, k) * CELL, Vector2(_cells(text) + 1.0, 1) * CELL)
		draw_rect(box, Color(Palette.VOID, 0.7 * alpha))
		_text(Vector2(MAP.x + 0.5, k), text, Color(Palette.TEXT, alpha))


## Rows of the panel that fit, and the first one shown.
func _panel_span() -> Vector2i:
	var fits := maxi(1, rows - 4)
	var count: int = panel.rows.size()
	var selected: int = panel.get("selected", -1)
	var first := count - fits if selected < 0 else selected - fits / 2
	return Vector2i(clampi(first, 0, maxi(0, count - fits)), fits)


func _draw_panel() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.VOID, 0.92))
	_text(Vector2(2, 1), panel.title, Palette.KIND[&"miho"])
	var span := _panel_span()
	for k in range(span.x, mini(span.x + span.y, panel.rows.size())):
		var y := 3 + k - span.x
		if k == panel.get("selected", -1):
			draw_rect(
				Rect2(Vector2(1, y) * CELL, Vector2(cols - 2, 1) * CELL), Color(Palette.TEXT, 0.15)
			)
		var x := 2.0
		for run: Array in panel.rows[k]:
			x = run[2] if run.size() > 2 else x
			_text(Vector2(x, y), run[0], run[1])
			x += _cells(run[0])


## The panel row under a point in this node's space, or -1.
func panel_row_at(local: Vector2) -> int:
	if panel.is_empty():
		return -1
	var span := _panel_span()
	var k := floori(local.y / CELL.y) - 3 + span.x
	return k if k >= span.x and k < mini(span.x + span.y, panel.rows.size()) else -1


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
