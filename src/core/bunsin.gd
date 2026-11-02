class_name Bunsin
extends RefCounted
## 분신 (Cards.BUNSIN, 여, 토, 화 and 목 in any order: Cards.SETS): a copy of Miho
## steps out onto the free tile next to her that the spell is aimed at. It is an
## ally (Mind.enlist) and fights on its own, as DCSS's spellforged servitor does
## (spl-summoning.cc cast_spellforged_servitor). It has TAILS tails of its own
## (Bestiary mana) that grow back as hers do, and spends them on the spell it was
## imprinted with: as `player_servitor_spell` picks one of the spells its caster
## has, the last spell she threw that TAILS tails pay for (Actor.imprint). With
## none it only claws. The spell goes alone (Guise.ALONE) and is silent. At most
## MOST copies stand on a storey: a cast that makes one more sends the oldest away
## once the new one is there, as DCSS `summoned_monster` expires the oldest summon
## over the cap (`_expire_capped_summon`).

const TAILS := 3
const MOST := 2


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
		_cap(w)
	return true


## The copies on the storey past MOST go, the lowest id first: ids are given in the
## order copies come to be, and one that came upstairs keeps its own.
static func _cap(w: World) -> void:
	var copies := w.actors.filter(func(a): return a.alive() and a.ally() and a.kind == Cards.BUNSIN)
	copies.sort_custom(func(a, b): return a.id < b.id)
	for old: Actor in copies.slice(0, maxi(0, copies.size() - MOST)):
		old.hp = 0
		old.intent.clear()
		w.emit({t = &"die", id = old.id, at = old.pos, foe = false, gone = true})
		w._changed()
		Mind.forget(w, old)
