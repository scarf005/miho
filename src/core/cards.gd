class_name Cards
extends RefCounted
## Spell cards. Two forms come from DCSS (Foxfire, Orb of Destruction); the
## five elements (오행) are taken from strong enemies. A spell costs tails by its
## cards (Spell.COST). Two different elements in one spell make one of ten
## compounds (상생 and 상극 pairs), which takes one slot and counts two cards.
## A pair and a third element make the 3단 compound of those three (TRIPLES), one
## slot worth three cards: 수+목+화 make 도약, which leaps Miho herself (Leap).
## A 3단 and a fourth element make the 4단 of its ring (QUADS), and a 4단 and the
## last element a 5단 (FIVES), up to the tier that forms now (TIER). 도약 takes a
## fourth element only as the last slot (Spell.queue).

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
	&"molten": [FIRE, METAL],
	&"thorn": [METAL, WOOD],
	&"rift": [WOOD, EARTH],
	&"mud": [EARTH, WATER],
}
## 3단 compound -> its three elements, in the order of their ring.
const TRIPLES := {
	&"volcano": [WOOD, FIRE, EARTH],
	&"furnace": [FIRE, EARTH, METAL],
	&"hail": [EARTH, METAL, WATER],
	&"frostbloom": [METAL, WATER, WOOD],
	VAULT: [WATER, WOOD, FIRE],
	&"swamp": [WOOD, EARTH, WATER],
	&"geyser": [EARTH, WATER, FIRE],
	&"hypnosis": [WATER, FIRE, METAL],
	&"talon": [FIRE, METAL, WOOD],
	&"palisade": [METAL, WOOD, EARTH],
}
## 4단 compound -> its four elements, in the order of their ring.
const QUADS := {
	&"beacon": [WOOD, FIRE, EARTH, METAL],
	&"cloak": [FIRE, EARTH, METAL, WATER],
	&"bind": [EARTH, METAL, WATER, WOOD],
	&"magpie": [METAL, WATER, WOOD, FIRE],
	&"mist": [WATER, WOOD, FIRE, EARTH],
	&"sinkhole": [WOOD, EARTH, WATER, FIRE],
	&"newmoon": [EARTH, WATER, FIRE, METAL],
	&"discord": [WATER, FIRE, METAL, WOOD],
	&"thunder": [FIRE, METAL, WOOD, EARTH],
	&"stillness": [METAL, WOOD, EARTH, WATER],
}
## 5단 compound -> the five elements in an order that makes it (`join`).
const FIVES := {
	SAMSARA: [EARTH, METAL, WATER, WOOD, FIRE],
	CONQUEST: [WOOD, EARTH, WATER, FIRE, METAL],
	DRAGON: [METAL, WATER, WOOD, FIRE, EARTH],
}

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
	&"molten": "쇳물",
	&"thorn": "가시",
	&"rift": "균열",
	&"mud": "진흙",
	&"volcano": "화산",
	&"furnace": "용광로",
	&"hail": "우박",
	&"frostbloom": "서리꽃",
	VAULT: "도약",
	&"swamp": "늪",
	&"geyser": "간헐천",
	&"hypnosis": "최면",
	&"talon": "쇠발톱",
	&"palisade": "목책",
	&"beacon": "봉화",
	&"cloak": "은신",
	&"bind": "속박",
	&"magpie": "오작교",
	&"mist": "안개비",
	&"sinkhole": "땅꺼짐",
	&"newmoon": "그믐",
	&"discord": "이간질",
	&"thunder": "벼락",
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
	&"molten": "쇳",
	&"thorn": "가",
	&"rift": "균",
	&"mud": "진",
	&"volcano": "산",
	&"furnace": "광",
	&"hail": "박",
	&"frostbloom": "꽃",
	VAULT: "약",
	&"swamp": "늪",
	&"geyser": "천",
	&"hypnosis": "최",
	&"talon": "발",
	&"palisade": "책",
	&"beacon": "봉",
	&"cloak": "은",
	&"bind": "속",
	&"magpie": "작",
	&"mist": "안",
	&"sinkhole": "꺼",
	&"newmoon": "믐",
	&"discord": "이",
	&"thunder": "벼",
	&"stillness": "고",
	SAMSARA: "윤",
	CONQUEST: "극",
	DRAGON: "룡",
}


## Every compound, pairs first, then by tier.
static func compounds() -> Array:
	return PAIRS.keys() + TRIPLES.keys() + QUADS.keys() + FIVES.keys()


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
	return PAIRS.get(slot, TRIPLES.get(slot, QUADS.get(slot, FIVES.get(slot, [slot]))))


## The elements a slot holds: itself or a compound's, none for a form or 도약,
## which leaps and carries nothing.
static func parts(slot: StringName) -> Array:
	return [] if slot == VAULT or FORMS.has(slot) else made_of(slot)
