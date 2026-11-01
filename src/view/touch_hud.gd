class_name TouchHud
extends RefCounted
## The status and the buttons of a touch screen, in the area under the map (portrait)
## or beside it (landscape), in place of StatusBar's two rows. It answers the same
## questions StatusBar does about a point (card_at, hand_at, queue_at, status_at,
## slot_at) and tells which button is under it. Every target is at least TARGET
## CSS pixels across. `mode` is play, menu (one button back), title (continue or
## start anew when a run is saved) or over (start anew).

## The least size of a button or a talisman, in CSS pixels.
const TARGET := 44.0
const CARD_H := 52.0
const COLS := 4
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
	&"over": [[&"new", "재시작"]],
}
## How long a pressed button stays lit, in seconds.
const FLASH := 0.15

var mode := &"play"
## The area this fills, in the term's space, and the term's pixels per CSS pixel.
var area := Rect2()
var unit := 1.0
var wide := false
var pressed := &""
var pressed_at := 0.0


## The CSS pixels the HUD needs, below the map in portrait (a height) or beside
## it in landscape (a width), for cells `ch` CSS pixels tall.
static func extent(wide_screen: bool, play: bool, ch: float) -> float:
	if wide_screen:
		return 300.0 if play else 120.0
	if not play:
		return TARGET + 12.0
	var cards := ceili(float(Cards.ALL.size()) / cards_per_row(false))
	return ch * 2.0 + CARD_H * cards + TARGET * (1.0 + ceili(BUTTONS.size() / float(COLS)))


static func cards_per_row(wide_screen: bool) -> int:
	return COLS if wide_screen else Cards.ALL.size()


## The targets of a mode in `field` (the term's pixels, `px` of them to a CSS
## pixel), as {id, kind, rect, n}: kind is stat, card (n the talisman's place),
## queue (n the slot, -1 the name) or button (with its label).
static func layout(
	mode_name: StringName, field: Rect2, px: float, wide_screen: bool, cards: int
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var h := TARGET * px
	if mode_name != &"play":
		var ids: Array = ALONE.get(mode_name, [])
		var tall := minf(h * 1.5, field.size.y)
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
	var per := cards_per_row(wide_screen)
	var card := Vector2(w / per, CARD_H * px)
	for i in cards:
		var at := Vector2(x + card.x * (i % per), y + card.y * (i / per))
		out.append({id = &"card", kind = &"card", rect = Rect2(at, card), n = i})
	y += card.y * ceili(float(Cards.ALL.size()) / per)
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
	return layout(mode, area, unit, wide, t.world.cards.size() if t.world != null else 0)


func _find(t: Term, local: Vector2, kind: StringName) -> Dictionary:
	for item in _items(t):
		if item.kind == kind and item.rect.has_point(local):
			return item
	return {}


## The button under a point in the term's space, or empty.
func button_at(t: Term, local: Vector2) -> StringName:
	return _find(t, local, &"button").get("id", &"")


## The talisman under a point, or empty.
func card_at(t: Term, local: Vector2) -> StringName:
	var item := _find(t, local, &"card")
	return t.world.cards[item.n] if not item.is_empty() else &""


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


## Touch has no saved-spell row: the spellbook lists them.
func slot_at(_t: Term, _local: Vector2) -> String:
	return ""


func draw(t: Term) -> void:
	for item in _items(t):
		match item.kind:
			&"stat":
				_draw_stat(t, item.rect)
			&"card":
				_draw_card(t, item)
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
	var right := "%d층 %d초" % [w.depth, w.round_no]
	t._text(Vector2(_cell(rect.end).x - t._cells(right), at.y), right, Palette.TEXT)
	var held: int = StatusBar._held(t)
	for i in w.max_tails():
		var c: Color = Palette.SIDE[0]
		if i >= w.tails:
			c = Palette.DIM
		elif i >= w.tails - held:
			c = Palette.CARD[Cards.EARTH]
		t._glyph(at + Vector2(i, 1), "~", c)


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
	t._glyph(_cell(rect.get_center()) - Vector2(0.5, 0.5), Cards.GLYPH[card], Palette.CARD[card])


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
		t._glyph(middle, Cards.GLYPH[slots[item.n]], c)
	else:
		var more := StatusBar.fits(t, item.n - slots.size() + 1)
		t._glyph(middle, "·", Palette.TEXT if more else Palette.DIM)


func _draw_button(t: Term, item: Dictionary) -> void:
	var rect := _shown(item)
	if item.id == pressed and t._time - pressed_at < FLASH:
		t.draw_rect(rect, Color(Palette.TEXT, 0.3))
	_lit(t, item)
	var label: String = item.label
	var at := _cell(rect.get_center()) - Vector2(t._cells(label) / 2.0, 0.5)
	t._text(at, label, Palette.TEXT)
