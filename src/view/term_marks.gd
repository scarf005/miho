class_name TermMarks
extends RefCounted
## Lines Term draws over the map to show where spells will go.

## How many times a bolt flickers, the seconds between and the zigzag it draws in a cell.
const ZAPS := 3
const ZAP_GAP := 0.07
const ZIGZAG := [Vector2(0.65, 0.05), Vector2(0.3, 0.52), Vector2(0.6, 0.52), Vector2(0.35, 0.95)]


## A charging creature's line for each spell (a spray's tiles), so every incoming
## spell is seen a round early; its edge has the caster's colour, so a line is told
## from another's and from fire. One running to a drum shows none: its info says so.
static func telegraphs(t: Term, actors: Dictionary) -> void:
	for id in actors:
		var a: Actor = actors[id]
		if a.is_miho() or not t.revealed(a.pos):
			continue
		for plan in a.magic.intent:
			var spell := Spell.make(plan.cards)
			var ray := Forecast.ray(t.world, a.pos, plan.dir)
			if spell.shape == Spell.SPRAY:
				ray = Spray.cover(t.world, a, spell, plan.dir)
			elif spell.shape == Spell.LEAP:
				ray = ray.slice(0, spell.leap())
			elif not spell.orb:
				ray = ray.slice(0, Spell.RANGE)
			for k in ray.size():
				if not t.in_view(ray[k]):
					continue
				var pulse := 0.5 + 0.5 * sin(t.sway * 8.0 - k * 0.6)
				var c := Color(Palette.SIDE[a.faction], 0.16 + 0.14 * pulse)
				var tile := Rect2(t.cell_of(ray[k]) * Term.CELL, Term.CELL)
				t.draw_rect(tile, c)
				t.draw_rect(tile, Palette.KIND[a.kind], false, 1.0)
			if not ray.is_empty() and t.in_view(a.pos + plan.dir):
				t.draw_glyph(
					t.cell_of(a.pos + plan.dir), Palette.BOLT[plan.dir], Palette.KIND[a.kind]
				)


## Where each projectile in sight flies next, over tiles Miho knows: an orb
## to the wall, a wisp to the end of its range, a homing orb one tile ahead.
static func paths(t: Term) -> void:
	for s in t.world.shots:
		if s.dir == Vector2i.ZERO or not t.revealed(s.pos):
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
			if t.in_view(p):
				t.draw_rect(
					Rect2(t.cell_of(p) * Term.CELL, Term.CELL),
					Color(c, 0.22 - 0.1 * k / ray.size())
				)
				if k == 0:
					t.draw_glyph(t.cell_of(p), Palette.BOLT[s.dir], Color(c, 0.8))


## A bolt on tile `at`: its streak flickers white and yellow a few times (Palette.ZAP).
static func bolt(t: Term, at: Vector2i) -> void:
	for k in ZAPS:
		t.anim.flash(at, Palette.ZAP[k % Palette.ZAP.size()], ZAP_GAP * k, true)


## The zigzag of lightning across a cell: the pixel font has no glyph for it.
static func zigzag(t: Term, cell: Vector2, color: Color) -> void:
	var at := cell * Term.CELL
	var points := PackedVector2Array()
	for p: Vector2 in ZIGZAG:
		points.append(at + p * Term.CELL)
	t.draw_polyline(points, color, 2.0)
