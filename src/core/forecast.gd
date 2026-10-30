class_name Forecast
extends RefCounted
## Reads one previewed round into drawable facts: the tiles each projectile
## crosses, what it strikes, how much harm every creature takes, and who
## notices Miho. The preview runs on what Miho knows (World.known_clone), so
## creatures she cannot see take no part in it.

var after: World
var events: Array[Dictionary] = []
## shot id -> {faction, spell, tiles: Array[Vector2i], dir, live}
var paths := {}
## actor id -> total damage this round
var harm := {}
## actor id -> true when it dies this round
var deaths := {}
## actor id -> true when it starts hunting Miho this round
var noticed := {}


static func of(world: World, action: Dictionary) -> Forecast:
	var f := Forecast.new()
	f.after = world.known_clone()
	for s in f.after.shots:
		f.paths[s.id] = {
			faction = s.faction, spell = s.spell, tiles = [s.pos], dir = s.dir, live = true
		}
	f.events = f.after.act(action)
	for e in f.events:
		match e.t:
			&"spawn":
				f.paths[e.shot] = {
					faction = e.faction,
					spell = Spell.make(e.cards),
					tiles = [e.at],
					dir = Vector2i.ZERO,
					live = true
				}
			&"fly":
				if f.paths.has(e.shot):
					f.paths[e.shot].tiles.append(e.to)
			&"hurt":
				f.harm[e.id] = f.harm.get(e.id, 0) + e.n
			&"die":
				f.deaths[e.id] = true
			&"notice":
				f.noticed[e.id] = true
	for id in f.paths:
		var s := f.after_shot(id)
		f.paths[id].live = s != null
		if s != null:
			f.paths[id].dir = s.dir
	return f


func after_shot(id: int) -> Shot:
	for s in after.shots:
		if s.id == id:
			return s
	return null


## Harm Miho takes this round.
func hurt_me() -> int:
	return harm.get(after.player().id, 0)


## Tiles a projectile would cross from `from` heading `dir` until a wall or the edge.
static func ray(world: World, from: Vector2i, dir: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if dir == Vector2i.ZERO:
		return out
	var p := from + dir
	while world.open_floor(p):
		out.append(p)
		p += dir
	return out
