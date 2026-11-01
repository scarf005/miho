class_name Skeletons
extends RefCounted
## The skeletons a storey is built on: what its tiles and rooms look like before
## anything is laid in them (FloorGen). Every plan draws rooms on World.rooms, the
## start room first, and returns {spots, links, goal}: the wall tiles left that
## could still be doorways (FloorGen._doorways), the far links it cut, and the room
## that holds the exit (empty for the room farthest from the start). Halls are not
## on World.rooms, so nothing is laid in them and they stay walkable.
##
## 누각 (pavilions): pavilions in a row joined by bridges (FloorGen._pavilions).
## 고리 회랑 (ring): a hall round a court of sky that one bridge crosses, rooms outside it.
## 천상 대로 (avenue): a lit hall from end to end, with a row of rooms along each side,
## each row joined by doorways from end to end.
## 쌍탑 (towers): two stepped towers, floor on floor, joined by bridges at different
## heights; the start and the exit lie at opposite ends of opposite towers.
## 부서진 층 (broken): BrokenFloor.
##
## A plan's `spots` may be opened as far doorways or hidden; its `sealed` tiles may only
## be hidden doors.

const PAVILIONS := &"pavilions"
const RING := &"ring"
const AVENUE := &"avenue"
const TOWERS := &"towers"
const BROKEN := &"broken"
## What a storey may be built on; `pick` draws from it.
const ALL: Array[StringName] = [PAVILIONS, RING, AVENUE, TOWERS]
## The skeletons with one way to the exit: no two routes are asked of them.
const ONE_WAY: Array[StringName] = [PAVILIONS]
## Tiles this near the start room and the exit room may lie on both routes (`two_ways`).
const NEAR_ENDS := 3
## How many rooms `far_ends` tries as the start.
const ENDS_TRIED := 8
## A row of rooms: a room's width with one wall (least, most), and how deep it goes.
const LOT := Vector2i(6, 12)
const DEEP := 7
## The chance that the space for a room of a ring stays sky, and that a room has
## another behind it.
const RING_GAPS := 0.15
const BEHIND := 0.6
## How far the ring's outer wall lies from the map's west and north edges, and the
## other two (least, most).
const RING_X := Vector2i(7, 12)
const RING_Y := Vector2i(5, 7)
const RING_HALL := 2
## The top row of an avenue's hall (least, most), its width, the size of the room at
## each end across and how far that room reaches beyond the hall, and the steps
## between lanterns.
const AVENUE_ROW := Vector2i(8, 17)
const AVENUE_HALL := 3
const AVENUE_END := Vector2i(6, 9)
const AVENUE_REACH := Vector2i(3, 6)
const AVENUE_LAMPS := Vector2i(6, 9)
## A tower's middle (least width, most), how far a floor may stand out of it on each
## side, and how tall a floor is with one wall.
const TOWER_WIDTH := Vector2i(10, 15)
const TOWER_STEP := 3
const TOWER_FLOOR := Vector2i(5, 9)
const TOWER_LANDINGS := 2
## How many rows apart the middles of the start room and the exit room are at least.
const TOWER_ENDS := 9


## The skeleton of the storey being built. A table of skeletons by storey replaces
## this draw once every skeleton exists.
static func pick(w: World) -> StringName:
	return ALL[w.rng.randi_range(0, ALL.size() - 1)]


## Draws a storey on `skeleton`.
static func draw(w: World, skeleton: StringName) -> Dictionary:
	match skeleton:
		RING:
			return _ring(w)
		AVENUE:
			return _avenue(w)
		TOWERS:
			return _towers(w)
		BROKEN:
			return BrokenFloor.draw(w)
	return FloorGen.pavilions(w)


## Whether `skeleton`'s routes stand, but on a skeleton with one way (ONE_WAY): two lead
## from `home` to `goal`, and one is left with every plank burnt and every plate shut.
static func routes_hold(w: World, skeleton: StringName, home: Rect2i, goal: Rect2i) -> bool:
	if ONE_WAY.has(skeleton):
		return true
	var left := Masks.floor_of(w, w.traps.keys() + planks(w), func(_p): return false)
	var from := FloorGen._centre(home)
	var to := Grid.index(FloorGen._centre(goal))
	return two_ways(w, home, goal) and Grid.search(from, left).dist[to] >= 0


