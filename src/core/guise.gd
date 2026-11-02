class_name Guise
extends RefCounted
## 스스로에게 걸기: a spell cast with no direction (`,`, or a click on Miho's own
## tile) goes on the caster herself. Only the buffs, which change how she is
## seen, what her claws do or her element, take that aim (`kind`); any other is refused with
## `only`. 쇠발톱 goes on her whatever the direction (ANYWHERE). A buff takes at
## least 3 talismans and holds 목. It has no time limit, stays on her from storey
## to storey (but RAISE), and she can drop it: one round, no tail (`dispel`).
##
## 그림자 (SHADOW: 여, the 단비 slot of 수+목, and any number of 수): a dark wisp
## rides her (Elements.stick), darkening the tiles round her (Spell.light: 3, and
## one more for every 수 past the first). It is silent. The dark hides her only
## from afar: a creature still sees the tiles next to it (World.NIGHT). Any dark
## wisp goes out at the end of a round in which a tile within its reach
## (Chebyshev, walls or not) caught fire or had its lantern lit (`tick`).
##
## 둔갑 (GUISE: the 균열 slot of 목+토 and one 목): she takes the form of the last
## creature of heaven that fell (Actor.prey; any fall, as for the tail it gives
## back); with none fallen yet it is refused with NO_PREY. A creature of heaven
## that is not hunting her does not know her (`fools`): seeing her does not
## start a hunt, its spells do not seek her, and her claws catch it unawares. A
## hunter is not fooled, nor a tracker (Bestiary tracks): the form changes, the
## smell does not. Nor is a cunning creature (SEES_THROUGH). One that sees her
## put the guise on and is sharp (ALARMED) hunts her at once, so it is not fooled
## while it hunts; a dull one that sees it is fooled. It is silent. The guise ends at
## the end of the round in which she has stood next to a creature of heaven BESIDE
## rounds in a row, when she casts any spell, or when she is hurt.
##
## 쇠발톱 (TALON, the 3단 of 화, 금 and 목): each claw of hers harms TALON_HARM
## more, or TALON_ABSORBED more against a creature that absorbs 쇠
## (Harm.claw_harm). The spell is silent.
##
## 은신 (CLOAK: 여 and the 균열 slot of 목+토): she wears the hat of 감투 도깨비
## (Hat): a creature knows her only from the next tile or while a wisp of another
## clings to her, a hunter too. The spell is silent. A tracker follows her scent
## even while it hunts (Mind.hunt), and a clever creature throws its wisp at where
## it suspects her (Aim.suspected).
##
## 불여우 (FLAME: 여 and the 들불 slot of 목+불): she counts as a fire creature
## (Actor.nature_kind = FLAME_KIND), under the rule creatures obey (Bestiary.absorbs,
## weak): fire spells and burning tiles do her no harm, water harms her twice over,
## and every spell of hers that holds 불 and harms does FLAME_HARM more (`flame_harm`).
## The spell is silent. Thrown along a direction it is the 여우불 of 들불, as ever.
##
## 사령술 (RAISE: the 윤회 slot of all five elements, 목 among them): the dead she sees rise
## as allies (Raise). The one buff with a time limit: it ends when she goes to another
## storey, by any way (Storeys.enter). The spell is silent. Thrown along a direction it
## is 윤회, as ever.

