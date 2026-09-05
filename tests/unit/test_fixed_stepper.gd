extends GutTest
## FixedStepper：把真实时间切成固定 tick 步数，限单帧上限防死亡螺旋。

const FixedStepper = preload("res://src/core/fixed_stepper.gd")

func test_full_delta_produces_one_step():
	var s = FixedStepper.new(0.05)
	assert_eq(s.add_delta(0.05), 1)

func test_accumulates_small_deltas():
	var s = FixedStepper.new(0.05)
	assert_eq(s.add_delta(0.02), 0)
	assert_eq(s.add_delta(0.02), 0)
	assert_eq(s.add_delta(0.02), 1)

func test_large_delta_produces_multiple_steps():
	var s = FixedStepper.new(0.05)
	assert_eq(s.add_delta(0.12), 2)

func test_caps_steps_per_frame():
	var s = FixedStepper.new(0.05, 3)
	assert_eq(s.add_delta(1.0), 3)

func test_drops_backlog_after_cap():
	var s = FixedStepper.new(0.05, 3)
	assert_eq(s.add_delta(1.0), 3)
	assert_eq(s.add_delta(0.0), 0)   # 积压已丢弃，不连环补步
