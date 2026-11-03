class_name PanelView
extends RefCounted
## The list over the game (Term.panel), the whole screen or a `box` of cells that leaves
## the game drawn around it: how it is drawn, how many entries fit, and which row, tab or
## detail a point in the term's space is on.

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


## The cells the panel takes: the screen, or its `box`, moved beside the creature list when it
## would hide Miho.
static func frame(t: Term) -> Rect2:
	var box: Rect2 = t.panel.get("box", Rect2(0, 0, t.cols, t.rows))
	if t.panel.has("box") and t.world != null and box.has_point(t._cell(t.world.player().pos)):
		box.position.x = minf(t.side.x, box.position.x)
	return box


## Entries of the panel that fit, and the first one shown (`top`).
static func span(t: Term) -> Vector2i:
	var fit := fits(int(frame(t).size.y), t.panel.get("detail", []).size())
	var count: int = t.panel.rows.size()
	return Vector2i(clampi(t.panel.get("top", 0), 0, maxi(0, count - fit)), fit)


static func _tabs_at(t: Term) -> float:
	return TABS_FROM if t.cols >= TAB_COLS else TABS_NARROW


static func draw(t: Term) -> void:
	var panel: Dictionary = t.panel
	var box := frame(t)
	var cols := int(box.size.x)
	var rows := int(box.size.y)
	if panel.has("box"):
		var outline := Rect2(Vector2.ZERO, box.size * Term.CELL)
		t.draw_set_transform(box.position * Term.CELL, 0.0, Vector2.ONE)
		t.draw_rect(outline, Palette.VOID)
		t.draw_rect(outline.grow(-1), Palette.DIM, false, 2.0)
	else:
		t.draw_rect(Rect2(Vector2.ZERO, t.size), Palette.VOID)
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
	_draw_choices(t, panel.get("choices", {}))
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
	t.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The parts of an example to pick from, one under another beneath it, with the keys.
static func _draw_choices(t: Term, choices: Dictionary) -> void:
	if choices.is_empty():
		return
	var last: int = mini(choices.top + choices.fit, choices.names.size())
	for k in range(choices.top, last):
		var at: Vector2 = choices.from + Vector2(0, k - choices.top)
		if k == choices.at or k == choices.lit:
			var alpha := 0.15 if k == choices.at else 0.07
			t.draw_rect(
				Rect2(at * Term.CELL, Vector2(t.cols - at.x, 1) * Term.CELL),
				Color(Palette.TEXT, alpha)
			)
		t._text(at, choices.names[k], Palette.TEXT if k == choices.at else Palette.DIM)
	if choices.top > 0:
		t._glyph(choices.from - Vector2(1, 0), "▲", Palette.DIM)
	if last < choices.names.size():
		t._glyph(choices.from + Vector2(-1, choices.fit - 1), "▼", Palette.DIM)
	var keys: Vector2 = (
		choices.from + Vector2(t.cols - choices.from.x - 2.0, choices.at - choices.top)
	)
	t._key(keys, "[", Palette.DIM)
	t._key(keys + Vector2(1, 0), "]", Palette.DIM)


## The part of an example under a point in the term's space, or -1.
static func choice_at(t: Term, local: Vector2) -> int:
	var choices: Dictionary = t.panel.get("choices", {})
	if choices.is_empty():
		return -1
	var k := floori(local.y / Term.CELL.y - choices.from.y) + int(choices.top)
	var last: int = mini(choices.top + choices.fit, choices.names.size())
	var on: bool = local.x / Term.CELL.x >= choices.from.x and k >= choices.top and k < last
	return k if on else -1


## The column where a line of runs that starts at `x` ends.
static func end(line: Array, x := 2.0) -> float:
	for run: Array in line:
		x = Keywords.column(run, x)
		x += Term._key_cells(run[0]) if run.slice(2).has(&"key") else Term._cells(run[0])
	return x


## The panel row under a point in the term's space, or -1 (the detail beside the
## list holds no rows).
static func row_at(t: Term, local: Vector2) -> int:
	if t.panel.is_empty() or aside_at(t, local):
		return -1
	var box := frame(t)
	if t.panel.has("box") and not box.has_point(local / Term.CELL):
		return -1
	var shown := span(t)
	var k := floori((local.y / Term.CELL.y - box.position.y - 3.0) / stride) + shown.x
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


## Whether a point in the term's space is over the panel's detail, beside the list or under it.
static func aside_at(t: Term, local: Vector2) -> bool:
	if t.panel.is_empty():
		return false
	var under: int = t.rows - t.panel.get("detail", []).size()
	return local.x / Term.CELL.x >= t.panel.get("aside_x", t.cols) or local.y / Term.CELL.y >= under
