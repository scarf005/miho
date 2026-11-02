class_name Ties
extends RefCounted
## Whom a creature (Actor) fights and follows, by id. Data only; the rules are in Mind.

## The creature of another group it fights (Mind.provoke), 0 for none; the
## rounds left of the fight; where it last saw that creature.
var rival := 0
var grudge := 0
var rival_at := Vector2i.ZERO
## The id of the leader of its band (FloorGen.bands), 0 for none; it is gone
## when the leader falls (Mind.forget).
var leader := 0


func copy() -> Ties:
	var c := Ties.new()
	c.rival = rival
	c.grudge = grudge
	c.rival_at = rival_at
	c.leader = leader
	return c
