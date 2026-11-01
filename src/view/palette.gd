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
	World.FLOOR: [".", Color(0.62, 0.58, 0.52), Color(0.11, 0.1, 0.09)],
	World.WALL: ["#", Color(0.72, 0.64, 0.56), Color(0.34, 0.29, 0.26)],
	World.DOOR: ["+", Color(0.85, 0.55, 0.25), Color(0.22, 0.12, 0.05)],
	World.DOOR_OPEN: ["'", Color(0.85, 0.55, 0.25), Color(0.11, 0.08, 0.05)],
	World.LANTERN: ["¤", Color(1.0, 0.85, 0.45), Color(0.4, 0.2, 0.06)],
	World.LANTERN_OUT: ["¤", Color(0.45, 0.4, 0.34), Color(0.14, 0.1, 0.07)],
	World.BAMBOO: ['"', Color(0.45, 0.78, 0.38), Color(0.06, 0.14, 0.06)],
	World.BOARD: ["=", Color(0.72, 0.5, 0.3), Color(0.2, 0.12, 0.06)],
	World.POND: ["~", Color(0.24, 0.4, 0.9), Color(0.04, 0.08, 0.2)],
	World.ASH: [",", Color(0.45, 0.44, 0.42), Color(0.08, 0.08, 0.08)],
	World.LANTERN_BROKEN: [";", Color(0.5, 0.4, 0.3), Color(0.12, 0.09, 0.07)],
	World.WALL_CRACKED: ["#", Color(0.62, 0.5, 0.42), Color(0.27, 0.22, 0.2)],
	World.RUBBLE: [":", Color(0.55, 0.5, 0.45), Color(0.13, 0.11, 0.1)],
	World.SKY: ["░", Color(0.08, 0.1, 0.22), Color(0.012, 0.016, 0.05)],
	World.WINDOW: ["#", Color(0.7, 0.95, 1.0), Color(0.1, 0.16, 0.26)],
	World.BRIDGE: ["═", Color(0.82, 0.7, 0.5), Color(0.19, 0.13, 0.08)],
	World.DRUM: ["◎", Color(0.95, 0.4, 0.28), Color(0.24, 0.07, 0.04)],
	World.DRUM_TORN: ["◌", Color(0.5, 0.36, 0.3), Color(0.12, 0.08, 0.07)],
	World.GRASS: ["¨", Color(0.5, 0.82, 0.32), Color(0.07, 0.16, 0.06)],
	World.STRAW: ["▤", Color(0.88, 0.78, 0.38), Color(0.22, 0.18, 0.07)],
	World.REEDS: ["‖", Color(0.62, 0.74, 0.34), Color(0.12, 0.17, 0.08)],
	World.REEDS_FLAT: ["_", Color(0.5, 0.52, 0.3), Color(0.12, 0.11, 0.07)],
	World.LEAVES: ["◆", Color(0.86, 0.46, 0.2), Color(0.16, 0.08, 0.04)],
	World.SHALLOW: ["~", Color(0.5, 0.76, 1.0), Color(0.06, 0.15, 0.3)],
	World.PILLAR: ["ß", Color(0.82, 0.76, 0.66), Color(0.2, 0.18, 0.16)],
	World.WOOD_WALL: ["#", Color(0.78, 0.56, 0.32), Color(0.26, 0.15, 0.07)],
	World.ICE: ["◇", Color(0.78, 0.92, 1.0), Color(0.16, 0.25, 0.36)],
	World.THORNS: ["‡", Color(0.6, 0.74, 0.36), Color(0.1, 0.13, 0.06)],
	World.MUD: ["~", Color(0.6, 0.46, 0.3), Color(0.17, 0.12, 0.07)],
	World.TRAP_ALARM: ["^", Color(0.96, 0.82, 0.3), Color(0.2, 0.16, 0.04)],
	World.TRAP_COLLAPSE: ["^", Color(0.82, 0.62, 0.4), Color(0.12, 0.07, 0.05)],
	World.TRAP_FIRE: ["^", Color(1.0, 0.5, 0.2), Color(0.27, 0.09, 0.03)],
	World.TRAP_VINE: ["^", Color(0.45, 0.86, 0.4), Color(0.06, 0.16, 0.06)],
	World.ALTAR: ["†", Color(0.62, 0.72, 0.95), Color(0.1, 0.12, 0.2)],
	World.ALTAR_LIT: ["†", Color(0.55, 0.92, 1.0), Color(0.1, 0.3, 0.4)],
	World.VEIL: ["╫", Color(1.0, 0.5, 0.14), Color(0.4, 0.1, 0.02)],
	World.LAMP: ["¶", Color(1.0, 0.82, 0.4), Color(0.22, 0.15, 0.05)],
	World.TALISMAN: ["◊", Color(0.5, 0.95, 0.9), Color(0.08, 0.22, 0.2)],
	World.SHELF: ["▒", Color(0.95, 0.8, 0.45), Color(0.24, 0.16, 0.07)],
	World.SHELF_READ: ["▒", Color(0.55, 0.5, 0.42), Color(0.13, 0.11, 0.09)],
	World.SCREEN: ["║", Color(0.85, 0.62, 0.3), Color(0.25, 0.14, 0.06)],
	World.JAR: ["0", Color(0.78, 0.52, 0.32), Color(0.2, 0.12, 0.07)],
	World.WATER_JAR: ["0", Color(0.45, 0.7, 1.0), Color(0.06, 0.14, 0.28)],
	World.CENSER: ["&", Color(0.9, 0.75, 0.35), Color(0.24, 0.17, 0.06)],
	World.COURTYARD: ["▫", Color(0.7, 0.82, 1.0), Color(0.12, 0.15, 0.24)],
	World.STATUE: ["8", Color(0.78, 0.74, 0.66), Color(0.2, 0.18, 0.16)],
	World.BOARD_ROTTEN: ["╪", Color(0.6, 0.45, 0.32), Color(0.16, 0.1, 0.06)],
}
## A burning tile, drawn over its terrain.
const BURNING := ["§", Color(1.0, 0.55, 0.18), Color(0.45, 0.12, 0.02)]
## Hot ground (Compounds), drawn over its terrain.
const HOT := ["☲", Color(1.0, 0.42, 0.16), Color(0.32, 0.08, 0.02)]
const STAIRS := ["<", Color(0.92, 0.92, 1.0)]
const ELIXIR := ["!", Color(1.0, 0.86, 0.3)]
const PEACH := ["%", Color(1.0, 0.56, 0.62)]
## gas kind -> [glyph, colour]: the map tints a tile in sight by the colour, thicker
## with the amount; the glyph is for the text view of the map.
const GAS := {
	Gas.FOG: ["◦", Color(0.62, 0.7, 0.78)],
	Gas.STEAM: ["°", Color(0.88, 0.9, 0.96)],
	Gas.SMOKE: ["▓", Color(0.42, 0.38, 0.36)],
	Gas.INCENSE: ["•", Color(0.82, 0.7, 0.52)],
	Gas.MARSH: ["¦", Color(0.62, 0.72, 0.3)],
}
## status (Status.of) -> [glyph, colour]: the mark by a creature that holds it.
const STATUS := {
	&"wet": ["~", Color(0.5, 0.76, 1.0)],
	&"alight": ["§", Color(1.0, 0.55, 0.18)],
	&"frozen": ["◇", Color(0.78, 0.92, 1.0)],
}
## The mark a fallen creature leaves on its tile.
const BODY := ["%", Color(0.62, 0.36, 0.3)]
## Dark tiles Miho makes out by shape only.
const STARLIGHT := Color(0.05, 0.06, 0.14)
## The storey below, made out through the sky (Storeys.below).
const BELOW := Color(0.06, 0.07, 0.16)

