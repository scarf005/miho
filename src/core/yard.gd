class_name Yard
extends RefCounted
## 장승 마당: a 장승 at one end of a room guards it, and stone lamps along
## its two long sides light the whole yard, so whoever walks in is seen. A grove
## of bamboo (hides whoever stands in it from all but the tiles next to it) and
## two pillars (shade the tiles behind them) are the safe tiles. On the stand
## beside the 장승 lies a talisman: Miho takes it by stepping on it, the one
## rolled for the storey, or the first element she does not hold yet when she
## holds that one already, and nothing when she holds them all. The risk is the
## 장승's orbs.

## The room's least size.
const LEAST := Vector2i(9, 5)
## From the guard's end: the stand, the pillars, and the bamboo's first column;
## the grove is GROVE columns deep and spans the middle three rows.
const STAND := 1
const PILLARS := 3
const GROVE := 2
## The doorways stay this far from the guard (Chebyshev).
const CLEAR := 2


## Lays out the yard in room r; false, with nothing changed, when the room is
## small, a way in lies by the guard's end on both sides, the guard or the layout
## would lie on anything but floor, or the layout would cut the storey apart.
static func make(w: World, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	if r.size.x < LEAST.x or r.size.y < LEAST.y:
		return false
	var doors := EventRooms.doorways(w, r)
	var ends := [false, true]
	FloorGen.shuffle(rng, ends)
	for flip: bool in ends:
		var guard := Vector2i(r.position.x if flip else r.end.x - 1, r.position.y + r.size.y / 2)
		if doors.any(func(p): return Grid.cheb(p, guard) <= CLEAR):
			continue
		var layout := _layout(r, guard, flip)
		if not w.open_floor(guard) or layout.keys().any(func(p): return w.tile(p) != World.FLOOR):
			continue
		var before := w.tiles.duplicate()
		for p: Vector2i in layout:
			w.tiles[Grid.index(p)] = layout[p]
		var stand := _inward(guard, flip, STAND)
		w._changed()
		if not FloorGen.connected(w):
			w.tiles = before
			w._changed()
			continue
		FloorGen.spawn(w, &"jangseung", guard).brain.guard = true
		var card: StringName = Cards.ELEMENTS[rng.randi_range(0, Cards.ELEMENTS.size() - 1)]
		w.sites.append({kind = &"yard", at = stand, card = card})
		return true
	return false


## What each tile of the yard becomes, with its guard at `guard`.
static func _layout(r: Rect2i, guard: Vector2i, flip: bool) -> Dictionary:
	var out := {}
	for p: Vector2i in _lamps(r):
		out[p] = World.LAMP
	for k in range(r.size.x - GROVE - 1, r.size.x - 1):
		for dy in range(-1, 2):
			out[_inward(guard, flip, k) + Vector2i(0, dy)] = World.BAMBOO
	for dy in [-1, 1]:
		out[_inward(guard, flip, PILLARS) + Vector2i(0, dy)] = World.PILLAR
	out[_inward(guard, flip, STAND)] = World.TALISMAN
	return out


## The stone lamps: on the top and bottom rows, one near each end and one in the middle.
static func _lamps(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in [r.position.x + 1, r.position.x + r.size.x / 2, r.end.x - 2]:
		out.append(Vector2i(x, r.position.y))
		out.append(Vector2i(x, r.end.y - 1))
	return out


## The tile k steps from the guard along the room's middle row.
static func _inward(guard: Vector2i, flip: bool, k: int) -> Vector2i:
	return guard + Vector2i(k if flip else -k, 0)


## The talisman the stand at site gives now: the one rolled, or the first
## element Miho does not hold, or none.
static func prize(w: World, site: Dictionary) -> StringName:
	if not w.cards.has(site.card):
		return site.card
	for c: StringName in Cards.ELEMENTS:
		if not w.cards.has(c):
			return c
	return &""


## Miho has come onto her tile: the stand gives its talisman, once.
static func arrive(w: World, me: Actor) -> void:
	for site: Dictionary in w.sites.duplicate():
		if (site.kind == &"yard" or site.kind == Labyrinth.PRIZE) and site.at == me.pos:
			var card := prize(w, site)
			w.sites.erase(site)
			w.set_tile(site.at, World.FLOOR)
			if card != &"":
				w.cards.append(card)
				w.emit({t = &"card", card = card, at = site.at})
