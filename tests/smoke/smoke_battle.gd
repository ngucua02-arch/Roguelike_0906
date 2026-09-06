extends Node
## P2 冒烟：自动玩家打满默认 6 波——脚本化买/升/放技能，断言内容全量且默认可守住。
## 策略：开局剑士@(12,2)；每次清波循环消费——按 弓手→法师→炮手→牧师 优先在
## 预设格购买，买满则给最低等级英雄升攻，直到金币不够；每 tick 全英雄尝试放技能。

const BattleSim = preload("res://src/core/battle_sim.gd")
const Events = preload("res://src/core/events.gd")

const MAX_TICKS := 60000
const BUY_PLAN := [
	{"def_id": "archer", "cell": Vector2i(11, 2)},
	{"def_id": "mage", "cell": Vector2i(12, 3)},
	{"def_id": "cannonier", "cell": Vector2i(12, 4)},
	{"def_id": "priest", "cell": Vector2i(12, 5)},
]

func _ready() -> void:
	var sim = BattleSim.new()
	sim.try_deploy("swordsman", Vector2i(12, 2))
	var ticks := 0
	var waves_started := 0
	var waves_cleared := 0
	var boss_seen := false
	var gold_ok := true
	while sim.result == "" and ticks < MAX_TICKS:
		ticks += 1
		for e in sim.step():
			match e.type:
				Events.WAVE_STARTED:
					waves_started += 1
				Events.WAVE_CLEARED:
					waves_cleared += 1
					_spend_down(sim)
				Events.SPAWN:
					if e.data.def_id == "ogre_lord":
						boss_seen = true
		for h in sim.heroes:
			sim.try_skill(h.id)
		if sim.gold < 0:
			gold_ok = false
	if ticks >= MAX_TICKS:
		_fail("超出 tick 上限仍未分出胜负")
	elif waves_started != 6 or waves_cleared != 6:
		_fail("波次未打满: started=%d cleared=%d" % [waves_started, waves_cleared])
	elif not boss_seen:
		_fail("boss 未出场")
	elif sim.heroes.size() < 5:
		_fail("自动玩家未买满英雄: %d" % sim.heroes.size())
	elif not gold_ok:
		_fail("金币出现负数")
	elif sim.result != "victory" or sim.castle_hp <= 0:
		_fail("默认策略应守住: result=%s castle=%d" % [sim.result, sim.castle_hp])
	else:
		print("SMOKE_OK result=%s castle_hp=%d ticks=%d heroes=%d gold=%d" % [sim.result, sim.castle_hp, ticks, sim.heroes.size(), sim.gold])
		get_tree().quit(0)

## 清波后循环消费：优先买规划英雄，买满则升攻，直到金币不够
func _spend_down(sim) -> void:
	var bought := true
	while bought:
		bought = false
		if _try_buy(sim):
			bought = true
			continue
		if sim.gold >= 40 and not sim.heroes.is_empty():
			var lowest = sim.heroes[0]
			for h in sim.heroes:
				if h.level < lowest.level:
					lowest = h
			var ev: Array = sim.try_upgrade(lowest.id, "damage")
			if ev.size() > 0 and ev[0].type == Events.UPGRADED:
				bought = true

func _try_buy(sim) -> bool:
	for plan in BUY_PLAN:
		var ev: Array = sim.try_deploy(plan.def_id, plan.cell)
		for e in ev:
			if e.type == Events.DEPLOYED:
				return true
	return false

func _fail(msg: String) -> void:
	push_error(msg)
	get_tree().quit(1)
