class_name Bunsin
extends RefCounted
## 분신 (Cards.BUNSIN, the 3단 of 토, 수 and 화: clay wetted and fired): a copy of Miho
## steps out onto the free tile next to her that the spell is aimed at. It is an
## ally (Mind.enlist) and fights on its own, as DCSS's spellforged servitor does
## (spl-summoning.cc cast_spellforged_servitor). It has TAILS tails of its own
## (Bestiary mana) that grow back as hers do, and spends them on the spell it was
## imprinted with: as `player_servitor_spell` picks one of the spells its caster
## has, the last spell she threw that TAILS tails pay for (Actor.imprint). With
## none it only claws. The spell goes alone (Guise.ALONE) and is silent.

const TAILS := 3


## Whether a spell thrown along `dir` is one a copy of her can cast: thrown, paid
## for by its tails, with no leap in it and not one that goes alone.
static func imprints(spell: Spell, dir: Vector2i) -> bool:
	return (
		dir != Vector2i.ZERO
		and spell.cost() <= TAILS
		and spell.shape != Spell.LEAP
		and not spell.swaps()
		and not spell.slots.any(func(c): return Guise.ALONE.has(c))
	)


## `caster` casts `spell` along `dir`: Miho's next copy will know it (`imprints`).
static func learn(caster: Actor, spell: Spell, dir: Vector2i) -> void:
	if caster.is_miho() and imprints(spell, dir):
		caster.imprint.assign(spell.cards)


## Whether a copy can step out onto `at`.
static func open(w: World, at: Vector2i) -> bool:
	return w.vacant(at)


## `caster` casts `spell` along `dir`: true when it is 분신, and World.cast has
## nothing more to do. A leap of the same action may have left no room for it.
static func cast(w: World, caster: Actor, spell: Spell, dir: Vector2i) -> bool:
	if not spell.has(Cards.BUNSIN):
		return false
	if open(w, caster.pos + dir):
		FloorGen.spawn(w, Cards.BUNSIN, caster.pos + dir).imprint.assign(caster.imprint)
		w._changed()
	return true
