extends GutTest
## 局内经济：金币账本与升级常量。

const Economy = preload("res://src/core/battle/economy.gd")

func test_initial_gold_and_gain_spend():
	var e = Economy.new(100)
	assert_eq(e.gold, 100)
	e.gain(30)
	assert_eq(e.gold, 130)
	e.spend(80)
	assert_eq(e.gold, 50)

func test_can_afford():
	var e = Economy.new(39)
	assert_false(e.can_afford(Economy.UPGRADE_COST))
	e.gain(1)
	assert_true(e.can_afford(Economy.UPGRADE_COST))

func test_upgrade_constants():
	assert_eq(Economy.UPGRADE_COST, 40)
	assert_almost_eq(Economy.UPGRADE_DAMAGE_MULT, 1.3, 0.001)
	assert_almost_eq(Economy.UPGRADE_INTERVAL_MULT, 0.85, 0.001)
