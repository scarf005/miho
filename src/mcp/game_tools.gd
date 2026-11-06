class_name GameTools
extends RefCounted
## The game as MCP tools. No MCP library exists for GDScript, and the protocol
## surface needed is small: initialize, notifications/initialized, ping,
## tools/list and tools/call, as JSON-RPC 2.0 over Godot's JSON class. `handle`
## takes one parsed request and returns the response, or null for a
## notification, so it runs without stdio (server.gd is the stdio loop).
##
## The agent plays on what Miho knows only (Observation). Walks of many rounds
## stop by Travel.hazard (forecast harm, being noticed, fire next to the step) and
## Travel.interrupted, as a walk in the game does (Journey).

const PROTOCOL := "2025-06-18"
const MAX_ROUNDS := 200
## What a walk says for each Travel.hazard.
const HAZARDS := {
	&"hurt": "the next step would hurt Miho",
	&"drop": "the next step would drop Miho to a lower storey",
	&"noticed": "the next step would get Miho noticed",
	&"blocked": "the next step is not allowed",
	&"fire": "fire is next to the next step",
}
## The tail costs of a spell of 1 to MAX_SLOTS cards (Spell.COST), and the square
## round where a compound projectile ends.
const COSTS := "%d, %d, %d, %d, %d" % Spell.COST
const SQUARE := "%dx%d" % [2 * Grid.NEAR + 1, 2 * Grid.NEAR + 1]
const INSTRUCTIONS := (
	(
		"Play Miho, a fox climbing a pavilion of %d storeys to drink the elixir on the top one. "
		% World.FLOORS
	)
	+ "She grows a tail on every storey, up to %d. " % World.FLOORS
	+ "Call new_game, then act. Every result shows the map and what Miho knows. "
	+ (
		"A spell is a queue of talismans, 1 to %d cards costing %s tails: "
		% [Spell.MAX_SLOTS, COSTS]
	)
	+ "fox or orb hurl projectiles, "
	+ "elements alone spray at once; more copies make it stronger. "
	+ "Game text is Korean. Use forecast to check a step or a spell before taking it, "
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
const KINDS := {
	"type": "string",
	"enum": ["shadow", "guise", "talon", "cloak", "flame", "raise", "vault"],
	"description": "dispel: the buff on Miho to drop (vault: the next fall harms nothing)."
}
const SPELLS := {
	type = "array",
	description =
	(
		"Spells hurled this round, each along its own direction. cards is the queue in order: "
		+ "talisman names (fox, orb, fire, water, wood, metal, earth) or their Korean "
		+ "names, repeats allowed. A repeat stacks; an element joins the first different element "
		+ "queued as one compound slot. Water, wood and fire in any order make one leap slot "
		+ (
			"(%s, %d cards). A spell fills at most %d slots. The leap slot only leads a spell: "
			% [Cards.NAME[Cards.VAULT], Cards.TRIPLE, Spell.MAX_SLOTS]
		)
		+ (
			"Miho leaps over sky, ponds and creatures onto the farthest free tile within %d tiles "
			% (Spell.LEAP_BASE + 1)
		)
		+ (
			"plus %d per wood card right behind it, then casts the rest there. The leap slot last "
			% Spell.LEAP_PER_WOOD
		)
		+ "behind fox or orb swaps: Miho goes where the projectile ends, trading places with a "
		+ "creature it strikes. With fox or orb it "
		+ "hurls projectiles; elements alone spray this round, shaped by the first slot "
		+ "(fire fan, water jet, metal gun, earth quake ring, wood vines; a compound its own "
		+ (
			"shape and effect, which a projectile carries to the %s where it ends). Metal makes "
			% SQUARE
		)
		+ "fox a bullet that goes through creatures and orb a cannonball; wood on an orb grows a "
		+ (
			"wooden wall. A wisp turns %d degrees a tile per fox and flies at most %d tiles; "
			% [Spell.WISP_TURN, Spell.RANGE]
		)
		+ (
			"where it stops it hovers %d rounds, and one of fox alone yelps every %d rounds, "
			% [Spell.WISP_LIFE, Lure.EVERY]
		)
		+ (
			"an alarm heaven searches. dir self casts it on Miho: only fox, water and wood (%s, "
			% Guise.NAME[Guise.SHADOW]
		)
		+ (
			"a dark wisp on her), wood, earth and wood (%s, the form of the last creature felled, "
			% Guise.NAME[Guise.GUISE]
		)
		+ (
			"which creatures not hunting her do not know), fox, wood and earth (%s: a creature "
			% Guise.NAME[Guise.CLOAK]
		)
		+ (
			"knows her only from beside her, hunters too), fox, fire and wood (%s: she is a fire "
			% Guise.NAME[Guise.FLAME]
		)
		+ (
			"creature, no harm from fire or metal and her fire harms what is immune to it %d at most) "
			% Guise.FLAME_THROUGH
		)
		+ "or the 3 element "
		+ (
			"compound %s (her claws harm more), which goes on her whatever dir. They last "
			% Guise.NAME[Guise.TALON]
		)
		+ "until she drops them "
		+ "with the action dispel. "
		+ "%s, %s, %s, %s, %s in any order, whatever dir, " % Guise.RECIPE[Guise.RAISE]
		+ "is %s: a body she sees rises as an " % Guise.NAME[Guise.RAISE]
		+ (
			"ally on its tile or next to it, a %s, or a %s from a creature with as much health; "
			% [Bestiary.KINDS[Raise.WEAK]["name"], Bestiary.KINDS[Raise.STRONG]["name"]]
		)
		+ "it ends when she leaves the storey, and what rose stays there. "
		+ "Fox, earth, fire and wood in any order make "
		+ ("%s: a copy of her steps out onto the free tile next to " % Cards.NAME[Cards.BUNSIN])
		+ (
			"her along dir and fights on its own, with %d tails of its own that grow back, spent "
			% Bunsin.TAILS
		)
		+ (
			"on the last spell she threw that costs at most %d; it claws without one. At most %d copies "
			% [Bunsin.TAILS, Bunsin.MOST]
		)
		+ "stand on a storey, and a cast that makes one more sends the oldest away. "
		+ "The forecast lists every number. "
		+ (
			"A spell of 1 to %d cards costs %s tails, and each card past %d costs %d more; "
			% [Spell.MAX_SLOTS, COSTS, Spell.MAX_SLOTS, Spell.COST_EXTRA]
		)
		+ "all spells together cost at most the unspent tails."
	),
	items =
	{
		type = "object",
		properties =
		{
			cards = {type = "array", items = {type = "string"}},
			dir =
			{
				"type": "string",
				"enum": ["n", "ne", "e", "se", "s", "sw", "w", "nw", "self"],
				"description": "Direction, or self."
			},
		},
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
			"Take an action. move steps in dir, or claws a creature there, or knocks a lantern or window, "
			+ "or slides a closed door open (Miho stays put); close shuts the open door in dir; "
			+ "wait passes a round; cast hurls spells; drink answers the question that stepping on "
			+ "the elixir asks, and nothing else is allowed until then. "
			+ "explore, rest (until the tails regrow), "
			+ (
				"stairs (to the seen stairs) and travel (to x,y) walk many rounds, up to %d, "
				% MAX_ROUNDS
			)
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
					"enum":
					[
						"move",
						"close",
						"wait",
						"cast",
						"dispel",
						"drink",
						"explore",
						"rest",
						"stairs",
						"travel"
					],
				},
				dir = DIRS,
				spells = SPELLS,
				kind = KINDS,
				yes =
				{type = "boolean", description = "drink: true drinks the elixir, false keeps it."},
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
				action = {"type": "string", "enum": ["move", "close", "wait", "cast", "dispel"]},
				dir = DIRS,
				spells = SPELLS,
				kind = KINDS,
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
	if not action.has("t") or not [&"move", &"close", &"wait", &"cast", &"dispel"].has(action.t):
		return _fail(action.get("error", "forecast takes move, close, wait, cast or dispel."))
	if not world.can(action):
		return _fail(_refusal(action))
	var f := Forecast.of(world, action)
	var me := f.after.player().id
	var out: Array[String] = []
	for one: Dictionary in action.get("spells", []):
		out.append(
			"spell: " + Info.plain(SpellInfo.spell(Spell.make(one.cards))).replace("\n", "; ")
		)
	for e in f.sprays:
		var tiles: Array = e.tiles.map(func(p): return "(%d,%d)" % [p.x, p.y])
		out.append("spray covers: " + (" ".join(tiles) if not tiles.is_empty() else "nothing"))
	var grown: Array = f.sprouts.map(func(p): return "(%d,%d)" % [p.x, p.y])
	if not grown.is_empty():
		out.append("wooden wall grows at: " + " ".join(grown))
	for p: Vector2i in f.grounds:
		out.append("(%d,%d) turns to %s" % [p.x, p.y, Tiles.of(f.grounds[p], "name")])
	var heated: Array = f.heated.map(func(p): return "(%d,%d)" % [p.x, p.y])
	if not heated.is_empty():
		out.append("hot ground at: " + " ".join(heated))
	out.append("harm to Miho: %d" % f.hurt_me())
	var noticing := f.noticed.keys().map(func(i): return _whom(world, i))
	out.append("noticed by: " + (", ".join(noticing) if not noticing.is_empty() else "nobody"))
	for i: int in f.harm:
		if i != me:
			var dies := " (dies)" if f.deaths.has(i) else ""
			out.append("harm dealt: %s -%d%s" % [_whom(world, i), f.harm[i], dies])
	for p: Vector2i in f.allies:
		out.append("ally appears: (%d,%d)" % [p.x, p.y])
	if f.after.depth != world.depth:
		var way := "falls" if f.drops_me() else "climbs"
		out.append("Miho %s to storey %d" % [way, f.after.depth])
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
	var out := {
		error =
		"action must be move, close, wait, cast, dispel, drink, explore, rest, stairs or travel."
	}
	match name:
		"wait", "explore", "rest", "stairs":
			out = {t = StringName(name)}
		"move", "close":
			var dir := Observation.dir_of(args.get("dir"))
			out = (
				{t = StringName(name), dir = dir}
				if dir != Vector2i.ZERO
				else {error = "%s needs dir: n, ne, e, se, s, sw, w or nw." % name}
			)
		"cast":
			out = _cast(args.get("spells"))
		"dispel":
			out = {t = &"dispel", kind = StringName(str(args.get("kind", "")))}
		"drink":
			out = (
				{t = &"drink", yes = args.yes}
				if args.get("yes") is bool
				else {error = "drink needs yes: true or false."}
			)
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
		var aim: Variant = one.get("dir") if one is Dictionary else null
		var dir := Observation.dir_of(aim)
		if not names is Array or (dir == Vector2i.ZERO and aim != "self"):
			return {error = "Each spell needs cards (a list of names) and a dir, or self."}
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
	if world.elixir_asked or action.t == &"drink":
		return (
			"The elixir waits for an answer: only drink, with yes, is allowed."
			if world.elixir_asked
			else "There is no question about the elixir to answer."
		)
	if world.player().ailments.stunned > 0:
		return "Miho is stunned and cannot act."
	if action.t == &"move":
		return "Miho cannot step there: it is blocked, off the map, or she is rooted."
	if action.t == &"close":
		return "There is no open door with nothing in it in that direction."
	return (
		"That cast is not allowed: each spell needs talismans Miho holds, "
		+ ("filling at most %d slots, " % Spell.MAX_SLOTS)
		+ (
			"its own open direction (self only for fox with water, or wood with earth "
			+ "once a creature has fallen), "
			+ "and all spells together cost at most the %d unspent tails." % world.tails
		)
	)


func _step_on(path: Array[Vector2i]) -> Dictionary:
	return _move_to(path[0] - world.player().pos) if not path.is_empty() else {}


func _move_to(dir: Vector2i) -> Dictionary:
	return {t = &"move", dir = dir} if dir != Vector2i.ZERO else {}


# --- walks -------------------------------------------------------------------


## Plays rounds of `next` (an action, or empty when done) by the stop rule of
## Travel.hazard, at most MAX_ROUNDS. `idle` is the refusal when it cannot take
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
		why = HAZARDS.get(Travel.hazard(world, action, Forecast.of(world, action)), "")
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
