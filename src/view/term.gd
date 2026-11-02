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
## Cells a popup starts above its tile, so the creature it is about stays in view.
const POPUP_ABOVE := 0.6
## Tiles of tail drawn behind a projectile.
const TRAIL := 4
const SIZE := 32
const BIG := 48
const SMALL := 16
## Pixels between the lines of wisps chasing one creature.
const LINE_GAP := 5.0
const DELAY := {
	&"move": 0.05,
	&"spawn": 0.04,
	&"fly": 0.03,
	&"land": 0.05,
	&"hit": 0.1,
	&"burst": 0.1,
	&"splash": 0.22,
	&"blast": 0.25,
	&"spray": 0.25,
	&"clash": 0.1,
	&"claw": 0.16,
	&"melee": 0.16,
	&"die": 0.14,
	&"sprout": 0.16,
	&"charge": 0.08,
	&"drum": 0.3,
	&"trap": 0.2,
}
## Cells each character takes, measured once (_cells).
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
## Set by the game: the tiles in travel exclusions (tile -> true).
var zone := {}
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
## Set by the game: the 도감 entry (WordHover) of the word the pointer is over in
## a panel, the log or a kept box, and the cell the pointer is in, which the box is
## drawn under.
var hint: Array = []:
	set(v):
		hint = Keywords.lines(v)
var hint_at := Vector2.ZERO
## The box Shift keeps where it is (WordHover.hold): {lines, fit} of the hover box
## that was open, drawn as it was and read for its words. A new `info` or `panel`
## ends it.
var pin := {}
## Set by the game: the debug view (DebugView.view) while it is on, else empty.
## It shows every tile, creature and goal as if Miho knew them.
var debug := {}
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
var _font: FontFile
## The hold `play` waits on.
var _hold: SceneTreeTimer
## Set by `rush` until the next `play`: the round in progress holds no more.
var _rushed := false
var _vis := PackedByteArray()
## Ids of the creatures under a hat (Hat) that are not drawn, though their tile is.
var _veiled := {}
var _actors := {}
var _shots := {}
var _animating := false
var _popups: Array[Dictionary] = []
## event index -> the Perceived fact of the round being played.
var _told := {}
var _flashes: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []
var _lanterns: Array[Dictionary] = []
var _shot_light := {}
## shot id -> the tiles it last flew through, newest last (TRAIL of them).
var _trails := {}
var _time := 0.0


func _ready() -> void:
	_font = Fonts.pixel()
	size = Vector2(cols, rows) * CELL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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


## The screen cell of map tile p, and whether it is inside the map area.
func _cell(p: Vector2i) -> Vector2:
	return Vector2(side + p - cam)


func _shown(p: Vector2i) -> bool:
	var c := p - cam
	var v := map_view()
	return c.x >= 0 and c.y >= 0 and c.x < v.x and c.y < v.y


func _process(delta: float) -> void:
	_time += delta
	var now := _time
	_popups = _popups.filter(func(p): return now - p.born < p.life)
	_flashes = _flashes.filter(func(f): return now - f.born < 0.35)
	_ghosts.assign(_ghosts.filter(func(g): return now - g.born < Afterimage.LIFE))
	queue_redraw()


## Shows the world as it is now, with nothing in flight.
func show_world(w: World) -> void:
	world = w
	_vis = w.seen
	_veiled = Hat.unseen(w)
	follow(w.player().pos)
	_actors.clear()
	_shots.clear()
	_animating = false
	for id in _trails.keys():
		if not w.shots.any(func(s): return s.id == id and s.dir != Vector2i.ZERO):
			_trails.erase(id)
	_lanterns.clear()
	for i in w.tiles.size():
		var p := Grid.at(i)
		if w.tiles[i] == World.LANTERN:
			_lanterns.append(_flame(w, p, Light.LANTERN_RADIUS, Light.LANTERN, false))
		if Light.GLOW.has(w.tiles[i]):
			var glow: Dictionary = Light.GLOW[w.tiles[i]]
			_lanterns.append(_flame(w, p, glow.radius, glow.color, false))
		if w.burning.has(p):
			_lanterns.append(_flame(w, p, Light.FIRE_RADIUS, Light.FIRE, true))
	settled.emit(w)


