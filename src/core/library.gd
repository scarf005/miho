class_name Library
extends RefCounted
## 서고: a dark room behind closed doors, floored with boards and dry straw,
## with scroll shelves (World.SHELF) along its top wall. Stepping onto a shelf
## reads the scrolls: the storey's whole map becomes known, once. The room
## burns easily: boards, straw and shelves take fire (Tiles.spread), and a
## shelf that burns first is lost.

## The room's least size.
const LEAST := Vector2i(5, 3)
## The share of the floor that is straw.
const STRAW := 0.35


## Shuts the ways into room r with doors, floors it and puts the shelves
## along its top wall; false, with nothing changed, when the room is small,
## has no way in, or has room for fewer than two shelves.
static func make(w: World, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	var doors := EventRooms.doorways(w, r)
	if r.size.x < LEAST.x or r.size.y < LEAST.y or doors.is_empty():
		return false
	var shelves: Array[Vector2i] = []
	for x in range(r.position.x + 1, r.end.x - 1, 2):
		var p := Vector2i(x, r.position.y)
		if doors.all(func(q): return Grid.cheb(p, q) > 1):
			shelves.append(p)
	if shelves.size() < 2:
		return false
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var straw := rng.randf() < STRAW
			w.tiles[Grid.index(Vector2i(x, y))] = World.STRAW if straw else World.BOARD
	for p in shelves:
		w.tiles[Grid.index(p)] = World.SHELF
	for p in doors:
		w.tiles[Grid.index(p)] = World.DOOR
	w._changed()
	w.sites.append({kind = &"library", at = shelves[0]})
	return true


## The shelf at site is read when Miho steps onto any of the room's shelves.
static func arrive(w: World, me: Actor) -> void:
	if w.tile(me.pos) != World.SHELF:
		return
	for site: Dictionary in w.sites.duplicate():
		if site.kind != &"library":
			continue
		w.sites.erase(site)
		w.known.resize(w.tiles.size())
		w.known.fill(1)
		for i in w.tiles.size():
			if w.tiles[i] == World.SHELF:
				w.tiles[i] = World.SHELF_READ
		w._changed()
		w.emit({t = &"read", at = me.pos})
