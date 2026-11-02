class_name Placement
extends RefCounted
## What lies on a storey's rooms, from a table of rows (Brogue CE
## autoGeneratorCatalog). Galleries, and the goal room whose lantern must light
## the stairs, stay bare. A row has:
##
## what, on: the tile kind laid, and the one it replaces (bare floor). A row
## lays `gas` of `amount` (Gas) in place of `what`, over the tiles of kind `on`,
## and each of those tiles keeps breathing that gas (World.vents). A row with
## `vent` lays `what` and has it breathe that gas. A row with `hidden` lays a
## plate (Traps) that is `what`, but the tile stays `on` until Miho finds it. A
## row with `aside` draws from a generator of its own (see `scatter`).
## tiers: the first and last storey (1 to 9) it appears on.
## chance: the percent chance that each patch is laid.
## count: [intercept, slope, most]. A storey has (intercept + depth * slope) / 100
## patches, at most `most`; the remainder is the chance of one more.
## grow: [start, step]. A patch starts on one random tile and spreads to each of
## its four neighbours in the room with `start` percent, then on from those with
## `start - step` percent, and so on (Brogue CE spawnDungeonFeature); [0, 0] is a
## single tile.
##
## A patch that cuts the storey apart is taken out again; for plates, the storey
## must stay whole with every plate counted as a wall, since heaven walks round
## them.

const ROWS := [
	{
		what = World.GRASS,
		on = World.FLOOR,
		tiers = [1, 9],
		chance = 100,
		count = [200, 25, 5],
		grow = [80, 15],
	},
	{
		what = World.LEAVES,
		on = World.FLOOR,
		tiers = [1, 9],
		chance = 80,
		count = [100, 20, 3],
		grow = [75, 15],
	},
	{
		what = World.STRAW,
		on = World.FLOOR,
		tiers = [2, 9],
		chance = 100,
		count = [0, 50, 3],
		grow = [85, 15],
	},
	{
		what = World.REEDS,
		on = World.FLOOR,
		tiers = [1, 9],
		chance = 100,
		count = [100, 25, 3],
		grow = [75, 12],
	},
	{
		what = World.SHALLOW,
		on = World.FLOOR,
		tiers = [1, 9],
		chance = 100,
		count = [100, 15, 2],
		grow = [80, 14],
	},
	{
		what = World.PILLAR,
		on = World.FLOOR,
		tiers = [2, 9],
		chance = 100,
		count = [0, 80, 4],
		grow = [0, 0],
	},
	{
		what = World.SCREEN,
		aside = true,
		on = World.FLOOR,
		tiers = [1, 9],
		chance = 100,
		count = [50, 20, 2],
		grow = [60, 30],
	},
	{
		what = World.JAR,
		aside = true,
		on = World.FLOOR,
		tiers = [1, 9],
		chance = 100,
		count = [100, 15, 3],
		grow = [60, 30],
	},
	{
		what = World.CENSER,
		vent = Gas.INCENSE,
		aside = true,
		on = World.FLOOR,
		tiers = [2, 9],
		chance = 100,
		count = [0, 30, 2],
		grow = [0, 0],
	},
	{
		what = World.COURTYARD,
		aside = true,
		on = World.FLOOR,
		tiers = [1, 9],
		chance = 100,
		count = [50, 20, 2],
		grow = [90, 12],
	},
	{
		gas = Gas.FOG,
		amount = Gas.MAX,
		on = World.POND,
		tiers = [2, 9],
		chance = 100,
		count = [50, 25, 2],
		grow = [100, 30],
	},
	{
		what = World.TRAP_ALARM,
		hidden = true,
		on = World.FLOOR,
		tiers = [1, 9],
		chance = 100,
		count = [50, 25, 3],
		grow = [0, 0],
	},
	{
		what = World.TRAP_COLLAPSE,
		hidden = true,
		on = World.FLOOR,
		tiers = [2, 9],
		chance = 100,
		count = [0, 30, 2],
		grow = [0, 0],
	},
	{
		what = World.TRAP_FIRE,
		hidden = true,
		on = World.FLOOR,
		tiers = [3, 9],
		chance = 100,
		count = [0, 30, 2],
		grow = [0, 0],
	},
	{
		what = World.TRAP_VINE,
		hidden = true,
		on = World.FLOOR,
		tiers = [2, 9],
		chance = 100,
		count = [0, 40, 2],
		grow = [0, 0],
	},
]
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## Lays every row's patches for this storey in the rooms but `goal`.
## Plates, and the rows with `aside` (furniture), draw from generators of their
## own, seeded from the world's, so they leave the draws of everything laid
## after them as they were.
static func scatter(w: World, goal: Rect2i) -> void:
	var plates := RandomNumberGenerator.new()
	plates.seed = w.rng.state
	var furniture := RandomNumberGenerator.new()
	furniture.seed = hash(w.rng.state)
	for row: Dictionary in ROWS:
		if w.depth < row.tiers[0] or w.depth > row.tiers[1]:
			continue
		var rng := w.rng
		if row.get("hidden", false):
			rng = plates
		elif row.get("aside", false):
			rng = furniture
		for i in count(row, w.depth, rng):
			var spots := _spots(w, row, goal)
			if spots.is_empty():
				break
			if rng.randi_range(1, 100) <= row.chance:
				lay(w, row, Grid.at(spots[rng.randi_range(0, spots.size() - 1)]), rng)
	w._changed()


