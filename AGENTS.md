# miho agent rules

These rules come from repeated user corrections. Every lane reads this file before it starts. A plan in docs/ does not override it.

## Concept

- The magic system is 음양오행: shapes 여 and 구, and the five elements. A new spell is made by combining the existing talismans: pairs, then 상생 and 상극 chains of three, four and five (docs/plan-compounds.md). Never add a new talisman or card outside this system.
- Before you add a tile, status, state or creature field, diff it against the existing table (src/core/tiles.gd, Actor, Info.state). If its rules match an existing entry, reuse that entry. Never add a themed name with the same rules.
- Level design teaches by arrangement, not by text. A secret or puzzle looks like ordinary terrain. Examples: a plain wall in front of an empty space, or three dark lanterns in a row. Never add an artificial prop whose hover explains the solution.
- Never add a gameplay limit the user did not ask for: a damage cap, a balance ceiling, or a test that enforces one. A numeric limit a lane needs goes to the user first, in plain words.
- Write no test that only mirrors a table, a name or a string, or repeats the expression the code uses. Check those with `rg`. Test behaviour.

## Player-facing text (hover, sidebar, 도감, log)

- Write `이름: 값` or a bare tag: `모양: 유도 구슬`, `피해: 2`, `소음: 3`, `가연성.`, `면역: 불`.
- A status a spell causes is one line with the status word coloured: `닿은 대상은 불이 붙는다`. The status has its entry in the 도감 상태이상 tab.
- A lone spray goes by its name alone: `불길`, never `불 불길`. Label words are plain Korean game words: `대상`, never `노림`.
- Do not write explanatory or causal sentences (`N하면 M한다`, `N해서 M하다`), and do not write `당신`.
- Delete every line that would not change what the player does. That includes "water is wet" lines and restatements of another line.
- Do not write hints, guesses or control tips, for example "숨은 문일 수 있다", "뒤에 숨을 수 있다" or "X키로 닫는다".
- No onomatopoeia in hover or 도감, because rules use only the radius: write `소음: N`. The map popup and the log keep the word.
- A rule shared by many things lives once in a 도감 glossary entry. The thing itself shows only the tag.
- Log lines are short past-tense events. Do not use exclamations.
- 꼬리 and 여우불 are Miho's words. A creature has 마력, and its wisps are 도깨비불, 저승불 or 혼불 (Bestiary.WISP_NAME).

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
- A find (a hidden door, a spotted thing) has a quiet neutral tick, a danger warns, and the bright chime is for a max health rise only.
- Check `Sfx.sound_of` for every new event.

## Merge gate (parent)

Passing tests and lint do not prove a lane is done. Before merging a lane that changes anything the player sees or hears, the parent must do all of the following:
1. Read every added or changed user-facing string in the diff against the text rules above.
2. Drive the changed UI with `just shot ... --keys=...` and look at the frames.
3. Check that each new event maps to a sound.
4. Fix the whole class of a reported defect, not only the quoted line.