const SHADOW := &"shadow"
const GUISE := &"guise"
const TALON := &"talon"
const CLOAK := &"cloak"
const FLAME := &"flame"
const RAISE := &"raise"
const NAME := {
	SHADOW: "그림자",
	GUISE: "둔갑",
	TALON: Cards.NAME[TALON],
	CLOAK: "은신",
	FLAME: "불여우",
	RAISE: "사령술",
}
## The talismans that make each, at their weakest.
const RECIPE := {
	SHADOW: [Cards.FOX, Cards.WATER, Cards.WOOD],
	GUISE: [Cards.WOOD, Cards.EARTH, Cards.WOOD],
	TALON: [Cards.FIRE, Cards.WOOD, Cards.METAL],
	CLOAK: [Cards.FOX, Cards.WOOD, Cards.EARTH],
	FLAME: [Cards.FOX, Cards.FIRE, Cards.WOOD],
	RAISE: [Cards.EARTH, Cards.METAL, Cards.WATER, Cards.FIRE, Cards.WOOD],
}
## The creature whose elements 불여우 gives her: a 불개, a fire creature that
## does nothing more with them.
const FLAME_KIND := &"bulgae"
## What her harming spells that hold 불 do more as 불여우.
const FLAME_HARM := 1
## The spells that go on her whatever the direction they are cast along.
const ANYWHERE := [TALON]
## The spells that take no other slot beside them.
const ALONE := [TALON, Cards.BUNSIN]
const NO_PREY := "아직 처치한 적이 없다"
const MIXED := "다른 부적과 섞을 수 없는 주문이다"
const BESIDE := 2
## The wits (Bestiary) from which a creature that sees her put on a guise hunts
## her, and from which it is never fooled.
const ALARMED := Bestiary.SHARP
const SEES_THROUGH := Bestiary.CUNNING
const TALON_HARM := 2
const TALON_ABSORBED := 1


## The refusal for a spell that does not go on oneself, listing every one that does.
static func only() -> String:
	return _only(func(s: String, _context := "") -> String: return s)


## `only` in the language shown, for the player to read and no rule to use.
static func shown_only() -> String:
	return _only(Lang.t)


static func _only(t: Callable) -> String:
	var spells := RECIPE.keys().map(
		func(k):
			var cards: Array = RECIPE[k].map(func(c): return t.call(Cards.GLYPH[c], "talisman"))
			return "%s(%s)" % [t.call(NAME[k]), "+".join(cards)]
	)
	return t.call("스스로에겐 %s만 걸 수 있다") % ", ".join(spells)


## What `spell` does cast on oneself: SHADOW, GUISE, TALON, CLOAK, FLAME, RAISE, or empty when
## it does not go on oneself.
static func kind(spell: Spell) -> StringName:
	if spell == null:
		return &""
	if spell.slots.size() == 1 and ANYWHERE.has(spell.slots[0]):
		return spell.slots[0]
	if spell.slots == [Cards.SAMSARA]:
		return RAISE
	if (
		spell.count(Cards.FOX) == 1
		and spell.count(&"rain") == 1
		and spell.slots.all(func(c): return c in [Cards.FOX, &"rain", Cards.WATER])
	):
		return SHADOW
	if spell.slots.size() == 2 and spell.count(&"rift") == 1:
		if spell.has(Cards.FOX):
			return CLOAK
		if spell.has(Cards.WOOD):
			return GUISE
	if spell.slots.size() == 2 and spell.count(&"wildfire") == 1 and spell.has(Cards.FOX):
		return FLAME
	return &""


## Whether `spell` holds a talisman that goes alone (ALONE) beside another slot.
static func mixed(spell: Spell) -> bool:
	return spell.slots.size() > 1 and spell.slots.any(func(c): return ALONE.has(c))


## Why `a` cannot cast `spell` on itself, or empty when it can.
static func why(a: Actor, spell: Spell) -> String:
	if mixed(spell):
		return MIXED
	match kind(spell):
		&"":
			return only()
		GUISE:
			return NO_PREY if a.prey == &"" else ""
	return ""


## The dark wisp a 그림자 cast with `spell` lays on her: a wisp of every 수 in the
## spell, the one in the 단비 slot among them.
static func dark(spell: Spell) -> Spell:
	var waters := []
	waters.resize(spell.cards.count(Cards.WATER))
	waters.fill(Cards.WATER)
	return Spell.make([Cards.FOX] + waters)


