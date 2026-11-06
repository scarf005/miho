class_name Curse
extends RefCounted
## What a 제웅 (Jars), torn, puts on Miho: one of three, picked by the world's dice from those
## that would change something now (`_open`).
##
## REAPER: 저승사자 comes SOONER rounds sooner, its omen still LEAD rounds before it. When the
## omen has been told, or is due this round, it comes at the end of this round. Every storey has
## its own clock, so World.curses keeps the new round of its arrival, always a round still to
## come, and `_reaper` can compare with `==`. Once it has come the curse is not picked, nor on
## the top storey, where it never comes.
##
## AGAIN: when the 저승사자 this clock sent has fallen, the clock starts again: the next one
## comes World.REAPER_AGAIN rounds later at World.REAPER_FAR tiles (Chebyshev) from the target
## (`target`), then after half the rounds and at half the tiles each time, never under 1. Each
## is counted from the one before, living or not, and told by an omen LEAD rounds before only
## when it comes after more than LEAD rounds. It hunts at once. The ones the elixir brings
## (Collapse) run apart and start nothing. A curse of REAPER hastens only the first.
##
## SIGHT: creatures of heaven see MORE_SIGHT tiles farther in the dark (Sight.reach), which is
## what lets one notice her where she stands unlit. Her own sight stays.
##
## Both lie on the storey she was on (World.curses, kept by Storeys), as its clock does: they
## hold there and come back with it. Another doll on that storey brings the reaper sooner
## again; it does not pick SIGHT twice, which would change nothing.
##
## BODY: a body lies on the jar's tile (World.bodies) for RISE_ROUNDS, then gets up as a
## creature of heaven, Raise.WEAK or from storey STRONG_FROM up Raise.STRONG, on its tile or
## the first free one beside it (Raise.spot_of). With none free it stays a body and tries again
## each round. It wakes searching where it stands, so it hunts her once it sees her. 사령술
## does not take it (Raise.tick).

const REAPER := &"reaper"
const SIGHT := &"sight"
const BODY := &"body"
## The curses by the name the 도감 gives them, and the status row the lasting ones.
const NAME := {REAPER: "저승의 저주", SIGHT: "시선의 저주", BODY: "객귀의 저주"}
## Rounds 저승사자 comes sooner.
const SOONER := 100
## Rounds its omen comes before it.
const LEAD := World.REAPER_ARRIVES - World.REAPER_OMEN
## Tiles farther creatures of heaven see in the dark.
const MORE_SIGHT := 2
## Rounds a body lies before it rises: one second (the clock counts one a round).
const RISE_ROUNDS := 1
## The storey from which a body rises as Raise.STRONG.
const STRONG_FROM := 5
## What a curse does, as the 도감 tells it (Info.CONDITIONS).
const ONLY_THERE := "걸린 층에서만 효과가 있다."
const TOLD := {
	REAPER:
	[
		["%s: %d초 일찍 옴", Bestiary.KINDS[&"saja"]["name"], SOONER],
		["알림: 오기 %d초 전", LEAD],
		"이미 오는 중이면 바로 나타난다.",
		ONLY_THERE,
	],
	SIGHT: [["적의 어두운 곳 시야: +%d칸", MORE_SIGHT], ONLY_THERE],
	BODY:
	[
		["시체: %d초 뒤 되살아남", RISE_ROUNDS],
		["되살아난 적: %s", Bestiary.KINDS[Raise.WEAK]["name"]],
		["%d층부터: %s", STRONG_FROM, Bestiary.KINDS[Raise.STRONG]["name"]],
	],
}


## The doll that stood at `at` has just torn: one curse falls on her.
static func strike(w: World, at: Vector2i) -> void:
	var what := pick(w)
	match what:
		REAPER:
			_hasten(w)
			w.emit({t = &"curse", what = what})
		SIGHT:
			w.curses[SIGHT] = true
			w.emit({t = &"curse", what = what})
		BODY:
			var body := Notice.lay(w, Raise.STRONG if w.depth >= STRONG_FROM else Raise.WEAK, at)
			body.rises = w.round_no + RISE_ROUNDS
			w.emit({t = &"curse", what = what, at = at})


## The curse the world's dice pick now.
static func pick(w: World) -> StringName:
	var open := _open(w)
	return open[w.rng.randi_range(0, open.size() - 1)]


