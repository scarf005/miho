extends Node3D
## Game flow and input. Keys: arrows, numpad or hjklyubn to move; 1-7 pick
## talismans (one per tail left); Space or Enter casts (or waits with nothing picked); . waits;
## Esc clears; M mutes. Mouse: click a neighbouring tile to move, click to aim
## and cast, right-click clears. Pointing at anything shows its stats.

const KEY_DIRS := {
	KEY_UP: Vector2i(0, -1),
	KEY_DOWN: Vector2i(0, 1),
	KEY_LEFT: Vector2i(-1, 0),
	KEY_RIGHT: Vector2i(1, 0),
	KEY_K: Vector2i(0, -1),
	KEY_J: Vector2i(0, 1),
	KEY_H: Vector2i(-1, 0),
	KEY_L: Vector2i(1, 0),
	KEY_Y: Vector2i(-1, -1),
	KEY_U: Vector2i(1, -1),
	KEY_B: Vector2i(-1, 1),
	KEY_N: Vector2i(1, 1),
	KEY_KP_8: Vector2i(0, -1),
	KEY_KP_2: Vector2i(0, 1),
	KEY_KP_4: Vector2i(-1, 0),
	KEY_KP_6: Vector2i(1, 0),
	KEY_KP_7: Vector2i(-1, -1),
	KEY_KP_9: Vector2i(1, -1),
	KEY_KP_1: Vector2i(-1, 1),
	KEY_KP_3: Vector2i(1, 1),
}

var world: World
var board: Board
var hud: Hud
var sfx: Sfx
var camera: Camera3D
var picked: Array[StringName] = []
var aim := Vector2i.ZERO
var busy := false
var state := &"title"
var hover := Vector2i(-1, -1)


func _ready() -> void:
	_stage()
	board = Board.new()
	add_child(board)
	hud = Hud.new()
	add_child(hud)
	sfx = Sfx.new()
	add_child(sfx)
	board.shown.connect(sfx.on_event)
	hud.card_pressed.connect(_toggle)
	_new_run()
	hud.curtain("미호", "천상누각 꼭대기에 사람이 되는 영약이 있다\n\n아무 키나 누르면 시작")
	Capture.attach(self)


func _stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffffff")
	env.ambient_light_energy = 0.62
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color("#fff4e2")
	sun.light_energy = 0.14
	sun.light_specular = 0.0
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 30
	camera.position = Vector3(0, 13.0, 13.6)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 1.25))


func _new_run() -> void:
	world = World.create(randi())
	picked.clear()
	aim = Vector2i.ZERO
	board.build(world)
	_refresh()


# --- input ----------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_point(event.position)
		return
	if busy:
		if event.is_pressed():
			board.speed = 4.0
		return
	if state == &"title":
		if event.is_pressed() and not event.is_echo() and not event is InputEventMouseMotion:
			state = &"play"
			busy = true
			sfx.play(&"card")
			await _turn_page(func(): hud.curtain("", ""))
			busy = false
		return
	if state == &"over":
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			state = &"play"
			hud.curtain("", "")
			_new_run()
		return
	if event is InputEventKey and event.pressed:
		_key(event)
	elif event is InputEventMouseButton and event.pressed:
		_click(event)


func _key(event: InputEventKey) -> void:
	var key := event.keycode
	if key >= KEY_1 and key <= KEY_7:
		_toggle(Cards.ALL[key - KEY_1])
	elif KEY_DIRS.has(key):
		_direction(KEY_DIRS[key])
	elif key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_F]:
		_confirm()
	elif key in [KEY_PERIOD, KEY_KP_5, KEY_KP_PERIOD]:
		_act({t = &"wait"})
	elif key == KEY_ESCAPE:
		_clear()
	elif key == KEY_M:
		sfx.muted = not sfx.muted


