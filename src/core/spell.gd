class_name Spell
extends RefCounted
## A spell is a set of one to four distinct cards with at least one form; it
## costs one tail per card. Every spell is hurled along one of eight lines.
## 여우불 alone: a harmless wisp that flies up to RANGE tiles, then hovers and
## lights its surroundings. 구슬 alone: a loud straight orb that hits harder
## after a run-up (DCSS mon-project.cc iood_damage). Both: a homing orb.
## Each element has one meaning on any form:
## 불 burns (a wisp hits for 1, an orb splashes), 물 is darkness and silence,
## 나무 roots, 쇠 flashes and blinds, 흙 thuds loudly and stuns.

const MAX_CARDS := 4
const MOMENTUM := 4
const WISP_SPEED := 3
const ORB_SPEED := 2
const RANGE := 7
const WISP_LIFE := 8
const HOMING_LIFE := 6

const NAMED := {
	"fox+fire": "화염구",
	"fox+water": "먹안개",
	"fox+wood": "덩굴불",
	"fox+metal": "섬광",
	"fox+earth": "땅울림",
	"fox+orb": "여우구슬",
	"orb+water": "먹구슬",
}

var cards: Array[StringName] = []
var wisp := false
var orb := false


static func make(picked: Array) -> Spell:
	var cards: Array[StringName] = []
	for c in Cards.ALL:
		if picked.has(c):
			cards.append(c)
	if cards.is_empty() or cards.size() != picked.size() or cards.size() > MAX_CARDS:
		return null
	if not (cards.has(Cards.FOX) or cards.has(Cards.ORB)):
		return null
	var spell := Spell.new()
	spell.cards = cards
	spell.wisp = cards.has(Cards.FOX)
	spell.orb = cards.has(Cards.ORB)
	return spell


func has(card: StringName) -> bool:
	return cards.has(card)


func homing() -> bool:
	return wisp and orb


## A wisp alone stops short of creatures; anything else strikes them.
func strikes() -> bool:
	return orb or has(Cards.FIRE) or has(Cards.WOOD) or has(Cards.EARTH)


func elements() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(cards.filter(func(c): return Cards.ELEMENTS.has(c)))
	return out


func key() -> String:
	return "+".join(cards)


func form_name() -> String:
	if homing():
		return "여우구슬"
	return Cards.NAME[Cards.ORB] if orb else Cards.NAME[Cards.FOX]


func title() -> String:
	if NAMED.has(key()):
		return NAMED[key()]
	var parts := elements().map(func(c): return Cards.NAME[c])
	if parts.is_empty():
		return form_name()
	if parts.size() == 1:
		return parts[0] + form_name()
	return "·".join(parts) + " " + form_name()


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
