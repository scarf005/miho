extends GutTest
## The gas layer: how it spreads and thins, what stops it, what it does to sight
## and to whoever stands in it, and how the log and the hover tell it.

const ME := Vector2i(4, 8)
const MID := Vector2i(20, 14)


## An open hall walled all round, Miho at ME.
func _hall() -> World:
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
	me.hp = 5
	me.max_hp = 5
	me.pos = ME
	w.actors.append(me)
	w.rng.seed = 5
	w.sense()
	return w


func _total(w: World) -> int:
	var n := 0
	for p: Vector2i in w.gas:
		n += w.gas[p].y
	return n


## Lays `amount` of `kind` on a block of tiles, `half` tiles out from `at`.
func _block(w: World, at: Vector2i, half: int, kind: int, amount: int) -> void:
	for y in range(at.y - half, at.y + half + 1):
		for x in range(at.x - half, at.x + half + 1):
			Gas.put(w, Vector2i(x, y), kind, amount)


# --- the table -----------------------------------------------------------------


func test_fog_thins_slowly_steam_and_smoke_quickly_and_all_of_them_block_sight() -> void:
	assert_eq(Gas.of(Gas.FOG, "decay"), 20)
	assert_eq(Gas.of(Gas.STEAM, "decay"), 50)
	assert_eq(Gas.of(Gas.SMOKE, "decay"), 50)
	assert_eq([Gas.of(Gas.FOG, "harm"), Gas.of(Gas.SMOKE, "harm")], [0, 0])
	assert_eq(Gas.of(Gas.STEAM, "harm"), 1)
	assert_true(Gas.of(Gas.STEAM, "wets"))
	assert_false(Gas.of(Gas.FOG, "wets"))
	for kind: int in Gas.ROWS:
		assert_ne(Gas.of(kind, "name"), "")


func test_only_walls_closed_doors_windows_pillars_wooden_walls_sky_and_seals_stop_gas() -> void:
	var stops := [
		World.WALL,
		World.WALL_CRACKED,
		World.DOOR,
		World.WINDOW,
		World.PILLAR,
		World.WOOD_WALL,
		World.SKY,
		World.SEAL,
	]
	for t in 256:
		assert_eq(Tiles.gas[t] == 0, stops.has(t), "gas on %d" % t)


# --- laying --------------------------------------------------------------------


func test_gas_adds_up_to_the_most_and_the_greater_of_two_kinds_stays() -> void:
	var w := _hall()
	Gas.put(w, MID, Gas.FOG, 4)
	Gas.put(w, MID, Gas.FOG, 4)
	assert_eq(Gas.at(w, MID), Vector2i(Gas.FOG, 8))
	Gas.put(w, MID, Gas.FOG, 4)
	assert_eq(Gas.at(w, MID), Vector2i(Gas.FOG, Gas.MAX), "capped")
	Gas.put(w, MID, Gas.SMOKE, 5)
	assert_eq(Gas.at(w, MID), Vector2i(Gas.FOG, Gas.MAX), "less than what lies there")
	Gas.put(w, MID, Gas.SMOKE, Gas.MAX)
	assert_eq(Gas.at(w, MID), Vector2i(Gas.SMOKE, Gas.MAX), "as much takes over")


func test_gas_is_not_laid_in_walls_or_in_nothing() -> void:
	var w := _hall()
	Gas.put(w, Vector2i(0, 0), Gas.FOG, 5)
	Gas.put(w, Vector2i(-3, 4), Gas.FOG, 5)
	Gas.put(w, MID, Gas.FOG, 0)
	assert_eq(w.gas, {})


func test_adding_gas_tells_of_a_new_cloud_once_and_putting_it_tells_nothing() -> void:
	var w := _hall()
	Gas.put(w, MID, Gas.FOG, 2)
	assert_eq(w.events, [] as Array[Dictionary])
	Gas.add(w, MID + Vector2i.RIGHT, Gas.STEAM, 2)
	Gas.add(w, MID + Vector2i.RIGHT, Gas.STEAM, 2)
	Gas.add(w, MID, Gas.STEAM, 2)
	assert_eq(
		w.events, [{t = &"gas", at = MID + Vector2i.RIGHT, kind = Gas.STEAM}] as Array[Dictionary]
	)


# --- spreading and thinning ----------------------------------------------------


func test_a_full_tile_spreads_to_an_even_one_in_each_of_nine_tiles() -> void:
	var w := _hall()
	Gas.put(w, MID, Gas.FOG, 9)
	Gas.spread(w, false)
	assert_eq(w.gas.size(), 9)
	for p: Vector2i in w.gas:
		assert_eq(w.gas[p], Vector2i(Gas.FOG, 1), str(p))
		assert_eq(Grid.cheb(p, MID) <= 1, true)


