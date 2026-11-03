class_name CreatureCard
extends RefCounted
## One creature in sight, as the sidebar and the touch screen's strip list it:
## glyph and name, hearts and status, then what it is doing and the spells it
## charges by name, or by talisman when the names do not fit, with where they aim
## (alone when both do not fit). SIDE_ROWS rows tall. What it is doing and the spells are
## words (`row`, WordHover); the name above opens the box of the creature itself.


## Draws creature `a` with its top-left at cell `at`, `width` cells wide.
static func draw(t: Term, a: Actor, at: Vector2, width: float) -> void:
	if a.pos == t.cursor:
		t.draw_rect(
			Rect2(at * Term.CELL, Vector2(width, Term.SIDE_ROWS) * Term.CELL),
			Color(Palette.TEXT, 0.12)
		)
	t.draw_glyph(at, Lang.t(a.info().glyph, "creature"), Palette.glyph_color(a))
	t.draw_text(at + Vector2(1.5, 0), Lang.t(a.info().name), Palette.KIND[a.kind])
	t.draw_pips(at + Vector2(0, 1), a.hp, a.max_hp, Palette.HURT, int(width) - 1)
	t.draw_status(at + Vector2(width - 1, 1), a)
	var row3 := _third(t, a, width)
	var dx := 0.0
	for run: Array in row3.doing:
		dx += t.draw_run(at + Vector2(dx, 2), run)
	var x: float = row3.x
	for plan: Array in row3.plans:
		var spell: Spell = plan[0]
		if row3.fits:
			t.draw_text(at + Vector2(x, 2), spell.shown(), Palette.card(spell.slots.back()))
			x += _named(t, plan) - 1.5
		else:
			for slot: StringName in spell.slots:
				t.draw_glyph(
					at + Vector2(x, 2), Lang.t(Cards.GLYPH[slot], "talisman"), Palette.card(slot)
				)
				x += 1
		t.draw_glyph(at + Vector2(x, 2), Palette.BOLT[plan[1]], Palette.SIDE[1])
		x += 1.5 if row3.fits else 1.0


## The third row of a card `width` cells wide as runs at their columns, for the words of it.
static func row(t: Term, a: Actor, width: float) -> Array:
	var row3 := _third(t, a, width)
	var out := []
	var x := 0.0
	for run: Array in row3.doing:
		out.append(run + [x])
		x += t.text_cells(run[0])
	x = row3.x
	for plan: Array in row3.plans:
		var spell: Spell = plan[0]
		if row3.fits:
			out.append(
				SpellInfo.tagged(spell.shown(), Palette.card(spell.slots.back()), [spell]) + [x]
			)
			x += _named(t, plan)
		else:
			out.append(
				(
					SpellInfo.tagged(
						"".join(
							spell.slots.map(func(c): return Lang.t(Cards.GLYPH[c], "talisman"))
						),
						Palette.TEXT,
						[spell]
					)
					+ [x]
				)
			)
			x += spell.slots.size() + 1.0
	return out


## What the third row holds: `doing`, its runs (none when they and the spells do not fit), `x`
## where the spells start, `plans`, each [spell, direction], and `fits`, whether by name.
static func _third(t: Term, a: Actor, width: float) -> Dictionary:
	var doing: String = Info.doing(t.world, a) if a.ailments.blind <= 0 else Lang.t("눈멂")
	if a.fighting() and a.ailments.blind <= 0:
		doing = Lang.t("싸우는 중")
	var runs := Keywords.runs(doing, Palette.ALERT[maxi(a.brain.alert, 1)])
	var plans: Array = a.magic.intent.map(func(p): return [Bestiary.spell(a.kind, p.cards), p.dir])
	var wide: float = plans.reduce(func(n, p): return n + _named(t, p), 0.0)
	var x := t.text_cells(doing) + 0.5
	if x + wide > width:
		x = 0.0
		runs = []
	return {doing = runs, x = x, plans = plans, fits = x + wide <= width}


## Cells a spell of a plan takes by name, its arrow among them.
static func _named(t: Term, plan: Array) -> float:
	return t.text_cells(plan[0].shown()) + 1.5