## A lantern or a burning tile as a flickering light: the tiles it lights and how much.
func _flame(w: World, p: Vector2i, radius: int, color: Vector3, fire: bool) -> Dictionary:
	var s := Light.spread(p, radius, w.light_mask())
	var lit := PackedInt32Array()
	var amount := PackedFloat32Array()
	for j in s.size():
		if s[j] > 0.0:
			lit.append(j)
			amount.append(s[j])
	var phase := float(Grid.index(p)) * 1.7
	return {lit = lit, amount = amount, phase = phase, color = color, fire = fire}


## Animates one round from `before` to `after`, then shows `after`.
func play(events: Array, before: World, after: World) -> void:
	world = after
	_rushed = false
	var perceived := Perceived.of(before, after, events)
	_vis = perceived.vis
	_veiled = perceived.veiled
	_told.clear()
	for f in perceived.facts:
		if f.i >= 0:
			_told[f.i] = f
	_actors.clear()
	for a in before.actors:
		if a.alive():
			_actors[a.id] = a.clone()
	_shots.clear()
	for s in before.shots:
		_shots[s.id] = {pos = s.pos, spell = s.spell, faction = s.faction}
	_animating = true
	var passes := Afterimage.plan(events)
	for i in events.size():
		var veiled := _veiled if debug.is_empty() else {}
		var left := Afterimage.copies(passes.get(i, []), _actors, _time, veiled)
		_ghosts.append_array(left.filter(func(g): return _visible(g.at)))
		var wait := _apply(events[i], _told.get(i, {}))
		if wait > 0.0 and not _rushed:
			_hold = get_tree().create_timer(wait / speed)
			await _hold.timeout
	noise = NoiseMeter.level(_vis, events)
	if not replay:
		for p in Perceived.spotted(before, after):
			shown.emit({t = &"spot", at = p}, cell_centre(p))
	show_world(after)


## Finishes the round in progress at once: `play` returns before this does, so
## the key that asked acts on the finished round. Popups and sounds still play.
func rush() -> void:
	_rushed = true
	if _hold != null:
		_hold.timeout.emit()


## Whether Miho sees tile p: what the log and the popups are told from.
func _visible(p: Vector2i) -> bool:
	return Perceived.sees(_vis, p)


## Whether `a` wears a hat that hides it now; the debug view sees through it.
func _hatted(a: Actor) -> bool:
	return debug.is_empty() and _veiled.has(a.id)


## Whether tile p is drawn: seen, or any tile with the debug view on.
func _revealed(p: Vector2i) -> bool:
	return Grid.inside(p) and (not debug.is_empty() or _vis[Grid.index(p)] == 1)


