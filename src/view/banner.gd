class_name Banner
extends RefCounted
## The lines drawn over the map on the title and on the ending, in the language
## shown.


## The title's lines; it offers to continue when `pending` is a run on disk.
static func title(pending: SaveGame) -> Array[String]:
	return [
		Lang.t("미호"),
		Lang.t("천상누각 꼭대기에 사람이 되는 영약이 있다"),
		Lang.t("아무 키나 눌러 시작" if pending == null else "Enter 이어하기 · N 새로 시작"),
	]


## The ending's lines: how the run ended, how far, kills, the seed and the key
## that starts over (`again`).
static func over(won: bool, w: World, kills: int, seed_value: int, again: String) -> Array[String]:
	return [
		Lang.t("사람이 되었다" if won else "쓰러졌다", "banner"),
		Lang.t("%d층 · %d초") % [w.depth, w.round_no],
		Lang.t("처치 %d") % kills,
		Lang.t("시드 %d") % seed_value,
		Lang.t("%s키를 눌러 재시작") % again,
	]