const SIDE := [Color(0.5, 0.78, 1.0), Color(1.0, 0.36, 0.26)]
const KIND := {
	&"miho": Color(1.0, 0.94, 0.8),
	&"dokkaebi": Color(0.95, 0.42, 0.3),
	&"oedari": Color(0.9, 0.35, 0.55),
	&"bujigaengi": Color(0.95, 0.62, 0.4),
	&"bitjaru": Color(0.78, 0.7, 0.42),
	&"gamtu": Color(0.72, 0.62, 0.95),
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
## The mark by a fleeing creature, in place of the hunting one.
const FLEE_MARK := "<"
## A travel exclusion's tint and outline.
const ZONE := Color(0.85, 0.2, 0.35)
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


## How strongly gas of `amount` tints its tile: thin gas lightly, and gas thick
## enough to block sight (Gas.OPAQUE) heavily.
static func gas_alpha(amount: int) -> float:
	return 0.1 + 0.06 * amount if amount < Gas.OPAQUE else 0.35 + 0.04 * amount


## A talisman slot's colour; a compound's is the mean of its elements'.
static func card(slot: StringName) -> Color:
	var parts := Cards.made_of(slot)
	var sum := Color(0, 0, 0, 0)
	for e: StringName in parts:
		sum += CARD[e]
	return sum / parts.size()


## How a spell shows: a leap as Miho where she lands.
static func shot_glyph(spell: Spell) -> String:
	if spell.shape == Spell.LEAP:
		return Bestiary.info(&"miho").glyph
	if spell.orb:
		return "●"
	return "○" if spell.has(Cards.WATER) else "*"


static func shot_color(spell: Spell, faction: int) -> Color:
	if spell.has(Cards.WATER):
		return CARD[Cards.WATER]
	if spell.has(Cards.FIRE):
		return CARD[Cards.FIRE]
	return SIDE[faction]
