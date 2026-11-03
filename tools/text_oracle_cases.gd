extends RefCounted
## The situations and events text_oracle.gd feeds to the text that tells how things stand
## now: the creature hover (Info.creature) and the log (Messages._render). Each case is built
## on a real world by the game's own code, then set by hand to the state it names.

static var _worlds := {}


## A copy of World.create(seed_value), which is built once.
static func world(seed_value: int) -> World:
	if not _worlds.has(seed_value):
		_worlds[seed_value] = World.create(seed_value)
	return _worlds[seed_value].clone()


## A world of a fixed seed with a creature of `kind` beside Miho, on floor all round it.
static func stand(seed_value: int, kind: StringName) -> Array:
	var w := world(seed_value)
	var at := w.player().pos + Vector2i(1, 0)
	for d in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0), Vector2i.DOWN, Vector2i.UP]:
		w.set_tile(at + d, World.FLOOR)
	var a := w.player() if kind == &"miho" else FloorGen.spawn(w, kind, at)
	w.sense()
	return [w, a.id]


## The state of a creature as a Callable (world, creature) that sets it, by name: how it
## rests, searches or hunts, what holds or burns it, and whether it sees Miho.
static func states() -> Dictionary:
	var out := {}
	out.rest = func(_w, _a): pass
	out.away = func(_w, a): a.pos += Vector2i.DOWN
	out.guard = func(_w, a): a.brain.guard = true
	out.ally = func(_w, a): a.faction = Actor.FOX
	out.follows = func(w, a):
		a.faction = Actor.FOX
		a.ties.leader = w.player().id
	out.leads = func(w, a): a.ties.leader = w.player().id
	out.search = func(_w, a): a.brain.alert = Actor.SEARCH
	out.search_late = func(_w, a):
		a.brain.alert = Actor.SEARCH
		a.brain.lost = World.SEARCH_ROUNDS
	out.search_wary = func(_w, a):
		a.brain.alert = Actor.SEARCH
		a.brain.wary = 2
		a.brain.lost = World.SEARCH_ROUNDS
	out.search_me = func(w, a):
		a.brain.alert = Actor.SEARCH
		a.brain.target = w.player().pos
	out.search_trail = func(w, a):
		a.brain.alert = Actor.SEARCH
		Scent.lay(w, a.pos + Vector2i.DOWN)
	out.hunt = func(_w, a): a.brain.alert = Actor.HUNT
	out.hunt_ally = func(_w, a):
		a.brain.alert = Actor.HUNT
		a.faction = Actor.FOX
	out.drum = func(_w, a):
		a.brain.alert = Actor.HUNT
		a.brain.drum = Vector2i.ONE
	out.fight = func(_w, a):
		a.ties.rival = 999
		a.ties.grudge = 4
	out.fight_player = func(w, a):
		a.ties.rival = w.player().id
		a.ties.grudge = 4
	out.blind = func(_w, a): a.ailments.blind = 3
	out.rooted = func(_w, a): a.ailments.rooted = 3
	out.stunned = func(_w, a): a.ailments.stunned = 3
	out.wary = func(_w, a): a.brain.wary = 3
	out.all_conditions = func(_w, a):
		a.ailments.blind = 1
		a.ailments.rooted = 2
		a.ailments.stunned = 3
		a.brain.wary = 4
	out.wet = func(_w, a): a.ailments.wet = Status.WET
	out.alight = func(_w, a): a.ailments.alight = Status.ALIGHT
	out.frozen = func(_w, a): a.ailments.frozen = 2
	out.talon = func(_w, a): a.buffs.talon = true
	out.cloak = func(_w, a): a.buffs.cloak = true
	out.flame = func(_w, a): a.buffs.flame = true
	out.raise = func(_w, a): a.buffs.raise = true
	out.guise = func(_w, a):
		a.buffs.guise = true
		a.buffs.form = &"saja"
		a.buffs.beside = 2
	out.prey = func(w, a):
		a.buffs.prey = &"saja"
		w.cards.assign([Cards.WOOD, Cards.EARTH])
	out.burning = func(w, a): w.burning[a.pos] = World.BURN_ROUNDS
	out.fierce = func(w, a):
		w.set_tile(a.pos, World.STRAW)
		w.burning[a.pos] = World.BURN_ROUNDS
	out.burning_alight = func(w, a):
		a.ailments.alight = Status.ALIGHT
		w.burning[a.pos] = World.BURN_ROUNDS
	out.veil = func(w, a): w.set_tile(a.pos + Vector2i.UP, World.VEIL)
	out.riders = func(w, a):
		for life in [0, 3]:
			var s := Shot.of(w, w.player(), Spell.make([Cards.FOX, Cards.FIRE]))
			s.host = a.id
			s.life = life
			w.shots.append(s)
	out.bamboo = func(w, a): w.set_tile(a.pos, World.BAMBOO)
	for kind in Compounds.HOT.size():
		out["hot%d" % kind] = func(w, a): w.hot[a.pos] = Vector2i(kind, Compounds.HOT_ROUNDS)
	for kind in Gas.ROWS:
		out["gas%d" % kind] = func(w, a): Gas.put(w, a.pos, kind, Gas.MAX)
	for curse in Curse.NAME:
		out["curse_%s" % curse] = func(w, _a): w.curses[curse] = World.REAPER_ARRIVES
	out.cloaked_me = func(w, a):
		a.brain.alert = Actor.SEARCH
		a.pos += Vector2i.RIGHT
		w.player().buffs.cloak = true
		w.burning[w.player().pos] = World.BURN_ROUNDS
	out.guised_me = func(w, a):
		a.brain.alert = Actor.SEARCH
		w.player().buffs.guise = true
		w.player().buffs.form = &"saja"
	out.guised_me_hunted = func(w, a):
		a.brain.alert = Actor.HUNT
		w.player().buffs.guise = true
		w.player().buffs.form = &"saja"
	out.claws_me = func(w, a):
		a.pos += Vector2i.DOWN
		w.player().buffs.talon = true
	for rank in range(2, Bestiary.RANKS + 1):
		out["rank%d" % rank] = func(_w, a):
			a.rank = rank
			if not a.is_miho():
				a.hp = Bestiary.hp(a.kind, rank)
				a.max_hp = a.hp
				a.magic.mana = Bestiary.mana(a.kind)
	out.charging = func(_w, a):
		var casts: Array = a.repertoire()
		if not casts.is_empty():
			a.magic.intent.append({cards = casts[0], dir = Vector2i.RIGHT})
	out.cooling = func(_w, a): a.magic.cooldown = 3
	out.spent = func(_w, a): a.magic.mana = 0
	return out


