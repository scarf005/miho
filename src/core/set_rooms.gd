class_name SetRooms
extends RefCounted
## Set rooms (짜인 방): rooms made of terrain alone, no key and no prize. Unlike
## an event room (EventRooms) one stays on World.rooms, so creatures are placed
## in it as in any other. Each storey tries one, after the patches are laid: of
## the kinds (ROWS) whose first storey has come, in a random order, the first that
## fits a random room but the start room and the goal room. The room is cleared
## of patches, plates and vents first. The choice draws from a generator of its
## own, seeded from the world's, as EventRooms does, so it leaves the draws of
## what is laid after it as they were. A room that cannot be built leaves the
## storey as it was, and every room keeps the storey whole (FloorGen.connected).
##
## 갈대 정원 (garden): reeds fill the room round a pool of shallow water.
## 불타기 쉬운 곳간 (granary): straw covers the floor, and a censer stands in it.
## 안개 연못 (mist): a pond grown from the middle breathes fog from every tile.
## 경보 복도 (corridor): a dark, narrow room whose floor hides alarm plates (Traps).
## 깨어나는 석상 (statues): statues stand inside the room and wake as 장승 (Statues).
## 무너지는 마루 (rotten): rotten boards fill the room but its edge, each a hole once
## a creature steps off it.
## 늪지 (swamp): mud with marsh gas rising from it, which fire sets off.

const ROWS := [
	{kind = &"garden", tier = 1},
	{kind = &"granary", tier = 2},
	{kind = &"mist", tier = 3},
	{kind = &"corridor", tier = 4},
	{kind = &"statues", tier = 5},
	{kind = &"rotten", tier = 6},
	{kind = &"swamp", tier = 7},
]
## A swamp is mud grown from the middle of the room like a patch (Placement), of
## at least MUD_LEAST tiles, with marsh gas breathed from MARSH_VENTS of them (one
## more in a room of LARGE_AREA tiles).
const MUD := {what = World.MUD, on = World.FLOOR, grow = [100, 15]}
const MARSH := {gas = Gas.MARSH, amount = Gas.VENT_LEVEL, on = World.MUD, grow = [0, 0]}
const MUD_LEAST := 6
const MARSH_VENTS := 2
## A rotten floor holds at least ROTTEN_LEAST boards.
const ROTTEN_LEAST := 6
## A corridor is at most CORRIDOR.x tiles across and at least CORRIDOR.y long.
const CORRIDOR := Vector2i(4, 7)
## A corridor holds a plate for each PLATE_AREA tiles, from PLATES.x to PLATES.y of
## them; with fewer than PLATES.x that leave the storey whole it is no corridor.
const PLATE_AREA := 4
const PLATES := Vector2i(3, 8)
## A pond grows from the middle of a mist room like a patch (Placement), and
## breathes fog on every tile.
const POND := {what = World.POND, on = World.FLOOR, grow = [100, 18]}
const FOG := {gas = Gas.FOG, amount = Gas.MAX, on = World.POND, grow = [100, 0]}
## A pond of fewer tiles is no mist room.
const POND_LEAST := 4
## A room of this many tiles holds one more censer (a granary: two, else one) or
## statue (a hall of statues: three, else two).
const LARGE_AREA := 40
## A room must hold this many floor tiles to be made into one.
const LEAST_AREA := 12
## What a room is cleared of: patches (Placement) and the pond and floorboards.
const CLEARED: Array[int] = [
	World.BAMBOO,
	World.POND,
	World.BOARD,
	World.GRASS,
	World.LEAVES,
	World.STRAW,
	World.REEDS,
	World.SHALLOW,
	World.PILLAR,
	World.SCREEN,
	World.JAR,
	World.WATER_JAR,
	World.CENSER,
	World.COURTYARD,
]


