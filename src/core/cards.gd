class_name Cards
extends RefCounted
## Spell cards. Two forms come from DCSS (Foxfire, Orb of Destruction); the
## five elements (오행) are taken from strong enemies. A spell costs tails by its
## cards (Spell.COST). Two different elements in one spell make one of ten
## compounds (상생 and 상극 pairs), which takes one slot and counts two cards.
## Three elements in a 상생 chain (목, 화, 토, 금, 수, 목) make a 3단 compound
## (TRIPLES), one slot worth three cards: 수+목+화 make 도약, which leaps Miho
## herself (Leap).

const FOX := &"fox"
const ORB := &"orb"
const FIRE := &"fire"
const WATER := &"water"
const WOOD := &"wood"
const METAL := &"metal"
const EARTH := &"earth"
const VAULT := &"vault"

const ALL: Array[StringName] = [FOX, ORB, FIRE, WATER, WOOD, METAL, EARTH]
const FORMS: Array[StringName] = [FOX, ORB]
const ELEMENTS: Array[StringName] = [FIRE, WATER, WOOD, METAL, EARTH]

## 상극: each element beats the one it maps to (wood beats earth, ...).
const BEATS := {WOOD: EARTH, EARTH: WATER, WATER: FIRE, FIRE: METAL, METAL: WOOD}

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
	&"split": [WOOD, EARTH],
	&"mud": [EARTH, WATER],
}
## 3단 compound -> its three elements, in 상생 order (수생목, 목생화).
const TRIPLES := {VAULT: [WATER, WOOD, FIRE]}

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
	&"split": "벽 가르기",
	&"mud": "진흙",
	VAULT: "도약",
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
	&"split": "벽",
	&"mud": "진",
	VAULT: "약",
}


## The compound two different elements make.
static func pair(a: StringName, b: StringName) -> StringName:
	for c in PAIRS:
		if PAIRS[c].has(a) and PAIRS[c].has(b):
			return c
	return &""


## The compound element `c` makes with `slot`: their pair when the slot is a
## different element, the 3단 compound when the slot is a compound of two
## other elements of its chain; else empty.
static func join(slot: StringName, c: StringName) -> StringName:
	if ELEMENTS.has(slot):
		return pair(slot, c) if slot != c else &""
	for t in TRIPLES:
		var rest: Array = TRIPLES[t].filter(func(e): return e != c)
		if rest.size() == 2 and pair(rest[0], rest[1]) == slot:
			return t
	return &""


## The cards a slot is worth: a compound's elements, else the slot itself.
static func made_of(slot: StringName) -> Array:
	return PAIRS.get(slot, TRIPLES.get(slot, [slot]))


## The elements a slot holds: itself, a compound's two, or none for a form.
static func parts(slot: StringName) -> Array:
	if PAIRS.has(slot):
		return PAIRS[slot]
	return [slot] if ELEMENTS.has(slot) else []
