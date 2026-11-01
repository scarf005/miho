class_name Exclusions
extends RefCounted
## Travel exclusions, as in Dungeon Crawl: danger zones Miho marks on the
## storey, which exploring and travel never walk into. A zone is a centre and
## a radius; it covers the known tiles within that many tiles of the centre
## that the centre sees (a wall or a door shuts it in). Radius 0 is the tile alone.

const DEFAULT_RADIUS := 5
const MAX_RADIUS := 7

## centre -> radius
var zones := {}


func is_empty() -> bool:
	return zones.is_empty()


## Marks a zone at `at`; if one is already centred there, makes it the tile
## alone, and if it already is, removes it.
func cycle(at: Vector2i) -> void:
	match zones.get(at, -1):
		-1:
			zones[at] = DEFAULT_RADIUS
		0:
			zones.erase(at)
		_:
			zones[at] = 0


## Marks a zone at `at` of `radius` (1 to MAX_RADIUS), or changes the one there.
func set_radius(at: Vector2i, radius: int) -> void:
	zones[at] = clampi(radius, 1, MAX_RADIUS)


func clear() -> void:
	zones.clear()


## Every tile of the zones as tile -> true; zones that cover `except` are left
## out, so Miho can always walk out of the one she stands in.
func tiles(w: World, except := Vector2i(-1, -1)) -> Dictionary:
	var out := {}
	for at: Vector2i in zones:
		var covered := _cover(w, at, zones[at])
		if not covered.has(except):
			out.merge(covered)
	return out


func _cover(w: World, at: Vector2i, radius: int) -> Dictionary:
	var out := {at: true}
	var view := w.fov(at)
	for y in range(maxi(at.y - radius, 0), mini(at.y + radius, Grid.H - 1) + 1):
		for x in range(maxi(at.x - radius, 0), mini(at.x + radius, Grid.W - 1) + 1):
			var i := Grid.index(Vector2i(x, y))
			if w.known[i] == 1 and view[i] == 1:
				out[Vector2i(x, y)] = true
	return out


## The line for a tile in a zone (`covered`, from `tiles`), with the radius at its
## centre; none for another tile.
func lines(p: Vector2i, covered: Dictionary) -> Array:
	if not covered.has(p):
		return []
	var radius: Variant = zones.get(p)
	var text := "위험구역" if radius == null else "위험구역 (반경 %d)" % radius
	return [[[text, Palette.ZONE]]]