## The first kind of the storey that fits a room is built there: {kind,
## room}, or an empty {} when none fits.
static func build(w: World, home: Rect2i, goal: Rect2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = w.rng.state
	var kinds := ROWS.filter(func(row): return w.depth >= row.tier)
	FloorGen.shuffle(rng, kinds)
	var rooms := w.rooms.filter(
		func(r): return r != home and r != goal and r.get_area() >= LEAST_AREA
	)
	for row: Dictionary in kinds:
		FloorGen.shuffle(rng, rooms)
		for r: Rect2i in rooms:
			if make(w, row.kind, r, rng):
				return {kind = row.kind, room = r}
	return {}


## Clears `r` and builds `kind` there; when it cannot, the tiles, plates, vents
## and gas are put back.
static func make(w: World, kind: StringName, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	var before := [w.tiles.duplicate(), w.traps.duplicate(), w.vents.duplicate(), w.gas.duplicate()]
	_clear(w, r)
	w._changed()
	var made := false
	match kind:
		&"garden":
			made = _garden(w, r)
		&"granary":
			made = _granary(w, r, rng)
		&"mist":
			made = _mist(w, r, rng)
		&"corridor":
			made = _corridor(w, r, rng)
		&"statues":
			made = _statues(w, r, rng)
		&"rotten":
			made = _rotten(w, r)
		&"swamp":
			made = _swamp(w, r, rng)
	if not made:
		w.tiles = before[0]
		w.traps = before[1]
		w.vents = before[2]
		w.gas = before[3]
	w._changed()
	return made


static func _clear(w: World, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := Vector2i(x, y)
			if CLEARED.has(w.tile(p)):
				w.tiles[Grid.index(p)] = World.FLOOR
			w.traps.erase(p)
			w.vents.erase(p)
			w.gas.erase(p)


## The floor tiles of `r` that nothing stands on or lies on.
static func _bare(w: World, r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := Vector2i(x, y)
			if (
				w.tile(p) == World.FLOOR
				and p != w.start
				and p != w.stairs
				and p != w.elixir
				and not w.peaches.has(p)
			):
				out.append(p)
	return out


static func _centre(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


## Reeds all over, shallow water round the middle: a third of the short side wide.
static func _garden(w: World, r: Rect2i) -> bool:
	var pool := (mini(r.size.x, r.size.y) - 1) / 3
	for p in _bare(w, r):
		w.tiles[Grid.index(p)] = World.SHALLOW if Grid.cheb(p, _centre(r)) <= pool else World.REEDS
	return true


## Straw all over, and censers (two in a room of LARGE_AREA tiles, else one) on
## tiles of it that leave the storey whole.
static func _granary(w: World, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	var spots := _bare(w, r)
	for p in spots:
		w.tiles[Grid.index(p)] = World.STRAW
	FloorGen.shuffle(rng, spots)
	var most := 2 if r.get_area() >= LARGE_AREA else 1
	var censers := 0
	for p in spots:
		if censers >= most:
			break
		w.tiles[Grid.index(p)] = World.CENSER
		if FloorGen.connected(w):
			Gas.put(w, p, Gas.INCENSE, Gas.VENT_LEVEL)
			w.vents[p] = Gas.INCENSE
			censers += 1
		else:
			w.tiles[Grid.index(p)] = World.STRAW
	return censers > 0


## A pond from the bare tile nearest the middle, fog on all of it; none when it
## would cut the storey apart or stays small.
static func _mist(w: World, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	var spots := _bare(w, r)
	if spots.is_empty():
		return false
	spots.sort_custom(func(a, b): return Grid.cheb(a, _centre(r)) < Grid.cheb(b, _centre(r)))
	var pond := Placement.lay(w, POND, spots[0], rng)
	if pond.size() < POND_LEAST:
		return false
	Placement.lay(w, FOG, pond[0], rng)
	return true


## Mud from the bare tile nearest the middle with marsh gas rising from some of it
## (the gas goes up in fire, Gas.light); none when the mud stays small or would cut
## the storey apart.
static func _swamp(w: World, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	var spots := _bare(w, r)
	if spots.is_empty():
		return false
	spots.sort_custom(func(a, b): return Grid.cheb(a, _centre(r)) < Grid.cheb(b, _centre(r)))
	var mud := Placement.lay(w, MUD, spots[0], rng)
	if mud.size() < MUD_LEAST:
		return false
	FloorGen.shuffle(rng, mud)
	for p in mud.slice(0, MARSH_VENTS + (1 if r.get_area() >= LARGE_AREA else 0)):
		Placement.lay(w, MARSH, p, rng)
	return true


## Rotten boards on every other tile off the room's edge, like a chessboard, so that
## each has plain floor beside it and Miho is never left on an island once the
## boards behind her are holes (Terrain.crumble). None when ROTTEN_LEAST boards are
## not to be had, or they cut the storey apart.
static func _rotten(w: World, r: Rect2i) -> bool:
	var boards := _bare(w, r.grow(-1)).filter(func(p): return (p.x + p.y) % 2 == 1)
	if boards.size() < ROTTEN_LEAST:
		return false
	for p in boards:
		w.tiles[Grid.index(p)] = World.BOARD_ROTTEN
	return FloorGen.connected(w, boards)


## Statues (two, three in a room of LARGE_AREA tiles) on bare tiles off the room's
## edge, where the ways in stay clear, each one that leaves the storey whole.
static func _statues(w: World, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	var inner := r.grow(-1)
	var spots := _bare(w, inner)
	FloorGen.shuffle(rng, spots)
	var most := 3 if r.get_area() >= LARGE_AREA else 2
	var statues := 0
	for p in spots:
		if statues >= most:
			break
		w.tiles[Grid.index(p)] = World.STATUE
		if FloorGen.connected(w):
			statues += 1
		else:
			w.tiles[Grid.index(p)] = World.FLOOR
	return statues == most


## Alarm plates on random bare tiles of a narrow room no light reaches, each one
## that leaves the storey whole with every plate counted as a wall.
static func _corridor(w: World, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	if mini(r.size.x, r.size.y) > CORRIDOR.x or maxi(r.size.x, r.size.y) < CORRIDOR.y:
		return false
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if w.lit(Vector2i(x, y)):
				return false
	var spots := _bare(w, r)
	FloorGen.shuffle(rng, spots)
	var most := clampi(r.get_area() / PLATE_AREA, PLATES.x, PLATES.y)
	var plates := 0
	for p in spots:
		if plates >= most:
			break
		w.traps[p] = World.TRAP_ALARM
		if FloorGen.connected(w, w.traps.keys()):
			plates += 1
		else:
			w.traps.erase(p)
	return plates >= PLATES.x
