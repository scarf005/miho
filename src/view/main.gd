extends Node
## Game flow and input, through the actions in Keys. Arrows, numpad or
## hjklyubn move, and keep moving while held; moving into a creature strikes it
## with claws. 1-7 pick talismans; with talismans picked a direction hurls the
## spell, and Shift with a direction holds it so several spells leave in one
## turn. Space, Enter or . waits, or hurls what is held. Esc clears what is
## picked and, with nothing to clear, opens the options; M mutes.
## > walks to the stairs, o explores, z rests until the tails regrow. x looks
## around: a cursor starts on Miho and the directions move it (Shift five
## tiles), showing what the pointer would; Enter walks there, Esc or x stops.
## Mouse: click a neighbour to move or a farther known tile to walk there, or
## with talismans picked click anywhere to hurl that way; click a talisman to
## pick it; right-click clears. Each storey left behind replays its best moment.

const REPLAY_ZOOM := 1.5
const REPLAY_SPEED := 0.7
## How much faster rounds play while walking many rounds.
const WALK_SPEED := 3.0
## Message lines shown over the map, and for how many rounds.
const LOG_ROWS := 3
const LOG_FADE := 5
## Tiles a cursor moves in look mode with Shift.
const LOOK_FAR := 5

var world: World
var term: Term
var sfx: Sfx
var reel := Highlight.new()
var picked: Array[StringName] = []
var staged: Array[Dictionary] = []
var busy := false
var state := &"title"
var hover := Vector2i(-1, -1)
var hover_card := &""
var hover_status := false
## Look mode: the direction keys move the cursor, which is `hover`.
var looking := false
var skip := false
## This run's seed, and the creatures of heaven that fell in it.
var run_seed := 0
var kills := 0
var settings: Settings
var glass: ColorRect
var pan: Tween
## A walk of many rounds is under way, and a key or click asked it to stop.
var walking := false
var halt := false
var messages := Messages.new()
var menu := Menu.new()
## The full-screen panel open over the game, or empty.
var overlay := &""
## Worked out once per world or talisman change: what Miho knows, the forecast
## of each step or wait (direction -> Forecast), the spell's reach (tile -> tint),
## and forecasts of the spell hurled each way, filled as the pointer aims.
var known: World
var ahead := {}
var reach := {}
var aims := {}
## Shortest walks from Miho over what she knows (Travel.search).
var routes := {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.VOID)
	settings = Settings.load_from()
	term = Term.new()
	add_child(term)
	sfx = Sfx.new()
	term.add_child(sfx)
	term.shown.connect(sfx.on_event)
	var crt := CanvasLayer.new()
	crt.layer = 10
	glass = ColorRect.new()
	glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.material = ShaderMaterial.new()
	glass.material.shader = preload("res://src/view/crt.gdshader")
	crt.add_child(glass)
	add_child(crt)
	get_viewport().size_changed.connect(_fit)
	_new_run()
	term.banner_lines = ["미호", "천상누각 꼭대기에 사람이 되는 영약이 있다", "아무 키나 눌러 시작"]
	_apply()
	Capture.attach(self)


## Puts the settings into effect.
func _apply() -> void:
	menu.settings = settings
	settings.apply_sound()
	glass.visible = settings.crt
	term.speed = settings.speed
	_fit()


func _fit() -> void:
	if state != &"replay":
		term.fit(get_viewport().get_visible_rect().size, settings.zoom)


func _new_run(seed_value := randi()) -> void:
	world = World.create(seed_value)
	run_seed = seed_value
	kills = 0
	messages = Messages.new()
	term.log_lines = []
	reel.clear()
	picked.clear()
	staged.clear()
	term.show_world(world)
	_forecast()


