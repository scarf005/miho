class_name Hearing
extends RefCounted
## Information comes from light and sound. Noise spreads around walls; Miho hears
## everything in range, heaven creatures go to search where they heard an alarm
## (Mind; how they read a projectile depends on their wits).


## Spreads a noise around walls. Miho hears every noise in range but her side's;
## heaven creatures that hear an alarm go to search its spot, or `spot` when given.
static func noise(
	w: World, at: Vector2i, loud: int, word: String, alarm: bool, by: int, spot := Vector2i(-1, -1)
) -> void:
	if loud <= 0:
		return
	var dist: PackedInt32Array = Grid.search(at, Masks.heard(w), loud).dist
	var me := w.player()
	var d := dist[Grid.index(me.pos)]
	var maker := w.actor(by)
	var heard_it := (maker == null or maker.faction != me.faction) and d >= 0 and d <= loud
	if heard_it:
		w.heard.append({at = at, word = word})
	w.emit({t = &"noise", at = at, word = word, loud = loud, heard = heard_it})
	if not alarm:
		return
	for a in w.actors:
		if (
			a.alive()
			and a.faction == Actor.HEAVEN
			and a.id != by
			and a.alert != Actor.HUNT
			and not a.info().get("deaf", false)
		):
			var da := dist[Grid.index(a.pos)]
			if da >= 0 and da <= loud:
				a.alert = Actor.SEARCH
				a.target = at if spot.x < 0 else spot
				a.lost = 0
