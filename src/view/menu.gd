class_name Menu
extends RefCounted
## Full-screen pages over the game, moved through with the direction keys,
## Enter and Esc, or the pointer: help lists every action with its keys;
## options change the settings; key settings bind keys to actions; the
## spellbook lists the queued spell and the saved ones, with what the selected
## one does, and a slot key saves it to that slot; the 도감 (Codex) lists every
## creature, spell, compound, item and terrain feature; the log lists the past
## messages; the credits list the notices of what the game is made with (NOTICES); the
## dispel page lists the buffs on Miho to drop; the debug commands
## (DebugMenu) list the Cheat commands. Every page
## moves as ListNav says, scrolls with the wheel, lights the row under the
## pointer, and a click selects it.
## `key`, `use`, `click` and `back` return what the game should do: &"close",
## &"changed" (settings or keys changed), &"ask" (처음부터 asks for a second use),
## &"restart", &"quit" (save and end the
## game), &"seed" (copy the seed), &"cast" (pick `chosen`), &"dispel" (drop the
## buff on the selected row), or nothing. The debug commands are the one page that is a
## box over the game: from the options it has no page to go back to, so Esc closes it.

## The groups of the help page under the moves: a title and its actions.
const HELP := [
	[
		"주문",
		[&"pick_1", &"confirm", &"self", &"again", &"unpick", &"slot_1", &"spellbook", &"dispel"],
	],
	[
		"탐험",
		[
			&"wait",
			&"rest",
			&"explore",
			&"fight",
			&"stairs",
			&"close",
			&"look",
			&"describe",
			&"exclude",
			&"exclude_clear",
			&"scent",
		],
	],
	["화면", [&"help", &"codex", &"log", &"cancel"]],
	["게임", [&"restart", &"regenerate", &"debug", &"cheat"]],
]
## What the throw key does besides throwing, in the words of the hover's key hints
## (LookMode.hints), before the action's name on its line of the help page.
const ALSO := {&"confirm": ["이동", "공격"]}
## What marks the first line of a round on the log page, and the cells the lines stand in
## to make room for it.
const ROUND_MARK := "_"
const MARK_CELLS := 1.5
## Cells the lines of a group of the help page stand in from its title.
const INDENT := 1.0
## The first of a run of actions that share one line of the help page, and the line's name.
const SHARED := {&"pick_1": "부적 고르기", &"slot_1": "저장 주문"}
## Cells between the longest name of a list and the values beside the names.
const GAP := 2.0
const MOUSE := [
	["왼쪽 클릭", "옆 칸으로 한 걸음, 먼 칸까지 걷기"],
	["부적 고르고 클릭", "그쪽으로 던지기"],
	["당신을 왼쪽 클릭", "주문 해제"],
	["오른쪽 클릭", "취소"],
	["가리키기", "무엇이 있는지 보기"],
	["단어 왼쪽 클릭", "도감에서 열기"],
	["마우스 뒤로/앞으로 버튼", "도감에서 뒤로/앞으로 가기"],
	["Alt+왼쪽/오른쪽", "도감에서 뒤로/앞으로 가기"],
	["[ ]", "도감 예시 고르기"],
	["Shift", "정보창 고정"],
]
## Tiles the look cursor moves with Shift held.
const LOOK_FAR := 5
const LOOK := [
	"살피는 중",
	"방향키로 커서 이동 (Shift는 %d칸), Enter 걷기, 위험구역 키로 표시 (그 위에서 1-%d 반지름), Esc 끝",
]
## Enter or a click raises one of these, and from 100 takes it back to 0.
const SLIDERS := [&"volume", &"music", &"crt"]
## The rows of the options in three groups, the settings, the pages and the run, with a
## blank row (&"") between them.
const OPTIONS := [
	&"volume",
	&"music",
	&"crt",
	&"zoom",
	&"speed",
	&"scent",
	&"language",
	&"korean_symbols",
	&"",
	&"codex",
	&"spells",
	&"log",
	&"help",
	&"keys",
	&"credits",
	&"",
	&"close",
	&"seed",
	&"dispel",
	&"cheat",
	&"restart",
	&"quit",
]
const OPTION_NAMES := {
	&"volume": "소리 크기",
	&"music": "음악 크기",
	&"crt": "브라운관 효과",
	&"zoom": "화면 크기",
	&"speed": "움직임 속도",
	&"scent": "냄새 보기",
	&"language": "언어",
	&"korean_symbols": "한글 기호",
	&"replay": "명장면 다시보기",
	&"codex": "도감",
	&"keys": "키 설정",
	&"spells": "주문서",
	&"dispel": "주문 해제",
	&"log": "기록",
	&"help": "도움말",
	&"credits": "크레딧",
	&"seed": "시드",
	&"cheat": "디버그 명령",
	&"restart": "처음부터",
	&"quit": "저장하고 끝내기",
	&"close": "계속",
}
const RESTART_SURE := "정말 처음부터 시작할까?"
## What the credits list after Godot's own notices: each a title, where its source is and
## the file of its notice.
const NOTICES := [
	["godot-rust", "https://github.com/godot-rust/gdext", "res://assets/licenses/godot-rust.txt"],
	["glam", "https://github.com/bitshifter/glam-rs", "res://assets/licenses/glam.txt"],
	["libc", "https://github.com/rust-lang/libc", "res://assets/licenses/libc.txt"],
	["Neo둥근모", "https://neodgm.dalgona.dev", "res://assets/fonts/NeoDunggeunmo-OFL.txt"],
	["DotGothic16", "https://fonts.google.com/specimen/DotGothic16", "res://assets/fonts/DotGothic16-OFL.txt"],
	["음악과 효과음", "", "res://assets/licenses/music.txt"],
	["Brogue CE", "https://github.com/tmewett/BrogueCE", "res://assets/licenses/brogue-ce.txt"],
	[
		"Dungeon Crawl Stone Soup",
		"https://github.com/crawl/crawl",
		"res://assets/licenses/dcss.txt"
	],
]
const MODIFIERS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