## The tiles of the storey that burn away to sky (Terrain.plank).
static func planks(w: World) -> Array:
	var out := []
	var at := w.tiles.find(World.BOARD)
	while at >= 0:
		if Terrain.plank(w, Grid.at(at)):
			out.append(Grid.at(at))
		at = w.tiles.find(World.BOARD, at + 1)
	return out


## Makes a random room the start, the first of ENDS_TRIED with two routes to the room
## farthest from it; returns that room, or an empty rect when none has.
static func far_ends(w: World) -> Rect2i:
	var homes := w.rooms.duplicate()
	FloorGen.shuffle(w.rng, homes)
	for home: Rect2i in homes.slice(0, ENDS_TRIED):
		var goal := FloorGen._farthest(w, FloorGen._centre(home))
		if goal != home and two_ways(w, home, goal):
			_first(w, home)
			return goal
	return Rect2i()


## Whether the walk from the middle of `home` to the middle of `goal` has two routes
## that share no tile but near those rooms (NEAR_ENDS): no block of 3 by 3 tiles
## away from them cuts it. A block that cuts it stands on every route, so only
## those on the shortest one are tried.
static func two_ways(w: World, home: Rect2i, goal: Rect2i) -> bool:
	var open := Masks.floor_of(w, w.traps.keys(), func(_p): return false)
	var from := home.position + home.size / 2
	var to := Grid.index(goal.position + goal.size / 2)
	var found := Grid.search(from, open)
	if found.dist[to] < 0:
		return false
	var tried := {}
	var at: int = to
	while at >= 0:
		for d in Grid.DIRS + [Vector2i.ZERO]:
			var mid: Vector2i = Grid.at(at) + d
			if tried.has(mid) or home.grow(NEAR_ENDS).has_point(mid):
				continue
			if goal.grow(NEAR_ENDS).has_point(mid):
				continue
			tried[mid] = true
			if Grid.search(from, _without(open, mid)).dist[to] < 0:
				return false
		at = found.parent[at]
	return true


## `open` with the 3 by 3 tiles round `mid` shut.
static func _without(open: PackedByteArray, mid: Vector2i) -> PackedByteArray:
	var out := open.duplicate()
	for d in Grid.DIRS + [Vector2i.ZERO]:
		if Grid.inside(mid + d):
			out[Grid.index(mid + d)] = 0
	return out


## The ring: a hall RING_HALL wide round a court of sky, rooms outside it on all
## four sides, the start and the exit on the hall on far sides of it, and a bridge
## across the court by way of an island in its middle.
static func _ring(w: World) -> Dictionary:
	var west := w.rng.randi_range(RING_X.x, RING_X.y)
	var north := w.rng.randi_range(RING_Y.x, RING_Y.y)
	var east := Grid.W - 1 - w.rng.randi_range(RING_X.x, RING_X.y)
	var south := Grid.H - 1 - w.rng.randi_range(RING_Y.x, RING_Y.y)
	var outer := Rect2i(west, north, east - west + 1, south - north + 1)
	var inside := outer.grow(-1)
	var court := inside.grow(-RING_HALL - 1)
	FloorGen._fill(w, outer, World.WALL)
	FloorGen._fill(w, inside, World.FLOOR)
	FloorGen._fill(w, court.grow(1), World.WALL)
	FloorGen._fill(w, court, World.SKY)
	var halls: Array[Rect2i] = [
		Rect2i(inside.position, Vector2i(inside.size.x, RING_HALL)),
		Rect2i(inside.position.x, inside.end.y - RING_HALL, inside.size.x, RING_HALL),
		Rect2i(inside.position, Vector2i(RING_HALL, inside.size.y)),
		Rect2i(inside.end.x - RING_HALL, inside.position.y, RING_HALL, inside.size.y),
	]
	_wing(w, Vector2i(1, north), Vector2i(Grid.W - 2, north), Vector2i.UP, RING_GAPS)
	_wing(w, Vector2i(1, south), Vector2i(Grid.W - 2, south), Vector2i.DOWN, RING_GAPS)
	_wing(w, outer.position, Vector2i(west, south), Vector2i.LEFT, RING_GAPS)
	_wing(w, Vector2i(east, north), Vector2i(east, south), Vector2i.RIGHT, RING_GAPS)
	var near := w.rooms.filter(
		func(r): return halls.any(func(h): return not _door_spots(w, r, h).is_empty())
	)
	var home: Rect2i = near[w.rng.randi_range(0, near.size() - 1)]
	var goal := home
	for r: Rect2i in near:
		if _gap(r, home) > _gap(goal, home):
			goal = r
	for r in [home, goal]:
		halls.any(func(h): return _door(w, r, h))
	_first(w, home)
	var plan := {spots = FloorGen._doorways(w, halls), links = [], goal = goal}
	_cross(w, court, plan.links)
	return plan


