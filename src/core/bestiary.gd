class_name Bestiary
extends RefCounted
## Creatures of the pavilion. Every caster uses only foxfire and orbs; strong
## ones (`drop`) add an element and give it to Miho when they fall.
## glyph: the syllable drawn for it. club: melee damage when next to Miho.
## step: how far its footsteps are heard (0 is silent). deaf: ignores noise.
## move: approach, align (gets in line for an orb), slow, or static.
## patrol: walks between rooms while resting. hunts: always knows where Miho is.
## absorb: &"fire" eats spells that carry fire (해태 guards against fire);
## &"nofire" eats every spell without fire (불가사리 dies only in fire).
## A creature's elements are those of the spells it casts. A spell that holds
## an element beating one of them hits it twice as hard (Cards.BEATS).

const FOX := Cards.FOX
const ORB := Cards.ORB

const KINDS := {
	&"miho": {name = "미호", glyph = "@", hp = 3},
	&"dokkaebi":
	{
		name = "도깨비",
		glyph = "도",
		hp = 2,
		club = 1,
		casts = [[FOX]],
		cd = 3,
		move = &"approach",
		step = 4,
		patrol = true,
	},
	&"jangseung":
	{
		name = "장승",
		glyph = "장",
		hp = 3,
		casts = [[ORB]],
		cd = 2,
		move = &"static",
		deaf = true,
	},
	&"imugi": {name = "이무기", glyph = "이", hp = 2, casts = [[ORB]], cd = 3, move = &"align"},
	&"bulgae":
	{
		name = "불개",
		glyph = "불",
		hp = 4,
		club = 1,
		casts = [[FOX, Cards.FIRE]],
		cd = 3,
		move = &"approach",
		step = 4,
		patrol = true,
		drop = Cards.FIRE,
		absorb = &"fire",
	},
	&"haetae":
	{
		name = "해태",
		glyph = "해",
		hp = 4,
		casts = [[ORB, Cards.WATER]],
		cd = 3,
		move = &"align",
		step = 3,
		drop = Cards.WATER,
		absorb = &"fire",
	},
	&"cheonha":
	{
		name = "천하대장군",
		glyph = "천",
		hp = 4,
		casts = [[ORB, Cards.WOOD]],
		cd = 2,
		move = &"static",
		deaf = true,
		drop = Cards.WOOD,
	},
	&"jiha":
	{
		name = "지하여장군",
		glyph = "지",
		hp = 4,
		casts = [[FOX, Cards.METAL]],
		cd = 3,
		move = &"static",
		deaf = true,
		drop = Cards.METAL,
	},
	&"bulgasari":
	{
		name = "불가사리",
		glyph = "가",
		hp = 3,
		club = 1,
		casts = [[ORB, Cards.EARTH]],
		cd = 3,
		move = &"slow",
		step = 5,
		drop = Cards.EARTH,
		absorb = &"nofire",
	},
	&"cheonnyeon":
	{
		name = "천년 이무기",
		glyph = "용",
		hp = 8,
		casts = [[FOX, ORB, Cards.WATER], [ORB, Cards.FIRE, Cards.METAL]],
		cd = 2,
		move = &"align",
		boss = true,
	},
	&"saja":
	{
		name = "저승사자",
		glyph = "사",
		hp = 9,
		club = 1,
		casts = [[ORB]],
		cd = 2,
		move = &"approach",
		step = 3,
		hunts = true,
	},
}


static func info(kind: StringName) -> Dictionary:
	return KINDS[kind]


static func absorbs(kind: StringName, spell: Spell) -> bool:
	match info(kind).get("absorb", &""):
		&"fire":
			return spell.has(Cards.FIRE)
		&"nofire":
			return not spell.has(Cards.FIRE)
	return false


## A creature's elements: those of the spells it casts, in 오행 order.
static func elements(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for c in Cards.ELEMENTS:
		if info(kind).get("casts", []).any(func(cast): return cast.has(c)):
			out.append(c)
	return out


## The elements that beat one of the creature's own, in 오행 order.
static func weak_to(kind: StringName) -> Array[StringName]:
	var mine := elements(kind)
	var out: Array[StringName] = []
	out.assign(Cards.ELEMENTS.filter(func(c): return mine.has(Cards.BEATS[c])))
	return out


## Whether the spell holds an element that beats one of the creature's.
static func weak(kind: StringName, spell: Spell) -> bool:
	return weak_to(kind).any(func(c): return spell.has(c))


## Wood creatures catch fire when a fire spell hits them.
static func burns(kind: StringName) -> bool:
	return elements(kind).has(Cards.WOOD)