var settings := Settings.new()
## The seed of the run, a row of the options (DCSS shows it in its version page),
## and whether Enter on it copied it since the page opened.
var seed_value := 0
var copied := false
var page := &""
var selected := 0:
	set(row):
		confirming = confirming and row == selected
		selected = row
## 처음부터 was used once and waits for a second use; leaving the row or Esc
## takes it back.
var confirming := false
## The first row shown, and the row the pointer is over (-1 for none).
var top := 0
var hovered := -1
## On the spellbook: the first line of the detail shown, by row.
var detail_tops := {}
## On the key page: the selected action waits for the key to bind.
var waiting := false
## The spell queued when the spellbook opened (or null), and the spell Enter chose there.
var queued: Spell
var chosen: Spell
## The buffs on Miho (Guise.worn) when the menu opened, which the dispel page lists.
var buffs := []
## The messages the log page lists, as rows.
var log_rows: Array = []
## The lines of the credits, wrapped to the screen width `credit_width` they were made for.
var credit_rows: Array = []
var credit_width := -1
## The 도감 page's tab, entry and scroll; it keeps them when closed.
var codex := Codex.new()
## The debug commands page; it keeps its row when closed.
var debug := DebugMenu.new()
## The title is showing: no run is being played, so the options leave out the
## debug commands, which would write to the run on disk.
var title := false
## The screen in cells, for the pages to fit their lists.
var room := Vector2i(40, 18):
	set(v):
		room = v
		codex.room = v
		debug.room = v
## The page this one was opened from and the row it was opened on; Esc goes back
## there. Empty when the game opened it.
var origin := &""
var origin_row := 0


