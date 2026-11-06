class_name Guise
extends RefCounted
## 스스로에게 걸기: a spell cast with no direction (`,`, or a click on Miho's own
## tile) goes on the caster herself. Only the buffs, which change how she is
## seen, what her claws do or her element, take that aim (`kind`); any other is refused with
## `only`. 쇠발톱 and 사령술 go on her whatever the direction (ANYWHERE). A buff takes at
## least 3 talismans and holds 목. It has no time limit, stays on her from storey
## to storey (but RAISE), and she can drop it: one round, no tail (`dispel`).
## The casts of 둔갑, 쇠발톱, 은신, 불여우 and 도약 are heard (LOUD); the other two are
## silent.
##
## 그림자 (SHADOW: 여, the 단비 slot of 수+목, and any number of 수): a dark wisp
## rides her (Elements.stick), darkening the tiles round her (Spell.light: 3, and
## one more for every 수 past the first). It is silent. The dark hides her only
## from afar: a creature still sees the tiles next to it (World.NIGHT). Any dark
## wisp goes out at the end of a round in which a tile within its reach
## (Chebyshev, walls or not) caught fire or had its lantern lit (`tick`).
##
## 둔갑 (GUISE: the 균열 slot of 목+토 and one 목): she takes the form of the last
## creature of heaven that fell (Buffs.prey; any fall, as for the tail it gives
## back); with none fallen yet it is refused with NO_PREY. A creature of heaven
## that is not hunting her does not know her (`fools`): seeing her does not
## start a hunt, its spells do not seek her, and her claws catch it unawares. A
## hunter is not fooled, nor a tracker (Bestiary tracks): the form changes, the
## smell does not. Nor is a cunning creature (SEES_THROUGH). One that sees her
## put the guise on and is sharp (ALARMED) hunts her at once, so it is not fooled
## while it hunts; a dull one that sees it is fooled. The guise ends at
## the end of the round in which she has stood next to a creature of heaven BESIDE
## rounds in a row, when she casts any spell, or when she is hurt.
##
## 쇠발톱 (TALON, the 3단 of 화, 금 and 목): each claw of hers harms TALON_HARM
## more, or TALON_ABSORBED more against a creature that absorbs 쇠
## (Harm.claw_harm), and is heard TALON_LOUD tiles even on a sneak attack
## (Harm.claw_loud).
##
## 은신 (CLOAK: 여 and the 균열 slot of 목+토): she wears the hat of 감투 도깨비
## (Hat): a creature knows her only from the next tile or while a wisp of another
## clings to her, a hunter too. A tracker follows her scent
## even while it hunts (Mind.hunt), and a clever creature throws its wisp at where
## it suspects her (Aim.suspected).
##
## 불여우 (FLAME: 여 and the 들불 slot of 목+불): she counts as a fire creature
## (Actor.nature_kind = FLAME_KIND), under the rule creatures obey (Bestiary.absorbs,
## weak): fire spells, 쇠 and burning tiles do her no harm, water harms her twice over,
## and a spell of hers that holds 불 harms a creature that would stop it whole by
## absorbing fire, for FLAME_THROUGH at most, and feeds it nothing (`through`).
## Thrown along a direction it is the 여우불 of 들불, as ever.
##
## 사령술 (RAISE, a set of 여, 토, 금, 수 and 목: Cards.SETS): the dead she sees rise as
## allies (Raise). The one buff with a time limit: it ends when she goes to another
## storey, by any way (Storeys.enter). The spell is silent and goes on her whatever the
## direction (ANYWHERE).
##
## 도약 (VAULT: the talisman alone): the next fall harms nothing, however many storeys
## it drops her, and ends the buff (`land`); a fall that does not happen (the first
## storey) leaves it. She lands in a ring of steam (Leap.vent). Cast along a direction
## it is the leap, as ever; only the aim at herself puts it on her, and only once.