# --- input ----------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	var press := event.is_pressed() and not event.is_echo()
	if event is InputEventMouseMotion:
		_point(event.position)
	elif state == &"replay":
		skip = skip or press
		term.speed = 8.0 if skip else term.speed
	elif walking:
		halt = halt or press
	elif busy or not event.is_pressed() or event.is_echo() and (overlay != &"" or state != &"play"):
		pass
	elif overlay != &"":
		_panel_input(event)
	elif state == &"title" and Keys.action_of(event) in [&"help", &"cancel"]:
		_open(&"help" if Keys.action_of(event) == &"help" else &"options")
	elif state == &"title":
		state = &"play"
		term.banner_lines = []
		sfx.play(&"card")
	elif state == &"over":
		if Keys.action_of(event) == &"restart":
			state = &"play"
			term.banner_lines = []
			_new_run()
	elif event is InputEventKey:
		_key(event)
	elif event is InputEventMouseButton and press:
		_click(event)


## Moves repeat while their key is held; other actions take only fresh presses.
## Repeats that arrive while a round plays are dropped, so none pile up.
func _key(event: InputEventKey) -> void:
	var action := Keys.action_of(event)
	if event.is_echo() and not Keys.MOVES.has(action):
		return
	if looking and _look_key(action, event.shift_pressed):
		return
	if Keys.MOVES.has(action):
		_direction(Keys.MOVES[action], event.shift_pressed)
	elif action.begins_with("pick_"):
		var i := int(action.trim_prefix("pick_")) - 1
		if i < world.cards.size():
			_toggle(world.cards[i])
	elif action in [&"wait", &"confirm"]:
		_act({t = &"cast", spells = staged.duplicate()} if not staged.is_empty() else {t = &"wait"})
	elif action == &"cancel" and (not picked.is_empty() or not staged.is_empty()):
		_clear()
	elif action == &"cancel":
		_open(&"options")
	elif action == &"stairs":
		_journey(_to_exit, "아직 계단을 찾지 못했다")
	elif action == &"explore":
		_journey(_exploring, "더 탐험할 곳이 없다")
	elif action == &"look":
		looking = true
		_look_at(world.player().pos)
	elif action == &"rest":
		_journey(_resting, "꼬리가 이미 다 자랐다")
	elif action in [&"log", &"help"]:
		_open(action)
	elif action == &"mute":
		settings.muted = not settings.muted
		settings.apply_sound()
		settings.save()


func _click(event: InputEventMouseButton) -> void:
	looking = false
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_clear()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := term.get_global_transform().affine_inverse() * event.position
	var card := term.card_at(local)
	if card != &"":
		_toggle(card)
		return
	if Grid.inside(hover):
		_use_tile(hover, event.shift_pressed)


## What a left click on `tile` does: wait on Miho's own, hurl towards another
## with talismans picked, step to a neighbour, or walk to a farther tile.
func _use_tile(tile: Vector2i, hold: bool) -> void:
	var me := world.player().pos
	if tile == me:
		_act({t = &"wait"})
	elif not picked.is_empty():
		_direction(Grid.nearest_dir(tile - me), hold)
	elif Grid.cheb(tile, me) == 1:
		_act({t = &"move", dir = tile - me})
	else:
		_journey(func(): return _step_on(Travel.route(routes, tile)))


func _point(screen: Vector2) -> void:
	var local := term.get_global_transform().affine_inverse() * screen
	if overlay != &"" and overlay != &"log":
		menu.point(term.panel_row_at(local))
		term.panel = menu.panel()
	var tile := term.tile_at(local)
	if not Grid.inside(tile):
		tile = term.side_at(local)
	var card := term.card_at(local)
	var status := term.status_at(local)
	if tile != hover or card != hover_card or status != hover_status:
		hover = tile
		hover_card = card
		hover_status = status
		if state == &"play" and not busy:
			_refresh()


## In look mode: the directions move the cursor, Enter walks to it, Esc or the
## look key stops. Any other action stops look mode and is left to `_key`
## (false).
func _look_key(action: StringName, far: bool) -> bool:
	if Keys.MOVES.has(action):
		_look_at(Grid.nudge(hover, Keys.MOVES[action], LOOK_FAR if far else 1))
	elif action == &"confirm":
		var goal := hover
		_stop_look()
		if goal != world.player().pos:
			_use_tile(goal, false)
	elif action in [&"cancel", &"look"]:
		_stop_look()
	else:
		_stop_look()
		return false
	return true


## Puts the cursor, which shows what the pointer would, on a tile.
func _look_at(tile: Vector2i) -> void:
	hover = tile
	hover_card = &""
	hover_status = false
	_refresh()


