class_name DebugView
extends RefCounted
## The debug overlay's data, read from the whole world and never written to it:
## where every creature is bound (its target tile), Miho's scent trail, the
## sounds made this round and the tiles each reached, and the hidden state of
## a creature as hover lines (lists of [text, Color] runs, like Info).


## {goals: [{from, to, alert}], scent: tile -> freshness 0..1 (only trails a
## hunter would still follow), sounds: [{at, word, loud, heard, reach: tile ->
## steps, as far as the sound travelled around walls}]}.
static func view(w: World) -> Dictionary:
	var goals := []
	for a in w.actors:
		if a.alive() and a.faction != Actor.FOX and a.alert != Actor.REST:
			goals.append({from = a.pos, to = a.target, alert = a.alert})
	var scent := {}
	if w.scent.size() == w.tiles.size():
		for i in w.scent.size():
			var age := w.round_no + 1 - w.scent[i]
			if w.scent[i] > 0 and age <= Scent.TRAIL_AGE:
				scent[Grid.at(i)] = 1.0 - float(age) / (Scent.TRAIL_AGE + 1)
	var sounds := []
	for e in w.events:
		if e.t == &"noise":
			var found: Dictionary = Grid.search(e.at, Masks.heard(w), e.loud)
			var reach := {}
			for i in found.dist.size():
				if found.dist[i] >= 0:
					reach[Grid.at(i)] = found.dist[i]
			sounds.append({at = e.at, word = e.word, loud = e.loud, heard = e.heard, reach = reach})
	return {goals = goals, scent = scent, sounds = sounds}


## What hovering tile p tells with the overlay on: every tile, creatures
## wherever they are, with their hidden state.
static func at(w: World, p: Vector2i) -> Array:
	if not Grid.inside(p):
		return []
	var a := w.actor_at(p)
	if a != null:
		return Info.creature(w, a) + (creature(a) if a.faction != Actor.FOX else [])
	var lines := Info.terrain(w, p)
	var stamp := w.scent[Grid.index(p)] if w.scent.size() == w.tiles.size() else 0
	if stamp > 0:
		lines.append([["냄새 %d초 전" % (w.round_no + 1 - stamp), Palette.DIM]])
	return lines


## A creature's hidden state: what it is after, how long it has been without a
## trail, its spell clock and aim, and what it last made of Miho.
static func creature(a: Actor) -> Array:
	var resting := a.alert == Actor.REST
	var goal := a.home if resting else a.target
	var color: Color = Palette.ALERT[maxi(a.alert, 1)]
	var goal_text := "%s (%d, %d) %d칸"
	goal_text = goal_text % ["쉬는 곳" if resting else "목표", goal.x, goal.y, Grid.cheb(a.pos, goal)]
	var lines := [[["디버그 ", Palette.DIM], [goal_text, color]]]
	if not resting:
		lines.append([["놓친 지 %d/%d초" % [a.lost, World.SEARCH_ROUNDS], Palette.TEXT]])
	if not a.info().get("casts", []).is_empty():
		lines.append(_clock(a))
	if a.sees_me:
		lines.append([["당신을 본 걸로 안다", Palette.HURT]])
	else:
		lines.append([["당신을 못 본 걸로 안다", Palette.SIDE[0]]])
	return lines


## The spell clock: the aim and talismans being charged, else the wait left.
static func _clock(a: Actor) -> Array:
	if a.intent.is_empty():
		var text := "%d초 뒤 주술" % a.cooldown if a.cooldown > 0 else "주술 가능"
		return [[text, Palette.TEXT]]
	var cards := "".join(a.intent.map(func(c): return Cards.GLYPH[c]))
	return [["조준 %s %s" % [Palette.BOLT[a.aim], cards], Palette.HURT]]
