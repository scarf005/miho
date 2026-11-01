class_name Bestiary
extends RefCounted
## Creatures of the pavilion. Every caster uses only foxfire and orbs; strong
## ones (`drop`) add an element and give it to Miho when they fall, and
## 부지깽이 도깨비 (도깨비불) and 불개 add fire to their foxfire. The plain
## dokkaebi's 도깨비불 is a lone wisp: no element, no harm. Every dokkaebi also
## casts the lone fire (KINDLE).
## Ranks: the storeys come in ranks of two storeys (`rank`), 1 to RANKS. A
## creature is of the rank of the storey it came to (Actor.rank): HEALTH holds,
## for each kind, its health at each rank, and `ranks` holds, by rank, every
## spell it casts from that rank on (`casts` before the first). Deeper spells
## keep the kind's elements and change the board more than they hurt: more
## wisps, homing orbs, sprays and compounds, and for a 도깨비 the LEAP, which
## closes the gap in place of more health. From PICKS on it picks the spell that
## suits (Aim.at), and from DOUBLES on it charges two at once.
## spell_name: what the log and hover call its first spell (`casts`), in place
## of the name its cards give it (Bestiary.spell).
## glyph: the syllable drawn for it. melee: what it strikes Miho with when next
## to her: its name, the verb the log ends in ("맞아", "물려") and the damage,
## and `throw`, how many tiles the blow pushes her back (into the sky she falls),
## and `root`, how many rounds it roots her (Elements.root).
## mana: it pays for its spells with mana, at the price of Miho's tails
## (Spell.price), in place of waiting `cd` rounds. It regrows one every
## World.TAIL_REGROW rounds, as Miho does her tails, picks what to cast from any
## rank on (Aim.at) and casts two at once when it can pay for both. It starts
## with all of it (Actor.mana).
## stokes: when awake, lights a dark lantern beside it before anything else (Mind).
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
## wits: how well it reads a projectile it sees fly (Mind): 0 dull, 1 sharp, 2
## cunning. A dull creature looks at the spot, a sharp one at where it came from,
## a cunning one hunts from there. One struck by a projectile of Miho's hunts her.
## hat: wears the invisibility hat, seen only from the next tile or with a wisp
## clinging to it (Hat).
## A creature's elements are those of the spells it casts. A spell that holds
## an element beating one of them hits it twice as hard (Cards.BEATS).

