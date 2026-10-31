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
## iood_damage); 여 alone a wisp for every 여, each hitting for 1. Homing
## projectiles chase a creature (Homing); a wisp with none flies up to RANGE
## tiles, then hovers and lights its surroundings. Elements alone spray: they
## cover their tiles in the round they are cast, with no projectile (Spray).
## Each element has one meaning on any form, one step stronger for every copy:
## 불 burns (a wisp hits for 1, an orb splashes), 물 is darkness and silence,
## 나무 roots, 쇠 flashes and blinds, 흙 thuds loudly and stuns.

const MAX_SLOTS := 5
const MOMENTUM := 4
const WISP_SPEED := 3
const ORB_SPEED := 2
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


## Copies of a talisman in the spell; a compound holds one of each of its elements.
func count(card: StringName) -> int:
	var n := 0
	for slot in slots:
		if slot == card or Cards.parts(slot).has(card):
			n += 1
	return n


func has(card: StringName) -> bool:
	return count(card) > 0


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
	return ORB_SPEED if orb else WISP_SPEED


## Rounds a projectile lasts in flight; 0 means until it hits something. A
## wisp lasts WISP_LIFE rounds once it hovers.
func life() -> int:
	return HOMING_LIFE if homing() else 0


## Projectiles one cast hurls: a wisp per 여, else one.
func shots() -> int:
	return count(Cards.FOX) if shape == WISP else 1


## How far a projectile may turn each tile, in steps of 45°; TURN_FREE turns
## any way. A homing orb turns 45° more for every 여, a wisp turns freely.
func turn() -> int:
	if shape == WISP:
		return TURN_FREE
	return mini(count(Cards.FOX), TURN_FREE) if homing() else 0


## Copies of an element past the first: each makes its effect one step stronger.
func extra(element: StringName) -> int:
	return maxi(0, count(element) - 1)


## Damage on a direct hit by a projectile that has come `distance` tiles from
## its caster: 1 a wisp, an orb 1 for every 구 and 1 more after a run-up, and
## 1 more for every 불 past the first.
func damage(distance: int) -> int:
	var n := 1
	if orb:
		n = count(Cards.ORB) + (1 if distance >= MOMENTUM else 0)
	return n + extra(Cards.FIRE)


## The light this projectile carries: {radius, color}, or empty for none.
func light(faction: int) -> Dictionary:
	if has(Cards.WATER):
		return {} if orb else {radius = 3, color = Light.DARK}
	var color: Vector3 = Light.FIRE if has(Cards.FIRE) else Light.SIDE[faction]
	if orb:
		return {radius = 2, color = color * 1.3}
	return {radius = 3, color = color}


## How far the cast is heard, and how far the orb's burst against a wall is heard.
func cast_noise() -> int:
	if shape == SPRAY:
		return Spray.noise(self)
	if has(Cards.WATER):
		return 0
	return 5 if orb else 2


func burst_noise() -> int:
	return 0 if has(Cards.WATER) or not orb else 7
