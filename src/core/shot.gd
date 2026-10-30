class_name Shot
extends RefCounted
## A projectile in flight: a foxfire wisp or an orb.

var id := 0
var faction := Actor.FOX
var caster := 0
var spell: Spell
var pos := Vector2i.ZERO
var origin := Vector2i.ZERO
var dir := Vector2i.ZERO
var life := 0
var gone := false


## Tiles between the caster and this shot, which sets orb damage.
func distance() -> int:
	return Grid.cheb(origin, pos)


func clone() -> Shot:
	var s := Shot.new()
	s.id = id
	s.faction = faction
	s.caster = caster
	s.spell = spell
	s.pos = pos
	s.origin = origin
	s.dir = dir
	s.life = life
	s.gone = gone
	return s
