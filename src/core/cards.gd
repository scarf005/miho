class_name Cards
extends RefCounted
## Spell cards. Two forms come from DCSS (Foxfire, Orb of Destruction); the
## five elements (오행) are taken from strong enemies. A spell costs tails by its
## cards (Spell.COST). Two different elements in one spell make one of nine
## compounds (상생 and 상극 pairs, but 화 and 금 make none), which takes one slot
## and counts two cards. A pair and a third element make the 3단 compound of
## those three, if there is one (TRIPLES), one slot worth three cards: 수+목+화
## make 도약, which leaps Miho herself (Leap). A 3단 and a fourth element make
## the 4단 of its ring, if there is one (QUADS), and a 4단 and the last element a
## 5단 (FIVES), up to the tier that forms now (TIER). 도약 takes a fourth element
## only as the last slot (Spell.queue). Cards queue into a compound in some
## orders only (`recipe`). 분신 and 사령술 (SETS) are made of exactly their cards in any order.
## What a spell meets in a creature is its elements (Spell.nature): a lone
## element is itself, a pair is both of its elements, a 3단 or more is what
## NATURE says, and 최면, 도약, 분신, 사령술, 은신, 오작교, 그믐, 이간질, 고요 and 윤회 have
## none. 낙뢰 is no element but ELECTRIC.

const FOX := &"fox"
const ORB := &"orb"
const FIRE := &"fire"
const WATER := &"water"
const WOOD := &"wood"
const METAL := &"metal"
const EARTH := &"earth"
const VAULT := &"vault"
const SAMSARA := &"samsara"
const CONQUEST := &"conquest"
const DRAGON := &"dragon"
const BUNSIN := &"bunsin"
const RAISE := &"raise"

const ALL: Array[StringName] = [FOX, ORB, FIRE, WATER, WOOD, METAL, EARTH]
const FORMS: Array[StringName] = [FOX, ORB]
const ELEMENTS: Array[StringName] = [FIRE, WATER, WOOD, METAL, EARTH]

## 상생: each element grows the one it maps to (wood grows fire, ...).
const GROWS := {WOOD: FIRE, FIRE: EARTH, EARTH: METAL, METAL: WATER, WATER: WOOD}
## 상극: each element beats the one it maps to (wood beats earth, ...).
const BEATS := {WOOD: EARTH, EARTH: WATER, WATER: FIRE, FIRE: METAL, METAL: WOOD}

## The most elements a compound joins: the 5단 holds all five.
const TIER := 5
## The elements a 3단 compound (TRIPLES) joins.
const TRIPLE := 3

## compound -> the two elements it is made of.
const PAIRS := {
	&"wildfire": [WOOD, FIRE],
	&"lava": [FIRE, EARTH],
	&"shrapnel": [EARTH, METAL],
	&"frost": [METAL, WATER],
	&"rain": [WATER, WOOD],
	&"steam": [WATER, FIRE],
	&"thorn": [METAL, WOOD],
	&"rift": [WOOD, EARTH],
	&"mud": [EARTH, WATER],
}
## 3단 compound -> its three elements, in the order of their ring.
const TRIPLES := {
	&"furnace": [FIRE, EARTH, METAL],
	VAULT: [WATER, WOOD, FIRE],
	&"swamp": [WOOD, EARTH, WATER],
	&"hypnosis": [WATER, FIRE, METAL],
	&"talon": [FIRE, METAL, WOOD],
	&"palisade": [METAL, WOOD, EARTH],
}
## 4단 compound -> its four elements, in the order of their ring.
const QUADS := {
	&"beacon": [WOOD, FIRE, EARTH, METAL],
	&"magpie": [METAL, WATER, WOOD, FIRE],
	&"mist": [WATER, WOOD, FIRE, EARTH],
	&"sinkhole": [WOOD, EARTH, WATER, FIRE],
	&"newmoon": [EARTH, WATER, FIRE, METAL],
	&"discord": [WATER, FIRE, METAL, WOOD],
	&"thunder": [FIRE, METAL, WOOD, EARTH],
	&"stillness": [METAL, WOOD, EARTH, WATER],
}
## Compound -> its cards, made in any order: each holds 여 and no ring of elements.
const SETS := {
	BUNSIN: [FOX, EARTH, FIRE, WOOD],
	RAISE: [FOX, EARTH, METAL, WATER, WOOD],
}
## 5단 compound -> its five elements; `recipe` finds an order of them that makes it.
const FIVES := {
	SAMSARA: [EARTH, METAL, WATER, WOOD, FIRE],
	CONQUEST: [WOOD, EARTH, WATER, FIRE, METAL],
	DRAGON: [METAL, WATER, WOOD, FIRE, EARTH],
}

## 3단 or more compound -> the elements it counts as against a creature's
## weakness and absorption, in 오행 order; one that is not here has none.
const NATURE := {
	&"furnace": [FIRE, METAL],
	&"swamp": [WATER, EARTH],
	&"talon": [METAL],
	&"palisade": [WOOD],
	&"beacon": [FIRE],
	&"mist": [WATER],
	&"sinkhole": [EARTH],
	DRAGON: [EARTH],
	CONQUEST: ELEMENTS,
}
## The compounds of 전기, a kind outside the five elements (Elements.charge).
const ELECTRIC: Array[StringName] = [&"thunder"]

