extends SceneTree
## How often each event room appears and how often it can be opened, over many
## seeds and every storey. A room is solvable when the key to its seal is within
## reach of the start with the seal shut and the rules open the seal.
## godot --headless --path . -s tools/event_rooms.gd -- 200

const SEEDS := 200


## The event rooms by name: `seals` lists where a storey has one, `opens` tells
## whether the rules open that one from the start. Add a room kind here.
static func kinds() -> Dictionary:
	return {"세 등불 보물방": {seals = _vault_seals, opens = _vault_opens}}


static func _vault_seals(w: World) -> Array:
	return w.seals.keys()


## Miho walks to a tile beside each lantern with the seal shut and casts fire
## there; the seal must then open by the rule that opens seals.
static func _vault_opens(w: World, seal: Vector2i) -> bool:
	var open := w.clone()
	var reach: PackedInt32Array = (
		Grid.search(w.start, Masks.floor_of(w, w.seals.keys(), func(_p): return false)).dist
	)
	var shot := Shot.new()
	shot.spell = Spell.make([Cards.ORB, Cards.FIRE])
	for lantern: Vector2i in w.seals[seal]:
		var at := lantern
		for d in Grid.DIRS:
			if Grid.inside(lantern + d) and reach[Grid.index(lantern + d)] >= 0:
				at = lantern + d
				break
		if at == lantern:
			return false
		Terrain.touch(open, shot, at, Vector2i(-1, -1))
	Terrain.unseal(open)
	return open.tile(seal) == World.DOOR_OPEN


## For every kind: the storeys looked at, those with the room, those where it
## opens, and the storeys where it does not.
static func measure(seeds: int) -> Dictionary:
	var kinds_ := kinds()
	var out := {}
	for name: String in kinds_:
		out[name] = {storeys = 0, present = 0, solvable = 0, stuck = []}
	for seed_value in seeds:
		for depth in range(1, World.FLOORS + 1):
			var w := World.create(seed_value)
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
