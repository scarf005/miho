class_name Glossary
extends RefCounted
## The rules many things share, by the tag their hover shows instead (Info), one
## `이름: 값` line each: the 도감's glossary (Codex).


## What washes the scent away: water, the spells that say so and the gases that do.
static func _scent_erasers() -> Array:
	var gases := Gas.ROWS.values().filter(func(g): return g.get("erases", false))
	return (
		[Lang.t("물 주문"), Lang.t(Cards.NAME[&"mist"]), Lang.t(Cards.NAME[&"stillness"])]
		+ gases.map(func(g): return Lang.t(g.name))
	)


static func rows() -> Dictionary:
	var spread := roundi(Tiles.DEFAULT.spread * 100)
	var burn := Lang.t("불타는 시간: %d초") % World.BURN_ROUNDS
	var night: int = World.NIGHT[Actor.HEAVEN]
	var no_sleep := Lang.t(Info.NO_SLEEP) + "."
	var no_scent := ", ".join(SpellInfo.tiles_with("scentless") + [Lang.t("불타는 칸")])
	return {
		Info.ALLY: ["자리 바꿈: 걸어 들어갈 때", Lang.t("함께 올라감: %d칸 안에 있을 때") % Storeys.FOLLOW],
		"밀침": ["벽에 부딪히면 남은 칸 수만큼 벽과 함께 피해를 입는다."],
		"이동 불가": [Lang.t("넘을 수 있음: 주문, %s") % Lang.t(Spell.SHAPE_NAME[Spell.LEAP])],
		"가연성":
		[
			burn,
			"불탄 뒤: 재",
			Lang.t("번지는 속도: 초당 %d칸") % Terrain.SPREAD_STEPS,
			Lang.t("번질 확률: %d%%") % spread
		],
		"인화성":
		[
			burn,
			"불탄 뒤: 재",
			Lang.t("번지는 속도: 초당 %d칸") % Terrain.FIERCE_STEPS,
			Lang.t("초당 피해: %d") % World.FIERCE_DAMAGE
		],
		"함정":
		[
			Lang.t("발견: 밝은 칸 또는 %d칸 안") % Traps.REACH,
			"작동: 밟은 생물, 지나간 투사체",
			"밟는 적: 추격 중인 적",
		],
		"흔적": ["수색하는 적: 추격 중이 아닌 적", "횟수: 적마다 한 번"],
		"약점":
		[
			Lang.t("피해: ×%d") % Elements.WEAK,
			"대상: 그 원소가 든 주문",
			Lang.t("막는 원소가 섞인 주문: ×%d") % (Elements.WEAK / Elements.HALF),
		],
		Info.ELECTRIC: _shocks(),
		"달라붙음": ["빛: 맞은 대상을 따라 움직임", "감투 쓴 적: 보임"],
		"둔함": ["주문을 보면: 날아가는 칸을 수색"],
		"영리함":
		[
			"주문을 보면: 쏜 곳을 수색",
			"날아오는 투사체를 피할 수 있다.",
			"눈앞에서 둔갑: 추격",
			Lang.t("북 치기: 추격 중 걸어서 %d칸 안") % Drums.REACH,
			Info.SUSPECTS
		],
		"교활함":
		[
			"주문을 보면: 쏜 곳에서 추격",
			"날아오는 투사체를 피할 수 있다.",
			"눈앞에서 둔갑: 추격",
			"둔갑: 속지 않음",
			Lang.t("북 치기: 추격 중 걸어서 %d칸 안") % Drums.REACH,
			"여우불 소음: 던진 곳을 수색",
			Info.SUSPECTS,
		],
		"순찰": ["쉴 때: 방 사이를 돌아다님", no_sleep, "무리: 대장을 따라다님"],
		"고정": ["움직이지 않음.", no_sleep],
		"수중":
		[
			Lang.t("이동: %s") % ", ".join(SpellInfo.tiles_with("water")),
			no_sleep,
			"서 있는 물이 없어지면 사라진다."
		],
		"끌어당김":
		[
			(
				Lang.t("물 밖에서 맞으면 적 옆의 빈 %s 끌려간다.")
				% StepGuard.toward(Lang.t(Tiles.of(World.SHALLOW, "name")))
			),
			"풀린 뒤에야 다시 묶을 수 있다."
		],
		"불에 탐": ["불붙음: 불이 든 주문에 맞을 때"],
		"위치 감지": ["추격: 항상", "보지 못해도 당신을 쫓아감", no_sleep],
		Info.SMELL:
		[
			"쉬거나 수색 중: 당신의 냄새를 따라감",
			"은신한 당신을 추격할 때: 냄새부터 따라감",
			"둔갑: 속지 않음",
			Lang.t("남은 냄새: %d초 이내") % Scent.TRAIL_AGE,
		],
		"등불 켜기": ["깨어 있을 때: 옆 칸의 꺼진 등불을 먼저 켬"],
		"밝음": ["적에게 보임: 시야 안 어디서나"],
		"어두움":
		[
			Lang.t("적에게 보임: %d칸 안") % night,
			Lang.t("경계한 적: %d칸 안") % (night + World.WARY_SIGHT),
			Lang.t("당신이 보는 거리: %d칸") % World.NIGHT[Actor.FOX],
		],
		"외침": ["시작: 추격을 시작할 때", "들은 적: 추격 중이 아니면 당신을 본 곳을 수색", "듣지 못하는 적: 소음 면역"],
		"수색":
		[
			"시작: 소음, 흔적, 날아오는 주문",
			"그 칸으로 이동",
			Lang.t("둘러봄: %d번") % World.SEARCH_ROUNDS,
			"끝: 쉬는 중",
			"당신을 보면: 추격 중",
		],
		"추격":
		[
			"시작: 당신을 봄, 주문에 맞음",
			"놓치면: 마지막으로 본 곳, 냄새를 따라감",
			"끝: 수색 중",
		],
		Info.ASLEEP: ["시야: 없음", "깨어남: 소음, 피해"],
		"소음":
		[
			"범위: 소음 값만큼의 칸, 벽을 돌아서",
			"당신은 범위 안의 소음을 모두 들을 수 있다.",
			"적: 소음이 난 곳을 수색",
			"추격 중인 적: 수색하지 않음",
		],
		"냄새":
		[
			"남김: 당신이 선 칸",
			Lang.t("남는 시간: %d초") % Scent.TRAIL_AGE,
			Lang.t("진한 냄새 남는 시간: %d초") % (Scent.TRAIL_AGE + Scent.STRONG_EXTRA),
			Lang.t("안 남는 칸: %s") % no_scent,
			Lang.t("지워짐: %s") % ", ".join(_scent_erasers()),
		],
	}


## What 전기 does to a creature (Elements.charge), one `이름: 값` line each: the
## elements that double its harm, wet, and those that make a dry creature immune.
static func _shocks() -> Array:
	var twice := Lang.t("피해 ×%d") % Elements.WEAK
	var out := []
	for e in Elements.CONDUCTS:
		out.append("%s %s: %s" % [Lang.t("오행"), Lang.t(Cards.NAME[e]), twice])
	out.append("%s: %s" % [Lang.t(Status.NAME[&"wet"]), twice])
	for e in Elements.GROUNDS:
		out.append("%s %s: %s" % [Lang.t("오행"), Lang.t(Cards.NAME[e]), Lang.t("면역")])
	return out
