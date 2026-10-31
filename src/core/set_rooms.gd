class_name SetRooms
extends RefCounted
## Set rooms (짜인 방): rooms made of terrain alone, no key and no prize. Unlike
## an event room (EventRooms) one stays on World.rooms, so creatures are placed
## in it as in any other. Each storey tries one, after the patches are laid: of
## the kinds (ROWS) whose first tier has come, in a random order, the first that
## fits a random room but the start room and the goal room. The room is cleared
## of patches, plates and vents first. The choice draws from a generator of its
## own, seeded from the world's, as EventRooms does, so it leaves the draws of
## what is laid after it as they were. A room that cannot be built leaves the
## storey as it was, and every room keeps the storey whole (FloorGen.connected).
##
## 갈대 정원 (garden): reeds fill the room round a pool of shallow water.
## 불타기 쉬운 곳간 (granary): straw covers the floor, and a censer stands in it.

const ROWS := [
	{kind = &"garden", tier = 1},
	{kind = &"granary", tier = 2},
]
## A granary of this many tiles holds two censers, else one.
const CENSERS_AREA := 40
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


## The first kind of the storey's tier that fits a room is built there: {kind,
## room}, or an empty {} when none fits.
static func build(w: World, home: Rect2i, goal: Rect2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = w.rng.state
	var kinds := ROWS.filter(func(row): return w.tier() >= row.tier)
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
	var made := false
	match kind:
		&"garden":
			made = _garden(w, r)
		&"granary":
			made = _granary(w, r, rng)
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


## Straw all over, and censers (two in a room of CENSERS_AREA tiles, else one) on
## tiles of it that leave the storey whole.
static func _granary(w: World, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	var spots := _bare(w, r)
	for p in spots:
		w.tiles[Grid.index(p)] = World.STRAW
	FloorGen.shuffle(rng, spots)
	var most := 2 if r.get_area() >= CENSERS_AREA else 1
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
