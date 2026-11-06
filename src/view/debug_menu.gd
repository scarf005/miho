class_name DebugMenu
extends RefCounted
## The debug commands (Cheat) as a list in a box over the game, moved through as
## ListNav says. Enter on a toggle or a plain command plays it; the rest ask for
## more first: a row opens a list of its own (Esc goes back to the row), and a
## command that needs a tile or a creature hides the box and waits for the cursor
## (the pointer, or the direction keys, Shift five tiles) to be put on one and
## Enter or a click to pick it; Tab moves the cursor to the next creature and
## Esc or a right click gives up. The box hides while a command plays and is
## back on the row it was left on once the round is over, unless the run ended.
## `key` and `click` return &"close" when the game should close the page and
## `run` the command asked for (`request`), else nothing.

## Cells between the longest name and the value beside it.
const GAP := 2.0
## The harm 적에게 피해 deals, stepped with Left and Right.
const AMOUNTS: Array[int] = [1, 2, 3, 5, 10, 20, 50]
const COMMANDS: Array[StringName] = [
	&"teleport",
	&"god",
	&"kill",
	&"damage",
	&"tails",
	&"move_foe",
	&"floor",
	&"card",
	&"summon",
	&"reveal",
	&"heal",
	&"halt",
	&"elixir",
]
## The rows of 적 제거.
const KILLS := ["하나", "모두"]
const FAR := 5

var world: World
## The list shown: empty for the commands, else the command whose list it is.
var page := &""
var selected := 0
var top := 0
var hovered := -1
var amount := 2
## The command a row chose: {action} to play at once, or {ask} to wait for picks.
var request := {}
## The command waiting for picks: {cmd, needs: [&"foe" or &"tile", ...], args}.
var ask := {}
var room := Vector2i(40, 18)
## The box is opening again after a command: on the list it was left on.
var resume := false
var _row := 0


## Opens the box on the commands, on the row it was last left on; after a
## command (`resume`) on the list that command was chosen from.
func open(size: Vector2i) -> void:
	room = size
	if not resume:
		selected = clampi(_row if page != &"" else selected, 0, COMMANDS.size() - 1)
		page = &""
	resume = false
	top = ListNav.reveal(0, selected, _rows().size(), _fits())
	hovered = -1
	request = {}


func panel() -> Dictionary:
	var title: String = Lang.t(Cheat.NAME.get(page, "디버그 명령"))
	return {
		title = title, rows = _rows(), selected = selected, top = top, hover = hovered, box = _box()
	}


## The box in the top right corner of the screen, in cells: as wide as its rows,
## and as high, but the two status rows stay in view.
func _box() -> Rect2:
	var wide := Term.text_cells(Lang.t(Cheat.NAME.get(page, "디버그 명령"))) + 2.0
	var rows := _rows()
	for row: Array in rows:
		wide = maxf(wide, PanelView.end(row))
	var high := clampi(rows.size() * PanelView.stride + 4, 5, maxi(5, room.y - 2))
	var size := Vector2(mini(ceili(wide) + 2, room.x), high)
	return Rect2(Vector2(room.x - size.x, 0), size)


func _fits() -> int:
	return PanelView.fits(int(_box().size.y), 0)


func _rows() -> Array:
	var rows := []
	match page:
		&"kill":
			rows = KILLS.map(func(n): return [[Lang.t(n), Palette.TEXT]])
		&"floor":
			for d in range(1, World.FLOORS + 1):
				var row := [[Lang.t("%d층") % d, Palette.KIND[&"miho"]]]
				if d == world.depth:
					row.append([Lang.t("지금"), Palette.DIM])
				rows.append(row)
		&"card":
			rows.append([[Lang.t("모두"), Palette.TEXT]])
			for c in Cards.ALL:
				var row := [[Lang.t(Cards.NAME[c]), Palette.card(c)]]
				if world.cards.has(c):
					row.append([Lang.t("있음"), Palette.DIM])
				rows.append(row)
		&"summon":
			for kind in Codex.foes():
				rows.append([[Lang.t(Bestiary.info(kind).name), Palette.KIND[kind]]])
		_:
			for cmd in COMMANDS:
				var row := [[Lang.t(Cheat.NAME[cmd]), Palette.TEXT]]
				if Cheat.TOGGLES.has(cmd):
					row.append([Lang.t("켜짐" if Cheat.on(world, cmd) else "꺼짐"), Palette.SIDE[0]])
				elif cmd == &"damage":
					row.append([str(AMOUNTS[amount]), Palette.SIDE[0]])
				rows.append(row)
	var value: float = (
		2.0 + GAP + rows.reduce(func(n, r): return maxf(n, Term.text_cells(r[0][0])), 0.0)
	)
	for row: Array in rows:
		if row.size() > 1:
			row[1].append(value)
	return rows


## Handles a key press with menu movement `nav`.
func key(e: InputEventKey, nav: StringName) -> StringName:
	if Keys.action_of(e) == &"cheat":
		return &"close"
	match nav:
		&"up", &"down", &"page_up", &"page_down", &"home", &"end":
			var count := _rows().size()
			selected = ListNav.step(nav, selected, count, _fits())
			top = ListNav.reveal(top, selected, count, _fits())
		&"left", &"right":
			if page == &"" and COMMANDS[selected] == &"damage":
				amount = posmod(amount + (1 if nav == &"right" else -1), AMOUNTS.size())
		&"enter":
			return _use()
		&"back":
			return back()
	return &""


