extends Node
## P0 冒烟：headless 步进 1000 tick，成功打印 SMOKE_OK 并以 0 退出。

const BattleSim = preload("res://src/core/battle_sim.gd")

const TOTAL_TICKS := 1000

func _ready() -> void:
	var sim = BattleSim.new()
	var last_events: Array = []
	for i in TOTAL_TICKS:
		last_events = sim.step()
		if sim.tick_count != i + 1:
			push_error("tick 计数中断: expected %d got %d" % [i + 1, sim.tick_count])
			get_tree().quit(1)
			return
		if last_events.is_empty():
			push_error("第 %d tick 未产出事件" % i)
			get_tree().quit(1)
			return
	if sim.tick_count != TOTAL_TICKS:
		push_error("最终计数错误: %d" % sim.tick_count)
		get_tree().quit(1)
		return
	print("SMOKE_OK tick_count=%d" % sim.tick_count)
	get_tree().quit(0)
