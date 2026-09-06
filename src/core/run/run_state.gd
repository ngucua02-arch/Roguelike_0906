extends RefCounted
## 一条冒险的持久状态：城堡/金币/阵容/全局加成/已用事件/确定性 RNG。

var level_index := 0            # 0 基
var castle_hp := 10
var castle_max := 10
var gold := 100
var attack_mult := 1.0          # 全局攻（永久）
var interval_mult := 1.0        # 全局攻速（永久）
var cd_mult := 1.0              # 技能 CD（永久）
var temp_attack_mult := 1.0     # 本关临时攻（宝箱）
var elite_hp_mult := 1.0        # 精英挑战：仅当关
var elite_gold_mult := 1.0
var kills_total := 0
var ticks_total := 0
var roster: Array = []          # [{def_id, cell, level, damage_mult, interval_mult}]
var used_event_ids := {}
var rng := RandomNumberGenerator.new()

func _init(seed_value := 0) -> void:
	rng.seed = seed_value

## 从事件池抽 n 个（排除已用；确定性依赖注入的种子）
func draw_events(pool: Array, n := 3) -> Array:
	var avail := pool.filter(func(d): return not used_event_ids.has(d.id))
	var picked: Array = []
	while picked.size() < n and avail.size() > 0:
		var i := rng.randi_range(0, avail.size() - 1)
		picked.append(avail[i])
		avail.remove_at(i)
	return picked

func apply_event(def) -> void:
	used_event_ids[def.id] = true
	match def.kind:
		"attack":
			attack_mult *= 1.0 + def.value / 100.0
		"attack_speed":
			interval_mult *= 100.0 / (100.0 + def.value)
		"gold":
			gold += def.value
		"castle":
			castle_hp += def.value
			castle_max += def.value
		"cooldown":
			cd_mult *= 1.0 - def.value / 100.0
		"levelup":
			if roster.size() > 0:
				var i := rng.randi_range(0, roster.size() - 1)
				roster[i].level += 1
				roster[i].damage_mult *= 1.3
		"elite":
			elite_hp_mult = 1.0 + def.value / 100.0
			elite_gold_mult = 2.0
		"chest":
			if rng.randf() < 0.5:
				gold += rng.randi_range(60, 120)
			else:
				temp_attack_mult = 1.3
	used_event_ids[def.id] = true

## 进入下一关：清掉仅当关的临时效果
func next_level() -> void:
	level_index += 1
	elite_hp_mult = 1.0
	elite_gold_mult = 1.0
	temp_attack_mult = 1.0
