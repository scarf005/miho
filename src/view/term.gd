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

const CELL := Vector2(32, 40)
const MAP := Vector2i(8, 0)
## Screen rows each creature takes in the sidebar, and its state there.
const SIDE_ROWS := 3
## Tiles of tail drawn behind a projectile.
const TRAIL := 4
const SIZE := 32
const BIG := 48
const SMALL := 16
## Pixels between the lines of wisps chasing one creature.
const LINE_GAP := 5.0
const HEART := [
	".##...##.",
	"####.####",
	"#########",
	"#########",
	".#######.",
	"..#####..",
	"...###...",
	"....#...."
]
const HEART_EMPTY := [
	".##...##.",
	"#..#.#..#",
	"#...#...#",
	"#.......#",
	".#.....#.",
	"..#...#..",
	"...#.#...",
	"....#...."
]
const DELAY := {
	&"move": 0.05,
	&"spawn": 0.04,
	&"fly": 0.03,
	&"land": 0.05,
	&"hit": 0.1,
	&"burst": 0.1,
	&"splash": 0.22,
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
var info: Array = []
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
var panel := {}
var cols := 40
var rows := 18
## The map tile drawn at the map area's top-left; negative centres a small map.
var cam := Vector2i.ZERO

var _font: FontFile
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
	for i in events.size():
		var wait := _apply(events[i], _told.get(i, {}))
		if wait > 0.0:
			await get_tree().create_timer(wait / speed).timeout
	show_world(after)


## Whether Miho sees tile p: what the log and the popups are told from.
func _visible(p: Vector2i) -> bool:
	return Perceived.sees(_vis, p)


## Whether `a` wears a hat that hides it now; the debug view sees through it.
func _hatted(a: Actor) -> bool:
	return debug.is_empty() and _veiled.has(a.id)


## Whether tile p is drawn: seen, or any tile with the debug view on.
func _revealed(p: Vector2i) -> bool:
	return Grid.inside(p) and (not debug.is_empty() or _vis[Grid.index(p)] == 1)


## The popup a fact shows over its tile, or empty: {at, text, color, life}.
static func popup_of(fact: Dictionary) -> Dictionary:
	var at: Vector2i = fact.where
	match fact.t:
		&"hurt":
			return {at = at, text = str(fact.n), color = Palette.HURT, life = 0.9}
		&"notice":
			return {at = at, text = "!", color = Palette.ALERT[2], life = 0.9}
		&"heed":
			return {at = at, text = "?", color = Palette.ALERT[1], life = 0.9}
		&"drum":
			return {at = at, text = "툭" if fact.wet else "둥", color = Palette.SOUND, life = 1.2}
		&"card":
			return {
				at = at, text = Cards.GLYPH[fact.card], color = Palette.CARD[fact.card], life = 1.6
			}
		&"heal":
			return {at = at, text = "+1", color = Palette.PEACH[1], life = 0.9}
		&"noise", &"shout":
			return {at = at, text = fact.word, color = Palette.SOUND, life = 1.4}
		&"find":
			var plate: Array = Palette.TILES[fact.kind]
			return {at = at, text = plate[0], color = plate[1], life = 1.6}
		&"trap":
			return {at = at, text = Traps.CLICK, color = Palette.TILES[fact.kind][1], life = 1.2}
	return {}


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
		&"splash":
			_flash(at, Color(1.0, 0.95, 0.7, 0.95))
			for d in Grid.DIRS:
				_flash(at + d, Color(Palette.BURNING[1], 0.85), 0.07)
			_flash(at, Color(Palette.BURNING[1], 0.9), 0.14)
		&"die":
			_actors.erase(e.id)
		&"spray":
			var color := Palette.card(Spell.make(e.cards).slots[0])
			for p: Vector2i in e.tiles:
				_flash(p, Color(color, 0.8), 0.02 * Grid.cheb(p, e.at))
		&"sprout":
			for p: Vector2i in e.tiles:
				_flash(p, Color(Palette.CARD[Cards.WOOD], 0.8), 0.04 * Grid.cheb(p, e.at))
		&"become", &"heat":
			var color: Color = Palette.HOT[1] if e.t == &"heat" else Palette.TILES[e.tile][1]
			for p: Vector2i in e.tiles:
				_flash(p, Color(color, 0.8), 0.04 * Grid.cheb(p, e.at))
	if fact.is_empty():
		return 0.0
	var popup := popup_of(fact)
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
	var c := Vector2i((local / CELL).floor()) - MAP + cam
	return c if Grid.inside(c) and _shown(c) else Vector2i(-1, -1)


## Where the creature listed in the sidebar under a point stands, or (-1, -1).
func side_at(local: Vector2) -> Vector2i:
	var c := Vector2i((local / CELL).floor())
	if world == null or c.x < 0 or c.x >= MAP.x or c.y < 0 or c.y >= rows - 2:
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
	var light := _field()
	var actors := _actors if _animating else _world_actors()
	var me := world.player()
	var me_pos: Vector2i = actors[me.id].pos if actors.has(me.id) else me.pos
	_draw_map(light, me_pos)
	_draw_telegraphs(actors)
	if not _animating:
		_draw_paths()
		for l: Array in lines:
			if _shown(l[0]) and _shown(l[1]):
				var a := cell_centre(l[0])
				var b := cell_centre(l[1])
				var side: Vector2 = (b - a).orthogonal().normalized() * LINE_GAP * l[3]
				draw_line(a + side, b + side, l[2], 2.0)
		DebugView.draw(self)
	_draw_things(light, actors)
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
		var at := _cell(p.at) + Vector2(0, -0.6 * k)
		if p.text.length() == 1:
			_glyph(at, p.text, Color(c, 1.0 - k * k))
		else:
			_text(at, p.text, Color(c, 1.0 - k * k))
	if not replay:
		_draw_side(actors, me_pos)
		StatusBar.draw(self)
		if banner_lines.is_empty():
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
		for item in [[world.stairs, Palette.STAIRS], [world.elixir, Palette.ELIXIR]]:
			if p == item[0]:
				glyph = item[1][0]
				fg = item[1][1]
		if world.peaches.has(p):
			glyph = Palette.PEACH[0]
			fg = Palette.PEACH[1]
		var fire := _vis[i] == 1 and world.burning.has(p)
		if fire:
			var k := _flicker(i * 1.7, true)
			glyph = Palette.BURNING[0]
			fg = Color(Palette.BURNING[1] * (0.7 + 0.4 * k), 1.0)
			bg = Color(Palette.BURNING[2] * k, 1.0)
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
		var in_zone := zone.has(p)
		if in_zone:
			bg = bg.lerp(Palette.ZONE, 0.18)
		draw_rect(Rect2(cell * CELL, CELL), bg)
		_glyph(cell, glyph, fg)
		if in_zone:
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


## A charging creature's line, so every incoming spell is seen a round early.
## A creature running to a drum shows no line: the sidebar and its info say so.
func _draw_telegraphs(actors: Dictionary) -> void:
	for id in actors:
		var a: Actor = actors[id]
		if a.faction == Actor.FOX or a.intent.is_empty() or not _revealed(a.pos):
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


## Where each projectile in sight flies next, over tiles Miho knows: an orb
## to the wall, a wisp to the end of its range, a homing orb one tile ahead.
func _draw_paths() -> void:
	for s in world.shots:
		if s.dir == Vector2i.ZERO or not _revealed(s.pos):
			continue
		var ray := Forecast.ray(world, s.pos, s.dir)
		if s.turn > 0:
			ray = ray.slice(0, 1)
		elif not s.spell.orb:
			ray = ray.slice(0, maxi(0, Spell.RANGE - s.distance()))
		var c := Palette.shot_color(s.spell, s.faction)
		for k in ray.size():
			var p := ray[k]
			if world.known[Grid.index(p)] == 0:
				break
			if _shown(p):
				draw_rect(Rect2(_cell(p) * CELL, CELL), Color(c, 0.22 - 0.1 * k / ray.size()))
				if k == 0:
					_glyph(_cell(p), Palette.BOLT[s.dir], Color(c, 0.8))


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
		_glyph(cell, Bestiary.info(Guise.looks(a)).glyph, c)
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


func _side_list(actors: Dictionary, me_pos: Vector2i) -> Array:
	var list: Array = actors.values().filter(
		func(a): return a.faction != Actor.FOX and _revealed(a.pos) and not _hatted(a)
	)
	list.sort_custom(func(a, b): return Grid.cheb(a.pos, me_pos) < Grid.cheb(b.pos, me_pos))
	return list.slice(0, (rows - 2) / SIDE_ROWS)


## Creatures in sight, nearest first, as Brogue lists them: glyph and name,
## hearts, then what it is doing and the spell it charges with its aim.
func _draw_side(actors: Dictionary, me_pos: Vector2i) -> void:
	var list := _side_list(actors, me_pos)
	for k in list.size():
		var a: Actor = list[k]
		var row := k * SIDE_ROWS
		if a.pos == cursor:
			draw_rect(
				Rect2(Vector2(0, row) * CELL, Vector2(MAP.x, SIDE_ROWS) * CELL),
				Color(Palette.TEXT, 0.12)
			)
		_glyph(Vector2(0, row), a.info().glyph, Palette.KIND[a.kind])
		_text(Vector2(1.5, row), a.info().name, Palette.KIND[a.kind])
		_pips(Vector2(0, row + 1), a.hp, a.max_hp, Palette.HURT, MAP.x - 1)
		_status(Vector2(MAP.x - 1, row + 1), a)
		var doing: String = Info.state(a) if a.blind <= 0 else "눈멂"
		if a.fighting() and a.blind <= 0:
			doing = "싸우는 중"
		_text(Vector2(0, row + 2), doing, Palette.ALERT[maxi(a.alert, 1)])
		var x := _cells(doing) + 0.5
		if a.intent.is_empty():
			continue
		var slots := Spell.make(a.intent).slots
		for j in slots.size():
			_glyph(Vector2(x + j, row + 2), Cards.GLYPH[slots[j]], Palette.card(slots[j]))
		_glyph(Vector2(x + slots.size(), row + 2), Palette.BOLT[a.aim], Palette.SIDE[1])


## A frame on the tile under the pointer, and what is there in a box on the
## far side of the map from it.
func _draw_info() -> void:
	var shown := Grid.inside(cursor) and _shown(cursor)
	if shown:
		var r := Rect2(_cell(cursor) * CELL, CELL)
		draw_rect(r.grow(-1), Color(Palette.TEXT, 0.7), false, 2.0)
	if info.is_empty():
		return
	var fit := _info_fit(cursor if shown else null)
	draw_set_transform(fit.at * CELL, 0.0, Vector2(fit.scale, fit.scale))
	var box := Rect2(Vector2.ZERO, fit.cells * CELL)
	draw_rect(box, Color(Palette.VOID, 0.92))
	draw_rect(box.grow(-1), Palette.DIM, false, 2.0)
	for column: Array in fit.columns:
		for k in column[1].size():
			var x: float = column[0]
			for run: Array in column[1][k]:
				_text(Vector2(x, k), run[0], run[1])
				x += _cells(run[0])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The layout of `info` (InfoBox) and `at`, the cell of its top-left corner. It
## lies in the map area, or in the whole width when that would make the text
## too small to read, on the far side from the map tile `p` (null for none).
func _info_fit(p: Variant = null) -> Dictionary:
	var v := map_view()
	var room := Rect2(Vector2(MAP), Vector2(v))
	var least := minf(1.0, InfoBox.READABLE / scale.x)
	var fit := InfoBox.layout(info, room.size, least)
	if fit.scale < least:
		room = Rect2(Vector2.ZERO, Vector2(cols, v.y))
		fit = InfoBox.layout(info, room.size, least)
	var wide: Vector2 = fit.cells * fit.scale
	var at := Vector2(room.position.x, room.end.y - wide.y)
	if p != null:
		var c: Vector2i = p - cam
		at.x = room.end.x - wide.x if c.x < v.x / 2 else room.position.x
		at.y = room.end.y - wide.y if c.y < v.y / 2 else 0
	return fit.merged({at = at})


func _draw_log() -> void:
	for k in log_lines.size():
		var runs: Array = log_lines[k][0]
		var alpha: float = log_lines[k][1]
		var width: float = runs.reduce(func(n, r): return n + _cells(r[0]), 0.0)
		var box := Rect2(Vector2(MAP.x, k) * CELL, Vector2(width + 1.0, 1) * CELL)
		draw_rect(box, Color(Palette.VOID, 0.7 * alpha))
		var x := MAP.x + 0.5
		for run: Array in runs:
			_text(Vector2(x, k), run[0], Color(run[1], alpha))
			x += _cells(run[0])


## Rows of a panel list that fit on `screen_rows` rows under a detail of `detail` lines.
static func list_fits(screen_rows: int, detail: int) -> int:
	return maxi(1, screen_rows - 4 - (detail + 1 if detail > 0 else 0))


## Rows of the panel that fit, and the first one shown (`top`).
func _panel_span() -> Vector2i:
	var fits := list_fits(rows, panel.get("detail", []).size())
	var count: int = panel.rows.size()
	return Vector2i(clampi(panel.get("top", 0), 0, maxi(0, count - fits)), fits)


func _draw_panel() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, size), Color(Palette.VOID, 1.0 if panel.get("opaque", false) else 0.92)
	)
	var detail: Array = panel.get("detail", [])
	for k in detail.size():
		var y := rows - detail.size() + k
		var x := 2.0
		for run: Array in detail[k]:
			_text(Vector2(x, y), run[0], run[1])
			x += _cells(run[0])
	_text(Vector2(2, 1), panel.title, Palette.KIND[&"miho"])
	var tab_x := 6.0
	for k in panel.get("tabs", []).size():
		_text(Vector2(tab_x, 1), panel.tabs[k], Palette.TEXT if k == panel.tab else Palette.DIM)
		tab_x += _cells(panel.tabs[k]) + 1.0
	var aside_x: float = panel.get("aside_x", cols)
	for k in panel.get("aside", []).size():
		var x := aside_x
		for run: Array in panel.aside[k]:
			_text(Vector2(x, 3 + k), run[0], run[1])
			x += _cells(run[0])
	if panel.get("aside_up", false):
		_glyph(Vector2(cols - 2, 2), "▲", Palette.DIM)
	if panel.get("aside_down", false):
		_glyph(Vector2(cols - 2, rows - 1), "▼", Palette.DIM)
	var span := _panel_span()
	for k in range(span.x, mini(span.x + span.y, panel.rows.size())):
		var y := 3 + k - span.x
		if k == panel.get("selected", -1) or k == panel.get("hover", -1):
			draw_rect(
				Rect2(Vector2(1, y) * CELL, Vector2(minf(aside_x, cols) - 2, 1) * CELL),
				Color(Palette.TEXT, 0.15 if k == panel.get("selected", -1) else 0.07)
			)
		var x := 2.0
		for run: Array in panel.rows[k]:
			x = run[2] if run.size() > 2 else x
			_text(Vector2(x, y), run[0], run[1])
			x += _cells(run[0])
	if span.x > 0:
		_glyph(Vector2(1, 2), "▲", Palette.DIM)
	if span.x + span.y < panel.rows.size():
		_glyph(Vector2(1, 3 + span.y), "▼", Palette.DIM)


