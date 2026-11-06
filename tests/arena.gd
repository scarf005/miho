class_name Arena
extends RefCounted
## Small worlds that tests draw as ASCII rows instead of filling tiles by hand.

## The tile each glyph of a row stands for, the glyphs the map draws (Palette.TILES).
## `@` is Miho on a floor tile.
const LEGEND := {
	"#": World.WALL,
	".": World.FLOOR,
	"@": World.FLOOR,
	"+": World.DOOR,
	"¤": World.LANTERN,
	'"': World.BAMBOO,
	"~": World.POND,
	"░": World.SKY,
	"◎": World.DRUM,
}


## A Grid.W x Grid.H world of wall with `rows` drawn from `at` down and right, as one room.
## The one `@` is Miho (3 health, no buffs). Every tile is known and seen, depth is 5, she
## has 9 tails and every talisman. Creatures and other state are the caller's.
static func from(rows: Array, at := Vector2i(1, 1)) -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	var width := 0
	for y in rows.size():
		var row: String = rows[y]
		width = maxi(width, row.length())
		for x in row.length():
			var p := at + Vector2i(x, y)
			w.tiles[Grid.index(p)] = LEGEND[row[x]]
			if row[x] == "@":
				_miho(w, p)
	w.rooms = [Rect2i(at, Vector2i(width, rows.size()))]
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.seen = w.known.duplicate()
	w.dim.resize(w.tiles.size())
	w.depth = 5
	w.tails = 9
	w.cards.assign(Cards.ALL)
	return w


## An open hall of floor walled at the edges, the whole map, with Miho at `me`.
static func hall(me: Vector2i) -> World:
	var rows := []
	for y in range(1, Grid.H - 1):
		var row := ""
		for x in range(1, Grid.W - 1):
			row += "@" if Vector2i(x, y) == me else "."
		rows.append(row)
	return from(rows)


static func _miho(w: World, p: Vector2i) -> void:
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = p
	w.actors.append(me)
