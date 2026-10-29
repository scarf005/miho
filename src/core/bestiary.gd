class_name Bestiary
extends RefCounted
## Creatures of the pavilion. Every caster uses only foxfire and orbs; strong
## ones (`drop`) add an element and give it to Miho when they fall.
## absorb: &"fire" eats spells that carry fire (해태 guards against fire);
## &"nofire" eats every spell without fire (불가사리 dies only in fire).

const FOX := Cards.FOX
const ORB := Cards.ORB

const KINDS := {
	&"miho": {name = "미호", hp = 3},
	&"dokkaebi": {name = "도깨비", hp = 2, casts = [[FOX]], cd = 3, move = &"approach", keep = 3},
	&"jangseung": {name = "장승", hp = 3, casts = [[ORB]], cd = 2, move = &"static"},
	&"imugi": {name = "이무기", hp = 2, casts = [[ORB]], cd = 3, move = &"align"},
	&"bulgae":
	{
		name = "불개",
		hp = 4,
		casts = [[FOX, Cards.FIRE]],
		cd = 3,
		move = &"approach",
		keep = 3,
		drop = Cards.FIRE,
		absorb = &"fire",
	},
	&"haetae":
	{
		name = "해태",
		hp = 4,
		casts = [[ORB, Cards.WATER]],
		cd = 3,
		move = &"align",
		drop = Cards.WATER,
		absorb = &"fire",
	},
	&"cheonha":
	{
		name = "천하대장군",
		hp = 4,
		casts = [[ORB, Cards.WOOD]],
		cd = 2,
		move = &"static",
		drop = Cards.WOOD,
	},
	&"jiha":
	{
		name = "지하여장군",
		hp = 4,
		casts = [[FOX, Cards.EARTH]],
		cd = 4,
		move = &"static",
		drop = Cards.EARTH,
	},
	&"bulgasari":
	{
		name = "불가사리",
		hp = 3,
		casts = [[ORB, Cards.METAL]],
		cd = 3,
		move = &"slow",
		drop = Cards.METAL,
		absorb = &"nofire",
	},
	&"cheonnyeon":
	{
		name = "천년 이무기",
		hp = 8,
		casts = [[FOX, ORB, Cards.WATER], [ORB, Cards.FIRE, Cards.METAL]],
		cd = 2,
		move = &"align",
		boss = true,
	},
	&"saja": {name = "저승사자", hp = 9, casts = [[ORB]], cd = 2, move = &"approach", keep = 1},
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
