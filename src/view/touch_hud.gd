class_name TouchHud
extends RefCounted
## The status and the buttons of a touch screen, in the area under the map (portrait)
## or beside it (landscape), in place of StatusBar's two rows. It answers the same
## questions StatusBar does about a point (card_at, hand_at, queue_at, status_at,
## slot_at) and tells which button is under it. Every target is at least TARGET
## CSS pixels across. In play it holds the status with the noise bar, in portrait a
## strip of the creatures in sight (in landscape the term's sidebar lists them), the
## talismans, a row of saved spells, the queue and the buttons. The strip and the
## saved row scroll sideways, from entry `first`. `mode` is play, menu (buttons for
## the page: the spellbook saves in a slot), title (continue or start anew when a
## run is saved) or over (start anew).

## The least size of a button or a talisman, in CSS pixels.
const TARGET := 44.0
const CARD_H := 52.0
## Buttons across: the longest label, three cells, fits in a quarter of 300 CSS pixels.
const COLS := 4
## Creatures the portrait strip shows at once.
const STRIP_CARDS := 2
const BUTTONS := [
	[&"wait", "대기"],
	[&"explore", "탐험"],
	[&"rest", "쉬기"],
	[&"stairs", "계단"],
	[&"fight", "공격"],
	[&"unpick", "빼기"],
	[&"close", "문닫기"],
	[&"again", "다시"],
	[&"spellbook", "주문서"],
	[&"codex", "도감"],
	[&"log", "기록"],
	[&"cancel", "메뉴"],
]
## The buttons of the other modes.
const ALONE := {
	&"menu": [[&"back", "뒤로"]],
	&"title": [],
	&"saved": [[&"continue", "이어하기"], [&"new", "새로 시작"]],
	&"over": [[&"log", "기록"], [&"new", "재시작"]],
}
## How long a pressed button stays lit, in seconds.
const FLASH := 0.15

var mode := &"play"
## The page open in menu mode.
var page := &""
## The area this fills, in the term's space, and the term's pixels per CSS pixel.
var area := Rect2()
var unit := 1.0
var wide := false
var pressed := &""
var pressed_at := 0.0
## The first entry shown of each scrolling row (&"strip", &"saved"), and the drag
## that has not yet made a whole step.
var first := {&"strip": 0, &"saved": 0}
var _dragged := {}


## The CSS pixels the HUD needs, below the map in portrait (a height) or beside
## it in landscape (a width), for cells `ch` CSS pixels tall.
static func extent(wide_screen: bool, play: bool, ch: float, saved := true) -> float:
	if wide_screen:
		return 300.0 if play else 120.0
	if not play:
		return TARGET + 12.0
	var cards := ceili(float(Cards.ALL.size()) / cards_per_row(false))
	var buttons := ceili(BUTTONS.size() / float(COLS))
	return ch * (2.0 + Term.SIDE_ROWS) + CARD_H * cards + TARGET * (1.0 + int(saved) + buttons)


static func cards_per_row(wide_screen: bool) -> int:
	return 4 if wide_screen else Cards.ALL.size()


## The buttons of a mode as [id, label]: the spellbook has Enter (cast the selected
## spell) and one for each saved-spell slot, labelled with its key.
static func buttons_of(mode_name: StringName, page_name: StringName) -> Array:
	if mode_name == &"menu" and page_name == &"spells":
		var out := [[&"enter", "던지기"]]
		for i in Keys.SLOTS.size():
			out.append([Keys.SLOTS[i], slot_label(Keys.SLOTS[i], i)])
		return out + ALONE[&"menu"]
	return ALONE.get(mode_name, [])


## What a saved-spell slot is called: the first key it is bound to, else its place.
static func slot_label(slot: StringName, place: int) -> String:
	var keys := Keys.keys_of(slot)
	return Keys.label(keys[0]) if not keys.is_empty() else str(place + 1)


