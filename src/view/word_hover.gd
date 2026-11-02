class_name WordHover
extends RefCounted
## The 도감 entry of a word the pointer is over in text the map hover cannot
## reach: the detail of a 도감 page, the rows of the log and help pages, the
## detail of the spellbook, and the log over the map. The map's own hover box
## follows the pointer, so a word in it cannot be pointed at. Term draws the
## entry in a box under the pointer (Term.hint); a left click opens it (WordLink).


## The hover lines of the entry of the word under `local`, a point in the space
## of term `t`, or none.
static func at(t: Term, local: Vector2) -> Array:
	return Keywords.entry(word_at(t, local))


## The word under `local` that has an entry of its own to show, or empty: the
## entry a 도감 page shows already has none.
static func word_at(t: Term, local: Vector2) -> String:
	var cell := local / Term.CELL
	for row: Array in _rows(t):
		if row[0] == floori(cell.y):
			var word := Keywords.word_at(row[2], row[1], cell.x)
			if word != "" and Keywords.locate(word) != t.panel.get("shown", Vector2i(-1, -1)):
				return word
	return ""


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
	if t.panel.get("words", false):
		var span := PanelView.span(t)
		for k in range(span.x, mini(span.x + span.y, t.panel.rows.size())):
			for j in PanelView.stride:
				out.append([3 + (k - span.x) * PanelView.stride + j, 2.0, t.panel.rows[k]])
	return out
