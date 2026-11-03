class_name Spell
extends RefCounted
## A spell is a queue of up to MAX_SLOTS talisman slots, filled card by card.
## A card of the same talisman again stacks; an element merges with the first
## slot it can join (Cards.join): a different element into their compound
## (Cards.PAIRS), one slot worth two cards, or a pair and a third element into
## the 3단 compound of the three (Cards.TRIPLES), one slot worth three, and on
## up to the 5단 of all five. A spell of 1 to 5 cards costs COST tails, and each
## card past five two more.
## Every spell is hurled along one of eight lines, and grows with the cards it
## holds: one card is power 1.
## The shape is read top down: 도약 (Cards.VAULT) leading the queue leaps
## Miho LEAP_BASE tiles and LEAP_PER_WOOD more for every 목 slot right behind it, and
## casts the rest of the spell where she lands (Leap). 도약 last behind 여 or
## 구 swaps: Miho goes where the projectile ends, trading places with the
## creature it strikes (Leap.swap); 도약 anywhere else makes no spell. 여 and
## 구 make a homing
## orb that turns 45° more each tile for every 여 (freely with four); 구 alone
## a loud straight orb, 1 damage for every 구 and 1 more after a run-up (DCSS
## mon-project.cc iood_damage); 여 alone a wisp for every 여 (one with 도약),
## each hitting for 1 (a lone 여 for none), turning WISP_TURN for every 여.
## From three 구 an orb gains speed every round it flies (`accel`, Shot.pace)
## and where it ends blasts the eight tiles round it (`blast`, Elements.splash);
## four make a cast of two orbs that spread among the creatures in sight
## (Homing.spread), five blast the full harm of the centre. 구 with 수 pushes the
## creature it strikes (Elements.strike).
## Homing projectiles chase a creature (Homing). A wisp flies up to RANGE
## tiles, chasing or not, and where it stops, at a wall or the end of its
## range, it hovers WISP_LIFE rounds, lights its surroundings and flies no
## more. A wisp that strikes a
## creature that does not eat it sticks to it for WISP_LIFE rounds and lights
## it wherever it goes (Elements.stick); a bullet does not stick. Elements alone spray: they
## cover their tiles in the round they are cast, with no projectile (Spray).
## Each element shows its nature by the form it rides, one step stronger for
## every copy (Elements): 쇠 makes a wisp a bullet and an orb a cannonball. A
## wisp with one 쇠 is a 탄환, a creature's a 번개 (`bullet`), and with two
## armour-piercing (`pierces`, 철갑탄); an orb that carries 유탄
## is a 비격진 (`mortar`), which bursts where it ends (Compounds).
## A compound is an element of its own (Compounds): it does not count as its
## elements for what a spell physically does (`holds`: fire spreading, washing,
## wood catching fire). For what a creature is weak to, absorbs or eats it
## counts as `nature`.

const MAX_SLOTS := 5
## Tails a spell of 1 to 5 cards costs.
const COST := [1, 2, 3, 5, 7]
## Tails each card past MAX_SLOTS costs.
const COST_EXTRA := 2
const MOMENTUM := 4
const WISP_SPEED := 3
## A lone orb; each more in the spell adds one, up to a bullet's.
const ORB_SPEED := 2
## A bullet: a wisp with 쇠. The fastest projectile.
const BULLET_SPEED := 5
const RANGE := 7
const WISP_LIFE := 8
const HOMING_LIFE := 6
const TURN_FREE := 4
## Degrees of turn: one step of the eight directions, and what a wisp banks
## each tile for every 여.
const TURN_STEP := 45
const WISP_TURN := 30
## Tiles a leap reaches past the 도약 slot's own and one for every 목 behind it.
const LEAP_BASE := 2
## Tiles one 목 slot behind a 도약 adds to a leap.
const LEAP_PER_WOOD := 3
## The radius of the darkness a wisp of 수 carries, and what each 수 past the
## first adds.
const DARK_RADIUS := 3
const DARK_PER_WATER := 1

