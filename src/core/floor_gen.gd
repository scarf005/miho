class_name FloorGen
extends RefCounted
## Builds each storey of the pavilion: pillars mirrored left to right like a
## hall's column rows, stairs on the far side, and the creatures listed below.

const PLAN := {
	1: [&"dokkaebi", &"dokkaebi", &"jangseung"],
	2: [&"bulgae", &"dokkaebi", &"jangseung"],
	3: [&"haetae", &"imugi", &"dokkaebi", &"jangseung"],
	4: [&"cheonha", &"jiha", &"dokkaebi", &"dokkaebi"],
	5: [&"imugi", &"imugi", &"dokkaebi", &"dokkaebi", &"jangseung"],
	6: [&"bulgasari", &"dokkaebi", &"imugi", &"jangseung"],
	7: [&"dokkaebi", &"dokkaebi", &"dokkaebi", &"imugi", &"imugi", &"jangseung"],
	8: [&"haetae", &"dokkaebi", &"dokkaebi", &"imugi", &"jangseung", &"jangseung"],
	9: [&"cheonnyeon", &"haetae", &"haetae"],
}
const PEACH_FLOORS := [3, 5, 7, 9]
const START := Vector2i(4, 8)


static func build(w: World) -> void:
	var me := w.player()
	w.actors.assign([me])
	w.shots.clear()
	w.peaches.clear()
	w.round_no = 0
	me.pos = START
	me.rooted = 0
	me.stunned = 0
	w.start = START
	w.elixir = Vector2i(-1, -1)
	w.stairs = Vector2i(-1, -1)
	if w.depth >= World.FLOORS:
		w.elixir = Vector2i(4, 0)
	else:
		w.stairs = Vector2i(w.rng.randi_range(0, Grid.W - 1), 0)
	_pillars(w)
	_creatures(w)
	if PEACH_FLOORS.has(w.depth):
		var spot := _random_spot(w, 3)
		if spot.x >= 0:
			w.peaches.append(spot)


static func _pillars(w: World) -> void:
	var goal := w.elixir if w.elixir.x >= 0 else w.stairs
	for attempt in 200:
		w.tiles = PackedByteArray()
		w.tiles.resize(Grid.W * Grid.H)
		var colonnade := w.rng.randf() < 0.5
		for y in range(1, Grid.H - 1):
			for x in range(0, Grid.W / 2):
				var chance := 0.18
				if colonnade:
					chance = 0.7 if x % 2 == 1 and y % 2 == 0 else 0.04
				if w.rng.randf() < chance:
					w.tiles[Grid.index(Vector2i(x, y))] = World.PILLAR
					w.tiles[Grid.index(Vector2i(Grid.W - 1 - x, y))] = World.PILLAR
		if _valid(w, goal) or attempt == 199:
			return


static func _valid(w: World, goal: Vector2i) -> bool:
	for p in [w.start, goal]:
		for d in Grid.DIRS + [Vector2i.ZERO]:
			if Grid.inside(p + d) and not w.open_floor(p + d):
				return false
	var pillars := w.tiles.count(World.PILLAR)
	if pillars < 6 or pillars > 18:
		return false
	var dist: PackedInt32Array = Grid.search(w.start, w.open_floor).dist
	for i in w.tiles.size():
		if w.tiles[i] == World.FLOOR and dist[i] < 0:
			return false
	return true


static func _creatures(w: World) -> void:
	for kind in PLAN[w.depth]:
		var spot := Vector2i(-1, -1)
		if kind == &"cheonnyeon":
			spot = nearest_free(w, w.elixir + Vector2i(0, 2))
		if spot.x < 0:
			spot = _random_spot(w, 4)
		if spot.x >= 0:
			var a := spawn(w, kind, spot)
			a.cooldown = w.rng.randi_range(1, a.info().get("cd", 1))


static func _random_spot(w: World, min_dist: int) -> Vector2i:
	var spots: Array[Vector2i] = []
	for i in w.tiles.size():
		var p := Grid.at(i)
		if w.vacant(p) and p != w.stairs and p != w.elixir and not w.peaches.has(p):
			if Grid.cheb(p, w.start) >= min_dist:
				spots.append(p)
	if spots.is_empty():
		return Vector2i(-1, -1)
	return spots[w.rng.randi_range(0, spots.size() - 1)]


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
	a.hp = Bestiary.info(kind).hp
	a.max_hp = a.hp
	w.actors.append(a)
	return a