const NAME := {
	FOX: "여우불",
	ORB: "구슬",
	FIRE: "불",
	WATER: "물",
	WOOD: "나무",
	METAL: "쇠",
	EARTH: "흙",
	&"wildfire": "들불",
	&"lava": "용암",
	&"shrapnel": "유탄",
	&"frost": "서리",
	&"rain": "단비",
	&"steam": "증기",
	&"thorn": "가시",
	&"rift": "균열",
	&"mud": "진흙",
	&"furnace": "용광로",
	VAULT: "도약",
	&"swamp": "늪",
	&"hypnosis": "최면",
	&"talon": "쇠발톱",
	&"palisade": "목책",
	BUNSIN: "분신",
	RAISE: "사령술",
	&"beacon": "봉화",
	&"magpie": "오작교",
	&"mist": "안개비",
	&"sinkhole": "땅꺼짐",
	&"newmoon": "그믐",
	&"discord": "이간질",
	&"thunder": "낙뢰",
	&"stillness": "고요",
	SAMSARA: "윤회",
	CONQUEST: "상극",
	DRAGON: "황룡",
}
const GLYPH := {
	FOX: "여",
	ORB: "구",
	FIRE: "화",
	WATER: "수",
	WOOD: "목",
	METAL: "금",
	EARTH: "토",
	&"wildfire": "들",
	&"lava": "용",
	&"shrapnel": "유",
	&"frost": "서",
	&"rain": "단",
	&"steam": "증",
	&"thorn": "가",
	&"rift": "균",
	&"mud": "진",
	&"furnace": "광",
	VAULT: "약",
	&"swamp": "늪",
	&"hypnosis": "최",
	&"talon": "발",
	&"palisade": "책",
	BUNSIN: "분",
	RAISE: "령",
	&"beacon": "봉",
	&"magpie": "작",
	&"mist": "안",
	&"sinkhole": "꺼",
	&"newmoon": "믐",
	&"discord": "이",
	&"thunder": "낙",
	&"stillness": "고",
	SAMSARA: "윤",
	CONQUEST: "극",
	DRAGON: "룡",
}

## compound -> the order of its cards that queues into it (`recipe`), once found.
static var _recipes := {}


## Every compound, pairs first, then by tier.
static func compounds() -> Array:
	return PAIRS.keys() + TRIPLES.keys() + QUADS.keys() + SETS.keys() + FIVES.keys()


## The compound two different elements make.
static func pair(a: StringName, b: StringName) -> StringName:
	for c in PAIRS:
		if PAIRS[c].has(a) and PAIRS[c].has(b):
			return c
	return &""


## The element that feeds the 상생 pair `c` (the one that grows the other), or
## none: a 토 feeds 유탄.
static func feeder(c: StringName) -> StringName:
	var made: Array = PAIRS.get(c, [])
	return made[0] if not made.is_empty() and GROWS[made[0]] == made[1] else &""


## The compound element `c` makes with `slot`, up to `tier` elements: their pair
## when the slot is a different element; the 3단 of the three when it is a pair;
## the 4단 of its ring when it is a 3단; when it is a 4단, 황룡 for a last 토, else
## the 5단 of its ring; else empty.
static func join(slot: StringName, c: StringName, tier := TIER) -> StringName:
	if ELEMENTS.has(slot):
		return pair(slot, c) if slot != c else &""
	if SETS.has(slot):
		return &""
	var made := made_of(slot)
	if made.size() < 2 or made.size() >= tier or made.has(c):
		return &""
	match made.size():
		2:
			return _chain(TRIPLES, made + [c])
		3:
			return _chain(QUADS, made + [c], made)
	if c == EARTH:
		return DRAGON
	return SAMSARA if _grows(made) else CONQUEST


## The compound of `table` of just `elements`, of the same ring as `like` if given.
static func _chain(table: Dictionary, elements: Array, like := []) -> StringName:
	for c in table:
		if (
			elements.all(func(e): return table[c].has(e))
			and (like.is_empty() or _grows(table[c]) == _grows(like))
		):
			return c
	return &""


## Whether a chain runs along 상생, else along 상극.
static func _grows(chain: Array) -> bool:
	return GROWS[chain[0]] == chain[1]


## The cards a slot is worth: a compound's elements, else the slot itself.
static func made_of(slot: StringName) -> Array:
	return PAIRS.get(
		slot, TRIPLES.get(slot, QUADS.get(slot, SETS.get(slot, FIVES.get(slot, [slot]))))
	)


## The compound that exactly the cards `picked` make, in any order, else empty.
static func set_of(picked: Array) -> StringName:
	for c in SETS:
		var made: Array = SETS[c]
		if (
			picked.size() == made.size()
			and made.all(func(e): return picked.count(e) == made.count(e))
		):
			return c
	return &""


## The cards of `slot` in the first order that queues into that one slot (the
## table's order, unless a pair without a compound is in the way): what to cast
## or to show for it.
static func recipe(slot: StringName) -> Array:
	if not _recipes.has(slot):
		_recipes[slot] = _order(slot, made_of(slot), [])
	return _recipes[slot]


## The first order of `rest` after `head` that queues into `slot` alone.
static func _order(slot: StringName, rest: Array, head: Array) -> Array:
	if rest.is_empty():
		var made := Spell.fill(head)
		return head if made.size() == 1 and made[0] == slot else []
	for i in rest.size():
		var left := rest.duplicate()
		left.remove_at(i)
		var found := _order(slot, left, head + [rest[i]])
		if not found.is_empty():
			return found
	return []


## The elements a slot holds: itself or a compound's, none for a form or 도약,
## which leaps and carries nothing.
static func parts(slot: StringName) -> Array:
	return [] if slot == VAULT or FORMS.has(slot) else made_of(slot).filter(ELEMENTS.has)


## The elements a slot counts as against a creature: itself, a pair's two, a
## 3단 or more by NATURE; none for the rest.
static func nature(slot: StringName) -> Array:
	return [slot] if ELEMENTS.has(slot) else PAIRS.get(slot, NATURE.get(slot, []))
