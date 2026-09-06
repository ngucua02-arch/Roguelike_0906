extends GutTest
## RunState：事件抽取确定性/去重、8 种事件效果、跨关重置。

const RunState = preload("res://src/core/run/run_state.gd")
const EventDefScript = preload("res://src/core/def/event_def.gd")

func _ev(id: String, kind: String, value := 0) -> EventDef:
	var d := EventDefScript.new()
	d.id = id
	d.title = id
	d.desc = ""
	d.kind = kind
	d.value = value
	return d

func _pool() -> Array:
	return [
		_ev("attack_plus", "attack", 20),
		_ev("speed_plus", "attack_speed", 15),
		_ev("gold_plus", "gold", 80),
		_ev("castle_plus", "castle", 5),
		_ev("cd_plus", "cooldown", 20),
		_ev("levelup", "levelup", 1),
		_ev("elite_challenge", "elite", 30),
		_ev("free_chest", "chest", 0),
	]

func test_draw_is_deterministic_with_same_seed():
	var a = RunState.new(42)
	var b = RunState.new(42)
	var da = a.draw_events(_pool(), 3)
	var db = b.draw_events(_pool(), 3)
	assert_eq(da.size(), 3)
	assert_eq(db.size(), 3)
	for i in 3:
		assert_eq(da[i].id, db[i].id)

func test_draw_no_duplicates_and_skips_used():
	var rs = RunState.new(7)
	var got := []
	for i in 2:  # 池共 8 个：抽 2 轮×3，留 2 个给第三轮
		for d in rs.draw_events(_pool(), 3):
			got.append(d.id)
			rs.apply_event(d)
	var third: Array = rs.draw_events(_pool(), 3)
	for d in third:
		assert_does_not_have(got, d.id)  # 已用的不再出现

func test_buff_events_apply():
	var rs = RunState.new(1)
	rs.apply_event(_ev("attack_plus", "attack", 20))
	assert_almost_eq(rs.attack_mult, 1.2, 0.001)
	rs.apply_event(_ev("speed_plus", "attack_speed", 15))
	assert_almost_eq(rs.interval_mult, 100.0 / 115.0, 0.001)
	rs.apply_event(_ev("cd_plus", "cooldown", 20))
	assert_almost_eq(rs.cd_mult, 0.8, 0.001)

func test_gold_and_castle_events():
	var rs = RunState.new(1)
	rs.apply_event(_ev("gold_plus", "gold", 80))
	assert_eq(rs.gold, 200)
	rs.apply_event(_ev("castle_plus", "castle", 5))
	assert_eq(rs.castle_hp, 15)
	assert_eq(rs.castle_max, 15)

func test_elite_event_and_level_reset():
	var rs = RunState.new(1)
	rs.apply_event(_ev("elite_challenge", "elite", 30))
	assert_almost_eq(rs.elite_hp_mult, 1.3, 0.001)
	assert_eq(rs.elite_gold_mult, 2)
	rs.next_level()
	assert_almost_eq(rs.elite_hp_mult, 1.0, 0.001)
	assert_eq(rs.elite_gold_mult, 1)
	assert_almost_eq(rs.attack_mult, 1.0, 0.001)  # 没拿过攻祝福

func test_levelup_event_upgrades_roster_deterministically():
	var rs = RunState.new(99)
	rs.roster = [
		{"def_id": "swordsman", "cell": Vector2i(12, 2), "level": 1, "damage_mult": 1.0, "interval_mult": 1.0},
		{"def_id": "archer", "cell": Vector2i(11, 2), "level": 1, "damage_mult": 1.0, "interval_mult": 1.0},
	]
	rs.apply_event(_ev("levelup", "levelup", 1))
	var leveled := 0
	for m in rs.roster:
		if m.level == 2:
			leveled += 1
			assert_almost_eq(m.damage_mult, 1.3, 0.001)
	assert_eq(leveled, 1)

func test_chest_event_changes_something_deterministically():
	var a = RunState.new(5)
	a.apply_event(_ev("free_chest", "chest", 0))
	var b = RunState.new(5)
	b.apply_event(_ev("free_chest", "chest", 0))
	# 同种子结果一致：要么同额金币要么同为临时攻
	var same: bool = (a.gold == b.gold) and (a.temp_attack_mult == b.temp_attack_mult)
	assert_true(same)
	assert_true(a.gold > 100 or a.temp_attack_mult > 1.0)
