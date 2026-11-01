class_name Keep
extends RefCounted
## 겹누각: walls within walls (DCSS onion city). Each band between two walls is a ring of
## rooms, joined all the way round, and each wall has one door, on the side opposite
## the door of the wall inside it; the exit lies in the innermost room. So there is
## one way in, unless a hidden door in the walls is found. Rooms stand against the
## outer wall on the east and west.
##
## The citadel (고리 + 겹누각) sets a smaller keep in the court of a ring (Skeletons),
## one bridge across the sky to its one door.

## How far the outer wall stands from the map's west and east edges, and from its north
## and south (least, most).
const MARGIN_X := Vector2i(8, 13)
const MARGIN_Y := Vector2i(1, 2)
## How deep the rooms of a band are on its east and west sides, and on its north and
## south (least, most).
const BAND_X := Vector2i(4, 5)
const BAND_Y := Vector2i(3, 4)
## How small the innermost room may be.
const CORE := Vector2i(4, 3)
## The chance that a space for a room outside the outer wall stays sky.
const GAPS := 0.3
## The citadel: its ring's distance from the map's west and east edges, and the sky
## round its keep.
const CITADEL_X := Vector2i(9, 12)
const COURT_SKY := 2


## The skeleton: two bands round the innermost room; the start is the room of the outer
## band farthest from its door.
static func draw(w: World) -> Dictionary:
	var west := w.rng.randi_range(MARGIN_X.x, MARGIN_X.y)
	var north := w.rng.randi_range(MARGIN_Y.x, MARGIN_Y.y)
	var wide := Grid.W - west - w.rng.randi_range(MARGIN_X.x, MARGIN_X.y)
	var outer := Rect2i(west, north, wide, Grid.H - 2 * north)
	_wings(w, outer)
	var mid := _inset(w, outer, 1)
	var rooms := _band(w, outer, mid)
	var inner := _inset(w, mid, 0)
	_band(w, mid, inner)
	var core := _core(w, inner)
	var side: Vector2i = Placement.SIDES[w.rng.randi_range(0, 3)]
	var door := _door(w, mid, side)
	_door(w, inner, -side)
	Skeletons._first(w, _farthest(rooms, door))
	return {spots = [], links = [], goal = core, sealed = FloorGen._doorways(w, [])}


## The citadel: a ring with rooms east and west of it, a keep of one band in its court,
## and a bridge from the ring to the keep's door. The start is the room on the ring
## farthest from the bridge.
static func citadel(w: World) -> Dictionary:
	var west := w.rng.randi_range(CITADEL_X.x, CITADEL_X.y)
	var wide := Grid.W - west - w.rng.randi_range(CITADEL_X.x, CITADEL_X.y)
	var outer := Rect2i(west, 1, wide, Grid.H - 2)
	var ring := Skeletons._ring_walls(w, outer)
	var near := []
	while near.is_empty():
		_wings(w, outer)
		near = Skeletons._rooms_by(w, ring.halls)
	var wall: Rect2i = ring.court.grow(-COURT_SKY)
	var inner := _inset(w, wall, 0)
	_band(w, wall, inner)
	var core := _core(w, inner)
	var side: Vector2i = Placement.SIDES[w.rng.randi_range(0, 3)]
	var landing := _bridge(w, wall, side)
	_door(w, inner, -side)
	var home := _farthest(near, landing)
	ring.halls.any(func(h): return Skeletons._door(w, home, h))
	Skeletons._first(w, home)
	var left := FloorGen._doorways(w, ring.halls)
	var keep := func(s: Array) -> bool: return ring.court.has_point(s[0])
	return {
		spots = left.filter(func(s): return not keep.call(s)),
		links = [],
		goal = core,
		sealed = left.filter(keep),
	}


## Of `rooms`, the one whose middle lies farthest from `from`.
static func _farthest(rooms: Array, from: Vector2i) -> Rect2i:
	var best: Rect2i = rooms[0]
	for r: Rect2i in rooms:
		if Grid.cheb(r.get_center(), from) > Grid.cheb(best.get_center(), from):
			best = r
	return best


## Rooms against the east and west of `outer`.
static func _wings(w: World, outer: Rect2i) -> void:
	var last := outer.end - Vector2i.ONE
	Skeletons._wing(w, outer.position, Vector2i(outer.position.x, last.y), Vector2i.LEFT, GAPS)
	Skeletons._wing(w, Vector2i(last.x, outer.position.y), last, Vector2i.RIGHT, GAPS)


