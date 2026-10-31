# miho agent rules

These rules come from repeated user corrections. Every lane reads this file before it starts. A plan in docs/ does not override it.

## Concept

- The magic system is 음양오행: shapes 여 and 구, and the five elements. A new spell is made by combining the existing talismans: pairs, then 상생 chains of three. Never add a new talisman or card outside this system.
- Before you add a tile, status, state or creature field, diff it against the existing table (src/core/tiles.gd, Actor, Info.state). If its rules match an existing entry, reuse that entry. Never add a themed name with the same rules.
- Level design teaches by arrangement, not by text. A secret or puzzle looks like ordinary terrain. Examples: a plain wall in front of an empty space, or three dark lanterns in a row. Never add an artificial prop whose hover explains the solution.

## Player-facing text (hover, sidebar, 도감, log)

- Write `이름: 값` or a bare tag: `모양: 유도 구슬`, `피해: 2`, `소리: 3칸`, `가연성.`, `용감함: 도망치지 않는다`.
- Do not write explanatory or causal sentences (`N하면 M한다`, `N해서 M하다`), and do not write `당신`.
- Delete every line that would not change what the player does. That includes "water is wet" lines and restatements of another line.
- Do not write hints, guesses or control tips, for example "숨은 문일 수 있다", "뒤에 숨을 수 있다" or "X키로 닫는다".
- No onomatopoeia in hover or 도감, because rules use only the radius: write `소리: N칸`. The map popup and the log keep the word.
- A rule shared by many things lives once in a 도감 glossary entry. The thing itself shows only the tag.
- Log lines are short past-tense events. Do not use exclamations.

## UI conventions

Every list, menu and scrolling pane follows standard conventions:
- Up/Down with key repeat when held, wrapping at both ends.
- PgUp/PgDn with repeat, Home and End.
- The mouse wheel scrolls, hover highlights, click selects.
- Tabs switch with Left/Right, Tab or a click.
- The selection stays in view. Esc closes and returns to where the list was opened.
- Every screen is reachable from the Esc menu.

Every player-visible event has a fitting sound:
- Terrain footsteps sound by tile.
- A good find chimes and a danger warns.
- Check `Sfx.sound_of` for every new event.

## Merge gate (parent)

Passing tests and lint do not prove a lane is done. Before merging a lane that changes anything the player sees or hears, the parent must do all of the following:
1. Read every added or changed user-facing string in the diff against the text rules above.
2. Drive the changed UI with `just shot ... --keys=...` and look at the frames.
3. Check that each new event maps to a sound.
4. Fix the whole class of a reported defect, not only the quoted line.
