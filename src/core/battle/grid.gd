extends RefCounted
## 网格与路径：正交折线路径的栅格化与沿线取点。
## 规则层一律用格单位（1 格 = 1.0，格中心 = 格坐标 + 0.5）；像素换算只发生在表现层。

const CELL_SIZE := 48  # 仅供表现层参考；规则层不使用

var width: int
var height: int
var waypoints: Array
var path_cells := {}  # Vector2i -> true（含场外起点格，spawn 用）
var path_length := 0.0
var _segment_lengths: Array = []

func _init(p_width: int, p_height: int, p_waypoints: Array) -> void:
	width = p_width
	height = p_height
	waypoints = p_waypoints
	for i in waypoints.size() - 1:
		var a: Vector2i = waypoints[i]
		var b: Vector2i = waypoints[i + 1]
		assert(a.x == b.x or a.y == b.y, "路径段必须正交")
		var c := a
		while true:
			path_cells[c] = true
			if c == b:
				break
			c += Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		_segment_lengths.append(float(absi(b.x - a.x) + absi(b.y - a.y)))
	for l in _segment_lengths:
		path_length += l

static func signi(v: int) -> int:
	return 1 if v > 0 else (-1 if v < 0 else 0)

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func is_path(cell: Vector2i) -> bool:
	return path_cells.has(cell)

func cell_to_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)

func point_at(dist: float) -> Vector2:
	var d := clampf(dist, 0.0, path_length)
	for i in waypoints.size() - 1:
		var seg: float = _segment_lengths[i]
		if d <= seg or i == waypoints.size() - 2:
			var a: Vector2i = waypoints[i]
			var b: Vector2i = waypoints[i + 1]
			var dir := (Vector2(b - a) / seg) if seg > 0.0 else Vector2.ZERO
			return cell_to_pos(a) + dir * d
		d -= seg
	return cell_to_pos(waypoints[waypoints.size() - 1])
