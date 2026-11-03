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
## its `nature` says, and 용광로, 봉화, 최면, 도약, 분신, 사령술, 은신, 오작교, 그믐, 이간질, 고요 and 윤회 have
## none. 낙뢰 is no element but `electric`.

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

## What each talisman and compound is called: a const, for what other consts fill with it
## (GameTools.SPELLS).
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
## How a talisman's slot shows; a compound's is its row's `glyph`.
const TALISMAN_GLYPH := {
	FOX: "여",
	ORB: "구",
	FIRE: "화",
	WATER: "수",
	WOOD: "목",
	METAL: "금",
	EARTH: "토",
}

## One row per compound: the pairs, the 3단 and the 4단, the sets, the 5단. A column
## after `sound` that a row leaves out does not hold for it.
##
## glyph: how its slot shows.
## made: its elements in the order of their ring (a 5단's `recipe` finds an order of
## them that makes it); a set, which holds 여 and no ring, its cards, made in any order.
## shape: [shape, size, more] (Spray.cover): a fan's radius, a line's length, how far ahead
## a cleave looks for a wall, a radius round the caster; for a burst how far ahead it
## lands and its radius, for tiles across the line how far ahead they lie and how many.
## 쇠발톱 and 사령술 go on Miho (Guise) and 분신 next to her (Bunsin): none is ever
## sprayed, and a projectile that carries it does nothing with it. 도약 has none.
## sound: its spray, and what a projectile carries on top of its own (Sfx).
## told: what it does where it reaches, for the hover (SpellInfo.compound): [label, value]
## or [label, format, what fills it]. One whose lines are built in code has a case there.
## nature: the elements a 3단 or more counts as against a creature's weakness and
## absorption, in 오행 order; a pair counts as both of its own.
## lobbed: it goes only with an orb (Forge.needs_orb).
## electric: it is of 전기, a kind outside the five elements (Elements.charge).
## boom: its spray is heard Compounds.BOOM tiles from the caster.
## calm: it does nothing to a creature but its own effect: the creature is not
## struck, so it does not hunt Miho or lose a feud for it.
const COMPOUND := {
	&"wildfire":
	{
		glyph = "들",
		made = [WOOD, FIRE],
		shape = [Spray.FAN_SHAPE, 3],
		sound = &"flame",
		told =
		[
			["불", "가연성·인화성 칸"],
			["번질 확률", "%d%%", roundi(Terrain.WILD_SPREAD * 100)],
			["불붙음", "%d초", Status.ALIGHT],
			["초당 피해", "%d", World.FIRE_DAMAGE],
		],
	},
	&"lava":
	{
		glyph = "용",
		made = [FIRE, EARTH],
		shape = [Spray.BURST, 0, 1],
		sound = &"rumble",
		told =
		[
			[Compounds.HOT[Compounds.MOLTEN].name, "%d초", Compounds.HOT_ROUNDS],
			["초당 피해", "%d", Compounds.HOT[Compounds.MOLTEN].harm],
		],
		lobbed = true,
	},
	&"shrapnel":
	{
		glyph = "유",
		made = [EARTH, METAL],
		shape = [Spray.BURST, 3, 1],
		sound = &"grenade",
		told = [["피해", "%d", Compounds.SHRAPNEL]],
	},
	&"frost":
	{
		glyph = "서",
		made = [METAL, WATER],
		shape = [Spray.LINE, 4],
		sound = &"ice",
	},
	&"rain":
	{
		glyph = "단",
		made = [WATER, WOOD],
		shape = [Spray.BURST, 3, 1],
		sound = &"jet",
		told =
		[
			["묶임", "%d초", Compounds.RAIN],
			["꺼짐", "불, 등불"],
			["맞은 북", "젖음"],
			["젖음", "%d초", Status.WET],
		],
	},
	&"steam":
	{
		glyph = "증",
		made = [WATER, FIRE],
		shape = [Spray.BURST, 3, 1],
		sound = &"hiss",
	},
	&"thorn":
	{
		glyph = "가",
		made = [METAL, WOOD],
		shape = [Spray.FAN_SHAPE, 2],
		sound = &"thorn",
		told =
		[
			["생성", Tiles.ROWS[World.THORNS].name],
			["피해", "%d", Compounds.THORN],
			["지날 때 피해", "%d", Compounds.THORN],
		],
	},
	&"rift":
	{
		glyph = "균",
		made = [WOOD, EARTH],
		shape = [Spray.CLEAVE, 3],
		sound = &"rumble",
		told = [["무너짐", "벽"]],
	},
	&"mud":
	{
		glyph = "진",
		made = [EARTH, WATER],
		shape = [Spray.BURST, 2, 1],
		sound = &"splash",
		told =
		[
			["꺼짐", "불, 등불"],
			["땅", Tiles.ROWS[World.MUD].name],
			["밟으면", "묶임 %d초", Compounds.MUD],
			["젖음", "%d초", Status.WET],
		],
	},
	&"furnace":
	{
		glyph = "광",
		made = [FIRE, EARTH, METAL],
		shape = [Spray.AROUND, 0],
		sound = &"flame",
		lobbed = true,
	},
	VAULT: {glyph = "약", made = [WATER, WOOD, FIRE]},
	&"swamp":
	{
		glyph = "늪",
		made = [WOOD, EARTH, WATER],
		shape = [Spray.BREACH, 3, 2],
		sound = &"splash",
		nature = [WATER, EARTH],
	},
	&"hypnosis":
	{
		glyph = "최",
		made = [WATER, FIRE, METAL],
		shape = [Spray.LINE, 5],
		sound = &"hiss",
		told = [["잠듦", "맞은 적"], ["면역", Info.NO_SLEEP]],
		calm = true,
	},
	&"talon":
	{
		glyph = "발",
		made = [FIRE, METAL, WOOD],
		shape = [Spray.AROUND, 0],
		sound = &"thorn",
		nature = [METAL],
	},
	&"palisade":
	{
		glyph = "책",
		made = [METAL, WOOD, EARTH],
		shape = [Spray.ACROSS, 2, 3],
		sound = &"thorn",
		nature = [WOOD],
	},
	&"beacon":
	{
		glyph = "봉",
		made = [WOOD, FIRE, EARTH, METAL],
		shape = [Spray.AROUND, 0],
		sound = &"flame",
	},
	&"magpie":
	{
		glyph = "작",
		made = [METAL, WATER, WOOD, FIRE],
		shape = [Spray.BAND, 8, 3],
		sound = &"creak",
		calm = true,
	},
	&"mist":
	{
		glyph = "안",
		made = [WATER, WOOD, FIRE, EARTH],
		shape = [Spray.AROUND, 4],
		sound = &"jet",
		nature = [WATER],
		calm = true,
	},
	&"sinkhole":
	{
		glyph = "꺼",
		made = [WOOD, EARTH, WATER, FIRE],
		shape = [Spray.BURST, 3, 1],
		sound = &"rumble",
		told =
		[
			["땅", Tiles.ROWS[World.SKY].name],
			["그 칸의 적", "추락"],
			["꺼지지 않는 칸", "당신이 선 칸, 계단으로 가는 길이 끊기는 칸"],
		],
		nature = [EARTH],
	},
	&"newmoon":
	{
		glyph = "믐",
		made = [EARTH, WATER, FIRE, METAL],
		shape = [Spray.AROUND, 8],
		sound = &"rumble",
		told = [["꺼짐", "불, 등불"]],
		calm = true,
	},
	&"discord":
	{
		glyph = "이",
		made = [WATER, FIRE, METAL, WOOD],
		shape = [Spray.SIGHT, 0],
		sound = &"charge",
		told = [["싸움", "가까운 적끼리 둘씩"], ["시간", "%d초", Mind.GRUDGE_ROUNDS]],
		calm = true,
	},
	&"thunder":
	{
		glyph = "낙",
		made = [FIRE, METAL, WOOD, EARTH],
		shape = [Spray.LINE, 8],
		sound = &"thunder",
		told =
		[
			["피해", "%d", Compounds.THUNDER],
			["기절", "%d초", Compounds.THUNDER_STUN],
			["옮겨붙음", "%d칸 안의 적, 최대 %d번", [Compounds.ARC_REACH, Compounds.ARCS]],
		],
		electric = true,
		boom = true,
	},
	&"stillness":
	{
		glyph = "고",
		made = [METAL, WOOD, EARTH, WATER],
		shape = [Spray.AROUND, 6],
		sound = &"hiss",
		told = [["추격 중인 적", "제자리 수색"], ["지워짐", "냄새"]],
		calm = true,
	},
	BUNSIN:
	{
		glyph = "분",
		made = [FOX, EARTH, FIRE, WOOD],
		shape = [Spray.AROUND, 0],
		sound = &"foxfire",
	},
	RAISE:
	{
		glyph = "령",
		made = [FOX, EARTH, METAL, WATER, WOOD],
		shape = [Spray.AROUND, 0],
		sound = &"card",
	},
	SAMSARA:
	{
		glyph = "윤",
		made = [EARTH, METAL, WATER, WOOD, FIRE],
		shape = [Spray.SIGHT, 0, true],
		sound = &"card",
		told = [["체력", "+%d", World.HEAL], ["기절", "%d초", Compounds.SAMSARA_STUN]],
	},
	CONQUEST:
	{
		glyph = "극",
		made = [WOOD, EARTH, WATER, FIRE, METAL],
		shape = [Spray.SIGHT, 0],
		sound = &"explosion",
		told =
		[
			["피해", "%d", Compounds.CONQUEST_HARM],
			["약점인 적 피해", "%d", Elements.WEAK * Compounds.CONQUEST_HARM],
		],
		nature = ELEMENTS,
		boom = true,
	},
	DRAGON:
	{
		glyph = "룡",
		made = [METAL, WATER, WOOD, FIRE, EARTH],
		shape = [Spray.AROUND, 4],
		sound = &"thunder",
		told =
		[
			["무너짐", "벽"],
			["밀침", "%d칸, 바깥으로", Compounds.DRAGON_PUSH],
			["기절", "%d초", Compounds.DRAGON_STUN],
		],
		nature = [EARTH],
		boom = true,
	},
}

