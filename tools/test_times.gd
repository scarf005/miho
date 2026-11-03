extends GutHookScript
## GUT pre-run hook of `just test`: for each test script, its set-up and tear-down included,
## prints `TIME <ms> <script> <storey>...`, the time without building storeys and the
## storeys it asks of Built, and `STOREY <ms> <storey>` for each it built. The runner uses
## them to balance the next run and keep scripts that share storeys on one shard.

var _started := 0
var _script := ""


## Lists no orphans: the list walks every object alive after each test, the worlds Built keeps
## too, and nothing reads it. GUT's total of orphans comes from Performance and stays.
class NoOrphans:
	extends "res://addons/gut/orphan_counter.gd".GutOrphanage

	func _get_system_orphan_node_ids():
		return []


func run() -> void:
	# A frame of a test waits on nothing, and no one reads the orphans the last wait counts.
	OS.low_processor_usage_mode = false
	gut._time_to_wait_for_final_queue_free = 0.0
	gut.get_orphan_counter().orphanage = NoOrphans.new()
	gut.start_script.connect(_start)
	gut.end_script.connect(_end)


func _start(script) -> void:
	_started = Time.get_ticks_msec()
	_script = script.get_filename()


func _end() -> void:
	var built := 0
	for storey: String in Built.spent:
		built += Built.spent[storey]
		print("STOREY %d %s" % [Built.spent[storey], storey])
	var own := Time.get_ticks_msec() - _started - built
	print("TIME %d %s %s" % [own, _script, " ".join(Built.asked.keys())])
	Built.asked.clear()
	Built.spent.clear()
