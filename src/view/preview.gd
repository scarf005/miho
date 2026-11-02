class_name Preview
extends RefCounted
## What the screen shows under the pointer for the game `m` (main.gd): what is
## there, the tiles a creature there sees, what the spell in hand would do hurled
## that way (each aim forecast once), or with nothing in hand the walk a click
## there would take.


## The pointer moved to the screen point: what it is over (a tile, a talisman,
## the status, a saved spell, a queue slot, a page row, a word) and, when that
## changed, the screen again. The page rows do not light while a box is kept
## (WordHover.hold); the tile and the rest are followed all the same, so a click
## acts on what is under the pointer.
static func point(m: Node, screen: Vector2) -> void:
	var term: Term = m.term
	var hinted := not term.hint.is_empty()
	var local: Vector2 = m._local(screen)
	if m.overlay != &"" and term.pin.is_empty():
		m.menu.point(PanelView.row_at(term, local))
		m.menu.codex.lit = PanelView.choice_at(term, local)
		term.panel = m.menu.panel()
	var tile := term.tile_at(local)
	if not Grid.inside(tile):
		tile = term.side_at(local)
	var card: StringName = term.bar.talisman_at(term, local)
	var status: bool = term.bar.status_at(term, local)
	var spell: String = term.bar.slot_at(term, local) + term.bar.hand_at(term, local)
	var slot: int = term.bar.queue_at(term, local)
	term.hint = WordHover.at(term, local)
	term.hint_at = local / Term.CELL
	if (
		hinted == term.hint.is_empty()
		or tile != m.hover
		or card != m.hover_card
		or status != m.hover_status
		or spell != m.hover_spell
		or slot != m.hover_slot
	):
		m.hover = tile
		m.hover_card = card
		m.hover_status = status
		m.hover_spell = spell
		m.hover_slot = slot
		if m.state == &"play" and not m.busy:
			m._refresh()


static func paint(m: Node) -> void:
	var world: World = m.world
	var term: Term = m.term
	_inspect(m)
	term.debug = DebugView.view(world) if m.debugging else {}
	term.zone = m.zone
	term.picked = m.picked
	term.staged = m.staged
	var tints: Dictionary = m.reach.duplicate()
	var marks := {}
	term.lines = []
	var me := world.player().pos
	for d: Vector2i in m.ahead:
		var f: Forecast = m.ahead[d]
		if f.drops_me():
			marks[me + d] = ["▼", Palette.HURT]
		elif f.hurt_me() > 0:
			marks[me + d] = [str(f.hurt_me()), Palette.HURT]
		elif not f.noticed.is_empty():
			tints[me + d] = Color(Palette.ALERT[2], 0.3)
	var hover: Vector2i = m.hover
	if not m.reach.is_empty() and Grid.inside(hover) and hover != me:
		var aim := Grid.nearest_dir(hover - me)
		if not m.aims.has(aim):
			var spells: Array = m.staged.duplicate()
			spells.append({cards = m.picked.duplicate(), dir = aim})
			m.aims[aim] = Forecast.of(world, {t = &"cast", spells = spells})
		AimView.paint(m.aims[aim], world, m.known, term, tints, marks)
	elif (
		m.picked.is_empty()
		and m.staged.is_empty()
		and Grid.inside(hover)
		and Grid.cheb(hover, me) > 1
	):
		for p in m._path_to(hover):
			tints[p] = Color(Palette.TEXT, 0.12)
	var a := world.actor_at(hover) if Grid.inside(hover) else null
	if a != null and a.faction != Actor.FOX and Hat.shown(world, a):
		var view: PackedByteArray = m.known.view_of(a)
		for i in view.size():
			if view[i] == 1 and world.known[i] == 1 and not tints.has(Grid.at(i)):
				tints[Grid.at(i)] = Color(Palette.SIDE[1], 0.3)
	if m.hover_status or hover == me:
		for i in world.seen.size():
			if world.seen[i] == 1 and not tints.has(Grid.at(i)):
				tints[Grid.at(i)] = Color(Palette.SIDE[0], 0.2)
	for b in world.actors:
		if Fight.sneakable(world, b):
			tints[b.pos] = Color(Palette.ALERT[1], 0.35)
	term.tints = tints
	term.marks = marks


static func _inspect(m: Node) -> void:
	var term: Term = m.term
	if not term.pin.is_empty():
		return
	term.info = []
	term.subject = ""
	term.cursor = Vector2i(-1, -1)
	var example := {}
	if m.state == &"play" and m.overlay == &"" and term.hint.is_empty():
		example = _tell(m)
	term.example = example


