class_name MapLayer
extends RefCounted
## The map as a Term draws it: every tile in the colour of the light on it, lantern light
## flickering, tiles out of sight from memory in dim blue, and on them the projectiles,
## creatures and marks.

var _term: Term
var _lanterns: Array[Dictionary] = []
var _shot_light := {}


func _init(of: Term) -> void:
	_term = of


## Finds the flames of world `w`: lanterns, what glows and what burns.
func light_up(w: World) -> void:
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


## A lantern or a burning tile as a flickering light: the tiles it lights and how much.
static func _flame(w: World, p: Vector2i, radius: int, color: Vector3, fire: bool) -> Dictionary:
	var s := Light.spread(p, radius, w.light_mask())
	var lit := PackedInt32Array()
	var amount := PackedFloat32Array()
	for j in s.size():
		if s[j] > 0.0:
			lit.append(j)
			amount.append(s[j])
	var phase := float(Grid.index(p)) * 1.7
	return {lit = lit, amount = amount, phase = phase, color = color, fire = fire}


## How bright a flame is now: lanterns waver a little, fire a lot.
func flicker(phase: float, fire: bool) -> float:
	var sway := _term.sway
	if fire:
		return 0.78 + 0.14 * sin(sway * 9.3 + phase) + 0.08 * sin(sway * 23.0 + phase)
	return 0.9 + 0.07 * sin(sway * 6.1 + phase) + 0.04 * sin(sway * 15.7 + phase)


