extends RefCounted
## A plain player for tools/survive.gd: it plays one seed from storey 1 through
## World.act with the actions a player has, and nothing else.
## In this order: with an awake creature of heaven in sight it hurls 구 (as many
## copies as its tails pay for) at the nearest one within Spell.RANGE; with no
## tail left it steps away to a safe tile, else claws as Tab does (Fight.step); it
## rests until the tails have regrown (health does not regrow); then it explores
## as the o key does (peaches, scrolls and jars first, then the unexplored), and
## once nothing is left it steps onto the exit. It ignores talismans it picks up.

## Rounds after which a run counts as having hit the limit.
const ROUND_LIMIT := 4000
## Rounds without a new tile of ground, a change of storey or of health after
## which a run counts as stuck.
const STALL := 200
## Different tiles Miho may stand on in STALL rounds before that counts as moving.
const STALL_SPOTS := 4


## One run of `seed_value`: {seed, end, rounds, visited, deepest, death}. `end`
## is dead, won, limit or stuck; `death` holds depth, killer, spell, blow
## (one blow from full health) and rounds, for a run that ended dead.
static func play(seed_value: int) -> Dictionary:
	var w := World.create(seed_value)
	var memory := Sightings.new()
	var visited := {w.depth: true}
	var rounds := 0
	var end := &""
	var death := {}
	var kinds := {}
	var spots := {}
	var still := 0
	var last_hp := w.player().hp
	var last_depth := w.depth
	while end == &"":
		if w.outcome != &"":
			end = w.outcome if w.outcome == &"won" else &"dead"
			break
		if rounds >= ROUND_LIMIT:
			end = &"limit"
			break
		memory.update(w)
		var action := choose(w, memory)
		if action.is_empty() or not w.can(action):
			end = &"stuck"
			break
		var me := w.player()
		var before := {hp = me.hp, max_hp = me.max_hp, depth = w.depth, id = me.id}
		for a in w.actors:
			kinds[a.id] = a.kind
		var events := w.act(action)
		rounds += 1
		visited[w.depth] = true
		for a in w.actors:
			kinds[a.id] = a.kind
		if w.outcome == &"lost":
			death = _death(w, events, before, kinds)
			death.rounds = rounds
		spots[w.player().pos] = true
		if w.depth != last_depth or w.player().hp != last_hp or spots.size() > STALL_SPOTS:
			last_depth = w.depth
			last_hp = w.player().hp
			spots = {w.player().pos: true}
			still = 0
		else:
			still += 1
			if still >= STALL:
				end = &"stuck"
	return {
		seed = seed_value,
		end = end,
		rounds = rounds,
		visited = visited.keys(),
		deepest = visited.keys().max(),
		death = death,
	}


## The action a player takes now; empty when there is nothing to do. A step Tab
## would refuse (a corner the walk cuts), or no way on while a creature is awake
## in sight or a fire burns, is a round of rest.
static func choose(w: World, memory: Sightings) -> Dictionary:
	var action := _choose(w, memory)
	var waits := not w.burning.is_empty() or Fight.targets(w).any(func(a): return not a.asleep())
	return action if w.can(action) or (action.is_empty() and not waits) else {t = &"wait"}


static func _choose(w: World, memory: Sightings) -> Dictionary:
	var me := w.player().pos
	if w.burning.has(me) or w.hot.has(me) or Gas.harms(w, me):
		var out := Grid.DIRS.filter(func(d): return Travel.walkable(w, me + d))
		out.sort_custom(
			func(a, b): return Travel.near_fire(w, me + a) < Travel.near_fire(w, me + b)
		)
		if not out.is_empty():
			return {t = &"move", dir = out[0]}
	var threats := Fight.targets(w).filter(func(a): return Travel._watching(a))
	if not threats.is_empty() and Grid.cheb(threats[0].pos, w.player().pos) <= Spell.RANGE:
		return _fight(w, threats)
	# A walker that hunts her but is out of reach: let the tails regrow, then go to it.
	if threats.any(
		func(a): return a.alert == Actor.HUNT and a.info().get("move", &"static") != &"static"
	):
		return {t = &"wait"} if w.tails < w.max_tails() else Fight.step(w)
	if threats.is_empty() and w.tails < w.max_tails():
		return {t = &"wait"}
	return _walk(w, memory)


