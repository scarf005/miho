class_name WordLink
extends RefCounted
## A left click, or a tap, on a word that has an entry in the 도감 (WordHover)
## opens that entry. No round is played and the world is not touched, so a saved
## run replays the same. A click on a box Shift keeps (Term.pin) that is on no
## word does nothing, so it does not reach the page or the tile under the box.


## A left click at `local` on the open page, which the page's own click meets
## when it is on no word: the 도감 opens on the word's entry.
static func click(m: Node, local: Vector2) -> StringName:
	var choice := PanelView.choice_at(m.term, local)
	if choice >= 0:
		m.menu.codex.part = choice
		return &""
	var word := WordHover.word_at(m.term, local)
	if word == "" and WordHover.on_pin(m.term, local):
		return &""
	if word == "" or m.menu.waiting:
		return m.menu.click(PanelView.row_at(m.term, local), PanelView.tab_at(m.term, local))
	m.menu.link(word)
	m.sfx.play(&"click")
	return &""


## A left click at `local` on a word of the log over the map in play, or of a box
## Shift keeps: the 도감 opens on its entry. Whether the click was used.
static func open(m: Node, local: Vector2) -> bool:
	if m.state != &"play" or m.overlay != &"":
		return false
	var word := WordHover.word_at(m.term, local)
	if word == "":
		return WordHover.on_pin(m.term, local)
	_show(m, word)
	return true


## The describe key: the 도감 opens on the entry of the hover box that is open, or
## of the one Shift keeps, as a click on a word of it would. Nothing else happens
## (no round, no log line) for a box with no entry. Whether it opened.
static func describe(m: Node) -> bool:
	var t: Term = m.term
	var word: String = t.pin.get("word", "") if not t.pin.is_empty() else t.subject
	if word == "" or t.info.is_empty() and t.pin.is_empty():
		return false
	if m.state != &"play" or m.overlay != &"":
		return false
	_show(m, word)
	return true


static func _show(m: Node, word: String) -> void:
	m._open(&"codex")
	m.menu.codex.link(word, false)
	m.term.panel = m.menu.panel()
	m.sfx.play(&"click")
