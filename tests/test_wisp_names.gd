extends GutTest
## A wisp with one 쇠 is Miho's 탄환 and a creature's 번개, never a 쇠 and the
## name of its wisp; 철갑탄 and 비격진 keep their names.

const BLUNT := ["쇠 혼불", "쇠 도깨비불", "쇠 저승불", "쇠 여우불"]


func test_a_metal_wisp_is_a_bullet_of_miho_and_lightning_of_a_creature() -> void:
	var fox_metal := [Cards.FOX, Cards.METAL]
	assert_eq(Spell.make(fox_metal).title(), "탄환")
	assert_eq(Spell.make([Cards.FOX, Cards.FOX, Cards.METAL]).title(), "탄환 2발")
	assert_eq(Bestiary.spell(&"jiha", fox_metal).title(), "번개")
	assert_eq(Bestiary.spell(&"dokkaebi", fox_metal).title(), "번개")
	assert_eq(Bestiary.spell(&"saja", fox_metal).title(), "번개")
	assert_eq(Bestiary.spell(&"jiha", fox_metal + [Cards.METAL]).title(), Spell.PIERCE_NAME)
	assert_eq(Spell.make(fox_metal + [Cards.METAL]).title(), Spell.PIERCE_NAME)
	assert_eq(Spell.make([Cards.ORB, Cards.EARTH, Cards.METAL]).title(), Spell.MORTAR_NAME)


func test_no_creature_spell_is_named_by_its_metal_and_its_wisp() -> void:
	for kind in Codex.foes():
		for r in range(1, Bestiary.RANKS + 1):
			for cast: Array in Bestiary.casts(kind, r):
				var title := Bestiary.spell(kind, cast).title()
				for bad in BLUNT:
					assert_false(title.contains(bad), "%s: %s" % [kind, title])
	for kind in Codex.foes():
		assert_string_contains(Bestiary.spell(kind, [Cards.FOX, Cards.METAL]).title(), "번개")


func test_each_of_two_wisps_is_named_alone_in_the_log_and_the_hover() -> void:
	var w := Codex.stage()
	w.depth = 5
	w.tails = 20
	w.cards.assign(Cards.ALL)
	w.tiles[Grid.index(Codex.ME + Vector2i(2, 2))] = World.LANTERN
	w._changed()
	w.sense()
	var foe := FloorGen.spawn(w, &"dokkaebi", Codex.ME + Vector2i(2, 0))
	foe.hp = 99
	foe.magic.cooldown = 99
	var before := w.clone()
	var events := w.act(
		{t = &"cast", spells = [{cards = [Cards.FOX, Cards.FOX], dir = Vector2i(1, 0)}]}
	)
	for i in 3:
		events += w.act({t = &"wait"})
	var lines := "\n".join(Messages.of(before, w, events).map(Messages.plain))
	assert_string_contains(lines, "여우불이 도깨비에게 붙었다")
	assert_false(lines.contains("2발이"), lines)
	var hover := Info.plain(Info.creature(w, foe))
	assert_string_contains(hover, "여우불 붙음")
	assert_false(hover.contains("여우불 2발"), hover)


func test_one_of_two_flying_is_named_alone_in_its_hover_and_on_the_death_screen() -> void:
	var w := Codex.stage()
	var two := Spell.make([Cards.ORB, Cards.ORB, Cards.ORB, Cards.ORB])
	assert_string_contains(two.title(), "2발", "the spell keeps its count where it is cast")
	var s := Flight.spawn(w, w.player(), two, Vector2i(1, 0), 0)
	assert_false(Info.plain(SpellInfo.shot(w, s)).contains("2발"))
	var line := Banner._by(w, {by = w.player().id, spell = two.tag()})
	assert_false(line.contains("2발"), line)