## Copies of 구 from which an orb gains speed (ORB_ACCEL) and its end blasts the
## eight tiles round it (`edge`); from TWIN_TIER one cast hurls TWINS orbs.
const BLAST_TIER := 3
const TWIN_TIER := 4
const TWINS := 2
## The copies of 구 from which the blast hurts half the harm at its centre, and all of it.
const HALF_TIER := 4
const FULL_TIER := 5
## What a blast hurts each creature round it from BLAST_TIER, before it reaches HALF_TIER.
const BLAST_HARM := 1
## Tiles a second an orb gains each round it flies (Shot.pace), by copies of 구.
const ORB_ACCEL := [0, 0, 0, 1, 2, 3]

const LEAP := &"leap"
const HOMING := &"homing"
const ORB := &"orb"
const WISP := &"wisp"
const SPRAY := &"spray"
const SHAPE_NAME := {LEAP: "멀리뛰기", HOMING: "유도 구슬", ORB: "구슬", WISP: "여우불"}
## Copies past which an element's spray grows no more.
const MAX_LEVEL := 5
## The 쇠 that make a wisp armour-piercing, and its name.
const PIERCE_METALS := 2
const PIERCE_NAME := "철갑탄"
## A wisp with one 쇠: Miho's, and a creature's (`wisp_name` set).
const BULLET_NAME := "탄환"
const BOLT_NAME := "번개"
## An orb that carries 유탄, and its name.
const MORTAR_NAME := "비격진"

## The cards as they were queued, repeats and all; the slots they fill.
var cards: Array[StringName] = []
var slots: Array[StringName] = []
var shape := &""
## The spell is an orb: straight or homing.
var orb := false
## A name a creature gives its own spell (Bestiary.spell), in place of title().
var called := ""
## A creature's word for its wisps (Bestiary.spell), in place of SHAPE_NAME.
var wisp_name := ""


## The spell `picked` queues, or null when it is no spell.
static func make(picked: Array) -> Spell:
	if not picked.all(func(c): return Cards.ALL.has(c)):
		return null
	var slots := fill(picked)
	var spell := Spell.new()
	spell.cards.assign(picked)
	spell.slots = slots
	spell.shape = _shape(spell)
	spell.orb = spell.shape in [HOMING, ORB]
	if slots.is_empty() or slots.size() > MAX_SLOTS or spell.shape == &"":
		return null
	var vault := slots.find(Cards.VAULT, 1)
	if vault != -1 and (vault < slots.size() - 1 or spell.shape in [LEAP, SPRAY]):
		return null
	return spell


## The slots the talismans `picked` fill, in order.
static func fill(picked: Array) -> Array[StringName]:
	var slots: Array[StringName] = []
	for c in picked:
		slots = queue(slots, c)
	return slots


## The slots after card `c` joins them: an element merges with the first slot
## it can join (Cards.join), but a 도약 that another slot follows, which stays a
## leap; anything else goes at the end. A slot that grows takes in the lone
## elements it now joins (`_settled`). The cards that make a compound of
## Cards.SETS in any order are that one slot, which another card takes apart again.
static func queue(slots: Array[StringName], c: StringName) -> Array[StringName]:
	var whole := Cards.set_of(_cards_of(slots) + [c])
	if whole != &"":
		return [whole]
	var out := slots
	if slots.any(func(s): return Cards.SETS.has(s)):
		out = []
		for card: StringName in _cards_of(slots):
			out = _joined(out, card)
	return _joined(out, c)


## `slots` with `c` joined as `queue` tells, no set made of them.
static func _joined(slots: Array[StringName], c: StringName) -> Array[StringName]:
	var out := slots.duplicate()
	if Cards.ELEMENTS.has(c):
		for i in out.size():
			if out[i] == Cards.VAULT and i < out.size() - 1:
				continue
			var joined := Cards.join(out[i], c)
			if joined != &"":
				out[i] = joined
				return _settled(out, i)
	out.append(c)
	return out


## Slot `i` has just grown: it takes in any lone element it now joins, so the
## order of the cards does not leave a compound in two slots.
static func _settled(slots: Array[StringName], i: int) -> Array[StringName]:
	if slots[i] == Cards.VAULT:
		return slots
	for j in slots.size():
		var joined := Cards.join(slots[i], slots[j]) if Cards.ELEMENTS.has(slots[j]) else &""
		if j != i and joined != &"":
			slots[i] = joined
			slots.remove_at(j)
			return _settled(slots, i - 1 if j < i else i)
	return slots


