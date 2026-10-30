class_name Palette
extends RefCounted
## Glyphs and colours. Tiles are drawn at the colour of the light on them
## (Brogue CE: surface colour times light); out of sight they fall back to a
## dim memory blue. Miho's side reads blue, heaven's side red, everywhere.
## Talismans of the five elements wear 오방색 (목 청, 화 적, 토 황, 금 백, 수 흑).

const VOID := Color("#000000")
const MEMORY_FG := Color(0.1, 0.11, 0.24)
const MEMORY_BG := Color(0.015, 0.015, 0.05)
## Faint blue light of fox eyes on tiles near Miho.
const NIGHT := Vector3(0.1, 0.13, 0.24)

## tile -> [glyph, foreground, background]
const TILES := {
	World.FLOOR: ["·", Color(0.62, 0.58, 0.52), Color(0.11, 0.1, 0.09)],
	World.WALL: ["#", Color(0.72, 0.64, 0.56), Color(0.34, 0.29, 0.26)],
	World.DOOR: ["+", Color(0.85, 0.55, 0.25), Color(0.22, 0.12, 0.05)],
	World.LANTERN: ["¤", Color(1.0, 0.85, 0.45), Color(0.4, 0.2, 0.06)],
	World.LANTERN_OUT: ["¤", Color(0.45, 0.4, 0.34), Color(0.14, 0.1, 0.07)],
}
const OPEN_DOOR := "'"
const STAIRS := ["<", Color(0.92, 0.92, 1.0)]
const ELIXIR := ["!", Color(1.0, 0.86, 0.3)]
const PEACH := ["%", Color(1.0, 0.56, 0.62)]
## Dark tiles Miho makes out by shape only.
const STARLIGHT := Color(0.05, 0.06, 0.14)

const SIDE := [Color(0.5, 0.78, 1.0), Color(1.0, 0.36, 0.26)]
const KIND := {
	&"miho": Color(1.0, 0.94, 0.8),
	&"dokkaebi": Color(0.95, 0.42, 0.3),
	&"jangseung": Color(0.82, 0.64, 0.42),
	&"imugi": Color(0.5, 0.8, 0.55),
	&"bulgae": Color(1.0, 0.55, 0.2),
	&"haetae": Color(0.55, 0.85, 0.95),
	&"cheonha": Color(0.4, 0.62, 1.0),
	&"jiha": Color(0.95, 0.95, 0.9),
	&"bulgasari": Color(0.95, 0.82, 0.35),
	&"cheonnyeon": Color(0.8, 0.5, 1.0),
	&"saja": Color(0.75, 0.75, 0.8),
}
const CARD := {
	Cards.FOX: Color(0.6, 0.82, 1.0),
	Cards.ORB: Color(0.82, 0.68, 1.0),
	Cards.WOOD: Color(0.3, 0.55, 1.0),
	Cards.FIRE: Color(1.0, 0.32, 0.25),
	Cards.EARTH: Color(1.0, 0.82, 0.3),
	Cards.METAL: Color(0.96, 0.96, 0.92),
	Cards.WATER: Color(0.42, 0.42, 0.55),
}
const HURT := Color(1.0, 0.25, 0.2)
const SOUND := Color(1.0, 0.78, 0.4)
const ALERT := [Color(0, 0, 0, 0), Color(1.0, 0.85, 0.3), Color(1.0, 0.25, 0.2)]
const ALERT_MARK := ["", "?", "!"]
const TEXT := Color(0.8, 0.78, 0.72)
const DIM := Color(0.35, 0.34, 0.33)
## Bolt glyphs by direction, as Brogue draws them.
const BOLT := {
	Vector2i(0, -1): "|",
	Vector2i(0, 1): "|",
	Vector2i(1, 0): "-",
	Vector2i(-1, 0): "-",
	Vector2i(1, -1): "/",
	Vector2i(-1, 1): "/",
	Vector2i(1, 1): "\\",
	Vector2i(-1, -1): "\\",
}


static func shot_glyph(spell: Spell) -> String:
	if spell.orb:
		return "●"
	return "○" if spell.has(Cards.WATER) else "*"


static func shot_color(spell: Spell, faction: int) -> Color:
	if spell.has(Cards.WATER):
		return CARD[Cards.WATER]
	if spell.has(Cards.FIRE):
		return CARD[Cards.FIRE]
	return SIDE[faction]