func _click(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_clear()
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not Grid.inside(hover):
		return
	var me := world.player().pos
	var spell := Spell.make(picked)
	if spell != null and spell.line:
		if hover != me:
			aim = Grid.nearest_dir(hover - me)
			_confirm()
	elif spell != null and hover == me:
		_confirm()
	elif hover == me:
		_act({t = &"wait"})
	elif Grid.cheb(hover, me) == 1:
		_act({t = &"move", dir = hover - me})


func _point(screen: Vector2) -> void:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var tile := Vector2i(-1, -1)
	if dir.y < -0.001:
		var hit := from + dir * (-from.y / dir.y)
		tile = Board.from3(hit)
	if tile == hover:
		return
	hover = tile
	var spell := Spell.make(picked)
	if (
		state == &"play"
		and not busy
		and spell != null
		and spell.line
		and Grid.inside(tile)
		and tile != world.player().pos
	):
		aim = Grid.nearest_dir(tile - world.player().pos)
		_refresh()
	_inspect()


func _inspect() -> void:
	if not Grid.inside(hover) or state != &"play":
		hud.hide_info()
		return
	var a := world.actor_at(hover)
	if a != null:
		hud.show_actor(a)
		return
	var s := world.shot_at(hover)
	if s != null:
		hud.show_shot(s)
		return
	hud.hide_info()


func _toggle(card: StringName) -> void:
	if state != &"play" or busy or not world.cards.has(card):
		return
	if picked.has(card):
		picked.erase(card)
	elif picked.size() < mini(Spell.MAX_CARDS, world.tails):
		picked.append(card)
	sfx.play(&"click")
	var spell := Spell.make(picked)
	if spell == null or not spell.line:
		aim = Vector2i.ZERO
	_refresh()


func _clear() -> void:
	picked.clear()
	aim = Vector2i.ZERO
	_refresh()


func _direction(d: Vector2i) -> void:
	var spell := Spell.make(picked)
	if spell != null and spell.line:
		if aim == d:
			_confirm()
		else:
			aim = d
			_refresh()
		return
	_act({t = &"move", dir = d})


func _confirm() -> void:
	var spell := Spell.make(picked)
	if spell == null:
		if picked.is_empty():
			_act({t = &"wait"})
		return
	if spell.line and aim == Vector2i.ZERO:
		return
	_act(_cast_action())


# --- turns ----------------------------------------------------------------------


func _act(action: Dictionary) -> void:
	if not world.can(action):
		sfx.play(&"click")
		return
	busy = true
	board.clear_marks()
	hud.hide_info()
	var depth := world.depth
	var events := world.act(action)
	await board.play(events, world)
	board.speed = 1.0
	if action.t == &"cast":
		picked.clear()
		aim = Vector2i.ZERO
	if world.depth != depth:
		await _turn_page(func(): board.build(world))
	if world.outcome == &"won":
		await _ending()
	elif world.outcome == &"lost":
		state = &"over"
		hud.curtain("쓰러졌다", "%d층에서\n\nR 다시" % world.depth)
	busy = false
	_refresh()
	_inspect()


func _cast_action() -> Dictionary:
	return {t = &"cast", spells = [{cards = picked.duplicate(), dir = aim}]}


## Swaps the scene behind a snapshot of the current one, then slides the snapshot away.
func _turn_page(change: Callable) -> void:
	await RenderingServer.frame_post_draw
	var picture := ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var slid := hud.slide(picture)
	change.call()
	_refresh()
	await slid.finished


func _ending() -> void:
	state = &"over"
	var me: Puppet = board.actors.get(world.player().id)
	if me != null and board.tails_root != null:
		for t in board.tails_root.get_children():
			if t.visible:
				t.fall()
				await get_tree().create_timer(0.18).timeout
		for ear in []:
			pass
	await get_tree().create_timer(0.8).timeout
	hud.curtain("사람이 되었다", "R 다시")


func _refresh() -> void:
	if world == null:
		return
	var spell := Spell.make(picked)
	var forecast: Forecast
	var danger := {}
	var dirs: Array = []
	if spell != null and world.can(_cast_action()):
		forecast = Forecast.of(world, _cast_action())
	else:
		forecast = Forecast.of(world, {t = &"wait"})
		if spell != null and spell.line and aim == Vector2i.ZERO:
			dirs = Grid.DIRS.duplicate()
		elif picked.is_empty():
			var me := world.player().pos
			danger[me] = forecast.hurt_me()
			for d in Grid.DIRS:
				var move := {t = &"move", dir = d}
				if world.can(move) and world.outcome == &"":
					danger[me + d] = Forecast.of(world, move).hurt_me()
	board.draw_forecast(forecast, danger, dirs)
	hud.refresh(world, picked)
