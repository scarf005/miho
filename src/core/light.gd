class_name Light
extends RefCounted
## Brogue-style light: every source adds its colour to the tiles it reaches,
## fading with distance (Brogue CE Light.c paintLight: 100 - (100 - fade) *
## dist / radius). Walls and closed doors cast shadows. A negative colour is
## darkness. A tile is lit when its brightest channel reaches LIT.
## `spread` and `field` run in Rust (rust/src/lib.rs, with the fade of 0.25).

const LIT := 0.3

const LANTERN := Vector3(1.0, 0.6, 0.28)
const LANTERN_RADIUS := 6
const SIDE: Array[Vector3] = [Vector3(0.45, 0.72, 1.0), Vector3(1.0, 0.3, 0.2)]
const FIRE := Vector3(1.0, 0.55, 0.15)
const FIRE_RADIUS := 3
## A gun's muzzle flash lights the shooter's tile for the round it fires.
const MUZZLE_RADIUS := 1
## Moonlight on skybridges: bright enough to be lit anywhere along the span.
const MOON := Vector3(0.4, 0.5, 0.75)
const DARK := Vector3(-1.4, -1.4, -1.4)
## The soul fire of a lit altar.
const SOUL := Vector3(0.4, 0.62, 1.0)
const SOUL_RADIUS := 4
## Tiles that always shine: tile kind -> {radius, color}.
const GLOW := {
	World.ALTAR_LIT: {radius = SOUL_RADIUS, color = SOUL},
	World.VEIL: {radius = LANTERN_RADIUS, color = FIRE},
	World.LAMP: {radius = LANTERN_RADIUS, color = LANTERN},
}


## Strength (0 to 1) a source gives each tile it reaches; `opaque` as for Sight.field.
static func spread(at: Vector2i, radius: int, opaque: PackedByteArray) -> PackedFloat32Array:
	return Native.spread(at, radius, opaque, Grid.W)


## Sum of every source; each source is {at, radius, color}.
static func field(sources: Array[Dictionary], opaque: PackedByteArray) -> PackedVector3Array:
	return Native.light(sources, opaque, Grid.W)


## Every light on the storey: lanterns, glowing tiles, fires, creatures
## alight (Status), muzzle flashes and glowing projectiles.
static func sources(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := w.tiles.find(World.LANTERN)
	while i >= 0:
		out.append({at = Grid.at(i), radius = LANTERN_RADIUS, color = LANTERN})
		i = w.tiles.find(World.LANTERN, i + 1)
	for t: int in GLOW:
		i = w.tiles.find(t)
		while i >= 0:
			out.append({at = Grid.at(i), radius = GLOW[t].radius, color = GLOW[t].color})
			i = w.tiles.find(t, i + 1)
	for p in w.burning:
		out.append({at = p, radius = FIRE_RADIUS, color = FIRE})
	for a in w.actors:
		if a.alive() and a.alight > 0:
			out.append({at = a.pos, radius = FIRE_RADIUS, color = FIRE})
	for p in w.flares:
		out.append({at = p, radius = MUZZLE_RADIUS, color = FIRE})
	for s in w.shots:
		if not s.gone:
			var l := s.spell.light(s.faction)
			if not l.is_empty():
				out.append({at = s.pos, radius = l.radius, color = l.color})
	return out


static func level(c: Vector3) -> float:
	return maxf(0.0, maxf(c.x, maxf(c.y, c.z)))
