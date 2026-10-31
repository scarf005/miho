extends Node
## Game flow and input, through the actions in Keys. Arrows, numpad or
## hjklyubn move, and keep moving while held; moving into a creature strikes it
## with claws. 1-7 pick talismans; with talismans picked a direction hurls the
## spell, and Shift with a direction holds it so several spells leave in one
## turn. Space, Enter or . waits, or hurls what is held. Esc clears what is
## picked and, with nothing to clear, opens the options.
## > walks to the stairs, o explores, z rests until the tails regrow. Tab fights
## like DCSS (Fight): it claws the nearest creature in sight or steps towards it.
## F3 shows the debug view (DebugView), which changes nothing in the game. x looks
## around: a cursor starts on Miho and the directions move it (Shift five
## tiles), showing what the pointer would; Enter walks there, Esc or x stops.
## In look mode the exclude key marks a danger zone (Exclusions) on the cursor
## that exploring and travel walk around; again it makes the zone one tile, and
## again removes it; 1-7 on a zone's centre set its radius.
## Mouse: click a neighbour to move or a farther known tile to walk there, or
## with talismans picked click anywhere to hurl that way; click a talisman to
## pick it; right-click clears. Each storey left behind replays its best moment.
## The run is saved after every round (SaveGame) and the title continues it; a
## run that ends leaves no save.

const REPLAY_ZOOM := 1.5
const REPLAY_SPEED := 0.7
## How much faster rounds play while walking many rounds.
const WALK_SPEED := 3.0
## Message lines shown over the map, and for how many rounds.
const LOG_ROWS := 3
const LOG_FADE := 5
## Tiles a cursor moves in look mode with Shift.
const LOOK_FAR := 5
## Time per frame spent replaying a saved run on Continue; the rest draws the count.
const REPLAY_BUDGET_MS := 40

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
## Key of the spell under the pointer on the status or talisman row, or empty.
var hover_spell := ""
## Look mode: the direction keys move the cursor, which is `hover`.
var looking := false
## The debug view is on: the whole storey, creatures and their goals are shown.
var debugging := false
var skip := false
## This run's seed, and the creatures of heaven that fell in it.
var run_seed := 0
var kills := 0
## This run as saved after every round, and the run on disk that the title
## offers to continue (null when there is none).
var run := SaveGame.new()
var pending: SaveGame
var save_path := SaveGame.PATH
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
## Shortest walks from Miho over what she knows, around the travel exclusions
## (Travel.search), and the tiles those cover.
var routes := {}
var excluded := Exclusions.new()
var zone := {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.VOID)
	settings = Settings.load_from()
	term = Term.new()
	add_child(term)
	sfx = Sfx.new()
	term.add_child(sfx)
	term.shown.connect(sfx.on_event)
	term.settled.connect(func(w: World) -> void: sfx.watch(w, term.cell_centre))
	var crt := CanvasLayer.new()
	crt.layer = 10
	glass = ColorRect.new()
	glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.material = ShaderMaterial.new()
	glass.material.shader = preload("res://src/view/crt.gdshader")
	glass.material.set_shader_parameter("curve", Crt.CURVE)
	crt.add_child(glass)
	add_child(crt)
	get_viewport().size_changed.connect(_fit)
	_new_run()
	_show_title()
	_apply()
	Capture.attach(self)


## The title screen, offering to continue the run on disk if there is one.
func _show_title() -> void:
	pending = SaveGame.load_from(save_path)
	state = &"title"
	term.banner_lines = [
		"미호",
		"천상누각 꼭대기에 사람이 되는 영약이 있다",
		"아무 키나 눌러 시작" if pending == null else "Enter 이어하기 · N 새로 시작",
	]


## Puts the settings into effect.
func _apply() -> void:
	menu.settings = settings
	settings.apply_sound()
	sfx.set_music(settings.music)
	term.saved = settings.spells
	glass.visible = settings.crt
	term.speed = settings.speed
	_fit()


func _fit() -> void:
	if state != &"replay":
		term.fit(get_viewport().get_visible_rect().size, settings.zoom)


