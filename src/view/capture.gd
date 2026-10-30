class_name Capture
extends Node
## Scripted runs for screenshots and checks, driven through the real input path:
## godot --path . -- --seed=3 --keys=Space,1,Up,Space --shot=out.png
## A key may also be `hover:x:y` (point at a tile), `click:x:y` (click it),
## `cell:x:y` (point at a screen cell, such as a talisman or the sidebar),
## `fire:x:y` (set a tile burning, to see how fire looks),
## `pause:seconds`, `walk:n` (n steps towards the stairs by direction keys),
## `hold:key:seconds`
## (the key held down, repeating 30 times a second), or `snap` (saves a frame
## in between as out-1.png, out-2.png ...). Keys may carry modifiers: Shift+Up.
## --replay=seconds also saves out-replay.png that long into the first
## highlight replay. --zoom=1.5 sets the cell scale (0 fits the whole map).
## Runs start from default settings and keys, and never save them.

var main: Node
var keys: PackedStringArray
var shot := ""
var frames := 0
var replay_at := -1.0
var _replay_time := 0.0


static func attach(main: Node) -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if not args.has("shot"):
		return
	if args.has("seed"):
		main._new_run(int(args.seed))
	main.settings = Settings.new()
	main.settings.path = ""
	main.settings.zoom = float(args.get("zoom", "0"))
	Keys.reset()
	main._apply()
	var c := Capture.new()
	c.main = main
	c.shot = args.shot
	c.keys = args.get("keys", "").split(",", false)
	c.replay_at = float(args.get("replay", "-1"))
	main.add_child(c)
	c._run.call_deferred()


func _process(delta: float) -> void:
	if replay_at < 0.0 or main.state != &"replay":
		return
	_replay_time += delta
	if _replay_time >= replay_at:
		replay_at = -1.0
		get_viewport().get_texture().get_image().save_png(shot.get_basename() + "-replay.png")


func _run() -> void:
	await get_tree().create_timer(0.6).timeout
	for k in keys:
		await _send(k)
		while main.busy or main.walking or main.state == &"replay":
			await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(shot)
	get_tree().quit()


func _send(k: String) -> void:
	var parts := k.split(":")
	match parts[0]:
		"hover":
			var tile := Vector2i(int(parts[1]), int(parts[2]))
			main._point(main.term.get_global_transform() * main.term.cell_centre(tile))
		"cell":
			var at := (Vector2(int(parts[1]), int(parts[2])) + Vector2(0.5, 0.5)) * Term.CELL
			main._point(main.term.get_global_transform() * at)
		"click":
			var tile := Vector2i(int(parts[1]), int(parts[2]))
			var at: Vector2 = main.term.get_global_transform() * main.term.cell_centre(tile)
			main._point(at)
			for pressed in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.position = at
				ev.pressed = pressed
				Input.parse_input_event(ev)
				await get_tree().process_frame
		"fire":
			main.world.burning[Vector2i(int(parts[1]), int(parts[2]))] = World.BURN_ROUNDS
			main.term.show_world(main.world)
			main._forecast()
		"walk":
			await _walk(int(parts[1]))
		"snap":
			frames += 1
			var path := shot.get_basename() + "-%d.png" % frames
			get_viewport().get_texture().get_image().save_png(path)
		"pause":
			await get_tree().create_timer(float(parts[1])).timeout
		"hold":
			var until := Time.get_ticks_msec() + int(float(parts[2]) * 1000.0)
			_press(parts[1], true, false)
			while Time.get_ticks_msec() < until:
				await get_tree().create_timer(1.0 / 30.0).timeout
				_press(parts[1], true, true)
			_press(parts[1], false, false)
		_:
			for pressed in [true, false]:
				_press(k, pressed, false)
				await get_tree().process_frame


## n steps towards the stairs, each by the first key of its direction.
func _walk(n: int) -> void:
	for i in n:
		var w: World = main.world
		var goal := w.stairs if w.stairs.x >= 0 else w.elixir
		var found := Grid.search(goal, w.open_floor)
		var me := w.player().pos
		var here: int = found.dist[Grid.index(me)]
		var step := Vector2i.ZERO
		for d in Grid.DIRS:
			var p := me + d
			if (
				Grid.inside(p)
				and found.dist[Grid.index(p)] >= 0
				and found.dist[Grid.index(p)] < here
			):
				step = d
				break
		if step == Vector2i.ZERO or main.state != &"play":
			return
		await _send(Keys.keys_of(Keys.MOVES.find_key(step))[0])
		while main.busy or main.state == &"replay":
			await get_tree().process_frame


## Sends a key with its modifiers ("Shift+Up"), as a press, a repeat or a release.
static func _press(k: String, pressed: bool, echo: bool) -> void:
	var ev := Keys.event(k)
	ev.pressed = pressed
	ev.echo = echo
	Input.parse_input_event(ev)