func test_spreading_keeps_the_total_on_average_and_the_same_seed_spreads_the_same() -> void:
	var sums := 0
	var first := {}
	for s in 200:
		var w := _hall()
		w.rng.seed = s
		Gas.put(w, MID, Gas.STEAM, 5)
		Gas.spread(w, false)
		sums += _total(w)
		if s == 3:
			first = w.gas
	assert_between(sums / 200.0, 4.6, 5.4, "5 spread over nine tiles, the odd ones by chance")
	var again := _hall()
	again.rng.seed = 3
	Gas.put(again, MID, Gas.STEAM, 5)
	Gas.spread(again, false)
	assert_eq(again.gas, first)


func test_a_tile_takes_the_kind_of_the_strongest_gas_around_it() -> void:
	var w := _hall()
	Gas.put(w, MID, Gas.SMOKE, 2)
	Gas.put(w, MID + Vector2i.RIGHT, Gas.STEAM, 8)
	Gas.spread(w, false)
	assert_eq(w.gas[MID].x, Gas.STEAM, "smoke 2 beside steam 8")
	assert_eq(w.gas[MID + Vector2i.RIGHT * 2].x, Gas.STEAM, "none before")
	assert_eq(w.gas[MID + Vector2i.RIGHT].x, Gas.STEAM)


func test_thinning_takes_one_from_a_fifth_of_fog_and_half_of_steam_and_smoke() -> void:
	for pair in [[Gas.FOG, 20], [Gas.STEAM, 50], [Gas.SMOKE, 50]]:
		var thinned := 0
		for s in 40:
			var w := _hall()
			w.rng.seed = s
			_block(w, MID, 4, pair[0], 5)
			Gas.spread(w)
			for y in range(MID.y - 2, MID.y + 3):
				for x in range(MID.x - 2, MID.x + 3):
					var amount := Gas.at(w, Vector2i(x, y)).y
					assert_between(amount, 4, 5, "an even block loses at most 1")
					thinned += 1 if amount == 4 else 0
		assert_between(thinned / (25.0 * 40), pair[1] / 100.0 - 0.05, pair[1] / 100.0 + 0.05)


func test_the_last_unit_thins_away_and_the_tile_is_clear() -> void:
	var gone := 0
	for s in 40:
		var w := _hall()
		w.rng.seed = s
		_block(w, MID, 1, Gas.STEAM, 1)
		Gas.spread(w)
		assert_between(Gas.at(w, MID).y, 0, 1)
		gone += 1 if not w.gas.has(MID) else 0
	assert_between(gone, 10, 30, "about half of 40 thin away")


func test_a_cloud_in_the_open_dies_away() -> void:
	for kind: int in Gas.ROWS:
		var w := _hall()
		_block(w, MID, 1, kind, Gas.MAX)
		var rounds := 0
		while not w.gas.is_empty() and rounds < 200:
			Gas.tick(w)
			rounds += 1
		assert_true(w.gas.is_empty(), "kind %d" % kind)
		assert_gt(rounds, 3)


func test_fog_lasts_longer_than_steam() -> void:
	var lasts := {}
	for kind in [Gas.FOG, Gas.STEAM]:
		var total := 0
		for s in 10:
			var w := _hall()
			w.rng.seed = s
			_block(w, MID, 2, kind, Gas.MAX)
			while not w.gas.is_empty():
				Gas.tick(w)
				total += 1
		lasts[kind] = total
	assert_gt(float(lasts[Gas.FOG]), lasts[Gas.STEAM] * 1.5)


func test_gas_stops_at_walls_and_closed_doors_and_a_door_closing_on_it_clears_it() -> void:
	var w := _hall()
	for y in range(1, Grid.H - 1):
		w.tiles[Grid.index(Vector2i(MID.x + 3, y))] = World.WALL
	w.tiles[Grid.index(Vector2i(MID.x + 3, MID.y))] = World.DOOR_OPEN
	_block(w, MID, 2, Gas.FOG, Gas.MAX)
	for i in 8:
		Gas.spread(w, false)
	var past := w.gas.keys().filter(func(p): return p.x > MID.x + 3)
	assert_gt(past.size(), 0, "through the open door")
	for p: Vector2i in w.gas:
		assert_ne(w.tile(p), World.WALL, str(p))
	w.set_tile(Vector2i(MID.x + 3, MID.y), World.DOOR)
	Gas.spread(w)
	assert_false(w.gas.has(Vector2i(MID.x + 3, MID.y)), "none in a closed door")
	for p: Vector2i in w.gas:
		assert_true(Gas.holds(w, p))


