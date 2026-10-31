class_name Actor
extends RefCounted
## A creature on the board. Faction FOX is Miho; HEAVEN is everything else.
## A heaven creature is resting (asleep, unless it patrols), searching a spot it
## heard or saw something at, or hunting Miho after it saw her.

const FOX := 0
const HEAVEN := 1

const REST := 0
const SEARCH := 1
const HUNT := 2

var id := 0
var kind := &""
var faction := HEAVEN
var pos := Vector2i.ZERO
var hp := 1
var max_hp := 1
var cooldown := 0
## Cards of the spell being charged; empty when not charging.
var intent: Array[StringName] = []
var aim := Vector2i.ZERO
var rooted := 0
var stunned := 0
var blind := 0
var casts := 0
var acted := 0
var alert := REST
## Where it last saw Miho, or the spot it is searching.
var target := Vector2i.ZERO
var lost := 0
## Rounds left of wariness after being hurt: it does not go back to rest, and
## notices Miho one tile farther in the dark.
var wary := 0
## The id of the hostile projectile it saw and reacted to last.
var noted := 0
## The ids of the changes (Notice) it has seen and reacted to.
var marked: Array[int] = []
var sees_me := false
## A guard (Yard) never sleeps: it keeps its eyes open at its post.
var guard := false
## The drum it runs to strike instead of attacking (Drums), or (-1, -1).
var drum := Vector2i(-1, -1)
## Where it rests, and where a patrol is heading.
var home := Vector2i.ZERO
var post := Vector2i.ZERO
## The creature of another group it fights (Mind.provoke), 0 for none; the
## rounds left of the fight; where it last saw that creature.
var rival := 0
var grudge := 0
var rival_at := Vector2i.ZERO


func alive() -> bool:
	return hp > 0


## Resting at its home with its eyes shut: it sees nothing, even the tiles next
## to it, until noise or a wound wakes it. One that walks while resting (a
## patrol, or one on its way home) is awake, and one that always knows where
## Miho is (`hunts`), or guards a yard (`guard`), never sleeps.
func asleep() -> bool:
	return (
		faction == HEAVEN
		and alert == REST
		and pos == home
		and not info().get("patrol", false)
		and not info().get("hunts", false)
		and not guard
	)


## Fighting another creature of heaven in place of Miho.
func fighting() -> bool:
	return rival != 0 and grudge > 0


## Hunting Miho by way of a drum.
func drumming() -> bool:
	return alert == HUNT and drum != Vector2i(-1, -1)


func info() -> Dictionary:
	return Bestiary.info(kind)


func next_cast() -> Array:
	var list: Array = info().get("casts", [])
	return list[casts % list.size()] if not list.is_empty() else []


func clone() -> Actor:
	var a := Actor.new()
	for p in [
		"id",
		"kind",
		"faction",
		"pos",
		"hp",
		"max_hp",
		"cooldown",
		"aim",
		"rooted",
		"stunned",
		"blind",
		"casts",
		"acted",
		"alert",
		"target",
		"lost",
		"wary",
		"noted",
		"sees_me",
		"guard",
		"drum",
		"home",
		"post",
		"rival",
		"grudge",
		"rival_at",
	]:
		a.set(p, get(p))
	a.intent = intent.duplicate()
	a.marked.assign(marked)
	return a
