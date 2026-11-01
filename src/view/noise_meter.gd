class_name NoiseMeter
extends RefCounted
## The noise bar under the storey and time, like DCSS's: the loudest noise made in
## Miho's sight in the last round, as a bar of BAR_CELLS segments coloured by band,
## and no number. Band 1 stays within her sight, band 2 carries past it, band 3 is
## far and band 4 is the loudest the game makes.

## Band 1 ends where her sight does: the tiles she sees without a light.
const NEAR := World.DIM
## Band 2 ends at a thud or a gunshot, the loudest ordinary noise.
const CARRIED := World.THUD
## Band 3 ends at a cannon, louder than any shout; a drum or a gong is band 4.
const FAR := Elements.CANNON_LOUD
const BAR_CELLS := 9
## The segments each band fills; band 4 makes the bar one segment longer.
const FILLED := [0, 3, 6, 9, 10]
## Cells of the longest bar: one segment more than BAR_CELLS, half a cell each.
const BAR_WIDTH := 5.0


## Cells from the caption's start to the end of the longest bar, the caption in
## the language shown.
static func width() -> float:
	return Term._cells(Lang.t("소음")) + 0.5 + BAR_WIDTH


## How far the loudest noise in `events` is heard, in tiles, from those made on a
## tile that `vis` has seen; 0 when none.
static func level(vis: PackedByteArray, events: Array) -> int:
	var out := 0
	for e: Dictionary in events:
		if e.t == &"noise" and Perceived.sees(vis, e.at):
			out = maxi(out, e.loud)
	return out


## 0 for silence, else 1 to 4 by how far `loud` tiles carries.
static func band(loud: int) -> int:
	if loud <= 0:
		return 0
	return 1 + [NEAR, CARRIED, FAR].filter(func(edge: int) -> bool: return loud > edge).size()


## Where the caption starts, flush with the right edge: on the lower status row
## after the queue when it fits there, else on the map row above the storey.
static func at(t: Term) -> Vector2:
	var x := t.cols - width()
	return Vector2(x, t.rows - (1 if x >= StatusBar.queue_x(t) + Spell.MAX_SLOTS + 0.5 else 3))


## Draws the caption and the bar.
static func draw(t: Term) -> void:
	var band_no := band(t.noise)
	var start := at(t)
	if start.y < t.rows - 2:
		t.draw_rect(
			Rect2(start * Term.CELL, Vector2(width(), 1) * Term.CELL), Color(Palette.VOID, 0.85)
		)
	t._text(start, Lang.t("소음"), Palette.TEXT)
	var cell := Term.CELL
	for i in maxi(BAR_CELLS, FILLED[band_no]):
		var seg := (
			((start + Vector2(Term._cells(Lang.t("소음")) + 0.5 + i * 0.5, 0)) * cell).round()
			+ Vector2(2, cell.y * 0.35)
		)
		var color: Color = Palette.DIM if i >= FILLED[band_no] else Palette.NOISE[band_no - 1]
		t.draw_rect(Rect2(seg, Vector2(cell.x * 0.5 - 4, cell.y * 0.3)), color)