## Ends look mode; the cursor goes back to the pointer.
func _stop_look() -> void:
	looking = false
	_point(get_viewport().get_mouse_position())


func _toggle(card: StringName) -> void:
	if picked.has(card):
		picked.erase(card)
	elif picked.size() < Spell.MAX_CARDS and _held() + picked.size() < world.tails:
		picked.append(card)
	sfx.play(&"click")
	_forecast()


func _held() -> int:
	return staged.reduce(func(n, s): return n + s.cards.size(), 0)


func _clear() -> void:
	picked.clear()
	staged.clear()
	_forecast()


## With talismans picked a direction hurls them (Shift holds them); otherwise it moves.
func _direction(d: Vector2i, hold: bool) -> void:
	if picked.is_empty():
		if not staged.is_empty() and not hold:
			_act({t = &"cast", spells = staged.duplicate()})
		elif staged.is_empty():
			_act({t = &"move", dir = d})
		return
	var spells := staged.duplicate()
	spells.append({cards = picked.duplicate(), dir = d})
	if not world.can({t = &"cast", spells = spells}):
		sfx.play(&"click")
		return
	if hold:
		staged = spells
		picked.clear()
		_forecast()
		return
	_act({t = &"cast", spells = spells})


# --- turns ----------------------------------------------------------------------


## Plays one round and returns its events (none when the action is not allowed).
func _act(action: Dictionary) -> Array:
	if not world.can(action):
		sfx.play(&"click")
		return []
	busy = true
	term.tints = {}
	term.marks = {}
	term.info = []
	term.cursor = Vector2i(-1, -1)
	var before := world.clone()
	var depth := world.depth
	var events := world.act(action)
	reel.record(before, action, events)
	kills += events.filter(func(e): return e.t == &"die" and e.id != world.player().id).size()
	sfx.listener.position = term.cell_centre(world.player().pos)
	await term.play(events, before, world)
	for line in Messages.of(before, world, events):
		messages.add(line, world.round_no)
	_show_log()
	if action.t == &"cast":
		picked.clear()
		staged.clear()
	if world.depth != depth or world.outcome == &"won":
		reel.rounds.pop_back()
		if settings.replay:
			await _replay()
		reel.clear()
	if world.outcome != &"":
		state = &"over"
		var again: String = (Keys.keys_of(&"restart").map(Keys.label) + ["R"])[0]
		term.banner_lines = [
			"사람이 되었다" if world.outcome == &"won" else "쓰러졌다",
			"%d층 · %d초" % [world.depth, world.round_no],
			"처치 %d" % kills,
			"시드 %d" % run_seed,
			"%s키를 눌러 재시작" % again,
		]
	busy = false
	_forecast()
	return events


## Plays `next` (an action, or empty when done) round after round. Stops
## before a step whose forecast shows harm or being noticed or that ends next
## to fire, and after a round
## in which something Miho should react to happened (Travel.interrupted), or
## when a key or click asks. `why` is said when it cannot take a first step.
func _journey(next: Callable, why := "") -> void:
	_clear()
	var sighted := Travel.in_sight(world)
	var rounds := 0
	walking = true
	halt = false
	term.speed = settings.speed * WALK_SPEED
	while not halt and state == &"play":
		var action: Dictionary = next.call()
		if action.is_empty():
			if rounds == 0 and why != "":
				_say(why)
			break
		var to: Vector2i = world.player().pos + action.get("dir", Vector2i.ZERO)
		var f: Forecast = ahead.get(action.get("dir", Vector2i.ZERO))
		if f == null or f.hurt_me() > 0 or not f.noticed.is_empty() or not world.can(action):
			break
		if action.t == &"move" and Travel.near_fire(world, to):
			break
		var before := world.clone()
		var events: Array = await _act(action)
		rounds += 1
		if Travel.interrupted(before, world, events, sighted):
			break
	walking = false
	term.speed = settings.speed
	if rounds == 0:
		sfx.play(&"click")


func _step_on(path: Array[Vector2i]) -> Dictionary:
	return {t = &"move", dir = path[0] - world.player().pos} if not path.is_empty() else {}