## The cards `slots` are worth, in order: what a part of a spell casts.
static func _cards_of(slots: Array) -> Array:
	var out := []
	for slot: StringName in slots:
		out.append_array(Cards.recipe(slot))
	return out


## The shape the slots make, read top down: a leap, a homing orb, an orb,
## foxfire, a spray.
static func _shape(s: Spell) -> StringName:
	if not s.slots.is_empty() and s.slots[0] == Cards.VAULT:
		return LEAP
	if s.count(Cards.FOX) > 0 and s.count(Cards.ORB) > 0:
		return HOMING
	if s.count(Cards.ORB) > 0:
		return ORB
	if s.count(Cards.FOX) > 0:
		return WISP
	return SPRAY if not s.slots.is_empty() else &""


## Tiles a leap reaches: LEAP_BASE, one for its 도약 and LEAP_PER_WOOD for every 목
## slot right behind it.
func leap() -> int:
	return LEAP_BASE + 1 + _woods() * LEAP_PER_WOOD


## The 목 slots right behind a leading 도약: they add reach, not roots.
func _woods() -> int:
	var n := 0
	while 1 + n < slots.size() and slots[1 + n] == Cards.WOOD:
		n += 1
	return n


## What a leap casts where it lands: the slots after its 도약 and 목, or null.
func rest() -> Spell:
	return make(_cards_of(slots.slice(1 + _woods())))


## Whether the projectile takes Miho where it ends: 도약 behind it (Leap.swap).
func swaps() -> bool:
	return shape != LEAP and has(Cards.VAULT)


## The spell without its 도약: the projectile once it has swapped.
func spent() -> Spell:
	return make(_cards_of(slots.filter(func(c): return c != Cards.VAULT)))


## How strong the spray of a lone element is: its copies, up to MAX_LEVEL; 0
## when the first slot is a compound or the spell is no spray.
func level() -> int:
	if shape != SPRAY or not Cards.ELEMENTS.has(slots[0]):
		return 0
	return mini(count(slots[0]), MAX_LEVEL)


## Copies of a talisman or a compound in the spell.
func count(card: StringName) -> int:
	return slots.count(card)


func has(card: StringName) -> bool:
	return count(card) > 0


## Whether an element is in the spell, alone or in a compound.
func holds(element: StringName) -> bool:
	return slots.any(func(slot): return Cards.parts(slot).has(element))


## The elements the spell meets in a creature (Bestiary.weak, absorbs, eats),
## each once, in 오행 order: those of every slot (Cards.nature).
func nature() -> Array[StringName]:
	var held: Array = slots.reduce(func(all, slot): return all + Cards.nature(slot), [])
	var out: Array[StringName] = []
	out.assign(Cards.ELEMENTS.filter(func(e): return held.has(e)))
	return out


## Whether the spell is of 전기 (Elements.charge): a slot of it.
func electric() -> bool:
	return slots.any(func(slot): return Cards.marked(slot, "electric"))


## The compound slots, each once, in queue order.
func compounds() -> Array[StringName]:
	var out: Array[StringName] = []
	for slot in slots:
		if Cards.parts(slot).size() > 1 and not out.has(slot):
			out.append(slot)
	return out


func homing() -> bool:
	return shape == HOMING


## The element slots, compounds among them but 도약, in queue order.
func elements() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(slots.filter(func(c): return not Cards.FORMS.has(c) and c != Cards.VAULT))
	return out


func key() -> String:
	return "+".join(cards)


## The spell a key() names, or null.
static func from_key(k: String) -> Spell:
	return make(Array(k.split("+")).map(func(c): return StringName(c)))


## What an event keeps of the spell: plain data, so that a forecast's events
## equal the round's.
func tag() -> Dictionary:
	return {cards = cards, called = called, wisp_name = wisp_name}


## The spell a tag() describes.
static func from_tag(data: Dictionary) -> Spell:
	var spell := make(data.cards)
	spell.called = data.called
	spell.wisp_name = data.wisp_name
	return spell


## The elements it carries, then its shape: "불×2 구슬"; a lone element's
## spray goes by its name alone: "불길".
func title() -> String:
	return _title(func(s: String) -> String: return s)


