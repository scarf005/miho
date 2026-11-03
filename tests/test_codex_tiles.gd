extends GutTest
## A tile's entry in the 도감 tells what the rules do to it: each case does the thing
## with the rule itself, then reads the entry.

const TILES := 4


func _told(name: String) -> String:
	var found := Codex.entries(TILES).filter(func(e): return e.name == name)
	return Info.plain(Codex.detail(found[0]))


func _tile(t: int) -> World:
	var w := Codex.stage()
	w.set_tile(Codex.AT, t)
	return w


func _shot(w: World, cards: Array) -> Shot:
	var s := Shot.new()
	s.spell = Spell.make(cards)
	s.caster = w.player().id
	s.pos = Codex.AT
	s.dir = Vector2i.RIGHT
	return s


## The compounds in the stand-in shot, each with the tile `t` after its ground rule.
func _laid(t: int) -> Dictionary:
	var out := {}
	for c: StringName in Cards.compounds():
		var w := _tile(t)
		var at: Array[Vector2i] = [Codex.AT]
		Compounds.ground(w, _shot(w, Cards.COMPOUND[c].made), c, at)
		out[c] = w
	return out


## The text an entry and the entries of its tags tell.
func _whole(name: String) -> String:
	var text := _told(name)
	if text.split("\n").has("땅."):
		text += "\n" + "\n".join(Glossary.rows()["땅"])
	return text


func _blocks_gas(name: String) -> bool:
	return Array(_told(name).split("\n")).any(
		func(line): return line.begins_with("막음: ") and line.contains("기체")
	)


## The labels on the lines that end in `change`.
func _labels(text: String, change: String) -> Array:
	var out := []
	for line in text.split("\n"):
		if line.ends_with(": " + change):
			out.append_array(line.trim_suffix(": " + change).split(", "))
	return out


func test_each_compound_that_changes_a_tile_is_told_on_its_entry_and_no_other() -> void:
	for t: int in Tiles.ROWS:
		var name: String = Tiles.of(t, "name")
		var text := _whole(name)
		var laid := _laid(t)
		for c: StringName in laid:
			var to: int = laid[c].tile(Codex.AT)
			var label := Lang.t(Cards.NAME[c])
			if to != t:
				assert_has(_labels(text, SpellInfo.becomes(to)), label, "%s %s" % [name, c])
			else:
				for other: int in Tiles.ROWS:
					assert_does_not_have(
						_labels(text, SpellInfo.becomes(other)), label, "%s %s" % [name, c]
					)


func test_lines_with_the_same_result_are_one_line_on_every_entry() -> void:
	assert_string_contains(_told("벽"), "나무 주문, 구슬: 금 간 벽이 됨")
	for e: Dictionary in Codex.entries(TILES):
		var seen := {}
		for line: String in Info.plain(Codex.detail(e)).split("\n"):
			if line.ends_with("됨"):
				var result := line.get_slice(": ", line.get_slice_count(": ") - 1)
				assert_false(seen.has(result), "%s: %s" % [e.name, line])
				seen[result] = true


func test_what_a_tile_blocks_is_one_line_on_every_entry() -> void:
	for e: Dictionary in Codex.entries(TILES):
		var blocks := Array(Info.plain(Codex.detail(e)).split("\n")).filter(
			func(line): return line.begins_with("막음: ")
		)
		assert_lte(blocks.size(), 1, "%s: %s" % [e.name, blocks])


func test_water_puts_out_a_lantern_and_a_veil_and_the_entry_tells_what_is_left() -> void:
	for t in [World.LANTERN, World.VEIL]:
		var w := _tile(t)
		Terrain.wash(w, Codex.AT)
		assert_ne(w.tile(Codex.AT), t)
		var told := _labels(_told(Tiles.of(t, "name")), SpellInfo.becomes(w.tile(Codex.AT)))
		assert_has(told, "물 주문", str(t))
	assert_does_not_have(_labels(_told("바닥"), SpellInfo.becomes(World.FLOOR)), "물 주문")


func test_only_bare_floor_takes_the_pool_of_a_water_orb() -> void:
	for t in [World.FLOOR, World.GRASS]:
		var w := _tile(t)
		var s := _shot(w, [Cards.ORB, Cards.WATER])
		Terrain.touch(w, s, Codex.AT, Vector2i(-1, -1))
		var told := _labels(_told(Tiles.of(t, "name")), SpellInfo.becomes(World.SHALLOW))
		assert_eq(told.has("물 구슬"), w.tile(Codex.AT) == World.SHALLOW, str(t))


func test_an_orb_on_a_wall_on_a_door_and_on_a_lantern_leaves_what_the_entry_tells() -> void:
	for t in [World.WALL, World.WALL_CRACKED, World.DOOR, World.LANTERN, World.WINDOW]:
		var w := _tile(t)
		Terrain.smash(w, _shot(w, [Cards.ORB]), Codex.AT, t)
		var told := _labels(_told(Tiles.of(t, "name")), SpellInfo.becomes(w.tile(Codex.AT)))
		assert_has(told, "구슬", str(t))


func test_an_orb_of_earth_or_metal_brings_a_whole_wall_down_and_the_entry_tells_so() -> void:
	for c: StringName in [Cards.EARTH, Cards.METAL]:
		var w := _tile(World.WALL)
		Terrain.smash(w, _shot(w, [Cards.ORB, c]), Codex.AT, World.WALL)
		var told := _labels(_told("벽"), SpellInfo.becomes(w.tile(Codex.AT)))
		assert_has(told, Lang.t(Cards.NAME[c]) + " 구슬")
	assert_does_not_have(_labels(_told("금 간 벽"), SpellInfo.becomes(World.RUBBLE)), "흙 구슬")