## How many patches of `row` storey `depth` has.
static func count(row: Dictionary, depth: int, rng: RandomNumberGenerator) -> int:
	var hundredths := maxi(0, row.count[0] + depth * row.count[1])
	var extra := 1 if rng.randi_range(0, 99) < hundredths % 100 else 0
	return mini(row.count[2], hundredths / 100 + extra)


## The tile numbers `row` may start on: free tiles of `row.on` in a room but `goal`.
static func _spots(w: World, row: Dictionary, goal: Rect2i) -> PackedInt32Array:
	var blocked: Array = w.gas.keys() + w.traps.keys() + [w.start, w.stairs, w.elixir]
	return Native.room_tiles(w.rooms, goal, w.tiles, row.on, blocked, Grid.W)


static func _free(w: World, p: Vector2i, row: Dictionary) -> bool:
	return w.tile(p) == row.on and _clear(w, p)


## Whether nothing but its kind keeps `p` from a patch: no gas or plate, not a way in or out.
static func _clear(w: World, p: Vector2i) -> bool:
	return (
		not w.gas.has(p) and not w.traps.has(p) and p != w.start and p != w.stairs and p != w.elixir
	)


static func _put(w: World, row: Dictionary, p: Vector2i) -> void:
	if row.has("gas"):
		Gas.put(w, p, row.gas, row.amount)
		w.vents[p] = row.gas
	elif row.get("hidden", false):
		w.traps[p] = row.what
	else:
		w.tiles[Grid.index(p)] = row.what
		if row.has("vent"):
			Gas.put(w, p, row.vent, Gas.VENT_LEVEL)
			w.vents[p] = row.vent


## A patch of `row` grown from `at` inside its room; the tiles laid, none when it
## would cut the storey apart. It grows with `rng`, the world's when none is given.
static func lay(
	w: World, row: Dictionary, at: Vector2i, rng: RandomNumberGenerator = null
) -> Array[Vector2i]:
	var dice := rng if rng != null else w.rng
	var room: Rect2i = w.rooms.filter(func(r: Rect2i): return r.has_point(at))[0]
	var laid: Array[Vector2i] = [at]
	var ring: Array[Vector2i] = [at]
	_put(w, row, at)
	var chance: int = row.grow[0]
	while chance > 0 and not ring.is_empty():
		var next: Array[Vector2i] = []
		for p in ring:
			for d in SIDES:
				if (
					room.has_point(p + d)
					and _free(w, p + d, row)
					and dice.randi_range(1, 100) <= chance
				):
					_put(w, row, p + d)
					next.append(p + d)
		laid.append_array(next)
		ring = next
		chance -= row.grow[1]
	if row.get("hidden", false):
		if not FloorGen.connected(w, w.traps.keys()):
			for p in laid:
				w.traps.erase(p)
			laid.clear()
	elif (
		row.has("what") and Tiles.walk[row.what] == 0 and not FloorGen.connected(w, w.traps.keys())
	):
		for p in laid:
			w.tiles[Grid.index(p)] = row.on
			w.vents.erase(p)
			w.gas.erase(p)
		laid.clear()
	return laid