## `caster` casts `spell` along `dir`, which ends its guise. With no direction
## (any for ANYWHERE) it goes on the caster: true, and Cast.cast has nothing
## more to do.
static func cast(w: World, caster: Actor, spell: Spell, dir: Vector2i) -> bool:
	if caster.guise:
		unmask(w, caster, &"cast")
	var own := kind(spell)
	if dir != Vector2i.ZERO and not ANYWHERE.has(own):
		return false
	match own:
		GUISE:
			_alarm(w, caster)
			caster.form = caster.prey
			caster.guise = true
			caster.beside = 0
			w.emit({t = &"guise", id = caster.id, at = caster.pos, kind = caster.form})
			return true
		TALON:
			caster.talon = true
			w.emit({t = &"talon", id = caster.id, at = caster.pos})
			return true
		CLOAK:
			caster.cloak = true
			w.emit({t = &"cloak", id = caster.id, at = caster.pos})
			return true
		FLAME:
			caster.flame = true
			w.emit({t = &"flame", id = caster.id, at = caster.pos})
			return true
		RAISE:
			caster.raise = true
			w.emit({t = &"raise", id = caster.id, at = caster.pos})
			return true
	for old in shadows(w, caster):
		old.gone = true
		w.emit({t = &"fade", shot = old.id, at = old.pos})
	var s := Shot.of(w, caster, dark(spell))
	s.spell.called = NAME[SHADOW]
	w.shots.append(s)
	Elements.stick(w, s, caster)
	s.life = 0
	return true


## Every creature of heaven of ALARMED wits that sees `caster` put on a guise
## hunts her from where she stands.
static func _alarm(w: World, caster: Actor) -> void:
	for a in _watching(w, caster):
		if Bestiary.wits(a.kind) >= ALARMED:
			Mind.hunt_from(w, a, caster.pos)


## The living creatures of heaven that see `caster`.
static func _watching(w: World, caster: Actor) -> Array:
	return w.actors.filter(
		func(a):
			return (
				a.alive()
				and a.faction == Actor.HEAVEN
				and w.sees(a, caster.pos)
				and not Hat.hidden(w, caster, a.pos)
			)
	)


## The nearest creature that would see through the 둔갑 among `spells`, or null when
## they hold none or none would: one that sees her and is sharp or hunts already.
static func watcher(w: World, spells: Array) -> Actor:
	if not spells.any(
		func(s): return s.dir == Vector2i.ZERO and kind(Spell.make(s.cards)) == GUISE
	):
		return null
	var me := w.player()
	var foes := _watching(w, me).filter(
		func(a): return Bestiary.wits(a.kind) >= ALARMED or a.alert == Actor.HUNT
	)
	foes.sort_custom(
		func(a, b):
			var near: int = Grid.cheb(a.pos, me.pos) - Grid.cheb(b.pos, me.pos)
			return near < 0 or near == 0 and a.id < b.id
	)
	return null if foes.is_empty() else foes[0]


## The 그림자 on `a`: the wisps of its own that ride it.
static func shadows(w: World, a: Actor) -> Array[Shot]:
	var out: Array[Shot] = []
	out.assign(Walk.riders(w, a).filter(func(s): return s.caster == a.id))
	return out


## The buffs on `a`, in the order of RECIPE.
static func worn(w: World, a: Actor) -> Array:
	var on := {
		SHADOW: not shadows(w, a).is_empty(),
		GUISE: a.guise,
		TALON: a.talon,
		CLOAK: a.cloak,
		FLAME: a.flame,
		RAISE: a.raise,
	}
	return RECIPE.keys().filter(func(k): return on[k])