## Tables built once from COMPOUND and read as a const is. slot -> how it shows, talisman or
## compound.
# gdlint:ignore = class-variable-name
static var GLYPH := _glyphs()
## compound -> what it is made of, for the 2단, the 3단, the 4단, the 5단 and the sets.
# gdlint:ignore = class-variable-name
static var PAIRS := _tier(2)
# gdlint:ignore = class-variable-name
static var TRIPLES := _tier(TRIPLE)
# gdlint:ignore = class-variable-name
static var QUADS := _tier(4)
# gdlint:ignore = class-variable-name
static var FIVES := _tier(TIER)
# gdlint:ignore = class-variable-name
static var SETS := _tier(0)
## compound -> the order of its cards that queues into it (`recipe`), once found.
static var _recipes := {}


static func _glyphs() -> Dictionary:
	var out := TALISMAN_GLYPH.duplicate()
	for c in COMPOUND:
		out[c] = COMPOUND[c].glyph
	return out


## compound -> `made` of those of `n` elements on a ring; for 0, of the sets, which hold 여.
static func _tier(n: int) -> Dictionary:
	var out := {}
	for c in COMPOUND:
		var made: Array = COMPOUND[c].made
		if (0 if made.has(FOX) else made.size()) == n:
			out[c] = made
	return out


## Whether the row of slot `c`, if it has one, holds column `field`.
static func marked(c: StringName, field: String) -> bool:
	return COMPOUND.has(c) and COMPOUND[c].has(field)


## Every compound, pairs first, then by tier.
static func compounds() -> Array:
	return COMPOUND.keys()


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
	return COMPOUND[slot].made if COMPOUND.has(slot) else [slot]


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


## How a recipe tells talisman `c`: a shape by its letter, an element by its name, through `t`.
static func part(c: StringName, t: Callable) -> String:
	return t.call(GLYPH[c], "talisman") if FORMS.has(c) else t.call(NAME[c])


## The talismans of the spell compound `slot` is cast as: its recipe, with an orb if it needs one.
static func spell_of(slot: StringName) -> Array:
	return [ORB] + recipe(slot) if marked(slot, "lobbed") else recipe(slot)


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
## 3단 or more by its `nature`; none for the rest.
static func nature(slot: StringName) -> Array:
	if ELEMENTS.has(slot):
		return [slot]
	return PAIRS.get(slot, COMPOUND[slot].get("nature", []) if COMPOUND.has(slot) else [])
