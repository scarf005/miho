class_name Journey
extends RefCounted
## Walks of many rounds in the game `m` (main.gd): to the stairs (>), exploring (o), resting
## until the tails regrow (z) or to a far tile, by the shortest ways around the travel
## exclusions (Exclusions) and where creatures were last seen (Sightings).

## How much faster rounds play while walking many rounds.
const WALK_SPEED := 3.0
## Why exploring or resting does not start.
const WATCHED := {
	&"explore": "깨어 있는 적이 보여서 탐험할 수 없다",
	&"rest": "깨어 있는 적이 보여서 쉴 수 없다",
}

var m: Node
## A walk is under way, and a key or click asked it to stop.
var walking := false
var halt := false
## Shortest walks from Miho over what she knows, around the travel exclusions
## and where creatures were last seen (Travel.search, Sightings), and the tiles
## the exclusions cover.
var routes := {}
var excluded := Exclusions.new()
var sightings := Sightings.new()
var zone := {}


func _init(of: Node) -> void:
	m = of


## Plays `next` (an action, or empty when done) round after round. Stops before a
## step whose forecast shows Travel.hazard, and after a round in which something
## Miho should react to happened (Travel.interrupted), or when a key or click asks.
## `why` is said when it cannot take a first step.
func go(next: Callable, why := "") -> void:
	m.casting.clear()
	var sighted := Travel.in_sight(m.world)
	var rounds := 0
	walking = true
	halt = false
	m.term.speed = m.settings.speed * WALK_SPEED
	while not halt and m.state == &"play":
		var action: Dictionary = next.call()
		if action.is_empty():
			if rounds == 0 and why != "":
				m.say(why)
			break
		var f: Forecast = m.ahead.get(action.get("dir", Vector2i.ZERO))
		if f == null or Travel.hazard(m.world, action, f) != &"":
			break
		var before: World = m.world.clone()
		var events: Array = await m.act(action)
		rounds += 1
		if Travel.interrupted(before, m.world, events, sighted):
			break
	walking = false
	m.term.speed = m.settings.speed
	if rounds == 0:
		m.sfx.play(&"click")


## Walks to the stairs.
func to_stairs() -> void:
	go(_to_exit, walled_in(Travel.exit(m.world), "아직 계단을 찾지 못했다"))


## Walks to `tile`.
func to_tile(tile: Vector2i) -> void:
	go(func(): return _step_on(path_to(tile)), walled_in(tile, ""))


## Explores, unless a creature in sight keeps it from starting.
func explore() -> void:
	if not _watched(&"explore"):
		go(exploring, "" if explore_walled() else "더 탐험할 곳이 없다")


## Rests until the tails regrow, unless a creature in sight keeps it from starting.
func rest() -> void:
	if not _watched(&"rest"):
		go(_resting, "꼬리가 이미 다 자랐다")


## Works out the walks again from where Miho stands.
func plan() -> void:
	var world: World = m.world
	zone = excluded.tiles(world)
	sightings.update(world)
	routes = Travel.search(world, excluded.tiles(world, world.player().pos).merged(sightings.at))


## The shortest walk to `tile`: around the exclusions, unless `tile` is in one,
## which Miho may walk into when told to.
func path_to(tile: Vector2i) -> Array[Vector2i]:
	return Travel.route(Travel.search(m.world, sightings.at) if zone.has(tile) else routes, tile)


## What is said when the way to `goal` is shut only by the exclusions, else `otherwise`.
func walled_in(goal: Vector2i, otherwise: String) -> String:
	var shut := (
		Grid.inside(goal)
		and Travel.route(routes, goal).is_empty()
		and not Travel.route(Travel.search(m.world, sightings.at), goal).is_empty()
	)
	return "위험구역 너머로는 갈 수 없다" if shut else otherwise


## Whether nothing is left to explore only because of the exclusions.
func explore_walled() -> bool:
	return (
		not excluded.is_empty()
		and Travel.explore_step(m.world, routes) == Vector2i.ZERO
		and Travel.explore_step(m.world, Travel.search(m.world, sightings.at)) != Vector2i.ZERO
	)


## The exclusions changed: keep them in the save and work out the walks again.
func zones_changed() -> void:
	m.run.exclusions = excluded.zones.duplicate()
	m.run.write()
	m.forecast()


## A step towards the nearest unexplored ground, after resting until the tails
## have all regrown (DCSS explore_auto_rest).
func exploring() -> Dictionary:
	var world: World = m.world
	var d := Travel.explore_step(world, routes)
	if d == Vector2i.ZERO:
		if explore_walled():
			m.say("위험구역 너머는 탐험할 수 없다")
		return {}
	return _resting() if world.tails < world.max_tails() else {t = &"move", dir = d}


func _resting() -> Dictionary:
	return {t = &"wait"} if m.world.tails < m.world.max_tails() else {}


func _to_exit() -> Dictionary:
	return _step_on(Travel.route(routes, Travel.exit(m.world)))


func _step_on(path: Array[Vector2i]) -> Dictionary:
	return {t = &"move", dir = path[0] - m.world.player().pos} if not path.is_empty() else {}


## Whether a creature in sight keeps the walk `kind` from starting, which is said.
func _watched(kind: StringName) -> bool:
	if not Travel.watched(m.world):
		return false
	m.say(WATCHED[kind])
	m.sfx.play(&"click")
	return true
