class_name Menu
extends RefCounted
## Full-screen pages over the game, moved through with the direction keys,
## Enter and Esc, or the pointer: help lists every action with its keys;
## options change the settings; key settings bind keys to actions; the
## spellbook lists the queued spell and the saved ones, with what the selected
## one does, and a slot key saves it to that slot; the 도감 (Codex) lists every
## creature, spell, compound, item and terrain feature; the log lists the past
## messages. Every page moves as ListNav says, scrolls with the wheel, lights
## the row under the pointer, and a click selects it.
## `key`, `use`, `click` and `back` return what the game should do: &"close",
## &"changed" (settings or keys changed), &"restart", &"quit" (save and end the
## game), &"cast" (pick `chosen`), or nothing.

const VALUE_COL := 18.0
const MOUSE := [
	["왼쪽 클릭", "옆 칸으로 한 걸음, 먼 칸까지 걷기"],
	["부적 고르고 클릭", "그쪽으로 던지기"],
	["오른쪽 클릭", "취소"],
	["가리키기", "무엇이 있는지 보기"],
]
const LOOK := ["살피는 중", "방향키로 커서 이동 (Shift는 5칸), Enter 걷기, 위험구역 키로 표시 (그 위에서 1-7 반경), Esc 끝"]
const OPTIONS := [
	&"volume", &"music", &"crt", &"zoom", &"speed", &"codex", &"keys", &"restart", &"quit", &"close"
]
const OPTION_NAMES := {
	&"volume": "소리 크기",
	&"music": "음악 크기",
	&"crt": "CRT 효과",
	&"zoom": "화면 크기",
	&"speed": "움직임 속도",
	&"replay": "명장면 다시보기",
	&"codex": "도감",
	&"keys": "키 설정",
	&"restart": "처음부터",
	&"quit": "저장하고 끝내기",
	&"close": "계속",
}
const MODIFIERS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

var settings := Settings.new()
## The seed of the run, shown under the options (DCSS shows it in its version page).
var seed_value := 0
var page := &""
var selected := 0
## The first row shown, and the row the pointer is over (-1 for none).
var top := 0
var hovered := -1
## On the key page: the selected action waits for the key to bind.
var waiting := false
## The spell queued when the spellbook opened (or null), and the spell Enter chose there.
var queued: Spell
var chosen: Spell
## The messages the log page lists, as rows.
var log_rows: Array = []
## The 도감 page's tab, entry and scroll; it keeps them when closed.
var codex := Codex.new()
## The screen in cells, for the pages to fit their lists.
var room := Vector2i(40, 18)
## The page this one was opened from and the row it was opened on; Esc goes back
## there. Empty when the game opened it.
var origin := &""
var origin_row := 0


## Opens a page, `size` the screen in cells when it changes.
func open(p: StringName, size := Vector2i.ZERO) -> void:
	page = p
	selected = 0
	top = 0
	hovered = -1
	waiting = false
	origin = &""
	if size != Vector2i.ZERO:
		room = size
	codex.room = room
	codex.hover = -1
	codex.select(codex.selected)
	if p == &"log":
		selected = maxi(0, log_rows.size() - 1)
		top = ListNav.reveal(0, selected, log_rows.size(), _fits())


## Opens a page from the current one, which Esc then returns to.
func _enter(p: StringName) -> void:
	var from := page
	var row := selected
	open(p)
	origin = from
	origin_row = row


## What the page shows, as a Term.panel.
func panel() -> Dictionary:
	var out := {title = "도움말", rows = _help()}
	match page:
		&"options":
			out = {
				title = "설정", rows = _options(), detail = [[["시드: %d" % seed_value, Palette.DIM]]]
			}
		&"keys":
			out = {title = "키 설정", rows = _keys()}
		&"spells":
			var list := spells()
			var detail: Array = SpellInfo.spell(list[selected]) if not list.is_empty() else []
			out = {title = "주문서", rows = _spells(list), detail = detail}
		&"log":
			out = {title = "기록", rows = log_rows}
		&"codex":
			return codex.panel()
	out.merge({selected = selected, top = top, hover = hovered})
	return out


## Rows of the page's list that fit.
func _fits() -> int:
	return Term.list_fits(room.y, panel().get("detail", []).size())


## Handles a key press.
func key(e: InputEventKey) -> StringName:
	var nav := _nav(e)
	if e.is_echo() and not nav in ListNav.REPEATS:
		return &""
	if waiting:
		return _bind(e)
	if page == &"codex":
		var out := codex.key(e, nav)
		return back() if out == &"close" else out
	var slot := Keys.action_of(e)
	var out := &"changed"
	if page in [&"help", &"log"] and slot == page:
		out = &"close"
	elif page == &"spells" and Keys.SLOTS.has(slot) and not spells().is_empty():
		var k := spells()[selected].key()
		var had: bool = settings.spells.get(slot, "") == k
		for s in settings.spells.keys():
			if settings.spells[s] == k:
				settings.spells.erase(s)
		if not had:
			settings.spells[slot] = k
	elif (
		page == &"keys"
		and e.keycode in [KEY_DELETE, KEY_BACKSPACE]
		and selected < _actions().size()
	):
		Keys.bind(_actions()[selected], [])
	else:
		out = _move(nav)
	return out


