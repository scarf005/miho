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
	var local: Vector2 = m.to_term(screen)
	if m.panels.overlay != &"" and term.pin.is_empty():
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
		or tile != m.look.hover
		or card != m.look.hover_card
		or status != m.look.hover_status
		or spell != m.look.hover_spell
		or slot != m.look.hover_slot
	):
		m.look.hover = tile
		m.look.hover_card = card
		m.look.hover_status = status
		m.look.hover_spell = spell
		m.look.hover_slot = slot
		if m.state == &"play" and not m.busy:
			m.refresh()


static func paint(m: Node) -> void:
	var world: World = m.world
	var term: Term = m.term
	term.scent = trail(m)
	_inspect(m)
	term.debug = DebugView.view(world) if m.debugging else {}
	term.zone = m.journey.zone
	term.zone_centres = m.journey.excluded.zones
	term.picked = m.casting.picked
	term.staged = m.casting.staged
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
	var hover: Vector2i = m.look.hover
	if not m.reach.is_empty() and Grid.inside(hover) and hover != me:
		var aim := Grid.nearest_dir(hover - me)
		if not m.aims.has(aim):
			var spells: Array = m.casting.staged.duplicate()
			spells.append({cards = m.casting.picked.duplicate(), dir = aim})
			m.aims[aim] = Forecast.of(world, {t = &"cast", spells = spells})
		AimView.paint(m.aims[aim], world, m.known, term, tints, marks)
	elif (
		m.casting.picked.is_empty()
		and m.casting.staged.is_empty()
		and Grid.inside(hover)
		and Grid.cheb(hover, me) > 1
	):
		for p in m.journey.path_to(hover):
			tints[p] = Color(Palette.TEXT, 0.12)
	var a := world.actor_at(hover) if Grid.inside(hover) else null
	if a != null and a.faction != Actor.FOX and Hat.shown(world, a):
		var view: PackedByteArray = m.known.view_of(a)
		for i in view.size():
			if view[i] == 1 and world.known[i] == 1 and not tints.has(Grid.at(i)):
				tints[Grid.at(i)] = Color(Palette.SIDE[1], 0.3)
	if m.look.hover_status or hover == me:
		for i in world.seen.size():
			if world.seen[i] == 1 and not tints.has(Grid.at(i)):
				tints[Grid.at(i)] = Color(Palette.SIDE[0], 0.2)
	for b in world.actors:
		if Fight.sneakable(world, b):
			tints[b.pos] = Color(Palette.ALERT[1], 0.35)
	term.tints = tints
	term.marks = marks


## The tiles of the scent trail to tint, with their freshness: those Miho has seen, or every
## one in the debug view; none with the setting off.
static func trail(m: Node) -> Dictionary:
	return Scent.fresh(m.world, not m.debugging) if m.debugging or m.settings.scent else {}


static func _inspect(m: Node) -> void:
	var term: Term = m.term
	if not term.pin.is_empty():
		return
	term.info = []
	term.subject = ""
	term.cursor = Vector2i(-1, -1)
	var example := {}
	if m.state == &"play" and m.panels.overlay == &"" and term.hint.is_empty():
		example = _tell(m)
	term.example = example


## Sets what the box under the pointer tells (`info`), and returns the example of the one
## spell it is about, or none.
static func _tell(m: Node) -> Dictionary:
	var held := Spell.make(m.casting.picked)
	if held == null or m.look.hover_slot >= held.slots.size():
		m.look.hover_slot = -1
	var term: Term = m.term
	term.cursor = m.look.hover
	var lines := _lines(m)
	var word := subject(m) if not lines.is_empty() else ""
	var row := key_row(m, word != "")
	var shown: bool = not lines.is_empty() and not row.is_empty() and not m.touch.enabled
	term.info = lines + [row] if shown else lines
	term.subject = word
	return _example(m)


