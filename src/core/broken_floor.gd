class_name BrokenFloor
extends RefCounted
## 부서진 층: one great building cut into rooms, its floor and inner walls torn open to
## the sky in holes that leave every open tile joined (Brogue designLakes). A hole
## hides nothing beyond it, and is a way down (Fall).

## How far the building stands from the map's west and east edges, and from its north
## and south edges (least, most).
const MARGIN_X := Vector2i(1, 5)
const MARGIN_Y := Vector2i(1, 3)
## The share of the building's inside torn away, the tiles a hole is grown to, and how
## many holes are tried for it.
const TORN := 0.2
const HOLE := Vector2i(5, 28)
const TRIES := 60
## The largest room that may stay whole: bigger than elsewhere, so that the holes have
## room to be walked round.
const ROOM_MOST := Vector2i(20, 12)


## The skeleton: the building, the far doorways of its rooms, then its holes, so that
## the start and the exit are picked from what is left to walk on.
static func draw(w: World) -> Dictionary:
	var west := w.rng.randi_range(MARGIN_X.x, MARGIN_X.y)
	var north := w.rng.randi_range(MARGIN_Y.x, MARGIN_Y.y)
	var wide := Grid.W - west - w.rng.randi_range(MARGIN_X.x, MARGIN_X.y)
	var tall := Grid.H - north - w.rng.randi_range(MARGIN_Y.x, MARGIN_Y.y)
	var hall := Rect2i(west, north, wide, tall)
	var galleries := raise(w, hall)
	var plan := {spots = [], links = [], goal = Rect2i()}
	plan.sealed = _loop(w, FloorGen._doorways(w, galleries), plan.links)
	tear(w, hall)
	plan.goal = Skeletons.far_ends(w)
	return plan


## Far doorways (FloorGen._loops) on `spots` until none is left to open: what makes
## two routes through one building. Returns the spots left.
static func _loop(w: World, spots: Array, links: Array) -> Array:
	var cut := -1
	while cut != links.size():
		cut = links.size()
		spots = FloorGen._loops(w, spots, links)
	return spots


## The building at `hall`, cut into rooms; returns its galleries.
static func raise(w: World, hall: Rect2i) -> Array[Rect2i]:
	var galleries: Array[Rect2i] = []
	FloorGen._fill(w, hall, World.WALL)
	FloorGen._fill(w, hall.grow(-1), World.FLOOR)
	FloorGen._split(w, hall.grow(-1), galleries, w.rng.randf() < FloorGen.GALLERIES, ROOM_MOST)
	return galleries


## Holes in what stands inside `hall`, up to TORN of it; a wall with nothing left to
## stand beside falls with them.
static func tear(w: World, hall: Rect2i) -> void:
	var free := _free(w, hall)
	var left := int(hall.grow(-1).get_area() * TORN)
	for attempt in TRIES:
		if left <= 0 or free.is_empty():
			break
		left -= _hole(w, free, w.rng.randi_range(HOLE.x, HOLE.y))
	w.tiles = Native.fallen(w.tiles, hall, World.WALL, World.SKY, Grid.W)


## A hole of up to `size` tiles of `free` grown from a random one; the tiles it took, none
## when it would cut the storey apart, a burnt plank counted as gone.
static func _hole(w: World, free: Dictionary, size: int) -> int:
	var keys := free.keys()
	var taken := {}
	var p: Vector2i = keys[w.rng.randi_range(0, keys.size() - 1)]
	for i in size * 3:
		if taken.size() >= size:
			break
		if free.has(p):
			taken[p] = w.tile(p)
			free.erase(p)
		keys = taken.keys()
		p = keys[w.rng.randi_range(0, keys.size() - 1)] + Placement.SIDES[w.rng.randi_range(0, 3)]
	for at: Vector2i in taken:
		w.tiles[Grid.index(at)] = World.SKY
	if FloorGen.connected(w, Skeletons.planks(w)):
		return taken.size()
	for at: Vector2i in taken:
		w.tiles[Grid.index(at)] = taken[at]
	return 0


## The tiles a hole may take: floor and wall inside `hall`, off the middle of every room
## (patrols head there, and the start and the exit lie there) and clear of every way
## through a wall and of the galleries.
static func _free(w: World, hall: Rect2i) -> Dictionary:
	var free := {}
	var tiles := Native.tearable(
		w.tiles, Tiles.walk, w.rooms, hall, World.FLOOR, World.WALL, Grid.W
	)
	for i in tiles:
		free[Grid.at(i)] = true
	return free
