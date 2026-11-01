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
- A status a spell causes is one line with the status word coloured. The status has its entry in the 도감 상태이상 tab.
- Never type a game value into a string: a spell name, a recipe, a list of spells, a count, a radius or a chance comes from its table or constant, so a change to the data changes the text. Use `"스스로에겐 %s만 걸 수 있다"` with the list filled from the table, never `그림자(여+수)나 둔갑(목+토)`.
- A lone spray goes by its name alone: `불길`, never `불 불길`. Label words are plain Korean game words: `대상`, never `노림`.
- Do not write explanatory or causal sentences (`N하면 M한다`, `N해서 M하다`), and do not write `당신`.
- Delete every line that would not change what the player does. That includes "water is wet" lines and restatements of another line.
- Do not write hints, guesses or control tips, for example "숨은 문일 수 있다", "뒤에 숨을 수 있다" or "X키로 닫는다".
- No onomatopoeia in hover or 도감, because rules use only the radius: write `소음: N`. The map popup and the log keep the word.
- A rule shared by many things lives once in a 도감 glossary entry. The thing itself shows only the tag.
- Log lines are short past-tense events. Do not use exclamations.
- Follow the global `korean-humanizer` skill for every Korean string you add or change. A line that passes the rules above can still read wrong. Any string that is a sentence or a description must be what a Korean player would say aloud. Keep the subject and the particles. An ability or a permission ends in `-ㄹ 수 있다`, never a flat `-ㄴ다`. Do not translate an English comment or brief word by word. User corrections:
  - `자신에게는 그림자나 둔갑만 건다` -> `스스로에겐 그림자나 둔갑만 걸 수 있다`
  - `밟으면 위층으로 오른다` -> `위층으로 올라갈 수 있다`
  - `당신을 보면 외친다: 낄낄 6칸` -> `말할 수 있다.`
  - `장승 피해 2` -> `장승이 피해를 2 입었다`
  - `장승 쓰러짐` -> `장승이 쓰러졌다`
  - `멀리서 탁` -> `멀리서 탁 소리를 들었다`
  - `불이 붙었다` -> `대나무에 불이 붙었다`
  - `2층` -> `2층으로 올라갔다`
  - `비키면 헛손질하고 휘청인다` -> a coined word such as `헛손질` does not go in the 도감; say what happens in common words.
- 꼬리 and 여우불 are Miho's words. A creature has 마력, and its wisps are 도깨비불, 저승불 or 혼불 (Bestiary.WISP_NAME).
- One thing keeps one name on every screen: 불붙음, 젖음, 묶임, 소음, 피해. A label is the word a Korean game prints (`속도`, `관통`, `착지`, `소화`), never a verb that reads as prose or a coined noun.
- Every bare tag that carries a rule has an entry in `Info.glossary`, its rule read from the code that applies it. A tag whose rule changes nothing the player does is deleted. A word with an entry shows it on mouse hover in the 도감 detail and the log (Keywords, WordHover).

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
1. Read every added or changed user-facing string in the diff against the text rules above, then read it aloud as Korean and rewrite it if a player would not say it. Before a tag, read the whole list from `just strings`.
2. Drive the changed UI with `just shot ... --keys=...` and look at the frames.
3. Check that each new event maps to a sound.
4. Fix the whole class of a reported defect, not only the quoted line.
