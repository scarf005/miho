class_name GameTools
extends RefCounted
## The game as MCP tools. No MCP library exists for GDScript, and the protocol
## surface needed is small: initialize, notifications/initialized, ping,
## tools/list and tools/call, as JSON-RPC 2.0 over Godot's JSON class. `handle`
## takes one parsed request and returns the response, or null for a
## notification, so it runs without stdio (server.gd is the stdio loop).
##
## The agent plays on what Miho knows only (Observation). Walks of many rounds
## stop by the rules of Main._journey: forecast harm, being noticed, fire next to
## the step, and Travel.interrupted.

const PROTOCOL := "2025-06-18"
const MAX_ROUNDS := 200
const INSTRUCTIONS := (
	"Play Miho, a fox climbing a pavilion of 27 storeys to drink the elixir on the top one. "
	+ "She grows a tail every third storey, up to nine. "
	+ "Call new_game, then act. Every result shows the map and what Miho knows. "
	+ "Game text is Korean. Use forecast to check a step before taking it, "
	+ "and explore, rest, stairs and travel to walk many rounds safely."
)
## The walks of many rounds, with what is said when one cannot take a first step.
const WALKS := {
	&"explore": "There is nowhere left to explore.",
	&"rest": "All the tails are already grown.",
	&"stairs": "Miho has not seen the stairs yet.",
	&"travel": "There is no known path there, or Miho is already there.",
}
const DIRS := {
	"type": "string",
	"enum": ["n", "ne", "e", "se", "s", "sw", "w", "nw"],
	"description": "Direction."
}
const SPELLS := {
	type = "array",
	description =
	(
		"Spells hurled this round, each along its own direction. cards are talisman names "
		+ "(fox, orb, fire, water, wood, metal, earth) or their Korean names. A spell needs fox or orb; "
		+ "all cards together cost at most the unspent tails."
	),
	items =
	{
		type = "object",
		properties = {cards = {type = "array", items = {type = "string"}}, dir = DIRS},
		required = ["cards", "dir"],
	},
}
const TOOLS := [
	{
		name = "new_game",
		description = "Start a new run and return the first observation.",
		inputSchema =
		{
			type = "object",
			properties = {seed = {type = "integer", description = "Seed; random when omitted."}},
		},
	},
	{
		name = "observe",
		description = "Return the current observation without acting.",
		inputSchema = {type = "object", properties = {}},
	},
	{
		name = "act",
		description =
		(
			"Take an action. move steps in dir, or claws a creature there, or knocks a lantern or window; "
			+ "wait passes a round; cast hurls spells. explore, rest (until the tails regrow), "
			+ "stairs (to the seen stairs) and travel (to x,y) walk many rounds, up to 200, "
			+ "and stop when a step would harm Miho or get her noticed, fire is next to the step, "
			+ "or something happens. An illegal action is refused and changes nothing."
		),
		inputSchema =
		{
			type = "object",
			properties =
			{
				action =
				{
					"type": "string",
					"enum": ["move", "wait", "cast", "explore", "rest", "stairs", "travel"],
				},
				dir = DIRS,
				spells = SPELLS,
				x = {type = "integer", description = "travel: tile column."},
				y = {type = "integer", description = "travel: tile row."},
			},
			required = ["action"],
		},
	},
	{
		name = "look",
		description = "Describe the tile (x, y) as Miho knows it: terrain, creature, projectile.",
		inputSchema =
		{
			type = "object",
			properties = {x = {type = "integer"}, y = {type = "integer"}},
			required = ["x", "y"],
		},
	},
	{
		name = "forecast",
		description =
		(
			"What one move, wait or cast would do this round: harm to Miho, who would notice her, "
			+ "harm dealt. Changes nothing."
		),
		inputSchema =
		{
			type = "object",
			properties =
			{
				action = {"type": "string", "enum": ["move", "wait", "cast"]},
				dir = DIRS,
				spells = SPELLS,
			},
			required = ["action"],
		},
	},
]

var world: World


static func error(id: Variant, code: int, message: String) -> Dictionary:
	return {jsonrpc = "2.0", id = _id(id), error = {code = code, message = message}}


## A whole-number id as an integer, so it reads back as the client sent it.
static func _id(id: Variant) -> Variant:
	return int(id) if id is float and id == floorf(id) else id


static func _result(id: Variant, result: Dictionary) -> Dictionary:
	return {jsonrpc = "2.0", id = _id(id), result = result}


## The response to one request, or null when none is owed (a notification).
func handle(request: Dictionary) -> Variant:
	if not request.has("id"):
		return null
	var id: Variant = request.id
	var method: Variant = request.get("method")
	if not method is String:
		return error(id, -32600, "Invalid request")
	var reply := error(id, -32601, "Method not found: " + method)
	match method:
		"initialize":
			reply = _result(
				id,
				{
					protocolVersion = PROTOCOL,
					capabilities = {tools = {}},
					serverInfo = {name = "miho", version = "1.0.0"},
					instructions = INSTRUCTIONS,
				}
			)
		"ping":
			reply = _result(id, {})
		"tools/list":
			reply = _result(id, {tools = TOOLS})
		"tools/call":
			reply = _call(id, request.get("params"))
	return reply


