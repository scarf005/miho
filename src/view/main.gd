extends Node
## Game flow and input, through the actions in Keys. Arrows, numpad or
## hjklyubn move, and keep moving while held; moving into a creature strikes it
## with claws. Space, Enter or . waits, or hurls what is queued. The queue and its aim
## are Casting's, walks of many rounds Journey's, the look cursor and what the pointer
## is over LookMode's, the page over the game Panels'. , casts the queue on Miho (Guise),
## as does a click on her; g, or a click on her with nothing queued, lists the buffs to drop.
## Esc clears the queue and what is held and, with nothing to clear, opens the options.
## c shuts an open door next to Miho (a direction key picks one when several are open).
## Tab fights like DCSS (Fight): it claws the nearest creature in sight or steps towards it,
## and with a queue moves the aim. F3 shows the debug view (DebugView), which changes nothing
## in the game; F4, or a click on its label, lists the debug commands (DebugMenu) in a box
## over the game, which play as actions.
## Mouse: click a neighbour to move or a farther known tile to walk there, or with a queue click
## anywhere to hurl; click a talisman to queue it or a 도감 word to open it; right-click clears.
## A step onto a plate found, fire or a drop asks first, and a held key stops when a creature comes
## into sight (StepGuard). Erasing the run asks first as well. The run is saved once a second
## (Autosave) and the title continues it; a run that ends leaves no save.

## Message lines shown over the map, and for how many rounds.
const LOG_ROWS := 3
const LOG_FADE := 5
## Time per frame spent replaying a saved run on Continue; the rest draws the count.
const REPLAY_BUDGET_MS := 40

var world: World
var term: Term
var sfx: Sfx
var touch := Touch.new()
var reel := Highlight.new()
var casting := Casting.new(self)
var journey := Journey.new(self)
var look := LookMode.new(self)
var panels := Panels.new(self)
var busy := false
var state := &"title"
## Several open doors are next to Miho: the next direction key shuts that one.
var shutting := false
## The step prompt and the sight of a held key (StepGuard), and whether the key
## being handled is a repeat of a held one.
var guard := StepGuard.new()
var held := false
## The title asks whether to erase the run on disk for a new one.
var erasing := false
## The debug view is on: the whole storey, creatures and their goals are shown.
var debugging := false
var skip := false
## This run's seed, and the creatures of heaven that fell in it.
var run_seed := 0
var kills := 0
## This run, and the run on disk that the title offers to continue (null when there is none).
var run := SaveGame.new()
var pending: SaveGame
var save_path := SaveGame.PATH
## Builds the world of a new run from its seed.
var make_world := World.create
var settings: Settings
var glass: ColorRect
var pan: Tween
var messages := Messages.new()
var menu := Menu.new()
## Worked out once per world or talisman change: what Miho knows, the forecast
## of each step or wait (direction -> Forecast), the spell's reach (tile -> tint),
## and forecasts of the spell hurled each way, filled as the pointer aims.
var known: World
var ahead := {}
var reach := {}
var aims := {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.VOID)
	settings = Settings.load_from()
	term = Term.new()
	add_child(term)
	touch.main = self
	add_child(touch)
	touch.start()
	add_child(Autosave.new(self))
	sfx = Sfx.new()
	term.add_child(sfx)
	term.shown.connect(sfx.on_event)
	term.settled.connect(func(w: World) -> void: sfx.watch(w, term.cell_centre))
	term.add_child(CodexSim.new())
	var crt := CanvasLayer.new()
	crt.layer = 10
	glass = ColorRect.new()
	glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.material = ShaderMaterial.new()
	glass.material.shader = preload("res://src/view/crt.gdshader")
	crt.add_child(glass)
	add_child(crt)
	get_viewport().size_changed.connect(fit)
	new_run()
	show_title()
	apply()
	Capture.attach(self)


## The title screen, offering to continue the run on disk if there is one.
func show_title(asking := false) -> void:
	pending = SaveGame.load_from(save_path)
	state = &"title"
	erasing = asking and pending != null
	Banner.show(self)


