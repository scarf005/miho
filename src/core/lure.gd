class_name Lure
extends RefCounted
## 여우 홀림: one of Miho's wisps of 여 alone (no element, no 도약) that hovers
## yelps WORD in the round it comes to hover and every second round after (at
## the end of each round its rounds left are even, so four times in
## Spell.WISP_LIFE), heard LOUD tiles and PER_FOX more for every 여 past the
## first, an alarm. A creature of heaven that hears it searches its tile, but
## a cunning one (Bestiary.CUNNING) searches where the wisp was thrown from. It
## keeps quiet while its caster stands on its tile, and wisps that share a tile
## yelp once. A wisp with an element, 수 among them, is silent.

const LOUD := 4
const PER_FOX := 2
## Rounds between two yelps.
const EVERY := 2
const WORD := "캥"


## Whether a hovering wisp of `spell` yelps.
static func lures(spell: Spell) -> bool:
	return spell.shape == Spell.WISP and spell.elements().is_empty() and not spell.swaps()


static func loud(spell: Spell) -> int:
	return LOUD + PER_FOX * spell.extra(Cards.FOX)


## The end of a round: every hovering lure due to yelp does.
static func tick(w: World) -> void:
	var told := {}
	for s in w.shots:
		var caster := w.actor(s.caster)
		if (
			s.gone
			or s.faction != Actor.FOX
			or s.dir != Vector2i.ZERO
			or Flight.rides(w, s)
			or s.life <= 0
			or s.life % EVERY != 0
			or not lures(s.spell)
			or told.has(s.pos)
			or (caster != null and caster.pos == s.pos)
		):
			continue
		told[s.pos] = true
		_yelp(w, s)


static func _yelp(w: World, s: Shot) -> void:
	var n := loud(s.spell)
	w.emit({t = &"yelp", shot = s.id, at = s.pos, loud = n})
	w.noise(s.pos, n, WORD, true, 0)
	var dist: PackedInt32Array = Grid.search(s.pos, Masks.heard(w), n).dist
	for a in w.actors:
		var d := dist[Grid.index(a.pos)]
		if (
			a.alive()
			and a.alert == Actor.SEARCH
			and a.target == s.pos
			and Bestiary.wits(a.kind) == Bestiary.CUNNING
			and d >= 0
			and d <= n
		):
			a.target = s.origin
