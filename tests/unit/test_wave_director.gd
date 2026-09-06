extends GutTest
## 波次调度：出场节奏/耗尽判定/清波转休整/休整自动下一波/末波收尾。

const WaveDirector = preload("res://src/core/battle/wave_director.gd")

func _waves() -> Array:
	return [
		{"groups": [{"def_id": "goblin", "count": 2, "interval": 1.0}]},
		{"groups": [{"def_id": "orc", "count": 1, "interval": 0.5}, {"def_id": "wolf", "count": 1, "interval": 2.0}]},
	]

func test_starts_idle_then_first_wave_spawns_rhythmically():
	var d = WaveDirector.new(_waves())
	assert_eq(d.phase, "idle")
	d.start_next_wave()
	assert_eq(d.index, 0)
	assert_eq(d.phase, "wave")
	assert_eq(d.tick(0.5).size(), 0)   # 首只 1.0s 后
	var mid: Array = d.tick(0.5)       # 累计 1.0s
	assert_eq(mid, ["goblin"])
	assert_eq(d.tick(0.9).size(), 0)
	assert_eq(d.tick(0.1), ["goblin"]) # 累计 2.0s

func test_announce_clear_then_break_auto_next():
	var d = WaveDirector.new(_waves())
	d.start_next_wave()
	d.tick(10.0)  # 首波全部出场（2 只 @1s）
	assert_true(d.exhausted())
	var r: Dictionary = d.announce_clear()
	assert_false(r.is_last)
	assert_eq(d.phase, "break")
	assert_almost_eq(d.break_left, 5.0, 0.001)
	assert_eq(d.tick(4.9).size(), 0)
	assert_eq(d.phase, "break")
	var spawns: Array = d.tick(0.1)  # 休整结束自动进第二波
	assert_eq(d.phase, "wave")
	assert_eq(d.index, 1)
	assert_eq(spawns.size(), 0)      # 首只 orc 在其 interval 0.5s 后
	assert_eq(d.tick(0.5), ["orc"])

func test_last_wave_finishes():
	var d = WaveDirector.new(_waves())
	d.start_next_wave()
	d.announce_clear()
	d.tick(5.0)  # 进入末波
	assert_eq(d.phase, "wave")
	d.tick(10.0)
	var r: Dictionary = d.announce_clear()
	assert_true(r.is_last)
	assert_true(d.is_finished())
	assert_eq(d.current_bonus(), 55)  # 35 + 10×2
