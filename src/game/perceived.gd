class_name Perceived
extends RefCounted
## What Miho perceives in one round: the single account the message log and the
## map's popups and marks both read. A tile is seen if she saw it at the start
## or at the end of the round. A fact is an event she is told of: one that
## happened on a seen tile, one with no place, or a noise she heard out of
## sight, copied with `where` (the tile it happened on) and `i` (its index in
## the round's events). Anything else that happened gives no fact.
## The map also marks a creature in sight by its state, so a creature that comes
## into sight marked, or changes its mark in sight, gives a `state` fact (i is
## -1) unless the round's facts already tell it: a seen notice, heed or blinding.
## It derives from `before` and `after` only, so a replay gives the same facts.

## The mark a seen event already tells.
const TELLS := {&"notice": "!", &"heed": "?", &"blind": "x", &"rise": "?"}

## Tiles seen at the start or end of the round (1 for seen).
var vis := PackedByteArray()
## The facts, in the order of the events.
var facts: Array[Dictionary] = []
## The ids of the creatures under a hat that she did not see in the round.
var veiled := {}


## What Miho perceives of `events`, the round from `before` to `after`.
static func of(before: World, after: World, events: Array) -> Perceived:
	var out := Perceived.new()
	out.vis = before.seen.duplicate()
	for i in out.vis.size():
		out.vis[i] |= after.seen[i]
	out.veiled = _veiled(before, after)
	var where := {}
	for w: World in [after, before]:
		for a in w.actors:
			where[a.id] = a.pos
	var factions := {}
	for s in before.shots:
		factions[s.id] = s.faction
	for i in events.size():
		var e: Dictionary = events[i]
		if e.t == &"move" and where.has(e.id):
			where[e.id] = e.to
		if e.t == &"spawn" or e.t == &"spray":
			factions[e.shot] = e.faction
		if e.t == &"hit":
			e = e.merged({faction = factions.get(e.shot, Actor.HEAVEN)})
		var at: Vector2i = e.get("to", e.get("at", where.get(e.get("id", -1), Vector2i(-1, -1))))
		var told := (
			not Grid.inside(at) and not e.has("id")
			or sees(out.vis, at)
			or (e.has("from") and sees(out.vis, e.from))
		)
		if e.t == &"noise":
			told = e.heard and not sees(out.vis, e.at)
		if ["id", "target", "rival"].any(func(k): return out.veiled.has(e.get(k, -1))):
			told = false
		if told:
			out.facts.append(e.merged({where = at, i = i}))
	out._tell_marks(before, after)
	return out


## The hat wearers (Hat) Miho saw neither at the start nor at the end of the
## round, by id: nothing that happens to them is told, though their tile is seen.
static func _veiled(before: World, after: World) -> Dictionary:
	var out := {}
	for w: World in [before, after]:
		for a in w.actors:
			if a.info().get("hat", false):
				out[a.id] = true
	for id in out.keys():
		for w: World in [before, after]:
			var a := w.actor(id)
			if a != null and a.alive() and Hat.shown(w, a):
				out.erase(id)
	return out


## A `state` fact for each creature in sight at the end whose mark Miho was
## not shown before: it was out of sight, or marked differently.
func _tell_marks(before: World, after: World) -> void:
	var covered := {}
	for f in facts:
		if TELLS.has(f.t):
			covered[[TELLS[f.t], f.id]] = true
	for a in after.actors:
		var mark := mark_of(a)
		if a.faction == Actor.FOX or not a.alive() or mark == "" or not Hat.shown(after, a):
			continue
		var was := before.actor(a.id)
		if was != null and was.alive() and Hat.shown(before, was) and mark_of(was) == mark:
			continue
		if not covered.has([mark, a.id]):
			facts.append({t = &"state", id = a.id, mark = mark, where = a.pos, i = -1})


## Where the useful things first come into Miho's sight in the round from
## `before` to `after`: the stairs, the elixir, a peach, a scroll, a talisman stand and a
## library. A tile she made out on this storey before, or knew by the scrolls, is
## not new; on a new storey every tile is.
static func spotted(before: World, after: World) -> Array[Vector2i]:
	var things: Array[Vector2i] = [after.stairs, after.elixir]
	things.append_array(after.peaches)
	things.append_array(Scrolls.spots(after))
	things.append_array(Jars.spots(after))
	for site: Dictionary in after.sites:
		if site.kind in [&"yard", Labyrinth.PRIZE, &"library"]:
			things.append(site.at)
	var out: Array[Vector2i] = []
	for p in things:
		if not Grid.inside(p):
			continue
		var i := Grid.index(p)
		var was := before.depth == after.depth and before.known.size() > i and before.known[i] == 1
		if (after.seen[i] == 1 or after.dim[i] == 1) and not was:
			out.append(p)
	return out


## Whether tile p is seen in `vis`.
static func sees(vis: PackedByteArray, p: Vector2i) -> bool:
	return Grid.inside(p) and vis[Grid.index(p)] == 1


## The mark the map draws by a creature: blind x, hunting !, searching ?, or none.
static func mark_of(a: Actor) -> String:
	if a.ailments.blind > 0:
		return "x"
	return Palette.ALERT_MARK[a.brain.alert]


## The popup a fact shows over its tile, or empty: {at, text, color, life}.
static func popup_of(fact: Dictionary) -> Dictionary:
	var at: Vector2i = fact.where
	match fact.t:
		&"hurt":
			return {at = at, text = str(fact.n), color = Palette.HURT, life = 0.9}
		&"notice":
			return {at = at, text = "!", color = Palette.ALERT[2], life = 0.9}
		&"heed":
			return {at = at, text = "?", color = Palette.ALERT[1], life = 0.9}
		&"drum":
			return {
				at = at, text = Lang.t("툭" if fact.wet else "둥"), color = Palette.SOUND, life = 1.2
			}
		&"card":
			return {
				at = at,
				text = Lang.t(Cards.GLYPH[fact.card], "talisman"),
				color = Palette.CARD[fact.card],
				life = 1.6
			}
		&"heal":
			if fact.get("n", World.HEAL) <= 0:
				return {}
			return {
				at = at,
				text = "+%d" % fact.get("n", World.HEAL),
				color = Palette.PEACH[1],
				life = 0.9
			}
		&"noise", &"shout":
			return {at = at, text = Lang.t(fact.word), color = Palette.SOUND, life = 1.4}
		&"find":
			var plate: Array = Palette.TILES[fact.kind]
			return {at = at, text = plate[0], color = plate[1], life = 1.6}
		&"trap":
			return {
				at = at, text = Lang.t(Traps.CLICK), color = Palette.TILES[fact.kind][1], life = 1.2
			}
	return {}
