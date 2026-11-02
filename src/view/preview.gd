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
	term.cursor = Vector2i(-1, -1)
	if m.state != &"play" or not term.hint.is_empty():
		return
	term.cursor = m.hover
	if m.hover_slot >= 0:
		term.info = SpellInfo.slot(Spell.make(m.picked), m.hover_slot)
	elif m.hover_spell != "":
		term.info = SpellInfo.spell(Spell.from_key(m.hover_spell))
	elif m.hover_card != &"":
		term.info = SpellInfo.hovered(m.hover_card, m.picked)
	elif m.hover_status:
		term.info = Info.creature(m.known, m.known.player())
	else:
		var lines: Array = (
			DebugView.at(m.world, m.hover) if m.debugging else Info.at(m.known, m.hover)
		)
		term.info = (
			m.menu.debug.head()
			+ lines
			+ m.excluded.lines(m.hover, m.zone)
			+ Info.ahead(m.world, m.ahead, m.hover)
		)
