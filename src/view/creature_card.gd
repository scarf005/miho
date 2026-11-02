class_name CreatureCard
extends RefCounted
## One creature in sight, as the sidebar and the touch screen's strip list it:
## glyph and name, hearts and status, then what it is doing and the spells it
## charges by name, or by talisman when the names do not fit, with where they aim
## (alone when both do not fit). SIDE_ROWS rows tall.


## Draws creature `a` with its top-left at cell `at`, `width` cells wide.
static func draw(t: Term, a: Actor, at: Vector2, width: float) -> void:
	if a.pos == t.cursor:
		t.draw_rect(
			Rect2(at * Term.CELL, Vector2(width, Term.SIDE_ROWS) * Term.CELL),
			Color(Palette.TEXT, 0.12)
		)
	t._glyph(at, Lang.t(a.info().glyph, "creature"), Palette.KIND[a.kind])
	t._text(at + Vector2(1.5, 0), Lang.t(a.info().name), Palette.KIND[a.kind])
	t._pips(at + Vector2(0, 1), a.hp, a.max_hp, Palette.HURT, int(width) - 1)
	t._status(at + Vector2(width - 1, 1), a)
	var doing: String = Info.doing(t.world, a) if a.blind <= 0 else Lang.t("눈멂")
	if a.fighting() and a.blind <= 0:
		doing = Lang.t("싸우는 중")
	var doing_runs := Keywords.runs(doing, Palette.ALERT[maxi(a.alert, 1)])
	var plans: Array = a.intent.map(func(p): return [Spell.make(p.cards), p.dir])
	var named := func(p: Array) -> float: return t._cells(p[0].shown()) + 1.5
	var wide: float = plans.reduce(func(n, p): return n + named.call(p), 0.0)
	var x := t._cells(doing) + 0.5
	if x + wide > width:
		x = 0.0
	else:
		var dx := 0.0
		for run: Array in doing_runs:
			dx += t._run(at + Vector2(dx, 2), run)
	var fits: bool = x + wide <= width
	for plan: Array in plans:
		var spell: Spell = plan[0]
		if fits:
			t._text(at + Vector2(x, 2), spell.shown(), Palette.card(spell.slots.back()))
			x += named.call(plan) - 1.5
		else:
			for slot: StringName in spell.slots:
				t._glyph(
					at + Vector2(x, 2), Lang.t(Cards.GLYPH[slot], "talisman"), Palette.card(slot)
				)
				x += 1
		t._glyph(at + Vector2(x, 2), Palette.BOLT[plan[1]], Palette.SIDE[1])
		x += 1.5 if fits else 1.0
