extends GutTest
## BattleSim P2 整合：请求层（部署/升级/技能）、波次、怪物特性、胜负锁定。

const BattleSim = preload("res://src/core/battle_sim.gd")
const Events = preload("res://src/core/events.gd")
const HeroDefScript = preload("res://src/core/def/hero_def.gd")
const MonsterDefScript = preload("res://src/core/def/monster_def.gd")

func _hero_def(id: String, dmg := 12, cost := 50, kind := "", rng := 1.5) -> HeroDef:
	var d := HeroDefScript.new()
	d.id = id
	d.display_name = id
	d.cost = cost
	d.attack_damage = dmg
	d.attack_interval = 0.8
	d.range_tiles = rng
	d.skill_kind = kind
	d.skill_cooldown = 1.0
	d.skill_damage = 20
	d.skill_radius = 1.5
	d.skill_slow_pct = 50
	d.skill_slow_duration = 3.0
	d.skill_haste_pct = 30
	d.skill_duration = 4.0
	return d

func _mon_def(id: String, hp := 30, speed := 1.2, armor := 0, gold := 3) -> MonsterDef:
	var d := MonsterDefScript.new()
	d.id = id
	d.display_name = id
	d.max_hp = hp
	d.move_speed = speed
	d.armor = armor
	d.gold_drop = gold
	return d

func _mini_config(overrides: Dictionary = {}) -> Dictionary:
	var c := {
		"hero_defs": [_hero_def("swordsman")],
		"monster_defs": [_mon_def("goblin"), _mon_def("shaman", 45, 0.9, 1, 6), _mon_def("boss", 800, 0.5, 6, 50)],
		"waves": [{"groups": [{"def_id": "goblin", "count": 2, "interval": 0.5}]}],
		"start_gold": 100,
	}
	for k in overrides:
		c[k] = overrides[k]
	return c

func _types_of(events: Array) -> Array:
	var out := []
	for e in events:
		out.append(e.type)
	return out

func _run_to_end(sim, max_ticks := 20000) -> int:
	var t := 0
	while sim.result == "" and t < max_ticks:
		t += 1
		sim.step()
	return t

func test_deploy_success_spends_gold():
	var sim = BattleSim.new(_mini_config())
	var ev: Array = sim.try_deploy("swordsman", Vector2i(12, 2))
	assert_has(_types_of(ev), Events.DEPLOYED)
	assert_eq(sim.heroes.size(), 1)
	assert_eq(sim.gold, 50)  # 100-60

func test_deploy_rejections():
	var sim = BattleSim.new(_mini_config({"start_gold": 10}))
	assert_has(_types_of(sim.try_deploy("swordsman", Vector2i(12, 2))), Events.BUY_FAILED)  # no_gold
	var sim2 = BattleSim.new(_mini_config())
	assert_has(_types_of(sim2.try_deploy("swordsman", Vector2i(13, 1))), Events.BUY_FAILED)  # on_path
	assert_has(_types_of(sim2.try_deploy("swordsman", Vector2i(5, 5))), Events.BUY_FAILED)   # not_adjacent_path
	assert_has(_types_of(sim2.try_deploy("swordsman", Vector2i(-1, 1))), Events.BUY_FAILED)  # out_of_bounds
	assert_eq(sim2.try_deploy("swordsman", Vector2i(12, 2)).size(), 1)
	assert_has(_types_of(sim2.try_deploy("swordsman", Vector2i(12, 2))), Events.BUY_FAILED)  # occupied
	assert_has(_types_of(sim2.try_deploy("archer", Vector2i(12, 2))), Events.BUY_FAILED)     # no_such_def

func test_upgrade_damage_and_interval():
	var sim = BattleSim.new(_mini_config({"start_gold": 200}))
	sim.try_deploy("swordsman", Vector2i(12, 2))
	var hid: int = sim.heroes[0].id
	assert_has(_types_of(sim.try_upgrade(hid, "damage")), Events.UPGRADED)
	assert_eq(sim.heroes[0].damage(), 16)  # round(12×1.3)=round(15.6)
	assert_eq(sim.gold, 110)  # 200-50-40
	assert_has(_types_of(sim.try_upgrade(hid, "interval")), Events.UPGRADED)
	assert_almost_eq(sim.heroes[0].interval_mult, 0.85, 0.001)
	assert_eq(sim.heroes[0].level, 3)
	assert_has(_types_of(sim.try_upgrade(hid, "hp")), Events.BUY_FAILED)  # bad_stat

