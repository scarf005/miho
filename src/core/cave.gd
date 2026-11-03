class_name Cave
extends RefCounted
## 무너진 석굴: tunnels dug out of the rock from a few small rooms (DCSS dgn-delve.cc `delve`).
## Only the small rooms are on World.rooms; the rest is tunnel one tile wide. Half the walls
## one tile thick are cracked, so that a hit opens a side way. The rock with nothing to stand
## beside falls away to the sky.

## How many rooms are tried and the size of one (least, most).
const ROOMS := 14
const TRIES := 200
const ROOM := Rect2i(4, 3, 6, 4)
## The chance the sky bites into a corner and how large a bite is (least, most).
const BITES := 0.8
const BITE := Rect2i(9, 5, 22, 10)
## A rock is dug with this many open tiles round it (least, most), and at the chance JOINS
## when it would join two ways; the share of the map dug, and how far back in the list of
## rocks to dig a dig may reach.
const AROUND := Vector2i(1, 3)
const JOINS := 0.12
const COVER := 0.42
const REACH := 125
const CRACKED := 0.25


static func draw(w: World) -> Dictionary:
	var area := Rect2i(1, 1, Grid.W - 2, Grid.H - 2)
	FloorGen._fill(w, area, World.WALL)
	_rooms(w, area.grow(-2), _bites(w, area))
	_delve(w, area.grow(-1))
	_join(w)
	_bare(w, area)
	var goal := Skeletons.far_ends(w)
	var thin := _thin_walls(w)
	_hide_doors(w, thin)
	_crack(w, thin)
	return {spots = [], links = [], goal = goal}


## Rooms of random size in `area`, none within two tiles of another.
static func _rooms(w: World, area: Rect2i, bites: Array[Rect2i]) -> void:
	for i in TRIES:
		if w.rooms.size() >= ROOMS:
			return
		var size := Vector2i(
			w.rng.randi_range(ROOM.position.x, ROOM.size.x),
			w.rng.randi_range(ROOM.position.y, ROOM.size.y)
		)
		var r := Rect2i(
			area.position.x + w.rng.randi_range(0, area.size.x - size.x),
			area.position.y + w.rng.randi_range(0, area.size.y - size.y),
			size.x,
			size.y
		)
		var clear := func(o): return not o.grow(2).intersects(r)
		if w.rooms.all(clear) and bites.all(clear):
			FloorGen._fill(w, r, World.FLOOR)
			w.rooms.append(r)


