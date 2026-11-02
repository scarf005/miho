# miho agent rules

These rules come from repeated user corrections. Every lane reads this file before it starts. A plan in docs/ does not override it.

## Concept

- The magic system is 음양오행: shapes 여 and 구, and the five elements. A new spell is made by combining the existing talismans: pairs, then 상생 and 상극 chains of three, four and five (docs/plan-compounds.md). Never add a new talisman or card outside this system.
- Before you add a tile, status, state or creature field, diff it against the existing table (src/core/tiles.gd, Actor, Info.state). If its rules match an existing entry, reuse that entry. Never add a themed name with the same rules.
- Level design teaches by arrangement, not by text. A secret or puzzle looks like ordinary terrain. Examples: a plain wall in front of an empty space, or three dark lanterns in a row. Never add an artificial prop whose hover explains the solution.
- Never add a gameplay limit the user did not ask for: a damage cap, a balance ceiling, or a test that enforces one. A numeric limit a lane needs goes to the user first, in plain words.
- Write no test that only mirrors a table, a name or a string, or repeats the expression the code uses. Check those with `rg`. Test behaviour.

## Player-facing text (hover, sidebar, 도감, log)

- Read the reference first. Before you add or change a line for a kind of thing, read the code that shows the same kind of thing in an open-source roguelike, and name the function in your report. A shape that no reference uses needs a stated reason. User: "슬롭 지적의 원인은 너가 다른 오픈소스 로그라이크의 ui코드 조사를 충분히 안해서". References:
  - DCSS, `/home/scarf/repo/crawl/crawl-ref/source/describe.cc`: `_monster_stat_description`, `_monster_attacks_description`, `_monster_spells_description`, `get_feature_desc`, `get_cloud_desc`, `_player_spell_desc`, `_get_spell_description`; `describe-spells.cc`: `_describe_book`.
  - Brogue CE, `/home/scarf/repo/etc/roguelike-algorithms/vendor/brogue-ce/src/brogue/`: `Monsters.c` `monsterDetails`, `getMonsterAbilitiesText`; `Items.c` `itemDetails`.
- Write `이름: 값` or a bare tag: `모양: 유도 구슬`, `피해: 2`, `소음: 3`, `가연성.`, `면역: 불`.
- A status a spell causes is one line with the status word coloured. The status has its entry in the 도감 상태이상 tab.
- Never type a game value into a string: a spell name, a recipe, a list of spells, a count, a radius or a chance comes from its table or constant, so a change to the data changes the text. Use `"스스로에겐 %s만 걸 수 있다"` with the list filled from the table, never `그림자(여+수)나 둔갑(목+토)`.
- A lone spray goes by its name alone: `불길`, never `불 불길`. Label words are plain Korean game words: `대상`, never `노림`.
- Do not write explanatory or causal sentences (`N하면 M한다`, `N해서 M하다`).
- The player is `당신` in every line, as roguelikes such as DCSS write `You`: `당신을 볼 수 없다`, `당신의 불이 꺼졌다`. `미호` is only the title of the game.
- Delete every line that would not change what the player does. That includes "water is wet" lines and restatements of another line.
- A thing lists what it has. Never add a line that denies what another thing has: kimchi does not say `최대 체력: 오르지 않음` when the peach says `가득 찼을 때 최대 체력: +1`, and a wall does not say `부술 수 없다.` when a cracked wall says `부서짐: 구슬`. The same goes for what the player already assumes, such as `멈춤: 첫 적` beside `관통`, or `바닥이 됨: 풀` on a spell with `피해: 1`. User: "이 두 문장이 대체 뭔 가치가 있음". A negative stays only when nothing else tells it and the player would act otherwise: `적은 밟지 않음.`, `냄새가 남지 않음.`
- Do not write hints, guesses or control tips, for example "숨은 문일 수 있다", "뒤에 숨을 수 있다" or "X키로 닫는다".
- No onomatopoeia in hover or 도감, because rules use only the radius: write `소음: N`. The map popup and the log keep the word.
- A rule shared by many things lives once in a 도감 glossary entry. The thing itself shows only the tag.
- Log lines are short past-tense events. Do not use exclamations.
- Follow the global `korean-humanizer` skill for every Korean string you add or change. A line that passes the rules above can still read wrong. Any string that is a sentence or a description must be what a Korean player would say aloud. Keep the subject and the particles. An ability or a permission ends in `-ㄹ 수 있다`, never a flat `-ㄴ다`. Do not translate an English comment or brief word by word. User corrections:
  - `자신에게는 그림자나 둔갑만 건다` -> `스스로에겐 그림자나 둔갑만 걸 수 있다`
  - `밟으면 위층으로 오른다` -> `위층으로 올라갈 수 있다`
  - `볼 수 없다` on a creature hover -> `당신을 볼 수 없다`: a bare verb reads as the player not seeing the creature.
  - `당신을 보면 외친다: 낄낄 6칸` -> `말할 수 있다.`
  - `장승 피해 2` -> `장승이 피해를 2 입었다`
  - `장승 쓰러짐` -> `장승이 쓰러졌다`
  - `멀리서 탁` -> `멀리서 탁 소리를 들었다`
  - `불이 붙었다` -> `대나무에 불이 붙었다`
  - `2층` -> `2층으로 올라갔다`
  - `비키면 헛손질하고 휘청인다` -> a coined word such as `헛손질` does not go in the 도감; say what happens in common words.
- 꼬리 and 여우불 are the player's words. A creature has 마력, and its wisps are 도깨비불, 저승불 or 혼불 (Bestiary.WISP_NAME).
- One thing keeps one name on every screen: 불붙음, 젖음, 묶임, 소음, 피해. A label is the word a Korean game prints (`속도`, `관통`, `착지`, `소화`), never a verb that reads as prose or a coined noun.
- Every bare tag that carries a rule has an entry in `Info.glossary`, its rule read from the code that applies it. A tag whose rule changes nothing the player does is deleted. Every name that has an entry in any 도감 tab (`Codex.entries`, so a new entry needs no list) is a word: in the 도감 detail, the spellbook detail, the log and help pages and the log over the map, the pointer over it shows the entry in a box under the pointer, and a left click or a tap opens that entry in its own tab, Esc going back (Keywords, WordHover, WordLink). A name is found whole or before a particle, never inside a longer word. Words in the map hover, the sidebar and the status row do not work yet: those boxes follow the pointer.

## UI conventions

Every list, menu and scrolling pane follows standard conventions:
- Up/Down with key repeat when held, wrapping at both ends.
- PgUp/PgDn with repeat, Home and End.
- The mouse wheel scrolls, hover highlights, click selects.
- Tabs switch with Left/Right, Tab or a click.
- The selection stays in view. Esc closes and returns to where the list was opened.
- Every screen is reachable from the Esc menu.
- A shortcut label beside what it stands for (a talisman number, a saved spell key) is small and dim, one look on every screen (`Term._key`): `1~7` are easy to remember, so the label never competes with the glyph. A key that is itself the content of a line, as in the help and key pages, stays body size.

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
