class_name WordHover
extends RefCounted
## The 도감 entry of a word the pointer is over in text on the screen: the detail
## of a 도감 page, the rows of the log and help pages, the detail of the spellbook,
## the log over the map, and a hover box that Shift keeps (`hold`). An open hover
## box follows the pointer and closes when it leaves the thing, so only a kept one
## can be pointed into. Term draws the entry in a box under the pointer
## (Term.hint); a left click opens it (WordLink).


## The hover lines of the entry of the word under `local`, a point in the space
## of term `t`, or none.
static func at(t: Term, local: Vector2) -> Array:
	return Keywords.entry(word_at(t, local))


## The word under `local` that has an entry of its own to show, or empty: the
## entry a 도감 page shows already has none. Over a kept box only its words count.
static func word_at(t: Term, local: Vector2) -> String:
	if on_pin(t, local):
		return _pin_word(t, local)
	var cell := local / Term.CELL
	for row: Array in _rows(t):
		if row[0] == floori(cell.y):
			var word := Keywords.word_at(row[2], row[1], cell.x)
			if word != "" and Keywords.locate(word) != t.panel.get("shown", Vector2i(-1, -1)):
				return word
	return ""


## Whether `local` is over the box Shift keeps.
static func on_pin(t: Term, local: Vector2) -> bool:
	return (
		not t.pin.is_empty()
		and Rect2(t.pin.fit.at, t.pin.fit.cells * t.pin.fit.scale).has_point(local / Term.CELL)
	)


## Shift down keeps the hover box that is open as it is, whatever the pointer
## crosses, and its words show their entries and link. Shift up lets it go, as
## does anything that acts: a key, a click off the box, a round.
static func hold(m: Node, down: bool) -> void:
	var t: Term = m.term
	if down:
		var on_map := not t.info.is_empty()
		var lines: Array = t.info if on_map else t.hint
		if lines.is_empty() or not t.pin.is_empty():
			return
		var box := {
			lines = lines,
			fit = t.info_fit() if on_map else t.hint_fit(),
			word = t.subject if on_map else ""
		}
		if not on_map:
			t.hint = []
		t.pin = box
	elif not t.pin.is_empty():
		t.pin = {}
		m._point(m._mouse())
		if m.state == &"play" and not m.busy:
			m._refresh()


## The word under `local` in the kept box: its columns are `fit.scale` times the
## size of a cell, from `fit.at`.
static func _pin_word(t: Term, local: Vector2) -> String:
	var fit: Dictionary = t.pin.fit
	var cell: Vector2 = (local / Term.CELL - fit.at) / fit.scale
	for column: Array in fit.columns:
		var k := floori(cell.y)
		if k >= 0 and k < column[1].size():
			var word := Keywords.word_at(column[1][k], column[0], cell.x)
			if word != "":
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
