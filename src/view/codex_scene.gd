class_name CodexScene
extends RefCounted
## The example beside an entry of the 도감 (CodexSim) as data: a small lit hall,
## who stands where in it, and the actions Miho takes. `build` makes it a real World
## with its own seed, and `actions` the actions for World.act, so what the example
## shows comes from the rules alone. An entry with no row has no example. A creature's example
## has a part for its strike and for each of its spells at a rank (`foe`).
##
## A row is [map, do, cards]; `do` and `cards` may be left out. The map's rows are
## parted by "/" and centred in the hall's height, column 0 at the hall's left. It
## has a mark from MARKS, or one of:
## @ Miho, d a creature hunting her that casts nothing, i one that can sleep, z one at
## rest, w a dull one (장승) at rest with one health, J a 장승 that casts once it sees her, m the
## creature the row is for, hunting her and casting nothing, g a 천하대장군 that does the same
## and stays where it stands, D a jar with a doll that puts on her the curse the row is
## for (`_doll`), t the tile the row is for, * burning floorboards, ^ burning straw, h and
## H hot ground of Compounds.HOT, 0 to 4 thick gas of that Gas kind, E the elixir, P a
## peach, K kimchi, S a scroll. A jar the row is for holds kimchi.
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
## The spell a copy of Miho casts in an example (Bunsin).
const IMPRINT: Array[StringName] = [Cards.FOX, Cards.FIRE]
const MIHO_HP := 9
## The cooldown of a creature that casts nothing while the example lasts.
const NEVER := 99
const CASTS := "c..."
const EAST := Vector2i(1, 0)
## Columns between the hall's left and a map's column 0: the action sits in the middle.
const LEFT := 1
## The column of a map where Miho stands, and so the first of her hall.
const ME := 2
const MARKS := {
	"#": World.WALL,
	"~": World.POND,
	"_": World.SKY,
	",": World.GRASS,
	";": World.STRAW,
	"l": World.LANTERN_OUT,
}
const HUNTER := "  @      m"
## A creature that walks to Miho and strikes, one that strikes where it stands, and one that
## casts at her.
const STRIKES := "  @  m"
const BESIDE := "  @m"
## How a creature moves that does not come up to Miho to strike.
const STAYS_OFF := [&"static", &"water", &"align"]
const AIMS := "  @   m"
const WATCHES := "........"
## What Miho does before a creature whose spell homes, so that its shot turns after her.
const DODGES := "^v^v^v^v"
const BURNS := "   ttt/  @ttt/   ttt"
const KNOCKS := "  @t"
const WALKS := "  @ttt"
const SHOT := "  @   d"
const NEAR := "  @  d"
## 사령술: she fells one, and what rises goes at the next.
const RISES := "  @ w    d"
## 용광로: she stands on a strip of land across a pond, where the furnace can only be put in
## line with the creature, near enough for its orbs to burst on it.
const POND_ROWS := "~~~~~~~~~~~~~/~~~~~~~~~~~~~/~~~~~~~~~~~~~/"
const CAUSEWAY := POND_ROWS + "~~~@     g~~~/" + POND_ROWS + "~~~~~~~~~~~~~"
const TABLE := {
	Guise.SHADOW: ["  @     d", "s..."],
	Guise.GUISE: ["  @w", ">s.."],
	&"wet": ["  @ d", CASTS, [Cards.WATER]],
	&"alight": [SHOT, CASTS, [Cards.FOX, Cards.FIRE]],
	&"frozen": [NEAR, CASTS, [Cards.METAL, Cards.WATER]],
	"묶임": [NEAR, CASTS, [Cards.FOX, Cards.WOOD]],
	"기절": [NEAR, CASTS, [Cards.FOX, Cards.EARTH]],
	"경계": ["  @    z", CASTS, [Cards.METAL]],
	"둔갑": ["  @w", ">s..", Guise.RECIPE[Guise.GUISE]],
	"쇠발톱": ["  @d", "s>>", Guise.RECIPE[Guise.TALON]],
	"은신": ["  @     d", "s...", Guise.RECIPE[Guise.CLOAK]],
	Guise.FLAME: ["  @  d", "sc..", Guise.RECIPE[Guise.FLAME]],
	"불여우": ["  @  d", "sc..", Guise.RECIPE[Guise.FLAME]],
	Guise.RAISE: [RISES, "s>>...."],
	Guise.CLOAK: ["  @     d", "s..."],
	Cards.VAULT: ["  @__", "c..."],
	&"magpie": ["   ________/  @________/   ________", "c>>>>>>>>"],
	Forge.FURNACE: [CAUSEWAY, "c......"],
	&"thunder": ["      w/  @  w  w/      w", "c..."],
	Guise.NAME[Guise.RAISE]: [RISES, "s>>....", Guise.RECIPE[Guise.RAISE]],
	Curse.NAME[Curse.REAPER]: ["  @D", CASTS, [Cards.ORB]],
	Curse.NAME[Curse.SIGHT]: ["  @D J", "c..", [Cards.ORB]],
	Curse.NAME[Curse.BODY]: ["  @D", CASTS, [Cards.ORB]],
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
}


