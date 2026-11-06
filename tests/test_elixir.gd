extends GutTest
## The elixir (Elixir): stepping on it asks, Y ends the run, N keeps it; while she carries
## it she shines, every foe hunts her, her tails are 9 at most and grow back 3 a round.

const ME := Vector2i(4, 2)
const E := Vector2i(1, 0)
const DRINK_YES := {t = &"drink", yes = true}
const DRINK_NO := {t = &"drink", yes = false}
const ELIXIR := {t = &"cheat", cmd = &"elixir"}


## A hall of floor with the elixir one step east of Miho.
func _world() -> World:
	var row := ".".repeat(30)
	var w := Arena.from([row, "...@" + row.substr(4), row], Vector2i(1, 1))
	w.elixir = w.player().pos + E
	return w


func _stand(w: World) -> void:
	w.act({t = &"move", dir = E})


func _kept(w: World) -> World:
	_stand(w)
	w.act(DRINK_NO)
	return w


func _foe(w: World, at: Vector2i) -> Actor:
	var a := FloorGen.spawn(w, &"dokkaebi", at)
	a.brain.alert = Actor.REST
	a.brain.home = at
	return a


func test_the_step_onto_the_elixir_is_a_whole_round() -> void:
	var w := _world()
	var foe := _foe(w, w.player().pos + Vector2i(8, 1))
	foe.brain.alert = Actor.HUNT
	var from := foe.pos
	var round_no := w.round_no
	_stand(w)
	assert_true(w.elixir_asked)
	assert_eq(w.round_no, round_no + 1)
	assert_ne(foe.pos, from, "the creatures acted")


func test_stepping_on_the_elixir_asks_and_allows_only_the_answer() -> void:
	var w := _world()
	_stand(w)
	assert_true(w.elixir_asked)
	assert_eq(w.outcome, &"", "no ending before she answers")
	for what: Dictionary in [{t = &"wait"}, {t = &"move", dir = E}, ELIXIR]:
		assert_false(w.can(what), str(what))
	assert_true(w.can(DRINK_YES) and w.can(DRINK_NO))


func test_an_answer_with_no_question_is_refused() -> void:
	var w := _world()
	assert_false(w.can(DRINK_YES))
	assert_false(w.can({t = &"drink"}), "and so is one with no yes or no")


func test_yes_ends_the_run_as_won_and_takes_no_round() -> void:
	var w := _world()
	_stand(w)
	var round_no := w.round_no
	var events := w.act(DRINK_YES)
	assert_eq(w.outcome, &"won")
	assert_eq(events.map(func(e): return e.t), [&"won"])
	assert_eq(w.round_no, round_no)
	assert_false(w.elixir_held)


func test_no_keeps_it_takes_it_off_the_floor_and_takes_no_round() -> void:
	var w := _world()
	_stand(w)
	var round_no := w.round_no
	w.act(DRINK_NO)
	assert_true(w.elixir_held)
	assert_false(w.elixir_asked)
	assert_eq(w.outcome, &"")
	assert_eq(w.elixir, Vector2i(-1, -1))
	assert_eq(w.round_no, round_no)
	assert_true(w.can({t = &"wait"}), "she goes on")


func test_a_kept_elixir_is_not_asked_about_again() -> void:
	var w := _kept(_world())
	w.act({t = &"move", dir = -E})
	w.act({t = &"move", dir = E})
	assert_false(w.elixir_asked)


func test_the_elixir_is_copied_by_a_clone_and_a_snapshot() -> void:
	var w := _world()
	_stand(w)
	assert_true(w.clone().elixir_asked)
	assert_true(Snapshot.world(Snapshot.of(w)).elixir_asked)
	w.act(DRINK_NO)
	assert_true(w.clone().elixir_held)
	assert_true(Snapshot.world(Snapshot.of(w)).elixir_held)


func test_the_most_tails_is_the_same_on_every_storey_and_ignores_the_altar() -> void:
	var w := _kept(_world())
	for depth in [1, 3, World.FLOORS]:
		w.depth = depth
		w.tail_bonus = 2
		assert_eq(w.max_tails(), Elixir.TAILS, "storey %d" % depth)
	w.depth = 1
	w.tail_bonus = 0
	assert_eq(w.max_tails(), Elixir.TAILS, "more than the storey allows")


func test_taking_it_cuts_tails_over_the_most() -> void:
	var w := _world()
	w.depth = World.FLOORS
	w.tail_bonus = 1
	w.tails = w.max_tails()
	assert_eq(w.tails, Elixir.TAILS + 1)
	_kept(w)
	assert_eq(w.tails, Elixir.TAILS)


func test_tails_grow_back_three_a_round_up_to_the_most() -> void:
	var w := _kept(_world())
	w.tails = 1
	w.act({t = &"wait"})
	assert_eq(w.tails, 1 + Elixir.REGROWN)
	w.act({t = &"wait"})
	assert_eq(w.tails, 1 + 2 * Elixir.REGROWN)
	w.act({t = &"wait"})
	assert_eq(w.tails, Elixir.TAILS, "not past the most")
	w.act({t = &"wait"})
	assert_eq(w.tails, Elixir.TAILS)


func test_tails_grow_back_one_in_three_rounds_without_it() -> void:
	var w := _world()
	w.tails = 1
	w.act({t = &"wait"})
	assert_eq(w.tails, 1, "the old regrowth")


