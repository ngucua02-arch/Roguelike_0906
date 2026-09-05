extends GutTest
## BattleSim P1：生成/移动/漏怪/城堡扣血/败北锁定（索敌攻击在 Task 4 追加）。

const BattleSim = preload("res://src/core/battle_sim.gd")
const Events = preload("res://src/core/events.gd")

func _run_to_end(sim, max_ticks := 20000) -> int:
	var t := 0
	while sim.result == "" and t < max_ticks:
		t += 1
		sim.step()
	return t

func test_step_emits_tick_first():
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	var events: Array = sim.step()
	assert_eq(sim.tick_count, 1)
	assert_eq(events[0].type, Events.TICK)
	assert_eq(events[0].data.tick, 1)

func test_monster_moves_along_path():
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	for i in 20:
		sim.step()
	var m = sim.monsters[0]
	assert_almost_eq(m.path_dist, 1.2, 0.001)  # 1.2 格/秒 × 1 秒
	var pos: Vector2 = sim.grid.point_at(m.path_dist)
	assert_almost_eq(pos.x, 0.7, 0.001)
	assert_almost_eq(pos.y, 1.5, 0.001)

func test_first_step_has_spawn_and_move():
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	var events: Array = sim.step()
	var types := []
	for e in events:
		types.append(e.type)
	assert_has(types, Events.SPAWN)
	assert_has(types, Events.MOVE)

func test_leak_decrements_castle_and_resolves_monster():
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	var t := _run_to_end(sim)
	assert_gt(t, 0)
	assert_eq(sim.castle_hp, 9)
	assert_false(sim.monsters[0].alive)

func test_cleared_battle_with_leak_still_wins_on_castle_alive():
	# 1 只全漏但城堡 9>0：波次清空即胜利（塔防语义：守住 = 城堡存活）
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0})
	_run_to_end(sim)
	assert_eq(sim.result, "victory")

func test_ten_leaks_trigger_defeat():
	var sim = BattleSim.new({"hero_damage": 0})
	var leaks := 0
	var defeats := 0
	var t := 0
	while sim.result == "" and t < 2000:
		t += 1
		for e in sim.step():
			if e.type == Events.LEAK:
				leaks += 1
			elif e.type == Events.DEFEAT:
				defeats += 1
	assert_eq(sim.result, "defeat")
	assert_eq(sim.castle_hp, 0)
	assert_eq(leaks, 10)
	assert_eq(defeats, 1)
	assert_eq(sim.monsters.size(), 10)

func test_defeat_locks_sim():
	var sim = BattleSim.new({"total_spawns": 1, "hero_damage": 0, "castle_hp": 1})
	_run_to_end(sim)
	assert_eq(sim.result, "defeat")
	var frozen_tick: int = sim.tick_count
	var events: Array = sim.step()
	assert_eq(events.size(), 0)
	assert_eq(sim.tick_count, frozen_tick)

func test_hero_attacks_in_range_and_damage_applied():
	var sim = BattleSim.new({"total_spawns": 1})
	var attacks := 0
	var hurts := 0
	var first_damage := -1
	for i in 300:
		for e in sim.step():
			if e.type == Events.ATTACK:
				attacks += 1
				if first_damage < 0:
					first_damage = e.data.damage
			elif e.type == Events.HURT:
				hurts += 1
	assert_gt(attacks, 0)
	assert_eq(attacks, hurts)
	assert_eq(first_damage, 12)

func test_hero_out_of_range_never_attacks():
	var sim = BattleSim.new({"hero_range_tiles": 0.5, "total_spawns": 1})
	var attacks := 0
	for i in 300:
		for e in sim.step():
			if e.type == Events.ATTACK:
				attacks += 1
	assert_eq(attacks, 0)  # 射程 0.5 < 离路 1.0，够不到任何怪

func test_armor_reduces_damage():
	var sim = BattleSim.new({"monster_armor": 5, "total_spawns": 1})
	var hurt_hp := -1
	for i in 300:
		for e in sim.step():
			if e.type == Events.HURT and hurt_hp < 0:
				hurt_hp = e.data.hp
				assert_eq(e.data.damage, 7)
	assert_eq(hurt_hp, 23)

func test_kill_emits_monster_died():
	var sim = BattleSim.new({"total_spawns": 1})
	var died := 0
	var t := 0
	while sim.result == "" and t < 2000:
		t += 1
		for e in sim.step():
			if e.type == Events.MONSTER_DIED:
				died += 1
	assert_eq(died, 1)
	assert_eq(sim.result, "victory")

func test_default_config_holds_castle_victory():
	# P1 完成标志：默认数值 10 只全歼、城堡满血（数值已原型验证：约 681 tick）
	var sim = BattleSim.new()
	var victories := 0
	var died := 0
	var t := 0
	while sim.result == "" and t < 20000:
		t += 1
		for e in sim.step():
			if e.type == Events.VICTORY:
				victories += 1
			elif e.type == Events.MONSTER_DIED:
				died += 1
	assert_eq(sim.result, "victory")
	assert_eq(sim.castle_hp, 10)
	assert_eq(died, 10)
	assert_eq(victories, 1)
	assert_lt(t, 20000)

func test_victory_locks_sim():
	var sim = BattleSim.new({"total_spawns": 1})
	_run_to_end(sim)
	assert_eq(sim.result, "victory")
	var frozen_tick: int = sim.tick_count
	var events: Array = sim.step()
	assert_eq(events.size(), 0)
	assert_eq(sim.tick_count, frozen_tick)
