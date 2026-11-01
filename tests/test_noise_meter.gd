extends GutTest
## The noise bar: the loudest noise Miho saw in a round, in DCSS's four bands.

const SEEN := Vector2i(6, 8)
const HIDDEN := Vector2i(20, 8)
const EAST := {t = &"move", dir = Vector2i(1, 0)}
## A noise of each band, from the game's own sounds.
const BANDS := [
	[World.KNOCK, 1],
	[NoiseMeter.NEAR, 1],
	[World.THUD, 2],
	[NoiseMeter.FAR, 3],
	[Drums.LOUD, 4],
]


func _vis() -> PackedByteArray:
	var vis := PackedByteArray()
	vis.resize(Grid.W * Grid.H)
	vis[Grid.index(SEEN)] = 1
	return vis


func _noise(at: Vector2i, loud: int) -> Dictionary:
	return {t = &"noise", at = at, word = "쿵", loud = loud, heard = true}


func test_no_noise_is_level_0_and_band_0() -> void:
	assert_eq(NoiseMeter.level(_vis(), []), 0)
	assert_eq(NoiseMeter.band(0), 0)


func test_a_seen_noise_of_each_band_is_that_band() -> void:
	for pair in BANDS:
		var loud: int = NoiseMeter.level(_vis(), [_noise(SEEN, pair[0])])
		assert_eq(loud, pair[0])
		assert_eq(NoiseMeter.band(loud), pair[1], "%d tiles" % pair[0])


func test_the_bands_follow_the_loudest_sounds_of_the_game() -> void:
	assert_lt(Terrain.SLIDE, NoiseMeter.NEAR, "a sliding door stays in sight")
	assert_lt(Bestiary.info(&"dokkaebi").shout.loud, NoiseMeter.NEAR + 1, "a shout in sight")
	assert_eq(NoiseMeter.band(Spray.GUN_LOUD), 2, "a gunshot")
	assert_eq(NoiseMeter.band(Elements.CANNON_LOUD), 3, "a cannon")
	assert_eq(NoiseMeter.band(Drums.LOUD), 4, "a drum")


func test_a_noise_out_of_sight_does_not_count() -> void:
	assert_eq(NoiseMeter.level(_vis(), [_noise(HIDDEN, Drums.LOUD)]), 0)


func test_the_loudest_of_several_wins() -> void:
	var events := [_noise(SEEN, 3), _noise(HIDDEN, 40), _noise(SEEN, World.THUD), _noise(SEEN, 4)]
	assert_eq(NoiseMeter.level(_vis(), events), World.THUD)


func test_what_is_not_a_noise_does_not_count() -> void:
	var events := [{t = &"shout", at = SEEN, word = "낄낄", loud = 6}]
	assert_eq(NoiseMeter.level(_vis(), events), 0)


func test_the_loudest_band_makes_the_bar_one_segment_longer() -> void:
	assert_eq(NoiseMeter.FILLED[NoiseMeter.band(Drums.LOUD)], NoiseMeter.BAR_CELLS + 1)
	assert_eq(NoiseMeter.FILLED[NoiseMeter.band(Elements.CANNON_LOUD)], NoiseMeter.BAR_CELLS)


func _main() -> Node:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(1)
	m.state = &"play"
	m.term.speed = 1000.0
	return m


func test_the_bar_shows_a_creak_after_the_round_and_is_empty_after_a_quiet_one() -> void:
	var m := _main()
	m.world.actors = m.world.actors.filter(func(a): return a.faction == Actor.FOX)
	var me: Actor = m.world.player()
	m.world.set_tile(me.pos + Vector2i(1, 0), World.BOARD)
	await m._act(EAST)
	assert_eq(m.term.noise, Tiles.of(World.BOARD, "tread")[0])
	await m._act({t = &"wait"})
	assert_eq(m.term.noise, 0)
