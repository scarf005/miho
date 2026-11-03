class_name Askew
extends RefCounted
## 어긋난 전각: rooms of many shapes attached one by one, each by a door to one already
## standing, some at the end of a hall, with no grid to read the next room from (Brogue
## attachRooms, attachHallwayTo, addLoops; the shapes of designCrossRoom,
## designSymmetricalCrossRoom, designCircularRoom, designChunkyRoom). A shape is a list of
## rectangles; only its largest is on World.rooms, the rest stays bare to walk on.

## How many rooms to stand, how many rooms to try for them, and the chance of a hall.
const ROOMS := 22
const TRIES := 500
const HALLS := 0.3
const HALL := Vector2i(3, 9)
## What rooms stand inside, their walls too.
const AREA := Rect2i(1, 1, Grid.W - 2, Grid.H - 2)
## How many ways close a loop and how long one may be.
const LOOPS := 6
const GAP := 7
const WAYS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]


static func draw(w: World) -> Dictionary:
	var parts: Array[Rect2i] = []
	var doors: Array[Vector2i] = []
	var mains: Array[Rect2i] = []
	var first := _shape(w.rng)
	var at := AREA.position
	while not _moved(first.rects, at).all(func(r): return _clear(w, r)):
		first = _shape(w.rng)
		at = Vector2i(
			w.rng.randi_range(AREA.position.x, AREA.end.x),
			w.rng.randi_range(AREA.position.y, AREA.end.y)
		)
	_stand(w, _moved(first.rects, at), parts)
	mains.append(_moved([first.main], at)[0])
	for i in TRIES:
		if mains.size() >= ROOMS:
			break
		_attach(w, parts, doors, mains)
	for p in doors:
		FloorGen._doorway(w, p)
	w.rooms.assign(mains)
	var plan := {spots = [], links = [], goal = Rect2i()}
	_hide_doors(w, plan.links)
	_loops(w, plan.links)
	plan.goal = Skeletons.far_ends(w)
	if w.secrets.keys().any(func(p): return w.rooms[0].grow(2).has_point(p)):
		plan.goal = Rect2i()
	return plan


## The storey's hidden doors at the mouths of straight ways, between floors that walk at least
## FloorGen.APART apart. The first room is picked after, by none of them: it would show one.
static func _hide_doors(w: World, links: Array) -> void:
	var open := Masks.floor_of(w)
	for g: Array in _gaps(w):
		var from: Vector2i = g[0]
		var d: Vector2i = g[1]
		var door: Vector2i = from + d
		if w.secrets.size() >= FloorGen.hidden_doors(w.depth):
			return
		if (
			_gap(w, from, d) == g[2]
			and FloorGen._walled(w, door, d)
			and Grid.distance(from, open, from + d * (g[2] + 1)) >= FloorGen.APART
		):
			_way(w, from, d, g[2], links)
			w.tiles[Grid.index(door)] = World.WALL
			w.secrets[door] = true
			open = Masks.floor_of(w)


## Up to LOOPS straight ways, up to GAP tiles long, across a wall or the sky between floors
## that walk at least FloorGen.APART apart (Brogue addLoops): the rooms stand as a tree until
## these open. Each joins `links`.
static func _loops(w: World, links: Array) -> void:
	var open := Masks.floor_of(w)
	var cut := 0
	for g: Array in _gaps(w):
		var from: Vector2i = g[0]
		var d: Vector2i = g[1]
		var to: Vector2i = from + d * (g[2] + 1)
		if cut >= LOOPS:
			return
		if _gap(w, from, d) == g[2] and Grid.distance(from, open, to) >= FloorGen.APART:
			_way(w, from, d, g[2], links)
			open = Masks.floor_of(w)
			cut += 1


