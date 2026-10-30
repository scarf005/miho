class_name FloorGen
extends RefCounted
## Builds each storey: rooms joined by corridors with a few extra loops (so a
## hunted fox has somewhere to slip away), doors where corridors meet rooms,
## and lanterns in some rooms. Corridors stay dark. Miho starts in the westmost
## room; the stairs (the elixir on the top storey) sit in the room farthest
## from her, which is always lit. Watchers that never move stand by lanterns.

const PLAN := {
	1: [&"dokkaebi", &"dokkaebi", &"jangseung"],
	2: [&"bulgae", &"dokkaebi", &"dokkaebi", &"jangseung"],
	3: [&"haetae", &"imugi", &"dokkaebi", &"jangseung"],
	4: [&"cheonha", &"jiha", &"dokkaebi", &"dokkaebi", &"imugi"],
	5: [&"imugi", &"imugi", &"dokkaebi", &"dokkaebi", &"jangseung"],
	6: [&"bulgasari", &"dokkaebi", &"imugi", &"jangseung", &"dokkaebi"],
	7: [&"dokkaebi", &"dokkaebi", &"dokkaebi", &"imugi", &"imugi", &"jangseung"],
	8: [&"haetae", &"dokkaebi", &"dokkaebi", &"imugi", &"jangseung", &"jangseung"],
	9: [&"cheonnyeon", &"haetae", &"haetae", &"dokkaebi"],
}
const PEACH_FLOORS := [3, 5, 7, 9]
const MIN_ROOMS := 6
const MAX_ROOMS := 9
const LOOPS := 2
const LIT_ROOMS := 0.45
const FOE_DISTANCE := 8


static func build(w: World) -> void:
	var me := w.player()
	w.actors.assign([me])
	w.shots.clear()
	w.peaches.clear()
	w.round_no = 0
	w.known = PackedByteArray()
	w.seen = PackedByteArray()
	w.dim = PackedByteArray()
	me.rooted = 0
	me.stunned = 0
	me.blind = 0
	for attempt in 100:
		_carve(w)
		if w.rooms.size() >= MIN_ROOMS and _connected(w):
			break
	var home := w.rooms[0]
	w.start = _centre(home)
	me.pos = w.start
	var goal := _farthest(w, w.start)
	w.elixir = Vector2i(-1, -1)
	w.stairs = Vector2i(-1, -1)
	if w.depth >= World.FLOORS:
		w.elixir = _centre(goal)
	else:
		w.stairs = _centre(goal)
	_lanterns(w, home, goal)
	_creatures(w)
	if PEACH_FLOORS.has(w.depth):
		var spot := _random_spot(w, 6)
		if spot.x >= 0:
			w.peaches.append(spot)


