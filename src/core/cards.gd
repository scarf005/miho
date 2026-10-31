class_name Cards
extends RefCounted
## Spell cards. Two forms come from DCSS (Foxfire, Orb of Destruction);
## the five elements (오행) are taken from strong enemies. Each card in a
## spell costs one tail. Two different elements in one spell make one of ten
## compounds (상생 and 상극 pairs), which takes one slot and costs two tails.

const FOX := &"fox"
const ORB := &"orb"
const FIRE := &"fire"
const WATER := &"water"
const WOOD := &"wood"
const METAL := &"metal"
const EARTH := &"earth"

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
}


## The compound two different elements make.
static func pair(a: StringName, b: StringName) -> StringName:
	for c in PAIRS:
		if PAIRS[c].has(a) and PAIRS[c].has(b):
			return c
	return &""


## The elements a slot holds: itself, a compound's two, or none for a form.
static func parts(slot: StringName) -> Array:
	if PAIRS.has(slot):
		return PAIRS[slot]
	return [slot] if ELEMENTS.has(slot) else []