## The light on every tile now, from the flames and from `shots` (id -> what flies).
func field(shots: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(Grid.W * Grid.H)
	for l in _lanterns:
		var c: Vector3 = l.color * flicker(l.phase, l.fire)
		var lit: PackedInt32Array = l.lit
		var amount: PackedFloat32Array = l.amount
		for j in lit.size():
			out[lit[j]] += c * amount[j]
	for id in shots:
		var s: Dictionary = shots[id]
		var l: Dictionary = s.spell.light(s.faction)
		if l.is_empty():
			continue
		var key := "%d@%s" % [id, s.pos]
		if not _shot_light.has(key):
			_shot_light[key] = Light.spread(s.pos, l.radius, _term.world.light_mask())
		var spread: PackedFloat32Array = _shot_light[key]
		var c: Vector3 = l.color * (0.92 + 0.08 * sin(_term.sway * 11.0 + id))
		for i in spread.size():
			if spread[i] > 0.0:
				out[i] += c * spread[i]
	if _shot_light.size() > 256:
		_shot_light.clear()
	return out


## Draws every tile Miho knows under `light`; `me_pos` is where the night light is.
func draw_tiles(light: PackedVector3Array, me_pos: Vector2i) -> void:
	var t := _term
	var world := t.world
	var vis := t.vis
	var tints := t.tints
	var zone := t.zone
	var known_only := t.debug.is_empty()
	var below := Storeys.below(world)
	for i in world.tiles.size():
		var p := Grid.at(i)
		if world.known[i] == 0 and vis[i] == 0 and known_only or not t.in_view(p):
			continue
		var tile := world.tiles[i]
		var spec: Array = Palette.TILES[tile]
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
			bg = item[2] if item.size() > 2 else bg
		var fire := vis[i] == 1 and world.burning.has(p)
		if fire:
			var k := flicker(i * 1.7, true)
			var flame: Array = (
				Palette.FIERCE_BURNING if Tiles.fierce[tile] == 1 else Palette.BURNING
			)
			glyph = flame[0]
			fg = Color(flame[1] * (0.7 + 0.4 * k), 1.0)
			bg = Color(flame[2] * k, 1.0)
		var hot := not fire and vis[i] == 1 and world.hot.has(p)
		if hot:
			glyph = Palette.HOT[0]
			fg = Palette.HOT[1]
			bg = Palette.HOT[2]
		if vis[i] == 1:
			var l := light[i]
			var d := Grid.cheb(p, me_pos)
			if d <= World.NIGHT[0]:
				l += Palette.NIGHT * (1.0 - d / 3.0)
			if (
				tile != World.LANTERN
				and tile != World.SKY
				and not fire
				and not hot
				and item.size() < 3
			):
				fg = _lit(fg, l, 0.18)
				bg = _lit(bg, l, 0.0) + Color(l.x, l.y, l.z) * 0.06
		elif world.dim[i] == 1:
			fg = fg * 0.3 + Palette.STARLIGHT
			bg = (
				bg * 0.22 + Palette.STARLIGHT * 0.4
				if item.size() < 3
				else Color(item[2] * 0.5, 1.0)
			)
		else:
			var v := fg.get_luminance()
			fg = (
				Palette.MEMORY_FG * (0.6 + v * 0.6)
				if item.size() < 3
				else Color(item[1] * 0.6, 1.0)
			)
			bg = Palette.MEMORY_BG if item.size() < 3 else Color(item[2] * 0.5, 1.0)
		var sunk := tile == World.SKY and below.size() > i and below[i] != World.SKY
		glyph = " " if sunk else glyph
		if vis[i] == 1 and world.gas.has(p):
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
		var cell := t.cell_of(p)
		if zone.has(p):
			bg = bg.lerp(Palette.ZONE, 0.18)
		if t.zone_centres.has(p):
			glyph = Palette.ZONE_MARK
			fg = Palette.ZONE
		t.draw_rect(Rect2(cell * Term.CELL, Term.CELL), bg)
		if sunk:
			t.draw_texture(Dither.of(below[i]), cell * Term.CELL, Palette.BELOW)
		t.draw_glyph(cell, glyph, fg)
		if zone.has(p):
			_outline(p, cell)


## Draws a line along each side of tile p that borders a tile outside the zone.
func _outline(p: Vector2i, cell: Vector2) -> void:
	var line := Color(Palette.ZONE, 0.7)
	var a := cell * Term.CELL
	var c := [a, a + Vector2(Term.CELL.x, 0), a + Term.CELL, a + Vector2(0, Term.CELL.y)]
	for side: Array in [
		[Vector2i.UP, 0, 1], [Vector2i.RIGHT, 1, 2], [Vector2i.DOWN, 3, 2], [Vector2i.LEFT, 0, 3]
	]:
		if not _term.zone.has(p + side[0]):
			_term.draw_line(c[side[1]], c[side[2]], line, 2.0)


static func _lit(c: Color, l: Vector3, floor_level: float) -> Color:
	return Color(
		c.r * clampf(floor_level + l.x, 0.0, 1.6),
		c.g * clampf(floor_level + l.y, 0.0, 1.6),
		c.b * clampf(floor_level + l.z, 0.0, 1.6)
	)


## Draws `shots` with their trails, `actors` and the game's marks over the tiles.
func draw_things(light: PackedVector3Array, actors: Dictionary, shots: Dictionary) -> void:
	var t := _term
	for id in shots:
		var s: Dictionary = shots[id]
		var tail: Array = t.anim.trails.get(id, [])
		var c := Palette.shot_color(s.spell, s.faction)
		for k in tail.size():
			var p: Vector2i = tail[k]
			if p == s.pos or not t.revealed(p) or not t.in_view(p):
				continue
			var fade := float(k + 1) / tail.size()
			var r := Rect2(t.cell_of(p) * Term.CELL, Term.CELL)
			t.draw_rect(r, Color(Palette.VOID, 0.75))
			t.draw_rect(r, Color(c, 0.12 + 0.3 * fade))
			t.draw_glyph(
				t.cell_of(p), "•" if k >= tail.size() - 2 else "·", Color(c, 0.35 + 0.65 * fade)
			)
	for id in shots:
		var s: Dictionary = shots[id]
		if t.revealed(s.pos) and t.in_view(s.pos):
			t.draw_glyph(
				t.cell_of(s.pos),
				Palette.shot_glyph(s.spell),
				Palette.shot_color(s.spell, s.faction)
			)
	for id in actors:
		var a: Actor = actors[id]
		if not a.is_miho() and not t.revealed(a.pos) or not t.in_view(a.pos) or t.hatted(a):
			continue
		var cell := t.cell_of(a.pos)
		var l := light[Grid.index(a.pos)]
		var c: Color = Palette.glyph_color(a)
		if not a.is_miho():
			c = c * clampf(0.55 + Light.level(l), 0.55, 1.2)
			c.a = 1.0
		elif Light.level(l) < Light.LIT:
			c = c.darkened(0.45)
		var back: Color = a.info().get("back", Color(0, 0, 0, 0.55))
		t.draw_rect(Rect2(cell * Term.CELL, Term.CELL), back)
		if t.tints.has(a.pos):
			t.draw_rect(Rect2(cell * Term.CELL, Term.CELL), t.tints[a.pos])
		t.draw_glyph(cell, Lang.t(Bestiary.info(Guise.looks(a)).glyph, "creature"), c)
		for s: Dictionary in shots.values():
			if s.pos == a.pos:
				var glow := Palette.shot_color(s.spell, s.faction)
				t.draw_small(cell + Vector2(0, -0.05), Palette.shot_glyph(s.spell), glow)
		if a.faction != Actor.FOX and t.sees(a.pos):
			var mark := Perceived.mark_of(a)
			if mark != "":
				t.draw_small(
					cell + Vector2(0.62, -0.05), mark, Palette.ALERT[maxi(a.brain.alert, 1)]
				)
		t.draw_status(cell + Vector2(0, 0.55), a)
	for p in t.marks:
		var m: Array = t.marks[p]
		if t.in_view(p):
			var at := t.cell_of(p) + Vector2(0.62, 0.55)
			var size := Vector2(
				t.font.get_string_size(m[0], 0, -1, Term.SMALL).x + 2, Term.SMALL + 2
			)
			t.draw_rect(Rect2(at * Term.CELL - Vector2(1, 1), size), Color(Palette.VOID, 0.8))
			t.draw_small(at, m[0], m[1])
