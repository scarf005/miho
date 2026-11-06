class_name Casting
extends RefCounted
## The talismans in the queue (Spell) of the game `m` (main.gd), and what leaves it: 1-8 put
## talismans in it; with a queue a direction hurls the spell (or leaps that way), and Shift with
## a direction holds it so several spells leave in one turn. Space, Enter or . hurl it at the
## cursor (or cast what is held). Picking from the keyboard puts the cursor on the nearest
## creature in sight, and Tab moves it to the next. QWEASD fill the queue with a saved spell,
## F with the last spell hurled.

var m: Node
var picked: Array[StringName] = []
var staged: Array[Dictionary] = []
## A talisman or saved spell was just refused: the next direction or tile is
## eaten, so the press meant to hurl it does not walk Miho instead.
var refused := false
## Key (Spell.key) of the last spell hurled this run, or empty; F picks it again.
var last_spell := ""


func _init(of: Node) -> void:
	m = of


## Whether this press is the one after a refusal with nothing to hurl, which
## must not walk; any press ends the refusal.
func eats_move() -> bool:
	var eat := refused and picked.is_empty() and staged.is_empty()
	refused = false
	return eat


## Puts a talisman at the end of the queue, when a slot and a tail are left for it.
func add(card: StringName) -> void:
	var why: Variant = null
	if Spell.fill(picked + [card]).size() > Spell.MAX_SLOTS:
		why = "부적 칸이 가득 찼다"
	elif _held() + Spell.price(picked.size() + 1) > Cheat.tails(m.world):
		why = _short(_held() + Spell.price(picked.size() + 1))
	elif Spell.make(picked + [card]) == null:
		why = func():
			return Lang.t("%s: 맨 앞, 또는 %s") % [Lang.t(Cards.NAME[Cards.VAULT]), SpellInfo.behind()]
	if why != null:
		_refuse(why)
	else:
		picked.append(card)
		m.sfx.play(&"click")
	m.forecast()


## Picks a saved spell's talismans to aim it, if Miho has them and the tails.
func recall(key: String) -> void:
	var spell := Spell.from_key(key) if key != "" else null
	var why: Variant = null
	if spell == null:
		why = "저장한 주문이 없다"
	elif not spell.cards.all(func(c): return m.world.cards.has(c)):
		why = "부적이 모자라다"
	elif spell.cost() + _held() > Cheat.tails(m.world):
		why = _short(spell.cost() + _held())
	if why != null:
		_refuse(why)
		return
	picked.assign(spell.cards)
	m.sfx.play(&"click")
	m.forecast()


## Picks the last spell hurled again.
func again() -> void:
	if last_spell == "":
		_refuse("아직 던진 주문이 없다")
	else:
		recall(last_spell)
		aim()


## For keyboard picks, which have no pointer to aim with: puts the cursor on the
## nearest creature in sight, unless it is on one already.
func aim() -> void:
	var foes := Fight.targets(m.world)
	if picked.is_empty() or foes.any(func(a): return a.pos == m.look.hover):
		return
	if not foes.is_empty():
		m.look.at(foes[0].pos)
	elif not Grid.inside(m.look.hover) and not m.touch.enabled:
		m.look.at(m.world.player().pos)


## With talismans picked, Tab moves the cursor to the next creature in sight, then to Miho.
func aim_next() -> void:
	var stops: Array = Fight.targets(m.world).map(func(a): return a.pos) + [m.world.player().pos]
	m.look.at(stops[(stops.find(m.look.hover) + 1) % stops.size()])


## Hurls the picked talismans towards the cursor, on Miho's own tile on her; with no
## cursor it says so instead of passing the round.
func hurl_at_cursor() -> void:
	if Grid.inside(m.look.hover):
		direction(Grid.nearest_dir(m.look.hover - m.world.player().pos), false)
	else:
		_refuse("겨눌 곳이 없다")


## Takes back the last talisman picked, else the last spell held.
func unpick() -> void:
	if not picked.is_empty():
		picked.pop_back()
	elif not staged.is_empty():
		staged.pop_back()
	else:
		return
	m.sfx.play(&"click")
	m.forecast()


## Empties the queue and what is held; the cursor goes back to the pointer.
func clear() -> void:
	forget()
	Preview.point(m, m.mouse())
	m.forecast()


## Empties the queue and what is held, and nothing else.
func forget() -> void:
	picked.clear()
	staged.clear()


## With talismans picked a direction hurls them (Shift holds them), and no
## direction casts them on Miho; otherwise it moves.
## Space and the like hurl towards the cursor through here.
func direction(d: Vector2i, hold: bool) -> void:
	if picked.is_empty():
		if not staged.is_empty() and not hold:
			m.act({t = &"cast", spells = staged.duplicate()})
		elif staged.is_empty():
			m.move(d)
		return
	var spell := Spell.make(picked)
	var why := Guise.why(m.world.player(), spell, d)
	if why != "":
		_refuse(why)
		return
	if Elixir.barred(m.world, spell, d):
		_refuse(Elixir.BARRED_WHY)
		return
	var spells := staged.duplicate()
	spells.append({cards = picked.duplicate(), dir = d})
	if not m.world.can({t = &"cast", spells = spells}):
		if spell.shape == Spell.LEAP:
			m.say("착지할 곳이 없다")
		m.sfx.play(&"click")
		return
	if hold:
		staged = spells
		picked.clear()
		m.forecast()
		return
	m.act({t = &"cast", spells = spells})


## The refusal when a spell needs more tails than Miho has.
func _short(need: int) -> Callable:
	var lack: int = need - Cheat.tails(m.world)
	return func(): return Lang.t("꼬리가 %d개 모자라다") % lack


## Says why a talisman or saved spell cannot be picked, with the warning sound.
func _refuse(why: Variant) -> void:
	m.say(Guise.shown_only if why is String and why == Guise.only() else why)
	m.sfx.play(&"deny")
	refused = true


func _held() -> int:
	return staged.reduce(func(n, s): return n + Spell.price(s.cards.size()), 0)
