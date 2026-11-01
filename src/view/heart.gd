class_name Heart
extends RefCounted
## The pixel heart Term draws for health, full or as an outline.

const FULL := [
	".##...##.",
	"####.####",
	"#########",
	"#########",
	".#######.",
	"..#####..",
	"...###...",
	"....#...."
]
const EMPTY := [
	".##...##.",
	"#..#.#..#",
	"#...#...#",
	"#.......#",
	".#.....#.",
	"..#...#..",
	"...#.#...",
	"....#...."
]


## A heart filling the cell `at` of `t`, full or as an outline.
static func draw(t: Term, at: Vector2, full: bool, color: Color) -> void:
	var rows: Array = FULL if full else EMPTY
	var px := 3.0
	var from := at * Term.CELL + (Term.CELL - Vector2(rows[0].length(), rows.size()) * px) / 2.0
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				t.draw_rect(Rect2((from + Vector2(x, y) * px).round(), Vector2(px, px)), color)