## The panel row under a point in this node's space, or -1 (the detail beside the
## list holds no rows).
func panel_row_at(local: Vector2) -> int:
	if panel.is_empty() or panel_aside_at(local):
		return -1
	var span := _panel_span()
	var k := floori(local.y / CELL.y) - 3 + span.x
	return k if k >= span.x and k < mini(span.x + span.y, panel.rows.size()) else -1


## The panel tab under a point in this node's space, or -1.
func panel_tab_at(local: Vector2) -> int:
	var x := 6.0
	for k in panel.get("tabs", []).size():
		var width := _cells(panel.tabs[k]) + 1.0
		if floori(local.y / CELL.y) == 1 and local.x / CELL.x >= x and local.x / CELL.x < x + width:
			return k
		x += width
	return -1


## Whether a point in this node's space is over the panel's detail.
func panel_aside_at(local: Vector2) -> bool:
	return not panel.is_empty() and local.x / CELL.x >= panel.get("aside_x", cols)


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
	var rows: Array = HEART if full else HEART_EMPTY
	var px := 3.0
	var from := at * CELL + (CELL - Vector2(rows[0].length(), rows.size()) * px) / 2.0
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				draw_rect(Rect2((from + Vector2(x, y) * px).round(), Vector2(px, px)), color)


## Cells a string takes: Hangul is two halves wide, ASCII one half.
static func _cells(s: String) -> float:
	var n := 0.0
	for c in s:
		n += 1.0 if c.unicode_at(0) > 0x7E else 0.5
	return n


## A line of text at the font's doubled grid, Hangul a cell wide and ASCII
## half; ♥ and ♡ are drawn as pixel hearts a cell wide.
func _text(at: Vector2, s: String, color: Color) -> void:
	var x := at.x
	for part in _hearts_split(s):
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


func _small(cell: Vector2, s: String, color: Color) -> void:
	var at := cell * CELL + Vector2(0, SMALL * 0.75)
	draw_string(_font, at.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, color)


## The mark of the status `a` holds (Status.of), small at `cell`.
func _status(cell: Vector2, a: Actor) -> void:
	var mark: Array = Palette.STATUS.get(Status.of(a), [])
	if not mark.is_empty():
		_small(cell, mark[0], mark[1])
