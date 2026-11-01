class_name PanelView
extends RefCounted
## The full-screen list over the game (Term.panel): how it is drawn, how many
## entries fit, and which row, tab or detail a point in the term's space is on.

## Narrower than this many cells, the tabs start at the left edge and the title is left out.
const TAB_COLS := 32
const TABS_FROM := 6.0
const TABS_NARROW := 0.5
## Rows between two entries of a list; more than 1 on a touch screen, so a finger
## can pick one.
static var stride := 1


## Rows of cells that the list and the detail beside it hold under a detail of
## `detail` lines.
static func lines_fit(screen_rows: int, detail: int) -> int:
	return maxi(1, screen_rows - 4 - (detail + 1 if detail > 0 else 0))


## Entries of the list that fit.
static func fits(screen_rows: int, detail: int) -> int:
	return maxi(1, lines_fit(screen_rows, detail) / stride)


## Entries of the panel that fit, and the first one shown (`top`).
static func span(t: Term) -> Vector2i:
	var fit := fits(t.rows, t.panel.get("detail", []).size())
	var count: int = t.panel.rows.size()
	return Vector2i(clampi(t.panel.get("top", 0), 0, maxi(0, count - fit)), fit)


static func _tabs_at(t: Term) -> float:
	return TABS_FROM if t.cols >= TAB_COLS else TABS_NARROW


static func draw(t: Term) -> void:
	var panel: Dictionary = t.panel
	var cols := t.cols
	var rows := t.rows
	t.draw_rect(
		Rect2(Vector2.ZERO, t.size),
		Color(Palette.VOID, 1.0 if panel.get("opaque", false) else 0.92)
	)
	var detail: Array = panel.get("detail", [])
	for k in detail.size():
		var y := rows - detail.size() + k
		var x := 2.0
		for run: Array in detail[k]:
			x += t._run(Vector2(x, y), run)
	if cols >= TAB_COLS or panel.get("tabs", []).is_empty():
		t._text(Vector2(2, 1), panel.title, Palette.KIND[&"miho"])
	var tab_x := _tabs_at(t)
	for k in panel.get("tabs", []).size():
		t._text(Vector2(tab_x, 1), panel.tabs[k], Palette.TEXT if k == panel.tab else Palette.DIM)
		tab_x += t._cells(panel.tabs[k]) + 1.0
	var aside_x: float = panel.get("aside_x", cols)
	for k in panel.get("aside", []).size():
		var x := aside_x
		for run: Array in panel.aside[k]:
			x += t._run(Vector2(x, 3 + k), run)
	if panel.get("aside_up", false):
		t._glyph(Vector2(cols - 2, 2), "▲", Palette.DIM)
	if panel.get("aside_down", false):
		t._glyph(Vector2(cols - 2, rows - 1), "▼", Palette.DIM)
	var shown := span(t)
	for k in range(shown.x, mini(shown.x + shown.y, panel.rows.size())):
		var y := 3 + (k - shown.x) * stride
		if k == panel.get("selected", -1) or k == panel.get("hover", -1):
			t.draw_rect(
				Rect2(
					Vector2(1, y) * Term.CELL, Vector2(minf(aside_x, cols) - 2, stride) * Term.CELL
				),
				Color(Palette.TEXT, 0.15 if k == panel.get("selected", -1) else 0.07)
			)
		var x := 2.0
		for run: Array in panel.rows[k]:
			x = Keywords.column(run, x)
			x += t._run(Vector2(x, y + (stride - 1) / 2.0), run)
	if shown.x > 0:
		t._glyph(Vector2(1, 2), "▲", Palette.DIM)
	if shown.x + shown.y < panel.rows.size():
		t._glyph(Vector2(1, 3 + shown.y * stride), "▼", Palette.DIM)


## The panel row under a point in the term's space, or -1 (the detail beside the
## list holds no rows).
static func row_at(t: Term, local: Vector2) -> int:
	if t.panel.is_empty() or aside_at(t, local):
		return -1
	var shown := span(t)
	var k := floori((local.y / Term.CELL.y - 3.0) / stride) + shown.x
	return k if k >= shown.x and k < mini(shown.x + shown.y, t.panel.rows.size()) else -1


## The panel tab under a point in the term's space, or -1. With rows apart the
## strip is as tall as the rows above the list.
static func tab_at(t: Term, local: Vector2) -> int:
	var x := _tabs_at(t)
	var row := floori(local.y / Term.CELL.y)
	for k in t.panel.get("tabs", []).size():
		var width: float = t._cells(t.panel.tabs[k]) + 1.0
		var on_strip := row == 1 or (stride > 1 and row >= 0 and row <= 2)
		if on_strip and local.x / Term.CELL.x >= x and local.x / Term.CELL.x < x + width:
			return k
		x += width
	return -1


## Whether a point in the term's space is over the panel's detail.
static func aside_at(t: Term, local: Vector2) -> bool:
	return not t.panel.is_empty() and local.x / Term.CELL.x >= t.panel.get("aside_x", t.cols)
