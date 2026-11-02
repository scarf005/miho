class_name Sight
extends RefCounted
## Symmetric shadowcasting (Albert Ford, 2021). A floor tile is visible when a
## line from the centre of the origin reaches its centre; walls are visible
## when any part of them is. For floor tiles sight is symmetric: a creature
## sees Miho's tile exactly when Miho sees its tile. Light uses the same field.


## A mask with 1 for every tile visible from `origin` within `radius`
## (Euclidean); `opaque` holds 1 for every tile that blocks sight (World.opaque_mask).
## In Rust, rust/src/lib.rs.
static func field(origin: Vector2i, radius: int, opaque: PackedByteArray) -> PackedByteArray:
	return Native.sight(origin, radius, opaque, Grid.W)


## What `me` senses now, [seen, dim, known]: World.seen, World.dim and World.known once it has
## looked round. Its own field answers for the clear tiles, as sight is symmetric between them.
## In Rust, rust/src/lib.rs.
static func sensed(w: World, me: Actor) -> Array:
	return Native.sense(
		me.pos,
		World.NIGHT[me.faction] + (World.WARY_SIGHT if me.wary > 0 else 0),
		me.asleep(),
		me.blind > 0,
		me.faction == Actor.FOX,
		w.fov(me.pos),
		w.opaque_mask(),
		Masks.hides(w),
		w._lit_mask(),
		w.known,
		World.VIEW,
		World.DIM,
		Grid.W
	)
