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
## The spells being charged, each {cards, dir}; empty when not charging.
var intent: Array[Dictionary] = []
## The rank of the storey it came to (Bestiary.rank): what it casts and its health.
var rank := 1
var rooted := 0
var stunned := 0
var blind := 0
## Rounds left of each status (Status).
var wet := 0
var alight := 0
var frozen := 0
var casts := 0
## The mana it has left to pay for spells with (Bestiary mana).
var mana := 0
## Rounds counted towards its next mana (Mind._regrow).
var regrow := 0
var acted := 0
var alert := REST
## Where it last saw Miho, or the spot it is searching.
var target := Vector2i.ZERO
var lost := 0
## Rounds left of wariness after being hurt: it does not go back to rest, and
## notices Miho one tile farther in the dark.
var wary := 0
## The ids of the changes (Notice) it has seen and reacted to.
var marked: Array[int] = []
var sees_me := false
## A guard (Yard) stands at its post: its state reads guarding.
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
## The id of the leader of its band (FloorGen.bands), 0 for none; it is gone
## when the leader falls (Mind.forget).
var leader := 0
## 둔갑 (Guise): the kind of the last creature of heaven that fell, the kind
## it looks like, whether it is in guise, and the rounds in a row it has stood
## next to a creature of heaven in guise.
var prey := &""
var form := &""
var guise := false
var beside := 0
## Whether it holds 쇠발톱 (her claws harm more) and 은신 (the hat's rule, Hat).
var talon := false
var cloak := false


func alive() -> bool:
	return hp > 0


## Resting at its home with its eyes shut: it sees nothing, even the tiles next
## to it, until noise or a wound wakes it. One that walks while resting (a
## patrol, or one on its way home) is awake, and one that always knows where
## Miho is (`hunts`) or cannot walk (a 장승, `move` static) never sleeps.
func asleep() -> bool:
	return alert == REST and pos == home and sleeps()


## Whether it can sleep at all: a creature of heaven that does not patrol, always
## hunt or stand fixed (the tags 순찰, 위치 감지 and 고정).
func sleeps() -> bool:
	return (
		faction == HEAVEN
		and not info().get("patrol", false)
		and not info().get("hunts", false)
		and info().get("move", &"static") != &"static"
	)


## Fighting another creature of heaven in place of Miho.
func fighting() -> bool:
	return rival != 0 and grudge > 0


## Resting on a patrol in the train of its leader (Mind.rest). One that does not
## patrol sleeps at its own home, band or not.
func following() -> bool:
	return faction == HEAVEN and leader != 0 and info().get("patrol", false)


## Hunting Miho by way of a drum.
func drumming() -> bool:
	return alert == HUNT and drum != Vector2i(-1, -1)


func info() -> Dictionary:
	return Bestiary.info(kind)


## Every spell it casts at its rank (Bestiary.casts).
func repertoire() -> Array:
	return Bestiary.casts(kind, rank)


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
		"rank",
		"rooted",
		"stunned",
		"blind",
		"wet",
		"alight",
		"frozen",
		"casts",
		"mana",
		"regrow",
		"acted",
		"alert",
		"target",
		"lost",
		"wary",
		"sees_me",
		"guard",
		"drum",
		"home",
		"post",
		"rival",
		"grudge",
		"rival_at",
		"leader",
		"prey",
		"form",
		"guise",
		"beside",
		"talon",
		"cloak",
	]:
		a.set(p, get(p))
	a.intent = intent.duplicate(true)
	a.marked.assign(marked)
	return a
