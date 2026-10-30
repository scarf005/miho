class_name Highlight
extends RefCounted
## The best moment of a storey, replayed when Miho leaves it (like a play of
## the game). Every round is recorded with the world before it; rounds score
## from their events, and the best short window that starts and ends on a
## scoring round wins. Rules are deterministic, so replaying the recorded
## actions from the first snapshot plays the moment exactly again.

const MIN_ROUNDS := 3
const MAX_ROUNDS := 8
const LEAD := 1
const PER_ROUND := 0.25

## {world: World before the round, action, score}
var rounds: Array[Dictionary] = []


func record(before: World, action: Dictionary, events: Array) -> void:
	rounds.append({world = before, action = action, score = score(before, events)})


func clear() -> void:
	rounds.clear()


static func score(before: World, events: Array) -> int:
	var me := before.player().id
	var kills := 0
	var total := 0
	for e in events:
		match e.t:
			&"die":
				if e.id != me:
					kills += 1
			&"claw":
				if e.sneak:
					total += 2
			&"card":
				total += 4
			&"hurt":
				if e.id == me:
					total += 1
			&"blind", &"stun", &"root", &"clash":
				total += 1
	return total + kills * 3 + maxi(0, kills - 1) * 4


## First and last round of the best window, with a round of lead-in, at least
## MIN_ROUNDS long; the last rounds when nothing scored. Empty when nothing was recorded.
func best() -> Dictionary:
	if rounds.is_empty():
		return {}
	var from := rounds.size() - 1
	var to := from
	var top := 0.0
	for i in rounds.size():
		if rounds[i].score <= 0:
			continue
		var total := 0
		for j in range(i, mini(rounds.size(), i + MAX_ROUNDS)):
			total += rounds[j].score
			var value := total - PER_ROUND * (j - i)
			if rounds[j].score > 0 and value > top:
				top = value
				from = i
				to = j
	from = maxi(0, mini(from - LEAD, to - MIN_ROUNDS + 1))
	return {from = from, to = to}


## The window as a fresh world and the actions to replay on it.
func clip(window: Dictionary) -> Dictionary:
	var actions: Array[Dictionary] = []
	for i in range(window.from, window.to + 1):
		actions.append(rounds[i].action)
	return {world = (rounds[window.from].world as World).clone(), actions = actions}
