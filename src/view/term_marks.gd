class_name TermMarks
extends RefCounted
## Lines Term draws over the map to show where spells will go.


## A charging creature's line for each spell (a spray's tiles), so every incoming
## spell is seen a round early; its edge has the caster's colour, so a line is told
## from another's and from fire. One running to a drum shows none: its info says so.
static func telegraphs(t: Term, actors: Dictionary) -> void:
	for id in actors:
		var a: Actor = actors[id]
		if a.is_miho() or not t._revealed(a.pos):
			continue
		for plan in a.intent:
			var spell := Spell.make(plan.cards)
			var ray := Forecast.ray(t.world, a.pos, plan.dir)
			if spell.shape == Spell.SPRAY:
				ray = Spray.cover(t.world, a, spell, plan.dir)
			elif spell.shape == Spell.LEAP:
				ray = ray.slice(0, spell.leap())
			elif not spell.orb:
				ray = ray.slice(0, Spell.RANGE)
			for k in ray.size():
				if not t._shown(ray[k]):
					continue
				var pulse := 0.5 + 0.5 * sin(t._time * 8.0 - k * 0.6)
				var c := Color(Palette.SIDE[a.faction], 0.16 + 0.14 * pulse)
				var tile := Rect2(t._cell(ray[k]) * Term.CELL, Term.CELL)
				t.draw_rect(tile, c)
				t.draw_rect(tile, Palette.KIND[a.kind], false, 1.0)
			if not ray.is_empty() and t._shown(a.pos + plan.dir):
				t._glyph(t._cell(a.pos + plan.dir), Palette.BOLT[plan.dir], Palette.KIND[a.kind])


## Where each projectile in sight flies next, over tiles Miho knows: an orb
## to the wall, a wisp to the end of its range, a homing orb one tile ahead.
static func paths(t: Term) -> void:
	for s in t.world.shots:
		if s.dir == Vector2i.ZERO or not t._revealed(s.pos):
			continue
		var ray := Forecast.ray(t.world, s.pos, s.dir)
		if s.turn > 0:
			ray = ray.slice(0, 1)
		elif not s.spell.orb:
			ray = ray.slice(0, maxi(0, Spell.RANGE - s.flown))
		var c := Palette.shot_color(s.spell, s.faction)
		for k in ray.size():
			var p := ray[k]
			if t.world.known[Grid.index(p)] == 0:
				break
			if t._shown(p):
				t.draw_rect(
					Rect2(t._cell(p) * Term.CELL, Term.CELL), Color(c, 0.22 - 0.1 * k / ray.size())
				)
				if k == 0:
					t._glyph(t._cell(p), Palette.BOLT[s.dir], Color(c, 0.8))
