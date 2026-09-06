extends GutTest
## Def→.tres 数据管线：P2 全量表可加载、字段反序列化正确。

func test_hero_swordsman():
	var h = load("res://resources/heroes/swordsman.tres")
	assert_eq(h.id, "swordsman")
	assert_eq(h.display_name, "剑士")
	assert_eq(h.cost, 60)
	assert_eq(h.attack_damage, 12)
	assert_almost_eq(h.attack_interval, 0.8, 0.001)
	assert_almost_eq(h.range_tiles, 1.5, 0.001)
	assert_eq(h.skill_kind, "whirl")
	assert_eq(h.skill_cooldown, 8.0)
	assert_eq(h.skill_damage, 20)

func test_hero_archer():
	var h = load("res://resources/heroes/archer.tres")
	assert_eq(h.id, "archer")
	assert_eq(h.cost, 80)
	assert_eq(h.attack_damage, 9)
	assert_almost_eq(h.range_tiles, 3.5, 0.001)
	assert_eq(h.skill_kind, "arrow_rain")
	assert_eq(h.skill_damage, 24)

func test_hero_mage():
	var h = load("res://resources/heroes/mage.tres")
	assert_eq(h.id, "mage")
	assert_eq(h.skill_kind, "frost_ring")
	assert_eq(h.skill_slow_pct, 50)
	assert_almost_eq(h.skill_slow_duration, 3.0, 0.001)

func test_hero_cannonier():
	var h = load("res://resources/heroes/cannonier.tres")
	assert_eq(h.id, "cannonier")
	assert_eq(h.cost, 140)
	assert_eq(h.attack_damage, 32)
	assert_eq(h.skill_kind, "barrage")
	assert_almost_eq(h.skill_radius, 2.5, 0.001)

func test_hero_priest():
	var h = load("res://resources/heroes/priest.tres")
	assert_eq(h.id, "priest")
	assert_eq(h.skill_kind, "aegis")
	assert_eq(h.skill_haste_pct, 30)
	assert_almost_eq(h.skill_duration, 4.0, 0.001)

func test_monster_goblin():
	var m = load("res://resources/monsters/goblin.tres")
	assert_eq(m.id, "goblin")
	assert_eq(m.max_hp, 30)
	assert_almost_eq(m.move_speed, 1.2, 0.001)
	assert_eq(m.gold_drop, 3)
	assert_eq(m.leak_damage, 1)

func test_monster_wolf():
	var m = load("res://resources/monsters/wolf.tres")
	assert_eq(m.id, "wolf")
	assert_eq(m.max_hp, 25)
	assert_almost_eq(m.move_speed, 2.0, 0.001)

func test_monster_orc():
	var m = load("res://resources/monsters/orc.tres")
	assert_eq(m.id, "orc")
	assert_eq(m.max_hp, 60)
	assert_eq(m.armor, 2)

func test_monster_shaman():
	var m = load("res://resources/monsters/shaman.tres")
	assert_eq(m.id, "shaman")
	assert_almost_eq(m.heal_radius, 2.0, 0.001)
	assert_eq(m.heal_amount, 8)
	assert_almost_eq(m.heal_interval, 3.0, 0.001)

func test_monster_golem():
	var m = load("res://resources/monsters/golem.tres")
	assert_eq(m.id, "golem")
	assert_eq(m.max_hp, 150)
	assert_eq(m.armor, 8)

func test_monster_ogre_lord():
	var m = load("res://resources/monsters/ogre_lord.tres")
	assert_eq(m.id, "ogre_lord")
	assert_eq(m.max_hp, 800)
	assert_true(m.is_boss)
	assert_eq(m.leak_damage, 3)
	assert_almost_eq(m.stomp_radius, 2.5, 0.001)
	assert_almost_eq(m.stomp_stun_duration, 2.0, 0.001)