# --- sight ---------------------------------------------------------------------


func test_gas_of_the_threshold_blocks_sight_and_thinner_gas_does_not() -> void:
	var w := _hall()
	var between := Vector2i(7, 8)
	var beyond := Vector2i(10, 8)
	assert_eq(w.fov(ME)[Grid.index(beyond)], 1)
	Gas.put(w, between, Gas.FOG, Gas.OPAQUE - 1)
	assert_false(w.opaque(between))
	assert_eq(w.fov(ME)[Grid.index(beyond)], 1, "thin gas lets sight through")
	Gas.put(w, between, Gas.FOG, 1)
	assert_true(w.opaque(between))
	assert_eq(w.opaque_mask()[Grid.index(between)], 1)
	assert_eq(w.fov(ME)[Grid.index(beyond)], 0, "thick gas blocks it")
	assert_eq(w.fov(ME)[Grid.index(between)], 1, "its near face is seen, like a wall's")


func test_every_kind_of_gas_blocks_sight_at_the_threshold() -> void:
	for kind: int in Gas.ROWS:
		var w := _hall()
		Gas.put(w, Vector2i(7, 8), kind, Gas.OPAQUE)
		assert_true(w.opaque(Vector2i(7, 8)), str(kind))


func test_sight_returns_as_a_wall_of_fog_thins_out() -> void:
	var w := _hall()
	var beyond := Vector2i(10, 8)
	for y in range(1, Grid.H - 1):
		Gas.put(w, Vector2i(7, y), Gas.FOG, Gas.MAX)
	w.sense()
	assert_eq(w.fov(ME)[Grid.index(beyond)], 0)
	var rounds := 0
	while w.fov(ME)[Grid.index(beyond)] == 0 and rounds < 100:
		Gas.tick(w)
		rounds += 1
	assert_eq(w.fov(ME)[Grid.index(beyond)], 1, "clear after %d rounds" % rounds)
	assert_gt(rounds, 1, "not at once")
	assert_false(w.gas.is_empty(), "while some gas still lies about")


func test_the_opaque_mask_agrees_with_opaque_on_every_tile_with_gas_about() -> void:
	var w := _hall()
	_block(w, MID, 3, Gas.FOG, 2)
	Gas.put(w, MID, Gas.SMOKE, 6)
	Gas.put(w, MID + Vector2i.DOWN, Gas.STEAM, Gas.OPAQUE)
	w.burning[MID + Vector2i.LEFT] = 2
	w._changed()
	var mask := w.opaque_mask()
	for i in mask.size():
		assert_eq(mask[i] == 1, w.opaque(Grid.at(i)), str(Grid.at(i)))
	assert_eq(mask[Grid.index(MID)], 1)
	assert_eq(mask[Grid.index(MID + Vector2i(2, 0))], 0)


func test_gas_does_not_cast_shadows_for_light() -> void:
	var w := _hall()
	Gas.put(w, Vector2i(7, 8), Gas.SMOKE, Gas.MAX)
	assert_false(w.blocks_light(Vector2i(7, 8)))
	assert_eq(w.light_mask()[Grid.index(Vector2i(7, 8))], 0)


# --- harm and wetting ----------------------------------------------------------


func test_steam_scalds_whoever_stands_in_it_each_round() -> void:
	var w := _hall()
	var at := ME + Vector2i(2, 0)
	var foe := FloorGen.spawn(w, &"jangseung", at)
	foe.cooldown = 99
	_block(w, ME, 3, Gas.STEAM, Gas.MAX)
	var hp := foe.hp
	var events := w.act({t = &"wait"})
	assert_eq(w.player().hp, 5 - Gas.of(Gas.STEAM, "harm"))
	assert_eq(foe.hp, hp - Gas.of(Gas.STEAM, "harm"))
	for who in [w.player(), foe]:
		assert_true(
			events.any(func(e): return e.t == &"scald" and e.id == who.id and e.kind == Gas.STEAM)
		)
	w.act({t = &"wait"})
	assert_eq(w.player().hp, 5 - 2 * Gas.of(Gas.STEAM, "harm"), "every round")


func test_steam_does_not_scald_who_stands_clear_of_it() -> void:
	var w := _hall()
	_block(w, ME + Vector2i(12, 0), 1, Gas.STEAM, Gas.MAX)
	var events := w.act({t = &"wait"})
	assert_eq(w.player().hp, 5)
	assert_false(events.any(func(e): return e.t == &"scald"))


