extends GutTest
## Def→.tres 数据管线：资源表可加载、字段反序列化正确。

func test_load_hero_tres():
	var hero = load("res://resources/heroes/swordsman.tres")
	assert_eq(hero.display_name, "剑士")
	assert_eq(hero.attack_damage, 12)
	assert_almost_eq(hero.attack_interval, 0.8, 0.001)
	assert_almost_eq(hero.range_tiles, 1.5, 0.001)

func test_load_monster_tres():
	var m = load("res://resources/monsters/goblin.tres")
	assert_eq(m.display_name, "哥布林")
	assert_eq(m.max_hp, 30)
	assert_almost_eq(m.move_speed, 1.2, 0.001)
	assert_eq(m.armor, 0)
	assert_eq(m.gold_drop, 3)
