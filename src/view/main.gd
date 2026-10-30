extends Node
## Game flow and input. Arrows, numpad or hjklyubn move; moving into a
## creature strikes it with claws. 1-7 pick talismans; with talismans picked a
## direction hurls the spell, and Shift with a direction holds it so several
## spells leave in one turn. Space, Enter or . waits, or hurls what is held.
## Esc clears; M mutes. Mouse: click a neighbour to move, or with talismans
## picked click anywhere to hurl that way; click a talisman to pick it;
## right-click clears. Each storey left behind replays its best moment.

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
const REPLAY_ZOOM := 1.5
const REPLAY_SPEED := 0.7

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
var skip := false
## Cell scale; 0 fits the whole map to the window.
var zoom := 0.0
var pan: Tween
## Worked out once per world or talisman change: what Miho knows, the forecast
## of each step or wait (direction -> Forecast), the spell's reach (tile -> tint),
## and forecasts of the spell hurled each way, filled as the pointer aims.
var known: World
var ahead := {}
var reach := {}
var aims := {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.VOID)
	term = Term.new()
	add_child(term)
	sfx = Sfx.new()
	term.add_child(sfx)
	term.shown.connect(sfx.on_event)
	var crt := CanvasLayer.new()
	crt.layer = 10
	var glass := ColorRect.new()
	glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.material = ShaderMaterial.new()
	glass.material.shader = preload("res://src/view/crt.gdshader")
	crt.add_child(glass)
	add_child(crt)
	get_viewport().size_changed.connect(_fit)
	_new_run()
	term.banner_lines = ["미호", "천상누각 꼭대기에 사람이 되는 영약이 있다", "아무 키나 누르면 시작"]
	_fit()
	Capture.attach(self)


func _fit() -> void:
	if state != &"replay":
		term.fit(get_viewport().get_visible_rect().size, zoom)


func _new_run(seed_value := randi()) -> void:
	world = World.create(seed_value)
	reel.clear()
	picked.clear()
	staged.clear()
	term.show_world(world)
	_forecast()


# --- input ----------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_point(event.position)
		return
	var press := event.is_pressed() and not event.is_echo()
	if state == &"replay":
		if press:
			skip = true
			term.speed = 8.0
		return
	if busy:
		return
	if state == &"title":
		if press:
			state = &"play"
			term.banner_lines = []
			sfx.play(&"card")
		return
	if state == &"over":
		if event is InputEventKey and press and event.keycode == KEY_R:
			state = &"play"
			term.banner_lines = []
			_new_run()
		return
	if event is InputEventKey and press:
		_key(event)
	elif event is InputEventMouseButton and press:
		_click(event)


func _key(event: InputEventKey) -> void:
	var key := event.keycode
	if key >= KEY_1 and key <= KEY_7:
		var i := key - KEY_1
		if i < world.cards.size():
			_toggle(world.cards[i])
	elif KEY_DIRS.has(key):
		_direction(KEY_DIRS[key], event.shift_pressed)
	elif key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_PERIOD, KEY_KP_5, KEY_KP_PERIOD]:
		_act({t = &"cast", spells = staged.duplicate()} if not staged.is_empty() else {t = &"wait"})
	elif key == KEY_ESCAPE:
		_clear()
	elif key == KEY_M:
		sfx.muted = not sfx.muted


func _click(event: InputEventMouseButton) -> void:
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
	if not Grid.inside(hover):
		return
	var me := world.player().pos
	if hover == me:
		_act({t = &"wait"})
	elif not picked.is_empty():
		_direction(Grid.nearest_dir(hover - me), event.shift_pressed)
	elif Grid.cheb(hover, me) == 1:
		_act({t = &"move", dir = hover - me})


func _point(screen: Vector2) -> void:
	var local := term.get_global_transform().affine_inverse() * screen
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


func _act(action: Dictionary) -> void:
	if not world.can(action):
		sfx.play(&"click")
		return
	busy = true
	term.tints = {}
	term.marks = {}
	term.info = []
	term.cursor = Vector2i(-1, -1)
	var before := world.clone()
	var depth := world.depth
	var events := world.act(action)
	reel.record(before, action, events)
	sfx.listener.position = term.cell_centre(world.player().pos)
	await term.play(events, before, world)
	if action.t == &"cast":
		picked.clear()
		staged.clear()
	if world.depth != depth or world.outcome == &"won":
		reel.rounds.pop_back()
		await _replay()
		reel.clear()
	if world.outcome == &"won":
		state = &"over"
		term.banner_lines = ["사람이 되었다", "%d초" % world.round_no, "R 다시"]
	elif world.outcome == &"lost":
		state = &"over"
		term.banner_lines = ["쓰러졌다", "%d층" % world.depth, "R 다시"]
	busy = false
	_forecast()


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
	term.speed = REPLAY_SPEED
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
	term.speed = 1.0
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


## Under the pointer: what is there, the tiles a creature there sees, and what
## the spell in hand would do hurled that way (each aim forecast once).
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
			marks[me + d] = ["!", Palette.ALERT[2]]
	if not reach.is_empty() and Grid.inside(hover) and hover != me:
		var aim := Grid.nearest_dir(hover - me)
		if not aims.has(aim):
			var spells := staged.duplicate()
			spells.append({cards = picked.duplicate(), dir = aim})
			aims[aim] = Forecast.of(world, {t = &"cast", spells = spells})
		_paint(aims[aim], tints, marks)
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
		term.info = Info.at(known, hover)


func _paint(f: Forecast, tints: Dictionary, marks: Dictionary) -> void:
	for id in f.paths:
		var path: Dictionary = f.paths[id]
		for p in path.tiles:
			tints[p] = Color(Palette.SIDE[path.faction], 0.35)
	for id in f.harm:
		var a := f.after.actor(id)
		if a != null:
			marks[a.pos] = [str(f.harm[id]), Palette.HURT]
