extends RefCounted
## 波次调度：逐波按组出场、波间休整 5 秒、末波收尾。
## waves 结构：[{groups: [{def_id, count, interval}], bonus 由公式给出}]

const BREAK_SECONDS := 5.0

var waves: Array = []
var index := -1            # 当前波（0 基；-1 = 未开始）
var phase := "idle"        # idle/wave/break/finished
var break_left := 0.0
var _groups: Array = []    # 当前波组计时：{def_id, left, timer}
var elapsed := 0.0         # 当前波内已过秒数

func _init(p_waves: Array) -> void:
	waves = p_waves

func wave_count() -> int:
	return waves.size()

func current_bonus() -> int:
	return 20 + 5 * (index + 1)

func start_next_wave() -> void:
	index += 1
	_groups = []
	for g in waves[index].groups:
		_groups.append({"def_id": g.def_id, "left": g.count, "timer": g.interval, "interval": g.interval})
	elapsed = 0.0
	phase = "wave"

## 推进状态：wave 出场到期怪（返回 def_id 列表）；break 倒计时到 0 自动开下一波
func tick(dt: float) -> Array:
	var spawns: Array = []
	if phase == "break":
		break_left -= dt
		if break_left <= 0.0:
			start_next_wave()
	if phase == "wave":
		elapsed += dt
		for g in _groups:
			if g.left <= 0:
				continue
			g.timer -= dt
			while g.timer <= 0.0 and g.left > 0:
				spawns.append(g.def_id)
				g.left -= 1
				g.timer += g.interval
	return spawns

func exhausted() -> bool:
	for g in _groups:
		if g.left > 0:
			return false
	return true

## 波清播报：末波转 finished，否则转 break（返回 is_last）
func announce_clear() -> Dictionary:
	if index >= waves.size() - 1:
		phase = "finished"
		return {"cleared": true, "is_last": true}
	phase = "break"
	break_left = BREAK_SECONDS
	return {"cleared": true, "is_last": false}

func is_finished() -> bool:
	return phase == "finished"