## The wall inside `wall`, a band's depth in, with room left for `more` bands and CORE.
static func _inset(w: World, wall: Rect2i, more: int) -> Rect2i:
	var fit := (wall.size - Vector2i(2, 2) - CORE) / 2 - Vector2i.ONE
	fit -= (Vector2i(BAND_X.x, BAND_Y.x) + Vector2i.ONE) * more
	var x := mini(w.rng.randi_range(BAND_X.x, BAND_X.y), fit.x)
	var y := mini(w.rng.randi_range(BAND_Y.x, BAND_Y.y), fit.y)
	return wall.grow_individual(-x - 1, -y - 1, -x - 1, -y - 1)


## The innermost room, inside wall `inner`.
static func _core(w: World, inner: Rect2i) -> Rect2i:
	var core := inner.grow(-1)
	FloorGen._fill(w, core, World.FLOOR)
	w.rooms.append(core)
	return core


## The walls `outer` and `inner` and the rooms of the band between them, with doorways
## all round it; returns the rooms.
static func _band(w: World, outer: Rect2i, inner: Rect2i) -> Array[Rect2i]:
	FloorGen._fill(w, outer, World.WALL)
	FloorGen._fill(w, outer.grow(-1), World.FLOOR)
	var top := outer.position.y + 1
	var tall := outer.size.y - 2
	for x in [inner.position.x, inner.end.x - 1]:
		FloorGen._fill(w, Rect2i(x, top, 1, tall), World.WALL)
	FloorGen._fill(w, inner, World.WALL)
	var across := inner.size.x - 2
	var deep := inner.position - outer.position - Vector2i.ONE
	var ring := _cut(w, Rect2i(inner.position.x + 1, top, across, deep.y))
	ring.append_array(_cut(w, Rect2i(inner.end.x, top, deep.x, tall)))
	var south := _cut(w, Rect2i(inner.position.x + 1, inner.end.y, across, deep.y))
	south.reverse()
	ring.append_array(south)
	var west := _cut(w, Rect2i(outer.position.x + 1, top, deep.x, tall))
	west.reverse()
	ring.append_array(west)
	for k in ring.size():
		Skeletons._door(w, ring[k - 1], ring[k])
	return ring


## The strip `r` cut across its length into rooms, in order; they join World.rooms.
static func _cut(w: World, r: Rect2i) -> Array[Rect2i]:
	var along := Vector2i.RIGHT if r.size.x >= r.size.y else Vector2i.DOWN
	var length := maxi(r.size.x, r.size.y)
	var across := r.size - along * length
	var out: Array[Rect2i] = []
	var at := 0
	while at < length:
		var piece := w.rng.randi_range(Skeletons.LOT.x, Skeletons.LOT.y)
		if length - at - piece - 1 < FloorGen.ROOM_LEAST:
			piece = length - at
		out.append(Rect2i(r.position + along * at, across + along * piece))
		w.rooms.append(out[-1])
		if at + piece < length:
			FloorGen._fill(w, Rect2i(r.position + along * (at + piece), across + along), World.WALL)
		at += piece + 1
	return out


## A doorway in side `side` of wall `wall` with a room on both sides of it; returns its
## tile. A wall with none stays shut, and the storey that is not whole starts over.
static func _door(w: World, wall: Rect2i, side: Vector2i) -> Vector2i:
	var spots := _spots(w, wall, side).filter(
		func(p): return FloorGen.room_at(w, p + side).has_area()
	)
	if spots.is_empty():
		return wall.position
	var at: Vector2i = spots[w.rng.randi_range(0, spots.size() - 1)]
	FloorGen._doorway(w, at)
	return at


## The tiles of side `side` of wall `wall` with a room inside and plain wall either side.
static func _spots(w: World, wall: Rect2i, side: Vector2i) -> Array[Vector2i]:
	var along := Vector2i(absi(side.y), absi(side.x))
	var length := wall.size.x if along.x == 1 else wall.size.y
	var start := wall.position
	if side == Vector2i.RIGHT:
		start.x = wall.end.x - 1
	elif side == Vector2i.DOWN:
		start.y = wall.end.y - 1
	var out: Array[Vector2i] = []
	for k in range(1, length - 1):
		var p := start + along * k
		if FloorGen.room_at(w, p - side).has_area() and FloorGen._walled(w, p, side):
			out.append(p)
	return out


## The bridge from side `side` of the keep's wall `wall` over the sky and through the
## wall of the hall beyond; returns the tile of that wall it comes through.
static func _bridge(w: World, wall: Rect2i, side: Vector2i) -> Vector2i:
	var spots := _spots(w, wall, side)
	var p: Vector2i = spots[w.rng.randi_range(0, spots.size() - 1)]
	w.tiles[Grid.index(p)] = World.FLOOR
	p += side
	while w.tile(p) == World.SKY:
		w.tiles[Grid.index(p)] = World.BRIDGE
		p += side
	w.tiles[Grid.index(p)] = World.FLOOR
	return p