## The sky bites into the corners of `area` at the chance BITES, so that
## no two caves have one outline. Returns the bites.
static func _bites(w: World, area: Rect2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for corner: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		var size := Vector2i(
			w.rng.randi_range(BITE.position.x, BITE.size.x),
			w.rng.randi_range(BITE.position.y, BITE.size.y)
		)
		var r := Rect2i(area.position + (area.size - size) * corner, size)
		if w.rng.randf() < BITES:
			out.append(r)
			FloorGen._fill(w, r, World.SKY)
	return out


## Digs `area` from the rocks beside the rooms until COVER of it is open. A rock is dug only
## with AROUND open tiles round it, and at the chance JOINS when those lie in two groups.
static func _delve(w: World, area: Rect2i) -> void:
	var store: Array[int] = []
	for r in w.rooms:
		for x in range(r.position.x - 1, r.end.x + 1):
			store.append(Grid.index(Vector2i(x, r.position.y - 1)))
			store.append(Grid.index(Vector2i(x, r.end.y)))
		for y in range(r.position.y, r.end.y):
			store.append(Grid.index(Vector2i(r.position.x - 1, y)))
			store.append(Grid.index(Vector2i(r.end.x, y)))
	FloorGen.shuffle(w.rng, store)
	var left := int(area.get_area() * COVER)
	var tiles := w.tiles
	while left > 0 and not store.is_empty():
		var at := store.size() - 1 - w.rng.randi_range(0, mini(REACH, store.size()) - 1)
		var i: int = store[at]
		store[at] = store[store.size() - 1]
		store.pop_back()
		var p := Grid.at(i)
		if tiles[i] != World.WALL or not area.has_point(p):
			continue
		var around := _around(tiles, i)
		if (
			around.count < AROUND.x
			or around.count > AROUND.y
			or (around.groups > 1 and w.rng.randf() >= JOINS)
		):
			continue
		tiles[i] = World.FLOOR
		left -= 1
		for d in Grid.DIRS:
			store.append(Grid.index(p + d))
	w.tiles = tiles


## How many of the eight tiles round tile `i` are open, and in how many groups (DCSS
## ngb_count, ngb_groups): diagonal tiles join a group too, but the sides reach no corner.
static func _around(tiles: PackedByteArray, i: int) -> Dictionary:
	var p := Grid.at(i)
	var count := 0
	var groups := 0
	var prev2 := false
	var prev: bool = tiles[Grid.index(p + Grid.DIRS[0])] == World.FLOOR
	for d in range(7, -1, -1):
		var cur: bool = tiles[Grid.index(p + Grid.DIRS[d])] == World.FLOOR
		count += 1 if cur else 0
		if cur and not prev and (d % 2 == 1 or not prev2):
			groups += 1
		prev2 = prev
		prev = cur
	if prev and groups == 0:
		groups = 1
	return {count = count, groups = groups}


## A tunnel from the middle of each room no walk reaches to the first room's middle, in a
## straight line along each axis.
static func _join(w: World) -> void:
	for r in w.rooms:
		var from := FloorGen._centre(w.rooms[0])
		var to := FloorGen._centre(r)
		if Grid.distance(from, Masks.floor_of(w), to) >= 0:
			continue
		var p := from
		while p != to:
			p += (Vector2i(to.x, p.y) - p).sign() if p.x != to.x else (to - p).sign()
			if w.tile(p) != World.FLOOR:
				w.tiles[Grid.index(p)] = World.FLOOR


## Rock with no floor against it, side or corner, falls away to the sky, and floor at the
## edge of the sky keeps a wall.
static func _bare(w: World, area: Rect2i) -> void:
	var tiles := w.tiles
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var p := Vector2i(x, y)
			if w.tile(p) != World.FLOOR:
				var by_floor := Grid.DIRS.any(func(d): return w.tile(p + d) == World.FLOOR)
				tiles[Grid.index(p)] = World.WALL if by_floor else World.SKY
	w.tiles = tiles


## The walls one tile thick with floor on both sides, as [tile, across], in a random order.
static func _thin_walls(w: World) -> Array:
	var out := []
	for i in w.tiles.size():
		if w.tiles[i] != World.WALL:
			continue
		var p := Grid.at(i)
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if w.tile(p - d) == World.FLOOR and w.tile(p + d) == World.FLOOR:
				out.append([p, d])
	FloorGen.shuffle(w.rng, out)
	return out


## The storey's hidden doors on walls of `thin` between ways that walk far apart, never by
## the first room, where one would be found at once.
static func _hide_doors(w: World, thin: Array) -> void:
	var open := Masks.floor_of(w)
	for s: Array in thin:
		var p: Vector2i = s[0]
		var d: Vector2i = s[1]
		if w.secrets.size() >= FloorGen.hidden_doors(w.depth):
			return
		if (
			FloorGen._walled(w, p, d)
			and not w.rooms[0].grow(2).has_point(p)
			and Grid.distance(p - d, open, p + d) >= FloorGen.SHORTCUT
		):
			w.secrets[p] = true


## CRACKED of the walls of `thin` that hide no door and touch none.
static func _crack(w: World, thin: Array) -> void:
	for s: Array in thin:
		var p: Vector2i = s[0]
		var near := Placement.SIDES.any(func(d): return w.secrets.has(p + d))
		if not w.secrets.has(p) and not near and w.rng.randf() < CRACKED:
			w.tiles[Grid.index(p)] = World.WALL_CRACKED
