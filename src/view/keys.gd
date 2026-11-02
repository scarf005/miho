class_name Keys
extends RefCounted
## The game's input actions: their names, default keys, and which action a
## key press means. Keys are written as Godot keycode strings with modifiers
## ("Shift+Period"), the form OS.find_keycode_from_string reads.

const MOVES := {
	&"move_n": Vector2i(0, -1),
	&"move_ne": Vector2i(1, -1),
	&"move_e": Vector2i(1, 0),
	&"move_se": Vector2i(1, 1),
	&"move_s": Vector2i(0, 1),
	&"move_sw": Vector2i(-1, 1),
	&"move_w": Vector2i(-1, 0),
	&"move_nw": Vector2i(-1, -1),
}
## Saved-spell slots, in order.
const SLOTS: Array[StringName] = [&"slot_1", &"slot_2", &"slot_3", &"slot_4", &"slot_5", &"slot_6"]
## Key names as the player reads them; the font has no arrow glyphs.
const SHOWN := {
	"Period": "마침표(.)",
	"Kp Period": "키패드 .",
	"Comma": "쉼표(,)",
	"Up": "방향키 위",
	"Down": "방향키 아래",
	"Left": "방향키 왼쪽",
	"Right": "방향키 오른쪽",
	"Escape": "Esc",
	"Shift+Period": ">",
	"Shift+Slash": "?",
}
## action -> [name, default keys]
const ACTIONS := {
	&"move_n": ["위로", ["Up", "Kp 8", "K"]],
	&"move_ne": ["오른쪽 위로", ["Kp 9", "U"]],
	&"move_e": ["오른쪽으로", ["Right", "Kp 6", "L"]],
	&"move_se": ["오른쪽 아래로", ["Kp 3", "N"]],
	&"move_s": ["아래로", ["Down", "Kp 2", "J"]],
	&"move_sw": ["왼쪽 아래로", ["Kp 1", "B"]],
	&"move_w": ["왼쪽으로", ["Left", "Kp 4", "H"]],
	&"move_nw": ["왼쪽 위로", ["Kp 7", "Y"]],
	&"wait": ["기다리기", ["Period", "Kp 5", "Kp Period"]],
	&"confirm": ["던지기", ["Enter", "Kp Enter", "Space"]],
	&"self": ["스스로에게 걸기", ["Comma"]],
	&"pick_1": ["부적 1", ["1"]],
	&"pick_2": ["부적 2", ["2"]],
	&"pick_3": ["부적 3", ["3"]],
	&"pick_4": ["부적 4", ["4"]],
	&"pick_5": ["부적 5", ["5"]],
	&"pick_6": ["부적 6", ["6"]],
	&"pick_7": ["부적 7", ["7"]],
	&"again": ["같은 주문 다시", ["F"]],
	&"spellbook": ["주문서", ["I"]],
	&"slot_1": ["저장 주문 1", ["Q"]],
	&"slot_2": ["저장 주문 2", ["W"]],
	&"slot_3": ["저장 주문 3", ["E"]],
	&"slot_4": ["저장 주문 4", ["A"]],
	&"slot_5": ["저장 주문 5", ["S"]],
	&"slot_6": ["저장 주문 6", ["D"]],
	&"unpick": ["주문 하나 빼기", ["Ctrl"]],
	&"cancel": ["취소 / 설정", ["Escape", "F10"]],
	&"stairs": ["계단으로 가기", ["Shift+Period"]],
	&"explore": ["자동 탐험", ["O"]],
	&"fight": ["자동 공격", ["Tab"]],
	&"look": ["살펴보기", ["X"]],
	&"rest": ["쉬기", ["Z"]],
	&"close": ["문 닫기", ["C"]],
	&"exclude": ["위험구역 표시", ["V"]],
	&"exclude_clear": ["위험구역 모두 지우기", ["Shift+V"]],
	&"debug": ["디버그 보기", ["F3"]],
	&"cheat": ["디버그 명령", ["F4"]],
	&"help": ["도움말", ["Shift+Slash", "F1"]],
	&"codex": ["도감", ["Slash"]],
	&"log": ["기록", ["Ctrl+P", "P"]],
	&"restart": ["재시작", ["R"]],
}


## Puts every action in the InputMap with its default keys.
static func reset() -> void:
	for action in ACTIONS:
		bind(action, ACTIONS[action][1])


## Replaces an action's keys.
static func bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for k: String in keys:
		InputMap.action_add_event(action, event(k))


## The action's keys as strings.
static func keys_of(action: StringName) -> Array[String]:
	var out: Array[String] = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append(OS.get_keycode_string(e.get_keycode_with_modifiers()))
	return out


static func event(key: String) -> InputEventKey:
	var code := OS.find_keycode_from_string(key)
	var e := InputEventKey.new()
	e.keycode = code & KEY_CODE_MASK
	e.shift_pressed = code & KEY_MASK_SHIFT != 0
	e.ctrl_pressed = code & KEY_MASK_CTRL != 0
	e.alt_pressed = code & KEY_MASK_ALT != 0
	e.meta_pressed = code & KEY_MASK_META != 0
	return e


## The action a key press means: one bound with exactly its modifiers, else a
## move bound without them (Shift with a direction holds a spell). Empty if none.
## A press of Ctrl alone is read as Ctrl without the modifier it sets.
static func action_of(e: InputEvent) -> StringName:
	if e is InputEventKey and e.keycode == KEY_CTRL and e.ctrl_pressed:
		e = e.duplicate()
		e.ctrl_pressed = false
	for action in ACTIONS:
		if e.is_action(action, true):
			return action
	for action in MOVES:
		if e.is_action(action):
			return action
	return &""


## A short label for a key: printable keys as their character.
static func label(key: String) -> String:
	if SHOWN.has(key):
		return Lang.t(SHOWN[key])
	if key.begins_with("Kp "):
		return Lang.t("키패드 ") + label(key.trim_prefix("Kp "))
	var code := OS.find_keycode_from_string(key)
	var bare := code & KEY_CODE_MASK
	if bare > 32 and bare < 127:
		var mods := key.substr(0, key.rfind("+") + 1) if key.length() > 1 else ""
		return mods + char(bare)
	return key
