class_name CodexScene
extends RefCounted
## The example beside an entry of the 도감 (CodexSim) as data: a small lit hall,
## who stands where in it, and the actions Miho takes. `build` makes it a real World
## with its own seed, and `actions` the actions for World.act, so what the example
## shows comes from the rules alone. An entry with no row has no example.
##
## A row is [map, do, cards]; `do` and `cards` may be left out. The map's rows are
## parted by "/" and centred in the hall's height, column 0 at the hall's left. It
## has a mark from MARKS, or one of:
## @ Miho, d a creature hunting her that casts nothing, i one that can sleep, z one at
## rest, w one at rest with one health, k the creature the row is for, t the tile the row is for,
## * burning floorboards, ^ burning straw, h and H hot ground of Compounds.HOT, 0 to
## 4 thick gas of that Gas kind, E the elixir, P a peach, K kimchi, S a scroll. A jar
## the row is for holds kimchi.
## `do` is a round for each letter: c casts the cards east, s casts them on Miho,
## > steps east, ^ north, v south, . waits, x shuts the door to the east.

## The map tiles in the window the example draws, and the first of them. The hall
## is the window less its ring of walls, far from the map's own edge, whose walls never
## break.
const VIEW := Vector2i(15, 9)
const CORNER := Vector2i(20, 9)
const HALL := Rect2i(CORNER + Vector2i.ONE, VIEW - Vector2i(2, 2))
## Where the hall's lanterns stand in the ring, in the window.
const LANTERNS: Array[Vector2i] = [Vector2i(4, 0), Vector2i(10, 0), Vector2i(4, 8), Vector2i(10, 8)]
const SEED := 1
## The storey of an example: a creature there outlasts most spells, so what the
## spell does to it stays in sight. Tails pay for any spell in the table.
const DEPTH := 5
const TAILS := 9
const MIHO_HP := 9
## The cooldown of a creature that casts nothing while the example lasts.
const NEVER := 99
const CASTS := "c..."
const EAST := Vector2i(1, 0)
## Columns between the hall's left and a map's column 0: the action sits in the middle.
const LEFT := 1
const MARKS := {
	"#": World.WALL,
	"~": World.POND,
	"_": World.SKY,
	",": World.GRASS,
	";": World.STRAW,
	"l": World.LANTERN_OUT,
}
const HUNTER := "  @      k"
const WATCHES := "........"
## What Miho does before a creature whose spell homes, so that its shot turns after her.
const DODGES := "^v^v^v^v"
const BURNS := "   ttt/  @ttt/   ttt"
const KNOCKS := "  @t"
const WALKS := "  @ttt"
const SHOT := "  @   d"
const NEAR := "  @  d"
const TWO := "  @  d/     d"
const COLUMN := "      #/      #/      #/  @   #/      #/      #/      #"
const LEAPS := "   ~~/  @~~/   ~~"
const FAN := "   ;;;;;/  @;;d;;/   ;;;;;"
const TABLE := {
	Cards.FOX: [SHOT],
	Spell.WISP: [SHOT],
	Cards.ORB: ["  @    d"],
	Spell.HOMING: ["        d//  @"],
	Spell.LEAP: [LEAPS, "c.."],
	Cards.VAULT: [LEAPS, "c.."],
	Spell.SPRAY: [FAN],
	Cards.FIRE: [FAN],
	Cards.WATER: ["  @ * d"],
	Cards.WOOD: [SHOT],
	Cards.METAL: [SHOT],
	Cards.EARTH: ["  @d"],
	&"fox+metal": [SHOT],
	&"fox+metal+metal": ["  @ d d #"],
	&"orb+earth+metal": ["  @    d/       d"],
	Guise.SHADOW: ["  @     d", "s..."],
	Guise.GUISE: ["  @w", ">s.."],
	Guise.TALON: ["  @d", "s>>"],
	Guise.CLOAK: ["  @     d", "s..."],
	&"wildfire": ["   ,,,,/  @,d,,/   ,,,,"],
	&"lava": [SHOT],
	&"shrapnel": ["     d/  @  d/     d"],
	&"frost": ["  @~~ d"],
	&"rain": ["    **/  @  d/    **"],
	&"steam": [NEAR],
	&"molten": [SHOT],
	&"thorn": ["  @ d"],
	&"rift": ["    #/    #/    #/  @ #   d/    #/    #/    #", "c...."],
	&"mud": ["  @    d", "c...."],
	&"volcano": [NEAR],
	&"furnace": [COLUMN],
	&"hail": [TWO],
	&"frostbloom": ["    ~/  @  d/    ~"],
	&"swamp": ["       #/       #/  @  d #/       #/       #"],
	&"geyser": ["  @ d"],
	&"palisade": ["  @     d", "c....."],
	&"beacon": ["   l    ,,,/  @     ,d,/        ,,,"],
	&"bind": ["  @    d/      d"],
	&"magpie": ["     ~~/     ~~/     ~~/  @  ~~   d/     ~~/     ~~/     ~~", "c....."],
	&"hypnosis": ["  @   i"],
	&"mist": [SHOT],
	&"sinkhole": [NEAR],
	&"newmoon": ["  @   *  d"],
	&"discord": ["  @   d/      d", "c....."],
	&"thunder": ["  @  d d"],
	&"stillness": ["    #/    #/  @ #  d/    #/    #"],
	Cards.SAMSARA: [SHOT],
	Cards.CONQUEST: [TWO],
	Cards.DRAGON: ["     @d #"],
	&"wet": ["  @ d", CASTS, [Cards.WATER]],
	&"alight": [SHOT, CASTS, [Cards.FOX, Cards.FIRE]],
	&"frozen": [NEAR, CASTS, [Cards.METAL, Cards.WATER]],
	"묶임": [NEAR, CASTS, [Cards.FOX, Cards.WOOD]],
	"기절": [NEAR, CASTS, [Cards.FOX, Cards.EARTH]],
	"경계": ["  @    z", CASTS, [Cards.METAL]],
	"둔갑": ["  @w", ">s..", [Cards.WOOD, Cards.EARTH]],
	"쇠발톱": ["  @d", "s>>", Guise.RECIPE[Guise.TALON]],
	"은신": ["  @     d", "s...", Guise.RECIPE[Guise.CLOAK]],
	&"elixir": ["  @ E", ">>"],
	&"peach": ["  @ P", ">>."],
	Jars.KIMCHI: ["  @ K", ">>."],
	&"scroll": ["  @ S", ">>."],
	World.WALL: ["  @ t", "c..", [Cards.ORB, Cards.EARTH]],
	World.WALL_CRACKED: ["  @ t", "c..", [Cards.ORB, Cards.METAL]],
	World.DOOR: ["   #/  @t/   #", ">>>."],
	World.DOOR_OPEN: ["   #/  @t/   #", "x.."],
	World.LANTERN: [KNOCKS, ">.>."],
	World.LANTERN_OUT: [KNOCKS, "c..", [Cards.FIRE]],
	World.BAMBOO: ["   ttt/  @ttt  d/   ttt", ">>>."],
	World.BOARD: [WALKS, ">>>."],
	World.POND: ["    tt/    tt/    tt/  @ tt d/    tt/    tt/    tt", "c...", [Cards.ORB]],
	World.SKY: ["     t/  @ dt/     t", "c..", [Cards.WATER]],
	World.WINDOW: [KNOCKS, ">."],
	World.BRIDGE: ["   __/  @tt/   __", ">>>."],
	World.DRUM: [KNOCKS, ">."],
	World.GRASS: [BURNS, CASTS, [Cards.FIRE]],
	World.STRAW: [BURNS, CASTS, [Cards.FIRE]],
	World.REEDS: [BURNS, CASTS, [Cards.FIRE]],
	World.LEAVES: [WALKS, ">>>."],
	World.SHALLOW: [WALKS, ">>>."],
	World.WOOD_WALL: [KNOCKS, CASTS, [Cards.FIRE]],
	World.THORNS: [KNOCKS, ">.."],
	World.MUD: ["  @ ttt  d", "......"],
	World.TRAP_ALARM: ["  @t     z", ">.."],
	World.TRAP_COLLAPSE: ["  @ dt", "c..", [Cards.WATER]],
	World.TRAP_FIRE: ["  @t", ">..."],
	World.TRAP_VINE: ["  @t", ">.."],
	World.SCREEN: [KNOCKS, ">."],
	World.JAR: [KNOCKS, ">.>."],
	World.CENSER: [KNOCKS, ">.."],
	World.STATUE: ["  @   t", ">>..."],
	World.VEIL: ["  @ t", "c..", [Cards.METAL, Cards.WATER]],
	World.SHELF: [BURNS, CASTS, [Cards.FIRE]],
	World.BOARD_ROTTEN: [WALKS, ">>>."],
	&"burning": ["  @ ***", "...."],
	&"fierce": ["   ^;;;/  @^;;;/   ^;;;", "...."],
	&"hot0": ["  @h", ">.."],
	&"hot1": ["  @H", ">.."],
	&"gas0": ["    000/  @ 000/    000", "...."],
	&"gas1": ["    111/  @ 111/    111", "...."],
	&"gas2": ["    222/  @ 222/    222", "...."],
	&"gas3": ["    333/  @ 333/    333", "...."],
	&"gas4": ["    444/  @ 444/    444", "c..", [Cards.FOX, Cards.FIRE]],
	&"body": ["  @w", ">.."],
	&"jangseung": ["  @   k", WATCHES],
	&"dueoksini": ["  @   k", WATCHES],
}


