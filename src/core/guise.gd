class_name Guise
extends RefCounted
## 자신에게 걸기: a spell cast with no direction (`,`, or a click on Miho's own
## tile) goes on the caster herself. Only the spells that change how she is
## seen take that aim (`kind`); any other is refused with ONLY.
##
## 그림자 (SHADOW: one 여 and any number of 수): a dark wisp rides her
## (Elements.stick) for Spell.WISP_LIFE rounds, darkening the tiles round her
## (Spell.light: 3, and one more for every 수 past the first). It is silent.
## The dark hides her only from afar: a creature still sees the tiles next to
## it (World.NIGHT). Any dark wisp goes out at the end of a round in which a
## tile within its reach (Chebyshev, walls or not) caught fire or had its
## lantern lit (`tick`).

const SHADOW := &"shadow"
const NAME := {SHADOW: "그림자"}
## The talismans that make each, at their weakest.
const RECIPE := {SHADOW: [Cards.FOX, Cards.WATER]}
const ONLY := "자신에게는 그림자(여+수)만 건다"


## What `spell` does cast on oneself: SHADOW, or empty when it does not go on
## oneself.
static func kind(spell: Spell) -> StringName:
	if spell == null:
		return &""
	if (
		spell.count(Cards.FOX) == 1
		and spell.has(Cards.WATER)
		and spell.slots.all(func(c): return c in [Cards.FOX, Cards.WATER])
	):
		return SHADOW
	return &""


## Why `a` cannot cast `spell` on itself, or empty when it can.
static func why(_a: Actor, spell: Spell) -> String:
	return ONLY if kind(spell) == &"" else ""


## `caster` casts `spell` along `dir`. With no direction it goes on the caster:
## true, and World.cast has nothing more to do.
static func cast(w: World, caster: Actor, spell: Spell, dir: Vector2i) -> bool:
	if dir != Vector2i.ZERO:
		return false
	var s := Shot.new()
	s.id = w.new_id()
	s.faction = caster.faction
	s.caster = caster.id
	s.spell = Spell.make(spell.cards)
	s.spell.called = NAME[SHADOW]
	s.origin = caster.pos
	w.shots.append(s)
	Elements.stick(w, s, caster)
	return true


## The end of a round: a dark wisp goes out where fire was lit within its reach.
static func tick(w: World) -> void:
	var lit := w.events.filter(func(e): return e.t == &"ignite" or e.t == &"relight")
	for s in w.shots:
		var l := s.spell.light(s.faction)
		if s.gone or l.is_empty() or Light.level(l.color) > 0.0:
			continue
		if lit.any(func(e): return Grid.cheb(e.at, s.pos) <= l.radius):
			s.gone = true
			w._changed()
			w.emit({t = &"fade", shot = s.id, at = s.pos, lit = true, title = s.spell.title()})