## `a` drops its buff `which`.
static func dispel(w: World, a: Actor, which: StringName) -> void:
	match which:
		SHADOW:
			for s in shadows(w, a):
				s.gone = true
				w._changed()
				w.emit(
					{
						t = &"fade",
						shot = s.id,
						at = s.pos,
						dropped = true,
						title = s.spell.title(),
						spell = s.spell.tag()
					}
				)
		GUISE:
			unmask(w, a, &"dispel")
		TALON:
			a.talon = false
			w.emit({t = &"untalon", id = a.id, at = a.pos})
		CLOAK:
			a.cloak = false
			w.emit({t = &"uncloak", id = a.id, at = a.pos})
		FLAME:
			a.flame = false
			w.emit({t = &"unflame", id = a.id, at = a.pos})
		RAISE:
			a.raise = false
			w.emit({t = &"unraise", id = a.id, at = a.pos})


## What 쇠발톱 adds to a claw of `me` at `foe`, or at no creature in particular.
static func talon_harm(me: Actor, foe: Actor = null) -> int:
	if not me.talon:
		return 0
	var eats := foe != null and Bestiary.absorbs(foe.kind, Spell.make([Cards.METAL]))
	return TALON_ABSORBED if eats else TALON_HARM


## What 불여우 adds to the harm of a spell of `caster` that holds 불. 벼락 is no element.
static func flame_harm(w: World, caster: int, spell: Spell) -> int:
	var me := w.actor(caster)
	if me == null or not me.flame or spell.electric():
		return 0
	return FLAME_HARM if spell.holds(Cards.FIRE) else 0


## The harm a hit of the flying shot `s` does, by what 불여우 adds.
static func shot_harm(w: World, s: Shot) -> int:
	var n := s.spell.damage(s.distance())
	return n + flame_harm(w, s.caster, s.spell) if n > 0 else n


## Whether `by` takes `a` for someone else: `a` is in guise and `by` is a creature
## of heaven that is not hunting, does not go by smell and is not cunning.
static func fools(by: Actor, a: Actor) -> bool:
	return (
		a.guise
		and by.faction == Actor.HEAVEN
		and by.alert != Actor.HUNT
		and not by.info().get("tracks", false)
		and Bestiary.wits(by.kind) < SEES_THROUGH
	)


## Whether `a` sees Miho and knows her.
static func knows(w: World, a: Actor) -> bool:
	return Hat.sees(w, a, w.player())


## The kind `a` is drawn as: its form in guise.
static func looks(a: Actor) -> StringName:
	return a.form if a.guise else a.kind


## `a` was hurt: one in guise drops it; a creature of heaven that fell is the
## form Miho's next guise takes.
static func hurt(w: World, a: Actor) -> void:
	if a.alive() and a.guise:
		unmask(w, a, &"hurt")
	elif not a.alive() and a.faction == Actor.HEAVEN:
		w.player().prey = a.kind


static func unmask(w: World, a: Actor, why_ended: StringName) -> void:
	a.guise = false
	a.beside = 0
	w.emit({t = &"unmask", id = a.id, at = a.pos, why = why_ended})


## The end of a round: a dark wisp goes out where fire was lit within its reach,
## and Miho in guise counts the rounds she stood beside heaven.
static func tick(w: World) -> void:
	var lit := w.events.filter(func(e): return e.t == &"ignite" or e.t == &"relight")
	for s in w.shots:
		var l := s.spell.light(s.faction)
		if s.gone or l.is_empty() or Light.level(l.color) > 0.0:
			continue
		if lit.any(func(e): return Grid.cheb(e.at, s.pos) <= l.radius):
			s.gone = true
			w._changed()
			w.emit(
				{
					t = &"fade",
					shot = s.id,
					at = s.pos,
					lit = true,
					title = s.spell.title(),
					spell = s.spell.tag()
				}
			)
	var me := w.player()
	if not me.guise:
		return
	var near := w.actors.any(
		func(a): return a.alive() and a.faction == Actor.HEAVEN and Grid.cheb(a.pos, me.pos) == 1
	)
	me.beside = me.beside + 1 if near else 0
	if me.beside >= BESIDE:
		unmask(w, me, &"beside")