## Applies one event to what is drawn; `fact` is what Miho is told of it, or
## empty. Returns how long to hold it.
func _apply(e: Dictionary, fact: Dictionary) -> float:
	var at: Vector2i = e.get("to", e.get("at", Vector2i(-1, -1)))
	if not Grid.inside(at) and _actors.has(e.get("id", -1)):
		at = _actors[e.id].pos
	match e.t:
		&"move":
			if _actors.has(e.id):
				_actors[e.id].pos = e.to
		&"cast":
			if Spell.make(e.cards).gun():
				_flash(at, Color(Palette.BURNING[1], 0.9))
		&"spawn":
			_shots[e.shot] = {pos = e.at, spell = Spell.make(e.cards), faction = e.faction}
		&"fly":
			if _shots.has(e.shot):
				_shots[e.shot].pos = e.to
				var tail: Array = _trails.get(e.shot, [])
				tail.append(e.from)
				_trails[e.shot] = tail.slice(-TRAIL)
		&"stick":
			_shots[e.shot] = {pos = e.at, spell = Spell.make(e.cards), faction = e.faction}
		&"ride":
			if _shots.has(e.shot):
				_shots[e.shot].pos = e.to
		&"burst", &"hit", &"fade", &"snuff":
			if not e.get("through", false):
				_shots.erase(e.shot)
			_flash(at, Color(1, 1, 1, 0.5))
		&"clash":
			_shots.erase(e.shot)
			_shots.erase(e.other)
			_flash(at, Color(1, 1, 1, 0.8))
		&"claw", &"melee":
			_flash(at, Palette.HURT)
		&"drum":
			_flash(at, Color(Palette.SOUND, 0.6))
		&"trap":
			_flash(at, Color(Palette.TILES[e.kind][1], 0.6))
		&"fall" when e.has("depth"):
			_popups.clear()
		&"ascend":
			_popups.clear()
		&"splash":
			var glow: Color = (
				Palette.BURNING[1] if Spell.make(e.cards).has(Cards.FIRE) else Color.WHITE
			)
			_flash(at, Color(1.0, 0.95, 0.7, 0.95))
			for d in Grid.DIRS:
				_flash(at + d, Color(glow, 0.85), 0.07)
			_flash(at, Color(glow, 0.9), 0.14)
		&"die":
			_actors.erase(e.id)
		&"spray":
			var color := Palette.card(Spell.make(e.cards).slots[0])
			for p: Vector2i in e.tiles:
				_flash(p, Color(color, 0.8), 0.02 * Grid.cheb(p, e.at))
		&"sprout":
			for p: Vector2i in e.tiles:
				_flash(p, Color(Palette.CARD[Cards.WOOD], 0.8), 0.04 * Grid.cheb(p, e.at))
		&"blast":
			for p: Vector2i in e.tiles:
				_flash(p, Color(Palette.BURNING[1], 0.9), 0.03 * Grid.cheb(p, e.at))
		&"become", &"heat":
			var color: Color = Palette.HOT[1] if e.t == &"heat" else Palette.TILES[e.tile][1]
			for p: Vector2i in e.tiles:
				_flash(p, Color(color, 0.8), 0.04 * Grid.cheb(p, e.at))
	if fact.is_empty():
		return 0.0
	var popup := Perceived.popup_of(fact)
	if not popup.is_empty():
		_popups.append(popup.merged({born = _time}))
	shown.emit(e, cell_centre(fact.where))
	return DELAY.get(e.t, 0.0)


## A tile lit up for a moment, starting `after` seconds from now.
func _flash(at: Vector2i, color: Color, after := 0.0) -> void:
	if _visible(at):
		_flashes.append({at = at, color = color, born = _time + after})


## Screen position of the centre of map tile p, in this node's space.
func cell_centre(p: Vector2i) -> Vector2:
	return (_cell(p) + Vector2(0.5, 0.5)) * CELL


## The map tile under a point in this node's space, or (-1, -1).
func tile_at(local: Vector2) -> Vector2i:
	var c := Vector2i((local / CELL).floor()) - side + cam
	return c if Grid.inside(c) and _shown(c) else Vector2i(-1, -1)


## Where the creature listed in the sidebar (or the touch strip) under a point stands, or (-1, -1).
func side_at(local: Vector2) -> Vector2i:
	var c := Vector2i((local / CELL).floor())
	if world != null and bar is TouchHud:
		var at: Vector2i = bar.creature_at(self, local)
		if at.x >= 0:
			return at
	if world == null or c.x < 0 or c.x >= side.x or c.y < 0 or c.y >= rows - foot:
		return Vector2i(-1, -1)
	var list := _side_list(_world_actors(), world.player().pos)
	return list[c.y / SIDE_ROWS].pos if c.y / SIDE_ROWS < list.size() else Vector2i(-1, -1)


# --- light -------------------------------------------------------------------


