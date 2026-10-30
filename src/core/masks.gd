class_name Masks
extends RefCounted
## Masks for the board primitives in Rust (Grid.search, Sight.field, Light):
## one byte per tile, read from a table of tile kinds and then corrected by the
## World's own test at the tiles where creatures, projectiles or fire change
## what the tile kind alone says.

static var _opaque := Grid.table(
	func(t): return Terrain.wall(t) or t == World.BAMBOO or t == World.DOOR
)
static var _floor := Grid.table(func(t): return World.WALKABLE.has(t))
static var _heard := Grid.table(func(t): return not Terrain.wall(t))


## World.opaque for every tile.
static func opaque(w: World) -> PackedByteArray:
	return Grid.mask(w.tiles, _opaque, odd(w), w.opaque)


## World.open_floor for every tile, but `test` decides at the `extra` tiles.
static func floor_of(w: World, extra: Array = [], test := Callable()) -> PackedByteArray:
	return Grid.mask(w.tiles, _floor, extra, test)


## A creature's `test` of the tiles it may step on (its own among them) for every tile.
static func walk(w: World, a: Actor, test: Callable) -> PackedByteArray:
	return floor_of(w, odd(w) + [a.pos], test)


## The tiles a noise spreads over: all but walls.
static func heard(w: World) -> PackedByteArray:
	return Grid.mask(w.tiles, _heard)


## Tiles where creatures, projectiles or fire stand.
static func odd(w: World) -> Array:
	return (
		w.burning.keys() + w.actors.map(func(a): return a.pos) + w.shots.map(func(s): return s.pos)
	)
