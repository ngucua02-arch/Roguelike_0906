extends Node
## P5 平衡统计：多种子 × 弱/正常两档策略跑完整冒险，输出通关率。
## 用法：godot --headless --path . res://tools/balance_sim.tscn

const Events = preload("res://src/core/events.gd")
const MAX_GUARD := 300000
const BUY_PLAN := [
	{"def_id": "swordsman", "cell": Vector2i(12, 2)},
	{"def_id": "archer", "cell": Vector2i(11, 2)},
	{"def_id": "mage", "cell": Vector2i(12, 3)},
	{"def_id": "cannonier", "cell": Vector2i(12, 4)},
	{"def_id": "priest", "cell": Vector2i(12, 5)},
]

var strat := "normal"
var seed_v := 1

func _ready() -> void:
	var out := ""
	for s in ["weak", "normal"]:
		var wins := 0
		var detail := ""
		for seed_v in [1, 2, 3, 4, 5]:
			var r: Dictionary = _run_one(s, seed_v)
			if r.win:
				wins += 1
			detail += "  seed=%d %s castle=%d kills=%d\n" % [seed_v, r.result, r.castle, r.kills]
		out += "%s: %d/5 胜\n%s" % [strat, wins, detail]
	print("BALANCE_RESULT\n" + out)
	get_tree().quit(0)

func _run_one(s: String, seed_v: int) -> Dictionary:
	strat = s
	seed_v = seed_v
	Game.restart_adventure(seed_v)
	var guard := 0
	while guard < MAX_GUARD:
		guard += 1
		match Game.phase:
			"event":
				_pick()
			"prep":
				_shop()
				Game.start_battle_phase()
			"battle":
				if Game.battle().director.phase == "break" and strat == "normal":
					_sweep()
				Game._physics_process(0.05)
				if strat == "normal":
					for h in Game.battle().heroes:
						Game.request_skill(h.id)
			"adventure_win":
				return {"win": true, "result": "win", "castle": Game.run.castle_hp, "kills": Game.run.kills_total}
			"adventure_lose":
				return {"win": false, "result": "lose", "castle": 0, "kills": Game.run.kills_total}
			"level_result":
				Game.continue_to_event()
	return {"win": false, "result": "timeout", "castle": -1, "kills": -1}

func _pick() -> void:
	if strat == "weak":
		Game.pick_event(Game.event_choices.size() - 1)  # 弱策略：乱选
		return
	var ids := []
	for d in Game.event_choices:
		ids.append(d.id)
	for want in ["attack_plus", "speed_plus", "gold_plus"]:
		var i: int = ids.find(want)
		if i >= 0:
			Game.pick_event(i)
			return
	Game.pick_event(0)

func _shop() -> void:
	if strat == "weak":
		if Game.battle().heroes.is_empty():
			Game.battle().try_deploy("swordsman", Vector2i(12, 2))
		return
	var bought := true
	while bought:
		bought = false
		for plan in BUY_PLAN:
			var ev: Array = Game.battle().try_deploy(plan.def_id, plan.cell)
			for e in ev:
				if e.type == Events.DEPLOYED:
					bought = true
					break
			if bought:
				break
		if bought:
			continue
		var sim = Game.battle()
		if sim.gold >= 40 and not sim.heroes.is_empty():
			var lowest = sim.heroes[0]
			for h in sim.heroes:
				if h.level < lowest.level:
					lowest = h
			var ev2: Array = sim.try_upgrade(lowest.id, "damage")
			for e in ev2:
				if e.type == Events.UPGRADED:
					bought = true

func _sweep() -> void:
	var sim = Game.battle()
	for plan in BUY_PLAN:
		sim.try_deploy(plan.def_id, plan.cell)
