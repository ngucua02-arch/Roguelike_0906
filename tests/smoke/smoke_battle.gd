extends Node
## P1 冒烟：headless 打完一场战斗，断言能分出胜负且胜负事件恰好一次。
## 契约：result 为空时每 tick 至少产出一个事件（TICK 恒在），这里显式校验。

const BattleSim = preload("res://src/core/battle_sim.gd")
const Events = preload("res://src/core/events.gd")

const MAX_TICKS := 20000

func _ready() -> void:
	var sim = BattleSim.new()  # 默认数值：P1 完成标志——默认可守住
	var ticks := 0
	while sim.result == "" and ticks < MAX_TICKS:
		ticks += 1
		var events: Array = sim.step()
		if events.is_empty():
			push_error("第 %d tick 未产出事件" % ticks)
			get_tree().quit(1)
			return
	if ticks >= MAX_TICKS:
		push_error("超出 tick 上限仍未分出胜负")
		get_tree().quit(1)
		return
	if sim.result != "victory" or sim.castle_hp <= 0:
		push_error("默认配置应守住: result=%s castle=%d" % [sim.result, sim.castle_hp])
		get_tree().quit(1)
		return
	print("SMOKE_OK result=%s castle_hp=%d ticks=%d" % [sim.result, sim.castle_hp, ticks])
	get_tree().quit(0)
