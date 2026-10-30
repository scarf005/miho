class_name Capture
extends Node
## Scripted runs for screenshots and checks, driven through the real input path:
## godot --path . -- --seed=3 --keys=Space,1,Up,Space --shot=out.png
## A key may also be `hover:x:y` (point at a tile), `cell:x:y` (point at a
## screen cell, such as a talisman or the sidebar), `pause:seconds`, or
## `walk:n` (n steps towards the stairs by arrow keys; Shift+s saves a frame
## in between as out-1.png, out-2.png ...). --replay=seconds also saves
## out-replay.png that long into the first highlight replay.

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
		while main.busy or main.state == &"replay":
			await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(shot)
	get_tree().quit()


func _send(k: String) -> void:
	if k.begins_with("hover:"):
		var xy := k.split(":")
		main._point(
			(
				main.term.get_global_transform()
				* main.term.cell_centre(Vector2i(int(xy[1]), int(xy[2])))
			)
		)
		return
	if k.begins_with("cell:"):
		var xy := k.split(":")
		var at := (Vector2(int(xy[1]), int(xy[2])) + Vector2(0.5, 0.5)) * Term.CELL
		main._point(main.term.get_global_transform() * at)
		return
	if k.begins_with("walk:"):
		for i in int(k.split(":")[1]):
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
			await _send(_key_for(step))
			while main.busy or main.state == &"replay":
				await get_tree().process_frame
		return
	if k.begins_with("snap"):
		frames += 1
		get_viewport().get_texture().get_image().save_png(shot.get_basename() + "-%d.png" % frames)
		return
	if k.begins_with("pause:"):
		await get_tree().create_timer(float(k.split(":")[1])).timeout
		return
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = OS.find_keycode_from_string(k)
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


static func _key_for(d: Vector2i) -> String:
	return {
		Vector2i(0, -1): "Kp 8",
		Vector2i(0, 1): "Kp 2",
		Vector2i(-1, 0): "Kp 4",
		Vector2i(1, 0): "Kp 6",
		Vector2i(-1, -1): "Kp 7",
		Vector2i(1, -1): "Kp 9",
		Vector2i(-1, 1): "Kp 1",
		Vector2i(1, 1): "Kp 3",
	}[d]