## Menu movement `nav` on the page's list; what the game should do.
func _move(nav: StringName) -> StringName:
	var out := &""
	match nav:
		&"up", &"down", &"page_up", &"page_down", &"home", &"end":
			var count: int = panel().rows.size()
			selected = ListNav.step(nav, selected, count, _fits())
			top = ListNav.reveal(top, selected, count, _fits())
		&"left", &"right":
			out = _change(1 if nav == &"right" else -1)
		&"enter":
			out = use()
		&"back":
			out = back()
	return out


## The first key of the slot a spell is saved in, or empty.
static func slot_key(spells: Dictionary, key: String) -> String:
	for slot in spells:
		if spells[slot] == key and not Keys.keys_of(slot).is_empty():
			return Keys.label(Keys.keys_of(slot)[0])
	return ""


## Enter in the spellbook: cast the selected spell, or close when there is none.
func _choose() -> StringName:
	var list := spells()
	chosen = list[selected] if not list.is_empty() else null
	return &"cast" if chosen != null else &"close"


## The queued spell, then every saved one not the same, in slot order.
func spells() -> Array[Spell]:
	var out: Array[Spell] = []
	if queued != null:
		out.append(queued)
	for slot in Keys.SLOTS:
		var s := Spell.from_key(settings.spells.get(slot, ""))
		if s != null and not out.any(func(o): return o.key() == s.key()):
			out.append(s)
	return out


## Every spell as a row: its slot key if saved, slots, name and cost.
func _spells(list: Array[Spell]) -> Array:
	var rows := []
	for s in list:
		var row := [[slot_key(settings.spells, s.key()), Palette.SIDE[0]]]
		for k in s.slots.size():
			row.append([Cards.GLYPH[s.slots[k]], Palette.card(s.slots[k]), 4.0 + k])
		row.append(["꼬리 %d" % s.cost(), Palette.DIM, 10.0])
		row.append([s.title(), Palette.TEXT, 14.0])
		rows.append(row)
	if rows.is_empty():
		rows.append([["줄에 든 부적도, 저장한 주문도 없다", Palette.DIM]])
	return rows


## The pointer is over row k (-1 for none): it lights.
func point(k: int) -> void:
	hovered = k
	codex.hover = k


## A left click over row `row` and tab `tab` (-1 for none): a tab shows, a row is
## selected and, on the pages that act, used.
func click(row: int, tab: int) -> StringName:
	if waiting:
		return &""
	if tab >= 0 and page == &"codex":
		codex.go(tab)
	elif row >= 0:
		if page == &"codex":
			codex.select(row)
			return &""
		selected = row
		top = ListNav.reveal(top, selected, panel().rows.size(), _fits())
		return use() if page in [&"options", &"keys", &"spells"] else &""
	return &""


## The wheel turns `dir` notches (1 down) over the detail (`aside`) or the list.
func wheel(dir: int, aside: bool) -> void:
	if page == &"codex":
		codex.wheel(dir, aside)
	else:
		top = ListNav.scrolled(top, dir * ListNav.WHEEL, panel().rows.size(), _fits())


## Enter on the selected row.
func use() -> StringName:
	match page:
		&"help", &"log":
			return &"close"
		&"spells":
			return _choose()
		&"keys":
			return _use_key_row()
		&"options":
			return _use_option()
	return &""


func _use_option() -> StringName:
	var row: StringName = OPTIONS[selected]
	match row:
		&"keys", &"codex":
			_enter(row)
			return &""
		&"restart", &"quit", &"close":
			return row
	return _change(1)


func _use_key_row() -> StringName:
	if selected >= _actions().size():
		Keys.reset()
		return &"changed"
	waiting = true
	return &""


## Esc: a page opened from another goes back to it, on the row it was opened
## from; others close.
func back() -> StringName:
	if origin == &"":
		return &"close"
	var from := origin
	var row := origin_row
	open(from)
	selected = row
	top = ListNav.reveal(0, row, panel().rows.size(), _fits())
	return &""


