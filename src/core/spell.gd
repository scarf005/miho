class_name Spell
extends RefCounted
## A spell is a queue of up to MAX_SLOTS talisman slots, filled card by card.
## A card of the same talisman again stacks; an element added while a
## different element is queued merges with the first such slot into their
## compound (Cards.PAIRS), one slot worth two cards. Every card costs one tail.
## Every spell is hurled along one of eight lines, and grows with the tails it
## costs: one card is power 1.
## The shape is read top down: 여 and 구 make a homing orb that turns 45° more
## each tile for every 여 (freely with four); 구 alone a loud straight orb, 1
## damage for every 구 and 1 more after a run-up (DCSS mon-project.cc
## iood_damage); 여 alone a wisp for every 여, each hitting for 1 (a lone 여
## for none), turning like a homing orb. Homing
## projectiles chase a creature (Homing); a wisp with none flies up to RANGE
## tiles, then hovers and lights its surroundings. A wisp that strikes a
## creature that does not eat it sticks to it for WISP_LIFE rounds and lights
## it wherever it goes (Elements.stick); a bullet does not stick. Elements alone spray: they
## cover their tiles in the round they are cast, with no projectile (Spray).
## Each element shows its nature by the form it rides, one step stronger for
## every copy (Elements): 쇠 makes a wisp a bullet and an orb a cannonball.
## A compound is an element of its own (Compounds): it does not count as its
## two elements, but for what a creature is weak to or eats (`holds`).

const MAX_SLOTS := 5
const MOMENTUM := 4
const WISP_SPEED := 3
const ORB_SPEED := 2
## A bullet: a wisp with 쇠. The fastest projectile.
const BULLET_SPEED := 5
const RANGE := 7
const WISP_LIFE := 8
const HOMING_LIFE := 6
const TURN_FREE := 4

const HOMING := &"homing"
const ORB := &"orb"
const WISP := &"wisp"
const SPRAY := &"spray"
const SHAPE_NAME := {HOMING: "유도 구슬", ORB: "구슬", WISP: "여우불"}
## Copies past which an element's spray grows no more.
const MAX_LEVEL := 3

## The cards as they were queued, repeats and all; the slots they fill.
var cards: Array[StringName] = []
var slots: Array[StringName] = []
var shape := &""
## The spell is an orb: straight or homing.
var orb := false
## A name a creature gives its own spell (Bestiary.spell), in place of title().
var called := ""


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
	return spell


## The slots the talismans `picked` fill, in order.
static func fill(picked: Array) -> Array[StringName]:
	var slots: Array[StringName] = []
	for c in picked:
		slots = queue(slots, c)
	return slots


## The slots after card `c` joins them: an element merges with the first
## different element; anything else goes at the end.
static func queue(slots: Array[StringName], c: StringName) -> Array[StringName]:
	var out := slots.duplicate()
	if Cards.ELEMENTS.has(c):
		for i in out.size():
			if Cards.ELEMENTS.has(out[i]) and out[i] != c:
				out[i] = Cards.pair(out[i], c)
				return out
	out.append(c)
	return out


## The shape the slots make, read top down: a homing orb, an orb, foxfire, a spray.
static func _shape(s: Spell) -> StringName:
	if s.count(Cards.FOX) > 0 and s.count(Cards.ORB) > 0:
		return HOMING
	if s.count(Cards.ORB) > 0:
		return ORB
	if s.count(Cards.FOX) > 0:
		return WISP
	return SPRAY if not s.slots.is_empty() else &""


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


## The compound slots, each once, in queue order.
func compounds() -> Array[StringName]:
	var out: Array[StringName] = []
	for slot in slots:
		if Cards.PAIRS.has(slot) and not out.has(slot):
			out.append(slot)
	return out


func homing() -> bool:
	return shape == HOMING


## The element slots, compounds among them, in queue order.
func elements() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(slots.filter(func(c): return not Cards.FORMS.has(c)))
	return out


func key() -> String:
	return "+".join(cards)


## The spell a key() names, or null.
static func from_key(k: String) -> Spell:
	return make(Array(k.split("+")).map(func(c): return StringName(c)))


## The elements it carries, then its shape: "불×2 구슬".
func title() -> String:
	if called != "":
		return called
	var parts: Array[String] = []
	var told := {}
	for slot in elements():
		if not told.has(slot):
			told[slot] = true
			var n := elements().count(slot)
			parts.append(Cards.NAME[slot] if n == 1 else "%s×%d" % [Cards.NAME[slot], n])
	var form: String = SHAPE_NAME.get(shape, Spray.called(self))
	if shape == WISP and count(Cards.FOX) > 1:
		form += " %d발" % count(Cards.FOX)
	return ("·".join(parts) + " " + form).strip_edges()


func cost() -> int:
	return cards.size()


func speed() -> int:
	if orb:
		return ORB_SPEED
	return BULLET_SPEED if gun() else WISP_SPEED


## A gun: a lone 쇠's spray, a bullet or a cannonball. Its muzzle flash lights
## the caster's tile for the round it fires (World.flares).
func gun() -> bool:
	if shape == SPRAY:
		return level() > 0 and slots[0] == Cards.METAL
	return has(Cards.METAL)


## Rounds a projectile lasts in flight; 0 means until it hits something. A
## wisp lasts WISP_LIFE rounds once it hovers or sticks.
func life() -> int:
	return HOMING_LIFE if homing() else 0


## Projectiles one cast hurls: a wisp per 여, else one.
func shots() -> int:
	return count(Cards.FOX) if shape == WISP else 1


## How far a projectile may turn each tile, in steps of 45°; TURN_FREE turns
## any way. A wisp or a homing orb turns 45° for every 여.
func turn() -> int:
	return mini(count(Cards.FOX), TURN_FREE) if shape == WISP or homing() else 0


## Copies of an element or a compound past the first: each makes its effect
## one step stronger.
func extra(element: StringName) -> int:
	return maxi(0, count(element) - 1)


## Damage on a direct hit by a projectile that has come `distance` tiles from
## its caster: 1 a wisp (none from a lone 여, one tail), Elements.BULLET a
## bullet, an orb 1 for every 구 and 1 more after a run-up, Elements.CANNON
## more a cannonball, and 1 more for every 불 or 쇠 past the first.
func damage(distance: int) -> int:
	var n := Elements.BULLET if has(Cards.METAL) else (0 if cost() == 1 else 1)
	if orb:
		n = count(Cards.ORB) + (1 if distance >= MOMENTUM else 0)
		n += Elements.CANNON if has(Cards.METAL) else 0
	return n + extra(Cards.FIRE) + extra(Cards.METAL)


## The light this projectile carries: {radius, color}, or empty for none. A
## bullet carries none.
func light(faction: int) -> Dictionary:
	if has(Cards.WATER):
		return {} if orb else {radius = 3, color = Light.DARK}
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
	if gun():
		return "쾅" if orb else "탕"
	return "웅" if orb else "휙"


func burst_noise() -> int:
	return 0 if has(Cards.WATER) or not orb else 7