func test_fog_and_smoke_do_no_harm() -> void:
	for kind in [Gas.FOG, Gas.SMOKE]:
		var w := _hall()
		_block(w, ME, 2, kind, Gas.MAX)
		w.act({t = &"wait"})
		assert_eq(w.player().hp, 5, str(kind))


func test_steam_that_kills_ends_the_run() -> void:
	var w := _hall()
	w.player().hp = 1
	_block(w, ME, 2, Gas.STEAM, Gas.MAX)
	w.act({t = &"wait"})
	assert_eq(w.outcome, &"lost")


func test_steam_wets_a_drum_once_until_it_dries() -> void:
	var w := _hall()
	var drum := MID
	w.set_tile(drum, World.DRUM)
	_block(w, drum, 1, Gas.STEAM, Gas.MAX)
	Gas.tick(w)
	assert_eq(w.wet.get(drum), Drums.WET_ROUNDS)
	w.wet[drum] = 7
	_block(w, drum, 1, Gas.STEAM, Gas.MAX)
	Gas.tick(w)
	assert_eq(w.wet[drum], 7, "already wet")
	var other := _hall()
	other.set_tile(drum, World.DRUM)
	_block(other, drum, 1, Gas.FOG, Gas.MAX)
	Gas.tick(other)
	assert_false(other.wet.has(drum), "fog does not wet")


# --- smoke from fire -----------------------------------------------------------


func test_a_burning_tile_breathes_out_smoke_that_blocks_sight() -> void:
	var w := _hall()
	var fire := Vector2i(7, 8)
	w.set_tile(fire, World.BOARD)
	w.burning[fire] = World.BURN_ROUNDS
	var events := w.act({t = &"wait"})
	assert_true(events.any(func(e): return e.t == &"gas" and e.at == fire and e.kind == Gas.SMOKE))
	assert_false(w.gas.is_empty())
	for p: Vector2i in w.gas:
		assert_eq(w.gas[p].x, Gas.SMOKE)
		assert_lte(Grid.cheb(p, fire), 1, "one round of spreading")


func test_a_fire_that_goes_out_leaves_smoke_that_clears() -> void:
	var w := _hall()
	var fire := Vector2i(7, 8)
	w.set_tile(fire, World.BOARD)
	w.burning[fire] = 2
	for i in 60:
		w.act({t = &"wait"})
	assert_false(w.burning.has(fire))
	assert_eq(w.gas, {})


func test_nothing_burning_no_smoke() -> void:
	var w := _hall()
	for i in 5:
		w.act({t = &"wait"})
	assert_eq(w.gas, {})


func test_a_big_fire_makes_thick_smoke_somewhere() -> void:
	var w := _hall()
	for x in range(8, 14):
		for y in range(7, 10):
			w.set_tile(Vector2i(x, y), World.BOARD)
			w.burning[Vector2i(x, y)] = World.BURN_ROUNDS
	for i in 2:
		w.act({t = &"wait"})
	assert_true(w.gas.values().any(func(g): return g.y >= Gas.OPAQUE))


# --- copies and replays --------------------------------------------------------


func test_a_clone_holds_its_own_copy_of_the_gas() -> void:
	var w := _hall()
	Gas.put(w, MID, Gas.FOG, 4)
	var c := w.clone()
	assert_eq(c.gas, w.gas)
	Gas.put(c, MID, Gas.FOG, 4)
	Gas.spread(c)
	assert_eq(w.gas, {MID: Vector2i(Gas.FOG, 4)}, "the original is not touched")


func test_a_preview_shows_the_gas_the_round_leaves() -> void:
	var w := World.create(7)
	var at := w.player().pos + Vector2i(1, 0)
	Gas.put(w, at, Gas.SMOKE, Gas.MAX)
	Gas.put(w, at + Vector2i(1, 0), Gas.STEAM, Gas.MAX)
	var previewed := w.preview({t = &"wait"})
	w.act({t = &"wait"})
	assert_eq(previewed.gas, w.gas)
	assert_eq(previewed.rng.state, w.rng.state)
	assert_eq(previewed.player().hp, w.player().hp)


func test_the_same_seed_and_actions_leave_the_same_gas_and_events() -> void:
	var runs := []
	for i in 2:
		var w := World.create(11)
		w.depth = 5
		FloorGen.build(w)
		w.sense()
		var at := w.player().pos
		_block(w, at, 2, Gas.STEAM, Gas.MAX)
		_block(w, at + Vector2i(3, 0), 1, Gas.FOG, Gas.MAX)
		var told := []
		for r in 12:
			told.append(w.act({t = &"wait"}))
		runs.append({gas = w.gas, hp = w.player().hp, events = told, rng = w.rng.state})
	assert_eq(runs[0], runs[1])
	assert_gt(runs[0].gas.size(), 0)