## Steps the selected option's value; wraps around.
func _change(step: int) -> StringName:
	if page != &"options":
		return &""
	match OPTIONS[selected]:
		&"volume":
			settings.volume = clampi(settings.volume + step * 10, 0, 100)
		&"music":
			settings.music = clampi(settings.music + step * 10, 0, 100)
		&"crt":
			settings.crt = not settings.crt
		&"zoom":
			settings.zoom = _cycle(Settings.ZOOMS, settings.zoom, step)
		&"speed":
			settings.speed = _cycle(Settings.SPEEDS, settings.speed, step)
		&"replay":
			settings.replay = not settings.replay
		_:
			return &""
	return &"changed"


static func _cycle(values: Array, v: float, step: int) -> float:
	return values[posmod(values.find(v) + step, values.size())]


## The key pressed while waiting goes to the selected action and leaves any
## other action that had it; Esc stops waiting; Shift and the like alone wait on.
func _bind(e: InputEventKey) -> StringName:
	if e.keycode in MODIFIERS:
		return &""
	waiting = false
	if e.keycode == KEY_ESCAPE:
		return &""
	var k := OS.get_keycode_string(e.get_keycode_with_modifiers())
	var action: StringName = _actions()[selected]
	for other in Keys.ACTIONS:
		var keys := Keys.keys_of(other)
		if keys.has(k) and other != action:
			keys.erase(k)
			Keys.bind(other, keys)
	var mine := Keys.keys_of(action)
	if not mine.has(k):
		mine.append(k)
	Keys.bind(action, mine)
	return &"changed"


static func _actions() -> Array:
	return Keys.ACTIONS.keys()


## A key as menu movement: up, down, left, right, page_up, page_down, home, end,
## tab_prev, tab_next, enter, back, or empty.
## Arrows, Enter and Esc always work, whatever the bindings.
static func _nav(e: InputEventKey) -> StringName:
	var raw := {
		KEY_UP: &"up",
		KEY_DOWN: &"down",
		KEY_LEFT: &"left",
		KEY_RIGHT: &"right",
		KEY_PAGEUP: &"page_up",
		KEY_PAGEDOWN: &"page_down",
		KEY_HOME: &"home",
		KEY_END: &"end",
		KEY_ENTER: &"enter",
		KEY_KP_ENTER: &"enter",
		KEY_ESCAPE: &"back",
	}
	if raw.has(e.keycode):
		return raw[e.keycode]
	if e.keycode == KEY_TAB:
		return &"tab_prev" if e.shift_pressed else &"tab_next"
	var bound := {
		&"move_n": &"up",
		&"move_s": &"down",
		&"move_w": &"left",
		&"move_e": &"right",
		&"confirm": &"enter",
		&"cancel": &"back",
	}
	return bound.get(Keys.action_of(e), &"")


func _options() -> Array:
	var values := {
		&"volume": str(settings.volume) if settings.volume > 0 else "끔",
		&"music": str(settings.music) if settings.music > 0 else "끔",
		&"crt": _on(settings.crt),
		&"zoom": "맞춤" if settings.zoom == 0.0 else str(settings.zoom),
		&"speed": "%dx" % int(settings.speed),
		&"replay": _on(settings.replay),
	}
	var rows := []
	for o in OPTIONS:
		var row := [[OPTION_NAMES[o], Palette.TEXT]]
		if values.has(o):
			row.append([values[o], Palette.SIDE[0], VALUE_COL])
		rows.append(row)
	return rows


static func _on(v: bool) -> String:
	return "켬" if v else "끔"


func _keys() -> Array:
	var rows := []
	for k in _actions().size():
		var action: StringName = _actions()[k]
		var keys := ", ".join(Keys.keys_of(action).map(Keys.label))
		if waiting and k == selected:
			keys = "키를 누르세요"
		rows.append([[Keys.ACTIONS[action][0], Palette.TEXT], [keys, Palette.SIDE[0], VALUE_COL]])
	rows.append([["모두 기본값", Palette.TEXT]])
	return rows


## Every action with its keys; the talismans share a row.
static func _help() -> Array:
	var rows := []
	for action in Keys.ACTIONS:
		if action.begins_with("pick_") and action != &"pick_1":
			continue
		var name: String = Keys.ACTIONS[action][0]
		var keys := Keys.keys_of(action).map(Keys.label)
		var sep := ", "
		if action == &"pick_1":
			sep = " "
			name = "부적 고르기"
			keys = []
			for i in range(1, Cards.ALL.size() + 1):
				keys.append("/".join(Keys.keys_of(StringName("pick_%d" % i)).map(Keys.label)))
		rows.append([[name, Palette.TEXT], [sep.join(keys), Palette.SIDE[0], VALUE_COL]])
	rows.append([[LOOK[0], Palette.TEXT], [LOOK[1], Palette.DIM, VALUE_COL]])
	for m in MOUSE:
		rows.append([[m[0], Palette.TEXT], [m[1], Palette.DIM, VALUE_COL]])
	return rows
