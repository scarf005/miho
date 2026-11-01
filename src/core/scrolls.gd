class_name Scrolls
extends RefCounted
## The scroll (주문서) a fallen creature drops for the talisman it yields, when
## Miho does not hold it. It lies in World.sites as {kind, at, card} on the
## corpse's tile, or the nearest tile that can hold one when that tile cannot:
## sky, a pond, a wall, the stairs, the elixir, a peach, a plate, another site
## or a creature. Miho takes the talisman by coming onto the tile (World.arrive);
## creatures, fire and water leave it be. Where no tile can hold it, none drops.
## Ground that turns to sky under it sends it the same way (`displace`).


## The card of the scroll on p, or &"".
static func card_at(w: World, p: Vector2i) -> StringName:
	for site: Dictionary in w.sites:
		if site.kind == &"scroll" and site.at == p:
			return site.card
	return &""


## Where the scrolls lie.
static func spots(w: World) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for site: Dictionary in w.sites:
		if site.kind == &"scroll":
			out.append(site.at)
	return out


## Creature `a` has just fallen: it drops its scroll.
static func drop(w: World, a: Actor) -> void:
	var card: StringName = a.info().get("drop", &"")
	if card == &"" or w.cards.has(card):
		return
	var at := _spot(w, a.pos)
	if at.x < 0:
		return
	w.sites.append({kind = &"scroll", at = at, card = card})
	w.emit({t = &"scroll", card = card, at = at})


## Miho has come onto her tile: she takes the scroll there, once.
static func arrive(w: World, me: Actor) -> void:
	for site: Dictionary in w.sites.duplicate():
		if site.kind == &"scroll" and site.at == me.pos:
			w.sites.erase(site)
			if not w.cards.has(site.card):
				w.cards.append(site.card)
				w.emit({t = &"card", card = site.card, at = site.at})


## `tiles` have just turned to sky: each scroll, kimchi and peach on them moves to the
## tile a scroll would drop on (`_spot`), and is lost where there is none.
static func displace(w: World, tiles: Array) -> void:
	for site: Dictionary in w.sites.duplicate():
		if site.kind in [&"scroll", Jars.KIMCHI] and tiles.has(site.at):
			site.at = _spot(w, site.at)
			if site.at.x < 0:
				w.sites.erase(site)
	for p: Vector2i in w.peaches.duplicate():
		if tiles.has(p):
			w.peaches.erase(p)
			var at := _spot(w, p)
			if at.x >= 0:
				w.peaches.append(at)


static func _holds(w: World, p: Vector2i) -> bool:
	return (
		w.open_floor(p)
		and w.actor_at(p) == null
		and p != w.stairs
		and p != w.elixir
		and not w.peaches.has(p)
		and not w.traps.has(p)
		and not w.sites.any(func(s): return s.get("at") == p)
	)


## `from` when a scroll can lie there, else the nearest tile across floor and
## sky that can (the lowest first among equals), or (-1, -1).
static func _spot(w: World, from: Vector2i) -> Vector2i:
	if _holds(w, from):
		return from
	var dist: PackedInt32Array = Grid.search(from, Masks.air(w)).dist
	var best := -1
	for i in dist.size():
		if dist[i] > 0 and (best < 0 or dist[i] < dist[best]) and _holds(w, Grid.at(i)):
			best = i
	return Grid.at(best) if best >= 0 else Vector2i(-1, -1)
