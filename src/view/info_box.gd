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


## The layout of `lines` in a box right under row `cell.y` of `room`, starting at
## column `cell.x` and moved left to stay inside it; above the row when there is
## more room there. It never covers the row. {scale, cells, columns, at}, `at`
## the cell of the box's top-left corner.
static func beside(lines: Array, room: Rect2, cell: Vector2i, least := READABLE) -> Dictionary:
	var below := Rect2(room.position.x, cell.y + 1, room.size.x, room.end.y - cell.y - 1)
	var above := Rect2(room.position, Vector2(room.size.x, cell.y - room.position.y))
	var fits := [below, above].map(
		func(r: Rect2) -> Dictionary: return layout(lines, r.size, least) if r.size.y >= 1.0 else {}
	)
	var up: bool = fits[0].is_empty() or (not fits[1].is_empty() and fits[1].scale > fits[0].scale)
	var fit: Dictionary = fits[1 if up else 0]
	var r: Rect2 = above if up else below
	if fit.is_empty():
		fit = layout(lines, room.size, least)
		r = room
	var wide: Vector2 = fit.cells * fit.scale
	var x := clampf(cell.x, r.position.x, maxf(r.position.x, r.end.x - wide.x))
	return fit.merged({at = Vector2(x, r.end.y - wide.y if up else r.position.y)})


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
			var first := 0
			while first < rows.size():
				var end := _end(rows, first, height)
				columns.append([x, rows.slice(first, end)])
				x += widths.slice(first, end).max() + GAP
				first = end
			var cells := Vector2(x - GAP + 0.5, height)
			if cells.x * scale <= room.x and cells.y * scale <= room.y:
				return {scale = scale, cells = cells, columns = columns}
	return {}


## Where a column of at most `height` rows from `first` ends: never between a
## line and the indented lines under it.
static func _end(rows: Array, first: int, height: int) -> int:
	var end := mini(first + height, rows.size())
	while end < rows.size() and end > first + 1 and _indented(rows[end]):
		end -= 1
	return end


static func _indented(line: Array) -> bool:
	return not line.is_empty() and String(line[0][0]).begins_with("  ")


static func _width(line: Array) -> float:
	return line.reduce(func(n, r): return n + Term._cells(r[0]), 0.0)
