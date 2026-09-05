extends GutTest
## 工程冒烟：GUT 链路与核心脚本加载可用。

func test_gut_and_events_alive():
	assert_true(true)
	var Events = preload("res://src/core/events.gd")
	assert_eq(Events.TICK, "tick")