## How far apart the middles of two rooms are.
static func _gap(a: Rect2i, b: Rect2i) -> int:
	return Grid.cheb(a.get_center(), b.get_center())


## The bridge over `court`, along its longer side or across it, with an island of
## floor in the middle; the walk it saves is always long enough, else it stays uncut.
static func _cross(w: World, court: Rect2i, links: Array) -> void:
	var mid := court.get_center()
	var along := w.rng.randf() < 0.5
	var from := (
		Vector2i(court.position.x - 2, mid.y) if along else Vector2i(mid.x, court.position.y - 2)
	)
	var to := Vector2i(court.end.x + 1, mid.y) if along else Vector2i(mid.x, court.end.y + 1)
	var dir: Vector2i = Vector2i.RIGHT if along else Vector2i.DOWN
	if Grid.search(from, Masks.floor_of(w)).dist[Grid.index(to)] < FloorGen.APART:
		return
	links.append({at = from + dir, a = from, b = to})
	var p := from + dir
	while p != to:
		w.tiles[Grid.index(p)] = World.BRIDGE if court.has_point(p) else World.FLOOR
		p += dir
	FloorGen._fill(w, Rect2i(mid - Vector2i.ONE, Vector2i(3, 3)), World.FLOOR)


## The avenue: a straight hall between a room at each end, a row of rooms along each
## side joined by doorways from end room to end room, and lanterns along the hall.
static func _avenue(w: World) -> Dictionary:
	var y := w.rng.randi_range(AVENUE_ROW.x, AVENUE_ROW.y)
	var ends: Array[Rect2i] = [_avenue_end(w, true, y), _avenue_end(w, false, y)]
	var hall_x: int = ends[0].end.x + 1
	var hall := Rect2i(hall_x, y, ends[1].position.x - 1 - hall_x, AVENUE_HALL)
	FloorGen._fill(w, hall.grow(1), World.WALL)
	FloorGen._fill(w, hall, World.FLOOR)
	for side: Array in [[y - 1, Vector2i.UP], [hall.end.y, Vector2i.DOWN]]:
		var from := Vector2i(hall_x - 1, side[0])
		var to := Vector2i(hall.end.x, side[0])
		var row := _wing(w, from, to, side[1], 0.0)
		var path: Array[Rect2i] = [ends[0]]
		path.append_array(row)
		path.append(ends[1])
		for k in range(1, path.size()):
			_door(w, path[k - 1], path[k])
	for r in ends:
		_door(w, r, hall)
	if w.rng.randf() < 0.5:
		ends.reverse()
	_first(w, ends[0])
	_avenue_lamps(w, hall, ends[0])
	return {spots = FloorGen._doorways(w, [hall]), links = [], goal = ends[1]}


## The room at an end of the avenue, west or east, round the hall's rows from y.
static func _avenue_end(w: World, west: bool, y: int) -> Rect2i:
	var width := w.rng.randi_range(AVENUE_END.x, AVENUE_END.y)
	var off := w.rng.randi_range(1, 3)
	var top := w.rng.randi_range(AVENUE_REACH.x, AVENUE_REACH.y)
	var low := w.rng.randi_range(AVENUE_REACH.x, AVENUE_REACH.y)
	var x := off if west else Grid.W - off - width
	var wall := Rect2i(x, y - top, width, top + AVENUE_HALL + low)
	FloorGen._fill(w, wall, World.WALL)
	FloorGen._fill(w, wall.grow(-1), World.FLOOR)
	w.rooms.append(wall.grow(-1))
	return wall.grow(-1)


