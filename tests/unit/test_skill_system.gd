extends GutTest
## 技能系统：5 技能效果与失败分支（用桩 sim 隔离测试）。

const SkillSystem = preload("res://src/core/battle/skill_system.gd")
const Entities = preload("res://src/core/battle/entities.gd")
const GridScript = preload("res://src/core/battle/grid.gd")
const HeroDefScript = preload("res://src/core/def/hero_def.gd")
const MonsterDefScript = preload("res://src/core/def/monster_def.gd")

const WPS: Array = [Vector2i(-1, 1), Vector2i(13, 1), Vector2i(13, 8), Vector2i(2, 8)]

class StubSim:
	extends RefCounted
	var grid = null
	var monsters: Array = []
	var heroes: Array = []
	func apply_damage(m, dmg: int, events: Array) -> void:
		var real: int = maxi(0, dmg - m.def.armor)
		m.hp -= real
		events.append({"type": "hurt", "data": {"id": m.id, "hp": maxi(m.hp, 0), "damage": real}})
		if m.hp <= 0:
			m.alive = false
			events.append({"type": "monster_died", "data": {"id": m.id}})

func _hero(kind: String, radius := 1.5, dmg := 20) -> Entities.Hero:
	var d := HeroDefScript.new()
	d.id = "t_" + kind
	d.attack_damage = 10
	d.attack_interval = 1.0
	d.skill_kind = kind
	d.skill_damage = dmg
	d.skill_radius = radius
	d.skill_slow_pct = 50
	d.skill_slow_duration = 3.0
	d.skill_haste_pct = 30
	d.skill_duration = 4.0
	return Entities.Hero.new(1, d, Vector2i(12, 2))

func _mon(id: int, path_dist: float, hp := 100, armor := 0) -> Entities.Monster:
	var d := MonsterDefScript.new()
	d.id = "stub"
	d.max_hp = hp
	d.armor = armor
	var m = Entities.Monster.new(id, d)
	m.path_dist = path_dist
	return m

func _sim_with(monsters: Array) -> StubSim:
	var s := StubSim.new()
	s.grid = GridScript.new(16, 10, WPS)
	s.monsters = monsters
	return s

func test_whirl_damages_all_in_radius():
	var h := _hero("whirl", 1.5, 20)
	var in1 := _mon(1, 12.0)   # 距英雄 1.41 < 1.5
	var in2 := _mon(2, 13.0)   # 距英雄 1.0
	var out := _mon(3, 9.0)    # 距英雄 ≈ 3.5
	var sim := _sim_with([in1, in2, out])
	var events: Array = SkillSystem.cast(sim, h)
	var casts := 0
	for e in events:
		if e.type == "skill_cast":
			casts += 1
	assert_eq(casts, 1)
	assert_eq(in1.hp, 80)   # 100-20
	assert_eq(in2.hp, 80)
	assert_eq(out.hp, 100)  # 射程外不受影响

func test_arrow_rain_centers_on_target_and_fails_without():
	var h := _hero("arrow_rain", 1.5, 24)
	var target := _mon(1, 13.0)   # 射程内目标
	var beside := _mon(2, 12.0)   # 目标旁边 (11.5,1.5) 距 (12.5,1.5) 1.0 < 1.5
	var sim := _sim_with([target, beside])
	var events: Array = SkillSystem.cast(sim, h)
	assert_gt(events.size(), 0)
	assert_eq(target.hp, 76)
	assert_eq(beside.hp, 76)
	var empty := _sim_with([_mon(3, 9.0)])  # 无射程内目标
	assert_eq(SkillSystem.cast(empty, h).size(), 0)  # 失败返回空

func test_frost_ring_slows():
	var h := _hero("frost_ring", 2.0, 12)
	var m := _mon(1, 13.0)
	var sim := _sim_with([m])
	var events: Array = SkillSystem.cast(sim, h)
	var slowed := false
	for e in events:
		if e.type == "slowed":
			slowed = true
	assert_true(slowed)
	assert_almost_eq(m.move_speed(), 0.5 * m.def.move_speed, 0.001)  # 减速 50%

func test_barrage_high_damage():
	var h := _hero("barrage", 2.5, 55)
	var m := _mon(1, 13.0, 200)
	var sim := _sim_with([m])
	SkillSystem.cast(sim, h)
	assert_eq(m.hp, 145)

func test_aegis_hastes_and_shields_allies():
	var h := _hero("aegis", 2.0, 0)
	h.haste_timer = 0.0
	var ally := Entities.Hero.new(2, _hero("whirl").def, Vector2i(11, 2))
	var sim := _sim_with([])
	sim.heroes = [h, ally]
	var events: Array = SkillSystem.cast(sim, h)
	assert_gt(events.size(), 0)
	assert_gt(ally.haste_timer, 0.0)
	assert_gt(ally.aegis_timer, 0.0)