## How bright a flame is now: lanterns waver a little, fire a lot.
func _flicker(phase: float, fire: bool) -> float:
	if fire:
		return 0.78 + 0.14 * sin(_time * 9.3 + phase) + 0.08 * sin(_time * 23.0 + phase)
	return 0.9 + 0.07 * sin(_time * 6.1 + phase) + 0.04 * sin(_time * 15.7 + phase)


func _field() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(Grid.W * Grid.H)
	for l in _lanterns:
		var c: Vector3 = l.color * _flicker(l.phase, l.fire)
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
			_shot_light[key] = Light.spread(s.pos, l.radius, world.light_mask())
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
	var light := _field()
	var actors := _actors if _animating else _world_actors()
	var me := world.player()
	var me_pos: Vector2i = actors[me.id].pos if actors.has(me.id) else me.pos
	_draw_map(light, me_pos)
	TermMarks.telegraphs(self, actors)
	if not _animating:
		TermMarks.paths(self)
		for l: Array in lines:
			if _shown(l[0]) and _shown(l[1]):
				var a := cell_centre(l[0])
				var b := cell_centre(l[1])
				var side: Vector2 = (b - a).orthogonal().normalized() * LINE_GAP * l[3]
				draw_line(a + side, b + side, l[2], 2.0)
		DebugView.draw(self)
	_draw_things(light, actors)
	Afterimage.draw(self, _ghosts, _time)
	for f in _flashes:
		if not _shown(f.at) or _time < f.born:
			continue
		var k: float = 1.0 - (_time - f.born) / 0.35
		var c: Color = f.color
		draw_rect(Rect2(_cell(f.at) * CELL, CELL), Color(c, c.a * k))
	for p in _popups:
		if not _shown(p.at):
			continue
		var k: float = (_time - p.born) / p.life
		var c: Color = p.color
		var at := _cell(p.at) + Vector2(0, -POPUP_ABOVE - 0.6 * k)
		if p.text.length() == 1:
			_glyph(at, p.text, Color(c, 1.0 - k * k))
		else:
			_text(at, p.text, Color(c, 1.0 - k * k))
	if not replay:
		if side.x > 0:
			_draw_side(actors, me_pos)
		bar.draw(self)
		if banner_lines.is_empty():
			_draw_log()
		_draw_info()
	var v := map_view()
	if panel.is_empty() and not banner_lines.is_empty():
		draw_rect(Rect2(Vector2.ZERO, Vector2(cols, v.y) * CELL), Color(0, 0, 0, 0.8))
		for r: Array in _banner_rows():
			_text(r[2], r[1], Palette.KIND[&"miho"] if r[0] == 0 else Palette.TEXT)


## Each row of the banner as [line index, text, position in cells]: the lines
## wrapped to the screen width, one blank row between them, centred over the map.
func _banner_rows() -> Array:
	var v := map_view()
	var rows_of_line := []
	var height := 0
	for line in banner_lines:
		var wrapped: Array = rows_of([[line, Palette.TEXT]], cols).map(
			func(row): return "".join(row.map(func(r): return r[0]))
		)
		rows_of_line.append(wrapped)
		height += wrapped.size() + 1
	var out := []
	var y := maxi(0, (v.y - height) / 2)
	for i in rows_of_line.size():
		for text: String in rows_of_line[i]:
			var w := _cells(text)
			var x := clampf(side.x + (v.x - w) / 2.0, 0.0, maxf(0.0, cols - w))
			out.append([i, text, Vector2(x, y)])
			y += 1
		y += 1
	return out


## Where banner line `i` is drawn, in cells.
func banner_rect(i: int) -> Rect2:
	var rect := Rect2()
	for r: Array in _banner_rows():
		if r[0] == i:
			var at := Rect2(r[2], Vector2(_cells(r[1]), 1))
			rect = at if rect.size == Vector2.ZERO else rect.merge(at)
	return rect


