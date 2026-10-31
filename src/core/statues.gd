class_name Statues
extends RefCounted
## 석상 (World.STATUE): a stone 장승 that cannot be walked through. When Miho
## stands within REACH (Chebyshev) of one at the end of a round, it wakes: the
## tile is floor and a 장승 stands there, hunting her.

const KIND := &"jangseung"
const REACH := 2


static func tick(w: World) -> void:
	var me := w.player()
	if w.outcome != &"" or me == null:
		return
	var i := w.tiles.find(World.STATUE)
	while i >= 0:
		var at := Grid.at(i)
		if Grid.cheb(at, me.pos) <= REACH:
			wake(w, at, me.pos)
		i = w.tiles.find(World.STATUE, i + 1)


## The statue at `at` wakes, hunting Miho at `prey`.
static func wake(w: World, at: Vector2i, prey: Vector2i) -> void:
	w.set_tile(at, World.FLOOR)
	var a := FloorGen.spawn(w, KIND, at)
	a.alert = Actor.HUNT
	a.target = prey
	a.cooldown = Bestiary.info(KIND).cd
	w.emit({t = &"wake", id = a.id, at = at})
