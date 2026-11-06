class_name Vault
extends RefCounted
## The treasure room (세 등불 보물방): a room shut off by walls, with two peaches
## inside. The way in is a plain wall (World.seals) in front of another room. It
## breaks like any wall, and it collapses when the three dark lanterns that stand
## in a row in that room are all lit.

## The lanterns of a vault; the peaches in it; how far from the wall they stand at most.
const LANTERNS := 3
const PRIZE := 2
const NEAR := 5
## How far apart the lanterns of a row stand: next to each other, or one tile between.
const GAPS := [1, 2]


## Makes room r a treasure room: every doorway in its walls is walled up (a
## window that looked along one becomes wall), a wall that has then nothing to
## stand beside falls away to the sky (`_fall`), and one doorway into another room
## becomes the sealing wall; LANTERNS dark lanterns stand in a row in that room,
## near the wall and away from the room's middle, and PRIZE peaches lie in r.
## False, with nothing changed, when r has a hidden door, can be reached another
## way, a wall with nothing to stand beside has no sky to fall to, or the storey
## would not be whole once the wall is gone.
static func make(w: World, r: Rect2i) -> bool:
	var ways := []
	for x in range(r.position.x, r.end.x):
		ways.append([Vector2i(x, r.position.y - 1), Vector2i.UP])
		ways.append([Vector2i(x, r.end.y), Vector2i.DOWN])
	for y in range(r.position.y, r.end.y):
		ways.append([Vector2i(r.position.x - 1, y), Vector2i.LEFT])
		ways.append([Vector2i(r.end.x, y), Vector2i.RIGHT])
	if ways.any(func(s): return w.secrets.has(s[0])):
		return false
	ways = ways.filter(func(s): return w.open_floor(s[0]))
	var fronts := ways.filter(func(s): return FloorGen.room_at(w, s[0] + s[1]).has_area())
	if fronts.is_empty():
		return false
	var before := w.tiles.duplicate()
	for s in ways:
		w.tiles[Grid.index(s[0])] = World.WALL
		for d in Placement.SIDES:
			if w.tile(s[0] + d) == World.WINDOW:
				w.tiles[Grid.index(s[0] + d)] = World.WALL
	if not _fall(w, ways):
		w.tiles = before
		return false
	var front: Array = fronts[w.rng.randi_range(0, fronts.size() - 1)]
	var wall: Vector2i = front[0]
	w.seals[wall] = []
	var shut: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
	if shut[Grid.index(r.get_center())] < 0 and FloorGen.connected(w):
		_row(w, wall, FloorGen.room_at(w, wall + front[1]))
	if w.seals[wall].is_empty():
		w.tiles = before
		w.seals.erase(wall)
		return false
	var inside: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if w.open_floor(Vector2i(x, y)):
				inside.append(Vector2i(x, y))
	FloorGen.shuffle(w.rng, inside)
	w.peaches.append_array(inside.slice(0, PRIZE))
	return true


## The walls round the walled-up `ways` with nothing but wall and sky round them fall
## to the sky, each once one beside it is sky; false when one is left standing.
static func _fall(w: World, ways: Array) -> bool:
	var bare := {}
	for s: Array in ways:
		for d: Vector2i in Grid.DIRS:
			var q: Vector2i = s[0] + d
			if Grid.inside(q) and Terrain.wall(w.tile(q)) and not _stands(w, q):
				bare[q] = true
	var fell := true
	while fell:
		fell = false
		for q: Vector2i in bare.keys():
			if Grid.DIRS.any(func(d): return w.tile(q + d) == World.SKY):
				w.tiles[Grid.index(q)] = World.SKY
				bare.erase(q)
				fell = true
	return bare.is_empty()


## Whether a tile beside `p` is neither wall nor sky.
static func _stands(w: World, p: Vector2i) -> bool:
	for d: Vector2i in Grid.DIRS:
		var t := w.tile(p + d)
		if Grid.inside(p + d) and not Terrain.wall(t) and t != World.SKY:
			return true
	return false


## Puts the dark lanterns of the wall in a straight row in `hall`: the first
## row, in a shuffled order, that leaves the storey whole. World.seals[wall]
## stays empty when none does.
static func _row(w: World, wall: Vector2i, hall: Rect2i) -> void:
	# A lantern stands on a free floor tile of the hall, not its middle, 2 to NEAR tiles
	# from the wall.
	var found := Native.lantern_rows(
		w.tiles, hall, wall, World.FLOOR, NEAR, LANTERNS, GAPS, Placement.SIDES, Grid.W
	)
	var rows := []
	for i in range(0, found.size(), LANTERNS):
		var row: Array[Vector2i] = []
		for k in LANTERNS:
			row.append(Grid.at(found[i + k]))
		rows.append(row)
	FloorGen.shuffle(w.rng, rows)
	for row: Array[Vector2i] in rows:
		for p in row:
			w.tiles[Grid.index(p)] = World.LANTERN_OUT
		w.seals[wall] = row
		if FloorGen.connected(w):
			return
		for p in row:
			w.tiles[Grid.index(p)] = World.FLOOR
		w.seals[wall] = []


## The end of a round: a wall that has fallen is forgotten; one whose lanterns
## are all lit collapses to rubble, with a thud heard World.THUD tiles.
static func tick(w: World) -> void:
	for at: Vector2i in w.seals.keys():
		if not Terrain.wall(w.tile(at)):
			w.seals.erase(at)
		elif w.seals[at].all(func(p): return w.tile(p) == World.LANTERN):
			w.seals.erase(at)
			w.set_tile(at, World.RUBBLE)
			Notice.record(w, &"wall", at)
			w.emit({t = &"collapse", at = at})
			Hearing.noise(w, at, World.THUD, "쿵", true, 0)
