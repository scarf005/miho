class_name Outside
extends RefCounted
## The ground round the pavilion on storey 1: every sky tile of the storey FloorGen built
## becomes grass with a pattern of one of DESIGNS over it (RunPlan.outside), and a vent of
## fog with a level of its own (World.vent_levels), so a thick bank of it blocks sight in
## patches. A sky court that no way leads to becomes wall. Miho starts outside the pavilion's
## gate, and a trail of 마당 runs from there to the edge of the map, where it ends in
## World.trail_end. Miho starts where FloorGen put her, inside; the pavilion's way out is
## World.gate. All from a generator of its own, so the same seed lays the same outside.

const DESIGNS: Array[StringName] = [&"meadow", &"grove", &"waterside"]
## What lies over the grass in each design, the first laid first: [tile, chance of the noise].
const LAYERS := {
	&"meadow": [[World.LEAVES, 0.38], [World.BAMBOO, 0.3]],
	&"grove": [[World.BAMBOO, 0.62], [World.LEAVES, 0.35]],
	&"waterside": [[World.SHALLOW, 0.47], [World.LEAVES, 0.3]],
}
## The fog a vent keeps: this much, and one more for each of two noises it lies in.
const FOG_LEAST := 2


## Lays the outside on the storey FloorGen.build made: ground over the sky, the gate, the trail
## and the fog. Sky beside the pavilion's walkable tiles becomes wall, but the gate, so the gate
## is the one way out. Miho stays where FloorGen put her.
static func lay(w: World) -> void:
	var sky := PackedByteArray()
	sky.resize(w.tiles.size())
	for i in sky.size():
		sky[i] = 1 if w.tiles[i] == World.SKY else 0
	var walk := Masks.opened(w)
	var seal := PackedByteArray()
	seal.resize(sky.size())
	for i in sky.size():
		seal[i] = 1 if sky[i] == 1 and _beside(walk, Grid.at(i)) else 0
	var gate := Vector2i(-1, -1)
	var path: Array[Vector2i] = []
	var best := -1
	for e in _entrances(w):
		var g := _gate(e)
		if e.start != g and seal[Grid.index(e.start)] == 1:
			continue
		var open := _unsealed(sky, seal, g)
		var found := trail(e.start, open)
		if found.size() <= 1:
			continue
		var dist: PackedInt32Array = Grid.search(e.start, open).dist
		var count := 0
		for d in dist:
			count += 1 if d >= 0 else 0
		var shorter := found.size() < path.size()
		var same := found.size() == path.size() and Grid.index(g) < Grid.index(gate)
		if count > best or (count == best and (shorter or same)):
			best = count
			gate = g
			path = found
	if not path.is_empty():
		for i in sky.size():
			if seal[i] == 1 and Grid.at(i) != gate:
				w.tiles[i] = World.WALL
				sky[i] = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(w.rng.seed) ^ RunPlan.OUTSIDE_SALT
	for i in sky.size():
		if sky[i] == 1:
			w.tiles[i] = World.GRASS
	for layer: Array in LAYERS[RunPlan.outside(w.rng.seed)]:
		var laid := _noise(layer[1], rng)
		for i in sky.size():
			if sky[i] == 1 and laid[i] == 1:
				w.tiles[i] = layer[0]
	var a := _noise(PondGarden.NOISE, rng)
	var b := _noise(PondGarden.NOISE, rng)
	if not path.is_empty():
		w.tiles[Grid.index(gate)] = World.DOOR
		for p in path:
			w.tiles[Grid.index(p)] = World.COURTYARD
		w.gate = gate
		w.trail_end = path[-1]
		w._changed()
		var reached: PackedInt32Array = Grid.search(w.start, Masks.opened(w)).dist
		for i in sky.size():
			if sky[i] == 1 and reached[i] < 0:
				w.tiles[i] = World.WALL
				sky[i] = 0
	w._changed()
	for i in sky.size():
		var p := Grid.at(i)
		if sky[i] == 1 and p not in path and Gas.holds(w, p):
			w.vents[p] = Gas.FOG
			w.vent_levels[p] = FOG_LEAST + a[i] + b[i]
			Gas.put(w, p, Gas.FOG, w.vent_levels[p])
	w._changed()


## 1 for each tile of the board that cellular noise of `chance` makes solid.
static func _noise(chance: float, rng: RandomNumberGenerator) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(Grid.W * Grid.H)
	var board := Rect2i(0, 0, Grid.W, Grid.H)
	for i: int in Native.noise(board, chance, PondGarden.PASSES, rng, Grid.W):
		out[i] = 1
	return out


## The tile the pavilion's way out leads through: the door in its wall, else the trail's first tile.
static func _gate(e: Dictionary) -> Vector2i:
	return e.door if e.door.x >= 0 else e.start


## The sky tiles not sealed by `seal`, the gate `g` kept open whatever its seal.
static func _unsealed(sky: PackedByteArray, seal: PackedByteArray, g: Vector2i) -> PackedByteArray:
	var open := sky.duplicate()
	for i in sky.size():
		if seal[i] == 1 and Grid.at(i) != g:
			open[i] = 0
	return open


## Whether one of the 8 tiles round `p` is walkable in `walk`.
static func _beside(walk: PackedByteArray, p: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if Grid.inside(q) and walk[Grid.index(q)] == 1:
				return true
	return false


## Where the trail may start, nearest Miho first, each {start, door}: the sky tile by a
## walkable one (`door` (-1, -1)), or the one behind a plain wall (`door`, to be a door).
static func _entrances(w: World) -> Array[Dictionary]:
	var dist: PackedInt32Array = Grid.search(w.start, Masks.floor_of(w)).dist
	var near: Array[int] = []
	for i in dist.size():
		if dist[i] >= 0:
			near.append(i)
	near.sort_custom(func(x, y): return dist[x] < dist[y] or (dist[x] == dist[y] and x < y))
	var out: Array[Dictionary] = []
	for i in near:
		var p := Grid.at(i)
		for d in Placement.SIDES:
			if w.tile(p + d) == World.SKY:
				out.append({start = p + d, door = Vector2i(-1, -1)})
		for d in Placement.SIDES:
			if FloorGen._walled(w, p + d, d) and w.tile(p + d * 2) == World.SKY:
				out.append({start = p + d * 2, door = p + d})
	return out


## The shortest way over the `open` tiles from `from` to the edge of the map, four ways a
## step, to the edge tile of the lowest index when several are as near. Its tiles, `from`
## first, or none when no way leads there.
static func trail(from: Vector2i, open: PackedByteArray) -> Array[Vector2i]:
	var parent := PackedInt32Array()
	parent.resize(open.size())
	parent.fill(-2)
	parent[Grid.index(from)] = -1
	var queue: Array[int] = [Grid.index(from)]
	var dist := {Grid.index(from): 0}
	for i in queue:
		for d in Placement.SIDES:
			var q := Grid.at(i) + d
			var j := Grid.index(q)
			if Grid.inside(q) and open[j] == 1 and parent[j] == -2:
				parent[j] = i
				dist[j] = dist[i] + 1
				queue.append(j)
	var end := -1
	for i in queue:
		if (
			_edge(Grid.at(i))
			and (end < 0 or dist[i] < dist[end] or (dist[i] == dist[end] and i < end))
		):
			end = i
	var out: Array[Vector2i] = []
	while end >= 0:
		out.push_front(Grid.at(end))
		end = parent[end]
	return out


static func _edge(p: Vector2i) -> bool:
	return p.x == 0 or p.y == 0 or p.x == Grid.W - 1 or p.y == Grid.H - 1
