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
## The world is on screen as it stands, after a round or a change.
signal settled(w: World)
## The full-screen list changed or closed (empty).
signal panel_set(shown: Dictionary)

const CELL := Vector2(32, 40)
const MAP := Vector2i(8, 0)
## Screen rows each creature takes in the sidebar, and its state there.
const SIDE_ROWS := 3
const SIZE := 32
const BIG := 48
const SMALL := 16
## Pixels between the lines of wisps chasing one creature.
const LINE_GAP := 5.0
## Cells each character takes, measured once (text_cells).
static var _widths := {}

var world: World
var picked: Array[StringName] = []
var staged: Array[Dictionary] = []
## Set by the game: tile -> Color tints, and tile -> [text, Color] marks.
var tints := {}
var marks := {}
## Set by the game: lines [from tile, to tile, Color, k], one per wisp to its
## creature; the k-th line to one creature is drawn k * LINE_GAP to the side.
var lines: Array = []
var replay := false
## The tile under the pointer and what it shows there, as Info lines.
var cursor := Vector2i(-1, -1)
## Set by the game: the tiles in travel exclusions (tile -> true), their centres (tile -> radius).
var zone := {}
var zone_centres := {}
var info: Array = []:
	set(v):
		info = Keywords.lines(v)
		pin = {}
## Set by the game: the spell the box of `info` is about, as a scene (SpellScene.of), or empty.
## Its example plays in the box, in a world that lives as long as the box does.
var example := {}:
	set(v):
		if v != example:
			example = v
			sim = ExampleSim.swap(self, sim, example)
## Set by the game with `info`: the name of the 도감 entry it tells of, or empty
## when it has none (Preview.subject); the describe key opens it.
var subject := ""
## Set by the game: the 도감 entry (WordHover) of the word the pointer is over in
## a panel, the log or a kept box, and the cell the pointer is in, which the box is
## drawn under.
var hint: Array = []:
	set(v):
		hint = Keywords.lines(v)
var hint_at := Vector2.ZERO
## The box Shift keeps where it is (WordHover.hold): {lines, fit, word} of the hover
## box that was open (`word` its `subject`), drawn as it was and read for its words.
## A new `info` or `panel` ends it.
var pin := {}
## Set by the game: the debug view (DebugView.view) while it is on, else empty.
## It shows every tile, creature and goal as if Miho knew them.
var debug := {}
## Set by the game: the tiles of Miho's scent trail to tint, with their freshness (Scent.fresh).
var scent := {}
var speed := 1.0
## Saved spells (Settings.spells), listed on the status row by their slot keys.
var saved := {}
var banner_lines: Array[String] = []
## Recent message lines over the top map rows, oldest first: [text, alpha].
var log_lines: Array = []
## A full-screen list over everything, or empty: {title, rows, selected, top,
## hover}, each row a list of [text, Color] runs, a run optionally starting at a
## given column ([text, Color, x]); `top` is the first row shown, `selected` and
## `hover` (-1 for none) the rows lit.
var panel := {}:
	set(v):
		panel = Keywords.panel(v)
		hint = []
		pin = {}
		panel_set.emit(panel)
var cols := 40
var rows := 18
## The map tile drawn at the map area's top-left; negative centres a small map.
var cam := Vector2i.ZERO
## Set by the touch screen: the camera keeps Miho in the middle of the map area as
## far as the map's edges allow, instead of only keeping her off the area's edges.
var centred := false
## How far the loudest noise Miho saw in the last round was heard, in tiles (NoiseMeter).
var noise := 0
## The cells the sidebar takes, which is also where the map area starts, and the rows
## under the map for status (a touch screen has neither, TouchHud holds its status).
var side := MAP
var foot := 2
## What draws and finds the status rows: StatusBar or a TouchHud.
var bar: Variant = StatusBar
## The smallest a cell may shrink to in the info box, in screen units.
var readable := InfoBox.READABLE * CELL.x

