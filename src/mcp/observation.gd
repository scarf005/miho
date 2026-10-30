class_name Observation
extends RefCounted
## What the agent reads each turn, as plain text, built only from what Miho
## knows: it draws a World.known_clone, so a creature or projectile out of her
## sight is not in it. x grows right and y grows down from the top-left tile.
##
## Map glyphs are Palette's. Tiles in sight are drawn as on the screen;
## remembered tiles keep their glyph except floor, which is `.`, so `·` marks
## the tiles whose occupants Miho can see. Tiles she has never made out are a
## space. A creature is drawn as its Bestiary glyph and Miho as `@`.

const NAMES := {
	Vector2i(0, -1): "n",
	Vector2i(1, -1): "ne",
	Vector2i(1, 0): "e",
	Vector2i(1, 1): "se",
	Vector2i(0, 1): "s",
	Vector2i(-1, 1): "sw",
	Vector2i(-1, 0): "w",
	Vector2i(-1, -1): "nw",
}
const ALERTS := ["resting", "searching", "hunting"]
const LEGEND := (
	"legend: #wall ▒cracked-wall :rubble ·floor(in sight) .floor(remembered) +door 'open-door "
	+ '¤lantern "bamboo =floorboards ~pond ,ash ^fire <stairs !elixir %peach '
	+ "●○*projectile @Miho"
)


static func text(world: World) -> String:
	var k := world.known_clone()
	var me := k.player()
	var out: Array[String] = [
		(
			"storey %d/%d, round %d, hp %d/%d, tails %d/%d"
			% [k.depth, World.FLOORS, k.round_no, me.hp, me.max_hp, k.tails, k.max_tails()]
		),
		"talismans: " + ", ".join(_cards(k)),
		"Miho at (%d,%d)" % [me.pos.x, me.pos.y],
	]
	if k.outcome != &"":
		out.append("game over: " + ("won, Miho became human" if k.outcome == &"won" else "lost"))
	out.append_array(_map(k))
	out.append(LEGEND)
	var foes := _foes(k)
	out.append("creatures in sight:" if not foes.is_empty() else "creatures in sight: none")
	for a: Actor in foes:
		out.append(_creature(k, a))
	var shots := k.shots.filter(func(s): return not s.gone)
	if not shots.is_empty():
		out.append("projectiles in sight:")
		for s: Shot in shots:
			out.append(_shot(s))
	out.append("moves: " + _moves(k))
	return "\n".join(out)


## The unit step called `name`, or zero when there is no such direction.
static func dir_of(name: Variant) -> Vector2i:
	for d: Vector2i in NAMES:
		if NAMES[d] == name:
			return d
	return Vector2i.ZERO


static func _cards(k: World) -> Array:
	var out := []
	for i in k.cards.size():
		out.append("%d %s (%s)" % [i + 1, k.cards[i], Cards.NAME[k.cards[i]]])
	return out


static func _foes(k: World) -> Array:
	var me := k.player().pos
	var list := k.actors.filter(func(a): return a.faction != Actor.FOX and a.alive())
	list.sort_custom(func(a, b): return Grid.cheb(a.pos, me) < Grid.cheb(b.pos, me))
	return list


static func _map(k: World) -> Array[String]:
	var ruler := "   "
	for x in Grid.W:
		ruler += str(x % 10)
	var rows: Array[String] = ["map, x across 0-%d, y down 0-%d:" % [Grid.W - 1, Grid.H - 1], ruler]
	for y in Grid.H:
		var row := "%2d " % y
		for x in Grid.W:
			row += _glyph(k, Vector2i(x, y))
		rows.append(row.rstrip(" "))
	return rows


static func _glyph(k: World, p: Vector2i) -> String:
	var i := Grid.index(p)
	if k.known[i] == 0:
		return " "
	var in_sight := k.seen[i] == 1
	if in_sight:
		var a := k.actor_at(p)
		if a != null:
			return a.info().glyph
		var s := k.shot_at(p)
		if s != null:
			return Palette.shot_glyph(s.spell)
		if k.burning.has(p):
			return Palette.BURNING[0]
	if k.peaches.has(p):
		return Palette.PEACH[0]
	if p == k.stairs:
		return Palette.STAIRS[0]
	if p == k.elixir:
		return Palette.ELIXIR[0]
	var t := k.tile(p)
	if t == World.DOOR and in_sight and not k.opaque(p):
		return Palette.OPEN_DOOR
	return "." if t == World.FLOOR and not in_sight else Palette.TILES[t][0]


static func _creature(k: World, a: Actor) -> String:
	var line := (
		"%s %s (%d,%d) hp %d/%d, %s"
		% [a.info().glyph, a.info().name, a.pos.x, a.pos.y, a.hp, a.max_hp, ALERTS[a.alert]]
	)
	if k.sees(a, k.player().pos):
		line += ", sees Miho"
	for c in [[a.blind, "blind"], [a.rooted, "rooted"], [a.stunned, "stunned"]]:
		if c[0] > 0:
			line += ", %s %d" % [c[1], c[0]]
	if not a.intent.is_empty():
		line += ", charging %s aimed %s" % [Spell.make(a.intent).title(), NAMES.get(a.aim, "?")]
	return line


static func _shot(s: Shot) -> String:
	var side := "Miho's" if s.faction == Actor.FOX else "heaven's"
	return (
		"%s (%d,%d) %s %s dir %s, harm %d"
		% [
			Palette.shot_glyph(s.spell),
			s.pos.x,
			s.pos.y,
			side,
			s.spell.title(),
			NAMES.get(s.dir, "none"),
			s.spell.damage(s.distance())
		]
	)


## The steps Miho may take, each with what stands there: a creature her claws
## strike, or a lantern she knocks.
static func _moves(k: World) -> String:
	var out := []
	for d in Grid.DIRS:
		if k.can({t = &"move", dir = d}):
			var a := k.actor_at(k.player().pos + d)
			var note := ""
			if a != null:
				note = "(claw %s)" % a.info().name
			elif Terrain.lantern(k.tile(k.player().pos + d)):
				note = "(knock lantern)"
			out.append(NAMES[d] + note)
	return ", ".join(out) if not out.is_empty() else "none"
