class_name Shot
extends RefCounted
## A projectile in flight: a foxfire wisp or an orb. A homing one chases the
## creature `target` (an actor id, 0 for none), turning at most `turn` steps of
## 45° a tile (Spell.turn). A wisp that struck a creature rides it: `host` is
## its actor id, and `pos` follows it (World.move) while it lives.

var id := 0
var faction := Actor.FOX
var caster := 0
var spell: Spell
var pos := Vector2i.ZERO
var origin := Vector2i.ZERO
var dir := Vector2i.ZERO
var life := 0
var gone := false
var target := 0
var turn := 0
var host := 0


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
	s.target = target
	s.turn = turn
	s.host = host
	return s
