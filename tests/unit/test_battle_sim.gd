extends GutTest
## BattleSim P0 桩：tick 计数与事件流。

const BattleSim = preload("res://src/core/battle_sim.gd")
const Events = preload("res://src/core/events.gd")

func test_initial_tick_count_zero():
	var sim = BattleSim.new()
	assert_eq(sim.tick_count, 0)

func test_step_emits_tick_event_and_counts():
	var sim = BattleSim.new()
	var events = sim.step()
	assert_eq(sim.tick_count, 1)
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, Events.TICK)
	assert_eq(events[0].data.tick, 1)

func test_1000_steps_reaches_1000():
	var sim = BattleSim.new()
	for i in 1000:
		sim.step()
	assert_eq(sim.tick_count, 1000)
