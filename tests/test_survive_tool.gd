extends GutTest
## The survival tool's bot plays a seed the same way every time.

const Bot := preload("res://tools/survive_bot.gd")


func test_a_seed_plays_the_same_run_twice() -> void:
	assert_eq(Bot.play(2), Bot.play(2))
