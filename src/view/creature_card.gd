class_name CreatureCard
extends RefCounted
## One creature in sight, as the sidebar and the touch screen's strip list it:
## glyph and name, hearts and status, then what it is doing and the spells it
## charges, aimed (alone when both do not fit). SIDE_ROWS rows tall.


## Draws creature `a` with its top-left at cell `at`, `width` cells wide.
static func draw(t: Term, a: Actor, at: Vector2, width: float) -> void:
	if a.pos == t.cursor:
		t.draw_rect(
			Rect2(at * Term.CELL, Vector2(width, Term.SIDE_ROWS) * Term.CELL),
			Color(Palette.TEXT, 0.12)
		)
	t._glyph(at, a.info().glyph, Palette.KIND[a.kind])
	t._text(at + Vector2(1.5, 0), a.info().name, Palette.KIND[a.kind])
	t._pips(at + Vector2(0, 1), a.hp, a.max_hp, Palette.HURT, int(width) - 1)
	t._status(at + Vector2(width - 1, 1), a)
	var doing: String = Info.state(a) if a.blind <= 0 else "눈멂"
	if a.fighting() and a.blind <= 0:
		doing = "싸우는 중"
	var doing_runs := Keywords.runs(doing, Palette.ALERT[maxi(a.alert, 1)])
	var plans := a.intent.map(func(p): return [Spell.make(p.cards).slots, p.dir])
	var x := t._cells(doing) + 0.5
	if x + plans.reduce(func(n, p): return n + p[0].size() + 1, 0) > width:
		x = 0.0
	else:
		var dx := 0.0
		for run: Array in doing_runs:
			dx += t._run(at + Vector2(dx, 2), run)
	for plan: Array in plans:
		for slot: StringName in plan[0]:
			t._glyph(at + Vector2(x, 2), Cards.GLYPH[slot], Palette.card(slot))
			x += 1
		t._glyph(at + Vector2(x, 2), Palette.BOLT[plan[1]], Palette.SIDE[1])
		x += 1