func _new_run(seed_value := randi()) -> void:
	world = World.create(seed_value)
	run_seed = seed_value
	run = SaveGame.new(save_path, seed_value)
	kills = 0
	excluded.clear()
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
	elif state == &"title" and pending != null:
		if event is InputEventKey and event.keycode == KEY_N:
			_restart()
		elif Keys.action_of(event) == &"confirm" or _left_click(event):
			_continue()
	elif state == &"title":
		state = &"play"
		term.banner_lines = []
		sfx.play(&"card")
	elif state == &"over":
		if Keys.action_of(event) == &"restart":
			_restart()
	elif event is InputEventKey:
		_key(event)
	elif event is InputEventMouseButton and press:
		_click(event)


static func _left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT


## Takes up the run saved on disk where it left off, playing its rounds again
## one a frame with the count on the title. A run the rules no longer allow is
## dropped.
func _continue() -> void:
	var saved := pending
	busy = true
	saved.begin()
	while saved.played < saved.actions.size():
		term.banner_lines = ["미호", "%d/%d" % [saved.played, saved.actions.size()]]
		var until := Time.get_ticks_msec() + REPLAY_BUDGET_MS
		while saved.played < saved.actions.size() and Time.get_ticks_msec() < until:
			if not saved.step():
				saved.erase()
				busy = false
				_show_title()
				return
		await get_tree().process_frame
	busy = false
	world = saved.world
	messages = saved.messages
	run = saved
	run_seed = run.seed_value
	kills = run.kills
	excluded.zones = run.exclusions.duplicate()
	pending = null
	state = &"play"
	term.banner_lines = []
	term.log_lines = []
	reel.clear()
	picked.clear()
	staged.clear()
	term.show_world(world)
	_show_log()
	_forecast()
	sfx.play(&"card")


## Starts a new run, which replaces the one on disk.
func _restart() -> void:
	run.erase()
	pending = null
	state = &"play"
	term.banner_lines = []
	_new_run()


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
		_journey(_to_exit, _walled_in(Travel.exit(world), "아직 계단을 찾지 못했다"))
	elif action == &"explore":
		_journey(_exploring, "" if _explore_walled() else "더 탐험할 곳이 없다")
	elif action == &"exclude_clear":
		excluded.clear()
		_zones_changed()
	elif action == &"spellbook":
		menu.cards = world.cards
		_open(&"spells")
	elif Keys.SLOTS.has(action):
		_recall(settings.spells.get(action, ""))
	elif action == &"look":
		looking = true
		_look_at(world.player().pos)
	elif action == &"rest":
		_journey(_resting, "꼬리가 이미 다 자랐다")
	elif action == &"fight":
		_fight()
	elif action == &"debug":
		debugging = not debugging
		_refresh()
	elif action in [&"log", &"help"]:
		_open(action)


func _click(event: InputEventMouseButton) -> void:
	looking = false
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_clear()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := _local(event.position)
	var card := term.card_at(local)
	if card != &"":
		_toggle(card)
		return
	if Grid.inside(hover):
		_use_tile(hover, event.shift_pressed)


## What a left click on `tile` does: nothing on Miho's own (a stray click must not
## pass the turn), hurl towards another with talismans picked, step to a
## neighbour, or walk to a farther tile.
func _use_tile(tile: Vector2i, hold: bool) -> void:
	var me := world.player().pos
	if tile == me:
		return
	if not picked.is_empty():
		_direction(Grid.nearest_dir(tile - me), hold)
	elif Grid.cheb(tile, me) == 1:
		_act({t = &"move", dir = tile - me})
	else:
		_journey(func(): return _step_on(_path_to(tile)), _walled_in(tile, ""))


## A screen point in the term's space, through the CRT curve when it is on.
func _local(screen: Vector2) -> Vector2:
	if glass.visible:
		screen = Crt.flat(screen, get_viewport().get_visible_rect().size)
	return term.get_global_transform().affine_inverse() * screen


func _point(screen: Vector2) -> void:
	var local := _local(screen)
	if overlay != &"" and overlay != &"log":
		menu.point(term.panel_row_at(local))
		term.panel = menu.panel()
	var tile := term.tile_at(local)
	if not Grid.inside(tile):
		tile = term.side_at(local)
	var card := term.card_at(local)
	var status := term.status_at(local)
	var spell := term.slot_at(local) + term.hand_at(local)
	if tile != hover or card != hover_card or status != hover_status or spell != hover_spell:
		hover = tile
		hover_card = card
		hover_status = status
		hover_spell = spell
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
	elif action == &"exclude" and world.known[Grid.index(hover)] == 1:
		excluded.cycle(hover)
		_zones_changed()
	elif action.begins_with("pick_") and excluded.zones.has(hover):
		excluded.set_radius(hover, int(action.trim_prefix("pick_")))
		_zones_changed()
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


