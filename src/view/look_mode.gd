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
