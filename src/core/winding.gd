class_name Winding
extends RefCounted
## 꺾인 복도: a hall three tiles wide that turns again and again from one end of the storey to
## the other, the longest way through a maze that prefers to turn. The start and the exit
## lie at its two ends. What is left of the map beside it is rooms of one, two or four cells,
## some of it sky.

## A cell's size with one wall, and how many fit on the map.
const STEP := 4
const CELLS := Vector2i(13, 6)
## The chance that a cell off the hall stays sky, and that a room takes in four cells.
const SKY := 0.3
const BIG := 0.3
## A hall of fewer cells is drawn again.
const LEAST_HALL := 26


static func draw(w: World) -> Dictionary:
	var origin := Vector2i(
		w.rng.randi_range(0, Grid.W - 2 - CELLS.x * STEP),
		w.rng.randi_range(0, Grid.H - 2 - CELLS.y * STEP)
	)
	var path := _longest_way(w.rng)
	var hall := path.slice(1, path.size() - 1)
	var spaces := _spaces(w.rng, hall, path[0], path[-1], origin)
	var parts: Array[Rect2i] = []
	for i in hall.size():
		parts.append(_cell(hall[i], origin))
		if i > 0:
			parts.append(_cell(hall[i - 1], origin).merge(_cell(hall[i], origin)))
	for r: Rect2i in spaces + parts:
		FloorGen._fill(w, r.grow(1), World.WALL)
	for r: Rect2i in spaces + parts:
		FloorGen._fill(w, r, World.FLOOR)
	w.rooms.assign(spaces)
	var home := FloorGen.room_at(w, _cell(path[0], origin).position)
	var goal := FloorGen.room_at(w, _cell(path[-1], origin).position)
	Skeletons._door(w, home, _cell(hall[0], origin))
	Skeletons._door(w, goal, _cell(hall[-1], origin))
	var cells: Array[Rect2i] = []
	for c: Vector2i in hall:
		cells.append(_cell(c, origin))
	_doors_off_hall(w, cells, [home, goal])
	Skeletons._first(w, home)
	return {spots = [], links = [], goal = goal, sealed = Cave._thin_walls(w)}


## A door from each room to a cell of the hall or to a room with a way to it: a tree, so the
## hall stays the only way along. The rooms that have `skip` their door already.
static func _doors_off_hall(w: World, cells: Array[Rect2i], skip: Array) -> void:
	var joined: Array[Rect2i] = cells.duplicate()
	joined.append_array(skip)
	var left := w.rooms.filter(func(r): return not skip.has(r))
	FloorGen.shuffle(w.rng, left)
	var cut := true
	while cut and not left.is_empty():
		cut = false
		for r: Rect2i in left.duplicate():
			if joined.any(func(o): return Skeletons._door(w, r, o)):
				joined.append(r)
				left.erase(r)
				cut = true


## The tiles of cell `c`, without walls.
static func _cell(c: Vector2i, origin: Vector2i) -> Rect2i:
	return Rect2i(origin + Vector2i.ONE + c * STEP, Vector2i(STEP - 1, STEP - 1))


## The cells of the longest way through a maze dug from a random cell, turning whenever it
## can (a recursive backtracker that goes straight only when it must).
static func _longest_way(rng: RandomNumberGenerator) -> Array:
	var free := {}
	for y in CELLS.y:
		for x in CELLS.x:
			free[Vector2i(x, y)] = true
	while true:
		var from := Vector2i(rng.randi_range(0, CELLS.x - 1), rng.randi_range(0, CELLS.y - 1))
		var links := _dig(rng, from, free)
		var far := _farthest(links, from)
		var path := _farthest(links, far[-1])
		if path.size() >= LEAST_HALL:
			return path
	return []


## The links of a maze over the `free` cells joined to `from`: cell -> its neighbours.
static func _dig(rng: RandomNumberGenerator, from: Vector2i, free: Dictionary) -> Dictionary:
	var links := {from: []}
	var stack: Array[Vector2i] = [from]
	var came := Vector2i.ZERO
	while not stack.is_empty():
		var at: Vector2i = stack[-1]
		var open := Placement.SIDES.filter(
			func(d): return free.has(at + d) and not links.has(at + d)
		)
		if open.is_empty():
			stack.pop_back()
			came = Vector2i.ZERO
			continue
		var turning := open.filter(func(d): return d != came)
		var pick: Array = turning if not turning.is_empty() else open
		var d: Vector2i = pick[rng.randi_range(0, pick.size() - 1)]
		var next := at + d
		links[next] = [at]
		links[at].append(next)
		stack.append(next)
		came = d
	return links


## The way from `from` to the cell farthest along `links`: cells, `from` first.
static func _farthest(links: Dictionary, from: Vector2i) -> Array:
	var back := {from: from}
	var queue: Array[Vector2i] = [from]
	var last := from
	while not queue.is_empty():
		last = queue.pop_front()
		for n: Vector2i in links[last]:
			if not back.has(n):
				back[n] = last
				queue.append(n)
	var way := [last]
	while way[0] != from:
		way.push_front(back[way[0]])
	return way


## The rooms on the cells off the `hall`: `first` and `last` are always rooms.
static func _spaces(
	rng: RandomNumberGenerator, hall: Array, first: Vector2i, last: Vector2i, origin: Vector2i
) -> Array:
	var free := {}
	for y in CELLS.y:
		for x in CELLS.x:
			if not hall.has(Vector2i(x, y)):
				free[Vector2i(x, y)] = true
	var out := []
	var cells := free.keys()
	FloorGen.shuffle(rng, cells)
	for c: Vector2i in cells:
		if not free.has(c):
			continue
		free.erase(c)
		var ends := c == first or c == last
		if not ends and rng.randf() < SKY:
			continue
		var r := _cell(c, origin)
		var block := [c + Vector2i.RIGHT, c + Vector2i.DOWN, c + Vector2i.ONE]
		if rng.randf() < BIG and block.all(func(n): return free.has(n)):
			for n: Vector2i in block:
				free.erase(n)
				r = r.merge(_cell(n, origin))
		else:
			for d: Vector2i in Placement.SIDES:
				if free.has(c + d):
					free.erase(c + d)
					r = r.merge(_cell(c + d, origin))
					break
		out.append(r)
	return out