## Every place a straight way can go, as [floor tile, way, tiles between], in a random order.
static func _gaps(w: World) -> Array:
	var gaps := []
	for i in w.tiles.size():
		if w.tiles[i] != World.FLOOR:
			continue
		var p := Grid.at(i)
		for d: Vector2i in WAYS:
			var long := _gap(w, p, d)
			if long > 0:
				gaps.append([p, d, long])
	FloorGen.shuffle(w.rng, gaps)
	return gaps


## How many tiles of wall or sky lie from `p` along `d` before the next floor, when that
## floor is near enough and a wall stands to both sides of the wall `p` faces; else 0.
static func _gap(w: World, p: Vector2i, d: Vector2i) -> int:
	if w.tile(p + d) != World.WALL:
		return 0
	var side := Vector2i(d.y, d.x)
	for long in range(1, GAP + 1):
		var at := p + d * long
		if not AREA.has_point(at):
			return 0
		var t := w.tile(at)
		if t == World.FLOOR:
			return long - 1 if w.tile(at - d) == World.WALL else 0
		if t != World.WALL and t != World.SKY:
			return 0
		var a := w.tile(at + side)
		var b := w.tile(at - side)
		if a != World.WALL and a != World.SKY or b != World.WALL and b != World.SKY:
			return 0
	return 0


## A way of floor `long` tiles long from `p` along `d`, its ends doorways, its sides walled
## where they were sky.
static func _way(w: World, p: Vector2i, d: Vector2i, long: int, links: Array) -> void:
	var side := Vector2i(d.y, d.x)
	for i in range(1, long + 1):
		var at := p + d * i
		w.tiles[Grid.index(at)] = World.FLOOR
		for s: Vector2i in [at + side, at - side]:
			if w.tile(s) == World.SKY:
				w.tiles[Grid.index(s)] = World.WALL
	FloorGen._doorway(w, p + d)
	if long > 1:
		FloorGen._doorway(w, p + d * long)
	links.append({at = p + d, a = p, b = p + d * (long + 1)})


## Tries one room off a random side of a random rectangle standing, by a door there and at
## the end of a hall at the chance HALLS. It stands when no floor lies within a tile of it.
static func _attach(
	w: World, parts: Array[Rect2i], doors: Array[Vector2i], mains: Array[Rect2i]
) -> void:
	var from := parts[w.rng.randi_range(0, parts.size() - 1)]
	var side: Vector2i = Placement.SIDES[w.rng.randi_range(0, 3)]
	var across := Vector2i(absi(side.y), absi(side.x))
	var door := _edge(from, side) + side + across * w.rng.randi_range(0, _span(from, across) - 1)
	var new: Array[Rect2i] = []
	var mouth := door + side
	if w.rng.randf() < HALLS:
		var long := w.rng.randi_range(HALL.x, HALL.y)
		new.append(
			Rect2i(mouth.min(mouth + side * (long - 1)), Vector2i.ONE + side.abs() * (long - 1))
		)
		mouth += side * long
	var shape := _shape(w.rng)
	var entry: Rect2i = shape.rects[w.rng.randi_range(0, shape.rects.size() - 1)]
	var near := Vector2i(
		entry.size.x - 1 if side.x < 0 else 0, entry.size.y - 1 if side.y < 0 else 0
	)
	var along := across * w.rng.randi_range(0, _span(entry, across) - 1)
	var offset := mouth - near - along - entry.position
	new.append_array(_moved(shape.rects, offset))
	if w.tile(door) == World.FLOOR:
		return
	for r in new:
		if not _clear(w, r):
			return
	_stand(w, new, parts)
	mains.append(_moved([shape.main], offset)[0])
	doors.append(door)


## `r` with a tile round it lies in AREA, and nothing round or under it is floor.
static func _clear(w: World, r: Rect2i) -> bool:
	var round_it := r.grow(1)
	if not AREA.encloses(round_it):
		return false
	var tiles := w.tiles
	for y in range(round_it.position.y, round_it.end.y):
		var row := y * Grid.W
		for x in range(round_it.position.x, round_it.end.x):
			if tiles[row + x] == World.FLOOR:
				return false
	return true