const FOX := Cards.FOX
const ORB := Cards.ORB
const GROWTH := 1
const RANKS := 5
## Health of each kind at ranks 1 to RANKS, one row per kind. A heavy fighter
## that stands its ground (장승, 두억시니, 해태, the bosses) grows to outlast
## Miho's best cast; a 도깨비 and the fast or fragile kinds stay low.
const HEALTH := {
	&"dokkaebi": [2, 3, 3, 3, 3],
	&"oedari": [3, 4, 4, 4, 4],
	&"bujigaengi": [2, 3, 3, 3, 3],
	&"bitjaru": [2, 3, 3, 3, 3],
	&"gamtu": [2, 3, 3, 3, 3],
	&"jangseung": [3, 4, 6, 8, 9],
	&"imugi": [2, 3, 3, 3, 3],
	&"bulgae": [4, 5, 5, 5, 5],
	&"haetae": [4, 5, 7, 9, 10],
	&"cheonha": [4, 5, 7, 9, 10],
	&"jiha": [4, 5, 7, 9, 10],
	&"bulgasari": [3, 4, 6, 8, 9],
	&"cheonnyeon": [8, 9, 11, 13, 14],
	&"saja": [12, 13, 15, 17, 18],
	&"gangcheori": [5, 6, 8, 10, 11],
	&"eodeopsini": [3, 4, 4, 4, 4],
	&"dueoksini": [6, 7, 9, 11, 12],
}
## Copies of 구 a creature's orb has beyond its rank (`tiered`).
const ORB_EXTRA := 1
const PICKS := 3
const DOUBLES := 4
## The lone fire every dokkaebi can cast (Aim.kindle): one tiny fan, no element of
## its kind (Bestiary.elements).
const KINDLE := [Cards.FIRE]
## The leap a deep 도깨비 casts (Leap): Miho's, by its talismans.
const LEAP := Cards.TRIPLES[Cards.VAULT]
## Every spell 저승사자 can buy with its mana, at any rank: all five elements,
## one to five cards.
const REAPER := [
	[Cards.WOOD],
	[Cards.FIRE],
	[Cards.WATER],
	[Cards.METAL],
	[Cards.EARTH],
	[ORB, Cards.FIRE],
	[FOX, ORB, Cards.METAL],
	[ORB, Cards.FIRE, Cards.METAL],
	[FOX, ORB, Cards.WOOD],
	[FOX, FOX, Cards.FIRE],
	[Cards.WOOD, Cards.FIRE, Cards.EARTH],
	[Cards.FIRE, Cards.EARTH, Cards.METAL],
	[Cards.EARTH, Cards.METAL, Cards.WATER],
	[Cards.METAL, Cards.WATER, Cards.WOOD],
	[Cards.WOOD, Cards.EARTH, Cards.WATER],
	[Cards.EARTH, Cards.WATER, Cards.FIRE],
	[Cards.WATER, Cards.FIRE, Cards.METAL],
	[Cards.FIRE, Cards.METAL, Cards.WOOD],
	[Cards.METAL, Cards.WOOD, Cards.EARTH],
	[FOX, FOX, ORB, Cards.FIRE],
	[FOX, FOX, FOX, Cards.WATER],
	[Cards.FIRE, Cards.EARTH, Cards.METAL, Cards.WATER],
	[Cards.EARTH, Cards.METAL, Cards.WATER, Cards.WOOD],
	[Cards.WOOD, Cards.EARTH, Cards.WATER, Cards.FIRE],
	[Cards.EARTH, Cards.WATER, Cards.FIRE, Cards.METAL],
	[Cards.FIRE, Cards.METAL, Cards.WOOD, Cards.EARTH],
	[FOX, FOX, ORB, Cards.FIRE, Cards.METAL],
	[Cards.WOOD, Cards.FIRE, Cards.EARTH, Cards.METAL, Cards.WATER],
	[Cards.WOOD, Cards.EARTH, Cards.WATER, Cards.FIRE, Cards.METAL],
	[Cards.WOOD, Cards.FIRE, Cards.METAL, Cards.WATER, Cards.EARTH],
]
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

## What a group calls its wisps; &"" for the rest.
const WISP_NAME := {&"dokkaebi": "도깨비불", &"underworld": "저승불", &"": "혼불"}