## The banner line under a point in this node's space, or -1.
func banner_at(local: Vector2) -> int:
	for i in banner_lines.size():
		if banner_rect(i).has_point(local / CELL):
			return i
	return -1


func _draw_map(light: PackedVector3Array, me_pos: Vector2i) -> void:
	var below := Storeys.below(world)
	for i in world.tiles.size():
		var p := Grid.at(i)
		if world.known[i] == 0 and _vis[i] == 0 and debug.is_empty() or not _shown(p):
			continue
		var t := world.tiles[i]
		var spec: Array = Palette.TILES[t]
		var glyph: String = spec[0]
		var fg: Color = spec[1]
		var bg: Color = spec[2]
		if world.bodies.has(p) and world.bodies[p].met:
			glyph = Palette.BODY[0]
			fg = Palette.BODY[1]
		var item := Palette.item(world, p)
		if not item.is_empty():
			glyph = item[0]
			fg = item[1]
		var fire := _vis[i] == 1 and world.burning.has(p)
		if fire:
			var k := _flicker(i * 1.7, true)
			var flame: Array = Palette.FIERCE_BURNING if Tiles.fierce[t] == 1 else Palette.BURNING
			glyph = flame[0]
			fg = Color(flame[1] * (0.7 + 0.4 * k), 1.0)
			bg = Color(flame[2] * k, 1.0)
		var hot := not fire and _vis[i] == 1 and world.hot.has(p)
		if hot:
			glyph = Palette.HOT[0]
			fg = Palette.HOT[1]
			bg = Palette.HOT[2]
		if _vis[i] == 1:
			var l := light[i]
			var d := Grid.cheb(p, me_pos)
			if d <= World.NIGHT[0]:
				l += Palette.NIGHT * (1.0 - d / 3.0)
			if t != World.LANTERN and t != World.SKY and not fire and not hot:
				fg = _lit(fg, l, 0.18)
				bg = _lit(bg, l, 0.0) + Color(l.x, l.y, l.z) * 0.06
		elif world.dim[i] == 1:
			fg = fg * 0.3 + Palette.STARLIGHT
			bg = bg * 0.22 + Palette.STARLIGHT * 0.4
		else:
			var v := fg.get_luminance()
			fg = Palette.MEMORY_FG * (0.6 + v * 0.6)
			bg = Palette.MEMORY_BG
		var sunk := t == World.SKY and below.size() > i and below[i] != World.SKY
		glyph = " " if sunk else glyph
		if _vis[i] == 1 and world.gas.has(p):
			var g: Vector2i = world.gas[p]
			var glow := clampf(0.35 + Light.level(light[i]), 0.35, 1.0)
			var gas: Color = Palette.GAS[g.x][1] * glow
			var k := Palette.gas_alpha(g.y)
			bg = bg.lerp(Color(gas, 1.0), k)
			fg = fg.lerp(Color(gas, 1.0), k * 0.5)
		var grain := 0.92 + 0.16 * fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		fg *= grain
		bg *= grain
		var tint: Color = tints.get(p, Color(0, 0, 0, 0))
		bg = bg.lerp(Color(tint, 1.0), tint.a)
		var cell := _cell(p)
		if zone.has(p):
			bg = bg.lerp(Palette.ZONE, 0.18)
		draw_rect(Rect2(cell * CELL, CELL), bg)
		if sunk:
			draw_texture(Dither.of(below[i]), cell * CELL, Palette.BELOW)
		_glyph(cell, glyph, fg)
		if zone.has(p):
			_outline(p, cell)


## Draws a line along each side of tile p that borders a tile outside the zone.
func _outline(p: Vector2i, cell: Vector2) -> void:
	var line := Color(Palette.ZONE, 0.7)
	var a := cell * CELL
	var c := [a, a + Vector2(CELL.x, 0), a + CELL, a + Vector2(0, CELL.y)]
	for side: Array in [
		[Vector2i.UP, 0, 1], [Vector2i.RIGHT, 1, 2], [Vector2i.DOWN, 3, 2], [Vector2i.LEFT, 0, 3]
	]:
		if not zone.has(p + side[0]):
			draw_line(c[side[1]], c[side[2]], line, 2.0)