static func _centre(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


static func _carve(w: World) -> void:
	w.tiles = PackedByteArray()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	w.rooms.clear()
	for i in 120:
		if w.rooms.size() >= MAX_ROOMS:
			break
		var size := Vector2i(w.rng.randi_range(4, 8), w.rng.randi_range(3, 5))
		var at := Vector2i(
			w.rng.randi_range(1, Grid.W - size.x - 1), w.rng.randi_range(1, Grid.H - size.y - 1)
		)
		var r := Rect2i(at, size)
		if w.rooms.any(func(o: Rect2i): return o.grow(1).intersects(r)):
			continue
		w.rooms.append(r)
		_fill(w, r, World.FLOOR)
	w.rooms.sort_custom(func(a: Rect2i, b: Rect2i): return _centre(a).x < _centre(b).x)
	for i in range(1, w.rooms.size()):
		_corridor(w, _centre(w.rooms[i - 1]), _centre(w.rooms[i]))
	for k in LOOPS:
		var a := w.rng.randi_range(0, w.rooms.size() - 1)
		var b := w.rng.randi_range(0, w.rooms.size() - 1)
		if absi(a - b) > 1:
			_corridor(w, _centre(w.rooms[a]), _centre(w.rooms[b]))
	_doors(w)


static func _fill(w: World, r: Rect2i, t: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			w.tiles[Grid.index(Vector2i(x, y))] = t


## An L-shaped corridor; the elbow side is random.
static func _corridor(w: World, a: Vector2i, b: Vector2i) -> void:
	var elbow := Vector2i(b.x, a.y) if w.rng.randf() < 0.5 else Vector2i(a.x, b.y)
	for leg in [[a, elbow], [elbow, b]]:
		var p: Vector2i = leg[0]
		var to: Vector2i = leg[1]
		var d := Vector2i(signi(to.x - p.x), signi(to.y - p.y))
		while true:
			w.tiles[Grid.index(p)] = World.FLOOR
			if p == to:
				break
			p += d


## A corridor tile on a room's edge, walled on both sides, may get a door.
static func _doors(w: World) -> void:
	for r in w.rooms:
		var ring := r.grow(1)
		for y in range(ring.position.y, ring.end.y):
			for x in range(ring.position.x, ring.end.x):
				var p := Vector2i(x, y)
				var top_or_bottom := y == ring.position.y or y == ring.end.y - 1
				var side := x == ring.position.x or x == ring.end.x - 1
				if top_or_bottom == side or w.tile(p) != World.FLOOR:
					continue
				var across := Vector2i(1, 0) if top_or_bottom else Vector2i(0, 1)
				if (
					w.tile(p + across) == World.WALL
					and w.tile(p - across) == World.WALL
					and w.rng.randf() < 0.6
				):
					w.tiles[Grid.index(p)] = World.DOOR


static func _connected(w: World) -> bool:
	var dist: PackedInt32Array = Grid.search(_centre(w.rooms[0]), w.open_floor).dist
	for i in w.tiles.size():
		if (w.tiles[i] == World.FLOOR or w.tiles[i] == World.DOOR) and dist[i] < 0:
			return false
	return true


static func _farthest(w: World, from: Vector2i) -> Rect2i:
	var dist: PackedInt32Array = Grid.search(from, w.open_floor).dist
	var best := w.rooms[0]
	for r in w.rooms:
		if dist[Grid.index(_centre(r))] > dist[Grid.index(_centre(best))]:
			best = r
	return best


## A lantern in a corner of the goal room and of some others, never the start room.
static func _lanterns(w: World, home: Rect2i, goal: Rect2i) -> void:
	for r in w.rooms:
		if r == home or (r != goal and w.rng.randf() >= LIT_ROOMS):
			continue
		var corners := [r.position, Vector2i(r.end.x - 1, r.position.y), r.end - Vector2i.ONE]
		corners.append(Vector2i(r.position.x, r.end.y - 1))
		corners.shuffle()
		for c: Vector2i in corners:
			if c == w.stairs or c == w.elixir or w.tile(c) != World.FLOOR:
				continue
			w.tiles[Grid.index(c)] = World.LANTERN
			if _connected(w):
				break
			w.tiles[Grid.index(c)] = World.FLOOR


static func _creatures(w: World) -> void:
	for kind in PLAN[w.depth]:
		var info := Bestiary.info(kind)
		var spot := Vector2i(-1, -1)
		if info.get("boss", false):
			spot = nearest_free(w, w.elixir + Vector2i(0, 1))
		elif info.get("move", &"static") == &"static":
			spot = _by_lantern(w)
		if spot.x < 0:
			spot = _random_spot(w, FOE_DISTANCE)
		if spot.x >= 0:
			var a := spawn(w, kind, spot)
			a.cooldown = w.rng.randi_range(1, info.get("cd", 1))


static func _by_lantern(w: World) -> Vector2i:
	var dist: PackedInt32Array = Grid.search(w.start, w.open_floor).dist
	var spots: Array[Vector2i] = []
	for i in w.tiles.size():
		if w.tiles[i] != World.LANTERN:
			continue
		for d in Grid.DIRS:
			var p: Vector2i = Grid.at(i) + d
			if (
				w.vacant(p)
				and p != w.stairs
				and p != w.elixir
				and dist[Grid.index(p)] >= FOE_DISTANCE
			):
				spots.append(p)
	if spots.is_empty():
		return Vector2i(-1, -1)
	return spots[w.rng.randi_range(0, spots.size() - 1)]


## A free room tile at least `min_dist` steps from the start.
static func _random_spot(w: World, min_dist: int) -> Vector2i:
	var dist: PackedInt32Array = Grid.search(w.start, w.open_floor).dist
	var spots: Array[Vector2i] = []
	for r in w.rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var p := Vector2i(x, y)
				if (
					w.vacant(p)
					and dist[Grid.index(p)] >= min_dist
					and p != w.stairs
					and p != w.elixir
					and not w.peaches.has(p)
				):
					spots.append(p)
	if spots.is_empty():
		return Vector2i(-1, -1)
	return spots[w.rng.randi_range(0, spots.size() - 1)]


## Where a resting patrol heads next: the middle of a random room.
static func patrol_point(w: World) -> Vector2i:
	return _centre(w.rooms[w.rng.randi_range(0, w.rooms.size() - 1)])


static func nearest_free(w: World, from: Vector2i) -> Vector2i:
	if w.vacant(from):
		return from
	var dist: PackedInt32Array = Grid.search(from, func(p): return w.open_floor(p)).dist
	var best := -1
	for i in dist.size():
		if dist[i] > 0 and w.vacant(Grid.at(i)) and (best < 0 or dist[i] < dist[best]):
			best = i
	return Grid.at(best) if best >= 0 else Vector2i(-1, -1)


static func spawn(w: World, kind: StringName, at: Vector2i) -> Actor:
	var a := Actor.new()
	a.id = w.new_id()
	a.kind = kind
	a.faction = Actor.HEAVEN
	a.pos = at
	a.home = at
	a.post = at
	a.hp = Bestiary.info(kind).hp
	a.max_hp = a.hp
	w.actors.append(a)
	return a