func point(k: int) -> void:
	hovered = k


## A left click on row `row` (-1 for none): the row is chosen.
func click(row: int) -> StringName:
	if row < 0:
		return &""
	selected = row
	top = ListNav.reveal(top, selected, _rows().size(), _fits())
	return _use()


func scroll_by(lines: int) -> void:
	top = ListNav.scrolled(top, lines, _rows().size(), _fits())


## Esc: a list of its own goes back to the commands, on the row that opened it.
func back() -> StringName:
	if page == &"":
		return &"close"
	page = &""
	selected = _row
	top = ListNav.reveal(0, selected, COMMANDS.size(), _fits())
	return &""


## Enter on the selected row.
func _use() -> StringName:
	if page != &"":
		return _chosen()
	var cmd := COMMANDS[selected]
	match cmd:
		&"kill", &"floor", &"card", &"summon":
			_row = selected
			page = cmd
			selected = 0
			top = 0
			return &""
		&"teleport":
			return _asks(cmd, [&"tile"])
		&"damage":
			return _asks(cmd, [&"foe"], {n = AMOUNTS[amount]})
		&"move_foe":
			return _asks(cmd, [&"foe", &"tile"])
	return _plays({cmd = cmd})


## Enter on a row of a list of its own.
func _chosen() -> StringName:
	match page:
		&"kill":
			return _asks(&"kill", [&"foe"]) if selected == 0 else _plays({cmd = &"kill_all"})
		&"floor":
			return _plays({cmd = &"floor", depth = selected + 1})
		&"card":
			if selected == 0:
				return _plays({cmd = &"cards"})
			return _plays({cmd = &"card", card = Cards.ALL[selected - 1]})
	return _asks(&"summon", [&"tile"], {kind = Codex.foes()[selected]})


func _plays(action: Dictionary) -> StringName:
	request = {action = action.merged({t = &"cheat"})}
	return &"close"


func _asks(cmd: StringName, needs: Array, args := {}) -> StringName:
	request = {ask = {cmd = cmd, needs = needs, args = args}}
	return &"close"


## The box has closed: plays the command asked for and opens the box again, or puts
## the cursor where the first pick is to be made.
func run(main: Node) -> void:
	var asked := request
	request = {}
	if asked.has("action"):
		await main.act(asked.action)
		_again(main)
	elif asked.has("ask"):
		ask = asked.ask
		main.look.at(_start(main.world))


## Whether a command waits for a tile or a creature.
func asking() -> bool:
	return not ask.is_empty()


## The first line of the tile's hover while a pick is waited for.
func head() -> Array:
	if not asking():
		return []
	var what := Lang.t("적" if ask.needs[0] == &"foe" else "칸")
	return [[[Lang.t("%s: %s") % [Lang.t(Cheat.NAME[ask.cmd]), what], Palette.TEXT]]]


## A key or click while a pick is waited for.
func pick(main: Node, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_pick_at(main, main.look.hover)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_give_up(main)
		return
	var action := Keys.action_of(event)
	if Keys.MOVES.has(action):
		main.look.at(
			Grid.nudge(main.look.hover, Keys.MOVES[action], FAR if event.shift_pressed else 1)
		)
	elif action == &"confirm":
		if not event.is_echo():
			_pick_at(main, main.look.hover)
	elif action == &"fight":
		main.look.at(_next(main.world, main.look.hover))
	elif action in [&"cancel", &"cheat"]:
		_give_up(main)


## Takes the creature or tile `p` as the next pick; with the last one picked the
## command is played, unless it does not fit, which asks again.
func _pick_at(main: Node, p: Vector2i) -> void:
	var w: World = main.world
	var foe := w.actor_at(p)
	if ask.needs[0] == &"foe":
		if foe == null or foe.faction == Actor.FOX:
			main.sfx.play(&"deny")
			return
		ask.args.id = foe.id
	else:
		ask.args.at = p
	if ask.needs.size() > 1:
		ask.needs.pop_front()
		main.look.at(p)
		return
	var action := {t = &"cheat", cmd = ask.cmd}.merged(ask.args)
	if not w.can(action):
		main.sfx.play(&"deny")
		return
	ask = {}
	main.look.at(p)
	await main.act(action)
	_again(main)


func _give_up(main: Node) -> void:
	ask = {}
	_again(main)


## Opens the box on the list it was left on, unless a command ended the run.
func _again(main: Node) -> void:
	if main.state == &"play" and main.panels.overlay == &"":
		resume = true
		main.panels.open(&"cheat")


## Where the cursor starts: on the nearest creature to pick one, else on Miho.
func _start(w: World) -> Vector2i:
	var foes := _foes(w)
	return foes[0].pos if ask.needs[0] == &"foe" and not foes.is_empty() else w.player().pos


## The creatures on the storey, nearest to Miho first.
func _foes(w: World) -> Array:
	var me := w.player().pos
	var foes := w.actors.filter(func(a): return a.alive() and a.faction != Actor.FOX)
	foes.sort_custom(func(a, b): return Grid.cheb(a.pos, me) < Grid.cheb(b.pos, me))
	return foes


## The creature after the one at `from`, wrapping round; `from` when there is none.
func _next(w: World, from: Vector2i) -> Vector2i:
	var foes := _foes(w)
	if foes.is_empty():
		return from
	return foes[(foes.find_custom(func(a): return a.pos == from) + 1) % foes.size()].pos