static func _lit(c: Color, l: Vector3, floor_level: float) -> Color:
	return Color(
		c.r * clampf(floor_level + l.x, 0.0, 1.6),
		c.g * clampf(floor_level + l.y, 0.0, 1.6),
		c.b * clampf(floor_level + l.z, 0.0, 1.6)
	)


func _draw_things(light: PackedVector3Array, actors: Dictionary) -> void:
	var shots := _shots if _animating else _world_shots()
	for id in shots:
		var s: Dictionary = shots[id]
		var tail: Array = _trails.get(id, [])
		var c := Palette.shot_color(s.spell, s.faction)
		for k in tail.size():
			var p: Vector2i = tail[k]
			if p == s.pos or not _revealed(p) or not _shown(p):
				continue
			var fade := float(k + 1) / tail.size()
			var r := Rect2(_cell(p) * CELL, CELL)
			draw_rect(r, Color(Palette.VOID, 0.75))
			draw_rect(r, Color(c, 0.12 + 0.3 * fade))
			_glyph(_cell(p), "•" if k >= tail.size() - 2 else "·", Color(c, 0.35 + 0.65 * fade))
	for id in shots:
		var s: Dictionary = shots[id]
		if _revealed(s.pos) and _shown(s.pos):
			_glyph(
				_cell(s.pos), Palette.shot_glyph(s.spell), Palette.shot_color(s.spell, s.faction)
			)
	for id in actors:
		var a: Actor = actors[id]
		if a.faction != Actor.FOX and not _revealed(a.pos) or not _shown(a.pos) or _hatted(a):
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
		if tints.has(a.pos):
			draw_rect(Rect2(cell * CELL, CELL), tints[a.pos])
		_glyph(cell, Lang.t(Bestiary.info(Guise.looks(a)).glyph, "creature"), c)
		for s: Dictionary in shots.values():
			if s.pos == a.pos:
				var glow := Palette.shot_color(s.spell, s.faction)
				_small(cell + Vector2(0, -0.05), Palette.shot_glyph(s.spell), glow)
		if a.faction != Actor.FOX and _visible(a.pos):
			var mark := Perceived.mark_of(a)
			if mark != "":
				_small(cell + Vector2(0.62, -0.05), mark, Palette.ALERT[maxi(a.alert, 1)])
		_status(cell + Vector2(0, 0.55), a)
	for p in marks:
		var m: Array = marks[p]
		if _shown(p):
			var at := _cell(p) + Vector2(0.62, 0.55)
			var size := Vector2(_font.get_string_size(m[0], 0, -1, SMALL).x + 2, SMALL + 2)
			draw_rect(Rect2(at * CELL - Vector2(1, 1), size), Color(Palette.VOID, 0.8))
			_small(at, m[0], m[1])


func _side_list(actors: Dictionary, me_pos: Vector2i, limit := -1) -> Array:
	var list: Array = actors.values().filter(
		func(a): return a.faction != Actor.FOX and _revealed(a.pos) and not _hatted(a)
	)
	list.sort_custom(func(a, b): return Grid.cheb(a.pos, me_pos) < Grid.cheb(b.pos, me_pos))
	return list.slice(0, (rows - foot) / SIDE_ROWS if limit < 0 else limit)


## Creatures in sight, nearest first, as Brogue lists them (CreatureCard).
func _draw_side(actors: Dictionary, me_pos: Vector2i) -> void:
	var list := _side_list(actors, me_pos)
	for k in list.size():
		CreatureCard.draw(self, list[k], Vector2(0, k * SIDE_ROWS), MAP.x)


