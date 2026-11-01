class_name Sightings
extends RefCounted
## Where Miho last saw each creature of heaven on this storey, kept until she
## sees the tile empty. Walks step around these tiles too, so one that a
## creature out of sight stands on does not turn a walk back and forth as it
## comes in and out of view.

## Tiles where a creature of heaven was last seen -> true.
var at := {}
var _world: World
var _depth := 0


## Remembers the creatures Miho sees now and forgets the tiles she sees empty;
## another run or storey starts afresh.
func update(w: World) -> void:
	if w != _world or w.depth != _depth:
		at = {}
		_world = w
		_depth = w.depth
	for p: Vector2i in at.keys():
		if w.seen[Grid.index(p)] == 1:
			at.erase(p)
	for id in Travel.in_sight(w):
		at[w.actor(id).pos] = true
