class_name RoundAnim
extends RefCounted
## What a Term shows of a round while it plays: the creatures and projectiles as its
## events move them, one event at a time, and the flashes, trails, afterimages and popups
## they leave, which outlast the round.

## Cells a popup starts above its tile, so the creature it is about stays in view.
const POPUP_ABOVE := 0.6
## Tiles of tail drawn behind a projectile.
const TRAIL := 4
const DELAY := {
	&"move": 0.05,
	&"spawn": 0.04,
	&"fly": 0.03,
	&"land": 0.05,
	&"hit": 0.1,
	&"burst": 0.1,
	&"splash": 0.22,
	&"blast": 0.25,
	&"spray": 0.25,
	&"clash": 0.1,
	&"claw": 0.16,
	&"melee": 0.16,
	&"die": 0.14,
	&"sprout": 0.16,
	&"charge": 0.08,
	&"drum": 0.3,
	&"trap": 0.2,
}
## Seconds a tile of a push (Fall) takes on average: the slide leaves fast and stops soft.
const SLIDE := 0.04
## Seconds between one arc of lightning and the next: arcs overlap, each flickering on its own.
const ARC_STAGGER := 0.03
## Seconds a tile lit up lasts, and one flickering with lightning.
const FLASH_LIFE := 0.35
const ZAP_LIFE := 0.18

## Whether a round is playing, so `actors` and `shots` are what is drawn.
var playing := false
var actors := {}
var shots := {}
var popups: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
## shot id -> the tiles it last flew through, newest last (TRAIL of them).
var trails := {}
## shot id -> true for each lightning (Spell.electric) spray of the round in play.
var _bolts := {}
## Whether the round in play has shaken the map: it shakes once.
var _shaken := false
var _term: Term


func _init(of: Term) -> void:
	_term = of


## Whether anything is left to move on screen (RedrawPace).
func moving() -> bool:
	return (
		playing
		or _term.shaking()
		or not (popups.is_empty() and flashes.is_empty() and ghosts.is_empty())
	)


## Drops what has faded by time `now`.
func expire(now: float) -> void:
	popups = popups.filter(func(p): return now - p.born < p.life)
	flashes = flashes.filter(func(f): return now - f.born < (ZAP_LIFE if f.zap else FLASH_LIFE))
	ghosts.assign(ghosts.filter(func(g): return now - g.born < Afterimage.LIFE))


## Ends the round on world `w`, with nothing in flight.
func settle(w: World) -> void:
	actors.clear()
	shots.clear()
	playing = false
	for id in trails.keys():
		if not w.shots.any(func(s): return s.id == id and s.dir != Vector2i.ZERO):
			trails.erase(id)


## Plays `events` one by one from the world `before`; `facts` are what Miho is told of them
## (Perceived.of).
func run(events: Array, before: World, facts: Array) -> void:
	var t := _term
	var told := {}
	for f in facts:
		if f.i >= 0:
			told[f.i] = f
	actors.clear()
	for a in before.actors:
		if a.alive():
			actors[a.id] = a.clone()
	shots.clear()
	for s in before.shots:
		shots[s.id] = {pos = s.pos, spell = s.spell, faction = s.faction}
	playing = true
	_shaken = false
	_bolts.clear()
	for e in events:
		if (
			e.t == &"spray" and Spell.make(e.cards).electric()
			or e.get("bolt", false) and e.t == &"spawn"
		):
			_bolts[e.shot] = true
	var passes := Afterimage.plan(events)
	var impact := Impact.of(events)
	var waits := holds(events, told)
	var drawn := {}
	for i in events.size():
		var veiled := t.veiled if t.debug.is_empty() else {}
		var left := Afterimage.copies(passes.get(i, []), actors, t.time, veiled)
		ghosts.append_array(left.filter(func(g): return t.sees(g.at)))
		if not drawn.has(i):
			apply(events[i], told.get(i, {}))
		for j: int in impact.get(i, []):
			apply(events[j], told.get(j, {}))
			drawn[j] = true
		await t.hold(waits[i])


## How long each of `events` holds the round, by index; `told` is what Miho is told of
## them, by index. Only what she is told holds, but what a touch sets off (Impact.of)
## holds where it comes; the touch itself, and one that pushes a creature, holds nothing,
## so the slide starts with it. A push holds SLIDE a tile in all, eased out (`slides`).
func holds(events: Array, told: Dictionary) -> Array[float]:
	var impact := Impact.of(events)
	var shoves := Impact.shoves(events)
	var slid := slides(events)
	var drawn := {}
	var out: Array[float] = []
	for i in events.size():
		var e: Dictionary = events[i]
		var wait: float = DELAY.get(e.t, 0.0)
		if not drawn.has(i) and not told.has(i):
			wait = 0.0
		elif _bolts.has(e.get("shot", -1)) and not drawn.has(i):
			wait = ARC_STAGGER if e.t == &"spray" else 0.0
		for j: int in impact.get(i, []):
			drawn[j] = true
		if impact.has(i) or shoves.has(i):
			wait = 0.0
		elif wait > 0.0 and slid.has(i):
			wait = slid[i]
		out.append(wait)
	return out