## Takes what the pages list from the game `m` (main.gd).
func sync(m: Node) -> void:
	queued = Spell.make(m.casting.picked)
	log_rows = log_of(m.messages.lines)
	seed_value = m.run_seed
	debug.world = m.world
	title = m.state == &"title"
	buffs = Guise.worn(m.world, m.world.player())
	codex.rank = Bestiary.rank(m.world.storey())


## The rows of the log page: every message as shown, the first of each round after a dim
## ROUND_MARK and the rest in line with it (DCSS message_window::new_cmdturn).
static func log_of(lines: Array) -> Array:
	var rows := []
	for k in lines.size():
		var first: bool = k == 0 or Messages.turn(lines[k]) != Messages.turn(lines[k - 1])
		var mark := [ROUND_MARK if first else "", Palette.DIM, 2.0]
		rows.append([mark, ["", Palette.DIM, 2.0 + MARK_CELLS]] + Messages.shown(lines[k]))
	return rows


## Opens a page, `size` the screen in cells when it changes.
func open(p: StringName, size := Vector2i.ZERO) -> void:
	page = p
	confirming = false
	selected = 0
	top = 0
	detail_tops.clear()
	hovered = -1
	waiting = false
	copied = false
	origin = &""
	if size != Vector2i.ZERO:
		room = size
	codex.hover = -1
	codex.lit = -1
	codex.trail.clear()
	codex.ahead.clear()
	codex.select(codex.selected)
	if p == &"cheat":
		debug.open(room)
	if p == &"options":
		selected = _listed().find(&"close")
		top = ListNav.reveal(0, selected, _listed().size(), _fits())
	if p == &"log":
		top = maxi(0, log_rows.size() - _fits())
	credit_width = -1


## A left click on the word `word` of the open page: its 도감 entry opens. Esc
## returns to the entry it was opened from, or to the page.
func link(word: String) -> void:
	var inside := page == &"codex"
	if not inside:
		_enter(&"codex")
	codex.link(word, inside)


## Opens a page from the current one, which Esc then returns to.
func _enter(p: StringName) -> void:
	var from := page
	var row := selected
	open(p)
	origin = from
	origin_row = row


## What the page shows, as a Term.panel.
func panel() -> Dictionary:
	var out := {}
	match page:
		&"options":
			var listed := _listed()
			var blank := range(listed.size()).filter(func(k): return listed[k] == &"")
			out = {title = "", rows = _options(), inert = blank}
		&"keys":
			out = {title = Lang.t("키 설정"), rows = _aligned(_keys())}
		&"spells":
			var list := spells()
			var detail: Array = SpellInfo.spell(list[selected]) if not list.is_empty() else []
			var rows := _spells(list)
			var from: int = detail_tops.get(selected, 0)
			var fit := _detail_fit(detail)
			var shown := detail.slice(from, from + fit)
			out = {
				title = Lang.t("주문서"),
				rows = rows,
				detail = shown,
				aside_up = from > 0,
				aside_down = from + fit < detail.size(),
				example = _example(list, rows, shown),
				bar = not list.is_empty()
			}
		&"dispel":
			out = {title = Lang.t("주문 해제"), rows = _dispels(), bar = not buffs.is_empty()}
		&"log":
			var none := [[[Lang.t("기록이 없다"), Palette.DIM]]]
			out = {
				title = Lang.t("기록"),
				rows = log_rows if log_rows else none,
				painted = true,
				words = true,
				bar = false
			}
		&"credits":
			out = {title = Lang.t("크레딧"), rows = _credits(), painted = true, bar = false}
		&"codex":
			return codex.panel()
		&"cheat":
			return debug.panel()
		_:
			out = {title = Lang.t("도움말"), rows = _help(), words = true, bar = false}
	out.merge({selected = selected, top = top, hover = hovered, bar = true})
	return out


## The lines of the spellbook's `detail` that fit under one row of the list.
func _detail_fit(detail: Array) -> int:
	return detail.size() if room.y <= 0 else mini(detail.size(), maxi(1, room.y - 5))