func _to_exit() -> Dictionary:
	return _step_on(Travel.route(routes, Travel.exit(world)))


func _exploring() -> Dictionary:
	var d := Travel.explore_step(world, routes)
	return {t = &"move", dir = d} if d != Vector2i.ZERO else {}


func _resting() -> Dictionary:
	return {t = &"wait"} if world.tails < world.max_tails() else {}


# --- messages and panels --------------------------------------------------------


func _say(text: String) -> void:
	messages.add([[text, Palette.TEXT]], world.round_no)
	_show_log()


## The last few lines over the map, older ones dimmer, gone after LOG_FADE rounds.
func _show_log() -> void:
	var recent := messages.lines.slice(-LOG_ROWS).filter(
		func(l): return world.round_no - l.round <= LOG_FADE
	)
	term.log_lines = []
	for k in recent.size():
		term.log_lines.append([Messages.shown(recent[k]), 1.0 - 0.3 * (recent.size() - 1 - k)])


## Shows a full-screen panel: the message log, or a Menu page.
func _open(kind: StringName) -> void:
	overlay = kind
	if kind == &"log":
		var rows := messages.lines.map(Messages.shown)
		term.panel = {title = "기록", rows = rows, selected = -1}
		return
	menu.open(kind)
	term.panel = menu.panel()


