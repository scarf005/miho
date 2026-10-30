extends GutTest

const ORB := Cards.ORB
const E := Vector2i(1, 0)
const WAIT := {t = &"wait"}


## An open hall walled at the edges, with no light, Miho at (4, 8).
func _world() -> World:
	var w := World.new()
	w.tiles.resize(Grid.W * Grid.H)
	w.tiles.fill(World.WALL)
	for y in range(1, Grid.H - 1):
		for x in range(1, Grid.W - 1):
			w.tiles[Grid.index(Vector2i(x, y))] = World.FLOOR
	var me := Actor.new()
	me.id = w.new_id()
	me.kind = &"miho"
	me.faction = Actor.FOX
	me.hp = 3
	me.max_hp = 3
	me.pos = Vector2i(4, 8)
	w.actors.append(me)
	return w


func test_a_highlight_replays_exactly_and_holds_the_kill() -> void:
	var w := _world()
	FloorGen.spawn(w, &"jangseung", Vector2i(9, 8)).hp = 1
	var reel := Highlight.new()
	var actions: Array[Dictionary] = [
		WAIT, WAIT, WAIT, WAIT, {t = &"cast", spells = [{cards = [ORB], dir = E}]}, WAIT, WAIT, WAIT
	]
	for a in actions:
		var before := w.clone()
		reel.record(before, a, w.act(a))
	var window := reel.best()
	var kill := reel.rounds.map(func(r): return r.score).find(3)
	assert_gt(kill, -1, "the kill scored")
	assert_between(kill, window.from, window.to)
	assert_gte(window.to - window.from + 1, Highlight.MIN_ROUNDS)
	var clip := reel.clip(window)
	var replay: World = clip.world
	for a in clip.actions:
		replay.act(a)
	var next: World = reel.rounds[window.to + 1].world if window.to + 1 < reel.rounds.size() else w
	assert_eq(replay.player().pos, next.player().pos)
	assert_eq(replay.actors.size(), next.actors.size())
	assert_eq(replay.rng.state, next.rng.state)


func test_a_quiet_storey_replays_its_last_rounds() -> void:
	var w := _world()
	var reel := Highlight.new()
	for i in 5:
		var before := w.clone()
		reel.record(before, WAIT, w.act(WAIT))
	assert_eq(reel.best(), {from = 2, to = 4})
