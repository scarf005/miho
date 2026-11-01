class_name Scattered
extends RefCounted
## 흩어진 정자: small pavilions scattered over the sky, each of a room or two, with a net
## of straight bridges between them. Bridges join them all first, then more cross where
## the walk round is long; some are planks of 마루, which burn away (Terrain.plank), as
## long as the storey stays whole without any of them.

## The rows of the field, the width of a stretch of it with a pavilion in it (least,
## most), and the chance that a stretch stays empty.
const ROWS := 3
const STRETCH := Vector2i(11, 15)
const EMPTY := 0.12
## A pavilion's size with its walls (least), and its width at most. Within its stretch
## it leaves a tile of sky to the east and south.
const LEAST := Vector2i(8, 6)
const WIDEST := 12
## The largest room of a pavilion.
const ROOM_MOST := Vector2i(6, 6)
## The fewest pavilions of a map of them: one with fewer is drawn again.
const FEWEST := 8
## The chance that a bridge is planks.
const PLANKS := 0.5


## The skeleton: pavilions over the whole map. Bridges first, so that a wall between two
## rooms a walk round joins has no door yet: half of those get one, far doorways, and
## the others may hide one. A storey with no plank is drawn again (no goal).
static func draw(w: World) -> Dictionary:
	var blocks := plant(w, Rect2i(1, 1, Grid.W - 2, Grid.H - 2))
	var plan := {spots = [], links = [], goal = Rect2i()}
	if blocks.size() < FEWEST:
		return plan
	join(w, blocks, plan.links)
	var doors := (w.rooms.size() - blocks.size()) / 2
	plan.sealed = FloorGen._loops(w, FloorGen._doorways(w, []), plan.links, doors)
	if not Skeletons.planks(w).is_empty():
		plan.goal = Skeletons.far_ends(w)
	return plan


## Pavilions over `area`, row by row; returns them with their walls.
static func plant(w: World, area: Rect2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var y := area.position.y
	for row in ROWS:
		var tall := (area.end.y - y) / (ROWS - row)
		var x := area.position.x
		while area.end.x - x >= STRETCH.x:
			var wide := w.rng.randi_range(STRETCH.x, STRETCH.y)
			if area.end.x - x - wide < STRETCH.x:
				wide = area.end.x - x
			if w.rng.randf() >= EMPTY:
				out.append(_pavilion(w, Rect2i(x, y, wide, tall)))
			x += wide
		y += tall
	return out


## A pavilion somewhere in `stretch`, its inside cut into rooms.
static func _pavilion(w: World, stretch: Rect2i) -> Rect2i:
	var size := Vector2i(
		w.rng.randi_range(LEAST.x, mini(WIDEST, stretch.size.x - 1)),
		w.rng.randi_range(LEAST.y, stretch.size.y - 1)
	)
	var at := (
		stretch.position
		+ Vector2i(
			w.rng.randi_range(0, stretch.size.x - 1 - size.x),
			w.rng.randi_range(0, stretch.size.y - 1 - size.y)
		)
	)
	var block := Rect2i(at, size)
	var none: Array[Rect2i] = []
	FloorGen._fill(w, block, World.WALL)
	FloorGen._fill(w, block.grow(-1), World.FLOOR)
	FloorGen._split(w, block.grow(-1), none, false, ROOM_MOST)
	return block


## Bridges between `blocks`: first where no walk joins the two ends yet, then where the
## walk round is at least FloorGen.APART (each joins `links`). Some then turn to planks.
static func join(w: World, blocks: Array[Rect2i], links: Array) -> void:
	var spans := _spans(blocks)
	FloorGen.shuffle(w.rng, spans)
	var laid := []
	for far: bool in [false, true]:
		for s: Dictionary in spans:
			if not _clear(w, s):
				continue
			var dist: int = Grid.search(s.a, Masks.floor_of(w)).dist[Grid.index(s.b)]
			if dist >= FloorGen.APART if far else dist < 0:
				if far:
					links.append({at = s.a + s.dir * 2, a = s.a, b = s.b})
				_lay(w, s, World.BRIDGE)
				laid.append(s)
	_planks(w, laid)


## Every straight way between two of `blocks`, east or south: {a, b, dir}, the tiles
## just inside the walls it goes through and its direction.
static func _spans(blocks: Array[Rect2i]) -> Array:
	var out := []
	for a in blocks:
		for b in blocks:
			if a.end.x <= b.position.x:
				for y in range(maxi(a.position.y, b.position.y) + 1, mini(a.end.y, b.end.y) - 1):
					var from := Vector2i(a.end.x - 2, y)
					out.append({a = from, b = Vector2i(b.position.x + 1, y), dir = Vector2i.RIGHT})
			if a.end.y <= b.position.y:
				for x in range(maxi(a.position.x, b.position.x) + 1, mini(a.end.x, b.end.x) - 1):
					var from := Vector2i(x, a.end.y - 2)
					out.append({a = from, b = Vector2i(x, b.position.y + 1), dir = Vector2i.DOWN})
	return out


## Whether span `s` can be laid: from room floor through a plain stretch of wall to room
## floor, over sky with sky on both sides, so that no bridge runs beside another.
static func _clear(w: World, s: Dictionary) -> bool:
	if w.tile(s.a) != World.FLOOR or w.tile(s.b) != World.FLOOR:
		return false
	if not FloorGen._walled(w, s.a + s.dir, s.dir) or not FloorGen._walled(w, s.b - s.dir, s.dir):
		return false
	var side := Vector2i(s.dir.y, s.dir.x)
	var p: Vector2i = s.a + s.dir * 2
	while p != s.b - s.dir:
		if w.tile(p) != World.SKY or w.tile(p + side) != World.SKY or w.tile(p - side) != World.SKY:
			return false
		p += s.dir
	return true


## Lays span `s` in tile `t`, with an opening in the wall at each end.
static func _lay(w: World, s: Dictionary, t: int) -> void:
	w.tiles[Grid.index(s.a + s.dir)] = World.FLOOR
	w.tiles[Grid.index(s.b - s.dir)] = World.FLOOR
	var p: Vector2i = s.a + s.dir * 2
	while p != s.b - s.dir:
		w.tiles[Grid.index(p)] = t
		p += s.dir


## Each bridge of `laid`, at the chance PLANKS, turns to planks unless that leaves the
## storey in pieces once they have burnt.
static func _planks(w: World, laid: Array) -> void:
	FloorGen.shuffle(w.rng, laid)
	for s: Dictionary in laid:
		if w.rng.randf() < PLANKS:
			_lay(w, s, World.BOARD)
			if not FloorGen.connected(w, Skeletons.planks(w)):
				_lay(w, s, World.BRIDGE)