## A frame on the tile under the pointer, and what is there in a box on the
## far side of the map from it.
func _draw_info() -> void:
	var shown := Grid.inside(cursor) and _shown(cursor)
	if shown:
		var r := Rect2(_cell(cursor) * CELL, CELL)
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
				x += _run(Vector2(x, k), run)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The layout of `lines` (InfoBox) and `at`, the cell of its top-left corner. It
## lies in the map area, or in the whole width when that would make the text
## too small to read, on the far side from the map tile `p` (null for none). With
## `extra` cells for the example (`example` of the layout); none when they do not fit.
func _info_fit(p: Variant = null, lines: Array = info, extra := Vector2.ZERO) -> Dictionary:
	var v := map_view()
	var room := Rect2(Vector2(side), Vector2(v))
	var least := minf(1.0, readable / (CELL.x * scale.x))
	var fit := InfoBox.layout(lines, room.size, least, extra)
	if fit.get("scale", 0.0) < least:
		room = Rect2(Vector2.ZERO, Vector2(cols, v.y))
		fit = InfoBox.layout(lines, room.size, least, extra)
		if fit.get("scale", 0.0) < least and extra != Vector2.ZERO:
			return _info_fit(p, lines)
	var wide: Vector2 = fit.cells * fit.scale
	var at := Vector2(room.position.x, room.end.y - wide.y)
	if p != null:
		var c: Vector2i = p - cam
		at.x = room.end.x - wide.x if c.x < v.x / 2 else room.position.x
		at.y = room.end.y - wide.y if c.y < v.y / 2 else 0
	return fit.merged({at = at})


## The layout of `info`: on the far side of the map from the tile under the pointer.
func info_fit() -> Dictionary:
	var extra := Vector2(CodexScene.VIEW) if sim != null else Vector2.ZERO
	return _info_fit(cursor if Grid.inside(cursor) and _shown(cursor) else null, info, extra)


## The layout of the hint under the cell the pointer is in, inside the screen.
func hint_fit() -> Dictionary:
	var room := Rect2(0, 0, cols, rows if not panel.is_empty() else rows - foot)
	return InfoBox.beside(hint, room, Vector2i(hint_at), minf(1.0, readable / (CELL.x * scale.x)))


func _draw_log() -> void:
	for r: Array in log_rows():
		var width: float = r[2].reduce(func(n, run): return n + _cells(run[0]), 0.0)
		var box := Rect2(Vector2(side.x, r[0]) * CELL, Vector2(width + 1.0, 1) * CELL)
		draw_rect(box, Color(Palette.VOID, 0.7 * r[3]))
		var x: float = r[1]
		for run: Array in r[2]:
			x += _run(Vector2(x, r[0]), run, r[3])


## The log as it is drawn, [screen row, column of the first run, runs, alpha] for
## each row; the pointer's word hover (WordHover) reads the same rows.
func log_rows() -> Array:
	var out := []
	for line: Array in log_lines:
		for runs: Array in rows_of(line[0], cols - side.x - 1.0):
			out.append([out.size(), side.x + 0.5, runs, line[1]])
	return out


## Coloured runs broken into rows no wider than `width` cells, at the spaces;
## a word wider than that takes a row of its own.
static func rows_of(runs: Array, width: float) -> Array:
	var out := [[]]
	var x := 0.0
	for run: Array in runs:
		if x + _cells(run[0]) <= width:
			out[-1].append(run)
			x += _cells(run[0])
			continue
		var words: PackedStringArray = run[0].split(" ")
		for i in words.size():
			var word: String = (" " if i > 0 else "") + words[i]
			if x > 0.0 and x + _cells(word) > width:
				out.append([])
				x = 0.0
				word = word.lstrip(" ")
			if word != "":
				out[-1].append(Keywords.piece(run, word))
				x += _cells(word)
	return out


