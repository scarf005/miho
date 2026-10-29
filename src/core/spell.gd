class_name Spell
extends RefCounted
## A spell is a set of one to four distinct cards with at least one form; it
## costs one tail per card.
## 여우불 alone: two fast seeking wisps. 구슬 alone: a straight orb that hits
## harder after a run-up. Both: one homing orb. Each element adds an on-hit effect.
## Ratios follow DCSS: foxfire outruns the orb, and an orb is weaker within
## four tiles of its caster (crawl mon-project.cc iood_damage).

const MAX_CARDS := 4
const MOMENTUM := 4
const SEEK_SPEED := 3
const ORB_SPEED := 2
const SEEK_LIFE := 3
const HOMING_LIFE := 4

const NAMED := {
	"fox+fire": "화염구",
	"fox+water": "물보라",
	"fox+wood": "덩굴불",
	"fox+metal": "쇠바늘",
	"fox+earth": "흙먼지",
	"fox+orb": "여우구슬",
}

var cards: Array[StringName] = []
var seek := false
var line := false


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
	spell.seek = cards.has(Cards.FOX)
	spell.line = cards.has(Cards.ORB)
	return spell


func has(card: StringName) -> bool:
	return cards.has(card)


func homing() -> bool:
	return seek and line


func elements() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(cards.filter(func(c): return Cards.ELEMENTS.has(c)))
	return out


func key() -> String:
	return "+".join(cards)


func form_name() -> String:
	if homing():
		return "여우구슬"
	return Cards.NAME[Cards.FOX] if seek else Cards.NAME[Cards.ORB]


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


func count() -> int:
	return 1 if line else 2


func speed() -> int:
	return ORB_SPEED if line else SEEK_SPEED


## Rounds a projectile lasts before fading; 0 means until it hits something.
func life() -> int:
	if homing():
		return HOMING_LIFE
	return SEEK_LIFE if seek else 0


## Damage on a direct hit by a projectile that has come `distance` tiles from its caster.
func damage(distance: int) -> int:
	return 2 if line and distance >= MOMENTUM else 1
