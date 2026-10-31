class_name Tiles
extends RefCounted
## What each kind of tile is: one row per kind, and every rule that tests a
## tile kind reads its row. A column a row leaves out takes its value from
## DEFAULT.
##
## name, health: what the hover text calls it, and the hits it takes to break.
## walk: creatures can stand here (a closed door counts, for paths: whoever
## walks into it opens it). sight, light: it blocks sight, it lets light
## through. burns, burns_to: fire can take it, and what it is once burnt.
## breaks_to: what a hit leaves of it (the outermost ring of the map never
## breaks). tread: [how far a step onto it is heard, the word for it].
## knock: Miho knocks it by walking into it. wall: a wall, cracked or not.

const ROWS := {
	World.FLOOR: {name = "바닥", walk = true},
	World.WALL:
	{
		name = "벽",
		health = 2,
		sight = true,
		light = false,
		wall = true,
		breaks_to = World.WALL_CRACKED,
	},
	World.DOOR:
	{name = "문", health = 1, walk = true, sight = true, burns = true, breaks_to = World.FLOOR},
	World.LANTERN: {name = "등불", health = 1, knock = true, breaks_to = World.LANTERN_OUT},
	World.LANTERN_OUT: {name = "꺼진 등불", health = 1, knock = true, breaks_to = World.LANTERN_BROKEN},
	World.BAMBOO:
	{
		name = "대숲",
		walk = true,
		sight = true,
		light = false,
		burns = true,
		tread = [2, "사각"],
	},
	World.BOARD: {name = "마루", walk = true, burns = true, tread = [3, "삐걱"]},
	World.POND: {name = "연못"},
	World.ASH: {name = "재", walk = true},
	World.LANTERN_BROKEN: {name = "부서진 등불", walk = true},
	World.WALL_CRACKED:
	{
		name = "금 간 벽",
		health = 1,
		sight = true,
		light = false,
		wall = true,
		breaks_to = World.RUBBLE,
	},
	World.RUBBLE: {name = "무너진 벽", walk = true},
	World.SKY: {name = "하늘"},
	World.WINDOW: {name = "창문", health = 1, knock = true, breaks_to = World.FLOOR},
	World.BRIDGE: {name = "하늘다리", walk = true, tread = [3, "삐걱"]},
	World.DOOR_OPEN: {name = "열린 문", walk = true, burns = true},
	World.DRUM: {name = "북", health = 1, knock = true, burns = true, breaks_to = World.DRUM_TORN},
	World.DRUM_TORN: {name = "찢어진 북", walk = true},
}
const DEFAULT := {
	name = "",
	health = 0,
	walk = false,
	sight = false,
	light = true,
	burns = false,
	burns_to = World.ASH,
	breaks_to = -1,
	tread = [0, "탁"],
	knock = false,
	wall = false,
}

## One byte per tile kind, 1 where the column holds: the tables Masks feeds to Rust.
static var walk := _flags("walk")
static var sight := _flags("sight")
static var light := _flags("light")
static var burns := _flags("burns")
static var knock := _flags("knock")
static var wall := _flags("wall")


## The value of `column` for tile kind `t`.
static func of(t: int, column: String) -> Variant:
	return ROWS.get(t, {}).get(column, DEFAULT[column])


static func _flags(column: String) -> PackedByteArray:
	return Grid.table(func(t): return of(t, column))
