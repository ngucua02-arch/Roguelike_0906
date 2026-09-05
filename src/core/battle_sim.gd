extends RefCounted
## 战斗模拟（P0 桩）：只统计 tick 并按步产出事件。
## P1 起逐步填充：网格/路径、实体、索敌、波次、技能、经济、胜负。

const Events = preload("res://src/core/events.gd")

var tick_count := 0

func step() -> Array:
	tick_count += 1
	return [{"type": Events.TICK, "data": {"tick": tick_count}}]
