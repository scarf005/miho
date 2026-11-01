extends SceneTree
## How often each event room appears and how often it can be opened, over many
## seeds and every storey. A room is solvable when the key to its gate is within
## reach of the start with the gate shut and the rules open the gate.
## godot --headless --path . -s tools/event_rooms.gd -- 200

const SEEDS := 200


## The event rooms by name: `seals` lists where a storey has one, `opens` tells
## whether the rules open that one from the start. Add a room kind here.
static func kinds() -> Dictionary:
	return {
		"세 등불 보물방": {seals = _vault_seals, opens = _vault_opens},
		"혼불 제단": {seals = _sites.bind(&"altar"), opens = _beside_reached},
		"도깨비불 장막": {seals = _veil_tiles, opens = _veil_opens},
		"장승 마당": {seals = _sites.bind(&"yard"), opens = _reached},
		"삐걱 마루": {seals = _sites.bind(&"creak"), opens = _reached},
		"서고": {seals = _sites.bind(&"library"), opens = _reached},
	}


static func _vault_seals(w: World) -> Array:
	return w.seals.keys()


## Where the rooms of a kind keep their key tile: the tile of each site.
static func _sites(w: World, kind: StringName) -> Array:
	return w.sites.filter(func(s): return s.kind == kind).map(func(s): return s.at)


## Whether Miho walks from the start to `p`, the gates shut.
static func _reached(w: World, p: Vector2i) -> bool:
	return _reach(w)[Grid.index(p)] >= 0


## Whether Miho walks from the start to a tile beside `p`, the gates shut.
static func _beside_reached(w: World, p: Vector2i) -> bool:
	var reach := _reach(w)
	return Grid.DIRS.any(func(d): return Grid.inside(p + d) and reach[Grid.index(p + d)] >= 0)


static func _reach(w: World) -> PackedInt32Array:
	return Grid.search(w.start, Masks.floor_of(w)).dist


## One tile of the veil, when the storey has one.
static func _veil_tiles(w: World) -> Array:
	var i := w.tiles.find(World.VEIL)
	return [] if i < 0 else [Grid.at(i)]


## Miho walks to a tile from which a water jet along a line reaches the veil, and
## the water puts that tile out.
static func _veil_opens(w: World, veil: Vector2i) -> bool:
	var reach := _reach(w)
	for i in reach.size():
		if reach[i] < 0:
			continue
		for d: Vector2i in Grid.DIRS:
			if Spray.line(w, Grid.at(i), d, Spray.JET[0], false).has(veil):
				var wet := w.clone()
				Terrain.wash(wet, veil)
				return wet.open_floor(veil)
	return false


## Miho walks to a tile beside each lantern with the wall standing and casts fire
## there; the wall must then collapse by the rule of the lanterns (Vault.tick).
static func _vault_opens(w: World, gate: Vector2i) -> bool:
	var open := w.clone()
	var reach := _reach(w)
	var shot := Shot.new()
	shot.spell = Spell.make([Cards.ORB, Cards.FIRE])
	for lantern: Vector2i in w.seals[gate]:
		var at := lantern
		for d in Grid.DIRS:
			if Grid.inside(lantern + d) and reach[Grid.index(lantern + d)] >= 0:
				at = lantern + d
				break
		if at == lantern:
			return false
		Terrain.touch(open, shot, at, Vector2i(-1, -1))
	Vault.tick(open)
	return open.tile(gate) == World.RUBBLE


## For every kind: the storeys looked at, those with the room, those where it
## opens, and the storeys where it does not.
static func measure(seeds: int) -> Dictionary:
	var kinds_ := kinds()
	var out := {}
	for name: String in kinds_:
		out[name] = {storeys = 0, present = 0, solvable = 0, stuck = []}
	for seed_value in seeds:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value * World.FLOORS + depth)
			w.depth = depth
			FloorGen.build(w)
			for name: String in kinds_:
				var row: Dictionary = out[name]
				row.storeys += 1
				for seal: Vector2i in kinds_[name].seals.call(w):
					row.present += 1
					if kinds_[name].opens.call(w, seal):
						row.solvable += 1
					else:
						row.stuck.append("seed %d storey %d" % [seed_value, depth])
	return out


## A markdown table of `measure`.
static func table(rows: Dictionary) -> String:
	var lines := ["| 방 | 층 | 나온 층 | 나온 비율 | 열리는 방 | 열리는 비율 |", "|---|---|---|---|---|---|"]
	for name: String in rows:
		var r: Dictionary = rows[name]
		var shown: float = 100.0 * r.present / r.storeys
		var opened: float = 100.0 * r.solvable / maxi(r.present, 1)
		lines.append(
			(
				"| %s | %d | %d | %.1f%% | %d | %.1f%% |"
				% [name, r.storeys, r.present, shown, r.solvable, opened]
			)
		)
	return "\n".join(lines)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	print(table(measure(int(args[0]) if not args.is_empty() else SEEDS)))
	quit()