## Picks a saved spell's talismans to aim it, if Miho has them and the tails.
func _recall(key: String) -> void:
	var spell := Spell.from_key(key) if key != "" else null
	var why := ""
	if spell == null:
		why = "저장한 주문이 없다. I로 주문서를 열고 칸 키를 눌러 저장"
	elif not spell.cards.all(func(c): return world.cards.has(c)):
		why = "부적이 모자라다"
	elif spell.cost() + _held() > world.tails:
		why = "꼬리가 모자라다"
	if why != "":
		_say(why)
		sfx.play(&"click")
		return
	picked.assign(spell.cards)
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
	if world.depth != depth:
		excluded.clear()
		run.exclusions = {}
	reel.record(before, action, events)
	kills += events.filter(func(e): return e.t == &"die" and e.id != world.player().id).size()
	# Saved before the round plays out, so closing the game at any point keeps it.
	run.record(action, kills, world.outcome != &"")
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
		if (
			f == null
			or f.hurt_me() > 0
			or f.drops_me()
			or not f.noticed.is_empty()
			or not world.can(action)
		):
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


## Tab: claws the nearest creature in sight or steps towards it; refuses when
## Miho is badly hurt or sees none.
func _fight() -> void:
	var step := {} if Fight.too_hurt(world) else Fight.step(world)
	if step.is_empty():
		_say("너무 다쳐서 싸울 수 없다" if Fight.too_hurt(world) else "보이는 적이 없다")
		sfx.play(&"click")
		return
	_clear()
	await _act(step)


func _step_on(path: Array[Vector2i]) -> Dictionary:
	return {t = &"move", dir = path[0] - world.player().pos} if not path.is_empty() else {}


## The shortest walk to `tile`: around the exclusions, unless `tile` is in one,
## which Miho may walk into when told to.
func _path_to(tile: Vector2i) -> Array[Vector2i]:
	return Travel.route(Travel.search(world) if zone.has(tile) else routes, tile)


## What is said when the way to `goal` is shut only by the exclusions, else `otherwise`.
func _walled_in(goal: Vector2i, otherwise: String) -> String:
	var shut := (
		Grid.inside(goal)
		and Travel.route(routes, goal).is_empty()
		and not Travel.route(Travel.search(world), goal).is_empty()
	)
	return "위험구역 너머로는 가지 않는다" if shut else otherwise


## Whether nothing is left to explore only because of the exclusions.
func _explore_walled() -> bool:
	return (
		not excluded.is_empty()
		and Travel.explore_step(world, routes) == Vector2i.ZERO
		and Travel.explore_step(world, Travel.search(world)) != Vector2i.ZERO
	)


## The exclusions changed: keep them in the save and work out the walks again.
func _zones_changed() -> void:
	run.exclusions = excluded.zones.duplicate()
	run.write()
	_forecast()


func _to_exit() -> Dictionary:
	return _step_on(Travel.route(routes, Travel.exit(world)))


## A step towards the nearest unexplored ground, after resting until the tails
## have all regrown (DCSS explore_auto_rest).
func _exploring() -> Dictionary:
	var d := Travel.explore_step(world, routes)
	if d == Vector2i.ZERO:
		if _explore_walled():
			_say("위험구역 너머는 탐험하지 않는다")
		return {}
	return _resting() if world.tails < world.max_tails() else {t = &"move", dir = d}


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
		var local := _local(event.position)
		command = menu.use() if term.panel_row_at(local) >= 0 else &""
	match command:
		&"close":
			_close()
			return
		&"changed":
			settings.save()
			_apply()
		&"cast":
			_close()
			_clear()
			_recall(menu.chosen.key())
			return
		&"restart":
			_close()
			_restart()
			return
		&"quit":
			_quit()
			return
	term.panel = menu.panel()


