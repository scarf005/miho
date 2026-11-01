class_name WordHover
extends RefCounted
## The 도감 entry of a word the pointer is over in text the map hover cannot
## reach: the detail of a 도감 page, the rows of a panel, and the log over the
## map. The map's own hover box follows the pointer, so a word in it cannot be
## pointed at. Term draws the entry in the same box (Term.hint).


## The hover lines of the entry of the word under `local`, a point in the space
## of term `t`, or none.
static func at(t: Term, local: Vector2) -> Array:
	var cell := local / Term.CELL
	for row: Array in _rows(t):
		if row[0] == floori(cell.y):
			var lines := Keywords.entry_at(row[2], row[1], cell.x)
			if not lines.is_empty():
				return lines
	return []


## What `t` shows as text, as [screen row, column of the first run, runs].
static func _rows(t: Term) -> Array:
	var out := []
	if t.panel.is_empty():
		if t.replay or not t.banner_lines.is_empty():
			return out
		return t.log_rows()
	var aside: Array = t.panel.get("aside", [])
	for k in aside.size():
		out.append([3 + k, t.panel.aside_x, aside[k]])
	var detail: Array = t.panel.get("detail", [])
	for k in detail.size():
		out.append([t.rows - detail.size() + k, 2.0, detail[k]])
	if aside.is_empty():
		var span := PanelView.span(t)
		for k in range(span.x, mini(span.x + span.y, t.panel.rows.size())):
			out.append([3 + k - span.x, 2.0, t.panel.rows[k]])
	return out