## Lanterns on the hall's two edge rows by turns, out of reach of the start room's middle.
static func _avenue_lamps(w: World, hall: Rect2i, home: Rect2i) -> void:
	var x := hall.position.x + w.rng.randi_range(AVENUE_LAMPS.x, AVENUE_LAMPS.y)
	var row := hall.position.y if w.rng.randf() < 0.5 else hall.end.y - 1
	while x < hall.end.x - 1:
		var p := Vector2i(x, row)
		if Grid.cheb(p, home.position + home.size / 2) > Light.LANTERN_RADIUS:
			w.tiles[Grid.index(p)] = World.LANTERN
		row = hall.position.y + hall.end.y - 1 - row
		x += w.rng.randi_range(AVENUE_LAMPS.x, AVENUE_LAMPS.y)


## The towers: floor on floor, each floor stepping out of the tower's middle by its
## own amount and cut into rooms; bridges join them at different heights: the
## lowest and highest first, joining the start at one end to the exit at the other
## by two ways round, then TOWER_LANDINGS between them where the walk is long.
static func _towers(w: World) -> Dictionary:
	var wide := w.rng.randi_range(TOWER_WIDTH.x, TOWER_WIDTH.y)
	var west := _tower(w, w.rng.randi_range(4, 7), wide)
	wide = w.rng.randi_range(TOWER_WIDTH.x, TOWER_WIDTH.y)
	var east := _tower(w, Grid.W - 5 - w.rng.randi_range(0, 3) - wide, wide)
	var rows := _landings(w, west, east)
	if rows.size() < 2:
		return {spots = [], links = [], goal = Rect2i()}
	var low: Array = rows[w.rng.randi_range(0, rows.size() / 3)]
	var high: Array = rows[rows.size() - 1 - w.rng.randi_range(0, rows.size() / 3)]
	var ends := [low, high]
	if w.rng.randf() < 0.5:
		ends.reverse()
	var home := _landing_room(w, ends[0], w.rng.randf() < 0.5)
	var from_west := home.position.x < Grid.W / 2
	var goal := _landing_room(w, ends[1], not from_west)
	if absi(home.get_center().y - goal.get_center().y) < TOWER_ENDS:
		return {spots = [], links = [], goal = Rect2i()}
	_first(w, home)
	var plan := {spots = FloorGen._doorways(w, []), links = [], goal = goal}
	var crossed: Array[int] = []
	var picks: Array = [ends[0], ends[1]]
	var between := rows.filter(func(s): return s[0] > low[0] + 2 and s[0] < high[0] - 2)
	FloorGen.shuffle(w.rng, between)
	picks.append_array(between.slice(0, TOWER_LANDINGS))
	for s: Array in picks:
		if (
			crossed.all(func(y): return absi(y - s[0]) >= 3)
			and FloorGen.link_far(w, s[1], s[2], s[0], plan.links)
		):
			crossed.append(s[0])
	return plan


## The room inside a bridge's end on row s[0]: west tower or east.
static func _landing_room(w: World, s: Array, in_west: bool) -> Rect2i:
	var at := Vector2i(s[1].end.x - 2, s[0]) if in_west else Vector2i(s[2].position.x + 1, s[0])
	return FloorGen.room_at(w, at)


