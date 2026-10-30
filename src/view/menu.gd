class_name Menu
extends RefCounted
## Full-screen pages over the game, moved through with the direction keys,
## Enter and Esc, or the pointer: help lists every action with its keys.

const KEY_COL := 13.0
const MOUSE := [
	["왼쪽 클릭", "옆 칸으로 한 걸음, 먼 칸까지 걷기"],
	["부적 고르고 클릭", "그쪽으로 던지기"],
	["오른쪽 클릭", "취소"],
	["가리키기", "무엇이 있는지 보기"],
]

var page := &""
var selected := 0


func open(p: StringName) -> void:
	page = p
	selected = 0


## What the page shows, as a Term.panel.
func panel() -> Dictionary:
	return {title = "도움말", rows = _help(), selected = selected}


## Handles a key press; returns what the game should do: &"close" or nothing.
func key(e: InputEventKey) -> StringName:
	match _nav(e):
		&"up":
			selected = maxi(0, selected - 1)
		&"down":
			selected = mini(_help().size() - 1, selected + 1)
		_:
			return &"close"
	return &""


## The pointer is over row k.
func point(k: int) -> void:
	if k >= 0:
		selected = k


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
	}
	return bound.get(Keys.action_of(e), &"")


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
		rows.append([[name, Palette.TEXT], [sep.join(keys), Palette.SIDE[0], KEY_COL]])
	for m in MOUSE:
		rows.append([[m[0], Palette.TEXT], [m[1], Palette.DIM, KEY_COL]])
	return rows
