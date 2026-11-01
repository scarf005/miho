extends GutTest
## The death banner tells what felled Miho, and the log opens over it.

const ME := Vector2i(4, 8)


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
	me.hp = 1
	me.max_hp = 3
	me.pos = ME
	w.actors.append(me)
	return w


func _foe(w: World, at: Vector2i) -> Actor:
	var foe := Actor.new()
	foe.id = w.new_id()
	foe.kind = &"dokkaebi"
	foe.faction = Actor.HEAVEN
	foe.hp = 3
	foe.max_hp = 3
	foe.pos = at
	w.actors.append(foe)
	w.sense()
	return foe


func _head(w: World) -> String:
	return Banner.over(w, 0, 1)[0]


func test_a_blow_from_a_seen_creature_names_it() -> void:
	var w := _world()
	var foe := _foe(w, ME + Vector2i.RIGHT)
	foe.alert = 2
	w.emit({t = &"melee", id = foe.id, target = w.player().id, at = ME, n = 1})
	w.hurt(w.player(), 1)
	assert_eq(_head(w), foe.info().name + "에게 쓰러졌다")


func test_a_blow_from_an_unseen_creature_names_nobody() -> void:
	var w := _world()
	var foe := _foe(w, ME + Vector2i.RIGHT)
	w.seen[Grid.index(foe.pos)] = 0
	w.emit({t = &"melee", id = foe.id, target = w.player().id, at = ME, n = 1})
	w.hurt(w.player(), 1)
	assert_eq(_head(w), "쓰러졌다")


func test_a_spell_names_its_caster_when_seen_and_itself_either_way() -> void:
	var w := _world()
	var foe := _foe(w, ME + Vector2i(2, 0))
	var hit := {t = &"hit", shot = 1, id = w.player().id, at = ME, by = foe.id, title = "불길"}
	w.emit(hit)
	w.hurt(w.player(), 1)
	assert_eq(_head(w), foe.info().name + "의 불길에 쓰러졌다")
	w.seen[Grid.index(foe.pos)] = 0
	assert_eq(_head(w), "불길에 쓰러졌다")


func test_her_own_spell_is_named_alone() -> void:
	var w := _world()
	w.emit({t = &"splash", at = ME, by = w.player().id, title = "여우불"})
	w.hurt(w.player(), 1)
	assert_eq(_head(w), "여우불에 쓰러졌다")


func test_an_earlier_wound_is_not_the_cause_of_a_later_one() -> void:
	var w := _world()
	w.player().hp = 2
	var foe := _foe(w, ME + Vector2i.RIGHT)
	w.emit({t = &"melee", id = foe.id, target = w.player().id, at = ME, n = 1})
	w.hurt(w.player(), 1)
	w.hurt(w.player(), 1)
	assert_eq(_head(w), "쓰러졌다")


func test_fire_and_a_fall_read_as_such() -> void:
	var w := _world()
	w.emit({t = &"burn", at = ME, id = w.player().id})
	w.hurt(w.player(), 1)
	assert_eq(_head(w), "불에 타 쓰러졌다")
	var fell := _world()
	fell.emit({t = &"fall", id = fell.player().id, from = ME, at = ME, depth = 1})
	fell.hurt(fell.player(), 1)
	assert_eq(_head(fell), "떨어져 쓰러졌다")


func test_the_log_opens_over_the_banner_and_closes_back_to_it() -> void:
	var m: Node = load("res://src/view/main.tscn").instantiate()
	m.save_path = ""
	add_child_autofree(m)
	Keys.reset()
	m._new_run(7)
	m.state = &"over"
	m.term.banner_lines = Banner.over(m.world, 0, m.run_seed)
	var open := Keys.event(Keys.keys_of(&"log")[0])
	open.pressed = true
	m._unhandled_input(open)
	assert_eq(m.overlay, &"log")
	var shut := Keys.event("Escape")
	shut.pressed = true
	m._unhandled_input(shut)
	assert_eq(m.overlay, &"")
	assert_eq(m.state, &"over")
