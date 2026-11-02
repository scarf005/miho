class_name Raise
extends RefCounted
## 사령술 (Guise.RAISE): while it is on, a body (World.bodies, Notice.fallen) Miho sees at
## the end of a round rises as an ally, whether it fell in her sight or lay there before,
## as DCSS Death Channel and Animate Dead raise the dead for their caster. No chance is
## involved. It takes the body's tile or the first free one next to it (`spot_of`); with
## none free it stays a body and tries again each round she sees it. What falls into the
## sky leaves no body, and an ally leaves none (Harm.hurt), so what rises does not rise
## again. It stays on the storey it rose on when she leaves (Storeys.followers), and up
## when she drops the spell.

## What rises from a body, and from a body of a creature with STRONG's health or more on
## this storey.
const WEAK := &"gaekgwi"
const STRONG := &"dalgyal"
const GROUP := &"undead"
## The rule as the 도감 tells it (Info.CONDITIONS).
const TOLD := [
	"지속 시간: 다음 층까지",
	[
		"시야에 보이는 시체를 아군으로 되살린다. 강한 적은 %s으로, 약한 적은 %s로.",
		Bestiary.KINDS[STRONG]["name"],
		Bestiary.KINDS[WEAK]["name"]
	],
]


## Whether a creature of `kind` is one of the dead. On Miho's side only 사령술 makes one.
static func undead(kind: StringName) -> bool:
	return Bestiary.info(kind).get("group", &"") == GROUP


## Whether `a` rose by 사령술.
static func risen(a: Actor) -> bool:
	return a.ally() and undead(a.kind)


## What rises on this storey from the body of a creature of `kind`.
static func rises(w: World, kind: StringName) -> StringName:
	var r := Bestiary.rank(w.depth)
	return STRONG if Bestiary.hp(kind, r) >= Bestiary.hp(STRONG, r) else WEAK


## Where a body at `at` rises: its tile, else the first tile next to it, none that a
## plate or fire would catch it on. (-1, -1) when none is free.
static func spot_of(w: World, at: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i.ZERO] + Grid.DIRS:
		var p := at + d
		if w.vacant(p) and not w.traps.has(p) and not w.burning.has(p):
			return p
	return Vector2i(-1, -1)


## The end of a round, once her sight is worked out: every body she sees rises, but one
## that rises for heaven (Curse).
static func tick(w: World) -> void:
	if not w.player().buffs.raise or w.outcome != &"":
		return
	for at: Vector2i in w.bodies.keys():
		var spot := spot_of(w, at)
		if w.seen[Grid.index(at)] == 1 and spot.x >= 0 and not w.bodies[at].has("rises"):
			Mind.enlist(w, FloorGen.spawn(w, rises(w, w.bodies[at].kind), spot))
			w.bodies.erase(at)
	w._changed()