var sim: ExampleSim = null
var still := false
## The round playing and what it leaves on screen.
var anim := RoundAnim.new(self)
## The tiles, the light on them and what stands there.
var layer := MapLayer.new(self)
var font: FontFile
## What Miho sees now, one byte a tile (World.seen).
var vis := PackedByteArray()
## Ids of the creatures under a hat (Hat) that are not drawn, though their tile is.
var veiled := {}
## The clock of what fades (popups, flashes, afterimages).
var time := 0.0
## The clock of what only sways (flames, an aim's pulse, bubbles); `still` stops it for pictures.
var sway := 0.0
## The time (`time`) the map began to shake.
var shook := -INF
## The hold `play` waits on.
var _hold: SceneTreeTimer
## Set by `rush` until the next `play`: the round in progress holds no more.
var _rushed := false
var _bubbles := Bubbles.new()


func _ready() -> void:
	font = Fonts.pixel()
	size = Vector2(cols, rows) * CELL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(RedrawPace.new(self))


## Fills `view` (in the parent's space) with cells at `zoom` times their size,
## or, at zoom 0, at the size that shows the whole map with sidebar and status rows.
func fit(view: Vector2, zoom: float, origin := Vector2.ZERO) -> void:
	var k := zoom
	if k <= 0.0:
		var whole := Vector2(MAP.x + Grid.W, Grid.H + 2) * CELL
		k = minf(view.x / whole.x, view.y / whole.y)
	cols = maxi(side.x + 1, floori(view.x / (CELL.x * k)))
	rows = maxi(4, floori(view.y / (CELL.y * k)))
	size = Vector2(cols, rows) * CELL
	scale = Vector2(k, k)
	position = origin + ((view - size * k) / 2.0).round()
	if world != null:
		follow(world.player().pos)


## Map tiles the map area holds across and down.
func map_view() -> Vector2i:
	return Vector2i(cols - side.x, rows - foot)


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
		if centred:
			cam[axis] = p[axis] - v[axis] / 2
		else:
			cam[axis] = clampi(cam[axis], p[axis] - v[axis] + 1 + margin, p[axis] - margin)
		cam[axis] = clampi(cam[axis], 0, grid[axis] - v[axis])


## Moves the camera by `by` tiles, never past the map (a drag on the touch screen).
func pan(by: Vector2i) -> void:
	var v := map_view()
	var grid := Vector2i(Grid.W, Grid.H)
	for axis in 2:
		if grid[axis] > v[axis]:
			cam[axis] = clampi(cam[axis] + by[axis], 0, grid[axis] - v[axis])


## The part of this node's space where map tiles are drawn.
func map_rect() -> Rect2:
	var from := Vector2(side) + Vector2(maxi(0, -cam.x), maxi(0, -cam.y))
	var v := map_view()
	var to := Vector2(side) + Vector2(mini(v.x, Grid.W - cam.x), mini(v.y, Grid.H - cam.y))
	return Rect2(from * CELL, (to - from) * CELL)


## The screen cell of map tile p.
func cell_of(p: Vector2i) -> Vector2:
	return Vector2(side + p - cam)


## Whether map tile p is inside the map area.
func in_view(p: Vector2i) -> bool:
	var c := p - cam
	var v := map_view()
	return c.x >= 0 and c.y >= 0 and c.x < v.x and c.y < v.y


func _process(delta: float) -> void:
	time += delta
	var swayed := 0.0 if still else delta
	sway += swayed
	anim.expire(time)
	anim.popups.append_array(_bubbles.rise(world, swayed, time))


## Starts the map shaking; pictures (`still`) do not shake.
func shake() -> void:
	if not still:
		shook = time


## Whether the map is shaking now.
func shaking() -> bool:
	return time - shook < Shake.LIFE


## Shows the world as it is now, with nothing in flight.
func show_world(w: World) -> void:
	world = w
	vis = w.seen
	veiled = Hat.unseen(w)
	follow(w.player().pos)
	anim.settle(w)
	layer.light_up(w)
	queue_redraw()
	settled.emit(w)


