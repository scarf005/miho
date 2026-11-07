# miho agent rules

These rules come from repeated user corrections. Every lane reads this file before it starts. A plan in docs/ does not override it.

## Concept

- The magic system is 음양오행: shapes 여 and 구, and the five elements. A new spell is made by combining the existing talismans: pairs, then 상생 and 상극 chains of three, four and five (docs/plan-compounds.md). Never add a new talisman or card outside this system.
- A buff, a spell cast on oneself, always holds 목. User: "버프형 주문은 반드시 목 있어야 함. 여 + 불 + 목, 여 + 수 + 목처럼".
- A buff takes at least 3 talismans, has no time limit and can be dropped at will. User: "변신형 주문은 전부 최소 주문 3장 조합하게 하고 전부 유지시간은 무한대로 하되 스스로 해제 가능하게". 은신 and 둔갑 can be seen through. User: "은신과 둔갑은 파훼당할수 있게 해".
- The cast of 둔갑, 은신, 불여우 and 쇠발톱 is heard 3 tiles, and a claw under 쇠발톱 is heard 3 tiles, a sneak one too. User: "둔갑, 은신, 불여우, 쇠발톱 모두 시전시 소음 3으로 바꾸고, 쇠발톱은 (영구 유지 가능한 페널티로) 근접 공격 소음을 3으로 바꿔".
- 불여우 turns Miho's `@` red, and her fire does not add harm. It gets through a fire creature's immunity for 1 harm at most. User: "불여우가 되면 @ 색을 붉은색으로 바꿔. 주문 피해 +1 제거하고 다음으로 바꿔: `불 면역을 1 피해까지 무시`".
- A creature with wits sees through a 둔갑 cast in front of it. User: "지능이 있는 적 눈앞에서 둔갑하면 소용없게, 지능이 없는 적을 추가로 만들어줘". 천년 이무기 is not fooled by 둔갑 either.
- 분신 has 3 tails of its own and fights on its own. User: "분신은 꼬리 3개 전투 알아서 하게해 (spellforged servitor처럼)", "분신의 꼬리가 3개라는 뜻이고 주문 가격은 알아서 정해줘". The recipe is 여+토+화+목, so it costs what `Spell.COST` says for four cards. User: "여+토+화+목", "분신은 최대 둘까지만". A third pushes out the oldest, as DCSS `summoned_monster` does. 사령술 costs 7 tails and is the one buff with a time limit, the storey it is cast on. User: "7꼬리 주문, 한 층 내내 지속, 시야의 죽은 적을 발견하면 시귀/강시 등으로 되살아남". 시귀 and 강시 are now named 객귀 and 달걀귀신. User: "객귀와 달걀귀신 ㄱㄱ".
- 사령술 and 윤회 are two spells. User: "윤회랑 별개의 사령술 주술을 추가하라 했는데?"
- 낙뢰 strikes the first creature on its line and arcs from foe to foe. User: "`벼락` -> `낙뢰`, 체인 라이트닝같이 여러 적을 오가며 공격하게 해 (3칸 이내 적에게 옮겨붙음, 최대 10번까지)".
- A leap strikes what it collides with by the tiles it has left, as a knockback does, and the leaper takes nothing. A creature is leapt over; a wall is what it collides with. User: "넉백 규칙 아까 말했잖아? 도약하면 마찬가지로 똑같은 원리로 충돌한 대상에 피해주게 해. 단, 도약한 대상은 피해를 입지 않음", "나무 1장마다 +1칸이 아니라 +3칸으로 바꿔".
- 오작교 bridges the sky along the aimed way. User: "오작교 7x7 말고 해당 방향으로 8x3으로 바꿔줘".
- 용암 is 구+불+흙, an orb that does not home: range 5, speed 2, bursts when spent, 3x3 hot iron. 봉화 hurls it homing in 8 directions. 용광로 is 구+불+흙+쇠: a furnace on a random free tile within 3 that hurls it every 2 s at a foe in sight. Without 구 they are no spell. User: "용암은 용암 구슬을 발사하는 주문으로 바꿔 (구+불+흙)", "봉화는 8방향으로 '유도' 용암 구슬 발사하는 주문으로 바꿔", "3칸 이내 범위에 무작위로 1개".
- A plain orb and 비격진 differ: 비격진 bursts 2 tiles round with its own wave. User: "이제 일반 구슬도 폭발하면서 비격진이랑 일반 구슬이랑 차이가 없어 차별화시켜."
- A spell of 쇠 that explodes has a proximity fuse: in flight it bursts beside a foe, so stepping aside does not dodge it. User: "폭발성 쇠 조합 주문들은 '근접신관' 기능 추가해. 즉 날아가다 적이 옆으로 이동해도 피할수 없고", "구+쇠면 근접신관을 다는거로 하자". A burst lays no hot iron under its caster. User: "2칸 거리면 적 앞애서 터져서 피해 없어야하는거아냐?"
- A creature's 번개 is lightning, never a wisp: it crosses its range at once and stays nowhere. User: "왜 도깨비불같이 동작함? 노란색/하얀색 색상에 번개와 닮은 유니코드 심볼로 으로 멋있게 번쩍거려야하는거아냐?". Every lightning spell, 낙뢰 too, strikes at once and flickers as the white and yellow zigzag (`TermMarks.zigzag`), no font glyph. User: "번개 주문은 번개니까 날아가는 애니메이션 없이 '즉시' 일어나야함", "지그재그말한거엿어".
- Flyers: 박쥐 on low storeys, 삼족오 of fire on high ones. User: "비행형 적 박쥐 (저층)와 삼족오(불, 고층) 추가해."
- The guns of 쇠: 쇠 is 권총, 쇠쇠 소총, 여+쇠 관통탄, 여+쇠+쇠 철갑탄. User: "쇠 = 권총, 쇠쇠 = 소총, 여 + 쇠 = 관통탄, 여쇠쇠 = 철갑탄".
- 이무기 has a strong melee as well as its spell. User: "이무기에 강한 근접 공격 추가". No 달걀귀신 comes on storey 2; a 도깨비 took its place. User, asked "2층의 달걀귀신을 도깨비로 되돌릴까요?": "2층엔 도깨비로". Flyers and creatures that fire does not burn cross hot iron unharmed.
- A creature is immune to the element its own beats and weak to the one that beats it (`Cards.BEATS`), immune winning where both meet. A creature of fire is immune to 쇠 and hit by a fire spell, and burning tiles and 불붙음 do nothing to it. 불가사리's immunity to a spell with no fire stays, and so does 불여우's own to fire. User: "오행에 대한 면역은 오행 기반으로 일관적으로 적용되게 전부 교체해. 가령 해태: `물` 이니까 `불` 면역, 두억시니는 `흙` 속성이니 `물` 면역".
- A storey's order and its concept change from run to run, the ninth too. User: "9층도 여러 컨셉으로". All ten shapes stay, and one more is a corridor of 3 tiles wide that turns many times. User: "여러번 꺾인 3칸 복도같은거 시안에 있을줄 알았는데 없네 이것도 추가필요".
- A labyrinth comes in 40% of runs, and it has many concepts, one of them the island that cannot be walked back from. Its prize is 2 or 3 peaches and it is not found by guessing the middle or broken into through a wall; two or three creatures guard it; its door may be hidden; explore still works in it. User: "한 판에 40% 확률로", "복숭아는 2~3개, 보상은 좋긴 한데 두억시니 하나는 좀 약한 위협인듯. 또한 가운데에 보상이 있으면 예측하기 쉬운 문제도 있고 벽 부숴서 건너가면 그만일것같아서 완전 정통 미로로 하는게 좋을지도 (또는 미궁 종류를 네종류 이상 아주 다양하게)", "미궁에 적이 그래도 두셋은 있어야 리스크가있을듯".
- 전기 hurts wood and fire. User: "전기는 나무, 불은 피해 입도록 하고 흙만 면역으로 해".
- A knocked 병풍 is heard 4 tiles. User: "병풍이 소음 6칸인건 말이 안되지 않아? 4칸으로 낮춰".
- A plate goes off for Miho, a creature and a projectile. User: "함정은 {적/플레이어/투사체}로 작동하게해".
- A push into a wall harms the creature and the wall by the tiles left of the push. User: "넉백시 벽에 부딫히면 남은 넉백 거리에 비례해서 벽과 대상에 피해를 줘": `벽 @외` flown 2 gives 1 and 1, `벽@외` flown 2 gives 2 and 2.
- Before you add a tile, status, state or creature field, diff it against the existing table (src/core/tiles.gd, Actor, Info.state). If its rules match an existing entry, reuse that entry. Never add a themed name with the same rules.
- Level design teaches by arrangement, not by text. A secret or puzzle looks like ordinary terrain. Examples: a plain wall in front of an empty space, or three dark lanterns in a row. Never add an artificial prop whose hover explains the solution.
- Never add a gameplay limit the user did not ask for: a damage cap, a balance ceiling, or a test that enforces one. A numeric limit a lane needs goes to the user first, in plain words.
- Write no test that only mirrors a table, a name or a string, or repeats the expression the code uses. Check those with `rg`. Test behaviour.