func test_a_new_storey_starts_with_none_but_its_own_fog() -> void:
	var w := World.create(3)
	w.gas[Vector2i(1, 1)] = Vector2i(Gas.SMOKE, 5)
	w.vents[Vector2i(1, 1)] = Gas.FOG
	w.depth = 1
	FloorGen.build(w)
	assert_false(w.gas.has(Vector2i(1, 1)))
	assert_true(w.gas.is_empty(), "tier 1 has no fog")
	assert_true(w.vents.is_empty(), "and no vents")


# --- vents ---------------------------------------------------------------------


## A storey of tier 2 or more with fog ponds, built at `seed_value`.
func _fog_storey(seed_value: int) -> World:
	var w := World.create(seed_value)
	w.depth = 4
	FloorGen.build(w)
	w.sense()
	return w


func test_a_vent_keeps_a_bank_of_gas_that_blocks_sight_indefinitely() -> void:
	var w := _hall()
	for x in range(20, 24):
		w.vents[Vector2i(x, 14)] = Gas.FOG
	for r in 200:
		Gas.tick(w)
	assert_gt(w.gas.size(), 8)
	assert_true(w.gas.values().any(func(g): return g.y >= Gas.OPAQUE), "thick somewhere")
	var thick := w.gas.values().filter(func(g): return g.y >= Gas.OPAQUE).size()
	assert_gt(thick, 3)
	for p: Vector2i in w.gas:
		assert_eq(w.gas[p].x, Gas.FOG)


func test_a_vent_alone_does_not_flood_the_storey() -> void:
	var w := _hall()
	for x in range(20, 24):
		for y in range(12, 15):
			w.vents[Vector2i(x, y)] = Gas.FOG
	var most := 0
	for r in 300:
		Gas.tick(w)
		most = maxi(most, w.gas.size())
	assert_lt(most, 120, "12 vents spread to a bank, not the whole hall")


func test_fog_ponds_of_built_storeys_keep_their_bank_for_300_rounds() -> void:
	var seen := 0
	for s in [1, 5, 6, 10]:
		var w := _fog_storey(s)
		assert_false(w.vents.is_empty(), "seed %d has a fog pond" % s)
		var most := 0
		for r in 300:
			Gas.tick(w)
			most = maxi(most, w.gas.size())
		seen += 1
		assert_gt(w.gas.size(), w.vents.size(), "seed %d keeps a bank" % s)
		assert_true(w.gas.values().any(func(g): return g.y >= Gas.OPAQUE), "seed %d" % s)
		assert_lt(most, 100, "seed %d does not flood" % s)
	assert_eq(seen, 4)


func test_vents_are_ponds_and_gas_stops_with_no_vent() -> void:
	var w := _fog_storey(1)
	for p: Vector2i in w.vents:
		assert_eq(w.tile(p), World.POND)
		assert_eq(w.vents[p], Gas.FOG)
	w.vents.clear()
	for r in 100:
		Gas.tick(w)
	assert_true(w.gas.is_empty(), "without its pond the fog dies away")


func test_a_clone_keeps_the_vents_and_a_preview_leaves_the_same_bank() -> void:
	var w := _fog_storey(1)
	var c := w.clone()
	assert_eq(c.vents, w.vents)
	c.vents.erase(c.vents.keys()[0])
	assert_eq(w.vents.size(), c.vents.size() + 1, "the copy is its own")
	var previewed := w.preview({t = &"wait"})
	w.act({t = &"wait"})
	assert_eq(previewed.gas, w.gas)


func test_the_same_seed_and_actions_leave_the_same_bank_around_vents() -> void:
	var runs := []
	for i in 2:
		var w := _fog_storey(1)
		var told := []
		for r in 40:
			told.append(w.act({t = &"wait"}))
		runs.append({gas = w.gas, vents = w.vents, events = told, rng = w.rng.state})
	assert_eq(runs[0], runs[1])
	assert_gt(runs[0].gas.size(), runs[0].vents.size())


func test_a_vent_makes_no_noise_in_the_log() -> void:
	var w := _hall()
	w.vents[MID] = Gas.FOG
	var events := w.act({t = &"wait"})
	assert_false(events.any(func(e): return e.t == &"gas"), "the bank is ambient")