## Draws `rects` as one space with its walls, and adds them to `parts`.
static func _stand(w: World, rects: Array[Rect2i], parts: Array[Rect2i]) -> void:
	for r in rects:
		FloorGen._fill(w, r.grow(1), World.WALL)
	for r in rects:
		FloorGen._fill(w, r, World.FLOOR)
	parts.append_array(rects)


## The corner of `r` on `side` that its tiles on that side run from.
static func _edge(r: Rect2i, side: Vector2i) -> Vector2i:
	return Vector2i(
		r.end.x - 1 if side.x > 0 else r.position.x, r.end.y - 1 if side.y > 0 else r.position.y
	)


## How many tiles `r` runs along `axis`.
static func _span(r: Rect2i, axis: Vector2i) -> int:
	return r.size.x if axis.x != 0 else r.size.y


## `rects` moved by `by`.
static func _moved(rects: Array, by: Vector2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for r: Rect2i in rects:
		out.append(Rect2i(r.position + by, r.size))
	return out


## A room of random shape round the origin: {rects, main}, its largest rectangle.
static func _shape(rng: RandomNumberGenerator) -> Dictionary:
	var rects: Array[Rect2i]
	match rng.randi_range(0, 4):
		0:
			rects = _cross(rng)
		1:
			rects = _even_cross(rng)
		2:
			rects = _round(rng)
		3:
			rects = _chunky(rng)
		_:
			rects = [Rect2i(0, 0, rng.randi_range(4, 11), rng.randi_range(3, 7))]
	var main := rects[0]
	for r in rects:
		if mini(r.size.x, r.size.y) >= FloorGen.ROOM_LEAST and r.get_area() > main.get_area():
			main = r
	return {rects = rects, main = main}


## Two bars across each other, the crossing off the middle (Brogue designCrossRoom).
static func _cross(rng: RandomNumberGenerator) -> Array[Rect2i]:
	var wide := Rect2i(0, 0, rng.randi_range(6, 13), rng.randi_range(3, 5))
	var tall := Vector2i(rng.randi_range(3, 5), rng.randi_range(6, 9))
	var at := Vector2i(
		rng.randi_range(0, wide.size.x - tall.x), -rng.randi_range(1, tall.y - wide.size.y)
	)
	return [wide, Rect2i(at, tall)]


## Two bars across each other's middles (Brogue designSymmetricalCrossRoom).
static func _even_cross(rng: RandomNumberGenerator) -> Array[Rect2i]:
	var wide := Rect2i(0, 0, rng.randi_range(7, 11), 3)
	var tall := Vector2i(3, rng.randi_range(7, 9))
	return [wide, Rect2i((wide.size.x - 3) / 2, -(tall.y - 3) / 2, tall.x, tall.y)]


## A disc, row by row, largest row first (Brogue designCircularRoom).
static func _round(rng: RandomNumberGenerator) -> Array[Rect2i]:
	var radius := rng.randi_range(2, 5)
	var rows: Array[Rect2i] = [Rect2i(-radius + 1, -radius + 1, radius * 2 - 1, radius * 2 - 1)]
	for dy in range(0, radius + 1):
		var half := int(sqrt(radius * radius + radius - dy * dy))
		rows.append(Rect2i(-half, dy, 2 * half + 1, 1))
		if dy > 0:
			rows.append(Rect2i(-half, -dy, 2 * half + 1, 1))
	return rows


## Blocks of 3 by 3, each overlapping one before it (Brogue designChunkyRoom).
static func _chunky(rng: RandomNumberGenerator) -> Array[Rect2i]:
	var out: Array[Rect2i] = [Rect2i(0, 0, 3, 3)]
	for i in rng.randi_range(2, 5):
		var from := out[rng.randi_range(0, out.size() - 1)]
		out.append(
			Rect2i(
				from.position + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2)),
				Vector2i(3, 3)
			)
		)
	return out