## Player-facing text (hover, sidebar, 도감, log)

- Read the reference first. Before you add or change a line for a kind of thing, read the code that shows the same kind of thing in an open-source roguelike, and name the function in your report. A shape that no reference uses needs a stated reason. User: "슬롭 지적의 원인은 너가 다른 오픈소스 로그라이크의 ui코드 조사를 충분히 안해서". References:
  - DCSS, `/home/scarf/repo/crawl/crawl-ref/source/describe.cc`: `_monster_stat_description`, `_monster_attacks_description`, `_monster_spells_description`, `get_feature_desc`, `get_cloud_desc`, `_player_spell_desc`, `_get_spell_description`; `describe-spells.cc`: `_describe_book`.
  - Brogue CE, `/home/scarf/repo/etc/roguelike-algorithms/vendor/brogue-ce/src/brogue/`: `Monsters.c` `monsterDetails`, `getMonsterAbilitiesText`; `Items.c` `itemDetails`.
- Write `이름: 값` or a bare tag: `모양: 유도 구슬`, `피해: 2`, `소음: 3`, `가연성.`, `면역: 불`.
- A creature that takes half harm from a spell tells `내성: 불이 섞인 주문`, and the 내성 entry tells `해당 주문에 피해를 절반만 입음`. A creature that takes none tells `면역: 불`. The burning tile is named `불`, as `맹렬한 불` is. User: "`피해 절반: 불이 섞인 주문` -> `내성: 불`, `내성` 키워드 설명: `해당 주문에 피해를 절반만 입음`", "불타는 칸 -> `불` (`맹렬한 불` 과 어감 맞추기 위해)", "`면역: 불 주문, 불타는 칸` -> `면역: 불`, `피해 절반: 불이 섞인 주문` -> `내성: 불이 섞인 주문`".
- A status a spell causes is one line with the status word coloured. The status has its entry in the 도감 상태이상 tab.
- Never type a game value into a string: a spell name, a recipe, a list of spells, a count, a radius or a chance comes from its table or constant, so a change to the data changes the text. Use `"스스로에겐 %s만 걸 수 있다"` with the list filled from the table, never `그림자(여+수)나 둔갑(목+토)`.
- A lone spray goes by its name alone: `불길`, never `불 불길`. Label words are plain Korean game words: `대상`, never `노림`.
- Do not write explanatory or causal sentences (`N하면 M한다`, `N해서 M하다`).
- The player is `당신` where a line could be read as about someone else, as roguelikes such as DCSS write `You`: `당신을 볼 수 없다` on a creature hover. `미호` is only the title of the game. A log line that can only be about the player drops the word. User: "`당신의 둔갑이 풀렸다` -> `둔갑이 풀렸다`가 훨씬 낫지않아? 지난번에 지적했던건 적 호버했을때 문구여서 헷갈릴수 있단거고 이건 누가 봐도 자기자신이 대상인걸 알수있잖아."
- Delete every line that would not change what the player does. That includes "water is wet" lines and restatements of another line.
- A thing lists what it has. Never add a line that denies what another thing has: kimchi does not say `최대 체력: 오르지 않음` when the peach says `가득 찼을 때 최대 체력: +1`, and a wall does not say `부술 수 없다.` when a cracked wall says `부서짐: 구슬`. The same goes for what the player already assumes, such as `멈춤: 첫 적` beside `관통`, or `바닥이 됨: 풀` on a spell with `피해: 1`. User: "이 두 문장이 대체 뭔 가치가 있음". A negative stays only when nothing else tells it and the player would act otherwise: `냄새가 남지 않음.`
- Do not write hints, guesses or control tips, for example "숨은 문일 수 있다", "뒤에 숨을 수 있다" or "X키로 닫는다".
- A hover box lists the key of every action the player can take on what it shows, the detail key first, as DCSS `direction_chooser::print_key_hints` prints `v - describe`. User: "dcss/cataclysm처럼 상세보기 키를 UI에 표시해줘", issue #15: "x로 문 위로 호버한 경우 `m 자세히` -> `m 자세히 c 닫기 v 위험구역 표시`".
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
  - `늪 가스` -> `늪 기체`. User: "영어는 가능한 한 지양해".
  - `길 위의 투사체: 돌아서 감` -> `날아오는 투사체를 피할 수 있다.` User: "이게 대체 뭔소리임?!". What a creature can do is a sentence, not a label and a value glued from a code rule.
  - The 사령술 hover is two lines. User: "사령술 설명이 완전 slop이야. 사람이었다면 이렇게 썼을꺼야: 지속 시간: 다음 층까지 / 시야에 보이는 시체를 아군으로 되살린다. 강한 적은 달걀귀신으로, 약한 적은 객귀로."
  - `냄새 추적` -> `후각이 뛰어나다`
  - `속지 않음: 교활함`, `둔갑하는 걸 보면 추격: 영리함`, `눈앞에서 쓰면 속지 않음: 영리함` -> `교활한 적, 후각이 뛰어난 적, 추격 중인 적에게는 효과가 없다.` User: "여전히 슬롭같음. 사람이었으면 둔갑 주문 설명엔 `*교활*한 적에게는 효과가 없다.` 정도로 쓰고". Who a spell works on is a plain sentence, with a label-and-list line only for numbers and tags.
    - `1초 뒤 되살아나는 시체` -> `객귀의 저주`. A thing's name is a name, and what it does goes in its entry. User: "이건 동작을 설명한건데 이걸 그대로 쓴다고? 명칭 `객귀의 저주` 로 바꿔".
  - `흙: 진흙` -> `흙 주문: 진흙이 됨`. User: "의미불명".
  - `주문과 멀리뛰기로만 건널 수 있다.` -> `이동 불가.`. User: "그냥 `이동 불가.` 태그면 끝 아닌가".
  - `유탄 탄환` -> `유탄`. User: "이미 유탄에 탄환이란 의미가 있어서 동어반복".
  - `하늘로 떨어져 2층으로 내려왔다` + `착지했다` -> `2층으로 추락했다`, or `2층으로 내려왔다` when 도약 softens it. One line, no restated cause. User: "ㄴㄴ `2층으로 내려왔다` or `2층으로 추락했다` 같이".