## Rows of the page's list that fit.
func _fits() -> int:
	return PanelView.fits(room.y, panel().get("detail", []).size())


## Handles a key press.
func key(e: InputEventKey) -> StringName:
	if page == &"codex" and e.alt_pressed and e.keycode in [KEY_LEFT, KEY_RIGHT]:
		return &"" if e.is_echo() else history(e.keycode == KEY_RIGHT)
	var nav := _nav(e)
	if e.is_echo() and not nav in ListNav.REPEATS:
		return &""
	if waiting:
		return _bind(e)
	if page == &"codex":
		var out := codex.key(e, nav)
		return _leave() if out == &"close" else out
	if page == &"cheat":
		var out := debug.key(e, nav)
		return _leave() if out == &"close" and debug.request.is_empty() else out
	var slot := Keys.action_of(e)
	var out := &"changed"
	if page in [&"help", &"log", &"dispel"] and slot == page:
		out = _leave()
	elif page == &"spells" and Keys.SLOTS.has(slot) and not spells().is_empty():
		save(slot)
	elif (
		page == &"keys"
		and e.keycode in [KEY_DELETE, KEY_BACKSPACE]
		and selected < _actions().size()
	):
		Keys.bind(_actions()[selected], [])
	else:
		out = _move(nav)
	return out


## Saves the selected spell in `slot`, or clears the slot when it holds that spell.
func save(slot: StringName) -> void:
	var k := spells()[selected].key()
	var had: bool = settings.spells.get(slot, "") == k
	for s in settings.spells.keys():
		if settings.spells[s] == k:
			settings.spells.erase(s)
	if not had:
		settings.spells[slot] = k
	selected = mini(selected, maxi(0, spells().size() - 1))


## Menu movement `nav` on the page's list; what the game should do.
func _move(nav: StringName) -> StringName:
	var out := &""
	match nav:
		&"up", &"down", &"page_up", &"page_down", &"home", &"end" when not panel().bar:
			# A page that is only read scrolls, with no row selected.
			var last := maxi(0, panel().rows.size() - _fits())
			top = ListNav.step(nav, mini(top, last), last + 1, _fits())
		&"up", &"down", &"page_up", &"page_down", &"home", &"end":
			var shown := panel()
			var count: int = shown.rows.size()
			selected = ListNav.step(nav, selected, count, _fits(), shown.get("inert", []))
			top = ListNav.reveal(top, selected, count, _fits())
		&"left", &"right":
			out = _change(1 if nav == &"right" else -1)
		&"enter":
			out = use()
		&"back":
			out = _leave()
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
		var key := slot_key(settings.spells, s.key())
		var row := [[key, Palette.KEY, 4.0 - Term.key_cells(key), &"key"]]
		for k in s.slots.size():
			row.append(
				[Lang.t(Cards.GLYPH[s.slots[k]], "talisman"), Palette.card(s.slots[k]), 4.0 + k]
			)
		row.append([Lang.t("꼬리 %d") % s.cost(), Palette.DIM, 10.0])
		row.append([s.shown(), Palette.TEXT, 14.0])
		rows.append(row)
	if rows.is_empty():
		rows.append([[Lang.t("고른 부적도, 저장한 주문도 없다"), Palette.DIM]])
	return rows


## The example of the selected spell (CodexSim) in the top right corner, where none of the
## rows or the detail reaches; empty when the page has no room for it.
func _example(list: Array[Spell], rows: Array, detail: Array) -> Dictionary:
	var texts: Array[Rect2] = []
	for k in rows.size():
		texts.append(Rect2(2, 3 + k - top, PanelView.end(rows[k]) - 2, 1))
	for k in detail.size():
		texts.append(Rect2(2, room.y - detail.size() + k, PanelView.end(detail[k]) - 2, 1))
	var fit := CodexSim.corner(room, texts)
	if list.is_empty() or fit.is_empty():
		return {}
	var spell := list[selected]
	return fit.merged({entry = [page, spell.key()], scene = SpellScene.of(spell.cards), rank = 0})


