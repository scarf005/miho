class_name Observation
extends RefCounted
## What the agent reads each turn, as plain text, built only from what Miho
## knows: it draws a World.known_clone, so a creature or projectile out of her
## sight is not in it. x grows right and y grows down from the top-left tile.
##
## Map glyphs are Palette's. Tiles in sight are drawn as on the screen;
## remembered tiles keep their glyph except floor, which is `·`, so `.` marks
## the tiles whose occupants Miho can see. Tiles she has never made out are a
## space. A creature is drawn as its Bestiary glyph and Miho as `@`. As in
## DCSS, one glyph may cover several kinds of tile (every wall is `#`); the
## colour tells them apart on the screen, and `look` tells them here.
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
## Remembered floor, so that `.` is only floor in sight.
const REMEMBERED_FLOOR := "·"
const ALERTS := ["resting", "searching", "hunting"]
const WITS := ["dull", "sharp", "cunning"]
const LEGEND := (
	"legend: ╳cracked-wall #wall(also wooden-wall, window: the tile name tells which, see look) "
	+ ":rubble .floor(in sight) ·floor(remembered) +closed-door 'open-door "
	+ "░sky ═skybridge ◎drum ◌torn-drum ;broken-lantern "
	+ '¤lantern "bamboo =floorboards ~pond(also shallow-water, mud: see look) ,ash '
	+ "¨grass ▤straw ‖reeds _flattened-reeds ◆leaves ßpillar "
	+ "◇ice ‡thorns †altar(lit or not: see look) ╫veil(fire) ¶stone-lamp ◊talisman-stand "
	+ "▒shelf(unread or read: see look) ║screen 0jar &censer "
	+ "▫courtyard 8statue ╪rotten-floorboards "
	+ "^trap-plate(alarm, collapsing-floor, fire, vine: the tile name tells which, see look) "
	+ "§fire ☲hot-ground ◦fog °steam ▓smoke •incense ¦marsh-gas <stairs !elixir "
	+ "%peach, kimchi or fallen-creature(see look) ?scroll(see look) ●○*projectile "
	+ "@Miho(or an allied 분신)"
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
	if me.guise:
		out.append("in guise as %s" % Bestiary.info(me.form).name)
	if me.talon:
		out.append("claws harm %d more" % Guise.TALON_HARM)
	if me.cloak:
		out.append("cloaked: seen only within %d tile" % Hat.REACH)
	if me.flame:
		var line := "fire creature: no harm from fire, lightning harms only wet, water harms twice"
		out.append("%s, fire spells harm %d more" % [line, Guise.FLAME_HARM])
	if me.raise:
		out.append(
			"raising the dead: a body in sight rises as an ally, until she leaves the storey"
		)
	if k.curses.has(Curse.REAPER):
		out.append("cursed: the reaper comes %d rounds sooner on this storey" % Curse.SOONER)
	if k.curses.has(Curse.SIGHT):
		out.append("cursed: creatures see %d tiles farther in the dark" % Curse.MORE_SIGHT)
	if Status.of(me) != &"":
		out.append("Miho is %s for %d rounds" % [Status.of(me), Status.rounds(me)])
	if k.outcome != &"":
		out.append("game over: " + ("won, Miho became human" if k.outcome == &"won" else "lost"))
	out.append_array(_map(k))
	out.append(LEGEND)
	var foes := _foes(k)
	out.append("creatures in sight:" if not foes.is_empty() else "creatures in sight: none")
	for a: Actor in foes:
		out.append(_creature(k, a))
	for a: Actor in k.actors.filter(func(b): return b.ally() and b.alive()):
		out.append("ally: " + _ally(k, a))
	var shots := k.shots.filter(func(s): return not s.gone)
	if not shots.is_empty():
		out.append("projectiles in sight:")
		for s: Shot in shots:
			out.append(_shot(k, s))
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
	var list := k.actors.filter(func(a): return a.faction == Actor.HEAVEN and a.alive())
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
		if k.hot.has(p):
			return Palette.HOT[0]
		if k.gas.has(p):
			return Palette.GAS[k.gas[p].x][0]
	if k.peaches.has(p):
		return Palette.PEACH[0]
	if Jars.spots(k).has(p):
		return Palette.KIMCHI[0]
	if Scrolls.card_at(k, p) != &"":
		return Palette.SCROLL
	if k.bodies.has(p) and k.bodies[p].met:
		return Palette.BODY[0]
	if p == k.stairs:
		return Palette.STAIRS[0]
	if p == k.elixir:
		return Palette.ELIXIR[0]
	var t := k.tile(p)
	return REMEMBERED_FLOOR if t == World.FLOOR and not in_sight else Palette.TILES[t][0]


## One of Miho's side: it fights on its own, and walking into it trades places.
static func _ally(k: World, a: Actor) -> String:
	var line := (
		"%s %s (%d,%d) hp %d/%d" % [a.info().glyph, a.info().name, a.pos.x, a.pos.y, a.hp, a.max_hp]
	)
	if Bestiary.mana(a.kind) > 0:
		line += ", tails %d/%d" % [a.mana, Bestiary.mana(a.kind)]
	for cast: Array in a.repertoire():
		line += ", casts " + Spell.make(cast).shown()
	if a.fighting():
		var rival := k.actor(a.rival)
		line += ", fighting " + (rival.info().name if rival != null else "something unseen")
	if not Legal.makes_way(a):
		line += ", cannot trade places"
	if Raise.risen(a):
		line += ", stays on this storey"
	return line


static func _creature(k: World, a: Actor) -> String:
	var line := (
		"%s %s (%d,%d) hp %d/%d, %s"
		% [a.info().glyph, a.info().name, a.pos.x, a.pos.y, a.hp, a.max_hp, ALERTS[a.alert]]
	)
	if Guise.knows(k, a):
		line += ", sees Miho"
	elif k.sees(a, k.player().pos):
		line += (
			", sees Miho but not through her "
			+ ("guise" if Guise.fools(a, k.player()) else "cloak")
		)
	elif a.alert == Actor.HUNT and not a.info().get("hunts", false):
		line += ", tracking scent"
	for c in [
		[a.blind, "blind"],
		[a.rooted, "rooted"],
		[a.stunned, "stunned"],
		[a.wet, "wet"],
		[a.alight, "alight"],
		[a.frozen, "frozen"]
	]:
		if c[0] > 0:
			line += ", %s %d" % [c[1], c[0]]
	if a.wary > 0:
		line += ", wary %d" % a.wary
	line += ", wits " + WITS[Bestiary.wits(a.kind)]
	var weak := Bestiary.weak_to(a.kind)
	if not weak.is_empty():
		line += ", weak to " + ", ".join(weak)
	if a.fighting():
		var rival := k.actor(a.rival)
		line += ", fighting " + (rival.info().name if rival != null else "something unseen")
	if a.leader != 0:
		var lead := k.actor(a.leader)
		line += ", follows " + (lead.info().name if lead != null else "something unseen")
	elif k.actors.any(func(b): return b.leader == a.id):
		line += ", leads a band"
	if a.drumming():
		line += ", running to the drum at (%d,%d)" % [a.drum.x, a.drum.y]
	for plan in a.intent:
		line += (
			", charging %s aimed %s"
			% [Bestiary.spell(a.kind, plan.cards).title(), NAMES.get(plan.dir, "?")]
		)
	return line


static func _shot(k: World, s: Shot) -> String:
	var side := "Miho's" if s.faction == Actor.FOX else "heaven's"
	var line := (
		"%s (%d,%d) %s %s dir %s, harm %d, speed %d"
		% [
			Palette.shot_glyph(s.spell),
			s.pos.x,
			s.pos.y,
			side,
			s.spell.title(),
			NAMES.get(s.dir, "none"),
			Guise.shot_harm(k, s),
			s.pace() if s.dir != Vector2i.ZERO else 0
		]
	)
	var t := k.actor(s.target)
	if t != null:
		line += ", chasing %s (%d,%d), turns %d°" % [t.info().name, t.pos.x, t.pos.y, s.turn]
	if s.life > 0:
		line += ", %d rounds left" % s.life
	return line


## The steps Miho may take, each with what stands there: a creature her claws
## strike, a lantern or window she knocks, or a closed door she slides open; then
## the open doors she may close.
static func _moves(k: World) -> String:
	var out := []
	for d in Grid.DIRS:
		if k.can({t = &"move", dir = d}):
			var to := k.player().pos + d
			var a := k.actor_at(to)
			var note := ""
			if a != null:
				note = ("(swap with %s)" if a.ally() else "(claw %s)") % a.info().name
			elif k.tile(to) == World.WINDOW:
				note = "(knock window)"
			elif Terrain.lantern(k.tile(to)):
				note = "(knock lantern)"
			elif k.tile(to) == World.DOOR:
				note = "(open door)"
			elif k.tile(to) == World.DRUM:
				note = "(tear drum)"
			elif Tiles.of(k.tile(to), "trap"):
				note = "(known trap)"
			out.append(NAMES[d] + note)
	var doors := NAMES.keys().filter(func(d): return k.can({t = &"close", dir = d}))
	var line := ", ".join(out) if not out.is_empty() else "none"
	return (
		line
		+ (
			"; close: " + ", ".join(doors.map(func(d): return NAMES[d]))
			if not doors.is_empty()
			else ""
		)
	)