- A click on a suggested spell or a saved spell fills the queue. User: "클릭하면 당연히 프리셋으로 채워줄줄 알았는데 아니야". The keyboard alone can aim at Miho. User: "키보드만으로 스스로를 겨눌 방법이 없어". Explore never takes the stairs. User: "자동탐색 했는데 그냥 다음 층으로 올라가버림. 이래선 안됨". On storey 1 Miho starts inside the pavilion and its door to the outside is a 1-tile 위험구역, so explore stays inside but she can walk out. User: "천상누각 밖으로 나가는 문은 1칸짜리 위험구역으로 만들고 미호를 천상누각 안에서 시작하게 함으로써 자연스럽게 자동 탐색으로는 밖으로 나가지 못하게, 하지만 원한다면 나갈 수 있게". She starts inside, right before that door, storey 1 is one building with no skybridge between its parts, and no wall is laid round it. User: "하늘누각 _밖_에서 문 앞에 있잖아요, _안_에서 문 앞에 있게 바꿔주세요", "1층에선 '전부 하나로 연결된' 구조만 나오게 해주세요 (하늘다리로 연결된 여러 방 등의 generator 제외)".
- A cast the player would regret asks at the moment it matters: `{적 이름} 눈앞에서 *둔갑*할까? Y/N`. User: "`{적 이름} 눈앞에서 *둔갑*할까? y/n` 같은 식이 더 나을듯". Every Y/N question ends this way: `영약을 마실까? Y/N`, `주문을 쓸까? Y/N`, not `영약을 마십니까?`. User chose `~할까?` ("후자로 ㄱㄱ").
- 꼬리 and 여우불 are the player's words. A creature has 마력, and its wisps are 도깨비불, 저승불 or 혼불 (Bestiary.WISP_NAME).
- One thing keeps one name on every screen: 불붙음, 젖음, 묶임, 소음, 피해. A label is the word a Korean game prints (`속도`, `관통`, `착지`, `소화`), never a verb that reads as prose or a coined noun.
- Every bare tag that carries a rule has an entry in `Glossary.rows`, its rule read from the code that applies it. A tag whose rule changes nothing the player does is deleted. Every name that has an entry in any 도감 tab (`Codex.entries`, so a new entry needs no list) is a word: in the 도감 detail, the spellbook detail, the log and help pages and the log over the map, the pointer over it shows the entry in a box under the pointer, and a left click or a tap opens that entry in its own tab, Esc going back (Keywords, WordHover, WordLink). A name is found whole or before a particle, never inside a longer word. A hover box follows the pointer, so while Shift is held (a long press on touch) the box that is open stays and its words work the same way (`WordHover.hold`, `Term.pin`): the map, sidebar creature, status row, talisman, saved spell and queue slot boxes and a word box on a page.
- The 도감 has no tab for characters, so 여동생 has no 도감 entry. User: "도감에 인물에 대한 탭은 없으니, 여동생은 도감에서 빼주세요."