const KINDS := {
	&"miho": {name = "미호", glyph = "@", hp = 3},
	&"dokkaebi":
	{
		name = "도깨비",
		glyph = "도",
		group = &"dokkaebi",
		shout = {word = "낄낄", loud = 6},
		melee = {name = "방망이", hit = "맞아", damage = 1},
		casts = [[FOX], KINDLE],
		ranks =
		{
			2: [[FOX], [FOX, FOX], KINDLE],
			3: [[FOX], [FOX, FOX], [FOX, ORB], LEAP, KINDLE],
			5: [[FOX], [FOX, FOX], [FOX, FOX, FOX, ORB], LEAP, KINDLE],
		},
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
		melee = {name = "씨름", hit = "져", damage = 1, throw = 2},
		casts = [KINDLE],
		cd = 3,
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
		melee = {name = "부지깽이", hit = "맞아", damage = 1},
		casts = [[FOX, Cards.FIRE], KINDLE],
		ranks =
		{
			2: [[FOX, Cards.FIRE], [ORB, Cards.FIRE], KINDLE],
			3: [[FOX, Cards.FIRE], [ORB, Cards.FIRE], LEAP, KINDLE],
			5:
			[
				[FOX, Cards.FIRE],
				[ORB, Cards.FIRE],
				[Cards.FIRE, Cards.FIRE, Cards.FIRE],
				LEAP,
				KINDLE,
			],
		},
		spell_name = "도깨비불",
		cd = 3,
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
		melee = {name = "빗자루", hit = "맞아", damage = 1},
		casts = [KINDLE],
		cd = 3,
		move = &"approach",
		step = 2,
		wits = 1,
		patrol = true,
		tracks = true,
	},
	&"gamtu":
	{
		name = "감투 도깨비",
		glyph = "감",
		group = &"dokkaebi",
		melee = {name = "방망이", hit = "맞아", damage = 1},
		casts = [KINDLE],
		cd = 3,
		move = &"approach",
		step = 2,
		wits = 1,
		patrol = true,
		hat = true,
	},
	&"jangseung":
	{
		name = "장승",
		glyph = "장",
		group = &"jangseung",
		melee = {name = "박치기", hit = "맞아", damage = 1},
		casts = [[ORB]],
		ranks =
		{
			2: [[FOX, ORB]],
			3: [[FOX, ORB], [FOX, FOX, ORB]],
			5: [[FOX, ORB], [FOX, FOX, FOX, FOX, ORB]],
		},
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
		casts = [[ORB]],
		ranks =
		{
			2: [[ORB], [FOX, FOX]],
			3: [[ORB], [FOX, FOX], [FOX, ORB]],
			5: [[ORB], [FOX, FOX], [FOX, FOX, FOX, ORB]],
		},
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
		melee = {name = "앞발", hit = "맞아", damage = 3},
		casts = [[ORB, Cards.WATER]],
		ranks =
		{
			2: [[ORB, Cards.WATER], [Cards.WATER]],
			3: [[ORB, Cards.WATER], [Cards.WATER, Cards.WATER], [FOX, ORB, Cards.WATER]],
			5:
			[
				[ORB, Cards.WATER],
				[Cards.WATER, Cards.WATER, Cards.WATER],
				[FOX, ORB, Cards.WATER],
			],
		},
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
		casts = [[ORB, Cards.WOOD]],
		ranks = {2: [[ORB, Cards.WOOD], [Cards.WOOD]]},
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
		casts = [[FOX, Cards.METAL]],
		ranks = {2: [[FOX, Cards.METAL], [FOX, Cards.METAL, Cards.METAL]]},
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
		melee = {name = "이빨", hit = "물려", damage = 1},
		casts = [[ORB, Cards.EARTH]],
		ranks = {3: [[ORB, Cards.EARTH], [FOX, Cards.EARTH], [Cards.EARTH, Cards.EARTH]]},
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
		casts = [[FOX, ORB, Cards.WATER], [ORB, Cards.FIRE, Cards.METAL]],
		ranks =
		{
			5:
			[
				[FOX, ORB, Cards.WATER],
				[ORB, Cards.FIRE, Cards.METAL],
				[FOX, Cards.WATER, Cards.METAL],
				[Cards.WATER, Cards.FIRE],
			],
		},
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
		melee = {name = "오랏줄", hit = "맞아", damage = 1, root = 2},
		mana = 9,
		casts = REAPER,
		move = &"approach",
		step = 3,
		hunts = true,
		wits = 2,
	},
	&"gangcheori":
	{
		name = "강철이",
		glyph = "강",
		group = &"dragon",
		shout = {word = "우르릉", loud = 8},
		casts = [[ORB, Cards.FIRE, Cards.METAL], [FOX, Cards.FIRE]],
		ranks =
		{
			4: [[ORB, Cards.FIRE, Cards.METAL], [FOX, Cards.FIRE], [Cards.FIRE, Cards.FIRE]],
			5:
			[
				[ORB, Cards.FIRE, Cards.METAL],
				[FOX, Cards.FIRE],
				[Cards.FIRE, Cards.FIRE],
				[FOX, ORB, Cards.FIRE],
			],
		},
		cd = 3,
		move = &"align",
		step = 3,
		wits = 1,
		absorb = &"fire",
	},
	&"eodeopsini":
	{
		name = "어둑시니",
		glyph = "어",
		group = &"underworld",
		melee = {name = "손톱", hit = "긁혀", damage = 1},
		casts = [[FOX, Cards.WATER]],
		ranks =
		{
			4: [[FOX, Cards.WATER], [FOX, FOX, Cards.WATER]],
			5: [[FOX, Cards.WATER], [FOX, FOX, Cards.WATER], [FOX, FOX, FOX, Cards.WATER]],
		},
		cd = 3,
		move = &"approach",
		step = 0,
		wits = 1,
		patrol = true,
		tracks = true,
	},
	&"dueoksini":
	{
		name = "두억시니",
		glyph = "두",
		group = &"underworld",
		shout = {word = "우어어", loud = 9},
		melee = {name = "주먹", hit = "맞아", damage = 2, throw = 3},
		casts = [[Cards.EARTH]],
		ranks = {4: [[Cards.EARTH], [Cards.EARTH, Cards.EARTH]]},
		cd = 3,
		move = &"slow",
		step = 5,
		wits = 0,
		patrol = true,
	},
}