## A run at `at`, on its background if it has one, faded to `alpha`; the cells it takes.
func _run(at: Vector2, run: Array, alpha := 1.0) -> float:
	if run.slice(2).has(&"key"):
		_key(at, run[0], Color(run[1], run[1].a * alpha))
		return _key_cells(run[0])
	var width := _cells(run[0])
	var back := Keywords.back(run)
	if back.a > 0.0:
		draw_rect(Rect2(at * CELL, Vector2(width, 1) * CELL), Color(back, back.a * alpha))
	_text(at, run[0], Color(run[1], run[1].a * alpha))
	return width


## Health as hearts, at most `room` of them; more health is written as a number.
func _pips(at: Vector2, n: int, of: int, color: Color, room := 6) -> void:
	if of > room:
		_heart(at, true, color)
		_text(at + Vector2(1, 0), "%d/%d" % [n, of], color)
		return
	for i in of:
		_heart(at + Vector2(i, 0), i < n, color if i < n else Palette.DIM)


## A pixel heart filling cell `at`, full or as an outline.
func _heart(at: Vector2, full: bool, color: Color) -> void:
	Heart.draw(self, at, full, color)


## Cells a string takes as the font draws it, each character rounded up to a
## half (× and ° a half, Hangul a whole); ♥ and ♡ are drawn as hearts a cell wide.
static func _cells(s: String) -> float:
	var n := 0.0
	for c in s:
		if not _widths.has(c):
			var px := Fonts.pixel().get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
			_widths[c] = 1.0 if c in ["♥", "♡"] else maxf(0.5, ceilf(px / CELL.x * 2.0) / 2.0)
		n += _widths[c]
	return n


## A line of text at the font's doubled grid, Hangul a cell wide and ASCII
## half; ♥ and ♡ are drawn as pixel hearts a cell wide.
func _text(at: Vector2, s: String, color: Color) -> void:
	var x := at.x
	for part in _hearts_split(Lang.singular(s)):
		if part == "♥" or part == "♡":
			_heart(
				Vector2(x, at.y), part == "♥", color if part == "♥" else Color(Palette.DIM, color.a)
			)
		else:
			var y := at.y * CELL.y + (CELL.y - SIZE) / 2.0 + SIZE * 0.75
			draw_string(
				_font,
				Vector2(x * CELL.x, y).round(),
				part,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				SIZE,
				color
			)
		x += _cells(part)


## Text cut into runs of plain text and single hearts.
static func _hearts_split(s: String) -> Array[String]:
	var out: Array[String] = []
	var run := ""
	for c in s:
		if c == "♥" or c == "♡":
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
func _glyph(cell: Vector2, c: String, color: Color) -> void:
	if c == "":
		return
	var px := BIG if c.unicode_at(0) < 0x1100 else SIZE
	var w := _font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := cell * CELL + Vector2((CELL.x - w) / 2.0, (CELL.y - px) / 2.0 + px * 0.75)
	draw_string(_font, at.round(), c, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


## A shortcut's label at the top of `cell`, small beside what it stands for.
func _key(cell: Vector2, s: String, color := Palette.KEY) -> void:
	_small(cell + Vector2(0, 0.05), s, color)


## The cells a shortcut's label takes, at the font's doubled grid.
static func _key_cells(s: String) -> float:
	var px := Fonts.pixel().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x
	return ceilf(px / CELL.x * 2.0) / 2.0


func _small(cell: Vector2, s: String, color: Color) -> void:
	var at := cell * CELL + Vector2(0, SMALL * 0.75)
	draw_string(_font, at.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, color)


## The marks of what holds `a`, small at `cell`: its status (Status.of), then
## rooted and stunned.
func _status(cell: Vector2, a: Actor) -> void:
	var held: Array = Palette.CONDITION.keys().filter(func(k): return a.get(k) > 0)
	var marks: Array = held.map(func(k): return Palette.CONDITION[k])
	if Palette.STATUS.has(Status.of(a)):
		marks.push_front(Palette.STATUS[Status.of(a)])
	for i in marks.size():
		_small(cell + Vector2(i * 0.33, 0), marks[i][0], marks[i][1])