func test_walking_into_a_lantern_leaves_what_the_entry_tells() -> void:
	var w := _tile(World.LANTERN)
	Terrain.knock(w, w.player(), Codex.AT)
	assert_has(_labels(_told("등불"), SpellInfo.becomes(w.tile(Codex.AT))), "부딪침")
	assert_false(_told("벽").contains("부딪침:"), "a wall is not knocked")


func test_what_is_stepped_on_or_off_is_told_by_what_it_becomes() -> void:
	for t in [World.REEDS, World.LEAVES]:
		var w := _tile(t)
		Terrain.trample(w, Codex.AT)
		assert_string_contains(
			_told(Tiles.of(t, "name")), "밟으면: " + SpellInfo.becomes(w.tile(Codex.AT))
		)
	var w := _tile(World.BOARD_ROTTEN)
	Terrain.crumble(w, w.player(), Codex.AT)
	assert_string_contains(_told("낡은 마루"), "떠나면: " + SpellInfo.becomes(w.tile(Codex.AT)))
	assert_false(_told("바닥").contains("밟으면:"))


func test_a_rotten_board_burns_away_to_what_its_entry_tells() -> void:
	var w := _tile(World.BOARD_ROTTEN)
	w.burning[Codex.AT] = 1
	Terrain.burn(w, [])
	assert_string_contains(_told("낡은 마루"), "불탄 뒤: " + Tiles.of(w.tile(Codex.AT), "name"))
	assert_false(_told("마루").contains("불탄 뒤:"), "the glossary tells of the rest")


func test_a_tile_gas_cannot_lie_on_tells_so_unless_it_is_solid() -> void:
	for t in [World.DOOR, World.WINDOW, World.SKY, World.FLOOR]:
		var w := _tile(t)
		Gas.put(w, Codex.AT, Gas.FOG, 1)
		assert_eq(_blocks_gas(Tiles.of(t, "name")), not w.gas.has(Codex.AT), str(t))
	assert_false(_blocks_gas("벽"), "a wall is taken for granted")


func test_what_never_takes_fire_is_tagged_and_the_tag_tells_it() -> void:
	for t: int in Tiles.ROWS:
		var w := _tile(t)
		Terrain.ignite(w, Codex.AT, true)
		var tagged := _told(Tiles.of(t, "name")).split("\n").has("소화.")
		assert_eq(tagged, not w.burning.has(Codex.AT), str(t))
	var told := "\n".join(Glossary.rows()["소화"])
	for spec in Compounds.HOT:
		assert_string_contains(told, spec.name)


func test_the_entry_of_fire_tells_what_puts_it_out_and_what_it_breathes() -> void:
	var laid := {}
	for c: StringName in Cards.compounds():
		var w := Codex.stage()
		w.burning[Codex.AT] = World.BURN_ROUNDS
		var at: Array[Vector2i] = [Codex.AT]
		Compounds.ground(w, _shot(w, Cards.COMPOUND[c].made), c, at)
		laid[Lang.t(Cards.NAME[c])] = not w.burning.has(Codex.AT)
	for name in ["불", "맹렬한 불"]:
		var told := _labels(_told(name), "꺼짐")
		assert_has(told, "물 주문")
		for label: String in laid:
			assert_eq(told.has(label), laid[label], label)
		assert_string_contains(_told(name), "뿜는 기체: " + Gas.of(Gas.SMOKE, "name"))


func test_the_entry_of_a_gas_tells_which_spells_lay_it() -> void:
	for kind: int in Gas.ROWS:
		var makers := []
		for c: StringName in Cards.compounds():
			var w := Codex.stage()
			var at: Array[Vector2i] = [Codex.AT]
			Compounds.ground(w, _shot(w, Cards.COMPOUND[c].made), c, at)
			if Gas.at(w, Codex.AT).x == kind:
				makers.append(Lang.t(Cards.NAME[c]))
		var name: String = Gas.of(kind, "name")
		var told := _told(name)
		if makers.is_empty():
			assert_false(told.contains("만드는 주문:"), name)
		else:
			assert_string_contains(told, "만드는 주문: " + ", ".join(makers))


func test_a_gas_that_blows_up_tells_what_the_blast_does_on_the_map_too() -> void:
	var w := Codex.stage()
	var foe := Codex.foe(Codex.foes()[0])
	foe.id = w.new_id()
	foe.faction = Actor.HEAVEN
	foe.pos = Codex.AT
	foe.hp = 99
	w.actors.append(foe)
	Gas.put(w, Codex.AT, Gas.MARSH, Gas.MAX)
	w.sense()
	var hover := Info.plain(Info.terrain(w, Codex.AT))
	Gas.light(w, Codex.AT)
	assert_eq(foe.hp, 99 - Gas.BLAST)
	assert_gt(foe.ailments.alight, 0)
	for told in [_told(Gas.of(Gas.MARSH, "name")), hover]:
		assert_string_contains(told, "불: 폭발")
		assert_string_contains(told, "폭발 피해: %d" % (99 - foe.hp))
		assert_string_contains(told, "폭발 소음: %d" % Gas.BLAST_LOUD)
		assert_string_contains(told, "불붙음: %d초" % foe.ailments.alight)
	assert_false(_told(Gas.of(Gas.FOG, "name")).contains("폭발"))


func test_steam_wets_whoever_stands_in_it_for_as_long_as_its_entry_tells() -> void:
	var w := Codex.stage()
	Status.soak(w, w.player())
	var told := _told(Gas.of(Gas.STEAM, "name"))
	assert_string_contains(told, "젖음: %d초" % w.player().ailments.wet)
	assert_false(_told(Gas.of(Gas.FOG, "name")).contains("젖음:"))