## Any press closes the log and help; the other Menu pages take keys, a left
## click uses the row under the pointer, and a right click goes back.
func _panel_input(event: InputEvent) -> void:
	var done := overlay == &"log" or overlay == &"help" and event is InputEventMouseButton
	var command := &"close" if done else &""
	if done:
		pass
	elif event is InputEventKey:
		command = menu.key(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		command = menu.back()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = term.get_global_transform().affine_inverse() * event.position
		command = menu.use() if term.panel_row_at(local) >= 0 else &""
	match command:
		&"close":
			_close()
			return
		&"changed":
			settings.save()
			_apply()
		&"restart":
			_close()
			state = &"play"
			term.banner_lines = []
			_new_run()
			return
	term.panel = menu.panel()


func _close() -> void:
	overlay = &""
	term.panel = {}


## The storey's best moment, zoomed in on Miho and slowed down; any key skips it.
func _replay() -> void:
	var window := reel.best()
	if window.is_empty():
		return
	var clip := reel.clip(window)
	var w: World = clip.world
	state = &"replay"
	skip = false
	term.replay = true
	term.speed = REPLAY_SPEED * settings.speed
	term.fit(get_viewport().get_visible_rect().size, 0.0)
	term.show_world(w)
	_follow(w, 0.5)
	await get_tree().create_timer(0.5).timeout
	for action in clip.actions:
		if skip:
			break
		var before := w.clone()
		var events := w.act(action)
		_follow(w, 0.6)
		await term.play(events, before, w)
		if not skip:
			await get_tree().create_timer(0.3).timeout
	pan.kill()
	term.replay = false
	term.speed = settings.speed
	state = &"play"
	_fit()
	term.show_world(world)


## Pans the zoomed, whole-map screen so Miho stays in the middle without
## showing past the map; a map narrower than the screen stays centred.
func _follow(w: World, time: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var whole := Vector2(Term.MAP.x + Grid.W, Grid.H + 2) * Term.CELL
	var k := minf(view.x / whole.x, view.y / whole.y) * REPLAY_ZOOM
	var map := term.map_rect()
	var at := view / 2.0 - term.cell_centre(w.player().pos) * k
	for axis in 2:
		var lo := view[axis] - map.end[axis] * k
		var hi := -map.position[axis] * k
		at[axis] = clampf(at[axis], lo, hi) if lo <= hi else (lo + hi) / 2.0
	pan = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	pan.tween_property(term, "scale", Vector2(k, k), time)
	pan.tween_property(term, "position", at.round(), time)
	sfx.listener.position = term.cell_centre(w.player().pos)


## What each choice would do, from what Miho knows: the reach of the spell in
## hand, and on each neighbouring tile the harm she would take and whether she
## would be seen there. These depend only on the world and the talismans in
## hand, so they are worked out once per change and reused while the pointer moves.
func _forecast() -> void:
	if world == null:
		return
	known = world.known_clone()
	routes = Travel.search(world)
	ahead = {}
	aims = {}
	reach = {}
	var me := world.player().pos
	if not picked.is_empty() and Spell.make(picked) != null:
		for d in Grid.DIRS:
			for p in Forecast.ray(world, me, d).slice(0, Spell.RANGE):
				reach[p] = Color(Palette.SIDE[0], 0.12)
	elif world.outcome == &"":
		for d: Vector2i in Grid.DIRS + [Vector2i.ZERO]:
			var action := {t = &"wait"} if d == Vector2i.ZERO else {t = &"move", dir = d}
			if world.can(action):
				ahead[d] = Forecast.of(world, action)
	_refresh()


## Under the pointer: what is there, the tiles a creature there sees, what the
## spell in hand would do hurled that way (each aim forecast once), or with
## nothing in hand the walk a click there would take.
func _refresh() -> void:
	if world == null:
		return
	_inspect()
	term.picked = picked
	term.staged = staged
	var tints := reach.duplicate()
	var marks := {}
	var me := world.player().pos
	for d: Vector2i in ahead:
		var f: Forecast = ahead[d]
		if f.hurt_me() > 0:
			marks[me + d] = [str(f.hurt_me()), Palette.HURT]
		elif not f.noticed.is_empty():
			tints[me + d] = Color(Palette.ALERT[1], 0.3)
	if not reach.is_empty() and Grid.inside(hover) and hover != me:
		var aim := Grid.nearest_dir(hover - me)
		if not aims.has(aim):
			var spells := staged.duplicate()
			spells.append({cards = picked.duplicate(), dir = aim})
			aims[aim] = Forecast.of(world, {t = &"cast", spells = spells})
		_paint(aims[aim], tints, marks)
	elif (
		picked.is_empty() and staged.is_empty() and Grid.inside(hover) and Grid.cheb(hover, me) > 1
	):
		for p in Travel.route(routes, hover):
			tints[p] = Color(Palette.TEXT, 0.12)
	var a := world.actor_at(hover) if Grid.inside(hover) else null
	if a != null and a.faction != Actor.FOX and world.seen[Grid.index(hover)] == 1:
		var view := known.view_of(a)
		for i in view.size():
			if view[i] == 1 and world.known[i] == 1 and not tints.has(Grid.at(i)):
				tints[Grid.at(i)] = Color(Palette.SIDE[1], 0.3)
	term.tints = tints
	term.marks = marks


func _inspect() -> void:
	term.info = []
	term.cursor = Vector2i(-1, -1)
	if state != &"play":
		return
	term.cursor = hover
	if hover_card != &"":
		term.info = Info.card(hover_card)
	elif hover_status:
		term.info = Info.creature(known, known.player())
	else:
		term.info = Info.at(known, hover) + _ahead_lines(hover)


## What stepping onto p (or waiting, on Miho's own tile) would bring, as the
## harm number or yellow tint on that tile shows it.
func _ahead_lines(p: Vector2i) -> Array:
	var d := p - world.player().pos
	var f: Forecast = ahead.get(d) if Grid.cheb(p, world.player().pos) <= 1 else null
	if f == null:
		return []
	var how := "기다리면" if d == Vector2i.ZERO else "이 칸으로 가면"
	var lines := []
	if f.hurt_me() > 0:
		lines.append([[how + " 피해를 %d 입는다" % f.hurt_me(), Palette.HURT]])
	if not f.noticed.is_empty():
		var names := f.noticed.keys().map(func(id): return f.after.actor(id).info().name)
		lines.append([[how + " " + ", ".join(names) + "에게 들킨다", Palette.ALERT[1]]])
	return lines


func _paint(f: Forecast, tints: Dictionary, marks: Dictionary) -> void:
	for id in f.paths:
		var path: Dictionary = f.paths[id]
		for p in path.tiles:
			tints[p] = Color(Palette.SIDE[path.faction], 0.35)
	for id in f.harm:
		var a := f.after.actor(id)
		if a != null:
			marks[a.pos] = [str(f.harm[id]), Palette.HURT]
