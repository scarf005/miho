class_name Sister
extends RefCounted
## 여동생: Miho's sick sister in the hut of the house (House). She is of Miho's side, stands
## where she is put and never follows her (Storeys._follows). Every COUGH rounds, a number
## the dice pick anew each time, she coughs, a noise heard COUGH_LOUD tiles (`turn`; her
## cooldown is the one Round.end counts down). On the map of houses every 저승사자 goes for her
## alone (`prey`, Mind._take_on). When she falls, by any hand, the run is lost (`fell`). When
## Miho stands beside her with the elixir (World.elixir_held) at the end of a round she lives
## through, the run ends as `rescued` (`meet`).

const KIND := &"sister"
## The least and most rounds between two coughs.
const COUGH := Vector2i(5, 15)
const COUGH_LOUD := 5
const COUGH_WORD := "콜록"


## The sister alive on the storey of `w`, or null.
static func of(w: World) -> Actor:
	for a in w.actors:
		if a.kind == KIND and a.alive():
			return a
	return null


## Whom `a` goes for on the map of houses: the sister when `a` is 저승사자, else null.
static func prey(w: World, a: Actor) -> Actor:
	return of(w) if w.depth == World.HOUSE and a.kind == &"saja" else null


## The sister's round: she coughs when her cooldown is over.
static func turn(w: World, a: Actor) -> void:
	if a.magic.cooldown > 0:
		return
	var heard := w.heard.size()
	Hearing.noise(w, a.pos, COUGH_LOUD, COUGH_WORD, true, -1)
	w.emit({t = &"cough", id = a.id, at = a.pos, heard = w.heard.size() > heard})
	a.magic.cooldown = w.rng.randi_range(COUGH.x, COUGH.y)


## The end of a round: Miho beside the sister with the elixir saves her.
static func meet(w: World) -> void:
	var sister := of(w)
	var me := w.player()
	if w.outcome != &"" or not w.elixir_held or sister == null or not me.alive():
		return
	if Grid.cheb(me.pos, sister.pos) == 1:
		w.outcome = &"rescued"
		w.emit({t = &"rescued"})


## `a` has fallen: if it is the sister, the run is lost.
static func fell(w: World, a: Actor) -> void:
	if a.kind == KIND and w.outcome == &"":
		w.outcome = &"lost"
		w.emit({t = &"lost"})
