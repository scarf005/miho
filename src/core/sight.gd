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
