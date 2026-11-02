class_name Altar
extends RefCounted
## 혼불 제단: an altar stands in the middle of a room. When NEED creatures of
## heaven fall within REACH tiles of it, by any harm or by a push into the sky,
## it burns: Miho's tails all return and this storey allows one more
## (World.tail_bonus). Luring heaven into the room is the risk. The altar
## blocks walking and spells.

const NEED := 3
const REACH := 6
## The room's least size.
const LEAST := Vector2i(5, 4)


## Puts an altar in the middle of room r; false, with nothing changed, when the
## room is small or the altar would cut the storey apart.
static func make(w: World, r: Rect2i) -> bool:
	if r.size.x < LEAST.x or r.size.y < LEAST.y:
		return false
	var at := r.position + r.size / 2
	w.set_tile(at, World.ALTAR)
	if not FloorGen.connected(w):
		w.set_tile(at, World.FLOOR)
		return false
	w.sites.append({kind = &"altar", at = at, fallen = 0})
	return true


## Counts the creatures of heaven that fell this round near the altar (a fall
## of Miho ends the run, and nothing counts then); the last of NEED lights it.
static func tick(w: World, site: Dictionary) -> void:
	for e in w.events:
		if e.t == &"die" and e.get("foe", false) and Grid.cheb(e.at, site.at) <= REACH:
			site.fallen += 1
	if site.fallen < NEED:
		return
	w.sites.erase(site)
	w.set_tile(site.at, World.ALTAR_LIT)
	w.tail_bonus += 1
	w.tails = w.max_tails()
	w.emit({t = &"altar"})
