class_name Banner
extends RefCounted
## The lines over the map on the title and when a run ends, in the language shown.

## The line holding the seed, which a click copies.
const SEED := 3
## The key that starts a new run from an ending, besides the restart action.
const AGAIN := KEY_R
## What the title asks before it erases the run on disk.
const ERASE := "이어하던 판을 지우고 새로 시작할까?"
## Puts text on the clipboard; a test swaps it, since a headless run has none.
static var clipboard := DisplayServer.clipboard_set


## Writes the lines of the state the game `m` (main.gd) is in: the title's or the
## ending's. Nothing in play.
static func show(m: Node) -> void:
	if m.state == &"title":
		m.term.banner_lines = title(m.pending, m.erasing, m.touch)
	elif m.state == &"over":
		m.term.banner_lines = over(m.world, m.kills, m.run_seed)
		for i in [-1, -2]:
			m.term.banner_lines[i] = m.touch.say(m.term.banner_lines[i], "")


## A press on the ending: a new run, the log, or the seed line copied.
static func input(m: Node, event: InputEvent) -> void:
	if Keys.action_of(event) == &"restart" or _again(event):
		m._new_game()
	elif Keys.action_of(event) == &"log":
		m._open(&"log")
	elif m._left_click(event) and m.term.banner_at(m._local(event.position)) == SEED:
		m._copy_seed()


## Whether `event` is the plain key AGAIN.
static func _again(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.keycode == AGAIN
		and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed)
	)


## Asks before the run in play gives way to a new one; Y
## answers (a second press of the button on a touch screen).
static func ask(m: Node) -> void:
	m.erasing = true
	m.sfx.play(&"warn")
	show(m)
	if m.state == &"play":
		m._show_log()
		m.term.log_lines.append([[[_sure(m.touch), Palette.TEXT]], 1.0])


## Takes the question back.
static func keep(m: Node) -> void:
	if m.state == &"title":
		m._show_title()
		return
	m.erasing = false
	show(m)
	if m.state == &"play":
		m._show_log()


static func _sure(touch: Touch) -> String:
	return touch.say(Lang.t(Menu.RESTART_SURE) + " Y/N", Lang.t(Menu.RESTART_SURE))


## The title's lines; it offers to continue when `pending` is a run on disk, or
## asks to erase it when `erasing`.
static func title(pending: SaveGame, erasing: bool, touch: Touch) -> Array[String]:
	var line := touch.say(
		Lang.t("아무 키나 눌러 시작" if pending == null else "Enter 이어하기 · N 새로 시작"),
		Lang.t("화면을 눌러 시작") if pending == null else ""
	)
	if erasing:
		line = touch.say(Lang.t(ERASE) + " Y/N", Lang.t(ERASE))
	return [Lang.t("미호"), Lang.t("천상누각 꼭대기에 사람이 되는 영약이 있다"), line]


## The lines of a run that ended in `w` with `kills` creatures put down.
static func over(w: World, kills: int, seed_value: int) -> Array[String]:
	var log_key: String = (Keys.keys_of(&"log").map(Keys.label) + ["Ctrl+P"])[0]
	return [
		Lang.t("사람이 되었다", "banner") if w.outcome == &"won" else _fallen(w),
		Lang.t("%d층 · %d초") % [w.depth, w.round_no],
		Lang.t("처치 %d") % kills,
		seed_line(seed_value, false),
		Lang.t("%s키를 눌러 기록 보기") % log_key,
		Lang.t("%s키를 눌러 재시작") % OS.get_keycode_string(AGAIN),
	]


## How Miho fell, from what came just before her last wound this round. A creature
## she does not see at the end goes unnamed.
static func _fallen(w: World) -> String:
	var me := w.player()
	var wounds := 0
	for i in range(w.events.size() - 1, -1, -1):
		var e: Dictionary = w.events[i]
		if e.t == &"hurt" and e.id == me.id:
			wounds += 1
		elif wounds == 1 and _blow(w, e) != "":
			return _blow(w, e)
		if wounds == 2:
			break
	return Lang.t("쓰러졌다", "banner")


## The line for event `e` when it can be what wounded Miho, or empty. The nearest
## such event before the wound decides.
static func _blow(w: World, e: Dictionary) -> String:
	var me := w.player()
	match e.t:
		&"melee" when e.target == me.id:
			return (
				Lang.t("%s에게 쓰러졌다") % _name(w, e.id)
				if _name(w, e.id) != ""
				else Lang.t("쓰러졌다", "banner")
			)
		&"crash" when e.id == me.id:
			return Lang.t("벽에 부딪혀 쓰러졌다")
		&"burn" when e.id == me.id:
			return Lang.t("불에 타 쓰러졌다")
		&"fall" when e.id == me.id:
			return Lang.t("떨어져 쓰러졌다")
		&"hit" when e.id == me.id:
			return _by(w, e)
		&"splash" when Grid.cheb(e.at, me.pos) <= 1:
			return _by(w, e)
		&"scald" when e.id == me.id:
			return Lang.t("%s에 쓰러졌다") % Lang.t(Gas.of(e.kind, "name"))
		&"blast" when e.tiles.has(me.pos):
			return Lang.t("%s 폭발에 쓰러졌다") % Lang.t(Gas.of(e.kind, "name"))
		&"sear" when e.id == me.id:
			return Lang.t("%s에 쓰러졌다") % Lang.t(Compounds.HOT[e.kind].name)
		&"prick" when e.id == me.id:
			return Lang.t("%s에 쓰러졌다") % Lang.t(Tiles.of(World.THORNS, "name"))
	return ""


static func _by(w: World, e: Dictionary) -> String:
	var name := _name(w, e.by) if e.by != w.player().id else ""
	var spell: String = Spell.from_tag(e.spell).shot_shown() if e.has("spell") else Lang.t(e.title)
	return Lang.t("%s의 %s에 쓰러졌다") % [name, spell] if name != "" else Lang.t("%s에 쓰러졌다") % spell


## The name of creature `id` if Miho sees it, else empty.
static func _name(w: World, id: int) -> String:
	var a := w.actor(id)
	return Lang.t(a.info().name) if a != null and Hat.shown(w, a) else ""


static func seed_line(seed_value: int, copied: bool) -> String:
	return Lang.t("시드 %d 복사했다" if copied else "시드 %d") % seed_value


## Copies the seed; a banner showing it says so.
static func copy(seed_value: int, t: Term) -> void:
	clipboard.call(str(seed_value))
	if t.banner_lines.size() > SEED:
		t.banner_lines[SEED] = seed_line(seed_value, true)
