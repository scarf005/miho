class_name LookMode
extends RefCounted
## What the pointer or the look cursor is over in the game `m` (main.gd). x looks around: a
## cursor starts on Miho and the directions move it (Shift five tiles), showing what the pointer
## would; Enter walks there, Esc or x stops. In look mode the exclude key marks a danger zone
## (Exclusions) on the cursor that exploring and travel walk around; again it makes the zone one
## tile, and again removes it; 1-7 on a zone's centre set its radius.

var m: Node
var hover := Vector2i(-1, -1)
var hover_card := &""
var hover_status := false
## Key of the spell under the pointer on the status or talisman row, or empty,
## and the queue slot under it, or -1.
var hover_spell := ""
var hover_slot := -1
## The direction keys move the cursor, which is `hover`.
var active := false


func _init(of: Node) -> void:
	m = of


## In look mode: the directions move the cursor, Enter walks to it, Esc or the
## look key stops. Any other action stops look mode and is left to the caller
## (false).
func key(action: StringName, far: bool) -> bool:
	if Keys.MOVES.has(action):
		at(Grid.nudge(hover, Keys.MOVES[action], Menu.LOOK_FAR if far else 1))
	elif action == &"confirm":
		var goal := hover
		stop()
		if goal != m.world.player().pos or not m.casting.picked.is_empty():
			m.use_tile(goal, false)
	elif action in [&"cancel", &"look"]:
		stop()
	elif action == &"close" and shuts(hover):
		var dir: Vector2i = hover - m.world.player().pos
		stop()
		m.act({t = &"close", dir = dir})
	elif action == &"exclude" and m.world.known[Grid.index(hover)] == 1:
		m.journey.excluded.cycle(hover)
		m.journey.zones_changed()
	elif action.begins_with("pick_") and m.journey.excluded.zones.has(hover):
		m.journey.excluded.set_radius(hover, int(action.trim_prefix("pick_")))
		m.journey.zones_changed()
	else:
		stop()
		return false
	return true


## Whether the close key shuts the door on `tile`: an open door next to Miho.
func shuts(tile: Vector2i) -> bool:
	return Grid.inside(tile) and m.world.can({t = &"close", dir = tile - m.world.player().pos})


## The keys that act on the tile `hover` now, as [action, label] in the order of the box: each
## is the one that `key` or the game takes there (the exclusion keys and Enter only in look
## mode, Enter to walk with no talisman picked). With talismans picked, the keys of the queue
## come first, as DCSS `direction_chooser::print_key_hints` lists them while it aims: Enter
## hurls it at a tile not Miho's, the self key casts it on her when it goes on her, and Esc
## empties it outside look mode (in it, Esc only stops looking).
func hints() -> Array:
	var out := []
	if not Grid.inside(hover):
		return out
	if not m.casting.picked.is_empty():
		if hover != m.world.player().pos:
			out.append([&"confirm", "던지기"])
		if m.casting.fits(Vector2i.ZERO):
			out.append([&"self", "스스로에게 걸기"])
		out.append([&"unpick", "하나 빼기"])
		if not active:
			out.append([&"cancel", "취소"])
	if shuts(hover):
		out.append([&"close", "닫기"])
	if not active:
		return out
	if m.world.known[Grid.index(hover)] == 1:
		match m.journey.excluded.zones.get(hover, -1):
			-1:
				out.append([&"exclude", "위험구역 표시"])
			0:
				out.append([&"exclude", "위험구역 지우기"])
				out.append([&"pick_1", "위험구역 반지름"])
			_:
				out.append([&"exclude", "위험구역 줄이기"])
				out.append([&"pick_1", "위험구역 반지름"])
	if hover != m.world.player().pos and m.casting.picked.is_empty() and _walkable(hover):
		var w: World = m.world if m.debugging else m.known
		var a: Actor = w.actor_at(hover)
		out.append([&"confirm", "공격" if a != null and a.faction != Actor.FOX else "이동"])
	return out


func _walkable(tile: Vector2i) -> bool:
	var d: Vector2i = tile - m.world.player().pos
	if Grid.cheb(tile, m.world.player().pos) == 1:
		return m.world.can({t = &"move", dir = d})
	return not m.journey.path_to(tile).is_empty()


## Puts the cursor, which shows what the pointer would, on a tile.
func at(tile: Vector2i) -> void:
	hover = tile
	hover_card = &""
	hover_status = false
	m.refresh()


## Ends look mode; the cursor goes back to the pointer.
func stop() -> void:
	active = false
	Preview.point(m, m.mouse())
