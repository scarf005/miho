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
	m.new_run(1)
	m.state = &"play"
	m.term.speed = 1000.0
	return m


func test_the_bar_sits_under_the_storey_flush_with_the_right_edge() -> void:
	var t: Term = _main().term
	t.fit(Vector2(1920, 1080), 0.0)
	assert_eq(NoiseMeter.at(t), Vector2(t.cols - NoiseMeter.width(), t.rows - 1))


## The bar never covers the queue or the spell's name at any zoom of the windows
## the game opens in, with the fewest talismans and with them all.
func test_the_bar_clears_the_queue_and_the_name_at_every_zoom() -> void:
	var m := _main()
	var t: Term = m.term
	for view in [Vector2(1280, 720), Vector2(1920, 1080)]:
		for zoom in Settings.ZOOMS:
			t.fit(view, zoom)
			for count in range(Cards.FORMS.size(), Cards.ALL.size() + 1):
				m.world.cards.assign(Cards.ALL.slice(0, count))
				var ctx := "%s zoom %s, %d talismans" % [view, zoom, count]
				var bar := NoiseMeter.at(t)
				assert_eq(bar.x + NoiseMeter.width(), float(t.cols), "on screen: " + ctx)
				if bar.y == t.rows - 1:
					assert_gte(bar.x, StatusBar.queue_x(t) + Spell.MAX_SLOTS, "queue: " + ctx)
				var name := StatusBar.title_at(t, "도깨비불")
				if name.y == bar.y:
					assert_lte(name.x + Term.text_cells("도깨비불"), bar.x, "name: " + ctx)


func test_the_bar_is_not_the_spell_name_to_the_mouse() -> void:
	var m := _main()
	m.term.fit(Vector2(1920, 1080), 0.0)
	m.picked.assign([Cards.ORB])
	var t: Term = m.term
	var on_bar := (NoiseMeter.at(t) + Vector2(1, 0.5)) * Term.CELL
	assert_eq(StatusBar.hand_at(t, on_bar), "")
	var name := StatusBar.title_at(t, Spell.make(m.picked).title())
	assert_eq(
		StatusBar.hand_at(t, (name + Vector2(0.25, 0.5)) * Term.CELL), Spell.make(m.picked).key()
	)


func test_the_bar_shows_a_creak_after_the_round_and_is_empty_after_a_quiet_one() -> void:
	var m := _main()
	m.world.actors = m.world.actors.filter(func(a): return a.faction == Actor.FOX)
	var me: Actor = m.world.player()
	m.world.set_tile(me.pos + Vector2i(1, 0), World.BOARD)
	await m.act(EAST)
	assert_eq(m.term.noise, Tiles.of(World.BOARD, "tread")[0])
	await m.act({t = &"wait"})
	assert_eq(m.term.noise, 0)
