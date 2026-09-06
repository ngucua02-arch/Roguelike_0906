extends RefCounted
## 索敌：射程内最近目标（P2 统一最近；P5 再按英雄扩索敌类型）。

static func nearest_in_range(monsters: Array, grid, from_pos: Vector2, range_tiles: float):
	var best = null
	var best_d := INF
	for m in monsters:
		if not m.alive:
			continue
		var d: float = from_pos.distance_to(grid.point_at(m.path_dist))
		if d < best_d:
			best_d = d
			best = m
	if best == null or best_d > range_tiles:
		return null
	return best