## The dispel key in the game `m` (main.gd): drops the one buff on Miho, or lists
## them when she wears more.
static func dispel(m: Node) -> void:
	var on := Guise.worn(m.world, m.world.player())
	if on.size() > 1:
		m.panels.open(&"dispel")
	elif on.size() == 1:
		m.act({t = &"dispel", kind = on[0]})
	else:
		m.say("풀 수 있는 주문이 없다")
		m.sfx.play(&"click")


## Every buff on Miho as a row: its name.
func _dispels() -> Array:
	var rows := []
	for kind: StringName in buffs:
		var last: StringName = Spell.make(Guise.RECIPE[kind]).slots.back()
		rows.append([[Lang.t(Guise.NAME[kind]), Palette.card(last)]])
	return rows if rows else [[[Lang.t("풀 수 있는 주문이 없다"), Palette.DIM]]]


## The pointer is over row k (-1 for none): it lights.
func point(k: int) -> void:
	hovered = k
	codex.hover = k
	debug.point(k)


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
		if page == &"cheat":
			return debug.click(row)
		if not PanelView.acts(panel(), row):
			return &""
		select(row)
		return use() if page in [&"options", &"keys", &"spells", &"dispel"] else &""
	return &""


## Selects row `row` of the page's list, without using it.
func select(row: int) -> void:
	selected = row
	top = ListNav.reveal(top, selected, panel().rows.size(), _fits())


## The wheel turns `dir` notches (1 down) over the detail (`aside`) or the list.
func wheel(dir: int, aside: bool) -> void:
	scroll_by(dir * ListNav.WHEEL, aside)


## Scrolls `lines` rows of the list, or lines of the 도감's detail.
func scroll_by(lines: int, aside: bool) -> void:
	if page == &"codex":
		codex.scroll_by(lines, aside)
	elif page == &"cheat":
		debug.scroll_by(lines)
	elif page == &"spells" and aside:
		var detail: Array = SpellInfo.spell(spells()[selected]) if not spells().is_empty() else []
		var last := detail.size() - _detail_fit(detail)
		detail_tops[selected] = clampi(detail_tops.get(selected, 0) + lines, 0, last)
	else:
		top = ListNav.scrolled(top, lines, panel().rows.size(), _fits())


## Enter on the selected row.
func use() -> StringName:
	match page:
		&"help", &"log", &"credits":
			return _leave()
		&"spells":
			return _choose()
		&"dispel":
			return &"dispel" if not buffs.is_empty() else _leave()
		&"keys":
			return _use_key_row()
		&"options":
			return _use_option()
	return &""


func _use_option() -> StringName:
	var row: StringName = _listed()[selected]
	match row:
		&"keys", &"codex", &"spells", &"dispel", &"log", &"help", &"credits":
			_enter(row)
			return &""
		&"cheat":
			open(row)
			return &""
		&"restart" when not confirming:
			confirming = true
			return &"ask"
		&"restart", &"quit", &"close":
			return row
		&"seed":
			copied = true
			return row
	return _change(-10 if row in SLIDERS and settings.get(row) == 100 else 1)


func _use_key_row() -> StringName:
	if selected >= _actions().size():
		Keys.reset()
		return &"changed"
	waiting = true
	return &""


## Esc or a right click: the debug page goes back as DebugMenu says; a page
## opened from another goes back to it, on the row it was opened from; others
## close.
func back() -> StringName:
	if page == &"cheat":
		var out := debug.back()
		return _leave() if out == &"close" else out
	return _leave()


## A browser's back and forward in the 도감: back goes as Esc does. Other pages
## ignore them.
func history(go_forward: bool) -> StringName:
	if page != &"codex":
		return &""
	if go_forward:
		codex.forward()
		return &""
	return back()