## UI conventions

Every list, menu and scrolling pane follows standard conventions:
- Up/Down with key repeat when held, wrapping at both ends.
- PgUp/PgDn with repeat, Home and End.
- The mouse wheel scrolls, hover highlights, click selects.
- Tabs switch with Left/Right, Tab or a click.
- The selection stays in view. Esc closes and returns to where the list was opened.
- Every screen is reachable from the Esc menu.
- A shortcut label beside what it stands for (a talisman number, a saved spell key) is small and dim, one look on every screen (`Term.draw_key`): `1~7` are easy to remember, so the label never competes with the glyph. A key that is itself the content of a line, as in the help and key pages, stays body size.

An example in the 도감 shows the spell doing what it does: it hits. User: "도감의 조합 애니메이션들 전부 확인하는게 좋을꺼야. 가령 용광로 설명에선 한 발도 못 맞춤".

The debug commands open over the game and stay open between commands. User: "`디버그` 누르면 설정으로 가지 않고 바로 게임 화면에 디버그 메뉴 뜨게 해서 빠르게 여러 디버그 조작할수있게해".

A thing with a background of its own shows it in the dark too. User: "복숭아 배경색이 여전히없어".

An example in the 도감 is picked, never only watched. A creature's example has a part for its strike and for each spell, and the creature does them itself. User: "1~5단계까지 진행되는거 계속 바라만 봐야함", "적 주문 보여주는건데 플레이어가 주문 시전하는거로 보여주는거", "근접공격, 주문들 각각 선택해서 볼수있게 해".