func test_her_tile_shines_as_a_lantern_does() -> void:
	var w := _world()
	var lantern := _world()
	var at := w.player().pos
	lantern.tiles[Grid.index(at)] = World.LANTERN
	lantern._changed()
	assert_false(w.lit(at + Vector2i(3, 0)), "dark without it")
	w.act(ELIXIR)
	var lit := 0
	for x in range(at.x - 8, at.x + 9):
		var p := Vector2i(x, at.y)
		if p != at:
			assert_eq(w.lit(p), lantern.lit(p), "tile %d" % x)
			lit += int(w.lit(p))
	assert_gt(lit, 0)
	w.act({t = &"move", dir = E})
	assert_true(w.lit(w.player().pos + Vector2i(Light.LANTERN_RADIUS - 2, 0)), "it moves with her")
	assert_false(w.lit(at - Vector2i(Light.LANTERN_RADIUS + 1, 0)), "and leaves the tile behind")


func test_every_foe_on_the_storey_hunts_her_even_unseen() -> void:
	var w := _world()
	var far := _foe(w, w.player().pos + Vector2i(8, 1))
	var kin := _foe(w, w.player().pos + Vector2i(8, 2))
	Mind.enlist(w, kin)
	_kept(w)
	w.act({t = &"wait"})
	assert_eq(far.brain.alert, Actor.HUNT)
	assert_eq(far.brain.target, w.player().pos)
	assert_ne(kin.brain.alert, Actor.HUNT, "an ally stays as it was")


func test_foes_rest_while_she_does_not_carry_it() -> void:
	var w := _world()
	var far := _foe(w, w.player().pos + Vector2i(8, 1))
	w.act({t = &"wait"})
	assert_ne(far.brain.alert, Actor.HUNT)


func test_taking_it_drops_the_guise_and_the_cloak_she_wore() -> void:
	var w := _world()
	var me := w.player()
	me.buffs.guise = true
	me.buffs.form = &"dokkaebi"
	me.buffs.cloak = true
	me.buffs.talon = true
	_kept(w)
	assert_false(me.buffs.guise)
	assert_false(me.buffs.cloak)
	assert_true(me.buffs.talon, "the other buffs stay")


func test_neither_guise_nor_cloak_can_be_cast_while_she_carries_it() -> void:
	var w := _world()
	w.player().buffs.prey = &"dokkaebi"
	var guise := {t = &"cast", spells = [{cards = Guise.RECIPE[Guise.GUISE], dir = Vector2i.ZERO}]}
	var cloak := {t = &"cast", spells = [{cards = Guise.RECIPE[Guise.CLOAK], dir = Vector2i.ZERO}]}
	var shadow := {
		t = &"cast", spells = [{cards = Guise.RECIPE[Guise.SHADOW], dir = Vector2i.ZERO}]
	}
	var thrown := {t = &"cast", spells = [{cards = Guise.RECIPE[Guise.GUISE], dir = E}]}
	for what: Dictionary in [guise, cloak, shadow, thrown]:
		assert_true(w.can(what), "before: %s" % what)
	_kept(w)
	assert_false(w.can(guise))
	assert_false(w.can(cloak))
	assert_true(w.can(shadow), "a spell that is not either")
	assert_true(w.can(thrown), "along a direction they are plain spells")


func test_the_debug_command_gives_it_at_once_with_no_question_and_no_round() -> void:
	var w := _world()
	var round_no := w.round_no
	assert_true(w.can(ELIXIR))
	w.act(ELIXIR)
	assert_true(w.elixir_held)
	assert_false(w.elixir_asked)
	assert_eq(w.round_no, round_no)
	assert_false(w.can(ELIXIR), "once")


func test_the_debug_command_drops_the_guise_too() -> void:
	var w := _world()
	w.player().buffs.cloak = true
	w.act(ELIXIR)
	assert_false(w.player().buffs.cloak)


func test_she_keeps_it_to_another_storey_and_none_lies_on_the_top_one() -> void:
	var w := World.create(5)
	w.act(ELIXIR)
	w.act({t = &"cheat", cmd = &"floor", depth = 3})
	assert_true(w.elixir_held)
	assert_eq(w.max_tails(), Elixir.TAILS)
	assert_eq(w.tails, Elixir.TAILS)
	w.act({t = &"cheat", cmd = &"floor", depth = World.FLOORS})
	assert_eq(w.elixir, Vector2i(-1, -1), "she has it already")


func test_a_walk_stops_when_the_elixir_asks() -> void:
	var w := _world()
	var before := w.clone()
	var events := w.act({t = &"move", dir = E})
	assert_true(Travel.interrupted(before, w, events, {}))


func test_a_saved_run_with_the_elixir_plays_again_and_the_answer_is_a_valid_save_action() -> void:
	var path := "user://test_elixir.cfg"
	var save := SaveGame.new(path, 5)
	save.record(ELIXIR, 0, false)
	save.write()
	var loaded := SaveGame.load_from(path)
	assert_false(loaded.stale)
	assert_true(loaded.replay())
	assert_true(loaded.world.elixir_held)
	assert_true(SaveGame._shaped(DRINK_NO))
	assert_false(SaveGame._shaped({t = &"drink"}))
	save.erase()
