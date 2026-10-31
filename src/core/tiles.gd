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
## knock: Miho knocks it by walking into it, and `hit` is how far that is heard
## and the word for it. wall: a wall, cracked or not.
## spread: the chance each second that fire next to it takes it. douses: fire
## never takes it, even a burning creature standing on it. trample: what it
## becomes when a creature steps onto it; crumbles: what it becomes when a
## creature steps off it (Terrain.crumble). scentless: a trail laid on it is lost.
## gas: gas can lie on it (Gas); walls, closed doors, windows, pillars and sky stop it.
## trap: a plate in the floor that goes off when a creature steps onto it (Traps).
## Heaven walks round it, and so does a walk Miho has planned. It is floor, not
## this tile kind, until Miho finds it.
## opens: it shuts the way now and is gone in time (a seal opens, a veil goes
## out), so the storey is whole without it (FloorGen.connected).

const ROWS := {
	World.FLOOR: {name = "바닥", walk = true},
	World.WALL:
	{
		name = "벽",
		health = 2,
		sight = true,
		light = false,
		wall = true,
		gas = false,
		breaks_to = World.WALL_CRACKED,
	},
	World.DOOR:
	{
		name = "문",
		health = 1,
		walk = true,
		sight = true,
		burns = true,
		gas = false,
		breaks_to = World.FLOOR,
	},
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
		scentless = true,
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
		gas = false,
		breaks_to = World.RUBBLE,
	},
	World.RUBBLE: {name = "무너진 벽", walk = true},
	World.SKY: {name = "하늘", gas = false},
	World.WINDOW: {name = "창문", health = 1, knock = true, gas = false, breaks_to = World.FLOOR},
	World.BRIDGE: {name = "하늘다리", walk = true, tread = [3, "삐걱"]},
	World.DOOR_OPEN: {name = "열린 문", walk = true, burns = true},
	World.DRUM:
	{
		name = "북",
		health = 1,
		knock = true,
		burns = true,
		breaks_to = World.DRUM_TORN,
		hit = [World.KNOCK, "찌익"],
	},
	World.DRUM_TORN: {name = "찢어진 북", walk = true},
	World.GRASS: {name = "풀", walk = true, burns = true, spread = 0.15},
	World.STRAW: {name = "마른 짚", walk = true, burns = true},
	World.REEDS:
	{name = "갈대", walk = true, sight = true, tread = [2, "바스락"], trample = World.REEDS_FLAT},
	World.REEDS_FLAT: {name = "쓰러진 갈대", walk = true},
	World.LEAVES: {name = "낙엽", walk = true, burns = true, tread = [2, "바스락"]},
	World.SHALLOW: {name = "얕은 물", walk = true, tread = [2, "철벅"], douses = true, scentless = true},
	World.PILLAR: {name = "기둥", sight = true, light = false, gas = false},
	World.WOOD_WALL:
	{
		name = "나무벽",
		health = 1,
		sight = true,
		light = false,
		burns = true,
		breaks_to = World.FLOOR,
		gas = false,
	},
	World.ICE: {name = "얼음", walk = true, douses = true},
	World.THORNS: {name = "가시덤불", walk = true, burns = true},
	World.MUD: {name = "진흙", walk = true, douses = true},
	World.TRAP_ALARM: {name = "징 함정", walk = true, trap = true},
	World.TRAP_COLLAPSE: {name = "허방다리", walk = true, trap = true},
	World.TRAP_FIRE: {name = "불씨 함정", walk = true, trap = true},
	World.TRAP_VINE: {name = "덩굴 함정", walk = true, trap = true},
	World.VERANDA: {name = "쪽마루", walk = true, burns = true, tread = [3, "삐걱"]},
	World.SEAL: {name = "봉인문", sight = true, light = false, gas = false, opens = true},
	World.ALTAR: {name = "혼불 제단"},
	World.ALTAR_LIT: {name = "타오르는 제단"},
	World.VEIL: {name = "도깨비불 장막", opens = true},
	World.LAMP: {name = "석등"},
	World.TALISMAN: {name = "부적 단", walk = true},
	World.SHELF: {name = "두루마리 서가", walk = true, burns = true},
	World.SHELF_READ: {name = "읽은 서가", walk = true, burns = true},
	World.SCREEN:
	{
		name = "병풍",
		health = 1,
		sight = true,
		burns = true,
		knock = true,
		breaks_to = World.FLOOR,
		hit = [World.THUD, "쿵"],
	},
	World.JAR:
	{
		name = "장독",
		health = 1,
		knock = true,
		breaks_to = World.FLOOR,
		hit = [World.KNOCK, "쨍그랑"],
	},
	World.WATER_JAR:
	{
		name = "물독",
		health = 1,
		knock = true,
		breaks_to = World.SHALLOW,
		hit = [World.KNOCK, "쨍그랑"],
	},
	World.CENSER: {name = "향로", health = 1, knock = true, breaks_to = World.FLOOR},
	World.COURTYARD: {name = "마당", walk = true},
	World.STATUE: {name = "석상"},
	World.BOARD_ROTTEN:
	{name = "낡은 마루", walk = true, burns = true, tread = [3, "삐걱"], crumbles = World.SKY},
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
	hit = [World.KNOCK, "쨍"],
	wall = false,
	spread = 0.5,
	douses = false,
	trample = -1,
	crumbles = -1,
	scentless = false,
	gas = true,
	trap = false,
	opens = false,
}

## One byte per tile kind, 1 where the column holds: the tables Masks feeds to Rust.
static var walk := _flags("walk")
static var sight := _flags("sight")
static var light := _flags("light")
static var burns := _flags("burns")
static var knock := _flags("knock")
static var wall := _flags("wall")
static var gas := _flags("gas")
static var opens := _flags("opens")
## Walkable once everything that `opens` has.
static var reachable := Grid.table(func(t): return of(t, "walk") or of(t, "opens"))


## The value of `column` for tile kind `t`.
static func of(t: int, column: String) -> Variant:
	return ROWS.get(t, {}).get(column, DEFAULT[column])


static func _flags(column: String) -> PackedByteArray:
	return Grid.table(func(t): return of(t, column))
