class_name Elixir
extends RefCounted
## 영약: the tile of the elixir asks Miho whether she drinks it (`ask`; World.elixir_asked),
## and nothing else is allowed until she answers, the action drink with yes or no. Yes ends the run
## as `won`. No takes the elixir along (`keep`; World.elixir_held), on every storey from
## then on, and a run in which she keeps it can no longer end by drinking it. An answer
## takes no round.
##
## While she carries it: her tile shines as a lantern's (Light.sources); every creature of
## heaven on her storey knows where she is and hunts her (Mind.perceive); the most tails
## are TAILS on any storey and REGROWN of them come back each round (Round._regrow); and
## no 둔갑 or 은신 can be cast on her (`barred`), the ones she wore dropped as she takes it.

const NAME := "영약"
## The most tails she has while she carries it, and those that grow back each round.
const TAILS := World.FLOORS
const REGROWN := 3
## What is asked, and why a cast is refused.
const ASK := "영약을 마십니까?"
const BARRED := [Guise.GUISE, Guise.CLOAK]
const BARRED_WHY := "영약을 지니고 있다"
## The rule as the 도감 tells it (Info.CONDITIONS).
const TOLD := [
	["빛: 반지름 %d칸", Light.LANTERN_RADIUS],
	"추적: 이 층의 모든 적",
	["꼬리: 최대 %d, 초당 +%d", TAILS, REGROWN],
	["걸 수 없음: %s, %s", Guise.NAME[Guise.GUISE], Guise.NAME[Guise.CLOAK]],
]


## Miho stands on the elixir: the question waits for her answer.
static func ask(w: World, me: Actor) -> void:
	w.elixir_asked = true
	w.emit({t = &"elixir", at = me.pos})


## Whether the answer `action` is drinking it and `w` waits for one.
static func can(w: World, action: Dictionary) -> bool:
	return w.elixir_asked and action.get("yes") is bool


## Plays the answer if `action` is one that `can`; false for any other action.
static func handled(w: World, action: Dictionary) -> bool:
	if action.t != &"drink":
		return false
	w.elixir_asked = false
	if action.yes:
		w.outcome = &"won"
		w.emit({t = &"won"})
	else:
		keep(w)
	return true


## Miho takes the elixir along: it leaves its tile, the 둔갑 and 은신 she wore are
## dropped, and she has no more tails than TAILS.
static func keep(w: World) -> void:
	var me := w.player()
	w.elixir = Vector2i(-1, -1)
	w.elixir_held = true
	for kind: StringName in BARRED:
		if Guise.worn(w, me).has(kind):
			Guise.dispel(w, me, kind)
	w.tails = mini(w.tails, TAILS)
	w._changed()
	w.sense()


## Whether `spell`, cast with no direction, is a 둔갑 or 은신 that `w` bars.
static func barred(w: World, spell: Spell, dir: Vector2i) -> bool:
	return w.elixir_held and dir == Vector2i.ZERO and BARRED.has(Guise.kind(spell))
