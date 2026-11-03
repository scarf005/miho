class_name Masks
extends RefCounted
## Masks for the board primitives in Rust (Grid.search, Sight.field, Light):
## one byte per tile, read from a table of tile kinds and then corrected by the
## World's own test at the tiles where creatures, projectiles or fire change
## what the tile kind alone says.

## Read from Tiles.of, not from the tables of Tiles: loading Tiles can load Masks, and
## the tables of Tiles are empty until it has loaded.
static var _shade := Grid.table(func(t): return not Tiles.of(t, "light"))
static var _heard := Grid.table(func(t): return not Tiles.of(t, "wall"))
static var _fly := Grid.table(
	func(t): return t != World.DOOR and (Tiles.of(t, "walk") or t == World.POND or t == World.SKY)
)
static var _air := Grid.table(func(t): return Tiles.of(t, "walk") or t == World.SKY)
## What a creature that flies crosses (Bestiary.ground).
static var flown := Grid.table(
	func(t): return Tiles.of(t, "walk") or Tiles.of(t, "water") or t == World.SKY
)
static var _hides := Grid.table(func(t): return t == World.BAMBOO)
static var _wade := Grid.table(func(t): return Tiles.of(t, "walk") or Tiles.of(t, "water"))


## Floor and water, which a creature's way from the start is counted across (FloorGen).
static func wade(w: World) -> PackedByteArray:
	return Grid.mask(w.tiles, _wade)


## Floor and sky, which a falling Miho comes down across (Fall).
static func air(w: World) -> PackedByteArray:
	return Grid.mask(w.tiles, _air)


## The tiles a homing projectile may fly through: open air (World.open_air)
## but closed doors.
static func fly(w: World) -> PackedByteArray:
	return Grid.mask(
		w.tiles,
		_fly,
		odd(w),
		func(p): return w.open_air(p) and not (w.tile(p) == World.DOOR and w.opaque(p))
	)


## World.opaque for every tile: only fire and gas change what the tile kind says.
static func opaque(w: World) -> PackedByteArray:
	return Grid.mask(w.tiles, Tiles.sight, w.burning.keys() + w.gas.keys(), w.opaque)


## World.blocks_light for every tile.
static func shade(w: World) -> PackedByteArray:
	return Grid.mask(w.tiles, _shade, w.burning.keys(), w.blocks_light)


## World.hides for every tile.
static func hides(w: World) -> PackedByteArray:
	return Grid.mask(w.tiles, _hides, w.burning.keys(), w.hides)


## World.open_floor for every tile, but `test` decides at the `extra` tiles.
static func floor_of(w: World, extra: Array = [], test := Callable()) -> PackedByteArray:
	return Grid.mask(w.tiles, Tiles.walk, extra, test)


## World.open_floor for every tile once every sealing wall (World.seals) has
## fallen and every veil gone out (Tiles.opens), but the tiles in `blocked`.
static func opened(w: World, blocked: Array = []) -> PackedByteArray:
	var open := Grid.mask(w.tiles, Tiles.reachable, blocked, func(_p): return false)
	for p: Vector2i in w.seals:
		if not blocked.has(p):
			open[Grid.index(p)] = 1
	return open


## A creature's `test` of the tiles it may step on (its own among them) for every tile, where
## `test` never holds on the tile of another creature alive (Mind._walkable), so it is not asked.
static func walk(w: World, a: Actor, test: Callable) -> PackedByteArray:
	var fall: Array = w.burning.keys() + w.traps.keys()
	for s in w.shots:
		fall.append(s.pos)
	var alive: Array[Actor] = []
	for b in w.actors:
		if not b.alive():
			fall.append(b.pos)
		elif Grid.inside(b.pos):
			alive.append(b)
	var out := Grid.mask(w.tiles, Bestiary.ground(a.kind), fall, test)
	for b in alive:
		out[Grid.index(b.pos)] = 0
	out[Grid.index(a.pos)] = 1
	return out


## The tiles a noise spreads over: all but walls.
static func heard(w: World) -> PackedByteArray:
	return Grid.mask(w.tiles, _heard)


## Tiles where creatures, projectiles or fire stand, and plates (Traps).
static func odd(w: World) -> Array:
	return (
		w.burning.keys()
		+ w.actors.map(func(a): return a.pos)
		+ w.shots.map(func(s): return s.pos)
		+ w.traps.keys()
	)