## The targets of a mode in `field` (the term's pixels, `px` of them to a CSS
## pixel), as {id, kind, rect, n}: kind is stat, strip (the creatures, portrait),
## card (n the talisman's place), saved (the saved spells), queue (n the slot, -1
## the name) or button (with its label).
static func layout(
	mode_name: StringName,
	field: Rect2,
	px: float,
	wide_screen: bool,
	cards: int,
	page_name := &"",
	with_saved := true
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var h := TARGET * px
	if mode_name != &"play":
		var ids := buttons_of(mode_name, page_name)
		var tall := minf(h * 1.5 if ids.size() < 3 else h, field.size.y)
		for i in ids.size():
			var rect := (
				Rect2(field.position + Vector2(0, tall * i), Vector2(field.size.x, tall))
				if wide_screen
				else Rect2(
					field.position + Vector2(field.size.x / ids.size() * i, 0),
					Vector2(field.size.x / ids.size(), tall)
				)
			)
			out.append({id = ids[i][0], kind = &"button", rect = rect, label = ids[i][1]})
		return out
	var x := field.position.x
	var w := field.size.x
	var y := field.position.y
	out.append({id = &"stat", kind = &"stat", rect = Rect2(x, y, w, Term.CELL.y * 2.0), n = 0})
	y += Term.CELL.y * 2.0
	if not wide_screen:
		var strip := Rect2(x, y, w, Term.CELL.y * Term.SIDE_ROWS)
		out.append({id = &"strip", kind = &"strip", rect = strip, n = 0})
		y += strip.size.y
	var per := cards_per_row(wide_screen)
	var card := Vector2(w / per, CARD_H * px)
	for i in cards:
		var at := Vector2(x + card.x * (i % per), y + card.y * (i / per))
		out.append({id = &"card", kind = &"card", rect = Rect2(at, card), n = i})
	y += card.y * maxi(1, ceili(float(cards) / per))
	if with_saved:
		out.append({id = &"saved", kind = &"saved", rect = Rect2(x, y, w, h), n = 0})
		y += h
	for j in Spell.MAX_SLOTS:
		out.append({id = &"queue", kind = &"queue", rect = Rect2(x + h * j, y, h, h), n = j})
	var name_at := h * Spell.MAX_SLOTS
	var name_rect := Rect2(x + name_at, y, w - name_at, h)
	out.append({id = &"queue", kind = &"queue", rect = name_rect, n = -1})
	y += h
	var cell := Vector2(w / COLS, h)
	for i in BUTTONS.size():
		var at := Vector2(x + cell.x * (i % COLS), y + h * (i / COLS))
		var rect := Rect2(at, cell)
		out.append({id = BUTTONS[i][0], kind = &"button", rect = rect, label = BUTTONS[i][1]})
	return out


func _items(t: Term) -> Array[Dictionary]:
	var cards := t.world.cards.size() if t.world != null else 0
	return layout(mode, area, unit, wide, cards, page, not t.saved.is_empty())


func _find(t: Term, local: Vector2, kind: StringName) -> Dictionary:
	for item in _items(t):
		if item.kind == kind and item.rect.has_point(local):
			return item
	return {}


## The rectangle of the first target of a kind, or an empty one.
func _rect(t: Term, kind: StringName) -> Rect2:
	for item in _items(t):
		if item.kind == kind:
			return item.rect
	return Rect2()


## The creatures the strip shows, as {actor, rect}: STRIP_CARDS of them from `first`.
func _creatures(t: Term) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var strip := _rect(t, &"strip")
	if t.world == null or strip.size == Vector2.ZERO:
		return out
	var list := t._side_list(t._world_actors(), t.world.player().pos, 99)
	var from := clampi(first[&"strip"], 0, maxi(0, list.size() - STRIP_CARDS))
	var card := Vector2(strip.size.x / STRIP_CARDS, strip.size.y)
	for k in mini(STRIP_CARDS, list.size() - from):
		out.append(
			{actor = list[from + k], rect = Rect2(strip.position + Vector2(card.x * k, 0), card)}
		)
	return out


## The saved spells the row shows, as {action, spell, rect}: as many as fit from `first`.
func _chips(t: Term) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var row := _rect(t, &"saved")
	var slots := Keys.SLOTS.filter(func(s): return t.saved.has(s))
	var x := row.position.x
	for i in range(clampi(first[&"saved"], 0, maxi(0, slots.size() - 1)), slots.size()):
		var spell := Spell.from_key(t.saved[slots[i]])
		var width := maxf(TARGET * unit, (spell.slots.size() + 1.5) * Term.CELL.x)
		if x + width > row.end.x + 0.5:
			break
		out.append(
			{action = slots[i], spell = spell, rect = Rect2(x, row.position.y, width, row.size.y)}
		)
		x += width
	return out


## How many entries a scrolling row has: creatures in sight or saved spells.
func _count(t: Term, kind: StringName) -> int:
	if kind == &"saved":
		return Keys.SLOTS.filter(func(s): return t.saved.has(s)).size()
	return t._side_list(t._world_actors(), t.world.player().pos, 99).size()


## The finger drags `dx` (the term's pixels) along the strip or the saved row at
## `local`: the row moves on by a whole entry for each entry's width. Whether the
## point is on one of the rows.
func scroll(t: Term, local: Vector2, dx: float) -> bool:
	for kind: StringName in [&"strip", &"saved"]:
		var rect := _rect(t, kind)
		if not rect.has_point(local):
			continue
		var pitch := rect.size.x / STRIP_CARDS if kind == &"strip" else TARGET * unit
		_dragged[kind] = _dragged.get(kind, 0.0) - dx
		var steps := int(_dragged[kind] / pitch)
		_dragged[kind] -= steps * pitch
		var last := _count(t, kind) - (STRIP_CARDS if kind == &"strip" else 1)
		first[kind] = clampi(first[kind] + steps, 0, maxi(0, last))
		return true
	return false


## A finger is lifted: the drag along a row starts over.
func release() -> void:
	_dragged.clear()


## The button under a point in the term's space, or empty.
func button_at(t: Term, local: Vector2) -> StringName:
	return _find(t, local, &"button").get("id", &"")


## Where the creature listed in the strip under a point stands, or (-1, -1).
func creature_at(t: Term, local: Vector2) -> Vector2i:
	for c in _creatures(t):
		if c.rect.has_point(local):
			return c.actor.pos
	return Vector2i(-1, -1)


## The saved-spell slot's action under a point, or empty.
func saved_at(t: Term, local: Vector2) -> StringName:
	for chip in _chips(t):
		if chip.rect.has_point(local):
			return chip.action
	return &""


## The talisman under a point, or empty.
func card_at(t: Term, local: Vector2) -> StringName:
	var item := _find(t, local, &"card")
	return t.world.cards[item.n] if not item.is_empty() else &""


## The talisman under a point, or empty: the same as card_at, as there is no compound row.
func talisman_at(t: Term, local: Vector2) -> StringName:
	return card_at(t, local)


## Whether a point is on a slot of the queue or its name: what casts it.
func cast_at(t: Term, local: Vector2) -> bool:
	return not _find(t, local, &"queue").is_empty()


## The queued spell's key when a point is on its name or a filled slot, else empty.
func hand_at(t: Term, local: Vector2) -> String:
	var spell := Spell.make(t.picked)
	var item := _find(t, local, &"queue")
	if spell == null or item.is_empty():
		return ""
	return spell.key() if item.n < spell.slots.size() else ""


## The filled queue slot under a point, or -1.
func queue_at(t: Term, local: Vector2) -> int:
	var spell := Spell.make(t.picked)
	var item := _find(t, local, &"queue")
	if spell == null or item.is_empty():
		return -1
	return item.n if item.n >= 0 and item.n < spell.slots.size() else -1


## Whether a point is on Miho's health or tails.
func status_at(t: Term, local: Vector2) -> bool:
	return not _find(t, local, &"stat").is_empty()


## The key of the spell a click under a point fills the queue with, or empty.
func preset_at(t: Term, local: Vector2) -> String:
	return slot_at(t, local)


## The key of the saved spell under a point, or empty.
func slot_at(t: Term, local: Vector2) -> String:
	for chip in _chips(t):
		if chip.rect.has_point(local):
			return chip.spell.key()
	return ""


func draw(t: Term) -> void:
	for item in _items(t):
		match item.kind:
			&"stat":
				_draw_stat(t, item.rect)
			&"strip":
				_draw_strip(t)
			&"card":
				_draw_card(t, item)
			&"saved":
				_draw_saved(t, item.rect)
			&"queue":
				_draw_queue(t, item)
			&"button":
				_draw_button(t, item)


## The cell (fractional) that a pixel point of the term's space lies in.
static func _cell(p: Vector2) -> Vector2:
	return p / Term.CELL


func _draw_stat(t: Term, rect: Rect2) -> void:
	var w := t.world
	var me := w.player()
	var at := _cell(rect.position)
	t._glyph(at, "@", Palette.KIND[&"miho"])
	t._pips(at + Vector2(1.5, 0), me.hp, me.max_hp, Palette.HURT)
	var right := Lang.t("%d층 %d초") % [w.depth, w.round_no]
	t._text(Vector2(_cell(rect.end).x - t._cells(right), at.y), right, Palette.TEXT)
	StatusBar.buffs(t, Vector2(_cell(rect.end).x - t._cells(right) - 1.0, at.y))
	var held: int = StatusBar._held(t)
	for i in w.max_tails():
		var c: Color = Palette.SIDE[0]
		if i >= w.tails:
			c = Palette.DIM
		elif i >= w.tails - held:
			c = Palette.CARD[Cards.EARTH]
		t._glyph(at + Vector2(i, 1), "~", c)
	NoiseMeter.draw(t, Vector2(_cell(rect.end).x - NoiseMeter.width(), at.y + 1))


func _draw_strip(t: Term) -> void:
	var strip := _rect(t, &"strip")
	for c in _creatures(t):
		CreatureCard.draw(t, c.actor, _cell(c.rect.position), c.rect.size.x / Term.CELL.x)
	_more(t, strip, first[&"strip"] > 0, first[&"strip"] + STRIP_CARDS < _count(t, &"strip"))


## `<` and `>` at the ends of a scrolling row that has more beyond them.
func _more(t: Term, row: Rect2, before: bool, after: bool) -> void:
	if before:
		t._small(_cell(row.position), "<", Palette.DIM)
	if after:
		t._small(_cell(Vector2(row.end.x - Term.CELL.x * 0.5, row.position.y)), ">", Palette.DIM)


func _draw_saved(t: Term, row: Rect2) -> void:
	var held: int = StatusBar._held(t)
	var chips := _chips(t)
	for chip in chips:
		var item := {rect = chip.rect}
		var spell: Spell = chip.spell
		var ready: bool = StatusBar._castable(t, spell, held)
		_lit(t, item)
		var at := _cell(_shown(item).position)
		var label := slot_label(chip.action, Keys.SLOTS.find(chip.action))
		t._key(at + Vector2(0.1, 0), label, Palette.KEY if ready else Palette.DIM)
		for k in spell.slots.size():
			var c := Palette.card(spell.slots[k])
			t._glyph(
				at + Vector2(0.5 + k, 0.4),
				Lang.t(Cards.GLYPH[spell.slots[k]], "talisman"),
				c if ready else c * 0.4
			)
	var slots := _count(t, &"saved")
	_more(t, row, first[&"saved"] > 0, first[&"saved"] + chips.size() < slots)


## The part of a target that is drawn: a little less than what answers a touch.
func _shown(item: Dictionary) -> Rect2:
	return item.rect.grow(-2.0 * unit)


func _lit(t: Term, item: Dictionary) -> void:
	t.draw_rect(_shown(item), Color(Palette.DIM, 0.6), false, 2.0 * unit)


func _draw_card(t: Term, item: Dictionary) -> void:
	var card := t.world.cards[item.n]
	var queued := Spell.make(t.picked)
	var rect := _shown(item)
	if queued != null and queued.cards.has(card):
		t.draw_rect(rect, Palette.CARD[card] * 0.45)
	_lit(t, item)
	t._glyph(
		_cell(rect.get_center()) - Vector2(0.5, 0.5),
		Lang.t(Cards.GLYPH[card], "talisman"),
		Palette.CARD[card]
	)


func _draw_queue(t: Term, item: Dictionary) -> void:
	var rect := _shown(item)
	var queued := Spell.make(t.picked)
	var slots: Array[StringName] = []
	if queued != null:
		slots = queued.slots
	if item.n < 0:
		var name: String = StatusBar._name(t, queued)
		var at := _cell(rect.get_center()) - Vector2(t._cells(name) / 2.0, 0.5)
		t._text(Vector2(maxf(at.x, _cell(rect.position).x), at.y), name, Palette.TEXT)
		return
	_lit(t, item)
	var middle := _cell(rect.get_center()) - Vector2(0.5, 0.5)
	if item.n < slots.size():
		var c := Palette.card(slots[item.n])
		t.draw_rect(rect, c * 0.35)
		t._glyph(middle, Lang.t(Cards.GLYPH[slots[item.n]], "talisman"), c)
	else:
		var more := StatusBar.fits(t, item.n - slots.size() + 1)
		t._glyph(middle, "·", Palette.TEXT if more else Palette.DIM)


func _draw_button(t: Term, item: Dictionary) -> void:
	var rect := _shown(item)
	if item.id == pressed and t._time - pressed_at < FLASH:
		t.draw_rect(rect, Color(Palette.TEXT, 0.3))
	_lit(t, item)
	var label: String = Lang.t(item.label, "button")
	var at := _cell(rect.get_center()) - Vector2(t._cells(label) / 2.0, 0.5)
	t._text(at, label, Palette.TEXT)