func _call(id: Variant, params: Variant) -> Dictionary:
	if not params is Dictionary or not params.get("name") is String:
		return error(id, -32602, "Invalid params: a tool name is required")
	var args: Variant = params.get("arguments", {})
	if not args is Dictionary:
		return error(id, -32602, "Invalid params: arguments must be an object")
	if not TOOLS.any(func(t): return t.name == params.name):
		return error(id, -32602, "Unknown tool: " + params.name)
	if world == null and params.name != "new_game":
		return _result(id, _fail("No game is running. Call new_game first."))
	return _result(id, call("_" + params.name, args))


static func _ok(text: String) -> Dictionary:
	return {content = [{type = "text", text = text}], isError = false}


static func _fail(text: String) -> Dictionary:
	return {content = [{type = "text", text = text}], isError = true}


# --- tools -------------------------------------------------------------------


func _new_game(args: Dictionary) -> Dictionary:
	var seed_value: Variant = args.get("seed", randi())
	if not _whole(seed_value):
		return _fail("seed must be an integer.")
	world = World.create(int(seed_value))
	return _ok("seed %d\n%s" % [int(seed_value), Observation.text(world)])


func _observe(_args: Dictionary) -> Dictionary:
	return _ok(Observation.text(world))


func _look(args: Dictionary) -> Dictionary:
	if not _whole(args.get("x")) or not _whole(args.get("y")):
		return _fail("x and y must be integers.")
	var p := Vector2i(int(args.x), int(args.y))
	if not Grid.inside(p):
		return _fail("(%d,%d) is outside the map." % [p.x, p.y])
	var lines := Info.at(world.known_clone(), p)
	return _ok(
		Info.plain(lines) if not lines.is_empty() else "unknown: Miho has not made out this tile"
	)


func _forecast(args: Dictionary) -> Dictionary:
	var action := _action(args)
	if not action.has("t") or not [&"move", &"wait", &"cast"].has(action.t):
		return _fail(action.get("error", "forecast takes move, wait or cast."))
	if not world.can(action):
		return _fail(_refusal(action))
	var f := Forecast.of(world, action)
	var me := f.after.player().id
	var out: Array[String] = ["harm to Miho: %d" % f.hurt_me()]
	var noticing := f.noticed.keys().map(func(i): return _whom(world, i))
	out.append("noticed by: " + (", ".join(noticing) if not noticing.is_empty() else "nobody"))
	for i: int in f.harm:
		if i != me:
			var dies := " (dies)" if f.deaths.has(i) else ""
			out.append("harm dealt: %s -%d%s" % [_whom(world, i), f.harm[i], dies])
	if f.after.depth != world.depth:
		out.append("Miho climbs to storey %d" % f.after.depth)
	return _ok("\n".join(out))


func _act(args: Dictionary) -> Dictionary:
	var action := _action(args)
	if action.has("error"):
		return _fail(action.error)
	if WALKS.has(action.t):
		return _walk(_next(action), WALKS[action.t])
	if not world.can(action):
		return _fail(_refusal(action))
	var before := world.clone()
	var events := world.act(action)
	return _report("", _lines(before, world, events))


# --- actions -----------------------------------------------------------------


## The action in `args` as a World action (move, wait, cast), a walk (explore,
## rest, stairs, travel with a goal), or {error} when the arguments are not valid.
func _action(args: Dictionary) -> Dictionary:
	var name: Variant = args.get("action")
	var out := {error = "action must be move, wait, cast, explore, rest, stairs or travel."}
	match name:
		"wait", "explore", "rest", "stairs":
			out = {t = StringName(name)}
		"move":
			var dir := Observation.dir_of(args.get("dir"))
			out = (
				{t = &"move", dir = dir}
				if dir != Vector2i.ZERO
				else {error = "move needs dir: n, ne, e, se, s, sw, w or nw."}
			)
		"cast":
			out = _cast(args.get("spells"))
		"travel":
			out = _travel(args.get("x"), args.get("y"))
	return out


func _travel(x: Variant, y: Variant) -> Dictionary:
	if not _whole(x) or not _whole(y):
		return {error = "travel needs integer x and y."}
	var goal := Vector2i(int(x), int(y))
	if not Grid.inside(goal):
		return {error = "(%d,%d) is outside the map." % [goal.x, goal.y]}
	return {t = &"travel", goal = goal}


