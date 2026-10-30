class_name Cards
extends RefCounted
## Spell cards. Two forms come from DCSS (Foxfire, Orb of Destruction);
## the five elements (오행) are taken from strong enemies. Each card in a
## spell costs one tail, so a fox with N tails can stack up to N cards.

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

const NAME := {
	FOX: "여우불",
	ORB: "구슬",
	FIRE: "불",
	WATER: "물",
	WOOD: "나무",
	METAL: "쇠",
	EARTH: "흙",
}
const GLYPH := {
	FOX: "여",
	ORB: "구",
	FIRE: "화",
	WATER: "수",
	WOOD: "목",
	METAL: "금",
	EARTH: "토",
}