static func _fight(w: World, threats: Array) -> Dictionary:
	var me := w.player().pos
	if w.tails >= 1:
		var copies := 1
		while copies < Spell.MAX_SLOTS and Spell.COST[copies] <= w.tails:
			copies += 1
		var cards: Array[StringName] = []
		cards.resize(copies)
		cards.fill(Cards.ORB)
		var dir := Grid.nearest_dir(threats[0].pos - me)
		var line := _lined_up(w, threats[0].pos)
		if line != Vector2i.ZERO and not _on_line(threats[0].pos - me):
			return {t = &"move", dir = line}
		return {t = &"cast", spells = [{cards = cards, dir = dir}]}
	var away := _away(w, threats)
	return {t = &"move", dir = away} if away != Vector2i.ZERO else Fight.step(w)


## Whether `d` points along one of the eight directions an orb flies.
static func _on_line(d: Vector2i) -> bool:
	return d.x == 0 or d.y == 0 or absi(d.x) == absi(d.y)


## A step to a safe tile from which `foe` lies along one of the eight directions
## within spell reach, or zero when there is none.
static func _lined_up(w: World, foe: Vector2i) -> Vector2i:
	var me := w.player().pos
	for d in Grid.DIRS:
		var p: Vector2i = me + d
		if (
			Travel.walkable(w, p)
			and w.can({t = &"move", dir = d})
			and _on_line(foe - p)
			and Grid.cheb(foe, p) <= Spell.RANGE
		):
			return d
	return Vector2i.ZERO


## The step to a safe tile that puts the most room between Miho and the nearest
## of `threats`, or zero when no step gains any.
static func _away(w: World, threats: Array) -> Vector2i:
	var me := w.player().pos
	var gap := func(p: Vector2i) -> int:
		return threats.map(func(a): return Grid.cheb(a.pos, p)).min()
	var best := Vector2i.ZERO
	var room: int = gap.call(me)
	for d in Grid.DIRS:
		var p: Vector2i = me + d
		if Travel.walkable(w, p) and w.can({t = &"move", dir = d}) and gap.call(p) > room:
			best = d
			room = gap.call(p)
	return best


## The step Travel.explore_step takes (the nearest peach, scroll or jar, else the
## unexplored, else beside the exit), but also with a creature in sight out of
## spell reach, which makes that function refuse; else onto the exit.
static func _walk(w: World, memory: Sightings) -> Dictionary:
	var me := w.player().pos
	var wanted: Array = w.peaches + Scrolls.spots(w) + Jars.spots(w)
	for avoid in [memory.at, {}]:
		var found := Travel.search(w, avoid)
		var path := Travel.route(found, Travel._nearest(found, wanted))
		if path.is_empty():
			path = Travel.route(found, Travel.frontier(w, found))
		if path.is_empty():
			path = Travel.route(found, Travel.exit(w))
			path.pop_back()
		if not path.is_empty():
			return {t = &"move", dir = path[0] - me}
	var out := Travel.exit(w)
	if out.x >= 0 and Grid.cheb(out, me) == 1:
		return {t = &"move", dir = out - me}
	return {}


## What killed Miho in this round: the creature (its kind) and spell of the
## melee or shot that struck her last, else the cause of the harm.
static func _death(w: World, events: Array, before: Dictionary, kinds: Dictionary) -> Dictionary:
	var hurts := events.filter(func(e): return e.t == &"hurt" and e.id == before.id)
	var out := {
		depth = before.depth,
		killer = "other",
		spell = "",
		blow = hurts.size() == 1 and before.hp == before.max_hp and hurts[0].n >= before.hp,
	}
	var at := events.size()
	for i in events.size():
		if events[i].t == &"hurt" and events[i].id == before.id:
			at = i
	for i in range(at - 1, -1, -1):
		var e: Dictionary = events[i]
		match e.t:
			&"hurt":
				break
			&"melee":
				if e.target == before.id:
					return _by(out, kinds, e.id, "melee")
			&"hit":
				if e.id == before.id:
					return _by(out, kinds, e.by, e.title)
			&"splash":
				return _by(out, kinds, e.by, e.title)
			&"burn":
				if e.id == before.id:
					return _cause(out, "fire")
			&"sear":
				if e.id == before.id:
					return _cause(out, "hot ground")
			&"prick":
				return _cause(out, "thorns")
			&"fall":
				return _cause(out, "fall")
	var me := w.player().pos
	if w.burning.has(me):
		return _cause(out, "fire")
	if Gas.harms(w, me):
		return _cause(out, "gas")
	return out


static func _by(out: Dictionary, kinds: Dictionary, id: int, spell: String) -> Dictionary:
	out.killer = String(Bestiary.info(kinds.get(id, &"miho")).name)
	out.spell = spell
	return out


static func _cause(out: Dictionary, cause: String) -> Dictionary:
	out.killer = cause
	return out
