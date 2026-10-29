class_name Capture
extends Node
## Scripted runs for screenshots and checks, driven through the real input path:
## godot --path . -- --seed=3 --keys=Space,1,Up,Space --shot=out.png
## A key may also be `hover:x:y` (point at a tile) or `pause:seconds`.

var main: Node
var keys: PackedStringArray
var shot := ""


static func attach(main: Node) -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if not args.has("shot"):
		return
	if args.has("seed"):
		main.world = World.create(int(args.seed))
		main.board.build(main.world)
		main._refresh()
	var c := Capture.new()
	c.main = main
	c.shot = args.shot
	c.keys = args.get("keys", "").split(",", false)
	main.add_child(c)
	c._run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.6).timeout
	for k in keys:
		await _send(k)
		while main.busy:
			await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(shot)
	get_tree().quit()


func _send(k: String) -> void:
	if k.begins_with("hover:"):
		var xy := k.split(":")
		main._point(
			main.camera.unproject_position(
				Board.to3(Vector2i(int(xy[1]), int(xy[2]))) + Vector3(0, 0.3, 0)
			)
		)
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