## Animates one round from `before` to `after`, then shows `after`.
func play(events: Array, before: World, after: World) -> void:
	world = after
	_rushed = false
	var perceived := Perceived.of(before, after, events)
	vis = perceived.vis
	veiled = perceived.veiled
	await anim.run(events, before, perceived.facts)
	noise = NoiseMeter.level(vis, events)
	if not replay:
		for p in Perceived.spotted(before, after):
			shown.emit({t = &"spot", at = p}, cell_centre(p))
	show_world(after)


## Waits `wait` seconds of the round in progress, none once it is rushed.
func hold(wait: float) -> void:
	if wait > 0.0 and not _rushed:
		_hold = get_tree().create_timer(wait / speed)
		await _hold.timeout


## Finishes the round in progress at once: `play` returns before this does, so
## the key that asked acts on the finished round. Popups and sounds still play.
func rush() -> void:
	_rushed = true
	if _hold != null:
		_hold.timeout.emit()


## Whether Miho sees tile p: what the log and the popups are told from.
func sees(p: Vector2i) -> bool:
	return Perceived.sees(vis, p)


## Whether `a` wears a hat that hides it now; the debug view sees through it.
func hatted(a: Actor) -> bool:
	return debug.is_empty() and veiled.has(a.id)


## Whether tile p is drawn: seen, or any tile with the debug view on.
func revealed(p: Vector2i) -> bool:
	return Grid.inside(p) and (not debug.is_empty() or vis[Grid.index(p)] == 1)


## Screen position of the centre of map tile p, in this node's space.
func cell_centre(p: Vector2i) -> Vector2:
	return (cell_of(p) + Vector2(0.5, 0.5)) * CELL


## The map tile under a point in this node's space, or (-1, -1).
func tile_at(local: Vector2) -> Vector2i:
	var c := Vector2i((local / CELL).floor()) - side + cam
	return c if Grid.inside(c) and in_view(c) else Vector2i(-1, -1)


## Where the creature listed in the sidebar (or the touch strip) under a point stands, or (-1, -1).
func side_at(local: Vector2) -> Vector2i:
	var c := Vector2i((local / CELL).floor())
	if world != null and bar is TouchHud:
		var at: Vector2i = bar.creature_at(self, local)
		if at.x >= 0:
			return at
	if world == null or c.x < 0 or c.x >= side.x or c.y < 0 or c.y >= rows - foot:
		return Vector2i(-1, -1)
	var list := side_list(world_actors(), world.player().pos)
	return list[c.y / SIDE_ROWS].pos if c.y / SIDE_ROWS < list.size() else Vector2i(-1, -1)


## The creature cards on the screen, as [creature, cell of the card, cells wide].
func side_cards() -> Array:
	if world == null:
		return []
	if bar is TouchHud:
		return bar.side_cards(self)
	if side.x <= 0:
		return []
	var list := side_list(world_actors(), world.player().pos)
	return range(list.size()).map(func(k): return [list[k], Vector2(0, k * SIDE_ROWS), MAP.x])


func _world_shots() -> Dictionary:
	var out := {}
	for s in world.shots:
		out[s.id] = {pos = s.pos, spell = s.spell, faction = s.faction}
	return out


## The living creatures of the world, id -> Actor.
func world_actors() -> Dictionary:
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
	# An opaque panel covers the whole game, but for a touch HUD out beside it.
	if not panel.get("opaque", false):
		_draw_game()
	elif bar is TouchHud and not replay:
		bar.draw(self)
	if not panel.is_empty():
		PanelView.draw(self)
	if not pin.is_empty():
		_draw_box(pin.fit)
	if not hint.is_empty():
		_draw_box(hint_fit())