## The step a walk takes next: an action, or empty when it is done.
func _next(walk: Dictionary) -> Callable:
	match walk.t:
		&"explore":
			return func(): return _move_to(Travel.explore_step(world, Travel.search(world)))
		&"rest":
			return func(): return {t = &"wait"} if world.tails < world.max_tails() else {}
		&"stairs":
			return func(): return _step_on(Travel.route(Travel.search(world), Travel.exit(world)))
	return func(): return _step_on(Travel.route(Travel.search(world), walk.goal))


func _cast(spells: Variant) -> Dictionary:
	if not spells is Array or spells.is_empty():
		return {error = "cast needs spells: a list of {cards, dir}."}
	var out := []
	for one: Variant in spells:
		var names: Variant = one.get("cards") if one is Dictionary else null
		var dir := Observation.dir_of(one.get("dir")) if one is Dictionary else Vector2i.ZERO
		if not names is Array or dir == Vector2i.ZERO:
			return {error = "Each spell needs cards (a list of names) and a dir."}
		var cards := []
		for n in names:
			var card := _card(n)
			if card == &"":
				return {error = "Unknown talisman: %s." % n}
			cards.append(card)
		out.append({cards = cards, dir = dir})
	return {t = &"cast", spells = out}


## A talisman by id (fox) or Korean name (여우불), or empty when there is none.
func _card(name: Variant) -> StringName:
	for c in Cards.ALL:
		if name == String(c) or name == Cards.NAME[c]:
			return c
	return &""


func _refusal(action: Dictionary) -> String:
	if world.outcome != &"":
		return "The game is over. Call new_game."
	if world.player().stunned > 0:
		return "Miho is stunned and cannot act."
	if action.t == &"move":
		return "Miho cannot step there: it is blocked, off the map, or she is rooted."
	return (
		"That cast is not allowed: each spell needs 1-4 different talismans Miho holds with fox or orb, "
		+ (
			"its own open direction, and all cards together cost at most the %d unspent tails."
			% world.tails
		)
	)


func _step_on(path: Array[Vector2i]) -> Dictionary:
	return _move_to(path[0] - world.player().pos) if not path.is_empty() else {}


func _move_to(dir: Vector2i) -> Dictionary:
	return {t = &"move", dir = dir} if dir != Vector2i.ZERO else {}


# --- walks -------------------------------------------------------------------


## Plays rounds of `next` (an action, or empty when done) by the stop rules of
## Main._journey, at most MAX_ROUNDS. `idle` is the refusal when it cannot take
## a first step.
func _walk(next: Callable, idle: String) -> Dictionary:
	var sighted := Travel.in_sight(world)
	var lines: Array[String] = []
	var rounds := 0
	var why := "done"
	while rounds < MAX_ROUNDS and world.outcome == &"":
		var action: Dictionary = next.call()
		if action.is_empty():
			break
		why = _hazard(action)
		if why != "":
			break
		var before := world.clone()
		var events := world.act(action)
		rounds += 1
		lines.append_array(_lines(before, world, events))
		why = "something happened, see the messages"
		if Travel.interrupted(before, world, events, sighted):
			break
		why = "done"
	if rounds == MAX_ROUNDS and why == "done":
		why = "reached the %d round limit" % MAX_ROUNDS
	if rounds == 0:
		return _fail(idle if why == "done" else "Not taken: " + why)
	return _report("rounds walked: %d, stopped: %s" % [rounds, why], lines)


## Why the walk must not take `action`, or empty.
func _hazard(action: Dictionary) -> String:
	var f := Forecast.of(world, action)
	if f.hurt_me() > 0:
		return "the next step would hurt Miho"
	if not f.noticed.is_empty():
		return "the next step would get Miho noticed"
	if not world.can(action):
		return "the next step is not allowed"
	if action.t == &"move" and Travel.near_fire(world, world.player().pos + action.dir):
		return "fire is next to the next step"
	return ""


# --- text --------------------------------------------------------------------


## The round's messages, each led by the round it happened in. Messages.of gives
## a String or a list of [text, Color] runs per line.
func _lines(before: World, after: World, events: Array) -> Array[String]:
	var out: Array[String] = []
	for line: Variant in Messages.of(before, after, events):
		var text: String = line if line is String else "".join(line.map(func(run): return run[0]))
		out.append("t%d: %s" % [after.round_no, text])
	return out


## An optional headline, the messages, then the observation.
func _report(head: String, lines: Array[String]) -> Dictionary:
	var out: Array[String] = []
	if head != "":
		out.append(head)
	out.append_array(lines)
	out.append(Observation.text(world))
	return _ok("\n".join(out))


## A creature as its name and tile, from the world it is in.
static func _whom(w: World, id: int) -> String:
	var a := w.actor(id)
	return "%s (%d,%d)" % [a.info().name, a.pos.x, a.pos.y] if a != null else "unknown"


static func _whole(v: Variant) -> bool:
	return (v is float or v is int) and v == floorf(v)
