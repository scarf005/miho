class_name StatusBar
extends RefCounted
## The two rows under the map. The upper one holds Miho's health, her tails
## (those the queued spells would spend in yellow), the saved spells by their
## slot keys, the storey and the time. The lower one holds the talismans by their
## number keys, the queue of MAX_SLOTS slots (a dim dot where no tail is left for
## another card), the queued spell's name and the noise bar.


static func draw(t: Term) -> void:
	var w := t.world
	var me := w.player()
	var row := t.rows - 2
	t._glyph(Vector2(0, row), "@", Palette.KIND[&"miho"])
	t._pips(Vector2(1.5, row), me.hp, me.max_hp, Palette.HURT)
	var held := _held(t) + t.picked.size()
	for i in w.max_tails():
		var c: Color = Palette.SIDE[0]
		if i >= w.tails:
			c = Palette.DIM
		elif i >= w.tails - held:
			c = Palette.CARD[Cards.EARTH]
		t._glyph(Vector2(Term.MAP.x + i, row), "~", c)
	var right := "%d층 %d초" % [w.depth, w.round_no]
	t._text(Vector2(t.cols - t._cells(right), row), right, Palette.TEXT)
	if not t.debug.is_empty():
		t._text(Vector2(t.cols - t._cells(right) - t._cells("디버그") - 1, row), "디버그", Palette.SOUND)
	for slot in saved_slots(t):
		var spell := Spell.from_key(t.saved[slot.action])
		var ready := _castable(t, spell, held)
		t._small(Vector2(slot.x, row + 0.05), slot.key, Palette.TEXT if ready else Palette.DIM)
		for k in spell.slots.size():
			var c := Palette.card(spell.slots[k])
			t._glyph(
				Vector2(slot.x + 0.5 + k, row), Cards.GLYPH[spell.slots[k]], c if ready else c * 0.4
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
		t._small(Vector2(x, row + 0.05), str(i + 1), Palette.DIM)
		t._glyph(Vector2(x + 1, row), Cards.GLYPH[card], Palette.CARD[card])
	var slots: Array[StringName] = []
	if queued != null:
		slots = queued.slots
	var room := w.tails - held
	for i in Spell.MAX_SLOTS:
		var at := Vector2(queue_x(t) + i, row)
		if i < slots.size():
			var c := Palette.card(slots[i])
			t.draw_rect(Rect2(at * Term.CELL, Term.CELL).grow(-2), c * 0.35)
			t._glyph(at, Cards.GLYPH[slots[i]], c)
		else:
			t._glyph(at, "·", Palette.TEXT if i - slots.size() < room else Palette.DIM)
	var name := _name(t, queued)
	var at := title_at(t, name)
	if at.y < row:
		t.draw_rect(
			Rect2(at * Term.CELL, Vector2(t._cells(name), 1) * Term.CELL), Color(Palette.VOID, 0.85)
		)
	t._text(at, name, Palette.TEXT)
	NoiseMeter.draw(t)


## Tails the spells held with Shift spend.
static func _held(t: Term) -> int:
	return t.staged.reduce(func(n, s): return n + s.cards.size(), 0)


## Where the queue's first slot is drawn on the lower row.
static func queue_x(t: Term) -> float:
	return Term.MAP.x + t.world.cards.size() * 3 + 1.0


## The queued spell's name as drawn, with the count of spells held with Shift.
static func _name(t: Term, spell: Spell) -> String:
	var name := spell.title() if spell != null else ""
	return "+%d %s" % [t.staged.size(), name] if not t.staged.is_empty() else name


## Where the queued spell's name starts: on the lower row between the queue and
## the noise bar when it fits there, else flush right on the map row above them.
static func title_at(t: Term, name: String) -> Vector2:
	var bar := NoiseMeter.at(t)
	var end: float = bar.x - 0.5 if bar.y == t.rows - 1 else float(t.cols)
	var x := end - t._cells(name)
	if x >= queue_x(t) + Spell.MAX_SLOTS + 0.5:
		return Vector2(x, t.rows - 1)
	return Vector2(maxf(0.0, t.cols - t._cells(name)), mini(t.rows - 3, int(bar.y) - 1))


## Saved spells on the upper row: {action, key, x, width}, left to right.
static func saved_slots(t: Term) -> Array:
	var out := []
	if t.world == null:
		return out
	var x := Term.MAP.x + t.world.max_tails() + 1.0
	for action in Keys.SLOTS:
		if not t.saved.has(action):
			continue
		var keys := Keys.keys_of(action)
		var width := 0.5 + Spell.from_key(t.saved[action]).slots.size()
		out.append(
			{
				action = action,
				key = Keys.label(keys[0]) if not keys.is_empty() else "",
				x = x,
				width = width
			}
		)
		x += width + 1.0
	return out


## Whether Miho has a spell's talismans and the tails for it beside `held`.
static func _castable(t: Term, spell: Spell, held: int) -> bool:
	return (
		spell.cards.all(func(c): return t.world.cards.has(c))
		and spell.cost() + held <= t.world.tails
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
	var on_name := floori(c.y) == int(name.y) and c.x >= name.x and c.x < name.x + t._cells(label)
	return spell.key() if on_name or queue_at(t, local) >= 0 else ""


## The filled queue slot under a point in the term's space, or -1.
static func queue_at(t: Term, local: Vector2) -> int:
	var spell := Spell.make(t.picked)
	if spell == null or floori(local.y / Term.CELL.y) != t.rows - 1:
		return -1
	var i := floori(local.x / Term.CELL.x - queue_x(t))
	return i if i >= 0 and i < spell.slots.size() else -1


## Whether a point in the term's space is on Miho's health or tails.
static func status_at(t: Term, local: Vector2) -> bool:
	var c := Vector2i((local / Term.CELL).floor())
	return (
		c.y == t.rows - 2
		and t.world != null
		and c.x >= 0
		and c.x < Term.MAP.x + t.world.max_tails()
	)


## The talisman under a point in the term's space, or empty.
static func card_at(t: Term, local: Vector2) -> StringName:
	var c := Vector2i((local / Term.CELL).floor())
	if c.y != t.rows - 1 or t.world == null:
		return &""
	var i := (c.x - Term.MAP.x) / 3
	if c.x < Term.MAP.x or i >= t.world.cards.size():
		return &""
	return t.world.cards[i]
