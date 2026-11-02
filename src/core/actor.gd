class_name Actor
extends Entity
## A creature on the board. A heaven creature is resting (asleep, unless it patrols),
## searching a spot it heard or saw something at, or hunting Miho after it saw her.

const REST := 0
const SEARCH := 1
const HUNT := 2

var kind := &""
var hp := 1
var max_hp := 1
## The rank of the storey it came to (Bestiary.rank): what it casts and its health.
var rank := 1
## Rounds left of each condition and status (Status).
var ailments: Ailments
## What it casts with and charges (Magic).
var magic: Magic
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
## Whom it fights and follows (Ties).
var ties: Ties
## The spells it holds on itself (Guise).
var buffs: Buffs


## `bare` leaves the parts a copy replaces unbuilt (`clone`).
func _init(bare := false) -> void:
	if not bare:
		ailments = Ailments.new()
		magic = Magic.new()
		ties = Ties.new()
		buffs = Buffs.new()


func alive() -> bool:
	return hp > 0


func is_miho() -> bool:
	return kind == &"miho"


## One of Miho's side but not Miho (Mind.enlist).
func ally() -> bool:
	return faction == FOX and not is_miho()


## Resting at its home with its eyes shut: it sees nothing, even the tiles next
## to it, until noise or a wound wakes it. One that walks while resting (a
## patrol, or one on its way home) is awake, and one that always knows where
## Miho is (`hunts`) or cannot walk (a 장승, `move` static) never sleeps.
func asleep() -> bool:
	return alert == REST and pos == home and sleeps()


## Whether it can sleep at all: a creature of heaven that does not patrol, always
## hunt, stand fixed or live under water (the tags 순찰, 위치 감지, 고정 and 수중).
func sleeps() -> bool:
	return (
		faction == HEAVEN
		and not info().get("patrol", false)
		and not info().get("hunts", false)
		and info().get("move", &"static") != &"static"
		and not Bestiary.swims(kind)
	)


## Fighting another creature of heaven in place of Miho.
func fighting() -> bool:
	return ties.rival != 0 and ties.grudge > 0


## Resting in the train of its leader (Mind.rest): one on patrol, or an ally behind
## Miho. One that does not patrol sleeps at its own home, band or not.
func following() -> bool:
	return ties.leader != 0 and (faction == FOX or info().get("patrol", false))


## Hunting Miho by way of a drum.
func drumming() -> bool:
	return alert == HUNT and drum != Vector2i(-1, -1)


func info() -> Dictionary:
	return Bestiary.info(kind)


## The kind whose elements it meets a spell with (Bestiary.weak, absorbs, burns):
## its own, but for Miho as 불여우 (Guise.FLAME_KIND).
func nature_kind() -> StringName:
	return Guise.FLAME_KIND if buffs.flame else kind


## Every spell it casts: the one it was imprinted with, else those of its rank
## (Bestiary.casts).
func repertoire() -> Array:
	return [magic.imprint] if not magic.imprint.is_empty() else Bestiary.casts(kind, rank)


func clone() -> Actor:
	var a := Actor.new(true)
	a.id = id
	a.kind = kind
	a.faction = faction
	a.pos = pos
	a.hp = hp
	a.max_hp = max_hp
	a.rank = rank
	a.acted = acted
	a.alert = alert
	a.target = target
	a.lost = lost
	a.wary = wary
	a.sees_me = sees_me
	a.guard = guard
	a.drum = drum
	a.home = home
	a.post = post
	a.ailments = ailments.copy()
	a.magic = magic.copy()
	a.ties = ties.copy()
	a.buffs = buffs.copy()
	a.marked.assign(marked)
	return a
