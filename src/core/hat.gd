class_name Hat
extends RefCounted
## 감투, the invisibility hat of the dokkaebi tales. A creature that wears one
## (Bestiary hat) is made out only from REACH tile away, or while a wisp clings
## to it (Elements.stick), the red cloth of the tale. Seeing its tile is not
## seeing it, so whoever asks whether a creature is seen asks here: Miho's map,
## hover, log, sidebar, travel and fight, the agent's observation, and the
## creatures that look for a foe (homing wisps, roots, a feud).

const REACH := 1


## Whether the hat of `a` hides it from someone standing at `from`.
static func hidden(w: World, a: Actor, from: Vector2i) -> bool:
	return (
		a.info().get("hat", false)
		and Grid.cheb(a.pos, from) > REACH
		and not w.shots.any(func(s): return s.host == a.id and not s.gone)
	)


## Whether Miho sees creature `a`: she sees its tile and no hat hides it.
static func shown(w: World, a: Actor) -> bool:
	return w.seen[Grid.index(a.pos)] == 1 and not hidden(w, a, w.player().pos)


## Whether `by` sees creature `a`, and knows it through any guise (Guise).
static func sees(w: World, by: Actor, a: Actor) -> bool:
	return w.sees(by, a.pos) and not hidden(w, a, by.pos) and not Guise.fools(by, a)


## The ids of the hat wearers Miho does not see now.
static func unseen(w: World) -> Dictionary:
	var out := {}
	for a in w.actors:
		if a.alive() and a.info().get("hat", false) and not shown(w, a):
			out[a.id] = true
	return out