func _leave() -> StringName:
	if confirming:
		confirming = false
		return &""
	if page == &"codex" and codex.back():
		return &""
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
	match _listed()[selected]:
		&"volume":
			settings.volume = clampi(settings.volume + step * 10, 0, 100)
		&"music":
			settings.music = clampi(settings.music + step * 10, 0, 100)
		&"crt":
			settings.crt = clampi(settings.crt + step * 10, 0, 100)
		&"zoom":
			settings.zoom = _cycle(Settings.ZOOMS, settings.zoom, step)
		&"speed":
			settings.speed = _cycle(Settings.SPEEDS, settings.speed, step)
		&"scent":
			settings.scent = not settings.scent
		&"language":
			var codes := Lang.NAMES.keys()
			settings.language = codes[posmod(
				codes.find(StringName(settings.language)) + step, codes.size()
			)]
			settings.apply_language()
		&"korean_symbols":
			settings.korean_symbols = not settings.korean_symbols
			settings.apply_language()
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
	var k := OS.get_keycode_string((Keys.pad(e) as InputEventKey).get_keycode_with_modifiers())
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


## The options the page lists.
func _listed() -> Array:
	return OPTIONS.filter(
		func(o): return not (title and o in [&"cheat", &"spells", &"dispel", &"log"])
	)


func _options() -> Array:
	var values := {
		&"volume": str(settings.volume) if settings.volume > 0 else Lang.t("꺼짐"),
		&"music": str(settings.music) if settings.music > 0 else Lang.t("꺼짐"),
		&"crt": str(settings.crt) if settings.crt > 0 else Lang.t("꺼짐"),
		&"zoom": Lang.t("맞춤") if settings.zoom == 0.0 else str(settings.zoom),
		&"language": Lang.NAMES[StringName(settings.language)],
		&"speed": "%dx" % int(settings.speed),
		&"scent": _on(settings.scent),
		&"replay": _on(settings.replay),
		&"korean_symbols": _on(settings.korean_symbols),
		&"seed": Lang.t("%d 복사했다") % seed_value if copied else str(seed_value),
	}
	var rows := []
	for o in _listed():
		if o == &"":
			rows.append([])
			continue
		var name: String = RESTART_SURE if o == &"restart" and confirming else OPTION_NAMES[o]
		var row := [[Lang.t(name), Palette.TEXT]]
		if values.has(o):
			row.append([values[o], Palette.SIDE[0]])
		rows.append(row)
	return _aligned(rows)


## Puts the value of each row that has one a GAP past the longest name among those rows.
static func _aligned(rows: Array) -> Array:
	var valued := rows.filter(func(r): return r.size() > 1)
	var widest: float = valued.reduce(func(n, r): return maxf(n, PanelView.end([r[0]])), 2.0)
	for row: Array in valued:
		row[1].append(widest + GAP)
	return rows


static func _on(v: bool) -> String:
	return Lang.t("켜짐") if v else Lang.t("꺼짐")


func _keys() -> Array:
	var rows := []
	for k in _actions().size():
		var action: StringName = _actions()[k]
		var keys := ", ".join(Keys.keys_of(action).map(Keys.label))
		if waiting and k == selected:
			keys = Lang.t("키 입력 대기")
		rows.append([[Lang.t(Keys.ACTIONS[action][0]), Palette.TEXT], [keys, Palette.SIDE[0]]])
	rows.append([[Lang.t("모두 기본값"), Palette.TEXT]])
	return rows