## One tower: floors from near the map's top to near its bottom, its middle `width`
## wide with its west wall at x.
static func _tower(w: World, x: int, width: int) -> Array[Rect2i]:
	var no_galleries: Array[Rect2i] = []
	var y := w.rng.randi_range(1, 3)
	var last := Grid.H - 2 - w.rng.randi_range(0, 2)
	var floors: Array[Rect2i] = []
	while y < last:
		var tall := w.rng.randi_range(TOWER_FLOOR.x, TOWER_FLOOR.y)
		if last - y - tall < TOWER_FLOOR.x:
			tall = last - y
		var out := w.rng.randi_range(0, TOWER_STEP)
		var wide := width + out + w.rng.randi_range(0, TOWER_STEP)
		var r := Rect2i(x - out, y, wide, tall + 1)
		FloorGen._fill(w, r, World.WALL)
		FloorGen._fill(w, r.grow(-1), World.FLOOR)
		FloorGen._split(w, r.grow(-1), no_galleries)
		floors.append(r)
		y += tall
	return floors


## The rows, top to bottom, where a straight bridge joins a floor of each tower:
## [row, west floor, east floor], with room floor just inside both walls.
static func _landings(w: World, west: Array[Rect2i], east: Array[Rect2i]) -> Array:
	var out := []
	for a in west:
		for b in east:
			for y in range(maxi(a.position.y, b.position.y) + 1, mini(a.end.y, b.end.y) - 1):
				if (
					w.tile(Vector2i(a.end.x - 2, y)) == World.FLOOR
					and w.tile(Vector2i(b.position.x + 1, y)) == World.FLOOR
				):
					out.append([y, a, b])
	return out


## Rooms side by side along the wall from `from` to `to`, going out from it in
## direction `out`, sharing walls: the row nearest the wall, returned in order,
## with another room behind some of them. Each space stays sky at the chance `gaps`.
static func _wing(
	w: World, from: Vector2i, to: Vector2i, out: Vector2i, gaps: float
) -> Array[Rect2i]:
	var along := (to - from).sign()
	var length := Grid.cheb(from, to)
	var room := 0
	while Grid.inside(from + out * (room + 3)):
		room += 1
	var row: Array[Rect2i] = []
	var at := 0
	while at < length:
		var width := w.rng.randi_range(LOT.x, LOT.y)
		if length - at - width < LOT.x:
			width = length - at
		if w.rng.randf() >= gaps:
			var deep := w.rng.randi_range(FloorGen.ROOM_LEAST, mini(room, DEEP))
			var near := from + along * at
			row.append(_lot(w, near, near + along * width, out, deep))
			if room - deep - 1 >= FloorGen.ROOM_LEAST and w.rng.randf() < BEHIND:
				var back := w.rng.randi_range(FloorGen.ROOM_LEAST, mini(room - deep - 1, DEEP))
				_lot(w, near + out * (deep + 1), near + along * width + out * (deep + 1), out, back)
		at += width
	return row


## A room with walls whose near wall runs from `a` to `b`, `deep` tiles deep in
## direction `out`. It joins World.rooms.
static func _lot(w: World, a: Vector2i, b: Vector2i, out: Vector2i, deep: int) -> Rect2i:
	var far := b + out * (deep + 1)
	var wall := Rect2i(a.min(far), (a - far).abs() + Vector2i.ONE)
	FloorGen._fill(w, wall, World.WALL)
	FloorGen._fill(w, wall.grow(-1), World.FLOOR)
	w.rooms.append(wall.grow(-1))
	return wall.grow(-1)


## A doorway at a random wall tile between `a` and `b`; false when they share none.
static func _door(w: World, a: Rect2i, b: Rect2i) -> bool:
	var spots := _door_spots(w, a, b)
	if spots.is_empty():
		return false
	FloorGen._doorway(w, spots[w.rng.randi_range(0, spots.size() - 1)])
	return true


## The wall tiles with `a` on one side and `b` on the other.
static func _door_spots(w: World, a: Rect2i, b: Rect2i) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for y in range(a.position.y - 1, a.end.y + 1):
		for x in range(a.position.x - 1, a.end.x + 1):
			var p := Vector2i(x, y)
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				if (
					w.tile(p) == World.WALL
					and (
						(a.has_point(p - d) and b.has_point(p + d))
						or (b.has_point(p - d) and a.has_point(p + d))
					)
				):
					spots.append(p)
	return spots


## Makes `home` the first room: the one Miho starts in.
static func _first(w: World, home: Rect2i) -> void:
	w.rooms.erase(home)
	w.rooms.push_front(home)
