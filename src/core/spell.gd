class_name Spell
extends RefCounted
## A spell is a queue of up to MAX_SLOTS talisman slots, filled card by card.
## A card of the same talisman again stacks; an element added while a
## different element is queued merges with the first such slot into their
## compound (Cards.PAIRS), one slot worth two cards. Every card costs one tail.
## Every spell is hurled along one of eight lines.
## 여우불 alone: a wisp that flies up to RANGE tiles, then hovers and lights
## its surroundings. 구슬 alone: a loud straight orb that hits harder after a
## run-up (DCSS mon-project.cc iood_damage). Both: a homing orb.
## Each element has one meaning on any form:
## 불 burns (a wisp hits for 1, an orb splashes), 물 is darkness and silence,
## 나무 roots, 쇠 flashes and blinds, 흙 thuds loudly and stuns.

const MAX_SLOTS := 5
const MOMENTUM := 4
const WISP_SPEED := 3
const ORB_SPEED := 2
const RANGE := 7
const WISP_LIFE := 8
const HOMING_LIFE := 6

const HOMING := &"homing"
const ORB := &"orb"
const WISP := &"wisp"
const SHAPE_NAME := {HOMING: "유도 구슬", ORB: "구슬", WISP: "여우불"}

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


## The shape the slots make, read top down: a homing orb, an orb, foxfire.
static func _shape(s: Spell) -> StringName:
	if s.count(Cards.FOX) > 0 and s.count(Cards.ORB) > 0:
		return HOMING
	if s.count(Cards.ORB) > 0:
		return ORB
	return WISP if s.count(Cards.FOX) > 0 else &""


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
	var form: String = SHAPE_NAME.get(shape, "")
	if shape == WISP and count(Cards.FOX) > 1:
		form += " %d발" % count(Cards.FOX)
	return form if parts.is_empty() else "·".join(parts) + " " + form


func cost() -> int:
	return cards.size()


func speed() -> int:
	return ORB_SPEED if orb else WISP_SPEED


## Rounds a projectile lasts; 0 means until it hits something.
func life() -> int:
	if homing():
		return HOMING_LIFE
	return 0 if orb else WISP_LIFE


## Damage on a direct hit by a projectile that has come `distance` tiles from its caster.
func damage(distance: int) -> int:
	if orb:
		return 2 if distance >= MOMENTUM else 1
	return 1 if has(Cards.FIRE) else 0


## A wisp alone stops short of creatures; anything else strikes them.
func strikes() -> bool:
	return orb or has(Cards.FIRE) or has(Cards.WOOD) or has(Cards.EARTH)


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
	if has(Cards.WATER):
		return 0
	return 5 if orb else 2


func burst_noise() -> int:
	return 0 if has(Cards.WATER) or not orb else 7