## Sets what the box under the pointer tells (`info`), and returns the example of the one
## spell it is about, or none.
static func _tell(m: Node) -> Dictionary:
	var held := Spell.make(m.picked)
	if held == null or m.hover_slot >= held.slots.size():
		m.hover_slot = -1
	var term: Term = m.term
	term.cursor = m.hover
	var lines := _lines(m)
	var word := subject(m) if not lines.is_empty() else ""
	var row := detail_row()
	var shown: bool = word != "" and not row.is_empty() and not m.touch.enabled
	term.info = lines + [row] if shown else lines
	term.subject = word
	return _example(m)


## The example of the one spell the box tells of, or none: Miho casts hers, and a creature
## its own.
static func _example(m: Node) -> Dictionary:
	var cards := []
	if m.hover_slot >= 0:
		cards = m.picked
	elif m.hover_spell != "":
		cards = Spell.from_key(m.hover_spell).cards
	elif m.hover_card != &"":
		cards = Cards.made_of(m.hover_card)
	elif not m.hover_status:
		var shot: Shot = m.world.shot_at(m.hover) if m.debugging else Info.shot_at(m.known, m.hover)
		if shot != null and shot.faction != Actor.FOX:
			var by: Actor = m.world.actor(shot.caster)
			return CodexScene.charged(by.kind if by != null else Codex.foes()[0], shot.spell.cards)
		if shot != null:
			cards = shot.spell.cards
	return SpellScene.of(cards) if not cards.is_empty() else {}


## The hover lines of what the pointer or the look cursor is over.
static func _lines(m: Node) -> Array:
	if m.hover_slot >= 0:
		return SpellInfo.slot(Spell.make(m.picked), m.hover_slot)
	if m.hover_spell != "":
		return SpellInfo.spell(Spell.from_key(m.hover_spell))
	if m.hover_card != &"":
		return SpellInfo.hovered(m.hover_card, m.picked)
	if m.hover_status:
		return Info.creature(m.known, m.known.player())
	var lines: Array = DebugView.at(m.world, m.hover) if m.debugging else Info.at(m.known, m.hover)
	return (
		m.menu.debug.head()
		+ lines
		+ m.excluded.lines(m.hover, m.zone)
		+ Info.ahead(m.world, m.ahead, m.hover)
	)


## The name of the 도감 entry that the box of `_lines` tells of, or empty when it
## has none (Miho herself, a tile Miho does not know). The debug view knows all. It is
## taken from the thing itself, in the order of `_lines`: a queue slot is its
## spell when that is one talisman, else the talisman at the slot; a saved spell
## its name; a talisman itself; a creature its kind; a projectile its spell; a
## tile what lies on it.
static func subject(m: Node) -> String:
	var word := _named(m)
	return word if word != "" and Keywords.locate(word).x >= 0 else ""


static func _named(m: Node) -> String:
	if m.hover_slot >= 0:
		var s := Spell.make(m.picked)
		if s == null:
			return ""
		return _spell(s) if s.cards.size() == 1 else _talisman(s.slots[m.hover_slot])
	if m.hover_spell != "":
		var s := Spell.from_key(m.hover_spell)
		return "" if s == null else _spell(s)
	if m.hover_card != &"":
		return _talisman(m.hover_card)
	if m.hover_status or not Grid.inside(m.hover):
		return ""
	var w: World = m.world if m.debugging else m.known
	var i := Grid.index(m.hover)
	if m.debugging or w.seen[i] == 1:
		var a := w.actor_at(m.hover)
		if a != null and (m.debugging or Hat.shown(w, a)):
			return "" if a.is_miho() else Lang.t(a.info().name)
		var shot := w.shot_at(m.hover)
		if shot != null:
			return _spell(shot.spell, shot.faction == Actor.FOX)
	if not m.debugging and w.known[i] == 0:
		return ""
	if Scrolls.card_at(w, m.hover) != &"":
		return Lang.t("주문서")
	return Lang.t(Info.tile_name(w, m.hover))


## The entry name of a spell: its own title when the 도감 lists it, else, for
## Miho's, its shape (a creature's wisp has no shape entry of Miho's).
static func _spell(s: Spell, own := true) -> String:
	var word := s.shown()
	if Keywords.locate(word).x >= 0 or not own:
		return word
	return Lang.t(Spell.SHAPE_NAME.get(s.shape, SpellInfo.SPRAY_NAME))


## The entry name of a talisman: a compound has its own, a plain one is a 부적.
static func _talisman(c: StringName) -> String:
	return Lang.t(Cards.NAME[c]) if Cards.compounds().has(c) else Codex.talisman_name(c)


## The last row of a box that has an entry: the key of `describe`, at body size as a key
## that is the content of its line is, then 자세히. Empty when the action has no key.
static func detail_row() -> Array:
	var keys := Keys.keys_of(&"describe")
	if keys.is_empty():
		return []
	return [[Keys.label(keys[0]), Palette.TEXT], [" " + Lang.t("자세히"), Palette.DIM]]
