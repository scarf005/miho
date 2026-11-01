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
