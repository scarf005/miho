extends GutTest
## Marsh gas: fire on a tile of the cloud sets off all of it at once.

const AT := Vector2i(6, 8)
const WAIT := {t = &"wait"}


## An open hall walled at the edges, Miho at (4, 8), a cloud of marsh gas of
## `n` tiles in a row from AT.
func _world(n := 4) -> World:
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
	w.depth = 3
	w.rng.seed = 5
	for i in n:
		Gas.put(w, AT + Vector2i(i, 0), Gas.MARSH, 3)
	w.sense()
	return w


func _blasts(events: Array) -> Array:
	return events.filter(func(e): return e.t == &"blast")


func test_marsh_gas_does_not_block_sight_however_thick() -> void:
	var w := _world()
	Gas.put(w, AT, Gas.MARSH, Gas.MAX)
	assert_false(Gas.blocks(w, AT))


func test_fire_on_one_tile_of_the_cloud_clears_all_of_it_and_blasts_once() -> void:
	var w := _world()
	w.gas[AT + Vector2i(9, 0)] = Vector2i(Gas.MARSH, 3)
	Terrain.ignite(w, AT + Vector2i(1, 0))
	var blasts := _blasts(w.events)
	assert_eq(blasts.size(), 1)
	assert_eq(blasts[0].tiles.size(), 4, "the joined tiles, not the far one")
	for i in 4:
		assert_false(w.gas.has(AT + Vector2i(i, 0)))
	assert_true(w.gas.has(AT + Vector2i(9, 0)), "a cloud apart stays")


func test_everyone_in_the_cloud_is_hurt_and_alight_and_none_outside() -> void:
	var w := _world()
	var inside := FloorGen.spawn(w, &"jangseung", AT + Vector2i(3, 0))
	var outside := FloorGen.spawn(w, &"jangseung", AT + Vector2i(3, 2))
	Terrain.ignite(w, AT)
	assert_eq(inside.hp, inside.max_hp - Gas.BLAST)
	assert_gt(inside.ailments.alight, 0)
	assert_eq(outside.hp, outside.max_hp)
	assert_eq(outside.ailments.alight, 0)


func test_the_blast_is_loud_and_it_logs_and_sounds() -> void:
	var w := _world()
	Terrain.ignite(w, AT)
	var noises := w.events.filter(func(e): return e.t == &"noise" and e.word == "쾅")
	assert_eq(noises.size(), 1)
	assert_eq(noises[0].loud, Gas.BLAST_LOUD)
	var blast: Dictionary = _blasts(w.events)[0]
	assert_eq(Sfx.sound_of(blast), &"blast")
	var lines: Array[String] = []
	lines.assign(Messages.of(w, w, [blast]).map(Messages.plain))
	assert_eq(lines, ["늪 기체가 폭발했다"] as Array[String])


func test_other_gases_do_not_explode() -> void:
	var w := _world()
	Gas.put(w, AT - Vector2i(0, 3), Gas.FOG, 3)
	Terrain.ignite(w, AT - Vector2i(0, 3))
	assert_eq(_blasts(w.events), [])
	assert_true(w.gas.has(AT - Vector2i(0, 3)))


func test_a_burning_tile_beside_the_cloud_sets_it_off_in_the_round_the_gas_reaches_it() -> void:
	var w := _world(1)
	w.set_tile(AT, World.GRASS)
	w.gas.erase(AT)
	Terrain.ignite(w, AT)
	Gas.put(w, AT, Gas.MARSH, 3)
	var events := w.act(WAIT)
	assert_eq(_blasts(events).size(), 1)
	assert_false(w.gas.has(AT))


func test_the_hover_of_the_gas_keeps_the_blast_a_secret() -> void:
	var w := _world()
	var text := Info.plain(Info.terrain(w, AT))
	assert_string_contains(text, "늪 기체")
	assert_false(text.contains("폭발"), text)
	assert_false(text.contains("시야"), text)
