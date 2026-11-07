class_name ListNav
extends RefCounted
## How a list page moves, whatever the page: Up and Down step and wrap, Page
## Up and Page Down move a page and stop at the ends, Home and End jump to the
## ends. `count` rows, `fits` of them shown at once, `top` the first shown.

## Rows a wheel notch scrolls.
const WHEEL := 3
## The navs that repeat while their key is held.
const REPEATS := [
	&"up", &"down", &"left", &"right", &"page_up", &"page_down", &"tab_prev", &"tab_next"
]


## The row that nav `nav` moves `selected` to, going on past the rows in `skip`, which act on
## nothing, in the way it moved; `selected` for any other nav.
static func step(nav: StringName, selected: int, count: int, fits: int, skip := []) -> int:
	var at := _moved(nav, selected, count, fits)
	var dir := -1 if nav in [&"up", &"page_up", &"end"] else 1
	while skip.has(at) and skip.size() < count:
		at = posmod(at + dir, count)
	return at


static func _moved(nav: StringName, selected: int, count: int, fits: int) -> int:
	if count <= 0:
		return 0
	match nav:
		&"up":
			return posmod(selected - 1, count)
		&"down":
			return posmod(selected + 1, count)
		&"page_up":
			return maxi(0, selected - fits)
		&"page_down":
			return mini(count - 1, selected + fits)
		&"home":
			return 0
		&"end":
			return count - 1
	return selected


## The first row shown once `selected` must be in view, scrolling the least.
static func reveal(top: int, selected: int, count: int, fits: int) -> int:
	return clampi(clampi(top, selected - fits + 1, selected), 0, maxi(0, count - fits))


## The first row shown after scrolling `lines` rows, kept inside the list.
static func scrolled(top: int, lines: int, count: int, fits: int) -> int:
	return clampi(top + lines, 0, maxi(0, count - fits))
