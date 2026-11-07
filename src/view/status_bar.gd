class_name StatusBar
extends RefCounted
## The two rows under the map. The upper one holds Miho's health, her tails
## (those the queued spells would spend in yellow) and their count, small as a
## shortcut's label is (Infra Arcana `draw_hp`), the saved spells by their
## slot keys, the storey and the time. The lower one holds the talismans by their
## number keys, the queue of MAX_SLOTS slots (a dim dot where no tail is left for
## another card), the compounds Miho can make now, the queued spell's name and
## the noise bar.

## Cells between two compound glyphs, so that a run does not read as a word.
const COMBO_GAP := 0.5


static func draw(t: Term) -> void:
	var w := t.world
	var me := w.player()
	var row := t.rows - 2
	t.draw_glyph(Vector2(0, row), "@", Palette.glyph_color(me))
	t.draw_pips(Vector2(1.5, row), me.hp, me.max_hp, Palette.HURT)
	var held := _held(t)
	tails(t, Vector2(Term.MAP.x, row))
	var right := Lang.t("%s %d초") % [Messages.storey(w.depth), w.round_no]
	t.draw_text(Vector2(t.cols - t.text_cells(right), row), right, Palette.TEXT)
	if not t.debug.is_empty():
		t.draw_text(debug_label(t).position, Lang.t("디버그"), Palette.SOUND)
	buffs(t, Vector2(t.cols - t.text_cells(right) - 1.0, row))
	for slot in saved_slots(t):
		var spell := Spell.from_key(t.saved[slot.action])
		var ready := _castable(t, spell, held)
		t.draw_key(Vector2(slot.x, row), slot.key, Palette.KEY if ready else Palette.DIM)
		for k in spell.slots.size():
			var c := Palette.card(spell.slots[k])
			t.draw_glyph(
				Vector2(slot.x + Term.key_cells(slot.key) + k, row),
				Lang.t(Cards.GLYPH[spell.slots[k]], "talisman"),
				c if ready else c * 0.4
			)
	row += 1
	var queued := Spell.make(t.picked)
	for i in w.cards.size():
		var card := w.cards[i]
		var x := Term.MAP.x + i * 3
		if queued != null and queued.cards.has(card):
			t.draw_rect(
				Rect2(Vector2(x, row) * Term.CELL, Vector2(2, 1) * Term.CELL),
				Palette.CARD[card] * 0.45
			)
		t.draw_key(Vector2(x + 0.5, row), str(i + 1))
		t.draw_glyph(Vector2(x + 1, row), Lang.t(Cards.GLYPH[card], "talisman"), Palette.CARD[card])
	var slots: Array[StringName] = []
	if queued != null:
		slots = queued.slots
	for i in Spell.MAX_SLOTS:
		var at := Vector2(queue_x(t) + i, row)
		if i < slots.size():
			var c := Palette.card(slots[i])
			t.draw_rect(Rect2(at * Term.CELL, Term.CELL).grow(-2), c * 0.35)
			t.draw_glyph(at, Lang.t(Cards.GLYPH[slots[i]], "talisman"), c)
		else:
			t.draw_glyph(at, "·", Palette.TEXT if fits(t, i - slots.size() + 1) else Palette.DIM)
	for combo in combos(t):
		if combo.c == &"":
			t.draw_text(Vector2(combo.x, row), "+%d" % combo.more, Palette.DIM)
			continue
		t.draw_glyph(
			Vector2(combo.x, row), Lang.t(Cards.GLYPH[combo.c], "talisman"), Palette.card(combo.c)
		)
	var name := _name(t, queued)
	var at := title_at(t, name)
	if at.y < row:
		t.draw_rect(
			Rect2(at * Term.CELL, Vector2(t.text_cells(name), 1) * Term.CELL),
			Color(Palette.VOID, 0.85)
		)
	t.draw_text(at, name, Palette.TEXT)
	NoiseMeter.draw(t)


## Miho's tails from cell `at`, those the queue and the spells held with Shift would spend
## in yellow, then how many she has.
static func tails(t: Term, at: Vector2) -> void:
	var w := t.world
	var held := _held(t)
	for i in w.max_tails():
		var c: Color = Palette.SIDE[0]
		if i >= w.tails:
			c = Palette.DIM
		elif i >= w.tails - held:
			c = Palette.CARD[Cards.EARTH]
		t.draw_glyph(at + Vector2(i, 0), "~", c)
	t.draw_key(at + Vector2(w.max_tails(), 0), str(w.tails))


