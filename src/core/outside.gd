class_name Outside
extends RefCounted
## The ground round the pavilion on storey 1: every sky tile of the storey FloorGen built
## becomes grass with a pattern of one of DESIGNS over it (RunPlan.outside), and a vent of
## fog with a level of its own (World.vent_levels), so a thick bank of it blocks sight in
## patches. A sky court that no way leads to becomes wall. The pavilion's way out is
## World.gate, Miho starts inside it, and a trail of 마당 runs from it to the edge of the map,
## where it ends in World.trail_end. All from a generator of its own, so the same seed lays
## the same outside.

const DESIGNS: Array[StringName] = [&"meadow", &"grove", &"waterside"]
## What lies over the grass in each design, the first laid first: [tile, chance of the noise].
const LAYERS := {
	&"meadow": [[World.LEAVES, 0.38], [World.BAMBOO, 0.3]],
	&"grove": [[World.BAMBOO, 0.62], [World.LEAVES, 0.35]],
	&"waterside": [[World.SHALLOW, 0.47], [World.LEAVES, 0.3]],
}
## The fog a vent keeps: this much, and one more for each of two noises it lies in.
const FOG_LEAST := 2


## The tile inside the way out nearest Miho, where she starts on storey 1 (FloorGen._build),
## or her own when no way leads out.
static func doorstep(w: World) -> Vector2i:
	var sky := _sky(w)
	for e in _entrances(w):
		if trail(e.start, sky).size() > 1:
			return e.inside
	return w.start


## Lays the outside on the storey FloorGen.build made: ground over the sky, the gate, the trail
## and the fog. The gate is the way out nearest Miho, and she starts inside it, before it.
static func lay(w: World) -> void:
	var sky := _sky(w)
	var gate := Vector2i(-1, -1)
	var path: Array[Vector2i] = []
	for e in _entrances(w):
		var found := trail(e.start, sky)
		if found.size() > 1 and _free(w, e.inside):
			gate = _gate(e)
			path = found
			w.start = e.inside
			w.player().pos = e.inside
			break
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


## 1 for each sky tile of `w`.
static func _sky(w: World) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w.tiles.size())
	for i in out.size():
		out[i] = 1 if w.tiles[i] == World.SKY else 0
	return out


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


## Whether nothing stands on `p`: no creature but Miho, plate, peach or jar.
static func _free(w: World, p: Vector2i) -> bool:
	var a := w.actor_at(p)
	return (
		(a == null or a == w.player())
		and not w.traps.has(p)
		and p not in w.peaches
		and not w.jars.has(p)
	)


## Where the trail may start, nearest Miho first, each {start, door, inside}: the sky tile by
## the walkable `inside` (`door` (-1, -1)), or the one behind a plain wall (`door`, to be a door).
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
				out.append({start = p + d, door = Vector2i(-1, -1), inside = p})
		for d in Placement.SIDES:
			if FloorGen._walled(w, p + d, d) and w.tile(p + d * 2) == World.SKY:
				out.append({start = p + d * 2, door = p + d, inside = p})
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