const SHADOW := &"shadow"
const GUISE := &"guise"
const TALON := &"talon"
const CLOAK := &"cloak"
const FLAME := &"flame"
const RAISE := &"raise"
const VAULT := Cards.VAULT
const NAME := {
	SHADOW: "그림자",
	GUISE: "둔갑",
	TALON: Cards.NAME[TALON],
	CLOAK: "은신",
	FLAME: "불여우",
	RAISE: Cards.NAME[RAISE],
	VAULT: Cards.NAME[VAULT],
}
## The talismans that make each, at their weakest.
const RECIPE := {
	SHADOW: [Cards.FOX, Cards.WATER, Cards.WOOD],
	GUISE: [Cards.WOOD, Cards.EARTH, Cards.WOOD],
	TALON: [Cards.FIRE, Cards.WOOD, Cards.METAL],
	CLOAK: [Cards.FOX, Cards.WOOD, Cards.EARTH],
	FLAME: [Cards.FOX, Cards.FIRE, Cards.WOOD],
	RAISE: Cards.COMPOUND[RAISE].made,
	VAULT: Cards.COMPOUND[VAULT].made,
}
## The creature whose elements 불여우 gives her: of fire, and immune to fire besides.
const FLAME_KIND := &"flame_fox"
## The most her spells that hold 불 harm a creature that would stop them whole.
const FLAME_THROUGH := 1
## The spells that go on her whatever the direction they are cast along.
const ANYWHERE := [TALON, RAISE]
## The spells that take no other slot beside them.
const ALONE := [TALON, Cards.BUNSIN, RAISE, &"beacon", &"furnace"]
const NO_PREY := "아직 처치한 적이 없다"
const WORN := "이미 건 주문은 다시 걸 수 없다"
const NO_ORB := "구슬 없이는 던질 수 없다"
const MIXED := "다른 부적과 섞을 수 없는 주문이다"
const BESIDE := 2
## The wits (Bestiary) from which a creature that sees her put on a guise hunts
## her, and from which it is never fooled.
const ALARMED := Bestiary.SHARP
const SEES_THROUGH := Bestiary.CUNNING
const TALON_HARM := 2
const TALON_ABSORBED := 1
## The buffs whose cast is heard CAST_LOUD tiles as a rustle, and a claw under 쇠발톱,
## TALON_LOUD.
const LOUD := [GUISE, TALON, CLOAK, FLAME, VAULT]
const CAST_LOUD := 3
const CAST_WORD := "바스락"
const TALON_LOUD := 3


## The refusal for a spell that does not go on oneself, listing every one that does.
static func only() -> String:
	return _only(func(s: String, _context := "") -> String: return s)


## `only` in the language shown, for the player to read and no rule to use.
static func shown_only() -> String:
	return _only(Lang.t)


static func _only(t: Callable) -> String:
	var spells := RECIPE.keys().map(
		func(k):
			var cards: Array = RECIPE[k].map(func(c): return Cards.part(c, t))
			return "%s(%s)" % [t.call(NAME[k]), "+".join(cards)]
	)
	return t.call("스스로에겐 %s만 걸 수 있다") % ", ".join(spells)


## What `spell` does cast on oneself: SHADOW, GUISE, TALON, CLOAK, FLAME, RAISE, VAULT, or empty
## when it does not go on oneself.
static func kind(spell: Spell) -> StringName:
	if spell == null:
		return &""
	if spell.slots.size() == 1 and spell.slots[0] == Cards.VAULT:
		return VAULT
	if spell.slots.size() == 1 and ANYWHERE.has(spell.slots[0]):
		return spell.slots[0]
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
	var most := 2 if spell.has(Forge.FURNACE) else 1
	return spell.slots.size() > most and spell.slots.any(func(c): return ALONE.has(c))


