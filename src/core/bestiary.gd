class_name Bestiary
extends RefCounted
## Creatures of the pavilion. Every caster uses only foxfire and orbs; strong
## ones (`drop`) add an element and give it to Miho when they fall, and the
## dokkaebi (도깨비불) and 불개 add fire to their foxfire.
## spell_name: what the log and hover call the spell it casts, in place of the
## name its cards give it (Bestiary.spell).
## glyph: the syllable drawn for it. melee: what it strikes Miho with when next
## to her: its name, the verb the log ends in ("맞아", "물려") and the damage,
## and `throw`, how many tiles the blow pushes her back (into the sky she falls).
## stokes: lights a dark lantern beside it before anything else (Mind).
## tracks: follows Miho's scent while it rests or searches (Mind).
## step: how far its footsteps are heard (0 is silent). deaf: ignores noise.
## move: approach, align (gets in line for an orb), slow, or static.
## patrol: walks between rooms while resting. hunts: always knows where Miho is.
## absorb: &"fire" eats spells that carry fire (해태 guards against fire);
## &"nofire" eats every spell without fire (불가사리 dies only in fire).
## eats: the element whose spells feed it when it absorbs them: max HP and HP
## grow by GROWTH.
## group: the group of heaven it belongs to (GROUPS).
## shout: what it shouts when it starts to hunt Miho, its word and how many
## tiles it is heard (Mind.shout); a creature without one is silent.
## wits: how well it reads a projectile (Mind): 0 dull, 1 sharp, 2 cunning. A
## dull creature looks at the spot, a sharp one at where the projectile came
## from, a cunning one hunts from there.
## A creature's elements are those of the spells it casts. A spell that holds
## an element beating one of them hits it twice as hard (Cards.BEATS).

const FOX := Cards.FOX
const ORB := Cards.ORB
const GROWTH := 1
const DULL := 0
const SHARP := 1
const CUNNING := 2
## The groups of heaven by `group`, with the name the hover gives them.
## Creatures of one group never fight each other (Mind.provoke).
const GROUPS := {
	&"dokkaebi": "도깨비",
	&"jangseung": "장승",
	&"dragon": "용",
	&"beast": "짐승",
	&"underworld": "저승",
}

