extends SceneTree
## Times a frame of the game's screen with and without the example of a hovered spell in its
## box: the time from one frame to the next (the engine waits out the rest of a frame, so it
## shows only a frame that runs over), and the example's own `_process` over a full loop of
## the example, with the round it plays and the aim it tints. Also what opening the box costs.
## godot --headless --path . -s tools/bench_example.gd

const FRAMES := 300
const LOOP := 1500
const FRAME := 1.0 / 60.0


func _init() -> void:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	root.add_child(m)
	await process_frame
	m.new_run(3)
	m.state = &"play"
	await process_frame
	var plain := await _frames()
	var t := Time.get_ticks_usec()
	m.hover_card = Cards.FIRE
	m.refresh()
	var opened := Time.get_ticks_usec() - t
	var boxed := await _frames()
	var sim: ExampleSim = m.term.sim
	var all := 0
	var most := 0
	for k in LOOP:
		t = Time.get_ticks_usec()
		sim._process(FRAME)
		var took := Time.get_ticks_usec() - t
		all += took
		most = maxi(most, took)
	m.hover_card = &""
	m.refresh()
	print("frame to frame without the box: mean %d us, most %d us" % plain)
	print("frame to frame with the box:    mean %d us, most %d us" % boxed)
	print(
		"the example's _process over %d frames: mean %d us, most %d us" % [LOOP, all / LOOP, most]
	)
	print("opening the box (world built, spell planned): %d us" % opened)
	quit()


## [mean, most] of the time from one frame to the next.
func _frames() -> Array:
	var all := 0
	var most := 0
	for k in FRAMES:
		var t := Time.get_ticks_usec()
		await process_frame
		var took := Time.get_ticks_usec() - t
		all += took
		most = maxi(most, took)
	return [all / FRAMES, most]
