extends GutTest
## 实体状态：英雄伤害乘算/急速间隔、怪物减速移速、最近索敌。

const Entities = preload("res://src/core/battle/entities.gd")
const Targeting = preload("res://src/core/battle/targeting.gd")
const GridScript = preload("res://src/core/battle/grid.gd")
const HeroDefScript = preload("res://src/core/def/hero_def.gd")
const MonsterDefScript = preload("res://src/core/def/monster_def.gd")

const WPS: Array = [Vector2i(-1, 1), Vector2i(13, 1), Vector2i(13, 8), Vector2i(2, 8)]

func _hero_def() -> HeroDef:
	var d := HeroDefScript.new()
	d.attack_damage = 12
	d.attack_interval = 1.0
	d.skill_haste_pct = 30
	return d

func _mon_def(hp := 30, speed := 1.0) -> MonsterDef:
	var d := MonsterDefScript.new()
	d.max_hp = hp
	d.move_speed = speed
	return d

func test_hero_damage_multiplier_rounds():
	var h = Entities.Hero.new(1, _hero_def(), Vector2i(12, 2))
	assert_eq(h.damage(), 12)
	h.damage_mult = 1.3
	assert_eq(h.damage(), 16)  # round(15.6)
	h.damage_mult = 1.3 * 1.3
	assert_eq(h.damage(), 20)  # round(20.28)

func test_hero_haste_shortens_interval():
	var h = Entities.Hero.new(1, _hero_def(), Vector2i(12, 2))
	assert_almost_eq(h.attack_interval(), 1.0, 0.001)
	h.haste_timer = 2.0
	assert_almost_eq(h.attack_interval(), 100.0 / 130.0, 0.001)

func test_monster_slow_reduces_speed():
	var m = Entities.Monster.new(1, _mon_def(30, 1.2))
	assert_almost_eq(m.move_speed(), 1.2, 0.001)
	m.slow_factor = 0.5
	m.slow_timer = 1.0
	assert_almost_eq(m.move_speed(), 0.6, 0.001)
	m.slow_timer = 0.0
	assert_almost_eq(m.move_speed(), 1.2, 0.001)

func test_nearest_in_range_picks_closest():
	var g = GridScript.new(16, 10, WPS)
	var m1 = Entities.Monster.new(1, _mon_def())
	var m2 = Entities.Monster.new(2, _mon_def())
	m1.path_dist = 12.0  # (11.5,1.5) 距英雄  ≈ 1.414
	m2.path_dist = 13.0  # (12.5,1.5) 距英雄 1.0 更近
	var got = Targeting.nearest_in_range([m1, m2], g, g.cell_to_pos(Vector2i(12, 2)), 1.5)
	assert_eq(got.id, 2)

func test_nearest_in_range_out_of_range_returns_null():
	var g = GridScript.new(16, 10, WPS)
	var m = Entities.Monster.new(1, _mon_def())
	m.path_dist = 10.0  # (9.5,1.5) 距英雄 ≈ 3.04
	assert_null(Targeting.nearest_in_range([m], g, g.cell_to_pos(Vector2i(12, 2)), 1.5))