## By the index of each `move` of a push, how long it holds: a slide of n tiles takes
## SLIDE * n, its tiles timed by an ease out. The slide ends as Afterimage.plan's does.
static func slides(events: Array) -> Dictionary:
	var out := {}
	var steps: Array[int] = []
	var id := -1
	for i in events.size() + 1:
		var e: Dictionary = events[i] if i < events.size() else {t = &"push", id = -1}
		if e.t == &"push" or e.t in Afterimage.TURNS or e.t == &"move" and e.id != id:
			var n := steps.size()
			for k in n:
				out[steps[k]] = (
					SLIDE * n * (sqrt(1.0 - float(k) / n) - sqrt(1.0 - float(k + 1) / n))
				)
			steps.clear()
			id = e.id if e.t == &"push" else -1
		elif e.t == &"move":
			steps.append(i)
	return out


## Applies one event to what is drawn; `fact` is what Miho is told of it, or
## empty.
func apply(e: Dictionary, fact: Dictionary) -> void:
	var at: Vector2i = e.get("to", e.get("at", Vector2i(-1, -1)))
	if not Grid.inside(at) and actors.has(e.get("id", -1)):
		at = actors[e.id].pos
	if not _shaken and Shake.by(e):
		_shaken = true
		_term.shake()
	match e.t:
		&"move":
			if actors.has(e.id):
				actors[e.id].pos = e.to
		&"cast":
			if Spell.make(e.cards).gun():
				flash(at, Color(Palette.BURNING[1], 0.9))
		&"spawn":
			if not e.get("bolt", false):
				shots[e.shot] = {pos = e.at, spell = Spell.make(e.cards), faction = e.faction}
		&"fly":
			if not shots.has(e.shot):
				TermMarks.bolt(_term, e.to)
			else:
				shots[e.shot].pos = e.to
				var tail: Array = trails.get(e.shot, [])
				tail.append(e.from)
				trails[e.shot] = tail.slice(-TRAIL)
		&"stick":
			shots[e.shot] = {pos = e.at, spell = Spell.make(e.cards), faction = e.faction}
		&"ride":
			if shots.has(e.shot):
				shots[e.shot].pos = e.to
		&"burst", &"hit", &"fade", &"snuff":
			if not e.get("through", false):
				shots.erase(e.shot)
			if not _bolts.has(e.get("shot", -1)):
				flash(at, Color(1, 1, 1, 0.5))
		&"clash":
			shots.erase(e.shot)
			shots.erase(e.other)
			flash(at, Color(1, 1, 1, 0.8))
		&"push":
			flash(at, Color(1, 1, 1, 0.8))
		&"claw", &"melee", &"crash":
			flash(at, Palette.HURT)
		&"drum":
			flash(at, Color(Palette.SOUND, 0.6))
		&"trap":
			flash(at, Color(Palette.TILES[e.kind][1], 0.6))
		&"fall" when e.has("depth"):
			popups.clear()
		&"ascend", &"descend", &"trail":
			popups.clear()
		&"splash":
			for f: Array in Impact.flashes(e):
				flash(f[0], f[1], f[2])
		&"die":
			actors.erase(e.id)
		&"ally":
			var ally: Actor = _term.world.actor(e.id)
			if ally != null:
				actors[e.id] = ally.clone()
				actors[e.id].pos = at
			flash(at, Color(Palette.SIDE[0], 0.9))
		&"spray":
			var spell := Spell.make(e.cards)
			var color := Palette.card(spell.slots[0])
			for p: Vector2i in e.tiles:
				if spell.electric():
					TermMarks.bolt(_term, p)
				else:
					flash(p, Color(color, 0.8), 0.02 * Grid.cheb(p, e.at))
		&"sprout":
			for p: Vector2i in e.tiles:
				flash(p, Color(Palette.CARD[Cards.WOOD], 0.8), 0.04 * Grid.cheb(p, e.at))
		&"blast":
			for p: Vector2i in e.tiles:
				flash(p, Color(Palette.BURNING[1], 0.9), 0.03 * Grid.cheb(p, e.at))
		&"become", &"heat":
			var color: Color = Palette.HOT[1] if e.t == &"heat" else Palette.TILES[e.tile][1]
			for p: Vector2i in e.tiles:
				flash(p, Color(color, 0.8), 0.04 * Grid.cheb(p, e.at))
	if fact.is_empty():
		return
	var popup := Perceived.popup_of(fact)
	if not popup.is_empty():
		popups.append(popup.merged({born = _term.time}))
	_term.shown.emit(e, _term.cell_centre(fact.where))


## A tile lit up for a moment, starting `after` seconds from now.
func flash(at: Vector2i, color: Color, after := 0.0, zap := false) -> void:
	if _term.sees(at):
		flashes.append({at = at, color = color, born = _term.time + after, zap = zap})


## Draws the afterimages, flashes and popups over the map.
func draw() -> void:
	var t := _term
	Afterimage.draw(t, ghosts, t.time)
	for f in flashes:
		if not t.in_view(f.at) or t.time < f.born:
			continue
		var k: float = 1.0 - (t.time - f.born) / (ZAP_LIFE if f.zap else FLASH_LIFE)
		var c: Color = f.color
		t.draw_rect(
			Rect2(t.cell_of(f.at) * Term.CELL, Term.CELL),
			Color(c, c.a * k * (0.35 if f.zap else 1.0))
		)
		if f.zap:
			TermMarks.zigzag(t, t.cell_of(f.at), c)
	for p in popups:
		if not t.in_view(p.at):
			continue
		var k: float = (t.time - p.born) / p.life
		var c: Color = p.color
		var at := t.cell_of(p.at) + Vector2(0, p.get("above", -POPUP_ABOVE) - 0.6 * k)
		if p.text.length() == 1:
			t.draw_glyph(at, p.text, Color(c, 1.0 - k * k))
		else:
			t.draw_text(at, p.text, Color(c, 1.0 - k * k))
