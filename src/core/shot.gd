class_name Shot
extends Entity
## A projectile in flight: a foxfire wisp or an orb. A homing one chases the
## creature `target` (an actor id, 0 for none), banking `turn` degrees a tile
## (Spell.turn) in `bank` and spending them on its turns (Homing.steer).
## `flown` counts the tiles it has flown. A wisp that struck a creature rides
## it: `host` is its actor id, and `pos` follows it (Walk.move) while it lives.
## An armour-piercing wisp (Spell.bores) has `pierced` the wall it went through.

var caster := 0
var spell: Spell
var origin := Vector2i.ZERO
var dir := Vector2i.ZERO
var life := 0
var gone := false
var target := 0
var turn := 0
var bank := 0
var flown := 0
var host := 0
var pierced := false
## It goes off beside a foe in flight (Flight.fuse).
var fused := false
## The arcs 낙뢰 has made (Compounds.arc).
var arcs := 0
## Rounds it has flown (Flight.phase): an orb gains Spell.accel a round.
var age := 0


func _init() -> void:
	faction = FOX


## A new shot of `spell` on the tile of `caster`, with a new id; not yet in `w.shots`.
static func of(w: World, caster: Actor, spell: Spell) -> Shot:
	var s := Shot.new()
	s.id = w.new_id()
	s.faction = caster.faction
	s.caster = caster.id
	s.spell = spell
	s.pos = caster.pos
	s.origin = caster.pos
	s.fused = Flight.fused(spell) or caster.kind == Forge.FURNACE
	return s


## Tiles between the caster and this shot, which sets orb damage.
func distance() -> int:
	return Grid.cheb(origin, pos)


## Tiles it flies this round: its spell's speed, and the acceleration of every round past.
func pace() -> int:
	return spell.speed() + spell.accel() * age


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
	s.arcs = arcs
	s.bank = bank
	s.flown = flown
	s.host = host
	s.pierced = pierced
	s.fused = fused
	s.age = age
	return s
