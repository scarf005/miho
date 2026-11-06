class_name House
extends RefCounted
## The house at the end of the trail from storey 1 (World.HOUSE): a clearing of grass and leaves
## in a forest of bamboo under the moon, and in it a hut of wood walls with one door, boards and
## straw. A trail of 마당 runs from the door to the nearest edge of the map, where it ends in
## World.trail_end, the way back to storey 1. Nobody lives here. All from a generator of its
## own, so the same seed builds the same house whenever Miho comes.

const HOUSE_SALT := 0x40C5
## The half sizes of the clearing round the middle of the map.
const CLEARING := Vector2i(14, 7)
## The chance of the noise that lays leaves over the clearing's grass.
const LEAVES := 0.3
## The hut, its walls included, and how far its middle may stand off the clearing's.
const HUT := Vector2i(9, 6)
const HUT_SHIFT := 2
## Tiles of straw on the hut's floor.
const STRAW := 2


## Builds the house on the storey Miho is on, with her at the trail's end.
static func build(w: World) -> void:
	FloorGen.clear(w, World.BAMBOO)
	w.stairs = Vector2i(-1, -1)
	w.down = Vector2i(-1, -1)
	w.elixir = Vector2i(-1, -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(w.rng.seed) ^ HOUSE_SALT
	var middle := Vector2i(Grid.W, Grid.H) / 2
	var leaves := Outside.noise(LEAVES, rng)
	for i in w.tiles.size():
		var d := Vector2(Grid.at(i) - middle) / Vector2(CLEARING)
		if d.length_squared() <= 1.0:
			w.tiles[i] = World.LEAVES if leaves[i] == 1 else World.GRASS
	var shift := Vector2i(
		rng.randi_range(-HUT_SHIFT, HUT_SHIFT), rng.randi_range(-HUT_SHIFT, HUT_SHIFT)
	)
	var hut := Rect2i(middle - HUT / 2 + shift, HUT)
	var inside := hut.grow(-1)
	FloorGen._fill(w, hut, World.WOOD_WALL)
	FloorGen._fill(w, inside, World.BOARD)
	var floor_tiles: Array[Vector2i] = []
	for y in range(inside.position.y, inside.end.y):
		for x in range(inside.position.x, inside.end.x):
			floor_tiles.append(Vector2i(x, y))
	FloorGen.shuffle(rng, floor_tiles)
	for p in floor_tiles.slice(0, STRAW):
		w.tiles[Grid.index(p)] = World.STRAW
	var out := _door_side(hut)
	var door := _door(hut, out)
	w.tiles[Grid.index(door)] = World.DOOR
	var open := PackedByteArray()
	open.resize(w.tiles.size())
	for i in open.size():
		open[i] = 0 if hut.has_point(Grid.at(i)) else 1
	var path := Outside.trail(door + out, open)
	for p in path:
		w.tiles[Grid.index(p)] = World.COURTYARD
	for i in open.size():
		if open[i] == 1 and Grid.at(i) not in path:
			w.outside[Grid.at(i)] = true
	w.trail_end = path[-1]
	w.start = path[-2]
	w.player().pos = w.start
	w.rooms.assign([inside, Rect2i(middle - CLEARING, CLEARING * 2 + Vector2i.ONE)])
	w.tail_bonus = w.storeys.get(1, {}).get("tail_bonus", 0)
	w._changed()


## The way out of the wall of `hut` that faces the nearest edge of the map, the first of
## up, down, left and right when several are as near.
static func _door_side(hut: Rect2i) -> Vector2i:
	var far := {
		Vector2i.UP: hut.position.y,
		Vector2i.DOWN: Grid.H - hut.end.y,
		Vector2i.LEFT: hut.position.x,
		Vector2i.RIGHT: Grid.W - hut.end.x,
	}
	var out := Vector2i.UP
	for d: Vector2i in far:
		if far[d] < far[out]:
			out = d
	return out


## The middle tile of the wall of `hut` on the side `out`.
static func _door(hut: Rect2i, out: Vector2i) -> Vector2i:
	var mid := hut.position + hut.size / 2
	match out:
		Vector2i.UP:
			return Vector2i(mid.x, hut.position.y)
		Vector2i.DOWN:
			return Vector2i(mid.x, hut.end.y - 1)
		Vector2i.LEFT:
			return Vector2i(hut.position.x, mid.y)
	return Vector2i(hut.end.x - 1, mid.y)
