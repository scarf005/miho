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
		if a.alive() and a.faction != Actor.FOX and a.brain.alert != Actor.REST:
			goals.append({from = a.pos, to = a.brain.target, alert = a.brain.alert})
	var scent := {}
	if w.scent.size() == w.tiles.size():
		for i in w.scent.size():
			var age := w.round_no + 1 - w.scent[i]
			var limit := Scent.reach(w, Grid.at(i))
			if w.scent[i] > 0 and age <= limit:
				scent[Grid.at(i)] = 1.0 - float(age) / (limit + 1)
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


## Draws the overlay on `t` from t.debug: Miho's scent trail (fresher is
## brighter), the tiles each sound of this round reached with its edge and
## word marked, and for each creature on the hunt or search a line to the tile
## it is bound for. It adds no popup or mark: those are Perceived's.
static func draw(t: Term) -> void:
	for p: Vector2i in t.debug.get("scent", {}):
		if t.in_view(p):
			var tint := Color(Palette.SIDE[0], 0.06 + 0.3 * t.debug.scent[p])
			t.draw_rect(Rect2(t.cell_of(p) * Term.CELL, Term.CELL), tint)
	for s: Dictionary in t.debug.get("sounds", []):
		for p: Vector2i in s.reach:
			if t.in_view(p):
				var edge: bool = s.reach[p] == s.loud
				var c := Color(Palette.SOUND, 0.22 if edge else 0.05)
				t.draw_rect(Rect2(t.cell_of(p) * Term.CELL, Term.CELL), c)
		if t.in_view(s.at):
			t.draw_small(t.cell_of(s.at), Lang.t(s.word), Palette.SOUND)
	for g: Dictionary in t.debug.get("goals", []):
		var c: Color = Palette.ALERT[g.alert]
		if t.in_view(g.from) and t.in_view(g.to):
			t.draw_line(t.cell_centre(g.from), t.cell_centre(g.to), Color(c, 0.4), 2.0)
		if t.in_view(g.to):
			var box := Rect2(t.cell_of(g.to) * Term.CELL, Term.CELL).grow(-6)
			t.draw_rect(box, Color(c, 0.9), false, 2.0)


## What hovering tile p tells with the overlay on: every tile, creatures
## wherever they are, with their hidden state, and projectiles wherever they fly.
static func at(w: World, p: Vector2i) -> Array:
	if not Grid.inside(p):
		return []
	var a := w.actor_at(p)
	if a != null:
		return Info.creature(w, a) + (creature(a) if a.faction != Actor.FOX else [])
	var s := shot_at(w, p)
	if s != null:
		return SpellInfo.shot(w, s)
	var lines := Info.terrain(w, p)
	var stamp := w.scent[Grid.index(p)] if w.scent.size() == w.tiles.size() else 0
	if stamp > 0:
		lines.append([[Lang.t("냄새 %d초 전") % (w.round_no + 1 - stamp), Palette.DIM]])
	return lines


## The projectile `at` tells of on tile p: one with no creature on its tile.
static func shot_at(w: World, p: Vector2i) -> Shot:
	return w.shot_at(p) if w.actor_at(p) == null else null


## A creature's hidden state: what it is after, how long it has been without a
## trail, and its spell clock and aim.
static func creature(a: Actor) -> Array:
	var resting := a.brain.alert == Actor.REST
	var goal := a.brain.home if resting else a.brain.target
	var color: Color = Palette.ALERT[maxi(a.brain.alert, 1)]
	var goal_text := Lang.t("%s (%d, %d) %d칸")
	goal_text = (
		goal_text % [Lang.t("쉬는 곳" if resting else "목표"), goal.x, goal.y, Grid.cheb(a.pos, goal)]
	)
	var lines := [[[Lang.t("디버그 "), Palette.DIM], [goal_text, color]]]
	if not resting:
		lines.append([[Lang.t("놓친 지 %d/%d초") % [a.brain.lost, World.SEARCH_ROUNDS], Palette.TEXT]])
	if not a.repertoire().is_empty():
		lines.append(_clock(a))
	return lines


## The spell clock: the aim and talismans being charged, else the wait left.
static func _clock(a: Actor) -> Array:
	if a.magic.intent.is_empty():
		var text := (
			Lang.t("%d초 뒤 주술") % a.magic.cooldown if a.magic.cooldown > 0 else Lang.t("주술 가능")
		)
		if Bestiary.mana(a.kind) > 0:
			text = Lang.t("마력 %d/%d") % [a.magic.mana, Bestiary.mana(a.kind)]
		return [[text, Palette.TEXT]]
	var glyphs := func(cards: Array) -> String:
		return "".join(cards.map(func(c): return Lang.t(Cards.GLYPH[c], "talisman")))
	var aimed := a.magic.intent.map(
		func(plan): return "%s %s" % [Palette.BOLT[plan.dir], glyphs.call(plan.cards)]
	)
	return [[Lang.t("조준 %s") % " ".join(aimed), Palette.HURT]]