## A new run: a run on disk or in play asks once first. An ending has none to lose.
func new_game() -> void:
	if erasing or state == &"over" or state == &"title" and pending == null:
		restart()
	elif state == &"title":
		sfx.play(&"warn")
		show_title(true)
	else:
		Banner.ask(self)


## Writes again the text kept from before a change of language: the banner, the
## log over the map and the hover.
func _translated() -> void:
	if not busy:
		Banner.show(self)
	if world != null:
		show_log()
		menu.log_rows = messages.lines.map(Messages.shown)
		refresh()


## Puts the settings into effect.
func apply() -> void:
	menu.settings = settings
	settings.apply_language()
	_translated()
	settings.apply_sound()
	sfx.set_music(settings.music)
	term.saved = settings.spells
	glass.visible = settings.crt > 0 and not touch.enabled
	Crt.apply(glass.material, settings.crt)
	term.speed = settings.speed
	fit()


## Lays the term out for the screen, and the page open on it.
func fit() -> void:
	if state == &"replay":
		return
	if touch.enabled:
		touch.fit()
	else:
		term.fit(get_viewport().get_visible_rect().size, settings.zoom)
	if panels.overlay != &"":
		menu.room = Vector2i(term.cols, term.rows)
		term.panel = menu.panel()


## Replaces the world with a new run, `seed_value` its seed.
func new_run(seed_value := randi()) -> void:
	run.flush()
	world = make_world.call(seed_value)
	run_seed = seed_value
	run = SaveGame.new(save_path, seed_value)
	erasing = false
	kills = 0
	casting.last_spell = ""
	journey.start_zones()
	messages = Messages.new()
	term.log_lines = []
	reel.clear()
	casting.forget()
	term.show_world(world)
	forecast()


# --- input ----------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	var press := event.is_pressed() and not event.is_echo()
	var walked := journey.walking or state == &"replay"
	if event is InputEventKey and event.keycode == KEY_SHIFT and not event.is_echo():
		WordHover.hold(self, event.pressed)
	if event.is_pressed() and state in [&"play", &"replay"]:
		journey.halt = journey.halt or journey.walking and press
		skip = skip or press
		term.rush()
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch.input(event)
	elif event is InputEventMouseMotion:
		if not touch.gesture.touching():
			if not event.shift_pressed:
				WordHover.hold(self, false)
			Preview.point(self, event.position)
	elif walked:
		pass
	elif (
		busy
		or not event.is_pressed()
		or event.is_echo() and panels.overlay == &"" and state != &"play"
	):
		pass
	elif panels.overlay != &"":
		panels.input(event)
	elif menu.debug.asking():
		menu.debug.pick(self, event)
	elif erasing:
		if press and event is InputEventKey and event.keycode == KEY_Y:
			restart()
		elif press:
			Banner.keep(self)
	elif state == &"play" and world.elixir_asked:
		_answer(event)
	elif state == &"title" and Keys.action_of(event) in [&"help", &"cancel"]:
		panels.open(&"help" if Keys.action_of(event) == &"help" else &"options")
	elif state == &"title" and pending != null:
		if event is InputEventKey and event.keycode == KEY_N:
			new_game()
		elif Keys.action_of(event) == &"confirm" or left_click(event):
			resume()
	elif state == &"title":
		begin()
	elif state == &"over":
		Banner.input(self, event)
	elif event is InputEventKey:
		_key(event)
	elif event is InputEventMouseButton and press:
		click(event)