const KINDS := {
	&"miho": {name = "미호", glyph = "@", hp = 3},
	&"dokkaebi":
	{
		name = "도깨비",
		glyph = "도",
		group = &"dokkaebi",
		shout = {word = "낄낄", loud = 6},
		hp = 2,
		melee = {name = "방망이", hit = "맞아", damage = 1},
		casts = [[FOX, Cards.FIRE]],
		spell_name = "도깨비불",
		cd = 3,
		move = &"approach",
		step = 4,
		wits = 1,
		patrol = true,
	},
	&"oedari":
	{
		name = "외다리 도깨비",
		glyph = "외",
		group = &"dokkaebi",
		shout = {word = "으라차", loud = 8},
		hp = 3,
		melee = {name = "씨름", hit = "져", damage = 1, throw = 2},
		move = &"approach",
		step = 6,
		wits = 1,
		patrol = true,
	},
	&"bujigaengi":
	{
		name = "부지깽이 도깨비",
		glyph = "부",
		group = &"dokkaebi",
		shout = {word = "낄낄", loud = 6},
		hp = 2,
		melee = {name = "부지깽이", hit = "맞아", damage = 1},
		move = &"approach",
		step = 4,
		wits = 1,
		patrol = true,
		absorb = &"fire",
		stokes = true,
	},
	&"bitjaru":
	{
		name = "빗자루 도깨비",
		glyph = "빗",
		group = &"dokkaebi",
		hp = 2,
		melee = {name = "빗자루", hit = "맞아", damage = 1},
		move = &"approach",
		step = 2,
		wits = 1,
		patrol = true,
		tracks = true,
	},
	&"jangseung":
	{
		name = "장승",
		glyph = "장",
		group = &"jangseung",
		hp = 3,
		casts = [[ORB]],
		cd = 2,
		move = &"static",
		deaf = true,
		wits = 0,
	},
	&"imugi":
	{
		name = "이무기",
		glyph = "이",
		group = &"dragon",
		shout = {word = "쉭", loud = 3},
		hp = 2,
		casts = [[ORB]],
		cd = 3,
		move = &"align",
		wits = 1,
	},
	&"bulgae":
	{
		name = "불개",
		glyph = "불",
		group = &"beast",
		shout = {word = "컹컹", loud = 8},
		hp = 4,
		melee = {name = "이빨", hit = "물려", damage = 1},
		casts = [[FOX, Cards.FIRE]],
		cd = 3,
		move = &"approach",
		step = 4,
		wits = 1,
		patrol = true,
		drop = Cards.FIRE,
		absorb = &"fire",
	},
	&"haetae":
	{
		name = "해태",
		glyph = "해",
		group = &"beast",
		shout = {word = "으르렁", loud = 5},
		hp = 4,
		casts = [[ORB, Cards.WATER]],
		cd = 3,
		move = &"align",
		step = 3,
		wits = 1,
		drop = Cards.WATER,
		absorb = &"fire",
	},
	&"cheonha":
	{
		name = "천하대장군",
		glyph = "천",
		group = &"jangseung",
		shout = {word = "이놈", loud = 9},
		hp = 4,
		casts = [[ORB, Cards.WOOD]],
		cd = 2,
		move = &"static",
		deaf = true,
		wits = 0,
		drop = Cards.WOOD,
	},
	&"jiha":
	{
		name = "지하여장군",
		glyph = "지",
		group = &"jangseung",
		shout = {word = "이놈", loud = 9},
		hp = 4,
		casts = [[FOX, Cards.METAL]],
		cd = 3,
		move = &"static",
		deaf = true,
		wits = 0,
		drop = Cards.METAL,
	},
	&"bulgasari":
	{
		name = "불가사리",
		glyph = "가",
		group = &"beast",
		shout = {word = "끼긱", loud = 6},
		hp = 3,
		melee = {name = "쇠톱 같은 이빨", hit = "물려", damage = 1},
		casts = [[ORB, Cards.EARTH]],
		cd = 3,
		move = &"slow",
		step = 5,
		wits = 1,
		drop = Cards.EARTH,
		absorb = &"nofire",
		eats = Cards.METAL,
	},
	&"cheonnyeon":
	{
		name = "천년 이무기",
		glyph = "용",
		group = &"dragon",
		shout = {word = "크아앙", loud = 12},
		hp = 8,
		casts = [[FOX, ORB, Cards.WATER], [ORB, Cards.FIRE, Cards.METAL]],
		cd = 2,
		move = &"align",
		boss = true,
		wits = 2,
	},
	&"saja":
	{
		name = "저승사자",
		glyph = "사",
		group = &"underworld",
		hp = 9,
		melee = {name = "오랏줄", hit = "맞아", damage = 1},
		casts = [[ORB]],
		cd = 2,
		move = &"approach",
		step = 3,
		hunts = true,
		wits = 2,
	},
}


static func info(kind: StringName) -> Dictionary:
	return KINDS[kind]


## The spell a `kind` hurls from `cards`, called by its own name if it has one.
static func spell(kind: StringName, cards: Array) -> Spell:
	var s := Spell.make(cards)
	s.called = info(kind).get("spell_name", "")
	return s


## Whether creatures of two kinds are of one group.
static func allied(a: StringName, b: StringName) -> bool:
	return info(a).get("group", &"") == info(b).get("group", &"")


## Whether `word` is what some creature shouts.
static func shouted(word: String) -> bool:
	return KINDS.values().any(func(k): return k.get("shout", {}).get("word", "") == word)


static func wits(kind: StringName) -> int:
	return info(kind).get("wits", DULL)


static func absorbs(kind: StringName, spell: Spell) -> bool:
	match info(kind).get("absorb", &""):
		&"fire":
			return spell.holds(Cards.FIRE)
		&"nofire":
			return not spell.holds(Cards.FIRE)
	return false


## Whether the creature eats the spell it absorbs and grows from it.
static func eats(kind: StringName, spell: Spell) -> bool:
	return absorbs(kind, spell) and spell.holds(info(kind).get("eats", &""))


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
	return weak_to(kind).any(func(c): return spell.holds(c))


## Wood creatures catch fire when a fire spell hits them.
static func burns(kind: StringName) -> bool:
	return elements(kind).has(Cards.WOOD)