## The id of a creature that is not in the world: the log calls it 무언가.
const GONE := 999


## The facts of a round the log tells, as sequences rendered together: each kind of event for
## every way its text branches. `ids` are the creatures of `after` by kind, `me` is Miho.
static func events(ids: Dictionary, me: int) -> Array:
	var out := []
	var foe: int = ids.values()[0]
	for id in [foe, GONE, me]:
		for other in [foe, me]:
			out.append_array(_acts(id, other))
	for kind in ids:
		out.append_array(_of_kind(kind, ids[kind], foe, me))
	out.append_array(_by_last(me, foe))
	return out


## Events whose text varies by the actor or the target.
static func _acts(id: int, other: int) -> Array:
	var tag := Spell.make([Cards.FOX, Cards.FIRE]).tag()
	var facts := [
		{t = &"noise", word = "쿵"},
		{t = &"notice", id = id},
		{t = &"claw", id = id, target = other, n = 2},
		{t = &"feud", id = id, rival = other},
		{t = &"shout", id = id, word = "낄낄"},
		{t = &"truce", id = id},
		{t = &"die", id = id},
		{t = &"die", id = id, gone = true},
		{t = &"fall", id = id},
		{t = &"fall", id = id, depth = 3},
		{t = &"swap", id = id, other = 0},
		{t = &"swap", id = id, other = other},
		{t = &"resist", id = id, taken = [Cards.FIRE]},
		{t = &"stick", id = id, cards = tag.cards, spell = tag},
		{t = &"trap", id = id, kind = World.STRAW},
		{t = &"trap", kind = World.STRAW, shot = 1, spell = tag},
		{t = &"open", id = id},
		{t = &"close", id = id},
		{t = &"drum", id = id, wet = false},
		{t = &"drum", id = id, wet = true},
		{t = &"relight", id = id},
		{t = &"fade", id = id, spell = tag, dropped = true},
		{t = &"fade", id = id, spell = tag, lit = true},
		{t = &"fade", id = id, title = "불길"},
		{t = &"hurt", id = id, n = 2},
	]
	for t in [
		&"arrive",
		&"sleep",
		&"absorb",
		&"calm",
		&"quench",
		&"thaw",
		&"dry",
		&"wet",
		&"freeze",
		&"alight",
		&"stun",
		&"root",
		&"blind",
		&"push",
		&"pull",
		&"leap"
	]:
		facts.append({t = t, id = id})
	for mark in Messages.STATE:
		facts.append({t = &"state", id = id, mark = mark})
	for t in Messages.FREED:
		facts.append({t = t, id = id})
	return facts.map(func(f): return [f])