## The scene of table row `key`, its cards `cards` unless the row names its own, or
## empty when there is no row. A creature with no row of its own hunts Miho as she waits.
static func of(key: Variant, cards := []) -> Dictionary:
	var row: Array = TABLE.get(key, [HUNTER, WATCHES] if Bestiary.KINDS.has(key) else [])
	if row.is_empty():
		return {}
	return {
		key = key,
		map = row[0],
		cards = row[2] if row.size() > 2 else cards,
		do = row[1] if row.size() > 1 else CASTS,
	}


## The scene as a World from its start, on a storey of rank `rank`; 0 for DEPTH.
static func build(scene: Dictionary, rank := 0) -> World:
	var w := World.new()
	w.rng.seed = SEED
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	w.rooms = [HALL]
	w.depth = rank * 2 - 1 if rank > 0 else DEPTH
	w.tail_bonus = maxi(0, TAILS - w.depth)
	w.tails = TAILS
	w.cards.assign(Cards.ALL)
	for y in range(HALL.position.y, HALL.end.y):
		for x in range(HALL.position.x, HALL.end.x):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	for p in LANTERNS:
		w.tiles[Grid.index(CORNER + p)] = World.LANTERN
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.max_hp = MIHO_HP
	me.hp = MIHO_HP - World.HEAL
	w.actors.append(me)
	var rows: PackedStringArray = scene.map.split("/")
	var top := HALL.position.y + (HALL.size.y - rows.size()) / 2
	for y in rows.size():
		for x in rows[y].length():
			_place(w, scene.key, rows[y][x], Vector2i(HALL.position.x + LEFT + x, top + y))
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.sense()
	return w


