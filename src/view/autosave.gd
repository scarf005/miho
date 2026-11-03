class_name Autosave
extends Timer
## Keeps the run of `main` on disk: once a second, and at once when the player leaves the game.

var main: Node


func _init(of: Node) -> void:
	main = of
	wait_time = 1.0
	autostart = true
	timeout.connect(_flush)


func _exit_tree() -> void:
	_flush()


func _notification(what: int) -> void:
	if (
		what
		in [
			NOTIFICATION_APPLICATION_PAUSED,
			NOTIFICATION_APPLICATION_FOCUS_OUT,
			NOTIFICATION_WM_WINDOW_FOCUS_OUT,
		]
	):
		_flush()


func _flush() -> void:
	main.run.flush()