func test_skill_request_flow():
	var sim = BattleSim.new(_mini_config({
		"hero_defs": [_hero_def("swordsman", 12, 50, "whirl")],
		"waves": [{"groups": [{"def_id": "goblin", "count": 1, "interval": 0.5}]}],
	}))
	sim.try_deploy("swordsman", Vector2i(12, 2))
	for i in 40:
		sim.step()  # 怪走到射程内
	var ev: Array = sim.try_skill(sim.heroes[0].id)
	assert_has(_types_of(ev), Events.SKILL_CAST)
	assert_has(_types_of(sim.try_skill(sim.heroes[0].id)), Events.SKILL_FAILED)  # cooldown
	sim.heroes[0].skill_cd = 0.0
	sim.heroes[0].stun_timer = 1.0
	assert_has(_types_of(sim.try_skill(sim.heroes[0].id)), Events.SKILL_FAILED)  # stunned

func test_shaman_heals_damaged_monster():
	var cfg := _mini_config({
		"hero_defs": [],
		"monster_defs": [_mon_def("goblin"), _mon_def("shaman", 45, 0.9, 1, 6)],
		"waves": [{"groups": [{"def_id": "goblin", "count": 1, "interval": 0.1}, {"def_id": "shaman", "count": 1, "interval": 0.1}]}],
	})
	cfg.monster_defs[1].heal_radius = 2.0
	cfg.monster_defs[1].heal_amount = 8
	cfg.monster_defs[1].heal_interval = 3.0
	var sim = BattleSim.new(cfg)
	for i in 5:
		sim.step()  # 两只都出生
	var goblin = null
	for m in sim.monsters:
		if m.def.id == "goblin":
			goblin = m
	sim.apply_damage(goblin, 20, [])
	assert_eq(goblin.hp, 10)
	var healed := false
	var t := 0
	while t < 100:
		t += 1
		for e in sim.step():
			if e.type == Events.HEALED:
				healed = true
	assert_true(healed)
	assert_gt(goblin.hp, 10)

func test_boss_stomp_stuns_but_aegis_blocks():
	var cfg := _mini_config({
		"hero_defs": [_hero_def("swordsman", 12, 50, "whirl"), _hero_def("swordsman2", 12, 50, "whirl")],
		"monster_defs": [_mon_def("goblin"), _mon_def("boss", 2000, 0.5, 0, 50)],
		"waves": [{"groups": [{"def_id": "boss", "count": 1, "interval": 0.1}]}],
	})
	cfg.monster_defs[1].stomp_radius = 2.5
	cfg.monster_defs[1].stomp_interval = 1.0
	cfg.monster_defs[1].stomp_stun_duration = 2.0
	var sim = BattleSim.new(cfg)
	sim.try_deploy("swordsman", Vector2i(12, 2))
	sim.try_deploy("swordsman2", Vector2i(11, 2))
	for i in 3:
		sim.step()  # boss 出生
	sim.monsters[0].path_dist = 14.0  # 直接放到英雄旁 (13.5,1.5)
	sim.monsters[0].stomp_timer = 0.05
	sim.heroes[0].aegis_timer = 999.0  # 圣盾中（白盒）
	var stunned_ids := []
	var t := 0
	while t < 60:
		t += 1
		for e in sim.step():
			if e.type == Events.STUNNED:
				stunned_ids.append(e.data.hero_id)
	assert_gt(sim.heroes[1].stun_timer, 0.0)  # 被踩晕
	assert_eq(sim.heroes[0].stun_timer, 0.0)  # 圣盾免疫
	assert_gt(stunned_ids.size(), 0)
	assert_does_not_have(stunned_ids, sim.heroes[0].id)

func test_boss_leak_costs_3_and_still_wins():
	var cfg := _mini_config({
		"hero_defs": [],
		"monster_defs": [_mon_def("boss", 100, 5.0, 0, 50)],
		"waves": [{"groups": [{"def_id": "boss", "count": 1, "interval": 0.1}]}],
	})
	cfg.monster_defs[0].leak_damage = 3
	var sim = BattleSim.new(cfg)
	var t := _run_to_end(sim)
	assert_gt(t, 0)
	assert_eq(sim.castle_hp, 7)  # 漏 boss 扣 3
	assert_eq(sim.result, "victory")

func test_mini_battle_terminal_and_lock():
	var sim = BattleSim.new(_mini_config({"hero_defs": []}))
	_run_to_end(sim)
	assert_eq(sim.result, "victory")  # 2 只全漏但城堡 8>0
	var frozen: int = sim.tick_count
	assert_eq(sim.step().size(), 0)
	assert_eq(sim.tick_count, frozen)

func test_default_config_defenseless_falls_mid_waves():
	# 无英雄：全漏；城堡 10 HP 在第 2 波途中归零（w1 漏 6 → 剩 4）
	var sim = BattleSim.new({})
	var waves_started := 0
	var t := 0
	while sim.result == "" and t < 12000:
		t += 1
		for e in sim.step():
			if e.type == Events.WAVE_STARTED:
				waves_started += 1
	assert_eq(sim.result, "defeat")
	assert_eq(waves_started, 2)
	assert_eq(sim.castle_hp, 0)  # 归零即判负