## The example of the one spell the box tells of, or none: Miho casts hers, and a creature
## its own.
static func _example(m: Node) -> Dictionary:
	var cards := []
	if m.look.hover_slot >= 0:
		cards = m.casting.picked
	elif m.look.hover_spell != "":
		cards = Spell.from_key(m.look.hover_spell).cards
	elif m.look.hover_card != &"":
		cards = Cards.spell_of(m.look.hover_card)
	elif not m.look.hover_status:
		var w: World = m.world if m.debugging else m.known
		var shot: Shot = (
			DebugView.shot_at(w, m.look.hover) if m.debugging else Info.shot_at(w, m.look.hover)
		)
		if shot != null and shot.faction != Actor.FOX:
			var by: Actor = w.actor(shot.caster)
			return CodexScene.charged(by.kind if by != null else Codex.foes()[0], shot.spell.cards)
		if shot != null:
			cards = shot.spell.cards
	return SpellScene.of(cards) if not cards.is_empty() else {}


## The hover lines of what the pointer or the look cursor is over.
static func _lines(m: Node) -> Array:
	if m.look.hover_slot >= 0:
		return SpellInfo.slot(Spell.make(m.casting.picked), m.look.hover_slot)
	if m.look.hover_spell != "":
		return SpellInfo.spell(Spell.from_key(m.look.hover_spell))
	if m.look.hover_card != &"":
		return SpellInfo.hovered(m.look.hover_card, m.casting.picked)
	if m.look.hover_status:
		return Info.creature(m.known, m.known.player())
	var lines: Array = (
		DebugView.at(m.world, m.look.hover)
		if m.debugging
		else Info.at(m.known, m.look.hover, m.term.scent)
	)
	return (
		m.menu.debug.head()
		+ lines
		+ m.journey.excluded.lines(m.look.hover, m.journey.zone)
		+ Info.ahead(m.world, m.ahead, m.look.hover)
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
	if m.look.hover_slot >= 0:
		var s := Spell.make(m.casting.picked)
		if s == null:
			return ""
		return _spell(s) if s.cards.size() == 1 else _talisman(s.slots[m.look.hover_slot])
	if m.look.hover_spell != "":
		var s := Spell.from_key(m.look.hover_spell)
		return "" if s == null else _spell(s)
	if m.look.hover_card != &"":
		return _talisman(m.look.hover_card)
	if m.look.hover_status or not Grid.inside(m.look.hover):
		return ""
	var w: World = m.world if m.debugging else m.known
	var i := Grid.index(m.look.hover)
	if m.debugging or w.seen[i] == 1:
		var a := w.actor_at(m.look.hover)
		if a != null and (m.debugging or Hat.shown(w, a)):
			return "" if a.is_miho() else Lang.t(a.info().name)
		var shot := w.shot_at(m.look.hover)
		if shot != null:
			return _spell(shot.spell, shot.faction == Actor.FOX)
	if not m.debugging and w.known[i] == 0:
		return ""
	if Scrolls.card_at(w, m.look.hover) != &"":
		return Lang.t("주문서")
	return Lang.t(Info.tile_name(w, m.look.hover))


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


## The last row of a box: the key of every action that works on what it shows, the detail key
## first when the box has an entry (`entry`), each key at body size as a key that is the content
## of its line is, then its name. Empty when no action has a key.
static func key_row(m: Node, entry: bool) -> Array:
	var shown := [[&"describe", "자세히"]] if entry else []
	shown.append_array(m.look.hints())
	var row := []
	for hint: Array in shown:
		var keys := Keys.keys_of(hint[0])
		if keys.is_empty():
			continue
		var key := Keys.label(keys[0])
		if hint[0] == &"pick_1":
			var last := Keys.keys_of(&"pick_%d" % Exclusions.MAX_RADIUS)
			if not last.is_empty():
				key += "~" + Keys.label(last[0])
		row.append([("  " if not row.is_empty() else "") + key, Palette.TEXT])
		row.append([" " + Lang.t(hint[1]), Palette.DIM])
	return row