## What the scene's Miho does, a round each, on a storey of rank `rank`; 0 for DEPTH.
static func actions(scene: Dictionary, rank := 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var letters: String = DODGES if _homes(scene, rank) else scene.do
	for letter: String in letters:
		match letter:
			"c":
				out.append({t = &"cast", spells = [{cards = scene.cards, dir = EAST}]})
			"s":
				out.append({t = &"cast", spells = [{cards = scene.cards, dir = Vector2i.ZERO}]})
			"^":
				out.append({t = &"move", dir = Vector2i(0, -1)})
			"v":
				out.append({t = &"move", dir = Vector2i(0, 1)})
			">":
				out.append({t = &"move", dir = EAST})
			"x":
				out.append({t = &"close", dir = EAST})
			".":
				out.append({t = &"wait"})
	return out


## Whether the scene is of a creature that casts a homing spell at `rank`.
static func _homes(scene: Dictionary, rank: int) -> bool:
	if not Bestiary.KINDS.has(scene.key) or scene.do != WATCHES:
		return false
	var at := rank if rank > 0 else Bestiary.rank(DEPTH)
	return Bestiary.casts(scene.key, at).any(func(c): return Spell.make(c).turn() > 0)


static func _place(w: World, key: Variant, mark: String, p: Vector2i) -> void:
	match mark:
		" ":
			pass
		"@":
			w.player().pos = p
			w.start = p
		"i":
			_foe(w, &"imugi", p, mark)
		"d", "z", "w":
			_foe(w, &"dokkaebi", p, mark)
		"k":
			_foe(w, key, p, mark)
		"t":
			w.set_tile(p, key)
			if key == World.JAR:
				w.jars[p] = Jars.KIMCHI
			if Tiles.of(key, "trap"):
				w.traps[p] = key
		"*", "^":
			w.set_tile(p, World.BOARD if mark == "*" else World.STRAW)
			w.burning[p] = World.BURN_ROUNDS
		"h", "H":
			var kind := Compounds.LAVA if mark == "h" else Compounds.MOLTEN
			w.hot[p] = Vector2i(kind, Compounds.HOT_ROUNDS)
		"E":
			w.elixir = p
		"P":
			w.peaches.append(p)
		"K":
			w.sites.append({kind = Jars.KIMCHI, at = p})
		"S":
			w.sites.append({kind = &"scroll", at = p, card = Cards.FIRE})
			w.cards.erase(Cards.FIRE)
		_:
			if MARKS.has(mark):
				w.set_tile(p, MARKS[mark])
			else:
				Gas.put(w, p, int(mark), Gas.MAX)


static func _foe(w: World, kind: StringName, p: Vector2i, mark: String) -> void:
	var a := FloorGen.spawn(w, kind, p)
	if mark != "k":
		a.cooldown = NEVER
	if mark == "w":
		a.hp = 1
	if mark in ["d", "i", "k"]:
		a.alert = Actor.HUNT
		a.target = w.player().pos