A run that has ended has nothing to lose, so a new run starts at once, by R too. User: "ctrl+q는 원래 살았을때 재시작 키여서 y/n 요구하는건데 왜 죽었을때도 요구해? 의미없잖음".

Every player-visible event has a fitting sound:
- Terrain footsteps sound by tile.
- A find (a hidden door, a spotted thing) has a quiet neutral tick, a danger warns, and the bright chime is for a max health rise only.
- Check `Sfx.sound_of` for every new event.

## Merge gate (parent)

Every task runs in its own worktree. A lane runs focused tests only. The oracle, the full suite and `SaveGame.VERSION` belong to the parent: it runs and records them in the background after the merge. User: "작업마다 개별 worktree에서 작업해", "오라클 등 전체 테스트는 병합 후 background에서 돌려".

A commit that finishes every point of an issue ends its body with `Closes #N`, so the push to main closes the issue. A commit that does part of one writes `Part of #N`. User: "커밋에 `closes #1` 처럼 하지 않은건가요? 그렇게 해야할것같은데요".

Force-push is allowed on every branch of this repository, main too, so a needed history fix (a rebase, a reworded or dropped commit) is done, never skipped or worked round. Push with `--force-with-lease`, keep every commit that is not the one being fixed, and never move a released tag. User: "그냥 이 repo는 force push 허용한다고 명시좀 해주세요. force push 핑계로 작업 버리는 일좀 막게."

Work runs as a software factory (StrongDM, https://factory.strongdm.ai/): the parent writes a spec and holdout scenarios, a lane implements from the spec alone, and the parent judges the lane by the share of holdout scenarios that pass. The scenarios stay outside the repository and outside the lane's brief, so a lane cannot fit them. The merge gate below still applies. User: "소프트웨어 팩토리 방식으로 해주시고요".

Closing an issue of this repository is allowed (`gh issue close`, `.claude/settings.json`): when every point of an issue, or every sub-issue of a parent issue, is done on main, close it. Do not comment on it. User: "이슈 닫는 것도 이 저장소에서 허용하게 해주세요."

An issue body is Korean, as its title is, and shows its frames as WebP images on the orphan `images` branch, linked through jsDelivr pinned to the commit (`https://cdn.jsdelivr.net/gh/scarf005/miho@<commit>/<sha256>.webp`). User: "이슈에 이미지들이 없으니 이해하기 힘들고 (cdn으로 이미지 올려주세요), 제목은 한글인데 본문은 또 영어이군요."

Passing tests and lint do not prove a lane is done. Before merging a lane that changes anything the player sees or hears, the parent must do all of the following:
1. Read every added or changed user-facing string in the diff against the text rules above, then read it aloud as Korean and rewrite it if a player would not say it. Before a tag, read the whole list from `just strings`.
2. Drive the changed UI with `just shot ... --keys=...` and look at the frames.
3. Check that each new event maps to a sound.
4. Fix the whole class of a reported defect, not only the quoted line.
5. After the merge, run `just launch-check` from the main checkout, the one the user plays from. A frame or a test run in a lane worktree does not prove that checkout starts. User: "설마 게임 실행이 되는지조차 확인 안하고 커밋한건 아니겠지".
