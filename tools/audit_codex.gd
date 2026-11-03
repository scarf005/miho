extends SceneTree
## Prints, for every part of every 도감 example, what its rounds did within the window the
## example plays, as one markdown row each: what it should show, the harm to the creatures,
## the bursts beside one, the statuses, tiles and gas it changed, whether a creature or Miho moved
## or healed (`moves`), and whether it did what it should.
## For a creature's spell, `landed` counts what reached Miho in rounds with no blow of the
## creature's. `probe` is the harm the spell does to a creature that stands still in a bare hall.
## godot --headless --path . -s tools/audit_codex.gd

const STATUSES := [&"wet", &"alight", &"frozen", &"rooted", &"stunned", &"blind"]
const FX := [
	&"leap",
	&"stun",
	&"wet",
	&"ignite",
	&"freeze",
	&"root",
	&"stick",
	&"feud",
	&"push",
	&"pull",
	&"prick",
	&"become",
	&"scald",
	&"sear",
	&"splash",
	&"blast",
	&"douse",
	&"sprout",
	&"grow",
	&"crumble",
	&"collapse",
	&"smash",
	&"trample",
	&"sleep",
	&"ally",
	&"raise",
	&"soul",
	&"guise",
	&"cloak",
	&"talon",
	&"flame",
	&"snuff",
	&"clash",
	&"hit"
]
const HEAD := (
	"| tab | entry | part | should show | foe harm | miho | status | spawned | bursts | beside "
	+ "| tiles+gas | moves | allies | fx | landed | probe | result |"
)


func _init() -> void:
	print(HEAD)
	print("|" + "---|".repeat(HEAD.count("|") - 1))
	for tab in Codex.TABS.size():
		for rank in range(1, Bestiary.RANKS + 1) if tab == 0 else [1]:
			for e in Codex.entries(tab, rank):
				var parts := SpellScene.parts(e.scene)
				for i in parts.size():
					var label: String = parts[i].get("label", str(i))
					var name: String = e.name + (" r%d" % rank if tab == 0 else "")
					_row(Codex.TABS[tab], name, label, SpellScene.ready(parts[i]), rank, tab)
	quit()


## The harm the spell of `cards` does to a tough creature that stands still, 3 or 5 tiles
## from Miho in a bare hall, by either of two dice: the most of the four.
static func probe(cards: Array) -> int:
	var most := 0
	for dx in [3, 5]:
		for seed in [1, 2]:
			var scene := {
				key = &"cheonha",
				map = "  @" + " ".repeat(dx - 1) + "g",
				cards = cards,
				do = "c" + ".".repeat(SpellScene.WAITS),
			}
			var w := CodexScene.build(scene)
			w.rng.seed = seed
			most = maxi(most, _run(w, scene).foe)
	return most


func _row(
	tab: String, name: String, label: String, scene: Dictionary, rank: int, tab_i: int
) -> void:
	var run := _run(CodexScene.build(scene, rank if tab_i == 0 else 0), scene)
	var probed := -1
	var should := "changes the hall"
	var ok: bool = run.tiles > 0 or not run.fx.is_empty() or run.moved or run.allies > 0
	if scene.has("charged"):
		should = "spell reaches Miho"
		ok = run.landed > 0 or run.spawned > 0 or run.fx.has(&"leap")
		if Spray.called(Spell.make(scene.charged)) != "":
			ok = run.covered > 0
	elif tab_i == 0:
		should = "walks up to Miho" if label == Lang.t("이동") else "blow hurts Miho"
		ok = run.moved if label == Lang.t("이동") else run.miho > 0
	elif tab_i in [1, 2] and scene.has("cards"):
		var spell := Spell.make(scene.cards)
		if Guise.kind(spell) == &"":
			probed = probe(scene.cards)
		if probed > 0:
			should = "harms the creature"
			ok = run.foe > 0
		else:
			should = "status, tiles or ally" if probed == 0 else "buff on Miho"
	print(
		(
			"| %s | %s | %s | %s | %d | %d | %s | %d | %d | %d | %d | %s | %d | %s | %d | %s | %s |"
			% [
				tab,
				name,
				label,
				should,
				run.foe,
				run.miho,
				",".join(run.status.keys().map(str)),
				run.spawned,
				run.bursts,
				run.beside,
				run.tiles,
				"y" if run.moved else "",
				run.allies,
				",".join(run.fx.keys().map(str)),
				run.landed,
				str(probed) if probed >= 0 else "-",
				"ok" if ok else "MISS"
			]
		)
	)


## Plays the actions of `scene` in `w` and sums up what they did.
static func _run(w: World, scene: Dictionary) -> Dictionary:
	var start := w.clone()
	var me := w.player().id
	var out := {
		foe = 0,
		miho = 0,
		spawned = 0,
		bursts = 0,
		beside = 0,
		status = {},
		moved = false,
		tiles = 0,
		allies = 0,
		fx = {},
		landed = 0,
		covered = 0
	}
	for action in CodexScene.actions(scene):
		if not w.can(action):
			break
		var side := {}
		var foes: Array[Vector2i] = []
		for a: Actor in w.actors:
			side[a.id] = a.faction
			if a.faction != Actor.FOX and a.alive():
				foes.append(a.pos)
		var there := w.player().pos
		var events := w.act(action)
		for a: Actor in w.actors:
			side[a.id] = a.faction
			if a.faction != Actor.FOX and a.alive():
				foes.append(a.pos)
		var melee := events.any(func(e: Dictionary) -> bool: return e.t == &"melee")
		for ev: Dictionary in events:
			var near: bool = Grid.cheb(ev.get("at", Vector2i(-9, -9)), w.player().pos) <= 1
			if not melee and (ev.t == &"hurt" and ev.id == me or FX.has(ev.t) and near):
				out.landed += 1
			if FX.has(ev.t):
				out.fx[ev.t] = true
			match ev.t:
				&"hurt":
					if ev.id == me:
						out.miho += ev.n
					elif side.get(ev.id, Actor.FOX) != Actor.FOX:
						out.foe += ev.n
				&"spray":
					if ev.tiles.has(there):
						out.covered += 1
				&"spawn":
					out.spawned += 1
				&"burst":
					out.bursts += 1
					if foes.any(func(p: Vector2i) -> bool: return Grid.cheb(p, ev.at) <= 1):
						out.beside += 1
		for a: Actor in w.actors:
			if a.id == me or a.faction == Actor.FOX:
				continue
			for s in STATUSES:
				if a.ailments.get(s) > 0:
					out.status[s] = true
			var a0: Actor = start.actor(a.id)
			if a0 != null and a0.pos != a.pos:
				out.moved = true
	var her := start.player()
	if w.player().pos != her.pos or w.player().hp > her.hp or w.player().max_hp > her.max_hp:
		out.moved = true
	for i in w.tiles.size():
		if w.tiles[i] != start.tiles[i]:
			out.tiles += 1
	out.tiles += 1 if str(w.gas.keys()) != str(start.gas.keys()) else 0
	out.allies = w.actors.filter(func(a: Actor) -> bool: return a.ally() and not a.is_miho()).size()
	return out