## Ends the game with the run kept; a web page cannot close itself, so it
## goes back to the title.
func _quit() -> void:
	if not OS.has_feature("web"):
		get_tree().quit()
		return
	_close()
	_new_run()
	_show_title()


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
	var me := world.player().pos
	zone = excluded.tiles(world)
	routes = Travel.search(world, excluded.tiles(world, me))
	ahead = {}
	aims = {}
	reach = {}
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
	term.debug = DebugView.view(world) if debugging else {}
	term.zone = zone
	term.picked = picked
	term.staged = staged
	var tints := reach.duplicate()
	var marks := {}
	var me := world.player().pos
	for d: Vector2i in ahead:
		var f: Forecast = ahead[d]
		if f.drops_me():
			marks[me + d] = ["▼", Palette.HURT]
		elif f.hurt_me() > 0:
			marks[me + d] = [str(f.hurt_me()), Palette.HURT]
		elif not f.noticed.is_empty():
			tints[me + d] = Color(Palette.ALERT[2], 0.3)
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
		for p in _path_to(hover):
			tints[p] = Color(Palette.TEXT, 0.12)
	var a := world.actor_at(hover) if Grid.inside(hover) else null
	if a != null and a.faction != Actor.FOX and world.seen[Grid.index(hover)] == 1:
		var view := known.view_of(a)
		for i in view.size():
			if view[i] == 1 and world.known[i] == 1 and not tints.has(Grid.at(i)):
				tints[Grid.at(i)] = Color(Palette.SIDE[1], 0.3)
	if hover_status or hover == me:
		for i in world.seen.size():
			if world.seen[i] == 1 and not tints.has(Grid.at(i)):
				tints[Grid.at(i)] = Color(Palette.SIDE[0], 0.2)
	for b in world.actors:
		if _sneakable(b):
			tints[b.pos] = Color(Palette.ALERT[1], 0.35)
	term.tints = tints
	term.marks = marks


func _inspect() -> void:
	term.info = []
	term.cursor = Vector2i(-1, -1)
	if state != &"play":
		return
	term.cursor = hover
	if hover_spell != "":
		term.info = Info.spell(Spell.from_key(hover_spell))
	elif hover_card != &"":
		term.info = Info.card(hover_card)
	elif hover_status:
		term.info = Info.creature(known, known.player())
	else:
		var lines := DebugView.at(world, hover) if debugging else Info.at(known, hover)
		term.info = lines + _zone_lines(hover) + _ahead_lines(hover)


## Says a tile is in a travel exclusion, and the radius at its centre.
func _zone_lines(p: Vector2i) -> Array:
	if not zone.has(p):
		return []
	var radius: Variant = excluded.zones.get(p)
	var text := "위험구역" if radius == null else "위험구역 (반경 %d)" % radius
	return [[[text, Palette.ZONE]]]


## What stepping onto p (or waiting, on Miho's own tile) would bring, as the
## harm number or red tint on that tile shows it.
func _ahead_lines(p: Vector2i) -> Array:
	var d := p - world.player().pos
	var f: Forecast = ahead.get(d) if Grid.cheb(p, world.player().pos) <= 1 else null
	if f == null:
		return []
	var how := "기다릴 시" if d == Vector2i.ZERO else "이 칸으로 갈 시"
	var lines := []
	if f.hurt_me() > 0:
		lines.append([[how + " 피해를 %d 입는다" % f.hurt_me(), Palette.HURT]])
	if f.drops_me():
		lines.append([[how + " 하늘로 떨어져 %d층으로 내려간다" % f.after.depth, Palette.HURT]])
	if not f.noticed.is_empty():
		var names := f.noticed.keys().map(func(id): return f.after.actor(id).info().name)
		lines.append([[how + " " + ", ".join(names) + "에게 들킨다", Palette.ALERT[2]]])
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
	for id in f.falls:
		var a := world.actor(id)
		if a != null:
			marks[a.pos] = ["▼", Palette.HURT]


## A creature next to Miho that her claws would catch unawares (World._claw).
func _sneakable(a: Actor) -> bool:
	return (
		a.alive()
		and a.faction != Actor.FOX
		and Grid.cheb(a.pos, world.player().pos) == 1
		and world.seen[Grid.index(a.pos)] == 1
		and a.unaware()
	)