## The title in the language shown, for the player to read and no rule to use.
func shown() -> String:
	return _title(Lang.t)


## The title of one shot of it, for what tells of a single wisp or orb.
func shot_shown() -> String:
	return _title(Lang.t, false)


## The title with every name, form and format string passed through `t`, and how many
## shots a cast makes when `whole`.
func _title(t: Callable, whole := true) -> String:
	if called != "":
		return t.call(called)
	if shape == SPRAY and level() > 0:
		return t.call(Spray.called(self))
	if shape == LEAP:
		var then := rest()
		var leap_title: String = t.call("%s %d칸") % [t.call(SHAPE_NAME[LEAP]), leap()]
		return leap_title + (", " + then._title(t) if then != null else "")
	var parts: Array[String] = []
	var told := {}
	for slot in elements():
		if not told.has(slot):
			told[slot] = true
			var n: int = elements().count(slot) - _named(slot)
			var name: String = t.call(Cards.NAME[slot])
			if n > 0:
				parts.append(name if n == 1 else "%s×%d" % [name, n])
	var form: String = wisp() if shape == WISP else SHAPE_NAME.get(shape, Spray.called(self))
	if pierces():
		form = PIERCE_NAME
	elif mortar():
		form = MORTAR_NAME
	form = t.call(form)
	if whole and shots() > 1:
		form += t.call(" %d발") % shots()
	if swaps():
		form += " " + t.call(Leap.SWAP_NAME)
	return ("·".join(parts) + " " + form).strip_edges()


## The slot and how many of it the name of the shape tells: 탄환, 철갑탄 and 비격진
## are iron by name, every 쇠; 비격진 one 유탄; none for the rest.
func _named(slot: StringName) -> int:
	if slot == Cards.METAL and (bullet() or pierces() or mortar()):
		return count(slot)
	return 1 if mortar() and slot == &"shrapnel" else 0


## What its wisps are called: a wisp with one 쇠 is a bullet.
func wisp() -> String:
	if bullet():
		return BULLET_NAME if wisp_name == "" else BOLT_NAME
	return wisp_name if wisp_name != "" else SHAPE_NAME[WISP]


func cost() -> int:
	return price(cards.size())


## Tails `n` cards cost: COST for up to five, then two more for each card.
static func price(n: int) -> int:
	return 0 if n <= 0 else COST[mini(n, COST.size()) - 1] + COST_EXTRA * maxi(0, n - COST.size())


## Copies of 구 that count, up to the last row of ORB_ACCEL.
func tier() -> int:
	return mini(count(Cards.ORB), ORB_ACCEL.size() - 1)


## Tiles a second the orb gains each round it flies.
func accel() -> int:
	return ORB_ACCEL[tier()]


## Whether the orb has BLAST_TIER copies of 구 or more.
func edged() -> bool:
	return orb and tier() >= BLAST_TIER


## Whether where the orb ends hurts the eight tiles round it: a fire orb, or
## from BLAST_TIER copies of 구.
func blasts() -> bool:
	return edged() or orb and has(Cards.FIRE)


## What each creature round where an orb ends is hurt for, before weakness, when
## its centre is hurt for `centre`: a fire orb's World.FIRE_DAMAGE and a copy
## more, and from BLAST_TIER copies of 구 BLAST_HARM, from HALF_TIER half of
## `centre` rounded up, from FULL_TIER all of it.
func blast(centre: int) -> int:
	var fire := World.FIRE_DAMAGE + extra(Cards.FIRE) if orb and has(Cards.FIRE) else 0
	if not edged():
		return fire
	if tier() >= FULL_TIER:
		return fire + centre
	return fire + (ceili(centre / 2.0) if tier() >= HALF_TIER else BLAST_HARM)


func speed() -> int:
	if orb:
		return mini(ORB_SPEED + count(Cards.ORB) - 1, BULLET_SPEED)
	if Elements.bolt(self):
		return RANGE
	return BULLET_SPEED if gun() else WISP_SPEED


## A gun: a lone 쇠's spray, a bullet or a cannonball, 낙뢰, or a 비격진. Its
## muzzle flash lights the caster's tile for the round it fires (World.flares).
func gun() -> bool:
	if shape == SPRAY:
		return slots[0] == &"thunder" or (level() > 0 and slots[0] == Cards.METAL)
	return shape != LEAP and (has(Cards.METAL) or mortar())