func _draw_game() -> void:
	# Only the map shakes: the sidebar, the log and the status rows are drawn after it is put back.
	draw_set_transform(Shake.offset(time - shook))
	var shots := anim.shots if anim.playing else _world_shots()
	var light := layer.field(shots)
	var actors := anim.actors if anim.playing else world_actors()
	var me := world.player()
	var me_pos: Vector2i = actors[me.id].pos if actors.has(me.id) else me.pos
	layer.draw_tiles(light, me_pos)
	TermMarks.telegraphs(self, actors)
	if not replay:
		TermMarks.scent(self)
	if not anim.playing:
		TermMarks.paths(self)
		for l: Array in lines:
			if in_view(l[0]) and in_view(l[1]):
				var a := cell_centre(l[0])
				var b := cell_centre(l[1])
				var side: Vector2 = (b - a).orthogonal().normalized() * LINE_GAP * l[3]
				draw_line(a + side, b + side, l[2], 2.0)
		DebugView.draw(self)
	layer.draw_things(light, actors, shots)
	anim.draw()
	draw_set_transform(Vector2.ZERO)
	if not replay:
		if side.x > 0:
			_draw_side(actors, me_pos)
		bar.draw(self)
		if banner_lines.is_empty():
			_draw_log()
		_draw_info()
	if panel.is_empty() and not banner_lines.is_empty():
		Banner.draw(self)


## The creatures of `actors` the sidebar lists, nearest to `me_pos` first, as many as fit
## or `limit`.
func side_list(actors: Dictionary, me_pos: Vector2i, limit := -1) -> Array:
	var list: Array = actors.values().filter(
		func(a): return not a.is_miho() and revealed(a.pos) and not hatted(a)
	)
	list.sort_custom(func(a, b): return Grid.cheb(a.pos, me_pos) < Grid.cheb(b.pos, me_pos))
	return list.slice(0, (rows - foot) / SIDE_ROWS if limit < 0 else limit)


## Creatures in sight, nearest first, as Brogue lists them (CreatureCard).
func _draw_side(actors: Dictionary, me_pos: Vector2i) -> void:
	var list := side_list(actors, me_pos)
	for k in list.size():
		CreatureCard.draw(self, list[k], Vector2(0, k * SIDE_ROWS), MAP.x)


## A frame on the tile under the pointer, and what is there in a box on the
## far side of the map from it.
func _draw_info() -> void:
	var shown := Grid.inside(cursor) and in_view(cursor)
	if shown:
		var r := Rect2(cell_of(cursor) * CELL, CELL)
		draw_rect(r.grow(-1), Color(Palette.TEXT, 0.7), false, 2.0)
	if not info.is_empty() and pin.is_empty():
		var fit := info_fit()
		_draw_box(fit)
		ExampleSim.place(sim, fit)


## A box laid out as `fit` says (InfoBox).
func _draw_box(fit: Dictionary) -> void:
	draw_set_transform(fit.at * CELL, 0.0, Vector2(fit.scale, fit.scale))
	var box := Rect2(Vector2.ZERO, fit.cells * CELL)
	draw_rect(box, Palette.VOID)
	draw_rect(box.grow(-1), Palette.DIM, false, 2.0)
	for column: Array in fit.columns:
		for k in column[1].size():
			var x: float = column[0]
			for run: Array in column[1][k]:
				x += draw_run(Vector2(x, k), run)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The layout of `lines` (InfoBox) and `at`, the cell of its top-left corner. It
## lies in the map area, or in the whole width when that would make the text
## too small to read, on the far side from the map tile `p` (null for none). With
## `extra` cells for the example (`example` of the layout); none when they do not fit.
func fit_far_from(p: Variant = null, lines: Array = info, extra := Vector2.ZERO) -> Dictionary:
	var laid := info_layout(lines, extra)
	return info_at(laid.fit, laid.room, p)