## Why `a` cannot cast `spell` on itself, or empty when it can.
static func why(a: Actor, spell: Spell, dir := Vector2i.ZERO) -> String:
	if Forge.needs_orb(spell):
		return NO_ORB
	if (dir != Vector2i.ZERO or Forge.around(spell)) and not mixed(spell):
		return ""
	if mixed(spell):
		return MIXED
	match kind(spell):
		&"":
			return only()
		GUISE:
			return NO_PREY if a.buffs.prey == &"" else ""
		VAULT:
			return WORN if a.buffs.vault else ""
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
	if caster.buffs.guise:
		unmask(w, caster, &"cast")
	var own := kind(spell)
	if (dir != Vector2i.ZERO or Forge.around(spell)) and not ANYWHERE.has(own):
		return false
	if LOUD.has(own):
		Hearing.noise(w, caster.pos, CAST_LOUD, CAST_WORD, caster.faction == Actor.FOX, caster.id)
	match own:
		GUISE:
			_alarm(w, caster)
			caster.buffs.form = caster.buffs.prey
			caster.buffs.guise = true
			caster.buffs.beside = 0
			w.emit({t = &"guise", id = caster.id, at = caster.pos, kind = caster.buffs.form})
			return true
		TALON:
			caster.buffs.talon = true
			w.emit({t = &"talon", id = caster.id, at = caster.pos})
			return true
		CLOAK:
			caster.buffs.cloak = true
			w.emit({t = &"cloak", id = caster.id, at = caster.pos})
			return true
		FLAME:
			caster.buffs.flame = true
			w.emit({t = &"flame", id = caster.id, at = caster.pos})
			return true
		RAISE:
			caster.buffs.raise = true
			w.emit({t = &"raise", id = caster.id, at = caster.pos})
			return true
		VAULT:
			caster.buffs.vault = true
			w.emit({t = &"vault", id = caster.id, at = caster.pos})
			return true
	for old in shadows(w, caster):
		old.gone = true
		w._light_dirty = true
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
		func(a): return Bestiary.wits(a.kind) >= ALARMED or a.brain.alert == Actor.HUNT
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
		GUISE: a.buffs.guise,
		TALON: a.buffs.talon,
		CLOAK: a.buffs.cloak,
		FLAME: a.buffs.flame,
		RAISE: a.buffs.raise,
		VAULT: a.buffs.vault,
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
			a.buffs.talon = false
			w.emit({t = &"untalon", id = a.id, at = a.pos})
		CLOAK:
			a.buffs.cloak = false
			w.emit({t = &"uncloak", id = a.id, at = a.pos})
		FLAME:
			a.buffs.flame = false
			w.emit({t = &"unflame", id = a.id, at = a.pos})
		RAISE:
			a.buffs.raise = false
			w.emit({t = &"unraise", id = a.id, at = a.pos})
		VAULT:
			a.buffs.vault = false
			w.emit({t = &"unvault", id = a.id, at = a.pos})


## `a` lands from a fall that 도약 softened: the buff is spent and steam rings the landing.
static func land(w: World, a: Actor) -> void:
	a.buffs.vault = false
	w.emit({t = &"unvault", id = a.id, at = a.pos, fall = true})
	Leap.vent(w, a.pos)


## What 쇠발톱 adds to a claw of `me` at `foe`, or at no creature in particular.
static func talon_harm(me: Actor, foe: Actor = null) -> int:
	if not me.buffs.talon:
		return 0
	var eats := foe != null and Bestiary.absorbs(foe.kind, Spell.make([Cards.METAL]))
	return TALON_ABSORBED if eats else TALON_HARM


## Whether the spell `s` gets through `a`, which would stop it whole (Bestiary.absorbs): the
## caster is 불여우, is not `a` itself and the spell holds 불. It harms for FLAME_THROUGH
## at most, sets nothing alight and feeds nothing (Elements.strike, splash, harm).
static func through(w: World, s: Shot, a: Actor) -> bool:
	var me := w.actor(s.caster)
	return (
		me != null
		and me != a
		and me.buffs.flame
		and s.spell.nature().has(Cards.FIRE)
		and Bestiary.absorbs(a.nature_kind(), s.spell)
	)


## Whether `by` takes `a` for someone else: `a` is in guise and `by` is a creature
## of heaven that is not hunting, does not go by smell and is not cunning.
static func fools(by: Actor, a: Actor) -> bool:
	return (
		a.buffs.guise
		and by.faction == Actor.HEAVEN
		and by.brain.alert != Actor.HUNT
		and not by.info().get("tracks", false)
		and Bestiary.wits(by.kind) < SEES_THROUGH
	)


## Whether `a` sees Miho and knows her.
static func knows(w: World, a: Actor) -> bool:
	return Hat.sees(w, a, w.player())


## The kind `a` is drawn as: its form in guise.
static func looks(a: Actor) -> StringName:
	return a.buffs.form if a.buffs.guise else a.kind


## `a` was hurt: one in guise drops it; a creature of heaven that fell is the
## form Miho's next guise takes.
static func hurt(w: World, a: Actor) -> void:
	if a.alive() and a.buffs.guise:
		unmask(w, a, &"hurt")
	elif not a.alive() and a.faction == Actor.HEAVEN:
		w.player().buffs.prey = a.kind


static func unmask(w: World, a: Actor, why_ended: StringName) -> void:
	a.buffs.guise = false
	a.buffs.beside = 0
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
	if not me.buffs.guise:
		return
	var near := w.actors.any(
		func(a): return a.alive() and a.faction == Actor.HEAVEN and Grid.cheb(a.pos, me.pos) == 1
	)
	me.buffs.beside = me.buffs.beside + 1 if near else 0
	if me.buffs.beside >= BESIDE:
		unmask(w, me, &"beside")
