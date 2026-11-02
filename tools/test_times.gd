extends GutHookScript
## GUT pre-run hook of `just test`: prints `TIME <ms> <script>` for each test script, its
## set-up and tear-down included, which the runner uses to balance the next run.

var _started := 0
var _script := ""


func run() -> void:
	gut.start_script.connect(_start)
	gut.end_script.connect(_end)


func _start(script) -> void:
	_started = Time.get_ticks_msec()
	_script = script.get_filename()


func _end() -> void:
	print("TIME %d %s" % [Time.get_ticks_msec() - _started, _script])
