class_name Guise
extends RefCounted
## 스스로에게 걸기: a spell cast with no direction (`,`, or a click on Miho's own
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
##
## 둔갑 (GUISE: 목+토, the 벽 가르기 slot, and any number of 목): she takes the
## form of the last creature of heaven that fell (Actor.prey; any fall, as for
## the tail it gives back) for ROUNDS rounds and PER_WOOD more for every 목;
## with none fallen yet it is refused with NO_PREY. A creature of heaven that
## is not hunting her does not know her (`fools`): seeing her does not start a
## hunt, its spells do not seek her, and her claws catch it unawares. A hunter
## is not fooled. It is silent. The guise ends at the end of the round in which
## she has stood next to a creature of heaven BESIDE rounds in a row, when she
## casts any spell, or when she is hurt.

const SHADOW := &"shadow"
const GUISE := &"guise"
const NAME := {SHADOW: "그림자", GUISE: "둔갑"}
## The talismans that make each, at their weakest.
const RECIPE := {SHADOW: [Cards.FOX, Cards.WATER], GUISE: [Cards.WOOD, Cards.EARTH]}
const ONLY := "스스로에겐 그림자(여+수)나 둔갑(목+토)만 걸 수 있다"
const NO_PREY := "아직 처치한 적이 없다"
const ROUNDS := 8
const PER_WOOD := 2
const BESIDE := 2


## What `spell` does cast on oneself: SHADOW, GUISE, or empty when it does not
## go on oneself.
static func kind(spell: Spell) -> StringName:
	if spell == null:
		return &""
	if (
		spell.count(Cards.FOX) == 1
		and spell.has(Cards.WATER)
		and spell.slots.all(func(c): return c in [Cards.FOX, Cards.WATER])
	):
		return SHADOW
	if spell.count(&"split") == 1 and spell.slots.all(func(c): return c in [&"split", Cards.WOOD]):
		return GUISE
	return &""


## Why `a` cannot cast `spell` on itself, or empty when it can.
static func why(a: Actor, spell: Spell) -> String:
	match kind(spell):
		&"":
			return ONLY
		GUISE:
			return NO_PREY if a.prey == &"" else ""
	return ""


## Rounds a guise cast with `spell` lasts.
static func rounds(spell: Spell) -> int:
	return ROUNDS + PER_WOOD * spell.count(Cards.WOOD)


## `caster` casts `spell` along `dir`, which ends its guise. With no direction
## it goes on the caster: true, and World.cast has nothing more to do.
static func cast(w: World, caster: Actor, spell: Spell, dir: Vector2i) -> bool:
	if caster.guise > 0:
		unmask(w, caster, &"cast")
	if dir != Vector2i.ZERO:
		return false
	if kind(spell) == GUISE:
		caster.form = caster.prey
		caster.guise = rounds(spell)
		caster.beside = 0
		w.emit({t = &"guise", id = caster.id, at = caster.pos, kind = caster.form})
		return true
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


## Whether `by` takes `a` for someone else: `a` is in guise and `by` is a
## creature of heaven that is not hunting.
static func fools(by: Actor, a: Actor) -> bool:
	return a.guise > 0 and by.faction == Actor.HEAVEN and by.alert != Actor.HUNT


## Whether `a` sees Miho and knows her.
static func knows(w: World, a: Actor) -> bool:
	return w.sees(a, w.player().pos) and not fools(a, w.player())


## The kind `a` is drawn as: its form in guise.
static func looks(a: Actor) -> StringName:
	return a.form if a.guise > 0 else a.kind


## `a` was hurt: one in guise drops it; a creature of heaven that fell is the
## form Miho's next guise takes.
static func hurt(w: World, a: Actor) -> void:
	if a.alive() and a.guise > 0:
		unmask(w, a, &"hurt")
	elif not a.alive() and a.faction == Actor.HEAVEN:
		w.player().prey = a.kind


static func unmask(w: World, a: Actor, why_ended: StringName) -> void:
	a.guise = 0
	a.beside = 0
	w.emit({t = &"unmask", id = a.id, at = a.pos, why = why_ended})


## The end of a round: a dark wisp goes out where fire was lit within its
## reach, and Miho's guise counts its rounds and those she stood beside heaven.
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
	var me := w.player()
	if me.guise <= 0:
		return
	var near := w.actors.any(
		func(a): return a.alive() and a.faction == Actor.HEAVEN and Grid.cheb(a.pos, me.pos) == 1
	)
	me.beside = me.beside + 1 if near else 0
	me.guise -= 1
	if me.beside >= BESIDE:
		unmask(w, me, &"beside")
	elif me.guise == 0:
		unmask(w, me, &"time")
