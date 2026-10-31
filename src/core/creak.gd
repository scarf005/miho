class_name Creak
extends RefCounted
## 삐걱 마루: a room floored with boards all over (World.BOARD, every step of
## which creaks for Tiles.tread tiles, and Miho's treads alarm heaven), with a
## sleeping 해태 at the end farthest from the ways in. When it falls, by any
## harm or by a push into the sky, every one of Miho's tails returns.

## The room's least size.
const LEAST := Vector2i(5, 3)
## The 해태 sleeps this far (Chebyshev) from every way in, or farther.
const FAR := 3


## Boards the whole of room r and lays the 해태 to sleep at its farthest tile;
## false, with nothing changed, when the room is small, has no way in, or has
## no tile FAR from the ways in.
static func make(w: World, r: Rect2i) -> bool:
	var doors := EventRooms.doorways(w, r)
	if r.size.x < LEAST.x or r.size.y < LEAST.y or doors.is_empty():
		return false
	var best := Vector2i(-1, -1)
	var far := FAR - 1
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := Vector2i(x, y)
			var d: int = doors.map(func(q): return Grid.cheb(p, q)).min()
			if d > far:
				best = p
				far = d
	if best.x < 0:
		return false
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			w.tiles[Grid.index(Vector2i(x, y))] = World.BOARD
	w._changed()
	var beast := FloorGen.spawn(w, &"haetae", best)
	w.sites.append({kind = &"creak", at = best, id = beast.id})
	return true


## The 해태 fell this round: every tail returns.
static func tick(w: World, site: Dictionary) -> void:
	if not w.events.any(func(e): return e.t == &"die" and e.id == site.id):
		return
	w.sites.erase(site)
	w.tails = w.max_tails()
	w.emit({t = &"creak"})