## A press while the elixir waits for an answer (Elixir): Y drinks it and N keeps it. The
## pages stay open to read; nothing else takes a turn.
func _answer(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var action := Keys.action_of(event)
	if event.keycode in [KEY_Y, KEY_N]:
		act({t = &"drink", yes = event.keycode == KEY_Y})
	elif action in [&"cancel", &"log", &"help", &"codex", &"restart"]:
		do_action(action, false)


## Leaves the title for the run.
func begin() -> void:
	state = &"play"
	term.banner_lines = []
	sfx.play(&"card")


## Whether `event` is the left mouse button.
static func left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT


## Takes up the run saved on disk where it left off, playing its rounds again
## one a frame with the count on the title. A run the rules no longer allow is
## dropped.
func resume() -> void:
	var saved := pending
	busy = true
	saved.begin()
	while saved.played < saved.actions.size():
		term.banner_lines = [Lang.t("미호"), "%d/%d" % [saved.played, saved.actions.size()]]
		var until := Time.get_ticks_msec() + REPLAY_BUDGET_MS
		while saved.played < saved.actions.size() and Time.get_ticks_msec() < until:
			if not saved.step():
				saved.erase()
				busy = false
				show_title()
				return
		await get_tree().process_frame
	busy = false
	world = saved.world
	messages = saved.messages
	run = saved
	run_seed = run.seed_value
	kills = run.kills
	journey.excluded.zones = run.exclusions.duplicate()
	pending = null
	state = &"play"
	term.banner_lines = []
	term.log_lines = []
	reel.clear()
	casting.forget()
	term.show_world(world)
	show_log()
	forecast()
	sfx.play(&"card")


## Starts a new run, which replaces the one on disk.
func restart() -> void:
	run.erase()
	pending = null
	state = &"play"
	term.banner_lines = []
	new_run()


## Moves repeat while their key is held; other actions take only fresh presses.
## Repeats that arrive while a round plays are dropped, so none pile up. A fresh
## press notes the creatures in sight (a repeat stops once another comes into
## sight), and StepGuard.reply reads an answer to a step prompt.
func _key(event: InputEventKey) -> void:
	var action := Keys.action_of(event)
	held = event.is_echo()
	if not held:
		guard.sighted = Travel.in_sight(world)
	match guard.reply(event, action):
		&"yes":
			guard.go(self)
		&"no":
			_unask()
		&"":
			if not held or Keys.MOVES.has(action) and not guard.startled(world):
				do_action(action, event.shift_pressed)
	held = false


## What a key means, or a button of the touch screen: `action` is a Keys action,
## `shift` holds a spell with a direction.
func do_action(action: StringName, shift: bool) -> void:
	if action == &"describe":
		WordLink.describe(self)
		return
	if action != &"":
		WordHover.hold(self, false)
	var eat := casting.eats_move()
	if not guard.answers(action):
		_unask()
	if shutting:
		shutting = false
		if Keys.MOVES.has(action):
			act({t = &"close", dir = Keys.MOVES[action]})
		return
	if look.active and look.key(action, shift):
		return
	if Keys.MOVES.has(action):
		if not eat:
			casting.direction(Keys.MOVES[action], shift)
	elif action.begins_with("pick_"):
		var i := int(action.trim_prefix("pick_")) - 1
		if i < world.cards.size():
			casting.add(world.cards[i])
			casting.aim()
	elif action in [&"wait", &"confirm"] and not casting.picked.is_empty():
		casting.hurl_at_cursor()
	elif action == &"self" and not casting.picked.is_empty():
		casting.direction(Vector2i.ZERO, shift)
	elif action in [&"wait", &"confirm"]:
		act(
			(
				{t = &"cast", spells = casting.staged.duplicate()}
				if not casting.staged.is_empty()
				else {t = &"wait"}
			)
		)
	elif action == &"unpick":
		casting.unpick()
	elif action == &"cancel" and (not casting.picked.is_empty() or not casting.staged.is_empty()):
		casting.clear()
	elif action == &"cancel":
		panels.open(&"options")
	elif action == &"stairs":
		journey.to_stairs()
	elif action == &"explore":
		journey.explore()
	elif action == &"exclude_clear":
		journey.excluded.clear()
		journey.zones_changed()
	elif action == &"spellbook":
		panels.open(&"spells")
	elif Keys.SLOTS.has(action):
		casting.recall(settings.spells.get(action, ""))
		casting.aim()
	elif action == &"again":
		casting.again()
	elif action == &"look":
		look.active = true
		look.at(world.player().pos)
	elif action == &"restart":
		new_game()
	elif action == &"rest":
		journey.rest()
	elif action == &"close":
		_shut()
	elif action == &"dispel":
		Menu.dispel(self)
	elif action == &"fight":
		if casting.picked.is_empty():
			_fight()
		else:
			casting.aim_next()
	elif action == &"scent":
		settings.scent = not settings.scent
		settings.save()
		refresh()
	elif action == &"debug":
		debugging = not debugging
		refresh()
	elif action in [&"log", &"help", &"codex", &"cheat"]:
		panels.open(action)


## A mouse press in play: on a word, the bar or a tile.
func click(event: InputEventMouseButton) -> void:
	if left_click(event) and WordLink.open(self, to_term(event.position)):
		return
	term.pin = {}
	look.active = false
	shutting = false
	var eat := casting.eats_move()
	if not Grid.inside(look.hover) or look.hover - world.player().pos != guard.asking:
		_unask()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		casting.clear()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := to_term(event.position)
	if term.bar.debug_at(term, local):
		panels.open(&"cheat")
		return
	var card: StringName = term.bar.card_at(term, local)
	if card != &"":
		casting.add(card)
		return
	var preset: String = term.bar.preset_at(term, local)
	if preset != "":
		casting.recall(preset)
		casting.aim()
		return
	if Grid.inside(look.hover) and not eat:
		use_tile(look.hover, event.shift_pressed)


## What a left click on `tile` does: on Miho's own, cast the talismans picked on her, or
## with none list her buffs to drop (a stray click must not pass the turn); hurl towards
## another with talismans picked, step to a neighbour, or walk to a farther tile.
func use_tile(tile: Vector2i, hold: bool) -> void:
	var me := world.player().pos
	if tile == me and casting.picked.is_empty():
		if casting.staged.is_empty() and not Guise.worn(world, world.player()).is_empty():
			panels.open(&"dispel")
		return
	if not casting.picked.is_empty():
		casting.direction(Grid.nearest_dir(tile - me), hold)
	elif Grid.cheb(tile, me) == 1:
		move(tile - me)
	else:
		journey.to_tile(tile)


## The pointer's screen point; nowhere on a touch screen.
func mouse() -> Vector2:
	return Touch.OFF if touch.enabled else get_viewport().get_mouse_position()


## A screen point in the term's space, through the CRT curve when it is on.
func to_term(screen: Vector2) -> Vector2:
	if glass.visible:
		screen = Crt.flat(screen, get_viewport().get_visible_rect().size, settings.crt)
	return term.get_global_transform().affine_inverse() * screen


# --- turns ----------------------------------------------------------------------


## A step. Onto a found plate, fire or a drop it asks first (StepGuard): the same
## step again, or Y, takes it; a held key never does.
func move(d: Vector2i) -> void:
	if StepGuard.danger(world, d, ahead.get(d)) and (held or guard.asking != d):
		if not held:
			guard.asking = d
			StepGuard.ask(self, [[StepGuard.question(world, d, touch.enabled), Palette.TEXT]])
		return
	act({t = &"move", dir = d})


## Drops the step prompt, if one is up.
func _unask() -> void:
	if guard.asked():
		guard.drop()
		show_log()


## Plays one round and returns its events (none when the action is not allowed).
func act(action: Dictionary) -> Array:
	if not world.can(action):
		sfx.play(&"click")
		return []
	if guard.holds_back(self, action):
		return []
	guard.drop()
	busy = true
	term.tints = {}
	term.marks = {}
	term.lines = []
	term.info = []
	term.example = {}
	term.cursor = Vector2i(-1, -1)
	var before := world.clone()
	var depth := world.depth
	var events := world.act(action)
	term.scent = Preview.trail(self)
	if world.depth != depth:
		journey.start_zones()
	reel.record(before, action, events)
	kills += events.filter(func(e): return e.t == &"die" and e.get("foe", false)).size()
	run.record(action, kills, world.outcome != &"")
	sfx.listener.position = term.cell_centre(world.player().pos)
	await term.play(events, before, world)
	messages.add_round(before, world, events)
	run.keep(world, messages)
	show_log()
	if action.t == &"cast":
		casting.last_spell = "+".join(action.spells.back().cards)
		casting.forget()
		Preview.point(self, mouse())
	if world.depth != depth or world.outcome == &"won":
		reel.rounds.pop_back()
		if settings.replay and action.t != &"cheat":
			await Replay.play(self)
		reel.clear()
	if world.outcome != &"":
		state = &"over"
		Banner.show(self)
	busy = false
	forecast()
	return events


## Shuts the open door next to Miho; with several, waits for a direction key.
func _shut() -> void:
	if look.shuts(look.hover):
		act({t = &"close", dir = look.hover - world.player().pos})
		return
	var doors := Grid.DIRS.filter(func(d): return world.can({t = &"close", dir = d}))
	if doors.size() == 1:
		act({t = &"close", dir = doors[0]})
		return
	sfx.play(&"click")
	shutting = not doors.is_empty()
	say("어느 쪽 문을 닫을까? 방향키" if shutting else "닫을 문이 없다")


## Tab: claws the nearest creature in sight or steps towards it; refuses when
## Miho is badly hurt or sees none.
func _fight() -> void:
	var step := {} if Fight.too_hurt(world) else Fight.step(world)
	if step.is_empty():
		say("너무 다쳐서 싸울 수 없다" if Fight.too_hurt(world) else "보이는 적이 없다")
		sfx.play(&"click")
		return
	casting.clear()
	await act(step)


# --- messages -----------------------------------------------------------------


## Puts the run's seed on the clipboard; the banner of a finished run says so.
func copy_seed() -> void:
	Banner.copy(run_seed, term)
	sfx.play(&"card")
	say("시드를 복사했다")


## Says `text` in the log.
func say(text: Variant) -> void:
	messages.add_text(text, world.round_no)
	show_log()


## The last few lines over the map, older ones dimmer, gone after LOG_FADE rounds.
func show_log() -> void:
	var recent := messages.lines.slice(-LOG_ROWS).filter(
		func(l): return world.round_no - l.round <= LOG_FADE
	)
	term.log_lines = []
	for k in recent.size():
		term.log_lines.append([Messages.shown(recent[k]), 1.0 - 0.3 * (recent.size() - 1 - k)])
	if world.elixir_asked:
		var ask := [[Lang.t(Elixir.ASK), Palette.TEXT]]
		term.log_lines.append([ask if touch.enabled else ask + [[" Y/N", Palette.TEXT]], 1.0])
	# The line the pointer's word hover came from may be gone or have moved.
	var hinted := not term.hint.is_empty()
	term.hint = WordHover.at(term, term.hint_at * Term.CELL)
	if hinted == term.hint.is_empty() and not busy:
		refresh()


## What each choice would do, from what Miho knows: the reach of the spell in
## hand, and on each neighbouring tile the harm she would take and whether she
## would be seen there. These depend only on the world and the talismans in
## hand, so they are worked out once per change and reused while the pointer moves.
func forecast() -> void:
	if world == null:
		return
	_unask()
	known = world.known_clone()
	var me := world.player().pos
	journey.plan()
	ahead = {}
	aims = {}
	reach = {}
	var spell := Spell.make(casting.picked)
	if spell != null and (spell.shape == Spell.LEAP or spell.has(Cards.BUNSIN)):
		for d in Grid.DIRS:
			if Leap.open(known, known.player(), spell, d):
				reach[Leap.aimed(known, me, d, spell)] = Color(Palette.SIDE[0], 0.3)
	elif spell != null:
		for d in Grid.DIRS:
			for p in Forecast.ray(world, me, d).slice(0, Spell.RANGE):
				reach[p] = Color(Palette.SIDE[0], 0.12)
	elif world.outcome == &"":
		for d: Vector2i in Grid.DIRS + [Vector2i.ZERO]:
			var action := {t = &"wait"} if d == Vector2i.ZERO else {t = &"move", dir = d}
			if world.can(action):
				ahead[d] = Forecast.of(world, action)
	refresh()


## Under the pointer: what is there and what a click or a spell would do (Preview).
func refresh() -> void:
	if world != null:
		Preview.paint(self)
