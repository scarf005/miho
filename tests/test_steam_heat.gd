extends GutTest
## Steam has a heat apart from its amount: it falls by 1 for each tile the steam spreads, and
## steam with none left is fog of what remains (Gas).

const MID := Vector2i(20, 14)
const E := Vector2i(1, 0)


func _steam(w: World, p: Vector2i, heat: int, amount := Gas.MAX) -> void:
	w.gas[p] = Vector2i(Gas.STEAM, amount)
	w.gas_heat[p] = heat


func _ring() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(-2, 3):
		for x in range(-2, 3):
			if maxi(absi(x), absi(y)) == 2:
				out.append(MID + Vector2i(x, y))
	return out


func test_a_ring_vented_at_landing_heat_never_scalds_its_middle() -> void:
	var w := Arena.hall(MID)
	w.player().hp = 99
	w.player().max_hp = 99
	var foe := FloorGen.spawn(w, &"jangseung", MID + Vector2i(2, 0))
	foe.max_hp = 99
	foe.hp = 99
	assert_eq(_ring().size(), 16)
	for p in _ring():
		Gas.add(w, p, Gas.STEAM, Compounds.STEAM, Leap.heat(p, MID))
	var burns := {w.player().id: 0, foe.id: 0}
	for i in 50:
		w.events.clear()
		Gas.tick(w)
		for e in w.events:
			if e.t == &"scald":
				burns[e.id] += 1
	assert_eq(burns[w.player().id], 0, "the middle")
	assert_gt(burns[foe.id], 0, "the ring")


func test_steam_that_cools_while_spreading_becomes_fog_of_that_amount() -> void:
	var w := Arena.hall(MID)
	_steam(w, MID, 1)
	Gas.spread(w, false)
	assert_eq(w.gas[MID], Vector2i(Gas.STEAM, 1), "the middle keeps its own heat")
	assert_eq(w.gas[MID + E], Vector2i(Gas.FOG, 1))
	assert_false(w.gas_heat.has(MID + E), "fog has no heat")
	w = Arena.hall(MID)
	for y in range(-1, 2):
		for x in range(-1, 2):
			_steam(w, MID + Vector2i(x, y), 2)
	Gas.spread(w, false)
	Gas.spread(w, false)
	assert_eq(w.gas[MID + E * 2].x, Gas.STEAM, "two tiles out")
	assert_eq(w.gas_heat[MID + E * 2], 1)
	assert_ne(w.gas.get(MID + E * 3, Gas.NONE).x, Gas.STEAM, "three tiles out")


func test_a_steaming_tile_takes_the_hotter_of_its_own_and_its_neighbour_less_one() -> void:
	var w := Arena.hall(MID)
	_steam(w, MID, 5)
	_steam(w, MID + E, 9)
	Gas.spread(w, false)
	assert_eq(w.gas_heat[MID], 8)
	assert_eq(w.gas_heat[MID + E], 9)


func test_steam_without_heat_counts_as_full_heat() -> void:
	var w := Arena.hall(MID)
	w.gas[MID] = Vector2i(Gas.STEAM, Gas.MAX)
	Gas.spread(w, false)
	assert_eq(w.gas[MID + E].x, Gas.STEAM)
	assert_eq(w.gas_heat[MID + E], Gas.MAX - 1)


func test_fog_set_alight_boils_to_steam_at_full_heat() -> void:
	var w := Arena.hall(MID)
	w.gas[MID] = Vector2i(Gas.FOG, 4)
	Gas.light(w, MID)
	assert_eq(w.gas[MID], Vector2i(Gas.STEAM, 4))
	assert_eq(w.gas_heat[MID], Gas.MAX)


func test_laying_steam_on_steam_keeps_the_hotter() -> void:
	var w := Arena.hall(MID)
	_steam(w, MID, 5, 2)
	Gas.put(w, MID, Gas.STEAM, 1, 2)
	assert_eq(w.gas_heat[MID], 5, "the cooler laid on the hotter")
	Gas.put(w, MID, Gas.STEAM, 1, 7)
	assert_eq(w.gas_heat[MID], 7, "the hotter laid on the cooler")
	Gas.put(w, MID, Gas.SMOKE, Gas.MAX, 7)
	assert_false(w.gas_heat.has(MID), "smoke has no heat")


func test_the_steam_spell_scalds_the_same_as_steam_that_never_cools() -> void:
	var rounds := []
	for never in [false, true]:
		var w := Arena.hall(Vector2i(4, 8))
		w.rng.seed = 7
		w.player().hp = 99
		w.player().max_hp = 99
		for at in [Vector2i(7, 7), Vector2i(7, 8), Vector2i(8, 9), Vector2i(11, 8)]:
			var foe := FloorGen.spawn(w, &"jangseung", at)
			foe.max_hp = 99
			foe.hp = 99
			foe.magic.cooldown = 99
		var log := []
		w.act({t = &"cast", spells = [{cards = [Cards.WATER, Cards.FIRE], dir = E}]})
		for i in 20:
			if never:
				for p: Vector2i in w.gas:
					if w.gas[p].x == Gas.STEAM:
						w.gas_heat[p] = Gas.MAX
			var events := w.act({t = &"wait"})
			log.append(
				events.filter(func(e): return e.t == &"scald").map(func(e): return [e.id, e.at])
			)
		rounds.append(log)
	assert_false(rounds[0].all(func(r): return r.is_empty()), "the cloud scalds someone")
	assert_eq(rounds[0], rounds[1])


func test_heat_survives_clone_snapshot_and_a_storey_left() -> void:
	var w := Arena.hall(MID)
	_steam(w, MID, 4)
	assert_eq(w.clone().gas_heat, {MID: 4}, "clone")
	assert_eq(Snapshot.world(bytes_to_var(var_to_bytes(Snapshot.of(w)))).gas_heat, {MID: 4})
	Storeys.leave(w)
	assert_eq(w.storeys[w.depth].gas_heat, {MID: 4}, "storey")
