class_name Afterimage
extends RefCounted
## A fading copy of a creature on each tile it passed when one action moved it
## more than one tile: a leap, a swap, a push. It reads a round's events and
## changes no rule.

## Seconds a copy takes to fade.
const LIFE := 0.25
const OPACITY := 0.6
## Events from a creature's own turn, which end a slide.
const TURNS := [&"cast", &"charge", &"notice", &"heed", &"claw", &"melee"]


## The tiles each creature passed, by the index of the event that leaves them:
## index -> [{id, at}]. A leap or swap is one `move` over several tiles. A
## push (Fall) is one `move` a tile, each after the `push` event, and counts
## from its second tile.
static func plan(events: Array) -> Dictionary:
	var out := {}
	var slide := {}
	for i in events.size():
		var e: Dictionary = events[i]
		if e.t in TURNS:
			slide = {}
		elif e.t == &"push":
			slide = {id = e.id, start = e.at, at = e.at, n = 0}
		elif e.t == &"move":
			var passed := []
			if Grid.cheb(e.from, e.to) > 1:
				passed = _line(e.from, e.to)
			elif slide.get("id", -1) == e.id and slide.at == e.from:
				slide.n += 1
				slide.at = e.to
				passed = [slide.start, e.from] if slide.n == 2 else [e.from] if slide.n > 2 else []
			else:
				slide = {}
			out[i] = passed.map(func(p): return {id = e.id, at = p})
	return out


## The tiles from `from` up to `to`, which lies on one of its eight lines.
static func _line(from: Vector2i, to: Vector2i) -> Array:
	var dir := Grid.line_dir(from, to)
	return range(Grid.cheb(from, to) if dir != Vector2i.ZERO else 1).map(
		func(k): return from + dir * k
	)


## The copies `passes` leave, as {at, glyph, color, born}, from the creatures
## in `actors` (id -> Actor), drawn as they look; none from an id of `hidden`.
static func copies(
	passes: Array, actors: Dictionary, born: float, hidden := {}
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in passes:
		if actors.has(p.id) and not hidden.has(p.id):
			var a: Actor = actors[p.id]
			var glyph := Lang.t(Bestiary.info(Guise.looks(a)).glyph, "creature")
			out.append({at = p.at, glyph = glyph, color = Palette.glyph_color(a), born = born})
	return out


## Draws `ghosts` at time `now`, each fading out over LIFE.
static func draw(t: Term, ghosts: Array[Dictionary], now: float) -> void:
	for g in ghosts:
		var k: float = 1.0 - (now - g.born) / LIFE
		if k <= 0.0 or not t.in_view(g.at):
			continue
		t.draw_rect(Rect2(t.cell_of(g.at) * Term.CELL, Term.CELL), Color(Palette.VOID, 0.5 * k))
		t.draw_glyph(t.cell_of(g.at), g.glyph, Color(g.color, OPACITY * k))
