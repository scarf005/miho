class_name Terrain
extends RefCounted
## Terrain that reacts to what Miho and heaven do to it. See World for the rules.


## An orb can be hurled at any open tile and at a lantern right next to the
## caster, which it smashes where it stands.
static func throwable(w: World, spell: Spell, at: Vector2i) -> bool:
	return w.open_air(at) or (spell.orb and w.tile(at) == World.LANTERN)