## The curses that would change something now.
static func _open(w: World) -> Array[StringName]:
	var out: Array[StringName] = [BODY]
	if w.depth < World.FLOORS and w.round_no + 1 < arrival(w):
		out.push_front(REAPER)
	if not w.curses.has(SIGHT):
		out.append(SIGHT)
	return out


## The lasting curses on this storey, in the order of NAME.
static func worn(w: World) -> Array:
	return NAME.keys().filter(func(c): return w.curses.has(c))


## The round 저승사자 arrives on this storey.
static func arrival(w: World) -> int:
	return w.curses.get(REAPER, World.REAPER_ARRIVES)


## Tiles farther a creature of heaven sees in the dark on this storey.
static func sight_bonus(w: World) -> int:
	return MORE_SIGHT if w.curses.has(SIGHT) else 0


static func _hasten(w: World) -> void:
	var left := arrival(w) - w.round_no - 1
	w.curses[REAPER] = w.round_no + 1 + (0 if left <= LEAD else maxi(LEAD, left - SOONER))


## The end of a round, its clock moved on.
static func tick(w: World) -> void:
	if w.outcome != &"":
		return
	_rise(w)
	if w.depth < World.FLOORS:
		_reaper(w)
		_again(w)


static func _rise(w: World) -> void:
	for at: Vector2i in w.bodies.keys():
		var body: Dictionary = w.bodies[at]
		var spot := Raise.spot_of(w, at)
		if w.round_no > body.get("rises", w.round_no) and spot.x >= 0:
			var a := FloorGen.spawn(w, body.kind, spot)
			a.brain.alert = Actor.SEARCH
			a.brain.target = spot
			w.bodies.erase(at)
			w.emit({t = &"rise", id = a.id, at = spot, kind = a.kind})


static func _reaper(w: World) -> void:
	var at := arrival(w)
	if w.round_no == at - LEAD:
		w.emit({t = &"omen"})
	elif w.round_no == at:
		var spot := FloorGen.nearest_free(w, w.start)
		if spot.x >= 0:
			var saja := FloorGen.spawn(w, &"saja", spot)
			w.first_reaper = saja.id
			w._changed()
			w.emit({t = &"arrive", id = saja.id, at = spot})


## `a` has fallen: if it was the 저승사자 this storey's clock sent, the clock of the next starts.
static func fell(w: World, a: Actor) -> void:
	if a.id == w.first_reaper:
		w.first_reaper = -1
		w.reaper_due = w.round_no + gap(0)


## Rounds the `step`th 저승사자 after the first comes after the one before.
static func gap(step: int) -> int:
	return maxi(1, World.REAPER_AGAIN >> step)


## Tiles the `step`th 저승사자 after the first comes from its target.
static func distance(step: int) -> int:
	return maxi(1, World.REAPER_FAR >> step)


## The tile the next 저승사자 hunts and is counted from: Miho. The map of houses (#6) names
## the sister here.
static func target(w: World) -> Vector2i:
	return w.player().pos


static func _again(w: World) -> void:
	if w.reaper_due < 0:
		return
	if w.round_no == w.reaper_due - LEAD and gap(w.reaper_step) > LEAD:
		w.emit({t = &"omen"})
	if w.round_no < w.reaper_due:
		return
	var to := target(w)
	var spot := _ring(w, to, distance(w.reaper_step))
	if spot.x < 0:
		return
	var saja := FloorGen.spawn(w, &"saja", spot)
	saja.brain.alert = Actor.HUNT
	saja.brain.target = to
	w.reaper_step += 1
	w.reaper_due = w.round_no + gap(w.reaper_step)
	w._changed()
	w.emit({t = &"arrive", id = saja.id, at = spot, kind = &"saja", anywhere = true})


## A free tile `far` tiles from `to` that can be walked to from it, picked by the world's dice;
## else the nearest free one.
static func _ring(w: World, to: Vector2i, far: int) -> Vector2i:
	var reach: PackedInt32Array = Grid.search(to, Masks.floor_of(w)).dist
	var list: Array[Vector2i] = []
	for i in Grid.W * Grid.H:
		var p := Grid.at(i)
		if Grid.cheb(p, to) == far and w.vacant(p) and not w.traps.has(p) and reach[i] >= 0:
			list.append(p)
	if list.is_empty():
		return FloorGen.nearest_free(w, to)
	return list[w.rng.randi_range(0, list.size() - 1)]