## The names of the buffs on Miho, the elixir she carries and the curses on the storey
## (Curse), ending at `end`: they have no time to run out, so the row keeps telling them.
## The debug label takes the place on that row.
static func buffs(t: Term, end: Vector2) -> void:
	if not t.debug.is_empty():
		return
	var at := end
	for kind: StringName in Guise.worn(t.world, t.world.player()):
		var name := Lang.t(Guise.NAME[kind])
		at.x -= t.text_cells(name) + 1.0
		var last: StringName = Spell.make(Guise.RECIPE[kind]).slots.back()
		t.draw_text(at, name, Palette.card(last))
	for kind: StringName in Curse.worn(t.world):
		var name := Lang.t(Curse.NAME[kind])
		at.x -= t.text_cells(name) + 1.0
		t.draw_text(at, name, Palette.BAD)
	if t.world.elixir_held:
		var name := Lang.t(Elixir.NAME)
		at.x -= t.text_cells(name) + 1.0
		t.draw_text(at, name, Palette.ELIXIR[1])


## The cells of the debug label, left of the storey and time on the upper row.
static func debug_label(t: Term) -> Rect2:
	var right := Lang.t("%s %d초") % [Messages.storey(t.world.depth), t.world.round_no]
	var width := t.text_cells(Lang.t("디버그"))
	return Rect2(t.cols - t.text_cells(right) - width - 1, t.rows - 2, width, 1)


## Whether a point in the term's space is on the debug label, which is shown while the
## debug view is on.
static func debug_at(t: Term, local: Vector2) -> bool:
	return not t.debug.is_empty() and debug_label(t).has_point(local / Term.CELL)


## Tails the spells held with Shift and the queue spend.
static func _held(t: Term) -> int:
	var staged: int = t.staged.reduce(func(n, s): return n + Spell.price(s.cards.size()), 0)
	return staged + Spell.price(t.picked.size())


## Whether Miho has the tails for `n` more cards in the queue.
static func fits(t: Term, n: int) -> bool:
	var staged := _held(t) - Spell.price(t.picked.size())
	return staged + Spell.price(t.picked.size() + n) <= Cheat.tails(t.world)


## Where the queue's first slot is drawn on the lower row.
static func queue_x(t: Term) -> float:
	return Term.MAP.x + t.world.cards.size() * 3 + 1.0


## The queued spell's name as drawn, with the count of spells held with Shift.
static func _name(t: Term, spell: Spell) -> String:
	var name := spell.shown() if spell != null else ""
	return "+%d %s" % [t.staged.size(), name] if not t.staged.is_empty() else name


## Where the queued spell's name starts: on the lower row between the queue and
## the noise bar when it fits there, else flush right on the map row above them.
static func title_at(t: Term, name: String) -> Vector2:
	var bar := NoiseMeter.at(t)
	var end: float = bar.x - 0.5 if bar.y == t.rows - 1 else float(t.cols)
	var x := end - t.text_cells(name)
	if x >= queue_x(t) + Spell.MAX_SLOTS + 0.5:
		return Vector2(x, t.rows - 1)
	return Vector2(maxf(0.0, t.cols - t.text_cells(name)), mini(t.rows - 3, int(bar.y) - 1))


## The compounds Miho can make now: all their elements held and the tails for
## them at her most, in tier order.
static func makeable(w: World) -> Array:
	return Cards.compounds().filter(
		func(c):
			var parts := Cards.spell_of(c)
			return parts.all(w.cards.has) and Spell.price(parts.size()) <= w.max_tails()
	)


## The compounds drawn after the queue, as {c, x}: as many as fit before the
## spell's name and the noise bar, the name keeping its place, then {c = &""}
## for the ones left out.
static func combos(t: Term) -> Array:
	var out := []
	if t.world == null:
		return out
	var list := makeable(t.world)
	var start := queue_x(t) + Spell.MAX_SLOTS + 1.0
	var end := float(t.cols)
	var bar := NoiseMeter.at(t)
	if bar.y == t.rows - 1:
		end = bar.x - 0.5
	var name := _name(t, Spell.make(t.picked))
	if name != "" and title_at(t, name).y == t.rows - 1:
		end = minf(end, title_at(t, name).x - 1.0)
	var room := end - start
	var step := 1.0 + COMBO_GAP
	var shown := list.size()
	if shown * step - COMBO_GAP > room:
		shown = maxi(0, floori((room - Term.text_cells("+%d" % list.size())) / step))
	for i in shown:
		out.append({c = list[i], x = start + i * step})
	if shown < list.size() and room > 0:
		out.append({c = &"", x = start + shown * step, more = list.size() - shown})
	return out


