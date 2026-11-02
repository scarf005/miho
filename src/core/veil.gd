class_name Veil
extends RefCounted
## 도깨비불 장막: a line of dokkaebi fire splits a room, and every way into the
## room lies on one side of it. The fire never dies down by itself and blocks
## walking and spells but not sight; it lights the room. Whoever stands next to
## it (in eight directions) when a round ends burns for World.FIRE_DAMAGE, unless
## it eats fire. A water spell that ends beside it, a jet of water or frost
## (the element that beats fire, Cards.BEATS) puts out the tiles it reaches
## (Terrain.wash, Compounds): ash, or ice after frost. A peach lies in the far
## half, away from the fire.

## How far the line lies from the tile inside the farthest doorway, so that
## entering burns nobody; and how many tiles lie beyond it, the peach among them.
const NEAR := 2
const FAR := 3


## Splits room r with a veil of fire and lays a peach beyond it; false, with
## nothing changed, when r is small or no line leaves all its doorways on one
## side, two tiles or more from it.
static func make(w: World, r: Rect2i, rng: RandomNumberGenerator) -> bool:
	var doors := EventRooms.doorways(w, r)
	if doors.is_empty():
		return false
	var plans := [[false, false], [false, true], [true, false], [true, true]]
	FloorGen.shuffle(rng, plans)
	for plan: Array in plans:
		var line := _line(r, doors, plan[0], plan[1], rng)
		if line.is_empty():
			continue
		var spots: Array = line.peaches.filter(w.open_floor)
		if spots.is_empty():
			continue
		for p: Vector2i in line.tiles:
			if w.open_floor(p):
				w.set_tile(p, World.VEIL)
		w.peaches.append(spots[rng.randi_range(0, spots.size() - 1)])
		return true
	return false


## Where the line runs in room r: {tiles, peaches}, or empty. `turn` lays the
## line across the room's height instead of its width, `flip` puts the doorways
## on the high side.
static func _line(
	r: Rect2i, doors: Array, turn: bool, flip: bool, rng: RandomNumberGenerator
) -> Dictionary:
	var length := r.size.y if turn else r.size.x
	var across := r.size.x if turn else r.size.y
	var along := doors.map(func(p): return _along(r, p, turn, flip))
	var cuts := range(along.max() + NEAR, length - FAR)
	if cuts.is_empty():
		return {}
	var cut: int = cuts[rng.randi_range(0, cuts.size() - 1)]
	var out := {tiles = [], peaches = []}
	for y in across:
		out.tiles.append(_tile(r, cut, y, turn, flip))
		for x in range(cut + NEAR, length):
			out.peaches.append(_tile(r, x, y, turn, flip))
	return out


## How far the room tile inside doorway p lies from the near end of room r,
## along the line's normal.
static func _along(r: Rect2i, p: Vector2i, turn: bool, flip: bool) -> int:
	var length := r.size.y if turn else r.size.x
	var at := clampi(p.y - r.position.y if turn else p.x - r.position.x, 0, length - 1)
	return length - 1 - at if flip else at


static func _tile(r: Rect2i, along: int, across: int, turn: bool, flip: bool) -> Vector2i:
	var length := r.size.y if turn else r.size.x
	var x := length - 1 - along if flip else along
	return r.position + (Vector2i(across, x) if turn else Vector2i(x, across))


## Whether p is next to the veil.
static func scorches(w: World, p: Vector2i) -> bool:
	return Grid.DIRS.any(func(d): return w.tile(p + d) == World.VEIL)


## Whoever stands next to the veil burns.
static func tick(w: World) -> void:
	if w.tiles.find(World.VEIL) < 0:
		return
	var flame := Spell.make([Cards.FOX, Cards.FIRE])
	for a in w.actors.duplicate():
		if a.alive() and scorches(w, a.pos):
			w.emit({t = &"burn", at = a.pos, id = a.id})
			if Bestiary.absorbs(a.nature_kind(), flame):
				w.emit({t = &"absorb", id = a.id, at = a.pos})
			else:
				Harm.hurt(w, a, World.FIRE_DAMAGE)