## The credits as rows: Godot's license, the parts of Godot under other licenses and those
## licenses (Godot's "Complying with licenses"), then each of NOTICES, every line wrapped to
## the screen. Made again only when the width changes.
func _credits() -> Array:
	if credit_width == room.x:
		return credit_rows
	var parts := []
	for c: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in c.parts:
			parts.append("\n".join([c.name] + Array(part.copyright) + [part.license]))
	var notices := [
		["Godot Engine", "https://godotengine.org", Engine.get_license_text()],
		["", "", "\n\n".join(parts)],
	]
	var licenses := Engine.get_license_info()
	for name: String in licenses:
		notices.append([name, "", licenses[name]])
	for n: Array in NOTICES:
		notices.append([Lang.t(n[0]), n[1], FileAccess.get_file_as_string(n[2])])
	credit_rows = []
	credit_width = room.x
	for n: Array in notices:
		if n[0] != "":
			var head := [[n[0], Palette.KIND[&"miho"]], ["  " + n[1], Palette.DIM]]
			credit_rows.append_array(Keywords.rows_of(head, room.x - 4.0))
		for line in n[2].strip_edges(false, true).replace("\t", "    ").split("\n"):
			var cut := _cut(line, room.x - 4.0)
			credit_rows.append_array(Keywords.rows_of([[cut, Palette.TEXT]], room.x - 4.0))
		credit_rows.append([])
	return credit_rows


## `line` with a space put into each word wider than `width` cells where its row ends, so that
## Keywords.rows_of breaks it there (a rule of dashes in a license).
static func _cut(line: String, width: float) -> String:
	var words := line.split(" ")
	for i in words.size():
		var word := words[i]
		var cut := ""
		while Term.text_cells(word) > width:
			var k := word.length() - 1
			while k > 1 and Term.text_cells(word.left(k)) > width:
				k -= 1
			cut += word.left(k) + " "
			word = word.substr(k)
		words[i] = cut + word
	return " ".join(words)


## Every action with its keys, in groups under a title, side by side in two columns
## when the screen is wide enough (DCSS _add_formatted_keyhelp).
func _help() -> Array:
	var groups := [_moves()]
	for group: Array in HELP:
		groups.append(_titled(group[0], _named(group[1].map(_help_row))))
	var mouse := MOUSE.map(
		func(m): return [[Lang.t(m[0]), Palette.TEXT], [Lang.t(m[1]), Palette.DIM]]
	)
	var mice := _titled("마우스", _named(mouse))
	var look: String = Lang.t(LOOK[1]) % [LOOK_FAR, Exclusions.MAX_RADIUS]
	var lines := Keywords.rows_of([[look, Palette.DIM]], _width(groups + [mice]) - INDENT)
	groups.append(_titled(LOOK[0], lines.map(func(l): return [l[0] + [0.0]] + l.slice(1))))
	groups.append(mice)
	# The two columns that fit the screen with the fewest rows; one column if none do.
	var count := func(gs: Array) -> int: return gs.reduce(func(n, g): return n + g.size(), 0)
	var best := [groups.size(), 0.0, INF]
	for k in range(1, groups.size()):
		var right := 2.0 + _width(groups.slice(0, k)) + GAP * 2
		var rows: int = maxi(count.call(groups.slice(0, k)), count.call(groups.slice(k)))
		if right + _width(groups.slice(k)) <= room.x and rows < best[2]:
			best = [k, right, rows]
	return _beside(groups.slice(0, best[0]), groups.slice(best[0]), best[1])


## The cells the widest line of the groups `groups` takes.
static func _width(groups: Array) -> float:
	var lines: Array = groups.reduce(func(all, g): return all + g, [])
	return lines.reduce(func(n, line): return maxf(n, PanelView.end(line, 0.0)), 0.0)


## The rows of the groups `left`, and beside them from column `right` the groups `right`.
static func _beside(left: Array, right: Array, at: float) -> Array:
	var one := func(gs: Array) -> Array: return gs.reduce(func(all, g): return all + g, [])
	var a: Array = one.call(left)
	var b: Array = one.call(right)
	var rows := []
	for k in maxi(a.size(), b.size()):
		var row := _shifted(a[k], 2.0) if k < a.size() else []
		rows.append(row + (_shifted(b[k], at) if k < b.size() else []))
	return rows


