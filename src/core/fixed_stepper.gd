extends RefCounted
## 固定步长累加器：累积真实 delta，按 step_interval 切成整数次步进。
## 单帧步进数封顶 max_steps_per_frame，超出部分直接丢弃（防卡顿后死亡螺旋）。

var step_interval: float
var max_steps_per_frame: int
var _accumulator := 0.0

func _init(p_step_interval: float, p_max_steps_per_frame: int = 5) -> void:
	step_interval = p_step_interval
	max_steps_per_frame = p_max_steps_per_frame

func add_delta(delta: float) -> int:
	_accumulator += delta
	var steps := 0
	while _accumulator >= step_interval and steps < max_steps_per_frame:
		_accumulator -= step_interval
		steps += 1
	if _accumulator > step_interval:
		_accumulator = 0.0
	return steps