## An armour-piercing wisp (철갑탄): 여 with two 쇠. It goes through every
## creature it hits, and one wall.
func pierces() -> bool:
	return shape == WISP and count(Cards.METAL) >= PIERCE_METALS


## A wisp with one 쇠: a bullet (탄환, and a creature's 번개).
func bullet() -> bool:
	return shape == WISP and has(Cards.METAL) and not pierces()


## A 비격진: an orb that carries 유탄, which bursts where it ends.
func mortar() -> bool:
	return orb and has(&"shrapnel")


## Rounds a projectile lasts in flight; 0 means until it hits something. A
## wisp lasts WISP_LIFE rounds once it hovers or sticks.
func life() -> int:
	return HOMING_LIFE if homing() else 0


## Projectiles one cast hurls: a wisp per 여, TWINS orbs from TWIN_TIER copies
## of 구 (they spread among the creatures in sight: Homing.spread), else one.
func shots() -> int:
	if orb and tier() == TWIN_TIER and not swaps():
		return TWINS
	return count(Cards.FOX) if shape == WISP and not swaps() else 1


## Degrees of turn a projectile banks each tile it flies (Homing.steer): a
## homing orb TURN_STEP for every 여, any way with TURN_FREE of them; a wisp
## WISP_TURN for every 여.
func turn() -> int:
	var foxes := mini(count(Cards.FOX), TURN_FREE)
	if homing():
		return TURN_STEP * foxes
	return WISP_TURN * foxes if shape == WISP else 0


## Copies of an element or a compound past the first: each makes its effect
## one step stronger.
func extra(element: StringName) -> int:
	return maxi(0, count(element) - 1)


## Tiles bigger than its base the compound `c` reaches: one for every copy past
## the first, and one for every lone element that feeds a 상생 pair (a 토 for 유탄).
func grown(c: StringName) -> int:
	return extra(c) + count(Cards.feeder(c))


## Damage on a direct hit by a projectile that has come `distance` tiles from
## its caster: 1 a wisp (none from a lone 여, one tail), Elements.BULLET a
## bullet, an orb 1 for every 구 and 1 more after a run-up, Elements.CANNON
## more a cannonball, and 1 more for every 불 or 쇠 past the first.
func damage(distance: int) -> int:
	var lone := cards.size() - Cards.made_of(Cards.VAULT).size() * count(Cards.VAULT) == 1
	var n := Elements.BULLET if has(Cards.METAL) else (0 if lone else 1)
	if orb:
		n = count(Cards.ORB) + (1 if distance >= MOMENTUM else 0)
		n += Elements.CANNON if has(Cards.METAL) else 0
	return n + extra(Cards.FIRE) + extra(Cards.METAL)


## The light this projectile carries: {radius, color}, or empty for none. A
## bullet carries none; a wisp of 수 darkness, a tile wider for every 수 past
## the first.
func light(faction: int) -> Dictionary:
	if has(Cards.WATER):
		return (
			{}
			if orb
			else {radius = DARK_RADIUS + DARK_PER_WATER * extra(Cards.WATER), color = Light.DARK}
		)
	if gun() and not orb:
		return {}
	var color: Vector3 = Light.FIRE if has(Cards.FIRE) else Light.SIDE[faction]
	if orb:
		return {radius = 2, color = color * 1.3}
	return {radius = 3, color = color}


## How far the cast is heard, and how far the orb's burst against a wall is
## heard. A bullet is heard Spray.GUN_LOUD, a cannonball Elements.CANNON_LOUD.
func cast_noise() -> int:
	if shape == SPRAY:
		return Spray.noise(self)
	if has(Cards.WATER):
		return 0
	if gun():
		return Elements.CANNON_LOUD if orb else Spray.GUN_LOUD
	return 5 if orb else 2


## The word a projectile's cast is heard as.
func cast_word() -> String:
	if Elements.bolt(self):
		return "콰르릉"
	if gun():
		return "쾅" if orb else "탕"
	return "웅" if orb else "휙"


func burst_noise() -> int:
	return 0 if has(Cards.WATER) or not orb else 7
