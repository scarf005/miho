class_name Menu
extends RefCounted
## Full-screen pages over the game, moved through with the direction keys,
## Enter and Esc, or the pointer: help lists every action with its keys;
## options change the settings; key settings bind keys to actions.
## `key`, `use` and `back` return what the game should do: &"close",
## &"changed" (settings or keys changed), &"restart", or nothing.

const VALUE_COL := 13.0
const MOUSE := [
	["왼쪽 클릭", "옆 칸으로 한 걸음, 먼 칸까지 걷기"],
	["부적 고르고 클릭", "그쪽으로 던지기"],
	["오른쪽 클릭", "취소"],
	["가리키기", "무엇이 있는지 보기"],
]
const OPTIONS := [&"volume", &"crt", &"zoom", &"speed", &"replay", &"keys", &"restart", &"close"]
const OPTION_NAMES := {
	&"volume": "소리 크기",
	&"crt": "CRT 효과",
	&"zoom": "화면 크기",
	&"speed": "움직임 속도",
	&"replay": "명장면 다시보기",
	&"keys": "키 설정",
	&"restart": "처음부터",
	&"close": "계속",
}
const MODIFIERS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

var settings := Settings.new()
var page := &""
var selected := 0
## On the key page: the selected action waits for the key to bind.
var waiting := false


func open(p: StringName) -> void:
	page = p
	selected = 0
	waiting = false


## What the page shows, as a Term.panel.
func panel() -> Dictionary:
	match page:
		&"options":
			return {title = "설정", rows = _options(), selected = selected}
		&"keys":
			return {title = "키 설정", rows = _keys(), selected = selected}
	return {title = "도움말", rows = _help(), selected = selected}


## Handles a key press.
func key(e: InputEventKey) -> StringName:
	if waiting:
		return _bind(e)
	if (
		page == &"keys"
		and e.keycode in [KEY_DELETE, KEY_BACKSPACE]
		and selected < _actions().size()
	):
		Keys.bind(_actions()[selected], [])
		return &"changed"
	var nav := _nav(e)
	var out := &""
	match nav:
		&"up", &"down":
			selected = clampi(selected + (1 if nav == &"down" else -1), 0, panel().rows.size() - 1)
		&"left", &"right":
			out = _change(1 if nav == &"right" else -1)
		&"enter":
			out = use()
		&"back":
			out = back()
		_:
			out = &"close" if page == &"help" else &""
	return out


## The pointer is over row k.
func point(k: int) -> void:
	if k >= 0 and not waiting:
		selected = k


## Enter on the selected row.
func use() -> StringName:
	if page == &"help":
		return &"close"
	if page == &"keys":
		if selected >= _actions().size():
			Keys.reset()
			return &"changed"
		waiting = true
		return &""
	var row: StringName = OPTIONS[selected]
	match row:
		&"keys":
			open(&"keys")
			return &""
		&"restart", &"close":
			return row
	return _change(1)


## Esc: the key page goes back to the options, others close.
func back() -> StringName:
	if page == &"keys":
		open(&"options")
		selected = OPTIONS.find(&"keys")
		return &""
	return &"close"


## Steps the selected option's value; wraps around.
func _change(step: int) -> StringName:
	if page != &"options":
		return &""
	match OPTIONS[selected]:
		&"volume":
			settings.volume = clampi(settings.volume + step * 10, 0, 100)
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


## A key as menu movement: up, down, left, right, enter, back, or empty.
## Arrows, Enter and Esc always work, whatever the bindings.
static func _nav(e: InputEventKey) -> StringName:
	var raw := {
		KEY_UP: &"up",
		KEY_DOWN: &"down",
		KEY_LEFT: &"left",
		KEY_RIGHT: &"right",
		KEY_ENTER: &"enter",
		KEY_KP_ENTER: &"enter",
		KEY_ESCAPE: &"back",
	}
	if raw.has(e.keycode):
		return raw[e.keycode]
	var bound := {
		&"move_n": &"up",
		&"move_s": &"down",
		&"move_w": &"left",
		&"move_e": &"right",
		&"confirm": &"enter",
		&"cancel": &"back",
		&"options": &"back",
	}
	return bound.get(Keys.action_of(e), &"")


func _options() -> Array:
	var values := {
		&"volume": str(settings.volume),
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


## Every action with its keys; the seven talismans share a row.
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
			for i in range(1, 8):
				keys.append("/".join(Keys.keys_of(StringName("pick_%d" % i)).map(Keys.label)))
		rows.append([[name, Palette.TEXT], [sep.join(keys), Palette.SIDE[0], VALUE_COL]])
	for m in MOUSE:
		rows.append([[m[0], Palette.TEXT], [m[1], Palette.DIM, VALUE_COL]])
	return rows