## A line whose runs have their columns moved `by` cells.
static func _shifted(line: Array, by: float) -> Array:
	return line.map(func(run): return run.map(func(v): return v + by if v is float else v))


## A group of the help page: its title over its lines.
static func _titled(title: String, lines: Array) -> Array:
	var title_line := [[Lang.t(title), Palette.KIND[&"miho"], 0.0]]
	return [title_line] + lines.map(func(line): return _shifted(line, INDENT))


## Lines of a name and a value, the names at column 0 and the values lined up a GAP past
## the longest name.
static func _named(lines: Array) -> Array:
	for line: Array in lines:
		line[0].append(0.0)
	return _aligned(lines)


## An action as a line of the help page: its name and its keys. The talismans and the saved
## spells share one line each.
static func _help_row(action: StringName) -> Array:
	var name: String = " · ".join(
		(ALSO.get(action, []) + [Keys.ACTIONS[action][0]]).map(func(w): return Lang.t(w))
	)
	var keys := ", ".join(Keys.keys_of(action).map(Keys.label))
	if action in SHARED:
		name = Lang.t(SHARED[action])
		var all: Array = Keys.SLOTS
		if action == &"pick_1":
			all = range(1, Cards.ALL.size() + 1).map(func(i): return StringName("pick_%d" % i))
		keys = " ".join(all.map(func(a): return "/".join(Keys.keys_of(a).map(Keys.label))))
	return [[name, Palette.TEXT], [keys, Palette.SIDE[0]]]


## The move keys as a square for each set of them (the keypad, the arrows, the others), the
## wait key of the set in the middle and the name the set's keys share over it.
static func _moves() -> Array:
	var sets := {}
	for action in Keys.MOVES.keys() + [&"wait"]:
		var dir: Vector2i = Keys.MOVES.get(action, Vector2i.ZERO)
		for key in Keys.keys_of(action):
			var kind := _key_set(key)
			if action != &"wait":
				sets.get_or_add(kind, {})
			if sets.has(kind) and not sets[kind].has(dir):
				sets[kind][dir] = key
	var lines := [[], [], [], []]
	var x := 0.0
	for keys: Dictionary in sets.values():
		var labels := {}
		for dir in keys:
			labels[dir] = _glyph(keys[dir])
		var shared := _prefix(labels.values())
		var widths := [0.0, 0.0, 0.0]
		for dir in labels:
			labels[dir] = labels[dir].trim_prefix(shared)
			widths[dir.x + 1] = maxf(widths[dir.x + 1], Term.text_cells(labels[dir]))
		if shared != "":
			lines[0].append([shared.strip_edges(), Palette.DIM, x])
		for dir in labels:
			var at: float = x + widths.slice(0, dir.x + 1).reduce(func(n, w): return n + w, 0.0)
			at += dir.x + 1 + (widths[dir.x + 1] - Term.text_cells(labels[dir])) / 2.0
			lines[dir.y + 2].append([labels[dir], Palette.SIDE[0], at])
		x += widths.reduce(func(n, w): return n + w, 0.0) + 2.0 + GAP * 2
	return _titled("이동", lines if lines[0] else lines.slice(1))


## Which set a key belongs to: the keypad, the arrows or the others.
static func _key_set(key: String) -> StringName:
	var code := OS.find_keycode_from_string(key)
	if key.begins_with("Kp "):
		return &"pad"
	return &"arrows" if code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] else &"other"


## A key as one character where it is one with no modifier, such as the full stop, else its
## label.
static func _glyph(key: String) -> String:
	var code := OS.find_keycode_from_string(key)
	return char(code) if code > 32 and code < 127 else Keys.label(key)


## The words every label starts with, up to the last space they share.
static func _prefix(labels: Array) -> String:
	var out: String = labels[0]
	for l: String in labels:
		while not l.begins_with(out):
			out = out.left(-1)
	return out.left(out.rfind(" ") + 1)
