extends GutTest
## 工程冒烟：GUT 链路与核心脚本加载可用。

const EventsScript := preload("res://src/core/events.gd")

func test_gut_and_events_alive():
	assert_true(true)
	assert_eq(EventsScript.TICK, "tick")