## Saved spells on the upper row: {action, key, x, width}, left to right.
static func saved_slots(t: Term) -> Array:
	var out := []
	if t.world == null:
		return out
	var x := tails_end(t) + 1.0
	for action in Keys.SLOTS:
		if not t.saved.has(action):
			continue
		var keys := Keys.keys_of(action)
		var key := Keys.label(keys[0]) if not keys.is_empty() else ""
		var width: float = Term.key_cells(key) + Spell.from_key(t.saved[action]).slots.size()
		out.append({action = action, key = key, x = x, width = width})
		x += width + 1.0
	return out


## Whether Miho has a spell's talismans and the tails for it beside `held`.
static func _castable(t: Term, spell: Spell, held: int) -> bool:
	return (
		not Guise.mixed(spell)
		and spell.cards.all(func(c): return t.world.cards.has(c))
		and spell.cost() + held <= Cheat.tails(t.world)
	)


## The saved spell under a point in the term's space, or empty.
static func slot_at(t: Term, local: Vector2) -> String:
	var c := local / Term.CELL
	if floori(c.y) != t.rows - 2:
		return ""
	for slot in saved_slots(t):
		if c.x >= slot.x and c.x < slot.x + slot.width:
			return t.saved[slot.action]
	return ""


## The queued spell's key when a point is on its name or a filled queue slot, else empty.
static func hand_at(t: Term, local: Vector2) -> String:
	var spell := Spell.make(t.picked)
	if spell == null:
		return ""
	var c := local / Term.CELL
	var label := _name(t, spell)
	var name := title_at(t, label)
	var on_name := (
		floori(c.y) == int(name.y) and c.x >= name.x and c.x < name.x + t.text_cells(label)
	)
	return spell.key() if on_name or queue_at(t, local) >= 0 else ""


## The filled queue slot under a point in the term's space, or -1.
static func queue_at(t: Term, local: Vector2) -> int:
	var spell := Spell.make(t.picked)
	if spell == null or floori(local.y / Term.CELL.y) != t.rows - 1:
		return -1
	var i := floori(local.x / Term.CELL.x - queue_x(t))
	return i if i >= 0 and i < spell.slots.size() else -1


## Where the tails and their count end on the upper row: the count takes the cells
## of the most there can be, so that the saved spells after it stay where they are.
static func tails_end(t: Term) -> float:
	return Term.MAP.x + t.world.max_tails() + Term.key_cells(str(t.world.max_tails()))


## Whether a point in the term's space is on Miho's health, tails or their count.
static func status_at(t: Term, local: Vector2) -> bool:
	var c := local / Term.CELL
	return floori(c.y) == t.rows - 2 and t.world != null and c.x >= 0 and c.x < tails_end(t)


## The talisman under a point in the term's space, or empty.
static func card_at(t: Term, local: Vector2) -> StringName:
	var c := Vector2i((local / Term.CELL).floor())
	if c.y != t.rows - 1 or t.world == null:
		return &""
	var i := (c.x - Term.MAP.x) / 3
	if c.x < Term.MAP.x or i >= t.world.cards.size():
		return &""
	return t.world.cards[i]


## The compound under a point in the term's space, or empty.
static func combo_at(t: Term, local: Vector2) -> StringName:
	var c := local / Term.CELL
	if floori(c.y) != t.rows - 1:
		return &""
	for combo in combos(t):
		if c.x >= combo.x and c.x < combo.x + 1.0:
			return combo.c
	return &""


## The key of the spell a click under a point fills the queue with, or empty: a saved
## spell's, or a compound's.
static func preset_at(t: Term, local: Vector2) -> String:
	var combo := combo_at(t, local)
	return Spell.make(Cards.spell_of(combo)).key() if combo != &"" else slot_at(t, local)


## The talisman or compound under a point in the term's space, or empty.
static func talisman_at(t: Term, local: Vector2) -> StringName:
	var card := card_at(t, local)
	return card if card != &"" else combo_at(t, local)