## Events that name a kind of creature, or need what it strikes and casts with.
static func _of_kind(kind: StringName, id: int, foe: int, me: int) -> Array:
	var out := [
		[{t = &"ally", id = id, kind = kind}],
		[{t = &"guise", kind = kind}],
		[{t = &"rise", id = id}]
	]
	if Bestiary.info(kind).has("melee"):
		out.append([{t = &"melee", id = id, target = me, n = 1}])
		out.append([{t = &"melee", id = id, target = foe, n = 1}])
	if Bestiary.info(kind).has("eats"):
		out.append([{t = &"grow", id = id}])
	for rank in range(1, Bestiary.RANKS + 1):
		for cards in Bestiary.casts(kind, rank):
			out.append([{t = &"charge", id = id, cards = cards}])
	for what in Notice.LABEL:
		out.append([{t = &"heed", id = id, kind = what}])
	return out


## Facts that read by the one before them, and those of a tile, a gas, a jar or a card.
static func _by_last(me: int, foe: int) -> Array:
	var shot := {t = &"hit", faction = Actor.FOX, by = me}
	var out := []
	var tag := Spell.make([Cards.FOX, Cards.FIRE]).tag()
	for id in [foe, me]:
		for by in [
			{t = &"burn", id = id, fierce = false},
			{t = &"burn", id = id, fierce = true},
			{t = &"scald", id = id, kind = 0},
			{t = &"sear", id = id, kind = 0},
			{t = &"crash", id = id},
			{t = &"prick", id = id},
			{t = &"claw", id = me, target = foe, n = 1},
			shot,
			{t = &"splash", faction = Actor.FOX, by = me},
			{t = &"hit", faction = Actor.HEAVEN, by = me, title = "불길"},
			{t = &"hit", faction = Actor.HEAVEN, by = GONE, spell = tag},
			{t = &"ascend", depth = 2},
		]:
			out.append([by, {t = &"hurt", id = id, n = 2}])
	out.append([{t = &"fall", id = foe}, {t = &"die", id = foe}])
	out.append([{t = &"ascend", depth = 2}, {t = &"heal"}])
	out.append([{t = &"gas", kind = 0}, {t = &"gas", kind = 0}])
	out.append([{t = &"gas", kind = 0}, {t = &"gas", kind = 1}])
	for f in [
		{t = &"card", card = Cards.FIRE},
		{t = &"scroll", card = Cards.WATER},
		{t = &"heal", n = 2, kimchi = true},
		{t = &"heal"},
		{t = &"heal", grew = true},
		{t = &"heal", spell = true},
		{t = &"sprout"},
		{t = &"yelp"},
		{t = &"unmask"},
		{t = &"talon"},
		{t = &"untalon"},
		{t = &"cloak"},
		{t = &"uncloak"},
		{t = &"flame"},
		{t = &"unflame"},
		{t = &"raise"},
		{t = &"unraise"},
		{t = &"soak"},
		{t = &"collapse"},
		{t = &"altar"},
		{t = &"read"},
		{t = &"creak"},
		{t = &"ascend", depth = 4},
		{t = &"omen"},
		{t = &"won"},
		{t = &"relight", id = -1},
		{t = &"wake"},
		{t = &"become", tile = World.WOOD_WALL},
		{t = &"become", tile = World.WOOD_WALL, was = World.FLOOR},
		{t = &"find", kind = World.WOOD_WALL},
		{t = &"crumble", was = World.WOOD_WALL},
		{t = &"trample", was = World.BAMBOO},
		{t = &"smash", was = World.LANTERN, left = World.LANTERN_OUT},
		{t = &"smash", was = World.WOOD_WALL, left = World.FLOOR},
	]:
		out.append([f])
	for jar in Messages.JAR_DOES:
		out.append([{t = &"jar", what = jar}])
	for tile in [
		World.WALL, World.WALL_CRACKED, World.WINDOW, World.SCREEN, World.JAR, World.CENSER
	]:
		out.append([{t = &"smash", was = tile, left = World.FLOOR}])
	for curse in Curse.NAME:
		out.append([{t = &"curse", what = curse}])
	for cmd in Cheat.NAME:
		for on in [true, false]:
			out.append([{t = &"cheat", cmd = cmd, kind = &"saja", depth = 2, on = on}])
	for kind in Gas.ROWS:
		out.append([{t = &"gas", kind = kind}])
		out.append([{t = &"blast", kind = kind}])
	for kind in Compounds.HOT.size():
		out.append([{t = &"heat", kind = kind}])
		out.append([{t = &"cool", kind = kind}])
	return out


## The fire events at `at`, whose text reads the tile `before` had there.
static func fires(at: Vector2i) -> Array:
	return [[{t = &"ignite", at = at}], [{t = &"burnout", at = at}], [{t = &"douse", at = at}]]