static func info(kind: StringName) -> Dictionary:
	return KINDS[kind]


## The rank of storey `depth`: two storeys each.
static func rank(depth: int) -> int:
	return mini((depth + 1) / 2, RANKS)


## Every spell a creature of `kind` casts at rank `r`, its orbs in the tier of
## the rank (`tiered`).
static func casts(kind: StringName, r: int) -> Array:
	var out: Array = info(kind).get("casts", [])
	for k in range(2, r + 1):
		out = info(kind).get("ranks", {}).get(k, out)
	return out.map(func(cast): return tiered(cast, r))


## `cast` with its 구 as many copies as rank `r` and ORB_EXTRA make, no more
## than the five slots of a spell leave room for (Spell.MAX_SLOTS): the orb
## tier follows the storey.
static func tiered(cast: Array, r: int) -> Array:
	var orbs := cast.count(ORB)
	if orbs == 0:
		return cast
	var n := clampi(r + ORB_EXTRA, 1, Spell.MAX_SLOTS - (cast.size() - orbs))
	var out := []
	for c in cast:
		if c != ORB:
			out.append(c)
		elif not out.has(ORB):
			for i in n:
				out.append(ORB)
	return out


## The health of a creature of `kind` at rank `r`.
static func hp(kind: StringName, r: int) -> int:
	return HEALTH[kind][r - 1]


## The spell a `kind` hurls from `cards`, its wisps in the words of its group
## (여우불 is Miho's), its first spell called by its own name if it has one.
static func spell(kind: StringName, cards: Array) -> Spell:
	var s := Spell.make(cards)
	if info(kind).has("group"):
		s.wisp_name = WISP_NAME.get(info(kind).group, WISP_NAME[&""])
	var first: Array = info(kind).get("casts", [[]])[0]
	if "+".join(first) == s.key():
		s.called = info(kind).get("spell_name", "")
	return s


## Whether creatures of two kinds are of one group.
static func allied(a: StringName, b: StringName) -> bool:
	return info(a).get("group", &"") == info(b).get("group", &"")


## Whether `word` is what some creature shouts.
static func shouted(word: String) -> bool:
	return KINDS.values().any(func(k): return k.get("shout", {}).get("word", "") == word)


## The mana a creature of `kind` pays its spells with, 0 for one that waits `cd`.
static func mana(kind: StringName) -> int:
	return info(kind).get("mana", 0)


static func wits(kind: StringName) -> int:
	return info(kind).get("wits", DULL)


## Whether creatures of `kind` come in bands (FloorGen.bands): those that walk
## and are no boss.
static func bands(kind: StringName) -> bool:
	var spec := info(kind)
	return (
		spec.has("group")
		and spec.get("move", &"static") != &"static"
		and not spec.get("boss", false)
	)


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


## A creature's elements: those of the spells it casts at any rank, in 오행
## order.
static func elements(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if info(kind).has("mana"):
		return out
	var all := []
	for r in range(1, RANKS + 1):
		all.append_array(casts(kind, r).filter(func(c): return c != KINDLE and c != LEAP))
	for c in Cards.ELEMENTS:
		if all.any(func(cast): return cast.has(c)):
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
