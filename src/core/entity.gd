class_name Entity
extends RefCounted
## Whatever stands on a tile: a creature (Actor) or a projectile (Shot). A rule
## about anything that enters a tile takes an Entity. Faction FOX is Miho and her
## allies (Mind.enlist); HEAVEN is everything else.

const FOX := 0
const HEAVEN := 1

var id := 0
var faction := HEAVEN
var pos := Vector2i.ZERO
