class_name Capture
extends Node
## Scripted runs for screenshots and checks, driven through the real input path:
## godot --path . -- --seed=3 --keys=Space,1,Up,Space --shot=out.png
## A key may also be `hover:x:y` (point at a tile), `aim:dx:dy` (point at the
## tile that far from Miho), `click:x:y` (click it),
## `cell:x:y` (point at a screen cell, such as a talisman, the sidebar or a
## menu row), `tap:x:y` (click a screen cell),
## `fire:x:y` (set a tile burning, to see how fire looks),
## `kill:x:y` (the creature there falls, leaving its body mark),
## `peace` (every creature of heaven is gone, for long waits),
## `tile:x:y:n` (make a tile kind n, a World constant), `at:x:y` (put Miho there),
## `trap:x:y:n` (a hidden plate of tile kind n lies there, to be found or stepped on),
## `foe:kind:x:y` (a creature stands there), `hunt:x:y` (the creature there notices Miho),
## `hp:n:dx:dy` (the creature that far from Miho is left with n health),
## `lamp:dx:dy` (a lantern that far from Miho), `chase:dx:dy` (it notices her),
## `follow:ldx:ldy:dx:dy` (it follows the creature at ldx:ldy),
## `card:name` (Miho holds that talisman, such as fire),
## `gas:x:y:kind:amount` (lay that much gas, a Gas constant, on a tile),
## `spawn:kind:dx:dy` (a creature that far from Miho, to see its info),
## `pause:seconds`, `walk:n` (n steps towards the stairs by direction keys),
## `hold:key:seconds`
## (the key held down, repeating 30 times a second), or `snap` (saves a frame
## in between as out-1.png, out-2.png ...). Keys may carry modifiers: Shift+Up.
## --depth=n builds the storeys up to n and puts Miho on n, with its tails.
## --replay=seconds also saves out-replay.png that long into the first
## highlight replay. --zoom=1.5 sets the cell scale (0 fits the whole map).
## Runs start from default settings and keys, and never save them. They keep no
## run either, unless --save=path names a file (a title that offers to continue
## it takes Enter, not any key, to start).

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
	main.save_path = args.get("save", "")
	main._new_run(int(args.get("seed", randi())))
	if args.has("depth"):
		for depth in range(2, int(args.depth) + 1):
			Storeys.leave(main.world)
			Storeys.enter(main.world, depth)
		main.world.tails = main.world.max_tails()
		main.world.sense()
		main.term.show_world(main.world)
	main._show_title()
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
		"hover", "aim":
			var tile := Vector2i(int(parts[1]), int(parts[2]))
			if parts[0] == "aim":
				tile += main.world.player().pos
			main._point(_screen(main.term.cell_centre(tile)))
		"cell":
			var at := (Vector2(int(parts[1]), int(parts[2])) + Vector2(0.5, 0.5)) * Term.CELL
			main._point(_screen(at))
		"click", "tap":
			var xy := Vector2i(int(parts[1]), int(parts[2]))
			var local: Vector2 = (
				main.term.cell_centre(xy)
				if parts[0] == "click"
				else (Vector2(xy) + Vector2(0.5, 0.5)) * Term.CELL
			)
			var at := _screen(local)
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
		"kill":
			var foe: Actor = main.world.actor_at(Vector2i(int(parts[1]), int(parts[2])))
			main.world.hurt(foe, foe.hp)
			main.world.sense()
			main.term.show_world(main.world)
			main._forecast()
		"tile", "trap", "at", "foe", "hunt", "card", "gas":
			_stage(parts)
		"hp", "chase", "follow", "lamp":
			var w: World = main.world
			var at := w.player().pos + Vector2i(int(parts[-2]), int(parts[-1]))
			match parts[0]:
				"lamp":
					w.set_tile(at, World.LANTERN)
				"hp":
					w.actor_at(at).hp = int(parts[1])
				"chase":
					w.hunt_from(w.actor_at(at), w.player().pos)
				"follow":
					w.actor_at(at).leader = (
						w.actor_at(w.player().pos + Vector2i(int(parts[1]), int(parts[2]))).id
					)
			main.term.show_world(main.world)
			main._forecast()
		"spawn":
			var at: Vector2i = main.world.player().pos + Vector2i(int(parts[2]), int(parts[3]))
			FloorGen.spawn(main.world, StringName(parts[1]), at)
			main.world.sense()
			main.term.show_world(main.world)
			main._forecast()
		"peace":
			main.world.actors.assign(
				main.world.actors.filter(func(a): return a.faction == Actor.FOX)
			)
			main.world.sense()
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


## Changes the world for a picture: tile, trap, at, foe, hunt, card and gas.
func _stage(parts: PackedStringArray) -> void:
	var w: World = main.world
	var xy := Vector2i(int(parts[-2]), int(parts[-1]))
	match parts[0]:
		"tile":
			w.set_tile(Vector2i(int(parts[1]), int(parts[2])), int(parts[3]))
		"trap":
			w.traps[Vector2i(int(parts[1]), int(parts[2]))] = int(parts[3])
		"at":
			w.player().pos = xy
		"foe":
			FloorGen.spawn(w, StringName(parts[1]), xy).cooldown = 99
		"hunt":
			w.hunt_from(w.actor_at(xy), w.player().pos)
		"card":
			if not w.cards.has(StringName(parts[1])):
				w.cards.append(StringName(parts[1]))
		"gas":
			Gas.put(w, Vector2i(int(parts[1]), int(parts[2])), int(parts[3]), int(parts[4]))
	w._changed()
	w.sense()
	main.term.show_world(w)
	main._forecast()


## n steps towards the stairs, each by the first key of its direction.
func _walk(n: int) -> void:
	for i in n:
		var w: World = main.world
		var goal := w.stairs if w.stairs.x >= 0 else w.elixir
		var found := Grid.search(goal, Masks.floor_of(w))
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


## Where a point in the term's space shows on the screen, as a pointer finds it.
func _screen(local: Vector2) -> Vector2:
	var drawn: Vector2 = main.term.get_global_transform() * local
	return Crt.seen(drawn, get_viewport().get_visible_rect().size) if main.glass.visible else drawn
