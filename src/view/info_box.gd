class_name InfoBox
extends RefCounted
## Where a hover's lines go in a room of cells. They stay in one column at full
## size when they fit. Otherwise the box flows into more columns, then shrinks
## to the smallest readable text. Only a hover that still does not fit has its
## wide lines broken and shrinks further, so every line is drawn whole inside
## the room.

## Space between two columns, in cells.
const GAP := 1.0
## The smallest size of a cell, as a share of CELL on the screen, in which text
## is easy to read.
const READABLE := 0.5
const SHRINK := 0.05
const SMALLEST := 0.2


## {scale, cells, columns}: the box is `cells` of its own, drawn at `scale`, so
## it takes cells * scale of the room. `columns` are [x, lines] in box cells,
## their lines together all the lines in order; text starts 0.5 cell inside.
## `least` is the smallest scale that is still readable. The largest scale that
## fits wins, then the fewest columns.
static func layout(lines: Array, room: Vector2, least := READABLE) -> Dictionary:
	var fit := _fit(lines, room, least)
	if not fit.is_empty():
		return fit
	var limit := room.x / least - 1.0
	var rows := []
	for line: Array in lines:
		rows.append_array(Codex.flow([line], limit) if _width(line) > limit else [line])
	return _fit(rows, room, SMALLEST)


## `rows` in the fewest columns at the largest scale down to `least` that fit
## `room`, or nothing.
static func _fit(rows: Array, room: Vector2, least: float) -> Dictionary:
	var widths := rows.map(_width)
	for k in ceili((1.0 - least) / SHRINK) + 1:
		var scale := 1.0 - k * SHRINK
		for n in range(1, rows.size() + 1):
			var height := ceili(rows.size() / float(n))
			var columns := []
			var x := 0.5
			for first in range(0, rows.size(), height):
				columns.append([x, rows.slice(first, first + height)])
				x += widths.slice(first, first + height).max() + GAP
			var cells := Vector2(x - GAP + 0.5, height)
			if cells.x * scale <= room.x and cells.y * scale <= room.y:
				return {scale = scale, cells = cells, columns = columns}
	return {}


static func _width(line: Array) -> float:
	return line.reduce(func(n, r): return n + Term._cells(r[0]), 0.0)
