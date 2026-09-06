extends Node
## P3 冒烟：自动玩家打满 5 关完整冒险（确定性：手动驱动状态机 + 固定种子）。
## 策略：事件优先 攻→速→金，否则选 0；备战期买满 BUY_PLAN 再升攻；战斗期放技能。

const Events = preload("res://src/core/events.gd")

const MAX_GUARD := 300000
const BUY_PLAN := [
	{"def_id": "swordsman", "cell": Vector2i(12, 2)},
	{"def_id": "archer", "cell": Vector2i(11, 2)},
	{"def_id": "mage", "cell": Vector2i(12, 3)},
	{"def_id": "cannonier", "cell": Vector2i(12, 4)},
	{"def_id": "priest", "cell": Vector2i(12, 5)},
]
const WANTED_EVENTS := ["attack_plus", "speed_plus", "gold_plus"]

func _ready() -> void:
	Game.restart_adventure()
	var guard := 0
	while guard < MAX_GUARD:
		guard += 1
		match Game.phase:
			"event":
				_pick_greedy()
			"prep":
				_shop()
				Game.start_battle_phase()
			"battle":
				if Game.battle().director.phase == "break":
					_shop()  # 波间休整扫货
				Game._physics_process(0.05)  # 手动步进 1 tick
				for h in Game.battle().heroes:
					Game.request_skill(h.id)
			"level_result":
				Game.continue_to_event()
			"adventure_win":
				var run = Game.run
				if run.level_index != 4:
					_fail("未打满 5 关: level_index=%d" % run.level_index)
				elif Game.battle().heroes.size() < 5:
					_fail("阵容不满: %d" % Game.battle().heroes.size())
				elif run.kills_total <= 0:
					_fail("总击杀为 0")
				elif run.castle_hp <= 0:
					_fail("城堡应为正")
				else:
					print("SMOKE_ADVENTURE_OK levels=5 kills=%d castle=%d/%d time=%s heroes=%d" % [
						run.kills_total, run.castle_hp, run.castle_max, _fmt_time(run.ticks_total), Game.battle().heroes.size()])
					get_tree().quit(0)
				return
			"adventure_lose":
				_fail("冒险失败于第 %d 关（kills=%d）" % [Game.run.level_index + 1, Game.run.kills_total])
				return
	_fail("超出预算仍未结束冒险")

func _pick_greedy() -> void:
	var ids := []
	for d in Game.event_choices:
		ids.append(d.id)
	for want in WANTED_EVENTS:
		var i: int = ids.find(want)
		if i >= 0:
			Game.pick_event(i)
			return
	Game.pick_event(0)

func _shop() -> void:
	var bought := true
	while bought:
		bought = false
		var sim = Game.battle()
		for plan in BUY_PLAN:
			var ev: Array = sim.try_deploy(plan.def_id, plan.cell)
			if _has(ev, Events.DEPLOYED):
				bought = true
				break
		if bought:
			continue
		var sim2 = Game.battle()
		if sim2.gold >= 40 and not sim2.heroes.is_empty():
			var lowest = sim2.heroes[0]
			for h in sim2.heroes:
				if h.level < lowest.level:
					lowest = h
			var ev: Array = sim2.try_upgrade(lowest.id, "damage")
			if _has(ev, Events.UPGRADED):
				bought = true

func _has(ev: Array, type: String) -> bool:
	for e in ev:
		if e.type == type:
			return true
	return false

func _fmt_time(ticks: int) -> String:
	var sec := int(ticks / 20.0)
	return "%d:%02d" % [sec / 60, sec % 60]

func _fail(msg: String) -> void:
	push_error(msg)
	get_tree().quit(1)