## The layout of `lines` and the room it lies in, under the log rows shown over the map
## (as Brogue lays its detail box under the message lines), as far as they leave half the
## map area; where it sits is `info_at`.
func info_layout(lines: Array, extra := Vector2.ZERO) -> Dictionary:
	var v := map_view()
	var top := mini(log_height(), v.y / 2)
	var room := Rect2(Vector2(side.x, side.y + top), Vector2(v.x, v.y - top))
	var least := minf(1.0, readable / (CELL.x * scale.x))
	var fit := InfoBox.layout(lines, room.size, least, extra)
	if fit.get("scale", 0.0) < least:
		room = Rect2(Vector2(0, top), Vector2(cols, v.y - top))
		fit = InfoBox.layout(lines, room.size, least, extra)
		if fit.get("scale", 0.0) < least and extra != Vector2.ZERO:
			return info_layout(lines)
	return {fit = fit, room = room}


## `fit` with `at`, its top-left cell in `room`, on the far side from the map tile `p`.
func info_at(fit: Dictionary, room: Rect2, p: Variant) -> Dictionary:
	var v := map_view()
	var wide: Vector2 = fit.cells * fit.scale
	var at := Vector2(room.position.x, room.end.y - wide.y)
	if p != null:
		var c: Vector2i = p - cam
		at.x = room.end.x - wide.x if c.x < v.x / 2 else room.position.x
		at.y = room.end.y - wide.y if c.y < v.y / 2 else room.position.y
	return fit.merged({at = at})


## The layout of `info`: on the far side of the map from the tile under the pointer.
func info_fit() -> Dictionary:
	var extra := Vector2(CodexScene.VIEW) if sim != null else Vector2.ZERO
	return fit_far_from(cursor if Grid.inside(cursor) and in_view(cursor) else null, info, extra)


## The layout of the hint under the cell the pointer is in, inside the screen.
func hint_fit() -> Dictionary:
	var room := Rect2(0, 0, cols, rows if not panel.is_empty() else rows - foot)
	return InfoBox.beside(hint, room, Vector2i(hint_at), minf(1.0, readable / (CELL.x * scale.x)))


## The rows the log takes over the map now.
func log_height() -> int:
	return log_rows().size() if banner_lines.is_empty() and not replay else 0


func _draw_log() -> void:
	for r: Array in log_rows():
		var width: float = r[2].reduce(func(n, run): return n + text_cells(run[0]), 0.0)
		var box := Rect2(Vector2(side.x, r[0]) * CELL, Vector2(width + 1.0, 1) * CELL)
		draw_rect(box, Color(Palette.VOID, 0.7 * r[3]))
		var x: float = r[1]
		for run: Array in r[2]:
			x += draw_run(Vector2(x, r[0]), run, r[3])


## The log as it is drawn, [screen row, column of the first run, runs, alpha] for
## each row; the pointer's word hover (WordHover) reads the same rows.
func log_rows() -> Array:
	var out := []
	for line: Array in log_lines:
		for runs: Array in Keywords.rows_of(line[0], cols - side.x - 1.0):
			out.append([out.size(), side.x + 0.5, runs, line[1]])
	return out


## A run at `at`, on its background if it has one, faded to `alpha`; the cells it takes.
func draw_run(at: Vector2, run: Array, alpha := 1.0) -> float:
	if run.slice(2).has(&"key"):
		draw_key(at, run[0], Color(run[1], run[1].a * alpha))
		return key_cells(run[0])
	var width := text_cells(run[0])
	var back := Keywords.back(run)
	if back.a > 0.0:
		draw_rect(Rect2(at * CELL, Vector2(width, 1) * CELL), Color(back, back.a * alpha))
	draw_text(at, run[0], Color(run[1], run[1].a * alpha))
	return width


## Health as hearts, at most `room` of them; more health is written as a number.
func draw_pips(at: Vector2, n: int, of: int, color: Color, room := 6) -> void:
	if of > room:
		_heart(at, true, color)
		draw_text(at + Vector2(1, 0), "%d/%d" % [n, of], color)
		return
	for i in of:
		_heart(at + Vector2(i, 0), i < n, color if i < n else Palette.DIM)