## The scene of table row `key`, its cards `cards` unless the row names its own, or
## empty when there is no row.
static func of(key: Variant, cards := []) -> Dictionary:
	var row: Array = TABLE.get(key, [])
	if row.is_empty():
		return {}
	return {
		key = key,
		map = row[0],
		cards = row[2] if row.size() > 2 else cards,
		do = row[1] if row.size() > 1 else CASTS,
	}


## The example of creature `kind` at rank `rank`: its strike, each of its spells at that rank,
## and for one with neither, or none to strike with that moves, how it walks up to Miho.
static func foe(kind: StringName, rank: int) -> Dictionary:
	var spec := Bestiary.info(kind)
	var move: StringName = spec.get("move", &"static")
	var each := []
	if spec.has("melee"):
		var label := Lang.t("근접: %s") % Lang.t(spec.melee.name)
		each.append(_foe_part(kind, BESIDE if move in STAYS_OFF else STRIKES, label))
	elif move != &"static":
		each.append(_foe_part(kind, HUNTER, Lang.t("이동")))
	for cards: Array in Bestiary.casts(kind, rank):
		each.append(charged(kind, cards))
	return {key = kind, each = each}


static func _foe_part(kind: StringName, map: String, label: String) -> Dictionary:
	return {key = kind, map = map, cards = [], do = WATCHES, label = label}


## The scene of creature `kind` with `cards` charged at Miho, cast the round she waits (Mind).
static func charged(kind: StringName, cards: Array) -> Dictionary:
	var turns := Spell.make(cards).turn() > 0
	var label := Bestiary.spell(kind, cards).shown()
	return _foe_part(kind, AIMS, label).merged(
		{charged = cards, do = DODGES if turns else WATCHES}, true
	)


## The scene as a World from its start, on a storey of rank `rank`; 0 for DEPTH.
static func build(scene: Dictionary, rank := 0) -> World:
	var w := hall(rank)
	var rows: PackedStringArray = scene.map.split("/")
	var top := HALL.position.y + (HALL.size.y - rows.size()) / 2
	for y in rows.size():
		for x in rows[y].length():
			_place(w, scene.key, rows[y][x], Vector2i(HALL.position.x + LEFT + x, top + y))
	if scene.has("charged"):
		var by: Actor = w.actors.back()
		by.magic.intent.assign([{cards = scene.charged, dir = -EAST}])
	w.known.resize(w.tiles.size())
	w.known.fill(1)
	w.sense()
	return w


## The empty hall on a storey of rank `rank` (0 for DEPTH), Miho in it where a map's
## "@" stands unless the map moves her.
static func hall(rank := 0) -> World:
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
	me.pos = HALL.position + Vector2i(LEFT + ME, HALL.size.y / 2)
	me.magic.imprint.assign(IMPRINT)
	w.start = me.pos
	w.actors.append(me)
	return w


## What the scene's Miho does, a round each.
static func actions(scene: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for letter: String in scene.do:
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


static func _place(w: World, key: Variant, mark: String, p: Vector2i) -> void:
	match mark:
		" ":
			pass
		"@":
			w.player().pos = p
			w.start = p
		"i":
			_foe(w, &"imugi", p, mark)
		"w", "J":
			_foe(w, &"jangseung", p, mark)
		"D":
			_doll(w, key, p)
		"d", "z":
			_foe(w, &"dokkaebi", p, mark)
		"g":
			_foe(w, &"cheonha", p, mark)
		"m":
			_foe(w, key, p, mark)
			if Bestiary.info(key).get("move") == &"water":
				w.set_tile(p, World.POND)
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


## A jar whose doll puts on Miho the curse named `key`, the seed moved on until the dice pick it.
## The hall is as the curse shows there: the reaper's omen told, or the lanterns out.
static func _doll(w: World, key: Variant, p: Vector2i) -> void:
	w.set_tile(p, World.JAR)
	w.jars[p] = &"effigy"
	var curse: StringName = Curse.NAME.find_key(key)
	if curse == Curse.REAPER:
		w.round_no = World.REAPER_OMEN
	elif curse == Curse.SIGHT:
		for at in LANTERNS:
			w.set_tile(CORNER + at, World.LANTERN_OUT)
	while Curse.pick(w.clone()) != curse:
		w.rng.seed += 1


static func _foe(w: World, kind: StringName, p: Vector2i, mark: String) -> void:
	var a := FloorGen.spawn(w, kind, p)
	if mark != "J":
		a.magic.cooldown = NEVER
	if mark == "w":
		a.hp = 1
	if mark in ["d", "i", "m", "g"]:
		a.brain.alert = Actor.HUNT
		a.brain.target = w.player().pos