## A pixel heart filling cell `at`, full or as an outline.
func _heart(at: Vector2, full: bool, color: Color) -> void:
	Heart.draw(self, at, full, color)


## Cells a string takes as the font draws it, each character rounded up to a
## half (× and ° a half, Hangul a whole); ♥ and ♡ are drawn as hearts a cell wide, ■ and □
## as the segments of a bar (NoiseMeter.segment) half a cell wide.
static func text_cells(s: String) -> float:
	var n := 0.0
	for c in s:
		if not _widths.has(c):
			var px := Fonts.pixel().get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
			_widths[c] = (
				1.0
				if c in ["♥", "♡"]
				else 0.5 if c in ["■", "□"] else maxf(0.5, ceilf(px / CELL.x * 2.0) / 2.0)
			)
		n += _widths[c]
	return n


## A line of text at the font's doubled grid, Hangul a cell wide and ASCII
## half; ♥ and ♡ are drawn as pixel hearts a cell wide, ■ and □ as bar segments.
func draw_text(at: Vector2, s: String, color: Color) -> void:
	var x := at.x
	for part in _hearts_split(Lang.singular(s)):
		if part == "♥" or part == "♡":
			_heart(
				Vector2(x, at.y), part == "♥", color if part == "♥" else Color(Palette.DIM, color.a)
			)
		elif part == "■" or part == "□":
			NoiseMeter.segment(
				self, Vector2(x, at.y), color if part == "■" else Color(Palette.DIM, color.a)
			)
		else:
			var y := at.y * CELL.y + (CELL.y - SIZE) / 2.0 + SIZE * 0.75
			draw_string(
				font,
				Vector2(x * CELL.x, y).round(),
				part,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				SIZE,
				color
			)
		x += text_cells(part)


## Text cut into runs of plain text and single hearts or bar segments.
static func _hearts_split(s: String) -> Array[String]:
	var out: Array[String] = []
	var run := ""
	for c in s:
		if c in ["♥", "♡", "■", "□"]:
			if run != "":
				out.append(run)
			out.append(c)
			run = ""
		else:
			run += c
	if run != "":
		out.append(run)
	return out


## One glyph centred in the cell at `cell` (in cells, may be fractional).
## Half-width glyphs are drawn at three times the font's pixel grid and
## Hangul at twice, so both fill a cell and keep square pixels.
func draw_glyph(cell: Vector2, c: String, color: Color) -> void:
	if c == "":
		return
	var px := BIG if c.unicode_at(0) < 0x1100 else SIZE
	var w := font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := cell * CELL + Vector2((CELL.x - w) / 2.0, (CELL.y - px) / 2.0 + px * 0.75)
	draw_string(font, at.round(), c, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


## A shortcut's label at the top of `cell`, small beside what it stands for.
func draw_key(cell: Vector2, s: String, color := Palette.KEY) -> void:
	draw_small(cell + Vector2(0, 0.05), s, color)


## The cells a shortcut's label takes, at the font's doubled grid.
static func key_cells(s: String) -> float:
	var px := Fonts.pixel().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x
	return ceilf(px / CELL.x * 2.0) / 2.0


## Text at the font's own size, at the top of `cell`.
func draw_small(cell: Vector2, s: String, color: Color) -> void:
	var at := cell * CELL + Vector2(0, SMALL * 0.75)
	draw_string(font, at.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, color)


## The marks of what holds `a`, small at `cell`: its status (Status.of), then
## rooted and stunned.
func draw_status(cell: Vector2, a: Actor) -> void:
	var held: Array = Palette.CONDITION.keys().filter(func(k): return a.ailments.get(k) > 0)
	var marks: Array = held.map(func(k): return Palette.CONDITION[k])
	if Palette.STATUS.has(Status.of(a)):
		marks.push_front(Palette.STATUS[Status.of(a)])
	for i in marks.size():
		draw_small(cell + Vector2(i * 0.33, 0), marks[i][0], marks[i][1])
